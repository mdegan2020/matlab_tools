classdef ProjectionBackendCustomGpuKernelPlan
    %ProjectionBackendCustomGpuKernelPlan Assessment for custom GPU kernels.

    properties (Constant)
        Format = "ProjectionBackendCustomGpuKernelPlan"
        Version = 1
    end

    methods (Static)
        function plan = assessment()
            %assessment Return the current custom-kernel decision record.
            plan = struct();
            plan.Format = ProjectionBackendCustomGpuKernelPlan.Format;
            plan.Version = ProjectionBackendCustomGpuKernelPlan.Version;
            plan.CustomKernelsEnabled = false;
            plan.Decision = "notJustifiedWithoutProfileEvidence";
            plan.CpuReference = "ProjectionReadbackRenderer.renderScene";
            plan.MatlabManagedGpuReference = ...
                "ProjectionReadbackRenderer gpuArray compositing path";
            plan.RequiredProfileEvidence = [ ...
                "representative tiled CPU timing", ...
                "representative thread-pool timing", ...
                "MATLAB-managed GPU timing on a GPU-capable workstation", ...
                "identified kernel-level bottleneck after the above paths"];
            plan.CandidateKernel = ProjectionBackendCustomGpuKernelPlan.candidateKernel();
        end

        function validateExecution(execution)
            %validateExecution Reject custom-kernel execution until justified.
            useCustomKernels = ProjectionBackendCustomGpuKernelPlan.fieldOrDefault( ...
                execution, "UseCustomGpuKernels", false);
            useCustomKernels = ProjectionBackendCustomGpuKernelPlan.validateLogicalScalar( ...
                useCustomKernels, "Execution.UseCustomGpuKernels");
            if useCustomKernels
                error("ProjectionBackendCustomGpuKernelPlan:notEnabled", ...
                    "Custom GPU kernels are not enabled without profile evidence and CPU/GPU reference equivalence tests.");
            end
        end
    end

    methods (Static, Access = private)
        function candidate = candidateKernel()
            candidate = struct();
            candidate.Name = "tileProjectionInterpolationKernel";
            candidate.TargetBottleneck = ...
                "per-output-pixel projection and interpolation inside tiled readback";
            candidate.Inputs = [ ...
                "tile output grid coordinates", ...
                "projection plane geometry", ...
                "sampled source image bands", ...
                "sampled source mesh plane coordinates"];
            candidate.Outputs = [ ...
                "tile image bands", ...
                "tile valid mask"];
            candidate.EquivalenceReferences = [ ...
                "CPU readback renderer", ...
                "MATLAB-managed gpuArray compositing path"];
        end

        function value = validateLogicalScalar(value, name)
            if ~(islogical(value) || isnumeric(value)) || ~isscalar(value)
                error("ProjectionBackendCustomGpuKernelPlan:invalidOption", ...
                    "%s must be a scalar logical value.", name);
            end
            value = logical(value);
        end

        function value = fieldOrDefault(value, fieldName, defaultValue)
            if isstruct(value) && isscalar(value) && isfield(value, fieldName)
                value = value.(fieldName);
            else
                value = defaultValue;
            end
        end
    end
end
