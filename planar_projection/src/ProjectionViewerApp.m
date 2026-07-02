classdef ProjectionViewerApp < handle
    %ProjectionViewerApp Programmatic preview app for projected imagery.

    properties (Access = private)
        Scene struct
        CurrentMesh struct
        Surfaces cell
        DefaultMeshSampling struct
        DragMeshSampling struct
        LayerTipDegrees double
        LayerTiltDegrees double
        LayerTwistDegrees double
        SelectedLayerIndex double = 1
        IsPanning logical = false
        LastPointerLocation double = [NaN NaN]
        PreviewTimer
        MinPreviewInterval double = 1 / 30
        MinCameraViewAngle double = 0.05
        MaxCameraViewAngle double = 60
        UIFigure matlab.ui.Figure
        GridLayout matlab.ui.container.GridLayout
        Axes matlab.ui.control.UIAxes
        Surface
        ControlGrid matlab.ui.container.GridLayout
        TipSlider matlab.ui.control.Slider
        TiltSlider matlab.ui.control.Slider
        TwistSlider matlab.ui.control.Slider
        AlphaSlider matlab.ui.control.Slider
        TipLabel matlab.ui.control.Label
        TiltLabel matlab.ui.control.Label
        TwistLabel matlab.ui.control.Label
        AlphaLabel matlab.ui.control.Label
        LayerDropDown matlab.ui.control.DropDown
        VisibleCheckBox matlab.ui.control.CheckBox
        BlendModeDropDown matlab.ui.control.DropDown
        CycleButton matlab.ui.control.Button
        ResetButton matlab.ui.control.Button
    end

    methods
        function app = ProjectionViewerApp(scene)
            if nargin < 1
                scene = ProjectionViewerHarness.createDefaultScene();
            end

            app.Scene = scene;
            numLayers = numel(app.Scene.layers);
            app.LayerTipDegrees = zeros(1, numLayers);
            app.LayerTiltDegrees = zeros(1, numLayers);
            app.LayerTwistDegrees = zeros(1, numLayers);
            app.DefaultMeshSampling = app.Scene.layers(1).MeshSampling;
            app.DragMeshSampling = app.createDragMeshSampling();
            app.PreviewTimer = tic;
            app.createComponents();
            app.createSurface();
            app.configureFrameCamera();
            app.updateLabels(0, 0, 0, app.Scene.layers(app.SelectedLayerIndex).Alpha);

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
                Position=[100 100 1100 760], ...
                WindowScrollWheelFcn=@(~, event) app.scrollZoom(event), ...
                WindowButtonDownFcn=@(~, ~) app.beginPan(), ...
                WindowButtonMotionFcn=@(~, ~) app.updatePan(), ...
                WindowButtonUpFcn=@(~, ~) app.endPan());

            app.GridLayout = uigridlayout(app.UIFigure, [2 1]);
            app.GridLayout.RowHeight = {"1x", "fit"};
            app.GridLayout.ColumnWidth = {"1x"};
            app.GridLayout.Padding = [8 8 8 8];
            app.GridLayout.RowSpacing = 8;

            app.Axes = uiaxes(app.GridLayout);
            app.Axes.Layout.Row = 1;
            app.Axes.Layout.Column = 1;
            app.Axes.Box = "on";
            app.Axes.Toolbar.Visible = "off";
            app.Axes.Interactions = [];
            title(app.Axes, "Projected preview");
            xlabel(app.Axes, "X");
            ylabel(app.Axes, "Y");
            zlabel(app.Axes, "Z");

            app.ControlGrid = uigridlayout(app.GridLayout, [2 9]);
            app.ControlGrid.Layout.Row = 2;
            app.ControlGrid.Layout.Column = 1;
            app.ControlGrid.RowHeight = {"fit", "fit"};
            app.ControlGrid.ColumnWidth = {"1.2x", "1x", "1x", "1x", "1x", ...
                "fit", "1x", "fit", "fit"};
            app.ControlGrid.Padding = [0 0 0 0];
            app.ControlGrid.ColumnSpacing = 14;

            layerLabel = uilabel(app.ControlGrid, Text="Layer");
            layerLabel.Layout.Row = 1;
            layerLabel.Layout.Column = 1;
            app.LayerDropDown = uidropdown(app.ControlGrid, ...
                Items=cellstr(app.layerDisplayNames()), ...
                ItemsData=1:numel(app.Scene.layers), ...
                Value=app.SelectedLayerIndex, ...
                ValueChangedFcn=@(~, event) app.layerSelectionChanged(event));
            app.LayerDropDown.Layout.Row = 2;
            app.LayerDropDown.Layout.Column = 1;

            app.TipLabel = uilabel(app.ControlGrid, Text="Tip 0.0 deg");
            app.TipLabel.Layout.Row = 1;
            app.TipLabel.Layout.Column = 2;
            app.TipSlider = uislider(app.ControlGrid, Limits=[-30 30], Value=0);
            app.TipSlider.Layout.Row = 2;
            app.TipSlider.Layout.Column = 2;
            app.TipSlider.MajorTicks = -30:10:30;
            app.TipSlider.ValueChangingFcn = @(source, event) ...
                app.sliderChanging(source, event, "tip");
            app.TipSlider.ValueChangedFcn = @(~, ~) app.updateFromSliderValues();

            app.TiltLabel = uilabel(app.ControlGrid, Text="Tilt 0.0 deg");
            app.TiltLabel.Layout.Row = 1;
            app.TiltLabel.Layout.Column = 3;
            app.TiltSlider = uislider(app.ControlGrid, Limits=[-30 30], Value=0);
            app.TiltSlider.Layout.Row = 2;
            app.TiltSlider.Layout.Column = 3;
            app.TiltSlider.MajorTicks = -30:10:30;
            app.TiltSlider.ValueChangingFcn = @(source, event) ...
                app.sliderChanging(source, event, "tilt");
            app.TiltSlider.ValueChangedFcn = @(~, ~) app.updateFromSliderValues();

            app.TwistLabel = uilabel(app.ControlGrid, Text="Twist 0.0 deg");
            app.TwistLabel.Layout.Row = 1;
            app.TwistLabel.Layout.Column = 4;
            app.TwistSlider = uislider(app.ControlGrid, Limits=[-30 30], Value=0);
            app.TwistSlider.Layout.Row = 2;
            app.TwistSlider.Layout.Column = 4;
            app.TwistSlider.MajorTicks = -30:10:30;
            app.TwistSlider.ValueChangingFcn = @(source, event) ...
                app.sliderChanging(source, event, "twist");
            app.TwistSlider.ValueChangedFcn = @(~, ~) app.updateFromSliderValues();

            app.AlphaLabel = uilabel(app.ControlGrid, Text="Alpha 1.00");
            app.AlphaLabel.Layout.Row = 1;
            app.AlphaLabel.Layout.Column = 5;
            app.AlphaSlider = uislider(app.ControlGrid, Limits=[0 1], Value=1);
            app.AlphaSlider.Layout.Row = 2;
            app.AlphaSlider.Layout.Column = 5;
            app.AlphaSlider.MajorTicks = 0:0.25:1;
            app.AlphaSlider.ValueChangingFcn = @(source, event) ...
                app.sliderChanging(source, event, "alpha");
            app.AlphaSlider.ValueChangedFcn = @(~, ~) app.updateFromSliderValues();

            app.VisibleCheckBox = uicheckbox(app.ControlGrid, Text="Visible", ...
                Value=true, ValueChangedFcn=@(~, event) app.visibleChanged(event));
            app.VisibleCheckBox.Layout.Row = [1 2];
            app.VisibleCheckBox.Layout.Column = 6;

            blendLabel = uilabel(app.ControlGrid, Text="Blend");
            blendLabel.Layout.Row = 1;
            blendLabel.Layout.Column = 7;
            app.BlendModeDropDown = uidropdown(app.ControlGrid, ...
                Items=["alpha", "redBlueAnaglyph"], ...
                Value="alpha", ...
                ValueChangedFcn=@(~, event) app.blendModeChanged(event));
            app.BlendModeDropDown.Layout.Row = 2;
            app.BlendModeDropDown.Layout.Column = 7;

            app.CycleButton = uibutton(app.ControlGrid, Text="Cycle", ...
                ButtonPushedFcn=@(~, ~) app.cycleLayer());
            app.CycleButton.Layout.Row = [1 2];
            app.CycleButton.Layout.Column = 8;

            app.ResetButton = uibutton(app.ControlGrid, Text="Reset", ...
                ButtonPushedFcn=@(~, ~) app.resetView());
            app.ResetButton.Layout.Row = [1 2];
            app.ResetButton.Layout.Column = 9;
        end

        function createSurface(app)
            hold(app.Axes, "on");
            app.Surfaces = cell(1, numel(app.Scene.layers));
            for layerIndex = 1:numel(app.Scene.layers)
                layer = app.Scene.layers(layerIndex);
                mesh = ProjectionMeshBuilder.buildLayerMesh( ...
                    layer, layer.CurrentProjectionPlane, app.Scene.renderOrigin);
                app.Surfaces{layerIndex} = surface(app.Axes, mesh.X, mesh.Y, ...
                    mesh.Z, mesh.Texture, FaceColor="texturemap", EdgeColor="none", ...
                    FaceAlpha=mesh.Alpha, Visible=app.onOff(layer.Visible));
                if layerIndex == app.SelectedLayerIndex
                    app.Surface = app.Surfaces{layerIndex};
                    app.CurrentMesh = mesh;
                end
            end
            hold(app.Axes, "off");
            axis(app.Axes, "equal");
            axis(app.Axes, "tight");
            grid(app.Axes, "off");
        end

        function configureFrameCamera(app)
            camera = app.Scene.frameCamera;
            renderOrigin = app.Scene.renderOrigin;
            target = app.Scene.layers(1).BaseProjectionPlane.P0 - renderOrigin;
            cameraPosition = camera.G0 - renderOrigin;
            upVector = camera.focalPlane.basis(:, 2);

            camproj(app.Axes, "orthographic");
            campos(app.Axes, cameraPosition.');
            camtarget(app.Axes, target.');
            camup(app.Axes, upVector.');
        end

        function scrollZoom(app, event)
            if ~app.isPointerInAxes()
                return
            end

            zoomFactor = 1.12 ^ event.VerticalScrollCount;
            newAngle = app.Axes.CameraViewAngle * zoomFactor;
            newAngle = min(max(newAngle, app.MinCameraViewAngle), app.MaxCameraViewAngle);
            app.Axes.CameraViewAngle = newAngle;
            drawnow limitrate
        end

        function beginPan(app)
            if ~app.isPointerInAxes() || app.UIFigure.SelectionType ~= "normal"
                return
            end

            app.IsPanning = true;
            app.LastPointerLocation = app.UIFigure.CurrentPoint;
        end

        function updatePan(app)
            if ~app.IsPanning
                return
            end

            currentPoint = app.UIFigure.CurrentPoint;
            pixelDelta = currentPoint - app.LastPointerLocation;
            if all(pixelDelta == 0)
                return
            end

            app.LastPointerLocation = currentPoint;
            panOffset = app.pixelDeltaToWorldPan(pixelDelta);
            campos(app.Axes, campos(app.Axes) + panOffset.');
            camtarget(app.Axes, camtarget(app.Axes) + panOffset.');
            drawnow limitrate
        end

        function endPan(app)
            app.IsPanning = false;
            app.LastPointerLocation = [NaN NaN];
        end

        function panOffset = pixelDeltaToWorldPan(app, pixelDelta)
            axesPosition = app.Axes.InnerPosition;
            widthPixels = max(axesPosition(3), 1);
            heightPixels = max(axesPosition(4), 1);

            cameraPosition = campos(app.Axes).';
            cameraTarget = camtarget(app.Axes).';
            viewDirection = cameraTarget - cameraPosition;
            viewDistance = norm(viewDirection);
            viewDirection = viewDirection / viewDistance;
            upVector = camup(app.Axes).';
            upVector = upVector / norm(upVector);
            rightVector = cross(viewDirection, upVector);
            rightVector = rightVector / norm(rightVector);

            viewHeight = 2 * viewDistance * tan(deg2rad(app.Axes.CameraViewAngle) / 2);
            viewWidth = viewHeight * widthPixels / heightPixels;
            panOffset = -pixelDelta(1) / widthPixels * viewWidth * rightVector - ...
                pixelDelta(2) / heightPixels * viewHeight * upVector;
        end

        function tf = isPointerInAxes(app)
            pointer = app.UIFigure.CurrentPoint;
            axesPosition = app.Axes.InnerPosition;
            tf = pointer(1) >= axesPosition(1) && ...
                pointer(1) <= axesPosition(1) + axesPosition(3) && ...
                pointer(2) >= axesPosition(2) && ...
                pointer(2) <= axesPosition(2) + axesPosition(4);
        end

        function sliderChanging(app, source, event, sliderName)
            tipDegrees = app.LayerTipDegrees(app.SelectedLayerIndex);
            tiltDegrees = app.LayerTiltDegrees(app.SelectedLayerIndex);
            twistDegrees = app.LayerTwistDegrees(app.SelectedLayerIndex);
            alpha = app.Scene.layers(app.SelectedLayerIndex).Alpha;

            switch sliderName
                case "tip"
                    tipDegrees = event.Value;
                case "tilt"
                    tiltDegrees = event.Value;
                case "twist"
                    twistDegrees = event.Value;
                case "alpha"
                    alpha = event.Value;
            end

            source.Value = event.Value;
            app.updateLabels(tipDegrees, tiltDegrees, twistDegrees, alpha);
            if toc(app.PreviewTimer) < app.MinPreviewInterval
                return
            end

            app.PreviewTimer = tic;
            app.updateProjection(tipDegrees, tiltDegrees, twistDegrees, alpha, ...
                app.DragMeshSampling);
        end

        function updateFromSliderValues(app)
            app.updateProjection(app.TipSlider.Value, app.TiltSlider.Value, ...
                app.TwistSlider.Value, app.AlphaSlider.Value, app.DefaultMeshSampling);
            app.PreviewTimer = tic;
        end

        function updateProjection(app, tipDegrees, tiltDegrees, twistDegrees, alpha, meshSampling)
            if nargin < 6
                meshSampling = app.DefaultMeshSampling;
            end

            layerIndex = app.SelectedLayerIndex;
            layer = app.Scene.layers(layerIndex);
            plane = ProjectionMeshBuilder.applyPlaneTipTilt( ...
                layer.BaseProjectionPlane, deg2rad(tipDegrees), ...
                deg2rad(tiltDegrees), deg2rad(twistDegrees));
            layer.CurrentProjectionPlane = plane;
            layer.Alpha = alpha;
            layer.MeshSampling = meshSampling;
            app.Scene.layers(layerIndex) = layer;
            app.LayerTipDegrees(layerIndex) = tipDegrees;
            app.LayerTiltDegrees(layerIndex) = tiltDegrees;
            app.LayerTwistDegrees(layerIndex) = twistDegrees;

            app.CurrentMesh = ProjectionMeshBuilder.buildLayerMesh( ...
                layer, plane, app.Scene.renderOrigin);
            app.Surface = app.Surfaces{layerIndex};
            app.Surface.XData = app.CurrentMesh.X;
            app.Surface.YData = app.CurrentMesh.Y;
            app.Surface.ZData = app.CurrentMesh.Z;
            app.Surface.FaceAlpha = app.CurrentMesh.Alpha;
            app.Surface.Visible = app.onOff(layer.Visible);
            app.updateLabels(tipDegrees, tiltDegrees, twistDegrees, alpha);
            drawnow limitrate
        end

        function updateLabels(app, tipDegrees, tiltDegrees, twistDegrees, alpha)
            app.TipLabel.Text = sprintf("Tip %.1f deg", tipDegrees);
            app.TiltLabel.Text = sprintf("Tilt %.1f deg", tiltDegrees);
            app.TwistLabel.Text = sprintf("Twist %.1f deg", twistDegrees);
            app.AlphaLabel.Text = sprintf("Alpha %.2f", alpha);
        end

        function resetView(app)
            app.TipSlider.Value = 0;
            app.TiltSlider.Value = 0;
            app.TwistSlider.Value = 0;
            app.AlphaSlider.Value = 1;
            app.updateProjection(0, 0, 0, 1, app.DefaultMeshSampling);
            app.configureFrameCamera();
        end

        function meshSampling = createDragMeshSampling(app)
            imageSize = app.Scene.layers(app.SelectedLayerIndex).SourceGeometry.ImageSize;
            rowStride = max(1, app.DefaultMeshSampling.RowStride * 2);
            columnStride = max(1, app.DefaultMeshSampling.ColumnStride * 2);
            meshSampling = ProjectionViewerHarness.createMeshSampling( ...
                imageSize, rowStride, columnStride);
        end

        function layerSelectionChanged(app, event)
            app.SelectedLayerIndex = event.Value;
            app.updateControlsFromSelectedLayer();
        end

        function visibleChanged(app, event)
            layer = app.Scene.layers(app.SelectedLayerIndex);
            layer.Visible = logical(event.Value);
            app.Scene.layers(app.SelectedLayerIndex) = layer;
            app.Surfaces{app.SelectedLayerIndex}.Visible = app.onOff(layer.Visible);
        end

        function blendModeChanged(app, event)
            layer = app.Scene.layers(app.SelectedLayerIndex);
            layer.BlendMode = string(event.Value);
            app.Scene.layers(app.SelectedLayerIndex) = layer;
        end

        function cycleLayer(app)
            [app.Scene, app.SelectedLayerIndex] = ProjectionLayerManager.cycleActiveLayer(app.Scene);
            for layerIndex = 1:numel(app.Scene.layers)
                layer = app.Scene.layers(layerIndex);
                app.Surfaces{layerIndex}.FaceAlpha = layer.Alpha;
                app.Surfaces{layerIndex}.Visible = app.onOff(layer.Visible);
            end
            app.updateControlsFromSelectedLayer();
        end

        function updateControlsFromSelectedLayer(app)
            layer = app.Scene.layers(app.SelectedLayerIndex);
            app.LayerDropDown.Value = app.SelectedLayerIndex;
            app.TipSlider.Value = app.LayerTipDegrees(app.SelectedLayerIndex);
            app.TiltSlider.Value = app.LayerTiltDegrees(app.SelectedLayerIndex);
            app.TwistSlider.Value = app.LayerTwistDegrees(app.SelectedLayerIndex);
            app.AlphaSlider.Value = layer.Alpha;
            app.VisibleCheckBox.Value = layer.Visible;
            app.BlendModeDropDown.Value = string(layer.BlendMode);
            app.Surface = app.Surfaces{app.SelectedLayerIndex};
            app.updateLabels(app.TipSlider.Value, app.TiltSlider.Value, ...
                app.TwistSlider.Value, layer.Alpha);
        end

        function names = layerDisplayNames(app)
            layers = app.Scene.layers;
            names = strings(1, numel(layers));
            for layerIndex = 1:numel(layers)
                names(layerIndex) = sprintf("%d: %s", layerIndex, layers(layerIndex).Name);
            end
        end

        function value = onOff(~, isVisible)
            if isVisible
                value = "on";
            else
                value = "off";
            end
        end
    end
end
