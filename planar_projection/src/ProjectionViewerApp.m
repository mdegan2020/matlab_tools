classdef ProjectionViewerApp < handle
    %ProjectionViewerApp Programmatic preview app for projected imagery.

    properties (Access = private)
        Scene struct
        CurrentMesh struct
        Surfaces cell
        DefaultMeshSampling struct
        DragMeshSampling struct
        PreviewPyramids cell
        PreviewTilingOptions struct
        PreviewTiledLayerMask logical
        PreviewTiles cell
        IsPreviewCameraReady logical = false
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
        InitialViewportFillFraction double = 0.5
        ModifierWheelStepDegrees double = 1
        ProjectionArrowStepDegrees double = 0.5
        ViewVectorDragProbeDegrees double = 0.01
        MinDragScreenJacobianRcond double = 1e-12
        FallbackViewVectorCorrectionStepDegrees double = 0.1
        KappaViewVectorCorrectionStepDegrees double = 0.1
        MinViewVectorIfovRadians double = 1e-12
        InteractivePreviewMaxTileMeshVertices double = 17
        PreviewLayerDepthStepFraction double = 1e-4
        PreviewLayerDepthMinimumStepMeters double = 0.5
        AnaglyphPreviewFaceAlpha double = 0.55
        MinProjectedNudgeNorm double = 1e-9
        ResetScene struct
        UIFigure matlab.ui.Figure
        HelpFigure matlab.ui.Figure
        GridLayout matlab.ui.container.GridLayout
        Axes matlab.ui.control.UIAxes
        Surface
        ControlGrid matlab.ui.container.GridLayout
        LayerHeaderGrid matlab.ui.container.GridLayout
        ImageContextMenu
        SaveMenuItem
        LoadMenuItem
        CycleMenuItem
        ResetMenuItem
        HelpMenuItem
        CrosshairMenuItem
        AlignmentPanelMenuItem
        ClearAlignmentOverlaysMenuItem
        BlendModeMenu
        AlphaBlendMenuItem
        AnaglyphBlendMenuItem
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
        MoveLayerUpButton matlab.ui.control.Button
        MoveLayerDownButton matlab.ui.control.Button
        IsCrosshairEnabled logical = false
        AlignmentGrid matlab.ui.container.GridLayout
        AlignmentReferenceDropDown matlab.ui.control.DropDown
        AlignmentMovingDropDown matlab.ui.control.DropDown
        AlignmentPresetDropDown matlab.ui.control.DropDown
        AlignmentScopeDropDown matlab.ui.control.DropDown
        AlignmentDetectorDropDown matlab.ui.control.DropDown
        AlignmentLossDropDown matlab.ui.control.DropDown
        AlignmentRoiButton matlab.ui.control.Button
        AlignmentClearRoiButton matlab.ui.control.Button
        AlignmentMatchButton matlab.ui.control.Button
        AlignmentSolveButton matlab.ui.control.Button
        AlignmentCancelButton matlab.ui.control.Button
        AlignmentPreviewButton matlab.ui.control.Button
        AlignmentApplyButton matlab.ui.control.Button
        AlignmentRevertButton matlab.ui.control.Button
        AlignmentClearOverlaysButton matlab.ui.control.Button
        AlignmentStatusLabel matlab.ui.control.Label
        AlignmentPairTable matlab.ui.control.Table
        AlignmentMatchTable matlab.ui.control.Table
        AlignmentRequest struct = struct()
        AlignmentWorkingImages struct = struct()
        AlignmentRawMatchResult struct = struct()
        AlignmentFilteredMatchResult struct = struct()
        AlignmentCuratedMatchMask cell = {}
        AlignmentResult struct = struct()
        AlignmentOverlayLines = gobjects(0)
        AlignmentSelectedMatchOverlay = gobjects(0)
        AlignmentRoiBounds double = []
        AlignmentRoiHandle = []
        AlignmentRoiListeners = []
        AlignmentCancelRequested logical = false
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
            app.ResetScene = app.createResetScene(scene);
            app.SelectedLayerIndex = numel(app.Scene.layers);
            app.DefaultMeshSampling = [app.Scene.layers.MeshSampling];
            app.DragMeshSampling = app.createDragMeshSampling();
            app.initializePreviewPyramids();
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
            else
                app.frameCurrentProjectionView(app.InitialViewportFillFraction);
            end
            app.refreshTiledProjectionSurfaces();
            app.updateControlsFromSelectedLayer();

            if nargout == 0
                clear app
            end
        end

        function delete(app)
            app.clearAlignmentOverlays();
            app.clearAlignmentRoi(false);
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
            else
                app.frameCurrentProjectionView(app.InitialViewportFillFraction);
            end
            app.refreshTiledProjectionSurfaces();
            app.updateControlsFromSelectedLayer();
            app.clearAlignmentComputationState();
            app.clearAlignmentOverlays();
            app.setAlignmentActionEnabled(false);
            app.setAlignmentSolveEnabled(false);
            app.setAlignmentStatus("Alignment not run");
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

        function diagnostics = alignmentDiagnostics(app)
            %alignmentDiagnostics Return lightweight GUI alignment diagnostics.
            diagnostics = struct();
            diagnostics.LayerCount = numel(app.Scene.layers);
            diagnostics.Layers = app.alignmentLayerDiagnostics();
            diagnostics.RenderOptions = app.alignmentRenderOptions();
            diagnostics.Stage = app.alignmentStageDiagnostics();
            diagnostics.Warning = "";

            try
                request = app.currentAlignmentRequest();
                schedule = ProjectionAlignmentScheduler.build(app.Scene, request);
                enabledPairs = app.enabledAlignmentPairs(schedule);
                diagnostics.Request = struct( ...
                    LayerIndices=request.LayerIndices, ...
                    ReferenceLayerIndex=request.ReferenceLayerIndex, ...
                    AnalysisBands=request.AnalysisBands, ...
                    LossMode=request.Options.LossMode, ...
                    SchedulingStrategy=request.Options.Scheduling.Strategy, ...
                    FilterGeometricMethod= ...
                    request.Options.FilterPipeline.GeometricMethod, ...
                    FilterNativeDisplacementMethod= ...
                    request.Options.FilterPipeline.NativeDisplacementMethod, ...
                    KappaBoundDegrees=request.Options.Bounds.KappaDegrees);
                diagnostics.Schedule = schedule;
                diagnostics.EnabledPairs = enabledPairs;
                diagnostics.EnabledPairCount = size(enabledPairs, 1);
                diagnostics.TotalDefaultMeshVertices = ...
                    sum([diagnostics.Layers.DefaultMeshVertexCount]);
                diagnostics.AllLayersHaveObservationRaySampler = ...
                    all([diagnostics.Layers.HasSampleRayFcn]);
            catch ME
                diagnostics.Request = struct();
                diagnostics.Schedule = struct();
                diagnostics.EnabledPairs = zeros(0, 2);
                diagnostics.EnabledPairCount = 0;
                diagnostics.TotalDefaultMeshVertices = ...
                    sum([diagnostics.Layers.DefaultMeshVertexCount]);
                diagnostics.AllLayersHaveObservationRaySampler = ...
                    all([diagnostics.Layers.HasSampleRayFcn]);
                diagnostics.Warning = string(ME.message);
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
                WindowButtonDownFcn=@(~, event) app.beginPan(event), ...
                WindowButtonMotionFcn=@(~, ~) app.pointerMoved(), ...
                WindowButtonUpFcn=@(~, ~) app.endPan());

            app.GridLayout = uigridlayout(app.UIFigure, [3 1]);
            app.GridLayout.RowHeight = {"1x", 0, "fit"};
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

            app.ControlGrid = uigridlayout(app.GridLayout, [2 6]);
            app.ControlGrid.Layout.Row = 3;
            app.ControlGrid.Layout.Column = 1;
            app.ControlGrid.RowHeight = {"fit", "fit"};
            app.ControlGrid.ColumnWidth = {420, "1x", "1x", "1x", "1x", ...
                "fit"};
            app.ControlGrid.Padding = [0 0 0 0];
            app.ControlGrid.ColumnSpacing = 12;

            app.LayerHeaderGrid = uigridlayout(app.ControlGrid, [1 6]);
            app.LayerHeaderGrid.Layout.Row = 1;
            app.LayerHeaderGrid.Layout.Column = 1;
            app.LayerHeaderGrid.RowHeight = {"fit"};
            app.LayerHeaderGrid.ColumnWidth = {"fit", "fit", "fit", "1x", ...
                "fit", "fit"};
            app.LayerHeaderGrid.Padding = [0 0 0 0];
            app.LayerHeaderGrid.ColumnSpacing = 4;

            layerLabel = uilabel(app.LayerHeaderGrid, Text="Layer");
            layerLabel.Layout.Row = 1;
            layerLabel.Layout.Column = 1;
            app.MoveLayerUpButton = uibutton(app.LayerHeaderGrid, ...
                Text="+", Tag="ProjectionViewerMoveLayerUpButton", ...
                Tooltip="Move selected layer up", ...
                ButtonPushedFcn=@(~, ~) app.moveSelectedLayerUp());
            app.MoveLayerUpButton.Layout.Row = 1;
            app.MoveLayerUpButton.Layout.Column = 2;
            app.MoveLayerDownButton = uibutton(app.LayerHeaderGrid, ...
                Text="-", Tag="ProjectionViewerMoveLayerDownButton", ...
                Tooltip="Move selected layer down", ...
                ButtonPushedFcn=@(~, ~) app.moveSelectedLayerDown());
            app.MoveLayerDownButton.Layout.Row = 1;
            app.MoveLayerDownButton.Layout.Column = 3;
            visibleLabel = uilabel(app.LayerHeaderGrid, Text="Visible", ...
                HorizontalAlignment="right");
            visibleLabel.Layout.Row = 1;
            visibleLabel.Layout.Column = 5;
            app.VisibleCheckBox = uicheckbox(app.LayerHeaderGrid, Text="", ...
                Value=true, ValueChangedFcn=@(~, event) app.visibleChanged(event));
            app.VisibleCheckBox.Layout.Row = 1;
            app.VisibleCheckBox.Layout.Column = 6;

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
            app.TipSlider = uislider(app.ControlGrid, Limits=[-85 85], Value=0);
            app.TipSlider.Layout.Row = 2;
            app.TipSlider.Layout.Column = 2;
            app.TipSlider.MajorTicks = [-85 -45 0 45 85];
            app.TipSlider.ValueChangingFcn = @(source, event) ...
                app.sliderChanging(source, event, "tip");
            app.TipSlider.ValueChangedFcn = @(~, ~) app.updateFromSliderValues();

            app.TiltLabel = uilabel(app.ControlGrid, Text="Tilt 0.0 deg");
            app.TiltLabel.Layout.Row = 1;
            app.TiltLabel.Layout.Column = 3;
            app.TiltSlider = uislider(app.ControlGrid, Limits=[-85 85], Value=0);
            app.TiltSlider.Layout.Row = 2;
            app.TiltSlider.Layout.Column = 3;
            app.TiltSlider.MajorTicks = [-85 -45 0 45 85];
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

            app.createAlignmentControls();
        end

        function createAlignmentControls(app)
            app.AlignmentGrid = uigridlayout(app.GridLayout, [4 16]);
            app.AlignmentGrid.Layout.Row = 2;
            app.AlignmentGrid.Layout.Column = 1;
            app.AlignmentGrid.Tag = "ProjectionViewerAlignmentGrid";
            app.AlignmentGrid.RowHeight = {"fit", "fit", 82, 120};
            app.AlignmentGrid.ColumnWidth = {90, 145, 80, 110, 80, 115, ...
                60, 60, 65, 60, 70, 70, 65, 65, 70, "1x"};
            app.AlignmentGrid.Padding = [0 0 0 0];
            app.AlignmentGrid.RowSpacing = 4;
            app.AlignmentGrid.ColumnSpacing = 8;

            referenceLabel = uilabel(app.AlignmentGrid, Text="Reference");
            referenceLabel.Layout.Row = 1;
            referenceLabel.Layout.Column = 1;
            app.AlignmentReferenceDropDown = uidropdown(app.AlignmentGrid, ...
                Items=cellstr(app.layerDisplayNames()), ...
                ItemsData=string(1:numel(app.Scene.layers)), ...
                Tag="ProjectionViewerAlignmentReferenceDropDown");
            app.AlignmentReferenceDropDown.Layout.Row = 2;
            app.AlignmentReferenceDropDown.Layout.Column = 1;

            movingLabel = uilabel(app.AlignmentGrid, Text="Moving");
            movingLabel.Layout.Row = 1;
            movingLabel.Layout.Column = 2;
            app.AlignmentMovingDropDown = uidropdown(app.AlignmentGrid, ...
                Items=cellstr(app.layerDisplayNames()), ...
                ItemsData=string(1:numel(app.Scene.layers)), ...
                Tag="ProjectionViewerAlignmentMovingDropDown");
            app.AlignmentMovingDropDown.Layout.Row = 2;
            app.AlignmentMovingDropDown.Layout.Column = 2;

            presetLabel = uilabel(app.AlignmentGrid, Text="Preset");
            presetLabel.Layout.Row = 1;
            presetLabel.Layout.Column = 3;
            app.AlignmentPresetDropDown = uidropdown(app.AlignmentGrid, ...
                Items=cellstr(["Fast", "Quality"]), ...
                ItemsData=["fast", "quality"], Value="fast", ...
                Tag="ProjectionViewerAlignmentPresetDropDown");
            app.AlignmentPresetDropDown.Layout.Row = 2;
            app.AlignmentPresetDropDown.Layout.Column = 3;

            scopeLabel = uilabel(app.AlignmentGrid, Text="Scope");
            scopeLabel.Layout.Row = 1;
            scopeLabel.Layout.Column = 4;
            app.AlignmentScopeDropDown = uidropdown(app.AlignmentGrid, ...
                Items=cellstr(["Selected pair", "Visible layers"]), ...
                ItemsData=["selectedPair", "visibleLayers"], ...
                Value="selectedPair", ...
                ValueChangedFcn=@(~, ~) app.refreshAlignmentPairTable(), ...
                Tag="ProjectionViewerAlignmentScopeDropDown");
            app.AlignmentScopeDropDown.Layout.Row = 2;
            app.AlignmentScopeDropDown.Layout.Column = 4;

            detectorLabel = uilabel(app.AlignmentGrid, Text="Detector");
            detectorLabel.Layout.Row = 1;
            detectorLabel.Layout.Column = 5;
            app.AlignmentDetectorDropDown = uidropdown(app.AlignmentGrid, ...
                Items=cellstr(["auto", "sift", "surf", "orb", "brisk", "kaze"]), ...
                ItemsData=["auto", "sift", "surf", "orb", "brisk", "kaze"], ...
                Value="auto", Tag="ProjectionViewerAlignmentDetectorDropDown");
            app.AlignmentDetectorDropDown.Layout.Row = 2;
            app.AlignmentDetectorDropDown.Layout.Column = 5;

            lossLabel = uilabel(app.AlignmentGrid, Text="Loss");
            lossLabel.Layout.Row = 1;
            lossLabel.Layout.Column = 6;
            app.AlignmentLossDropDown = uidropdown(app.AlignmentGrid, ...
                Items=cellstr(["projectionPlane2D", "rayToRay3D"]), ...
                ItemsData=["projectionPlane2D", "rayToRay3D"], ...
                Value="projectionPlane2D", ...
                Tag="ProjectionViewerAlignmentLossDropDown");
            app.AlignmentLossDropDown.Layout.Row = 2;
            app.AlignmentLossDropDown.Layout.Column = 6;

            app.AlignmentRoiButton = uibutton(app.AlignmentGrid, ...
                Text="ROI", Tag="ProjectionViewerAlignmentRoiButton", ...
                Tooltip="Draw projection-plane ROI", ...
                ButtonPushedFcn=@(~, ~) app.selectAlignmentRoi());
            app.AlignmentRoiButton.Layout.Row = 2;
            app.AlignmentRoiButton.Layout.Column = 7;

            app.AlignmentClearRoiButton = uibutton(app.AlignmentGrid, ...
                Text="Clear", Tag="ProjectionViewerAlignmentClearRoiButton", ...
                Tooltip="Clear alignment ROI", ...
                ButtonPushedFcn=@(~, ~) app.clearAlignmentRoi(true));
            app.AlignmentClearRoiButton.Layout.Row = 2;
            app.AlignmentClearRoiButton.Layout.Column = 8;

            app.AlignmentMatchButton = uibutton(app.AlignmentGrid, ...
                Text="Match", Tag="ProjectionViewerAlignmentMatchButton", ...
                ButtonPushedFcn=@(~, ~) app.matchAlignmentWorkflow());
            app.AlignmentMatchButton.Layout.Row = 2;
            app.AlignmentMatchButton.Layout.Column = 9;

            app.AlignmentSolveButton = uibutton(app.AlignmentGrid, ...
                Text="Solve", Enable="off", ...
                Tag="ProjectionViewerAlignmentSolveButton", ...
                ButtonPushedFcn=@(~, ~) app.solveAlignmentWorkflow());
            app.AlignmentSolveButton.Layout.Row = 2;
            app.AlignmentSolveButton.Layout.Column = 10;

            app.AlignmentCancelButton = uibutton(app.AlignmentGrid, ...
                Text="Cancel", Enable="off", ...
                Tag="ProjectionViewerAlignmentCancelButton", ...
                ButtonPushedFcn=@(~, ~) app.cancelAlignmentWorkflow());
            app.AlignmentCancelButton.Layout.Row = 2;
            app.AlignmentCancelButton.Layout.Column = 11;

            app.AlignmentPreviewButton = uibutton(app.AlignmentGrid, ...
                Text="Preview", Enable="off", ...
                Tag="ProjectionViewerAlignmentPreviewButton", ...
                ButtonPushedFcn=@(~, ~) app.previewAlignmentResult());
            app.AlignmentPreviewButton.Layout.Row = 2;
            app.AlignmentPreviewButton.Layout.Column = 12;

            app.AlignmentApplyButton = uibutton(app.AlignmentGrid, ...
                Text="Apply", Enable="off", ...
                Tag="ProjectionViewerAlignmentApplyButton", ...
                ButtonPushedFcn=@(~, ~) app.applyAlignmentResult());
            app.AlignmentApplyButton.Layout.Row = 2;
            app.AlignmentApplyButton.Layout.Column = 13;

            app.AlignmentRevertButton = uibutton(app.AlignmentGrid, ...
                Text="Revert", Enable="off", ...
                Tag="ProjectionViewerAlignmentRevertButton", ...
                ButtonPushedFcn=@(~, ~) app.revertAlignmentResult());
            app.AlignmentRevertButton.Layout.Row = 2;
            app.AlignmentRevertButton.Layout.Column = 14;

            app.AlignmentClearOverlaysButton = uibutton(app.AlignmentGrid, ...
                Text="Clear", Tooltip="Clear match overlays", ...
                Tag="ProjectionViewerAlignmentClearOverlaysButton", ...
                ButtonPushedFcn=@(~, ~) app.clearAlignmentOverlaysFromControls());
            app.AlignmentClearOverlaysButton.Layout.Row = 2;
            app.AlignmentClearOverlaysButton.Layout.Column = 15;

            app.AlignmentStatusLabel = uilabel(app.AlignmentGrid, ...
                Text="Alignment not run", ...
                Tag="ProjectionViewerAlignmentStatusLabel");
            app.AlignmentStatusLabel.Layout.Row = [1 2];
            app.AlignmentStatusLabel.Layout.Column = 16;

            app.AlignmentPairTable = uitable(app.AlignmentGrid, ...
                Data=app.emptyAlignmentPairTable(), ...
                ColumnEditable=[true false false false false false false], ...
                Tag="ProjectionViewerAlignmentPairTable");
            app.AlignmentPairTable.Layout.Row = 3;
            app.AlignmentPairTable.Layout.Column = [1 16];

            app.AlignmentMatchTable = uitable(app.AlignmentGrid, ...
                Data=app.emptyAlignmentMatchTable(), ...
                ColumnEditable=[true false false false false false false ...
                false false false false false false false false], ...
                CellEditCallback=@(~, ~) app.alignmentMatchTableEdited(), ...
                CellSelectionCallback=@(~, event) ...
                app.alignmentMatchTableSelected(event), ...
                Tag="ProjectionViewerAlignmentMatchTable");
            app.AlignmentMatchTable.Layout.Row = 4;
            app.AlignmentMatchTable.Layout.Column = [1 16];

            app.updateAlignmentLayerItems();
            app.setAlignmentActionEnabled(false);
            app.setAlignmentPanelVisible(false);
        end

        function updateAlignmentLayerItems(app)
            if isempty(app.AlignmentReferenceDropDown) || ...
                    ~isvalid(app.AlignmentReferenceDropDown)
                return
            end

            layerCount = numel(app.Scene.layers);
            layerItems = cellstr(app.layerDisplayNames());
            referenceValue = app.validAlignmentLayerValue( ...
                app.AlignmentReferenceDropDown.Value, ceil(layerCount / 2));
            movingDefault = app.SelectedLayerIndex;
            if layerCount > 1 && movingDefault == referenceValue
                movingDefault = min(layerCount, referenceValue + 1);
                if movingDefault == referenceValue
                    movingDefault = max(1, referenceValue - 1);
                end
            end
            movingValue = app.validAlignmentLayerValue( ...
                app.AlignmentMovingDropDown.Value, movingDefault);
            if layerCount > 1 && movingValue == referenceValue
                movingValue = min(layerCount, referenceValue + 1);
                if movingValue == referenceValue
                    movingValue = max(1, referenceValue - 1);
                end
            end

            app.AlignmentReferenceDropDown.Items = layerItems;
            app.AlignmentReferenceDropDown.ItemsData = string(1:layerCount);
            app.AlignmentReferenceDropDown.Value = string(referenceValue);
            app.AlignmentMovingDropDown.Items = layerItems;
            app.AlignmentMovingDropDown.ItemsData = string(1:layerCount);
            app.AlignmentMovingDropDown.Value = string(movingValue);
            app.refreshAlignmentPairTable();
        end

        function value = validAlignmentLayerValue(app, value, defaultValue)
            layerCount = numel(app.Scene.layers);
            value = str2double(string(value));
            if isempty(value) || ~isscalar(value) || ~isfinite(value) || ...
                    value < 1 || value > layerCount
                value = defaultValue;
            end
            value = min(max(round(double(value)), 1), layerCount);
        end

        function runAlignmentWorkflow(app)
            app.matchAlignmentWorkflow();
            if app.hasSolvableFilteredMatches()
                app.solveAlignmentWorkflow();
            end
        end

        function matchAlignmentWorkflow(app)
            app.AlignmentCancelRequested = false;
            app.clearAlignmentComputationState();
            app.clearAlignmentOverlays();
            app.setAlignmentActionEnabled(false);
            app.setAlignmentSolveEnabled(false);
            app.setAlignmentRunning(true);
            cleanup = onCleanup(@() app.setAlignmentRunning(false));

            try
                request = app.currentAlignmentRequest();
                options = request.Options;
                if numel(request.LayerIndices) < 2
                    app.setAlignmentStatus("Alignment needs at least two visible layers.");
                    return
                end
                if numel(request.LayerIndices) == 2 && ...
                        request.LayerIndices(1) == request.LayerIndices(2)
                    app.setAlignmentStatus("Choose different reference and moving layers.");
                    return
                end
                schedule = ProjectionAlignmentScheduler.build(app.Scene, request);
                enabledPairs = app.enabledAlignmentPairs(schedule);
                app.updateAlignmentPairTable(schedule, enabledPairs, [], []);
                if isempty(enabledPairs)
                    app.setAlignmentStatus("No enabled alignment pairs.");
                    return
                end

                app.setAlignmentStatus("Rendering working images...");
                app.throwIfAlignmentCancelled();
                workingImages = ProjectionAlignmentWorkingImageRenderer.render( ...
                    app.Scene, request, app.alignmentRenderOptions());
                workingImages = app.applyEnabledPairsToWorkingImages( ...
                    workingImages, enabledPairs);

                app.setAlignmentStatus("Detecting and matching features...");
                app.throwIfAlignmentCancelled();
                matchResult = ProjectionAlignmentFeatureMatcher.match( ...
                    workingImages, options);
                app.updateAlignmentPairTable(workingImages.Schedule, ...
                    enabledPairs, matchResult, []);

                app.setAlignmentStatus("Filtering matches...");
                app.throwIfAlignmentCancelled();
                filteredMatches = ProjectionAlignmentMatchFilter.filter( ...
                    matchResult, options);
                filteredMatches = app.applyAlignmentRoi(filteredMatches);
                app.AlignmentRequest = request;
                app.AlignmentWorkingImages = workingImages;
                app.AlignmentRawMatchResult = matchResult;
                app.AlignmentFilteredMatchResult = filteredMatches;
                app.AlignmentCuratedMatchMask = ...
                    app.defaultAlignmentCuratedMatchMask(filteredMatches);
                app.updateAlignmentPairTable(workingImages.Schedule, ...
                    enabledPairs, matchResult, filteredMatches);
                app.updateAlignmentMatchTable(filteredMatches, []);
                app.drawAlignmentMatchOverlays(filteredMatches);
                matchCount = sum([filteredMatches.Matches.Count]);
                if matchCount < 3 || any([filteredMatches.Matches.Count] < 3)
                    app.setAlignmentStatus(sprintf( ...
                        "Each enabled pair needs at least 3 filtered matches; found %d total.", ...
                        matchCount));
                    return
                end

                app.setAlignmentSolveEnabled(true);
                app.setAlignmentStatus(sprintf( ...
                    "Matched and filtered %d observations. Ready to solve.", ...
                    matchCount));
            catch ME
                if strcmp(ME.identifier, "ProjectionViewerApp:alignmentCancelled")
                    app.AlignmentResult = ProjectionAlignmentResult.validate( ...
                        struct(Status="cancelled"));
                    app.setAlignmentStatus("Alignment cancelled.");
                else
                    app.AlignmentResult = ProjectionAlignmentResult.validate( ...
                        struct(Status="failed", Warnings=string(ME.message)));
                    app.setAlignmentStatus("Alignment failed: " + string(ME.message));
                end
            end
        end

        function solveAlignmentWorkflow(app)
            if ~app.hasFilteredAlignmentMatches()
                app.setAlignmentStatus("Run Match before Solve.");
                app.setAlignmentSolveEnabled(false);
                return
            end

            app.AlignmentCancelRequested = false;
            app.setAlignmentRunning(true);
            cleanup = onCleanup(@() app.setAlignmentRunning(false));
            app.setAlignmentActionEnabled(false);
            app.syncCuratedMaskFromMatchTable();

            try
                schedule = app.AlignmentWorkingImages.Schedule;
                enabledPairs = app.enabledAlignmentPairs(schedule);
                solveMatches = app.applyEnabledPairsToMatchResult( ...
                    app.AlignmentFilteredMatchResult, enabledPairs);
                solveMatches = app.applyCuratedMaskToMatchResult(solveMatches);
                app.updateAlignmentPairTable(schedule, enabledPairs, ...
                    app.AlignmentRawMatchResult, solveMatches);
                app.updateAlignmentMatchTable(app.AlignmentFilteredMatchResult, []);
                if isempty(enabledPairs) || isempty(solveMatches.Matches)
                    app.setAlignmentStatus("No enabled matched pairs.");
                    return
                end

                matchCount = sum([solveMatches.Matches.Count]);
                if matchCount < 3 || any([solveMatches.Matches.Count] < 3)
                    app.setAlignmentStatus(sprintf( ...
                        "Each enabled pair needs at least 3 filtered matches; found %d total.", ...
                        matchCount));
                    return
                end

                app.setAlignmentStatus("Solving OPK corrections...");
                app.throwIfAlignmentCancelled();
                options = app.AlignmentRequest.Options;
                result = ProjectionAlignmentOpkSolver.solve( ...
                    app.Scene, solveMatches, options);
                emptyResult = ProjectionAlignmentResult.empty( ...
                    app.AlignmentRequest);
                result.RequestSummary = emptyResult.RequestSummary;
                result = ProjectionAlignmentResult.validate(result);
                app.AlignmentResult = result;
                app.updateAlignmentMatchTable(app.AlignmentFilteredMatchResult, ...
                    result);
                app.drawAlignmentOverlays(result);
                app.setAlignmentActionEnabled(true);
                app.setAlignmentStatus(app.alignmentResultSummary(result));
            catch ME
                if strcmp(ME.identifier, "ProjectionViewerApp:alignmentCancelled")
                    app.AlignmentResult = ProjectionAlignmentResult.validate( ...
                        struct(Status="cancelled"));
                    app.setAlignmentStatus("Alignment cancelled.");
                else
                    app.AlignmentResult = ProjectionAlignmentResult.validate( ...
                        struct(Status="failed", Warnings=string(ME.message)));
                    app.setAlignmentStatus("Alignment failed: " + string(ME.message));
                end
            end
        end

        function cancelAlignmentWorkflow(app)
            app.AlignmentCancelRequested = true;
            app.setAlignmentStatus("Cancelling alignment...");
        end

        function previewAlignmentResult(app)
            if ~app.hasAlignmentResult()
                return
            end
            app.Scene = ProjectionAlignmentOpkSolver.previewCorrections( ...
                app.Scene, app.AlignmentResult);
            app.refreshProjectionSurfaces(app.DefaultMeshSampling);
            app.updateControlsFromSelectedLayer();
            app.drawAlignmentOverlays(app.AlignmentResult);
            app.setAlignmentStatus("Previewing " + ...
                app.alignmentCorrectionSummary(app.AlignmentResult));
        end

        function applyAlignmentResult(app)
            if ~app.hasAlignmentResult()
                return
            end
            app.Scene = ProjectionAlignmentOpkSolver.applyCorrections( ...
                app.Scene, app.AlignmentResult);
            app.refreshProjectionSurfaces(app.DefaultMeshSampling);
            app.updateControlsFromSelectedLayer();
            app.drawAlignmentOverlays(app.AlignmentResult);
            app.setAlignmentStatus("Applied " + ...
                app.alignmentCorrectionSummary(app.AlignmentResult));
        end

        function revertAlignmentResult(app)
            if ~app.hasAlignmentResult()
                return
            end
            app.Scene = ProjectionAlignmentOpkSolver.revertCorrections( ...
                app.Scene, app.AlignmentResult);
            app.refreshProjectionSurfaces(app.DefaultMeshSampling);
            app.updateControlsFromSelectedLayer();
            app.drawAlignmentOverlays(app.AlignmentResult);
            app.setAlignmentStatus("Reverted alignment preview.");
        end

        function request = currentAlignmentRequest(app)
            options = app.currentAlignmentOptions();
            referenceIndex = app.validAlignmentLayerValue( ...
                app.AlignmentReferenceDropDown.Value, 1);
            movingIndex = app.validAlignmentLayerValue( ...
                app.AlignmentMovingDropDown.Value, numel(app.Scene.layers));
            scope = app.alignmentScope();
            if scope == "visibleLayers"
                layerIndices = app.visibleAlignmentLayerIndices();
                schedulingStrategy = "centerOut";
            else
                layerIndices = [movingIndex referenceIndex];
                schedulingStrategy = "twoImage";
            end
            options.Scheduling.Strategy = schedulingStrategy;
            options.Scheduling.ReferenceLayerIndex = referenceIndex;
            options = ProjectionAlignmentOptions.validate(options);
            request = ProjectionAlignmentRequest.validate(struct( ...
                Scene=app.Scene, ...
                LayerIndices=layerIndices, ...
                ReferenceLayerIndex=referenceIndex, ...
                AnalysisBands=ones(1, numel(layerIndices)), ...
                Options=options));
        end

        function options = currentAlignmentOptions(app)
            preset = app.alignmentPreset();
            switch preset
                case "quality"
                    detectorMaxFeatures = 2000;
                    matcherMaxRatio = 0.8;
                otherwise
                    detectorMaxFeatures = 1000;
                    matcherMaxRatio = 0.9;
            end
            options = ProjectionAlignmentOptions.validate(struct( ...
                Detector=struct(Method=string(app.AlignmentDetectorDropDown.Value), ...
                MaxFeatures=detectorMaxFeatures), ...
                Matcher=struct(MaxRatio=matcherMaxRatio), ...
                FilterPipeline=struct( ...
                GeometricMethod="similarity", ...
                NativeDisplacementMethod="mad"), ...
                Bounds=struct(KappaDegrees=15), ...
                LossMode=string(app.AlignmentLossDropDown.Value)));
        end

        function preset = alignmentPreset(app)
            preset = "fast";
            if ~isempty(app.AlignmentPresetDropDown) && ...
                    isvalid(app.AlignmentPresetDropDown)
                preset = string(app.AlignmentPresetDropDown.Value);
            end
        end

        function scope = alignmentScope(app)
            scope = "selectedPair";
            if ~isempty(app.AlignmentScopeDropDown) && ...
                    isvalid(app.AlignmentScopeDropDown)
                scope = string(app.AlignmentScopeDropDown.Value);
            end
        end

        function layerIndices = visibleAlignmentLayerIndices(app)
            visibleMask = [app.Scene.layers.Visible];
            layerIndices = find(visibleMask);
        end

        function options = alignmentRenderOptions(app)
            if app.alignmentPreset() == "quality"
                outputSize = [768 768];
            else
                outputSize = [512 512];
            end
            options = struct(OutputSize=outputSize, ...
                MaxOutputPixels=prod(outputSize));
        end

        function layerDiagnostics = alignmentLayerDiagnostics(app)
            names = app.layerDisplayNames();
            for layerIndex = 1:numel(app.Scene.layers)
                layer = app.Scene.layers(layerIndex);
                meshSampling = app.DefaultMeshSampling(layerIndex);
                sourceGeometry = layer.SourceGeometry;
                layerDiagnostic = struct();
                layerDiagnostic.LayerIndex = layerIndex;
                layerDiagnostic.Name = names(layerIndex);
                layerDiagnostic.ImageSize = double(sourceGeometry.ImageSize);
                layerDiagnostic.DefaultMeshRowCount = ...
                    numel(meshSampling.RowIndices);
                layerDiagnostic.DefaultMeshColumnCount = ...
                    numel(meshSampling.ColumnIndices);
                layerDiagnostic.DefaultMeshVertexCount = ...
                    layerDiagnostic.DefaultMeshRowCount * ...
                    layerDiagnostic.DefaultMeshColumnCount;
                layerDiagnostic.HasSampleRayFcn = ...
                    isfield(sourceGeometry, "SampleRayFcn") && ...
                    isa(sourceGeometry.SampleRayFcn, "function_handle");
                if layerIndex == 1
                    layerDiagnostics = layerDiagnostic;
                else
                    layerDiagnostics(layerIndex) = layerDiagnostic;
                end
            end
        end

        function stageDiagnostics = alignmentStageDiagnostics(app)
            stageDiagnostics = struct();
            stageDiagnostics.HasRequest = app.hasScalarStruct( ...
                app.AlignmentRequest);
            stageDiagnostics.HasWorkingImages = app.hasScalarStruct( ...
                app.AlignmentWorkingImages);
            stageDiagnostics.HasRawMatches = app.hasMatchResult( ...
                app.AlignmentRawMatchResult);
            stageDiagnostics.HasFilteredMatches = app.hasMatchResult( ...
                app.AlignmentFilteredMatchResult);
            stageDiagnostics.HasSolveResult = app.hasAlignmentResult();
            stageDiagnostics.RawMatchCount = app.totalAlignmentMatchCount( ...
                app.AlignmentRawMatchResult);
            stageDiagnostics.FilteredMatchCount = ...
                app.totalAlignmentMatchCount(app.AlignmentFilteredMatchResult);
            stageDiagnostics.SolvedMatchCount = ...
                app.totalAlignmentMatchCount(app.AlignmentResult);
            stageDiagnostics.CuratedMaskCount = ...
                numel(app.AlignmentCuratedMatchMask);
            stageDiagnostics.CuratedMatchCount = ...
                sum(app.curatedAlignmentMatchCounts( ...
                app.AlignmentFilteredMatchResult));
        end

        function tf = hasScalarStruct(~, value)
            tf = isstruct(value) && isscalar(value) && ~isempty(fieldnames(value));
        end

        function tf = hasMatchResult(~, value)
            tf = isstruct(value) && isfield(value, "Matches") && ...
                ~isempty(value.Matches);
        end

        function count = totalAlignmentMatchCount(app, matchResult)
            count = 0;
            if app.hasMatchResult(matchResult)
                count = sum([matchResult.Matches.Count]);
            end
        end

        function refreshAlignmentPairTable(app)
            if isempty(app.AlignmentPairTable) || ~isvalid(app.AlignmentPairTable)
                return
            end

            try
                request = app.currentAlignmentRequest();
                if numel(request.LayerIndices) < 2
                    app.AlignmentPairTable.Data = app.emptyAlignmentPairTable();
                    return
                end
                schedule = ProjectionAlignmentScheduler.build(app.Scene, request);
                enabledPairs = app.enabledAlignmentPairs(schedule);
                app.updateAlignmentPairTable(schedule, enabledPairs, [], []);
            catch
                app.AlignmentPairTable.Data = app.emptyAlignmentPairTable();
            end
        end

        function data = emptyAlignmentPairTable(~)
            data = table(logical.empty(0, 1), strings(0, 1), ...
                zeros(0, 1), zeros(0, 1), nan(0, 1), nan(0, 1), ...
                nan(0, 1), VariableNames=["Enabled", "Pair", "Moving", ...
                "Reference", "RawMatches", "FilteredMatches", "Confidence"]);
        end

        function data = emptyAlignmentMatchTable(~)
            data = table(logical.empty(0, 1), strings(0, 1), zeros(0, 1), ...
                nan(0, 1), nan(0, 1), nan(0, 1), nan(0, 1), ...
                nan(0, 1), nan(0, 1), nan(0, 1), nan(0, 1), ...
                nan(0, 1), nan(0, 1), nan(0, 1), strings(0, 1), ...
                VariableNames=["Enabled", "Pair", "MatchIndex", "Score", ...
                "MovingRow", "MovingColumn", "ReferenceRow", ...
                "ReferenceColumn", "MovingX", "MovingY", "ReferenceX", ...
                "ReferenceY", "ResidualBefore", "ResidualAfter", "State"]);
        end

        function updateAlignmentPairTable(app, schedule, enabledPairs, ...
                matchResult, filteredMatches)
            if isempty(app.AlignmentPairTable) || ~isvalid(app.AlignmentPairTable)
                return
            end
            if nargin < 4
                matchResult = [];
            end
            if nargin < 5
                filteredMatches = [];
            end

            pairCount = numel(schedule.Pairs);
            enabledKeys = app.pairKeys(enabledPairs);
            enabled = false(pairCount, 1);
            labels = strings(pairCount, 1);
            moving = zeros(pairCount, 1);
            reference = zeros(pairCount, 1);
            rawMatches = nan(pairCount, 1);
            filteredCounts = nan(pairCount, 1);
            confidence = nan(pairCount, 1);
            for pairIndex = 1:pairCount
                pair = schedule.Pairs(pairIndex).Pair;
                key = app.pairKey(pair);
                labels(pairIndex) = key;
                enabled(pairIndex) = ismember(key, enabledKeys);
                moving(pairIndex) = pair(1);
                reference(pairIndex) = pair(2);
                rawMatches(pairIndex) = app.matchCountForPair(matchResult, pair);
                filteredCounts(pairIndex) = app.matchCountForPair( ...
                    filteredMatches, pair);
                confidence(pairIndex) = app.confidenceForPair(matchResult, pair);
            end

            app.AlignmentPairTable.Data = table(enabled, labels, moving, ...
                reference, rawMatches, filteredCounts, confidence, ...
                VariableNames=["Enabled", "Pair", "Moving", "Reference", ...
                "RawMatches", "FilteredMatches", "Confidence"]);
        end

        function updateAlignmentMatchTable(app, matchResult, result)
            if isempty(app.AlignmentMatchTable) || ~isvalid(app.AlignmentMatchTable)
                return
            end
            if nargin < 2 || ~app.hasMatchResult(matchResult)
                app.AlignmentMatchTable.Data = app.emptyAlignmentMatchTable();
                return
            end
            if nargin < 3
                result = [];
            end

            data = app.alignmentMatchTableData(matchResult, result);
            if height(data) > 0
                residuals = data.ResidualAfter;
                residuals(~isfinite(residuals)) = -Inf;
                [~, order] = sort(residuals, "descend");
                data = data(order, :);
            end
            app.AlignmentMatchTable.Data = data;
        end

        function data = alignmentMatchTableData(app, matchResult, result)
            totalCount = sum([matchResult.Matches.Count]);
            if totalCount == 0
                data = app.emptyAlignmentMatchTable();
                return
            end

            enabled = false(totalCount, 1);
            labels = strings(totalCount, 1);
            matchIndices = zeros(totalCount, 1);
            scores = nan(totalCount, 1);
            movingRows = nan(totalCount, 1);
            movingColumns = nan(totalCount, 1);
            referenceRows = nan(totalCount, 1);
            referenceColumns = nan(totalCount, 1);
            movingX = nan(totalCount, 1);
            movingY = nan(totalCount, 1);
            referenceX = nan(totalCount, 1);
            referenceY = nan(totalCount, 1);
            residualBefore = nan(totalCount, 1);
            residualAfter = nan(totalCount, 1);
            states = strings(totalCount, 1);

            rowIndex = 0;
            for pairIndex = 1:numel(matchResult.Matches)
                pairMatch = matchResult.Matches(pairIndex);
                recordIndices = app.matchRecordIndices(pairMatch);
                curatedMask = app.curatedMaskForPair( ...
                    pairMatch.Pair, pairMatch.Count);
                for matchIndex = 1:pairMatch.Count
                    rowIndex = rowIndex + 1;
                    recordIndex = recordIndices(matchIndex);
                    residualRecord = app.residualRecordForMatch( ...
                        result, pairMatch.Pair, recordIndex);
                    enabled(rowIndex) = curatedMask(matchIndex);
                    labels(rowIndex) = app.pairKey(pairMatch.Pair);
                    matchIndices(rowIndex) = recordIndex;
                    scores(rowIndex) = pairMatch.Scores(matchIndex);
                    movingRows(rowIndex) = pairMatch.MovingSourceRows(matchIndex);
                    movingColumns(rowIndex) = ...
                        pairMatch.MovingSourceColumns(matchIndex);
                    referenceRows(rowIndex) = ...
                        pairMatch.ReferenceSourceRows(matchIndex);
                    referenceColumns(rowIndex) = ...
                        pairMatch.ReferenceSourceColumns(matchIndex);
                    movingX(rowIndex) = pairMatch.MovingFeatureLocations( ...
                        matchIndex, 1);
                    movingY(rowIndex) = pairMatch.MovingFeatureLocations( ...
                        matchIndex, 2);
                    referenceX(rowIndex) = ...
                        pairMatch.ReferenceFeatureLocations(matchIndex, 1);
                    referenceY(rowIndex) = ...
                        pairMatch.ReferenceFeatureLocations(matchIndex, 2);
                    residualBefore(rowIndex) = residualRecord.Before;
                    residualAfter(rowIndex) = residualRecord.After;
                    if ~enabled(rowIndex)
                        states(rowIndex) = "disabled";
                    elseif residualRecord.Found
                        states(rowIndex) = "solverObservation";
                    else
                        states(rowIndex) = "accepted";
                    end
                end
            end

            data = table(enabled, labels, matchIndices, scores, movingRows, ...
                movingColumns, referenceRows, referenceColumns, movingX, ...
                movingY, referenceX, referenceY, residualBefore, ...
                residualAfter, states, VariableNames=["Enabled", "Pair", ...
                "MatchIndex", "Score", "MovingRow", "MovingColumn", ...
                "ReferenceRow", "ReferenceColumn", "MovingX", "MovingY", ...
                "ReferenceX", "ReferenceY", "ResidualBefore", ...
                "ResidualAfter", "State"]);
        end

        function enabledPairs = enabledAlignmentPairs(app, schedule)
            if isempty(schedule.Pairs)
                enabledPairs = zeros(0, 2);
                return
            end

            pairs = reshape([schedule.Pairs.Pair], 2, []).';
            enabled = true(size(pairs, 1), 1);
            if ~isempty(app.AlignmentPairTable) && isvalid(app.AlignmentPairTable)
                data = app.AlignmentPairTable.Data;
                if istable(data) && all(ismember(["Enabled", "Pair"], ...
                        string(data.Properties.VariableNames)))
                    tableKeys = string(data.Pair);
                    for pairIndex = 1:size(pairs, 1)
                        matchIndex = find(tableKeys == app.pairKey(pairs(pairIndex, :)), ...
                            1, "first");
                        if ~isempty(matchIndex)
                            enabled(pairIndex) = logical(data.Enabled(matchIndex));
                        end
                    end
                end
            end
            enabledPairs = pairs(enabled, :);
        end

        function workingImages = applyEnabledPairsToWorkingImages(app, ...
                workingImages, enabledPairs)
            enabledKeys = app.pairKeys(enabledPairs);
            pairKeys = strings(1, numel(workingImages.Schedule.Pairs));
            for pairIndex = 1:numel(workingImages.Schedule.Pairs)
                pairKeys(pairIndex) = app.pairKey( ...
                    workingImages.Schedule.Pairs(pairIndex).Pair);
            end
            keepMask = ismember(pairKeys, enabledKeys);
            workingImages.Schedule.Pairs = workingImages.Schedule.Pairs(keepMask);
            workingImages.Schedule.PairCount = numel(workingImages.Schedule.Pairs);
            workingImages.Schedule.LayerIndices = unique(enabledPairs(:).', ...
                "stable");
            workingImages.PairOverlapMasks = workingImages.PairOverlapMasks(keepMask);
        end

        function matchResult = applyEnabledPairsToMatchResult(app, ...
                matchResult, enabledPairs)
            if isempty(matchResult) || ~isstruct(matchResult) || ...
                    ~isfield(matchResult, "Matches") || isempty(matchResult.Matches)
                return
            end

            enabledKeys = app.pairKeys(enabledPairs);
            pairKeys = strings(1, numel(matchResult.Matches));
            for pairIndex = 1:numel(matchResult.Matches)
                pairKeys(pairIndex) = app.pairKey( ...
                    matchResult.Matches(pairIndex).Pair);
            end
            keepMask = ismember(pairKeys, enabledKeys);
            matchResult.Matches = matchResult.Matches(keepMask);
            if isfield(matchResult, "Schedule") && ...
                    isfield(matchResult.Schedule, "Pairs")
                matchResult.Schedule.Pairs = matchResult.Schedule.Pairs(keepMask);
                matchResult.Schedule.PairCount = ...
                    numel(matchResult.Schedule.Pairs);
                matchResult.Schedule.LayerIndices = unique(enabledPairs(:).', ...
                    "stable");
            end
            matchResult = app.subsetAlignmentPairDiagnostics( ...
                matchResult, keepMask);
        end

        function matchResult = applyCuratedMaskToMatchResult(app, matchResult)
            if ~app.hasMatchResult(matchResult)
                return
            end

            for k = 1:numel(matchResult.Matches)
                pairMatch = matchResult.Matches(k);
                keepMask = app.curatedMaskForPair( ...
                    pairMatch.Pair, pairMatch.Count);
                matchResult.Matches(k) = app.subsetAlignmentPairMatch( ...
                    pairMatch, keepMask);
            end
        end

        function matchResult = subsetAlignmentPairDiagnostics(~, ...
                matchResult, keepMask)
            if ~isfield(matchResult, "Diagnostics") || ...
                    ~isstruct(matchResult.Diagnostics)
                return
            end

            diagnostics = matchResult.Diagnostics;
            if isfield(diagnostics, "PairDiagnostics") && ...
                    numel(diagnostics.PairDiagnostics) == numel(keepMask)
                diagnostics.PairDiagnostics = diagnostics.PairDiagnostics(keepMask);
            end
            if isfield(diagnostics, "FilterPipeline") && ...
                    numel(diagnostics.FilterPipeline) == numel(keepMask)
                diagnostics.FilterPipeline = diagnostics.FilterPipeline(keepMask);
            end
            matchResult.Diagnostics = diagnostics;
        end

        function keys = pairKeys(app, pairs)
            keys = strings(1, size(pairs, 1));
            for pairIndex = 1:size(pairs, 1)
                keys(pairIndex) = app.pairKey(pairs(pairIndex, :));
            end
        end

        function key = pairKey(~, pair)
            key = sprintf("%d -> %d", pair(1), pair(2));
        end

        function count = matchCountForPair(app, matchResult, pair)
            count = NaN;
            pairMatch = app.matchForPair(matchResult, pair);
            if ~isempty(pairMatch)
                count = pairMatch.Count;
            end
        end

        function confidence = confidenceForPair(~, matchResult, pair)
            confidence = NaN;
            if isempty(matchResult) || ~isstruct(matchResult) || ...
                    ~isfield(matchResult, "Diagnostics") || ...
                    ~isfield(matchResult.Diagnostics, "PairDiagnostics")
                return
            end
            diagnostics = matchResult.Diagnostics.PairDiagnostics;
            for k = 1:numel(diagnostics)
                if isequal(diagnostics(k).Pair, pair)
                    confidence = diagnostics(k).Confidence;
                    return
                end
            end
        end

        function pairMatch = matchForPair(~, matchResult, pair)
            pairMatch = [];
            if isempty(matchResult) || ~isstruct(matchResult) || ...
                    ~isfield(matchResult, "Matches")
                return
            end
            for k = 1:numel(matchResult.Matches)
                if isequal(matchResult.Matches(k).Pair, pair)
                    pairMatch = matchResult.Matches(k);
                    return
                end
            end
        end

        function record = residualRecordForMatch(app, result, pair, matchIndex)
            record = struct(Before=NaN, After=NaN, Found=false);
            if isempty(result) || ~isstruct(result) || ...
                    ~isfield(result, "Diagnostics") || ...
                    ~isfield(result.Diagnostics, "MatchRecords")
                return
            end

            records = result.Diagnostics.MatchRecords;
            for k = 1:numel(records)
                if string(records(k).PairKey) == app.pairKey(pair) && ...
                        records(k).MatchIndex == matchIndex
                    record.Before = records(k).ResidualBefore;
                    record.After = records(k).ResidualAfter;
                    record.Found = true;
                    return
                end
            end
        end

        function indices = matchRecordIndices(~, pairMatch)
            if isfield(pairMatch, "MatchRecordIndices") && ...
                    numel(pairMatch.MatchRecordIndices) == pairMatch.Count
                indices = pairMatch.MatchRecordIndices(:);
            else
                indices = (1:pairMatch.Count).';
            end
        end

        function mask = curatedMaskForPair(app, pair, count)
            mask = true(count, 1);
            if isempty(app.AlignmentCuratedMatchMask) || ...
                    ~app.hasMatchResult(app.AlignmentFilteredMatchResult)
                return
            end

            pairIndex = app.filteredMatchPairIndex(pair);
            if isnan(pairIndex) || pairIndex > numel(app.AlignmentCuratedMatchMask)
                return
            end

            candidate = app.AlignmentCuratedMatchMask{pairIndex};
            if numel(candidate) == count
                mask = logical(candidate(:));
            end
        end

        function pairIndex = filteredMatchPairIndex(app, pair)
            pairIndex = NaN;
            if ~app.hasMatchResult(app.AlignmentFilteredMatchResult)
                return
            end

            for k = 1:numel(app.AlignmentFilteredMatchResult.Matches)
                if isequal(app.AlignmentFilteredMatchResult.Matches(k).Pair, pair)
                    pairIndex = k;
                    return
                end
            end
        end

        function syncCuratedMaskFromMatchTable(app)
            if isempty(app.AlignmentMatchTable) || ...
                    ~isvalid(app.AlignmentMatchTable) || ...
                    ~app.hasMatchResult(app.AlignmentFilteredMatchResult)
                return
            end

            data = app.AlignmentMatchTable.Data;
            if ~istable(data) || height(data) == 0 || ...
                    ~all(ismember(["Enabled", "Pair", "MatchIndex"], ...
                    string(data.Properties.VariableNames)))
                return
            end

            masks = cell(1, numel(app.AlignmentFilteredMatchResult.Matches));
            for pairIndex = 1:numel(masks)
                masks{pairIndex} = false( ...
                    app.AlignmentFilteredMatchResult.Matches(pairIndex).Count, 1);
            end

            for rowIndex = 1:height(data)
                pair = app.pairFromKey(data.Pair(rowIndex));
                pairIndex = app.filteredMatchPairIndex(pair);
                if isnan(pairIndex)
                    continue
                end
                pairMatch = app.AlignmentFilteredMatchResult.Matches(pairIndex);
                recordIndices = app.matchRecordIndices(pairMatch);
                matchMask = recordIndices == data.MatchIndex(rowIndex);
                if any(matchMask)
                    masks{pairIndex}(matchMask) = logical(data.Enabled(rowIndex));
                end
            end

            app.AlignmentCuratedMatchMask = masks;
        end

        function pair = pairFromKey(~, key)
            values = sscanf(char(string(key)), "%d -> %d");
            if numel(values) ~= 2
                pair = [NaN NaN];
            else
                pair = values(:).';
            end
        end

        function counts = curatedAlignmentMatchCounts(app, matchResult)
            if ~app.hasMatchResult(matchResult)
                counts = zeros(1, 0);
                return
            end

            counts = zeros(1, numel(matchResult.Matches));
            for k = 1:numel(matchResult.Matches)
                pairMatch = matchResult.Matches(k);
                counts(k) = nnz(app.curatedMaskForPair( ...
                    pairMatch.Pair, pairMatch.Count));
            end
        end

        function matchResult = applyAlignmentRoi(app, matchResult)
            if isempty(app.AlignmentRoiBounds) || isempty(matchResult.Matches)
                return
            end

            initialCounts = [matchResult.Matches.Count];
            for k = 1:numel(matchResult.Matches)
                pairMatch = matchResult.Matches(k);
                keepMask = app.pointsInsideAlignmentRoi( ...
                    pairMatch.MovingProjectionPoints) & ...
                    app.pointsInsideAlignmentRoi( ...
                    pairMatch.ReferenceProjectionPoints);
                matchResult.Matches(k) = app.subsetAlignmentPairMatch( ...
                    pairMatch, keepMask);
            end
            finalCounts = [matchResult.Matches.Count];
            matchResult.Diagnostics.Roi = struct( ...
                Bounds=app.AlignmentRoiBounds, ...
                RejectedCount=sum(initialCounts - finalCounts), ...
                RemainingCount=sum(finalCounts));
        end

        function mask = pointsInsideAlignmentRoi(app, points)
            bounds = app.AlignmentRoiBounds;
            mask = points(:, 1) >= bounds(1) & points(:, 1) <= bounds(2) & ...
                points(:, 2) >= bounds(3) & points(:, 2) <= bounds(4);
        end

        function pairMatch = subsetAlignmentPairMatch(~, pairMatch, keepMask)
            rowFields = ["MovingFeatureLocations", "ReferenceFeatureLocations", ...
                "MovingPlaneCoordinates", "ReferencePlaneCoordinates", ...
                "MovingSourceRows", "MovingSourceColumns", ...
                "ReferenceSourceRows", "ReferenceSourceColumns", "IndexPairs", ...
                "MatchMetric", "Scores", "MatchRecordIndices"];
            keepMask = logical(keepMask(:));
            for fieldName = rowFields
                if isfield(pairMatch, fieldName)
                    pairMatch.(fieldName) = pairMatch.(fieldName)(keepMask, :);
                end
            end
            pairMatch.Count = nnz(keepMask);
        end

        function masks = defaultAlignmentCuratedMatchMask(~, matchResult)
            masks = cell(1, numel(matchResult.Matches));
            for k = 1:numel(matchResult.Matches)
                masks{k} = true(matchResult.Matches(k).Count, 1);
            end
        end

        function selectAlignmentRoi(app)
            app.clearAlignmentRoi(false);
            position = app.defaultAlignmentRoiPosition();
            app.AlignmentRoiBounds = app.roiBoundsFromPosition(position);
            try
                app.drawAlignmentRoiOverlay(position);
                app.setAlignmentStatus("ROI active.");
            catch
                app.AlignmentRoiHandle = [];
                app.AlignmentRoiListeners = [];
                app.setAlignmentStatus("ROI set to central projection area.");
            end
        end

        function clearAlignmentRoi(app, updateStatus)
            if nargin < 2
                updateStatus = true;
            end
            if ~isempty(app.AlignmentRoiListeners)
                try
                    delete(app.AlignmentRoiListeners);
                catch
                end
            end
            app.AlignmentRoiListeners = [];
            if app.hasValidAlignmentRoiHandle()
                delete(app.AlignmentRoiHandle);
            end
            app.AlignmentRoiHandle = [];
            app.AlignmentRoiBounds = [];
            if updateStatus
                app.setAlignmentStatus("ROI cleared.");
            end
        end

        function updateAlignmentRoiBounds(app)
            if app.hasValidAlignmentRoiHandle() && ...
                    isprop(app.AlignmentRoiHandle, "Position")
                app.AlignmentRoiBounds = app.roiBoundsFromPosition( ...
                    app.AlignmentRoiHandle.Position);
            end
        end

        function tf = hasValidAlignmentRoiHandle(app)
            try
                tf = ~isempty(app.AlignmentRoiHandle) && ...
                    isvalid(app.AlignmentRoiHandle);
            catch
                tf = false;
            end
        end

        function position = defaultAlignmentRoiPosition(app)
            bounds = app.defaultAlignmentRoiBounds();
            width = 0.6 * (bounds(2) - bounds(1));
            height = 0.6 * (bounds(4) - bounds(3));
            position = [bounds(1) + 0.2 * (bounds(2) - bounds(1)), ...
                bounds(3) + 0.2 * (bounds(4) - bounds(3)), ...
                width, height];
        end

        function bounds = roiBoundsFromPosition(~, position)
            xValues = [position(1), position(1) + position(3)];
            yValues = [position(2), position(2) + position(4)];
            bounds = [min(xValues), max(xValues), min(yValues), max(yValues)];
        end

        function bounds = defaultAlignmentRoiBounds(app)
            layerIndices = app.alignmentRoiLayerIndices();
            [intersectionBounds, unionBounds, hasIntersection] = ...
                app.projectionPlaneBoundsForLayers(layerIndices);
            if hasIntersection
                bounds = intersectionBounds;
            else
                bounds = unionBounds;
            end

            if isempty(bounds) || any(~isfinite(bounds)) || ...
                    bounds(2) <= bounds(1) || bounds(4) <= bounds(3)
                bounds = [-1 1 -1 1];
            end
        end

        function layerIndices = alignmentRoiLayerIndices(app)
            try
                request = app.currentAlignmentRequest();
                layerIndices = unique(request.LayerIndices, "stable");
            catch
                layerIndices = find([app.Scene.layers.Visible]);
            end
            if isempty(layerIndices)
                layerIndices = app.SelectedLayerIndex;
            end
        end

        function [intersectionBounds, unionBounds, hasIntersection] = ...
                projectionPlaneBoundsForLayers(app, layerIndices)
            plane = app.currentProjectionPlane();
            intersectionBounds = [-Inf Inf -Inf Inf];
            unionBounds = [Inf -Inf Inf -Inf];

            for layerIndex = reshape(layerIndices, 1, [])
                layer = app.Scene.layers(layerIndex);
                layer.CurrentProjectionPlane = plane;
                layer.MeshSampling = app.DefaultMeshSampling(layerIndex);
                mesh = ProjectionMeshBuilder.buildLayerMesh( ...
                    layer, plane, app.Scene.renderOrigin);
                coordinates = PlanarProjection.worldToPlane( ...
                    reshape(mesh.WorldPoints, 3, []), plane);
                layerBounds = [min(coordinates(1, :)), max(coordinates(1, :)), ...
                    min(coordinates(2, :)), max(coordinates(2, :))];
                intersectionBounds = [ ...
                    max(intersectionBounds(1), layerBounds(1)), ...
                    min(intersectionBounds(2), layerBounds(2)), ...
                    max(intersectionBounds(3), layerBounds(3)), ...
                    min(intersectionBounds(4), layerBounds(4))];
                unionBounds = [ ...
                    min(unionBounds(1), layerBounds(1)), ...
                    max(unionBounds(2), layerBounds(2)), ...
                    min(unionBounds(3), layerBounds(3)), ...
                    max(unionBounds(4), layerBounds(4))];
            end

            hasIntersection = all(isfinite(intersectionBounds)) && ...
                intersectionBounds(2) > intersectionBounds(1) && ...
                intersectionBounds(4) > intersectionBounds(3);
        end

        function drawAlignmentRoiOverlay(app, position)
            bounds = app.roiBoundsFromPosition(position);
            planeCoordinates = [ ...
                bounds(1), bounds(2), bounds(2), bounds(1), bounds(1); ...
                bounds(3), bounds(3), bounds(4), bounds(4), bounds(3)];
            worldPoints = PlanarProjection.reconstruct3d( ...
                planeCoordinates, app.currentProjectionPlane()) - ...
                app.Scene.renderOrigin;
            app.AlignmentRoiHandle = line(app.Axes, ...
                worldPoints(1, :), worldPoints(2, :), worldPoints(3, :), ...
                Color=[0 1 1], LineWidth=1.5, HitTest="off", ...
                PickableParts="none", Tag="ProjectionViewerAlignmentRoi");
            app.raiseCrosshairOverlay();
        end

        function toggleAlignmentPanel(app)
            app.setAlignmentPanelVisible(~app.isAlignmentPanelVisible());
        end

        function setAlignmentPanelVisible(app, isVisible)
            if isempty(app.AlignmentGrid) || ~isvalid(app.AlignmentGrid)
                return
            end

            app.AlignmentGrid.Visible = app.onOff(isVisible);
            rowHeights = app.GridLayout.RowHeight;
            if isVisible
                rowHeights{2} = "fit";
            else
                rowHeights{2} = 0;
            end
            app.GridLayout.RowHeight = rowHeights;

            if ~isempty(app.AlignmentPanelMenuItem) && ...
                    isvalid(app.AlignmentPanelMenuItem)
                app.AlignmentPanelMenuItem.Checked = app.onOff(isVisible);
            end
            drawnow limitrate
        end

        function tf = isAlignmentPanelVisible(app)
            tf = ~isempty(app.AlignmentGrid) && isvalid(app.AlignmentGrid) && ...
                string(app.AlignmentGrid.Visible) == "on";
        end

        function setAlignmentRunning(app, isRunning)
            if isempty(app.AlignmentMatchButton) || ...
                    ~isvalid(app.AlignmentMatchButton)
                return
            end
            app.AlignmentMatchButton.Enable = app.onOff(~isRunning);
            if isRunning
                app.setAlignmentSolveEnabled(false);
            else
                app.setAlignmentSolveEnabled(app.hasSolvableFilteredMatches());
            end
            app.AlignmentCancelButton.Enable = app.onOff(isRunning);
            drawnow limitrate
        end

        function setAlignmentSolveEnabled(app, isEnabled)
            if isempty(app.AlignmentSolveButton) || ...
                    ~isvalid(app.AlignmentSolveButton)
                return
            end
            app.AlignmentSolveButton.Enable = app.onOff(isEnabled);
        end

        function setAlignmentActionEnabled(app, isEnabled)
            if isempty(app.AlignmentPreviewButton) || ...
                    ~isvalid(app.AlignmentPreviewButton)
                return
            end
            state = app.onOff(isEnabled);
            app.AlignmentPreviewButton.Enable = state;
            app.AlignmentApplyButton.Enable = state;
            app.AlignmentRevertButton.Enable = state;
        end

        function tf = hasAlignmentResult(app)
            tf = isstruct(app.AlignmentResult) && ...
                isfield(app.AlignmentResult, "SolvedCorrections") && ...
                ~isempty(app.AlignmentResult.SolvedCorrections);
        end

        function tf = hasFilteredAlignmentMatches(app)
            tf = isstruct(app.AlignmentFilteredMatchResult) && ...
                isfield(app.AlignmentFilteredMatchResult, "Matches") && ...
                ~isempty(app.AlignmentFilteredMatchResult.Matches);
        end

        function tf = hasSolvableFilteredMatches(app)
            counts = app.curatedAlignmentMatchCounts( ...
                app.AlignmentFilteredMatchResult);
            tf = app.hasFilteredAlignmentMatches() && ...
                all(counts >= 3) && sum(counts) >= 3;
        end

        function clearAlignmentComputationState(app)
            app.AlignmentRequest = struct();
            app.AlignmentWorkingImages = struct();
            app.AlignmentRawMatchResult = struct();
            app.AlignmentFilteredMatchResult = struct();
            app.AlignmentCuratedMatchMask = {};
            app.AlignmentResult = struct();
            app.updateAlignmentMatchTable([], []);
            app.clearSelectedAlignmentMatchOverlay();
        end

        function throwIfAlignmentCancelled(app)
            drawnow limitrate
            if app.AlignmentCancelRequested
                error("ProjectionViewerApp:alignmentCancelled", ...
                    "Alignment was cancelled.");
            end
        end

        function setAlignmentStatus(app, statusText)
            if isempty(app.AlignmentStatusLabel) || ~isvalid(app.AlignmentStatusLabel)
                return
            end
            app.AlignmentStatusLabel.Text = char(statusText);
            drawnow limitrate
        end

        function summary = alignmentResultSummary(app, result)
            matchCount = sum([result.Matches.Count]);
            rmsBefore = app.safeRmsValue(result, "RmsBefore");
            rmsAfter = app.safeRmsValue(result, "RmsAfter");
            summary = string(sprintf( ...
                "%d solver observations, RMS %.4g -> %.4g. %s", ...
                matchCount, rmsBefore, rmsAfter, ...
                char(app.alignmentCorrectionSummary(result))));
            if ~isempty(result.Warnings)
                summary = summary + " Warnings: " + ...
                    strjoin(string(result.Warnings), "; ");
            end
        end

        function summary = alignmentCorrectionSummary(~, result)
            parts = strings(1, numel(result.SolvedCorrections));
            for k = 1:numel(result.SolvedCorrections)
                correction = result.SolvedCorrections(k);
                opk = correction.ViewVectorAngularOffsetsDegrees;
                parts(k) = sprintf("L%d OPK [%.4g %.4g %.4g] deg", ...
                    correction.LayerIndex, opk(1), opk(2), opk(3));
            end
            summary = strjoin(parts, "; ");
        end

        function value = safeRmsValue(~, result, fieldName)
            value = NaN;
            if isfield(result, "Diagnostics") && ...
                    isfield(result.Diagnostics, fieldName)
                value = result.Diagnostics.(fieldName);
            end
        end

        function alignmentMatchTableEdited(app)
            app.syncCuratedMaskFromMatchTable();
            app.AlignmentResult = struct();
            app.setAlignmentActionEnabled(false);
            app.setAlignmentSolveEnabled(app.hasSolvableFilteredMatches());
            app.updateAlignmentMatchTable(app.AlignmentFilteredMatchResult, []);
            visibleMatches = app.applyCuratedMaskToMatchResult( ...
                app.AlignmentFilteredMatchResult);
            app.drawAlignmentMatchOverlays(visibleMatches);
            app.setAlignmentStatus("Match curation updated. Solve again.");
        end

        function alignmentMatchTableSelected(app, event)
            if (isstruct(event) && isfield(event, "Indices")) || ...
                    (isobject(event) && isprop(event, "Indices"))
                indices = event.Indices;
            else
                indices = [];
            end
            if isempty(indices)
                app.clearSelectedAlignmentMatchOverlay();
                return
            end
            rowIndex = indices(1, 1);
            data = app.AlignmentMatchTable.Data;
            if ~istable(data) || rowIndex < 1 || rowIndex > height(data)
                app.clearSelectedAlignmentMatchOverlay();
                return
            end

            app.drawSelectedAlignmentMatchOverlay(data(rowIndex, :));
        end

        function drawSelectedAlignmentMatchOverlay(app, rowData)
            app.clearSelectedAlignmentMatchOverlay();
            if ~app.hasMatchResult(app.AlignmentFilteredMatchResult)
                return
            end

            pair = app.pairFromKey(rowData.Pair(1));
            pairIndex = app.filteredMatchPairIndex(pair);
            if isnan(pairIndex)
                return
            end

            pairMatch = app.AlignmentFilteredMatchResult.Matches(pairIndex);
            recordIndices = app.matchRecordIndices(pairMatch);
            matchIndex = find(recordIndices == rowData.MatchIndex(1), ...
                1, "first");
            if isempty(matchIndex)
                return
            end

            plane = app.currentProjectionPlane();
            movingWorld = PlanarProjection.reconstruct3d( ...
                pairMatch.MovingPlaneCoordinates(matchIndex, :).', plane) - ...
                app.Scene.renderOrigin;
            referenceWorld = PlanarProjection.reconstruct3d( ...
                pairMatch.ReferencePlaneCoordinates(matchIndex, :).', plane) - ...
                app.Scene.renderOrigin;
            selectedLine = line(app.Axes, ...
                [movingWorld(1) referenceWorld(1)], ...
                [movingWorld(2) referenceWorld(2)], ...
                [movingWorld(3) referenceWorld(3)], ...
                Color=[1 0 1], LineWidth=2.5, HitTest="off", ...
                PickableParts="none", ...
                Tag="ProjectionViewerAlignmentSelectedMatchOverlay");
            selectedMarkers = line(app.Axes, ...
                [movingWorld(1) referenceWorld(1)], ...
                [movingWorld(2) referenceWorld(2)], ...
                [movingWorld(3) referenceWorld(3)], ...
                LineStyle="none", Marker="s", MarkerSize=7, ...
                MarkerEdgeColor=[1 0 1], HitTest="off", ...
                PickableParts="none", ...
                Tag="ProjectionViewerAlignmentSelectedMatchOverlay");
            app.AlignmentSelectedMatchOverlay = [selectedLine selectedMarkers];
            app.raiseCrosshairOverlay();
        end

        function clearSelectedAlignmentMatchOverlay(app)
            if isempty(app.AlignmentSelectedMatchOverlay)
                return
            end
            for k = 1:numel(app.AlignmentSelectedMatchOverlay)
                overlay = app.AlignmentSelectedMatchOverlay(k);
                if ~isempty(overlay) && isvalid(overlay)
                    delete(overlay);
                end
            end
            app.AlignmentSelectedMatchOverlay = gobjects(0);
        end

        function drawAlignmentMatchOverlays(app, matchResult)
            result = struct(Matches=app.alignmentOverlayMatches(matchResult));
            app.drawAlignmentOverlays(result);
        end

        function matches = alignmentOverlayMatches(app, matchResult)
            if isempty(matchResult) || ~isstruct(matchResult) || ...
                    (~isfield(matchResult, "Matches") || isempty(matchResult.Matches)) && ...
                    (~isfield(matchResult, "Diagnostics") || ...
                    ~isfield(matchResult.Diagnostics, "MatchRecords"))
                matches = struct("Pair", {}, "MovingProjectionPoints", {}, ...
                    "ReferenceProjectionPoints", {}, "Count", {});
                return
            end

            if isfield(matchResult, "Diagnostics") && ...
                    isfield(matchResult.Diagnostics, "MatchRecords") && ...
                    ~isempty(matchResult.Diagnostics.MatchRecords)
                matches = app.alignmentOverlayMatchesFromRecords( ...
                    matchResult.Diagnostics.MatchRecords);
                return
            end

            for k = 1:numel(matchResult.Matches)
                pairMatch = matchResult.Matches(k);
                match = struct();
                match.Pair = pairMatch.Pair;
                [movingPoints, referencePoints] = ...
                    app.currentAlignmentProjectionPoints(pairMatch);
                match.MovingProjectionPoints = movingPoints;
                match.ReferenceProjectionPoints = referencePoints;
                match.Count = pairMatch.Count;
                if k == 1
                    matches = match;
                else
                    matches(k) = match;
                end
            end
        end

        function matches = alignmentOverlayMatchesFromRecords(app, records)
            if isempty(records)
                matches = struct("Pair", {}, "MovingProjectionPoints", {}, ...
                    "ReferenceProjectionPoints", {}, "Count", {});
                return
            end

            pairKeys = unique(string({records.PairKey}), "stable");
            for k = 1:numel(pairKeys)
                pairRecords = records(string({records.PairKey}) == pairKeys(k));
                pair = pairRecords(1).Pair;
                pairMatch = struct();
                pairMatch.Pair = pair;
                pairMatch.MovingSourceRows = [pairRecords.MovingSourceRow].';
                pairMatch.MovingSourceColumns = ...
                    [pairRecords.MovingSourceColumn].';
                pairMatch.ReferenceSourceRows = ...
                    [pairRecords.ReferenceSourceRow].';
                pairMatch.ReferenceSourceColumns = ...
                    [pairRecords.ReferenceSourceColumn].';
                pairMatch.MovingPlaneCoordinates = zeros(numel(pairRecords), 2);
                pairMatch.ReferencePlaneCoordinates = zeros(numel(pairRecords), 2);
                pairMatch.Count = numel(pairRecords);

                match = struct();
                match.Pair = pair;
                [movingPoints, referencePoints] = ...
                    app.currentAlignmentProjectionPoints(pairMatch);
                match.MovingProjectionPoints = movingPoints;
                match.ReferenceProjectionPoints = referencePoints;
                match.Count = pairMatch.Count;
                if k == 1
                    matches = match;
                else
                    matches(k) = match;
                end
            end
        end

        function [movingPoints, referencePoints] = ...
                currentAlignmentProjectionPoints(app, pairMatch)
            movingPoints = pairMatch.MovingPlaneCoordinates;
            referencePoints = pairMatch.ReferencePlaneCoordinates;
            requiredFields = ["MovingSourceRows", "MovingSourceColumns", ...
                "ReferenceSourceRows", "ReferenceSourceColumns"];
            if any(~isfield(pairMatch, requiredFields))
                return
            end

            try
                movingPoints = app.projectLayerSourceObservationsToCurrentPlane( ...
                    pairMatch.Pair(1), pairMatch.MovingSourceRows, ...
                    pairMatch.MovingSourceColumns);
                referencePoints = ...
                    app.projectLayerSourceObservationsToCurrentPlane( ...
                    pairMatch.Pair(2), pairMatch.ReferenceSourceRows, ...
                    pairMatch.ReferenceSourceColumns);
            catch
                movingPoints = pairMatch.MovingPlaneCoordinates;
                referencePoints = pairMatch.ReferencePlaneCoordinates;
            end
        end

        function planePoints = projectLayerSourceObservationsToCurrentPlane( ...
                app, layerIndex, rows, columns)
            rows = double(rows(:));
            columns = double(columns(:));
            plane = app.currentProjectionPlane();
            layer = app.Scene.layers(layerIndex);
            layer.CurrentProjectionPlane = plane;
            layer.MeshSampling = app.DefaultMeshSampling(layerIndex);
            mesh = ProjectionMeshBuilder.buildLayerMesh( ...
                layer, plane, app.Scene.renderOrigin);

            worldPoints = nan(3, numel(rows));
            for componentIndex = 1:3
                componentGrid = squeeze(mesh.WorldPoints(componentIndex, :, :));
                worldPoints(componentIndex, :) = interp2( ...
                    mesh.ColumnIndices, mesh.RowIndices, componentGrid, ...
                    columns.', rows.', "linear", NaN);
            end

            if any(~isfinite(worldPoints), "all")
                error("ProjectionViewerApp:invalidAlignmentOverlayPoint", ...
                    "Alignment overlay source observations must lie inside the current layer mesh.");
            end
            planePoints = PlanarProjection.worldToPlane(worldPoints, plane).';
        end

        function refreshAlignmentOverlays(app)
            if ~app.hasAlignmentOverlayGraphics()
                return
            end

            if app.hasAlignmentResult()
                app.drawAlignmentOverlays(app.AlignmentResult);
            elseif app.hasFilteredAlignmentMatches()
                visibleMatches = app.applyCuratedMaskToMatchResult( ...
                    app.AlignmentFilteredMatchResult);
                app.drawAlignmentMatchOverlays(visibleMatches);
            end
        end

        function tf = hasAlignmentOverlayGraphics(app)
            try
                tf = any(isgraphics(app.AlignmentOverlayLines)) || ...
                    any(isgraphics(app.AlignmentSelectedMatchOverlay));
            catch
                tf = false;
            end
        end

        function drawAlignmentOverlays(app, result)
            app.clearAlignmentOverlays();
            if isempty(result.Matches) || sum([result.Matches.Count]) == 0
                return
            end

            plane = app.currentProjectionPlane();
            matchCount = sum([result.Matches.Count]);
            lineX = nan(3, matchCount);
            lineY = nan(3, matchCount);
            lineZ = nan(3, matchCount);
            movingPoints = nan(3, matchCount);
            referencePoints = nan(3, matchCount);
            cursor = 0;
            for pairIndex = 1:numel(result.Matches)
                pairMatch = result.Matches(pairIndex);
                pairCount = pairMatch.Count;
                if pairCount == 0
                    continue
                end
                movingWorld = PlanarProjection.reconstruct3d( ...
                    pairMatch.MovingProjectionPoints.', plane) - ...
                    app.Scene.renderOrigin;
                referenceWorld = PlanarProjection.reconstruct3d( ...
                    pairMatch.ReferenceProjectionPoints.', plane) - ...
                    app.Scene.renderOrigin;
                idx = cursor + (1:pairCount);
                lineX(:, idx) = [movingWorld(1, :); referenceWorld(1, :); ...
                    nan(1, pairCount)];
                lineY(:, idx) = [movingWorld(2, :); referenceWorld(2, :); ...
                    nan(1, pairCount)];
                lineZ(:, idx) = [movingWorld(3, :); referenceWorld(3, :); ...
                    nan(1, pairCount)];
                movingPoints(:, idx) = movingWorld;
                referencePoints(:, idx) = referenceWorld;
                cursor = cursor + pairCount;
            end

            if cursor == 0
                return
            end
            lineX = lineX(:, 1:cursor);
            lineY = lineY(:, 1:cursor);
            lineZ = lineZ(:, 1:cursor);
            movingPoints = movingPoints(:, 1:cursor);
            referencePoints = referencePoints(:, 1:cursor);

            matchLines = line(app.Axes, lineX(:), lineY(:), lineZ(:), ...
                Color=[1 0.9 0.1], LineWidth=0.75, HitTest="off", ...
                PickableParts="none", Tag="ProjectionViewerAlignmentMatchOverlay");
            movingMarkers = line(app.Axes, movingPoints(1, :), ...
                movingPoints(2, :), movingPoints(3, :), LineStyle="none", ...
                Marker="o", MarkerSize=4, MarkerEdgeColor=[1 0.9 0.1], ...
                HitTest="off", PickableParts="none", ...
                Tag="ProjectionViewerAlignmentMovingMatchOverlay");
            referenceMarkers = line(app.Axes, referencePoints(1, :), ...
                referencePoints(2, :), referencePoints(3, :), LineStyle="none", ...
                Marker="+", MarkerSize=5, MarkerEdgeColor=[0 1 0.3], ...
                HitTest="off", PickableParts="none", ...
                Tag="ProjectionViewerAlignmentReferenceMatchOverlay");
            app.AlignmentOverlayLines = [matchLines movingMarkers referenceMarkers];
            app.raiseCrosshairOverlay();
        end

        function clearAlignmentOverlays(app)
            app.clearSelectedAlignmentMatchOverlay();
            if isempty(app.AlignmentOverlayLines)
                return
            end
            for k = 1:numel(app.AlignmentOverlayLines)
                overlay = app.AlignmentOverlayLines(k);
                if ~isempty(overlay) && isvalid(overlay)
                    delete(overlay);
                end
            end
            app.AlignmentOverlayLines = gobjects(0);
        end

        function clearAlignmentOverlaysFromControls(app)
            app.clearAlignmentOverlays();
            app.setAlignmentStatus("Alignment overlays cleared.");
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
            app.AlignmentPanelMenuItem = uimenu(app.ImageContextMenu, ...
                Text="Alignment panel", Checked="off", ...
                MenuSelectedFcn=@(~, ~) app.toggleAlignmentPanel(), ...
                Tag="ProjectionViewerAlignmentPanelMenuItem");
            app.ClearAlignmentOverlaysMenuItem = uimenu(app.ImageContextMenu, ...
                Text="Clear alignment overlays", ...
                MenuSelectedFcn=@(~, ~) app.clearAlignmentOverlaysFromControls(), ...
                Tag="ProjectionViewerClearAlignmentOverlaysMenuItem");
            app.BlendModeMenu = uimenu(app.ImageContextMenu, ...
                Text="Blend mode", Separator="on", ...
                Tag="ProjectionViewerBlendModeMenu");
            app.AlphaBlendMenuItem = uimenu(app.BlendModeMenu, ...
                Text="Alpha", Checked="on", ...
                MenuSelectedFcn=@(~, ~) app.setSelectedLayerBlendMode("alpha"), ...
                Tag="ProjectionViewerAlphaBlendMenuItem");
            app.AnaglyphBlendMenuItem = uimenu(app.BlendModeMenu, ...
                Text="Red/blue anaglyph", Checked="off", ...
                MenuSelectedFcn=@(~, ~) app.setSelectedLayerBlendMode("redBlueAnaglyph"), ...
                Tag="ProjectionViewerAnaglyphBlendMenuItem");
            app.Axes.ContextMenu = app.ImageContextMenu;
        end

        function createCrosshairOverlay(app)
            app.CrosshairHorizontal = line(app.Axes, [NaN NaN], ...
                [NaN NaN], [NaN NaN], Color=[0 1 1], LineWidth=1, ...
                Visible="off", Clipping="off", HitTest="off", ...
                PickableParts="none", Tag="ProjectionViewerCrosshairHorizontal");
            app.CrosshairVertical = line(app.Axes, [NaN NaN], ...
                [NaN NaN], [NaN NaN], Color=[0 1 1], LineWidth=1, ...
                Visible="off", Clipping="off", HitTest="off", ...
                PickableParts="none", Tag="ProjectionViewerCrosshairVertical");
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

        function scene = createResetScene(~, scene)
            for layerIndex = 1:numel(scene.layers)
                layer = scene.layers(layerIndex);
                layer.Alpha = 1.0;
                layer.Visible = true;
                layer.BlendMode = "alpha";
                layer.ProjectionOffsetMeters = [0; 0];
                layer.ViewVectorAngularOffsetsDegrees = [0; 0; 0];
                layer.CurrentProjectionPlane = layer.BaseProjectionPlane;
                scene.layers(layerIndex) = layer;
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
            app.IsPreviewCameraReady = true;
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
                if app.usesTiledPreview(layerIndex)
                    app.Surfaces{layerIndex} = ...
                        app.createTiledLayerSurfaces(layerIndex);
                    if layerIndex == app.SelectedLayerIndex
                        app.Surface = app.primarySurfaceForLayer(layerIndex);
                        app.CurrentMesh = struct();
                    end
                    continue
                end

                mesh = ProjectionMeshBuilder.buildLayerMesh( ...
                    layer, layer.CurrentProjectionPlane, app.Scene.renderOrigin);
                app.Surfaces{layerIndex} = app.createPreviewSurface( ...
                    layerIndex, mesh, mesh.Texture, ...
                    "ProjectionViewerLayerSurface");
                if layerIndex == app.SelectedLayerIndex
                    app.Surface = app.primarySurfaceForLayer(layerIndex);
                    app.CurrentMesh = mesh;
                end
            end
            hold(app.Axes, "off");
            axis(app.Axes, "equal");
            axis(app.Axes, "tight");
            grid(app.Axes, "off");
            app.stabilizeAxesLimits();
            app.hideImageAxesDecorations();
            app.raiseCrosshairOverlay();
        end

        function rebuildSurfaces(app)
            for layerIndex = 1:numel(app.Surfaces)
                app.deleteLayerSurfaces(layerIndex);
            end
            app.createSurface();
        end

        function initializePreviewPyramids(app)
            app.PreviewTilingOptions = ProjectionPreviewPyramid.defaultOptions();
            layerCount = numel(app.Scene.layers);
            app.PreviewPyramids = cell(1, layerCount);
            app.PreviewTiledLayerMask = false(1, layerCount);
            app.PreviewTiles = cell(1, layerCount);
            for layerIndex = 1:layerCount
                pyramid = ProjectionPreviewPyramid.build( ...
                    app.Scene.layers(layerIndex).Image, ...
                    app.PreviewTilingOptions);
                app.PreviewPyramids{layerIndex} = pyramid;
                app.PreviewTiledLayerMask(layerIndex) = ...
                    ProjectionPreviewPyramid.shouldUseTiling( ...
                    pyramid, app.PreviewTilingOptions);
            end
        end

        function tf = usesTiledPreview(app, layerIndex)
            tf = ~isempty(app.PreviewTiledLayerMask) && ...
                layerIndex <= numel(app.PreviewTiledLayerMask) && ...
                app.PreviewTiledLayerMask(layerIndex);
        end

        function surfaceHandle = createPreviewSurface(app, layerIndex, ...
                mesh, texture, tag)
            [X, Y, Z] = app.previewSurfaceCoordinates(mesh, layerIndex);
            surfaceHandle = surface(app.Axes, X, Y, Z, ...
                app.previewTextureForLayer(texture, layerIndex), ...
                FaceColor="texturemap", EdgeColor="none", LineStyle="none", ...
                FaceAlpha=app.previewFaceAlphaForLayer(mesh.Alpha, layerIndex), ...
                Visible=app.onOff(mesh.Visible), ...
                ContextMenu=app.ImageContextMenu, Tag=tag);
        end

        function surfaceHandles = createTiledLayerSurfaces(app, layerIndex, tiles)
            if nargin < 3
                tiles = app.previewTilesForLayer(layerIndex);
            end
            app.PreviewTiles{layerIndex} = tiles;
            surfaceHandles = gobjects(1, numel(tiles));
            for tileIndex = 1:numel(tiles)
                tileLayer = app.tilePreviewLayer(layerIndex, tiles(tileIndex));
                mesh = ProjectionMeshBuilder.buildLayerMesh( ...
                    tileLayer, tileLayer.CurrentProjectionPlane, ...
                    app.Scene.renderOrigin);
                surfaceHandles(tileIndex) = app.createPreviewSurface( ...
                    layerIndex, mesh, tileLayer.DisplayTexture, ...
                    "ProjectionViewerPreviewTileSurface");
            end
        end

        function tileLayer = tilePreviewLayer(app, layerIndex, tile, ...
                includeTexture, maxMeshVertices)
            if nargin < 4
                includeTexture = true;
            end
            if nargin < 5
                maxMeshVertices = app.PreviewTilingOptions.MaxTileMeshVertices;
            end

            pyramid = app.PreviewPyramids{layerIndex};
            tileLayer = app.Scene.layers(layerIndex);
            if includeTexture
                tileImage = ProjectionPreviewPyramid.tileTexture(pyramid, tile);
                tileLayer.DisplayTexture = ...
                    ProjectionViewerHarness.prepareDisplayTexture(tileImage);
            end
            tileLayer.MeshSampling = ProjectionPreviewPyramid.tileMeshSampling( ...
                pyramid, tile, maxMeshVertices);
        end

        function tiles = previewTilesForLayer(app, layerIndex)
            pyramid = app.PreviewPyramids{layerIndex};
            if ~app.IsPreviewCameraReady
                coarsestLevelIndex = numel(pyramid.Levels);
                tiles = ProjectionPreviewPyramid.tileBounds( ...
                    pyramid, coarsestLevelIndex, ...
                    app.PreviewTilingOptions.TileSize);
                return
            end

            startLevelIndex = app.previewLevelIndexForLayer(layerIndex);
            maxVisibleTiles = app.PreviewTilingOptions.MaxVisibleTilesPerLayer;
            tiles = ProjectionPreviewPyramid.emptyTiles();

            for levelIndex = startLevelIndex:numel(pyramid.Levels)
                levelTiles = ProjectionPreviewPyramid.tileBounds( ...
                    pyramid, levelIndex, app.PreviewTilingOptions.TileSize);
                tiles = app.visiblePreviewTiles(layerIndex, levelTiles);
                if numel(tiles) <= maxVisibleTiles
                    return
                end
            end

            if numel(tiles) > maxVisibleTiles
                tiles = tiles(1:maxVisibleTiles);
            end
        end

        function levelIndex = previewLevelIndexForLayer(app, layerIndex)
            pyramid = app.PreviewPyramids{layerIndex};
            desiredDownsample = app.previewDesiredDownsampleForLayer(layerIndex);
            levelIndex = ProjectionPreviewPyramid.selectLevel( ...
                pyramid, desiredDownsample);
        end

        function desiredDownsample = previewDesiredDownsampleForLayer(app, layerIndex)
            layer = app.Scene.layers(layerIndex);
            layer.MeshSampling = app.DefaultMeshSampling(layerIndex);
            mesh = ProjectionMeshBuilder.buildLayerMesh( ...
                layer, layer.CurrentProjectionPlane, app.Scene.renderOrigin);
            [X, Y, Z] = app.previewSurfaceCoordinates(mesh, layerIndex);
            points = [X(:).'; Y(:).'; Z(:).'];

            [rightVector, upVector] = app.cameraScreenBasis();
            [viewWidth, viewHeight] = app.cameraViewWorldSize();
            axesPosition = app.Axes.InnerPosition;
            widthPixels = max(axesPosition(3), 1);
            heightPixels = max(axesPosition(4), 1);
            projectedWidth = max(rightVector.' * points) - ...
                min(rightVector.' * points);
            projectedHeight = max(upVector.' * points) - ...
                min(upVector.' * points);
            footprintPixels = max(projectedWidth / max(viewWidth, eps) * ...
                widthPixels, 1) * max(projectedHeight / max(viewHeight, eps) * ...
                heightPixels, 1);

            imagePixels = prod(double(app.PreviewPyramids{layerIndex}.ImageSize));
            desiredDownsample = max(1, sqrt(imagePixels / footprintPixels));
        end

        function tiles = visiblePreviewTiles(app, layerIndex, tiles)
            if isempty(tiles)
                return
            end

            visibleMask = false(1, numel(tiles));
            for tileIndex = 1:numel(tiles)
                visibleMask(tileIndex) = app.previewTileOverlapsCameraView( ...
                    layerIndex, tiles(tileIndex));
            end
            tiles = tiles(visibleMask);
        end

        function tf = previewTileOverlapsCameraView(app, layerIndex, tile)
            pyramid = app.PreviewPyramids{layerIndex};
            layer = app.Scene.layers(layerIndex);
            layer.MeshSampling = ProjectionPreviewPyramid.tileMeshSampling(pyramid, tile, 2);
            mesh = ProjectionMeshBuilder.buildLayerMesh( ...
                layer, layer.CurrentProjectionPlane, app.Scene.renderOrigin);
            [X, Y, Z] = app.previewSurfaceCoordinates(mesh, layerIndex);
            points = [X(:).'; Y(:).'; Z(:).'];

            [rightVector, upVector] = app.cameraScreenBasis();
            [viewWidth, viewHeight] = app.cameraViewWorldSize();
            center = camtarget(app.Axes).';
            screenX = rightVector.' * (points - center);
            screenY = upVector.' * (points - center);
            halfWidth = 0.5 * viewWidth;
            halfHeight = 0.5 * viewHeight;
            tf = max(screenX) >= -halfWidth && min(screenX) <= halfWidth && ...
                max(screenY) >= -halfHeight && min(screenY) <= halfHeight;
        end

        function refreshTiledProjectionSurfaces(app)
            if isempty(app.Surfaces) || isempty(app.PreviewTiledLayerMask)
                return
            end

            tiledLayerIndices = find(app.PreviewTiledLayerMask);
            for layerIndex = reshape(tiledLayerIndices, 1, [])
                app.refreshTiledLayerSurfaces(layerIndex);
            end
            app.raiseCrosshairOverlay();
        end

        function refreshTiledLayerSurfaces(app, layerIndex)
            tiles = app.previewTilesForLayer(layerIndex);
            app.setTiledLayerSurfaces(layerIndex, tiles, false);
        end

        function updateTiledLayerSurfaceGeometry(app, layerIndex, maxMeshVertices)
            if nargin < 3
                maxMeshVertices = app.PreviewTilingOptions.MaxTileMeshVertices;
            end

            tiles = app.currentPreviewTilesForLayer(layerIndex);
            surfaceHandles = app.validLayerSurfaces(layerIndex);
            if isempty(tiles) || numel(surfaceHandles) ~= numel(tiles)
                app.replaceTiledLayerSurfaces(layerIndex);
                return
            end

            app.updateExistingTiledLayerSurfaces( ...
                layerIndex, tiles, false, maxMeshVertices);
        end

        function replaceTiledLayerSurfaces(app, layerIndex)
            if ~app.usesTiledPreview(layerIndex)
                return
            end

            tiles = app.previewTilesForLayer(layerIndex);
            app.setTiledLayerSurfaces(layerIndex, tiles, true);
        end

        function setTiledLayerSurfaces(app, layerIndex, tiles, updateTexture)
            if nargin < 4
                updateTexture = false;
            end

            surfaceHandles = app.validLayerSurfaces(layerIndex);
            if app.canReuseTiledLayerSurfaces(layerIndex, tiles, surfaceHandles)
                if updateTexture
                    app.updateExistingTiledLayerSurfaces(layerIndex, tiles, true);
                end
                return
            end

            app.deleteLayerSurfaces(layerIndex);
            app.Surfaces{layerIndex} = app.createTiledLayerSurfaces(layerIndex, tiles);
            if layerIndex == app.SelectedLayerIndex
                app.Surface = app.primarySurfaceForLayer(layerIndex);
            end
        end

        function tf = canReuseTiledLayerSurfaces(app, layerIndex, tiles, surfaceHandles)
            previousTiles = app.currentPreviewTilesForLayer(layerIndex);
            tf = numel(surfaceHandles) == numel(tiles) && ...
                isequal(previousTiles, tiles);
        end

        function tiles = currentPreviewTilesForLayer(app, layerIndex)
            if isempty(app.PreviewTiles) || layerIndex > numel(app.PreviewTiles) || ...
                    isempty(app.PreviewTiles{layerIndex})
                tiles = ProjectionPreviewPyramid.emptyTiles();
            else
                tiles = app.PreviewTiles{layerIndex};
            end
        end

        function updateExistingTiledLayerSurfaces(app, layerIndex, tiles, ...
                updateTexture, maxMeshVertices)
            if nargin < 5
                maxMeshVertices = app.PreviewTilingOptions.MaxTileMeshVertices;
            end

            surfaceHandles = app.validLayerSurfaces(layerIndex);
            for tileIndex = 1:numel(tiles)
                tileLayer = app.tilePreviewLayer( ...
                    layerIndex, tiles(tileIndex), updateTexture, maxMeshVertices);
                mesh = ProjectionMeshBuilder.buildLayerMesh( ...
                    tileLayer, tileLayer.CurrentProjectionPlane, ...
                    app.Scene.renderOrigin);
                app.updatePreviewSurfaceHandle( ...
                    surfaceHandles(tileIndex), layerIndex, mesh, updateTexture);
            end
            app.PreviewTiles{layerIndex} = tiles;
            if layerIndex == app.SelectedLayerIndex
                app.Surface = app.primarySurfaceForLayer(layerIndex);
            end
        end

        function surfaceHandles = validLayerSurfaces(app, layerIndex)
            if isempty(app.Surfaces) || layerIndex > numel(app.Surfaces) || ...
                    isempty(app.Surfaces{layerIndex})
                surfaceHandles = gobjects(0);
                return
            end

            surfaceHandles = app.Surfaces{layerIndex};
            surfaceHandles = surfaceHandles(isgraphics(surfaceHandles));
        end

        function surfaceHandle = primarySurfaceForLayer(app, layerIndex)
            surfaceHandles = app.validLayerSurfaces(layerIndex);
            if isempty(surfaceHandles)
                surfaceHandle = gobjects(0);
            else
                surfaceHandle = surfaceHandles(1);
            end
        end

        function deleteLayerSurfaces(app, layerIndex)
            surfaceHandles = app.validLayerSurfaces(layerIndex);
            if ~isempty(surfaceHandles)
                delete(surfaceHandles);
            end
            if ~isempty(app.Surfaces) && layerIndex <= numel(app.Surfaces)
                app.Surfaces{layerIndex} = gobjects(0);
            end
            if ~isempty(app.PreviewTiles) && layerIndex <= numel(app.PreviewTiles)
                app.PreviewTiles{layerIndex} = ProjectionPreviewPyramid.emptyTiles();
            end
        end

        function setLayerSurfaceVisible(app, layerIndex, isVisible)
            surfaceHandles = app.validLayerSurfaces(layerIndex);
            for surfaceIndex = 1:numel(surfaceHandles)
                surfaceHandles(surfaceIndex).Visible = app.onOff(isVisible);
            end
        end

        function setLayerSurfaceAlpha(app, layerIndex, alpha)
            surfaceHandles = app.validLayerSurfaces(layerIndex);
            faceAlpha = app.previewFaceAlphaForLayer(alpha, layerIndex);
            for surfaceIndex = 1:numel(surfaceHandles)
                surfaceHandles(surfaceIndex).FaceAlpha = faceAlpha;
            end
        end

        function raiseCrosshairOverlay(app)
            if ~isempty(app.CrosshairHorizontal) && isvalid(app.CrosshairHorizontal)
                uistack(app.CrosshairHorizontal, "top");
            end
            if ~isempty(app.CrosshairVertical) && isvalid(app.CrosshairVertical)
                uistack(app.CrosshairVertical, "top");
            end
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
            app.IsPreviewCameraReady = true;
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
            app.refreshTiledProjectionSurfaces();

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
            if app.adjustProjectionFromArrowKey(event)
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
            app.updatePan();
            app.updateCrosshair();
        end

        function scrollWheel(app, event)
            if app.IsControlDown || app.eventHasControl(event)
                app.scrollTwist(event);
                app.updateCrosshair();
                return
            end
            if app.IsShiftDown || app.eventHasShift(event)
                app.scrollTip(event);
                app.updateCrosshair();
                return
            end
            if app.IsAltDown || app.eventHasAlt(event)
                app.scrollTilt(event);
                app.updateCrosshair();
                return
            end
            app.scrollZoom(event);
            app.updateCrosshair();
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

        function handled = adjustProjectionFromArrowKey(app, event)
            handled = true;
            tipDelta = 0;
            tiltDelta = 0;
            if app.eventKeyIs(event, "uparrow")
                tipDelta = app.ProjectionArrowStepDegrees;
            elseif app.eventKeyIs(event, "downarrow")
                tipDelta = -app.ProjectionArrowStepDegrees;
            elseif app.eventKeyIs(event, "rightarrow")
                tiltDelta = app.ProjectionArrowStepDegrees;
            elseif app.eventKeyIs(event, "leftarrow")
                tiltDelta = -app.ProjectionArrowStepDegrees;
            else
                handled = false;
                return
            end

            tipDegrees = app.clampSliderValue( ...
                app.TipSlider, app.TipSlider.Value + tipDelta);
            tiltDegrees = app.clampSliderValue( ...
                app.TiltSlider, app.TiltSlider.Value + tiltDelta);
            app.TipSlider.Value = tipDegrees;
            app.TiltSlider.Value = tiltDegrees;
            app.updateProjection(tipDegrees, tiltDegrees, ...
                app.AlphaSlider.Value, app.DefaultMeshSampling);
            app.PreviewTimer = tic;
        end

        function value = sliderWheelValue(app, slider, event)
            value = slider.Value - ...
                event.VerticalScrollCount * app.ModifierWheelStepDegrees;
            value = app.clampSliderValue(slider, value);
        end

        function value = clampSliderValue(~, slider, value)
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
            app.refreshTiledProjectionSurfaces();
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
            hasAlt = app.IsAltDown || app.eventHasAlt(event);
            if hasControl && any(selectionType == ["normal", "alt"])
                app.DragMode = "translateLayer";
            elseif hasAlt && selectionType == "normal"
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
            app.refreshTiledProjectionSurfaces();
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

        function [viewWidth, viewHeight] = cameraViewWorldSize(app)
            axesPosition = app.Axes.InnerPosition;
            widthPixels = max(axesPosition(3), 1);
            heightPixels = max(axesPosition(4), 1);
            [~, ~, ~, viewDistance] = app.cameraScreenBasis();
            viewHeight = 2 * viewDistance * tan( ...
                deg2rad(app.Axes.CameraViewAngle) / 2);
            viewWidth = viewHeight * widthPixels / heightPixels;
            viewWidth = max(viewWidth, eps);
            viewHeight = max(viewHeight, eps);
        end

        function frameCurrentProjectionView(app, fillFraction)
            fillFraction = app.validateViewportFillFraction(fillFraction);
            [projectedWidth, projectedHeight] = app.currentSurfaceProjectedSize();
            if any(~isfinite([projectedWidth projectedHeight])) || ...
                    max(projectedWidth, projectedHeight) <= eps
                return
            end

            axesPosition = app.Axes.InnerPosition;
            aspectRatio = max(axesPosition(3), 1) / max(axesPosition(4), 1);
            desiredViewHeight = max(projectedHeight / fillFraction, ...
                projectedWidth / (aspectRatio * fillFraction));
            [~, ~, ~, viewDistance] = app.cameraScreenBasis();
            desiredViewAngle = rad2deg(2 * atan(desiredViewHeight / ...
                (2 * viewDistance)));
            app.Axes.CameraViewAngle = min(max(desiredViewAngle, ...
                app.MinCameraViewAngle), app.MaxCameraViewAngle);
        end

        function [projectedWidth, projectedHeight] = currentSurfaceProjectedSize(app)
            layerIndices = find([app.Scene.layers.Visible]);
            if isempty(layerIndices)
                layerIndices = app.SelectedLayerIndex;
            end

            points = zeros(3, 0);
            for layerIndex = reshape(layerIndices, 1, [])
                surfaceHandles = app.validLayerSurfaces(layerIndex);
                for surfaceIndex = 1:numel(surfaceHandles)
                    surfaceHandle = surfaceHandles(surfaceIndex);
                    points = [points, [surfaceHandle.XData(:).'; ...
                        surfaceHandle.YData(:).'; ...
                        surfaceHandle.ZData(:).']]; %#ok<AGROW>
                end
            end

            if isempty(points)
                projectedWidth = NaN;
                projectedHeight = NaN;
                return
            end

            [rightVector, upVector] = app.cameraScreenBasis();
            projectedWidth = max(rightVector.' * points) - ...
                min(rightVector.' * points);
            projectedHeight = max(upVector.' * points) - ...
                min(upVector.' * points);
        end

        function fillFraction = validateViewportFillFraction(~, fillFraction)
            if ~isnumeric(fillFraction) || ~isscalar(fillFraction) || ...
                    ~isfinite(fillFraction) || fillFraction <= 0 || ...
                    fillFraction > 1
                error("ProjectionViewerApp:invalidViewportFillFraction", ...
                    "Viewport fill fraction must be in the range (0, 1].");
            end
            fillFraction = double(fillFraction);
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
            app.setLayerSurfaceAlpha(layerIndex, alpha);
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
            tileMeshVertexLimit = app.previewTileMeshVertexLimit(meshSamplings);

            for layerIndex = 1:numel(app.Scene.layers)
                layer = app.Scene.layers(layerIndex);
                layer.CurrentProjectionPlane = plane;
                if layerIndex == selectedLayerIndex
                    layer.Alpha = alpha;
                end
                layer.MeshSampling = meshSamplings(layerIndex);
                app.Scene.layers(layerIndex) = layer;

                if app.usesTiledPreview(layerIndex)
                    app.updateTiledLayerSurfaceGeometry(layerIndex, tileMeshVertexLimit);
                    if layerIndex == selectedLayerIndex
                        app.CurrentMesh = struct();
                        app.Surface = app.primarySurfaceForLayer(layerIndex);
                    end
                    continue
                end

                mesh = ProjectionMeshBuilder.buildLayerMesh( ...
                    layer, plane, app.Scene.renderOrigin);
                app.updateSurfaceFromMesh(layerIndex, mesh);
                if layerIndex == selectedLayerIndex
                    app.CurrentMesh = mesh;
                    app.Surface = app.primarySurfaceForLayer(layerIndex);
                end
            end

            app.updateLabels(tipDegrees, tiltDegrees, app.ViewTwistDegrees, alpha);
            if isequal(meshSamplings, app.DefaultMeshSampling)
                app.refreshAlignmentOverlays();
            end
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

                if app.usesTiledPreview(layerIndex)
                    app.replaceTiledLayerSurfaces(layerIndex);
                    if layerIndex == app.SelectedLayerIndex
                        app.CurrentMesh = struct();
                        app.Surface = app.primarySurfaceForLayer(layerIndex);
                    end
                    continue
                end

                mesh = ProjectionMeshBuilder.buildLayerMesh( ...
                    layer, plane, app.Scene.renderOrigin);
                app.updateSurfaceFromMesh(layerIndex, mesh);
                if layerIndex == app.SelectedLayerIndex
                    app.CurrentMesh = mesh;
                    app.Surface = app.primarySurfaceForLayer(layerIndex);
                end
            end

            if isequal(meshSamplings, app.DefaultMeshSampling)
                app.refreshAlignmentOverlays();
            end
        end

        function updateSurfaceFromMesh(app, layerIndex, mesh)
            if app.usesTiledPreview(layerIndex)
                app.updateTiledLayerSurfaceGeometry(layerIndex);
                return
            end

            surfaceHandle = app.Surfaces{layerIndex};
            app.updatePreviewSurfaceHandle(surfaceHandle, layerIndex, mesh, true);
        end

        function updatePreviewSurfaceHandle(app, surfaceHandle, layerIndex, ...
                mesh, updateTexture)
            [X, Y, Z] = app.previewSurfaceCoordinates(mesh, layerIndex);
            surfaceHandle.XData = X;
            surfaceHandle.YData = Y;
            surfaceHandle.ZData = Z;
            if updateTexture
                surfaceHandle.CData = app.previewTextureForLayer( ...
                    mesh.Texture, layerIndex);
            end
            surfaceHandle.FaceAlpha = app.previewFaceAlphaForLayer( ...
                mesh.Alpha, layerIndex);
            surfaceHandle.Visible = app.onOff(mesh.Visible);
        end

        function maxVertices = previewTileMeshVertexLimit(app, meshSamplings)
            maxVertices = app.PreviewTilingOptions.MaxTileMeshVertices;
            if isequal(meshSamplings, app.DragMeshSampling)
                maxVertices = min(maxVertices, app.InteractivePreviewMaxTileMeshVertices);
            end
        end

        function updateAllSurfaceBlendAppearance(app)
            for layerIndex = 1:numel(app.Surfaces)
                if app.usesTiledPreview(layerIndex)
                    app.updateTiledLayerSurfaceAppearance(layerIndex);
                    continue
                end

                surfaceHandle = app.primarySurfaceForLayer(layerIndex);
                if isempty(surfaceHandle) || ~isgraphics(surfaceHandle)
                    continue
                end
                layer = app.Scene.layers(layerIndex);
                surfaceHandle.CData = app.previewTextureForLayer( ...
                    layer.DisplayTexture, layerIndex);
                surfaceHandle.FaceAlpha = app.previewFaceAlphaForLayer( ...
                    layer.Alpha, layerIndex);
                surfaceHandle.Visible = app.onOff(layer.Visible);
            end
        end

        function updateTiledLayerSurfaceAppearance(app, layerIndex)
            tiles = app.currentPreviewTilesForLayer(layerIndex);
            surfaceHandles = app.validLayerSurfaces(layerIndex);
            if isempty(tiles) || numel(surfaceHandles) ~= numel(tiles)
                app.replaceTiledLayerSurfaces(layerIndex);
                return
            end

            for tileIndex = 1:numel(tiles)
                tileLayer = app.tilePreviewLayer(layerIndex, tiles(tileIndex));
                surfaceHandles(tileIndex).CData = app.previewTextureForLayer( ...
                    tileLayer.DisplayTexture, layerIndex);
                surfaceHandles(tileIndex).FaceAlpha = app.previewFaceAlphaForLayer( ...
                    tileLayer.Alpha, layerIndex);
                surfaceHandles(tileIndex).Visible = app.onOff(tileLayer.Visible);
            end
        end

        function texture = previewTextureForLayer(app, texture, layerIndex)
            layer = app.Scene.layers(layerIndex);
            if lower(string(layer.BlendMode)) ~= "redblueanaglyph"
                return
            end

            gray = app.grayscaleDisplayTexture(texture);
            texture = zeros([size(gray, 1), size(gray, 2), 3], "like", texture);
            channelIndex = app.anaglyphChannelForLayer(layerIndex);
            texture(:, :, channelIndex) = gray;
        end

        function alpha = previewFaceAlphaForLayer(app, alpha, layerIndex)
            layer = app.Scene.layers(layerIndex);
            if lower(string(layer.BlendMode)) == "redblueanaglyph" && ...
                    app.visibleAnaglyphLayerCount() > 1
                alpha = min(alpha, app.AnaglyphPreviewFaceAlpha);
            end
        end

        function channelIndex = anaglyphChannelForLayer(app, layerIndex)
            anaglyphLayers = find([app.Scene.layers.Visible] & ...
                lower(string([app.Scene.layers.BlendMode])) == "redblueanaglyph");
            ordinal = find(anaglyphLayers == layerIndex, 1, "first");
            if isempty(ordinal)
                ordinal = 1;
            end
            channelIndex = 1 + 2 * double(mod(ordinal, 2) == 0);
        end

        function count = visibleAnaglyphLayerCount(app)
            count = nnz([app.Scene.layers.Visible] & ...
                lower(string([app.Scene.layers.BlendMode])) == "redblueanaglyph");
        end

        function gray = grayscaleDisplayTexture(~, texture)
            if ismatrix(texture)
                gray = texture;
            elseif isinteger(texture)
                gray = cast(round(mean(double(texture), 3)), class(texture));
            elseif islogical(texture)
                gray = any(texture, 3);
            else
                gray = mean(texture, 3);
            end
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
            [minimums, maximums] = app.previewBoundsForProjectionRange();
            spans = maximums - minimums;
            padding = max(0.05 * max(spans), app.previewLayerDepthStepMeters());
            if ~isfinite(padding) || padding <= 0
                padding = 1;
            end

            app.Axes.XLim = [minimums(1) - padding, maximums(1) + padding];
            app.Axes.YLim = [minimums(2) - padding, maximums(2) + padding];
            app.Axes.ZLim = [minimums(3) - padding, maximums(3) + padding];
            app.Axes.XLimMode = "manual";
            app.Axes.YLimMode = "manual";
            app.Axes.ZLimMode = "manual";
            app.Axes.DataAspectRatio = [1 1 1];
            app.Axes.DataAspectRatioMode = "manual";
            app.Axes.PlotBoxAspectRatioMode = "auto";
        end

        function [minimums, maximums] = previewBoundsForProjectionRange(app)
            minimums = [Inf; Inf; Inf];
            maximums = [-Inf; -Inf; -Inf];
            tipSamples = unique([0 app.TipSlider.Limits]);
            tiltSamples = unique([0 app.TiltSlider.Limits]);

            for tipDegrees = tipSamples
                for tiltDegrees = tiltSamples
                    plane = ProjectionMeshBuilder.applyPlaneTipTilt( ...
                        app.Scene.layers(1).BaseProjectionPlane, ...
                        deg2rad(tipDegrees), deg2rad(tiltDegrees));
                    for layerIndex = 1:numel(app.Scene.layers)
                        layer = app.Scene.layers(layerIndex);
                        layer.CurrentProjectionPlane = plane;
                        layer.MeshSampling = app.DefaultMeshSampling(layerIndex);
                        try
                            mesh = ProjectionMeshBuilder.buildLayerMesh( ...
                                layer, plane, app.Scene.renderOrigin);
                        catch ME
                            if app.isPreviewBoundsIntersectionError(ME)
                                continue
                            end
                            rethrow(ME);
                        end
                        [X, Y, Z] = app.previewSurfaceCoordinates(mesh, layerIndex);
                        [minimums, maximums] = app.accumulatePreviewBounds( ...
                            minimums, maximums, X, Y, Z);
                    end
                end
            end

            if any(~isfinite(minimums)) || any(~isfinite(maximums))
                minimums = [-1; -1; -1];
                maximums = [1; 1; 1];
            end
        end

        function [minimums, maximums] = accumulatePreviewBounds(~, ...
                minimums, maximums, X, Y, Z)
            minimums = min(minimums, [min(X, [], "all"); ...
                min(Y, [], "all"); min(Z, [], "all")]);
            maximums = max(maximums, [max(X, [], "all"); ...
                max(Y, [], "all"); max(Z, [], "all")]);
        end

        function tf = isPreviewBoundsIntersectionError(~, ME)
            tf = any(string(ME.identifier) == ...
                ["ProjectionMeshBuilder:behindSource", ...
                "ProjectionMeshBuilder:parallelRay"]);
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
            app.Scene = app.ResetScene;
            app.SelectedLayerIndex = numel(app.Scene.layers);
            app.DefaultMeshSampling = [app.Scene.layers.MeshSampling];
            app.DragMeshSampling = app.createDragMeshSampling();
            app.initializePreviewPyramids();
            app.TipSlider.Value = 0;
            app.TiltSlider.Value = 0;
            app.TwistSlider.Value = 0;
            app.AlphaSlider.Value = 1;
            app.ProjectionTipDegrees = 0;
            app.ProjectionTiltDegrees = 0;
            app.ViewTwistDegrees = 0;
            app.IsControlDown = false;
            app.IsShiftDown = false;
            app.IsAltDown = false;
            app.DragMode = "none";
            app.LastPointerLocation = [NaN NaN];
            app.NeedsDragFinalize = false;
            app.IsPreviewCameraReady = false;
            app.clearAlignmentComputationState();
            app.AlignmentCancelRequested = false;
            app.clearAlignmentOverlays();
            app.clearAlignmentRoi(false);
            app.setAlignmentActionEnabled(false);
            app.setAlignmentSolveEnabled(false);
            app.setAlignmentStatus("Alignment not run");
            app.rebuildSurfaces();
            app.configureFrameCamera();
            app.frameCurrentProjectionView(app.InitialViewportFillFraction);
            app.updateLayerDropDownItems();
            app.updateControlsFromSelectedLayer();
            app.refreshTiledProjectionSurfaces();
            app.PreviewTimer = tic;
            app.updateCrosshair();
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

        function setSelectedLayerBlendMode(app, blendMode)
            targetLayerIndices = find([app.Scene.layers.Visible]);
            if isempty(targetLayerIndices)
                targetLayerIndices = app.SelectedLayerIndex;
            end
            for layerIndex = reshape(targetLayerIndices, 1, [])
                layer = app.Scene.layers(layerIndex);
                layer.BlendMode = string(blendMode);
                app.Scene.layers(layerIndex) = layer;
            end
            app.updateAllSurfaceBlendAppearance();
            app.updateBlendMenuChecks();
        end

        function cycleLayer(app)
            nextLayerIndex = mod(app.SelectedLayerIndex, numel(app.Scene.layers)) + 1;
            for layerIndex = 1:numel(app.Scene.layers)
                layer = app.Scene.layers(layerIndex);
                layer.Visible = layerIndex == nextLayerIndex;
                app.Scene.layers(layerIndex) = layer;
                app.setLayerSurfaceVisible(layerIndex, layer.Visible);
            end
            app.updateAllSurfaceBlendAppearance();
            app.SelectedLayerIndex = nextLayerIndex;
            app.updateControlsFromSelectedLayer();
        end

        function moveSelectedLayerUp(app)
            app.swapSelectedLayer(1);
        end

        function moveSelectedLayerDown(app)
            app.swapSelectedLayer(-1);
        end

        function swapSelectedLayer(app, direction)
            targetIndex = app.SelectedLayerIndex + direction;
            if targetIndex < 1 || targetIndex > numel(app.Scene.layers)
                return
            end

            swapIndices = [app.SelectedLayerIndex targetIndex];
            app.Scene.layers(swapIndices) = app.Scene.layers(fliplr(swapIndices));
            app.DefaultMeshSampling(swapIndices) = ...
                app.DefaultMeshSampling(fliplr(swapIndices));
            app.DragMeshSampling(swapIndices) = ...
                app.DragMeshSampling(fliplr(swapIndices));
            app.PreviewPyramids(swapIndices) = ...
                app.PreviewPyramids(fliplr(swapIndices));
            app.PreviewTiledLayerMask(swapIndices) = ...
                app.PreviewTiledLayerMask(fliplr(swapIndices));
            app.SelectedLayerIndex = targetIndex;
            app.refreshProjectionSurfaces(app.DefaultMeshSampling);
            app.updateLayerDropDownItems();
            app.updateControlsFromSelectedLayer();
        end

        function updateControlsFromSelectedLayer(app)
            layer = app.Scene.layers(app.SelectedLayerIndex);
            app.updateLayerDropDownItems();
            app.LayerDropDown.Value = app.SelectedLayerIndex;
            app.TipSlider.Value = app.ProjectionTipDegrees;
            app.TiltSlider.Value = app.ProjectionTiltDegrees;
            app.TwistSlider.Value = app.ViewTwistDegrees;
            app.AlphaSlider.Value = layer.Alpha;
            app.VisibleCheckBox.Value = layer.Visible;
            app.updateBlendMenuChecks();
            app.Surface = app.primarySurfaceForLayer(app.SelectedLayerIndex);
            app.updateLabels(app.TipSlider.Value, app.TiltSlider.Value, ...
                app.TwistSlider.Value, layer.Alpha);
        end

        function updateLayerDropDownItems(app)
            app.LayerDropDown.Items = cellstr(app.layerDisplayNames());
            app.LayerDropDown.ItemsData = 1:numel(app.Scene.layers);
            app.updateAlignmentLayerItems();
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
            app.updateAllSurfaceBlendAppearance();
            app.VisibleCheckBox.Value = layer.Visible;
        end

        function updateBlendMenuChecks(app)
            if isempty(app.AlphaBlendMenuItem) || ~isvalid(app.AlphaBlendMenuItem)
                return
            end

            visibleModes = app.visibleBlendModes();
            app.AlphaBlendMenuItem.Checked = app.onOff(all(visibleModes == "alpha"));
            app.AnaglyphBlendMenuItem.Checked = ...
                app.onOff(all(visibleModes == "redBlueAnaglyph"));
        end

        function modes = visibleBlendModes(app)
            visibleMask = [app.Scene.layers.Visible];
            if ~any(visibleMask)
                visibleMask(app.SelectedLayerIndex) = true;
            end
            modes = string([app.Scene.layers(visibleMask).BlendMode]);
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
            pointerFraction = (pointer - axesPosition(1:2)) ./ ...
                max(axesPosition(3:4), 1);
            pointerFraction = min(max(pointerFraction, 0), 1);

            [rightVector, upVector, viewDirection, viewDistance] = ...
                app.cameraScreenBasis();
            axesWidth = max(axesPosition(3), 1);
            axesHeight = max(axesPosition(4), 1);
            viewHeight = 2 * viewDistance * tan( ...
                deg2rad(app.Axes.CameraViewAngle) / 2);
            viewWidth = viewHeight * axesWidth / axesHeight;
            center = camtarget(app.Axes).' - 0.25 * viewDistance * viewDirection;
            xOffset = (pointerFraction(1) - 0.5) * viewWidth;
            yOffset = (pointerFraction(2) - 0.5) * viewHeight;
            horizontalPoints = center + yOffset * upVector + ...
                [-0.5 0.5] .* viewWidth .* rightVector;
            verticalPoints = center + xOffset * rightVector + ...
                [-0.5 0.5] .* viewHeight .* upVector;

            app.CrosshairHorizontal.XData = horizontalPoints(1, :);
            app.CrosshairHorizontal.YData = horizontalPoints(2, :);
            app.CrosshairHorizontal.ZData = horizontalPoints(3, :);
            app.CrosshairVertical.XData = verticalPoints(1, :);
            app.CrosshairVertical.YData = verticalPoints(2, :);
            app.CrosshairVertical.ZData = verticalPoints(3, :);
            app.CrosshairHorizontal.Visible = "on";
            app.CrosshairVertical.Visible = "on";
            app.raiseCrosshairOverlay();
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
                "Alt/Option + left drag: adjust selected-layer omega and phi"
                "Double left click: show the next layer and hide the others"
                ""
                "Keyboard"
                "Up/Down arrows: adjust Tip by 0.5 deg"
                "Left/Right arrows: adjust Tilt by 0.5 deg"
                "W/A/S/D: nudge the selected layer"
                "I/K: adjust phi"
                "J/L: adjust omega"
                "U/O: adjust kappa"
                "Space down: hide the selected layer"
                "Space up: show the selected layer"
                ""
                "Context menu"
                "Right click inside the image for Save, Load, Cycle, Reset, Help, Crosshair, Alignment panel,"
                "Clear alignment overlays, and Blend mode."
                "Crosshair overlays cyan screen-space guide lines across the viewport."
                "Reset restores neutral tip, tilt, twist, layer order, visibility, alpha, blend mode, offsets, and OPK corrections."
                "+/- beside Layer move the selected layer one step up or down in the stack."
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
