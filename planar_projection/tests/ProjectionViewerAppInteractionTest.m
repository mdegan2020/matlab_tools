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
            twistSlider = ProjectionViewerAppInteractionTest.findTwistSlider(fig);
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

        function twistSlider = findTwistSlider(fig)
            sliders = findall(fig, "-isa", "matlab.ui.control.Slider");
            sliderColumns = arrayfun(@(slider) slider.Layout.Column, sliders);
            twistSlider = sliders(sliderColumns == 4);
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
    end
end
