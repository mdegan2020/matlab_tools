classdef ProjectionSurface3DViewer < handle
    %ProjectionSurface3DViewer Runtime-only B6 product comparison viewer.

    properties (Access = private)
        Model ProjectionSurfaceWorkbenchModel
        UIFigure matlab.ui.Figure
        GridLayout matlab.ui.container.GridLayout
        Axes matlab.ui.control.UIAxes
        AxesToolbar
        ProductDropDown matlab.ui.control.DropDown
        ComparisonDropDown matlab.ui.control.DropDown
        ColorDropDown matlab.ui.control.DropDown
        DisplayFrameDropDown matlab.ui.control.DropDown
        VerticalExaggerationField matlab.ui.control.NumericEditField
        InspectCheckBox matlab.ui.control.CheckBox
        GlyphCheckBox matlab.ui.control.CheckBox
        DecimationField matlab.ui.control.NumericEditField
        SelectionTable matlab.ui.control.Table
        StatusLabel matlab.ui.control.Label
        CurrentPayload struct = struct()
        SelectedDisplayIndex double = 0
        PrimaryHandles = gobjects(0)
        ComparisonHandles = gobjects(0)
        GlyphHandles = gobjects(0)
        LastDisplayFrame string = ""
        CameraInitialized logical = false
    end

    methods
        function app = ProjectionSurface3DViewer(model)
            %ProjectionSurface3DViewer Open a viewer for one workbench model.
            if ~isa(model, "ProjectionSurfaceWorkbenchModel") || ~isscalar(model)
                error("ProjectionSurface3DViewer:invalidModel", ...
                    "A scalar ProjectionSurfaceWorkbenchModel is required.");
            end
            app.Model = model;
            app.createComponents();
            app.refresh();
            if nargout == 0
                clear app
            end
        end

        function delete(app)
            app.deleteHandles(app.PrimaryHandles);
            app.deleteHandles(app.ComparisonHandles);
            app.deleteHandles(app.GlyphHandles);
            if ~isempty(app.UIFigure) && isvalid(app.UIFigure)
                app.UIFigure.CloseRequestFcn = [];
                delete(app.UIFigure);
            end
        end

        function figure = figureHandle(app)
            %figureHandle Return the runtime figure for programmatic testing.
            figure = app.UIFigure;
        end

        function axesHandle = axesHandle(app)
            %axesHandle Return the 3-D axes.
            axesHandle = app.Axes;
        end

        function setProduct(app, productId)
            %setProduct Select and render an available product.
            app.Model.configure(struct(OutputProductId=string(productId)));
            app.ProductDropDown.Value = string(productId);
            app.refresh();
        end

        function setComparison(app, productId)
            %setComparison Select an optional comparison overlay.
            app.Model.configure(struct(ComparisonProductId=string(productId)));
            app.ComparisonDropDown.Value = string(productId);
            app.refresh();
        end

        function setColorMode(app, colorMode)
            %setColorMode Apply one documented color mapping.
            app.Model.configure(struct(ColorMode=string(colorMode)));
            app.ColorDropDown.Value = string(colorMode);
            app.refresh();
        end

        function setDecimationLimit(app, limit)
            %setDecimationLimit Bound interactive display without data loss.
            app.Model.configure(struct(DecimationLimit=limit));
            app.DecimationField.Value = limit;
            app.refresh();
        end

        function setDisplayFrame(app, displayFrame)
            %setDisplayFrame Select a declared reversible display transform.
            app.Model.configure(struct(DisplayFrame=string(displayFrame)));
            app.DisplayFrameDropDown.Value = string(displayFrame);
            app.refresh();
        end

        function setVerticalExaggeration(app, value)
            %setVerticalExaggeration Apply metric Z exaggeration for display only.
            app.Model.configure(struct(VerticalExaggeration=value));
            app.VerticalExaggerationField.Value = value;
            app.refresh();
        end

        function setInspectMode(app, enabled)
            %setInspectMode Toggle the visible point-selection interaction mode.
            if ~isscalar(enabled) || ...
                    ~(islogical(enabled) || (isnumeric(enabled) && ...
                    ismember(enabled, [0 1])))
                error("ProjectionSurface3DViewer:invalidInspectMode", ...
                    "Inspect mode must be one logical value.");
            end
            app.InspectCheckBox.Value = logical(enabled);
            app.refresh();
        end

        function setViewpoint(app, viewpoint)
            %setViewpoint Apply one standard camera orientation.
            viewpoint = string(viewpoint);
            switch viewpoint
                case "top"
                    view(app.Axes, 0, 90);
                case "north"
                    view(app.Axes, 0, 0);
                case "east"
                    view(app.Axes, 90, 0);
                case "isometric"
                    view(app.Axes, -37.5, 30);
                otherwise
                    error("ProjectionSurface3DViewer:invalidViewpoint", ...
                        "Viewpoint must be top, north, east, or isometric.");
            end
            app.CameraInitialized = true;
        end

        function state = cameraState(app)
            %cameraState Return testable camera and interaction state.
            state = app.captureCamera();
            state.DisplayFrame = app.LastDisplayFrame;
            state.InteractionCount = numel(app.Axes.Interactions);
            state.InspectMode = app.InspectCheckBox.Value;
        end

        function selectDisplayPoint(app, displayIndex)
            %selectDisplayPoint Link one displayed point to its observations.
            if ~isnumeric(displayIndex) || ~isscalar(displayIndex) || ...
                    ~isfinite(displayIndex) || fix(displayIndex) ~= displayIndex || ...
                    displayIndex < 1 || ...
                    displayIndex > app.CurrentPayload.DisplayPointCount
                error("ProjectionSurface3DViewer:invalidSelection", ...
                    "Selection must index one displayed point.");
            end
            app.SelectedDisplayIndex = double(displayIndex);
            point = app.CurrentPayload.Points(displayIndex);
            app.updateSelectionTable(point);
            app.updateGlyph(point);
            app.StatusLabel.Text = sprintf( ...
                "Selected %s (%d source observations)", ...
                point.PointId, numel(point.ObservationLinks));
        end

        function info = selectedPointInfo(app)
            %selectedPointInfo Return graphics-free selected point/link state.
            if app.SelectedDisplayIndex < 1 || ...
                    app.SelectedDisplayIndex > app.CurrentPayload.DisplayPointCount
                info = struct(Selected=false, Point=struct(), ...
                    ObservationLinks=ProjectionSurfaceProductCatalog.emptyLinks());
                return
            end
            point = app.CurrentPayload.Points(app.SelectedDisplayIndex);
            info = struct(Selected=true, Point=point, ...
                ObservationLinks=point.ObservationLinks);
        end

        function diagnostics = diagnostics(app)
            %diagnostics Return bounded runtime visualization diagnostics.
            state = app.Model.state();
            diagnostics = struct(ProductId=app.CurrentPayload.ProductId, ...
                SourceRepresentation=app.CurrentPayload.SourceRepresentation, ...
                DisplayRepresentation=app.CurrentPayload.Representation, ...
                FullPointCount=app.CurrentPayload.FullPointCount, ...
                FilteredPointCount=app.CurrentPayload.FilteredPointCount, ...
                DisplayPointCount=app.CurrentPayload.DisplayPointCount, ...
                Decimated=app.CurrentPayload.Decimated, ...
                PrimaryObjectCount=nnz(isgraphics(app.PrimaryHandles)), ...
                ComparisonObjectCount=nnz(isgraphics(app.ComparisonHandles)), ...
                UncertaintyGlyphCount=double(any(isgraphics(app.GlyphHandles))), ...
                UncertaintyGlyphAxisCount=nnz(isgraphics(app.GlyphHandles)), ...
                MaximumUncertaintyGlyphs=state.MaximumUncertaintyGlyphs, ...
                DisplayFrameId=app.CurrentPayload.DisplayFrameId, ...
                CoordinateKind=app.CurrentPayload.CoordinateFrame.CoordinateKind, ...
                VerticalExaggeration=state.VerticalExaggeration, ...
                InspectMode=app.InspectCheckBox.Value, ...
                CompleteProductRetained= ...
                app.CurrentPayload.CompleteProductRetained, ...
                GraphicsStateSerialized=state.GraphicsStateIncluded);
        end
    end

    methods (Access = private)
        function createComponents(app)
            app.UIFigure = uifigure(Name="Surface 3-D Viewer", ...
                Position=[180 120 1120 760], ...
                Tag="ProjectionSurface3DViewerFigure", ...
                CloseRequestFcn=@(~, ~) delete(app));
            app.GridLayout = uigridlayout(app.UIFigure, [3 3], ...
                RowHeight={"fit", "1x", "fit"}, ...
                ColumnWidth={"1x", "1x", 330}, ...
                Padding=[10 10 10 10], RowSpacing=8, ColumnSpacing=8);

            controls = uigridlayout(app.GridLayout, [2 10], ...
                ColumnWidth={"fit", "1x", "fit", "1x", "fit", "1x", ...
                "fit", 85, "fit", "fit"}, ...
                RowHeight={"fit", "fit"}, Padding=[0 0 0 0]);
            controls.Layout.Row = 1;
            controls.Layout.Column = [1 3];
            uilabel(controls, Text="Product");
            available = app.availableProducts();
            app.ProductDropDown = uidropdown(controls, ...
                Items=reshape(string({available.Label}), 1, []), ...
                ItemsData=reshape(string({available.ProductId}), 1, []), ...
                Value=app.Model.state().OutputProductId, ...
                Tag="ProjectionSurface3DProductDropDown", ...
                ValueChangedFcn=@(source, ~) app.productChanged(source));
            uilabel(controls, Text="Compare");
            app.ComparisonDropDown = uidropdown(controls, ...
                Items=["None" reshape(string({available.Label}), 1, [])], ...
                ItemsData=["" reshape(string({available.ProductId}), 1, [])], ...
                Tag="ProjectionSurface3DComparisonDropDown", ...
                ValueChangedFcn=@(source, ~) app.comparisonChanged(source));
            uilabel(controls, Text="Color");
            modes = cellstr(ProjectionSurfaceWorkbenchModel.colorModes());
            app.ColorDropDown = uidropdown(controls, Items=modes, ...
                ItemsData=modes, Value=app.Model.state().ColorMode, ...
                Tag="ProjectionSurface3DColorDropDown", ...
                ValueChangedFcn=@(source, ~) app.colorChanged(source));
            uilabel(controls, Text="Max points");
            app.DecimationField = uieditfield(controls, "numeric", ...
                Value=app.Model.state().DecimationLimit, Limits=[1 Inf], ...
                RoundFractionalValues="on", ...
                Tag="ProjectionSurface3DDecimationField", ...
                ValueChangedFcn=@(source, ~) app.decimationChanged(source));
            app.GlyphCheckBox = uicheckbox(controls, ...
                Text="Selected uncertainty", Value=true, ...
                Tag="ProjectionSurface3DGlyphCheckBox", ...
                ValueChangedFcn=@(~, ~) app.refreshGlyph());
            uibutton(controls, Text="Reset view", ...
                Tag="ProjectionSurface3DResetViewButton", ...
                ButtonPushedFcn=@(~, ~) app.resetView());
            state = app.Model.state();
            modes = ProjectionCoordinateFrame.displayModes( ...
                state.CoordinateFrame);
            uilabel(controls, Text="Display");
            app.DisplayFrameDropDown = uidropdown(controls, ...
                Items=cellstr(modes), ItemsData=cellstr(modes), ...
                Value=state.DisplayFrame, ...
                Tag="ProjectionSurface3DDisplayFrameDropDown", ...
                ValueChangedFcn=@(source, ~) app.displayFrameChanged(source));
            uilabel(controls, Text="Z scale");
            app.VerticalExaggerationField = uieditfield(controls, "numeric", ...
                Value=state.VerticalExaggeration, Limits=[0.01 100], ...
                Tag="ProjectionSurface3DVerticalExaggerationField", ...
                ValueChangedFcn=@(source, ~) ...
                app.verticalExaggerationChanged(source));
            app.InspectCheckBox = uicheckbox(controls, ...
                Text="Inspect point", Value=false, ...
                Tag="ProjectionSurface3DInspectCheckBox", ...
                ValueChangedFcn=@(~, ~) app.refresh());
            uibutton(controls, Text="Top", ...
                Tag="ProjectionSurface3DTopViewButton", ...
                ButtonPushedFcn=@(~, ~) app.setViewpoint("top"));
            uibutton(controls, Text="North", ...
                Tag="ProjectionSurface3DNorthViewButton", ...
                ButtonPushedFcn=@(~, ~) app.setViewpoint("north"));
            uibutton(controls, Text="East", ...
                Tag="ProjectionSurface3DEastViewButton", ...
                ButtonPushedFcn=@(~, ~) app.setViewpoint("east"));
            uibutton(controls, Text="Iso", ...
                Tag="ProjectionSurface3DIsometricViewButton", ...
                ButtonPushedFcn=@(~, ~) app.setViewpoint("isometric"));

            app.Axes = uiaxes(app.GridLayout, ...
                Tag="ProjectionSurface3DAxes");
            app.Axes.Layout.Row = 2;
            app.Axes.Layout.Column = [1 2];
            app.configureAxesNavigation();
            grid(app.Axes, "on");
            view(app.Axes, 3);

            side = uigridlayout(app.GridLayout, [3 1], ...
                RowHeight={"fit", "1x", "fit"}, Padding=[0 0 0 0]);
            side.Layout.Row = 2;
            side.Layout.Column = 3;
            titleLabel = uilabel(side, Text="Selected full-source observations", ...
                FontWeight="bold");
            titleLabel.Layout.Row = 1;
            app.SelectionTable = uitable(side, ...
                Data=app.emptyLinkTable(), ...
                ColumnName={"View" "Pass" "Observation" "Column" "Row" "Accepted"}, ...
                Tag="ProjectionSurface3DObservationTable");
            app.SelectionTable.Layout.Row = 2;
            note = uilabel(side, ...
                Text="Glyphs are selected-only and never stored in the catalog.", ...
                WordWrap="on");
            note.Layout.Row = 3;

            app.StatusLabel = uilabel(app.GridLayout, Text="Ready", ...
                Tag="ProjectionSurface3DStatusLabel");
            app.StatusLabel.Layout.Row = 3;
            app.StatusLabel.Layout.Column = [1 3];
        end

        function refresh(app)
            state = app.Model.state();
            camera = app.captureCamera();
            preserveCamera = app.CameraInitialized && ...
                app.LastDisplayFrame == state.DisplayFrame;
            app.CurrentPayload = app.Model.payload( ...
                state.OutputProductId, state.ColorMode);
            app.SelectedDisplayIndex = 0;
            app.SelectionTable.Data = app.emptyLinkTable();
            app.deleteHandles(app.PrimaryHandles);
            app.deleteHandles(app.ComparisonHandles);
            app.deleteHandles(app.GlyphHandles);
            app.PrimaryHandles = gobjects(0);
            app.ComparisonHandles = gobjects(0);
            app.GlyphHandles = gobjects(0);
            app.configureAxesNavigation();
            hold(app.Axes, "on");
            app.PrimaryHandles = app.renderPayload(app.CurrentPayload, false);
            if strlength(state.ComparisonProductId) > 0 && ...
                    state.ComparisonProductId ~= state.OutputProductId
                comparison = app.Model.payload( ...
                    state.ComparisonProductId, state.ColorMode);
                app.ComparisonHandles = app.renderPayload(comparison, true);
            end
            hold(app.Axes, "off");
            names = app.CurrentPayload.AxisNames;
            xlabel(app.Axes, names(1));
            ylabel(app.Axes, names(2));
            zlabel(app.Axes, names(3));
            daspect(app.Axes, [1 1 1 / state.VerticalExaggeration]);
            if preserveCamera
                app.restoreCamera(camera);
            else
                axis(app.Axes, "tight");
                view(app.Axes, 3);
                app.CameraInitialized = true;
            end
            app.LastDisplayFrame = state.DisplayFrame;
            title(app.Axes, app.CurrentPayload.Label + " — " + ...
                state.DisplayFrame, Interpreter="none");
            colorStatus = state.ColorMode;
            if ~app.CurrentPayload.ColorAvailable
                colorStatus = colorStatus + " unavailable (" + ...
                    app.CurrentPayload.ColorUnavailableReason + ")";
            end
            app.StatusLabel.Text = sprintf( ...
                "%d/%d displayed; %s; %s; %s; complete product retained", ...
                app.CurrentPayload.DisplayPointCount, ...
                app.CurrentPayload.FullPointCount, ...
                app.CurrentPayload.Representation, state.DisplayFrame, colorStatus);
        end

        function configureAxesNavigation(app)
            app.Axes.Interactions = [rotateInteraction dataTipInteraction];
            if isempty(app.AxesToolbar) || ~isvalid(app.AxesToolbar)
                app.AxesToolbar = axtoolbar(app.Axes, ...
                    {"rotate", "pan", "zoomin", "zoomout", ...
                    "restoreview", "datacursor"});
            end
            app.AxesToolbar.Visible = "on";
        end

        function handles = renderPayload(app, payload, comparison)
            handles = gobjects(0);
            if payload.DisplayPointCount == 0
                return
            end
            if comparison
                handles = scatter3(app.Axes, payload.PointsDisplay(1, :), ...
                    payload.PointsDisplay(2, :), payload.PointsDisplay(3, :), ...
                    22, [0.35 0.35 0.35], "x", ...
                    Tag="ProjectionSurface3DComparisonObject", ...
                    HitTest="off");
                return
            end
            switch payload.Representation
                case {"pointCloud", "voxel"}
                    marker = 24;
                    if payload.Representation == "voxel"
                        marker = 36;
                    end
                    handles = scatter3(app.Axes, payload.PointsDisplay(1, :), ...
                        payload.PointsDisplay(2, :), payload.PointsDisplay(3, :), ...
                        marker, payload.ColorValues, "filled", ...
                        Tag="ProjectionSurface3DPointObject");
                case "mesh"
                    handles = patch(app.Axes, ...
                        Faces=payload.MeshDisplay.Faces, ...
                        Vertices=payload.MeshDisplay.Vertices.', ...
                        FaceVertexCData=payload.ColorValues(:), ...
                        FaceColor="interp", EdgeColor=[0.25 0.25 0.25], ...
                        Tag="ProjectionSurface3DMeshObject");
                otherwise
                    cdata = nan(size(payload.GridDisplay.Z));
                    cdata(payload.GridDisplay.ValidMask) = payload.ColorValues;
                    handles = surf(app.Axes, payload.GridDisplay.X, ...
                        payload.GridDisplay.Y, payload.GridDisplay.Z, cdata, ...
                        EdgeColor="none", Tag="ProjectionSurface3DGridObject");
            end
            if app.InspectCheckBox.Value
                handles.ButtonDownFcn = @(~, event) app.objectSelected(event);
            end
            colormap(app.Axes, parula(256));
        end

        function updateSelectionTable(app, point)
            links = point.ObservationLinks;
            if isempty(links)
                app.SelectionTable.Data = app.emptyLinkTable();
                return
            end
            app.SelectionTable.Data = table( ...
                reshape(string({links.ViewId}), [], 1), ...
                reshape(string({links.PassId}), [], 1), ...
                reshape(string({links.ObservationId}), [], 1), ...
                reshape([links.SourceColumnPixels], [], 1), ...
                reshape([links.SourceRowPixels], [], 1), ...
                reshape([links.Accepted], [], 1), ...
                VariableNames=["ViewId" "PassId" "ObservationId" ...
                "SourceColumnPixels" "SourceRowPixels" "Accepted"]);
        end

        function updateGlyph(app, point)
            app.deleteHandles(app.GlyphHandles);
            app.GlyphHandles = gobjects(0);
            state = app.Model.state();
            if ~app.GlyphCheckBox.Value || state.MaximumUncertaintyGlyphs < 1
                return
            end
            covariance = ProjectionCoordinateFrame.covarianceToDisplay( ...
                app.CurrentPayload.CoordinateFrame, ...
                point.CovarianceWorldMetersSquared, ...
                app.CurrentPayload.DisplayFrameId);
            if any(~isfinite(covariance), "all")
                return
            end
            [vectors, values] = eig(0.5 * (covariance + covariance.'), "vector");
            scales = sqrt(max(values, 0));
            origin = ProjectionCoordinateFrame.worldToDisplay( ...
                app.CurrentPayload.CoordinateFrame, point.PointWorld, ...
                app.CurrentPayload.DisplayFrameId);
            app.GlyphHandles = gobjects(1, 3);
            held = ishold(app.Axes);
            hold(app.Axes, "on");
            for index = 1:3
                endpoint = vectors(:, index) * scales(index);
                app.GlyphHandles(index) = plot3(app.Axes, ...
                    [origin(1) - endpoint(1) origin(1) + endpoint(1)], ...
                    [origin(2) - endpoint(2) origin(2) + endpoint(2)], ...
                    [origin(3) - endpoint(3) origin(3) + endpoint(3)], ...
                    LineWidth=2, Tag="ProjectionSurface3DUncertaintyGlyph", ...
                    HitTest="off");
            end
            if ~held
                hold(app.Axes, "off");
            end
        end

        function refreshGlyph(app)
            info = app.selectedPointInfo();
            if info.Selected
                app.updateGlyph(info.Point);
            else
                app.deleteHandles(app.GlyphHandles);
                app.GlyphHandles = gobjects(0);
            end
        end

        function objectSelected(app, event)
            if isempty(event) || ~isprop(event, "IntersectionPoint")
                return
            end
            point = double(event.IntersectionPoint(:));
            [~, index] = min(vecnorm( ...
                app.CurrentPayload.PointsDisplay - point, 2, 1));
            app.selectDisplayPoint(index);
        end

        function productChanged(app, source)
            app.Model.configure(struct(OutputProductId=string(source.Value)));
            app.refresh();
        end

        function comparisonChanged(app, source)
            app.Model.configure(struct(ComparisonProductId=string(source.Value)));
            app.refresh();
        end

        function colorChanged(app, source)
            app.Model.configure(struct(ColorMode=string(source.Value)));
            app.refresh();
        end

        function decimationChanged(app, source)
            app.Model.configure(struct(DecimationLimit=source.Value));
            app.refresh();
        end

        function displayFrameChanged(app, source)
            app.Model.configure(struct(DisplayFrame=string(source.Value)));
            app.refresh();
        end

        function verticalExaggerationChanged(app, source)
            app.Model.configure(struct(VerticalExaggeration=source.Value));
            app.refresh();
        end

        function resetView(app)
            view(app.Axes, 3);
            axis(app.Axes, "tight");
            app.CameraInitialized = true;
        end

        function state = captureCamera(app)
            state = struct(Valid=false, Position=zeros(1, 3), ...
                Target=zeros(1, 3), UpVector=zeros(1, 3), ViewAngle=0, ...
                XLim=zeros(1, 2), YLim=zeros(1, 2), ZLim=zeros(1, 2));
            if isempty(app.Axes) || ~isvalid(app.Axes)
                return
            end
            state = struct(Valid=true, Position=app.Axes.CameraPosition, ...
                Target=app.Axes.CameraTarget, ...
                UpVector=app.Axes.CameraUpVector, ...
                ViewAngle=app.Axes.CameraViewAngle, XLim=app.Axes.XLim, ...
                YLim=app.Axes.YLim, ZLim=app.Axes.ZLim);
        end

        function restoreCamera(app, state)
            if ~state.Valid
                return
            end
            app.Axes.XLim = state.XLim;
            app.Axes.YLim = state.YLim;
            app.Axes.ZLim = state.ZLim;
            app.Axes.CameraPosition = state.Position;
            app.Axes.CameraTarget = state.Target;
            app.Axes.CameraUpVector = state.UpVector;
            app.Axes.CameraViewAngle = state.ViewAngle;
        end

        function products = availableProducts(app)
            summaries = app.Model.productSummaries();
            products = summaries(string({summaries.Status}) == "available");
        end

        function tableValue = emptyLinkTable(~)
            tableValue = table(strings(0, 1), strings(0, 1), ...
                strings(0, 1), zeros(0, 1), zeros(0, 1), false(0, 1), ...
                VariableNames=["ViewId" "PassId" "ObservationId" ...
                "SourceColumnPixels" "SourceRowPixels" "Accepted"]);
        end

        function deleteHandles(~, handles)
            handles = handles(isgraphics(handles));
            if ~isempty(handles)
                delete(handles);
            end
        end
    end
end
