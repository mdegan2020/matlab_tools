classdef ProjectionPairViewpointTest < matlab.unittest.TestCase
    %ProjectionPairViewpointTest Tests presentation-only pair camera plans.

    methods (TestClassSetup)
        function addSourceToPath(testCase)
            projectRoot = fileparts(fileparts(mfilename("fullpath")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(projectRoot, "src")));
        end
    end

    methods (Test)
        function testMidpointCameraUsesSharedOverlapOrigins(testCase)
            [scene, pair] = ProjectionPairViewpointTest.sceneAndPair();

            result = ProjectionPairViewpoint.compute(scene, pair, ...
                struct(AspectRatio=4 / 3));

            testCase.verifyTrue(result.Available);
            testCase.verifyEqual(result.OriginModes, ...
                ["sharedOverlap" "sharedOverlap"]);
            testCase.verifyEqual(result.Camera.PositionWorld, ...
                mean(result.RepresentativeOrigins, 2), AbsTol=1e-10);
            expectedTarget = PlanarProjection.reconstruct3d( ...
                result.OverlapCentroidPlaneCoordinates, ...
                scene.layers(1).CurrentProjectionPlane);
            testCase.verifyEqual(result.Camera.TargetWorld, ...
                expectedTarget, AbsTol=1e-10);
            viewDirection = result.Camera.TargetWorld - ...
                result.Camera.PositionWorld;
            viewDirection = viewDirection / norm(viewDirection);
            testCase.verifyEqual(result.Camera.UpVector.' * viewDirection, ...
                0, AbsTol=1e-12);
            testCase.verifyGreaterThan(result.OverlapArea, 0);
            testCase.verifyGreaterThan(result.Camera.ViewAngle, 0);
        end

        function testMissingContinuousSamplerUsesReferenceOrigin(testCase)
            [scene, pair] = ProjectionPairViewpointTest.sceneAndPair();
            scene.layers(1).SourceGeometry = rmfield( ...
                scene.layers(1).SourceGeometry, "SampleRayFcn");

            result = ProjectionPairViewpoint.compute(scene, pair);

            testCase.verifyTrue(result.Available);
            testCase.verifyEqual(result.OriginModes(1), ...
                "referenceOriginFallback");
            testCase.verifyEqual(result.RepresentativeOrigins(:, 1), ...
                scene.layers(1).SourceGeometry.ReferenceOrigin, ...
                AbsTol=1e-12);
        end

        function testNoOverlapReturnsExplanation(testCase)
            [scene, pair] = ProjectionPairViewpointTest.sceneAndPair();
            scene.layers(2).ProjectionOffsetMeters = [1e6; 0];

            result = ProjectionPairViewpoint.compute(scene, pair);

            testCase.verifyFalse(result.Available);
            testCase.verifyNotEmpty(result.Explanation);
            testCase.verifySubstring(result.Explanation, "no usable shared");
        end

        function testComputationDoesNotMutateScientificScene(testCase)
            [scene, pair] = ProjectionPairViewpointTest.sceneAndPair();
            original = scene;

            ProjectionPairViewpoint.compute(scene, pair);

            testCase.verifyEqual(scene, original);
        end
    end

    methods (Static, Access = private)
        function [scene, pair] = sceneAndPair()
            images = {uint8(reshape(1:480, 20, 24)), ...
                uint8(reshape(2:481, 20, 24))};
            paths = ["pair-view-a.tif" "pair-view-b.tif"];
            scene = ProjectionViewerHarness.createSceneFromImages( ...
                images, paths, struct(RowStride=4, ColumnStride=4));
            scene.layers(1).ViewId = "pair-view-a";
            scene.layers(2).ViewId = "pair-view-b";
            scene = ProjectionViewMetadata.ensureScene(scene);
            controller = ProjectionPairController(scene);
            pair = controller.currentPair();
        end
    end
end
