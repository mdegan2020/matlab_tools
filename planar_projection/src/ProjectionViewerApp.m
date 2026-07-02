classdef ProjectionViewerApp < handle
    %ProjectionViewerApp Programmatic preview app for projected imagery.

    properties (Access = private)
        Scene struct
        CurrentMesh struct
        DefaultMeshSampling struct
        DragMeshSampling struct
        PreviewTimer
        MinPreviewInterval double = 1 / 30
        UIFigure matlab.ui.Figure
        GridLayout matlab.ui.container.GridLayout
        Axes matlab.ui.control.UIAxes
        Surface
        ControlGrid matlab.ui.container.GridLayout
        TipSlider matlab.ui.control.Slider
        TiltSlider matlab.ui.control.Slider
        AlphaSlider matlab.ui.control.Slider
        TipLabel matlab.ui.control.Label
        TiltLabel matlab.ui.control.Label
        AlphaLabel matlab.ui.control.Label
        ResetButton matlab.ui.control.Button
    end

    methods
        function app = ProjectionViewerApp(scene)
            if nargin < 1
                scene = ProjectionViewerHarness.createDefaultScene();
            end

            app.Scene = scene;
            app.DefaultMeshSampling = app.Scene.layers.MeshSampling;
            app.DragMeshSampling = app.createDragMeshSampling();
            app.PreviewTimer = tic;
            app.createComponents();
            app.createSurface();
            app.configureFrameCamera();
            app.updateLabels(0, 0, app.Scene.layers.Alpha);

            if nargout == 0
                clear app
            end
        end

        function delete(app)
            if ~isempty(app.UIFigure) && isvalid(app.UIFigure)
                delete(app.UIFigure);
            end
        end
    end

    methods (Access = private)
        function createComponents(app)
            app.UIFigure = uifigure(Name="Projection Viewer Prototype", ...
                Position=[100 100 1100 760]);

            app.GridLayout = uigridlayout(app.UIFigure, [2 1]);
            app.GridLayout.RowHeight = {"1x", "fit"};
            app.GridLayout.ColumnWidth = {"1x"};
            app.GridLayout.Padding = [8 8 8 8];
            app.GridLayout.RowSpacing = 8;

            app.Axes = uiaxes(app.GridLayout);
            app.Axes.Layout.Row = 1;
            app.Axes.Layout.Column = 1;
            app.Axes.Box = "on";
            app.Axes.Toolbar.Visible = "on";
            app.Axes.Interactions = [panInteraction zoomInteraction];
            title(app.Axes, "Projected preview");
            xlabel(app.Axes, "X");
            ylabel(app.Axes, "Y");
            zlabel(app.Axes, "Z");

            app.ControlGrid = uigridlayout(app.GridLayout, [2 4]);
            app.ControlGrid.Layout.Row = 2;
            app.ControlGrid.Layout.Column = 1;
            app.ControlGrid.RowHeight = {"fit", "fit"};
            app.ControlGrid.ColumnWidth = {"1x", "1x", "1x", "fit"};
            app.ControlGrid.Padding = [0 0 0 0];
            app.ControlGrid.ColumnSpacing = 14;

            app.TipLabel = uilabel(app.ControlGrid, Text="Tip 0.0 deg");
            app.TipLabel.Layout.Row = 1;
            app.TipLabel.Layout.Column = 1;
            app.TipSlider = uislider(app.ControlGrid, Limits=[-15 15], Value=0);
            app.TipSlider.Layout.Row = 2;
            app.TipSlider.Layout.Column = 1;
            app.TipSlider.MajorTicks = -15:5:15;
            app.TipSlider.ValueChangingFcn = @(source, event) ...
                app.sliderChanging(source, event, "tip");
            app.TipSlider.ValueChangedFcn = @(~, ~) app.updateFromSliderValues();

            app.TiltLabel = uilabel(app.ControlGrid, Text="Tilt 0.0 deg");
            app.TiltLabel.Layout.Row = 1;
            app.TiltLabel.Layout.Column = 2;
            app.TiltSlider = uislider(app.ControlGrid, Limits=[-15 15], Value=0);
            app.TiltSlider.Layout.Row = 2;
            app.TiltSlider.Layout.Column = 2;
            app.TiltSlider.MajorTicks = -15:5:15;
            app.TiltSlider.ValueChangingFcn = @(source, event) ...
                app.sliderChanging(source, event, "tilt");
            app.TiltSlider.ValueChangedFcn = @(~, ~) app.updateFromSliderValues();

            app.AlphaLabel = uilabel(app.ControlGrid, Text="Alpha 1.00");
            app.AlphaLabel.Layout.Row = 1;
            app.AlphaLabel.Layout.Column = 3;
            app.AlphaSlider = uislider(app.ControlGrid, Limits=[0 1], Value=1);
            app.AlphaSlider.Layout.Row = 2;
            app.AlphaSlider.Layout.Column = 3;
            app.AlphaSlider.MajorTicks = 0:0.25:1;
            app.AlphaSlider.ValueChangingFcn = @(source, event) ...
                app.sliderChanging(source, event, "alpha");
            app.AlphaSlider.ValueChangedFcn = @(~, ~) app.updateFromSliderValues();

            app.ResetButton = uibutton(app.ControlGrid, Text="Reset", ...
                ButtonPushedFcn=@(~, ~) app.resetView());
            app.ResetButton.Layout.Row = [1 2];
            app.ResetButton.Layout.Column = 4;
        end

        function createSurface(app)
            layer = app.Scene.layers;
            app.CurrentMesh = ProjectionMeshBuilder.buildLayerMesh( ...
                layer, layer.CurrentProjectionPlane, app.Scene.renderOrigin);

            app.Surface = surface(app.Axes, app.CurrentMesh.X, app.CurrentMesh.Y, ...
                app.CurrentMesh.Z, app.CurrentMesh.Texture, ...
                FaceColor="texturemap", EdgeColor="none", ...
                FaceAlpha=app.CurrentMesh.Alpha);
            axis(app.Axes, "equal");
            axis(app.Axes, "tight");
            grid(app.Axes, "off");
        end

        function configureFrameCamera(app)
            camera = app.Scene.frameCamera;
            renderOrigin = app.Scene.renderOrigin;
            target = app.Scene.layers.BaseProjectionPlane.P0 - renderOrigin;
            cameraPosition = camera.G0 - renderOrigin;
            upVector = camera.focalPlane.basis(:, 2);

            camproj(app.Axes, "orthographic");
            campos(app.Axes, cameraPosition.');
            camtarget(app.Axes, target.');
            camup(app.Axes, upVector.');
        end

        function sliderChanging(app, source, event, sliderName)
            tipDegrees = app.TipSlider.Value;
            tiltDegrees = app.TiltSlider.Value;
            alpha = app.AlphaSlider.Value;

            switch sliderName
                case "tip"
                    tipDegrees = event.Value;
                case "tilt"
                    tiltDegrees = event.Value;
                case "alpha"
                    alpha = event.Value;
            end

            source.Value = event.Value;
            app.updateLabels(tipDegrees, tiltDegrees, alpha);
            if toc(app.PreviewTimer) < app.MinPreviewInterval
                return
            end

            app.PreviewTimer = tic;
            app.updateProjection(tipDegrees, tiltDegrees, alpha, app.DragMeshSampling);
        end

        function updateFromSliderValues(app)
            app.updateProjection(app.TipSlider.Value, app.TiltSlider.Value, ...
                app.AlphaSlider.Value, app.DefaultMeshSampling);
            app.PreviewTimer = tic;
        end

        function updateProjection(app, tipDegrees, tiltDegrees, alpha, meshSampling)
            if nargin < 5
                meshSampling = app.DefaultMeshSampling;
            end

            layer = app.Scene.layers;
            plane = ProjectionMeshBuilder.applyPlaneTipTilt( ...
                layer.BaseProjectionPlane, deg2rad(tipDegrees), deg2rad(tiltDegrees));
            layer.CurrentProjectionPlane = plane;
            layer.Alpha = alpha;
            layer.MeshSampling = meshSampling;
            app.Scene.layers = layer;

            app.CurrentMesh = ProjectionMeshBuilder.buildLayerMesh( ...
                layer, plane, app.Scene.renderOrigin);
            app.Surface.XData = app.CurrentMesh.X;
            app.Surface.YData = app.CurrentMesh.Y;
            app.Surface.ZData = app.CurrentMesh.Z;
            app.Surface.FaceAlpha = app.CurrentMesh.Alpha;
            app.updateLabels(tipDegrees, tiltDegrees, alpha);
            drawnow limitrate
        end

        function updateLabels(app, tipDegrees, tiltDegrees, alpha)
            app.TipLabel.Text = sprintf("Tip %.1f deg", tipDegrees);
            app.TiltLabel.Text = sprintf("Tilt %.1f deg", tiltDegrees);
            app.AlphaLabel.Text = sprintf("Alpha %.2f", alpha);
        end

        function resetView(app)
            app.TipSlider.Value = 0;
            app.TiltSlider.Value = 0;
            app.AlphaSlider.Value = 1;
            app.updateProjection(0, 0, 1, app.DefaultMeshSampling);
            app.configureFrameCamera();
        end

        function meshSampling = createDragMeshSampling(app)
            imageSize = app.Scene.layers.SourceGeometry.ImageSize;
            rowStride = max(1, app.DefaultMeshSampling.RowStride * 2);
            columnStride = max(1, app.DefaultMeshSampling.ColumnStride * 2);
            meshSampling = ProjectionViewerHarness.createMeshSampling( ...
                imageSize, rowStride, columnStride);
        end
    end
end
