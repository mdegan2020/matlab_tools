classdef ProjectionViewerAppInteractionTest < matlab.unittest.TestCase
    %ProjectionViewerAppInteractionTest Tests for programmatic viewer callbacks.

    properties (Constant)
        Tol = 1e-10
    end

    methods (TestClassSetup)
        function addSourceToPath(testCase)
            projectRoot = fileparts(fileparts(mfilename("fullpath")));
            srcFolder = fullfile(projectRoot, "src");
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(srcFolder));
        end
    end

    methods (TestMethodSetup)
        function closeExistingViewer(testCase)
            delete(findall(groot, "Type", "figure", ...
                "Name", "Projection Viewer Prototype"));
            testCase.addTeardown(@() delete(findall(groot, "Type", "figure", ...
                "Name", "Projection Viewer Prototype")));
        end
    end

    methods (Test)
        function testImageAxesDecorationsAreHidden(testCase)
            scene = ProjectionViewerAppInteractionTest.makeScene();
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow

            fig = findall(groot, "Type", "figure", ...
                "Name", "Projection Viewer Prototype");
            ax = findall(fig, "Type", "axes");

            testCase.verifyEqual(string(ax.Title.String), "");
            testCase.verifyEqual(string(ax.XLabel.String), "");
            testCase.verifyEqual(string(ax.YLabel.String), "");
            testCase.verifyEqual(string(ax.ZLabel.String), "");
            testCase.verifyEmpty(ax.XTick);
            testCase.verifyEmpty(ax.YTick);
            testCase.verifyEmpty(ax.ZTick);
            testCase.verifyEqual(string(ax.Box), "off");
            testCase.verifyEqual(string(ax.Visible), "off");
        end

        function testControlScrollAdjustsTwistWithoutZoomOrMeshChange(testCase)
            scene = ProjectionViewerAppInteractionTest.makeScene();
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow

            fig = findall(groot, "Type", "figure", ...
                "Name", "Projection Viewer Prototype");
            ax = findall(fig, "Type", "axes");
            twistSlider = ProjectionViewerAppInteractionTest.findSliderInColumn(fig, 4);
            surfaceHandle = findall(ax, "Type", "surface");
            x0 = surfaceHandle(1).XData;
            y0 = surfaceHandle(1).YData;
            z0 = surfaceHandle(1).ZData;
            initialCameraViewAngle = ax.CameraViewAngle;
            initialUpVector = camup(ax);

            fig.WindowKeyPressFcn(fig, ...
                ProjectionViewerAppInteractionTest.makeKeyEvent("control"));
            fig.WindowScrollWheelFcn(fig, ...
                ProjectionViewerAppInteractionTest.makeScrollEvent(-3));
            drawnow

            testCase.verifyEqual(twistSlider.Value, 3, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyEqual(ax.CameraViewAngle, initialCameraViewAngle, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyGreaterThan(norm(camup(ax) - initialUpVector), 1e-9);
            testCase.verifyEqual(surfaceHandle(1).XData, x0, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyEqual(surfaceHandle(1).YData, y0, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyEqual(surfaceHandle(1).ZData, z0, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);

            fig.WindowKeyReleaseFcn(fig, ...
                ProjectionViewerAppInteractionTest.makeKeyEvent("control"));
            fig.WindowScrollWheelFcn(fig, ...
                ProjectionViewerAppInteractionTest.makeScrollEvent(-3));
            drawnow

            testCase.verifyEqual(twistSlider.Value, 3, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
        end

        function testShiftScrollAdjustsTipWithoutZoom(testCase)
            scene = ProjectionViewerAppInteractionTest.makeScene();
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow

            fig = findall(groot, "Type", "figure", ...
                "Name", "Projection Viewer Prototype");
            ax = findall(fig, "Type", "axes");
            tipSlider = ProjectionViewerAppInteractionTest.findSliderInColumn(fig, 2);
            surfaceHandle = findall(ax, "Type", "surface");
            initialXData = surfaceHandle(1).XData;
            initialYData = surfaceHandle(1).YData;
            initialZData = surfaceHandle(1).ZData;
            initialCameraViewAngle = ax.CameraViewAngle;

            fig.WindowKeyPressFcn(fig, ...
                ProjectionViewerAppInteractionTest.makeKeyEvent("shift"));
            fig.WindowScrollWheelFcn(fig, ...
                ProjectionViewerAppInteractionTest.makeScrollEvent(-4));
            drawnow

            testCase.verifyEqual(tipSlider.Value, 4, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyEqual(ax.CameraViewAngle, initialCameraViewAngle, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyGreaterThan(ProjectionViewerAppInteractionTest.surfaceChange( ...
                surfaceHandle(1), initialXData, initialYData, initialZData), 1e-9);

            fig.WindowKeyReleaseFcn(fig, ...
                ProjectionViewerAppInteractionTest.makeKeyEvent("shift"));
            fig.WindowScrollWheelFcn(fig, ...
                ProjectionViewerAppInteractionTest.makeScrollEvent(-2));
            drawnow

            testCase.verifyEqual(tipSlider.Value, 4, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
        end

        function testAltScrollAdjustsTiltWithoutZoom(testCase)
            scene = ProjectionViewerAppInteractionTest.makeScene();
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow

            fig = findall(groot, "Type", "figure", ...
                "Name", "Projection Viewer Prototype");
            ax = findall(fig, "Type", "axes");
            tiltSlider = ProjectionViewerAppInteractionTest.findSliderInColumn(fig, 3);
            surfaceHandle = findall(ax, "Type", "surface");
            initialXData = surfaceHandle(1).XData;
            initialYData = surfaceHandle(1).YData;
            initialZData = surfaceHandle(1).ZData;
            initialCameraViewAngle = ax.CameraViewAngle;

            fig.WindowKeyPressFcn(fig, ...
                ProjectionViewerAppInteractionTest.makeKeyEvent("alt"));
            fig.WindowScrollWheelFcn(fig, ...
                ProjectionViewerAppInteractionTest.makeScrollEvent(-5));
            drawnow

            testCase.verifyEqual(tiltSlider.Value, 5, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyEqual(ax.CameraViewAngle, initialCameraViewAngle, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyGreaterThan(ProjectionViewerAppInteractionTest.surfaceChange( ...
                surfaceHandle(1), initialXData, initialYData, initialZData), 1e-9);

            fig.WindowKeyReleaseFcn(fig, ...
                ProjectionViewerAppInteractionTest.makeKeyEvent("alt"));
            fig.WindowScrollWheelFcn(fig, ...
                ProjectionViewerAppInteractionTest.makeScrollEvent(-2));
            drawnow

            testCase.verifyEqual(tiltSlider.Value, 5, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
        end

        function testLayerSpecificAlphaDragUsesSelectedLayerSampling(testCase)
            scene = ProjectionViewerAppInteractionTest.makeTwoImageScene();
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow

            fig = findall(groot, "Type", "figure", ...
                "Name", "Projection Viewer Prototype");
            ax = findall(fig, "Type", "axes");
            layerDropDown = ProjectionViewerAppInteractionTest.findLayerDropDown(fig);
            alphaSlider = ProjectionViewerAppInteractionTest.findSliderInColumn(fig, 5);

            layerDropDown.Value = 2;
            layerDropDown.ValueChangedFcn(layerDropDown, struct("Value", 2));
            drawnow
            pause(0.04)

            alphaSlider.ValueChangingFcn(alphaSlider, struct("Value", 0.4));
            drawnow
            alphaSlider.Value = 0.4;
            alphaSlider.ValueChangedFcn(alphaSlider, struct());
            drawnow

            surfaceHandles = findall(ax, "Type", "surface");
            hasLayer2Texture = any(arrayfun( ...
                @(surfaceHandle) isequal(surfaceHandle.CData, ...
                scene.layers(2).DisplayTexture), surfaceHandles));
            testCase.verifyTrue(hasLayer2Texture);
            testCase.verifyEqual(alphaSlider.Value, 0.4, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
        end

        function testTipTiltControlsSharedProjectionPlane(testCase)
            scene = ProjectionViewerAppInteractionTest.makeTwoImageScene();
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow

            fig = findall(groot, "Type", "figure", ...
                "Name", "Projection Viewer Prototype");
            ax = findall(fig, "Type", "axes");
            layerDropDown = ProjectionViewerAppInteractionTest.findLayerDropDown(fig);
            tipSlider = ProjectionViewerAppInteractionTest.findSliderInColumn(fig, 2);
            layerSurfaces = ProjectionViewerAppInteractionTest.findLayerSurfaces( ...
                ax, scene);
            layer1X0 = layerSurfaces(1).XData;
            layer1Y0 = layerSurfaces(1).YData;
            layer1Z0 = layerSurfaces(1).ZData;
            layer2X0 = layerSurfaces(2).XData;
            layer2Y0 = layerSurfaces(2).YData;
            layer2Z0 = layerSurfaces(2).ZData;

            layerDropDown.Value = 2;
            layerDropDown.ValueChangedFcn(layerDropDown, struct("Value", 2));
            tipSlider.Value = 6;
            tipSlider.ValueChangedFcn(tipSlider, struct());
            drawnow

            layerSurfaces = ProjectionViewerAppInteractionTest.findLayerSurfaces( ...
                ax, scene);
            layer1Change = ProjectionViewerAppInteractionTest.surfaceChange( ...
                layerSurfaces(1), layer1X0, layer1Y0, layer1Z0);
            layer2Change = ProjectionViewerAppInteractionTest.surfaceChange( ...
                layerSurfaces(2), layer2X0, layer2Y0, layer2Z0);
            layerDropDown.Value = 1;
            layerDropDown.ValueChangedFcn(layerDropDown, struct("Value", 1));
            drawnow

            testCase.verifyGreaterThan(layer1Change, 1e-9);
            testCase.verifyGreaterThan(layer2Change, 1e-9);
            testCase.verifyEqual(tipSlider.Value, 6, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
        end
    end

    methods (Static, Access = private)
        function scene = makeScene()
            imageData = uint8(reshape(1:60, 4, 5, 3));
            options = struct();
            options.RowStride = 2;
            options.ColumnStride = 2;
            scene = ProjectionViewerHarness.createSceneFromImage( ...
                imageData, "synthetic.tif", options);
        end

        function scene = makeTwoImageScene()
            imageData1 = uint8(reshape(1:60, 4, 5, 3));
            imageData2 = uint8(reshape(1:72, 6, 4, 3));
            options = struct();
            options.RowStride = 2;
            options.ColumnStride = 2;
            scene = ProjectionViewerHarness.createSceneFromImages( ...
                {imageData1, imageData2}, ["layer1.tif", "layer2.tif"], ...
                options);
        end

        function dropdown = findLayerDropDown(fig)
            dropdowns = findall(fig, "-isa", "matlab.ui.control.DropDown");
            isLayerDropDown = false(size(dropdowns));
            for k = 1:numel(dropdowns)
                isLayerDropDown(k) = isnumeric(dropdowns(k).ItemsData) && ...
                    isequal(dropdowns(k).ItemsData, 1:numel(dropdowns(k).Items));
            end
            dropdown = dropdowns(isLayerDropDown);
        end

        function slider = findSliderInColumn(fig, column)
            sliders = findall(fig, "-isa", "matlab.ui.control.Slider");
            sliderColumns = arrayfun(@(slider) slider.Layout.Column, sliders);
            slider = sliders(sliderColumns == column);
        end

        function surfaces = findLayerSurfaces(ax, scene)
            surfaceHandles = findall(ax, "Type", "surface");
            surfaces = gobjects(1, numel(scene.layers));
            for layerIndex = 1:numel(scene.layers)
                isLayerSurface = arrayfun( ...
                    @(surfaceHandle) isequal(surfaceHandle.CData, ...
                    scene.layers(layerIndex).DisplayTexture), surfaceHandles);
                surfaces(layerIndex) = surfaceHandles(isLayerSurface);
            end
        end

        function event = makeKeyEvent(key)
            event = struct();
            event.Key = key;
            event.Modifier = key;
        end

        function event = makeScrollEvent(verticalScrollCount)
            event = struct();
            event.VerticalScrollCount = verticalScrollCount;
        end

        function change = surfaceChange(surfaceHandle, x0, y0, z0)
            change = max([max(abs(surfaceHandle.XData - x0), [], "all"), ...
                max(abs(surfaceHandle.YData - y0), [], "all"), ...
                max(abs(surfaceHandle.ZData - z0), [], "all")]);
        end
    end
end
