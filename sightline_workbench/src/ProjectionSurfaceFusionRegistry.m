classdef ProjectionSurfaceFusionRegistry < handle
    %ProjectionSurfaceFusionRegistry Explicit caller-owned fusion registry.

    properties (Access = private)
        Algorithms cell = cell(1, 0)
        AlgorithmIds (1, :) string = strings(1, 0)
    end

    methods
        function registry = ProjectionSurfaceFusionRegistry(algorithms)
            %ProjectionSurfaceFusionRegistry Construct from explicit instances.
            if nargin < 1
                algorithms = cell(1, 0);
            end
            if ~iscell(algorithms) || ~isvector(algorithms)
                error("ProjectionSurfaceFusionRegistry:invalidAlgorithms", ...
                    "Algorithms must be a cell vector of fusion instances.");
            end
            for index = 1:numel(algorithms)
                registry.register(algorithms{index});
            end
        end

        function register(registry, algorithm)
            %register Add one explicit surface-fusion instance.
            if ~isa(algorithm, "ProjectionSurfaceFusionAlgorithm")
                error("ProjectionSurfaceFusionRegistry:invalidAlgorithm", ...
                    "Registered values must derive from ProjectionSurfaceFusionAlgorithm.");
            end
            metadata = algorithm.metadata();
            algorithmId = string(metadata.AlgorithmId);
            if ~isscalar(algorithmId) || ismissing(algorithmId) || ...
                    strlength(algorithmId) == 0
                error("ProjectionSurfaceFusionRegistry:invalidAlgorithm", ...
                    "Fusion AlgorithmId must be a nonempty string scalar.");
            end
            if ismember(algorithmId, registry.AlgorithmIds)
                error("ProjectionSurfaceFusionRegistry:duplicateAlgorithm", ...
                    "Fusion algorithm '%s' is already registered.", algorithmId);
            end
            registry.AlgorithmIds(end + 1) = algorithmId;
            registry.Algorithms{end + 1} = algorithm;
        end

        function algorithm = resolve(registry, algorithmId)
            %resolve Return a registered instance without dynamic loading.
            algorithmId = string(algorithmId);
            index = find(registry.AlgorithmIds == algorithmId, 1, "first");
            if isempty(index)
                error("ProjectionSurfaceFusionRegistry:unknownAlgorithm", ...
                    "Fusion algorithm '%s' is not explicitly registered.", ...
                    algorithmId);
            end
            algorithm = registry.Algorithms{index};
        end

        function ids = list(registry)
            %list Return registered IDs in insertion order.
            ids = registry.AlgorithmIds;
        end
    end
end
