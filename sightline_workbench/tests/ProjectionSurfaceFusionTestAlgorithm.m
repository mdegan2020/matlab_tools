classdef ProjectionSurfaceFusionTestAlgorithm < ProjectionSurfaceFusionAlgorithm
    %ProjectionSurfaceFusionTestAlgorithm Controlled failure fixture.

    methods
        function metadata = metadata(~)
            metadata = struct(AlgorithmId="test.failing-fusion", ...
                Name="Controlled failing fusion", SemanticVersion="1.0.0", ...
                Capabilities=struct(), ...
                RequiredProducts="ProjectionMultiRayPointSet", ...
                Deterministic=true, Precision="double", ...
                MemoryEstimate="none", CpuSupported=true, ...
                GpuSupported=false, ProductRole="exampleOnly");
        end

        function options = defaultOptions(~)
            options = struct();
        end

        function options = validateOptions(~, options)
            if isempty(options)
                options = struct();
            end
            if ~isstruct(options) || ~isscalar(options) || ...
                    ~isempty(fieldnames(options))
                error("ProjectionSurfaceFusionTestAlgorithm:invalidOptions", ...
                    "The controlled fixture has no options.");
            end
        end
    end

    methods (Access = protected)
        function result = fuseImpl(~, ~, ~, ~) %#ok<STOUT>
            error("ProjectionSurfaceFusionTestAlgorithm:expectedFailure", ...
                "Controlled algorithm failure.");
        end
    end
end
