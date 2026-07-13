classdef ProjectionSurfaceRegistrationService
    %ProjectionSurfaceRegistrationService Direct headless S7 facade.

    methods (Static)
        function result = run(request, algorithm, options, runtimeControl)
            %run Execute registration without opening either viewer.
            if nargin < 2 || isempty(algorithm)
                algorithm = ProjectionRobustDemTranslation();
            end
            if nargin < 3
                options = struct();
            end
            if nargin < 4
                runtimeControl = struct();
            end
            if ~isa(algorithm, "ProjectionSurfaceRegistrationAlgorithm")
                error("ProjectionSurfaceRegistrationService:invalidAlgorithm", ...
                    "Algorithm must derive from the registration base class.");
            end
            result = algorithm.register(request, options, runtimeControl);
        end
    end
end
