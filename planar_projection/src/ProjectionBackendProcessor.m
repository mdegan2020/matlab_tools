classdef ProjectionBackendProcessor
    %ProjectionBackendProcessor Backend processor entry facade.

    methods (Static)
        function result = run(jobInput)
            %run Resolve and validate a backend job without rendering yet.
            job = ProjectionBackendJob.resolvePayloads(jobInput);
            stateApplied = false;
            if isfield(job, "ViewerState")
                [job.Scene, job.ViewerState] = ProjectionViewerState.applyToScene( ...
                    job.Scene, job.ViewerState);
                stateApplied = true;
            end
            outputGrid = ProjectionBackendOutputGrid.plan(job.Scene, ...
                ProjectionBackendProcessor.viewerStateForGrid(job), job.RenderOptions);

            result = struct();
            if stateApplied
                result.Status = "stateApplied";
            else
                result.Status = "validated";
            end
            result.Format = "ProjectionBackendResult";
            result.Version = 1;
            result.Job = job;
            result.Scene = job.Scene;
            result.RenderOptions = job.RenderOptions;
            result.Output = job.Output;
            result.Execution = job.Execution;
            result.OutputGrid = outputGrid;
            result.Readback = [];
            result.Message = "Backend job is resolved and ready for later rendering milestones.";

            if isfield(job, "ViewerState")
                result.ViewerState = job.ViewerState;
            else
                result.ViewerState = [];
            end
        end
    end

    methods (Static, Access = private)
        function viewerState = viewerStateForGrid(job)
            if isfield(job, "ViewerState")
                viewerState = job.ViewerState;
            else
                viewerState = [];
            end
        end
    end
end
