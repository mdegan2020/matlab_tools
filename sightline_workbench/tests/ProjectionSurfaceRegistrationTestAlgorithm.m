classdef ProjectionSurfaceRegistrationTestAlgorithm < ...
        ProjectionSurfaceRegistrationAlgorithm
    %ProjectionSurfaceRegistrationTestAlgorithm Deliberate failure fixture.

    methods
        function metadata = metadata(~)
            metadata = struct(AlgorithmId="test.registration.failure", ...
                Name="Deliberate registration failure", ...
                SemanticVersion="1.0.0", Capabilities=struct(), ...
                AllowedTransform="globalTranslation", Deterministic=true, ...
                Precision="double", CpuSupported=true, GpuSupported=false);
        end

        function options = defaultOptions(~)
            options = struct();
        end

        function options = validateOptions(~, options)
            if nargin < 2 || isempty(options)
                options = struct();
            end
            if ~isstruct(options) || ~isscalar(options) || ...
                    ~isempty(fieldnames(options))
                error("ProjectionSurfaceRegistrationTestAlgorithm:invalidOptions", ...
                    "The failure fixture accepts no options.");
            end
        end
    end

    methods (Access = protected)
        function result = registerImpl(~, ~, ~, ~) %#ok<STOUT>
            error("ProjectionSurfaceRegistrationTestAlgorithm:intentional", ...
                "Deliberate extension failure.");
        end
    end
end
