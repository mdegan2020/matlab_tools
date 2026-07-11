classdef ProjectionBackendGpuSupport
    %ProjectionBackendGpuSupport Capability checks for optional GPU execution.

    methods (Static)
        function info = resolve(requested)
            %resolve Return the effective GPU mode for a requested job.
            if nargin < 1
                requested = false;
            end
            requested = ProjectionBackendGpuSupport.validateLogicalScalar( ...
                requested, "requested");
            capability = ProjectionBackendGpuSupport.capability();

            info = capability;
            info.Requested = requested;
            info.Enabled = requested && capability.Available;
            if ~requested
                info.FallbackReason = "";
            elseif capability.Available
                info.FallbackReason = "";
            else
                info.FallbackReason = capability.Reason;
            end
        end

        function info = capability()
            %capability Probe MATLAB-managed gpuArray availability.
            info = struct();
            info.Available = false;
            info.DeviceCount = 0;
            info.DeviceIndex = [];
            info.DeviceName = "";
            info.Reason = "";

            if exist("gpuDeviceCount", "file") ~= 2 || ...
                    exist("gpuDevice", "file") ~= 2 || ...
                    exist("gpuArray", "file") ~= 2
                info.Reason = "MATLAB gpuArray support is not installed.";
                return
            end

            try
                info.DeviceCount = gpuDeviceCount;
            catch exception
                info.Reason = "Unable to query GPU devices: " + ...
                    string(exception.message);
                return
            end

            if info.DeviceCount < 1
                info.Reason = "No supported GPU device is available.";
                return
            end

            try
                device = gpuDevice;
                info.Available = true;
                info.DeviceIndex = device.Index;
                info.DeviceName = string(device.Name);
                info.Reason = "";
            catch exception
                info.Reason = "Unable to select a GPU device: " + ...
                    string(exception.message);
            end
        end
    end

    methods (Static, Access = private)
        function value = validateLogicalScalar(value, name)
            if ~(islogical(value) || isnumeric(value)) || ~isscalar(value)
                error("ProjectionBackendGpuSupport:invalidOption", ...
                    "%s must be a scalar logical value.", name);
            end
            value = logical(value);
        end
    end
end
