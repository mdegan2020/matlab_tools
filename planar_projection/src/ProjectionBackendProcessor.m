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
            [job, alignment] = ProjectionBackendProcessor.runAlignment(job);
            [outputGrid, preparedLayers] = ProjectionBackendOutputGrid.plan(job.Scene, ...
                ProjectionBackendProcessor.viewerStateForGrid(job), job.RenderOptions);
            renderOptions = ProjectionBackendProcessor.renderOptionsWithGrid( ...
                job.RenderOptions, outputGrid);
            renderOptions = ProjectionBackendProcessor.renderOptionsWithExecution( ...
                renderOptions, job.Execution);
            renderPlan = ProjectionBackendRenderPlan.compile( ...
                job.Scene, renderOptions, preparedLayers);
            renderTimer = tic;
            readback = ProjectionBackendProcessor.renderScene( ...
                job.Scene, renderOptions, job.Execution, renderPlan);
            renderSeconds = toc(renderTimer);

            result = struct();
            result.Status = ProjectionBackendProcessor.resultStatus( ...
                stateApplied, alignment.Enabled);
            result.Format = "ProjectionBackendResult";
            result.Version = 1;
            result.Job = job;
            result.Scene = job.Scene;
            result.RenderOptions = renderOptions;
            result.Output = job.Output;
            result.Execution = job.Execution;
            result.Alignment = alignment;
            result.OutputGrid = outputGrid;
            result.RenderPlan = ProjectionBackendRenderPlan.summary(renderPlan);
            result.Readback = readback;
            result.GpuInfo = readback.GpuInfo;
            result.OutputFiles = [];
            result.Timing = struct(RenderSeconds=renderSeconds, ...
                AlignmentSeconds=alignment.TimingSeconds, ...
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

        function validation = validate(jobInput)
            %validate Resolve and plan a backend job without rendering.
            validationTimer = tic;
            job = ProjectionBackendJob.resolvePayloads(jobInput);
            stateApplied = false;
            if isfield(job, "ViewerState")
                [job.Scene, job.ViewerState] = ProjectionViewerState.applyToScene( ...
                    job.Scene, job.ViewerState);
                stateApplied = true;
            end
            [outputGrid, preparedLayers] = ProjectionBackendOutputGrid.plan(job.Scene, ...
                ProjectionBackendProcessor.viewerStateForGrid(job), job.RenderOptions);
            renderOptions = ProjectionBackendProcessor.renderOptionsWithGrid( ...
                job.RenderOptions, outputGrid);
            renderOptions = ProjectionBackendProcessor.renderOptionsWithExecution( ...
                renderOptions, job.Execution);
            renderPlan = ProjectionBackendRenderPlan.compile( ...
                job.Scene, renderOptions, preparedLayers);

            validation = struct();
            validation.Format = "ProjectionBackendValidation";
            validation.Version = 1;
            validation.Status = "valid";
            validation.StateApplied = stateApplied;
            validation.Job = job;
            validation.RenderOptions = renderOptions;
            validation.Output = job.Output;
            validation.Execution = job.Execution;
            validation.Alignment = job.Alignment;
            validation.OutputGrid = outputGrid;
            validation.RenderPlan = ProjectionBackendRenderPlan.summary(renderPlan);
            validation.GpuInfo = renderPlan.GpuInfo;
            validation.Timing = struct(ValidationSeconds=toc(validationTimer));
            validation.Message = "Backend job resolved and planned successfully.";
        end
    end

    methods (Static, Access = private)
        function renderOptions = renderOptionsWithGrid(renderOptions, outputGrid)
            if isempty(renderOptions.OutputSize)
                renderOptions.OutputSize = outputGrid.OutputSize;
            end
            renderOptions.OutputGrid = outputGrid;
        end

        function renderOptions = renderOptionsWithExecution(renderOptions, execution)
            renderOptions.UseGPU = renderOptions.UseGPU || execution.UseGPU;
        end

        function readback = renderScene( ...
                scene, renderOptions, execution, renderPlan)
            executionMode = lower(string(execution.Mode));
            if executionMode == "threads" || ...
                    (isfield(renderOptions, "TileSize") && ...
                    ~isempty(renderOptions.TileSize))
                readback = ProjectionBackendTiledRenderer.renderScene( ...
                    scene, renderOptions, execution, renderPlan);
            else
                readback = ProjectionReadbackRenderer.renderPlan(renderPlan);
            end
        end

        function [job, alignment] = runAlignment(job)
            alignment = ProjectionBackendProcessor.emptyAlignment(job);
            if ~isfield(job, "Alignment") || ~job.Alignment.Enabled
                return
            end

            alignmentTimer = tic;
            request = ProjectionBackendProcessor.alignmentRequestForJob(job);
            [job.Scene, alignment.Result] = ProjectionAlignmentRunner.run( ...
                job.Scene, request, job.Alignment.RenderOptions);
            job.ViewerState = ProjectionViewerState.fromScene( ...
                job.Scene, ProjectionBackendProcessor.viewerStateForGrid(job));
            alignment.Enabled = true;
            alignment.TimingSeconds = toc(alignmentTimer);
        end

        function request = alignmentRequestForJob(job)
            request = job.Alignment.Request;
            request.Scene = job.Scene;
            request = ProjectionAlignmentRequest.validate(request);
        end

        function alignment = emptyAlignment(job)
            alignment = struct();
            alignment.Enabled = false;
            alignment.Result = [];
            alignment.WriteUpdatedViewerState = false;
            alignment.WriteDiagnostics = false;
            alignment.ViewerStateFileName = "";
            alignment.DiagnosticsFileName = "";
            alignment.TimingSeconds = 0;
            if isfield(job, "Alignment")
                alignment.WriteUpdatedViewerState = ...
                    job.Alignment.WriteUpdatedViewerState;
                alignment.WriteDiagnostics = job.Alignment.WriteDiagnostics;
                alignment.ViewerStateFileName = job.Alignment.ViewerStateFileName;
                alignment.DiagnosticsFileName = job.Alignment.DiagnosticsFileName;
            end
        end

        function status = resultStatus(stateApplied, alignmentApplied)
            if stateApplied && alignmentApplied
                status = "stateAppliedAligned";
            elseif alignmentApplied
                status = "aligned";
            elseif stateApplied
                status = "stateApplied";
            else
                status = "validated";
            end
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
