classdef (Abstract) ProjectionSurfaceRegistrationAlgorithm < handle
    %ProjectionSurfaceRegistrationAlgorithm Sealed S7 registration lifecycle.

    methods (Sealed)
        function result = register(algorithm, request, options, runtimeControl)
            %register Validate, execute, normalize, and annotate registration.
            if nargin < 3
                options = struct();
            end
            if nargin < 4
                runtimeControl = struct();
            end
            request = ProjectionSurfaceRegistrationRequest.validate(request);
            metadata = ProjectionSurfaceRegistrationAlgorithm. ...
                validateMetadata(algorithm.metadata());
            options = algorithm.validateOptions(options);
            runtimeControl = ProjectionSurfaceRegistrationAlgorithm. ...
                validateRuntimeControl(runtimeControl);
            ProjectionSurfaceRegistrationAlgorithm.throwIfCancelled( ...
                runtimeControl);
            ProjectionSurfaceRegistrationAlgorithm.notifyProgress( ...
                runtimeControl, 0, "starting");
            timer = tic;
            try
                rawResult = algorithm.registerImpl( ...
                    request, options, runtimeControl);
            catch exception
                if exception.identifier == ...
                        "ProjectionSurfaceRegistrationAlgorithm:cancelled"
                    rethrow(exception)
                end
                wrapped = MException( ...
                    "ProjectionSurfaceRegistrationAlgorithm:algorithmFailure", ...
                    "Surface-registration algorithm '%s' failed: %s", ...
                    metadata.AlgorithmId, exception.message);
                wrapped = addCause(wrapped, exception);
                throw(wrapped)
            end
            ProjectionSurfaceRegistrationAlgorithm.throwIfCancelled( ...
                runtimeControl);
            rawResult.Timing.TotalSeconds = toc(timer);
            rawResult.Execution = ProjectionSurfaceRegistrationAlgorithm. ...
                execution(ProjectionSurfaceRegistrationAlgorithm.field( ...
                rawResult, "Execution", struct()), metadata);
            rawResult.Provenance = ProjectionSurfaceRegistrationAlgorithm. ...
                provenance(ProjectionSurfaceRegistrationAlgorithm.field( ...
                rawResult, "Provenance", struct()), metadata, request, ...
                options, string(class(algorithm)));
            result = ProjectionSurfaceRegistrationResult.validate( ...
                rawResult, request, metadata);
            ProjectionSurfaceRegistrationAlgorithm.notifyProgress( ...
                runtimeControl, 1, "completed");
        end
    end

    methods (Abstract)
        metadata = metadata(algorithm)
        options = defaultOptions(algorithm)
        options = validateOptions(algorithm, options)
    end

    methods (Abstract, Access = protected)
        result = registerImpl(algorithm, request, options, runtimeControl)
    end

    methods (Static)
        function runtimeControl = validateRuntimeControl(runtimeControl)
            %validateRuntimeControl Normalize progress and cancellation hooks.
            if isempty(runtimeControl)
                runtimeControl = struct();
            end
            if ~isstruct(runtimeControl) || ~isscalar(runtimeControl)
                error("ProjectionSurfaceRegistrationAlgorithm:invalidRuntimeControl", ...
                    "Runtime control must be a scalar struct.");
            end
            defaults = struct(ProgressFcn=[], CancellationFcn=[]);
            names = string(fieldnames(runtimeControl));
            unknown = setdiff(names, string(fieldnames(defaults)));
            if ~isempty(unknown)
                error("ProjectionSurfaceRegistrationAlgorithm:invalidRuntimeControl", ...
                    "Unexpected runtime-control field: %s.", unknown(1));
            end
            for name = names.'
                defaults.(name) = runtimeControl.(name);
            end
            for field = ["ProgressFcn" "CancellationFcn"]
                value = defaults.(field);
                if ~(isempty(value) || isa(value, "function_handle"))
                    error("ProjectionSurfaceRegistrationAlgorithm:invalidRuntimeControl", ...
                        "%s must be empty or a function handle.", field);
                end
            end
            runtimeControl = defaults;
        end
    end

    methods (Static, Access = protected)
        function throwIfCancelled(runtimeControl)
            if ~isempty(runtimeControl.CancellationFcn) && ...
                    logical(runtimeControl.CancellationFcn())
                error("ProjectionSurfaceRegistrationAlgorithm:cancelled", ...
                    "Surface registration was cancelled cooperatively.");
            end
        end

        function notifyProgress(runtimeControl, fraction, stage)
            if ~isempty(runtimeControl.ProgressFcn)
                runtimeControl.ProgressFcn(struct( ...
                    Fraction=double(fraction), Stage=string(stage)));
            end
        end
    end

    methods (Static, Access = private)
        function metadata = validateMetadata(metadata)
            required = ["AlgorithmId" "Name" "SemanticVersion" ...
                "Capabilities" "AllowedTransform" "Deterministic" ...
                "Precision" "CpuSupported" "GpuSupported"];
            if ~isstruct(metadata) || ~isscalar(metadata) || ...
                    any(~isfield(metadata, required))
                error("ProjectionSurfaceRegistrationAlgorithm:invalidMetadata", ...
                    "Registration metadata is incomplete.");
            end
            fields = ["AlgorithmId" "Name" "SemanticVersion" ...
                "AllowedTransform" "Precision"];
            for field = fields
                metadata.(field) = string(metadata.(field));
                if ~isscalar(metadata.(field)) || ...
                        strlength(metadata.(field)) == 0
                    error("ProjectionSurfaceRegistrationAlgorithm:invalidMetadata", ...
                        "%s must be a nonempty string scalar.", field);
                end
            end
            if isempty(regexp(metadata.AlgorithmId, ...
                    "^[A-Za-z][A-Za-z0-9_.-]*$", "once")) || ...
                    isempty(regexp(metadata.SemanticVersion, ...
                    "^[0-9]+\.[0-9]+\.[0-9]+$", "once")) || ...
                    metadata.AllowedTransform ~= "globalTranslation" || ...
                    metadata.Precision ~= "double" || ...
                    ~isstruct(metadata.Capabilities) || ...
                    ~isscalar(metadata.Capabilities)
                error("ProjectionSurfaceRegistrationAlgorithm:invalidMetadata", ...
                    "Registration identity/capabilities are invalid.");
            end
            for field = ["Deterministic" "CpuSupported" "GpuSupported"]
                if ~islogical(metadata.(field)) || ~isscalar(metadata.(field))
                    error("ProjectionSurfaceRegistrationAlgorithm:invalidMetadata", ...
                        "%s must be a logical scalar.", field);
                end
            end
        end

        function execution = execution(execution, metadata)
            if ~isstruct(execution) || ~isscalar(execution)
                error("ProjectionSurfaceRegistrationAlgorithm:invalidExecution", ...
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
                provenance, metadata, request, options, className)
            if ~isstruct(provenance) || ~isscalar(provenance)
                error("ProjectionSurfaceRegistrationAlgorithm:invalidProvenance", ...
                    "Provenance must be a scalar struct.");
            end
            identity = struct(PointSetGenerationId= ...
                request.PointSet.GenerationId, ...
                DemWorldFrame=request.Dem.WorldFrame, ...
                DemShape=size(request.Dem.HaeHeightsMeters), ...
                DemDatum=request.Dem.HeightReferenceInput, ...
                DemGeoid=request.Dem.GeoidModel, ...
                DemAccuracy=request.Dem.Accuracy, RoiWorld=request.RoiWorld);
            provenance.AlgorithmId = metadata.AlgorithmId;
            provenance.AlgorithmClass = className;
            provenance.AlgorithmSemanticVersion = metadata.SemanticVersion;
            provenance.RequestFormat = request.Format;
            provenance.RequestVersion = request.Version;
            provenance.RequestFingerprint = ...
                ProjectionGeometryFingerprint.hash(identity);
            provenance.PointSetGenerationId = request.PointSet.GenerationId;
            provenance.DemDatumAssumption = request.Dem.DatumAssumption;
            provenance.Options = options;
            provenance.Seed = request.Seed;
            provenance.AutoApplied = false;
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
