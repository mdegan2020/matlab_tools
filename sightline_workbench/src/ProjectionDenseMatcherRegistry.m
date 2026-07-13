classdef ProjectionDenseMatcherRegistry < handle
    %ProjectionDenseMatcherRegistry Explicit caller-owned matcher registry.

    properties (Access = private)
        Matchers cell = cell(1, 0)
        AlgorithmIds (1, :) string = strings(1, 0)
    end

    methods
        function registry = ProjectionDenseMatcherRegistry(matchers)
            %ProjectionDenseMatcherRegistry Construct from explicit instances.
            if nargin < 1
                matchers = cell(1, 0);
            end
            if ~iscell(matchers) || ~isvector(matchers)
                error("ProjectionDenseMatcherRegistry:invalidMatchers", ...
                    "Matchers must be a cell vector of matcher instances.");
            end
            for index = 1:numel(matchers)
                registry.register(matchers{index});
            end
        end

        function register(registry, matcher)
            %register Add one explicit matcher instance.
            if ~isa(matcher, "ProjectionDenseMatcher")
                error("ProjectionDenseMatcherRegistry:invalidMatcher", ...
                    "Registered values must derive from ProjectionDenseMatcher.");
            end
            metadata = matcher.metadata();
            algorithmId = string(metadata.AlgorithmId);
            if ~isscalar(algorithmId) || strlength(algorithmId) == 0
                error("ProjectionDenseMatcherRegistry:invalidMatcher", ...
                    "Matcher AlgorithmId must be a nonempty string scalar.");
            end
            if ismember(algorithmId, registry.AlgorithmIds)
                error("ProjectionDenseMatcherRegistry:duplicateMatcher", ...
                    "Matcher '%s' is already registered.", algorithmId);
            end
            registry.AlgorithmIds(end + 1) = algorithmId;
            registry.Matchers{end + 1} = matcher;
        end

        function matcher = resolve(registry, algorithmId)
            %resolve Return a registered matcher without dynamic loading.
            algorithmId = string(algorithmId);
            index = find(registry.AlgorithmIds == algorithmId, 1, "first");
            if isempty(index)
                error("ProjectionDenseMatcherRegistry:unknownMatcher", ...
                    "Matcher '%s' is not explicitly registered.", algorithmId);
            end
            matcher = registry.Matchers{index};
        end

        function ids = list(registry)
            %list Return registered algorithm IDs in insertion order.
            ids = registry.AlgorithmIds;
        end
    end
end
