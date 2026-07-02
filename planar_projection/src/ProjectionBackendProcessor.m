classdef ProjectionBackendProcessor
    %ProjectionBackendProcessor Backend processor entry facade.

    methods (Static)
        function result = run(jobInput)
            %run Resolve and validate a backend job without rendering yet.
            job = ProjectionBackendJob.resolvePayloads(jobInput);

            result = struct();
            result.Status = "validated";
            result.Format = "ProjectionBackendResult";
            result.Version = 1;
            result.Job = job;
            result.Scene = job.Scene;
            result.RenderOptions = job.RenderOptions;
            result.Output = job.Output;
            result.Execution = job.Execution;
            result.Readback = [];
            result.Message = "Backend Milestone 1 validated the job contract; rendering is implemented in later milestones.";

            if isfield(job, "ViewerState")
                result.ViewerState = job.ViewerState;
            else
                result.ViewerState = [];
            end
        end
    end
end
