classdef ProjectionAlignmentRequest
    %ProjectionAlignmentRequest Validate reusable alignment request structs.

    properties (Constant)
        Format = "ProjectionAlignmentRequest"
        Version = 2
    end

    methods (Static)
        function request = create(scene, options)
            %create Build a normalized alignment request from live inputs.
            if nargin < 1
                scene = [];
            end
            if nargin < 2
                options = struct();
            end

            request = struct();
            if ~isempty(scene)
                request.Scene = scene;
            end
            request.Options = options;
            request = ProjectionAlignmentRequest.validate(request);
        end

        function request = validate(request)
            %validate Normalize and validate an alignment request.
            if nargin < 1 || isempty(request)
                request = struct();
            end
            if ProjectionAlignmentRequest.isPath(request)
                request = ProjectionAlignmentRequest.read(request);
                return
            end
            if ~isstruct(request) || ~isscalar(request)
                error("ProjectionAlignmentRequest:invalidRequest", ...
                    "Alignment request must be a scalar struct or JSON file path.");
            end

            request.Format = ProjectionAlignmentRequest.Format;
            request.Version = ProjectionAlignmentRequest.Version;
            request.SceneVariableName = ProjectionAlignmentRequest.validateVariableName( ...
                ProjectionAlignmentRequest.fieldOrDefault(request, ...
                "SceneVariableName", "scene"), "SceneVariableName");

            hasScene = ProjectionAlignmentRequest.hasFieldValue(request, "Scene");
            hasScenePath = ProjectionAlignmentRequest.hasFieldValue(request, ...
                "SceneMatPath");
            if hasScene
                request.Scene = ProjectionLayerIdentity.ensureScene(request.Scene);
                ProjectionAlignmentRequest.validateScene(request.Scene);
            end
            if hasScenePath
                request.SceneMatPath = ProjectionAlignmentRequest.validatePathValue( ...
                    request.SceneMatPath, "SceneMatPath");
            end

            sceneLayerCount = ProjectionAlignmentRequest.sceneLayerCount(request);
            request.LayerIndices = ProjectionAlignmentRequest.validateLayerIndices( ...
                ProjectionAlignmentRequest.fieldOrDefault(request, "LayerIndices", []), ...
                sceneLayerCount);
            if isempty(request.LayerIndices) && ~isempty(sceneLayerCount)
                request.LayerIndices = 1:sceneLayerCount;
            end

            request.LayerIds = ProjectionAlignmentRequest.validateLayerIds( ...
                ProjectionAlignmentRequest.fieldOrDefault(request, ...
                "LayerIds", strings(1, 0)), request, request.LayerIndices);

            request.ReferenceLayerIndex = ...
                ProjectionAlignmentRequest.validateReferenceLayerIndex( ...
                ProjectionAlignmentRequest.fieldOrDefault(request, ...
                "ReferenceLayerIndex", []), request.LayerIndices);
            request.ReferenceLayerId = ...
                ProjectionAlignmentRequest.validateReferenceLayerId( ...
                ProjectionAlignmentRequest.fieldOrDefault(request, ...
                "ReferenceLayerId", ""), request.LayerIds, ...
                request.LayerIndices, request.ReferenceLayerIndex);
            request.AnalysisBands = ProjectionAlignmentRequest.validateAnalysisBands( ...
                ProjectionAlignmentRequest.fieldOrDefault(request, "AnalysisBands", []), ...
                numel(request.LayerIndices));
            request.Options = ProjectionAlignmentOptions.validate( ...
                ProjectionAlignmentRequest.fieldOrDefault(request, "Options", struct()));

            if ProjectionAlignmentRequest.hasFieldValue(request, "ViewerState")
                request.ViewerState = ProjectionAlignmentRequest.validateViewerState( ...
                    request.ViewerState, sceneLayerCount, request.LayerIndices);
            end
            request.Metadata = ProjectionAlignmentRequest.validateMetadata( ...
                ProjectionAlignmentRequest.fieldOrDefault(request, "Metadata", struct()));
        end

        function jsonRequest = toJsonStruct(request)
            %toJsonStruct Return a JSON-compatible alignment request.
            jsonRequest = ProjectionAlignmentRequest.validate(request);
            jsonRequest.Options = ProjectionAlignmentOptions.toJsonStruct( ...
                jsonRequest.Options);
            if ProjectionAlignmentRequest.hasFieldValue(jsonRequest, "Scene")
                if ~ProjectionAlignmentRequest.hasFieldValue(jsonRequest, "SceneMatPath")
                    error("ProjectionAlignmentRequest:missingPayloadPath", ...
                        "Requests with live Scene data must include SceneMatPath before JSON serialization.");
                end
                jsonRequest = rmfield(jsonRequest, "Scene");
            end
        end

        function jsonText = encode(request)
            %encode Convert an alignment request to pretty JSON text.
            jsonText = jsonencode(ProjectionAlignmentRequest.toJsonStruct(request), ...
                PrettyPrint=true);
        end

        function request = decode(jsonText)
            %decode Decode alignment request JSON.
            request = ProjectionAlignmentRequest.validate(jsondecode(jsonText));
        end

        function write(filePath, request)
            %write Save an alignment request as JSON.
            ProjectionAlignmentRequest.writeTextFile(filePath, ...
                ProjectionAlignmentRequest.encode(request));
        end

        function request = read(filePath)
            %read Load an alignment request from JSON.
            filePath = ProjectionAlignmentRequest.validateFilePath(filePath);
            if ~isfile(filePath)
                error("ProjectionAlignmentRequest:fileNotFound", ...
                    "Alignment request file does not exist: %s", filePath);
            end
            request = ProjectionAlignmentRequest.decode(fileread(filePath));
        end
    end

    methods (Static, Access = private)
        function validateScene(scene)
            if ~isstruct(scene) || ~isscalar(scene) || ~isfield(scene, "layers") || ...
                    isempty(scene.layers) || ~isstruct(scene.layers)
                error("ProjectionAlignmentRequest:invalidScene", ...
                    "Scene must contain a nonempty struct array of layers.");
            end
        end

        function layerCount = sceneLayerCount(request)
            layerCount = [];
            if ProjectionAlignmentRequest.hasFieldValue(request, "Scene") && ...
                    isfield(request.Scene, "layers")
                layerCount = numel(request.Scene.layers);
            end
        end

        function indices = validateLayerIndices(indices, sceneLayerCount)
            if isempty(indices)
                indices = [];
                return
            end
            if ~isnumeric(indices) || ~isvector(indices) || any(~isfinite(indices)) || ...
                    any(indices < 1) || any(fix(indices) ~= indices)
                error("ProjectionAlignmentRequest:invalidLayerIndices", ...
                    "LayerIndices must contain positive integer layer indices.");
            end
            indices = double(reshape(indices, 1, []));
            if numel(unique(indices)) ~= numel(indices)
                error("ProjectionAlignmentRequest:invalidLayerIndices", ...
                    "LayerIndices must not contain duplicates.");
            end
            if ~isempty(sceneLayerCount) && any(indices > sceneLayerCount)
                error("ProjectionAlignmentRequest:invalidLayerIndices", ...
                    "LayerIndices must refer to existing scene layers.");
            end
        end

        function referenceIndex = validateReferenceLayerIndex(referenceIndex, layerIndices)
            if isempty(layerIndices)
                referenceIndex = ProjectionAlignmentRequest.validateOptionalPositiveInteger( ...
                    referenceIndex, "ReferenceLayerIndex");
                return
            end
            if isempty(referenceIndex)
                referenceIndex = layerIndices(ceil(numel(layerIndices) / 2));
                return
            end
            referenceIndex = ProjectionAlignmentRequest.validateOptionalPositiveInteger( ...
                referenceIndex, "ReferenceLayerIndex");
            if ~ismember(referenceIndex, layerIndices)
                error("ProjectionAlignmentRequest:invalidReferenceLayerIndex", ...
                    "ReferenceLayerIndex must be one of the requested LayerIndices.");
            end
        end

        function bands = validateAnalysisBands(bands, layerCount)
            if layerCount == 0
                if isempty(bands)
                    bands = [];
                    return
                end
                bands = ProjectionAlignmentRequest.validatePositiveIntegerVector( ...
                    bands, "AnalysisBands");
                return
            end

            if isempty(bands)
                bands = ones(1, layerCount);
                return
            end
            bands = ProjectionAlignmentRequest.validatePositiveIntegerVector( ...
                bands, "AnalysisBands");
            if isscalar(bands)
                bands = repmat(bands, 1, layerCount);
                return
            end
            if numel(bands) ~= layerCount
                error("ProjectionAlignmentRequest:analysisBandMismatch", ...
                    "AnalysisBands must be scalar or match the number of LayerIndices.");
            end
        end

        function layerIds = validateLayerIds(layerIds, request, layerIndices)
            if isempty(layerIds)
                layerIds = strings(1, 0);
            else
                layerIds = string(layerIds);
                if ~isvector(layerIds) || any(ismissing(layerIds)) || ...
                        any(strlength(strip(layerIds)) == 0) || ...
                        numel(layerIds) ~= numel(layerIndices) || ...
                        numel(unique(layerIds)) ~= numel(layerIds)
                    error("ProjectionAlignmentRequest:invalidLayerIds", ...
                        "LayerIds must uniquely identify each requested layer.");
                end
                layerIds = reshape(strip(layerIds), 1, []);
            end

            if ProjectionAlignmentRequest.hasFieldValue(request, "Scene") && ...
                    ~isempty(layerIndices)
                sceneIds = ProjectionLayerIdentity.idsForIndices( ...
                    request.Scene, layerIndices);
                if isempty(layerIds)
                    layerIds = sceneIds;
                elseif ~isequal(layerIds, sceneIds)
                    error("ProjectionAlignmentRequest:layerIdMismatch", ...
                        "LayerIds must match LayerIndices in the request scene.");
                end
            end
        end

        function referenceLayerId = validateReferenceLayerId( ...
                referenceLayerId, layerIds, layerIndices, referenceLayerIndex)
            referenceLayerId = string(referenceLayerId);
            if ~isscalar(referenceLayerId) || ismissing(referenceLayerId)
                error("ProjectionAlignmentRequest:invalidReferenceLayerId", ...
                    "ReferenceLayerId must be a scalar string.");
            end
            referenceLayerId = strip(referenceLayerId);
            if isempty(layerIds)
                return
            end

            referencePosition = find(layerIndices == referenceLayerIndex, ...
                1, "first");
            expectedId = layerIds(referencePosition);
            if strlength(referenceLayerId) == 0
                referenceLayerId = expectedId;
            elseif referenceLayerId ~= expectedId
                error("ProjectionAlignmentRequest:referenceLayerIdMismatch", ...
                    "ReferenceLayerId must match ReferenceLayerIndex.");
            end
        end

        function state = validateViewerState(state, sceneLayerCount, layerIndices)
            if isempty(sceneLayerCount) && ~isempty(layerIndices)
                sceneLayerCount = max(layerIndices);
            end
            if isempty(sceneLayerCount)
                if ~isstruct(state) || ~isscalar(state)
                    error("ProjectionAlignmentRequest:invalidViewerState", ...
                        "ViewerState must be a scalar struct when layer count is unknown.");
                end
                return
            end
            state = ProjectionViewerState.validate(state, sceneLayerCount);
        end

        function metadata = validateMetadata(metadata)
            if isempty(metadata)
                metadata = struct();
            end
            if ~isstruct(metadata) || ~isscalar(metadata)
                error("ProjectionAlignmentRequest:invalidMetadata", ...
                    "Metadata must be a scalar struct.");
            end
        end

        function value = validateOptionalPositiveInteger(value, name)
            if isempty(value)
                value = [];
                return
            end
            if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value) || ...
                    value < 1 || fix(value) ~= value
                error("ProjectionAlignmentRequest:invalidInteger", ...
                    "%s must be a positive integer.", name);
            end
            value = double(value);
        end

        function value = validatePositiveIntegerVector(value, name)
            if ~isnumeric(value) || isempty(value) || ~isvector(value) || ...
                    any(~isfinite(value)) || any(value < 1) || ...
                    any(fix(value) ~= value)
                error("ProjectionAlignmentRequest:invalidInteger", ...
                    "%s must contain positive integers.", name);
            end
            value = double(reshape(value, 1, []));
        end

        function value = validatePathValue(value, name)
            if ~(ischar(value) || (isstring(value) && isscalar(value))) || ...
                    strlength(string(value)) == 0
                error("ProjectionAlignmentRequest:invalidPath", ...
                    "%s must be a nonempty file path.", name);
            end
            value = string(value);
        end

        function variableName = validateVariableName(variableName, name)
            if ~(ischar(variableName) || (isstring(variableName) && ...
                    isscalar(variableName))) || strlength(string(variableName)) == 0 || ...
                    ~isvarname(char(variableName))
                error("ProjectionAlignmentRequest:invalidVariableName", ...
                    "%s must be a valid MATLAB variable name.", name);
            end
            variableName = char(variableName);
        end

        function value = fieldOrDefault(value, fieldName, defaultValue)
            if isfield(value, fieldName)
                value = value.(fieldName);
            else
                value = defaultValue;
            end
        end

        function tf = hasFieldValue(value, fieldName)
            tf = isstruct(value) && isfield(value, fieldName) && ...
                ~isempty(value.(fieldName));
        end

        function tf = isPath(value)
            tf = ischar(value) || (isstring(value) && isscalar(value));
        end

        function filePath = validateFilePath(filePath)
            if ~(ischar(filePath) || (isstring(filePath) && isscalar(filePath))) || ...
                    strlength(string(filePath)) == 0
                error("ProjectionAlignmentRequest:invalidPath", ...
                    "File path must be a nonempty character vector or scalar string.");
            end
            filePath = char(filePath);
        end

        function writeTextFile(filePath, text)
            filePath = ProjectionAlignmentRequest.validateFilePath(filePath);
            fid = fopen(filePath, "w");
            if fid < 0
                error("ProjectionAlignmentRequest:fileOpenFailed", ...
                    "Unable to open alignment request file for writing: %s", filePath);
            end
            cleaner = onCleanup(@() fclose(fid));
            fprintf(fid, "%s\n", text);
            clear cleaner
        end
    end
end
