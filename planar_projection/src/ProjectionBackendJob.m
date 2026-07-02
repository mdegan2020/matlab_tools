classdef ProjectionBackendJob
    %ProjectionBackendJob Validate and serialize backend processor jobs.

    properties (Constant)
        Format = "ProjectionBackendJob"
        Version = 1
    end

    methods (Static)
        function job = create(scene, options)
            %create Build a normalized live backend job from in-memory inputs.
            if nargin < 1
                scene = [];
            end
            if nargin < 2
                options = struct();
            end

            if isempty(options)
                options = struct();
            end
            if ~isstruct(options) || ~isscalar(options)
                error("ProjectionBackendJob:invalidOptions", ...
                    "Job options must be a scalar struct.");
            end

            job = options;
            if ~isempty(scene)
                job.Scene = scene;
            end
            job = ProjectionBackendJob.validate(job);
        end

        function job = validate(job)
            %validate Normalize and validate a backend job struct or job path.
            if ProjectionBackendJob.isPath(job)
                job = ProjectionBackendJob.read(job);
                return
            end
            if ~isstruct(job) || ~isscalar(job)
                error("ProjectionBackendJob:invalidJob", ...
                    "Backend job must be a scalar struct or JSON/MAT file path.");
            end

            job.Format = ProjectionBackendJob.Format;
            job.Version = ProjectionBackendJob.Version;
            job.SceneVariableName = ProjectionBackendJob.validateVariableName( ...
                ProjectionBackendJob.fieldOrDefault(job, "SceneVariableName", "scene"), ...
                "SceneVariableName");
            job.ViewerStateVariableName = ProjectionBackendJob.validateVariableName( ...
                ProjectionBackendJob.fieldOrDefault(job, "ViewerStateVariableName", ...
                "viewerState"), "ViewerStateVariableName");

            hasScene = ProjectionBackendJob.hasFieldValue(job, "Scene");
            hasScenePath = ProjectionBackendJob.hasFieldValue(job, "SceneMatPath");
            if hasScene
                ProjectionBackendJob.validateScene(job.Scene);
            end
            if hasScenePath
                job.SceneMatPath = ProjectionBackendJob.validatePathValue( ...
                    job.SceneMatPath, "SceneMatPath");
            end
            if ~hasScene && ~hasScenePath
                error("ProjectionBackendJob:missingScene", ...
                    "Backend job must contain Scene or SceneMatPath.");
            end

            if ProjectionBackendJob.hasFieldValue(job, "ViewerStatePath")
                job.ViewerStatePath = ProjectionBackendJob.validatePathValue( ...
                    job.ViewerStatePath, "ViewerStatePath");
            end
            if ProjectionBackendJob.hasFieldValue(job, "ViewerState")
                layerCount = ProjectionBackendJob.sceneLayerCount(job);
                job.ViewerState = ProjectionBackendJob.validateViewerState( ...
                    job.ViewerState, layerCount);
            end

            job.RenderOptions = ProjectionBackendJob.validateRenderOptions( ...
                ProjectionBackendJob.mergedRenderOptions(job));
            job.Output = ProjectionBackendJob.validateOutputOptions( ...
                ProjectionBackendJob.fieldOrDefault(job, "Output", struct()));
            job.Execution = ProjectionBackendJob.validateExecutionOptions( ...
                ProjectionBackendJob.fieldOrDefault(job, "Execution", struct()));
        end

        function job = resolvePayloads(job)
            %resolvePayloads Load path-referenced scene and viewer-state payloads.
            job = ProjectionBackendJob.validate(job);

            if ~ProjectionBackendJob.hasFieldValue(job, "Scene") && ...
                    ProjectionBackendJob.hasFieldValue(job, "SceneMatPath")
                job.Scene = ProjectionBackendJob.readScenePayload( ...
                    job.SceneMatPath, job.SceneVariableName);
            end

            if ~ProjectionBackendJob.hasFieldValue(job, "ViewerState") && ...
                    ProjectionBackendJob.hasFieldValue(job, "ViewerStatePath")
                job.ViewerState = ProjectionViewerState.read( ...
                    job.ViewerStatePath, ProjectionBackendJob.sceneLayerCount(job));
            elseif ProjectionBackendJob.hasFieldValue(job, "ViewerState")
                job.ViewerState = ProjectionBackendJob.validateViewerState( ...
                    job.ViewerState, ProjectionBackendJob.sceneLayerCount(job));
            end

            job = ProjectionBackendJob.validate(job);
        end

        function jsonText = encode(job)
            %encode Convert a lightweight backend job to pretty JSON text.
            job = ProjectionBackendJob.validate(job);
            jsonJob = ProjectionBackendJob.toJsonStruct(job);
            jsonText = jsonencode(jsonJob, PrettyPrint=true);
        end

        function job = decode(jsonText)
            %decode Decode backend job JSON into a normalized job struct.
            job = ProjectionBackendJob.validate(jsondecode(jsonText));
        end

        function write(filePath, job)
            %write Save a backend job as JSON or MAT based on file extension.
            filePath = ProjectionBackendJob.validateFilePath(filePath);
            [~, ~, extension] = fileparts(filePath);
            extension = lower(string(extension));

            switch extension
                case ".json"
                    ProjectionBackendJob.writeJson(filePath, job);
                case ".mat"
                    ProjectionBackendJob.writeMat(filePath, job);
                otherwise
                    error("ProjectionBackendJob:unsupportedFileType", ...
                        "Backend job path must end in .json or .mat.");
            end
        end

        function job = read(filePath)
            %read Load a backend job from a JSON or MAT file.
            filePath = ProjectionBackendJob.validateFilePath(filePath);
            if ~isfile(filePath)
                error("ProjectionBackendJob:fileNotFound", ...
                    "Backend job file does not exist: %s", filePath);
            end

            [jobFolder, ~, extension] = fileparts(filePath);
            extension = lower(string(extension));
            switch extension
                case ".json"
                    job = ProjectionBackendJob.decode(fileread(filePath));
                case ".mat"
                    job = ProjectionBackendJob.readMatJob(filePath);
                otherwise
                    error("ProjectionBackendJob:unsupportedFileType", ...
                        "Backend job path must end in .json or .mat.");
            end

            job = ProjectionBackendJob.resolveRelativePaths(job, jobFolder);
            job = ProjectionBackendJob.validate(job);
        end

        function writeScenePayload(filePath, scene, variableName)
            %writeScenePayload Save heavy scene/geometry data to a MAT payload.
            if nargin < 3
                variableName = "scene";
            end
            filePath = ProjectionBackendJob.validateFilePath(filePath);
            variableName = ProjectionBackendJob.validateVariableName( ...
                variableName, "variableName");
            ProjectionBackendJob.validateScene(scene);

            payload = struct();
            payload.(variableName) = scene;
            save(filePath, "-struct", "payload");
        end

        function scene = readScenePayload(filePath, variableName)
            %readScenePayload Load a scene from a MAT payload.
            if nargin < 2
                variableName = "scene";
            end
            filePath = ProjectionBackendJob.validateFilePath(filePath);
            variableName = ProjectionBackendJob.validateVariableName( ...
                variableName, "variableName");
            if ~isfile(filePath)
                error("ProjectionBackendJob:fileNotFound", ...
                    "Scene payload file does not exist: %s", filePath);
            end

            payload = load(filePath);
            if isfield(payload, variableName)
                scene = payload.(variableName);
            else
                names = fieldnames(payload);
                if numel(names) ~= 1
                    error("ProjectionBackendJob:missingPayloadVariable", ...
                        "Scene payload must contain variable %s.", variableName);
                end
                scene = payload.(names{1});
            end

            ProjectionBackendJob.validateScene(scene);
        end
    end

    methods (Static, Access = private)
        function writeJson(filePath, job)
            job = ProjectionBackendJob.validate(job);
            [jobFolder, jobBaseName] = fileparts(filePath);
            if strlength(string(jobFolder)) == 0
                jobFolder = pwd;
            end

            if ProjectionBackendJob.hasFieldValue(job, "Scene")
                if ~ProjectionBackendJob.hasFieldValue(job, "SceneMatPath")
                    scenePayloadName = string(jobBaseName) + "_scene.mat";
                    job.SceneMatPath = scenePayloadName;
                end
                scenePayloadPath = ProjectionBackendJob.resolvePath( ...
                    job.SceneMatPath, jobFolder);
                ProjectionBackendJob.writeScenePayload( ...
                    scenePayloadPath, job.Scene, job.SceneVariableName);
            end

            jsonText = ProjectionBackendJob.encode(job);
            ProjectionBackendJob.writeTextFile(filePath, jsonText);
        end

        function writeMat(filePath, job)
            job = ProjectionBackendJob.validate(job);
            save(filePath, "job");
        end

        function job = readMatJob(filePath)
            payload = load(filePath);
            if isfield(payload, "job")
                job = payload.job;
            elseif isfield(payload, "scene")
                job = struct(Scene=payload.scene);
            else
                names = fieldnames(payload);
                if numel(names) ~= 1
                    error("ProjectionBackendJob:missingJobVariable", ...
                        "MAT backend job must contain variable job or scene.");
                end
                job = payload.(names{1});
            end
        end

        function jsonJob = toJsonStruct(job)
            jsonJob = job;
            if ProjectionBackendJob.hasFieldValue(jsonJob, "Scene")
                if ~ProjectionBackendJob.hasFieldValue(jsonJob, "SceneMatPath")
                    error("ProjectionBackendJob:missingPayloadPath", ...
                        "JSON jobs with live Scene data must include SceneMatPath.");
                end
                jsonJob = rmfield(jsonJob, "Scene");
            end
        end

        function options = mergedRenderOptions(job)
            options = ProjectionBackendJob.defaultRenderOptions();
            if ProjectionBackendJob.hasFieldValue(job, "Scene") && ...
                    isfield(job.Scene, "renderOptions")
                options = ProjectionBackendJob.mergeStruct(options, job.Scene.renderOptions, ...
                    "RenderOptions");
            end
            if isfield(job, "RenderOptions")
                options = ProjectionBackendJob.mergeStruct(options, job.RenderOptions, ...
                    "RenderOptions");
            end
        end

        function options = defaultRenderOptions()
            options = struct();
            options.OutputSize = [];
            options.TileSize = [];
            options.Interpolation = "bilinear";
            options.UseGPU = false;
            options.InvalidIntersectionPolicy = "error";
        end

        function options = validateRenderOptions(options)
            options = ProjectionBackendJob.mergeStruct( ...
                ProjectionBackendJob.defaultRenderOptions(), options, "RenderOptions");
            if ~isempty(options.OutputSize)
                options.OutputSize = ProjectionBackendJob.validateOutputSize( ...
                    options.OutputSize);
            end
            if ~isempty(options.TileSize)
                options.TileSize = ProjectionBackendJob.validateTileSize( ...
                    options.TileSize);
            end
            options.Interpolation = lower(string(options.Interpolation));
            if ~isscalar(options.Interpolation) || ...
                    ~any(options.Interpolation == ["bilinear", "nearest"])
                error("ProjectionBackendJob:invalidRenderOptions", ...
                    "RenderOptions.Interpolation must be bilinear or nearest.");
            end
            options.UseGPU = ProjectionBackendJob.validateLogicalScalar( ...
                options.UseGPU, "RenderOptions.UseGPU");
            if options.UseGPU
                error("ProjectionBackendJob:unsupportedExecution", ...
                    "Backend Milestone 1 supports CPU-only jobs; UseGPU must be false.");
            end
            options.InvalidIntersectionPolicy = string(options.InvalidIntersectionPolicy);
            if ~isscalar(options.InvalidIntersectionPolicy) || ...
                    options.InvalidIntersectionPolicy ~= "error"
                error("ProjectionBackendJob:invalidRenderOptions", ...
                    "RenderOptions.InvalidIntersectionPolicy must be error.");
            end
        end

        function output = validateOutputOptions(output)
            defaults = struct();
            defaults.Directory = "";
            defaults.Formats = ["tiff", "png"];
            defaults.WriteFiles = false;
            defaults.IncludeComposite = true;
            defaults.IncludeLayers = true;

            output = ProjectionBackendJob.mergeStruct(defaults, output, "Output");
            output.Directory = string(output.Directory);
            if ~isscalar(output.Directory)
                error("ProjectionBackendJob:invalidOutput", ...
                    "Output.Directory must be a scalar string.");
            end
            output.Formats = lower(string(output.Formats));
            output.Formats = reshape(output.Formats, 1, []);
            if isempty(output.Formats) || ...
                    any(~ismember(output.Formats, ["tiff", "png"]))
                error("ProjectionBackendJob:invalidOutput", ...
                    "Output.Formats must contain tiff and/or png.");
            end
            output.WriteFiles = ProjectionBackendJob.validateLogicalScalar( ...
                output.WriteFiles, "Output.WriteFiles");
            output.IncludeComposite = ProjectionBackendJob.validateLogicalScalar( ...
                output.IncludeComposite, "Output.IncludeComposite");
            output.IncludeLayers = ProjectionBackendJob.validateLogicalScalar( ...
                output.IncludeLayers, "Output.IncludeLayers");
            if output.WriteFiles && strlength(output.Directory) == 0
                error("ProjectionBackendJob:invalidOutput", ...
                    "Output.Directory is required when Output.WriteFiles is true.");
            end
        end

        function execution = validateExecutionOptions(execution)
            defaults = struct();
            defaults.Mode = "serial";
            defaults.UseGPU = false;

            execution = ProjectionBackendJob.mergeStruct(defaults, execution, "Execution");
            execution.Mode = lower(string(execution.Mode));
            if ~isscalar(execution.Mode) || ...
                    ~ismember(execution.Mode, ["serial", "threads"])
                error("ProjectionBackendJob:invalidExecution", ...
                    "Execution.Mode must be serial or threads.");
            end
            execution.UseGPU = ProjectionBackendJob.validateLogicalScalar( ...
                execution.UseGPU, "Execution.UseGPU");
            if execution.UseGPU
                error("ProjectionBackendJob:unsupportedExecution", ...
                    "Backend Milestone 1 supports CPU-only jobs; Execution.UseGPU must be false.");
            end
        end

        function validateScene(scene)
            if ~isstruct(scene) || ~isscalar(scene) || ...
                    ~isfield(scene, "frameCamera") || ...
                    ~isfield(scene, "renderOrigin") || ...
                    ~isfield(scene, "layers")
                error("ProjectionBackendJob:invalidScene", ...
                    "Scene must contain frameCamera, renderOrigin, and layers.");
            end

            PlanarProjection.validateCamera(scene.frameCamera);
            ProjectionBackendJob.validatePoint(scene.renderOrigin, "scene.renderOrigin");
            if isempty(scene.layers) || ~isstruct(scene.layers)
                error("ProjectionBackendJob:invalidScene", ...
                    "Scene must contain a nonempty struct array of layers.");
            end

            for layerIndex = 1:numel(scene.layers)
                ProjectionBackendJob.validateLayer(scene.layers(layerIndex), layerIndex);
            end
        end

        function validateLayer(layer, layerIndex)
            requiredFields = ["Image", "SourceGeometry", "MeshSampling", ...
                "BaseProjectionPlane", "CurrentProjectionPlane", "Alpha", ...
                "BlendMode", "Visible"];
            if ~isstruct(layer) || ~isscalar(layer) || any(~isfield(layer, requiredFields))
                error("ProjectionBackendJob:invalidLayer", ...
                    "Scene layer %d is missing required backend fields.", layerIndex);
            end

            ProjectionBackendJob.validateImage(layer.Image, layerIndex);
            ProjectionBackendJob.validateSourceGeometry(layer.SourceGeometry, layerIndex);
            ProjectionBackendJob.validateMeshSampling(layer.MeshSampling, layerIndex);
            PlanarProjection.validatePlane(layer.BaseProjectionPlane);
            PlanarProjection.validatePlane(layer.CurrentProjectionPlane);
            ProjectionBackendJob.validateAlpha(layer.Alpha, layerIndex);
            ProjectionBackendJob.validateLogicalScalar(layer.Visible, "layer.Visible");
            ProjectionBackendJob.validateBlendMode(layer.BlendMode, layerIndex);
        end

        function validateImage(imageData, layerIndex)
            if ~(isnumeric(imageData) || islogical(imageData)) || isempty(imageData) || ...
                    ndims(imageData) > 3 || any(~isfinite(imageData), "all")
                error("ProjectionBackendJob:invalidLayer", ...
                    "Scene layer %d Image must be a finite numeric or logical 2-D/3-D array.", ...
                    layerIndex);
            end
            if size(imageData, 3) < 1
                error("ProjectionBackendJob:invalidLayer", ...
                    "Scene layer %d Image must contain at least one band.", layerIndex);
            end
        end

        function validateSourceGeometry(sourceGeometry, layerIndex)
            if ~isstruct(sourceGeometry) || ~isscalar(sourceGeometry) || ...
                    ~isfield(sourceGeometry, "SampleFcn") || ...
                    ~isa(sourceGeometry.SampleFcn, "function_handle")
                error("ProjectionBackendJob:invalidLayer", ...
                    "Scene layer %d SourceGeometry must expose a SampleFcn.", layerIndex);
            end
        end

        function validateMeshSampling(meshSampling, layerIndex)
            if ~isstruct(meshSampling) || ~isscalar(meshSampling) || ...
                    ~isfield(meshSampling, "RowIndices") || ...
                    ~isfield(meshSampling, "ColumnIndices")
                error("ProjectionBackendJob:invalidLayer", ...
                    "Scene layer %d MeshSampling must contain RowIndices and ColumnIndices.", ...
                    layerIndex);
            end
            ProjectionBackendJob.validateIndices(meshSampling.RowIndices, "RowIndices");
            ProjectionBackendJob.validateIndices(meshSampling.ColumnIndices, ...
                "ColumnIndices");
        end

        function state = validateViewerState(state, layerCount)
            if isempty(layerCount)
                state = ProjectionViewerState.validate(state);
            else
                state = ProjectionViewerState.validate(state, layerCount);
            end
        end

        function layerCount = sceneLayerCount(job)
            if ProjectionBackendJob.hasFieldValue(job, "Scene") && ...
                    isfield(job.Scene, "layers")
                layerCount = numel(job.Scene.layers);
            else
                layerCount = [];
            end
        end

        function value = validateOutputSize(value)
            if ~isnumeric(value) || ~isvector(value) || numel(value) ~= 2 || ...
                    any(~isfinite(value)) || any(value < 1) || ...
                    any(fix(value) ~= value)
                error("ProjectionBackendJob:invalidRenderOptions", ...
                    "RenderOptions.OutputSize must be a finite positive 1x2 integer vector.");
            end
            value = double(value(:).');
        end

        function value = validateTileSize(value)
            if ~isnumeric(value) || ~isvector(value) || numel(value) ~= 2 || ...
                    any(~isfinite(value)) || any(value < 1) || ...
                    any(fix(value) ~= value)
                error("ProjectionBackendJob:invalidRenderOptions", ...
                    "RenderOptions.TileSize must be a finite positive 1x2 integer vector.");
            end
            value = double(value(:).');
        end

        function validatePoint(value, name)
            if ~isnumeric(value) || ~isequal(size(value), [3 1]) || ...
                    any(~isfinite(value))
                error("ProjectionBackendJob:invalidScene", ...
                    "%s must be a finite numeric 3x1 vector.", name);
            end
        end

        function validateIndices(indices, name)
            if ~isnumeric(indices) || isempty(indices) || ~isvector(indices) || ...
                    any(~isfinite(indices)) || any(indices < 1) || ...
                    any(fix(indices) ~= indices)
                error("ProjectionBackendJob:invalidLayer", ...
                    "MeshSampling.%s must contain finite positive integer indices.", name);
            end
        end

        function validateAlpha(value, layerIndex)
            if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value) || ...
                    value < 0 || value > 1
                error("ProjectionBackendJob:invalidLayer", ...
                    "Scene layer %d Alpha must be in the range [0, 1].", layerIndex);
            end
        end

        function validateBlendMode(value, layerIndex)
            value = string(value);
            if ~isscalar(value) || ~any(value == ["alpha", "redBlueAnaglyph"])
                error("ProjectionBackendJob:invalidLayer", ...
                    "Scene layer %d BlendMode must be alpha or redBlueAnaglyph.", ...
                    layerIndex);
            end
        end

        function value = validateLogicalScalar(value, name)
            if ~(islogical(value) || isnumeric(value)) || ~isscalar(value)
                error("ProjectionBackendJob:invalidLogical", ...
                    "%s must be a scalar logical value.", name);
            end
            value = logical(value);
        end

        function pathValue = validatePathValue(pathValue, name)
            if ~(ischar(pathValue) || (isstring(pathValue) && isscalar(pathValue))) || ...
                    strlength(string(pathValue)) == 0
                error("ProjectionBackendJob:invalidPath", ...
                    "%s must be a nonempty file path.", name);
            end
            pathValue = string(pathValue);
        end

        function filePath = validateFilePath(filePath)
            if ~(ischar(filePath) || (isstring(filePath) && isscalar(filePath))) || ...
                    strlength(string(filePath)) == 0
                error("ProjectionBackendJob:invalidPath", ...
                    "File path must be a nonempty character vector or scalar string.");
            end
            filePath = char(filePath);
        end

        function variableName = validateVariableName(variableName, name)
            if ~(ischar(variableName) || (isstring(variableName) && isscalar(variableName))) || ...
                    strlength(string(variableName)) == 0 || ...
                    ~isvarname(char(variableName))
                error("ProjectionBackendJob:invalidVariableName", ...
                    "%s must be a valid MATLAB variable name.", name);
            end
            variableName = char(variableName);
        end

        function job = resolveRelativePaths(job, baseDirectory)
            if ProjectionBackendJob.hasFieldValue(job, "SceneMatPath")
                job.SceneMatPath = ProjectionBackendJob.resolvePath( ...
                    job.SceneMatPath, baseDirectory);
            end
            if ProjectionBackendJob.hasFieldValue(job, "ViewerStatePath")
                job.ViewerStatePath = ProjectionBackendJob.resolvePath( ...
                    job.ViewerStatePath, baseDirectory);
            end
        end

        function pathValue = resolvePath(pathValue, baseDirectory)
            pathValue = ProjectionBackendJob.validatePathValue(pathValue, "pathValue");
            if ProjectionBackendJob.isAbsolutePath(pathValue) || ...
                    strlength(string(baseDirectory)) == 0
                return
            end
            pathValue = string(fullfile(baseDirectory, char(pathValue)));
        end

        function tf = isAbsolutePath(pathValue)
            pathValue = char(pathValue);
            tf = startsWith(pathValue, filesep) || startsWith(pathValue, "\\") || ...
                ~isempty(regexp(pathValue, "^[A-Za-z]:[\\/]", "once"));
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

        function output = mergeStruct(defaults, overrides, name)
            if isempty(overrides)
                output = defaults;
                return
            end
            if ~isstruct(overrides) || ~isscalar(overrides)
                error("ProjectionBackendJob:invalidOptions", ...
                    "%s must be a scalar struct.", name);
            end

            output = defaults;
            names = fieldnames(overrides);
            for k = 1:numel(names)
                output.(names{k}) = overrides.(names{k});
            end
        end

        function tf = isPath(value)
            tf = ischar(value) || (isstring(value) && isscalar(value));
        end

        function writeTextFile(filePath, text)
            fid = fopen(filePath, "w");
            if fid < 0
                error("ProjectionBackendJob:fileOpenFailed", ...
                    "Unable to open backend job file for writing: %s", filePath);
            end
            cleaner = onCleanup(@() fclose(fid));
            fprintf(fid, "%s\n", text);
            clear cleaner
        end
    end
end
