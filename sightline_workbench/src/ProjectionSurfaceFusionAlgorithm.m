classdef (Abstract) ProjectionSurfaceFusionAlgorithm < handle
    %ProjectionSurfaceFusionAlgorithm Common lifecycle for fusion extensions.

    methods (Sealed)
        function result = fuse(algorithm, request, options, runtimeControl)
            %fuse Validate, execute, normalize, and annotate one request.
            if nargin < 3
                options = struct();
            end
            if nargin < 4
                runtimeControl = struct();
            end
            request = ProjectionSurfaceFusionRequest.validate(request);
            metadata = ProjectionSurfaceFusionAlgorithm.validateMetadata( ...
                algorithm.metadata());
            options = algorithm.validateOptions(options);
            runtimeControl = ProjectionSurfaceFusionAlgorithm. ...
                validateRuntimeControl(runtimeControl);
            ProjectionSurfaceFusionAlgorithm.throwIfCancelled(runtimeControl);
            ProjectionSurfaceFusionAlgorithm.notifyProgress( ...
                runtimeControl, 0, "starting");
            timer = tic;
            try
                rawResult = algorithm.fuseImpl(request, options, runtimeControl);
            catch exception
                if exception.identifier == ...
                        "ProjectionSurfaceFusionAlgorithm:cancelled"
                    rethrow(exception)
                end
                wrapped = MException( ...
                    "ProjectionSurfaceFusionAlgorithm:algorithmFailure", ...
                    "Surface-fusion algorithm '%s' failed: %s", ...
                    metadata.AlgorithmId, exception.message);
                wrapped = addCause(wrapped, exception);
                throw(wrapped)
            end
            ProjectionSurfaceFusionAlgorithm.throwIfCancelled(runtimeControl);
            rawResult.Timing.TotalSeconds = toc(timer);
            rawResult.Execution = ProjectionSurfaceFusionAlgorithm.execution( ...
                ProjectionSurfaceFusionAlgorithm.field( ...
                rawResult, "Execution", struct()), metadata);
            rawResult.Provenance = ProjectionSurfaceFusionAlgorithm.provenance( ...
                ProjectionSurfaceFusionAlgorithm.field( ...
                rawResult, "Provenance", struct()), metadata, request, ...
                options, string(class(algorithm)));
            result = ProjectionSurfaceFusionResult.validate( ...
                rawResult, request, metadata);
            ProjectionSurfaceFusionAlgorithm.notifyProgress( ...
                runtimeControl, 1, "completed");
        end
    end

    methods (Abstract)
        metadata = metadata(algorithm)
        options = defaultOptions(algorithm)
        options = validateOptions(algorithm, options)
    end

    methods (Abstract, Access = protected)
        result = fuseImpl(algorithm, request, options, runtimeControl)
    end

    methods (Static)
        function runtimeControl = validateRuntimeControl(runtimeControl)
            %validateRuntimeControl Normalize progress and cancellation hooks.
            if isempty(runtimeControl)
                runtimeControl = struct();
            end
            if ~isstruct(runtimeControl) || ~isscalar(runtimeControl)
                error("ProjectionSurfaceFusionAlgorithm:invalidRuntimeControl", ...
                    "Runtime control must be a scalar struct.");
            end
            defaults = struct(ProgressFcn=[], CancellationFcn=[]);
            names = string(fieldnames(runtimeControl));
            unknown = setdiff(names, string(fieldnames(defaults)));
            if ~isempty(unknown)
                error("ProjectionSurfaceFusionAlgorithm:invalidRuntimeControl", ...
                    "Unexpected runtime-control field: %s.", unknown(1));
            end
            for name = names.'
                defaults.(name) = runtimeControl.(name);
            end
            for field = ["ProgressFcn" "CancellationFcn"]
                value = defaults.(field);
                if ~(isempty(value) || isa(value, "function_handle"))
                    error("ProjectionSurfaceFusionAlgorithm:invalidRuntimeControl", ...
                        "%s must be empty or a function handle.", field);
                end
            end
            runtimeControl = defaults;
        end
    end

    methods (Static, Access = protected)
        function throwIfCancelled(runtimeControl)
            %throwIfCancelled Cooperatively stop at deterministic boundaries.
            if ~isempty(runtimeControl.CancellationFcn) && ...
                    logical(runtimeControl.CancellationFcn())
                error("ProjectionSurfaceFusionAlgorithm:cancelled", ...
                    "Surface fusion was cancelled cooperatively.");
            end
        end

        function notifyProgress(runtimeControl, fraction, stage)
            %notifyProgress Publish one runtime-only progress update.
            if ~isempty(runtimeControl.ProgressFcn)
                runtimeControl.ProgressFcn(struct( ...
                    Fraction=double(fraction), Stage=string(stage)));
            end
        end
    end

    methods (Static, Access = private)
        function metadata = validateMetadata(metadata)
            required = ["AlgorithmId" "Name" "SemanticVersion" ...
                "Capabilities" "RequiredProducts" "Deterministic" ...
                "Precision" "MemoryEstimate" "CpuSupported" ...
                "GpuSupported" "ProductRole"];
            if ~isstruct(metadata) || ~isscalar(metadata) || ...
                    any(~isfield(metadata, required))
                error("ProjectionSurfaceFusionAlgorithm:invalidMetadata", ...
                    "Surface-fusion metadata is incomplete.");
            end
            scalarStrings = ["AlgorithmId" "Name" "SemanticVersion" ...
                "Precision" "MemoryEstimate" "ProductRole"];
            for field = scalarStrings
                metadata.(field) = string(metadata.(field));
                if ~isscalar(metadata.(field)) || ...
                        ismissing(metadata.(field)) || ...
                        strlength(metadata.(field)) == 0
                    error("ProjectionSurfaceFusionAlgorithm:invalidMetadata", ...
                        "%s must be a nonempty string scalar.", field);
                end
            end
            if isempty(regexp(metadata.AlgorithmId, ...
                    "^[A-Za-z][A-Za-z0-9_.-]*$", "once")) || ...
                    isempty(regexp(metadata.SemanticVersion, ...
                    "^[0-9]+\.[0-9]+\.[0-9]+$", "once")) || ...
                    ~ismember(metadata.ProductRole, ...
                    ["authoritativeReference" "diagnosticDerived" "exampleOnly"])
                error("ProjectionSurfaceFusionAlgorithm:invalidMetadata", ...
                    "Algorithm identity, semantic version, or product role is malformed.");
            end
            metadata.RequiredProducts = reshape( ...
                string(metadata.RequiredProducts), 1, []);
            if ~isstruct(metadata.Capabilities) || ...
                    ~isscalar(metadata.Capabilities)
                error("ProjectionSurfaceFusionAlgorithm:invalidMetadata", ...
                    "Capabilities must be a scalar struct.");
            end
            for field = ["Deterministic" "CpuSupported" "GpuSupported"]
                if ~islogical(metadata.(field)) || ~isscalar(metadata.(field))
                    error("ProjectionSurfaceFusionAlgorithm:invalidMetadata", ...
                        "%s must be a logical scalar.", field);
                end
            end
        end

        function execution = execution(execution, metadata)
            if ~isstruct(execution) || ~isscalar(execution)
                error("ProjectionSurfaceFusionAlgorithm:invalidExecution", ...
                    "Execution must be a scalar struct.");
            end
            execution.AlgorithmId = metadata.AlgorithmId;
            execution.CpuSupported = metadata.CpuSupported;
            execution.GpuSupported = metadata.GpuSupported;
            if ~isfield(execution, "Device")
                execution.Device = "cpu";
            end
            if ~isfield(execution, "FallbackReason")
                execution.FallbackReason = "";
            end
        end

        function provenance = provenance( ...
                provenance, metadata, request, options, algorithmClass)
            if ~isstruct(provenance) || ~isscalar(provenance)
                error("ProjectionSurfaceFusionAlgorithm:invalidProvenance", ...
                    "Provenance must be a scalar struct.");
            end
            provenance.AlgorithmId = metadata.AlgorithmId;
            provenance.AlgorithmVersion = metadata.SemanticVersion;
            provenance.AlgorithmClass = algorithmClass;
            provenance.ProductRole = metadata.ProductRole;
            provenance.InputPointSetGenerationId = ...
                request.PointSet.GenerationId;
            provenance.WorldFrame = request.PointSet.WorldFrame;
            provenance.RoiWorld = request.RoiWorld;
            provenance.VoxelScalesMeters = request.VoxelScalesMeters;
            provenance.VoxelScaleSource = request.VoxelScaleSource;
            provenance.Seed = request.Seed;
            provenance.Precision = request.PrecisionPolicy;
            provenance.Deterministic = metadata.Deterministic;
            provenance.OptionsFingerprint = ...
                ProjectionGeometryFingerprint.hash(options);
        end

        function value = field(source, name, defaultValue)
            if isfield(source, name)
                value = source.(name);
            else
                value = defaultValue;
            end
        end
    end
end
