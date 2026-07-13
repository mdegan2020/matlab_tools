classdef ProjectionSurfaceFusionSdkTest < matlab.unittest.TestCase
    %ProjectionSurfaceFusionSdkTest S6/B4 SDK and built-in fusion tests.

    methods (TestClassSetup)
        function addPaths(testCase)
            root = fileparts(fileparts(mfilename("fullpath")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(root, "src")));
        end
    end

    methods (Test)
        function testRequestDerivesGsdAndUncertaintyScaleSweeps(testCase)
            request = ProjectionSurfaceFusionFixture.request();
            gsdRequest = ProjectionSurfaceFusionRequest.validate(request);
            uncertaintyRequest = request;
            uncertaintyRequest.GsdMeters = [];
            uncertaintyRequest = ProjectionSurfaceFusionRequest. ...
                validate(uncertaintyRequest);

            testCase.verifyEqual(gsdRequest.VoxelScalesMeters, [0.25 0.5 1]);
            testCase.verifyEqual(gsdRequest.BaseVoxelScaleMeters, 0.5);
            testCase.verifyEqual(gsdRequest.VoxelScaleSource, "gsd");
            testCase.verifyEqual(uncertaintyRequest.VoxelScalesMeters, ...
                [0.15 0.3 0.6], AbsTol=1e-14);
            testCase.verifyEqual(uncertaintyRequest.VoxelScaleSource, ...
                "pointUncertainty");
        end

        function testRequestStrictSchemaForbidsTruthAndRuntimeHooks(testCase)
            request = ProjectionSurfaceFusionFixture.request();
            truthRequest = request;
            truthRequest.Truth = struct();
            callbackRequest = request;
            callbackRequest.ProgressFcn = @(~) [];
            futureRequest = request;
            futureRequest.Version = 2;
            handleRequest = request;
            handleRequest.Context = struct(Probe= ...
                ProjectionSurfaceFusionProgressProbe());
            covarianceRequest = request;
            covarianceRequest.PointSet.Points(1). ...
                CovarianceWorldMetersSquared = diag([1 1 -1]);

            testCase.verifyError(@() ...
                ProjectionSurfaceFusionRequest.validate(truthRequest), ...
                "ProjectionSurfaceFusionRequest:forbiddenData");
            testCase.verifyError(@() ...
                ProjectionSurfaceFusionRequest.validate(callbackRequest), ...
                "ProjectionSurfaceFusionRequest:forbiddenData");
            testCase.verifyError(@() ...
                ProjectionSurfaceFusionRequest.validate(futureRequest), ...
                "ProjectionSurfaceFusionRequest:unsupportedSchema");
            testCase.verifyError(@() ...
                ProjectionSurfaceFusionRequest.validate(handleRequest), ...
                "ProjectionSurfaceFusionRequest:invalidContext");
            testCase.verifyError(@() ...
                ProjectionSurfaceFusionRequest.validate(covarianceRequest), ...
                "ProjectionSurfaceFusionRequest:invalidPointSet");
        end

        function testLifecycleReportsProgressCancellationAndFailure(testCase)
            request = ProjectionSurfaceFusionFixture.request();
            probe = ProjectionSurfaceFusionProgressProbe();
            algorithm = ProjectionHardVoxelFusion();
            result = algorithm.fuse(request, algorithm.defaultOptions(), ...
                struct(ProgressFcn=@(update) probe.record(update)));
            cancelling = struct(CancellationFcn=@() true);

            testCase.verifyEqual(probe.Stages(1), "starting");
            testCase.verifyEqual(probe.Stages(end), "completed");
            testCase.verifyEqual(probe.Fractions([1 end]), [0 1]);
            testCase.verifyGreaterThanOrEqual(result.Timing.TotalSeconds, 0);
            testCase.verifyError(@() algorithm.fuse(request, struct(), cancelling), ...
                "ProjectionSurfaceFusionAlgorithm:cancelled");
            testCase.verifyError(@() ProjectionSurfaceFusionTestAlgorithm(). ...
                fuse(request), ...
                "ProjectionSurfaceFusionAlgorithm:algorithmFailure");
        end

        function testRegistryIsExplicitAndExampleConforms(testCase)
            registry = ProjectionSurfaceFusionRegistry({ ...
                ProjectionRobustMultiRayFusion(), ...
                ProjectionHardVoxelFusion(), ProjectionGaussianSplatFusion(), ...
                ProjectionExampleSurfaceFusion()});
            example = registry.resolve("example.mode-centroid");
            result = example.fuse(ProjectionSurfaceFusionFixture.request());

            testCase.verifyEqual(registry.list(), [ ...
                "sightline.fusion.robust-multi-ray" ...
                "sightline.fusion.hard-voxel" ...
                "sightline.fusion.gaussian-splat" ...
                "example.mode-centroid"]);
            testCase.verifyEqual(result.ProductRole, "exampleOnly");
            testCase.verifyEqual(result.CompetingModes.ModeCount, 2);
            testCase.verifyNumElements(result.FusedPoints, 2);
            testCase.verifyError(@() registry.resolve("unregistered.class"), ...
                "ProjectionSurfaceFusionRegistry:unknownAlgorithm");
        end

        function testRobustAdapterPreservesAuthoritativePoints(testCase)
            request = ProjectionSurfaceFusionFixture.request();
            result = ProjectionRobustMultiRayFusion().fuse(request);
            input = request.PointSet.Points;

            testCase.verifyEqual(string({result.FusedPoints.PointId}), ...
                string({input.PointId}));
            testCase.verifyEqual( ...
                ProjectionSurfaceFusionFixture.fusedCoordinates(result), ...
                horzcat(input.PointWorld));
            testCase.verifyEqual(result.ProductRole, "authoritativeReference");
            testCase.verifyFalse(result.Diagnostics.PointSetRecomputed);
            testCase.verifyTrue(isempty(fieldnames(result.SparseVoxelEvidence)));
        end

        function testHardVoxelPreservesModesAndIndependentContributors(testCase)
            request = ProjectionSurfaceFusionFixture.request();
            result = ProjectionHardVoxelFusion().fuse(request);
            baseScale = result.SparseVoxelEvidence.ScaleResults(2);

            testCase.verifyEqual(result.SparseVoxelEvidence.Method, ...
                "hardOccupancy");
            testCase.verifyNumElements(result.SparseVoxelEvidence.ScaleResults, 3);
            testCase.verifyEqual(sort(string({baseScale.Modes.ModeId})), ...
                ["parapet" "roof"]);
            testCase.verifyEqual( ...
                ProjectionSurfaceFusionFixture.totalEvidence(baseScale), 16);
            testCase.verifyEqual(result.Contributors.IndependentPassIds, ...
                ["pass-1" "pass-2"]);
            testCase.verifyFalse(result.Diagnostics.PairMultiplicityUsed);
            testCase.verifyEqual(sort(unique( ...
                ProjectionSurfaceFusionFixture.fusedModes(result))), ...
                ["parapet" "roof"]);
        end

        function testGaussianSplatIsNormalizedDeterministicAndBounded(testCase)
            request = ProjectionSurfaceFusionFixture.request();
            algorithm = ProjectionGaussianSplatFusion();
            first = algorithm.fuse(request);
            second = algorithm.fuse(request);
            baseScale = first.SparseVoxelEvidence.ScaleResults(2);

            testCase.verifyEqual(first.SparseVoxelEvidence.Method, ...
                "gaussianSplat");
            testCase.verifyEqual( ...
                ProjectionSurfaceFusionFixture.totalEvidence(baseScale), 16, ...
                AbsTol=1e-12);
            testCase.verifyEqual(first.SparseVoxelEvidence, ...
                second.SparseVoxelEvidence);
            testCase.verifyEqual( ...
                ProjectionSurfaceFusionFixture.fusedCoordinates(first), ...
                ProjectionSurfaceFusionFixture.fusedCoordinates(second));
            testCase.verifyGreaterThan(first.Memory.Bytes, 0);
            testCase.verifyEqual(first.Execution.Device, "cpu");
        end

        function testPairMultiplicityCannotChangeVoxelEvidence(testCase)
            baseline = ProjectionSurfaceFusionFixture.request();
            duplicate = ProjectionSurfaceFusionFixture.duplicatePairCountRequest();
            hard = ProjectionHardVoxelFusion();
            gaussian = ProjectionGaussianSplatFusion();
            baselineHard = hard.fuse(baseline);
            duplicateHard = hard.fuse(duplicate);
            baselineGaussian = gaussian.fuse(baseline);
            duplicateGaussian = gaussian.fuse(duplicate);

            testCase.verifyEqual(duplicateHard.SparseVoxelEvidence, ...
                baselineHard.SparseVoxelEvidence);
            testCase.verifyEqual(duplicateGaussian.SparseVoxelEvidence, ...
                baselineGaussian.SparseVoxelEvidence);
            testCase.verifyEqual( ...
                ProjectionSurfaceFusionFixture.fusedCoordinates(duplicateHard), ...
                ProjectionSurfaceFusionFixture.fusedCoordinates(baselineHard));
        end

        function testSingleEvidenceKeepsGeometryAndFinalPointsDouble(testCase)
            request = ProjectionSurfaceFusionFixture.request();
            request.PrecisionPolicy = struct(Geometry="double", ...
                Evidence="single", Final="double");
            result = ProjectionGaussianSplatFusion().fuse(request);
            classes = ProjectionSurfaceFusionFixture.evidenceClasses( ...
                result.SparseVoxelEvidence.ScaleResults(2));

            testCase.verifyEqual(classes, ["single" "single"]);
            testCase.verifyClass(result.FusedPoints(1).PointWorld, "double");
            testCase.verifyClass(result.FusedPoints(1). ...
                CovarianceWorldMetersSquared, "double");
            testCase.verifyEqual(result.Precision.Evidence, "single");
        end

        function testLimitsAndMalformedResultsFailClosed(testCase)
            request = ProjectionSurfaceFusionFixture.request();
            normalized = ProjectionSurfaceFusionRequest.validate(request);
            metadata = ProjectionHardVoxelFusion().metadata();
            truthResult = struct(Truth=struct());
            tinyGrid = struct(MaximumGridCells=1);
            tinyContribution = struct(MaximumContributions=1);
            robustAlgorithm = ProjectionRobustMultiRayFusion();
            malformedPointResult = robustAlgorithm.fuse(request);
            malformedPointResult.FusedPoints(1). ...
                CovarianceWorldMetersSquared = diag([1 1 -1]);

            testCase.verifyError(@() ProjectionSurfaceFusionResult.validate( ...
                truthResult, normalized, metadata), ...
                "ProjectionSurfaceFusionResult:forbiddenData");
            testCase.verifyError(@() ProjectionHardVoxelFusion().fuse( ...
                request, tinyGrid), ...
                "ProjectionSurfaceFusionAlgorithm:algorithmFailure");
            testCase.verifyError(@() ProjectionGaussianSplatFusion().fuse( ...
                request, tinyContribution), ...
                "ProjectionSurfaceFusionAlgorithm:algorithmFailure");
            testCase.verifyError(@() ProjectionSurfaceFusionResult.validate( ...
                malformedPointResult, normalized, robustAlgorithm.metadata()), ...
                "ProjectionSurfaceFusionResult:invalidPoints");
        end

        function testMatAndCompactJsonPersistence(testCase)
            folder = string(tempname);
            mkdir(folder);
            testCase.addTeardown(@() rmdir(folder, "s"));
            result = ProjectionGaussianSplatFusion().fuse( ...
                ProjectionSurfaceFusionFixture.request());
            paths = ProjectionSurfaceFusionResult.write(result, ...
                fullfile(folder, "fusion.mat"), ...
                fullfile(folder, "fusion.json"));
            payload = load(paths.MatPath, "fusionResult");
            metadata = jsondecode(fileread(paths.MetadataPath));

            testCase.verifyEqual(payload.fusionResult.AlgorithmId, ...
                result.AlgorithmId);
            testCase.verifyEqual(string(metadata.AlgorithmId), ...
                result.AlgorithmId);
            testCase.verifyNumElements(metadata.VoxelScaleSummaries, 3);
            testCase.verifyFalse(isfield(metadata, "SparseVoxelEvidence"));
            testCase.verifyFalse(isfield(metadata, "FusedPoints"));
        end
    end
end
