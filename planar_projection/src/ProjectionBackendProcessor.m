classdef ProjectionBackendProcessor
    %ProjectionBackendProcessor Backend processor entry facade.

    methods (Static)
        function result = run(jobInput)
            %run Resolve, render, and optionally write a backend job.
            totalTimer = tic;
            job = ProjectionBackendJob.resolvePayloads(jobInput);
            stateApplied = false;
            if isfield(job, "ViewerState")
                [job.Scene, job.ViewerState] = ProjectionViewerState.applyToScene( ...
                    job.Scene, job.ViewerState);
                stateApplied = true;
            end
            outputGrid = ProjectionBackendOutputGrid.plan(job.Scene, ...
                ProjectionBackendProcessor.viewerStateForGrid(job), job.RenderOptions);
            renderOptions = ProjectionBackendProcessor.renderOptionsWithGrid( ...
                job.RenderOptions, outputGrid);
            renderTimer = tic;
            readback = ProjectionReadbackRenderer.renderScene(job.Scene, renderOptions);
            renderSeconds = toc(renderTimer);

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
            result.RenderOptions = renderOptions;
            result.Output = job.Output;
            result.Execution = job.Execution;
            result.OutputGrid = outputGrid;
            result.Readback = readback;
            result.OutputFiles = [];
            result.Timing = struct(RenderSeconds=renderSeconds, ...
                WriteSeconds=0, TotalSeconds=0);
            result.Message = "Backend job rendered successfully.";

            if isfield(job, "ViewerState")
                result.ViewerState = job.ViewerState;
            else
                result.ViewerState = [];
            end

            if result.Output.WriteFiles
                writeTimer = tic;
                result.OutputFiles = ProjectionBackendOutputWriter.write(result);
                result.Timing.WriteSeconds = toc(writeTimer);
            end
            result.Timing.TotalSeconds = toc(totalTimer);
        end
    end

    methods (Static, Access = private)
        function renderOptions = renderOptionsWithGrid(renderOptions, outputGrid)
            if isempty(renderOptions.OutputSize)
                renderOptions.OutputSize = outputGrid.OutputSize;
            end
            renderOptions.OutputGrid = outputGrid;
        end

        function viewerState = viewerStateForGrid(job)
            if isfield(job, "ViewerState")
                viewerState = job.ViewerState;
            else
                viewerState = [];
            end
        end
    end
end
