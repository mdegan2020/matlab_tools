classdef (Abstract) ProjectionDenseMatcher < handle
    %ProjectionDenseMatcher Common lifecycle for dense matcher extensions.

    methods (Sealed)
        function result = match(matcher, request, options, runtimeControl)
            %match Validate, execute, normalize, and annotate one request.
            if nargin < 3
                options = struct();
            end
            if nargin < 4
                runtimeControl = struct();
            end
            request = ProjectionDenseMatchRequest.validate(request);
            metadata = ProjectionDenseMatcher.validateMetadata( ...
                matcher.metadata());
            options = matcher.validateOptions(options);
            runtimeControl = ProjectionDenseMatcher.validateRuntimeControl( ...
                runtimeControl);
            ProjectionDenseMatcher.throwIfCancelled(runtimeControl);
            ProjectionDenseMatcher.notifyProgress( ...
                runtimeControl, 0, "starting");
            timer = tic;
            try
                rawResult = matcher.matchImpl( ...
                    request, options, runtimeControl);
            catch exception
                if exception.identifier == "ProjectionDenseMatcher:cancelled"
                    rethrow(exception)
                end
                wrapped = MException("ProjectionDenseMatcher:algorithmFailure", ...
                    "Dense matcher '%s' failed: %s", ...
                    metadata.AlgorithmId, exception.message);
                wrapped = addCause(wrapped, exception);
                throw(wrapped)
            end
            ProjectionDenseMatcher.throwIfCancelled(runtimeControl);
            result = ProjectionDenseMatchResult.validate(rawResult, request);
            result.Timing.TotalSeconds = toc(timer);
            result.Execution = ProjectionDenseMatcher.execution( ...
                result.Execution, metadata);
            result.Provenance = ProjectionDenseMatcher.provenance( ...
                result.Provenance, metadata, request, options, ...
                string(class(matcher)));
            result = ProjectionDenseMatchResult.validate(result, request);
            ProjectionDenseMatcher.notifyProgress( ...
                runtimeControl, 1, "completed");
        end
    end

    methods (Abstract)
        metadata = metadata(matcher)
        options = defaultOptions(matcher)
        options = validateOptions(matcher, options)
    end

    methods (Abstract, Access = protected)
        result = matchImpl(matcher, request, options, runtimeControl)
    end

    methods (Static)
        function runtimeControl = validateRuntimeControl(runtimeControl)
            %validateRuntimeControl Normalize progress and cancellation hooks.
            if isempty(runtimeControl)
                runtimeControl = struct();
            end
            if ~isstruct(runtimeControl) || ~isscalar(runtimeControl)
                error("ProjectionDenseMatcher:invalidRuntimeControl", ...
                    "Runtime control must be a scalar struct.");
            end
            defaults = struct(ProgressFcn=[], CancellationFcn=[]);
            names = fieldnames(runtimeControl);
            unknown = setdiff(string(names), string(fieldnames(defaults)));
            if ~isempty(unknown)
                error("ProjectionDenseMatcher:invalidRuntimeControl", ...
                    "Unexpected runtime-control field: %s.", unknown(1));
            end
            for index = 1:numel(names)
                defaults.(names{index}) = runtimeControl.(names{index});
            end
            fields = ["ProgressFcn" "CancellationFcn"];
            for field = fields
                value = defaults.(field);
                if ~(isempty(value) || isa(value, "function_handle"))
                    error("ProjectionDenseMatcher:invalidRuntimeControl", ...
                        "%s must be empty or a function handle.", field);
                end
            end
            runtimeControl = defaults;
        end
    end

    methods (Static, Access = private)
        function metadata = validateMetadata(metadata)
            required = ["AlgorithmId" "Name" "SemanticVersion" ...
                "Capabilities" "RequiredProducts" "Deterministic" ...
                "Precision" "MemoryEstimate" "CpuSupported" "GpuSupported"];
            if ~isstruct(metadata) || ~isscalar(metadata) || ...
                    any(~isfield(metadata, required))
                error("ProjectionDenseMatcher:invalidMetadata", ...
                    "Matcher metadata is incomplete.");
            end
            scalarStrings = ["AlgorithmId" "Name" "SemanticVersion" ...
                "Precision" "MemoryEstimate"];
            for field = scalarStrings
                metadata.(field) = string(metadata.(field));
                if ~isscalar(metadata.(field)) || ...
                        ismissing(metadata.(field)) || ...
                        strlength(metadata.(field)) == 0
                    error("ProjectionDenseMatcher:invalidMetadata", ...
                        "%s must be a nonempty string scalar.", field);
                end
            end
            if isempty(regexp(metadata.AlgorithmId, ...
                    "^[A-Za-z][A-Za-z0-9_.-]*$", "once")) || ...
                    isempty(regexp(metadata.SemanticVersion, ...
                    "^[0-9]+\.[0-9]+\.[0-9]+$", "once"))
                error("ProjectionDenseMatcher:invalidMetadata", ...
                    "AlgorithmId or SemanticVersion is malformed.");
            end
            metadata.RequiredProducts = reshape( ...
                string(metadata.RequiredProducts), 1, []);
            if ~isstruct(metadata.Capabilities) || ...
                    ~isscalar(metadata.Capabilities)
                error("ProjectionDenseMatcher:invalidMetadata", ...
                    "Capabilities must be a scalar struct.");
            end
            logicalFields = ["Deterministic" "CpuSupported" "GpuSupported"];
            for field = logicalFields
                if ~(islogical(metadata.(field)) && isscalar(metadata.(field)))
                    error("ProjectionDenseMatcher:invalidMetadata", ...
                        "%s must be a logical scalar.", field);
                end
            end
        end

        function throwIfCancelled(runtimeControl)
            if ~isempty(runtimeControl.CancellationFcn) && ...
                    logical(runtimeControl.CancellationFcn())
                error("ProjectionDenseMatcher:cancelled", ...
                    "Dense matching was cancelled cooperatively.");
            end
        end

        function notifyProgress(runtimeControl, fraction, stage)
            if isempty(runtimeControl.ProgressFcn)
                return
            end
            runtimeControl.ProgressFcn(struct(Fraction=fraction, Stage=stage));
        end

        function execution = execution(execution, metadata)
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
                provenance, metadata, request, options, matcherClass)
            provenance.AlgorithmId = metadata.AlgorithmId;
            provenance.AlgorithmVersion = metadata.SemanticVersion;
            provenance.MatcherClass = matcherClass;
            provenance.PairId = request.PairId;
            provenance.ViewIds = request.ViewIds;
            provenance.Seed = request.Seed;
            provenance.Precision = metadata.Precision;
            provenance.Deterministic = metadata.Deterministic;
            provenance.OptionsFingerprint = ...
                ProjectionGeometryFingerprint.hash(options);
        end
    end
end
