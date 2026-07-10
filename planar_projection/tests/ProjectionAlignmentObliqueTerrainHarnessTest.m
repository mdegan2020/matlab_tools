classdef ProjectionAlignmentObliqueTerrainHarnessTest < matlab.unittest.TestCase
    %ProjectionAlignmentObliqueTerrainHarnessTest Oblique stereo fixture tests.

    properties (Constant)
        Tol = 1e-8
    end

    methods (TestClassSetup)
        function addSourceToPath(testCase)
            projectRoot = fileparts(fileparts(mfilename("fullpath")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(projectRoot, "src")));
        end
    end

    methods (Test)
        function testTrajectoryGeometryMatchesRequestedStereo(testCase)
            rgbImage = ...
                ProjectionAlignmentObliqueTerrainHarnessTest.texturedRgbImage();

            [scene, truth] = ProjectionAlignmentObliqueTerrainHarness.createScene( ...
                rgbImage, struct(SensorImageSize=[96 104], MeshStride=8));
            trajectories = truth.Trajectories;
            centers = reshape([trajectories.Center], 3, []);
            viewDirections = -centers ./ vecnorm(centers);
            offNadir = acosd([0 0 -1] * viewDirections);

            testCase.verifyEqual(vecnorm(centers), [10000 10000], ...
                AbsTol=ProjectionAlignmentObliqueTerrainHarnessTest.Tol);
            testCase.verifyEqual(offNadir, [65 65], ...
                AbsTol=ProjectionAlignmentObliqueTerrainHarnessTest.Tol);
            testCase.verifyEqual(diff([trajectories.AzimuthDegrees]), 3, ...
                AbsTol=ProjectionAlignmentObliqueTerrainHarnessTest.Tol);
            testCase.verifyEqual([trajectories.ElevationDegrees], [25 25], ...
                AbsTol=ProjectionAlignmentObliqueTerrainHarnessTest.Tol);
            testCase.verifyEqual(scene.Simulation.AzimuthSeparationDegrees, 3, ...
                AbsTol=ProjectionAlignmentObliqueTerrainHarnessTest.Tol);
            testCase.verifyFalse(scene.Simulation.DemIsBackendInput);
        end

        function testDrapeUsesRedAndBlueBandsOnBoundedDem(testCase)
            rgbImage = zeros(80, 84, 3, "uint8");
            rgbImage(:, :, 1) = 25;
            rgbImage(:, :, 2) = 117;
            rgbImage(:, :, 3) = 200;

            [scene, truth] = ProjectionAlignmentObliqueTerrainHarness.createScene( ...
                rgbImage, struct(SensorImageSize=[72 76], MeshStride=8));

            testCase.verifyEqual(scene.layers(1).Image, ...
                25 * ones(72, 76, "uint8"));
            testCase.verifyEqual(scene.layers(2).Image, ...
                200 * ones(72, 76, "uint8"));
            testCase.verifyGreaterThan(min(truth.DemZ, [], "all"), -50.01);
            testCase.verifyLessThan(min(truth.DemZ, [], "all"), -45);
            testCase.verifyEqual(double(max(truth.DemZ, [], "all")), ...
                50, AbsTol=0.01);
            testCase.verifyGreaterThan([truth.SensorViews.ValidFraction], ...
                [0.99 0.99]);
        end

        function testSourceGeometrySupportsGridAndObservationSampling(testCase)
            rgbImage = ...
                ProjectionAlignmentObliqueTerrainHarnessTest.texturedRgbImage();
            [scene, ~] = ProjectionAlignmentObliqueTerrainHarness.createScene( ...
                rgbImage, struct(SensorImageSize=[64 68], MeshStride=8));
            geometry = scene.layers(1).SourceGeometry;

            [origins, vectors] = geometry.SampleFcn([1 32 64], [1 34 68]);
            [rayOrigins, rayVectors] = geometry.SampleRayFcn( ...
                [1 32 64], [1 34 68]);
            mesh = ProjectionMeshBuilder.buildLayerMesh( ...
                scene.layers(1), scene.layers(1).CurrentProjectionPlane, ...
                scene.renderOrigin);

            testCase.verifySize(origins, [3 3]);
            testCase.verifySize(vectors, [3 3 3]);
            testCase.verifySize(rayOrigins, [3 3]);
            testCase.verifySize(rayVectors, [3 3]);
            testCase.verifyGreaterThan(norm(origins(:, 3) - origins(:, 1)), 0);
            testCase.verifyEqual(squeeze(vectors(:, 1, 1)), rayVectors(:, 1), ...
                AbsTol=ProjectionAlignmentObliqueTerrainHarnessTest.Tol);
            testCase.verifyTrue(all(isfinite(mesh.WorldPoints), "all"));
            testCase.verifyTrue(all(mesh.Ranges > 0, "all"));
        end

        function testSimulationIsDeterministic(testCase)
            rgbImage = ...
                ProjectionAlignmentObliqueTerrainHarnessTest.texturedRgbImage();
            options = struct(SensorImageSize=[80 88], MeshStride=8);

            [firstScene, firstTruth] = ...
                ProjectionAlignmentObliqueTerrainHarness.createScene( ...
                rgbImage, options);
            [secondScene, secondTruth] = ...
                ProjectionAlignmentObliqueTerrainHarness.createScene( ...
                rgbImage, options);

            testCase.verifyEqual(firstScene.layers(1).Image, ...
                secondScene.layers(1).Image);
            testCase.verifyEqual(firstScene.layers(2).Image, ...
                secondScene.layers(2).Image);
            testCase.verifyEqual(firstTruth.SensorViews(1).GroundX, ...
                secondTruth.SensorViews(1).GroundX);
            testCase.verifyEqual(firstTruth.SensorViews(2).GroundZ, ...
                secondTruth.SensorViews(2).GroundZ);
        end

        function testComparisonReportsTerrainTruthSeparation(testCase)
            rgbImage = ...
                ProjectionAlignmentObliqueTerrainHarnessTest.texturedRgbImage();
            [scene, truth] = ProjectionAlignmentObliqueTerrainHarness.createScene( ...
                rgbImage, struct(SensorImageSize=[128 128], MeshStride=8));
            alignmentOptions = ProjectionAlignmentOptions.validate(struct( ...
                Detector=struct(Method="sift", MaxFeatures=300, ...
                MaskSupportRadiusPixels=0), ...
                Matcher=struct(MaxRatio=0.95), ...
                FilterPipeline=struct(GeometricMethod="none")));
            request = ProjectionAlignmentRequest.validate(struct(Scene=scene, ...
                LayerIndices=[2 1], ReferenceLayerIndex=1, ...
                AnalysisBands=[1 1], Options=alignmentOptions));
            comparison = ProjectionAlignmentWorkingImageComparison.evaluate( ...
                scene, request, struct(RenderOptions=struct( ...
                OutputSize=[128 128]), RunSolve=true));

            comparison = ...
                ProjectionAlignmentObliqueTerrainHarness.addTruthDiagnostics( ...
                comparison, truth);
            sparseTruth = comparison.Summary.Modes(1).TerrainTruth.Raw;
            fullTruth = comparison.Summary.Modes(2).TerrainTruth.Raw;

            testCase.verifyGreaterThan(sparseTruth.Count, 0);
            testCase.verifyGreaterThan(fullTruth.Count, 0);
            testCase.verifyEqual(sparseTruth.ValidTruthCount, sparseTruth.Count);
            testCase.verifyEqual(fullTruth.ValidTruthCount, fullTruth.Count);
            testCase.verifyTrue(isfinite(sparseTruth.MedianSeparationMeters));
            testCase.verifyTrue(isfinite(fullTruth.P95SeparationMeters));
            fullSolve = comparison.Summary.Modes(2).Solve;
            testCase.verifyTrue(fullSolve.Attempted);
            testCase.verifyEqual(fullSolve.Status, "solved");
            testCase.verifyTrue(isfinite(fullSolve.RmsBefore));
            testCase.verifyTrue(isfinite(fullSolve.CorrectionNormDegrees));
        end
    end

    methods (Static, Access = private)
        function rgbImage = texturedRgbImage()
            [x, y] = meshgrid(1:160, 1:144);
            texture = uint8(mod(3 * x + 5 * y + ...
                40 * sin(x / 3) + 30 * cos(y / 5), 256));
            rgbImage = cat(3, texture, uint8(255 - texture), texture);
        end
    end
end
