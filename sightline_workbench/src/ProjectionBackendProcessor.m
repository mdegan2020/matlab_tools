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
            [renderOptions, returnInMemory] = ...
                ProjectionBackendProcessor.configureOutputExecution( ...
                renderOptions, job.Output, job.Execution, outputGrid);
            renderPlan = ProjectionBackendRenderPlan.compile( ...
                job.Scene, renderOptions, preparedLayers);
            renderTimer = tic;
            preliminaryOutputFiles = [];
            if returnInMemory
                readback = ProjectionBackendProcessor.renderScene( ...
                    job.Scene, renderOptions, job.Execution, renderPlan);
                readback.ReturnedInMemory = true;
                readback.Streaming = false;
                readback.StreamWriteSeconds = 0;
            else
                [readback, preliminaryOutputFiles] = ...
                    ProjectionBackendProcessor.streamScene( ...
                    job, renderOptions, renderPlan);
            end
            renderSeconds = toc(renderTimer);

            result = struct();
            result.Status = ProjectionBackendProcessor.resultStatus( ...
                stateApplied, alignment.Enabled, alignment.Applied);
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
            result.OutputFiles = preliminaryOutputFiles;
            result.Timing = struct(RenderSeconds=renderSeconds, ...
                AlignmentSeconds=alignment.TimingSeconds, ...
                WriteSeconds=readback.StreamWriteSeconds, TotalSeconds=0);
            result.Message = "Backend job rendered successfully.";

            if isfield(job, "ViewerState")
                result.ViewerState = job.ViewerState;
            else
                result.ViewerState = [];
            end

            if result.Output.WriteFiles
                writeTimer = tic;
                if result.Readback.Streaming
                    result.OutputFiles = ProjectionBackendOutputWriter.complete( ...
                        result, result.OutputFiles);
                else
                    result.OutputFiles = ProjectionBackendOutputWriter.write(result);
                end
                result.Timing.WriteSeconds = result.Timing.WriteSeconds + ...
                    toc(writeTimer);
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
            [renderOptions, ~] = ...
                ProjectionBackendProcessor.configureOutputExecution( ...
                renderOptions, job.Output, job.Execution, outputGrid);
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

        function [renderOptions, returnInMemory] = configureOutputExecution( ...
                renderOptions, output, execution, outputGrid)
            pixelCount = double(outputGrid.PixelCount);
            maximumPixels = double(output.MaximumInMemoryPixels);
            policy = lower(string(output.InMemoryPolicy));
            if policy == "always" && pixelCount > maximumPixels
                error("ProjectionBackendProcessor:inMemoryLimitExceeded", ...
                    "Output has %g pixels, above Output.MaximumInMemoryPixels=%g.", ...
                    pixelCount, maximumPixels);
            end
            if ~output.WriteFiles
                if pixelCount > maximumPixels
                    error("ProjectionBackendProcessor:inMemoryLimitExceeded", ...
                        "A non-writing job must return its %g pixels in memory, above Output.MaximumInMemoryPixels=%g.", ...
                        pixelCount, maximumPixels);
                end
                returnInMemory = true;
                return
            end
            returnInMemory = policy == "always" || ...
                (policy == "auto" && pixelCount <= maximumPixels);
            if returnInMemory
                return
            end
            if lower(string(execution.Mode)) ~= "serial"
                error("ProjectionBackendProcessor:streamingRequiresSerial", ...
                    "Bounded output streaming requires Execution.Mode=""serial"" until Backend Performance Pack 3.");
            end
            formats = reshape(lower(string(output.Formats)), 1, []);
            if ~isequal(formats, "tiff")
                error("ProjectionBackendProcessor:streamingRequiresTiff", ...
                    "Bounded output streaming currently requires Output.Formats=""tiff""; PNG remains an in-memory format.");
            end
            if isempty(renderOptions.TileSize)
                renderOptions.TileSize = [256 256];
            end
            if any(mod(renderOptions.TileSize, 16) ~= 0)
                error("ProjectionBackendProcessor:invalidStreamingTileSize", ...
                    "Streaming TIFF TileSize dimensions must be multiples of 16.");
            end
            renderOptions.IncludeLayerReadbacks = output.IncludeLayers;
            renderOptions.IncludeQueryCoordinates = false;
        end

        function [readback, outputFiles] = streamScene( ...
                job, renderOptions, renderPlan)
            writer = ProjectionBackendTiffTileWriter( ...
                job.Output, job.Scene.layers, renderPlan.LayerIndices, ...
                renderPlan.OutputSize, renderOptions.TileSize);
            cleanup = onCleanup(@() writer.abort());
            consumer = @(tile, tileReadback) ...
                writer.writeTile(tile, tileReadback);
            readback = ProjectionBackendTiledRenderer.streamScene( ...
                job.Scene, renderOptions, job.Execution, renderPlan, consumer);
            outputFiles = writer.finalize();
            clear cleanup
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
            alignment.Applied = logical( ...
                alignment.Result.Diagnostics.Applied);
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
            alignment.Applied = false;
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

        function status = resultStatus(stateApplied, alignmentEnabled, ...
                alignmentApplied)
            if alignmentEnabled && ~alignmentApplied
                if stateApplied
                    status = "stateAppliedAlignmentRejected";
                else
                    status = "alignmentRejected";
                end
            elseif stateApplied && alignmentApplied
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
