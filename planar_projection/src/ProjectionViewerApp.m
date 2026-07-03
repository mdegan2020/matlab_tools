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
        IsControlDown logical = false
        IsShiftDown logical = false
        IsAltDown logical = false
        DragMode string = "none"
        LastPointerLocation double = [NaN NaN]
        NeedsDragFinalize logical = false
        PreviewTimer
        MinPreviewInterval double = 1 / 30
        MinCameraViewAngle double = 0.05
        MaxCameraViewAngle double = 60
        ModifierWheelStepDegrees double = 1
        ViewVectorDragProbeDegrees double = 0.01
        MinDragScreenJacobianRcond double = 1e-12
        FallbackViewVectorCorrectionStepDegrees double = 0.1
        KappaViewVectorCorrectionStepDegrees double = 0.1
        MinViewVectorIfovRadians double = 1e-12
        PreviewLayerDepthStepFraction double = 1e-4
        PreviewLayerDepthMinimumStepMeters double = 0.5
        MinProjectedNudgeNorm double = 1e-9
        UIFigure matlab.ui.Figure
        HelpFigure matlab.ui.Figure
        GridLayout matlab.ui.container.GridLayout
        Axes matlab.ui.control.UIAxes
        Surface
        ControlGrid matlab.ui.container.GridLayout
        LayerStyleGrid matlab.ui.container.GridLayout
        ImageContextMenu
        SaveMenuItem
        LoadMenuItem
        CycleMenuItem
        ResetMenuItem
        HelpMenuItem
        CrosshairMenuItem
        CrosshairHorizontal
        CrosshairVertical
        TipSlider matlab.ui.control.Slider
        TiltSlider matlab.ui.control.Slider
        TwistSlider matlab.ui.control.Slider
        AlphaSlider matlab.ui.control.Slider
        TipLabel matlab.ui.control.Label
        TiltLabel matlab.ui.control.Label
        TwistLabel matlab.ui.control.Label
        AlphaLabel matlab.ui.control.Label
        ViewVectorLabel matlab.ui.control.Label
        LayerDropDown matlab.ui.control.DropDown
        VisibleCheckBox matlab.ui.control.CheckBox
        BlendModeDropDown matlab.ui.control.DropDown
        IsCrosshairEnabled logical = false
    end

    methods
        function app = ProjectionViewerApp(scene, projectionPlane, viewerState)
            if nargin < 1
                scene = ProjectionViewerHarness.createDefaultScene();
            end
            if nargin < 2
                projectionPlane = [];
            end
            if nargin < 3
                viewerState = [];
            end
            if ~isempty(projectionPlane) && ProjectionViewerState.isState(projectionPlane)
                viewerState = projectionPlane;
                projectionPlane = [];
            end
            if nargin >= 2 && ~isempty(projectionPlane)
                scene = ProjectionViewerHarness.applyProjectionPlane(scene, projectionPlane);
            end

            app.Scene = scene;
            app.SelectedLayerIndex = numel(app.Scene.layers);
            app.DefaultMeshSampling = [app.Scene.layers.MeshSampling];
            app.DragMeshSampling = app.createDragMeshSampling();
            app.PreviewTimer = tic;
            if ~isempty(viewerState)
                viewerState = ProjectionViewerState.validate( ...
                    viewerState, numel(app.Scene.layers));
                app.applyViewerStateToScene(viewerState);
            end
            app.createComponents();
            app.createSurface();
            app.configureFrameCamera();
            if ~isempty(viewerState) && isfield(viewerState, "Camera")
                app.applyCameraState(viewerState.Camera);
            end
            app.updateControlsFromSelectedLayer();

            if nargout == 0
                clear app
            end
        end

        function delete(app)
            if ~isempty(app.UIFigure) && isvalid(app.UIFigure)
                delete(app.UIFigure);
            end
            if ~isempty(app.HelpFigure) && isvalid(app.HelpFigure)
                delete(app.HelpFigure);
            end
        end

        function state = exportState(app)
            %exportState Return a JSON-serializable snapshot of viewer state.
            state = struct();
            state.Format = ProjectionViewerState.Format;
            state.Version = ProjectionViewerState.Version;
            state.LayerCount = numel(app.Scene.layers);
            state.SelectedLayerIndex = app.SelectedLayerIndex;
            state.Projection = struct();
            state.Projection.TipDegrees = app.ProjectionTipDegrees;
            state.Projection.TiltDegrees = app.ProjectionTiltDegrees;
            state.View = struct();
            state.View.TwistDegrees = app.ViewTwistDegrees;
            state.Camera = app.exportCameraState();

            for layerIndex = 1:numel(app.Scene.layers)
                layerState = app.exportLayerState(layerIndex);
                if layerIndex == 1
                    layers = layerState;
                else
                    layers(layerIndex) = layerState;
                end
            end
            state.Layers = layers;
            state = ProjectionViewerState.validate(state, numel(app.Scene.layers));
        end

        function importState(app, state)
            %importState Apply a validated viewer state to the app.
            state = ProjectionViewerState.validate(state, numel(app.Scene.layers));
            app.applyViewerStateToScene(state);
            app.refreshProjectionSurfaces(app.DefaultMeshSampling);
            app.configureFrameCamera();
            if isfield(state, "Camera")
                app.applyCameraState(state.Camera);
            end
            app.updateControlsFromSelectedLayer();
            drawnow limitrate
        end

        function saveState(app, filePath)
            %saveState Write the current viewer state to a JSON file.
            ProjectionViewerState.write(filePath, app.exportState());
        end

        function state = loadState(app, filePath)
            %loadState Read and apply a viewer state JSON file.
            state = ProjectionViewerState.read(filePath, numel(app.Scene.layers));
            app.importState(state);
        end

        function job = exportBackendJob(app, options)
            %exportBackendJob Return a backend job for the current app state.
            if nargin < 2
                options = struct();
            end
            if isempty(options)
                options = struct();
            end
            if ~isstruct(options) || ~isscalar(options)
                error("ProjectionViewerApp:invalidBackendJobOptions", ...
                    "Backend job options must be a scalar struct.");
            end
            options.ViewerState = app.exportState();
            job = ProjectionBackendJob.create(app.Scene, options);
        end

        function writeBackendJob(app, filePath, options)
            %writeBackendJob Write the current app state as a backend job.
            if nargin < 3
                options = struct();
            end
            ProjectionBackendJob.write(filePath, app.exportBackendJob(options));
        end
    end

    methods (Access = private)
        function createComponents(app)
            app.UIFigure = uifigure(Name="Projection Viewer Prototype", ...
                Position=[100 100 1100 760], ...
                WindowScrollWheelFcn=@(~, event) app.scrollWheel(event), ...
                WindowKeyPressFcn=@(~, event) app.keyPressed(event), ...
                WindowKeyReleaseFcn=@(~, event) app.keyReleased(event), ...
                WindowButtonDownFcn=@(~, event) app.beginPan(event), ...
                WindowButtonMotionFcn=@(~, ~) app.pointerMoved(), ...
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
            app.createImageContextMenu();
            app.createCrosshairOverlay();

            app.ControlGrid = uigridlayout(app.GridLayout, [2 7]);
            app.ControlGrid.Layout.Row = 2;
            app.ControlGrid.Layout.Column = 1;
            app.ControlGrid.RowHeight = {"fit", "fit"};
            app.ControlGrid.ColumnWidth = {420, "1x", "1x", "1x", "1x", ...
                "fit", "fit"};
            app.ControlGrid.Padding = [0 0 0 0];
            app.ControlGrid.ColumnSpacing = 12;

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
            app.TipSlider = uislider(app.ControlGrid, Limits=[-45 45], Value=0);
            app.TipSlider.Layout.Row = 2;
            app.TipSlider.Layout.Column = 2;
            app.TipSlider.MajorTicks = -45:15:45;
            app.TipSlider.ValueChangingFcn = @(source, event) ...
                app.sliderChanging(source, event, "tip");
            app.TipSlider.ValueChangedFcn = @(~, ~) app.updateFromSliderValues();

            app.TiltLabel = uilabel(app.ControlGrid, Text="Tilt 0.0 deg");
            app.TiltLabel.Layout.Row = 1;
            app.TiltLabel.Layout.Column = 3;
            app.TiltSlider = uislider(app.ControlGrid, Limits=[-45 45], Value=0);
            app.TiltSlider.Layout.Row = 2;
            app.TiltSlider.Layout.Column = 3;
            app.TiltSlider.MajorTicks = -45:15:45;
            app.TiltSlider.ValueChangingFcn = @(source, event) ...
                app.sliderChanging(source, event, "tilt");
            app.TiltSlider.ValueChangedFcn = @(~, ~) app.updateFromSliderValues();

            app.TwistLabel = uilabel(app.ControlGrid, Text="Twist 0.0 deg");
            app.TwistLabel.Layout.Row = 1;
            app.TwistLabel.Layout.Column = 4;
            app.TwistSlider = uislider(app.ControlGrid, Limits=[-45 45], Value=0);
            app.TwistSlider.Layout.Row = 2;
            app.TwistSlider.Layout.Column = 4;
            app.TwistSlider.MajorTicks = -45:15:45;
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
                app.alphaChanging(source, event);
            app.AlphaSlider.ValueChangedFcn = @(~, ~) app.updateAlphaFromSlider();

            app.ViewVectorLabel = uilabel(app.ControlGrid, ...
                Text=sprintf("Omega 0.0000 deg\nPhi 0.0000 deg\nKappa 0.000 deg"));
            app.ViewVectorLabel.Layout.Row = [1 2];
            app.ViewVectorLabel.Layout.Column = 6;

            app.LayerStyleGrid = uigridlayout(app.ControlGrid, [2 1]);
            app.LayerStyleGrid.Layout.Row = [1 2];
            app.LayerStyleGrid.Layout.Column = 7;
            app.LayerStyleGrid.RowHeight = {"fit", "fit"};
            app.LayerStyleGrid.ColumnWidth = {"fit"};
            app.LayerStyleGrid.Padding = [0 0 0 0];
            app.LayerStyleGrid.RowSpacing = 4;

            app.VisibleCheckBox = uicheckbox(app.LayerStyleGrid, Text="Visible", ...
                Value=true, ValueChangedFcn=@(~, event) app.visibleChanged(event));
            app.VisibleCheckBox.Layout.Row = 1;
            app.VisibleCheckBox.Layout.Column = 1;

            app.BlendModeDropDown = uidropdown(app.LayerStyleGrid, ...
                Items=["alpha", "redBlueAnaglyph"], ...
                Value="alpha", ...
                ValueChangedFcn=@(~, event) app.blendModeChanged(event));
            app.BlendModeDropDown.Layout.Row = 2;
            app.BlendModeDropDown.Layout.Column = 1;
        end

        function createImageContextMenu(app)
            app.ImageContextMenu = uicontextmenu(app.UIFigure);
            app.SaveMenuItem = uimenu(app.ImageContextMenu, Text="Save", ...
                MenuSelectedFcn=@(~, ~) app.saveStateFromDialog(), ...
                Tag="ProjectionViewerSaveMenuItem");
            app.LoadMenuItem = uimenu(app.ImageContextMenu, Text="Load", ...
                MenuSelectedFcn=@(~, ~) app.loadStateFromDialog(), ...
                Tag="ProjectionViewerLoadMenuItem");
            app.CycleMenuItem = uimenu(app.ImageContextMenu, Text="Cycle", ...
                MenuSelectedFcn=@(~, ~) app.cycleLayer(), ...
                Tag="ProjectionViewerCycleMenuItem");
            app.ResetMenuItem = uimenu(app.ImageContextMenu, Text="Reset", ...
                MenuSelectedFcn=@(~, ~) app.resetView(), ...
                Tag="ProjectionViewerResetMenuItem");
            app.HelpMenuItem = uimenu(app.ImageContextMenu, Text="Help", ...
                Separator="on", MenuSelectedFcn=@(~, ~) app.showHelpDialog(), ...
                Tag="ProjectionViewerHelpMenuItem");
            app.CrosshairMenuItem = uimenu(app.ImageContextMenu, ...
                Text="Crosshair", Checked="off", ...
                MenuSelectedFcn=@(~, ~) app.toggleCrosshair(), ...
                Tag="ProjectionViewerCrosshairMenuItem");
            app.Axes.ContextMenu = app.ImageContextMenu;
        end

        function createCrosshairOverlay(app)
            app.CrosshairHorizontal = annotation(app.UIFigure, "line", ...
                [0 0], [0 0], Color=[0 1 1], LineWidth=1, ...
                Visible="off", Tag="ProjectionViewerCrosshairHorizontal");
            app.CrosshairVertical = annotation(app.UIFigure, "line", ...
                [0 0], [0 0], Color=[0 1 1], LineWidth=1, ...
                Visible="off", Tag="ProjectionViewerCrosshairVertical");
        end

        function layerState = exportLayerState(app, layerIndex)
            layer = app.Scene.layers(layerIndex);
            layerState = struct();
            layerState.Index = layerIndex;
            layerState.Name = string(layer.Name);
            layerState.ImagePath = string(layer.ImagePath);
            layerState.Alpha = layer.Alpha;
            layerState.Visible = logical(layer.Visible);
            layerState.BlendMode = string(layer.BlendMode);
            layerState.ProjectionOffsetMeters = app.layerProjectionOffset(layer).';
            layerState.ViewVectorAngularOffsetsDegrees = ...
                app.layerViewVectorAngularOffsetsDegrees(layer).';
        end

        function cameraState = exportCameraState(app)
            cameraState = struct();
            cameraState.Position = campos(app.Axes);
            cameraState.Target = camtarget(app.Axes);
            cameraState.UpVector = camup(app.Axes);
            cameraState.ViewAngle = app.Axes.CameraViewAngle;
            cameraState.Projection = "orthographic";
        end

        function applyViewerStateToScene(app, state)
            app.SelectedLayerIndex = state.SelectedLayerIndex;
            app.ProjectionTipDegrees = state.Projection.TipDegrees;
            app.ProjectionTiltDegrees = state.Projection.TiltDegrees;
            app.ViewTwistDegrees = state.View.TwistDegrees;
            plane = app.currentProjectionPlane();

            for layerIndex = 1:numel(app.Scene.layers)
                layer = app.Scene.layers(layerIndex);
                layerState = state.Layers(layerIndex);
                layer.Alpha = layerState.Alpha;
                layer.Visible = layerState.Visible;
                layer.BlendMode = string(layerState.BlendMode);
                layer.ProjectionOffsetMeters = layerState.ProjectionOffsetMeters(:);
                layer.ViewVectorAngularOffsetsDegrees = ...
                    layerState.ViewVectorAngularOffsetsDegrees(:);
                layer.CurrentProjectionPlane = plane;
                app.Scene.layers(layerIndex) = layer;
            end
        end

        function plane = currentProjectionPlane(app)
            plane = ProjectionMeshBuilder.applyPlaneTipTilt( ...
                app.Scene.layers(1).BaseProjectionPlane, ...
                deg2rad(app.ProjectionTipDegrees), ...
                deg2rad(app.ProjectionTiltDegrees));
        end

        function applyCameraState(app, cameraState)
            camproj(app.Axes, char(cameraState.Projection));
            campos(app.Axes, cameraState.Position);
            camtarget(app.Axes, cameraState.Target);
            camup(app.Axes, cameraState.UpVector);
            app.Axes.CameraViewAngle = cameraState.ViewAngle;
        end

        function saveStateFromDialog(app)
            [fileName, folderName] = uiputfile("*.json", ...
                "Save Projection Viewer State", "projection_viewer_state.json");
            if isequal(fileName, 0)
                return
            end

            try
                app.saveState(fullfile(folderName, fileName));
            catch ME
                app.showStateFileError("Save Failed", ME);
            end
        end

        function loadStateFromDialog(app)
            [fileName, folderName] = uigetfile("*.json", ...
                "Load Projection Viewer State");
            if isequal(fileName, 0)
                return
            end

            try
                app.loadState(fullfile(folderName, fileName));
            catch ME
                app.showStateFileError("Load Failed", ME);
            end
        end

        function showStateFileError(app, titleText, ME)
            if ~isempty(app.UIFigure) && isvalid(app.UIFigure)
                uialert(app.UIFigure, ME.message, titleText);
            else
                warning("%s: %s", titleText, ME.message);
            end
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
                    FaceAlpha=mesh.Alpha, Visible=app.onOff(layer.Visible), ...
                    ContextMenu=app.ImageContextMenu);
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

        function handled = nudgeSelectedLayerFromKey(app, event)
            handled = false;
            key = app.eventStringValue(event, "Key");
            if isempty(key)
                return
            end

            key = key(1);
            if ~any(key == ["w", "a", "s", "d"])
                return
            end
            handled = true;

            layerIndex = app.SelectedLayerIndex;
            layer = app.Scene.layers(layerIndex);
            plane = layer.CurrentProjectionPlane;
            [worldDirection, stepMeters] = app.layerNudgeWorldDirection(key, layer, plane);
            projectionDelta = plane.basis.' * (stepMeters * worldDirection);
            layer.ProjectionOffsetMeters = app.layerProjectionOffset(layer) + projectionDelta;
            app.Scene.layers(layerIndex) = layer;
            app.updateProjection(app.ProjectionTipDegrees, app.ProjectionTiltDegrees, ...
                layer.Alpha, app.DefaultMeshSampling);
            app.PreviewTimer = tic;
        end

        function [worldDirection, stepMeters] = layerNudgeWorldDirection(app, key, layer, plane)
            upVector = camup(app.Axes).';
            upVector = upVector / norm(upVector);
            viewDirection = camtarget(app.Axes).' - campos(app.Axes).';
            viewDirection = viewDirection / norm(viewDirection);
            rightVector = cross(viewDirection, upVector);
            rightVector = rightVector / norm(rightVector);

            switch key
                case "w"
                    worldDirection = app.projectDirectionToPlane(upVector, plane, plane.basis(:, 2));
                    stepMeters = app.layerVerticalNudgeStepMeters(layer);
                case "s"
                    worldDirection = app.projectDirectionToPlane(-upVector, plane, -plane.basis(:, 2));
                    stepMeters = app.layerVerticalNudgeStepMeters(layer);
                case "a"
                    worldDirection = app.projectDirectionToPlane(-rightVector, plane, -plane.basis(:, 1));
                    stepMeters = app.layerHorizontalNudgeStepMeters(layer);
                case "d"
                    worldDirection = app.projectDirectionToPlane(rightVector, plane, plane.basis(:, 1));
                    stepMeters = app.layerHorizontalNudgeStepMeters(layer);
            end
        end

        function projectedDirection = projectDirectionToPlane(app, direction, plane, fallback)
            projectedDirection = direction - plane.VN * (plane.VN.' * direction);
            directionNorm = norm(projectedDirection);
            if directionNorm <= app.MinProjectedNudgeNorm
                projectedDirection = fallback;
                directionNorm = norm(projectedDirection);
            end
            projectedDirection = projectedDirection / directionNorm;
        end

        function stepMeters = layerVerticalNudgeStepMeters(~, layer)
            stepMeters = 1;
            if isfield(layer.SourceGeometry, "GSD")
                stepMeters = layer.SourceGeometry.GSD;
            end
        end

        function stepMeters = layerHorizontalNudgeStepMeters(~, layer)
            stepMeters = 1;
            if isfield(layer.SourceGeometry, "PlatformStepMeters")
                stepMeters = layer.SourceGeometry.PlatformStepMeters;
            end
        end

        function offset = layerProjectionOffset(~, layer)
            if isfield(layer, "ProjectionOffsetMeters")
                offset = double(layer.ProjectionOffsetMeters(:));
            else
                offset = [0; 0];
            end
        end

        function handled = adjustSelectedLayerViewVectorCorrectionFromKey(app, event)
            handled = false;
            key = app.eventStringValue(event, "Key");
            if isempty(key)
                return
            end

            [componentIndex, direction] = app.viewVectorCorrectionKey(key(1));
            if componentIndex == 0
                return
            end
            handled = true;

            layerIndex = app.SelectedLayerIndex;
            layer = app.Scene.layers(layerIndex);
            offsetsDegrees = app.layerViewVectorAngularOffsetsDegrees(layer);
            offsetsDegrees(componentIndex) = offsetsDegrees(componentIndex) + ...
                direction * app.layerViewVectorCorrectionStepDegrees( ...
                layer, componentIndex);
            layer.ViewVectorAngularOffsetsDegrees = offsetsDegrees;
            app.Scene.layers(layerIndex) = layer;
            app.updateProjection(app.ProjectionTipDegrees, app.ProjectionTiltDegrees, ...
                layer.Alpha, app.DefaultMeshSampling);
            app.PreviewTimer = tic;
        end

        function [componentIndex, direction] = viewVectorCorrectionKey(~, key)
            componentIndex = 0;
            direction = 0;
            switch key
                case "j"
                    componentIndex = 1;
                    direction = -1;
                case "l"
                    componentIndex = 1;
                    direction = 1;
                case "k"
                    componentIndex = 2;
                    direction = -1;
                case "i"
                    componentIndex = 2;
                    direction = 1;
                case "u"
                    componentIndex = 3;
                    direction = -1;
                case "o"
                    componentIndex = 3;
                    direction = 1;
            end
        end

        function offsetsDegrees = layerViewVectorAngularOffsetsDegrees(~, layer)
            if isfield(layer, "ViewVectorAngularOffsetsDegrees")
                offsetsDegrees = double(layer.ViewVectorAngularOffsetsDegrees(:));
            else
                offsetsDegrees = [0; 0; 0];
            end
        end

        function stepDegrees = layerViewVectorCorrectionStepDegrees(app, layer, componentIndex)
            configuredStep = app.configuredViewVectorCorrectionStepDegrees( ...
                layer, componentIndex);
            if ~isempty(configuredStep)
                stepDegrees = configuredStep;
                return
            end

            if componentIndex == 3
                stepDegrees = app.KappaViewVectorCorrectionStepDegrees;
            else
                stepDegrees = app.layerViewVectorIfovDegrees(layer);
            end
        end

        function stepDegrees = configuredViewVectorCorrectionStepDegrees(~, layer, componentIndex)
            stepDegrees = [];
            if ~isfield(layer, "ViewVectorCorrectionStepDegrees")
                return
            end

            configuredSteps = double(layer.ViewVectorCorrectionStepDegrees(:));
            if ~(isscalar(configuredSteps) || numel(configuredSteps) == 3) || ...
                    any(~isfinite(configuredSteps)) || any(configuredSteps <= 0)
                error("ProjectionViewerApp:invalidViewVectorCorrectionStep", ...
                    "Layer ViewVectorCorrectionStepDegrees must be a positive finite scalar or 3-vector.");
            end

            if isscalar(configuredSteps)
                stepDegrees = configuredSteps;
            else
                stepDegrees = configuredSteps(componentIndex);
            end
        end

        function ifovDegrees = layerViewVectorIfovDegrees(app, layer)
            sourceGeometry = layer.SourceGeometry;
            explicitIfovDegrees = app.explicitViewVectorIfovDegrees(sourceGeometry);
            if ~isempty(explicitIfovDegrees)
                ifovDegrees = explicitIfovDegrees;
                return
            end

            imageSize = double(sourceGeometry.ImageSize);
            rowIndices = app.centerAdjacentIndices(imageSize(1));
            columnIndices = app.centerAdjacentIndices(imageSize(2));
            [~, V] = sourceGeometry.SampleFcn(rowIndices, columnIndices);
            anglesRadians = app.sampledViewVectorNeighborAngles(V);
            anglesRadians = anglesRadians(isfinite(anglesRadians) & ...
                anglesRadians > app.MinViewVectorIfovRadians);

            if isempty(anglesRadians)
                ifovDegrees = app.FallbackViewVectorCorrectionStepDegrees;
            else
                ifovDegrees = rad2deg(median(anglesRadians));
            end
        end

        function ifovDegrees = explicitViewVectorIfovDegrees(app, sourceGeometry)
            ifovDegrees = [];
            if isfield(sourceGeometry, "IFOVDegrees")
                ifovDegrees = app.validatePositiveScalar( ...
                    sourceGeometry.IFOVDegrees, "IFOVDegrees");
            elseif isfield(sourceGeometry, "IFOVRadians")
                ifovRadians = app.validatePositiveScalar( ...
                    sourceGeometry.IFOVRadians, "IFOVRadians");
                ifovDegrees = rad2deg(ifovRadians);
            end
        end

        function indices = centerAdjacentIndices(~, count)
            if count <= 1
                indices = 1;
                return
            end

            firstIndex = max(1, floor((count + 1) / 2));
            secondIndex = min(count, firstIndex + 1);
            if secondIndex == firstIndex
                firstIndex = firstIndex - 1;
            end
            indices = [firstIndex secondIndex];
        end

        function anglesRadians = sampledViewVectorNeighborAngles(app, V)
            V = app.normalizeSampledViewVectors(V);
            anglesRadians = zeros(0, 1);
            if size(V, 2) > 1
                rowDots = squeeze(sum(V(:, 1:end-1, :) .* V(:, 2:end, :), 1));
                anglesRadians = [anglesRadians; app.vectorAnglesFromDots(rowDots(:))];
            end
            if size(V, 3) > 1
                columnDots = squeeze(sum(V(:, :, 1:end-1) .* V(:, :, 2:end), 1));
                anglesRadians = [anglesRadians; app.vectorAnglesFromDots(columnDots(:))];
            end
        end

        function V = normalizeSampledViewVectors(~, V)
            vectorNorms = sqrt(sum(V.^2, 1));
            V = V ./ vectorNorms;
        end

        function anglesRadians = vectorAnglesFromDots(~, dots)
            dots = min(max(double(dots), -1), 1);
            anglesRadians = acos(dots);
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
            if app.IsControlDown || app.IsShiftDown || app.IsAltDown
                return
            end
            if app.eventKeyIs(event, "space")
                app.setSelectedLayerVisible(false);
                return
            end
            if app.nudgeSelectedLayerFromKey(event)
                return
            end
            app.adjustSelectedLayerViewVectorCorrectionFromKey(event);
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
            if app.eventKeyIs(event, "space")
                app.setSelectedLayerVisible(true);
            end
        end

        function pointerMoved(app)
            app.updateCrosshair();
            app.updatePan();
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

        function beginPan(app, event)
            if nargin < 2
                event = struct();
            end
            if ~app.isPointerInAxes()
                return
            end

            selectionType = string(app.UIFigure.SelectionType);
            if selectionType == "open"
                app.cycleLayer();
                return
            end
            hasControl = app.IsControlDown || app.eventHasControl(event);
            if hasControl && selectionType == "normal"
                app.DragMode = "translateLayer";
            elseif hasControl && selectionType == "alt"
                app.DragMode = "adjustViewVectors";
            elseif selectionType == "normal"
                app.DragMode = "panCamera";
            else
                return
            end

            app.NeedsDragFinalize = false;
            app.LastPointerLocation = app.UIFigure.CurrentPoint;
        end

        function updatePan(app)
            if app.DragMode == "none"
                return
            end

            currentPoint = app.UIFigure.CurrentPoint;
            pixelDelta = currentPoint - app.LastPointerLocation;
            if all(pixelDelta == 0)
                return
            end

            app.LastPointerLocation = currentPoint;
            switch app.DragMode
                case "panCamera"
                    app.panCameraByPixelDelta(pixelDelta);
                case "translateLayer"
                    app.translateSelectedLayerByPixelDelta(pixelDelta);
                case "adjustViewVectors"
                    app.adjustSelectedLayerViewVectorsByPixelDelta(pixelDelta);
            end
        end

        function endPan(app)
            dragMode = app.DragMode;
            app.DragMode = "none";
            app.LastPointerLocation = [NaN NaN];
            if app.NeedsDragFinalize && ...
                    any(dragMode == ["translateLayer", "adjustViewVectors"])
                layer = app.Scene.layers(app.SelectedLayerIndex);
                app.updateProjection(app.ProjectionTipDegrees, ...
                    app.ProjectionTiltDegrees, layer.Alpha, app.DefaultMeshSampling);
                app.PreviewTimer = tic;
            end
            app.NeedsDragFinalize = false;
        end

        function panCameraByPixelDelta(app, pixelDelta)
            panOffset = app.pixelDeltaToWorldPan(pixelDelta);
            campos(app.Axes, campos(app.Axes) + panOffset.');
            camtarget(app.Axes, camtarget(app.Axes) + panOffset.');
            drawnow limitrate
        end

        function translateSelectedLayerByPixelDelta(app, pixelDelta)
            layerIndex = app.SelectedLayerIndex;
            layer = app.Scene.layers(layerIndex);
            plane = layer.CurrentProjectionPlane;
            projectionDelta = app.pixelDeltaToProjectionOffsetDelta( ...
                pixelDelta, plane);
            if all(abs(projectionDelta) <= eps)
                return
            end

            layer.ProjectionOffsetMeters = ...
                app.layerProjectionOffset(layer) + projectionDelta;
            app.Scene.layers(layerIndex) = layer;
            app.updateProjection(app.ProjectionTipDegrees, ...
                app.ProjectionTiltDegrees, layer.Alpha, app.DragMeshSampling);
            app.PreviewTimer = tic;
            app.NeedsDragFinalize = true;
        end

        function adjustSelectedLayerViewVectorsByPixelDelta(app, pixelDelta)
            layerIndex = app.SelectedLayerIndex;
            layer = app.Scene.layers(layerIndex);
            plane = layer.CurrentProjectionPlane;
            angleDeltaDegrees = app.pixelDeltaToViewVectorDragDeltaDegrees( ...
                pixelDelta, layer, plane, layerIndex);
            if all(abs(angleDeltaDegrees) <= eps)
                return
            end

            offsetsDegrees = app.layerViewVectorAngularOffsetsDegrees(layer);
            offsetsDegrees(1:2) = offsetsDegrees(1:2) + angleDeltaDegrees;
            layer.ViewVectorAngularOffsetsDegrees = offsetsDegrees;
            app.Scene.layers(layerIndex) = layer;
            app.updateProjection(app.ProjectionTipDegrees, ...
                app.ProjectionTiltDegrees, layer.Alpha, app.DragMeshSampling);
            app.PreviewTimer = tic;
            app.NeedsDragFinalize = true;
        end

        function panOffset = pixelDeltaToWorldPan(app, pixelDelta)
            panOffset = -app.pixelDeltaToScreenWorldMotion(pixelDelta);
        end

        function worldMotion = pixelDeltaToScreenWorldMotion(app, pixelDelta)
            axesPosition = app.Axes.InnerPosition;
            widthPixels = max(axesPosition(3), 1);
            heightPixels = max(axesPosition(4), 1);
            [rightVector, upVector, ~, viewDistance] = app.cameraScreenBasis();

            viewHeight = 2 * viewDistance * tan(deg2rad(app.Axes.CameraViewAngle) / 2);
            viewWidth = viewHeight * widthPixels / heightPixels;
            worldMotion = pixelDelta(1) / widthPixels * viewWidth * rightVector + ...
                pixelDelta(2) / heightPixels * viewHeight * upVector;
        end

        function projectionDelta = pixelDeltaToProjectionOffsetDelta(app, pixelDelta, plane)
            [rightVector, upVector] = app.cameraScreenBasis();
            screenMotion = app.pixelDeltaToScreenWorldMotion(pixelDelta);
            target = [rightVector.' * screenMotion; upVector.' * screenMotion];
            screenJacobian = app.screenJacobianForPlaneBasis( ...
                plane.basis, rightVector, upVector);

            if rcond(screenJacobian) > app.MinDragScreenJacobianRcond
                projectionDelta = screenJacobian \ target;
            else
                projectionDelta = plane.basis.' * screenMotion;
            end
        end

        function angleDeltaDegrees = pixelDeltaToViewVectorDragDeltaDegrees( ...
                app, pixelDelta, layer, plane, layerIndex)
            [rightVector, upVector] = app.cameraScreenBasis();
            screenMotion = app.pixelDeltaToScreenWorldMotion(pixelDelta);
            target = [rightVector.' * screenMotion; upVector.' * screenMotion];
            screenJacobian = app.screenJacobianForViewVectorOffsets( ...
                layer, plane, layerIndex, rightVector, upVector);

            if rcond(screenJacobian) > app.MinDragScreenJacobianRcond
                angleDeltaDegrees = screenJacobian \ target;
            else
                angleDeltaDegrees = app.fallbackViewVectorDragDeltaDegrees( ...
                    pixelDelta, layer);
            end
        end

        function screenJacobian = screenJacobianForPlaneBasis(~, basis, ...
                rightVector, upVector)
            screenJacobian = [rightVector.' * basis(:, 1), ...
                rightVector.' * basis(:, 2); ...
                upVector.' * basis(:, 1), upVector.' * basis(:, 2)];
        end

        function screenJacobian = screenJacobianForViewVectorOffsets( ...
                app, layer, plane, layerIndex, rightVector, upVector)
            probeDegrees = app.ViewVectorDragProbeDegrees;
            offsetsDegrees = app.layerViewVectorAngularOffsetsDegrees(layer);
            sampledLayer = layer;
            sampledLayer.MeshSampling = app.DragMeshSampling(layerIndex);
            baseCenter = app.layerMeshCenter(sampledLayer, plane);
            screenJacobian = zeros(2, 2);

            for componentIndex = 1:2
                perturbedLayer = sampledLayer;
                perturbedOffsetsDegrees = offsetsDegrees;
                perturbedOffsetsDegrees(componentIndex) = ...
                    perturbedOffsetsDegrees(componentIndex) + probeDegrees;
                perturbedLayer.ViewVectorAngularOffsetsDegrees = ...
                    perturbedOffsetsDegrees;
                perturbedCenter = app.layerMeshCenter(perturbedLayer, plane);
                centerDerivative = (perturbedCenter - baseCenter) / probeDegrees;
                screenJacobian(:, componentIndex) = ...
                    [rightVector.' * centerDerivative; upVector.' * centerDerivative];
            end
        end

        function center = layerMeshCenter(app, layer, plane)
            mesh = ProjectionMeshBuilder.buildLayerMesh( ...
                layer, plane, app.Scene.renderOrigin);
            center = [mean(mesh.X, "all"); ...
                mean(mesh.Y, "all"); mean(mesh.Z, "all")];
        end

        function angleDeltaDegrees = fallbackViewVectorDragDeltaDegrees( ...
                app, pixelDelta, layer)
            axesPosition = app.Axes.InnerPosition;
            widthPixels = max(axesPosition(3), 1);
            heightPixels = max(axesPosition(4), 1);
            omegaStepDegrees = app.layerViewVectorCorrectionStepDegrees(layer, 1);
            phiStepDegrees = app.layerViewVectorCorrectionStepDegrees(layer, 2);
            angleDeltaDegrees = [ ...
                pixelDelta(2) / heightPixels * omegaStepDegrees; ...
                pixelDelta(1) / widthPixels * phiStepDegrees];
        end

        function [rightVector, upVector, viewDirection, viewDistance] = cameraScreenBasis(app)
            cameraPosition = campos(app.Axes).';
            cameraTarget = camtarget(app.Axes).';
            viewDirection = cameraTarget - cameraPosition;
            viewDistance = norm(viewDirection);
            viewDirection = viewDirection / viewDistance;
            upVector = camup(app.Axes).';
            upVector = upVector / norm(upVector);
            rightVector = cross(viewDirection, upVector);
            rightVector = rightVector / norm(rightVector);
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
                otherwise
                    error("ProjectionViewerApp:invalidSlider", ...
                        "Projection slider name must be ""tip"" or ""tilt"".");
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

        function alphaChanging(app, source, event)
            alpha = app.validateSliderAlpha(event.Value);
            source.Value = alpha;
            app.updateSelectedLayerAlpha(alpha);
        end

        function updateAlphaFromSlider(app)
            alpha = app.validateSliderAlpha(app.AlphaSlider.Value);
            app.AlphaSlider.Value = alpha;
            app.updateSelectedLayerAlpha(alpha);
            app.PreviewTimer = tic;
        end

        function updateSelectedLayerAlpha(app, alpha)
            layerIndex = app.SelectedLayerIndex;
            layer = app.Scene.layers(layerIndex);
            layer.Alpha = alpha;
            app.Scene.layers(layerIndex) = layer;
            app.Surfaces{layerIndex}.FaceAlpha = alpha;
            if ~isempty(app.CurrentMesh)
                app.CurrentMesh.Alpha = alpha;
            end
            app.updateLabels(app.ProjectionTipDegrees, ...
                app.ProjectionTiltDegrees, app.ViewTwistDegrees, alpha);
            drawnow limitrate
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

        function refreshProjectionSurfaces(app, meshSamplings)
            if nargin < 2
                meshSamplings = app.DefaultMeshSampling;
            end

            plane = app.currentProjectionPlane();
            for layerIndex = 1:numel(app.Scene.layers)
                layer = app.Scene.layers(layerIndex);
                layer.CurrentProjectionPlane = plane;
                layer.MeshSampling = meshSamplings(layerIndex);
                app.Scene.layers(layerIndex) = layer;

                mesh = ProjectionMeshBuilder.buildLayerMesh( ...
                    layer, plane, app.Scene.renderOrigin);
                app.updateSurfaceFromMesh(layerIndex, mesh);
                if layerIndex == app.SelectedLayerIndex
                    app.CurrentMesh = mesh;
                    app.Surface = app.Surfaces{layerIndex};
                end
            end
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
            app.updateViewVectorLabel();
        end

        function updateViewVectorLabel(app)
            layer = app.Scene.layers(app.SelectedLayerIndex);
            offsetsDegrees = app.layerViewVectorAngularOffsetsDegrees(layer);
            app.ViewVectorLabel.Text = sprintf( ...
                "Omega %.4f deg\nPhi %.4f deg\nKappa %.3f deg", ...
                offsetsDegrees(1), offsetsDegrees(2), offsetsDegrees(3));
        end

        function alpha = validateSliderAlpha(app, alpha)
            alpha = double(alpha);
            if ~isscalar(alpha) || ~isfinite(alpha)
                error("ProjectionViewerApp:invalidAlpha", ...
                    "Alpha must be a finite scalar.");
            end

            limits = app.AlphaSlider.Limits;
            alpha = min(max(alpha, limits(1)), limits(2));
        end

        function value = validatePositiveScalar(~, value, name)
            if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value) || value <= 0
                error("ProjectionViewerApp:invalidViewVectorIFOV", ...
                    "%s must be a positive finite scalar.", name);
            end
            value = double(value);
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
            app.setSelectedLayerVisible(logical(event.Value));
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

        function setSelectedLayerVisible(app, isVisible)
            layerIndex = app.SelectedLayerIndex;
            layer = app.Scene.layers(layerIndex);
            layer.Visible = logical(isVisible);
            app.Scene.layers(layerIndex) = layer;
            app.Surfaces{layerIndex}.Visible = app.onOff(layer.Visible);
            app.VisibleCheckBox.Value = layer.Visible;
        end

        function toggleCrosshair(app)
            app.setCrosshairEnabled(~app.IsCrosshairEnabled);
        end

        function setCrosshairEnabled(app, isEnabled)
            app.IsCrosshairEnabled = logical(isEnabled);
            app.CrosshairMenuItem.Checked = app.onOff(app.IsCrosshairEnabled);
            app.updateCrosshair();
        end

        function updateCrosshair(app)
            if isempty(app.CrosshairHorizontal) || ...
                    ~isvalid(app.CrosshairHorizontal) || ...
                    isempty(app.CrosshairVertical) || ...
                    ~isvalid(app.CrosshairVertical)
                return
            end

            if ~app.IsCrosshairEnabled || ~app.isPointerInAxes()
                app.hideCrosshair();
                return
            end

            pointer = app.UIFigure.CurrentPoint;
            axesPosition = app.Axes.InnerPosition;
            figurePosition = app.UIFigure.Position;
            figureWidth = max(figurePosition(3), 1);
            figureHeight = max(figurePosition(4), 1);
            x = min(max(pointer(1), axesPosition(1)), ...
                axesPosition(1) + axesPosition(3));
            y = min(max(pointer(2), axesPosition(2)), ...
                axesPosition(2) + axesPosition(4));
            app.CrosshairHorizontal.Position = [ ...
                axesPosition(1) / figureWidth, ...
                y / figureHeight, ...
                axesPosition(3) / figureWidth, 0];
            app.CrosshairVertical.Position = [ ...
                x / figureWidth, ...
                axesPosition(2) / figureHeight, ...
                0, axesPosition(4) / figureHeight];
            app.CrosshairHorizontal.Visible = "on";
            app.CrosshairVertical.Visible = "on";
        end

        function hideCrosshair(app)
            app.CrosshairHorizontal.Visible = "off";
            app.CrosshairVertical.Visible = "off";
        end

        function showHelpDialog(app)
            if ~isempty(app.HelpFigure) && isvalid(app.HelpFigure)
                app.HelpFigure.Visible = "on";
                return
            end

            app.HelpFigure = uifigure(Name="Projection Viewer Help", ...
                Position=[160 160 560 430], ...
                CloseRequestFcn=@(~, ~) app.closeHelpDialog());
            grid = uigridlayout(app.HelpFigure, [1 1]);
            grid.Padding = [12 12 12 12];
            textArea = uitextarea(grid, Editable="off", ...
                Value=app.helpText());
            textArea.Layout.Row = 1;
            textArea.Layout.Column = 1;
        end

        function closeHelpDialog(app)
            if ~isempty(app.HelpFigure) && isvalid(app.HelpFigure)
                delete(app.HelpFigure);
            end
            app.HelpFigure = [];
        end

        function text = helpText(~)
            text = [
                "Mouse controls"
                "Mouse wheel: zoom the view"
                "Shift + wheel: adjust Tip"
                "Alt/Option + wheel: adjust Tilt"
                "Control + wheel: adjust Twist"
                "Left drag: pan the camera"
                "Control + left drag: translate the selected layer"
                "Control + right drag: adjust selected-layer omega and phi"
                "Double left click: cycle the active layer"
                ""
                "Keyboard"
                "W/A/S/D: nudge the selected layer"
                "I/K: adjust phi"
                "J/L: adjust omega"
                "U/O: adjust kappa"
                "Space down: hide the selected layer"
                "Space up: show the selected layer"
                ""
                "Context menu"
                "Right click inside the image for Save, Load, Cycle, Reset, Help, and Crosshair."
                "Crosshair overlays cyan screen-space guide lines across the viewport."
                ];
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
