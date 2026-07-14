classdef ProjectionStereoCursorModelTest < matlab.unittest.TestCase
    %ProjectionStereoCursorModelTest Tests RD-6 physical cursor geometry.

    properties (Constant)
        Tol = 1e-6
    end

    methods (TestClassSetup)
        function addPaths(testCase)
            root = fileparts(fileparts(mfilename("fullpath")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(root));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(root, "src")));
        end
    end

    methods (Test)
        function testSignedHeightUsesDeclaredPlaneNormalForObliquePlane(testCase)
            scene = ProjectionStereoCursorModelTest.scene(2);
            base = scene.layers(1).CurrentProjectionPlane;
            plane = ProjectionMeshBuilder.applyPlaneTipTilt( ...
                base, deg2rad(11), deg2rad(-8));
            anchor = [1.25; -2.5];
            planePoint = PlanarProjection.reconstruct3d(anchor, plane);

            zero = ProjectionStereoCursorModel.worldPoint(plane, anchor, 0);
            positive = ProjectionStereoCursorModel.worldPoint(plane, anchor, 17);
            negative = ProjectionStereoCursorModel.worldPoint(plane, anchor, -9);

            testCase.verifyEqual(zero, planePoint, ...
                AbsTol=ProjectionStereoCursorModelTest.Tol);
            testCase.verifyEqual(dot(positive - planePoint, plane.VN), 17, ...
                AbsTol=ProjectionStereoCursorModelTest.Tol);
            testCase.verifyEqual(dot(negative - planePoint, plane.VN), -9, ...
                AbsTol=ProjectionStereoCursorModelTest.Tol);
        end

        function testPlaneZeroCoincidesAndSignedDisparityReverses(testCase)
            scene = ProjectionStereoCursorModelTest.scene(2);
            plane = scene.layers(1).CurrentProjectionPlane;
            viewIds = ProjectionViewMetadata.ids(scene);

            zero = ProjectionStereoCursorModel.projectPair(scene, viewIds, ...
                ProjectionStereoCursorModel.worldPoint(plane, [0; 0], 0), plane);
            positive = ProjectionStereoCursorModel.projectPair(scene, viewIds, ...
                ProjectionStereoCursorModel.worldPoint(plane, [0; 0], 20), plane);
            negative = ProjectionStereoCursorModel.projectPair(scene, viewIds, ...
                ProjectionStereoCursorModel.worldPoint(plane, [0; 0], -20), plane);
            zeroDelta = zero.Projections(2).PlaneCoordinates - ...
                zero.Projections(1).PlaneCoordinates;
            positiveDelta = positive.Projections(2).PlaneCoordinates - ...
                positive.Projections(1).PlaneCoordinates;
            negativeDelta = negative.Projections(2).PlaneCoordinates - ...
                negative.Projections(1).PlaneCoordinates;

            testCase.verifyEqual(zero.ValidCount, 2);
            testCase.verifyEqual(zeroDelta, [0 0], ...
                AbsTol=ProjectionStereoCursorModelTest.Tol);
            testCase.verifyGreaterThan(norm(positiveDelta), 0);
            testCase.verifyEqual(negativeDelta, -positiveDelta, ...
                AbsTol=1e-5);
        end

        function testStableViewProjectionIgnoresRoleAndLayerOrder(testCase)
            scene = ProjectionStereoCursorModelTest.scene(2);
            plane = scene.layers(1).CurrentProjectionPlane;
            viewIds = ProjectionViewMetadata.ids(scene);
            point = ProjectionStereoCursorModel.worldPoint(plane, [0; 0], 8);

            forward = ProjectionStereoCursorModel.projectPair( ...
                scene, viewIds, point, plane);
            reversed = ProjectionStereoCursorModel.projectPair( ...
                scene, fliplr(viewIds), point, plane);
            reorderedScene = scene;
            reorderedScene.layers = fliplr(reorderedScene.layers);
            reordered = ProjectionStereoCursorModel.projectPair( ...
                reorderedScene, viewIds, point, plane);

            testCase.verifyEqual(reversed.PairId, forward.PairId);
            testCase.verifyEqual(reordered.PairId, forward.PairId);
            for viewId = viewIds
                expected = ProjectionStereoCursorModelTest.forView( ...
                    forward, viewId);
                reversedView = ProjectionStereoCursorModelTest.forView( ...
                    reversed, viewId);
                reorderedView = ProjectionStereoCursorModelTest.forView( ...
                    reordered, viewId);
                testCase.verifyEqual(reversedView.SourceCoordinates, ...
                    expected.SourceCoordinates, AbsTol=1e-8);
                testCase.verifyEqual(reorderedView.SourceCoordinates, ...
                    expected.SourceCoordinates, AbsTol=1e-8);
            end
        end

        function testInvalidProjectionStatesAreExplicit(testCase)
            scene = ProjectionStereoCursorModelTest.scene(2);
            plane = scene.layers(1).CurrentProjectionPlane;
            viewIds = ProjectionViewMetadata.ids(scene);
            outsidePoint = ProjectionStereoCursorModel.worldPoint( ...
                plane, [1e6; 0], 0);
            outside = ProjectionStereoCursorModel.projectPair( ...
                scene, viewIds, outsidePoint, plane);
            behindPoint = scene.layers(1).SourceGeometry.ReferenceOrigin - ...
                100 * scene.layers(1).SourceGeometry.OpticalAxis;
            behind = ProjectionStereoCursorModel.projectPair( ...
                scene, viewIds, behindPoint, plane);
            scene.layers(1).SourceGeometry.SampleRayFcn = [];
            unsupported = ProjectionStereoCursorModel.projectPair( ...
                scene, viewIds, ...
                ProjectionStereoCursorModel.worldPoint(plane, [0; 0], 0), plane);

            testCase.verifyEqual(outside.ValidCount, 0);
            testCase.verifyEqual(string({outside.Projections.Status}), ...
                ["outsideSourceFootprint" "outsideSourceFootprint"]);
            testCase.verifyEqual(string({behind.Projections.Status}), ...
                ["behindSource" "behindSource"]);
            testCase.verifyEqual(unsupported.Projections(1).Status, ...
                "unsupportedSourceGeometry");
            testCase.verifyFalse(unsupported.Projections(1).Valid);
        end
    end

    methods (Static, Access = private)
        function scene = scene(count)
            images = arrayfun(@(index) ...
                uint8(index * ones(32, 40)), 1:count, UniformOutput=false);
            paths = "cursor-" + string(1:count) + ".tif";
            scene = ProjectionViewerHarness.createSceneFromImages( ...
                images, paths, struct(RowStride=4, ColumnStride=4));
            for index = 1:count
                scene.layers(index).ViewId = "cursor-view-" + index;
                scene.layers(index).PassId = "cursor-pass";
            end
            scene = ProjectionViewMetadata.ensureScene(scene);
        end

        function projection = forView(result, viewId)
            index = find(string({result.Projections.ViewId}) == viewId, ...
                1, "first");
            projection = result.Projections(index);
        end
    end
end
