classdef ProjectionViewerRealDataFramingTest < matlab.unittest.TestCase
    %ProjectionViewerRealDataFramingTest Initial framing for real geometry.

    properties (Constant)
        Tol = 1e-9
    end

    methods (TestClassSetup)
        function addSourceToPath(testCase)
            projectRoot = fileparts(fileparts(mfilename("fullpath")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(projectRoot, "src")));
        end
    end

    methods (Test)
        function testOffsetFootprintIsCenteredAndVisible(testCase)
            scene = ProjectionViewerRealDataFramingTest.makeScene(100, 1000);
            expectedDirection = scene.frameCamera.V0;
            expectedDistance = norm(scene.layers.BaseProjectionPlane.P0 - ...
                scene.frameCamera.G0);

            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow
            ax = ProjectionViewerRealDataFramingTest.viewerAxes();
            metrics = ProjectionViewerRealDataFramingTest.screenMetrics(ax);
            actualDirection = ProjectionViewerRealDataFramingTest.viewDirection(ax);
            actualDistance = norm(camtarget(ax).' - campos(ax).');

            testCase.verifyTrue(metrics.IntersectsViewport);
            testCase.verifyGreaterThan(metrics.FillFraction, 0.45);
            testCase.verifyLessThan(metrics.FillFraction, 0.55);
            testCase.verifyLessThan(abs(metrics.CenterFractionX), 1e-8);
            testCase.verifyLessThan(abs(metrics.CenterFractionY), 1e-8);
            testCase.verifyEqual(actualDirection, expectedDirection, ...
                AbsTol=ProjectionViewerRealDataFramingTest.Tol);
            testCase.verifyEqual(actualDistance, expectedDistance, ...
                AbsTol=ProjectionViewerRealDataFramingTest.Tol);
            testCase.verifyGreaterThan(norm(camtarget(ax)), 1);
        end

        function testSubPointZeroFiveDegreeViewStillFillsViewport(testCase)
            scene = ProjectionViewerRealDataFramingTest.makeScene(1e6, 0);

            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow
            ax = ProjectionViewerRealDataFramingTest.viewerAxes();
            metrics = ProjectionViewerRealDataFramingTest.screenMetrics(ax);

            testCase.verifyLessThan(ax.CameraViewAngle, 0.05);
            testCase.verifyGreaterThan(ax.CameraViewAngle, 0);
            testCase.verifyTrue(metrics.IntersectsViewport);
            testCase.verifyGreaterThan(metrics.FillFraction, 0.45);
            testCase.verifyLessThan(metrics.FillFraction, 0.55);
        end

        function testTiledWorldCoordinatesRetainActiveSurfaces(testCase)
            scene = ProjectionViewerRealDataFramingTest.makeTiledWorldScene();

            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow
            ax = ProjectionViewerRealDataFramingTest.viewerAxes();
            activeSurfaces = findall(ax, "Type", "surface", ...
                "Tag", "ProjectionViewerPreviewTileSurface");
            diagnostics = app.performanceDiagnostics();

            testCase.verifyNotEmpty(activeSurfaces);
            testCase.verifyTrue(all(arrayfun( ...
                @(value) string(value.Visible) == "on", activeSurfaces)));
            testCase.verifyGreaterThan( ...
                diagnostics.Viewer.PredictedVisibleTileCounts(1), 0);
        end
    end

    methods (Static, Access = private)
        function scene = makeScene(rangeMeters, lateralOffsetMeters)
            imageSize = [5 7];
            imageData = uint8(reshape(1:prod(imageSize), imageSize));
            rowPosts = [1 3 5];
            columnPosts = [1 4 7];
            centerRow = (imageSize(1) + 1) / 2;
            centerColumn = (imageSize(2) + 1) / 2;
            origins = [zeros(1, numel(columnPosts)); ...
                lateralOffsetMeters * ones(1, numel(columnPosts)); ...
                0.05 * (columnPosts - centerColumn)];
            viewVectors = zeros(3, numel(rowPosts), numel(columnPosts));
            for rowIndex = 1:numel(rowPosts)
                for columnIndex = 1:numel(columnPosts)
                    viewVectors(:, rowIndex, columnIndex) = [1; ...
                        (rowPosts(rowIndex) - centerRow) / rangeMeters; ...
                        (columnPosts(columnIndex) - centerColumn) / rangeMeters];
                end
            end
            viewVectors = viewVectors ./ sqrt(sum(viewVectors .^ 2, 1));
            geometryDefinition = struct( ...
                RowPostIndices=rowPosts, ...
                ColumnPostIndices=columnPosts, ...
                ViewVectorOrigins=origins, ...
                ViewVectors=viewVectors, ...
                NominalSceneCenter=[0; lateralOffsetMeters; 0], ...
                Metadata=struct(Source="framing-test"));
            projectionPlane = PlanarProjection.definePlaneFromBasis( ...
                [rangeMeters; 0; 0], [0; 1; 0], [0; 0; 1]);
            options = ProjectionViewerHarness.realDataOptions(struct( ...
                RowStride=2, ColumnStride=3, FrameFocalLength=1, ...
                ReferenceOrigin=[0; lateralOffsetMeters; 0], ...
                OpticalAxis=[1; 0; 0], PlatformDirection=[0; 0; 1], ...
                RowAxis=[0; 1; 0], ImageXAxis=[0; 0; 1], ...
                ImageYAxis=[0; 1; 0]));
            scene = ProjectionViewerHarness.createRealDataScene( ...
                "Offset real layer", {imageData}, {geometryDefinition}, ...
                projectionPlane, options);
        end

        function scene = makeTiledWorldScene()
            imageSize = [2001 2001];
            imageData = zeros(imageSize, "uint8");
            rowPosts = [1 1001 2001];
            columnPosts = [1 1001 2001];
            centerRow = (imageSize(1) + 1) / 2;
            centerColumn = (imageSize(2) + 1) / 2;
            rangeMeters = 1000;
            metersPerPixel = 0.01;
            planeOrigin = [1e6; 2e6; 3e6];
            cameraOrigin = planeOrigin - [rangeMeters; 0; 0];
            origins = repmat(cameraOrigin, 1, numel(columnPosts));
            viewVectors = zeros(3, numel(rowPosts), numel(columnPosts));
            for rowIndex = 1:numel(rowPosts)
                for columnIndex = 1:numel(columnPosts)
                    viewVectors(:, rowIndex, columnIndex) = [1; ...
                        metersPerPixel * ...
                        (rowPosts(rowIndex) - centerRow) / rangeMeters; ...
                        metersPerPixel * ...
                        (columnPosts(columnIndex) - centerColumn) / rangeMeters];
                end
            end
            viewVectors = viewVectors ./ sqrt(sum(viewVectors .^ 2, 1));
            geometryDefinition = struct( ...
                RowPostIndices=rowPosts, ...
                ColumnPostIndices=columnPosts, ...
                ViewVectorOrigins=origins, ...
                ViewVectors=viewVectors, ...
                NominalSceneCenter=cameraOrigin, ...
                Metadata=struct(Source="tiled-world-framing-test"));
            projectionPlane = PlanarProjection.definePlaneFromBasis( ...
                planeOrigin, [0; 1; 0], [0; 0; 1]);
            options = ProjectionViewerHarness.realDataOptions(struct( ...
                RowStride=250, ColumnStride=250, FrameFocalLength=1, ...
                DisplayTextureMaxPixels=10000, ...
                ReferenceOrigin=cameraOrigin, OpticalAxis=[1; 0; 0], ...
                PlatformDirection=[0; 0; 1], RowAxis=[0; 1; 0], ...
                ImageXAxis=[0; 0; 1], ImageYAxis=[0; 1; 0]));
            scene = ProjectionViewerHarness.createRealDataScene( ...
                "Tiled world layer", {imageData}, {geometryDefinition}, ...
                projectionPlane, options);
        end

        function ax = viewerAxes()
            fig = findall(groot, "Type", "figure", ...
                "Name", "Projection Viewer Prototype");
            ax = findall(fig(1), "Type", "axes");
            ax = ax(1);
        end

        function metrics = screenMetrics(ax)
            surfaces = findall(ax, "Type", "surface");
            visible = arrayfun(@(value) string(value.Visible) == "on", surfaces);
            points = ProjectionViewerRealDataFramingTest.surfacePoints( ...
                surfaces(visible));
            viewDirection = ProjectionViewerRealDataFramingTest.viewDirection(ax);
            upVector = camup(ax).';
            upVector = upVector / norm(upVector);
            rightVector = cross(viewDirection, upVector);
            rightVector = rightVector / norm(rightVector);
            cameraTarget = camtarget(ax).';
            relativePoints = points - cameraTarget;
            screenX = rightVector.' * relativePoints;
            screenY = upVector.' * relativePoints;
            viewDistance = norm(cameraTarget - campos(ax).');
            axesPosition = ax.InnerPosition;
            viewHeight = 2 * viewDistance * tan( ...
                deg2rad(ax.CameraViewAngle) / 2);
            viewWidth = viewHeight * max(axesPosition(3), 1) / ...
                max(axesPosition(4), 1);
            metrics = struct();
            metrics.FillFraction = max( ...
                (max(screenX) - min(screenX)) / viewWidth, ...
                (max(screenY) - min(screenY)) / viewHeight);
            metrics.CenterFractionX = 0.5 * ...
                (min(screenX) + max(screenX)) / viewWidth;
            metrics.CenterFractionY = 0.5 * ...
                (min(screenY) + max(screenY)) / viewHeight;
            metrics.IntersectsViewport = ...
                max(screenX) >= -0.5 * viewWidth && ...
                min(screenX) <= 0.5 * viewWidth && ...
                max(screenY) >= -0.5 * viewHeight && ...
                min(screenY) <= 0.5 * viewHeight;
        end

        function points = surfacePoints(surfaces)
            points = zeros(3, 0);
            for surfaceIndex = 1:numel(surfaces)
                surfaceHandle = surfaces(surfaceIndex);
                points = [points, [surfaceHandle.XData(:).'; ...
                    surfaceHandle.YData(:).'; ...
                    surfaceHandle.ZData(:).']]; %#ok<AGROW>
            end
        end

        function direction = viewDirection(ax)
            direction = camtarget(ax).' - campos(ax).';
            direction = direction / norm(direction);
        end
    end
end
