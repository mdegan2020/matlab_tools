classdef ProjectionBackendGpuSupport
    %ProjectionBackendGpuSupport Capability checks for optional GPU execution.

    methods (Static)
        function info = resolve(requested)
            %resolve Return the effective GPU mode for a requested job.
            if nargin < 1
                requested = false;
            end
            try
                info = ProjectionGpuSupport.resolve(requested);
            catch exception
                if exception.identifier == "ProjectionGpuSupport:invalidOption"
                    error("ProjectionBackendGpuSupport:invalidOption", ...
                        "%s", exception.message);
                end
                rethrow(exception)
            end
        end

        function info = capability()
            %capability Probe MATLAB-managed gpuArray availability.
            info = ProjectionGpuSupport.capability();
        end
    end
end
