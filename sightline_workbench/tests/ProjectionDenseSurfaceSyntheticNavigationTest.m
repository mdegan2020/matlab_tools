classdef ProjectionDenseSurfaceSyntheticNavigationTest < matlab.unittest.TestCase
    %ProjectionDenseSurfaceSyntheticNavigationTest Tests reported error variants.

    methods (TestClassSetup)
        function addProjectPaths(testCase)
            projectRoot = fileparts(fileparts(mfilename("fullpath")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(projectRoot, "src")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(projectRoot, "tests")));
        end
    end

    methods (Test)
        function testErrorStatesAreDeterministicAndRngLocal(testCase)
            originalRng = rng;
            testCase.addTeardown(@() rng(originalRng));
            [config, run] = ...
                ProjectionDenseSurfaceSyntheticNavigationTest.fixtureRun();
            rng(43, "twister");
            expectedRandom = rand(1, 5);
            rng(43, "twister");

            first = ProjectionDenseSurfaceSyntheticNavigation.createFromResult( ...
                config, run);
            actualRandom = rand(1, 5);
            second = ProjectionDenseSurfaceSyntheticNavigation.createFromResult( ...
                config, run);

            testCase.verifyEqual(actualRandom, expectedRandom);
            testCase.verifyEqual(first.Presets(1).ErrorState, ...
                second.Presets(1).ErrorState);
            testCase.verifyEqual(first.Presets(2).ErrorState, ...
                second.Presets(2).ErrorState);
            testCase.verifyEqual( ...
                first.Presets(1).Variants(1).ConstantOpkDegrees, ...
                second.Presets(1).Variants(1).ConstantOpkDegrees);
        end

        function testNavigationGradeOrdersBelowTacticalGrade(testCase)
            [config, run] = ...
                ProjectionDenseSurfaceSyntheticNavigationTest.fixtureRun();

            bundle = ProjectionDenseSurfaceSyntheticNavigation.createFromResult( ...
                config, run);
            tactical = bundle.Presets(1).Statistics;
            navigation = bundle.Presets(2).Statistics;

            testCase.verifyEqual(bundle.Presets(1).Name, "Tactical Grade IMU");
            testCase.verifyEqual(bundle.Presets(2).Name, "Navigation Grade IMU");
            testCase.verifyLessThan(navigation.AttitudeRmsDegrees, ...
                tactical.AttitudeRmsDegrees);
            testCase.verifyLessThan( ...
                navigation.UnaidedVelocityStepRmsMetersPerSecond, ...
                tactical.UnaidedVelocityStepRmsMetersPerSecond);
            testCase.verifyLessThan(navigation.MaximumAttitudeDegrees, ...
                tactical.MaximumAttitudeDegrees);
        end

        function testOneSortieTimelineAndNominalGnssAidingAreExplicit(testCase)
            [config, run] = ...
                ProjectionDenseSurfaceSyntheticNavigationTest.fixtureRun();

            bundle = ProjectionDenseSurfaceSyntheticNavigation.createFromResult( ...
                config, run);
            tactical = bundle.Presets(1).ErrorState;
            navigation = bundle.Presets(2).ErrorState;
            viewTimes = [run.Truth.Views.CenterTimeSeconds];
            sampled = ProjectionDenseSurfaceSyntheticNavigation.sampleErrorState( ...
                tactical, viewTimes);

            testCase.verifyEqual(bundle.BiasDrawScope, "one-sortie");
            testCase.verifyEqual(bundle.AidingMode, "nominal-non-rtk-gnss");
            testCase.verifyEqual(tactical.TimesSeconds, navigation.TimesSeconds);
            testCase.verifySize(tactical.GyroBiasDrawDegreesPerHour, [3 1]);
            testCase.verifySize(tactical.AccelerometerBiasDrawMg, [3 1]);
            testCase.verifyGreaterThan(numel(tactical.AidingIndices), 1);
            testCase.verifyTrue(all(isfinite(sampled.PositionErrorMeters), "all"));
            testCase.verifyEqual(tactical.BiasDrawScope, "one-sortie");
        end

        function testPointingOnlyIsConstantWhileCombinedGeometryDrifts(testCase)
            [config, run] = ...
                ProjectionDenseSurfaceSyntheticNavigationTest.fixtureRun();
            bundle = ProjectionDenseSurfaceSyntheticNavigation.createFromResult( ...
                config, run);
            pointing = bundle.Presets(1).Variants(1).SourceGeometries{1};
            combined = bundle.Presets(1).Variants(2).SourceGeometries{1};
            row = 0.5 * (run.Truth.ImageSize(1) + 1);
            columns = [1 0.5 * (run.Truth.ImageSize(2) + 1) ...
                run.Truth.ImageSize(2)];

            [truthOrigins, truthVectors] = ...
                ProjectionDenseSurfaceSyntheticTruth.sampleRays( ...
                run.Truth, 1, row, columns);
            [pointingOrigins, pointingVectors] = ...
                pointing.SampleRayFcn(row, columns);
            [combinedOrigins, combinedVectors] = ...
                combined.SampleRayFcn(row, columns);
            pointingAngles = ...
                ProjectionDenseSurfaceSyntheticNavigationTest.angularErrors( ...
                truthVectors, pointingVectors);
            combinedAngles = ...
                ProjectionDenseSurfaceSyntheticNavigationTest.angularErrors( ...
                truthVectors, combinedVectors);

            testCase.verifyEqual(pointingOrigins, truthOrigins, AbsTol=1e-3);
            testCase.verifyGreaterThan(max(vecnorm( ...
                combinedOrigins - truthOrigins, 2, 1)), 0);
            testCase.verifyLessThan(std(pointingAngles), 1e-5);
            testCase.verifyGreaterThan(std(combinedAngles), std(pointingAngles));
            testCase.verifyGreaterThan(max(combinedAngles), 0);
        end

        function testGeometryVariantsImplementSamplingContracts(testCase)
            [config, run] = ...
                ProjectionDenseSurfaceSyntheticNavigationTest.fixtureRun();
            bundle = ProjectionDenseSurfaceSyntheticNavigation.createFromResult( ...
                config, run);
            geometry = bundle.Presets(2).Variants(2).SourceGeometries{2};

            [origins, vectors] = geometry.SampleFcn([1 17 33], [1 25 49]);
            [pairedOrigins, pairedVectors] = geometry.SampleRayFcn( ...
                [1.5 17.25 32.5], [2 24.75 48]);

            testCase.verifySize(origins, [3 3]);
            testCase.verifySize(vectors, [3 3 3]);
            testCase.verifySize(pairedOrigins, [3 3]);
            testCase.verifySize(pairedVectors, [3 3]);
            testCase.verifyEqual(squeeze(vecnorm(vectors, 2, 1)), ...
                ones(3, 3), AbsTol=1e-12);
            testCase.verifyEqual(vecnorm(pairedVectors, 2, 1), ...
                ones(1, 3), AbsTol=1e-12);
            testCase.verifyFalse(geometry.TruthIncluded);
            testCase.verifyEqual(geometry.CoordinateFrame, ...
                "reported-synthetic-navigation");
        end

        function testVariantsReferenceImagesWithoutPayloadOrTruthLeak(testCase)
            [config, run] = ...
                ProjectionDenseSurfaceSyntheticNavigationTest.fixtureRun();

            bundle = ProjectionDenseSurfaceSyntheticNavigation.createFromResult( ...
                config, run);
            geometry = bundle.Presets(1).Variants(1).SourceGeometries{1};
            details = functions(geometry.SampleFcn);
            workspace = details.workspace{1};

            testCase.verifyFalse(bundle.ImagesDuplicated);
            testCase.verifyFalse(isfield(bundle, "Images"));
            testCase.verifyFalse(isfield(bundle, "Image"));
            testCase.verifyFalse(isfield(bundle.Presets(1).Variants(1), "Images"));
            testCase.verifyFalse( ...
                ProjectionDenseSurfaceSyntheticNavigationTest.hasTruthPayload( ...
                workspace));
            testCase.verifyEqual(bundle.ImageReference.ImageSize, ...
                run.Summary.ImageSize);
            testCase.verifyEqual(bundle.ImageReference.ConfigurationFingerprint, ...
                run.Summary.ConfigurationFingerprint);
        end

        function testImagePayloadInReferenceIsRejected(testCase)
            [config, run] = ...
                ProjectionDenseSurfaceSyntheticNavigationTest.fixtureRun();
            reference = struct(ConfigurationFingerprint="public", ImagePaths="", ...
                ImageSize=run.Truth.ImageSize, ImageClass="uint8", ...
                Images={run.Images(1)});

            testCase.verifyError( ...
                @() ProjectionDenseSurfaceSyntheticNavigation.create( ...
                config, run.Truth, reference), ...
                "ProjectionDenseSurfaceSyntheticNavigation:invalidImageReference");
        end

        function testWritesCompactImageFreeVariantArtifacts(testCase)
            [config, run] = ...
                ProjectionDenseSurfaceSyntheticNavigationTest.fixtureRun();
            bundle = ProjectionDenseSurfaceSyntheticNavigation.createFromResult( ...
                config, run);
            outputDirectory = string(tempname);
            mkdir(outputDirectory);
            testCase.addTeardown(@() rmdir(outputDirectory, "s"));

            artifacts = ProjectionDenseSurfaceSyntheticNavigation.writeArtifacts( ...
                bundle, outputDirectory);
            payload = load(artifacts.VariantsMatPath);
            summary = jsondecode(fileread(artifacts.SummaryJsonPath));
            loadedGeometry = ...
                payload.bundle.Presets(1).Variants(1).SourceGeometries{1};
            [loadedOrigins, loadedVectors] = ...
                loadedGeometry.SampleFcn([1 17 33], [1 25 49]);

            testCase.verifyTrue(isfile(artifacts.VariantsMatPath));
            testCase.verifyTrue(isfile(artifacts.SummaryJsonPath));
            testCase.verifyFalse(isfield(payload.bundle, "Images"));
            testCase.verifyFalse(payload.bundle.ImagesDuplicated);
            testCase.verifyFalse(summary.ImagesDuplicated);
            testCase.verifyEqual(numel(summary.Presets), 2);
            testCase.verifySize(loadedOrigins, [3 3]);
            testCase.verifySize(loadedVectors, [3 3 3]);
        end
    end

    methods (Static, Access = private)
        function [config, run] = fixtureRun()
            [config, plan, sourceImage] = ...
                ProjectionDenseSurfaceSyntheticTestSupport.generatorFixture();
            run = ProjectionDenseSurfaceSyntheticGenerator.generate( ...
                config, plan, sourceImage, struct(WriteFiles=false));
        end

        function angles = angularErrors(first, second)
            cosines = sum(first .* second, 1);
            angles = real(acosd(max(-1, min(1, cosines))));
        end

        function tf = hasTruthPayload(value)
            tf = false;
            if isstruct(value)
                names = string(fieldnames(value));
                forbidden = ["Truth" "Terrain" "Images" "Image"];
                if any(ismember(names, forbidden))
                    tf = true;
                    return
                end
                for elementIndex = 1:numel(value)
                    for fieldIndex = 1:numel(names)
                        tf = tf || ...
                            ProjectionDenseSurfaceSyntheticNavigationTest. ...
                            hasTruthPayload(value(elementIndex).(names(fieldIndex)));
                    end
                end
                return
            end
            if iscell(value)
                tf = any(cellfun( ...
                    @ProjectionDenseSurfaceSyntheticNavigationTest.hasTruthPayload, ...
                    value));
            end
        end
    end
end
