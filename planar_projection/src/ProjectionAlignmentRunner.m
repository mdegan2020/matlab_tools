classdef ProjectionAlignmentRunner
    %ProjectionAlignmentRunner Execute the reusable alignment pipeline.

    methods (Static)
        function [alignedScene, result] = run(scene, request, renderOptions)
            %run Render working images, match/filter features, solve, and apply.
            if nargin < 2
                request = struct();
            end
            if nargin < 3
                renderOptions = struct();
            end

            scene = ProjectionLayerIdentity.ensureScene(scene);
            ProjectionAlignmentRunner.validateScene(scene);
            request = ProjectionAlignmentRunner.requestWithScene(scene, request);
            options = request.Options;
            totalTimer = tic;

            workingTimer = tic;
            workingImages = ProjectionAlignmentWorkingImageRenderer.render( ...
                scene, request, renderOptions);
            workingSeconds = toc(workingTimer);

            matchingTimer = tic;
            matchResult = ProjectionAlignmentFeatureMatcher.match( ...
                workingImages, options);
            matchingSeconds = toc(matchingTimer);

            filteringTimer = tic;
            filteredMatches = ProjectionAlignmentMatchFilter.filter( ...
                matchResult, options, scene);
            filteringSeconds = toc(filteringTimer);

            solveTimer = tic;
            result = ProjectionAlignmentOpkSolver.solve( ...
                scene, filteredMatches, options);
            solveSeconds = toc(solveTimer);

            applyTimer = tic;
            alignedScene = ProjectionAlignmentOpkSolver.applyCorrections( ...
                scene, result);
            applySeconds = toc(applyTimer);

            result = ProjectionAlignmentRunner.addDiagnostics( ...
                result, request, workingImages, matchResult, filteredMatches, ...
                workingSeconds, matchingSeconds, filteringSeconds, solveSeconds, ...
                applySeconds, toc(totalTimer));
        end
    end

    methods (Static, Access = private)
        function request = requestWithScene(scene, request)
            if isempty(request)
                request = struct();
            end
            if ~isstruct(request) || ~isscalar(request)
                error("ProjectionAlignmentRunner:invalidRequest", ...
                    "Alignment request must be a scalar struct.");
            end
            request.Scene = scene;
            request = ProjectionAlignmentRequest.validate(request);
        end

        function result = addDiagnostics(result, request, workingImages, ...
                matchResult, filteredMatches, workingSeconds, matchingSeconds, ...
                filteringSeconds, solveSeconds, applySeconds, totalSeconds)
            result.Timing.TotalSeconds = totalSeconds;
            result.Timing.StageSeconds.WorkingImages = workingSeconds;
            result.Timing.StageSeconds.Matching = matchingSeconds;
            result.Timing.StageSeconds.Filtering = filteringSeconds;
            result.Timing.StageSeconds.Solver = solveSeconds;
            result.Timing.StageSeconds.ApplyCorrections = applySeconds;
            result.Diagnostics.Request = ...
                ProjectionAlignmentRunner.requestDiagnostics(request);
            result.Diagnostics.WorkingImages = ...
                ProjectionAlignmentRunner.workingImageDiagnostics(workingImages);
            result.Diagnostics.Matching = matchResult.Diagnostics;
            result.Diagnostics.Filtering = filteredMatches.Diagnostics;
            result = ProjectionAlignmentResult.validate(result);
        end

        function diagnostics = requestDiagnostics(request)
            diagnostics = struct();
            diagnostics.LayerIndices = request.LayerIndices;
            diagnostics.LayerIds = request.LayerIds;
            diagnostics.ReferenceLayerIndex = request.ReferenceLayerIndex;
            diagnostics.ReferenceLayerId = request.ReferenceLayerId;
            diagnostics.AnalysisBands = request.AnalysisBands;
            diagnostics.LossMode = request.Options.LossMode;
            diagnostics.SchedulingStrategy = request.Options.Scheduling.Strategy;
        end

        function diagnostics = workingImageDiagnostics(workingImages)
            diagnostics = struct();
            diagnostics.LayerIndices = workingImages.LayerIndices;
            diagnostics.LayerIds = workingImages.LayerIds;
            diagnostics.ReferenceLayerIndex = workingImages.ReferenceLayerIndex;
            diagnostics.ReferenceLayerId = workingImages.ReferenceLayerId;
            diagnostics.AnalysisBands = workingImages.AnalysisBands;
            diagnostics.OutputSize = workingImages.OutputSize;
            diagnostics.Schedule = workingImages.Schedule;
            diagnostics.PairOverlapCounts = [workingImages.PairOverlapMasks.Count];
        end

        function validateScene(scene)
            if ~isstruct(scene) || ~isscalar(scene) || ~isfield(scene, "layers") || ...
                    ~isfield(scene, "renderOrigin") || isempty(scene.layers)
                error("ProjectionAlignmentRunner:invalidScene", ...
                    "Scene must contain renderOrigin and nonempty layers.");
            end
        end
    end
end
