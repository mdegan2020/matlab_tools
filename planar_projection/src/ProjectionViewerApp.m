classdef ProjectionViewerApp < handle
    %ProjectionViewerApp Programmatic preview app for projected imagery.

    properties (Access = private)
        Scene struct
        CurrentMesh struct
        Surfaces cell
        DefaultMeshSampling struct
        DragMeshSampling struct
        ProjectionTipDegrees double = 0
        ProjectionTiltDegrees double = 0
        ViewTwistDegrees double = 0
        SelectedLayerIndex double = 1
        IsPanning logical = false
        IsControlDown logical = false
        IsShiftDown logical = false
        IsAltDown logical = false
        LastPointerLocation double = [NaN NaN]
        PreviewTimer
        MinPreviewInterval double = 1 / 30
        MinCameraViewAngle double = 0.05
        MaxCameraViewAngle double = 60
        ModifierWheelStepDegrees double = 1
        PreviewLayerDepthStepFraction double = 1e-4
        PreviewLayerDepthMinimumStepMeters double = 0.5
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
        function app = ProjectionViewerApp(scene, projectionPlane)
            if nargin < 1
                scene = ProjectionViewerHarness.createDefaultScene();
            end
            if nargin >= 2 && ~isempty(projectionPlane)
                scene = ProjectionViewerHarness.applyProjectionPlane(scene, projectionPlane);
            end

            app.Scene = scene;
            app.DefaultMeshSampling = [app.Scene.layers.MeshSampling];
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
                WindowScrollWheelFcn=@(~, event) app.scrollWheel(event), ...
                WindowKeyPressFcn=@(~, event) app.keyPressed(event), ...
                WindowKeyReleaseFcn=@(~, event) app.keyReleased(event), ...
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
            app.Axes.Toolbar.Visible = "off";
            app.Axes.Interactions = [];
            app.hideImageAxesDecorations();

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
                app.twistChanging(source, event);
            app.TwistSlider.ValueChangedFcn = @(~, ~) app.updateViewTwistFromSlider();

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
                [X, Y, Z] = app.previewSurfaceCoordinates(mesh, layerIndex);
                app.Surfaces{layerIndex} = surface(app.Axes, X, Y, ...
                    Z, mesh.Texture, FaceColor="texturemap", EdgeColor="none", ...
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
            app.stabilizeAxesLimits();
            app.hideImageAxesDecorations();
        end

        function hideImageAxesDecorations(app)
            title(app.Axes, "");
            xlabel(app.Axes, "");
            ylabel(app.Axes, "");
            zlabel(app.Axes, "");
            app.Axes.XTick = [];
            app.Axes.YTick = [];
            app.Axes.ZTick = [];
            app.Axes.Box = "off";
            app.Axes.Visible = "off";
            app.Axes.Toolbar.Visible = "off";
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
            app.applyViewTwist();
        end

        function twistChanging(app, source, event)
            source.Value = event.Value;
            app.updateViewTwist(event.Value);
        end

        function updateViewTwistFromSlider(app)
            app.updateViewTwist(app.TwistSlider.Value);
        end

        function updateViewTwist(app, twistDegrees)
            app.ViewTwistDegrees = twistDegrees;
            app.applyViewTwist();

            layer = app.Scene.layers(app.SelectedLayerIndex);
            app.updateLabels(app.ProjectionTipDegrees, ...
                app.ProjectionTiltDegrees, ...
                app.ViewTwistDegrees, layer.Alpha);
            drawnow limitrate
        end

        function applyViewTwist(app)
            cameraViewAngle = app.Axes.CameraViewAngle;
            baseUpVector = app.Scene.frameCamera.focalPlane.basis(:, 2);
            viewDirection = camtarget(app.Axes).' - campos(app.Axes).';
            upVector = app.rotateVectorAboutAxis( ...
                baseUpVector, viewDirection, deg2rad(app.ViewTwistDegrees));
            camup(app.Axes, upVector.');
            app.Axes.CameraViewAngle = cameraViewAngle;
        end

        function keyPressed(app, event)
            if app.eventHasControl(event)
                app.IsControlDown = true;
            end
            if app.eventHasShift(event)
                app.IsShiftDown = true;
            end
            if app.eventHasAlt(event)
                app.IsAltDown = true;
            end
        end

        function keyReleased(app, event)
            if app.eventKeyIs(event, "control")
                app.IsControlDown = false;
            end
            if app.eventKeyIs(event, "shift")
                app.IsShiftDown = false;
            end
            if app.eventKeyIs(event, ["alt", "option"])
                app.IsAltDown = false;
            end
        end

        function scrollWheel(app, event)
            if app.IsControlDown || app.eventHasControl(event)
                app.scrollTwist(event);
                return
            end
            if app.IsShiftDown || app.eventHasShift(event)
                app.scrollTip(event);
                return
            end
            if app.IsAltDown || app.eventHasAlt(event)
                app.scrollTilt(event);
                return
            end
            app.scrollZoom(event);
        end

        function scrollTwist(app, event)
            twistDegrees = app.sliderWheelValue(app.TwistSlider, event);
            app.TwistSlider.Value = twistDegrees;
            app.updateViewTwist(twistDegrees);
        end

        function scrollTip(app, event)
            tipDegrees = app.sliderWheelValue(app.TipSlider, event);
            app.TipSlider.Value = tipDegrees;
            app.updateProjection(tipDegrees, app.TiltSlider.Value, ...
                app.AlphaSlider.Value, app.DefaultMeshSampling);
            app.PreviewTimer = tic;
        end

        function scrollTilt(app, event)
            tiltDegrees = app.sliderWheelValue(app.TiltSlider, event);
            app.TiltSlider.Value = tiltDegrees;
            app.updateProjection(app.TipSlider.Value, tiltDegrees, ...
                app.AlphaSlider.Value, app.DefaultMeshSampling);
            app.PreviewTimer = tic;
        end

        function value = sliderWheelValue(app, slider, event)
            value = slider.Value - ...
                event.VerticalScrollCount * app.ModifierWheelStepDegrees;
            limits = slider.Limits;
            value = min(max(value, limits(1)), limits(2));
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

        function rotatedVector = rotateVectorAboutAxis(~, vector, axis, angle)
            vector = vector(:);
            axis = axis(:) / norm(axis);
            K = [0 -axis(3) axis(2); axis(3) 0 -axis(1); -axis(2) axis(1) 0];
            R = cos(angle) * eye(3) + (1 - cos(angle)) * (axis * axis.') + sin(angle) * K;
            rotatedVector = R * vector;
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
            tipDegrees = app.ProjectionTipDegrees;
            tiltDegrees = app.ProjectionTiltDegrees;
            alpha = app.Scene.layers(app.SelectedLayerIndex).Alpha;

            switch sliderName
                case "tip"
                    tipDegrees = event.Value;
                case "tilt"
                    tiltDegrees = event.Value;
                case "alpha"
                    alpha = event.Value;
            end

            source.Value = event.Value;
            app.updateLabels(tipDegrees, tiltDegrees, app.ViewTwistDegrees, alpha);
            if toc(app.PreviewTimer) < app.MinPreviewInterval
                return
            end

            app.PreviewTimer = tic;
            app.updateProjection(tipDegrees, tiltDegrees, alpha, ...
                app.DragMeshSampling);
        end

        function updateFromSliderValues(app)
            app.updateProjection(app.TipSlider.Value, app.TiltSlider.Value, ...
                app.AlphaSlider.Value, app.DefaultMeshSampling);
            app.PreviewTimer = tic;
        end

        function updateProjection(app, tipDegrees, tiltDegrees, alpha, meshSamplings)
            selectedLayerIndex = app.SelectedLayerIndex;
            if nargin < 5
                meshSamplings = app.DefaultMeshSampling;
            end

            app.ProjectionTipDegrees = tipDegrees;
            app.ProjectionTiltDegrees = tiltDegrees;
            plane = ProjectionMeshBuilder.applyPlaneTipTilt( ...
                app.Scene.layers(1).BaseProjectionPlane, ...
                deg2rad(tipDegrees), deg2rad(tiltDegrees));

            for layerIndex = 1:numel(app.Scene.layers)
                layer = app.Scene.layers(layerIndex);
                layer.CurrentProjectionPlane = plane;
                if layerIndex == selectedLayerIndex
                    layer.Alpha = alpha;
                end
                layer.MeshSampling = meshSamplings(layerIndex);
                app.Scene.layers(layerIndex) = layer;

                mesh = ProjectionMeshBuilder.buildLayerMesh( ...
                    layer, plane, app.Scene.renderOrigin);
                app.updateSurfaceFromMesh(layerIndex, mesh);
                if layerIndex == selectedLayerIndex
                    app.CurrentMesh = mesh;
                    app.Surface = app.Surfaces{layerIndex};
                end
            end

            app.updateLabels(tipDegrees, tiltDegrees, app.ViewTwistDegrees, alpha);
            drawnow limitrate
        end

        function updateSurfaceFromMesh(app, layerIndex, mesh)
            surfaceHandle = app.Surfaces{layerIndex};
            [X, Y, Z] = app.previewSurfaceCoordinates(mesh, layerIndex);
            surfaceHandle.XData = X;
            surfaceHandle.YData = Y;
            surfaceHandle.ZData = Z;
            surfaceHandle.CData = mesh.Texture;
            surfaceHandle.FaceAlpha = mesh.Alpha;
            surfaceHandle.Visible = app.onOff(mesh.Visible);
        end

        function [X, Y, Z] = previewSurfaceCoordinates(app, mesh, layerIndex)
            offset = app.previewLayerDepthOffset(layerIndex);
            X = mesh.X + offset(1);
            Y = mesh.Y + offset(2);
            Z = mesh.Z + offset(3);
        end

        function offset = previewLayerDepthOffset(app, layerIndex)
            layerCount = numel(app.Scene.layers);
            depthStep = app.previewLayerDepthStepMeters();
            if layerCount < 2 || depthStep == 0
                offset = [0; 0; 0];
                return
            end

            centeredLayerIndex = double(layerIndex) - (double(layerCount) + 1) / 2;
            offset = -centeredLayerIndex * depthStep * ...
                app.frameCameraViewDirection();
        end

        function depthStep = previewLayerDepthStepMeters(app)
            depthStep = max(app.PreviewLayerDepthMinimumStepMeters, ...
                app.PreviewLayerDepthStepFraction * app.frameCameraRange());
        end

        function viewDirection = frameCameraViewDirection(app)
            cameraPosition = app.Scene.frameCamera.G0 - app.Scene.renderOrigin;
            target = app.Scene.layers(1).BaseProjectionPlane.P0 - app.Scene.renderOrigin;
            viewDirection = target - cameraPosition;
            viewDirection = viewDirection / norm(viewDirection);
        end

        function range = frameCameraRange(app)
            cameraPosition = app.Scene.frameCamera.G0 - app.Scene.renderOrigin;
            target = app.Scene.layers(1).BaseProjectionPlane.P0 - app.Scene.renderOrigin;
            range = norm(target - cameraPosition);
        end

        function stabilizeAxesLimits(app)
            radius = 0;
            for layerIndex = 1:numel(app.Surfaces)
                surfaceHandle = app.Surfaces{layerIndex};
                points = [surfaceHandle.XData(:).'; ...
                    surfaceHandle.YData(:).'; surfaceHandle.ZData(:).'];
                radius = max(radius, max(vecnorm(points, 2, 1)));
            end

            if ~isfinite(radius) || radius <= 0
                radius = 1;
            end

            limit = 1.02 * radius + ...
                numel(app.Scene.layers) * app.previewLayerDepthStepMeters();
            app.Axes.XLim = [-limit limit];
            app.Axes.YLim = [-limit limit];
            app.Axes.ZLim = [-limit limit];
            app.Axes.XLimMode = "manual";
            app.Axes.YLimMode = "manual";
            app.Axes.ZLimMode = "manual";
            app.Axes.DataAspectRatio = [1 1 1];
            app.Axes.DataAspectRatioMode = "manual";
            app.Axes.PlotBoxAspectRatioMode = "auto";
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
            app.ViewTwistDegrees = 0;
            app.updateProjection(0, 0, 1, app.DefaultMeshSampling);
            app.configureFrameCamera();
        end

        function meshSamplings = createDragMeshSampling(app)
            for layerIndex = 1:numel(app.Scene.layers)
                imageSize = app.Scene.layers(layerIndex).SourceGeometry.ImageSize;
                layerSampling = app.DefaultMeshSampling(layerIndex);
                rowStride = max(1, layerSampling.RowStride * 2);
                columnStride = max(1, layerSampling.ColumnStride * 2);
                meshSampling = ProjectionViewerHarness.createMeshSampling( ...
                    imageSize, rowStride, columnStride);
                if layerIndex == 1
                    meshSamplings = meshSampling;
                else
                    meshSamplings(layerIndex) = meshSampling;
                end
            end
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
            app.TipSlider.Value = app.ProjectionTipDegrees;
            app.TiltSlider.Value = app.ProjectionTiltDegrees;
            app.TwistSlider.Value = app.ViewTwistDegrees;
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

        function tf = eventHasControl(app, event)
            tf = app.eventKeyIs(event, "control") || ...
                app.eventModifierIs(event, "control");
        end

        function tf = eventHasShift(app, event)
            tf = app.eventKeyIs(event, "shift") || ...
                app.eventModifierIs(event, "shift");
        end

        function tf = eventHasAlt(app, event)
            tf = app.eventKeyIs(event, ["alt", "option"]) || ...
                app.eventModifierIs(event, ["alt", "option"]);
        end

        function tf = eventKeyIs(app, event, key)
            tf = any(ismember(app.eventStringValue(event, "Key"), string(key)));
        end

        function tf = eventModifierIs(app, event, modifier)
            tf = any(ismember(app.eventStringValue(event, "Modifier"), string(modifier)));
        end

        function value = eventStringValue(~, event, propertyName)
            propertyName = char(propertyName);
            if isstruct(event) && isfield(event, propertyName)
                rawValue = event.(propertyName);
            elseif isobject(event) && isprop(event, propertyName)
                rawValue = event.(propertyName);
            else
                value = strings(1, 0);
                return
            end

            value = lower(string(rawValue));
        end
    end
end
