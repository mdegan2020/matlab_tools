classdef ProjectionSurfaceRegistrationRegistry < handle
    %ProjectionSurfaceRegistrationRegistry Explicit caller-owned registry.

    properties (Access = private)
        Algorithms cell = cell(1, 0)
        AlgorithmIds (1, :) string = strings(1, 0)
    end

    methods
        function registry = ProjectionSurfaceRegistrationRegistry(algorithms)
            if nargin < 1
                algorithms = cell(1, 0);
            end
            if ~iscell(algorithms) || ~isvector(algorithms)
                error("ProjectionSurfaceRegistrationRegistry:invalidAlgorithms", ...
                    "Algorithms must be a cell vector of registration instances.");
            end
            for index = 1:numel(algorithms)
                registry.register(algorithms{index});
            end
        end

        function register(registry, algorithm)
            if ~isa(algorithm, "ProjectionSurfaceRegistrationAlgorithm")
                error("ProjectionSurfaceRegistrationRegistry:invalidAlgorithm", ...
                    "Values must derive from ProjectionSurfaceRegistrationAlgorithm.");
            end
            metadata = algorithm.metadata();
            algorithmId = string(metadata.AlgorithmId);
            if ~isscalar(algorithmId) || strlength(algorithmId) == 0
                error("ProjectionSurfaceRegistrationRegistry:invalidAlgorithm", ...
                    "AlgorithmId must be explicit.");
            end
            if ismember(algorithmId, registry.AlgorithmIds)
                error("ProjectionSurfaceRegistrationRegistry:duplicateAlgorithm", ...
                    "Registration algorithm '%s' is already registered.", ...
                    algorithmId);
            end
            registry.AlgorithmIds(end + 1) = algorithmId;
            registry.Algorithms{end + 1} = algorithm;
        end

        function algorithm = resolve(registry, algorithmId)
            index = find(registry.AlgorithmIds == string(algorithmId), ...
                1, "first");
            if isempty(index)
                error("ProjectionSurfaceRegistrationRegistry:unknownAlgorithm", ...
                    "Registration algorithm '%s' is not registered.", algorithmId);
            end
            algorithm = registry.Algorithms{index};
        end

        function ids = list(registry)
            ids = registry.AlgorithmIds;
        end
    end
end
