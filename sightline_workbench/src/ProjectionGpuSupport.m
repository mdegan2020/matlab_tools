classdef ProjectionGpuSupport
    %ProjectionGpuSupport Shared capability checks for optional gpuArray work.

    methods (Static)
        function info = resolve(requested)
            %resolve Return effective GPU state for an optional request.
            if nargin < 1
                requested = false;
            end
            requested = ProjectionGpuSupport.validateLogicalScalar( ...
                requested, "requested");
            capability = ProjectionGpuSupport.capability();
            info = capability;
            info.Requested = requested;
            info.Enabled = requested && capability.Available;
            if requested && ~capability.Available
                info.FallbackReason = capability.Reason;
            else
                info.FallbackReason = "";
            end
        end

        function info = capability()
            %capability Probe MATLAB-managed gpuArray availability.
            info = struct(Available=false, DeviceCount=0, ...
                DeviceIndex=[], DeviceName="", Reason="");
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
            catch exception
                info.Reason = "Unable to select a GPU device: " + ...
                    string(exception.message);
            end
        end
    end

    methods (Static, Access = private)
        function value = validateLogicalScalar(value, name)
            if ~(islogical(value) || isnumeric(value)) || ~isscalar(value)
                error("ProjectionGpuSupport:invalidOption", ...
                    "%s must be a scalar logical value.", name);
            end
            value = logical(value);
        end
    end
end
