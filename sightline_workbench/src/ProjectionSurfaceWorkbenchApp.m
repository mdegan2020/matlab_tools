classdef ProjectionSurfaceWorkbenchApp < handle
    %ProjectionSurfaceWorkbenchApp Separate floating B6 control workbench.

    properties (Access = private)
        Model ProjectionSurfaceWorkbenchModel
        UIFigure matlab.ui.Figure
        GridLayout matlab.ui.container.GridLayout
        NetworkTable matlab.ui.control.Table
        PairScheduleDropDown matlab.ui.control.DropDown
        DenseMethodDropDown matlab.ui.control.DropDown
        GeometrySearchDropDown matlab.ui.control.DropDown
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
        CancelButton matlab.ui.control.Button
        LaunchViewerButton matlab.ui.control.Button
        Viewer ProjectionSurface3DViewer
        CancelRequested logical = false
        ProgressFraction double = 0
        ProgressStage string = "idle"
        ProgressMessage string = "Ready"
    end

    methods
        function app = ProjectionSurfaceWorkbenchApp(catalog, configuration)
            %ProjectionSurfaceWorkbenchApp Create a separate floating workbench.
            if nargin < 2
                configuration = struct();
            end
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
            app.CancelButton.Enable = "on";
        end

        function tf = isCancellationRequested(app)
            %isCancellationRequested Runtime callback target for algorithms.
            tf = app.CancelRequested;
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
                ViewerOpen=viewerOpen, GraphicsStateSerialized=false);
        end

        function snapshot = componentSnapshot(app)
            %componentSnapshot Return inspectable layout/control identities.
            snapshot = struct(FigureTag=string(app.UIFigure.Tag), ...
                NetworkTableTag=string(app.NetworkTable.Tag), ...
                ProductTableTag=string(app.ProductTable.Tag), ...
                LaunchViewerTag=string(app.LaunchViewerButton.Tag), ...
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

            footer = uigridlayout(app.GridLayout, [1 6], ...
                ColumnWidth={"fit", "1x", 180, "fit", "fit", "fit"}, ...
                Padding=[0 0 0 0]);
            footer.Layout.Row = 3;
            footer.Layout.Column = [1 3];
            app.ProgressLabel = uilabel(footer, Text="Ready", ...
                Tag="ProjectionSurfaceWorkbenchProgressLabel");
            app.ProgressLabel.Layout.Column = [1 2];
            app.ProgressGauge = uigauge(footer, "linear", Limits=[0 1], ...
                Value=0, Tag="ProjectionSurfaceWorkbenchProgressGauge");
            app.ProgressGauge.Layout.Column = 3;
            app.CancelButton = uibutton(footer, Text="Cancel", ...
                Tag="ProjectionSurfaceWorkbenchCancelButton", ...
                ButtonPushedFcn=@(~, ~) app.requestCancel());
            app.CancelButton.Layout.Column = 4;
            refresh = uibutton(footer, Text="Refresh diagnostics", ...
                Tag="ProjectionSurfaceWorkbenchRefreshButton", ...
                ButtonPushedFcn=@(~, ~) app.refreshDiagnostics());
            refresh.Layout.Column = 5;
            app.LaunchViewerButton = uibutton(footer, Text="Open 3-D viewer", ...
                Tag="ProjectionSurfaceWorkbenchOpenViewerButton", ...
                ButtonPushedFcn=@(~, ~) app.openViewer());
            app.LaunchViewerButton.Layout.Column = 6;
        end

        function createInputPanel(app)
            panel = uipanel(app.GridLayout, Title="Input network and pair planning", ...
                Tag="ProjectionSurfaceWorkbenchInputPanel");
            panel.Layout.Row = 1;
            panel.Layout.Column = 1;
            grid = uigridlayout(panel, [5 2], ...
                RowHeight={"1x", "fit", "fit", "fit", "fit"}, ...
                ColumnWidth={125, "1x"}, Padding=[6 6 6 6]);
            app.NetworkTable = uitable(grid, ...
                ColumnEditable=[true false false], ...
                ColumnName={"Include" "Kind" "Stable ID"}, ...
                Tag="ProjectionSurfaceWorkbenchNetworkTable", ...
                CellEditCallback=@(~, ~) app.networkChanged());
            app.NetworkTable.Layout.Row = 1;
            app.NetworkTable.Layout.Column = [1 2];
            app.PairScheduleDropDown = app.labeledDropDown(grid, 2, ...
                "Pair schedule", ["fast" "balanced" "quality" ...
                "allPlausible" "operator"], ...
                "ProjectionSurfaceWorkbenchPairScheduleDropDown");
            app.DenseMethodDropDown = app.labeledDropDown(grid, 3, ...
                "Dense method", ["currentSgm" "classicalTemplate" "external"], ...
                "ProjectionSurfaceWorkbenchDenseMethodDropDown");
            app.GeometrySearchDropDown = app.labeledDropDown(grid, 4, ...
                "Geometry search", ["sparseSeeded" "widePrior" ...
                "localStrip" "terrainGrid"], ...
                "ProjectionSurfaceWorkbenchGeometrySearchDropDown");
            info = uilabel(grid, Text="Stable view/pass selections; pair schedule remains independent of sparse alignment.", ...
                WordWrap="on");
            info.Layout.Row = 5;
            info.Layout.Column = [1 2];
        end

        function createProcessingPanel(app)
            panel = uipanel(app.GridLayout, Title="Processing, uncertainty, and fusion", ...
                Tag="ProjectionSurfaceWorkbenchProcessingPanel");
            panel.Layout.Row = 1;
            panel.Layout.Column = 2;
            grid = uigridlayout(panel, [6 2], ...
                RowHeight=repmat({"fit"}, 1, 6), ...
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
            fusion = app.fusionProducts();
            app.FusionDropDown = app.labeledDataDropDown(grid, 3, ...
                "Fusion product", string({fusion.Label}), ...
                string({fusion.ProductId}), ...
                "ProjectionSurfaceWorkbenchFusionDropDown");
            app.DemDropDown = app.labeledDropDown(grid, 4, ...
                "DEM registration", ["none" "preview" "registered" "difference"], ...
                "ProjectionSurfaceWorkbenchDemDropDown");
            app.OutputDropDown = app.productDropDown(grid, 5, ...
                "Output product", "ProjectionSurfaceWorkbenchOutputDropDown");
            app.ComparisonDropDown = app.comparisonDropDown(grid, 6, ...
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
            app.StatisticsArea.Value = [ ...
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
        end

        function controlsChanged(app)
            changes = struct(PairSchedule=string(app.PairScheduleDropDown.Value), ...
                DenseMethod=string(app.DenseMethodDropDown.Value), ...
                GeometrySearch=string(app.GeometrySearchDropDown.Value), ...
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
            try
                app.Model.configure(struct( ...
                    SelectedViewIds=reshape(selectedViews, 1, []), ...
                    SelectedPassIds=reshape(selectedPasses, 1, [])));
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
            tableValue = table( ...
                [ismember(viewIds, state.SelectedViewIds).'; ...
                ismember(passIds, state.SelectedPassIds).'], ...
                [repmat("view", numel(viewIds), 1); ...
                repmat("pass", numel(passIds), 1)], ...
                [reshape(viewIds, [], 1); reshape(passIds, [], 1)], ...
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
    end
end
