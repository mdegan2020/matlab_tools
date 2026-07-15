classdef ProjectionSurfaceWorkbenchApp < handle
    %ProjectionSurfaceWorkbenchApp Separate floating B6 control workbench.

    properties (Access = private)
        Model ProjectionSurfaceWorkbenchModel
        Runner
        UIFigure matlab.ui.Figure
        GridLayout matlab.ui.container.GridLayout
        NetworkTable matlab.ui.control.Table
        PairScheduleDropDown matlab.ui.control.DropDown
        DenseMethodDropDown matlab.ui.control.DropDown
        GeometrySearchDropDown matlab.ui.control.DropDown
        ExecutionPathDropDown matlab.ui.control.DropDown
        ConsistencyDropDown matlab.ui.control.DropDown
        OcclusionDropDown matlab.ui.control.DropDown
        MaximumObservationsField matlab.ui.control.NumericEditField
        MaximumAssociationRecordsField matlab.ui.control.NumericEditField
        FusionAlgorithmDropDown matlab.ui.control.DropDown
        StageDropDown matlab.ui.control.DropDown
        UncertaintyField matlab.ui.control.NumericEditField
        FusionDropDown matlab.ui.control.DropDown
        DemDropDown matlab.ui.control.DropDown
        OutputDropDown matlab.ui.control.DropDown
        ComparisonDropDown matlab.ui.control.DropDown
        ColorDropDown matlab.ui.control.DropDown
        ProductTable matlab.ui.control.Table
        StatisticsArea matlab.ui.control.TextArea
        ProgressGauge
        ProgressLabel matlab.ui.control.Label
        RunButton matlab.ui.control.Button
        CancelButton matlab.ui.control.Button
        EvidenceButton matlab.ui.control.Button
        ExportButton matlab.ui.control.Button
        LaunchViewerButton matlab.ui.control.Button
        Viewer ProjectionSurface3DViewer
        EvidenceFigure
        CancelRequested logical = false
        IsRunning logical = false
        ProgressFraction double = 0
        ProgressStage string = "idle"
        ProgressMessage string = "Ready"
        LastPreflight struct = struct()
        LastRun struct = struct()
    end

    methods
        function app = ProjectionSurfaceWorkbenchApp( ...
                catalog, configuration, runner)
            %ProjectionSurfaceWorkbenchApp Create a separate floating workbench.
            if nargin < 2
                configuration = struct();
            end
            if nargin < 3
                runner = [];
            end
            if ~(isempty(runner) || ...
                    isa(runner, "ProjectionSurfaceWorkbenchRunner"))
                error("ProjectionSurfaceWorkbenchApp:invalidRunner", ...
                    "Runner must be empty or scene-bound surface runner.");
            end
            app.Runner = runner;
            app.Model = ProjectionSurfaceWorkbenchModel(catalog, configuration);
            app.createComponents();
            app.syncControls();
            app.refreshDiagnostics();
            if nargout == 0
                clear app
            end
        end

        function delete(app)
            if ~isempty(app.Viewer) && isvalid(app.Viewer)
                delete(app.Viewer);
            end
            if ~isempty(app.EvidenceFigure) && isvalid(app.EvidenceFigure)
                delete(app.EvidenceFigure);
            end
            if ~isempty(app.UIFigure) && isvalid(app.UIFigure)
                app.UIFigure.CloseRequestFcn = [];
                delete(app.UIFigure);
            end
        end

        function figure = figureHandle(app)
            %figureHandle Return the floating workbench figure.
            figure = app.UIFigure;
        end

        function state = modelState(app)
            %modelState Return portable selections without runtime UI state.
            state = app.Model.state();
        end

        function setSelection(app, changes)
            %setSelection Apply graphics-free selections and refresh controls.
            app.Model.configure(changes);
            app.syncControls();
            app.refreshDiagnostics();
        end

        function viewer = openViewer(app)
            %openViewer Launch or focus the separate runtime 3-D viewer.
            if isempty(app.Viewer) || ~isvalid(app.Viewer) || ...
                    ~isvalid(app.Viewer.figureHandle())
                app.Viewer = ProjectionSurface3DViewer(app.Model);
            else
                figure(app.Viewer.figureHandle());
            end
            viewer = app.Viewer;
        end

        function viewer = viewerHandle(app)
            %viewerHandle Return the runtime viewer object, if open.
            viewer = app.Viewer;
        end

        function setProgress(app, fraction, stage, message)
            %setProgress Publish bounded runtime-only processing progress.
            if nargin < 4
                message = stage;
            end
            if ~isnumeric(fraction) || ~isscalar(fraction) || ...
                    ~isfinite(fraction) || fraction < 0 || fraction > 1
                error("ProjectionSurfaceWorkbenchApp:invalidProgress", ...
                    "Progress fraction must be between zero and one.");
            end
            stage = string(stage);
            message = string(message);
            if ~isscalar(stage) || ~isscalar(message) || ...
                    ismissing(stage) || ismissing(message)
                error("ProjectionSurfaceWorkbenchApp:invalidProgress", ...
                    "Progress stage and message must be string scalars.");
            end
            app.ProgressFraction = double(fraction);
            app.ProgressStage = stage;
            app.ProgressMessage = message;
            app.ProgressGauge.Value = app.ProgressFraction;
            app.ProgressLabel.Text = sprintf("%s — %s (%.0f%%)", ...
                app.ProgressStage, app.ProgressMessage, ...
                100 * app.ProgressFraction);
            drawnow limitrate
        end

        function requestCancel(app)
            %requestCancel Set cooperative runtime cancellation state.
            app.CancelRequested = true;
            app.CancelButton.Enable = "off";
            app.ProgressStage = "cancelling";
            app.ProgressMessage = "Cancellation requested";
            app.ProgressLabel.Text = app.ProgressMessage;
        end

        function resetCancellation(app)
            %resetCancellation Prepare the runtime UI for a new operation.
            app.CancelRequested = false;
            app.CancelButton.Enable = app.onOff(app.IsRunning);
        end

        function tf = isCancellationRequested(app)
            %isCancellationRequested Runtime callback target for algorithms.
            tf = app.CancelRequested;
        end

        function report = preflight(app)
            %preflight Return the exact scene-bound execution proposal.
            if isempty(app.Runner)
                error("ProjectionSurfaceWorkbenchApp:noRunner", ...
                    "This catalog is not bound to executable scene inputs.");
            end
            report = app.Runner.preflight(app.Model.state());
            app.LastPreflight = report;
            app.refreshDiagnostics();
        end

        function outcome = runProcessing(app)
            %runProcessing Execute the configured scene-bound processing run.
            if isempty(app.Runner)
                error("ProjectionSurfaceWorkbenchApp:noRunner", ...
                    "This catalog is not bound to executable scene inputs.");
            end
            if app.IsRunning
                error("ProjectionSurfaceWorkbenchApp:alreadyRunning", ...
                    "A surface processing run is already active.");
            end
            app.IsRunning = true;
            app.CancelRequested = false;
            app.closeEvidence();
            app.RunButton.Enable = "off";
            app.CancelButton.Enable = "on";
            cleanup = onCleanup(@() app.finishRun());
            try
                app.LastPreflight = app.Runner.preflight(app.Model.state());
                runtime = struct( ...
                    ProgressFcn=@(event) app.progressEvent(event), ...
                    CancellationFcn=@() app.isCancellationRequested());
                outcome = app.Runner.run(app.Model.state(), runtime);
                app.LastRun = outcome;
                if ismember(outcome.Status, ["succeeded" "partial"])
                    app.closeViewer();
                    app.Model.replaceCatalog(outcome.Catalog);
                    app.refreshProductControls();
                end
                app.setProgress(app.completedFraction(outcome.Status), ...
                    outcome.Status, outcome.Message);
            catch exception
                outcome = struct(Status="failed", ...
                    Message=string(exception.message), ...
                    Identifier=string(exception.identifier), ...
                    GraphicsStateIncluded=false);
                app.LastRun = outcome;
                app.setProgress(0, "failed", exception.message);
            end
            clear cleanup
            app.refreshDiagnostics();
        end

        function outcome = lastRunResult(app)
            %lastRunResult Return retained diagnostics and portable evidence.
            outcome = app.LastRun;
        end

        function exportRun(app, path)
            %exportRun Save retained portable run evidence without graphics.
            if isempty(fieldnames(app.LastRun))
                error("ProjectionSurfaceWorkbenchApp:noRun", ...
                    "Run processing before exporting diagnostics.");
            end
            path = string(path);
            if ~isscalar(path) || strlength(path) == 0
                error("ProjectionSurfaceWorkbenchApp:invalidExportPath", ...
                    "Export path must be a nonempty string scalar.");
            end
            [~, ~, extension] = fileparts(path);
            extension = lower(string(extension));
            if extension == ".mat"
                surfaceWorkbenchRun = app.LastRun;
                save(path, "surfaceWorkbenchRun", "-mat");
            elseif extension == ".json"
                metadata = app.compactRunMetadata();
                fileId = fopen(path, "w");
                if fileId < 0
                    error("ProjectionSurfaceWorkbenchApp:exportFailed", ...
                        "Unable to open the JSON export path.");
                end
                cleanup = onCleanup(@() fclose(fileId));
                fprintf(fileId, "%s", jsonencode(metadata, PrettyPrint=true));
                clear cleanup
            else
                error("ProjectionSurfaceWorkbenchApp:invalidExportPath", ...
                    "Run export requires a .mat or .json extension.");
            end
        end

        function diagnostics = diagnostics(app)
            %diagnostics Return model statistics plus runtime progress state.
            state = app.Model.state();
            stats = app.Model.statistics(state.OutputProductId);
            network = app.Model.networkStatistics();
            estimate = app.Model.processingEstimate();
            viewerOpen = ~isempty(app.Viewer) && isvalid(app.Viewer) && ...
                isvalid(app.Viewer.figureHandle());
            diagnostics = struct(State=state, ProductStatistics=stats, ...
                ProductSummaries=app.Model.productSummaries(), ...
                NetworkStatistics=network, ProcessingEstimate=estimate, ...
                Progress=struct(Fraction=app.ProgressFraction, ...
                Stage=app.ProgressStage, Message=app.ProgressMessage), ...
                CancellationRequested=app.CancelRequested, ...
                IsRunning=app.IsRunning, RunnerBound=~isempty(app.Runner), ...
                Preflight=app.LastPreflight, LastRun=app.runSummary(), ...
                ViewerOpen=viewerOpen, GraphicsStateSerialized=false);
        end

        function snapshot = componentSnapshot(app)
            %componentSnapshot Return inspectable layout/control identities.
            snapshot = struct(FigureTag=string(app.UIFigure.Tag), ...
                NetworkTableTag=string(app.NetworkTable.Tag), ...
                ProductTableTag=string(app.ProductTable.Tag), ...
                LaunchViewerTag=string(app.LaunchViewerButton.Tag), ...
                RunTag=string(app.RunButton.Tag), ...
                CancelTag=string(app.CancelButton.Tag), ...
                GridRows=numel(app.GridLayout.RowHeight), ...
                GridColumns=numel(app.GridLayout.ColumnWidth));
        end
    end

    methods (Access = private)
        function createComponents(app)
            app.UIFigure = uifigure(Name="Surface Workbench", ...
                Position=[120 80 1320 860], ...
                Tag="ProjectionSurfaceWorkbenchFigure", ...
                CloseRequestFcn=@(~, ~) delete(app));
            app.GridLayout = uigridlayout(app.UIFigure, [3 3], ...
                RowHeight={"fit", "1x", "fit"}, ...
                ColumnWidth={"1x", "1x", "1x"}, ...
                Padding=[10 10 10 10], RowSpacing=8, ColumnSpacing=8);

            app.createInputPanel();
            app.createProcessingPanel();
            app.createDiagnosticsPanel();

            productPanel = uipanel(app.GridLayout, Title="Products and stages", ...
                Tag="ProjectionSurfaceWorkbenchProductPanel");
            productPanel.Layout.Row = 2;
            productPanel.Layout.Column = [1 3];
            productGrid = uigridlayout(productPanel, [1 2], ...
                ColumnWidth={"2x", "1x"}, Padding=[6 6 6 6]);
            app.ProductTable = uitable(productGrid, ...
                Tag="ProjectionSurfaceWorkbenchProductTable");
            app.ProductTable.Layout.Column = 1;
            app.StatisticsArea = uitextarea(productGrid, Editable="off", ...
                Tag="ProjectionSurfaceWorkbenchStatisticsArea");
            app.StatisticsArea.Layout.Column = 2;

            footer = uigridlayout(app.GridLayout, [1 9], ...
                ColumnWidth={"fit", "1x", 180, "fit", "fit", "fit", ...
                "fit", "fit", "fit"}, ...
                Padding=[0 0 0 0]);
            footer.Layout.Row = 3;
            footer.Layout.Column = [1 3];
            app.ProgressLabel = uilabel(footer, Text="Ready", ...
                Tag="ProjectionSurfaceWorkbenchProgressLabel");
            app.ProgressLabel.Layout.Column = [1 2];
            app.ProgressGauge = uigauge(footer, "linear", Limits=[0 1], ...
                Value=0, Tag="ProjectionSurfaceWorkbenchProgressGauge");
            app.ProgressGauge.Layout.Column = 3;
            app.RunButton = uibutton(footer, Text="Run", ...
                Enable=app.onOff(~isempty(app.Runner)), ...
                Tag="ProjectionSurfaceWorkbenchRunButton", ...
                ButtonPushedFcn=@(~, ~) app.runProcessing());
            app.RunButton.Layout.Column = 4;
            app.CancelButton = uibutton(footer, Text="Cancel", ...
                Enable="off", ...
                Tag="ProjectionSurfaceWorkbenchCancelButton", ...
                ButtonPushedFcn=@(~, ~) app.requestCancel());
            app.CancelButton.Layout.Column = 5;
            app.EvidenceButton = uibutton(footer, Text="Open evidence", ...
                Enable="off", ...
                Tag="ProjectionSurfaceWorkbenchEvidenceButton", ...
                ButtonPushedFcn=@(~, ~) app.openEvidence());
            app.EvidenceButton.Layout.Column = 6;
            app.ExportButton = uibutton(footer, Text="Export run...", ...
                Enable="off", ...
                Tag="ProjectionSurfaceWorkbenchExportButton", ...
                ButtonPushedFcn=@(~, ~) app.exportRunInteractive());
            app.ExportButton.Layout.Column = 7;
            refresh = uibutton(footer, Text="Refresh diagnostics", ...
                Tag="ProjectionSurfaceWorkbenchRefreshButton", ...
                ButtonPushedFcn=@(~, ~) app.refreshDiagnostics());
            refresh.Layout.Column = 8;
            app.LaunchViewerButton = uibutton(footer, Text="Open 3-D viewer", ...
                Tag="ProjectionSurfaceWorkbenchOpenViewerButton", ...
                ButtonPushedFcn=@(~, ~) app.openViewer());
            app.LaunchViewerButton.Layout.Column = 9;
        end

        function createInputPanel(app)
            panel = uipanel(app.GridLayout, Title="Input network and pair planning", ...
                Tag="ProjectionSurfaceWorkbenchInputPanel");
            panel.Layout.Row = 1;
            panel.Layout.Column = 1;
            grid = uigridlayout(panel, [10 2], ...
                RowHeight={"1x", "fit", "fit", "fit", "fit", "fit", ...
                "fit", "fit", "fit", "fit"}, ...
                ColumnWidth={125, "1x"}, Padding=[6 6 6 6]);
            app.NetworkTable = uitable(grid, ...
                ColumnEditable=[true false false], ...
                ColumnName={"Include" "Kind" "Stable ID"}, ...
                Tag="ProjectionSurfaceWorkbenchNetworkTable", ...
                CellEditCallback=@(~, ~) app.networkChanged());
            app.NetworkTable.Layout.Row = 1;
            app.NetworkTable.Layout.Column = [1 2];
            app.PairScheduleDropDown = app.labeledDataDropDown(grid, 2, ...
                "Pair schedule", ["Selected pair" "Planned subset" ...
                "All quality pairs" "All plausible pairs" "Explicit pairs"], ...
                ["fast" "balanced" "quality" "allPlausible" "operator"], ...
                "ProjectionSurfaceWorkbenchPairScheduleDropDown");
            app.DenseMethodDropDown = app.labeledDataDropDown(grid, 3, ...
                "Dense method", ["SGM" "Template matcher" "Custom matcher"], ...
                ["currentSgm" "classicalTemplate" "external"], ...
                "ProjectionSurfaceWorkbenchDenseMethodDropDown");
            app.GeometrySearchDropDown = app.labeledDropDown(grid, 4, ...
                "Geometry search", ["sparseSeeded" "widePrior" ...
                "localStrip" "terrainGrid"], ...
                "ProjectionSurfaceWorkbenchGeometrySearchDropDown");
            app.ExecutionPathDropDown = app.labeledDataDropDown(grid, 5, ...
                "Execution", ["CPU" "GPU if available" "GPU required"], ...
                ["cpu" "gpuIfAvailable" "gpuRequired"], ...
                "ProjectionSurfaceWorkbenchExecutionDropDown");
            app.ConsistencyDropDown = app.labeledDropDown(grid, 6, ...
                "Consistency", ["strict" "balanced" "permissive"], ...
                "ProjectionSurfaceWorkbenchConsistencyDropDown");
            app.OcclusionDropDown = app.labeledDataDropDown(grid, 7, ...
                "Occlusion", ["Reject" "Retain diagnostic" ...
                "Matcher default"], ...
                ["reject" "retainDiagnostic" "matcherDefault"], ...
                "ProjectionSurfaceWorkbenchOcclusionDropDown");
            maximumLabel = uilabel(grid, Text="Observation cap");
            maximumLabel.Layout.Row = 8;
            maximumLabel.Layout.Column = 1;
            app.MaximumObservationsField = uieditfield(grid, "numeric", ...
                Value=5000, Limits=[1 Inf], RoundFractionalValues="on", ...
                Tag="ProjectionSurfaceWorkbenchMaximumObservationsField", ...
                ValueChangedFcn=@(~, ~) app.controlsChanged());
            app.MaximumObservationsField.Layout.Row = 8;
            app.MaximumObservationsField.Layout.Column = 2;
            totalLabel = uilabel(grid, Text="Total association budget");
            totalLabel.Layout.Row = 9;
            totalLabel.Layout.Column = 1;
            app.MaximumAssociationRecordsField = uieditfield(grid, "numeric", ...
                Value=50000, Limits=[1 Inf], RoundFractionalValues="on", ...
                Tag="ProjectionSurfaceWorkbenchMaximumAssociationRecordsField", ...
                ValueChangedFcn=@(~, ~) app.controlsChanged());
            app.MaximumAssociationRecordsField.Layout.Row = 9;
            app.MaximumAssociationRecordsField.Layout.Column = 2;
            info = uilabel(grid, Text=[ ...
                "Select stable views, passes, and physical pairs; preflight " ...
                "reports exact bounded work before Run."], ...
                WordWrap="on");
            info.Layout.Row = 10;
            info.Layout.Column = [1 2];
        end

        function createProcessingPanel(app)
            panel = uipanel(app.GridLayout, Title="Processing, uncertainty, and fusion", ...
                Tag="ProjectionSurfaceWorkbenchProcessingPanel");
            panel.Layout.Row = 1;
            panel.Layout.Column = 2;
            grid = uigridlayout(panel, [7 2], ...
                RowHeight=repmat({"fit"}, 1, 7), ...
                ColumnWidth={150, "1x"}, Padding=[6 6 6 6]);
            app.StageDropDown = app.labeledDropDown(grid, 1, ...
                "Processing stage", ["rawPairwise" "robustMultiView" ...
                "uncertaintyFiltered" "fusionDerived" "voxelEvidence" ...
                "mesh" "grid" "dem" "registered" "demDifference"], ...
                "ProjectionSurfaceWorkbenchStageDropDown");
            label = uilabel(grid, Text="Max uncertainty (m)");
            label.Layout.Row = 2;
            label.Layout.Column = 1;
            app.UncertaintyField = uieditfield(grid, "numeric", ...
                Value=Inf, Limits=[eps Inf], ...
                Tag="ProjectionSurfaceWorkbenchUncertaintyField", ...
                ValueChangedFcn=@(~, ~) app.controlsChanged());
            app.UncertaintyField.Layout.Row = 2;
            app.UncertaintyField.Layout.Column = 2;
            app.FusionAlgorithmDropDown = app.labeledDataDropDown(grid, 3, ...
                "Fusion algorithm", ["Robust multi-ray" "Example centroid"], ...
                ["robustMultiRay" "exampleCentroid"], ...
                "ProjectionSurfaceWorkbenchFusionAlgorithmDropDown");
            fusion = app.fusionProducts();
            app.FusionDropDown = app.labeledDataDropDown(grid, 4, ...
                "Fusion product", string({fusion.Label}), ...
                string({fusion.ProductId}), ...
                "ProjectionSurfaceWorkbenchFusionDropDown");
            app.DemDropDown = app.labeledDropDown(grid, 5, ...
                "DEM registration", ["none" "preview" "registered" "difference"], ...
                "ProjectionSurfaceWorkbenchDemDropDown");
            app.OutputDropDown = app.productDropDown(grid, 6, ...
                "Output product", "ProjectionSurfaceWorkbenchOutputDropDown");
            app.ComparisonDropDown = app.comparisonDropDown(grid, 7, ...
                "Compare with", "ProjectionSurfaceWorkbenchComparisonDropDown");
        end

        function createDiagnosticsPanel(app)
            panel = uipanel(app.GridLayout, Title="3-D display and output", ...
                Tag="ProjectionSurfaceWorkbenchDisplayPanel");
            panel.Layout.Row = 1;
            panel.Layout.Column = 3;
            grid = uigridlayout(panel, [4 2], ...
                RowHeight={"fit", "fit", "fit", "1x"}, ...
                ColumnWidth={140, "1x"}, Padding=[6 6 6 6]);
            app.ColorDropDown = app.labeledDropDown(grid, 1, ...
                "Color by", ProjectionSurfaceWorkbenchModel.colorModes(), ...
                "ProjectionSurfaceWorkbenchColorDropDown");
            decimationLabel = uilabel(grid, Text="Interactive cap");
            decimationLabel.Layout.Row = 2;
            decimationLabel.Layout.Column = 1;
            decimation = uieditfield(grid, "numeric", Value=50000, ...
                Limits=[1 Inf], RoundFractionalValues="on", ...
                Tag="ProjectionSurfaceWorkbenchDecimationField", ...
                ValueChangedFcn=@(source, ~) app.decimationChanged(source));
            decimation.Layout.Row = 2;
            decimation.Layout.Column = 2;
            glyphLabel = uilabel(grid, Text="Glyph limit");
            glyphLabel.Layout.Row = 3;
            glyphLabel.Layout.Column = 1;
            glyph = uieditfield(grid, "numeric", Value=1, Limits=[0 Inf], ...
                RoundFractionalValues="on", ...
                Tag="ProjectionSurfaceWorkbenchGlyphLimitField", ...
                ValueChangedFcn=@(source, ~) app.glyphLimitChanged(source));
            glyph.Layout.Row = 3;
            glyph.Layout.Column = 2;
            note = uilabel(grid, WordWrap="on", ...
                Text=["Point, mesh, grid, voxel, DEM, registered, and difference " ...
                "products share one catalog. Missing later products remain explicit."]);
            note.Layout.Row = 4;
            note.Layout.Column = [1 2];
        end

        function control = labeledDropDown(app, grid, row, labelText, items, tag)
            control = app.labeledDataDropDown(grid, row, labelText, ...
                string(items), string(items), tag);
        end

        function control = labeledDataDropDown(app, grid, row, labelText, ...
                items, itemsData, tag)
            label = uilabel(grid, Text=labelText);
            label.Layout.Row = row;
            label.Layout.Column = 1;
            control = uidropdown(grid, Items=cellstr(items), ...
                ItemsData=cellstr(itemsData), Tag=tag, ...
                ValueChangedFcn=@(~, ~) app.controlsChanged());
            control.Layout.Row = row;
            control.Layout.Column = 2;
        end

        function control = productDropDown(app, grid, row, labelText, tag)
            products = app.availableProducts();
            control = app.labeledDataDropDown(grid, row, labelText, ...
                string({products.Label}), string({products.ProductId}), tag);
        end

        function control = comparisonDropDown(app, grid, row, labelText, tag)
            products = app.availableProducts();
            control = app.labeledDataDropDown(grid, row, labelText, ...
                ["None" string({products.Label})], ...
                ["" string({products.ProductId})], tag);
        end

        function syncControls(app)
            state = app.Model.state();
            app.NetworkTable.Data = app.networkTable(state);
            app.PairScheduleDropDown.Value = state.PairSchedule;
            app.DenseMethodDropDown.Value = state.DenseMethod;
            app.GeometrySearchDropDown.Value = state.GeometrySearch;
            app.ExecutionPathDropDown.Value = state.ExecutionPath;
            app.ConsistencyDropDown.Value = state.ConsistencyPolicy;
            app.OcclusionDropDown.Value = state.OcclusionPolicy;
            app.MaximumObservationsField.Value = state.MaximumObservations;
            app.MaximumAssociationRecordsField.Value = ...
                state.MaximumAssociationRecords;
            app.FusionAlgorithmDropDown.Value = state.FusionAlgorithm;
            app.StageDropDown.Value = state.ProcessingStage;
            app.UncertaintyField.Value = state.MaximumUncertaintyMeters;
            app.FusionDropDown.Value = state.FusionProductId;
            app.DemDropDown.Value = state.DemRegistrationMode;
            app.OutputDropDown.Value = state.OutputProductId;
            app.ComparisonDropDown.Value = state.ComparisonProductId;
            app.ColorDropDown.Value = state.ColorMode;
        end

        function refreshDiagnostics(app)
            summaries = app.Model.productSummaries();
            app.ProductTable.Data = struct2table(summaries);
            state = app.Model.state();
            stats = app.Model.statistics(state.OutputProductId);
            network = app.Model.networkStatistics();
            estimate = app.Model.processingEstimate();
            lines = [ ...
                sprintf("Output: %s", stats.ProductId); ...
                sprintf("Stage: %s", stats.Stage); ...
                sprintf("Full / filtered / display: %d / %d / %d", ...
                stats.FullPointCount, stats.FilteredPointCount, ...
                stats.DisplayPointCount); ...
                sprintf("Decimated: %s", string(stats.Decimated)); ...
                sprintf("Median uncertainty: %.6g m", ...
                stats.MedianUncertaintyMeters); ...
                sprintf("Median residual: %.6g m", stats.MedianResidualMeters); ...
                sprintf("Selected views / passes: %d / %d", ...
                network.SelectedViewCount, network.SelectedPassCount); ...
                sprintf("Raw pairs / robust points: %d / %d", ...
                network.RawPairwisePointCount, ...
                network.RobustMultiViewPointCount); ...
                sprintf("Scheduled pairs / relative work: %d / %.0f", ...
                estimate.ScheduledPairCount, estimate.RelativeWorkUnits); ...
                sprintf("Estimated selected memory: %.3f MiB", ...
                stats.EstimatedMemoryBytes / 1024 ^ 2)];
            if ~isempty(app.Runner)
                try
                    report = app.Runner.preflight(state);
                    app.LastPreflight = report;
                    pairList = strjoin(report.SelectedPairIds, ", ");
                    lines = [lines; ...
                        sprintf("Preflight: %s", app.supportLabel(report)); ...
                        sprintf("Pairs: %s", pairList); ...
                        sprintf("Matcher / execution: %s / %s", ...
                        report.MatcherAlgorithmId, report.ExecutionPath); ...
                        sprintf("Search / rectification: %s / %s", ...
                        report.GeometrySearch, report.RectificationState); ...
                        sprintf("Overlap / cap: %d px / %d observations", ...
                        report.ResourceEstimate.OverlapPixelCount, ...
                        report.ResourceEstimate.MaximumObservations); ...
                        sprintf("Association records: %d requested / %d scheduled", ...
                        report.ResourceEstimate.RequestedAssociationRecordCount, ...
                        report.ResourceEstimate.MaximumScheduledAssociationRecords)];
                    if report.ResourceEstimate.AssociationBudgetApplied
                        lines(end + 1) = "Budget: " + ...
                            report.ResourceEstimate.AssociationBudgetAdvice;
                    end
                    if strlength(report.FallbackReason) > 0
                        lines(end + 1) = "Fallback: " + report.FallbackReason;
                    end
                catch exception
                    lines(end + 1) = "Preflight unavailable: " + ...
                        string(exception.message);
                end
            end
            if ~isempty(fieldnames(app.LastRun))
                summary = app.runSummary();
                lines = [lines; ...
                    sprintf("Last run: %s — %s", ...
                    summary.Status, summary.Message); ...
                    sprintf("Candidates / accepted / pairs: %d / %d / %d", ...
                    summary.CandidateCount, summary.AcceptedCount, ...
                    summary.PairCount)];
            end
            app.StatisticsArea.Value = lines;
            hasEvidence = app.hasEvidence();
            app.EvidenceButton.Enable = app.onOff(hasEvidence);
            app.ExportButton.Enable = app.onOff( ...
                ~isempty(fieldnames(app.LastRun)));
        end

        function controlsChanged(app)
            changes = struct(PairSchedule=string(app.PairScheduleDropDown.Value), ...
                DenseMethod=string(app.DenseMethodDropDown.Value), ...
                GeometrySearch=string(app.GeometrySearchDropDown.Value), ...
                ExecutionPath=string(app.ExecutionPathDropDown.Value), ...
                ConsistencyPolicy=string(app.ConsistencyDropDown.Value), ...
                OcclusionPolicy=string(app.OcclusionDropDown.Value), ...
                MaximumObservations=app.MaximumObservationsField.Value, ...
                MaximumAssociationRecords= ...
                app.MaximumAssociationRecordsField.Value, ...
                FusionAlgorithm=string(app.FusionAlgorithmDropDown.Value), ...
                ProcessingStage=string(app.StageDropDown.Value), ...
                MaximumUncertaintyMeters=app.UncertaintyField.Value, ...
                FusionProductId=string(app.FusionDropDown.Value), ...
                DemRegistrationMode=string(app.DemDropDown.Value), ...
                OutputProductId=string(app.OutputDropDown.Value), ...
                ComparisonProductId=string(app.ComparisonDropDown.Value), ...
                ColorMode=string(app.ColorDropDown.Value));
            try
                app.Model.configure(changes);
                app.ProgressLabel.Text = "Selections updated";
            catch exception
                app.syncControls();
                app.ProgressLabel.Text = "Selection rejected: " + exception.message;
            end
            app.refreshDiagnostics();
        end

        function networkChanged(app)
            data = app.NetworkTable.Data;
            selectedViews = string(data.StableId(data.Include & data.Kind == "view"));
            selectedPasses = string(data.StableId(data.Include & data.Kind == "pass"));
            selectedPairs = string(data.StableId(data.Include & data.Kind == "pair"));
            try
                app.Model.configure(struct( ...
                    SelectedViewIds=reshape(selectedViews, 1, []), ...
                    SelectedPassIds=reshape(selectedPasses, 1, []), ...
                    SelectedPairIds=reshape(selectedPairs, 1, [])));
                app.ProgressLabel.Text = "Network selection updated";
            catch exception
                app.ProgressLabel.Text = "Network selection rejected: " + ...
                    exception.message;
                app.syncControls();
            end
        end

        function decimationChanged(app, source)
            app.setSelection(struct(DecimationLimit=source.Value));
        end

        function glyphLimitChanged(app, source)
            app.setSelection(struct(MaximumUncertaintyGlyphs=source.Value));
        end

        function tableValue = networkTable(app, state)
            viewIds = app.Model.catalogValue().ViewIds;
            passIds = app.Model.catalogValue().PassIds;
            pairIds = app.Model.catalogValue().PairIds;
            tableValue = table( ...
                [ismember(viewIds, state.SelectedViewIds).'; ...
                ismember(passIds, state.SelectedPassIds).'; ...
                ismember(pairIds, state.SelectedPairIds).'], ...
                [repmat("view", numel(viewIds), 1); ...
                repmat("pass", numel(passIds), 1); ...
                repmat("pair", numel(pairIds), 1)], ...
                [reshape(viewIds, [], 1); reshape(passIds, [], 1); ...
                reshape(pairIds, [], 1)], ...
                VariableNames=["Include" "Kind" "StableId"]);
        end

        function products = availableProducts(app)
            summaries = app.Model.productSummaries();
            products = summaries(string({summaries.Status}) == "available");
        end

        function products = fusionProducts(app)
            products = app.availableProducts();
            selected = ismember(string({products.Stage}), ...
                ["robustMultiView" "fusionDerived" "voxelEvidence"]);
            products = products(selected);
        end

        function progressEvent(app, event)
            app.setProgress(event.Fraction, event.Stage, event.Message);
        end

        function finishRun(app)
            app.IsRunning = false;
            app.CancelRequested = false;
            if ~isempty(app.RunButton) && isvalid(app.RunButton)
                app.RunButton.Enable = app.onOff(~isempty(app.Runner));
            end
            if ~isempty(app.CancelButton) && isvalid(app.CancelButton)
                app.CancelButton.Enable = "off";
            end
        end

        function fraction = completedFraction(app, status)
            if ismember(string(status), ["succeeded" "partial"])
                fraction = 1;
            else
                fraction = app.ProgressFraction;
            end
        end

        function closeViewer(app)
            if ~isempty(app.Viewer) && isvalid(app.Viewer)
                delete(app.Viewer);
            end
            app.Viewer = ProjectionSurface3DViewer.empty();
        end

        function refreshProductControls(app)
            products = app.availableProducts();
            app.setDropDownItems(app.OutputDropDown, ...
                string({products.Label}), string({products.ProductId}));
            app.setDropDownItems(app.ComparisonDropDown, ...
                ["None" string({products.Label})], ...
                ["" string({products.ProductId})]);
            fusion = app.fusionProducts();
            app.setDropDownItems(app.FusionDropDown, ...
                string({fusion.Label}), string({fusion.ProductId}));
            app.syncControls();
        end

        function setDropDownItems(~, control, items, itemsData)
            set(control, "Items", cellstr(items), ...
                "ItemsData", cellstr(itemsData));
        end

        function summary = runSummary(app)
            summary = struct(Status="notRun", Message="", ...
                CandidateCount=0, AcceptedCount=0, PairCount=0, ...
                FailedPairCount=0);
            if isempty(fieldnames(app.LastRun))
                return
            end
            if isfield(app.LastRun, "Status")
                summary.Status = string(app.LastRun.Status);
            end
            if isfield(app.LastRun, "Message")
                summary.Message = string(app.LastRun.Message);
            end
            if isfield(app.LastRun, "Diagnostics") && ...
                    isstruct(app.LastRun.Diagnostics) && ...
                    ~isempty(fieldnames(app.LastRun.Diagnostics))
                diagnostics = app.LastRun.Diagnostics;
                summary.CandidateCount = diagnostics.CandidateCount;
                summary.AcceptedCount = ...
                    diagnostics.AcceptedCorrespondenceCount;
                summary.PairCount = diagnostics.PairCount;
                summary.FailedPairCount = diagnostics.FailedPairCount;
            end
        end

        function tf = hasEvidence(app)
            tf = false;
            if ~isfield(app.LastRun, "PairRuns")
                return
            end
            runs = app.LastRun.PairRuns;
            for index = 1:numel(runs)
                if isstruct(runs(index).Evidence) && ...
                        ~isempty(fieldnames(runs(index).Evidence))
                    tf = true;
                    return
                end
            end
        end

        function figureHandle = openEvidence(app)
            if ~app.hasEvidence()
                error("ProjectionSurfaceWorkbenchApp:noEvidence", ...
                    "The last run retained no pair diagnostic evidence.");
            end
            if ~isempty(app.EvidenceFigure) && isvalid(app.EvidenceFigure)
                figure(app.EvidenceFigure);
                figureHandle = app.EvidenceFigure;
                return
            end
            runs = app.LastRun.PairRuns;
            selected = find(arrayfun(@(run) ...
                ~isempty(fieldnames(run.Evidence)), runs), 1, "first");
            evidence = runs(selected).Evidence;
            app.EvidenceFigure = uifigure(Name="Surface Pair Evidence", ...
                Position=[180 120 1180 720], ...
                Tag="ProjectionSurfaceWorkbenchEvidenceFigure", ...
                CloseRequestFcn=@(~, ~) app.closeEvidence());
            grid = uigridlayout(app.EvidenceFigure, [3 3], ...
                RowHeight={"1x", "1x", "1x"}, ...
                ColumnWidth={"1x", "1x", "1x"});
            values = {evidence.MovingAnalysisImage, ...
                evidence.ReferenceAnalysisImage, evidence.OverlapMask, ...
                evidence.MovingValidityMask, evidence.ReferenceValidityMask, ...
                app.diagnosticSurface(evidence)};
            labels = ["Moving analysis" "Reference analysis" ...
                "Overlap mask" "Moving valid" "Reference valid" ...
                "Matcher diagnostic"];
            for index = 1:numel(values)
                axisHandle = uiaxes(grid, ...
                    Tag="ProjectionSurfaceWorkbenchEvidenceAxes" + index);
                imagesc(axisHandle, values{index});
                axisHandle.YDir = "reverse";
                axisHandle.DataAspectRatio = [1 1 1];
                title(axisHandle, labels(index));
                colorbar(axisHandle);
            end
            qualityAxis = uiaxes(grid, ...
                Tag="ProjectionSurfaceWorkbenchQualityAxes");
            score = double(evidence.Score(:));
            confidence = double(evidence.Confidence(:));
            finite = isfinite(score) & isfinite(confidence);
            plot(qualityAxis, score(finite), confidence(finite), ".");
            xlabel(qualityAxis, "Score");
            ylabel(qualityAxis, "Confidence");
            title(qualityAxis, "Score / confidence");
            rayAxis = uiaxes(grid, ...
                Tag="ProjectionSurfaceWorkbenchRayResidualAxes");
            raySeparation = app.raySeparations();
            histogram(rayAxis, raySeparation(isfinite(raySeparation)));
            xlabel(rayAxis, "Ray separation (m)");
            title(rayAxis, "Ray geometry residuals");
            heightAxis = uiaxes(grid, ...
                Tag="ProjectionSurfaceWorkbenchHeightAxes");
            heights = app.reconstructedHeights();
            histogram(heightAxis, heights(isfinite(heights)));
            xlabel(heightAxis, "World Z (m)");
            title(heightAxis, "Reconstructed height distribution");
            figureHandle = app.EvidenceFigure;
        end

        function values = raySeparations(app)
            values = zeros(1, 0);
            if ~isfield(app.LastRun, "Association") || ...
                    ~isstruct(app.LastRun.Association) || ...
                    ~isfield(app.LastRun.Association, "RawPairwiseRecords")
                return
            end
            records = app.LastRun.Association.RawPairwiseRecords;
            if ~isempty(records) && ...
                    isfield(records, "PairRaySeparationMeters")
                values = double([records.PairRaySeparationMeters]);
            end
        end

        function values = reconstructedHeights(app)
            values = zeros(1, 0);
            if ~isfield(app.LastRun, "PointSet") || ...
                    ~isstruct(app.LastRun.PointSet) || ...
                    ~isfield(app.LastRun.PointSet, "Points")
                return
            end
            points = app.LastRun.PointSet.Points;
            if isempty(points)
                return
            end
            points = points([points.Valid]);
            if ~isempty(points)
                coordinates = horzcat(points.PointWorld);
                values = coordinates(3, :);
            end
        end

        function value = diagnosticSurface(~, evidence)
            diagnostics = evidence.MatcherDiagnostics;
            candidates = ["DisparityMap" "Disparity" "ConfidenceMap" ...
                "CostMap" "ValidMask" "RectifiedOverlapMask"];
            for name = candidates
                if isstruct(diagnostics) && isfield(diagnostics, name) && ...
                        isnumeric(diagnostics.(name)) && ...
                        ~isempty(diagnostics.(name))
                    value = diagnostics.(name);
                    return
                end
            end
            value = double(evidence.OverlapMask);
        end

        function closeEvidence(app)
            if ~isempty(app.EvidenceFigure) && isvalid(app.EvidenceFigure)
                app.EvidenceFigure.CloseRequestFcn = [];
                delete(app.EvidenceFigure);
            end
            app.EvidenceFigure = [];
        end

        function exportRunInteractive(app)
            [file, folder] = uiputfile({"*.mat"; "*.json"}, ...
                "Export surface workbench run", ...
                "surface-workbench-run.mat");
            if isequal(file, 0)
                return
            end
            app.exportRun(fullfile(folder, file));
        end

        function metadata = compactRunMetadata(app)
            run = app.LastRun;
            metadata = struct(Format="ProjectionSurfaceWorkbenchRunMetadata", ...
                Version=1, Status=string(run.Status), ...
                Message=string(run.Message), GraphicsStateIncluded=false);
            for field = ["Preflight" "Diagnostics" "StageDiagnostics" ...
                    "Provenance"]
                if isfield(run, field)
                    metadata.(field) = run.(field);
                else
                    metadata.(field) = struct();
                end
            end
            for field = ["Identifier" "ProcessingStage" ...
                    "LastCompletedPairId"]
                if isfield(run, field)
                    metadata.(field) = string(run.(field));
                else
                    metadata.(field) = "";
                end
            end
            if isfield(run, "PairRuns")
                pairRuns = run.PairRuns;
                if ~isempty(pairRuns) && isfield(pairRuns, "Evidence")
                    pairRuns = rmfield(pairRuns, "Evidence");
                end
                metadata.PairRuns = pairRuns;
            else
                metadata.PairRuns = struct([]);
            end
            if isfield(run, "Catalog") && isstruct(run.Catalog) && ...
                    isfield(run.Catalog, "GenerationId")
                metadata.Catalog = struct( ...
                    GenerationId=run.Catalog.GenerationId, ...
                    ViewIds=run.Catalog.ViewIds, ...
                    PassIds=run.Catalog.PassIds, ...
                    PairIds=run.Catalog.PairIds, ...
                    ProductSummaries=app.Model.productSummaries());
            else
                metadata.Catalog = struct();
            end
        end

        function label = supportLabel(~, report)
            if report.Supported
                label = "supported";
            else
                label = "unsupported — " + report.Reason;
            end
        end

        function value = onOff(~, condition)
            if condition
                value = "on";
            else
                value = "off";
            end
        end
    end
end
