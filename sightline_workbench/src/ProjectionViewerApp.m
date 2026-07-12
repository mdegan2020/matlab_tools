classdef ProjectionViewerApp < handle
    %ProjectionViewerApp Programmatic preview app for projected imagery.

    properties (Access = private)
        Scene struct
        CurrentMesh struct
        Surfaces cell
        DefaultMeshSampling struct
        DragMeshSampling struct
        PreviewPyramids cell
        PreviewGeometryCaches cell
        PreviewGeometryGenerations double
        PreviewTilingOptions struct
        PreviewTiledLayerMask logical
        PreviewTiles cell
        PreviewTileKeys cell
        PreviewTileDataCache
        PreviewSampledGeometryCache
        PreviewSurfacePool = gobjects(0)
        PreviewCurrentLevelIndices double
        PreviewDesiredLevelIndices double
        PreviewDesiredDownsamples double
        PreviewDesiredDownsamplesPerAxis double
        PreviewPendingLevelIndices double
        PreviewPredictedCandidateCounts double
        PreviewPredictedVisibleTileCounts double
        PreviewPredictedTextureBytes double
        PreviewLayerSurfaceBudgets double
        PreviewLayerTextureBudgets double
        PreviewBudgetLimitedLayerMask logical
        RenderedLayerAlphas double
        PendingAlphaMask logical
        AlphaPreviewTimer
        IsPreviewCameraReady logical = false
        ProjectionTipDegrees double = 0
        ProjectionTiltDegrees double = 0
        ViewTwistDegrees double = 0
        SelectedLayerIndex double = 1
        IsControlDown logical = false
        IsShiftDown logical = false
        IsAltDown logical = false
        ViewportKeyboardMode string = "normal"
        DragMode string = "none"
        LastPointerLocation double = [NaN NaN]
        NeedsDragFinalize logical = false
        PreviewTimer
        CameraSettleTimer
        CameraScheduleGeneration uint64 = uint64(0)
        IsCameraReconciliationPending logical = false
        PerformanceMonitor
        MinPreviewInterval double = 1 / 30
        CameraSettleDelaySeconds double = 0.12
        PreviewLodPromoteThreshold double = 0.75
        PreviewLodDemoteThreshold double = 1.75
        PreviewViewportHaloFraction double = 0.2
        PreviewTileCacheMaxBytes double = 256 * 1024 ^ 2
        PreviewSampleCacheMaxBytes double = 64 * 1024 ^ 2
        PreviewSurfacePoolMaxCount double = 64
        PreviewMaxVisibleSurfaces double = 48
        PreviewMaxVisibleTextureBytes double = 256 * 1024 ^ 2
        PreviewTargetMaxTilesPerLayer double = 12
        PreviewAutomaticTilePolicy logical = false
        AlphaPreviewMinIntervalSeconds double = 0.05
        MinCameraViewAngle double = 1e-6
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
        AnaglyphPreviewFaceAlpha double = 0.70
        AnaglyphChannelGain double = 1.25
        AnaglyphOffChannelFloor double = 0.08
        AnaglyphStereoExaggeration double = 1
        AnaglyphStereoExaggerationStep double = 0.25
        AnaglyphStereoExaggerationLimits double = [0 3]
        AnaglyphStereoBaseSeparationFraction double = 0.01
        AnaglyphScreenDepthOffsetMeters double = 0
        AnaglyphScreenDepthStepFraction double = 0.01
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
        AnaglyphControlsMenu
        AnaglyphIncreaseSeparationMenuItem
        AnaglyphDecreaseSeparationMenuItem
        AnaglyphMoveNearerMenuItem
        AnaglyphMoveFartherMenuItem
        AnaglyphResetPresentationMenuItem
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
        IsCrosshairVisible logical = false
        IsPointerMotionBusy logical = false
        AlignmentLauncherGrid matlab.ui.container.GridLayout
        AlignmentGrid matlab.ui.container.GridLayout
        AlignmentOpenWorkbenchButton matlab.ui.control.Button
        AlignmentLauncherStatusLabel matlab.ui.control.Label
        AlignmentWorkbenchFigure matlab.ui.Figure
        AlignmentWorkbenchGrid matlab.ui.container.GridLayout
        AlignmentStageLabel matlab.ui.control.Label
        AlignmentDiagnosticsTextArea matlab.ui.control.TextArea
        AlignmentReferenceDropDown matlab.ui.control.DropDown
        AlignmentMovingDropDown matlab.ui.control.DropDown
        AlignmentSwapPairButton matlab.ui.control.Button
        AlignmentPreviousPairButton matlab.ui.control.Button
        AlignmentNextPairButton matlab.ui.control.Button
        AlignmentPairStatusLabel matlab.ui.control.Label
        AlignmentPairEnabledCheckBox matlab.ui.control.StateButton
        AlignmentSoloPairCheckBox matlab.ui.control.StateButton
        AlignmentPairViewButton matlab.ui.control.Button
        AlignmentRestoreViewButton matlab.ui.control.Button
        AlignmentFollowPairCheckBox matlab.ui.control.StateButton
        AlignmentSwapEyesButton matlab.ui.control.Button
        AlignmentResetEyesButton matlab.ui.control.Button
        AlignmentStereoEyeStatusLabel matlab.ui.control.Label
        AlignmentPairViewStatusLabel matlab.ui.control.Label
        AlignmentPresetDropDown matlab.ui.control.DropDown
        AlignmentScopeDropDown matlab.ui.control.DropDown
        AlignmentDetectorDropDown matlab.ui.control.DropDown
        AlignmentPairGraphModeDropDown matlab.ui.control.DropDown
        AlignmentMaxPairsSpinner matlab.ui.control.Spinner
        AlignmentAllPairsCheckBox matlab.ui.control.CheckBox
        AlignmentLossDropDown matlab.ui.control.DropDown
        AlignmentCoplanarityDropDown matlab.ui.control.DropDown
        AlignmentReferenceMotionCheckBox matlab.ui.control.StateButton
        AlignmentRoiButton matlab.ui.control.Button
        AlignmentClearRoiButton matlab.ui.control.Button
        AlignmentMatchButton matlab.ui.control.Button
        AlignmentFilterButton matlab.ui.control.Button
        AlignmentSolveButton matlab.ui.control.Button
        AlignmentCancelButton matlab.ui.control.Button
        AlignmentPreviewButton matlab.ui.control.Button
        AlignmentApplyButton matlab.ui.control.Button
        AlignmentRevertButton matlab.ui.control.Button
        AlignmentClearOverlaysButton matlab.ui.control.Button
        AlignmentAcceptedOverlayCheckBox matlab.ui.control.StateButton
        AlignmentRejectedOverlayCheckBox matlab.ui.control.StateButton
        AlignmentWorstOverlayCheckBox matlab.ui.control.StateButton
        AlignmentFeatureOverlayCheckBox matlab.ui.control.StateButton
        AlignmentDeleteMatchButton matlab.ui.control.Button
        AlignmentUndoCurationButton matlab.ui.control.Button
        AlignmentDenseSurfaceButton matlab.ui.control.Button
        AlignmentStatusLabel matlab.ui.control.Label
        AlignmentPairTable matlab.ui.control.Table
        AlignmentMatchTable matlab.ui.control.Table
        AlignmentSession
        AlignmentPairController
        StereoEyeController
        AlignmentSoloState struct = struct()
        PairViewpointRuntime struct = struct()
        MotionRuntime struct = struct()
        MotionFigure matlab.ui.Figure
        MotionTable matlab.ui.control.Table
        MotionPassDropDown matlab.ui.control.DropDown
        MotionLoopCheckBox matlab.ui.control.CheckBox
        MotionHoverCheckBox matlab.ui.control.CheckBox
        MotionPinCheckBox matlab.ui.control.CheckBox
        MotionStartExitButton matlab.ui.control.Button
        MotionPreviousButton matlab.ui.control.Button
        MotionNextButton matlab.ui.control.Button
        MotionPlayPauseButton matlab.ui.control.Button
        MotionRateSpinner matlab.ui.control.Spinner
        MotionStatusLabel matlab.ui.control.Label
        MotionImageryMenuItem
        MotionLeftEdgeButton matlab.ui.control.Button
        MotionRightEdgeButton matlab.ui.control.Button
        MotionIdentityLabel matlab.ui.control.Label
        MotionIdentityTimer
        MotionPlaybackTimer
        MotionEdgeWidthPixels double = 64
        MotionIdentitySeconds double = 2
        AlignmentOverlayLines = gobjects(0)
        AlignmentSelectedMatchOverlay = gobjects(0)
        AlignmentRoiHandle = []
        AlignmentRoiListeners = []
        AlignmentRoiDrawingActive logical = false
        AlignmentRoiStartPoint double = [NaN NaN]
        AlignmentAnchorDragState struct = struct()
        AlignmentAnchorDragCancelled logical = false
        DenseSurfaceHandles struct = struct()
        DenseSurfaceDiagnostics struct = struct()
        DenseSurfaceRunning logical = false
        CorrectionStore
        AlignmentAppliedGenerationId string = ""
    end

    properties (Access = private, Dependent)
        AlignmentRequest
        AlignmentWorkingImages
        AlignmentWorkingImageCacheKey
        AlignmentWorkingImageCacheValue
        AlignmentWorkingImageCacheHits
        AlignmentWorkingImageCacheMisses
        AlignmentRawMatchResult
        AlignmentPreRoiMatchResult
        AlignmentFilteredMatchResult
        AlignmentCuratedMatchMask
        AlignmentDeletedMatchMask
        AlignmentCurationUndoStack
        AlignmentSelectedMatchRows
        AlignmentResult
        AlignmentRoiBounds
        AlignmentCancelRequested
    end

    methods
        function app = ProjectionViewerApp( ...
                scene, projectionPlane, viewerState, correctionOptions)
            if nargin < 1
                scene = ProjectionViewerHarness.createDefaultScene();
            end
            if nargin < 2
                projectionPlane = [];
            end
            if nargin < 3
                viewerState = [];
            end
            if nargin < 4
                correctionOptions = struct();
            end
            if ~isempty(projectionPlane) && ProjectionViewerState.isState(projectionPlane)
                viewerState = projectionPlane;
                projectionPlane = [];
            end
            if nargin >= 2 && ~isempty(projectionPlane)
                scene = ProjectionViewerHarness.applyProjectionPlane(scene, projectionPlane);
            end
            scene = ProjectionViewMetadata.ensureScene(scene);

            app.Scene = scene;
            app.AlignmentSession = ProjectionAlignmentSession();
            app.ResetScene = app.createResetScene(scene);
            app.PerformanceMonitor = ProjectionViewerPerformanceMonitor();
            app.PreviewTileDataCache = ProjectionViewerLruCache( ...
                app.PreviewTileCacheMaxBytes);
            app.PreviewSampledGeometryCache = ProjectionViewerLruCache( ...
                app.PreviewSampleCacheMaxBytes);
            app.SelectedLayerIndex = numel(app.Scene.layers);
            app.AlignmentPairController = ProjectionPairController(app.Scene);
            app.StereoEyeController = ProjectionStereoEyeController();
            if numel(app.Scene.layers) > 1
                referenceIndex = ceil(numel(app.Scene.layers) / 2);
                movingIndex = app.SelectedLayerIndex;
                if movingIndex == referenceIndex
                    movingIndex = min(numel(app.Scene.layers), ...
                        referenceIndex + 1);
                end
                viewIds = ProjectionViewMetadata.ids(app.Scene);
                app.AlignmentPairController.selectViews( ...
                    viewIds(referenceIndex), viewIds(movingIndex));
            end
            app.PairViewpointRuntime = app.defaultPairViewpointRuntime();
            app.MotionRuntime = app.defaultMotionRuntime();
            app.DefaultMeshSampling = [app.Scene.layers.MeshSampling];
            app.DragMeshSampling = app.createDragMeshSampling();
            app.initializePreviewPyramids();
            app.initializeCameraSettleTimer();
            app.PreviewTimer = tic;
            if ~isempty(viewerState)
                [~, viewerState] = ProjectionViewerState.applyToScene( ...
                    app.Scene, viewerState);
                app.applyViewerStateToScene(viewerState);
                app.resetAlphaRuntimeState();
            end
            app.CorrectionStore = ProjectionCorrectionStore( ...
                app.Scene, correctionOptions);
            app.createComponents();
            app.createSurface();
            app.configureFrameCamera();
            if ~isempty(viewerState) && isfield(viewerState, "Camera")
                app.applyCameraState(viewerState.Camera);
            else
                app.frameCurrentProjectionView(app.InitialViewportFillFraction);
            end
            app.updateAllSurfaceBlendAppearance();
            app.refreshTiledProjectionSurfaces();
            app.updateControlsFromSelectedLayer();

            if nargout == 0
                clear app
            end
        end

        function delete(app)
            app.closeMotionImagery();
            app.exitAlignmentSoloPair();
            app.deleteCameraSettleTimer();
            app.clearPreviewTileRuntimeCache();
            app.clearPreviewSampledGeometryCache();
            app.clearAlignmentOverlays();
            app.clearAlignmentRoi(false);
            app.closeDenseSurfaceWindows();
            if ~isempty(app.AlignmentWorkbenchFigure) && ...
                    isvalid(app.AlignmentWorkbenchFigure)
                delete(app.AlignmentWorkbenchFigure);
            end
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

        function generationId = correctionGenerationId(app)
            %correctionGenerationId Return the current scientific generation.
            generationId = app.CorrectionStore.currentGenerationId();
        end

        function correctionSet = currentCorrection(app, lifecycle)
            %currentCorrection Query current correction lifecycle state.
            correctionSet = app.CorrectionStore.current(lifecycle);
        end

        function records = correctionHistory(app, generationId)
            %correctionHistory Query authoritative immutable correction history.
            if nargin < 2
                records = app.CorrectionStore.history();
            else
                records = app.CorrectionStore.history(generationId);
            end
        end

        function diagnostics = correctionDiagnostics(app)
            %correctionDiagnostics Return lifecycle and callback diagnostics.
            diagnostics = app.CorrectionStore.diagnostics();
        end

        function proposed = proposeCorrectionSet(app, correctionSet)
            %proposeCorrectionSet Add a portable proposal to viewer history.
            proposed = app.CorrectionStore.propose(correctionSet);
        end

        function accepted = acceptCorrection(app, generationId)
            %acceptCorrection Accept a current portable proposal.
            accepted = app.CorrectionStore.accept(generationId);
        end

        function applied = applyCorrection(app, generationId)
            %applyCorrection Atomically apply a reviewed portable generation.
            previousScene = app.Scene;
            [app.Scene, applied] = app.CorrectionStore.apply(generationId);
            app.refreshCorrectionScene(previousScene);
        end

        function reverted = revertCorrection(app, generationId)
            %revertCorrection Restore an exact parent correction generation.
            previousScene = app.Scene;
            [app.Scene, reverted] = app.CorrectionStore.revert(generationId);
            if string(generationId) == app.AlignmentAppliedGenerationId
                app.AlignmentAppliedGenerationId = "";
            end
            app.refreshCorrectionScene(previousScene);
        end

        function importState(app, state)
            %importState Apply a validated viewer state to the app.
            app.cancelCameraReconciliation();
            [~, state] = ProjectionViewerState.applyToScene(app.Scene, state);
            app.applyViewerStateToScene(state);
            app.PairViewpointRuntime = app.defaultPairViewpointRuntime();
            app.resetAlphaRuntimeState();
            app.refreshProjectionSurfaces(app.DefaultMeshSampling);
            app.configureFrameCamera();
            if isfield(state, "Camera")
                app.applyCameraState(state.Camera);
            else
                app.frameCurrentProjectionView(app.InitialViewportFillFraction);
            end
            app.updateAllSurfaceBlendAppearance();
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
            diagnostics.ActivePair = app.AlignmentPairController.currentPair();
            diagnostics.SoloPairActive = ...
                ProjectionSoloPairVisibility.isActive(app.AlignmentSoloState);
            diagnostics.EffectiveLayerVisibility = ...
                app.effectiveLayerVisibilityMask();
            diagnostics.StereoEyes = app.activeStereoEyeAssignment();
            diagnostics.PairViewpoint = app.pairViewpointDiagnostics();

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
                    PairGraphQualitySpeed= ...
                    request.Options.Scheduling.QualitySpeed, ...
                    PairGraphMaxPairs=request.Options.Scheduling.MaxPairs, ...
                    PairGraphAllPlausiblePairs= ...
                    request.Options.Scheduling.AllPlausiblePairs, ...
                    FilterGeometricMethod= ...
                    request.Options.FilterPipeline.GeometricMethod, ...
                    FilterCoplanarityMethod= ...
                    request.Options.FilterPipeline.CoplanarityMethod, ...
                    FilterNativeDisplacementMethod= ...
                    request.Options.FilterPipeline.NativeDisplacementMethod, ...
                    AllowReferenceMotion= ...
                    request.Options.MovableParameters.AllowReferenceMotion, ...
                    PointingPriorDefaultSigmaDegrees= ...
                    request.Options.PointingPriors.DefaultSigmaDegrees, ...
                    KappaBoundDegrees=request.Options.Bounds.KappaDegrees, ...
                    SafeMinSolverObservationsPerPair= ...
                    request.Options.SafeSolvePolicy.MinSolverObservationsPerPair, ...
                    SafeMinPreferredObservationsPerPair= ...
                    request.Options.SafeSolvePolicy.MinPreferredObservationsPerPair, ...
                    SafeFailOnBoundHit= ...
                    request.Options.SafeSolvePolicy.FailOnBoundHit, ...
                    SafeMinResidualImprovementFraction= ...
                    request.Options.SafeSolvePolicy.MinResidualImprovementFraction);
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

        function diagnostics = performanceDiagnostics(app)
            %performanceDiagnostics Return runtime-only viewer work metrics.
            monitorSnapshot = app.PerformanceMonitor.snapshot();
            diagnostics = struct();
            diagnostics.Format = "ProjectionViewerPerformanceDiagnostics";
            diagnostics.Version = 1;
            diagnostics.Environment = struct( ...
                MATLABVersion=string(version), ...
                Computer=string(computer));
            diagnostics.Counters = monitorSnapshot.Counters;
            diagnostics.Timings = monitorSnapshot.Timings;
            diagnostics.ElapsedSeconds = monitorSnapshot.ElapsedSeconds;
            diagnostics.MaxTimingSamples = monitorSnapshot.MaxTimingSamples;
            diagnostics.Viewer = app.viewerPerformanceRuntimeState();
        end

        function diagnostics = motionDiagnostics(app)
            %motionDiagnostics Return motion configuration and runtime state.
            runtime = app.MotionRuntime;
            diagnostics = struct(Active=runtime.Active, ...
                WindowOpen=~isempty(app.MotionFigure) && ...
                isvalid(app.MotionFigure), Position=runtime.Position, ...
                Loop=runtime.Loop, HoverEdges=runtime.HoverEdges, ...
                IdentityPinned=runtime.IdentityPinned, ...
                Playing=runtime.Playing, RateFps=runtime.RateFps, ...
                PauseReason=runtime.PauseReason, ...
                PlaybackFrameCount=runtime.PlaybackFrameCount, ...
                Warning=runtime.Warning, Sequence=runtime.Sequence, ...
                EffectiveVisibility=app.effectiveLayerVisibilityMask(), ...
                KeyboardMode=app.ViewportKeyboardMode);
            diagnostics.Lookahead = runtime.Lookahead;
            diagnostics.LookaheadCount = double( ...
                isstruct(runtime.Lookahead) && ...
                isfield(runtime.Lookahead, "Available") && ...
                runtime.Lookahead.Available);
            if runtime.Active && runtime.Position > 0
                diagnostics.Frame = ...
                    runtime.Sequence.Frames(runtime.Position);
            else
                diagnostics.Frame = struct();
            end
        end

        function resetPerformanceDiagnostics(app)
            %resetPerformanceDiagnostics Clear viewer work metrics only.
            app.PerformanceMonitor.reset();
        end

        function flushPreviewUpdates(app)
            %flushPreviewUpdates Apply pending alpha and camera updates.
            app.flushPendingAlphaUpdates();
            app.flushCameraReconciliation();
        end

        function plan = compileRasterPreview(app, options)
            %compileRasterPreview Build an optional CPU raster-preview plan.
            if nargin < 2
                options = struct();
            end
            options = app.rasterPreviewOptions(options);
            plan = ProjectionRasterPreviewRenderer.compile( ...
                app.Scene, app.exportCameraState(), options);
        end

        function result = renderRasterPreview(app, options)
            %renderRasterPreview Render an optional diagnostic raster preview.
            if nargin < 2
                options = struct();
            end
            plan = app.compileRasterPreview(options);
            result = ProjectionRasterPreviewRenderer.composite( ...
                plan, app.Scene.layers);
            result.Plan = plan;
        end

        function options = configurePreviewTiling(app, overrides)
            %configurePreviewTiling Set runtime-only display tiling options.
            if nargin < 2
                overrides = struct();
            end
            if isempty(overrides)
                overrides = struct();
            end
            if ~isstruct(overrides) || ~isscalar(overrides)
                error("ProjectionViewerApp:invalidPreviewTilingOptions", ...
                    "Preview tiling overrides must be a scalar struct.");
            end
            merged = app.PreviewTilingOptions;
            names = fieldnames(overrides);
            for k = 1:numel(names)
                merged.(names{k}) = overrides.(names{k});
            end
            options = ProjectionPreviewPyramid.defaultOptions(merged);
            app.cancelCameraReconciliation();
            app.initializePreviewPyramids(options);
            app.rebuildSurfaces();
            app.updateControlsFromSelectedLayer();
        end

        function options = configurePreviewCache(app, overrides)
            %configurePreviewCache Set runtime preview cache and pool budgets.
            if nargin < 2 || isempty(overrides)
                overrides = struct();
            end
            if ~isstruct(overrides) || ~isscalar(overrides)
                error("ProjectionViewerApp:invalidPreviewCacheOptions", ...
                    "Preview cache overrides must be a scalar struct.");
            end
            options = struct(MaxBytes=app.PreviewTileCacheMaxBytes, ...
                SampleMaxBytes=app.PreviewSampleCacheMaxBytes, ...
                SurfacePoolMaxCount=app.PreviewSurfacePoolMaxCount);
            names = fieldnames(overrides);
            for k = 1:numel(names)
                if ~isfield(options, names{k})
                    error("ProjectionViewerApp:invalidPreviewCacheOptions", ...
                        "Unknown preview cache option %s.", names{k});
                end
                options.(names{k}) = overrides.(names{k});
            end
            options.MaxBytes = app.validatePositiveIntegerOption( ...
                options.MaxBytes, "MaxBytes");
            options.SampleMaxBytes = app.validatePositiveIntegerOption( ...
                options.SampleMaxBytes, "SampleMaxBytes");
            options.SurfacePoolMaxCount = app.validateNonnegativeIntegerOption( ...
                options.SurfacePoolMaxCount, "SurfacePoolMaxCount");
            app.clearPreviewTileRuntimeCache();
            app.clearPreviewSampledGeometryCache();
            app.PreviewTileCacheMaxBytes = options.MaxBytes;
            app.PreviewSampleCacheMaxBytes = options.SampleMaxBytes;
            app.PreviewSurfacePoolMaxCount = options.SurfacePoolMaxCount;
            app.PreviewTileDataCache = ProjectionViewerLruCache( ...
                options.MaxBytes);
            app.PreviewSampledGeometryCache = ProjectionViewerLruCache( ...
                options.SampleMaxBytes);
        end

        function options = configurePreviewBudget(app, overrides)
            %configurePreviewBudget Set display-only object/render budgets.
            if nargin < 2 || isempty(overrides)
                overrides = struct();
            end
            if ~isstruct(overrides) || ~isscalar(overrides)
                error("ProjectionViewerApp:invalidPreviewBudgetOptions", ...
                    "Preview budget overrides must be a scalar struct.");
            end
            options = struct( ...
                MaxVisibleSurfaces=app.PreviewMaxVisibleSurfaces, ...
                MaxVisibleTextureBytes=app.PreviewMaxVisibleTextureBytes, ...
                TargetMaxTilesPerLayer=app.PreviewTargetMaxTilesPerLayer, ...
                AutomaticTilePolicy=app.PreviewAutomaticTilePolicy, ...
                AlphaPreviewMinIntervalSeconds= ...
                app.AlphaPreviewMinIntervalSeconds);
            names = fieldnames(overrides);
            for k = 1:numel(names)
                if ~isfield(options, names{k})
                    error("ProjectionViewerApp:invalidPreviewBudgetOptions", ...
                        "Unknown preview budget option %s.", names{k});
                end
                options.(names{k}) = overrides.(names{k});
            end
            options.MaxVisibleSurfaces = app.validatePositiveIntegerOption( ...
                options.MaxVisibleSurfaces, "MaxVisibleSurfaces");
            options.MaxVisibleTextureBytes = ...
                app.validatePositiveIntegerOption( ...
                options.MaxVisibleTextureBytes, "MaxVisibleTextureBytes");
            options.TargetMaxTilesPerLayer = ...
                app.validatePositiveIntegerOption( ...
                options.TargetMaxTilesPerLayer, ...
                "TargetMaxTilesPerLayer");
            options.AutomaticTilePolicy = app.validateLogicalOption( ...
                options.AutomaticTilePolicy, "AutomaticTilePolicy");
            options.AlphaPreviewMinIntervalSeconds = ...
                app.validateNonnegativeScalarOption( ...
                options.AlphaPreviewMinIntervalSeconds, ...
                "AlphaPreviewMinIntervalSeconds");

            app.flushPendingAlphaUpdates();
            app.PreviewMaxVisibleSurfaces = options.MaxVisibleSurfaces;
            app.PreviewMaxVisibleTextureBytes = ...
                options.MaxVisibleTextureBytes;
            app.PreviewTargetMaxTilesPerLayer = ...
                options.TargetMaxTilesPerLayer;
            app.PreviewAutomaticTilePolicy = options.AutomaticTilePolicy;
            app.AlphaPreviewMinIntervalSeconds = ...
                options.AlphaPreviewMinIntervalSeconds;
            app.refreshTiledProjectionSurfaces();
        end
    end

    methods
        function value = get.AlignmentRequest(app)
            value = app.AlignmentSession.Request;
        end

        function set.AlignmentRequest(app, value)
            app.AlignmentSession.Request = value;
        end

        function value = get.AlignmentWorkingImages(app)
            value = app.AlignmentSession.WorkingImages;
        end

        function set.AlignmentWorkingImages(app, value)
            app.AlignmentSession.WorkingImages = value;
        end

        function value = get.AlignmentWorkingImageCacheKey(app)
            value = app.AlignmentSession.WorkingImageCacheKey;
        end

        function set.AlignmentWorkingImageCacheKey(app, value)
            app.AlignmentSession.WorkingImageCacheKey = value;
        end

        function value = get.AlignmentWorkingImageCacheValue(app)
            value = app.AlignmentSession.WorkingImageCacheValue;
        end

        function set.AlignmentWorkingImageCacheValue(app, value)
            app.AlignmentSession.WorkingImageCacheValue = value;
        end

        function value = get.AlignmentWorkingImageCacheHits(app)
            value = app.AlignmentSession.WorkingImageCacheHits;
        end

        function set.AlignmentWorkingImageCacheHits(app, value)
            app.AlignmentSession.WorkingImageCacheHits = value;
        end

        function value = get.AlignmentWorkingImageCacheMisses(app)
            value = app.AlignmentSession.WorkingImageCacheMisses;
        end

        function set.AlignmentWorkingImageCacheMisses(app, value)
            app.AlignmentSession.WorkingImageCacheMisses = value;
        end

        function value = get.AlignmentRawMatchResult(app)
            value = app.AlignmentSession.RawMatchResult;
        end

        function set.AlignmentRawMatchResult(app, value)
            app.AlignmentSession.RawMatchResult = value;
        end

        function value = get.AlignmentPreRoiMatchResult(app)
            value = app.AlignmentSession.PreRoiMatchResult;
        end

        function set.AlignmentPreRoiMatchResult(app, value)
            app.AlignmentSession.PreRoiMatchResult = value;
        end

        function value = get.AlignmentFilteredMatchResult(app)
            value = app.AlignmentSession.FilteredMatchResult;
        end

        function set.AlignmentFilteredMatchResult(app, value)
            app.AlignmentSession.FilteredMatchResult = value;
        end

        function value = get.AlignmentCuratedMatchMask(app)
            value = app.AlignmentSession.CuratedMatchMask;
        end

        function set.AlignmentCuratedMatchMask(app, value)
            app.AlignmentSession.CuratedMatchMask = value;
        end

        function value = get.AlignmentDeletedMatchMask(app)
            value = app.AlignmentSession.DeletedMatchMask;
        end

        function set.AlignmentDeletedMatchMask(app, value)
            app.AlignmentSession.DeletedMatchMask = value;
        end

        function value = get.AlignmentCurationUndoStack(app)
            value = app.AlignmentSession.CurationUndoStack;
        end

        function set.AlignmentCurationUndoStack(app, value)
            app.AlignmentSession.CurationUndoStack = value;
        end

        function value = get.AlignmentSelectedMatchRows(app)
            value = app.AlignmentSession.SelectedMatchRows;
        end

        function set.AlignmentSelectedMatchRows(app, value)
            app.AlignmentSession.SelectedMatchRows = value;
        end

        function value = get.AlignmentResult(app)
            value = app.AlignmentSession.Result;
        end

        function set.AlignmentResult(app, value)
            app.AlignmentSession.Result = value;
        end

        function value = get.AlignmentRoiBounds(app)
            value = app.AlignmentSession.RoiBounds;
        end

        function set.AlignmentRoiBounds(app, value)
            app.AlignmentSession.RoiBounds = value;
        end

        function value = get.AlignmentCancelRequested(app)
            value = app.AlignmentSession.CancelRequested;
        end

        function set.AlignmentCancelRequested(app, value)
            app.AlignmentSession.CancelRequested = value;
        end

    end

    methods (Access = private)
        function refreshCorrectionScene(app, previousScene)
            layerIndices = app.changedProjectionLayerIndices( ...
                previousScene, app.Scene);
            app.refreshProjectionLayers( ...
                layerIndices, app.DefaultMeshSampling, false);
            app.updateControlsFromSelectedLayer();
        end


        function createComponents(app)
            app.UIFigure = uifigure(Name="Sightline Workbench", ...
                Position=[100 100 1100 760], ...
                WindowScrollWheelFcn=@(~, event) app.scrollWheel(event), ...
                WindowKeyPressFcn=@(~, event) app.keyPressed(event), ...
                WindowKeyReleaseFcn=@(~, event) app.keyReleased(event), ...
                WindowButtonDownFcn=@(~, event) app.beginPan(event), ...
                WindowButtonMotionFcn=[], ...
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
            colormap(app.Axes, gray(256));
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
            app.TwistSlider = uislider(app.ControlGrid, Limits=[-85 85], Value=0);
            app.TwistSlider.Layout.Row = 2;
            app.TwistSlider.Layout.Column = 4;
            app.TwistSlider.MajorTicks = [-85 -45 0 45 85];
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

        end

        function createAlignmentLauncherControls(app)
            app.AlignmentLauncherGrid = uigridlayout(app.GridLayout, [1 4]);
            app.AlignmentLauncherGrid.Layout.Row = 2;
            app.AlignmentLauncherGrid.Layout.Column = 1;
            app.AlignmentLauncherGrid.Tag = "ProjectionViewerAlignmentGrid";
            app.AlignmentLauncherGrid.RowHeight = {"fit"};
            app.AlignmentLauncherGrid.ColumnWidth = {150, 130, "fit", "1x"};
            app.AlignmentLauncherGrid.Padding = [0 0 0 0];
            app.AlignmentLauncherGrid.ColumnSpacing = 8;

            app.AlignmentOpenWorkbenchButton = uibutton( ...
                app.AlignmentLauncherGrid, Text="Open Workbench", ...
                Tag="ProjectionViewerAlignmentOpenWorkbenchButton", ...
                ButtonPushedFcn=@(~, ~) app.openAlignmentWorkbench());
            app.AlignmentOpenWorkbenchButton.Layout.Column = 1;
            app.AlignmentStageLabel = uilabel(app.AlignmentLauncherGrid, ...
                Text="Stage: setup", ...
                Tag="ProjectionViewerAlignmentStageLabel");
            app.AlignmentStageLabel.Layout.Column = 2;
            clearButton = uibutton(app.AlignmentLauncherGrid, ...
                Text="Clear overlays", ...
                Tag="ProjectionViewerAlignmentLauncherClearOverlaysButton", ...
                ButtonPushedFcn=@(~, ~) ...
                app.clearAlignmentOverlaysFromControls());
            clearButton.Layout.Column = 3;
            app.AlignmentLauncherStatusLabel = uilabel( ...
                app.AlignmentLauncherGrid, Text="Alignment not run", ...
                Tag="ProjectionViewerAlignmentLauncherStatusLabel");
            app.AlignmentLauncherStatusLabel.Layout.Column = 4;
            app.AlignmentLauncherGrid.Visible = "off";
            rowHeights = app.GridLayout.RowHeight;
            rowHeights{2} = 0;
            app.GridLayout.RowHeight = rowHeights;
            app.refreshAlignmentSessionIndicators();
        end

        function openAlignmentWorkbench(app)
            if isempty(app.AlignmentWorkbenchFigure) || ...
                    ~isvalid(app.AlignmentWorkbenchFigure)
                creationTimer = tic;
                app.createAlignmentControls();
                app.PerformanceMonitor.increment("AlignmentWorkbenchCreations");
                app.PerformanceMonitor.recordTiming( ...
                    "AlignmentWorkbenchCreateSeconds", toc(creationTimer));
            end
            app.AlignmentWorkbenchFigure.Visible = "on";
            figure(app.AlignmentWorkbenchFigure);
            app.refreshAlignmentSessionIndicators();
        end

        function hideAlignmentWorkbench(app)
            app.exitAlignmentSoloPair();
            if ~isempty(app.AlignmentWorkbenchFigure) && ...
                    isvalid(app.AlignmentWorkbenchFigure)
                app.AlignmentWorkbenchFigure.Visible = "off";
            end
        end

        function createAlignmentControls(app)
            app.AlignmentWorkbenchFigure = uifigure( ...
                Name="Alignment Workbench", Position=[140 100 1400 900], ...
                CloseRequestFcn=@(~, ~) app.hideAlignmentWorkbench(), ...
                Tag="ProjectionViewerAlignmentWorkbench");
            app.AlignmentGrid = uigridlayout(app.AlignmentWorkbenchFigure, ...
                [6 17]);
            app.AlignmentGrid.Tag = "ProjectionViewerAlignmentGrid";
            app.AlignmentGrid.RowHeight = {"fit", "fit", "fit", ...
                "fit", 92, "1x"};
            app.AlignmentGrid.ColumnWidth = {90, 135, 80, 110, 90, 130, ...
                120, 60, 60, 65, 65, 70, 70, 65, 65, 75, "1x"};
            app.AlignmentGrid.Padding = [10 10 10 10];
            app.AlignmentGrid.RowSpacing = 6;
            app.AlignmentGrid.ColumnSpacing = 8;

            setupHeading = uilabel(app.AlignmentGrid, Text="SETUP", ...
                FontWeight="bold");
            setupHeading.Layout.Row = 1;
            setupHeading.Layout.Column = [1 7];
            solveHeading = uilabel(app.AlignmentGrid, ...
                Text="SOLVE, CURATE, AND OVERLAYS", FontWeight="bold");
            solveHeading.Layout.Row = 1;
            solveHeading.Layout.Column = [8 16];

            referenceLabel = uilabel(app.AlignmentGrid, Text="Reference");
            referenceLabel.Layout.Row = 2;
            referenceLabel.Layout.Column = 1;
            app.AlignmentReferenceDropDown = uidropdown(app.AlignmentGrid, ...
                Items=cellstr(app.layerDisplayNames()), ...
                ItemsData=string(1:numel(app.Scene.layers)), ...
                ValueChangedFcn=@(~, ~) ...
                app.alignmentActivePairSelectorsChanged(), ...
                Tag="ProjectionViewerAlignmentReferenceDropDown");
            app.AlignmentReferenceDropDown.Layout.Row = 3;
            app.AlignmentReferenceDropDown.Layout.Column = 1;

            movingLabel = uilabel(app.AlignmentGrid, Text="Moving");
            movingLabel.Layout.Row = 2;
            movingLabel.Layout.Column = 2;
            app.AlignmentMovingDropDown = uidropdown(app.AlignmentGrid, ...
                Items=cellstr(app.layerDisplayNames()), ...
                ItemsData=string(1:numel(app.Scene.layers)), ...
                ValueChangedFcn=@(~, ~) ...
                app.alignmentActivePairSelectorsChanged(), ...
                Tag="ProjectionViewerAlignmentMovingDropDown");
            app.AlignmentMovingDropDown.Layout.Row = 3;
            app.AlignmentMovingDropDown.Layout.Column = 2;

            presetLabel = uilabel(app.AlignmentGrid, Text="Preset");
            presetLabel.Layout.Row = 2;
            presetLabel.Layout.Column = 3;
            app.AlignmentPresetDropDown = uidropdown(app.AlignmentGrid, ...
                Items=cellstr(["Fast", "Quality"]), ...
                ItemsData=["fast", "quality"], Value="fast", ...
                ValueChangedFcn=@(~, ~) app.alignmentSetupChanged(false), ...
                Tag="ProjectionViewerAlignmentPresetDropDown");
            app.AlignmentPresetDropDown.Layout.Row = 3;
            app.AlignmentPresetDropDown.Layout.Column = 3;

            scopeLabel = uilabel(app.AlignmentGrid, Text="Scope");
            scopeLabel.Layout.Row = 2;
            scopeLabel.Layout.Column = 4;
            app.AlignmentScopeDropDown = uidropdown(app.AlignmentGrid, ...
                Items=cellstr(["Selected pair", "Visible layers"]), ...
                ItemsData=["selectedPair", "visibleLayers"], ...
                Value="selectedPair", ...
                ValueChangedFcn=@(~, ~) app.alignmentSetupChanged(true), ...
                Tag="ProjectionViewerAlignmentScopeDropDown");
            app.AlignmentScopeDropDown.Layout.Row = 3;
            app.AlignmentScopeDropDown.Layout.Column = 4;

            detectorLabel = uilabel(app.AlignmentGrid, Text="Detector");
            detectorLabel.Layout.Row = 2;
            detectorLabel.Layout.Column = 5;
            app.AlignmentDetectorDropDown = uidropdown(app.AlignmentGrid, ...
                Items=cellstr(["auto", "sift", "surf", "orb", "brisk", "kaze"]), ...
                ItemsData=["auto", "sift", "surf", "orb", "brisk", "kaze"], ...
                Value="auto", ...
                ValueChangedFcn=@(~, ~) app.alignmentSetupChanged(false), ...
                Tag="ProjectionViewerAlignmentDetectorDropDown");
            app.AlignmentDetectorDropDown.Layout.Row = 3;
            app.AlignmentDetectorDropDown.Layout.Column = 5;

            lossLabel = uilabel(app.AlignmentGrid, Text="Loss");
            lossLabel.Layout.Row = 2;
            lossLabel.Layout.Column = 6;
            app.AlignmentLossDropDown = uidropdown(app.AlignmentGrid, ...
                Items=cellstr(["projectionPlane2D", "rayToRay3D", ...
                "epipolarCoplanarity"]), ...
                ItemsData=["projectionPlane2D", "rayToRay3D", ...
                "epipolarCoplanarity"], ...
                Value="projectionPlane2D", ...
                ValueChangedFcn=@(~, ~) app.alignmentSolveSettingChanged(), ...
                Tag="ProjectionViewerAlignmentLossDropDown");
            app.AlignmentLossDropDown.Layout.Row = 3;
            app.AlignmentLossDropDown.Layout.Column = 6;

            coplanarityLabel = uilabel(app.AlignmentGrid, Text="Coplanarity filter");
            coplanarityLabel.Layout.Row = 2;
            coplanarityLabel.Layout.Column = 7;
            app.AlignmentCoplanarityDropDown = uidropdown( ...
                app.AlignmentGrid, Items=cellstr(["Off", "Robust"]), ...
                ItemsData=["none", "robustMad"], Value="none", ...
                ValueChangedFcn=@(~, ~) app.alignmentFilterSettingChanged(), ...
                Tag="ProjectionViewerAlignmentCoplanarityDropDown");
            app.AlignmentCoplanarityDropDown.Layout.Row = 3;
            app.AlignmentCoplanarityDropDown.Layout.Column = 7;

            app.AlignmentRoiButton = uibutton(app.AlignmentGrid, ...
                Text="ROI", Tag="ProjectionViewerAlignmentRoiButton", ...
                Tooltip="Draw projection-plane ROI", ...
                ButtonPushedFcn=@(~, ~) app.selectAlignmentRoi());
            app.AlignmentRoiButton.Layout.Row = 3;
            app.AlignmentRoiButton.Layout.Column = 8;

            app.AlignmentClearRoiButton = uibutton(app.AlignmentGrid, ...
                Text="Clear", Tag="ProjectionViewerAlignmentClearRoiButton", ...
                Tooltip="Clear alignment ROI", ...
                ButtonPushedFcn=@(~, ~) app.clearAlignmentRoi(true));
            app.AlignmentClearRoiButton.Layout.Row = 3;
            app.AlignmentClearRoiButton.Layout.Column = 9;

            app.AlignmentMatchButton = uibutton(app.AlignmentGrid, ...
                Text="Match", Tag="ProjectionViewerAlignmentMatchButton", ...
                ButtonPushedFcn=@(~, ~) app.matchAlignmentWorkflow());
            app.AlignmentMatchButton.Layout.Row = 3;
            app.AlignmentMatchButton.Layout.Column = 10;

            app.AlignmentFilterButton = uibutton(app.AlignmentGrid, ...
                Text="Filter", Enable="off", ...
                Tag="ProjectionViewerAlignmentFilterButton", ...
                ButtonPushedFcn=@(~, ~) app.filterAlignmentWorkflow());
            app.AlignmentFilterButton.Layout.Row = 3;
            app.AlignmentFilterButton.Layout.Column = 11;

            app.AlignmentSolveButton = uibutton(app.AlignmentGrid, ...
                Text="Solve", Enable="off", ...
                Tag="ProjectionViewerAlignmentSolveButton", ...
                ButtonPushedFcn=@(~, ~) app.solveAlignmentWorkflow());
            app.AlignmentSolveButton.Layout.Row = 4;
            app.AlignmentSolveButton.Layout.Column = 1;

            app.AlignmentCancelButton = uibutton(app.AlignmentGrid, ...
                Text="Cancel", Enable="off", ...
                Tag="ProjectionViewerAlignmentCancelButton", ...
                ButtonPushedFcn=@(~, ~) app.cancelAlignmentWorkflow());
            app.AlignmentCancelButton.Layout.Row = 3;
            app.AlignmentCancelButton.Layout.Column = 12;

            app.AlignmentReferenceMotionCheckBox = uibutton( ...
                app.AlignmentGrid, "state", Text="Move reference", Value=true, ...
                Tooltip="Allow both images to move; turn off only for an intentional fixed-reference control", ...
                Tag="ProjectionViewerAlignmentReferenceMotionCheckBox", ...
                ValueChangedFcn=@(~, ~) app.alignmentSolveSettingChanged());
            app.AlignmentReferenceMotionCheckBox.Layout.Row = 3;
            app.AlignmentReferenceMotionCheckBox.Layout.Column = [13 14];

            app.AlignmentPreviewButton = uibutton(app.AlignmentGrid, ...
                Text="Preview", Enable="off", ...
                Tag="ProjectionViewerAlignmentPreviewButton", ...
                ButtonPushedFcn=@(~, ~) app.previewAlignmentResult());
            app.AlignmentPreviewButton.Layout.Row = 4;
            app.AlignmentPreviewButton.Layout.Column = 2;

            app.AlignmentApplyButton = uibutton(app.AlignmentGrid, ...
                Text="Apply", Enable="off", ...
                Tag="ProjectionViewerAlignmentApplyButton", ...
                ButtonPushedFcn=@(~, ~) app.applyAlignmentResult());
            app.AlignmentApplyButton.Layout.Row = 4;
            app.AlignmentApplyButton.Layout.Column = 3;

            app.AlignmentRevertButton = uibutton(app.AlignmentGrid, ...
                Text="Revert", Enable="off", ...
                Tag="ProjectionViewerAlignmentRevertButton", ...
                ButtonPushedFcn=@(~, ~) app.revertAlignmentResult());
            app.AlignmentRevertButton.Layout.Row = 4;
            app.AlignmentRevertButton.Layout.Column = 4;

            app.AlignmentClearOverlaysButton = uibutton(app.AlignmentGrid, ...
                Text="Clear", Tooltip="Clear match overlays", ...
                Tag="ProjectionViewerAlignmentClearOverlaysButton", ...
                ButtonPushedFcn=@(~, ~) app.clearAlignmentOverlaysFromControls());
            app.AlignmentClearOverlaysButton.Layout.Row = 4;
            app.AlignmentClearOverlaysButton.Layout.Column = 16;

            app.AlignmentAcceptedOverlayCheckBox = uibutton( ...
                app.AlignmentGrid, "state", Text="Accepted", Value=true, ...
                Tag="ProjectionViewerAlignmentAcceptedOverlayCheckBox", ...
                ValueChangedFcn=@(~, ~) app.refreshAlignmentOverlays(true));
            app.AlignmentAcceptedOverlayCheckBox.Layout.Row = 4;
            app.AlignmentAcceptedOverlayCheckBox.Layout.Column = [5 6];

            app.AlignmentRejectedOverlayCheckBox = uibutton( ...
                app.AlignmentGrid, "state", Text="Rejected", Value=false, ...
                Tag="ProjectionViewerAlignmentRejectedOverlayCheckBox", ...
                ValueChangedFcn=@(~, ~) app.refreshAlignmentOverlays(true));
            app.AlignmentRejectedOverlayCheckBox.Layout.Row = 4;
            app.AlignmentRejectedOverlayCheckBox.Layout.Column = [7 8];

            app.AlignmentWorstOverlayCheckBox = uibutton( ...
                app.AlignmentGrid, "state", Text="Worst", Value=false, ...
                Tag="ProjectionViewerAlignmentWorstOverlayCheckBox", ...
                ValueChangedFcn=@(~, ~) app.refreshAlignmentOverlays(true));
            app.AlignmentWorstOverlayCheckBox.Layout.Row = 4;
            app.AlignmentWorstOverlayCheckBox.Layout.Column = [9 10];

            app.AlignmentFeatureOverlayCheckBox = uibutton( ...
                app.AlignmentGrid, "state", Text="Points", Value=true, ...
                Tag="ProjectionViewerAlignmentFeatureOverlayCheckBox", ...
                ValueChangedFcn=@(~, ~) app.refreshAlignmentOverlays(true));
            app.AlignmentFeatureOverlayCheckBox.Layout.Row = 4;
            app.AlignmentFeatureOverlayCheckBox.Layout.Column = 11;

            app.AlignmentDeleteMatchButton = uibutton(app.AlignmentGrid, ...
                Text="Delete", Tooltip="Delete selected match rows", ...
                Tag="ProjectionViewerAlignmentDeleteMatchButton", ...
                ButtonPushedFcn=@(~, ~) app.deleteSelectedAlignmentMatches());
            app.AlignmentDeleteMatchButton.Layout.Row = 4;
            app.AlignmentDeleteMatchButton.Layout.Column = 12;

            app.AlignmentUndoCurationButton = uibutton(app.AlignmentGrid, ...
                Text="Undo", Tooltip="Undo last curation or common-anchor adjustment", ...
                Tag="ProjectionViewerAlignmentUndoCurationButton", ...
                ButtonPushedFcn=@(~, ~) app.undoAlignmentCuration());
            app.AlignmentUndoCurationButton.Layout.Row = 4;
            app.AlignmentUndoCurationButton.Layout.Column = 13;

            app.AlignmentDenseSurfaceButton = uibutton(app.AlignmentGrid, ...
                Text="Dense surface", Enable="off", ...
                Tooltip="Run CPU semi-global matching on the current aligned pair", ...
                Tag="ProjectionViewerAlignmentDenseSurfaceButton", ...
                ButtonPushedFcn=@(~, ~) ...
                app.extractDenseSurfaceFromAlignment());
            app.AlignmentDenseSurfaceButton.Layout.Row = 4;
            app.AlignmentDenseSurfaceButton.Layout.Column = [14 15];

            app.AlignmentStatusLabel = uilabel(app.AlignmentGrid, ...
                Text="Alignment not run", ...
                Tag="ProjectionViewerAlignmentStatusLabel");
            app.AlignmentStatusLabel.Layout.Row = 1;
            app.AlignmentStatusLabel.Layout.Column = 17;
            app.AlignmentDiagnosticsTextArea = uitextarea(app.AlignmentGrid, ...
                Editable="off", Value=["Match: stale"; "Filter: stale"; ...
                "Solve: stale"; "Preview: stale"; "Apply: stale"], ...
                Tag="ProjectionViewerAlignmentDiagnosticsTextArea");
            app.AlignmentDiagnosticsTextArea.Layout.Row = [2 4];
            app.AlignmentDiagnosticsTextArea.Layout.Column = 17;

            app.AlignmentPairTable = uitable(app.AlignmentGrid, ...
                Data=app.emptyAlignmentPairTable(), ...
                ColumnEditable=[true false false false false false false], ...
                Tag="ProjectionViewerAlignmentPairTable");
            app.AlignmentPairTable.Layout.Row = 5;
            app.AlignmentPairTable.Layout.Column = [1 17];

            app.AlignmentMatchTable = uitable(app.AlignmentGrid, ...
                Data=app.emptyAlignmentMatchTable(), ...
                ColumnEditable=[true false false false false false false ...
                false false false false false false false false], ...
                CellEditCallback=@(~, ~) app.alignmentMatchTableEdited(), ...
                CellSelectionCallback=@(~, event) ...
                app.alignmentMatchTableSelected(event), ...
                Tag="ProjectionViewerAlignmentMatchTable");
            app.AlignmentMatchTable.Layout.Row = 6;
            app.AlignmentMatchTable.Layout.Column = [1 17];

            app.organizeAlignmentWorkbenchLayout(setupHeading, solveHeading, ...
                referenceLabel, movingLabel, presetLabel, scopeLabel, ...
                detectorLabel, lossLabel, coplanarityLabel);

            app.updateAlignmentLayerItems();
            app.setAlignmentActionEnabled(false);
            app.refreshAlignmentSessionIndicators();
        end

        function organizeAlignmentWorkbenchLayout(app, setupHeading, ...
                solveHeading, referenceLabel, movingLabel, presetLabel, ...
                scopeLabel, detectorLabel, lossLabel, coplanarityLabel)
            delete([setupHeading solveHeading]);
            app.AlignmentGrid.RowHeight = {36, "fit", "fit", "fit", ...
                115, "1x", 155};
            app.AlignmentGrid.ColumnWidth = {"1x", "1x"};
            app.AlignmentGrid.RowSpacing = 8;
            app.AlignmentGrid.ColumnSpacing = 10;

            headerGrid = uigridlayout(app.AlignmentGrid, [1 2]);
            headerGrid.Layout.Row = 1;
            headerGrid.Layout.Column = [1 2];
            headerGrid.RowHeight = {"1x"};
            headerGrid.ColumnWidth = {260, "1x"};
            headerGrid.Padding = [0 0 0 0];
            headerGrid.ColumnSpacing = 10;
            headerGrid.Tag = "ProjectionViewerAlignmentHeaderGrid";
            heading = uilabel(headerGrid, Text="ALIGNMENT WORKBENCH", ...
                FontWeight="bold", FontSize=15);
            heading.Layout.Column = 1;
            app.AlignmentStatusLabel.Parent = headerGrid;
            app.AlignmentStatusLabel.Layout.Row = 1;
            app.AlignmentStatusLabel.Layout.Column = 2;

            activePairPanel = uipanel(app.AlignmentGrid, ...
                Title="Active pair — inspection and navigation", ...
                Tag="ProjectionViewerAlignmentActivePairPanel");
            activePairPanel.Layout.Row = 2;
            activePairPanel.Layout.Column = [1 2];
            activePairGrid = uigridlayout(activePairPanel, [2 14]);
            activePairGrid.RowHeight = {"fit", "fit"};
            activePairGrid.ColumnWidth = {65, "1x", "1x", 55, 55, ...
                85, 75, 90, 100, 105, 75, 75, "1.1x", "1.1x"};
            activePairGrid.Padding = [8 4 8 6];
            activePairGrid.ColumnSpacing = 8;
            app.AlignmentPreviousPairButton = uibutton(activePairGrid, ...
                Text="Previous", ...
                Tag="ProjectionViewerAlignmentPreviousPairButton", ...
                ButtonPushedFcn=@(~, ~) app.stepAlignmentActivePair(-1));
            app.AlignmentPreviousPairButton.Layout.Row = 2;
            app.AlignmentPreviousPairButton.Layout.Column = 1;
            referenceLabel.Parent = activePairGrid;
            referenceLabel.Layout.Row = 1;
            referenceLabel.Layout.Column = 2;
            app.AlignmentReferenceDropDown.Parent = activePairGrid;
            app.AlignmentReferenceDropDown.Layout.Row = 2;
            app.AlignmentReferenceDropDown.Layout.Column = 2;
            movingLabel.Parent = activePairGrid;
            movingLabel.Layout.Row = 1;
            movingLabel.Layout.Column = 3;
            app.AlignmentMovingDropDown.Parent = activePairGrid;
            app.AlignmentMovingDropDown.Layout.Row = 2;
            app.AlignmentMovingDropDown.Layout.Column = 3;
            app.AlignmentSwapPairButton = uibutton(activePairGrid, ...
                Text="Swap", Tag="ProjectionViewerAlignmentSwapPairButton", ...
                ButtonPushedFcn=@(~, ~) app.swapAlignmentActivePair());
            app.AlignmentSwapPairButton.Layout.Row = 2;
            app.AlignmentSwapPairButton.Layout.Column = 4;
            app.AlignmentNextPairButton = uibutton(activePairGrid, ...
                Text="Next", Tag="ProjectionViewerAlignmentNextPairButton", ...
                ButtonPushedFcn=@(~, ~) app.stepAlignmentActivePair(1));
            app.AlignmentNextPairButton.Layout.Row = 2;
            app.AlignmentNextPairButton.Layout.Column = 5;
            app.AlignmentPairEnabledCheckBox = uibutton( ...
                activePairGrid, "state", Text="Pair enabled", Value=true, ...
                Tag="ProjectionViewerAlignmentPairEnabledCheckBox", ...
                ValueChangedFcn=@(~, ~) app.alignmentPairEnabledChanged());
            app.AlignmentPairEnabledCheckBox.Layout.Row = 2;
            app.AlignmentPairEnabledCheckBox.Layout.Column = 6;
            app.AlignmentSoloPairCheckBox = uibutton( ...
                activePairGrid, "state", Text="Solo pair", Value=false, ...
                Tag="ProjectionViewerAlignmentSoloPairCheckBox", ...
                ValueChangedFcn=@(~, ~) app.alignmentSoloPairChanged());
            app.AlignmentSoloPairCheckBox.Layout.Row = 2;
            app.AlignmentSoloPairCheckBox.Layout.Column = 7;
            app.AlignmentPairViewButton = uibutton(activePairGrid, ...
                Text="Pair viewpoint", ...
                Tag="ProjectionViewerAlignmentPairViewButton", ...
                ButtonPushedFcn=@(~, ~) app.applyActivePairViewpoint(true));
            app.AlignmentPairViewButton.Layout.Row = 2;
            app.AlignmentPairViewButton.Layout.Column = 8;
            app.AlignmentRestoreViewButton = uibutton(activePairGrid, ...
                Text="Restore viewpoint", ...
                Tag="ProjectionViewerAlignmentRestoreViewButton", ...
                ButtonPushedFcn=@(~, ~) app.restorePairViewpoint());
            app.AlignmentRestoreViewButton.Layout.Row = 2;
            app.AlignmentRestoreViewButton.Layout.Column = 9;
            app.AlignmentFollowPairCheckBox = uibutton( ...
                activePairGrid, "state", Text="Follow active pair", ...
                Value=false, ...
                Tag="ProjectionViewerAlignmentFollowPairCheckBox", ...
                ValueChangedFcn=@(~, ~) app.followActivePairChanged());
            app.AlignmentFollowPairCheckBox.Layout.Row = 2;
            app.AlignmentFollowPairCheckBox.Layout.Column = 10;
            app.AlignmentSwapEyesButton = uibutton(activePairGrid, ...
                Text="Swap eyes", ...
                Tooltip="Manually swap left/right eyes for this pair", ...
                Tag="ProjectionViewerAlignmentSwapEyesButton", ...
                ButtonPushedFcn=@(~, ~) app.swapAlignmentStereoEyes());
            app.AlignmentSwapEyesButton.Layout.Row = 2;
            app.AlignmentSwapEyesButton.Layout.Column = 11;
            app.AlignmentResetEyesButton = uibutton(activePairGrid, ...
                Text="Reset eyes", ...
                Tooltip="Restore automatic geometric eye assignment", ...
                Tag="ProjectionViewerAlignmentResetEyesButton", ...
                ButtonPushedFcn=@(~, ~) app.resetAlignmentStereoEyes());
            app.AlignmentResetEyesButton.Layout.Row = 2;
            app.AlignmentResetEyesButton.Layout.Column = 12;
            app.AlignmentPairStatusLabel = uilabel(activePairGrid, ...
                Text="No active pair", ...
                Tag="ProjectionViewerAlignmentPairStatusLabel");
            app.AlignmentPairStatusLabel.Layout.Row = 1;
            app.AlignmentPairStatusLabel.Layout.Column = 13;
            app.AlignmentStereoEyeStatusLabel = uilabel(activePairGrid, ...
                Text="Eyes unavailable", ...
                Tag="ProjectionViewerAlignmentStereoEyeStatusLabel");
            app.AlignmentStereoEyeStatusLabel.Layout.Row = 2;
            app.AlignmentStereoEyeStatusLabel.Layout.Column = 13;
            app.AlignmentPairViewStatusLabel = uilabel(activePairGrid, ...
                Text="Pair viewpoint unavailable", WordWrap="on", ...
                Tag="ProjectionViewerAlignmentPairViewStatusLabel");
            app.AlignmentPairViewStatusLabel.Layout.Row = [1 2];
            app.AlignmentPairViewStatusLabel.Layout.Column = 14;

            setupPanel = uipanel(app.AlignmentGrid, ...
                Title="1. Setup and matching inputs", ...
                Tag="ProjectionViewerAlignmentSetupPanel");
            setupPanel.Layout.Row = 3;
            setupPanel.Layout.Column = 1;
            setupGrid = uigridlayout(setupPanel, [2 6]);
            setupGrid.RowHeight = {"fit", "fit"};
            setupGrid.ColumnWidth = {"1x", "1x", "1x", "1x", "1x", "1x"};
            setupGrid.Padding = [8 6 8 8];
            setupGrid.ColumnSpacing = 8;
            setupLabels = [scopeLabel presetLabel detectorLabel];
            setupControls = [app.AlignmentScopeDropDown ...
                app.AlignmentPresetDropDown app.AlignmentDetectorDropDown];
            for column = 1:numel(setupLabels)
                setupLabels(column).Parent = setupGrid;
                setupLabels(column).Layout.Row = 1;
                setupLabels(column).Layout.Column = column;
                setupControls(column).Parent = setupGrid;
                setupControls(column).Layout.Row = 2;
                setupControls(column).Layout.Column = column;
            end
            graphModeLabel = uilabel(setupGrid, Text="Pair graph");
            graphModeLabel.Layout.Row = 1;
            graphModeLabel.Layout.Column = 4;
            app.AlignmentPairGraphModeDropDown = uidropdown(setupGrid, ...
                Items=cellstr(["Fast", "Balanced", "Quality"]), ...
                ItemsData=["fast", "balanced", "quality"], ...
                Value="balanced", ...
                ValueChangedFcn=@(~, ~) app.alignmentSetupChanged(true), ...
                Tag="ProjectionViewerAlignmentPairGraphModeDropDown");
            app.AlignmentPairGraphModeDropDown.Layout.Row = 2;
            app.AlignmentPairGraphModeDropDown.Layout.Column = 4;
            maxPairsLabel = uilabel(setupGrid, Text="Max pairs");
            maxPairsLabel.Layout.Row = 1;
            maxPairsLabel.Layout.Column = 5;
            app.AlignmentMaxPairsSpinner = uispinner(setupGrid, ...
                Limits=[1 100000], Step=1, Value=20, ...
                RoundFractionalValues="on", ...
                ValueChangedFcn=@(~, ~) app.alignmentSetupChanged(true), ...
                Tag="ProjectionViewerAlignmentMaxPairsSpinner");
            app.AlignmentMaxPairsSpinner.Layout.Row = 2;
            app.AlignmentMaxPairsSpinner.Layout.Column = 5;
            allPairsLabel = uilabel(setupGrid, Text="Pair coverage");
            allPairsLabel.Layout.Row = 1;
            allPairsLabel.Layout.Column = 6;
            app.AlignmentAllPairsCheckBox = uicheckbox(setupGrid, ...
                Text="All plausible", Value=false, ...
                ValueChangedFcn=@(~, ~) app.alignmentSetupChanged(true), ...
                Tag="ProjectionViewerAlignmentAllPairsCheckBox");
            app.AlignmentAllPairsCheckBox.Layout.Row = 2;
            app.AlignmentAllPairsCheckBox.Layout.Column = 6;

            settingsPanel = uipanel(app.AlignmentGrid, ...
                Title="2. Filter and solve settings", ...
                Tag="ProjectionViewerAlignmentSettingsPanel");
            settingsPanel.Layout.Row = 3;
            settingsPanel.Layout.Column = 2;
            settingsGrid = uigridlayout(settingsPanel, [2 5]);
            settingsGrid.RowHeight = {"fit", "fit"};
            settingsGrid.ColumnWidth = {"1.2x", "1.2x", "1.4x", ...
                "1x", "1x"};
            settingsGrid.Padding = [8 6 8 8];
            settingsGrid.ColumnSpacing = 8;
            lossLabel.Text = "Loss model";
            coplanarityLabel.Text = "Coplanarity prefilter";
            referencePolicyLabel = uilabel(settingsGrid, ...
                Text="Reference policy");
            drawRoiLabel = uilabel(settingsGrid, Text="Projection-plane ROI");
            clearRoiLabel = uilabel(settingsGrid, Text="");
            settingLabels = [lossLabel coplanarityLabel ...
                referencePolicyLabel drawRoiLabel clearRoiLabel];
            for column = 1:numel(settingLabels)
                settingLabels(column).Parent = settingsGrid;
                settingLabels(column).Layout.Row = 1;
                settingLabels(column).Layout.Column = column;
            end
            app.AlignmentLossDropDown.Parent = settingsGrid;
            app.AlignmentLossDropDown.Layout.Row = 2;
            app.AlignmentLossDropDown.Layout.Column = 1;
            app.AlignmentCoplanarityDropDown.Parent = settingsGrid;
            app.AlignmentCoplanarityDropDown.Layout.Row = 2;
            app.AlignmentCoplanarityDropDown.Layout.Column = 2;
            app.AlignmentReferenceMotionCheckBox.Parent = settingsGrid;
            app.AlignmentReferenceMotionCheckBox.Layout.Row = 2;
            app.AlignmentReferenceMotionCheckBox.Layout.Column = 3;
            app.AlignmentReferenceMotionCheckBox.Text = ...
                "Allow reference motion";
            app.AlignmentRoiButton.Parent = settingsGrid;
            app.AlignmentRoiButton.Layout.Row = 2;
            app.AlignmentRoiButton.Layout.Column = 4;
            app.AlignmentRoiButton.Text = "Draw ROI";
            app.AlignmentClearRoiButton.Parent = settingsGrid;
            app.AlignmentClearRoiButton.Layout.Row = 2;
            app.AlignmentClearRoiButton.Layout.Column = 5;
            app.AlignmentClearRoiButton.Text = "Clear ROI";

            workflowPanel = uipanel(app.AlignmentGrid, ...
                Title="3. Staged workflow and review", ...
                Tag="ProjectionViewerAlignmentWorkflowPanel");
            workflowPanel.Layout.Row = 4;
            workflowPanel.Layout.Column = [1 2];
            workflowGrid = uigridlayout(workflowPanel, [2 9]);
            workflowGrid.RowHeight = {"fit", "fit"};
            workflowGrid.ColumnWidth = {85, 85, 85, 85, 85, 85, 85, ...
                115, "1x"};
            workflowGrid.Padding = [8 6 8 8];
            workflowGrid.RowSpacing = 6;
            workflowGrid.ColumnSpacing = 8;
            stageControls = [app.AlignmentMatchButton ...
                app.AlignmentFilterButton app.AlignmentSolveButton ...
                app.AlignmentPreviewButton app.AlignmentApplyButton ...
                app.AlignmentRevertButton app.AlignmentCancelButton ...
                app.AlignmentDenseSurfaceButton];
            for column = 1:numel(stageControls)
                stageControls(column).Parent = workflowGrid;
                stageControls(column).Layout.Row = 1;
                stageControls(column).Layout.Column = column;
            end
            stageHint = uilabel(workflowGrid, ...
                Text="Run stages left to right; inspect before Solve");
            stageHint.Layout.Row = 1;
            stageHint.Layout.Column = 9;
            app.AlignmentAcceptedOverlayCheckBox.Text = "Accepted lines";
            app.AlignmentRejectedOverlayCheckBox.Text = "Rejected lines";
            app.AlignmentWorstOverlayCheckBox.Text = "Worst 10%";
            app.AlignmentFeatureOverlayCheckBox.Text = "Feature points";
            app.AlignmentClearOverlaysButton.Text = "Clear overlays";
            app.AlignmentDeleteMatchButton.Text = "Delete selected";
            app.AlignmentUndoCurationButton.Text = "Undo last";
            reviewControls = {app.AlignmentAcceptedOverlayCheckBox, ...
                app.AlignmentRejectedOverlayCheckBox, ...
                app.AlignmentWorstOverlayCheckBox, ...
                app.AlignmentFeatureOverlayCheckBox, ...
                app.AlignmentClearOverlaysButton, ...
                app.AlignmentDeleteMatchButton, ...
                app.AlignmentUndoCurationButton};
            for column = 1:numel(reviewControls)
                control = reviewControls{column};
                control.Parent = workflowGrid;
                control.Layout.Row = 2;
                control.Layout.Column = column;
            end
            reviewHint = uilabel(workflowGrid, ...
                Text="Selection is synchronized with the match ledger");
            reviewHint.Layout.Row = 2;
            reviewHint.Layout.Column = [8 9];

            pairPanel = uipanel(app.AlignmentGrid, ...
                Title="Pair schedule — enable rows before Match", ...
                Tag="ProjectionViewerAlignmentPairPanel");
            pairPanel.Layout.Row = 5;
            pairPanel.Layout.Column = [1 2];
            pairGrid = uigridlayout(pairPanel, [1 1]);
            pairGrid.Padding = [4 4 4 4];
            app.AlignmentPairTable.Parent = pairGrid;
            app.AlignmentPairTable.Layout.Row = 1;
            app.AlignmentPairTable.Layout.Column = 1;

            matchPanel = uipanel(app.AlignmentGrid, ...
                Title="Match ledger — Enabled controls the next Solve", ...
                Tag="ProjectionViewerAlignmentMatchPanel");
            matchPanel.Layout.Row = 6;
            matchPanel.Layout.Column = [1 2];
            matchGrid = uigridlayout(matchPanel, [1 1]);
            matchGrid.Padding = [4 4 4 4];
            app.AlignmentMatchTable.Parent = matchGrid;
            app.AlignmentMatchTable.Layout.Row = 1;
            app.AlignmentMatchTable.Layout.Column = 1;

            diagnosticsPanel = uipanel(app.AlignmentGrid, ...
                Title="Stage status and diagnostics", ...
                Tag="ProjectionViewerAlignmentDiagnosticsPanel");
            diagnosticsPanel.Layout.Row = 7;
            diagnosticsPanel.Layout.Column = [1 2];
            diagnosticsGrid = uigridlayout(diagnosticsPanel, [1 1]);
            diagnosticsGrid.Padding = [4 4 4 4];
            app.AlignmentDiagnosticsTextArea.Parent = diagnosticsGrid;
            app.AlignmentDiagnosticsTextArea.Layout.Row = 1;
            app.AlignmentDiagnosticsTextArea.Layout.Column = 1;
        end

        function updateAlignmentLayerItems(app)
            if isempty(app.AlignmentReferenceDropDown) || ...
                    ~isvalid(app.AlignmentReferenceDropDown)
                return
            end

            layerCount = numel(app.Scene.layers);
            layerItems = cellstr(app.layerDisplayNames());
            app.AlignmentReferenceDropDown.Items = layerItems;
            app.AlignmentReferenceDropDown.ItemsData = string(1:layerCount);
            app.AlignmentMovingDropDown.Items = layerItems;
            app.AlignmentMovingDropDown.ItemsData = string(1:layerCount);
            app.AlignmentPairController.synchronizeScene(app.Scene);
            pair = app.AlignmentPairController.currentPair();
            if isfield(pair, "ViewsAvailable") && pair.ViewsAvailable
                app.AlignmentReferenceDropDown.Value = ...
                    string(pair.ReferenceLayerIndex);
                app.AlignmentMovingDropDown.Value = ...
                    string(pair.MovingLayerIndex);
            elseif layerCount > 1
                referenceValue = ceil(layerCount / 2);
                movingValue = app.SelectedLayerIndex;
                if movingValue == referenceValue
                    movingValue = min(layerCount, referenceValue + 1);
                end
                viewIds = ProjectionViewMetadata.ids(app.Scene);
                pair = app.AlignmentPairController.selectViews( ...
                    viewIds(referenceValue), viewIds(movingValue));
                app.AlignmentReferenceDropDown.Value = ...
                    string(pair.ReferenceLayerIndex);
                app.AlignmentMovingDropDown.Value = ...
                    string(pair.MovingLayerIndex);
            end
            app.refreshAlignmentActivePairControls();
            app.refreshAlignmentPairTable();
        end

        function alignmentActivePairSelectorsChanged(app)
            app.synchronizeAlignmentActivePairFromSelectors();
        end

        function selected = synchronizeAlignmentActivePairFromSelectors(app)
            referenceIndex = app.validAlignmentLayerValue( ...
                app.AlignmentReferenceDropDown.Value, 1);
            movingIndex = app.validAlignmentLayerValue( ...
                app.AlignmentMovingDropDown.Value, numel(app.Scene.layers));
            if referenceIndex == movingIndex
                app.refreshAlignmentActivePairControls();
                app.setAlignmentStatus( ...
                    "Reference and moving views must differ.");
                selected = false;
                return
            end
            viewIds = ProjectionViewMetadata.ids(app.Scene);
            oldPresentationOffsets = app.anaglyphPresentationOffsets();
            app.AlignmentPairController.selectViews( ...
                viewIds(referenceIndex), viewIds(movingIndex));
            app.activeAlignmentPairChanged(oldPresentationOffsets);
            selected = true;
        end

        function swapAlignmentActivePair(app)
            oldPresentationOffsets = app.anaglyphPresentationOffsets();
            app.AlignmentPairController.swapRoles();
            app.activeAlignmentPairChanged(oldPresentationOffsets);
        end

        function stepAlignmentActivePair(app, direction)
            oldPresentationOffsets = app.anaglyphPresentationOffsets();
            if direction > 0
                [~, changed] = app.AlignmentPairController.stepNext();
            else
                [~, changed] = app.AlignmentPairController.stepPrevious();
            end
            if changed
                app.activeAlignmentPairChanged(oldPresentationOffsets);
            else
                app.refreshAlignmentActivePairControls();
            end
        end

        function activeAlignmentPairChanged(app, oldPresentationOffsets)
            if nargin < 2
                oldPresentationOffsets = app.anaglyphPresentationOffsets();
            end
            pair = app.AlignmentPairController.currentPair();
            if ProjectionSoloPairVisibility.isActive(app.AlignmentSoloState)
                app.AlignmentSoloState = ProjectionSoloPairVisibility.follow( ...
                    app.AlignmentSoloState, app.Scene, ...
                    pair.ReferenceViewId, pair.MovingViewId);
                app.applyAlignmentSoloPresentation();
            end
            if app.visibleAnaglyphLayerCount() == 2
                app.updateAllSurfaceBlendAppearance();
                app.applyAnaglyphPresentationOffsetDelta( ...
                    oldPresentationOffsets);
            end
            app.followPairViewpointAfterNavigation();
            app.refreshAlignmentActivePairControls();
            app.refreshAlignmentOverlays(true);
            app.clearSelectedAlignmentMatchOverlay();
        end

        function refreshAlignmentActivePairControls(app)
            if isempty(app.AlignmentPairStatusLabel) || ...
                    ~isvalid(app.AlignmentPairStatusLabel)
                return
            end
            pair = app.AlignmentPairController.currentPair();
            if ~isfield(pair, "PairId") || strlength(pair.PairId) == 0
                app.AlignmentPairStatusLabel.Text = "No active pair";
                app.AlignmentPairEnabledCheckBox.Enable = "off";
                app.AlignmentSoloPairCheckBox.Enable = "off";
                app.AlignmentSwapEyesButton.Enable = "off";
                app.AlignmentResetEyesButton.Enable = "off";
                app.refreshAlignmentPairViewpointControls();
                return
            end
            if pair.ViewsAvailable
                app.AlignmentReferenceDropDown.Value = ...
                    string(pair.ReferenceLayerIndex);
                app.AlignmentMovingDropDown.Value = ...
                    string(pair.MovingLayerIndex);
            end
            app.AlignmentPairEnabledCheckBox.Value = logical(pair.Enabled);
            app.AlignmentPairStatusLabel.Text = char( ...
                string(pair.Category) + " | " + string(pair.Status));
            pairIds = string({app.AlignmentPairController.Schedule.Pairs.PairId});
            pairIndex = find(pairIds == pair.PairId, 1, "first");
            enabled = [app.AlignmentPairController.Schedule.Pairs.Enabled];
            app.AlignmentPreviousPairButton.Enable = app.onOff( ...
                any(find(enabled) < pairIndex));
            app.AlignmentNextPairButton.Enable = app.onOff( ...
                any(find(enabled) > pairIndex));
            app.refreshAlignmentPairViewpointControls();
            app.refreshAlignmentStereoEyeStatus();
        end

        function followActivePairChanged(app)
            runtime = app.PairViewpointRuntime;
            runtime.FollowEnabled = ...
                logical(app.AlignmentFollowPairCheckBox.Value);
            runtime.SuspendedPairId = "";
            app.PairViewpointRuntime = runtime;
            app.refreshAlignmentPairViewpointStatus();
        end

        function followPairViewpointAfterNavigation(app)
            runtime = app.PairViewpointRuntime;
            pair = app.AlignmentPairController.currentPair();
            if ~isfield(pair, "PairId")
                return
            end
            pairId = string(pair.PairId);
            pairChanged = pairId ~= runtime.LastSelectionPairId;
            runtime.LastSelectionPairId = pairId;
            if pairChanged
                runtime.SuspendedPairId = "";
            end
            app.PairViewpointRuntime = runtime;
            if pairChanged && runtime.FollowEnabled
                app.applyActivePairViewpoint(false);
            end
        end

        function applyActivePairViewpoint(app, captureRestore)
            if nargin < 2
                captureRestore = true;
            end
            plan = app.activePairViewpointPlan();
            runtime = app.PairViewpointRuntime;
            runtime.LastPlan = plan;
            if ~plan.Available
                app.PairViewpointRuntime = runtime;
                app.refreshAlignmentPairViewpointControls(false);
                app.setAlignmentStatus(plan.Explanation);
                return
            end
            if (captureRestore || runtime.FollowEnabled) && ...
                    isempty(fieldnames(runtime.RestoreCamera))
                runtime.RestoreCamera = app.exportCameraState();
            end
            app.cancelCameraReconciliation();
            cameraState = struct( ...
                Position=(plan.Camera.PositionWorld - ...
                app.Scene.renderOrigin).', ...
                Target=(plan.Camera.TargetWorld - app.Scene.renderOrigin).', ...
                UpVector=plan.Camera.UpVector.', ...
                ViewAngle=plan.Camera.ViewAngle, Projection="orthographic");
            app.applyCameraState(cameraState);
            runtime.LastAppliedPairId = plan.PairId;
            runtime.SuspendedPairId = "";
            runtime.LastSelectionPairId = plan.PairId;
            app.PairViewpointRuntime = runtime;
            drawnow limitrate
            app.scheduleCameraReconciliation();
            app.refreshAlignmentPairViewpointControls(false);
        end

        function restorePairViewpoint(app)
            runtime = app.PairViewpointRuntime;
            if isempty(fieldnames(runtime.RestoreCamera))
                app.refreshAlignmentPairViewpointStatus();
                return
            end
            app.cancelCameraReconciliation();
            app.applyCameraState(runtime.RestoreCamera);
            runtime.RestoreCamera = struct();
            runtime.LastAppliedPairId = "";
            if runtime.FollowEnabled
                pair = app.AlignmentPairController.currentPair();
                runtime.SuspendedPairId = string(pair.PairId);
            end
            app.PairViewpointRuntime = runtime;
            drawnow limitrate
            app.scheduleCameraReconciliation();
            app.refreshAlignmentPairViewpointControls(false);
        end

        function plan = activePairViewpointPlan(app)
            axesPosition = app.Axes.InnerPosition;
            aspectRatio = max(axesPosition(3), 1) / ...
                max(axesPosition(4), 1);
            plan = ProjectionPairViewpoint.compute(app.Scene, ...
                app.AlignmentPairController.currentPair(), ...
                struct(AspectRatio=aspectRatio, FillFraction=0.8, ...
                MinimumViewAngleDegrees=app.MinCameraViewAngle, ...
                MaximumViewAngleDegrees=app.MaxCameraViewAngle));
        end

        function refreshAlignmentPairViewpointControls(app, recompute)
            if nargin < 2
                recompute = true;
            end
            if isempty(app.AlignmentPairViewButton) || ...
                    ~isvalid(app.AlignmentPairViewButton)
                return
            end
            runtime = app.PairViewpointRuntime;
            if recompute
                runtime.LastPlan = app.activePairViewpointPlan();
            end
            pair = app.AlignmentPairController.currentPair();
            if strlength(runtime.LastSelectionPairId) == 0 && ...
                    isfield(pair, "PairId")
                runtime.LastSelectionPairId = string(pair.PairId);
            end
            app.PairViewpointRuntime = runtime;
            plan = runtime.LastPlan;
            available = isstruct(plan) && isfield(plan, "Available") && ...
                logical(plan.Available);
            if available
                explanation = "View from the active pair midpoint.";
            elseif isstruct(plan) && isfield(plan, "Explanation")
                explanation = string(plan.Explanation);
            else
                explanation = "Pair viewpoint is unavailable.";
            end
            app.AlignmentPairViewButton.Enable = app.onOff(available);
            app.AlignmentPairViewButton.Tooltip = char(explanation);
            app.AlignmentFollowPairCheckBox.Enable = app.onOff(available);
            app.AlignmentFollowPairCheckBox.Tooltip = char(explanation);
            app.AlignmentFollowPairCheckBox.Value = runtime.FollowEnabled;
            app.AlignmentRestoreViewButton.Enable = app.onOff( ...
                ~isempty(fieldnames(runtime.RestoreCamera)));
            app.AlignmentRestoreViewButton.Tooltip = ...
                "Restore the camera captured before Pair viewpoint.";
            app.refreshAlignmentPairViewpointStatus();
        end

        function refreshAlignmentPairViewpointStatus(app)
            if isempty(app.AlignmentPairViewStatusLabel) || ...
                    ~isvalid(app.AlignmentPairViewStatusLabel)
                return
            end
            runtime = app.PairViewpointRuntime;
            pair = app.AlignmentPairController.currentPair();
            pairId = "";
            if isfield(pair, "PairId")
                pairId = string(pair.PairId);
            end
            if isstruct(runtime.LastPlan) && ...
                    isfield(runtime.LastPlan, "Available") && ...
                    ~runtime.LastPlan.Available
                text = string(runtime.LastPlan.Explanation);
            elseif runtime.FollowEnabled && ...
                    runtime.SuspendedPairId == pairId
                text = "Follow suspended for this pair; navigation resumes it.";
            elseif runtime.FollowEnabled
                text = "Follow active pair is on.";
            elseif runtime.LastAppliedPairId == pairId && strlength(pairId) > 0
                text = "Pair viewpoint applied; Restore is available.";
            else
                text = "Pair viewpoint is available.";
            end
            app.AlignmentPairViewStatusLabel.Text = char(text);
            app.AlignmentPairViewStatusLabel.Tooltip = char(text);
        end

        function noteManualCameraMotion(app)
            runtime = app.PairViewpointRuntime;
            if ~runtime.FollowEnabled
                return
            end
            pair = app.AlignmentPairController.currentPair();
            if isfield(pair, "PairId")
                runtime.SuspendedPairId = string(pair.PairId);
                app.PairViewpointRuntime = runtime;
                app.refreshAlignmentPairViewpointStatus();
            end
        end

        function diagnostics = pairViewpointDiagnostics(app)
            runtime = app.PairViewpointRuntime;
            pair = app.AlignmentPairController.currentPair();
            pairId = "";
            if isfield(pair, "PairId")
                pairId = string(pair.PairId);
            end
            plan = runtime.LastPlan;
            if ~isstruct(plan) || ~isfield(plan, "Available")
                plan = app.activePairViewpointPlan();
            end
            diagnostics = struct(Available=logical(plan.Available), ...
                Explanation=string(plan.Explanation), ...
                FollowEnabled=runtime.FollowEnabled, ...
                SuspendedForCurrentPair= ...
                runtime.FollowEnabled && runtime.SuspendedPairId == pairId, ...
                RestoreAvailable= ...
                ~isempty(fieldnames(runtime.RestoreCamera)), ...
                LastAppliedPairId=runtime.LastAppliedPairId, ...
                Plan=plan);
        end

        function runtime = defaultPairViewpointRuntime(app)
            pair = app.AlignmentPairController.currentPair();
            pairId = "";
            if isfield(pair, "PairId")
                pairId = string(pair.PairId);
            end
            runtime = struct(FollowEnabled=false, SuspendedPairId="", ...
                RestoreCamera=struct(), LastAppliedPairId="", ...
                LastSelectionPairId=pairId, LastPlan=struct());
        end

        function refreshAlignmentStereoEyeStatus(app)
            if isempty(app.AlignmentStereoEyeStatusLabel) || ...
                    ~isvalid(app.AlignmentStereoEyeStatusLabel)
                return
            end
            assignment = app.activeStereoEyeAssignment();
            available = isfield(assignment, "LeftViewId") && ...
                strlength(assignment.LeftViewId) > 0;
            app.AlignmentSwapEyesButton.Enable = app.onOff(available);
            app.AlignmentResetEyesButton.Enable = app.onOff( ...
                available && assignment.ManualOverride);
            if ~available
                app.AlignmentStereoEyeStatusLabel.Text = "Eyes unavailable";
                return
            end
            if assignment.ManualOverride
                modeText = "manual override";
            elseif assignment.IsDegenerate
                modeText = "auto, hysteresis";
            else
                modeText = "automatic";
            end
            app.AlignmentStereoEyeStatusLabel.Text = char( ...
                "Red/left: " + assignment.LeftViewId + " (" + ...
                modeText + ")");
        end

        function swapAlignmentStereoEyes(app)
            inputs = app.activeStereoEyeInputs();
            if ~inputs.Available
                return
            end
            oldPresentationOffsets = app.anaglyphPresentationOffsets();
            app.StereoEyeController.swapManual(inputs.PairId, ...
                inputs.ViewIds, inputs.Origins, inputs.CameraRightVector);
            app.updateAllSurfaceBlendAppearance();
            app.applyAnaglyphPresentationOffsetDelta(oldPresentationOffsets);
            app.refreshAlignmentStereoEyeStatus();
        end

        function resetAlignmentStereoEyes(app)
            inputs = app.activeStereoEyeInputs();
            if ~inputs.Available
                return
            end
            oldPresentationOffsets = app.anaglyphPresentationOffsets();
            app.StereoEyeController.resetManual(inputs.PairId, ...
                inputs.ViewIds, inputs.Origins, inputs.CameraRightVector);
            app.updateAllSurfaceBlendAppearance();
            app.applyAnaglyphPresentationOffsetDelta(oldPresentationOffsets);
            app.refreshAlignmentStereoEyeStatus();
        end

        function alignmentPairEnabledChanged(app)
            pair = app.AlignmentPairController.currentPair();
            app.AlignmentPairController.setPairEnabled(pair.PairId, ...
                logical(app.AlignmentPairEnabledCheckBox.Value));
            app.updateAlignmentPairTableEnabledState(pair);
            app.refreshAlignmentActivePairControls();
        end

        function updateAlignmentPairTableEnabledState(app, pair)
            if isempty(app.AlignmentPairTable) || ...
                    ~isvalid(app.AlignmentPairTable)
                return
            end
            data = app.AlignmentPairTable.Data;
            requiredVariables = ["Enabled", "Moving", "Reference"];
            if ~istable(data) || ~all(ismember(requiredVariables, ...
                    string(data.Properties.VariableNames)))
                return
            end
            activeIndices = sort([pair.MovingLayerIndex ...
                pair.ReferenceLayerIndex]);
            for rowIndex = 1:height(data)
                rowIndices = sort([data.Moving(rowIndex) ...
                    data.Reference(rowIndex)]);
                if isequal(rowIndices, activeIndices)
                    data.Enabled(rowIndex) = logical(pair.Enabled);
                end
            end
            app.AlignmentPairTable.Data = data;
        end

        function alignmentSoloPairChanged(app)
            if logical(app.AlignmentSoloPairCheckBox.Value)
                pair = app.AlignmentPairController.currentPair();
                app.AlignmentSoloState = ProjectionSoloPairVisibility.activate( ...
                    app.Scene, pair.ReferenceViewId, pair.MovingViewId);
                if ~isempty(app.VisibleCheckBox) && isvalid(app.VisibleCheckBox)
                    app.VisibleCheckBox.Enable = "off";
                end
                app.applyAlignmentSoloPresentation();
            else
                app.exitAlignmentSoloPair();
            end
        end

        function applyAlignmentSoloPresentation(app)
            mask = ProjectionSoloPairVisibility.effectiveMask( ...
                app.AlignmentSoloState, app.Scene);
            for layerIndex = 1:numel(app.Scene.layers)
                app.setLayerSurfaceVisible(layerIndex, mask(layerIndex));
            end
            app.raiseCrosshairOverlay();
        end

        function exitAlignmentSoloPair(app)
            if ~ProjectionSoloPairVisibility.isActive(app.AlignmentSoloState)
                return
            end
            app.Scene = ProjectionSoloPairVisibility.restore( ...
                app.Scene, app.AlignmentSoloState);
            app.AlignmentSoloState = struct();
            if ~isempty(app.AlignmentSoloPairCheckBox) && ...
                    isvalid(app.AlignmentSoloPairCheckBox)
                app.AlignmentSoloPairCheckBox.Value = false;
            end
            if ~isempty(app.VisibleCheckBox) && isvalid(app.VisibleCheckBox)
                app.VisibleCheckBox.Enable = "on";
            end
            for layerIndex = 1:numel(app.Scene.layers)
                app.setLayerSurfaceVisible( ...
                    layerIndex, app.Scene.layers(layerIndex).Visible);
            end
            app.updateAllSurfaceBlendAppearance();
            app.raiseCrosshairOverlay();
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

        function matchAlignmentWorkflow(app)
            if ~app.synchronizeAlignmentActivePairFromSelectors()
                return
            end
            app.AlignmentSession.clearCancel();
            app.clearAlignmentComputationState();
            app.clearAlignmentOverlays();
            app.setAlignmentActionEnabled(false);
            app.setAlignmentFilterEnabled(false);
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
                workingImages = app.renderAlignmentWorkingImages( ...
                    request, app.alignmentRenderOptions());
                workingImages = app.applyEnabledPairsToWorkingImages( ...
                    workingImages, enabledPairs);

                app.setAlignmentStatus("Detecting and matching features...");
                app.throwIfAlignmentCancelled();
                matchResult = ProjectionAlignmentFeatureMatcher.match( ...
                    workingImages, options);
                app.AlignmentSession.storeRawMatches( ...
                    request, workingImages, matchResult);
                app.updateAlignmentPairTable(workingImages.Schedule, ...
                    enabledPairs, matchResult, []);
                app.updateAlignmentMatchTable(matchResult, []);
                app.drawAlignmentMatchOverlays(matchResult);
                rawMatchCount = sum([matchResult.Matches.Count]);
                app.setAlignmentFilterEnabled(true);
                app.setAlignmentStatus(sprintf( ...
                    "Matched %d raw observations. Ready to filter.", ...
                    rawMatchCount));
            catch ME
                if strcmp(ME.identifier, "ProjectionViewerApp:alignmentCancelled")
                    app.AlignmentSession.storeSolve( ...
                        ProjectionAlignmentResult.validate( ...
                        struct(Status="cancelled")));
                    app.setAlignmentStatus("Alignment cancelled.");
                else
                    app.AlignmentSession.storeSolve( ...
                        ProjectionAlignmentResult.validate( ...
                        struct(Status="failed", Warnings=string(ME.message))));
                    app.setAlignmentStatus("Alignment failed: " + string(ME.message));
                end
            end
        end

        function filterAlignmentWorkflow(app)
            if ~app.hasMatchResult(app.AlignmentRawMatchResult)
                app.setAlignmentStatus("Run Match before Filter.");
                app.setAlignmentFilterEnabled(false);
                return
            end

            app.AlignmentSession.clearCancel();
            app.setAlignmentRunning(true);
            cleanup = onCleanup(@() app.setAlignmentRunning(false));
            app.setAlignmentActionEnabled(false);
            app.setAlignmentSolveEnabled(false);

            try
                app.setAlignmentStatus("Filtering matches...");
                app.throwIfAlignmentCancelled();
                options = app.AlignmentRequest.Options;
                currentOptions = app.currentAlignmentOptions();
                options.FilterPipeline = currentOptions.FilterPipeline;
                request = app.AlignmentRequest;
                request.Options = options;
                app.AlignmentRequest = request;
                filteredMatches = ProjectionAlignmentMatchFilter.filter( ...
                    app.AlignmentRawMatchResult, options, app.Scene);
                preRoiMatches = filteredMatches;
                filteredMatches = app.applyAlignmentRoi(filteredMatches);
                app.AlignmentSession.storeFilteredMatches(preRoiMatches, ...
                    filteredMatches, ...
                    app.defaultAlignmentCuratedMatchMask(filteredMatches), ...
                    app.defaultAlignmentDeletedMatchMask(filteredMatches));
                schedule = app.AlignmentWorkingImages.Schedule;
                enabledPairs = app.enabledAlignmentPairs(schedule);
                app.updateAlignmentPairTable(schedule, enabledPairs, ...
                    app.AlignmentRawMatchResult, filteredMatches);
                app.updateAlignmentMatchTable(filteredMatches, []);
                app.drawAlignmentMatchOverlays(filteredMatches);
                rawMatchCount = sum([app.AlignmentRawMatchResult.Matches.Count]);
                matchCount = sum([filteredMatches.Matches.Count]);
                if matchCount < 3 || any([filteredMatches.Matches.Count] < 3)
                    app.setAlignmentStatus(sprintf( ...
                        ['Each enabled pair needs at least 3 filtered matches; ' ...
                        '%d raw -> %d filtered total.'], ...
                        rawMatchCount, matchCount));
                    return
                end

                app.setAlignmentSolveEnabled(true);
                app.setAlignmentStatus(sprintf( ...
                    "Filtered %d raw -> %d observations. Ready to solve.", ...
                    rawMatchCount, matchCount));
            catch ME
                if strcmp(ME.identifier, "ProjectionViewerApp:alignmentCancelled")
                    app.setAlignmentStatus("Alignment filtering cancelled.");
                else
                    app.setAlignmentStatus( ...
                        "Alignment filtering failed: " + string(ME.message));
                end
            end
        end

        function solveAlignmentWorkflow(app)
            if ~app.hasFilteredAlignmentMatches()
                app.setAlignmentStatus("Run Filter before Solve.");
                app.setAlignmentSolveEnabled(false);
                return
            end

            app.AlignmentSession.clearCancel();
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
                currentOptions = app.currentAlignmentOptions();
                options.LossMode = currentOptions.LossMode;
                options.MovableParameters = currentOptions.MovableParameters;
                request = app.AlignmentRequest;
                request.Options = options;
                app.AlignmentRequest = request;
                result = ProjectionAlignmentOpkSolver.solve( ...
                    app.Scene, solveMatches, options, struct( ...
                    CancellationFcn=@() ...
                    app.alignmentCancellationRequested()));
                emptyResult = ProjectionAlignmentResult.empty( ...
                    app.AlignmentRequest);
                result.RequestSummary = emptyResult.RequestSummary;
                result = ProjectionAlignmentSafeSolvePolicy.apply( ...
                    result, solveMatches, options);
                app.AlignmentSession.storeSolve(result);
                app.updateAlignmentMatchTable(app.AlignmentFilteredMatchResult, ...
                    result);
                app.drawAlignmentOverlays(result);
                app.setAlignmentActionEnabled( ...
                    app.isAlignmentResultActionable(result));
                app.setAlignmentStatus(app.alignmentResultSummary(result));
            catch ME
                if any(strcmp(ME.identifier, [ ...
                        "ProjectionViewerApp:alignmentCancelled", ...
                        "ProjectionAlignmentOpkSolver:cancelled"]))
                    app.AlignmentSession.storeSolve( ...
                        ProjectionAlignmentResult.validate( ...
                        struct(Status="cancelled")));
                    app.setAlignmentStatus("Alignment cancelled.");
                else
                    app.AlignmentSession.storeSolve( ...
                        ProjectionAlignmentResult.validate( ...
                        struct(Status="failed", Warnings=string(ME.message))));
                    app.setAlignmentStatus("Alignment failed: " + string(ME.message));
                end
            end
        end

        function cancelAlignmentWorkflow(app)
            app.AlignmentSession.requestCancel();
            app.setAlignmentStatus("Cancelling alignment...");
        end

        function previewAlignmentResult(app)
            if ~app.isAlignmentResultActionable(app.AlignmentResult)
                return
            end
            previousScene = app.Scene;
            app.Scene = ProjectionAlignmentOpkSolver.previewCorrections( ...
                app.Scene, app.AlignmentResult);
            layerIndices = app.changedProjectionLayerIndices( ...
                previousScene, app.Scene);
            app.refreshProjectionLayers( ...
                layerIndices, app.DefaultMeshSampling, false);
            app.updateControlsFromSelectedLayer();
            app.drawAlignmentOverlays(app.AlignmentResult);
            app.AlignmentSession.markPreviewed();
            app.setAlignmentStatus("Previewing " + ...
                app.alignmentCorrectionSummary(app.AlignmentResult));
        end

        function applyAlignmentResult(app)
            if ~app.isAlignmentResultActionable(app.AlignmentResult)
                return
            end
            parentScene = ProjectionAlignmentOpkSolver.revertCorrections( ...
                app.Scene, app.AlignmentResult);
            if ~app.CorrectionStore.hasCurrent("applied")
                app.CorrectionStore.synchronizeScene(parentScene, ...
                    app.CorrectionStore.currentGenerationId());
            end
            correctionOptions = struct(ParentGenerationId= ...
                app.CorrectionStore.currentGenerationId());
            correctionSet = ProjectionCorrectionOpkAdapter.fromAlignmentResult( ...
                parentScene, app.AlignmentResult, correctionOptions);
            app.CorrectionStore.propose(correctionSet);
            app.CorrectionStore.accept(correctionSet.GenerationId);
            previousScene = app.Scene;
            [app.Scene, ~] = app.CorrectionStore.apply( ...
                correctionSet.GenerationId);
            app.AlignmentAppliedGenerationId = correctionSet.GenerationId;
            app.refreshCorrectionScene(previousScene);
            app.drawAlignmentOverlays(app.AlignmentResult);
            app.AlignmentSession.markApplied();
            app.setAlignmentStatus("Applied " + ...
                app.alignmentCorrectionSummary(app.AlignmentResult));
        end

        function revertAlignmentResult(app)
            if ~app.isAlignmentResultActionable(app.AlignmentResult)
                return
            end
            previousScene = app.Scene;
            if app.CorrectionStore.hasCurrent("applied")
                applied = app.CorrectionStore.current("applied");
                if applied.GenerationId ~= app.AlignmentAppliedGenerationId
                    error("ProjectionViewerApp:differentCorrectionApplied", ...
                        "The current applied correction was not created by " + ...
                        "this alignment result and cannot be reverted here.");
                end
                [app.Scene, ~] = app.CorrectionStore.revert( ...
                    applied.GenerationId);
                app.AlignmentAppliedGenerationId = "";
            else
                app.Scene = ProjectionAlignmentOpkSolver.revertCorrections( ...
                    app.Scene, app.AlignmentResult);
            end
            app.refreshCorrectionScene(previousScene);
            app.drawAlignmentOverlays(app.AlignmentResult);
            app.AlignmentSession.markReverted();
            app.setAlignmentStatus("Reverted alignment preview.");
        end

        function extractDenseSurfaceFromAlignment(app)
            if ~app.hasDenseSurfaceInput()
                app.setAlignmentStatus( ...
                    "Preview or apply an aligned pair with at least three accepted matches first.");
                return
            end
            app.DenseSurfaceRunning = true;
            app.AlignmentDenseSurfaceButton.Enable = "off";
            cleanup = onCleanup(@() app.finishDenseSurfaceRun());
            app.setAlignmentStatus("Rendering the current aligned stereo pair...");
            drawnow limitrate
            try
                [pairMatch, pair] = app.currentDenseSurfacePairMatch();
                options = app.currentAlignmentOptions();
                options.Scheduling.Strategy = "twoImage";
                options.Scheduling.ReferenceLayerIndex = pair(2);
                request = ProjectionAlignmentRequest.validate(struct( ...
                    Scene=app.Scene, LayerIndices=pair, ...
                    ReferenceLayerIndex=pair(2), AnalysisBands=[1 1], ...
                    Options=options));
                workingImages = app.renderAlignmentWorkingImages( ...
                    request, app.alignmentRenderOptions());
                pairWorking = workingImages.PairWorkingImages(1);
                app.setAlignmentStatus("Running CPU semi-global matching...");
                drawnow limitrate
                result = ProjectionDenseSurfaceExtractor.extract( ...
                    app.Scene, pairWorking, pairMatch);
                app.closeDenseSurfaceWindows();
                app.DenseSurfaceHandles = ...
                    ProjectionDenseSurfaceViewer.show(result);
                app.DenseSurfaceDiagnostics = result.Diagnostics;
                app.DenseSurfaceDiagnostics.Status = result.Status;
                app.setAlignmentStatus(sprintf( ...
                    "Dense surface: %d points, median height %.4g m, %.3g s.", ...
                    result.Diagnostics.SurfacePointCount, ...
                    result.Diagnostics.HeightMedianMeters, ...
                    result.Diagnostics.TotalSeconds));
            catch ME
                app.DenseSurfaceDiagnostics = struct(Status="failed", ...
                    Identifier=string(ME.identifier), ...
                    Message=string(ME.message));
                app.setAlignmentStatus( ...
                    "Dense surface failed: " + string(ME.message));
            end
            clear cleanup
        end

        function [pairMatch, pair] = currentDenseSurfacePairMatch(app)
            movingIndex = app.validAlignmentLayerValue( ...
                app.AlignmentMovingDropDown.Value, numel(app.Scene.layers));
            referenceIndex = app.validAlignmentLayerValue( ...
                app.AlignmentReferenceDropDown.Value, 1);
            pair = [movingIndex referenceIndex];
            matches = app.alignmentAcceptedSolveMatches();
            pairMatch = struct();
            for k = 1:numel(matches.Matches)
                candidatePair = ProjectionAlignmentLayerResolver.pairIndices( ...
                    app.Scene, matches.Matches(k));
                if isequal(candidatePair, pair)
                    pairMatch = matches.Matches(k);
                    break
                end
            end
            if isempty(fieldnames(pairMatch))
                error("ProjectionViewerApp:missingDenseSurfacePair", ...
                    "The selected moving-to-reference pair has no accepted matches.");
            end
        end

        function tf = hasDenseSurfaceInput(app)
            tf = false;
            capabilities = ProjectionDenseSurfaceExtractor.capabilities();
            if ~capabilities.HasDisparitySgm || ...
                    isempty(app.AlignmentMatchTable) || ...
                    ~isvalid(app.AlignmentMatchTable) || ...
                    ~app.hasFilteredAlignmentMatches()
                return
            end
            state = app.AlignmentSession.diagnostics();
            hasAlignedScene = any(state.Stage == ["previewed", "applied"]) || ...
                state.ManualAdjustmentUndoCount > 0;
            if ~hasAlignedScene
                return
            end
            try
                pairMatch = app.currentDenseSurfacePairMatch();
                tf = pairMatch.Count >= 3;
            catch
                tf = false;
            end
        end

        function refreshDenseSurfaceButton(app, state)
            if isempty(app.AlignmentDenseSurfaceButton) || ...
                    ~isvalid(app.AlignmentDenseSurfaceButton)
                return
            end
            if nargin < 2
                state = app.AlignmentSession.diagnostics();
            end
            capabilities = ProjectionDenseSurfaceExtractor.capabilities();
            hasAlignedScene = any(state.Stage == ["previewed", "applied"]) || ...
                state.ManualAdjustmentUndoCount > 0;
            enabled = ~app.DenseSurfaceRunning && ...
                capabilities.HasDisparitySgm && hasAlignedScene && ...
                app.hasDenseSurfaceInput();
            app.AlignmentDenseSurfaceButton.Enable = app.onOff(enabled);
        end

        function finishDenseSurfaceRun(app)
            app.DenseSurfaceRunning = false;
            app.refreshDenseSurfaceButton();
        end

        function closeDenseSurfaceWindows(app)
            handles = app.DenseSurfaceHandles;
            app.DenseSurfaceHandles = struct();
            if ~isstruct(handles)
                return
            end
            names = ["IntensityViewer", "SurfaceFigure"];
            for name = names
                if isfield(handles, name)
                    graphicsHandle = handles.(name);
                    if ~isempty(graphicsHandle) && isvalid(graphicsHandle)
                        delete(graphicsHandle);
                    end
                end
            end
        end

        function layerIndices = changedProjectionLayerIndices(app, ...
                previousScene, currentScene)
            changedMask = false(1, numel(currentScene.layers));
            for layerIndex = 1:numel(currentScene.layers)
                previousLayer = previousScene.layers(layerIndex);
                currentLayer = currentScene.layers(layerIndex);
                changedMask(layerIndex) = ~isequaln( ...
                    app.layerProjectionOffset(previousLayer), ...
                    app.layerProjectionOffset(currentLayer)) || ...
                    ~isequaln( ...
                    app.layerViewVectorAngularOffsetsDegrees(previousLayer), ...
                    app.layerViewVectorAngularOffsetsDegrees(currentLayer));
            end
            layerIndices = find(changedMask);
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
                schedulingStrategy = "qualityGraph";
                runtimePairs = app.AlignmentPairController.Schedule.Pairs;
                if ~isempty(runtimePairs)
                    scheduledViewIds = string( ...
                        {app.Scene.layers(layerIndices).ViewId});
                    inScope = arrayfun(@(pair) all(ismember( ...
                        pair.ViewIds, scheduledViewIds)), runtimePairs);
                    options.Scheduling.ForcedExcludePairIds = string( ...
                        {runtimePairs(inScope & ...
                        ~[runtimePairs.Enabled]).PairId});
                end
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
                Scheduling=struct( ...
                QualitySpeed=app.alignmentPairGraphMode(), ...
                MaxPairs=app.alignmentMaxPairs(), ...
                AllPlausiblePairs=app.alignmentAllPlausiblePairs()), ...
                FilterPipeline=struct( ...
                GeometricMethod="similarity", ...
                CoplanarityMethod=app.alignmentCoplanarityMethod(), ...
                NativeDisplacementMethod="none"), ...
                MovableParameters=struct( ...
                AllowReferenceMotion=app.allowAlignmentReferenceMotion()), ...
                Bounds=struct(KappaDegrees=15), ...
                SafeSolvePolicy=struct( ...
                MinSolverObservationsPerPair=3, ...
                MinPreferredObservationsPerPair=10, ...
                FailOnBoundHit=true, ...
                MinResidualImprovementFraction=0.10), ...
                LossMode=string(app.AlignmentLossDropDown.Value)));
        end

        function mode = alignmentPairGraphMode(app)
            mode = "balanced";
            if ~isempty(app.AlignmentPairGraphModeDropDown) && ...
                    isvalid(app.AlignmentPairGraphModeDropDown)
                mode = string(app.AlignmentPairGraphModeDropDown.Value);
            end
        end

        function count = alignmentMaxPairs(app)
            count = 20;
            if ~isempty(app.AlignmentMaxPairsSpinner) && ...
                    isvalid(app.AlignmentMaxPairsSpinner)
                count = double(app.AlignmentMaxPairsSpinner.Value);
            end
        end

        function tf = alignmentAllPlausiblePairs(app)
            tf = false;
            if ~isempty(app.AlignmentAllPairsCheckBox) && ...
                    isvalid(app.AlignmentAllPairsCheckBox)
                tf = logical(app.AlignmentAllPairsCheckBox.Value);
            end
        end

        function method = alignmentCoplanarityMethod(app)
            method = "none";
            if ~isempty(app.AlignmentCoplanarityDropDown) && ...
                    isvalid(app.AlignmentCoplanarityDropDown)
                method = string(app.AlignmentCoplanarityDropDown.Value);
            end
        end

        function tf = allowAlignmentReferenceMotion(app)
            tf = true;
            if ~isempty(app.AlignmentReferenceMotionCheckBox) && ...
                    isvalid(app.AlignmentReferenceMotionCheckBox)
                tf = logical(app.AlignmentReferenceMotionCheckBox.Value);
            end
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

        function alignmentSetupChanged(app, refreshPairs)
            if refreshPairs
                app.refreshAlignmentPairTable();
            end
            state = app.AlignmentSession.diagnostics();
            if state.MatchRevision == 0
                app.refreshAlignmentSessionIndicators();
                return
            end
            app.AlignmentSession.invalidateMatch();
            app.setAlignmentFilterEnabled(false);
            app.setAlignmentSolveEnabled(false);
            app.setAlignmentActionEnabled(false);
            app.clearAlignmentOverlays();
            app.setAlignmentStatus("Setup changed. Run Match again.");
        end

        function alignmentFilterSettingChanged(app)
            state = app.AlignmentSession.diagnostics();
            if state.MatchRevision == 0
                app.refreshAlignmentSessionIndicators();
                return
            end
            app.AlignmentSession.invalidateFilter();
            app.setAlignmentFilterEnabled(true);
            app.setAlignmentSolveEnabled(false);
            app.setAlignmentActionEnabled(false);
            app.updateAlignmentMatchTable(app.AlignmentRawMatchResult, []);
            app.drawAlignmentMatchOverlays(app.AlignmentRawMatchResult);
            app.setAlignmentStatus("Filter setting changed. Run Filter again.");
        end

        function alignmentSolveSettingChanged(app)
            state = app.AlignmentSession.diagnostics();
            if state.FilterRevision == 0
                app.refreshAlignmentSessionIndicators();
                return
            end
            app.AlignmentSession.invalidateSolve();
            app.setAlignmentSolveEnabled(app.hasSolvableFilteredMatches());
            app.setAlignmentActionEnabled(false);
            app.updateAlignmentMatchTable(app.AlignmentFilteredMatchResult, []);
            app.drawAlignmentMatchOverlays(app.AlignmentFilteredMatchResult);
            app.setAlignmentStatus("Solve setting changed. Run Solve again.");
        end

        function layerIndices = visibleAlignmentLayerIndices(app)
            visibleMask = [app.Scene.layers.Visible];
            layerIndices = find(visibleMask);
        end

        function mask = effectiveLayerVisibilityMask(app)
            if app.MotionRuntime.Active
                mask = false(1, numel(app.Scene.layers));
                layerIndex = app.currentMotionLayerIndex();
                if layerIndex > 0
                    mask(layerIndex) = true;
                end
                return
            end
            mask = ProjectionSoloPairVisibility.effectiveMask( ...
                app.AlignmentSoloState, app.Scene);
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
            stageDiagnostics.Session = app.AlignmentSession.diagnostics();
            stageDiagnostics.HasRequest = app.hasScalarStruct( ...
                app.AlignmentRequest);
            stageDiagnostics.HasWorkingImages = app.hasScalarStruct( ...
                app.AlignmentWorkingImages);
            stageDiagnostics.WorkingImageCacheHits = ...
                app.AlignmentWorkingImageCacheHits;
            stageDiagnostics.WorkingImageCacheMisses = ...
                app.AlignmentWorkingImageCacheMisses;
            stageDiagnostics.HasRawMatches = app.hasMatchResult( ...
                app.AlignmentRawMatchResult);
            stageDiagnostics.HasFilteredMatches = app.hasMatchResult( ...
                app.AlignmentFilteredMatchResult);
            stageDiagnostics.HasSolveResult = app.hasAlignmentResult();
            stageDiagnostics.RawMatchCount = app.totalAlignmentMatchCount( ...
                app.AlignmentRawMatchResult);
            stageDiagnostics.PreRoiMatchCount = ...
                app.totalAlignmentMatchCount(app.AlignmentPreRoiMatchResult);
            stageDiagnostics.FilteredMatchCount = ...
                app.totalAlignmentMatchCount(app.AlignmentFilteredMatchResult);
            stageDiagnostics.SolvedMatchCount = ...
                app.totalAlignmentMatchCount(app.AlignmentResult);
            stageDiagnostics.CuratedMaskCount = ...
                numel(app.AlignmentCuratedMatchMask);
            stageDiagnostics.CuratedMatchCount = ...
                sum(app.curatedAlignmentMatchCounts( ...
                app.AlignmentFilteredMatchResult));
            stageDiagnostics.RoiActive = ~isempty(app.AlignmentRoiBounds);
            stageDiagnostics.RoiBounds = app.AlignmentRoiBounds;
            stageDiagnostics.RoiRejectedRecordCount = ...
                app.alignmentLedgerRejectionCount( ...
                app.AlignmentFilteredMatchResult, "roi");
            stageDiagnostics.ManualAdjustmentCount = ...
                numel(app.AlignmentSession.ManualAdjustmentHistory);
            stageDiagnostics.ManualAdjustmentUndoCount = ...
                numel(app.AlignmentSession.ManualAdjustmentUndoStack);
            stageDiagnostics.DenseSurface = app.DenseSurfaceDiagnostics;
            stageDiagnostics.LastManualAdjustment = struct();
            if ~isempty(app.AlignmentSession.ManualAdjustmentHistory)
                stageDiagnostics.LastManualAdjustment = ...
                    app.AlignmentSession.ManualAdjustmentHistory{end};
            end
            stageDiagnostics.FeatureDiagnostics = struct();
            if app.hasMatchResult(app.AlignmentRawMatchResult) && ...
                    isfield(app.AlignmentRawMatchResult, "Diagnostics")
                stageDiagnostics.FeatureDiagnostics = ...
                    app.AlignmentRawMatchResult.Diagnostics;
            end
            stageDiagnostics.FilterDiagnostics = struct([]);
            if app.hasMatchResult(app.AlignmentPreRoiMatchResult) && ...
                    isfield(app.AlignmentPreRoiMatchResult, "Diagnostics") && ...
                    isfield(app.AlignmentPreRoiMatchResult.Diagnostics, ...
                    "FilterPipeline")
                stageDiagnostics.FilterDiagnostics = ...
                    app.AlignmentPreRoiMatchResult.Diagnostics.FilterPipeline;
            end
        end

        function count = alignmentLedgerRejectionCount(app, matchResult, reason)
            count = 0;
            if ~app.hasMatchResult(matchResult)
                return
            end
            records = ProjectionAlignmentMatchLedger.combine(matchResult);
            for k = 1:numel(records)
                count = count + any(records(k).RejectionReasons == reason);
            end
        end

        function tf = hasScalarStruct(~, value)
            tf = isstruct(value) && isscalar(value) && ~isempty(fieldnames(value));
        end

        function workingImages = renderAlignmentWorkingImages(app, request, options)
            key = ProjectionAlignmentWorkingImageRenderer.cacheKey( ...
                app.Scene, request, options);
            if app.hasScalarStruct(app.AlignmentWorkingImageCacheKey) && ...
                    isequaln(key, app.AlignmentWorkingImageCacheKey) && ...
                    app.hasScalarStruct(app.AlignmentWorkingImageCacheValue)
                workingImages = ProjectionAlignmentLayerResolver.reindex( ...
                    app.Scene, app.AlignmentWorkingImageCacheValue);
                app.AlignmentWorkingImageCacheValue = workingImages;
                app.AlignmentWorkingImageCacheHits = ...
                    app.AlignmentWorkingImageCacheHits + 1;
                return
            end
            workingImages = ProjectionAlignmentWorkingImageRenderer.render( ...
                app.Scene, request, options);
            app.AlignmentWorkingImageCacheKey = key;
            app.AlignmentWorkingImageCacheValue = workingImages;
            app.AlignmentWorkingImageCacheMisses = ...
                app.AlignmentWorkingImageCacheMisses + 1;
        end

        function clearAlignmentWorkingImageCache(app)
            app.AlignmentWorkingImageCacheKey = struct();
            app.AlignmentWorkingImageCacheValue = struct();
            app.AlignmentWorkingImageCacheHits = 0;
            app.AlignmentWorkingImageCacheMisses = 0;
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
                deletedMask = app.deletedMaskForPair( ...
                    pairMatch.Pair, pairMatch.Count);
                for matchIndex = 1:pairMatch.Count
                    rowIndex = rowIndex + 1;
                    recordIndex = recordIndices(matchIndex);
                    residualRecord = app.residualRecordForMatch( ...
                        result, pairMatch.Pair, recordIndex);
                    enabled(rowIndex) = curatedMask(matchIndex) && ...
                        ~deletedMask(matchIndex);
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
                    if deletedMask(matchIndex)
                        states(rowIndex) = "deleted";
                    elseif ~enabled(rowIndex)
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
            viewIds = ProjectionViewMetadata.ids(app.Scene);
            controllerPairs = app.AlignmentPairController.Schedule.Pairs;
            controllerPairIds = string({controllerPairs.PairId});
            for pairIndex = 1:size(pairs, 1)
                identity = ProjectionViewMetadata.pairIdentity( ...
                    viewIds(pairs(pairIndex, 1)), ...
                    viewIds(pairs(pairIndex, 2)));
                controllerIndex = find( ...
                    controllerPairIds == identity.PairId, 1, "first");
                if ~isempty(controllerIndex)
                    enabled(pairIndex) = enabled(pairIndex) && ...
                        logical(controllerPairs(controllerIndex).Enabled);
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
            if isfield(workingImages, "PairWorkingImages")
                workingImages.PairWorkingImages = ...
                    workingImages.PairWorkingImages(keepMask);
                workingImages.GridKeys = workingImages.GridKeys(keepMask);
                outputSizes = reshape( ...
                    [workingImages.PairWorkingImages.OutputSize], 2, []).';
                workingImages.OutputSize = outputSizes;
                firstPair = workingImages.PairWorkingImages(1);
                workingImages.ProjectionPlane = firstPair.ProjectionPlane;
                workingImages.OutputGrid = firstPair.OutputGrid;
                workingImages.PixelToPlane = firstPair.PixelToPlane;
                workingImages.LayerImages = firstPair.LayerImages;
                workingImages.LayerMasks = firstPair.LayerMasks;
            end
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
            mask = mask & ~app.deletedMaskForPair(pair, count);
        end

        function mask = deletedMaskForPair(app, pair, count)
            mask = false(count, 1);
            if isempty(app.AlignmentDeletedMatchMask) || ...
                    ~app.hasMatchResult(app.AlignmentFilteredMatchResult)
                return
            end

            pairIndex = app.filteredMatchPairIndex(pair);
            if isnan(pairIndex) || pairIndex > numel(app.AlignmentDeletedMatchMask)
                return
            end

            candidate = app.AlignmentDeletedMatchMask{pairIndex};
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

            enabledMasks = cell(1, numel(app.AlignmentFilteredMatchResult.Matches));
            deletedMasks = cell(1, numel(app.AlignmentFilteredMatchResult.Matches));
            for pairIndex = 1:numel(enabledMasks)
                enabledMasks{pairIndex} = false( ...
                    app.AlignmentFilteredMatchResult.Matches(pairIndex).Count, 1);
                deletedMasks{pairIndex} = false( ...
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
                    isDeleted = ismember("State", ...
                        string(data.Properties.VariableNames)) && ...
                        string(data.State(rowIndex)) == "deleted";
                    enabledMasks{pairIndex}(matchMask) = ...
                        logical(data.Enabled(rowIndex)) && ~isDeleted;
                    deletedMasks{pairIndex}(matchMask) = isDeleted;
                end
            end

            app.AlignmentCuratedMatchMask = enabledMasks;
            app.AlignmentDeletedMatchMask = deletedMasks;
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
                    pairMatch.MovingPlaneCoordinates) & ...
                    app.pointsInsideAlignmentRoi( ...
                    pairMatch.ReferencePlaneCoordinates);
                if isfield(pairMatch, "MatchLedger") && ...
                        isfield(pairMatch, "MatchRecordIndices")
                    fullKeepMask = [pairMatch.MatchLedger.Accepted].';
                    recordIndices = pairMatch.MatchRecordIndices(:);
                    fullKeepMask(recordIndices) = ...
                        fullKeepMask(recordIndices) & keepMask;
                    pairMatch.MatchLedger = ...
                        ProjectionAlignmentMatchLedger.applyStage( ...
                        pairMatch.MatchLedger, "roi", fullKeepMask);
                end
                matchResult.Matches(k) = app.subsetAlignmentPairMatch( ...
                    pairMatch, keepMask);
            end
            finalCounts = [matchResult.Matches.Count];
            matchResult.MatchLedger = ...
                ProjectionAlignmentMatchLedger.combine(matchResult);
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

        function masks = defaultAlignmentDeletedMatchMask(~, matchResult)
            masks = cell(1, numel(matchResult.Matches));
            for k = 1:numel(matchResult.Matches)
                masks{k} = false(matchResult.Matches(k).Count, 1);
            end
        end

        function selectAlignmentRoi(app)
            app.clearAlignmentRoi(false);
            position = app.defaultAlignmentRoiPosition();
            app.AlignmentRoiBounds = app.roiBoundsFromPosition(position);
            try
                app.drawAlignmentRoiOverlay(position);
                app.AlignmentRoiDrawingActive = true;
                app.AlignmentRoiStartPoint = [NaN NaN];
                app.refreshAlignmentRoiFiltering();
                app.setAlignmentStatus( ...
                    "ROI active; left-drag in the viewport to redraw it.");
            catch
                app.AlignmentRoiHandle = [];
                app.AlignmentRoiListeners = [];
                app.AlignmentRoiDrawingActive = false;
                app.setAlignmentStatus("Unable to draw the alignment ROI.");
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
            app.AlignmentRoiDrawingActive = false;
            app.AlignmentRoiStartPoint = [NaN NaN];
            if updateStatus
                app.refreshAlignmentRoiFiltering();
                app.setAlignmentStatus("ROI cleared.");
            end
        end

        function updateAlignmentRoiBounds(app)
            if app.hasValidAlignmentRoiHandle() && ...
                    all(isfinite(app.AlignmentRoiBounds))
                app.updateAlignmentRoiOverlay();
            end
        end

        function refreshAlignmentRoiFiltering(app)
            if ~app.hasMatchResult(app.AlignmentPreRoiMatchResult)
                return
            end
            filteredMatches = app.applyAlignmentRoi( ...
                app.AlignmentPreRoiMatchResult);
            app.AlignmentSession.replaceFilteredMatches(filteredMatches, ...
                app.defaultAlignmentCuratedMatchMask(filteredMatches), ...
                app.defaultAlignmentDeletedMatchMask(filteredMatches));
            app.setAlignmentActionEnabled(false);
            app.setAlignmentSolveEnabled(app.hasSolvableFilteredMatches());
            app.updateAlignmentMatchTable(filteredMatches, []);
            app.drawAlignmentMatchOverlays(filteredMatches);
            if app.hasScalarStruct(app.AlignmentWorkingImages) && ...
                    isfield(app.AlignmentWorkingImages, "Schedule")
                schedule = app.AlignmentWorkingImages.Schedule;
                app.updateAlignmentPairTable(schedule, ...
                    app.enabledAlignmentPairs(schedule), ...
                    app.AlignmentRawMatchResult, filteredMatches);
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
                mesh = app.buildInstrumentedLayerMesh( ...
                    layerIndex, layer, plane);
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
            app.AlignmentRoiBounds = app.roiBoundsFromPosition(position);
            app.updateAlignmentRoiOverlay();
        end

        function updateAlignmentRoiOverlay(app)
            bounds = app.AlignmentRoiBounds;
            planeCoordinates = [ ...
                bounds(1), bounds(2), bounds(2), bounds(1), bounds(1); ...
                bounds(3), bounds(3), bounds(4), bounds(4), bounds(3)];
            worldPoints = PlanarProjection.reconstruct3d( ...
                planeCoordinates, app.currentProjectionPlane()) - ...
                app.Scene.renderOrigin;
            if app.hasValidAlignmentRoiHandle()
                app.AlignmentRoiHandle.XData = worldPoints(1, :);
                app.AlignmentRoiHandle.YData = worldPoints(2, :);
                app.AlignmentRoiHandle.ZData = worldPoints(3, :);
            else
                app.AlignmentRoiHandle = line(app.Axes, ...
                    worldPoints(1, :), worldPoints(2, :), worldPoints(3, :), ...
                    Color=[0 1 1], LineWidth=1.5, HitTest="off", ...
                    PickableParts="none", Tag="ProjectionViewerAlignmentRoi");
            end
            app.raiseCrosshairOverlay();
        end

        function toggleAlignmentPanel(app)
            app.setAlignmentPanelVisible(~app.isAlignmentPanelVisible());
        end

        function setAlignmentPanelVisible(app, isVisible)
            if isVisible && (isempty(app.AlignmentLauncherGrid) || ...
                    ~isvalid(app.AlignmentLauncherGrid))
                creationTimer = tic;
                app.createAlignmentLauncherControls();
                app.PerformanceMonitor.increment("AlignmentUiCreations");
                app.PerformanceMonitor.recordTiming( ...
                    "AlignmentUiCreateSeconds", toc(creationTimer));
            end
            if isempty(app.AlignmentLauncherGrid) || ...
                    ~isvalid(app.AlignmentLauncherGrid)
                return
            end

            app.AlignmentLauncherGrid.Visible = app.onOff(isVisible);
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
            tf = ~isempty(app.AlignmentLauncherGrid) && ...
                isvalid(app.AlignmentLauncherGrid) && ...
                string(app.AlignmentLauncherGrid.Visible) == "on";
        end

        function setAlignmentRunning(app, isRunning)
            if isempty(app.AlignmentMatchButton) || ...
                    ~isvalid(app.AlignmentMatchButton)
                return
            end
            app.AlignmentMatchButton.Enable = app.onOff(~isRunning);
            app.setAlignmentFilterEnabled(~isRunning && ...
                app.hasMatchResult(app.AlignmentRawMatchResult));
            if isRunning
                app.setAlignmentSolveEnabled(false);
            else
                app.setAlignmentSolveEnabled(app.hasSolvableFilteredMatches());
            end
            app.AlignmentCancelButton.Enable = app.onOff(isRunning);
            drawnow limitrate
        end

        function setAlignmentFilterEnabled(app, isEnabled)
            if isempty(app.AlignmentFilterButton) || ...
                    ~isvalid(app.AlignmentFilterButton)
                return
            end
            app.AlignmentFilterButton.Enable = app.onOff(isEnabled);
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

        function tf = isAlignmentResultActionable(~, result)
            tf = ProjectionAlignmentSafeSolvePolicy.isActionable(result);
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
            app.AlignmentSession.clearComputation();
            app.DenseSurfaceDiagnostics = struct();
            app.DenseSurfaceRunning = false;
            app.closeDenseSurfaceWindows();
            app.updateAlignmentMatchTable([], []);
            app.clearSelectedAlignmentMatchOverlay();
            app.refreshAlignmentSessionIndicators();
        end

        function throwIfAlignmentCancelled(app)
            drawnow limitrate
            if app.AlignmentCancelRequested
                error("ProjectionViewerApp:alignmentCancelled", ...
                    "Alignment was cancelled.");
            end
        end

        function tf = alignmentCancellationRequested(app)
            drawnow limitrate
            tf = app.AlignmentCancelRequested;
        end

        function setAlignmentStatus(app, statusText)
            didUpdate = false;
            if ~isempty(app.AlignmentStatusLabel) && ...
                    isvalid(app.AlignmentStatusLabel)
                app.AlignmentStatusLabel.Text = char(statusText);
                didUpdate = true;
            end
            if ~isempty(app.AlignmentLauncherStatusLabel) && ...
                    isvalid(app.AlignmentLauncherStatusLabel)
                app.AlignmentLauncherStatusLabel.Text = char(statusText);
                didUpdate = true;
            end
            app.refreshAlignmentSessionIndicators();
            if didUpdate
                drawnow limitrate
            end
        end

        function refreshAlignmentSessionIndicators(app)
            state = app.AlignmentSession.diagnostics();
            app.refreshDenseSurfaceButton(state);
            if ~isempty(app.AlignmentStageLabel) && ...
                    isvalid(app.AlignmentStageLabel)
                app.AlignmentStageLabel.Text = char("Stage: " + state.Stage);
            end
            if isempty(app.AlignmentDiagnosticsTextArea) || ...
                    ~isvalid(app.AlignmentDiagnosticsTextArea)
                return
            end
            names = ["Match", "Filter", "Solve", "Preview", "Apply"];
            values = [state.Stale.Match, state.Stale.Filter, ...
                state.Stale.Solve, state.Stale.Preview, state.Stale.Apply];
            lines = strings(numel(names) + 6, 1);
            lines(1) = "Stage: " + state.Stage;
            lines(2) = "Session revision: " + string(state.Revision);
            for k = 1:numel(names)
                if values(k)
                    label = "stale";
                else
                    label = "current";
                end
                lines(k + 2) = names(k) + ": " + label;
            end
            lines(8) = "Raw observations: " + string( ...
                app.totalAlignmentMatchCount(app.AlignmentRawMatchResult));
            lines(9) = "Filtered observations: " + string( ...
                app.totalAlignmentMatchCount(app.AlignmentFilteredMatchResult));
            lines(10) = "Solved observations: " + string( ...
                app.totalAlignmentMatchCount(app.AlignmentResult));
            lines(11) = "ROI: " + app.onOff(~isempty(app.AlignmentRoiBounds));
            if state.ManualAdjustmentCount > 0
                lines(end + 1) = "Manual anchor adjustments: " + ...
                    string(state.ManualAdjustmentCount);
            end
            result = app.AlignmentResult;
            if isstruct(result) && isfield(result, "Diagnostics") && ...
                    isfield(result.Diagnostics, "Observability") && ...
                    isfield(result.Diagnostics.Observability, "Solution")
                observability = result.Diagnostics.Observability.Solution;
                lines(end + 1) = "Observed rank: " + ...
                    string(observability.Rank) + "/" + ...
                    string(numel(observability.Modes));
                lines(end + 1) = "Weak modes: " + ...
                    string(numel(observability.WeakModes));
            end
            if isstruct(result) && isfield(result, "Diagnostics") && ...
                    isfield(result.Diagnostics, "SafeSolvePolicy")
                lines(end + 1) = "Safety: " + ...
                    string(result.Diagnostics.SafeSolvePolicy.Status);
            end
            app.AlignmentDiagnosticsTextArea.Value = cellstr(lines);
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
            app.pushAlignmentCurationUndoState();
            app.syncCuratedMaskFromMatchTable();
            app.finishAlignmentCurationEdit("Match curation updated. Solve again.");
        end

        function finishAlignmentCurationEdit(app, statusText)
            app.AlignmentSession.invalidateSolve();
            app.setAlignmentActionEnabled(false);
            app.setAlignmentSolveEnabled(app.hasSolvableFilteredMatches());
            app.updateAlignmentMatchTable(app.AlignmentFilteredMatchResult, []);
            visibleMatches = app.applyCuratedMaskToMatchResult( ...
                app.AlignmentFilteredMatchResult);
            app.drawAlignmentMatchOverlays(visibleMatches);
            app.setAlignmentStatus(statusText);
        end

        function pushAlignmentCurationUndoState(app)
            snapshot = struct( ...
                CuratedMatchMask={app.AlignmentCuratedMatchMask}, ...
                DeletedMatchMask={app.AlignmentDeletedMatchMask}, ...
                Revision=double(app.AlignmentSession.Revision));
            app.AlignmentCurationUndoStack{end + 1} = snapshot;
        end

        function deleteSelectedAlignmentMatches(app)
            if isempty(app.AlignmentSelectedMatchRows)
                app.setAlignmentStatus("Select match rows before Delete.");
                return
            end
            if isempty(app.AlignmentMatchTable) || ~isvalid(app.AlignmentMatchTable)
                return
            end

            data = app.AlignmentMatchTable.Data;
            if ~istable(data) || height(data) == 0
                return
            end

            rows = unique(app.AlignmentSelectedMatchRows(:));
            rows = rows(rows >= 1 & rows <= height(data));
            if isempty(rows)
                app.setAlignmentStatus("Select match rows before Delete.");
                return
            end

            app.pushAlignmentCurationUndoState();
            data.Enabled(rows) = false;
            data.State(rows) = "deleted";
            app.AlignmentMatchTable.Data = data;
            app.syncCuratedMaskFromMatchTable();
            app.finishAlignmentCurationEdit("Deleted selected matches. Solve again.");
        end

        function undoAlignmentCuration(app)
            curationRevision = app.latestAlignmentUndoRevision( ...
                app.AlignmentCurationUndoStack);
            manualRevision = app.latestAlignmentUndoRevision( ...
                app.AlignmentSession.ManualAdjustmentUndoStack);
            if manualRevision > curationRevision
                app.undoManualAlignmentAdjustment();
                return
            end
            if isempty(app.AlignmentCurationUndoStack)
                app.setAlignmentStatus("No alignment edit to undo.");
                return
            end

            snapshot = app.AlignmentCurationUndoStack{end};
            app.AlignmentCurationUndoStack(end) = [];
            app.AlignmentCuratedMatchMask = snapshot.CuratedMatchMask;
            app.AlignmentDeletedMatchMask = snapshot.DeletedMatchMask;
            app.finishAlignmentCurationEdit("Undid match curation. Solve again.");
        end

        function undoManualAlignmentAdjustment(app)
            [record, found] = app.AlignmentSession.popManualAdjustment();
            if ~found
                app.setAlignmentStatus("No manual alignment adjustment to undo.");
                return
            end
            previousScene = app.Scene;
            app.Scene = ProjectionAlignmentCommonAnchor.applyCorrections( ...
                app.Scene, record.StartingCorrections);
            layerIndices = app.changedProjectionLayerIndices( ...
                previousScene, app.Scene);
            app.refreshProjectionLayers( ...
                layerIndices, app.DefaultMeshSampling, false);
            app.updateControlsFromSelectedLayer();
            app.setAlignmentActionEnabled(false);
            app.setAlignmentSolveEnabled(app.hasSolvableFilteredMatches());
            app.refreshAlignmentOverlays(true);
            app.refreshSelectedAlignmentMatchOverlay();
            app.setAlignmentStatus( ...
                "Undid common-anchor adjustment. Solve diagnostics remain stale.");
        end

        function revision = latestAlignmentUndoRevision(~, stack)
            revision = -Inf;
            if isempty(stack)
                return
            end
            record = stack{end};
            if isstruct(record) && isfield(record, "Revision")
                revision = double(record.Revision);
            end
        end

        function alignmentMatchTableSelected(app, event)
            if (isstruct(event) && isfield(event, "Indices")) || ...
                    (isobject(event) && isprop(event, "Indices"))
                indices = event.Indices;
            else
                indices = [];
            end
            if isempty(indices)
                app.AlignmentSelectedMatchRows = [];
                app.clearSelectedAlignmentMatchOverlay();
                return
            end
            rowIndex = indices(1, 1);
            app.AlignmentSelectedMatchRows = unique(indices(:, 1)).';
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

            pairSubset = pairMatch;
            pairSubset.MovingSourceRows = pairMatch.MovingSourceRows(matchIndex);
            pairSubset.MovingSourceColumns = ...
                pairMatch.MovingSourceColumns(matchIndex);
            pairSubset.ReferenceSourceRows = ...
                pairMatch.ReferenceSourceRows(matchIndex);
            pairSubset.ReferenceSourceColumns = ...
                pairMatch.ReferenceSourceColumns(matchIndex);
            pairSubset.MovingPlaneCoordinates = ...
                pairMatch.MovingPlaneCoordinates(matchIndex, :);
            pairSubset.ReferencePlaneCoordinates = ...
                pairMatch.ReferencePlaneCoordinates(matchIndex, :);
            [movingProjectionPoint, referenceProjectionPoint, ...
                movingValid, referenceValid] = ...
                app.currentAlignmentProjectionPoints(pairSubset);
            if ~movingValid && ~referenceValid
                return
            end
            plane = app.currentProjectionPlane();
            selectedHandles = gobjects(0);
            if movingValid
                movingWorld = PlanarProjection.reconstruct3d( ...
                    movingProjectionPoint.', plane) - app.Scene.renderOrigin;
            else
                movingWorld = nan(3, 1);
            end
            if referenceValid
                referenceWorld = PlanarProjection.reconstruct3d( ...
                    referenceProjectionPoint.', plane) - app.Scene.renderOrigin;
            else
                referenceWorld = nan(3, 1);
            end
            if movingValid && referenceValid
                selectedHandles(end + 1) = line(app.Axes, ...
                    [movingWorld(1) referenceWorld(1)], ...
                    [movingWorld(2) referenceWorld(2)], ...
                    [movingWorld(3) referenceWorld(3)], ...
                    Color=[1 0 1], LineWidth=2.5, HitTest="off", ...
                    PickableParts="none", ...
                    Tag="ProjectionViewerAlignmentSelectedMatchOverlay");
            end
            selectedHandles(end + 1) = line(app.Axes, ...
                [movingWorld(1) referenceWorld(1)], ...
                [movingWorld(2) referenceWorld(2)], ...
                [movingWorld(3) referenceWorld(3)], ...
                LineStyle="none", Marker="s", MarkerSize=7, ...
                MarkerEdgeColor=[1 0 1], HitTest="off", ...
                PickableParts="none", ...
                Tag="ProjectionViewerAlignmentSelectedMatchOverlay");
            app.AlignmentSelectedMatchOverlay = selectedHandles;
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
            matches = app.alignmentOverlayMatches(matchResult);
            matches = app.filterActiveAlignmentPairMatches(matches);
            result = struct(Matches=matches);
            app.drawAlignmentOverlays(result);
        end

        function matches = filterActiveAlignmentPairMatches(app, matches)
            if isempty(matches)
                return
            end
            pair = app.activeAlignmentLayerPair();
            if isempty(pair)
                return
            end
            keep = false(1, numel(matches));
            for matchIndex = 1:numel(matches)
                resolvedPair = ProjectionAlignmentLayerResolver.pairIndices( ...
                    app.Scene, matches(matchIndex));
                keep(matchIndex) = isequal(sort(resolvedPair), sort(pair));
            end
            matches = matches(keep);
        end

        function pair = activeAlignmentLayerPair(app)
            pairRecord = app.AlignmentPairController.currentPair();
            if isfield(pairRecord, "ViewsAvailable") && ...
                    pairRecord.ViewsAvailable
                pair = [pairRecord.MovingLayerIndex ...
                    pairRecord.ReferenceLayerIndex];
            else
                pair = zeros(1, 0);
            end
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

        function [movingPoints, referencePoints, movingValid, referenceValid] = ...
                currentAlignmentProjectionPoints(app, pairMatch)
            count = double(pairMatch.Count);
            movingPoints = nan(count, 2);
            referencePoints = nan(count, 2);
            movingValid = false(count, 1);
            referenceValid = false(count, 1);
            requiredFields = ["MovingSourceRows", "MovingSourceColumns", ...
                "ReferenceSourceRows", "ReferenceSourceColumns"];
            if any(~isfield(pairMatch, requiredFields))
                if isfield(pairMatch, "MovingPlaneCoordinates")
                    movingPoints = pairMatch.MovingPlaneCoordinates;
                    movingValid = all(isfinite(movingPoints), 2);
                end
                if isfield(pairMatch, "ReferencePlaneCoordinates")
                    referencePoints = pairMatch.ReferencePlaneCoordinates;
                    referenceValid = all(isfinite(referencePoints), 2);
                end
                return
            end

            pair = ProjectionAlignmentLayerResolver.pairIndices( ...
                app.Scene, pairMatch);
            [movingPoints, movingValid] = ...
                app.projectLayerSourceObservationsToCurrentPlane( ...
                pair(1), pairMatch.MovingSourceRows, ...
                pairMatch.MovingSourceColumns);
            [referencePoints, referenceValid] = ...
                app.projectLayerSourceObservationsToCurrentPlane( ...
                pair(2), pairMatch.ReferenceSourceRows, ...
                pairMatch.ReferenceSourceColumns);
        end

        function [planePoints, validMask, status] = ...
                projectLayerSourceObservationsToCurrentPlane( ...
                app, layerIndex, rows, columns)
            projection = ProjectionAlignmentObservationProjector.project( ...
                app.Scene, layerIndex, rows, columns, ...
                app.currentProjectionPlane());
            planePoints = projection.PlaneCoordinates;
            validMask = projection.ValidMask;
            status = projection.Status;
        end

        function refreshAlignmentOverlays(app, force)
            if nargin < 2
                force = false;
            end
            if ~force && ~app.hasAlignmentOverlayGraphics()
                return
            end

            if app.hasAlignmentResult()
                app.drawAlignmentOverlays(app.AlignmentResult);
            elseif app.hasFilteredAlignmentMatches()
                visibleMatches = app.applyCuratedMaskToMatchResult( ...
                    app.AlignmentFilteredMatchResult);
                app.drawAlignmentMatchOverlays(visibleMatches);
            elseif app.hasMatchResult(app.AlignmentRawMatchResult)
                app.drawAlignmentMatchOverlays(app.AlignmentRawMatchResult);
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

        function records = alignmentOverlayRecords(app, result)
            acceptedRecords = app.emptyAlignmentOverlayRecords();
            rejectedRecords = app.emptyAlignmentOverlayRecords();

            if app.hasFilteredAlignmentMatches()
                acceptedMatches = app.applyCuratedMaskToMatchResult( ...
                    app.AlignmentFilteredMatchResult);
                acceptedRecords = app.alignmentOverlayRecordsFromMatchResult( ...
                    acceptedMatches, "accepted", result);
                if app.hasMatchResult(app.AlignmentRawMatchResult)
                    rawRecords = app.alignmentOverlayRecordsFromMatchResult( ...
                        app.AlignmentRawMatchResult, "rejected", []);
                    acceptedKeys = app.alignmentOverlayRecordKeys( ...
                        acceptedRecords);
                    rawKeys = app.alignmentOverlayRecordKeys(rawRecords);
                    rejectedRecords = rawRecords(~ismember(rawKeys, acceptedKeys));
                end
            elseif isfield(result, "Diagnostics") && ...
                    isfield(result.Diagnostics, "MatchRecords") && ...
                    ~isempty(result.Diagnostics.MatchRecords)
                acceptedRecords = app.alignmentOverlayRecordsFromSolverRecords( ...
                    result.Diagnostics.MatchRecords);
            elseif isfield(result, "Matches") && ~isempty(result.Matches)
                acceptedRecords = app.alignmentOverlayRecordsFromOverlayMatches( ...
                    result.Matches);
            end

            records = [acceptedRecords rejectedRecords];
            activePair = app.activeAlignmentLayerPair();
            if ~isempty(activePair) && ~isempty(records)
                pairMask = false(1, numel(records));
                for recordIndex = 1:numel(records)
                    pairMask(recordIndex) = isequal( ...
                        sort(records(recordIndex).Pair), sort(activePair));
                end
                records = records(pairMask);
            end
            records = app.markWorstAlignmentOverlayRecords(records);
        end

        function records = emptyAlignmentOverlayRecords(~)
            records = struct("Pair", {}, "PairLayerIds", {}, "PairKey", {}, ...
                "MatchIndex", {}, ...
                "State", {}, "MovingProjectionPoint", {}, ...
                "ReferenceProjectionPoint", {}, "MovingValid", {}, ...
                "ReferenceValid", {}, "ResidualAfter", {}, "IsWorst", {});
        end

        function records = alignmentOverlayRecordsFromMatchResult(app, ...
                matchResult, state, result)
            records = app.emptyAlignmentOverlayRecords();
            if ~app.hasMatchResult(matchResult)
                return
            end
            if nargin < 4
                result = [];
            end

            cursor = 0;
            totalCount = sum([matchResult.Matches.Count]);
            if totalCount == 0
                return
            end
            records(1, totalCount) = app.defaultAlignmentOverlayRecord();
            for pairIndex = 1:numel(matchResult.Matches)
                pairMatch = matchResult.Matches(pairIndex);
                recordIndices = app.matchRecordIndices(pairMatch);
                [movingPoints, referencePoints, movingValid, referenceValid] = ...
                    app.currentAlignmentProjectionPoints(pairMatch);
                for matchIndex = 1:pairMatch.Count
                    cursor = cursor + 1;
                    recordIndex = recordIndices(matchIndex);
                    residualRecord = app.residualRecordForMatch( ...
                        result, pairMatch.Pair, recordIndex);
                    record = app.defaultAlignmentOverlayRecord();
                    record.Pair = ProjectionAlignmentLayerResolver.pairIndices( ...
                        app.Scene, pairMatch);
                    record.PairLayerIds = app.pairLayerIdsForMatch(pairMatch);
                    record.PairKey = app.pairKey(record.Pair);
                    record.MatchIndex = recordIndex;
                    record.State = state;
                    record.MovingProjectionPoint = movingPoints(matchIndex, :);
                    record.ReferenceProjectionPoint = ...
                        referencePoints(matchIndex, :);
                    record.MovingValid = movingValid(matchIndex);
                    record.ReferenceValid = referenceValid(matchIndex);
                    if ~(record.MovingValid && record.ReferenceValid)
                        record.State = "invalidProjection";
                    end
                    record.ResidualAfter = residualRecord.After;
                    records(cursor) = record;
                end
            end
            records = records(1:cursor);
        end

        function records = alignmentOverlayRecordsFromSolverRecords(app, ...
                solverRecords)
            records = app.emptyAlignmentOverlayRecords();
            if isempty(solverRecords)
                return
            end

            records(1, numel(solverRecords)) = ...
                app.defaultAlignmentOverlayRecord();
            for k = 1:numel(solverRecords)
                solverRecord = solverRecords(k);
                pairMatch = struct();
                pairMatch.Pair = solverRecord.Pair;
                if isfield(solverRecord, "PairLayerIds")
                    pairMatch.PairLayerIds = solverRecord.PairLayerIds;
                end
                pairMatch.MovingSourceRows = solverRecord.MovingSourceRow;
                pairMatch.MovingSourceColumns = solverRecord.MovingSourceColumn;
                pairMatch.ReferenceSourceRows = ...
                    solverRecord.ReferenceSourceRow;
                pairMatch.ReferenceSourceColumns = ...
                    solverRecord.ReferenceSourceColumn;
                pairMatch.MovingPlaneCoordinates = ...
                    [solverRecord.MovingProjectionX solverRecord.MovingProjectionY];
                pairMatch.ReferencePlaneCoordinates = ...
                    [solverRecord.ReferenceProjectionX ...
                    solverRecord.ReferenceProjectionY];
                pairMatch.Count = 1;
                [movingPoints, referencePoints, movingValid, referenceValid] = ...
                    app.currentAlignmentProjectionPoints(pairMatch);

                record = app.defaultAlignmentOverlayRecord();
                record.Pair = ProjectionAlignmentLayerResolver.pairIndices( ...
                    app.Scene, pairMatch);
                record.PairLayerIds = app.pairLayerIdsForMatch(pairMatch);
                record.PairKey = app.pairKey(record.Pair);
                record.MatchIndex = solverRecord.MatchIndex;
                record.State = "accepted";
                record.MovingProjectionPoint = movingPoints(1, :);
                record.ReferenceProjectionPoint = referencePoints(1, :);
                record.MovingValid = movingValid(1);
                record.ReferenceValid = referenceValid(1);
                if ~(record.MovingValid && record.ReferenceValid)
                    record.State = "invalidProjection";
                end
                record.ResidualAfter = solverRecord.ResidualAfter;
                records(k) = record;
            end
        end

        function records = alignmentOverlayRecordsFromOverlayMatches(app, matches)
            records = app.emptyAlignmentOverlayRecords();
            if isempty(matches)
                return
            end

            totalCount = sum([matches.Count]);
            if totalCount == 0
                return
            end
            records(1, totalCount) = app.defaultAlignmentOverlayRecord();
            cursor = 0;
            for pairIndex = 1:numel(matches)
                pairMatch = matches(pairIndex);
                for matchIndex = 1:pairMatch.Count
                    cursor = cursor + 1;
                    record = app.defaultAlignmentOverlayRecord();
                    record.Pair = pairMatch.Pair;
                    record.PairLayerIds = app.pairLayerIdsForMatch(pairMatch);
                    record.PairKey = app.pairKey(pairMatch.Pair);
                    record.MatchIndex = matchIndex;
                    record.State = "accepted";
                    record.MovingProjectionPoint = ...
                        pairMatch.MovingProjectionPoints(matchIndex, :);
                    record.ReferenceProjectionPoint = ...
                        pairMatch.ReferenceProjectionPoints(matchIndex, :);
                    record.MovingValid = all(isfinite( ...
                        record.MovingProjectionPoint));
                    record.ReferenceValid = all(isfinite( ...
                        record.ReferenceProjectionPoint));
                    if ~(record.MovingValid && record.ReferenceValid)
                        record.State = "invalidProjection";
                    end
                    records(cursor) = record;
                end
            end
        end

        function record = defaultAlignmentOverlayRecord(~)
            record = struct(Pair=[0 0], PairLayerIds=strings(1, 0), ...
                PairKey="", MatchIndex=0, ...
                State="accepted", MovingProjectionPoint=[NaN NaN], ...
                ReferenceProjectionPoint=[NaN NaN], MovingValid=false, ...
                ReferenceValid=false, ResidualAfter=NaN, IsWorst=false);
        end

        function layerIds = pairLayerIdsForMatch(app, pairMatch)
            if isfield(pairMatch, "PairLayerIds") && ...
                    numel(pairMatch.PairLayerIds) == 2
                layerIds = reshape(string(pairMatch.PairLayerIds), 1, []);
            else
                pair = ProjectionAlignmentLayerResolver.pairIndices( ...
                    app.Scene, pairMatch);
                layerIds = ProjectionLayerIdentity.idsForIndices(app.Scene, pair);
            end
        end

        function keys = alignmentOverlayRecordKeys(~, records)
            keys = strings(1, numel(records));
            for k = 1:numel(records)
                keys(k) = records(k).PairKey + "#" + string(records(k).MatchIndex);
            end
        end

        function records = markWorstAlignmentOverlayRecords(~, records)
            if isempty(records)
                return
            end

            residuals = [records.ResidualAfter];
            finiteMask = isfinite(residuals);
            if ~any(finiteMask)
                return
            end

            finiteIndices = find(finiteMask);
            [~, order] = sort(residuals(finiteMask), "descend");
            worstCount = max(1, ceil(0.10 * numel(finiteIndices)));
            worstIndices = finiteIndices(order(1:worstCount));
            for k = reshape(worstIndices, 1, [])
                records(k).IsWorst = true;
            end
        end

        function drawAlignmentOverlays(app, result)
            app.clearAlignmentOverlays();
            records = app.alignmentOverlayRecords(result);
            if isempty(records)
                return
            end

            handles = gobjects(0);
            acceptedMask = string([records.State]) == "accepted";
            rejectedMask = ~acceptedMask;
            if app.alignmentOverlayToggleValue( ...
                    "AlignmentAcceptedOverlayCheckBox", true)
                handles = [handles app.drawAlignmentOverlayLines( ...
                    records(acceptedMask), [1 0.9 0.1], 0.75, ...
                    "ProjectionViewerAlignmentMatchOverlay")];
            end
            if app.alignmentOverlayToggleValue( ...
                    "AlignmentRejectedOverlayCheckBox", false)
                handles = [handles app.drawAlignmentOverlayLines( ...
                    records(rejectedMask), [0.55 0.55 0.55], 0.5, ...
                    "ProjectionViewerAlignmentRejectedMatchOverlay")];
            end
            if app.alignmentOverlayToggleValue( ...
                    "AlignmentFeatureOverlayCheckBox", true)
                handles = [handles app.drawAlignmentOverlayMarkers( ...
                    records(acceptedMask), [1 0.9 0.1], [0 1 0.3], ...
                    "ProjectionViewerAlignmentMovingMatchOverlay", ...
                    "ProjectionViewerAlignmentReferenceMatchOverlay")];
                if app.alignmentOverlayToggleValue( ...
                        "AlignmentRejectedOverlayCheckBox", false)
                    handles = [handles app.drawAlignmentOverlayMarkers( ...
                        records(rejectedMask), [0.55 0.55 0.55], ...
                        [0.45 0.65 0.45], ...
                        "ProjectionViewerAlignmentRejectedMovingMatchOverlay", ...
                        "ProjectionViewerAlignmentRejectedReferenceMatchOverlay")];
                end
            end
            if app.alignmentOverlayToggleValue( ...
                    "AlignmentWorstOverlayCheckBox", false)
                worstMask = [records.IsWorst];
                handles = [handles app.drawAlignmentOverlayLines( ...
                    records(worstMask), [1 0 1], 2, ...
                    "ProjectionViewerAlignmentWorstMatchOverlay")];
            end
            app.AlignmentOverlayLines = handles;
            app.raiseCrosshairOverlay();
        end

        function value = alignmentOverlayToggleValue(app, propertyName, defaultValue)
            control = app.(propertyName);
            if isempty(control) || ~isvalid(control)
                value = defaultValue;
            else
                value = logical(control.Value);
            end
        end

        function handles = drawAlignmentOverlayLines(app, records, color, ...
                lineWidth, tag)
            handles = gobjects(0);
            if isempty(records)
                return
            end
            records = records([records.MovingValid] & [records.ReferenceValid]);
            if isempty(records)
                return
            end

            [lineX, lineY, lineZ] = app.alignmentOverlayLineCoordinates(records);
            handles = line(app.Axes, lineX(:), lineY(:), lineZ(:), ...
                Color=color, LineWidth=lineWidth, HitTest="on", ...
                PickableParts="visible", Tag=tag, UserData=records, ...
                ButtonDownFcn=@(src, event) ...
                app.selectAlignmentMatchFromOverlay(src, event));
        end

        function handles = drawAlignmentOverlayMarkers(app, records, ...
                movingColor, referenceColor, movingTag, referenceTag)
            handles = gobjects(0);
            if isempty(records)
                return
            end

            [movingPoints, referencePoints] = ...
                app.alignmentOverlayWorldPoints(records);
            movingMask = [records.MovingValid];
            if any(movingMask)
                movingRecords = records(movingMask);
                handles(end + 1) = line(app.Axes, ...
                    movingPoints(1, movingMask), movingPoints(2, movingMask), ...
                    movingPoints(3, movingMask), LineStyle="none", ...
                    Marker="o", MarkerSize=4, MarkerEdgeColor=movingColor, ...
                    HitTest="on", PickableParts="visible", Tag=movingTag, ...
                    UserData=movingRecords, ButtonDownFcn=@(src, event) ...
                    app.selectAlignmentMatchFromOverlay(src, event));
            end
            referenceMask = [records.ReferenceValid];
            if any(referenceMask)
                referenceRecords = records(referenceMask);
                handles(end + 1) = line(app.Axes, ...
                    referencePoints(1, referenceMask), ...
                    referencePoints(2, referenceMask), ...
                    referencePoints(3, referenceMask), ...
                    LineStyle="none", Marker="+", MarkerSize=5, ...
                    MarkerEdgeColor=referenceColor, HitTest="on", ...
                    PickableParts="visible", Tag=referenceTag, ...
                    UserData=referenceRecords, ButtonDownFcn=@(src, event) ...
                    app.selectAlignmentMatchFromOverlay(src, event));
            end
        end

        function selectAlignmentMatchFromOverlay(app, source, event)
            records = source.UserData;
            if isempty(records)
                return
            end

            clickPoint = app.alignmentOverlayClickPoint(event);
            recordIndex = app.nearestAlignmentOverlayRecordIndex( ...
                records, clickPoint);
            if isnan(recordIndex)
                return
            end
            app.selectAlignmentMatchRecord(records(recordIndex));
            if app.IsShiftDown || app.eventHasShift(event)
                app.beginAlignmentAnchorDrag();
            end
        end

        function clickPoint = alignmentOverlayClickPoint(app, event)
            if (isstruct(event) && isfield(event, "IntersectionPoint")) || ...
                    (isobject(event) && isprop(event, "IntersectionPoint"))
                clickPoint = double(event.IntersectionPoint(1, :));
            else
                currentPoint = app.Axes.CurrentPoint;
                clickPoint = double(currentPoint(1, :));
            end
        end

        function recordIndex = nearestAlignmentOverlayRecordIndex(app, ...
                records, clickPoint)
            recordIndex = NaN;
            if isempty(records)
                return
            end

            [movingPoints, referencePoints] = ...
                app.alignmentOverlayWorldPoints(records);
            distances = inf(1, numel(records));
            for k = 1:numel(records)
                if records(k).MovingValid && records(k).ReferenceValid
                    distances(k) = app.pointToSegmentDistance(clickPoint(:), ...
                        movingPoints(:, k), referencePoints(:, k));
                elseif records(k).MovingValid
                    distances(k) = norm(clickPoint(:) - movingPoints(:, k));
                elseif records(k).ReferenceValid
                    distances(k) = norm(clickPoint(:) - referencePoints(:, k));
                end
            end
            [~, recordIndex] = min(distances);
        end

        function distance = pointToSegmentDistance(~, point, endpointA, endpointB)
            segment = endpointB - endpointA;
            segmentLengthSquared = dot(segment, segment);
            if segmentLengthSquared <= eps
                closestPoint = endpointA;
            else
                fraction = dot(point - endpointA, segment) / ...
                    segmentLengthSquared;
                fraction = min(max(fraction, 0), 1);
                closestPoint = endpointA + fraction * segment;
            end
            distance = norm(point - closestPoint);
        end

        function selectAlignmentMatchRecord(app, record)
            if isempty(app.AlignmentMatchTable) || ~isvalid(app.AlignmentMatchTable)
                return
            end

            data = app.AlignmentMatchTable.Data;
            if ~istable(data) || height(data) == 0
                return
            end

            row = find(data.Pair == record.PairKey & ...
                data.MatchIndex == record.MatchIndex, 1, "first");
            if isempty(row)
                return
            end

            app.AlignmentSelectedMatchRows = row;
            try
                if isprop(app.AlignmentMatchTable, "Selection")
                    app.AlignmentMatchTable.Selection = [row 1];
                end
            catch
            end
            app.drawSelectedAlignmentMatchOverlay(data(row, :));
        end

        function [lineX, lineY, lineZ] = alignmentOverlayLineCoordinates( ...
                app, records)
            [movingPoints, referencePoints] = ...
                app.alignmentOverlayWorldPoints(records);
            matchCount = numel(records);
            lineX = [movingPoints(1, :); referencePoints(1, :); ...
                nan(1, matchCount)];
            lineY = [movingPoints(2, :); referencePoints(2, :); ...
                nan(1, matchCount)];
            lineZ = [movingPoints(3, :); referencePoints(3, :); ...
                nan(1, matchCount)];
        end

        function [movingPoints, referencePoints] = ...
                alignmentOverlayWorldPoints(app, records)
            plane = app.currentProjectionPlane();
            movingPlanePoints = reshape([records.MovingProjectionPoint], ...
                2, []).';
            referencePlanePoints = reshape([records.ReferenceProjectionPoint], ...
                2, []).';
            movingPoints = nan(3, numel(records));
            referencePoints = nan(3, numel(records));
            movingMask = reshape([records.MovingValid], [], 1) & ...
                all(isfinite(movingPlanePoints), 2);
            referenceMask = reshape([records.ReferenceValid], [], 1) & ...
                all(isfinite(referencePlanePoints), 2);
            if any(movingMask)
                movingPoints(:, movingMask) = PlanarProjection.reconstruct3d( ...
                    movingPlanePoints(movingMask, :).', plane) - ...
                    app.Scene.renderOrigin;
            end
            if any(referenceMask)
                referencePoints(:, referenceMask) = ...
                    PlanarProjection.reconstruct3d( ...
                    referencePlanePoints(referenceMask, :).', plane) - ...
                    app.Scene.renderOrigin;
            end
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
            app.MotionImageryMenuItem = uimenu(app.ImageContextMenu, ...
                Text="Motion imagery...", Separator="on", ...
                MenuSelectedFcn=@(~, ~) app.openMotionImagery(), ...
                Tag="ProjectionViewerMotionImageryMenuItem");
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
            app.AnaglyphControlsMenu = uimenu(app.BlendModeMenu, ...
                Text="Anaglyph presentation", Separator="on", ...
                Tag="ProjectionViewerAnaglyphControlsMenu");
            app.AnaglyphIncreaseSeparationMenuItem = uimenu( ...
                app.AnaglyphControlsMenu, ...
                Text="Increase stereo separation", ...
                MenuSelectedFcn=@(~, ~) app.adjustAnaglyphStereoExaggeration(1), ...
                Tag="ProjectionViewerAnaglyphIncreaseSeparationMenuItem");
            app.AnaglyphDecreaseSeparationMenuItem = uimenu( ...
                app.AnaglyphControlsMenu, ...
                Text="Decrease stereo separation", ...
                MenuSelectedFcn=@(~, ~) app.adjustAnaglyphStereoExaggeration(-1), ...
                Tag="ProjectionViewerAnaglyphDecreaseSeparationMenuItem");
            app.AnaglyphMoveNearerMenuItem = uimenu( ...
                app.AnaglyphControlsMenu, Text="Move depth nearer", ...
                MenuSelectedFcn=@(~, ~) app.adjustAnaglyphScreenDepthOffset(1), ...
                Tag="ProjectionViewerAnaglyphMoveNearerMenuItem");
            app.AnaglyphMoveFartherMenuItem = uimenu( ...
                app.AnaglyphControlsMenu, Text="Move depth farther", ...
                MenuSelectedFcn=@(~, ~) app.adjustAnaglyphScreenDepthOffset(-1), ...
                Tag="ProjectionViewerAnaglyphMoveFartherMenuItem");
            app.AnaglyphResetPresentationMenuItem = uimenu( ...
                app.AnaglyphControlsMenu, Text="Reset anaglyph presentation", ...
                MenuSelectedFcn=@(~, ~) app.resetAnaglyphPresentation(), ...
                Tag="ProjectionViewerAnaglyphResetPresentationMenuItem");
            app.Axes.ContextMenu = app.ImageContextMenu;
        end

        function openMotionImagery(app)
            if ~isempty(app.MotionFigure) && isvalid(app.MotionFigure)
                figure(app.MotionFigure);
                return
            end
            app.MotionFigure = uifigure(Name="Motion Imagery", ...
                Position=[180 180 860 430], ...
                CloseRequestFcn=@(~, ~) app.closeMotionImagery(), ...
                Tag="ProjectionViewerMotionFigure");
            grid = uigridlayout(app.MotionFigure, [5 6]);
            grid.RowHeight = {"fit", "1x", "fit", "fit", "fit"};
            grid.ColumnWidth = {"fit", "1x", "fit", "fit", "fit", "fit"};
            grid.Padding = [10 10 10 10];

            uilabel(grid, Text="Pass");
            passIds = unique(string({app.Scene.layers.PassId}), "stable");
            app.MotionPassDropDown = uidropdown(grid, ...
                Items=cellstr(["All passes" passIds]), ...
                ItemsData=cellstr(["__all__" passIds]), Value="__all__", ...
                ValueChangedFcn=@(~, ~) app.motionConfigurationChanged(), ...
                Tag="ProjectionViewerMotionPassDropDown");
            app.MotionPassDropDown.Layout.Column = 2;
            app.MotionLoopCheckBox = uicheckbox(grid, Text="Loop", ...
                Value=false, ValueChangedFcn=@(~, ~) app.motionControlChanged(), ...
                Tag="ProjectionViewerMotionLoopCheckBox");
            app.MotionLoopCheckBox.Layout.Column = 3;
            app.MotionHoverCheckBox = uicheckbox(grid, ...
                Text="Hover edge controls", Value=true, ...
                ValueChangedFcn=@(~, ~) app.motionControlChanged(), ...
                Tag="ProjectionViewerMotionHoverCheckBox");
            app.MotionHoverCheckBox.Layout.Column = [4 5];
            app.MotionPinCheckBox = uicheckbox(grid, Text="Pin identity", ...
                Value=false, ValueChangedFcn=@(~, ~) app.motionControlChanged(), ...
                Tag="ProjectionViewerMotionPinCheckBox");
            app.MotionPinCheckBox.Layout.Column = 6;

            app.MotionTable = uitable(grid, ...
                Data=app.motionConfigurationTable(), ...
                ColumnEditable=[true false false false false], ...
                ColumnWidth={65 "auto" "auto" "auto" "auto"}, ...
                CellEditCallback=@(~, ~) app.motionConfigurationChanged(), ...
                Tag="ProjectionViewerMotionTable");
            app.MotionTable.Layout.Row = 2;
            app.MotionTable.Layout.Column = [1 6];

            app.MotionPreviousButton = uibutton(grid, Text="Previous", ...
                ButtonPushedFcn=@(~, ~) app.stepMotion(-1), ...
                Tag="ProjectionViewerMotionPreviousButton");
            app.MotionPreviousButton.Layout.Row = 3;
            app.MotionPreviousButton.Layout.Column = 1;
            app.MotionNextButton = uibutton(grid, Text="Next", ...
                ButtonPushedFcn=@(~, ~) app.stepMotion(1), ...
                Tag="ProjectionViewerMotionNextButton");
            app.MotionNextButton.Layout.Row = 3;
            app.MotionNextButton.Layout.Column = 2;
            rateLabel = uilabel(grid, Text="Rate (fps)", ...
                HorizontalAlignment="right");
            rateLabel.Layout.Row = 3;
            rateLabel.Layout.Column = 3;
            app.MotionRateSpinner = uispinner(grid, Limits=[0.5 10], ...
                Step=0.5, Value=ProjectionMotionPlayback.DefaultRateFps, ...
                ValueChangedFcn=@(~, ~) app.motionControlChanged(), ...
                Tag="ProjectionViewerMotionRateSpinner");
            app.MotionRateSpinner.Layout.Row = 3;
            app.MotionRateSpinner.Layout.Column = 4;
            app.MotionPlayPauseButton = uibutton(grid, Text="Play", ...
                Enable="off", ...
                ButtonPushedFcn=@(~, ~) app.toggleMotionPlayback(), ...
                Tag="ProjectionViewerMotionPlayPauseButton");
            app.MotionPlayPauseButton.Layout.Row = 3;
            app.MotionPlayPauseButton.Layout.Column = 5;
            app.MotionStartExitButton = uibutton(grid, Text="Start", ...
                ButtonPushedFcn=@(~, ~) app.toggleMotionImagery(), ...
                Tag="ProjectionViewerMotionStartExitButton");
            app.MotionStartExitButton.Layout.Row = 3;
            app.MotionStartExitButton.Layout.Column = 6;
            app.MotionStatusLabel = uilabel(grid, Text="", ...
                WordWrap="on", Tag="ProjectionViewerMotionStatusLabel");
            app.MotionStatusLabel.Layout.Row = [4 5];
            app.MotionStatusLabel.Layout.Column = [1 6];
            app.motionConfigurationChanged();
        end

        function data = motionConfigurationTable(app)
            count = numel(app.Scene.layers);
            include = true(count, 1);
            layer = strings(count, 1);
            viewId = strings(count, 1);
            passId = strings(count, 1);
            time = strings(count, 1);
            sequence = ProjectionMotionSequence.build(app.Scene, ...
                struct(LayerIndices=1:count));
            for index = 1:count
                item = app.Scene.layers(index);
                layer(index) = sprintf("%d: %s", index, item.Name);
                viewId(index) = string(item.ViewId);
                passId(index) = string(item.PassId);
                if sequence.Available
                    time(index) = sequence.Frames(index).TimeText;
                else
                    time(index) = "time unavailable";
                end
            end
            data = table(include, layer, viewId, passId, time, ...
                VariableNames=["Include" "Layer" "ViewId" "Pass" "Time"]);
        end

        function motionConfigurationChanged(app)
            sequence = app.configuredMotionSequence();
            if isempty(app.MotionStartExitButton) || ...
                    ~isvalid(app.MotionStartExitButton)
                return
            end
            app.MotionStartExitButton.Enable = app.onOff( ...
                sequence.Available || app.MotionRuntime.Active);
            app.MotionPlayPauseButton.Enable = app.onOff( ...
                app.MotionRuntime.Active);
            if app.MotionRuntime.Active
                app.MotionStatusLabel.Text = char(app.motionStatusText());
            elseif sequence.Available
                app.MotionStatusLabel.Text = char( ...
                    app.sequenceConfigurationStatus(sequence));
            else
                app.MotionStatusLabel.Text = char(sequence.Explanation);
            end
        end

        function sequence = configuredMotionSequence(app)
            options = struct();
            if isempty(app.MotionTable) || ~isvalid(app.MotionTable)
                options.IncludedViewIds = ProjectionViewMetadata.ids(app.Scene);
            else
                data = app.MotionTable.Data;
                options.IncludedViewIds = string(data.ViewId(logical(data.Include)));
            end
            if ~isempty(app.MotionPassDropDown) && ...
                    isvalid(app.MotionPassDropDown) && ...
                    string(app.MotionPassDropDown.Value) ~= "__all__"
                options.PassIds = string(app.MotionPassDropDown.Value);
            end
            sequence = ProjectionMotionSequence.build(app.Scene, options);
        end

        function text = sequenceConfigurationStatus(~, sequence)
            text = sprintf("%d frames. %s", numel(sequence.Frames), ...
                sequence.OrderingExplanation);
        end

        function toggleMotionImagery(app)
            if app.MotionRuntime.Active
                app.exitMotionImagery();
            else
                app.enterMotionImagery();
            end
        end

        function enterMotionImagery(app)
            sequence = app.configuredMotionSequence();
            if ~sequence.Available
                app.motionConfigurationChanged();
                return
            end
            runtime = app.MotionRuntime;
            runtime.Active = true;
            runtime.Sequence = sequence;
            runtime.Position = 1;
            runtime.Loop = app.MotionLoopCheckBox.Value;
            runtime.HoverEdges = app.MotionHoverCheckBox.Value;
            runtime.IdentityPinned = app.MotionPinCheckBox.Value;
            newRate = ProjectionMotionPlayback.rate( ...
                app.MotionRateSpinner.Value);
            if runtime.Playing && runtime.RateFps ~= newRate
                runtime.NextPlaybackTickElapsed = ...
                    toc(runtime.PlaybackClock) + ...
                    ProjectionMotionPlayback.delay(newRate);
            end
            runtime.RateFps = newRate;
            runtime.Warning = strjoin(sequence.Warnings, " ");
            runtime.PauseReason = "";
            runtime.SceneSignature = app.motionSceneSignature();
            runtime.Snapshot = struct( ...
                SelectedLayerIndex=app.SelectedLayerIndex, ...
                Camera=app.exportCameraState(), ...
                KeyboardMode=app.ViewportKeyboardMode, ...
                PairViewpointRuntime=app.PairViewpointRuntime, ...
                AnaglyphStereoExaggeration=app.AnaglyphStereoExaggeration, ...
                AnaglyphScreenDepthOffsetMeters= ...
                app.AnaglyphScreenDepthOffsetMeters);
            app.MotionRuntime = runtime;
            app.ViewportKeyboardMode = "motion";
            app.UIFigure.CurrentObject = app.Axes;
            app.MotionStartExitButton.Text = "Exit";
            app.MotionPlayPauseButton.Enable = "on";
            app.MotionPlayPauseButton.Text = "Play";
            app.createMotionPlaybackTimer();
            app.createMotionViewportControls();
            app.applyMotionFrame();
            app.refreshPointerMotionCallback();
        end

        function exitMotionImagery(app)
            if ~app.MotionRuntime.Active
                return
            end
            app.pauseMotionPlayback("Motion imagery exited.");
            snapshot = app.MotionRuntime.Snapshot;
            app.stopMotionIdentityTimer();
            app.deleteMotionPlaybackTimer();
            app.deleteMotionViewportControls();
            app.MotionRuntime = app.defaultMotionRuntime();
            app.SelectedLayerIndex = snapshot.SelectedLayerIndex;
            app.ViewportKeyboardMode = snapshot.KeyboardMode;
            app.PairViewpointRuntime = snapshot.PairViewpointRuntime;
            app.AnaglyphStereoExaggeration = ...
                snapshot.AnaglyphStereoExaggeration;
            app.AnaglyphScreenDepthOffsetMeters = ...
                snapshot.AnaglyphScreenDepthOffsetMeters;
            viewerAvailable = ~isempty(app.UIFigure) && ...
                isvalid(app.UIFigure) && ~isempty(app.Axes) && ...
                isvalid(app.Axes);
            if viewerAvailable
                app.applyCameraState(snapshot.Camera);
                app.updateAllSurfaceBlendAppearance();
                app.updateControlsFromSelectedLayer();
            end
            if ~isempty(app.MotionStartExitButton) && ...
                    isvalid(app.MotionStartExitButton)
                app.MotionStartExitButton.Text = "Start";
                app.MotionPlayPauseButton.Text = "Play";
                app.MotionPlayPauseButton.Enable = "off";
                app.motionConfigurationChanged();
            end
            app.refreshPointerMotionCallback();
        end

        function closeMotionImagery(app)
            app.exitMotionImagery();
            if ~isempty(app.MotionFigure) && isvalid(app.MotionFigure)
                app.MotionFigure.CloseRequestFcn = [];
                delete(app.MotionFigure);
            end
            app.MotionFigure = [];
        end

        function motionControlChanged(app)
            runtime = app.MotionRuntime;
            runtime.Loop = app.MotionLoopCheckBox.Value;
            runtime.HoverEdges = app.MotionHoverCheckBox.Value;
            runtime.IdentityPinned = app.MotionPinCheckBox.Value;
            runtime.RateFps = ProjectionMotionPlayback.rate( ...
                app.MotionRateSpinner.Value);
            app.MotionRuntime = runtime;
            if runtime.Active
                app.showMotionIdentity();
                app.updateMotionEdgeControls();
                app.updateMotionNavigationControls();
                app.refreshPointerMotionCallback();
                if runtime.Playing
                    if app.prepareMotionLookahead()
                        app.scheduleMotionPlaybackTick();
                    end
                end
            end
        end

        function changed = stepMotion(app, delta, isPlaybackStep)
            if nargin < 3
                isPlaybackStep = false;
            end
            changed = false;
            if ~app.MotionRuntime.Active
                return
            end
            if app.MotionRuntime.Playing && ~isPlaybackStep
                app.pauseMotionPlayback("Paused for manual step.");
            end
            runtime = app.MotionRuntime;
            [position, changed, boundary] = ProjectionMotionSequence.step( ...
                runtime.Sequence, runtime.Position, delta, runtime.Loop);
            runtime.Position = position;
            app.MotionRuntime = runtime;
            if changed
                app.PerformanceMonitor.increment("MotionFrameSwitches");
                changed = app.applyMotionFrame();
            elseif boundary
                app.refreshMotionStatus();
            end
        end

        function success = applyMotionFrame(app)
            success = false;
            layerIndex = app.currentMotionLayerIndex();
            if layerIndex == 0
                if app.MotionRuntime.Playing
                    app.pauseMotionPlayback( ...
                        "Paused because the sequence contains a stale view.");
                end
                app.refreshMotionStatus();
                return
            end
            app.SelectedLayerIndex = layerIndex;
            try
                if app.usesTiledPreview(layerIndex) && ...
                        isempty(app.validLayerSurfaces(layerIndex))
                    app.refreshTiledLayerSurfaces(layerIndex);
                end
                app.updateAllSurfaceBlendAppearance();
            catch exception
                runtime = app.MotionRuntime;
                runtime.Warning = "Motion frame load failed: " + ...
                    string(exception.message);
                app.MotionRuntime = runtime;
                if runtime.Playing
                    app.pauseMotionPlayback( ...
                        "Paused because a frame could not be loaded.");
                end
                app.refreshMotionStatus();
                return
            end
            app.updateControlsFromSelectedLayer();
            app.showMotionIdentity();
            app.updateMotionNavigationControls();
            app.updateMotionEdgeControls();
            app.refreshMotionStatus();
            success = true;
        end

        function toggleMotionPlayback(app)
            if app.MotionRuntime.Playing
                app.pauseMotionPlayback("Playback paused by operator.");
            else
                app.startMotionPlayback();
            end
        end

        function startMotionPlayback(app)
            if ~app.MotionRuntime.Active
                return
            end
            [available, reason] = app.motionPlaybackStateIsValid();
            if ~available
                app.pauseMotionPlayback(reason);
                return
            end
            runtime = app.MotionRuntime;
            runtime.Playing = true;
            runtime.PauseReason = "";
            runtime.PlaybackClock = tic;
            runtime.LastPlaybackTickElapsed = 0;
            runtime.RateFps = ProjectionMotionPlayback.rate( ...
                app.MotionRateSpinner.Value);
            runtime.NextPlaybackTickElapsed = ...
                ProjectionMotionPlayback.delay(runtime.RateFps);
            app.MotionRuntime = runtime;
            app.MotionPlayPauseButton.Text = "Pause";
            if ~app.prepareMotionLookahead()
                if app.MotionRuntime.Playing
                    app.pauseMotionPlayback( ...
                        "Playback reached the end of the sequence.");
                end
                return
            end
            app.scheduleMotionPlaybackTick();
            app.refreshMotionStatus();
        end

        function pauseMotionPlayback(app, reason)
            runtime = app.MotionRuntime;
            wasPlaying = runtime.Playing;
            runtime.Playing = false;
            runtime.PauseReason = string(reason);
            runtime.Lookahead = struct();
            app.MotionRuntime = runtime;
            if ~isempty(app.MotionPlaybackTimer) && ...
                    isvalid(app.MotionPlaybackTimer) && ...
                    string(app.MotionPlaybackTimer.Running) == "on"
                stop(app.MotionPlaybackTimer);
            end
            if wasPlaying
                app.PerformanceMonitor.increment("MotionPlaybackPauses");
            end
            if ~isempty(app.MotionPlayPauseButton) && ...
                    isvalid(app.MotionPlayPauseButton)
                app.MotionPlayPauseButton.Text = "Play";
            end
            app.refreshMotionStatus();
        end

        function createMotionPlaybackTimer(app)
            app.deleteMotionPlaybackTimer();
            app.MotionPlaybackTimer = timer( ...
                ExecutionMode="singleShot", BusyMode="queue", ...
                StartDelay=ProjectionMotionPlayback.delay( ...
                app.MotionRuntime.RateFps), ...
                TimerFcn=@(~, ~) ...
                ProjectionViewerApp.dispatchMotionPlaybackTick(app), ...
                ErrorFcn=@(~, event) ...
                ProjectionViewerApp.dispatchMotionPlaybackError(app, event), ...
                Name="Sightline motion playback", ...
                Tag="ProjectionViewerMotionPlaybackTimer");
        end

        function deleteMotionPlaybackTimer(app)
            if ~isempty(app.MotionPlaybackTimer) && ...
                    isvalid(app.MotionPlaybackTimer)
                stop(app.MotionPlaybackTimer);
                delete(app.MotionPlaybackTimer);
            end
            app.MotionPlaybackTimer = [];
        end

        function scheduleMotionPlaybackTick(app)
            if ~app.MotionRuntime.Active || ~app.MotionRuntime.Playing || ...
                    isempty(app.MotionPlaybackTimer) || ...
                    ~isvalid(app.MotionPlaybackTimer)
                return
            end
            if string(app.MotionPlaybackTimer.Running) == "on"
                stop(app.MotionPlaybackTimer);
            end
            remainingSeconds = app.MotionRuntime.NextPlaybackTickElapsed - ...
                toc(app.MotionRuntime.PlaybackClock);
            app.MotionPlaybackTimer.StartDelay = max(0.001, ...
                round(1000 * remainingSeconds) / 1000);
            start(app.MotionPlaybackTimer);
            app.PerformanceMonitor.increment("MotionPlaybackSchedules");
        end

        function motionPlaybackTick(app)
            if ~app.MotionRuntime.Active || ~app.MotionRuntime.Playing
                return
            end
            app.PerformanceMonitor.increment("MotionPlaybackTicks");
            runtime = app.MotionRuntime;
            elapsed = toc(runtime.PlaybackClock);
            app.PerformanceMonitor.recordTiming( ...
                "MotionPlaybackCadenceSeconds", ...
                elapsed - runtime.LastPlaybackTickElapsed);
            runtime.LastPlaybackTickElapsed = elapsed;
            app.MotionRuntime = runtime;
            [available, reason] = app.motionPlaybackStateIsValid();
            if ~available
                app.pauseMotionPlayback(reason);
                return
            end
            lookahead = app.MotionRuntime.Lookahead;
            if ~isstruct(lookahead) || ...
                    ~isfield(lookahead, "Available") || ...
                    ~lookahead.Available || ~lookahead.Ready
                if ~app.prepareMotionLookahead()
                    if app.MotionRuntime.Playing
                        app.pauseMotionPlayback( ...
                            "Playback reached the end of the sequence.");
                    end
                    return
                end
            end
            frameTimer = tic;
            changed = app.stepMotion(1, true);
            app.PerformanceMonitor.recordTiming( ...
                "MotionFrameSwitchSeconds", toc(frameTimer));
            if ~changed || ~app.MotionRuntime.Playing
                return
            end
            runtime = app.MotionRuntime;
            runtime.PlaybackFrameCount = runtime.PlaybackFrameCount + 1;
            nextTarget = runtime.NextPlaybackTickElapsed + ...
                ProjectionMotionPlayback.delay(runtime.RateFps);
            runtime.NextPlaybackTickElapsed = max(nextTarget, ...
                toc(runtime.PlaybackClock) + 0.001);
            app.MotionRuntime = runtime;
            if app.prepareMotionLookahead()
                app.scheduleMotionPlaybackTick();
            elseif app.MotionRuntime.Playing
                app.pauseMotionPlayback( ...
                    "Playback reached the end of the sequence.");
            end
        end

        function ready = prepareMotionLookahead(app)
            ready = false;
            if ~app.MotionRuntime.Active || ~app.MotionRuntime.Playing
                return
            end
            runtime = app.MotionRuntime;
            lookahead = ProjectionMotionPlayback.next( ...
                runtime.Sequence, runtime.Position, runtime.Loop);
            runtime.Lookahead = lookahead;
            app.MotionRuntime = runtime;
            if ~lookahead.Available
                return
            end
            app.PerformanceMonitor.increment("MotionLookaheadPreparations");
            try
                layerIndex = ProjectionViewMetadata.indexForId( ...
                    app.Scene, lookahead.ViewId);
                if ~app.motionFrameDataIsAvailable(layerIndex)
                    app.pauseMotionPlayback( ...
                        "Playback paused because the next frame is missing data.");
                    return
                end
                if app.usesTiledPreview(layerIndex) && ...
                        isempty(app.validLayerSurfaces(layerIndex))
                    app.refreshTiledLayerSurfaces(layerIndex);
                end
            catch exception
                app.pauseMotionPlayback( ...
                    "Playback paused because lookahead loading failed: " + ...
                    string(exception.message));
                return
            end
            runtime = app.MotionRuntime;
            lookahead.LayerIndex = layerIndex;
            lookahead.Ready = true;
            runtime.Lookahead = lookahead;
            app.MotionRuntime = runtime;
            app.PerformanceMonitor.increment("MotionLookaheadReady");
            ready = true;
            app.refreshMotionStatus();
        end

        function [valid, reason] = motionPlaybackStateIsValid(app)
            valid = false;
            reason = "";
            if ~app.MotionRuntime.Active
                reason = "Playback requires active motion imagery.";
                return
            end
            if ~app.viewportHasInteractionFocus()
                reason = "Playback paused because viewport focus was lost.";
                return
            end
            if ~isequaln(app.MotionRuntime.SceneSignature, ...
                    app.motionSceneSignature())
                reason = ...
                    "Playback paused because the sequence or a layer changed.";
                return
            end
            layerIndex = app.currentMotionLayerIndex();
            if layerIndex == 0
                reason = "Playback paused because the current frame is stale.";
                return
            end
            if ~app.motionFrameDataIsAvailable(layerIndex)
                reason = ...
                    "Playback paused because the current frame is missing data.";
                return
            end
            valid = true;
        end

        function signature = motionSceneSignature(app)
            state = app.exportState();
            signature = struct( ...
                ViewIds=ProjectionViewMetadata.ids(app.Scene), ...
                PassIds=string({app.Scene.layers.PassId}), ...
                Projection=state.Projection, Layers=state.Layers);
        end

        function available = motionFrameDataIsAvailable(app, layerIndex)
            layer = app.Scene.layers(layerIndex);
            available = isfield(layer, "DisplayTexture") && ...
                ~isempty(layer.DisplayTexture) && ...
                isfield(layer, "SourceGeometry") && ...
                isstruct(layer.SourceGeometry) && ...
                isfield(layer.SourceGeometry, "SampleFcn") && ...
                isa(layer.SourceGeometry.SampleFcn, "function_handle");
        end

        function motionPlaybackTimerFailed(app, event)
            message = "unknown timer error";
            if isobject(event) && isprop(event, "Data") && ...
                    isa(event.Data, "MException")
                message = string(event.Data.message);
            end
            app.pauseMotionPlayback( ...
                "Playback paused because its timer failed: " + message);
        end

        function layerIndex = currentMotionLayerIndex(app)
            layerIndex = 0;
            runtime = app.MotionRuntime;
            if ~runtime.Active || runtime.Position < 1 || ...
                    runtime.Position > numel(runtime.Sequence.Frames)
                return
            end
            viewId = runtime.Sequence.Frames(runtime.Position).ViewId;
            try
                layerIndex = ProjectionViewMetadata.indexForId(app.Scene, viewId);
            catch exception
                runtime.Warning = "Motion frame is stale: " + ...
                    string(exception.message);
                app.MotionRuntime = runtime;
            end
        end

        function createMotionViewportControls(app)
            app.MotionLeftEdgeButton = uibutton(app.UIFigure, Text="<", ...
                Visible="off", ButtonPushedFcn=@(~, ~) app.stepMotion(-1), ...
                Tag="ProjectionViewerMotionLeftEdgeButton");
            app.MotionRightEdgeButton = uibutton(app.UIFigure, Text=">", ...
                Visible="off", ButtonPushedFcn=@(~, ~) app.stepMotion(1), ...
                Tag="ProjectionViewerMotionRightEdgeButton");
            app.MotionIdentityLabel = uilabel(app.UIFigure, Text="", ...
                HorizontalAlignment="center", BackgroundColor=[0.05 0.05 0.05], ...
                FontColor=[1 1 1], Visible="off", ...
                Tag="ProjectionViewerMotionIdentityLabel");
            app.MotionIdentityTimer = timer(ExecutionMode="singleShot", ...
                StartDelay=app.MotionIdentitySeconds, ...
                TimerFcn=@(~, ~) app.hideMotionIdentity());
            app.positionMotionViewportControls();
        end

        function positionMotionViewportControls(app)
            if isempty(app.MotionLeftEdgeButton) || ...
                    ~isvalid(app.MotionLeftEdgeButton)
                return
            end
            axesPosition = getpixelposition(app.Axes, true);
            buttonSize = [42 70];
            vertical = axesPosition(2) + (axesPosition(4) - buttonSize(2)) / 2;
            app.MotionLeftEdgeButton.Position = ...
                [axesPosition(1) + 8 vertical buttonSize];
            app.MotionRightEdgeButton.Position = ...
                [axesPosition(1) + axesPosition(3) - buttonSize(1) - 8, ...
                vertical, buttonSize];
            app.MotionIdentityLabel.Position = ...
                [axesPosition(1) + axesPosition(3) * 0.15, ...
                axesPosition(2) + axesPosition(4) - 40, ...
                axesPosition(3) * 0.70, 28];
        end

        function updateMotionEdgeControls(app)
            if ~app.MotionRuntime.Active || ...
                    isempty(app.MotionLeftEdgeButton) || ...
                    ~isvalid(app.MotionLeftEdgeButton)
                return
            end
            timerValue = tic;
            app.positionMotionViewportControls();
            runtime = app.MotionRuntime;
            leftVisible = ~runtime.HoverEdges;
            rightVisible = ~runtime.HoverEdges;
            if runtime.HoverEdges
                pointer = app.UIFigure.CurrentPoint;
                axesPosition = getpixelposition(app.Axes, true);
                insideY = pointer(2) >= axesPosition(2) && ...
                    pointer(2) <= axesPosition(2) + axesPosition(4);
                leftVisible = insideY && pointer(1) >= axesPosition(1) && ...
                    pointer(1) <= axesPosition(1) + app.MotionEdgeWidthPixels;
                rightVisible = insideY && ...
                    pointer(1) <= axesPosition(1) + axesPosition(3) && ...
                    pointer(1) >= axesPosition(1) + axesPosition(3) - ...
                    app.MotionEdgeWidthPixels;
            end
            app.setMotionEdgeVisibility(leftVisible, rightVisible);
            app.PerformanceMonitor.recordTiming( ...
                "MotionHoverSeconds", toc(timerValue));
        end

        function setMotionEdgeVisibility(app, leftVisible, rightVisible)
            prior = [string(app.MotionLeftEdgeButton.Visible), ...
                string(app.MotionRightEdgeButton.Visible)];
            next = [app.onOff(leftVisible), app.onOff(rightVisible)];
            if any(prior ~= next)
                app.PerformanceMonitor.increment("MotionHoverStateChanges");
                app.MotionLeftEdgeButton.Visible = next(1);
                app.MotionRightEdgeButton.Visible = next(2);
            end
        end

        function updateMotionNavigationControls(app)
            runtime = app.MotionRuntime;
            count = numel(runtime.Sequence.Frames);
            previousEnabled = runtime.Loop || runtime.Position > 1;
            nextEnabled = runtime.Loop || runtime.Position < count;
            app.MotionPreviousButton.Enable = app.onOff(previousEnabled);
            app.MotionNextButton.Enable = app.onOff(nextEnabled);
            app.MotionLeftEdgeButton.Enable = app.onOff(previousEnabled);
            app.MotionRightEdgeButton.Enable = app.onOff(nextEnabled);
        end

        function showMotionIdentity(app)
            if ~app.MotionRuntime.Active || ...
                    isempty(app.MotionIdentityLabel) || ...
                    ~isvalid(app.MotionIdentityLabel)
                return
            end
            frame = app.MotionRuntime.Sequence.Frames( ...
                app.MotionRuntime.Position);
            app.MotionIdentityLabel.Text = char(sprintf( ...
                "%d/%d  %s | %s | %s | %s", frame.Position, ...
                frame.Count, frame.LayerName, frame.PassId, frame.TimeText, ...
                frame.CorrectionStatus));
            app.MotionIdentityLabel.Visible = "on";
            app.stopMotionIdentityTimer();
            if ~app.MotionRuntime.IdentityPinned && ...
                    ~isempty(app.MotionIdentityTimer) && ...
                    isvalid(app.MotionIdentityTimer)
                start(app.MotionIdentityTimer);
            end
        end

        function hideMotionIdentity(app)
            if app.MotionRuntime.Active && ...
                    ~app.MotionRuntime.IdentityPinned && ...
                    ~isempty(app.MotionIdentityLabel) && ...
                    isvalid(app.MotionIdentityLabel)
                app.MotionIdentityLabel.Visible = "off";
            end
        end

        function stopMotionIdentityTimer(app)
            if ~isempty(app.MotionIdentityTimer) && ...
                    isvalid(app.MotionIdentityTimer)
                stop(app.MotionIdentityTimer);
            end
        end

        function deleteMotionViewportControls(app)
            app.stopMotionIdentityTimer();
            objects = {app.MotionIdentityTimer, app.MotionLeftEdgeButton, ...
                app.MotionRightEdgeButton, app.MotionIdentityLabel};
            for index = 1:numel(objects)
                object = objects{index};
                if ~isempty(object) && isvalid(object)
                    delete(object);
                end
            end
            app.MotionIdentityTimer = [];
            app.MotionLeftEdgeButton = [];
            app.MotionRightEdgeButton = [];
            app.MotionIdentityLabel = [];
        end

        function refreshMotionStatus(app)
            if isempty(app.MotionStatusLabel) || ~isvalid(app.MotionStatusLabel)
                return
            end
            app.MotionStatusLabel.Text = char(app.motionStatusText());
        end

        function text = motionStatusText(app)
            runtime = app.MotionRuntime;
            if ~runtime.Active
                text = "Motion imagery is not active.";
                return
            end
            frame = runtime.Sequence.Frames(runtime.Position);
            text = string(sprintf("Frame %d of %d: %s (%s).", ...
                runtime.Position, numel(runtime.Sequence.Frames), ...
                frame.LayerName, frame.ViewId));
            if runtime.Playing
                text = text + sprintf(" Playing at %.1f fps.", runtime.RateFps);
            elseif strlength(runtime.PauseReason) > 0
                text = text + " " + runtime.PauseReason;
            else
                text = text + sprintf(" Ready at %.1f fps.", runtime.RateFps);
            end
            if strlength(runtime.Warning) > 0
                text = text + " Warning: " + runtime.Warning;
            end
        end

        function runtime = defaultMotionRuntime(~)
            runtime = struct(Active=false, Sequence=struct(), Position=0, ...
                Loop=false, HoverEdges=true, IdentityPinned=false, ...
                Playing=false, RateFps=ProjectionMotionPlayback.DefaultRateFps, ...
                PauseReason="", Lookahead=struct(), ...
                SceneSignature=struct(), PlaybackFrameCount=0, ...
                PlaybackClock=[], LastPlaybackTickElapsed=0, ...
                NextPlaybackTickElapsed=0, ...
                Warning="", Snapshot=struct());
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
            layerState.LayerId = string(layer.LayerId);
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

                mesh = app.buildInstrumentedLayerMesh( ...
                    layerIndex, layer, layer.CurrentProjectionPlane);
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

        function initializePreviewPyramids(app, options)
            if nargin < 2
                options = ProjectionPreviewPyramid.defaultOptions();
            else
                options = ProjectionPreviewPyramid.defaultOptions(options);
            end
            app.PreviewTilingOptions = options;
            layerCount = numel(app.Scene.layers);
            app.PreviewPyramids = cell(1, layerCount);
            app.PreviewGeometryCaches = cell(1, layerCount);
            app.PreviewGeometryGenerations = ones(1, layerCount);
            app.PreviewTiledLayerMask = false(1, layerCount);
            app.PreviewTiles = cell(1, layerCount);
            app.PreviewTileKeys = cell(1, layerCount);
            app.PreviewCurrentLevelIndices = ones(1, layerCount);
            app.PreviewDesiredLevelIndices = ones(1, layerCount);
            app.PreviewDesiredDownsamples = ones(1, layerCount);
            app.PreviewDesiredDownsamplesPerAxis = ones(layerCount, 2);
            app.PreviewPendingLevelIndices = zeros(1, layerCount);
            app.PreviewPredictedCandidateCounts = zeros(1, layerCount);
            app.PreviewPredictedVisibleTileCounts = zeros(1, layerCount);
            app.PreviewPredictedTextureBytes = zeros(1, layerCount);
            app.PreviewLayerSurfaceBudgets = zeros(1, layerCount);
            app.PreviewLayerTextureBudgets = zeros(1, layerCount);
            app.PreviewBudgetLimitedLayerMask = false(1, layerCount);
            app.RenderedLayerAlphas = [app.Scene.layers.Alpha];
            app.PendingAlphaMask = false(1, layerCount);
            app.AlphaPreviewTimer = [];
            app.clearPreviewTileRuntimeCache();
            app.clearPreviewSampledGeometryCache();
            for layerIndex = 1:layerCount
                layerOptions = app.PreviewTilingOptions;
                layerOptions.SourcePath = ...
                    app.Scene.layers(layerIndex).ImagePath;
                pyramid = ProjectionPreviewPyramid.build( ...
                    app.Scene.layers(layerIndex).Image, ...
                    layerOptions);
                app.PreviewPyramids{layerIndex} = pyramid;
                app.PreviewTiledLayerMask(layerIndex) = ...
                    ProjectionPreviewPyramid.shouldUseTiling( ...
                    pyramid, app.PreviewTilingOptions);
                if app.PreviewTiledLayerMask(layerIndex)
                    app.PreviewCurrentLevelIndices(layerIndex) = 0;
                    app.PreviewDesiredLevelIndices(layerIndex) = 0;
                    app.PreviewDesiredDownsamples(layerIndex) = NaN;
                    app.PreviewDesiredDownsamplesPerAxis(layerIndex, :) = NaN;
                end
            end
        end

        function initializeCameraSettleTimer(app)
            app.CameraSettleTimer = timer( ...
                ExecutionMode="singleShot", ...
                BusyMode="drop", ...
                StartDelay=app.CameraSettleDelaySeconds, ...
                TimerFcn=@(source, ~) app.cameraSettleTimerFired(source), ...
                Name="ProjectionViewerCameraSettleTimer");
        end

        function deleteCameraSettleTimer(app)
            app.IsCameraReconciliationPending = false;
            if isempty(app.CameraSettleTimer) || ...
                    ~isvalid(app.CameraSettleTimer)
                return
            end
            if string(app.CameraSettleTimer.Running) == "on"
                stop(app.CameraSettleTimer);
            end
            delete(app.CameraSettleTimer);
            app.CameraSettleTimer = [];
        end

        function scheduleCameraReconciliation(app)
            if ~any(app.PreviewTiledLayerMask)
                return
            end
            app.PerformanceMonitor.increment("CameraScheduleRequests");
            if app.IsCameraReconciliationPending
                app.PerformanceMonitor.increment("CoalescedRequests");
            end
            app.CameraScheduleGeneration = app.CameraScheduleGeneration + 1;
            app.IsCameraReconciliationPending = true;
            if string(app.CameraSettleTimer.Running) == "on"
                stop(app.CameraSettleTimer);
            end
            app.CameraSettleTimer.StartDelay = app.CameraSettleDelaySeconds;
            app.CameraSettleTimer.UserData = app.CameraScheduleGeneration;
            start(app.CameraSettleTimer);
        end

        function suspendCameraReconciliationTimer(app)
            if ~app.IsCameraReconciliationPending
                return
            end
            if string(app.CameraSettleTimer.Running) == "on"
                stop(app.CameraSettleTimer);
            end
            app.CameraScheduleGeneration = app.CameraScheduleGeneration + 1;
        end

        function cameraSettleTimerFired(app, timerObject)
            app.reconcileCameraPreview(uint64(timerObject.UserData));
        end

        function flushCameraReconciliation(app)
            if ~app.IsCameraReconciliationPending
                return
            end
            if string(app.CameraSettleTimer.Running) == "on"
                stop(app.CameraSettleTimer);
            end
            app.reconcileCameraPreview(app.CameraScheduleGeneration);
        end

        function cancelCameraReconciliation(app)
            if ~app.IsCameraReconciliationPending
                return
            end
            if string(app.CameraSettleTimer.Running) == "on"
                stop(app.CameraSettleTimer);
            end
            app.IsCameraReconciliationPending = false;
            app.CameraScheduleGeneration = app.CameraScheduleGeneration + 1;
            app.PerformanceMonitor.increment("DroppedRequests");
        end

        function reconcileCameraPreview(app, generation)
            if generation ~= app.CameraScheduleGeneration
                app.PerformanceMonitor.increment("DroppedRequests");
                return
            end
            app.IsCameraReconciliationPending = false;
            frameTimer = app.beginPerformanceFrame();
            app.PerformanceMonitor.increment("CameraReconciliations");
            app.refreshTiledProjectionSurfaces();
            drawnow limitrate
            app.finishPerformanceFrame(frameTimer, "CameraSettleSeconds");
        end

        function tf = usesTiledPreview(app, layerIndex)
            tf = ~isempty(app.PreviewTiledLayerMask) && ...
                layerIndex <= numel(app.PreviewTiledLayerMask) && ...
                app.PreviewTiledLayerMask(layerIndex);
        end

        function surfaceHandle = createPreviewSurface(app, layerIndex, ...
                mesh, texture, tag)
            surfaceTimer = tic;
            [X, Y, Z] = app.previewSurfaceCoordinates(mesh, layerIndex);
            displayTexture = app.previewTextureForLayer(texture, layerIndex);
            surfaceHandle = surface(app.Axes, X, Y, Z, ...
                displayTexture, ...
                FaceColor="texturemap", EdgeColor="none", LineStyle="none", ...
                CDataMapping="scaled", ...
                FaceAlpha=app.previewFaceAlphaForLayer(mesh.Alpha, layerIndex), ...
                Visible=app.onOff(app.previewSurfaceIsVisible( ...
                mesh.Visible, mesh.Alpha)), ...
                ContextMenu=app.ImageContextMenu, Tag=tag);
            app.PerformanceMonitor.increment("SurfaceCreations");
            app.PerformanceMonitor.increment( ...
                "TextureUploadBytes", app.arrayBytes(displayTexture));
            app.PerformanceMonitor.recordTiming( ...
                "SurfaceCreateSeconds", toc(surfaceTimer));
        end

        function surfaceHandles = createTiledLayerSurfaces(app, layerIndex, tiles)
            if nargin < 3
                tiles = app.previewTilesForLayer(layerIndex);
            end
            surfaceHandles = gobjects(1, numel(tiles));
            tileKeys = app.previewTileKeys(tiles);
            for tileIndex = 1:numel(tiles)
                tileData = app.preparedPreviewTileData( ...
                    layerIndex, tiles(tileIndex), ...
                    app.PreviewTilingOptions.MaxTileMeshVertices);
                surfaceHandles(tileIndex) = app.acquirePreviewTileSurface( ...
                    layerIndex, tileData);
                surfaceHandles(tileIndex).UserData = tileKeys(tileIndex);
            end
            app.PreviewTiles{layerIndex} = tiles;
            app.PreviewTileKeys{layerIndex} = tileKeys;
            app.recordAppliedPreviewLevel(layerIndex, tiles);
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
                textureTimer = tic;
                [tileImage, pyramid, wasMaterialized] = ...
                    ProjectionPreviewPyramid.tileTexture(pyramid, tile);
                app.PreviewPyramids{layerIndex} = pyramid;
                if wasMaterialized
                    levelBytes = app.arrayBytes( ...
                        pyramid.Levels(tile.LevelIndex).Image);
                    app.PerformanceMonitor.increment( ...
                        "PyramidLevelMaterializations");
                    app.PerformanceMonitor.increment( ...
                        "PyramidMaterializedBytes", levelBytes);
                end
                tileLayer.DisplayTexture = app.preparePreviewDisplayTexture( ...
                    tileImage, layerIndex);
                app.PerformanceMonitor.increment("TexturePreparations");
                app.PerformanceMonitor.increment("PreparedTextureBytes", ...
                    app.arrayBytes(tileLayer.DisplayTexture));
                app.PerformanceMonitor.recordTiming( ...
                    "TexturePrepareSeconds", toc(textureTimer));
            end
            tileLayer.MeshSampling = ProjectionPreviewPyramid.tileMeshSampling( ...
                pyramid, tile, maxMeshVertices);
        end

        function tileData = preparedPreviewTileData(app, layerIndex, tile, ...
                maxMeshVertices)
            key = app.previewTileDataKey( ...
                layerIndex, tile, maxMeshVertices);
            [found, tileData] = app.PreviewTileDataCache.get(key);
            if found
                app.PerformanceMonitor.increment("TileCacheHits");
                return
            end

            app.PerformanceMonitor.increment("TileCacheMisses");
            tileLayer = app.tilePreviewLayer( ...
                layerIndex, tile, true, maxMeshVertices);
            mesh = app.buildInstrumentedLayerMesh( ...
                layerIndex, tileLayer, tileLayer.CurrentProjectionPlane);
            mesh.Texture = [];
            tileData = struct(Mesh=mesh, ...
                DisplayTexture=tileLayer.DisplayTexture);
            cacheBefore = app.PreviewTileDataCache.diagnostics();
            app.PreviewTileDataCache.put( ...
                key, tileData, app.previewTileDataBytes(tileData));
            cacheAfter = app.PreviewTileDataCache.diagnostics();
            app.PerformanceMonitor.increment("TileCacheEvictions", ...
                cacheAfter.EvictionCount - cacheBefore.EvictionCount);
        end

        function sampledGeometry = sampledLayerGeometry( ...
                app, layerIndex, layer)
            key = app.sampledGeometryCacheKey(layerIndex, layer);
            [found, sampledGeometry] = ...
                app.PreviewSampledGeometryCache.get(key);
            if found
                app.PerformanceMonitor.increment("SampleCacheHits");
                return
            end

            sampleTimer = tic;
            app.PerformanceMonitor.increment("SampleCacheMisses");
            app.PerformanceMonitor.increment("SampleFcnCalls");
            sampledGeometry = ...
                ProjectionMeshBuilder.sampleLayerGeometry(layer);
            cacheBefore = app.PreviewSampledGeometryCache.diagnostics();
            app.PreviewSampledGeometryCache.put( ...
                key, sampledGeometry, app.arrayBytes(sampledGeometry));
            cacheAfter = app.PreviewSampledGeometryCache.diagnostics();
            app.PerformanceMonitor.increment("SampleCacheEvictions", ...
                cacheAfter.EvictionCount - cacheBefore.EvictionCount);
            app.PerformanceMonitor.recordTiming( ...
                "SampleGeometrySeconds", toc(sampleTimer));
        end

        function key = sampledGeometryCacheKey(~, layerIndex, layer)
            rowIndices = double(layer.MeshSampling.RowIndices(:).');
            columnIndices = double(layer.MeshSampling.ColumnIndices(:).');
            imageSize = double(layer.SourceGeometry.ImageSize(:).');
            key = string(sprintf("Layer%d_Image%s_R%s_C%s", ...
                layerIndex, sprintf("%d_", imageSize), ...
                sprintf("%d_", rowIndices), ...
                sprintf("%d_", columnIndices)));
        end

        function key = previewTileDataKey(app, layerIndex, tile, maxMeshVertices)
            tileKey = ProjectionPreviewPyramid.tileKey(tile);
            key = string(sprintf("Layer%d_G%d_M%d_%s", layerIndex, ...
                app.PreviewGeometryGenerations(layerIndex), ...
                maxMeshVertices, tileKey));
        end

        function bytes = previewTileDataBytes(app, tileData)
            bytes = app.arrayBytes(tileData);
        end

        function keys = previewTileKeys(~, tiles)
            keys = strings(1, numel(tiles));
            for tileIndex = 1:numel(tiles)
                keys(tileIndex) = ProjectionPreviewPyramid.tileKey( ...
                    tiles(tileIndex));
            end
        end

        function tiles = previewTilesForLayer(app, layerIndex, cameraContext)
            pyramid = app.PreviewPyramids{layerIndex};
            budget = app.previewLayerBudget(layerIndex);
            if ~app.IsPreviewCameraReady
                coarsestLevelIndex = numel(pyramid.Levels);
                app.PreviewDesiredLevelIndices(layerIndex) = coarsestLevelIndex;
                app.PreviewDesiredDownsamples(layerIndex) = ...
                    pyramid.Levels(coarsestLevelIndex).Downsample;
                app.PreviewPendingLevelIndices(layerIndex) = coarsestLevelIndex;
                tiles = ProjectionPreviewPyramid.tileBounds( ...
                    pyramid, coarsestLevelIndex, ...
                    app.PreviewTilingOptions.TileSize);
                app.PerformanceMonitor.increment("TileCandidates", numel(tiles));
                return
            end
            if nargin < 3 || isempty(cameraContext)
                cameraContext = app.previewCameraContext();
            end

            startLevelIndex = app.previewLevelIndexForLayer( ...
                layerIndex, cameraContext);
            maxVisibleTiles = min( ...
                app.PreviewTilingOptions.MaxVisibleTilesPerLayer, ...
                budget.MaxSurfaces);
            if app.PreviewAutomaticTilePolicy
                maxVisibleTiles = min(maxVisibleTiles, ...
                    app.PreviewTargetMaxTilesPerLayer);
            end
            tiles = ProjectionPreviewPyramid.emptyTiles();
            geometry = app.previewGeometryCacheForLayer(layerIndex);
            app.PreviewBudgetLimitedLayerMask(layerIndex) = false;

            for levelIndex = startLevelIndex:numel(pyramid.Levels)
                app.PreviewPendingLevelIndices(layerIndex) = levelIndex;
                tiles = app.visiblePreviewTiles( ...
                    layerIndex, geometry, levelIndex, cameraContext);
                textureBytes = app.previewTilesTextureBytes( ...
                    layerIndex, tiles);
                if numel(tiles) <= maxVisibleTiles && ...
                        textureBytes <= budget.MaxTextureBytes
                    return
                end
                app.PreviewBudgetLimitedLayerMask(layerIndex) = true;
                app.PerformanceMonitor.increment( ...
                    "BudgetLimitedLodSelections");
            end

            if numel(tiles) > maxVisibleTiles || ...
                    app.previewTilesTextureBytes(layerIndex, tiles) > ...
                    budget.MaxTextureBytes
                app.PerformanceMonitor.increment("PreviewBudgetOverruns");
            end
        end

        function budget = previewLayerBudget(app, layerIndex)
            visibleMask = app.effectiveLayerVisibilityMask() & ...
                [app.Scene.layers.Alpha] > 0;
            visibleTiledMask = visibleMask & app.PreviewTiledLayerMask;
            tiledLayerCount = max(1, nnz(visibleTiledMask));
            untiledLayerCount = nnz(visibleMask & ~app.PreviewTiledLayerMask);
            availableSurfaces = max(1, ...
                app.PreviewMaxVisibleSurfaces - untiledLayerCount);
            surfaceShare = max(1, floor( ...
                availableSurfaces / tiledLayerCount));

            untiledTextureBytes = 0;
            untiledIndices = find(visibleMask & ~app.PreviewTiledLayerMask);
            for untiledIndex = reshape(untiledIndices, 1, [])
                untiledTextureBytes = untiledTextureBytes + ...
                    app.arrayBytes( ...
                    app.Scene.layers(untiledIndex).DisplayTexture);
            end
            availableTextureBytes = max(1, ...
                app.PreviewMaxVisibleTextureBytes - untiledTextureBytes);
            textureShare = max(1, floor( ...
                availableTextureBytes / tiledLayerCount));

            app.PreviewLayerSurfaceBudgets(layerIndex) = surfaceShare;
            app.PreviewLayerTextureBudgets(layerIndex) = textureShare;
            budget = struct(MaxSurfaces=surfaceShare, ...
                MaxTextureBytes=textureShare);
        end

        function bytes = previewTilesTextureBytes(app, layerIndex, tiles)
            if isempty(tiles)
                bytes = 0;
                return
            end
            texturePixels = sum(arrayfun( ...
                @(tile) prod(double(tile.TextureSize)), tiles));
            bytes = texturePixels * ...
                app.previewDisplayBytesPerPixel(layerIndex);
        end

        function bytes = previewDisplayBytesPerPixel(app, layerIndex)
            pyramid = app.PreviewPyramids{layerIndex};
            if app.usesScalarPreviewTexture(layerIndex)
                bytes = app.imageClassBytes("single");
            elseif pyramid.BandCount == 3
                bytes = 3 * app.imageClassBytes(pyramid.ImageClass);
            else
                bytes = 3 * app.imageClassBytes("single");
            end
        end

        function texture = preparePreviewDisplayTexture( ...
                app, imageData, layerIndex)
            if app.usesScalarPreviewTexture(layerIndex)
                texture = ...
                    ProjectionViewerHarness.prepareScalarDisplayTexture( ...
                    imageData);
                app.PerformanceMonitor.increment( ...
                    "ScalarTexturePreparations");
            else
                texture = ProjectionViewerHarness.prepareDisplayTexture( ...
                    imageData);
                app.PerformanceMonitor.increment( ...
                    "RgbFallbackTexturePreparations");
            end
        end

        function tf = usesScalarPreviewTexture(app, layerIndex)
            pyramid = app.PreviewPyramids{layerIndex};
            tf = app.PreviewTilingOptions.UseScalarSingleBandTextures && ...
                pyramid.BandCount == 1;
        end

        function levelIndex = previewLevelIndexForLayer( ...
                app, layerIndex, cameraContext)
            pyramid = app.PreviewPyramids{layerIndex};
            [desiredDownsample, desiredDownsamplesPerAxis] = ...
                app.previewDesiredDownsampleForLayer(layerIndex, cameraContext);
            app.PreviewDesiredDownsamples(layerIndex) = desiredDownsample;
            app.PreviewDesiredDownsamplesPerAxis(layerIndex, :) = ...
                desiredDownsamplesPerAxis;
            desiredLevelIndex = ProjectionPreviewPyramid.selectLevel( ...
                pyramid, desiredDownsample);
            app.PreviewDesiredLevelIndices(layerIndex) = desiredLevelIndex;
            currentLevelIndex = app.PreviewCurrentLevelIndices(layerIndex);
            if currentLevelIndex < 1
                levelIndex = desiredLevelIndex;
                return
            end

            [levelIndex, diagnostics] = ...
                ProjectionPreviewPyramid.selectLevelWithHysteresis( ...
                pyramid, desiredDownsample, currentLevelIndex, ...
                app.PreviewLodPromoteThreshold, ...
                app.PreviewLodDemoteThreshold);
            if diagnostics.WasSuppressed
                app.PerformanceMonitor.increment("SuppressedLodTransitions");
            end
        end

        function [desiredDownsample, perAxis] = ...
                previewDesiredDownsampleForLayer( ...
                app, layerIndex, cameraContext)
            geometry = app.previewGeometryCacheForLayer(layerIndex);
            [projectedWidthPixels, projectedHeightPixels] = ...
                ProjectionPreviewTileGeometry.projectedExtentPixels( ...
                geometry, cameraContext);
            imageSize = double(app.PreviewPyramids{layerIndex}.ImageSize);
            perAxis = [imageSize(2) / projectedWidthPixels, ...
                imageSize(1) / projectedHeightPixels];
            desiredDownsample = max(1, min(perAxis));
        end

        function tiles = visiblePreviewTiles(app, layerIndex, geometry, ...
                levelIndex, cameraContext)
            [visibleMask, diagnostics] = ...
                ProjectionPreviewTileGeometry.visibleMask( ...
                geometry, levelIndex, cameraContext);
            app.PerformanceMonitor.increment( ...
                "TileCandidates", diagnostics.CandidateCount);
            app.PerformanceMonitor.increment( ...
                "VectorizedTileTests", diagnostics.CandidateCount);
            app.PreviewPredictedCandidateCounts(layerIndex) = ...
                diagnostics.CandidateCount;
            app.PreviewPredictedVisibleTileCounts(layerIndex) = ...
                diagnostics.VisibleCount;
            app.PreviewPredictedTextureBytes(layerIndex) = ...
                diagnostics.VisibleTexturePixels * ...
                app.previewDisplayBytesPerPixel(layerIndex);
            tiles = geometry.Levels(levelIndex).Tiles(visibleMask);
        end

        function cameraContext = previewCameraContext(app)
            app.PerformanceMonitor.increment("CameraStateQueries");
            cameraPosition = campos(app.Axes).';
            cameraTarget = camtarget(app.Axes).';
            viewDirection = cameraTarget - cameraPosition;
            viewDistance = norm(viewDirection);
            viewDirection = viewDirection / viewDistance;
            upVector = camup(app.Axes).';
            upVector = upVector / norm(upVector);
            rightVector = cross(viewDirection, upVector);
            rightVector = rightVector / norm(rightVector);
            axesPosition = app.Axes.InnerPosition;
            viewHeight = 2 * viewDistance * tan( ...
                deg2rad(app.Axes.CameraViewAngle) / 2);
            viewWidth = viewHeight * max(axesPosition(3), 1) / ...
                max(axesPosition(4), 1);

            cameraContext = struct();
            cameraContext.RightVector = rightVector;
            cameraContext.UpVector = upVector;
            cameraContext.Center = cameraTarget;
            cameraContext.ViewWidth = viewWidth;
            cameraContext.ViewHeight = viewHeight;
            cameraContext.ViewportWidthPixels = max(axesPosition(3), 1);
            cameraContext.ViewportHeightPixels = max(axesPosition(4), 1);
            cameraContext.HaloFraction = app.PreviewViewportHaloFraction;
        end

        function geometry = previewGeometryCacheForLayer(app, layerIndex)
            key = app.previewGeometryCacheKey(layerIndex);
            entry = app.PreviewGeometryCaches{layerIndex};
            hasEntry = isstruct(entry) && isscalar(entry) && ...
                isfield(entry, "Key");
            if hasEntry && isequaln(entry.Key, key)
                app.PerformanceMonitor.increment("GeometryCacheHits");
                geometry = entry.Geometry;
                return
            end

            app.PerformanceMonitor.increment("GeometryCacheMisses");
            if hasEntry
                app.PreviewGeometryGenerations(layerIndex) = ...
                    app.PreviewGeometryGenerations(layerIndex) + 1;
            end
            layer = app.Scene.layers(layerIndex);
            plane = layer.CurrentProjectionPlane;
            meshBuilderFcn = @(sampledLayer, sampledPlane, ~) ...
                app.buildInstrumentedLayerMesh( ...
                layerIndex, sampledLayer, sampledPlane);
            geometry = ProjectionPreviewTileGeometry.build( ...
                layer, app.PreviewPyramids{layerIndex}, plane, ...
                app.Scene.renderOrigin, app.PreviewTilingOptions.TileSize, ...
                meshBuilderFcn);
            app.PreviewGeometryCaches{layerIndex} = ...
                struct(Key=key, Geometry=geometry);
        end

        function invalidatePreviewGeometry(app, layerIndices)
            for layerIndex = reshape(layerIndices, 1, [])
                app.PreviewGeometryCaches{layerIndex} = [];
                app.PreviewGeometryGenerations(layerIndex) = ...
                    app.PreviewGeometryGenerations(layerIndex) + 1;
            end
        end

        function key = previewGeometryCacheKey(app, layerIndex)
            layer = app.Scene.layers(layerIndex);
            plane = layer.CurrentProjectionPlane;
            sourceGeometry = layer.SourceGeometry;
            key = struct();
            key.LayerName = string(layer.Name);
            key.ImagePath = string(layer.ImagePath);
            key.ImageSize = double(app.PreviewPyramids{layerIndex}.ImageSize);
            key.ImageClass = app.PreviewPyramids{layerIndex}.ImageClass;
            key.SourceImageSize = double(sourceGeometry.ImageSize);
            key.SourceSampleFcn = sourceGeometry.SampleFcn;
            key.Plane = [plane.P0(:); plane.basis(:); plane.VN(:)];
            key.ViewVectorAngularOffsetsDegrees = ...
                app.layerViewVectorAngularOffsetsDegrees(layer);
            key.ProjectionOffsetMeters = app.layerProjectionOffset(layer);
            key.RenderOrigin = app.Scene.renderOrigin(:);
            key.TileSize = app.PreviewTilingOptions.TileSize;
        end

        function refreshTiledProjectionSurfaces(app)
            refreshTimer = tic;
            app.PerformanceMonitor.increment("TileRefreshes");
            if isempty(app.Surfaces) || isempty(app.PreviewTiledLayerMask)
                app.PerformanceMonitor.recordTiming( ...
                    "TileRefreshSeconds", toc(refreshTimer));
                return
            end

            tiledLayerIndices = find(app.PreviewTiledLayerMask & ...
                app.effectiveLayerVisibilityMask() & ...
                [app.Scene.layers.Alpha] > 0);
            if isempty(tiledLayerIndices)
                app.PerformanceMonitor.recordTiming( ...
                    "TileRefreshSeconds", toc(refreshTimer));
                return
            end
            cameraContext = app.previewCameraContext();
            for layerIndex = reshape(tiledLayerIndices, 1, [])
                app.refreshTiledLayerSurfaces(layerIndex, cameraContext);
            end
            app.raiseCrosshairOverlay();
            app.PerformanceMonitor.recordTiming( ...
                "TileRefreshSeconds", toc(refreshTimer));
        end

        function refreshTiledLayerSurfaces(app, layerIndex, cameraContext)
            if nargin < 3 || isempty(cameraContext)
                cameraContext = app.previewCameraContext();
            end
            tiles = app.previewTilesForLayer(layerIndex, cameraContext);
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

            cameraContext = app.previewCameraContext();
            tiles = app.previewTilesForLayer(layerIndex, cameraContext);
            app.setTiledLayerSurfaces(layerIndex, tiles, true);
        end

        function setTiledLayerSurfaces(app, layerIndex, tiles, updateTexture)
            if nargin < 4
                updateTexture = false;
            end

            surfaceHandles = app.validLayerSurfaces(layerIndex);
            if app.canReuseTiledLayerSurfaces(layerIndex, tiles, surfaceHandles)
                app.PerformanceMonitor.increment( ...
                    "SurfaceHandleReuses", numel(surfaceHandles));
                if updateTexture
                    app.updateExistingTiledLayerSurfaces(layerIndex, tiles, true);
                end
                app.recordAppliedPreviewLevel(layerIndex, tiles);
                return
            end

            previousKeys = app.currentPreviewTileKeys(layerIndex);
            targetKeys = app.previewTileKeys(tiles);
            replacementHandles = gobjects(1, numel(tiles));
            usedPrevious = false(1, numel(surfaceHandles));
            if numel(previousKeys) ~= numel(surfaceHandles)
                previousKeys = strings(size(surfaceHandles));
            end
            for tileIndex = 1:numel(tiles)
                previousIndex = find(~usedPrevious & ...
                    previousKeys == targetKeys(tileIndex), 1, "first");
                if ~isempty(previousIndex)
                    replacementHandles(tileIndex) = ...
                        surfaceHandles(previousIndex);
                    usedPrevious(previousIndex) = true;
                    app.PerformanceMonitor.increment("SurfaceHandleReuses");
                    if updateTexture
                        tileData = app.preparedPreviewTileData( ...
                            layerIndex, tiles(tileIndex), ...
                            app.PreviewTilingOptions.MaxTileMeshVertices);
                        app.updatePreviewTileSurface( ...
                            replacementHandles(tileIndex), layerIndex, ...
                            tileData, true);
                    end
                    continue
                end

                tileData = app.preparedPreviewTileData( ...
                    layerIndex, tiles(tileIndex), ...
                    app.PreviewTilingOptions.MaxTileMeshVertices);
                replacementHandles(tileIndex) = ...
                    app.acquirePreviewTileSurface(layerIndex, tileData);
                replacementHandles(tileIndex).UserData = targetKeys(tileIndex);
            end

            app.retirePreviewTileSurfaces(surfaceHandles(~usedPrevious));
            app.Surfaces{layerIndex} = replacementHandles;
            app.PreviewTiles{layerIndex} = tiles;
            app.PreviewTileKeys{layerIndex} = targetKeys;
            app.recordAppliedPreviewLevel(layerIndex, tiles);
            if layerIndex == app.SelectedLayerIndex
                app.Surface = app.primarySurfaceForLayer(layerIndex);
            end
        end

        function tf = canReuseTiledLayerSurfaces(app, layerIndex, tiles, surfaceHandles)
            previousKeys = app.currentPreviewTileKeys(layerIndex);
            targetKeys = app.previewTileKeys(tiles);
            tf = numel(surfaceHandles) == numel(tiles) && ...
                isequal(previousKeys, targetKeys);
        end

        function tiles = currentPreviewTilesForLayer(app, layerIndex)
            if isempty(app.PreviewTiles) || layerIndex > numel(app.PreviewTiles) || ...
                    isempty(app.PreviewTiles{layerIndex})
                tiles = ProjectionPreviewPyramid.emptyTiles();
            else
                tiles = app.PreviewTiles{layerIndex};
            end
        end

        function keys = currentPreviewTileKeys(app, layerIndex)
            if isempty(app.PreviewTileKeys) || ...
                    layerIndex > numel(app.PreviewTileKeys) || ...
                    isempty(app.PreviewTileKeys{layerIndex})
                keys = strings(1, 0);
            else
                keys = app.PreviewTileKeys{layerIndex};
            end
        end

        function updateExistingTiledLayerSurfaces(app, layerIndex, tiles, ...
                updateTexture, maxMeshVertices)
            if nargin < 5
                maxMeshVertices = app.PreviewTilingOptions.MaxTileMeshVertices;
            end

            surfaceHandles = app.validLayerSurfaces(layerIndex);
            for tileIndex = 1:numel(tiles)
                tileData = app.preparedPreviewTileData( ...
                    layerIndex, tiles(tileIndex), maxMeshVertices);
                app.updatePreviewTileSurface( ...
                    surfaceHandles(tileIndex), layerIndex, ...
                    tileData, updateTexture);
            end
            app.PreviewTiles{layerIndex} = tiles;
            app.PreviewTileKeys{layerIndex} = app.previewTileKeys(tiles);
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
            app.deleteSurfaceHandles(surfaceHandles);
            if ~isempty(app.Surfaces) && layerIndex <= numel(app.Surfaces)
                app.Surfaces{layerIndex} = gobjects(0);
            end
            if ~isempty(app.PreviewTiles) && layerIndex <= numel(app.PreviewTiles)
                app.PreviewTiles{layerIndex} = ProjectionPreviewPyramid.emptyTiles();
            end
            if ~isempty(app.PreviewTileKeys) && layerIndex <= numel(app.PreviewTileKeys)
                app.PreviewTileKeys{layerIndex} = strings(1, 0);
            end
        end

        function deleteSurfaceHandles(app, surfaceHandles)
            if isempty(surfaceHandles)
                return
            end
            app.PerformanceMonitor.increment( ...
                "SurfaceDeletions", numel(surfaceHandles));
            delete(surfaceHandles);
        end

        function surfaceHandle = acquirePreviewTileSurface( ...
                app, layerIndex, tileData)
            app.PreviewSurfacePool = app.validPreviewSurfacePool();
            mesh = app.previewTileAppearanceMesh(tileData.Mesh, layerIndex);
            if isempty(app.PreviewSurfacePool)
                app.PerformanceMonitor.increment("SurfacePoolMisses");
                surfaceHandle = app.createPreviewSurface( ...
                    layerIndex, mesh, tileData.DisplayTexture, ...
                    "ProjectionViewerPreviewTileSurface");
                return
            end

            app.PerformanceMonitor.increment("SurfacePoolHits");
            surfaceHandle = app.PreviewSurfacePool(end);
            app.PreviewSurfacePool(end) = [];
            surfaceHandle.Visible = "off";
            surfaceHandle.Tag = "ProjectionViewerPreviewTileSurface";
            surfaceHandle.ContextMenu = app.ImageContextMenu;
            displayTexture = app.previewTextureForLayer( ...
                tileData.DisplayTexture, layerIndex);
            surfaceHandle.CData = displayTexture;
            app.PerformanceMonitor.increment( ...
                "TextureUploadBytes", app.arrayBytes(displayTexture));
            app.updatePreviewSurfaceHandle( ...
                surfaceHandle, layerIndex, mesh, false);
        end

        function updatePreviewTileSurface(app, surfaceHandle, layerIndex, ...
                tileData, updateTexture)
            mesh = app.previewTileAppearanceMesh(tileData.Mesh, layerIndex);
            if updateTexture
                displayTexture = app.previewTextureForLayer( ...
                    tileData.DisplayTexture, layerIndex);
                surfaceHandle.CData = displayTexture;
                app.PerformanceMonitor.increment( ...
                    "TextureUploadBytes", app.arrayBytes(displayTexture));
            end
            app.updatePreviewSurfaceHandle( ...
                surfaceHandle, layerIndex, mesh, false);
        end

        function mesh = previewTileAppearanceMesh(app, mesh, layerIndex)
            layer = app.Scene.layers(layerIndex);
            mesh.Alpha = layer.Alpha;
            mesh.Visible = app.previewSurfaceIsVisible( ...
                layer.Visible, layer.Alpha);
        end

        function retirePreviewTileSurfaces(app, surfaceHandles)
            surfaceHandles = surfaceHandles(isgraphics(surfaceHandles));
            if isempty(surfaceHandles)
                return
            end
            app.PreviewSurfacePool = app.validPreviewSurfacePool();
            availableCount = max(0, app.PreviewSurfacePoolMaxCount - ...
                numel(app.PreviewSurfacePool));
            pooledCount = min(numel(surfaceHandles), availableCount);
            pooledHandles = surfaceHandles(1:pooledCount);
            if ~isempty(pooledHandles)
                set(pooledHandles, "Visible", "off", ...
                    "Tag", "ProjectionViewerPooledTileSurface");
                set(pooledHandles, "UserData", "");
                app.PreviewSurfacePool = ...
                    [app.PreviewSurfacePool pooledHandles];
                app.PerformanceMonitor.increment( ...
                    "SurfacePoolRetirements", pooledCount);
            end
            app.deleteSurfaceHandles(surfaceHandles(pooledCount + 1:end));
        end

        function surfaceHandles = validPreviewSurfacePool(app)
            surfaceHandles = app.PreviewSurfacePool;
            surfaceHandles = surfaceHandles(isgraphics(surfaceHandles));
        end

        function clearPreviewTileRuntimeCache(app)
            if ~isempty(app.PreviewTileDataCache) && ...
                    isvalid(app.PreviewTileDataCache)
                app.PreviewTileDataCache.clear();
            end
            pool = app.validPreviewSurfacePool();
            app.deleteSurfaceHandles(pool);
            app.PreviewSurfacePool = gobjects(0);
        end

        function clearPreviewSampledGeometryCache(app)
            if ~isempty(app.PreviewSampledGeometryCache) && ...
                    isvalid(app.PreviewSampledGeometryCache)
                app.PreviewSampledGeometryCache.clear();
            end
        end

        function recordAppliedPreviewLevel(app, layerIndex, tiles)
            levelIndex = app.PreviewPendingLevelIndices(layerIndex);
            if ~isempty(tiles)
                levelIndex = tiles(1).LevelIndex;
            end
            previousLevelIndex = app.PreviewCurrentLevelIndices(layerIndex);
            if previousLevelIndex > 0 && levelIndex > 0 && ...
                    previousLevelIndex ~= levelIndex
                app.PerformanceMonitor.increment("LodTransitions");
            end
            if levelIndex > 0
                app.PreviewCurrentLevelIndices(layerIndex) = levelIndex;
            end
            app.PreviewPendingLevelIndices(layerIndex) = 0;
        end

        function setLayerSurfaceVisible(app, layerIndex, isVisible)
            surfaceHandles = app.validLayerSurfaces(layerIndex);
            if isempty(surfaceHandles)
                return
            end
            alpha = app.Scene.layers(layerIndex).Alpha;
            isVisible = app.previewSurfaceIsVisible(isVisible, alpha);
            set(surfaceHandles, "Visible", char(app.onOff(isVisible)));
        end

        function setLayerSurfaceAlpha(app, layerIndex, alpha)
            surfaceHandles = app.validLayerSurfaces(layerIndex);
            if isempty(surfaceHandles)
                return
            end
            faceAlpha = app.previewFaceAlphaForLayer(alpha, layerIndex);
            visibleMask = app.effectiveLayerVisibilityMask();
            isVisible = app.previewSurfaceIsVisible( ...
                visibleMask(layerIndex), alpha);
            currentVisibility = string(get(surfaceHandles, "Visible"));
            visibilityChanges = nnz( ...
                (currentVisibility == "on") ~= isVisible);
            set(surfaceHandles, "FaceAlpha", faceAlpha, ...
                "Visible", char(app.onOff(isVisible)));
            app.PerformanceMonitor.increment( ...
                "AlphaVisibilityTransitions", visibilityChanges);
        end

        function raiseCrosshairOverlay(app)
            handles = [app.CrosshairHorizontal app.CrosshairVertical];
            handles = handles(isgraphics(handles));
            if ~isempty(handles)
                app.PerformanceMonitor.increment("OverlayRestacks");
                uistack(handles, "top");
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
            app.flushCameraReconciliation();
        end

        function updateViewTwist(app, twistDegrees)
            app.noteManualCameraMotion();
            frameTimer = app.beginPerformanceFrame();
            app.suspendCameraReconciliationTimer();
            oldPresentationOffsets = app.anaglyphPresentationOffsets();
            oldChannelAssignments = app.anaglyphChannelAssignments();
            app.ViewTwistDegrees = twistDegrees;
            app.applyViewTwist();
            newChannelAssignments = app.anaglyphChannelAssignments();
            if ~isequal(oldChannelAssignments, newChannelAssignments)
                app.updateAllSurfaceBlendAppearance();
            end
            app.applyAnaglyphPresentationOffsetDelta( ...
                oldPresentationOffsets);

            layer = app.Scene.layers(app.SelectedLayerIndex);
            app.updateLabels(app.ProjectionTipDegrees, ...
                app.ProjectionTiltDegrees, ...
                app.ViewTwistDegrees, layer.Alpha);
            drawnow limitrate
            app.finishPerformanceFrame(frameTimer, "TwistSeconds");
            app.scheduleCameraReconciliation();
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

            app.nudgeSelectedLayerInDirection(key);
        end

        function nudgeSelectedLayerInDirection(app, key)

            layerIndex = app.SelectedLayerIndex;
            layer = app.Scene.layers(layerIndex);
            plane = layer.CurrentProjectionPlane;
            [worldDirection, stepMeters] = app.layerNudgeWorldDirection(key, layer, plane);
            projectionDelta = plane.basis.' * (stepMeters * worldDirection);
            app.translateLayerProjectionOffset( ...
                layerIndex, projectionDelta, true);
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
            app.updateSelectedLayerProjection( ...
                layerIndex, app.DefaultMeshSampling);
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
            if app.eventKeyIs(event, "escape") && app.MotionRuntime.Active
                app.exitMotionImagery();
                return
            end
            if app.eventKeyIs(event, "escape") && ...
                    app.DragMode == "adjustCommonAnchor"
                app.cancelAlignmentAnchorDrag( ...
                    "Common-anchor adjustment cancelled.");
                return
            end
            if app.eventHasControl(event)
                app.IsControlDown = true;
            end
            if app.eventHasShift(event)
                app.IsShiftDown = true;
            end
            if app.eventHasAlt(event)
                app.IsAltDown = true;
            end
            if app.handleViewportArrowKey(event)
                return
            end
            if app.IsControlDown || app.IsShiftDown || app.IsAltDown
                return
            end
            if app.eventKeyIs(event, "space")
                if app.MotionRuntime.Active
                    app.toggleMotionPlayback();
                    return
                end
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
                if app.MotionRuntime.Active
                    return
                end
                app.setSelectedLayerVisible(true);
            end
        end

        function pointerMoved(app)
            if app.IsPointerMotionBusy
                app.PerformanceMonitor.increment("DroppedRequests");
                return
            end
            app.IsPointerMotionBusy = true;
            cleanup = onCleanup(@() app.finishPointerMotion());
            app.PerformanceMonitor.increment("PointerMotionCallbacks");
            app.updatePan();
            app.updateCrosshair();
            app.updateMotionEdgeControls();
            clear cleanup
        end

        function finishPointerMotion(app)
            app.IsPointerMotionBusy = false;
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

        function handled = handleViewportArrowKey(app, event)
            handled = false;
            key = app.eventStringValue(event, "Key");
            if isempty(key) || ~any(key(1) == ...
                    ["uparrow", "downarrow", "leftarrow", "rightarrow"])
                return
            end
            if ~app.viewportHasInteractionFocus() || ...
                    app.eventHasControl(event) || app.eventHasAlt(event)
                return
            end

            if app.IsShiftDown || app.eventHasShift(event)
                handled = app.adjustProjectionFromArrowKey(event);
                return
            end
            if app.ViewportKeyboardMode == "motion"
                handled = true;
                if key(1) == "leftarrow"
                    app.stepMotion(-1);
                elseif key(1) == "rightarrow"
                    app.stepMotion(1);
                end
                return
            elseif app.ViewportKeyboardMode ~= "normal"
                return
            end

            handled = true;
            if key(1) == "leftarrow"
                app.selectAdjacentLayer(-1);
            elseif key(1) == "rightarrow"
                app.selectAdjacentLayer(1);
            elseif key(1) == "uparrow"
                app.nudgeSelectedLayerInDirection("w");
            else
                app.nudgeSelectedLayerInDirection("s");
            end
        end

        function tf = viewportHasInteractionFocus(app)
            tf = false;
            focusObject = app.UIFigure.CurrentObject;
            if isempty(focusObject) || ~isvalid(focusObject)
                return
            end
            if focusObject == app.Axes
                tf = true;
                return
            end
            if ~isgraphics(focusObject)
                return
            end
            parentAxes = ancestor(focusObject, "axes");
            tf = ~isempty(parentAxes) && parentAxes == app.Axes;
        end

        function selectAdjacentLayer(app, direction)
            targetIndex = min(max(app.SelectedLayerIndex + direction, 1), ...
                numel(app.Scene.layers));
            if targetIndex == app.SelectedLayerIndex
                return
            end
            app.SelectedLayerIndex = targetIndex;
            app.updateControlsFromSelectedLayer();
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

            app.noteManualCameraMotion();
            frameTimer = app.beginPerformanceFrame();
            app.suspendCameraReconciliationTimer();
            zoomFactor = 1.12 ^ event.VerticalScrollCount;
            newAngle = app.Axes.CameraViewAngle * zoomFactor;
            newAngle = min(max(newAngle, app.MinCameraViewAngle), app.MaxCameraViewAngle);
            app.Axes.CameraViewAngle = newAngle;
            drawnow limitrate
            app.finishPerformanceFrame(frameTimer, "ZoomSeconds");
            app.scheduleCameraReconciliation();
        end

        function beginPan(app, event)
            if nargin < 2
                event = struct();
            end
            if ~app.isPointerInAxes()
                return
            end

            selectionType = string(app.UIFigure.SelectionType);
            if app.AlignmentRoiDrawingActive && selectionType == "normal"
                planePoint = app.currentPointerProjectionPlanePoint();
                if all(isfinite(planePoint))
                    app.AlignmentRoiStartPoint = planePoint;
                    app.DragMode = "drawAlignmentRoi";
                    app.LastPointerLocation = app.UIFigure.CurrentPoint;
                    app.refreshPointerMotionCallback();
                end
                return
            end
            if selectionType == "open"
                app.cycleLayer();
                return
            end
            hasControl = app.IsControlDown || app.eventHasControl(event);
            hasShift = app.IsShiftDown || app.eventHasShift(event);
            hasAlt = app.IsAltDown || app.eventHasAlt(event);
            if hasShift && any(selectionType == ["normal", "extend"])
                app.beginAlignmentAnchorDrag();
                return
            elseif hasControl && any(selectionType == ["normal", "alt"])
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
            app.refreshPointerMotionCallback();
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
                case "drawAlignmentRoi"
                    app.updateDrawnAlignmentRoi();
                case "adjustCommonAnchor"
                    app.updateAlignmentAnchorDrag();
            end
        end

        function endPan(app)
            dragMode = app.DragMode;
            app.DragMode = "none";
            app.LastPointerLocation = [NaN NaN];
            app.refreshPointerMotionCallback();
            if dragMode == "adjustCommonAnchor"
                app.finishAlignmentAnchorDrag();
                app.NeedsDragFinalize = false;
                return
            end
            if dragMode == "panCamera"
                app.flushCameraReconciliation();
            end
            if dragMode == "drawAlignmentRoi"
                app.AlignmentRoiDrawingActive = false;
                app.AlignmentRoiStartPoint = [NaN NaN];
                app.refreshAlignmentRoiFiltering();
                app.setAlignmentStatus("ROI updated; matches re-filtered.");
            end
            if app.NeedsDragFinalize && dragMode == "translateLayer"
                app.flushCameraReconciliation();
                app.refreshAlignmentOverlays();
            elseif app.NeedsDragFinalize && dragMode == "adjustViewVectors"
                app.updateSelectedLayerProjection( ...
                    app.SelectedLayerIndex, app.DefaultMeshSampling);
                app.PreviewTimer = tic;
            end
            app.NeedsDragFinalize = false;
        end

        function started = beginAlignmentAnchorDrag(app)
            started = false;
            if app.DragMode == "adjustCommonAnchor"
                started = true;
                return
            end
            if isempty(app.AlignmentMatchTable) || ...
                    ~isvalid(app.AlignmentMatchTable) || ...
                    isempty(app.AlignmentSelectedMatchRows)
                app.setAlignmentStatus( ...
                    "Select an accepted match before Shift+left anchor drag.");
                return
            end
            data = app.AlignmentMatchTable.Data;
            row = app.AlignmentSelectedMatchRows(1);
            if ~istable(data) || row < 1 || row > height(data) || ...
                    ~data.Enabled(row) || ...
                    ismember(string(data.State(row)), ["disabled", "deleted"])
                app.setAlignmentStatus( ...
                    "Shift+left anchor drag requires an enabled accepted match.");
                return
            end
            pointerPoint = app.currentPointerProjectionPlanePoint();
            if any(~isfinite(pointerPoint))
                app.setAlignmentStatus( ...
                    "The anchor cursor does not intersect the projection plane.");
                return
            end

            try
                pair = app.pairFromKey(data.Pair(row));
                matches = app.alignmentAcceptedSolveMatches();
                options = app.currentAlignmentOptions();
                state = ProjectionAlignmentCommonAnchor.prepare( ...
                    app.Scene, matches, pair, data.MatchIndex(row), ...
                    app.currentProjectionPlane(), options);
                state.PointerOffset = state.StartingCentroid - pointerPoint;
                state.LastTarget = state.StartingCentroid;
                state.HasMoved = false;
                app.AlignmentAnchorDragState = state;
                app.AlignmentAnchorDragCancelled = false;
                app.DragMode = "adjustCommonAnchor";
                app.LastPointerLocation = app.UIFigure.CurrentPoint;
                app.refreshPointerMotionCallback();
                app.setAlignmentStatus(sprintf( ...
                    "Dragging common anchor %d for %s; release to refine, Esc to cancel.", ...
                    state.MatchIndex, char(data.Pair(row))));
                started = true;
            catch ME
                app.AlignmentAnchorDragState = struct();
                app.setAlignmentStatus( ...
                    "Cannot start common-anchor drag: " + string(ME.message));
            end
        end

        function updateAlignmentAnchorDrag(app)
            state = app.AlignmentAnchorDragState;
            if isempty(fieldnames(state))
                return
            end
            pointerPoint = app.currentPointerProjectionPlanePoint();
            if any(~isfinite(pointerPoint))
                return
            end
            target = pointerPoint + state.PointerOffset;
            try
                preview = ProjectionAlignmentCommonAnchor.preview(state, target);
                previousScene = app.Scene;
                app.Scene = preview.Scene;
                layerIndices = app.changedProjectionLayerIndices( ...
                    previousScene, app.Scene);
                if ~isempty(layerIndices)
                    app.refreshProjectionLayers( ...
                        layerIndices, app.DragMeshSampling, false);
                end
                state.LastTarget = target;
                state.HasMoved = state.HasMoved || ...
                    norm(target - state.StartingCentroid) > 1e-9;
                app.AlignmentAnchorDragState = state;
                app.refreshSelectedAlignmentMatchOverlay();
                drawnow limitrate
            catch ME
                app.cancelAlignmentAnchorDrag( ...
                    "Common-anchor preview failed: " + string(ME.message));
            end
        end

        function finishAlignmentAnchorDrag(app)
            state = app.AlignmentAnchorDragState;
            if isempty(fieldnames(state)) || app.AlignmentAnchorDragCancelled
                app.AlignmentAnchorDragState = struct();
                app.AlignmentAnchorDragCancelled = false;
                return
            end
            if ~state.HasMoved
                app.restoreAlignmentAnchorStartScene(state);
                app.AlignmentAnchorDragState = struct();
                app.setAlignmentStatus("Common-anchor adjustment unchanged.");
                return
            end

            app.setAlignmentStatus("Refining common-anchor adjustment...");
            adjustmentStored = false;
            try
                result = ProjectionAlignmentCommonAnchor.refine( ...
                    state, state.LastTarget);
                if ~result.Success
                    app.restoreAlignmentAnchorStartScene(state);
                    app.setAlignmentStatus( ...
                        "Common-anchor adjustment rejected: " + ...
                        result.FailureReason);
                else
                    previousScene = app.Scene;
                    app.Scene = result.Scene;
                    layerIndices = app.changedProjectionLayerIndices( ...
                        previousScene, app.Scene);
                    app.refreshProjectionLayers( ...
                        layerIndices, app.DefaultMeshSampling, false);
                    app.updateControlsFromSelectedLayer();
                    record = app.commonAnchorAdjustmentRecord(result);
                    app.AlignmentSession.storeManualAdjustment(record);
                    adjustmentStored = true;
                    app.setAlignmentActionEnabled(false);
                    app.setAlignmentSolveEnabled( ...
                        app.hasSolvableFilteredMatches());
                    app.refreshAlignmentOverlays(true);
                    app.refreshSelectedAlignmentMatchOverlay();
                    app.setAlignmentStatus(sprintf( ...
                        "Common anchor applied to both images; target error %.4g m, ray RMS %.4g -> %.4g. Solve diagnostics are stale.", ...
                        result.TargetErrorMeters, result.ForwardRayRmsBefore, ...
                        result.ForwardRayRmsAfter));
                end
            catch ME
                if adjustmentStored
                    app.AlignmentSession.popManualAdjustment();
                end
                app.restoreAlignmentAnchorStartScene(state);
                app.setAlignmentStatus( ...
                    "Common-anchor adjustment failed: " + string(ME.message));
            end
            app.AlignmentAnchorDragState = struct();
            app.AlignmentAnchorDragCancelled = false;
        end

        function cancelAlignmentAnchorDrag(app, statusText)
            state = app.AlignmentAnchorDragState;
            app.AlignmentAnchorDragCancelled = true;
            app.DragMode = "none";
            app.LastPointerLocation = [NaN NaN];
            app.refreshPointerMotionCallback();
            if ~isempty(fieldnames(state))
                app.restoreAlignmentAnchorStartScene(state);
            end
            app.AlignmentAnchorDragState = struct();
            app.setAlignmentStatus(statusText);
        end

        function restoreAlignmentAnchorStartScene(app, state)
            previousScene = app.Scene;
            app.Scene = state.StartScene;
            layerIndices = app.changedProjectionLayerIndices( ...
                previousScene, app.Scene);
            if ~isempty(layerIndices)
                app.refreshProjectionLayers( ...
                    layerIndices, app.DefaultMeshSampling, false);
            end
            app.updateControlsFromSelectedLayer();
            app.refreshAlignmentOverlays(true);
            app.refreshSelectedAlignmentMatchOverlay();
        end

        function matches = alignmentAcceptedSolveMatches(app)
            matches = app.AlignmentFilteredMatchResult;
            if app.hasScalarStruct(app.AlignmentWorkingImages) && ...
                    isfield(app.AlignmentWorkingImages, "Schedule")
                enabledPairs = app.enabledAlignmentPairs( ...
                    app.AlignmentWorkingImages.Schedule);
                matches = app.applyEnabledPairsToMatchResult( ...
                    matches, enabledPairs);
            end
            matches = app.applyCuratedMaskToMatchResult(matches);
        end

        function record = commonAnchorAdjustmentRecord(~, result)
            startOpk = reshape( ...
                [result.StartingCorrections.ViewVectorAngularOffsetsDegrees], ...
                3, []).';
            finalOpk = reshape( ...
                [result.Corrections.ViewVectorAngularOffsetsDegrees], 3, []).';
            record = struct(Kind="commonAnchor", ...
                MatchIndex=result.MatchIndex, Pair=result.Pair, ...
                LayerIds=result.LayerIds, ...
                TargetPlanePoint=result.TargetPlanePoint, ...
                AchievedPlanePoint=result.Centroid, ...
                TargetErrorMeters=result.TargetErrorMeters, ...
                StartingProjectionPoints=result.StartingProjectionPoints, ...
                AchievedProjectionPoints=result.ProjectionPoints, ...
                EndpointWeights=result.EndpointWeights, ...
                StartingDisparity=result.StartingDisparity, ...
                AchievedDisparity=result.Disparity, ...
                StartingCorrections=result.StartingCorrections, ...
                FinalCorrections=result.Corrections, ...
                OpkChangesDegrees=finalOpk - startOpk, ...
                CommonDeltaDegrees=result.CommonDeltaDegrees, ...
                AdjustedCommonModes=result.AdjustedCommonModes, ...
                Jacobian=result.Jacobian, ...
                JacobianReciprocalCondition= ...
                    result.JacobianReciprocalCondition, ...
                JacobianSingularValues=result.JacobianSingularValues, ...
                BoundsDegrees=result.CommonBoundsDegrees, ...
                BoundHitMask=result.BoundHitMask, ...
                ForwardRayRmsBefore=result.ForwardRayRmsBefore, ...
                ForwardRayRmsAfter=result.ForwardRayRmsAfter);
        end

        function refreshSelectedAlignmentMatchOverlay(app)
            if isempty(app.AlignmentSelectedMatchRows) || ...
                    isempty(app.AlignmentMatchTable) || ...
                    ~isvalid(app.AlignmentMatchTable)
                return
            end
            data = app.AlignmentMatchTable.Data;
            row = app.AlignmentSelectedMatchRows(1);
            if istable(data) && row >= 1 && row <= height(data)
                app.drawSelectedAlignmentMatchOverlay(data(row, :));
            end
        end

        function updateDrawnAlignmentRoi(app)
            currentPoint = app.currentPointerProjectionPlanePoint();
            startPoint = app.AlignmentRoiStartPoint;
            if any(~isfinite(currentPoint)) || any(~isfinite(startPoint))
                return
            end
            bounds = [min(startPoint(1), currentPoint(1)), ...
                max(startPoint(1), currentPoint(1)), ...
                min(startPoint(2), currentPoint(2)), ...
                max(startPoint(2), currentPoint(2))];
            if bounds(2) - bounds(1) <= eps || bounds(4) - bounds(3) <= eps
                return
            end
            app.AlignmentRoiBounds = bounds;
            app.updateAlignmentRoiBounds();
            drawnow limitrate
        end

        function planePoint = currentPointerProjectionPlanePoint(app)
            planePoint = [NaN NaN];
            currentPoint = double(app.Axes.CurrentPoint);
            if ~isequal(size(currentPoint), [2 3]) || ...
                    any(~isfinite(currentPoint), "all")
                return
            end
            renderPlane = app.currentProjectionPlane();
            renderPlane.P0 = renderPlane.P0 - app.Scene.renderOrigin;
            origin = currentPoint(1, :).';
            direction = currentPoint(2, :).' - origin;
            denominator = renderPlane.VN.' * direction;
            if abs(denominator) <= 1e-12
                return
            end
            range = (renderPlane.VN.' * (renderPlane.P0 - origin)) / ...
                denominator;
            renderPoint = origin + range * direction;
            worldPoint = renderPoint + app.Scene.renderOrigin;
            coordinates = PlanarProjection.worldToPlane( ...
                worldPoint, app.currentProjectionPlane());
            planePoint = coordinates(:).';
        end

        function panCameraByPixelDelta(app, pixelDelta)
            app.noteManualCameraMotion();
            frameTimer = app.beginPerformanceFrame();
            app.suspendCameraReconciliationTimer();
            panOffset = app.pixelDeltaToWorldPan(pixelDelta);
            campos(app.Axes, campos(app.Axes) + panOffset.');
            camtarget(app.Axes, camtarget(app.Axes) + panOffset.');
            drawnow limitrate
            app.finishPerformanceFrame(frameTimer, "PanSeconds");
            app.scheduleCameraReconciliation();
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

            app.translateLayerProjectionOffset( ...
                layerIndex, projectionDelta, false);
            app.PreviewTimer = tic;
            app.NeedsDragFinalize = true;
        end

        function translateLayerProjectionOffset(app, layerIndex, ...
                projectionDelta, refreshOverlays)
            frameTimer = app.beginPerformanceFrame();
            projectionDelta = double(projectionDelta(:));
            layer = app.Scene.layers(layerIndex);
            plane = layer.CurrentProjectionPlane;
            worldDelta = plane.basis * projectionDelta;
            layer.ProjectionOffsetMeters = ...
                app.layerProjectionOffset(layer) + projectionDelta;
            app.Scene.layers(layerIndex) = layer;

            surfaceHandles = app.validLayerSurfaces(layerIndex);
            for surfaceHandle = reshape(surfaceHandles, 1, [])
                surfaceHandle.XData = surfaceHandle.XData + worldDelta(1);
                surfaceHandle.YData = surfaceHandle.YData + worldDelta(2);
                surfaceHandle.ZData = surfaceHandle.ZData + worldDelta(3);
            end
            if layerIndex == app.SelectedLayerIndex && ...
                    ~isempty(app.CurrentMesh) && isfield(app.CurrentMesh, "X")
                app.CurrentMesh = app.translateMesh( ...
                    app.CurrentMesh, projectionDelta, worldDelta);
            end

            app.invalidatePreviewGeometry(layerIndex);
            app.PerformanceMonitor.increment("RigidProjectionTranslations");
            if refreshOverlays
                app.refreshAlignmentOverlays();
            end
            drawnow limitrate
            app.finishPerformanceFrame( ...
                frameTimer, "ProjectionOffsetSeconds");
            if app.usesTiledPreview(layerIndex)
                app.scheduleCameraReconciliation();
            end
        end

        function mesh = translateMesh(~, mesh, projectionDelta, worldDelta)
            mesh.X = mesh.X + worldDelta(1);
            mesh.Y = mesh.Y + worldDelta(2);
            mesh.Z = mesh.Z + worldDelta(3);
            mesh.WorldPoints = mesh.WorldPoints + ...
                reshape(worldDelta, 3, 1, 1);
            mesh.RenderPoints = mesh.RenderPoints + ...
                reshape(worldDelta, 3, 1, 1);
            mesh.ProjectionOffsetMeters = ...
                mesh.ProjectionOffsetMeters + projectionDelta;
            mesh.ProjectionOffsetWorld = ...
                mesh.ProjectionOffsetWorld + worldDelta;
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
            app.updateSelectedLayerProjection( ...
                layerIndex, app.DragMeshSampling);
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
            baseCenter = app.layerMeshCenter( ...
                layerIndex, sampledLayer, plane);
            screenJacobian = zeros(2, 2);

            for componentIndex = 1:2
                perturbedLayer = sampledLayer;
                perturbedOffsetsDegrees = offsetsDegrees;
                perturbedOffsetsDegrees(componentIndex) = ...
                    perturbedOffsetsDegrees(componentIndex) + probeDegrees;
                perturbedLayer.ViewVectorAngularOffsetsDegrees = ...
                    perturbedOffsetsDegrees;
                perturbedCenter = app.layerMeshCenter( ...
                    layerIndex, perturbedLayer, plane);
                centerDerivative = (perturbedCenter - baseCenter) / probeDegrees;
                screenJacobian(:, componentIndex) = ...
                    [rightVector.' * centerDerivative; upVector.' * centerDerivative];
            end
        end

        function center = layerMeshCenter(app, layerIndex, layer, plane)
            mesh = app.buildInstrumentedLayerMesh( ...
                layerIndex, layer, plane);
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
            points = app.currentVisibleSurfacePoints();
            if isempty(points)
                return
            end
            app.centerCameraOnSurfacePoints(points);
            [projectedWidth, projectedHeight] = ...
                app.projectedSurfaceSize(points);
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
            points = app.currentVisibleSurfacePoints();
            [projectedWidth, projectedHeight] = ...
                app.projectedSurfaceSize(points);
        end

        function points = currentVisibleSurfacePoints(app)
            layerIndices = find(app.effectiveLayerVisibilityMask());
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
        end

        function centerCameraOnSurfacePoints(app, points)
            if isempty(points)
                return
            end

            [rightVector, upVector] = app.cameraScreenBasis();
            cameraTarget = camtarget(app.Axes).';
            relativePoints = points - cameraTarget;
            screenX = rightVector.' * relativePoints;
            screenY = upVector.' * relativePoints;
            screenCenterOffset = 0.5 * (min(screenX) + max(screenX)) * ...
                rightVector + 0.5 * (min(screenY) + max(screenY)) * upVector;
            if any(~isfinite(screenCenterOffset)) || ...
                    norm(screenCenterOffset) <= eps
                return
            end

            cameraPosition = campos(app.Axes).' + screenCenterOffset;
            cameraTarget = cameraTarget + screenCenterOffset;
            cameraUpVector = camup(app.Axes).';
            cameraViewAngle = app.Axes.CameraViewAngle;
            app.Axes.CameraPosition = cameraPosition.';
            app.Axes.CameraTarget = cameraTarget.';
            app.Axes.CameraUpVector = cameraUpVector.';
            app.Axes.CameraViewAngle = cameraViewAngle;
        end

        function [projectedWidth, projectedHeight] = ...
                projectedSurfaceSize(app, points)
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

        function alphaChanging(app, ~, event)
            alpha = app.validateSliderAlpha(event.Value);
            app.requestSelectedLayerAlpha(alpha, false);
        end

        function updateAlphaFromSlider(app)
            alpha = app.validateSliderAlpha(app.AlphaSlider.Value);
            app.requestSelectedLayerAlpha(alpha, true);
            app.PreviewTimer = tic;
        end

        function requestSelectedLayerAlpha(app, alpha, forceRender)
            layerIndex = app.SelectedLayerIndex;
            layer = app.Scene.layers(layerIndex);
            app.PerformanceMonitor.increment("AlphaRequests");
            layer.Alpha = alpha;
            app.Scene.layers(layerIndex) = layer;
            if layerIndex == app.SelectedLayerIndex && ...
                    ~isempty(app.CurrentMesh) && ...
                    isfield(app.CurrentMesh, "Alpha")
                app.CurrentMesh.Alpha = alpha;
            end
            app.updateAlphaLabel(alpha);
            app.PendingAlphaMask(layerIndex) = ...
                app.RenderedLayerAlphas(layerIndex) ~= alpha;
            if ~app.PendingAlphaMask(layerIndex)
                return
            end

            canRender = forceRender || isempty(app.AlphaPreviewTimer) || ...
                toc(app.AlphaPreviewTimer) >= ...
                app.AlphaPreviewMinIntervalSeconds;
            if ~canRender
                app.PerformanceMonitor.increment("AlphaCoalescedRequests");
                return
            end
            app.renderLayerAlpha(layerIndex, forceRender);
        end

        function flushPendingAlphaUpdates(app)
            layerIndices = find(app.PendingAlphaMask);
            for layerIndex = reshape(layerIndices, 1, [])
                app.renderLayerAlpha(layerIndex, true);
            end
        end

        function renderLayerAlpha(app, layerIndex, isFinal)
            frameTimer = app.beginPerformanceFrame();
            alpha = app.Scene.layers(layerIndex).Alpha;
            previousAlpha = app.RenderedLayerAlphas(layerIndex);
            app.setLayerSurfaceAlpha(layerIndex, alpha);
            app.RenderedLayerAlphas(layerIndex) = alpha;
            app.PendingAlphaMask(layerIndex) = false;
            if isFinal
                app.PerformanceMonitor.increment("AlphaFinalizations");
            end
            drawnow limitrate
            app.finishPerformanceFrame(frameTimer, "AlphaSeconds");
            app.AlphaPreviewTimer = tic;
            if previousAlpha == 0 && alpha > 0 && ...
                    app.usesTiledPreview(layerIndex)
                app.scheduleCameraReconciliation();
            end
        end

        function updateAlphaLabel(app, alpha)
            app.AlphaLabel.Text = sprintf("Alpha %.2f", alpha);
        end

        function resetAlphaRuntimeState(app)
            app.RenderedLayerAlphas = [app.Scene.layers.Alpha];
            app.PendingAlphaMask = false(1, numel(app.Scene.layers));
            app.AlphaPreviewTimer = [];
        end

        function updateProjection(app, tipDegrees, tiltDegrees, alpha, meshSamplings)
            frameTimer = app.beginPerformanceFrame();
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
            app.invalidatePreviewGeometry(1:numel(app.Scene.layers));

            for layerIndex = 1:numel(app.Scene.layers)
                app.PerformanceMonitor.increment("LayerGeometryRefreshes");
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

                mesh = app.buildInstrumentedLayerMesh( ...
                    layerIndex, layer, plane);
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
            app.finishPerformanceFrame(frameTimer, "ProjectionSeconds");
        end

        function updateSelectedLayerProjection( ...
                app, layerIndex, meshSamplings)
            frameTimer = app.beginPerformanceFrame();
            app.refreshProjectionLayers( ...
                layerIndex, meshSamplings, ...
                isequal(meshSamplings, app.DefaultMeshSampling));
            layer = app.Scene.layers(layerIndex);
            app.updateLabels(app.ProjectionTipDegrees, ...
                app.ProjectionTiltDegrees, app.ViewTwistDegrees, layer.Alpha);
            drawnow limitrate
            app.finishPerformanceFrame(frameTimer, "ProjectionSeconds");
        end

        function refreshProjectionSurfaces(app, meshSamplings)
            if nargin < 2
                meshSamplings = app.DefaultMeshSampling;
            end

            app.refreshProjectionLayers( ...
                1:numel(app.Scene.layers), meshSamplings, true);
        end

        function refreshProjectionLayers(app, layerIndices, ...
                meshSamplings, refreshOverlays)
            if nargin < 3
                meshSamplings = app.DefaultMeshSampling;
            end
            if nargin < 4
                refreshOverlays = true;
            end
            layerIndices = unique(double(layerIndices(:).'), "stable");
            if isempty(layerIndices)
                return
            end

            plane = app.currentProjectionPlane();
            app.invalidatePreviewGeometry(layerIndices);
            for layerIndex = layerIndices
                app.PerformanceMonitor.increment("LayerGeometryRefreshes");
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

                mesh = app.buildInstrumentedLayerMesh( ...
                    layerIndex, layer, plane);
                app.updateSurfaceFromMesh(layerIndex, mesh);
                if layerIndex == app.SelectedLayerIndex
                    app.CurrentMesh = mesh;
                    app.Surface = app.primarySurfaceForLayer(layerIndex);
                end
            end

            if refreshOverlays && ...
                    isequal(meshSamplings, app.DefaultMeshSampling)
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
            surfaceHandle.Visible = app.onOff( ...
                app.previewSurfaceIsVisible(mesh.Visible, mesh.Alpha));
        end

        function maxVertices = previewTileMeshVertexLimit(app, meshSamplings)
            maxVertices = app.PreviewTilingOptions.MaxTileMeshVertices;
            if isequal(meshSamplings, app.DragMeshSampling)
                maxVertices = min(maxVertices, app.InteractivePreviewMaxTileMeshVertices);
            end
        end

        function updateAllSurfaceBlendAppearance(app)
            visibleMask = app.effectiveLayerVisibilityMask();
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
                surfaceHandle.Visible = app.onOff( ...
                    app.previewSurfaceIsVisible( ...
                    visibleMask(layerIndex), layer.Alpha));
            end
        end

        function updateTiledLayerSurfaceAppearance(app, layerIndex)
            tiles = app.currentPreviewTilesForLayer(layerIndex);
            surfaceHandles = app.validLayerSurfaces(layerIndex);
            if isempty(tiles) || numel(surfaceHandles) ~= numel(tiles)
                app.replaceTiledLayerSurfaces(layerIndex);
                return
            end

            visibleMask = app.effectiveLayerVisibilityMask();
            for tileIndex = 1:numel(tiles)
                tileData = app.preparedPreviewTileData( ...
                    layerIndex, tiles(tileIndex), ...
                    app.PreviewTilingOptions.MaxTileMeshVertices);
                layer = app.Scene.layers(layerIndex);
                surfaceHandles(tileIndex).CData = app.previewTextureForLayer( ...
                    tileData.DisplayTexture, layerIndex);
                surfaceHandles(tileIndex).FaceAlpha = app.previewFaceAlphaForLayer( ...
                    layer.Alpha, layerIndex);
                surfaceHandles(tileIndex).Visible = app.onOff( ...
                    app.previewSurfaceIsVisible( ...
                    visibleMask(layerIndex), layer.Alpha));
            end
        end

        function texture = previewTextureForLayer(app, texture, layerIndex)
            layer = app.Scene.layers(layerIndex);
            if app.MotionRuntime.Active
                return
            end
            if lower(string(layer.BlendMode)) ~= "redblueanaglyph"
                return
            end

            gray = app.normalizedGrayscaleDisplayTexture(texture);
            texture = app.AnaglyphOffChannelFloor * ...
                ones([size(gray, 1), size(gray, 2), 3], "single");
            channelIndex = app.anaglyphChannelForLayer(layerIndex);
            texture(:, :, channelIndex) = min(1, ...
                app.AnaglyphOffChannelFloor + ...
                app.AnaglyphChannelGain * gray);
        end

        function alpha = previewFaceAlphaForLayer(app, alpha, layerIndex)
            layer = app.Scene.layers(layerIndex);
            if app.MotionRuntime.Active
                return
            end
            if lower(string(layer.BlendMode)) == "redblueanaglyph" && ...
                    app.visibleAnaglyphLayerCount() > 1
                alpha = min(alpha, app.AnaglyphPreviewFaceAlpha);
            end
        end

        function tf = previewSurfaceIsVisible(~, isVisible, alpha)
            tf = logical(isVisible) && alpha > 0;
        end

        function channelIndex = anaglyphChannelForLayer(app, layerIndex)
            channelAssignments = app.anaglyphChannelAssignments();
            channelIndex = channelAssignments(layerIndex);
            if channelIndex == 0
                channelIndex = 1;
            end
        end

        function channelAssignments = anaglyphChannelAssignments(app)
            channelAssignments = zeros(1, numel(app.Scene.layers));
            anaglyphLayers = app.visibleAnaglyphLayerIndices();
            for ordinal = 1:numel(anaglyphLayers)
                channelAssignments(anaglyphLayers(ordinal)) = ...
                    1 + 2 * double(mod(ordinal, 2) == 0);
            end
            if numel(anaglyphLayers) ~= 2
                return
            end
            viewIds = ProjectionViewMetadata.ids(app.Scene);
            visibleViewIds = viewIds(anaglyphLayers);
            identity = ProjectionViewMetadata.pairIdentity( ...
                visibleViewIds(1), visibleViewIds(2));
            origins = app.layerViewOrigins(anaglyphLayers);
            if any(~isfinite(origins), "all")
                return
            end
            assignment = app.StereoEyeController.resolve( ...
                identity.PairId, visibleViewIds, ...
                origins, ...
                app.anaglyphPresentationRightVector());
            leftIndex = find(visibleViewIds == assignment.LeftViewId, ...
                1, "first");
            rightIndex = find(visibleViewIds == assignment.RightViewId, ...
                1, "first");
            channelAssignments(anaglyphLayers(leftIndex)) = 1;
            channelAssignments(anaglyphLayers(rightIndex)) = 3;
        end

        function assignment = activeStereoEyeAssignment(app)
            inputs = app.activeStereoEyeInputs();
            if ~inputs.Available
                assignment = struct( ...
                    PairId="", LeftViewId="", RightViewId="", ...
                    RedViewId="", CyanViewId="", Mode="unavailable", ...
                    Status="unavailable", IsDegenerate=false, ...
                    ProjectionRatio=NaN, ...
                    HysteresisRatio=app.StereoEyeController.HysteresisRatio, ...
                    ManualOverride=false);
                return
            end
            assignment = app.StereoEyeController.resolve( ...
                inputs.PairId, inputs.ViewIds, inputs.Origins, ...
                inputs.CameraRightVector);
        end

        function inputs = activeStereoEyeInputs(app)
            inputs = struct(Available=false, PairId="", ...
                ViewIds=strings(1, 0), Origins=zeros(3, 0), ...
                CameraRightVector=zeros(3, 1));
            pair = app.AlignmentPairController.currentPair();
            if ~isfield(pair, "ViewsAvailable") || ~pair.ViewsAvailable
                return
            end
            layerIndices = [pair.ReferenceLayerIndex pair.MovingLayerIndex];
            origins = app.layerViewOrigins(layerIndices);
            if any(~isfinite(origins), "all")
                return
            end
            inputs.Available = true;
            inputs.PairId = pair.PairId;
            inputs.ViewIds = [pair.ReferenceViewId pair.MovingViewId];
            inputs.Origins = origins;
            inputs.CameraRightVector = ...
                app.anaglyphPresentationRightVector();
        end

        function count = visibleAnaglyphLayerCount(app)
            count = numel(app.visibleAnaglyphLayerIndices());
        end

        function layerIndices = visibleAnaglyphLayerIndices(app)
            layerIndices = find(app.effectiveLayerVisibilityMask() & ...
                lower(string([app.Scene.layers.BlendMode])) == ...
                "redblueanaglyph");
        end

        function gray = normalizedGrayscaleDisplayTexture(~, texture)
            if ismatrix(texture)
                gray = texture;
            elseif isinteger(texture)
                gray = cast(round(mean(double(texture), 3)), class(texture));
            elseif islogical(texture)
                gray = any(texture, 3);
            else
                gray = mean(texture, 3);
            end
            if isinteger(gray)
                gray = single(gray) / single(intmax(class(gray)));
            elseif islogical(gray)
                gray = single(gray);
            else
                gray = single(gray);
                gray = min(max(gray, 0), 1);
            end
        end

        function [X, Y, Z] = previewSurfaceCoordinates(app, mesh, layerIndex)
            offset = app.previewLayerDepthOffset(layerIndex) + ...
                app.anaglyphPresentationOffset(layerIndex);
            X = mesh.X + offset(1);
            Y = mesh.Y + offset(2);
            Z = mesh.Z + offset(3);
        end

        function offset = anaglyphPresentationOffset(app, layerIndex)
            offset = zeros(3, 1);
            if abs(app.AnaglyphStereoExaggeration - 1) <= eps && ...
                    abs(app.AnaglyphScreenDepthOffsetMeters) <= eps
                return
            end
            if lower(string(app.Scene.layers(layerIndex).BlendMode)) ~= ...
                    "redblueanaglyph" || app.visibleAnaglyphLayerCount() ~= 2
                return
            end

            rightVector = app.anaglyphPresentationRightVector();
            channelIndex = app.anaglyphChannelForLayer(layerIndex);
            eyeSign = -1 + 2 * double(channelIndex == 3);
            [viewWidth, ~] = app.cameraViewWorldSize();
            separationShift = (app.AnaglyphStereoExaggeration - 1) * ...
                app.AnaglyphStereoBaseSeparationFraction * viewWidth;
            parallaxShift = eyeSign * (separationShift + ...
                app.AnaglyphScreenDepthOffsetMeters);
            offset = parallaxShift * rightVector;
        end

        function offsets = anaglyphPresentationOffsets(app)
            offsets = zeros(3, numel(app.Scene.layers));
            for layerIndex = 1:numel(app.Scene.layers)
                offsets(:, layerIndex) = ...
                    app.anaglyphPresentationOffset(layerIndex);
            end
        end

        function applyAnaglyphPresentationOffsetDelta(app, oldOffsets)
            newOffsets = app.anaglyphPresentationOffsets();
            if ~isequal(size(oldOffsets), size(newOffsets))
                return
            end
            for layerIndex = 1:numel(app.Scene.layers)
                delta = newOffsets(:, layerIndex) - ...
                    oldOffsets(:, layerIndex);
                if norm(delta) <= eps
                    continue
                end
                surfaceHandles = app.validLayerSurfaces(layerIndex);
                for surfaceIndex = 1:numel(surfaceHandles)
                    surfaceHandle = surfaceHandles(surfaceIndex);
                    surfaceHandle.XData = surfaceHandle.XData + delta(1);
                    surfaceHandle.YData = surfaceHandle.YData + delta(2);
                    surfaceHandle.ZData = surfaceHandle.ZData + delta(3);
                end
            end
        end

        function origins = layerViewOrigins(app, layerIndices)
            origins = zeros(3, numel(layerIndices));
            for k = 1:numel(layerIndices)
                layer = app.Scene.layers(layerIndices(k));
                sourceGeometry = layer.SourceGeometry;
                origin = [NaN; NaN; NaN];
                if isfield(sourceGeometry, "ReferenceOrigin") && ...
                        isnumeric(sourceGeometry.ReferenceOrigin) && ...
                        numel(sourceGeometry.ReferenceOrigin) == 3
                    origin = sourceGeometry.ReferenceOrigin;
                elseif isfield(sourceGeometry, "Origins") && ...
                        isnumeric(sourceGeometry.Origins) && ...
                        size(sourceGeometry.Origins, 1) == 3
                    origin = mean(double(sourceGeometry.Origins), 2);
                elseif isfield(sourceGeometry, "ViewVectorOrigins") && ...
                        isnumeric(sourceGeometry.ViewVectorOrigins) && ...
                        size(sourceGeometry.ViewVectorOrigins, 1) == 3
                    origin = mean(double(sourceGeometry.ViewVectorOrigins), 2);
                end
                origins(:, k) = double(origin(:));
            end
        end

        function rightVector = anaglyphPresentationRightVector(app)
            if ~isempty(app.Axes) && isvalid(app.Axes) && ...
                    app.IsPreviewCameraReady
                viewDirection = camtarget(app.Axes).' - campos(app.Axes).';
                if norm(viewDirection) > 0
                    viewDirection = viewDirection / norm(viewDirection);
                    upVector = camup(app.Axes).';
                    if norm(upVector) > 0
                        upVector = upVector / norm(upVector);
                        rightVector = cross(viewDirection, upVector);
                        if norm(rightVector) > 1e-12
                            rightVector = rightVector / norm(rightVector);
                            return
                        end
                    end
                end
            end
            rightVector = app.Scene.frameCamera.focalPlane.basis(:, 1);
            rightVector = rightVector / norm(rightVector);
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
                            mesh = app.buildInstrumentedLayerMesh( ...
                                layerIndex, layer, plane);
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

        function value = validatePositiveIntegerOption(~, value, name)
            if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value) || ...
                    value < 1 || fix(value) ~= value
                error("ProjectionViewerApp:invalidPreviewCacheOptions", ...
                    "%s must be a positive integer.", name);
            end
            value = double(value);
        end

        function value = validateNonnegativeIntegerOption(~, value, name)
            if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value) || ...
                    value < 0 || fix(value) ~= value
                error("ProjectionViewerApp:invalidPreviewCacheOptions", ...
                    "%s must be a nonnegative integer.", name);
            end
            value = double(value);
        end

        function value = validateNonnegativeScalarOption(~, value, name)
            if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value) || ...
                    value < 0
                error("ProjectionViewerApp:invalidPreviewBudgetOptions", ...
                    "%s must be a nonnegative finite scalar.", name);
            end
            value = double(value);
        end

        function value = validateLogicalOption(~, value, name)
            if ~isscalar(value) || ...
                    ~(islogical(value) || ...
                    (isnumeric(value) && isfinite(value) && ...
                    any(value == [0 1])))
                error("ProjectionViewerApp:invalidPreviewBudgetOptions", ...
                    "%s must be a logical scalar.", name);
            end
            value = logical(value);
        end

        function options = rasterPreviewOptions(app, options)
            if isempty(options)
                options = struct();
            end
            if ~isstruct(options) || ~isscalar(options)
                error("ProjectionViewerApp:invalidRasterPreviewOptions", ...
                    "Raster preview options must be a scalar struct.");
            end
            if ~isfield(options, "OutputSize") || isempty(options.OutputSize)
                axesPosition = app.Axes.InnerPosition;
                options.OutputSize = max(1, round( ...
                    [axesPosition(4), axesPosition(3)]));
            end
        end

        function resetView(app)
            app.exitMotionImagery();
            app.exitAlignmentSoloPair();
            app.cancelCameraReconciliation();
            app.Scene = app.ResetScene;
            app.AlignmentPairController.regenerate(app.Scene);
            app.StereoEyeController = ProjectionStereoEyeController();
            app.PairViewpointRuntime = app.defaultPairViewpointRuntime();
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
            app.AnaglyphStereoExaggeration = 1;
            app.AnaglyphScreenDepthOffsetMeters = 0;
            app.IsControlDown = false;
            app.IsShiftDown = false;
            app.IsAltDown = false;
            app.ViewportKeyboardMode = "normal";
            app.DragMode = "none";
            app.LastPointerLocation = [NaN NaN];
            app.NeedsDragFinalize = false;
            app.AlignmentAnchorDragState = struct();
            app.AlignmentAnchorDragCancelled = false;
            app.IsPreviewCameraReady = false;
            app.clearAlignmentComputationState();
            app.clearAlignmentWorkingImageCache();
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
            oldPresentationOffsets = app.anaglyphPresentationOffsets();
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
            app.applyAnaglyphPresentationOffsetDelta( ...
                oldPresentationOffsets);
            app.updateBlendMenuChecks();
        end

        function adjustAnaglyphStereoExaggeration(app, direction)
            direction = sign(double(direction));
            if direction == 0
                return
            end
            oldPresentationOffsets = app.anaglyphPresentationOffsets();
            limits = app.AnaglyphStereoExaggerationLimits;
            app.AnaglyphStereoExaggeration = min(max( ...
                app.AnaglyphStereoExaggeration + ...
                direction * app.AnaglyphStereoExaggerationStep, ...
                limits(1)), limits(2));
            app.applyAnaglyphPresentationOffsetDelta( ...
                oldPresentationOffsets);
            app.updateAnaglyphPresentationMenuText();
            drawnow limitrate
        end

        function adjustAnaglyphScreenDepthOffset(app, direction)
            direction = sign(double(direction));
            if direction == 0
                return
            end
            oldPresentationOffsets = app.anaglyphPresentationOffsets();
            app.AnaglyphScreenDepthOffsetMeters = ...
                app.AnaglyphScreenDepthOffsetMeters + ...
                direction * app.anaglyphScreenDepthStepMeters();
            app.applyAnaglyphPresentationOffsetDelta( ...
                oldPresentationOffsets);
            app.updateAnaglyphPresentationMenuText();
            drawnow limitrate
        end

        function resetAnaglyphPresentation(app)
            oldPresentationOffsets = app.anaglyphPresentationOffsets();
            app.AnaglyphStereoExaggeration = 1;
            app.AnaglyphScreenDepthOffsetMeters = 0;
            app.applyAnaglyphPresentationOffsetDelta( ...
                oldPresentationOffsets);
            app.updateAnaglyphPresentationMenuText();
            drawnow limitrate
        end

        function stepMeters = anaglyphScreenDepthStepMeters(app)
            if ~isempty(app.Axes) && isvalid(app.Axes) && ...
                    app.IsPreviewCameraReady
                viewDistance = norm(camtarget(app.Axes).' - campos(app.Axes).');
                axesPosition = app.Axes.InnerPosition;
                viewHeight = 2 * viewDistance * tan( ...
                    deg2rad(app.Axes.CameraViewAngle) / 2);
                viewWidth = viewHeight * max(axesPosition(3), 1) / ...
                    max(axesPosition(4), 1);
                stepMeters = app.AnaglyphScreenDepthStepFraction * viewWidth;
            else
                stepMeters = app.AnaglyphScreenDepthStepFraction * ...
                    app.frameCameraRange();
            end
            stepMeters = max(stepMeters, eps);
        end

        function cycleLayer(app)
            oldPresentationOffsets = app.anaglyphPresentationOffsets();
            nextLayerIndex = mod(app.SelectedLayerIndex, numel(app.Scene.layers)) + 1;
            for layerIndex = 1:numel(app.Scene.layers)
                layer = app.Scene.layers(layerIndex);
                layer.Visible = layerIndex == nextLayerIndex;
                app.Scene.layers(layerIndex) = layer;
                app.setLayerSurfaceVisible(layerIndex, layer.Visible);
            end
            if app.usesTiledPreview(nextLayerIndex)
                app.refreshTiledLayerSurfaces(nextLayerIndex);
            end
            app.updateAllSurfaceBlendAppearance();
            app.applyAnaglyphPresentationOffsetDelta( ...
                oldPresentationOffsets);
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

            priorScene = app.Scene;
            [referenceLayerId, movingLayerId] = ...
                app.currentAlignmentDropDownLayerIds(priorScene);
            swapIndices = [app.SelectedLayerIndex targetIndex];
            app.Scene.layers(swapIndices) = app.Scene.layers(fliplr(swapIndices));
            app.DefaultMeshSampling(swapIndices) = ...
                app.DefaultMeshSampling(fliplr(swapIndices));
            app.DragMeshSampling(swapIndices) = ...
                app.DragMeshSampling(fliplr(swapIndices));
            app.PreviewPyramids(swapIndices) = ...
                app.PreviewPyramids(fliplr(swapIndices));
            app.PreviewGeometryCaches(swapIndices) = ...
                app.PreviewGeometryCaches(fliplr(swapIndices));
            app.PreviewGeometryGenerations(swapIndices) = ...
                app.PreviewGeometryGenerations(fliplr(swapIndices));
            app.PreviewTiledLayerMask(swapIndices) = ...
                app.PreviewTiledLayerMask(fliplr(swapIndices));
            app.PreviewTileKeys(swapIndices) = ...
                app.PreviewTileKeys(fliplr(swapIndices));
            app.PreviewCurrentLevelIndices(swapIndices) = ...
                app.PreviewCurrentLevelIndices(fliplr(swapIndices));
            app.PreviewDesiredLevelIndices(swapIndices) = ...
                app.PreviewDesiredLevelIndices(fliplr(swapIndices));
            app.PreviewDesiredDownsamples(swapIndices) = ...
                app.PreviewDesiredDownsamples(fliplr(swapIndices));
            app.PreviewDesiredDownsamplesPerAxis(swapIndices, :) = ...
                app.PreviewDesiredDownsamplesPerAxis(fliplr(swapIndices), :);
            app.PreviewPendingLevelIndices(swapIndices) = ...
                app.PreviewPendingLevelIndices(fliplr(swapIndices));
            app.PreviewPredictedCandidateCounts(swapIndices) = ...
                app.PreviewPredictedCandidateCounts(fliplr(swapIndices));
            app.PreviewPredictedVisibleTileCounts(swapIndices) = ...
                app.PreviewPredictedVisibleTileCounts(fliplr(swapIndices));
            app.PreviewPredictedTextureBytes(swapIndices) = ...
                app.PreviewPredictedTextureBytes(fliplr(swapIndices));
            app.PreviewLayerSurfaceBudgets(swapIndices) = ...
                app.PreviewLayerSurfaceBudgets(fliplr(swapIndices));
            app.PreviewLayerTextureBudgets(swapIndices) = ...
                app.PreviewLayerTextureBudgets(fliplr(swapIndices));
            app.PreviewBudgetLimitedLayerMask(swapIndices) = ...
                app.PreviewBudgetLimitedLayerMask(fliplr(swapIndices));
            app.RenderedLayerAlphas(swapIndices) = ...
                app.RenderedLayerAlphas(fliplr(swapIndices));
            app.PendingAlphaMask(swapIndices) = ...
                app.PendingAlphaMask(fliplr(swapIndices));
            app.PreviewTileDataCache.clear();
            app.PreviewSampledGeometryCache.clear();
            app.SelectedLayerIndex = targetIndex;
            app.reindexAlignmentSessionAfterLayerReorder(priorScene);
            app.reindexAlignmentPairTableAfterLayerReorder(priorScene);
            app.restoreAlignmentDropDownLayerIds( ...
                referenceLayerId, movingLayerId);
            app.refreshProjectionSurfaces(app.DefaultMeshSampling);
            app.updateLayerDropDownItems();
            app.updateControlsFromSelectedLayer();
            app.refreshAlignmentSessionViewsAfterLayerReorder();
            if ProjectionSoloPairVisibility.isActive(app.AlignmentSoloState)
                app.applyAlignmentSoloPresentation();
            end
        end

        function [referenceLayerId, movingLayerId] = ...
                currentAlignmentDropDownLayerIds(app, scene)
            referenceLayerId = "";
            movingLayerId = "";
            if isempty(app.AlignmentReferenceDropDown) || ...
                    ~isvalid(app.AlignmentReferenceDropDown)
                return
            end
            referenceIndex = app.validAlignmentLayerValue( ...
                app.AlignmentReferenceDropDown.Value, 1);
            movingIndex = app.validAlignmentLayerValue( ...
                app.AlignmentMovingDropDown.Value, numel(scene.layers));
            referenceLayerId = string(scene.layers(referenceIndex).LayerId);
            movingLayerId = string(scene.layers(movingIndex).LayerId);
        end

        function restoreAlignmentDropDownLayerIds(app, referenceLayerId, movingLayerId)
            if isempty(app.AlignmentReferenceDropDown) || ...
                    ~isvalid(app.AlignmentReferenceDropDown)
                return
            end
            if strlength(referenceLayerId) > 0
                app.AlignmentReferenceDropDown.Value = string( ...
                    ProjectionLayerIdentity.indexForId( ...
                    app.Scene, referenceLayerId));
            end
            if strlength(movingLayerId) > 0
                app.AlignmentMovingDropDown.Value = string( ...
                    ProjectionLayerIdentity.indexForId( ...
                    app.Scene, movingLayerId));
            end
        end

        function reindexAlignmentSessionAfterLayerReorder(app, priorScene)
            propertyNames = ["AlignmentRequest", "AlignmentWorkingImages", ...
                "AlignmentRawMatchResult", "AlignmentPreRoiMatchResult", ...
                "AlignmentFilteredMatchResult", "AlignmentResult"];
            for propertyName = propertyNames
                value = app.(propertyName);
                if isstruct(value) && ~isempty(fieldnames(value))
                    app.(propertyName) = ProjectionAlignmentLayerResolver.reindex( ...
                        app.Scene, value, priorScene);
                end
            end
        end

        function reindexAlignmentPairTableAfterLayerReorder(app, priorScene)
            if isempty(app.AlignmentPairTable) || ...
                    ~isvalid(app.AlignmentPairTable)
                return
            end
            data = app.AlignmentPairTable.Data;
            requiredVariables = ["Pair", "Moving", "Reference"];
            if ~istable(data) || ~all(ismember(requiredVariables, ...
                    string(data.Properties.VariableNames)))
                return
            end
            for rowIndex = 1:height(data)
                oldPair = app.pairFromKey(data.Pair(rowIndex));
                pairRecord = struct(Pair=oldPair, ...
                    PairLayerIds=ProjectionLayerIdentity.idsForIndices( ...
                    priorScene, oldPair));
                newPair = ProjectionAlignmentLayerResolver.pairIndices( ...
                    app.Scene, pairRecord, priorScene);
                data.Pair(rowIndex) = app.pairKey(newPair);
                data.Moving(rowIndex) = newPair(1);
                data.Reference(rowIndex) = newPair(2);
            end
            app.AlignmentPairTable.Data = data;
        end

        function refreshAlignmentSessionViewsAfterLayerReorder(app)
            if app.hasMatchResult(app.AlignmentFilteredMatchResult)
                app.updateAlignmentMatchTable( ...
                    app.AlignmentFilteredMatchResult, app.AlignmentResult);
            elseif app.hasMatchResult(app.AlignmentRawMatchResult)
                app.updateAlignmentMatchTable(app.AlignmentRawMatchResult, []);
            end
            if app.hasScalarStruct(app.AlignmentWorkingImages) && ...
                    isfield(app.AlignmentWorkingImages, "Schedule")
                schedule = app.AlignmentWorkingImages.Schedule;
                app.updateAlignmentPairTable(schedule, ...
                    app.enabledAlignmentPairs(schedule), ...
                    app.AlignmentRawMatchResult, ...
                    app.AlignmentFilteredMatchResult);
            else
                app.refreshAlignmentPairTable();
            end
            app.refreshAlignmentOverlays(true);
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
            isVisible = logical(isVisible);
            if layer.Visible == isVisible
                app.VisibleCheckBox.Value = layer.Visible;
                return
            end
            oldPresentationOffsets = app.anaglyphPresentationOffsets();
            layer.Visible = isVisible;
            app.Scene.layers(layerIndex) = layer;
            if isVisible && app.usesTiledPreview(layerIndex)
                app.refreshTiledLayerSurfaces(layerIndex);
            end
            if app.layerVisibilityRequiresBlendRefresh(layerIndex)
                app.updateAllSurfaceBlendAppearance();
            else
                app.setLayerSurfaceVisible(layerIndex, layer.Visible);
            end
            app.applyAnaglyphPresentationOffsetDelta( ...
                oldPresentationOffsets);
            app.VisibleCheckBox.Value = layer.Visible;
            app.updateBlendMenuChecks();
        end

        function tf = layerVisibilityRequiresBlendRefresh(app, layerIndex)
            blendMode = lower(string(app.Scene.layers(layerIndex).BlendMode));
            tf = blendMode == "redblueanaglyph";
        end

        function updateBlendMenuChecks(app)
            if isempty(app.AlphaBlendMenuItem) || ~isvalid(app.AlphaBlendMenuItem)
                return
            end

            visibleModes = app.visibleBlendModes();
            app.AlphaBlendMenuItem.Checked = app.onOff(all(visibleModes == "alpha"));
            app.AnaglyphBlendMenuItem.Checked = ...
                app.onOff(all(visibleModes == "redBlueAnaglyph"));
            app.updateAnaglyphPresentationMenuText();
        end

        function updateAnaglyphPresentationMenuText(app)
            if isempty(app.AnaglyphControlsMenu) || ...
                    ~isvalid(app.AnaglyphControlsMenu)
                return
            end
            app.AnaglyphControlsMenu.Text = sprintf( ...
                "Anaglyph presentation (%.2fx, %.3g m)", ...
                app.AnaglyphStereoExaggeration, ...
                app.AnaglyphScreenDepthOffsetMeters);
            app.AnaglyphControlsMenu.Enable = app.onOff( ...
                app.visibleAnaglyphLayerCount() == 2);
        end

        function modes = visibleBlendModes(app)
            visibleMask = app.effectiveLayerVisibilityMask();
            if ~any(visibleMask)
                visibleMask(app.SelectedLayerIndex) = true;
            end
            modes = string([app.Scene.layers(visibleMask).BlendMode]);
        end

        function runtime = viewerPerformanceRuntimeState(app)
            layerCount = numel(app.Scene.layers);
            imageSizes = zeros(layerCount, 3);
            currentLevelIndices = app.PreviewCurrentLevelIndices;
            currentDownsamples = ones(1, layerCount);
            currentTileCounts = zeros(1, layerCount);
            fullLevelCandidateCounts = zeros(1, layerCount);
            visibleSurfaceCount = 0;
            visibleTileSurfaceCount = 0;
            visibleTexturePixels = 0;
            visibleTextureBytes = 0;
            pyramidMaterializedLevelCounts = zeros(1, layerCount);
            pyramidMaterializedBytes = zeros(1, layerCount);
            pyramidAdditionalBytes = zeros(1, layerCount);
            pyramidSourceModes = strings(1, layerCount);
            pyramidLevelCounts = zeros(1, layerCount);

            for layerIndex = 1:layerCount
                storage = ProjectionPreviewPyramid.storageDiagnostics( ...
                    app.PreviewPyramids{layerIndex});
                pyramidMaterializedLevelCounts(layerIndex) = ...
                    storage.MaterializedLevelCount;
                pyramidMaterializedBytes(layerIndex) = ...
                    storage.MaterializedBytes;
                pyramidAdditionalBytes(layerIndex) = ...
                    storage.AdditionalMaterializedBytes;
                pyramidSourceModes(layerIndex) = storage.SourceMode;
                pyramidLevelCounts(layerIndex) = storage.LevelCount;
                imageData = app.Scene.layers(layerIndex).Image;
                imageSizes(layerIndex, :) = [size(imageData, 1), ...
                    size(imageData, 2), size(imageData, 3)];
                tiles = app.currentPreviewTilesForLayer(layerIndex);
                currentTileCounts(layerIndex) = numel(tiles);
                currentLevelIndex = currentLevelIndices(layerIndex);
                if currentLevelIndex > 0
                    currentDownsamples(layerIndex) = ...
                        app.PreviewPyramids{layerIndex}.Levels( ...
                        currentLevelIndex).Downsample;
                end
                if ~isempty(tiles)
                    levelSize = app.PreviewPyramids{layerIndex}.Levels( ...
                        currentLevelIndex).ImageSize;
                    tileSize = app.PreviewTilingOptions.TileSize;
                    fullLevelCandidateCounts(layerIndex) = ...
                        prod(ceil(double(levelSize) / tileSize));
                elseif ~app.usesTiledPreview(layerIndex)
                    currentLevelIndices(layerIndex) = 1;
                    fullLevelCandidateCounts(layerIndex) = 1;
                end

                surfaceHandles = app.validLayerSurfaces(layerIndex);
                for surfaceIndex = 1:numel(surfaceHandles)
                    surfaceHandle = surfaceHandles(surfaceIndex);
                    if string(surfaceHandle.Visible) ~= "on"
                        continue
                    end
                    visibleSurfaceCount = visibleSurfaceCount + 1;
                    if string(surfaceHandle.Tag) == ...
                            "ProjectionViewerPreviewTileSurface"
                        visibleTileSurfaceCount = visibleTileSurfaceCount + 1;
                    end
                    texture = surfaceHandle.CData;
                    visibleTexturePixels = visibleTexturePixels + ...
                        size(texture, 1) * size(texture, 2);
                    visibleTextureBytes = visibleTextureBytes + ...
                        app.arrayBytes(texture);
                end
            end

            runtime = struct();
            runtime.LayerCount = layerCount;
            runtime.ImageSizes = imageSizes;
            runtime.VisibleLayerCount = nnz([app.Scene.layers.Visible]);
            runtime.CameraViewAngleDegrees = app.Axes.CameraViewAngle;
            runtime.DisplayTileSize = app.PreviewTilingOptions.TileSize;
            runtime.PyramidSourceModes = pyramidSourceModes;
            runtime.PyramidLevelCounts = pyramidLevelCounts;
            runtime.PyramidMaterializedLevelCounts = ...
                pyramidMaterializedLevelCounts;
            runtime.PyramidMaterializedBytes = pyramidMaterializedBytes;
            runtime.PyramidMaterializedBytesTotal = ...
                sum(pyramidMaterializedBytes);
            runtime.PyramidAdditionalMaterializedBytes = ...
                pyramidAdditionalBytes;
            runtime.PyramidAdditionalMaterializedBytesTotal = ...
                sum(pyramidAdditionalBytes);
            runtime.CurrentLevelIndices = currentLevelIndices;
            runtime.DesiredLevelIndices = app.PreviewDesiredLevelIndices;
            runtime.DesiredDownsamples = app.PreviewDesiredDownsamples;
            runtime.DesiredDownsamplesPerAxis = ...
                app.PreviewDesiredDownsamplesPerAxis;
            runtime.PendingLevelIndices = app.PreviewPendingLevelIndices;
            runtime.CurrentDownsamples = currentDownsamples;
            runtime.LevelTexelsPerScreenPixel = ...
                app.PreviewDesiredDownsamplesPerAxis ./ ...
                max(currentDownsamples(:), eps);
            runtime.CurrentTileCounts = currentTileCounts;
            runtime.FullLevelCandidateCounts = fullLevelCandidateCounts;
            runtime.PredictedCandidateCounts = ...
                app.PreviewPredictedCandidateCounts;
            runtime.PredictedVisibleTileCounts = ...
                app.PreviewPredictedVisibleTileCounts;
            runtime.PredictedTextureBytes = app.PreviewPredictedTextureBytes;
            runtime.LayerSurfaceBudgets = app.PreviewLayerSurfaceBudgets;
            runtime.LayerTextureBudgets = app.PreviewLayerTextureBudgets;
            runtime.BudgetLimitedLayerMask = ...
                app.PreviewBudgetLimitedLayerMask;
            runtime.VisibleSurfaceCount = visibleSurfaceCount;
            runtime.VisibleTileSurfaceCount = visibleTileSurfaceCount;
            runtime.VisibleTexturePixels = visibleTexturePixels;
            runtime.VisibleTextureBytes = visibleTextureBytes;
            runtime.CameraReconcilePending = ...
                app.IsCameraReconciliationPending;
            runtime.CameraScheduleGeneration = ...
                double(app.CameraScheduleGeneration);
            runtime.CameraSettleDelaySeconds = app.CameraSettleDelaySeconds;
            runtime.LodPromoteThreshold = app.PreviewLodPromoteThreshold;
            runtime.LodDemoteThreshold = app.PreviewLodDemoteThreshold;
            runtime.ViewportHaloFraction = app.PreviewViewportHaloFraction;
            runtime.GlobalPreviewBudget = struct( ...
                MaxVisibleSurfaces=app.PreviewMaxVisibleSurfaces, ...
                MaxVisibleTextureBytes= ...
                app.PreviewMaxVisibleTextureBytes, ...
                TargetMaxTilesPerLayer= ...
                app.PreviewTargetMaxTilesPerLayer, ...
                AutomaticTilePolicy=app.PreviewAutomaticTilePolicy);
            runtime.AlphaPreviewMinIntervalSeconds = ...
                app.AlphaPreviewMinIntervalSeconds;
            runtime.RenderedLayerAlphas = app.RenderedLayerAlphas;
            runtime.PendingAlphaMask = app.PendingAlphaMask;
            runtime.AlignmentControlsCreated = ...
                ~isempty(app.AlignmentLauncherGrid) && ...
                isvalid(app.AlignmentLauncherGrid);
            runtime.AlignmentWorkbenchCreated = ...
                ~isempty(app.AlignmentWorkbenchFigure) && ...
                isvalid(app.AlignmentWorkbenchFigure);
            runtime.AlignmentTableCount = nnz([ ...
                ~isempty(app.AlignmentPairTable) && ...
                isvalid(app.AlignmentPairTable), ...
                ~isempty(app.AlignmentMatchTable) && ...
                isvalid(app.AlignmentMatchTable)]);
            runtime.TileDataCache = app.PreviewTileDataCache.diagnostics();
            runtime.SampledGeometryCache = ...
                app.PreviewSampledGeometryCache.diagnostics();
            runtime.SurfacePoolCount = numel(app.validPreviewSurfacePool());
            runtime.SurfacePoolLimit = app.PreviewSurfacePoolMaxCount;
            runtime.Motion = struct(Active=app.MotionRuntime.Active, ...
                Playing=app.MotionRuntime.Playing, ...
                LookaheadCount=double(isstruct(app.MotionRuntime.Lookahead) && ...
                isfield(app.MotionRuntime.Lookahead, "Available") && ...
                app.MotionRuntime.Lookahead.Available), ...
                LookaheadLimit=1);
        end

        function bytes = arrayBytes(~, value)
            switch class(value)
                case {"logical", "uint8", "int8"}
                    bytesPerElement = 1;
                case {"uint16", "int16"}
                    bytesPerElement = 2;
                case {"uint32", "int32", "single"}
                    bytesPerElement = 4;
                case {"uint64", "int64", "double"}
                    bytesPerElement = 8;
                otherwise
                    info = whos("value");
                    bytes = double(info.bytes);
                    return
            end
            bytes = double(numel(value)) * bytesPerElement;
        end

        function bytes = imageClassBytes(~, imageClass)
            switch string(imageClass)
                case {"logical", "uint8", "int8"}
                    bytes = 1;
                case {"uint16", "int16"}
                    bytes = 2;
                case {"uint32", "int32", "single"}
                    bytes = 4;
                case {"uint64", "int64", "double"}
                    bytes = 8;
                otherwise
                    error("ProjectionViewerApp:unsupportedImageClass", ...
                        "Unsupported preview image class %s.", imageClass);
            end
        end

        function frameTimer = beginPerformanceFrame(app)
            app.PerformanceMonitor.increment("FrameRequests");
            frameTimer = tic;
        end

        function finishPerformanceFrame(app, frameTimer, timingName)
            durationSeconds = toc(frameTimer);
            app.PerformanceMonitor.increment("RenderedFrames");
            app.PerformanceMonitor.recordTiming("FrameSeconds", durationSeconds);
            app.PerformanceMonitor.recordTiming(timingName, durationSeconds);
        end

        function mesh = buildInstrumentedLayerMesh( ...
                app, layerIndex, layer, plane)
            meshTimer = tic;
            app.PerformanceMonitor.increment("MeshBuilds");
            sampledGeometry = app.sampledLayerGeometry(layerIndex, layer);
            mesh = ProjectionMeshBuilder.buildLayerMeshFromSamples( ...
                layer, plane, app.Scene.renderOrigin, sampledGeometry);
            app.PerformanceMonitor.recordTiming( ...
                "MeshBuildSeconds", toc(meshTimer));
        end

        function toggleCrosshair(app)
            app.setCrosshairEnabled(~app.IsCrosshairEnabled);
        end

        function setCrosshairEnabled(app, isEnabled)
            app.IsCrosshairEnabled = logical(isEnabled);
            app.CrosshairMenuItem.Checked = app.onOff(app.IsCrosshairEnabled);
            app.refreshPointerMotionCallback();
            app.updateCrosshair();
        end

        function refreshPointerMotionCallback(app)
            if isempty(app.UIFigure) || ~isvalid(app.UIFigure)
                return
            end
            motionHoverActive = app.MotionRuntime.Active && ...
                app.MotionRuntime.HoverEdges;
            if app.IsCrosshairEnabled || app.DragMode ~= "none" || ...
                    motionHoverActive
                app.UIFigure.WindowButtonMotionFcn = ...
                    @(~, ~) app.pointerMoved();
            else
                app.UIFigure.WindowButtonMotionFcn = [];
            end
        end

        function updateCrosshair(app)
            crosshairTimer = tic;
            app.PerformanceMonitor.increment("CrosshairUpdates");
            if isempty(app.CrosshairHorizontal) || ...
                    ~isvalid(app.CrosshairHorizontal) || ...
                    isempty(app.CrosshairVertical) || ...
                    ~isvalid(app.CrosshairVertical)
                app.PerformanceMonitor.recordTiming( ...
                    "CrosshairSeconds", toc(crosshairTimer));
                return
            end

            if ~app.IsCrosshairEnabled || ~app.isPointerInAxes()
                app.hideCrosshair();
                app.PerformanceMonitor.recordTiming( ...
                    "CrosshairSeconds", toc(crosshairTimer));
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
            app.PerformanceMonitor.increment("CrosshairGeometryUpdates");
            if ~app.IsCrosshairVisible
                app.CrosshairHorizontal.Visible = "on";
                app.CrosshairVertical.Visible = "on";
                app.IsCrosshairVisible = true;
                app.PerformanceMonitor.increment("CrosshairVisibilityUpdates");
            end
            app.PerformanceMonitor.recordTiming( ...
                "CrosshairSeconds", toc(crosshairTimer));
        end

        function hideCrosshair(app)
            if ~app.IsCrosshairVisible
                return
            end
            app.CrosshairHorizontal.Visible = "off";
            app.CrosshairVertical.Visible = "off";
            app.IsCrosshairVisible = false;
            app.PerformanceMonitor.increment("CrosshairVisibilityUpdates");
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
                "Shift + left drag: move the selected accepted stereo anchor with both images"
                "Double left click: show the next layer and hide the others"
                ""
                "Keyboard"
                "Shift + Up/Down arrows: adjust Tip by 0.5 deg"
                "Shift + Left/Right arrows: adjust Tilt by 0.5 deg"
                "Left/Right arrows: select the previous/next layer"
                "Up/Down arrows: nudge the selected layer vertically"
                "Arrow shortcuts require viewport interaction focus"
                "Motion imagery: Left/Right step frames; Up/Down are reserved"
                "Motion imagery: Space toggles 0.5-10 fps Play/Pause"
                "Escape exits motion imagery and restores the prior view"
                "W/A/S/D: nudge the selected layer"
                "I/K: adjust phi"
                "J/L: adjust omega"
                "U/O: adjust kappa"
                "Space down: hide the selected layer"
                "Space up: show the selected layer"
                ""
                "Context menu"
                "Right click inside the image for Save, Load, Cycle, Reset, Help, Crosshair, Alignment panel,"
                "Motion imagery, Clear alignment overlays, and Blend mode."
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

    methods (Static, Access = private)
        function dispatchMotionPlaybackTick(app)
            if ~isempty(app) && isvalid(app)
                app.motionPlaybackTick();
            end
        end

        function dispatchMotionPlaybackError(app, event)
            if ~isempty(app) && isvalid(app)
                app.motionPlaybackTimerFailed(event);
            end
        end
    end
end
