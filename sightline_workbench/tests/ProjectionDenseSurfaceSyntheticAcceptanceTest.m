classdef ProjectionDenseSurfaceSyntheticAcceptanceTest < matlab.unittest.TestCase
    %ProjectionDenseSurfaceSyntheticAcceptanceTest Tests final truth evidence.

    methods (TestClassSetup)
        function addProjectPaths(testCase)
            projectRoot = fileparts(fileparts(mfilename("fullpath")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(projectRoot, "src")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(projectRoot, "tests")));
        end
    end

    methods (TestMethodSetup)
        function closeFigures(testCase)
            testCase.addTeardown(@() close("all", "force"));
            close("all", "force");
        end
    end

    methods (Test)
        function testReportedVariantBuildsViewerSceneWithoutTruth(testCase)
            [~, run, navigation] = ...
                ProjectionDenseSurfaceSyntheticTestSupport.acceptanceFixture();

            scene = ProjectionDenseSurfaceSyntheticAcceptance.buildScene( ...
                navigation, 1, "pointing-only", run.Images);
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow

            testCase.verifyEqual(numel(scene.layers), numel(run.Images));
            testCase.verifyFalse(scene.SyntheticAcceptance.TruthIncluded);
            testCase.verifyEqual(scene.SyntheticAcceptance.GeometryRole, ...
                "reported-only");
            testCase.verifyFalse(isfield(scene, "Truth"));
            testCase.verifyFalse(isfield(scene, "Terrain"));
            testCase.verifyEqual(scene.layers(1).Image, run.Images{1});
            testCase.verifyFalse(scene.layers(1).SourceGeometry.TruthIncluded);
            testCase.verifyTrue(isvalid(app));
        end

        function testAllPresetModesRunStagedAlignment(testCase)
            [~, run, navigation] = ...
                ProjectionDenseSurfaceSyntheticTestSupport.acceptanceFixture();
            options = ProjectionDenseSurfaceSyntheticAcceptanceTest.options(false);

            report = ProjectionDenseSurfaceSyntheticAcceptance.run( ...
                navigation, run.Truth, ...
                ProjectionDenseSurfaceSyntheticAcceptanceTest.withImages( ...
                options, run.Images));

            testCase.verifyEqual(report.Status, "complete");
            testCase.verifyEqual(numel(report.Runs), 4);
            testCase.verifyEqual(string({report.Runs.Status}), ...
                repmat("completed", 1, 4));
            testCase.verifyGreaterThanOrEqual( ...
                min(arrayfun(@(record) record.StageCounts.Raw, report.Runs)), 3);
            testCase.verifyGreaterThanOrEqual( ...
                min(arrayfun(@(record) record.StageCounts.Filtered, report.Runs)), 3);
            testCase.verifyTrue(all(arrayfun(@(record) ...
                isfinite(record.TruthCorrespondence.P95SeparationMeters), ...
                report.Runs)));
            recovered = cat(3, report.Runs.RecoveredCorrectionDegrees);
            testCase.verifyEqual(recovered(:, 2, :), ...
                zeros(3, 1, numel(report.Runs)), AbsTol=1e-12);
            testCase.verifyFalse(report.ThresholdsEstablished);
        end

        function testDenseEvidenceUsesMutuallyVisibleTruth(testCase)
            testCase.assumeTrue(exist("disparitySGM", "file") == 2);
            [~, run, navigation] = ...
                ProjectionDenseSurfaceSyntheticTestSupport.acceptanceFixture();
            options = ProjectionDenseSurfaceSyntheticAcceptanceTest.options(true);
            options.PresetIndices = 1;
            options.Modes = "pointing-only";

            report = ProjectionDenseSurfaceSyntheticAcceptance.run( ...
                navigation, run.Truth, ...
                ProjectionDenseSurfaceSyntheticAcceptanceTest.withImages( ...
                options, run.Images));
            dense = report.Runs.DenseSurface;

            testCase.verifyEqual(dense.Status, "succeeded");
            testCase.verifyGreaterThan(dense.ValidCount, 100);
            testCase.verifyGreaterThan(dense.MutuallyVisibleCount, 100);
            testCase.verifyGreaterThanOrEqual(dense.OcclusionExcludedCount, 0);
            testCase.verifyTrue(isfinite(dense.HeightRmsMeters));
            testCase.verifyTrue(isfinite(dense.HeightP95Meters));
            testCase.verifyTrue(isfinite(dense.RaySeparationP95Meters));
        end

        function testAcceptanceEvidenceIsDeterministic(testCase)
            [~, run, navigation] = ...
                ProjectionDenseSurfaceSyntheticTestSupport.acceptanceFixture();
            options = ProjectionDenseSurfaceSyntheticAcceptanceTest.options(false);
            options.PresetIndices = 1;
            options.Modes = "pointing-only";
            options = ProjectionDenseSurfaceSyntheticAcceptanceTest.withImages( ...
                options, run.Images);

            report = ProjectionDenseSurfaceSyntheticAcceptance.runRepeatable( ...
                navigation, run.Truth, options);

            testCase.verifyEqual(report.Repeatability.Status, "verified");
            testCase.verifyTrue(report.Repeatability.Exact);
            testCase.verifyGreaterThan( ...
                report.Repeatability.FirstRunRuntimeSeconds, 0);
            testCase.verifyGreaterThan( ...
                report.Repeatability.SecondRunRuntimeSeconds, 0);
        end

        function testWritesCompactEvidenceArtifacts(testCase)
            [~, run, navigation] = ...
                ProjectionDenseSurfaceSyntheticTestSupport.acceptanceFixture();
            outputDirectory = string(tempname);
            mkdir(outputDirectory);
            testCase.addTeardown(@() rmdir(outputDirectory, "s"));
            options = ProjectionDenseSurfaceSyntheticAcceptanceTest.options(false);
            options.PresetIndices = 1;
            options.Modes = "pointing-only";
            options.WriteArtifacts = true;
            options.OutputDirectory = outputDirectory;

            report = ProjectionDenseSurfaceSyntheticAcceptance.run( ...
                navigation, run.Truth, ...
                ProjectionDenseSurfaceSyntheticAcceptanceTest.withImages( ...
                options, run.Images));
            payload = load(report.Artifacts.ReportMatPath);
            jsonReport = jsondecode(fileread(report.Artifacts.ReportJsonPath));

            testCase.verifyTrue(isfile(report.Artifacts.ReportMatPath));
            testCase.verifyTrue(isfile(report.Artifacts.ReportJsonPath));
            testCase.verifyFalse(isfield(payload.report, "Images"));
            testCase.verifyFalse(isfield(payload.report, "Scene"));
            testCase.verifyEqual(string(jsonReport.Status), "complete");
            testCase.verifyEqual(string(jsonReport.ConfigurationFingerprint), ...
                report.ConfigurationFingerprint);
        end

        function testInvalidImagePayloadIsRejected(testCase)
            [~, run, navigation] = ...
                ProjectionDenseSurfaceSyntheticTestSupport.acceptanceFixture();
            invalidImages = run.Images;
            invalidImages{1} = invalidImages{1}(1:end-1, :);

            testCase.verifyError( ...
                @() ProjectionDenseSurfaceSyntheticAcceptance.buildScene( ...
                navigation, 1, "pointing-only", invalidImages), ...
                "ProjectionDenseSurfaceSyntheticAcceptance:invalidImages");
        end
    end

    methods (Static, Access = private)
        function options = options(runDense)
            options = struct(WorkingOutputSize=[128 128], ...
                DetectorMethod="sift", MaximumFeatures=1000, ...
                RunDense=logical(runDense), ...
                DenseOptions=struct(UniquenessThreshold=0, ...
                MaximumSurfacePoints=20000));
        end

        function options = withImages(options, images)
            options.Images = images;
        end
    end
end
