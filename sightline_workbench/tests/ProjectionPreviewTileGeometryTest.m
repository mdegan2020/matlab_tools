classdef ProjectionPreviewTileGeometryTest < matlab.unittest.TestCase
    %ProjectionPreviewTileGeometryTest Tests cached tile footprint geometry.

    methods (TestClassSetup)
        function addSourceToPath(testCase)
            projectRoot = fileparts(fileparts(mfilename("fullpath")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(projectRoot, "src")));
        end
    end

    methods (Test)
        function testBuildSamplesOneSharedGridPerLevel(testCase)
            scene = ProjectionPreviewTileGeometryTest.makeScene();
            layer = scene.layers;
            pyramid = ProjectionPreviewPyramid.build( ...
                layer.Image, struct(TileSize=4));

            cache = ProjectionPreviewTileGeometry.build( ...
                layer, pyramid, layer.CurrentProjectionPlane, ...
                scene.renderOrigin, 4);

            testCase.verifyEqual(cache.MeshBuildCount, numel(pyramid.Levels));
            testCase.verifyEqual(numel(cache.Levels(1).Tiles), 9);
            testCase.verifySize(cache.Levels(1).RenderCorners, [3 4 9]);
            testCase.verifyGreaterThan(size(cache.LayerRenderPoints, 2), 4);
        end

        function testVectorizedVisibilityMatchesScalarReference(testCase)
            scene = ProjectionPreviewTileGeometryTest.makeScene();
            layer = scene.layers;
            pyramid = ProjectionPreviewPyramid.build( ...
                layer.Image, struct(TileSize=4));
            cache = ProjectionPreviewTileGeometry.build( ...
                layer, pyramid, layer.CurrentProjectionPlane, ...
                scene.renderOrigin, 4);
            context = ProjectionPreviewTileGeometryTest.cameraContext( ...
                cache, layer.CurrentProjectionPlane);

            [actualMask, diagnostics] = ...
                ProjectionPreviewTileGeometry.visibleMask(cache, 1, context);
            expectedMask = ProjectionPreviewTileGeometryTest.scalarVisibleMask( ...
                cache.Levels(1).RenderCorners, context);

            testCase.verifyEqual(actualMask, expectedMask);
            testCase.verifyEqual(diagnostics.CandidateCount, 9);
            testCase.verifyEqual(diagnostics.VisibleCount, nnz(expectedMask));
            testCase.verifyGreaterThan(diagnostics.VisibleCount, 0);
            testCase.verifyLessThan(diagnostics.VisibleCount, 9);
        end

        function testProjectedExtentReportsBothScreenAxes(testCase)
            scene = ProjectionPreviewTileGeometryTest.makeScene();
            layer = scene.layers;
            pyramid = ProjectionPreviewPyramid.build( ...
                layer.Image, struct(TileSize=4));
            cache = ProjectionPreviewTileGeometry.build( ...
                layer, pyramid, layer.CurrentProjectionPlane, ...
                scene.renderOrigin, 4);
            context = ProjectionPreviewTileGeometryTest.cameraContext( ...
                cache, layer.CurrentProjectionPlane);

            [widthPixels, heightPixels] = ...
                ProjectionPreviewTileGeometry.projectedExtentPixels( ...
                cache, context);

            testCase.verifyGreaterThan(widthPixels, 1);
            testCase.verifyGreaterThan(heightPixels, 1);
        end

        function testVisibilityHonorsNonzeroRenderOrigin(testCase)
            scene = ProjectionPreviewTileGeometryTest.makeScene();
            layer = scene.layers;
            plane = layer.CurrentProjectionPlane;
            renderOrigin = plane.P0 + 1e6 * plane.basis(:, 1) + ...
                2e6 * plane.basis(:, 2);
            pyramid = ProjectionPreviewPyramid.build( ...
                layer.Image, struct(TileSize=4));
            cache = ProjectionPreviewTileGeometry.build( ...
                layer, pyramid, plane, renderOrigin, 4);
            mesh = ProjectionMeshBuilder.buildLayerMesh( ...
                layer, plane, renderOrigin);
            context = ProjectionPreviewTileGeometryTest.cameraContextFromPoints( ...
                reshape(mesh.RenderPoints, 3, []), plane);

            [visibleMask, diagnostics] = ...
                ProjectionPreviewTileGeometry.visibleMask(cache, 1, context);

            testCase.verifyTrue(any(visibleMask));
            testCase.verifyGreaterThan(diagnostics.VisibleCount, 0);
        end
    end

    methods (Static, Access = private)
        function scene = makeScene()
            imageData = uint8(reshape(1:120, 10, 12));
            scene = ProjectionViewerHarness.createSceneFromImage( ...
                imageData, "tile_geometry.tif", ...
                struct(RowStride=3, ColumnStride=3));
        end

        function context = cameraContext(cache, plane)
            points = cache.LayerRenderPoints;
            context = ...
                ProjectionPreviewTileGeometryTest.cameraContextFromPoints( ...
                points, plane);
        end

        function context = cameraContextFromPoints(points, plane)
            center = mean(points, 2);
            rightVector = plane.basis(:, 1);
            upVector = plane.basis(:, 2);
            width = max(rightVector.' * points) - min(rightVector.' * points);
            height = max(upVector.' * points) - min(upVector.' * points);
            context = struct(RightVector=rightVector, ...
                UpVector=upVector, Center=center, ...
                ViewWidth=0.45 * width, ViewHeight=0.45 * height, ...
                ViewportWidthPixels=800, ViewportHeightPixels=600, ...
                HaloFraction=0.2);
        end

        function visibleMask = scalarVisibleMask(corners, context)
            tileCount = size(corners, 3);
            visibleMask = false(1, tileCount);
            halfWidth = 0.5 * context.ViewWidth * ...
                (1 + context.HaloFraction);
            halfHeight = 0.5 * context.ViewHeight * ...
                (1 + context.HaloFraction);
            for tileIndex = 1:tileCount
                points = corners(:, :, tileIndex) - context.Center;
                screenX = context.RightVector.' * points;
                screenY = context.UpVector.' * points;
                visibleMask(tileIndex) = max(screenX) >= -halfWidth && ...
                    min(screenX) <= halfWidth && ...
                    max(screenY) >= -halfHeight && ...
                    min(screenY) <= halfHeight;
            end
        end
    end
end
