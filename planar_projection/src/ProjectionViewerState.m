classdef ProjectionViewerState
    %ProjectionViewerState Serialize and validate projection viewer state.

    properties (Constant)
        Format = "ProjectionViewerState"
        Version = 1
    end

    methods (Static)
        function tf = isState(value)
            %isState Return true for values that look like viewer state input.
            tf = false;
            if ischar(value) || (isstring(value) && isscalar(value))
                tf = true;
                return
            end

            if isstruct(value) && isscalar(value)
                tf = isfield(value, "Projection") || ...
                    isfield(value, "Layers") || isfield(value, "Format");
            end
        end

        function state = validate(state, layerCount)
            %validate Normalize and validate a viewer state struct.
            if ischar(state) || (isstring(state) && isscalar(state))
                state = ProjectionViewerState.read(state);
            end
            if nargin < 2
                layerCount = [];
            end

            if ~isstruct(state) || ~isscalar(state)
                error("ProjectionViewerState:invalidState", ...
                    "Viewer state must be a scalar struct or JSON file path.");
            end

            rawLayers = ProjectionViewerState.requiredField(state, "Layers");
            if isempty(layerCount)
                layerCount = numel(rawLayers);
            end
            layerCount = ProjectionViewerState.validatePositiveInteger( ...
                layerCount, "layerCount");
            if numel(rawLayers) ~= layerCount
                error("ProjectionViewerState:layerCountMismatch", ...
                    "Viewer state layer count must match the scene layer count.");
            end

            state = ProjectionViewerState.validateTopLevel(state);
            state.SelectedLayerIndex = ProjectionViewerState.validateLayerIndex( ...
                ProjectionViewerState.fieldOrDefault(state, "SelectedLayerIndex", ...
                layerCount), layerCount, "SelectedLayerIndex");
            state.Projection = ProjectionViewerState.validateProjection( ...
                ProjectionViewerState.fieldOrDefault(state, "Projection", struct()));
            state.View = ProjectionViewerState.validateView( ...
                ProjectionViewerState.fieldOrDefault(state, "View", struct()));

            for layerIndex = 1:layerCount
                layer = ProjectionViewerState.validateLayer(rawLayers(layerIndex), ...
                    layerIndex);
                if layerIndex == 1
                    layers = layer;
                else
                    layers(layerIndex) = layer;
                end
            end
            state.LayerCount = layerCount;
            state.Layers = layers;

            if isfield(state, "Camera") && ~isempty(state.Camera)
                state.Camera = ProjectionViewerState.validateCamera(state.Camera);
            end
        end

        function jsonText = encode(state)
            %encode Convert a viewer state struct to pretty JSON text.
            state = ProjectionViewerState.validate(state);
            jsonText = jsonencode(state, PrettyPrint=true);
        end

        function state = decode(jsonText, layerCount)
            %decode Decode JSON text into a normalized viewer state struct.
            if nargin < 2
                layerCount = [];
            end
            state = ProjectionViewerState.validate(jsondecode(jsonText), layerCount);
        end

        function write(filePath, state)
            %write Save a viewer state as pretty JSON.
            jsonText = ProjectionViewerState.encode(state);
            filePath = ProjectionViewerState.validateFilePath(filePath);
            fid = fopen(filePath, "w");
            if fid < 0
                error("ProjectionViewerState:fileOpenFailed", ...
                    "Unable to open state file for writing: %s", filePath);
            end
            cleaner = onCleanup(@() fclose(fid));
            fprintf(fid, "%s\n", jsonText);
            clear cleaner
        end

        function state = read(filePath, layerCount)
            %read Load a viewer state from JSON.
            if nargin < 2
                layerCount = [];
            end
            filePath = ProjectionViewerState.validateFilePath(filePath);
            state = ProjectionViewerState.decode(fileread(filePath), layerCount);
        end

        function [scene, state] = applyToScene(scene, state)
            %applyToScene Apply viewer state to a scene without creating an app.
            ProjectionViewerState.validateScene(scene);
            state = ProjectionViewerState.validate(state, numel(scene.layers));
            ProjectionViewerState.validateSceneCompatibility(scene, state);

            plane = ProjectionMeshBuilder.applyPlaneTipTilt( ...
                scene.layers(1).BaseProjectionPlane, ...
                deg2rad(state.Projection.TipDegrees), ...
                deg2rad(state.Projection.TiltDegrees));

            for layerIndex = 1:numel(scene.layers)
                layer = scene.layers(layerIndex);
                layerState = state.Layers(layerIndex);
                layer.Alpha = layerState.Alpha;
                layer.Visible = layerState.Visible;
                layer.BlendMode = string(layerState.BlendMode);
                layer.ProjectionOffsetMeters = layerState.ProjectionOffsetMeters(:);
                layer.ViewVectorAngularOffsetsDegrees = ...
                    layerState.ViewVectorAngularOffsetsDegrees(:);
                layer.CurrentProjectionPlane = plane;
                scene.layers(layerIndex) = layer;
            end
        end
    end

    methods (Static, Access = private)
        function validateScene(scene)
            if ~isstruct(scene) || ~isscalar(scene) || ~isfield(scene, "layers") || ...
                    isempty(scene.layers) || ~isstruct(scene.layers)
                error("ProjectionViewerState:invalidScene", ...
                    "Scene must contain a nonempty struct array of layers.");
            end

            for layerIndex = 1:numel(scene.layers)
                layer = scene.layers(layerIndex);
                if ~isfield(layer, "BaseProjectionPlane") || ...
                        ~isfield(layer, "CurrentProjectionPlane")
                    error("ProjectionViewerState:invalidScene", ...
                        "Scene layers must contain base and current projection planes.");
                end
                PlanarProjection.validatePlane(layer.BaseProjectionPlane);
                PlanarProjection.validatePlane(layer.CurrentProjectionPlane);
            end
        end

        function validateSceneCompatibility(scene, state)
            for layerIndex = 1:numel(scene.layers)
                layer = scene.layers(layerIndex);
                layerState = state.Layers(layerIndex);
                ProjectionViewerState.validateLayerIdentity(layer, layerState, layerIndex);
                ProjectionViewerState.validateLayerImagePath(layer, layerState, layerIndex);
            end
        end

        function validateLayerIdentity(layer, layerState, layerIndex)
            sceneName = string(ProjectionViewerState.fieldOrDefault(layer, ...
                "Name", ""));
            stateName = string(layerState.Name);
            if strlength(sceneName) > 0 && strlength(stateName) > 0 && ...
                    sceneName ~= stateName
                error("ProjectionViewerState:layerOrderMismatch", ...
                    "Viewer state layer %d does not match the scene layer order.", ...
                    layerIndex);
            end
        end

        function validateLayerImagePath(layer, layerState, layerIndex)
            scenePath = string(ProjectionViewerState.fieldOrDefault(layer, ...
                "ImagePath", ""));
            statePath = string(layerState.ImagePath);
            if strlength(scenePath) > 0 && strlength(statePath) > 0 && ...
                    scenePath ~= statePath
                error("ProjectionViewerState:imagePathMismatch", ...
                    "Viewer state layer %d ImagePath does not match the scene layer.", ...
                    layerIndex);
            end
        end

        function state = validateTopLevel(state)
            state.Format = ProjectionViewerState.Format;
            state.Version = ProjectionViewerState.Version;
        end

        function projection = validateProjection(projection)
            if ~isstruct(projection) || ~isscalar(projection)
                error("ProjectionViewerState:invalidProjection", ...
                    "Projection state must be a scalar struct.");
            end
            projection.TipDegrees = ProjectionViewerState.validateFiniteScalar( ...
                ProjectionViewerState.fieldOrDefault(projection, "TipDegrees", 0), ...
                "TipDegrees");
            projection.TiltDegrees = ProjectionViewerState.validateFiniteScalar( ...
                ProjectionViewerState.fieldOrDefault(projection, "TiltDegrees", 0), ...
                "TiltDegrees");
        end

        function view = validateView(view)
            if ~isstruct(view) || ~isscalar(view)
                error("ProjectionViewerState:invalidView", ...
                    "View state must be a scalar struct.");
            end
            view.TwistDegrees = ProjectionViewerState.validateFiniteScalar( ...
                ProjectionViewerState.fieldOrDefault(view, "TwistDegrees", 0), ...
                "TwistDegrees");
        end

        function layer = validateLayer(layer, layerIndex)
            if ~isstruct(layer) || ~isscalar(layer)
                error("ProjectionViewerState:invalidLayer", ...
                    "Each layer state must be a scalar struct.");
            end

            layer.Index = ProjectionViewerState.validatePositiveInteger( ...
                ProjectionViewerState.fieldOrDefault(layer, "Index", layerIndex), ...
                "Layer Index");
            if layer.Index ~= layerIndex
                error("ProjectionViewerState:invalidLayer", ...
                    "Layer state indices must match layer order.");
            end

            layer.Name = string(ProjectionViewerState.fieldOrDefault(layer, ...
                "Name", ""));
            layer.ImagePath = string(ProjectionViewerState.fieldOrDefault(layer, ...
                "ImagePath", ""));
            layer.Alpha = ProjectionViewerState.validateAlpha( ...
                ProjectionViewerState.fieldOrDefault(layer, "Alpha", 1));
            layer.Visible = ProjectionViewerState.validateLogicalScalar( ...
                ProjectionViewerState.fieldOrDefault(layer, "Visible", true), ...
                "Visible");
            layer.BlendMode = ProjectionViewerState.validateBlendMode( ...
                ProjectionViewerState.fieldOrDefault(layer, "BlendMode", "alpha"));
            layer.ProjectionOffsetMeters = ProjectionViewerState.validateVector( ...
                ProjectionViewerState.fieldOrDefault(layer, ...
                "ProjectionOffsetMeters", [0 0]), 2, "ProjectionOffsetMeters");
            layer.ViewVectorAngularOffsetsDegrees = ProjectionViewerState.validateVector( ...
                ProjectionViewerState.fieldOrDefault(layer, ...
                "ViewVectorAngularOffsetsDegrees", [0 0 0]), 3, ...
                "ViewVectorAngularOffsetsDegrees");
        end

        function camera = validateCamera(camera)
            if ~isstruct(camera) || ~isscalar(camera)
                error("ProjectionViewerState:invalidCamera", ...
                    "Camera state must be a scalar struct.");
            end

            camera.Position = ProjectionViewerState.validateVector( ...
                ProjectionViewerState.requiredField(camera, "Position"), 3, ...
                "Camera Position");
            camera.Target = ProjectionViewerState.validateVector( ...
                ProjectionViewerState.requiredField(camera, "Target"), 3, ...
                "Camera Target");
            camera.UpVector = ProjectionViewerState.validateVector( ...
                ProjectionViewerState.requiredField(camera, "UpVector"), 3, ...
                "Camera UpVector");
            camera.ViewAngle = ProjectionViewerState.validatePositiveScalar( ...
                ProjectionViewerState.requiredField(camera, "ViewAngle"), ...
                "Camera ViewAngle");
            camera.Projection = string(ProjectionViewerState.fieldOrDefault( ...
                camera, "Projection", "orthographic"));
            if ~isscalar(camera.Projection) || ...
                    ~any(camera.Projection == ["orthographic", "perspective"])
                error("ProjectionViewerState:invalidCamera", ...
                    "Camera Projection must be orthographic or perspective.");
            end
        end

        function value = requiredField(state, fieldName)
            if ~isfield(state, fieldName)
                error("ProjectionViewerState:missingField", ...
                    "Viewer state must contain %s.", fieldName);
            end
            value = state.(fieldName);
        end

        function value = fieldOrDefault(state, fieldName, defaultValue)
            if isfield(state, fieldName)
                value = state.(fieldName);
            else
                value = defaultValue;
            end
        end

        function value = validateFiniteScalar(value, name)
            if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value)
                error("ProjectionViewerState:invalidScalar", ...
                    "%s must be a finite numeric scalar.", name);
            end
            value = double(value);
        end

        function value = validatePositiveScalar(value, name)
            value = ProjectionViewerState.validateFiniteScalar(value, name);
            if value <= 0
                error("ProjectionViewerState:invalidScalar", ...
                    "%s must be positive.", name);
            end
        end

        function value = validatePositiveInteger(value, name)
            value = ProjectionViewerState.validateFiniteScalar(value, name);
            if value < 1 || fix(value) ~= value
                error("ProjectionViewerState:invalidInteger", ...
                    "%s must be a positive integer.", name);
            end
        end

        function value = validateLayerIndex(value, layerCount, name)
            value = ProjectionViewerState.validatePositiveInteger(value, name);
            if value > layerCount
                error("ProjectionViewerState:invalidLayerIndex", ...
                    "%s must refer to an existing layer.", name);
            end
        end

        function value = validateAlpha(value)
            value = ProjectionViewerState.validateFiniteScalar(value, "Alpha");
            if value < 0 || value > 1
                error("ProjectionViewerState:invalidAlpha", ...
                    "Layer Alpha must be in the range [0, 1].");
            end
        end

        function value = validateLogicalScalar(value, name)
            if ~(islogical(value) || isnumeric(value)) || ~isscalar(value)
                error("ProjectionViewerState:invalidLogical", ...
                    "%s must be a scalar logical value.", name);
            end
            value = logical(value);
        end

        function value = validateBlendMode(value)
            value = string(value);
            if ~isscalar(value) || ~any(value == ["alpha", "redBlueAnaglyph"])
                error("ProjectionViewerState:invalidBlendMode", ...
                    "BlendMode must be alpha or redBlueAnaglyph.");
            end
        end

        function value = validateVector(value, count, name)
            if ~isnumeric(value) || numel(value) ~= count || any(~isfinite(value), "all")
                error("ProjectionViewerState:invalidVector", ...
                    "%s must be a finite numeric %d-vector.", name, count);
            end
            value = double(value(:).');
        end

        function filePath = validateFilePath(filePath)
            if ~(ischar(filePath) || (isstring(filePath) && isscalar(filePath))) || ...
                    strlength(string(filePath)) == 0
                error("ProjectionViewerState:invalidFilePath", ...
                    "File path must be a nonempty character vector or scalar string.");
            end
            filePath = char(filePath);
        end
    end
end
