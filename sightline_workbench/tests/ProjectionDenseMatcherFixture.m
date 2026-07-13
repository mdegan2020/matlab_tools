classdef ProjectionDenseMatcherFixture < ProjectionDenseMatcher
    %ProjectionDenseMatcherFixture Deterministic SDK conformance matcher.

    methods
        function metadata = metadata(~)
            metadata = struct(AlgorithmId="test.fixture", ...
                Name="Test fixture matcher", SemanticVersion="1.0.0", ...
                Capabilities=struct(Geometry="mappedGrid"), ...
                RequiredProducts=strings(1, 0), Deterministic=true, ...
                Precision="double", MemoryEstimate="constant", ...
                CpuSupported=true, GpuSupported=false);
        end

        function options = defaultOptions(~)
            options = struct(Count=4, ResultMode="valid");
        end

        function options = validateOptions(matcher, options)
            defaults = matcher.defaultOptions();
            if isempty(options)
                options = struct();
            end
            if ~isstruct(options) || ~isscalar(options)
                error("ProjectionDenseMatcherFixture:invalidOptions", ...
                    "Options must be a scalar struct.");
            end
            names = fieldnames(options);
            unknown = setdiff(string(names), string(fieldnames(defaults)));
            if ~isempty(unknown)
                error("ProjectionDenseMatcherFixture:invalidOptions", ...
                    "Unexpected option: %s.", unknown(1));
            end
            for index = 1:numel(names)
                defaults.(names{index}) = options.(names{index});
            end
            if ~isnumeric(defaults.Count) || ~isscalar(defaults.Count) || ...
                    ~isfinite(defaults.Count) || defaults.Count < 1 || ...
                    fix(defaults.Count) ~= defaults.Count
                error("ProjectionDenseMatcherFixture:invalidOptions", ...
                    "Count must be a positive integer.");
            end
            defaults.ResultMode = string(defaults.ResultMode);
            if ~isscalar(defaults.ResultMode) || ...
                    ~ismember(defaults.ResultMode, ["valid" "forbidden" "error"])
                error("ProjectionDenseMatcherFixture:invalidOptions", ...
                    "ResultMode must be valid, forbidden, or error.");
            end
            options = defaults;
        end
    end

    methods (Access = protected)
        function result = matchImpl(~, request, options, ~)
            if options.ResultMode == "error"
                error("ProjectionDenseMatcherFixture:expectedFailure", ...
                    "Expected fixture algorithm failure.");
            end
            indices = find(request.OverlapMask, options.Count, "first");
            movingRows = request.SourceRows{1}(indices);
            movingColumns = request.SourceColumns{1}(indices);
            referenceRows = request.SourceRows{2}(indices);
            referenceColumns = request.SourceColumns{2}(indices);
            count = numel(indices);
            result = struct( ...
                MovingSourceRows=movingRows, ...
                MovingSourceColumns=movingColumns, ...
                ReferenceSourceRows=referenceRows, ...
                ReferenceSourceColumns=referenceColumns, ...
                States=repmat("valid", count, 1), ...
                Score=zeros(count, 1), Confidence=ones(count, 1), ...
                Diagnostics=struct(Fixture=true), ...
                Execution=struct(Device="cpu"));
            if options.ResultMode == "forbidden"
                result.Surface = struct();
            end
        end
    end
end
