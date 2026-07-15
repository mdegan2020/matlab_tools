classdef ProjectionSurfaceWorkbenchRunner < handle
    %ProjectionSurfaceWorkbenchRunner Scene-bound dense-surface orchestration.

    properties (Constant)
        Format = "ProjectionSurfaceWorkbenchRun"
        Version = 2
    end

    properties (Access = private)
        Context struct
        MatcherRegistry ProjectionDenseMatcherRegistry
        FusionRegistry ProjectionSurfaceFusionRegistry
        LastRuntimeEvent struct = struct()
    end

    methods
        function runner = ProjectionSurfaceWorkbenchRunner(context, registries)
            %ProjectionSurfaceWorkbenchRunner Bind portable inputs to runtimes.
            if nargin < 2
                registries = struct();
            end
            runner.Context = ...
                ProjectionSurfaceWorkbenchRunner.validateContext(context);
            if isfield(registries, "MatcherRegistry")
                runner.MatcherRegistry = registries.MatcherRegistry;
            else
                runner.MatcherRegistry = ProjectionDenseMatcherRegistry( ...
                    {ProjectionDenseSgmMatcher(), ...
                    ProjectionDenseTemplateMatcher()});
            end
            if isfield(registries, "FusionRegistry")
                runner.FusionRegistry = registries.FusionRegistry;
            else
                runner.FusionRegistry = ProjectionSurfaceFusionRegistry( ...
                    {ProjectionRobustMultiRayFusion(), ...
                    ProjectionExampleSurfaceFusion()});
            end
            if ~isa(runner.MatcherRegistry, "ProjectionDenseMatcherRegistry") || ...
                    ~isa(runner.FusionRegistry, ...
                    "ProjectionSurfaceFusionRegistry")
                error("ProjectionSurfaceWorkbenchRunner:invalidRegistries", ...
                    "Matcher and fusion registries must use the public SDK registries.");
            end
        end

        function catalog = initialCatalog(runner)
            %initialCatalog Build a sparse-bootstrap scene-bound catalog.
            records = ProjectionSurfaceWorkbenchRunner.emptyRecords();
            entries = runner.Context.PairEntries;
            for index = 1:numel(entries)
                result = ProjectionSurfaceWorkbenchRunner. ...
                    sparseResult(entries(index).Request);
                records = [records runner.recordsForResult( ...
                    entries(index), result, "sparse-bootstrap", Inf)]; %#ok<AGROW>
            end
            bootstrapOptions = ProjectionDenseObservationAssociator.defaults();
            bootstrapOptions.MinimumPairAngleDegrees = 0;
            bootstrapOptions.MinimumTextureScore = 0;
            bootstrapOptions.MinimumNavigationWeight = 0;
            bootstrapOptions.MinimumRadiometricConsistency = 0;
            bootstrapReconstruction = ProjectionMultiRayReconstructor.defaults();
            bootstrapReconstruction.MaximumResidualMeters = 1e6;
            bootstrapReconstruction.MaximumConditionNumber = 1e14;
            [pointSet, status, association] = runner.reconstruct( ...
                records, bootstrapOptions, bootstrapReconstruction);
            if status ~= "succeeded"
                accepted = 0;
                tracks = 0;
                if isfield(association, "Diagnostics")
                    accepted = association.Diagnostics.AcceptedPairRecordCount;
                    tracks = association.Diagnostics.TrackCount;
                end
                error("ProjectionSurfaceWorkbenchRunner:noBootstrapSurface", ...
                    "The selected alignment evidence cannot form a finite " + ...
                    "scene-bound bootstrap surface (%d accepted records, " + ...
                    "%d tracks).", accepted, tracks);
            end
            pointSet.Provenance.SurfaceWorkbenchRun = struct( ...
                Kind="sparseBootstrap", ...
                PairIds=string({entries.PairId}), ...
                ActivePairId=runner.Context.ActivePairId);
            catalog = ProjectionSurfaceProductCatalog.create(pointSet, {});
        end

        function configuration = initialConfiguration(~, catalog)
            %initialConfiguration Select all eligible multi-view evidence.
            catalog = ProjectionSurfaceProductCatalog.validate(catalog);
            configuration = struct( ...
                SelectedViewIds=catalog.ViewIds, ...
                SelectedPassIds=catalog.PassIds, ...
                SelectedPairIds=catalog.PairIds, PairSchedule="quality", ...
                DenseMethod="currentSgm", GeometrySearch="sparseSeeded", ...
                ExecutionPath="cpu", ConsistencyPolicy="balanced", ...
                MaximumObservations=5000, ...
                MaximumAssociationRecords=50000, ...
                FusionAlgorithm="robustMultiRay", ...
                ProcessingStage="robustMultiView");
        end

        function report = preflight(runner, state)
            %preflight Describe exact pair, matcher, search, and resource work.
            [entries, pairDecisions] = runner.schedulePlan(state);
            [matcher, matcherId, supported, reason, fallback] = ...
                runner.resolveMatcher(state);
            metadata = struct();
            options = struct();
            if supported
                metadata = matcher.metadata();
                options = runner.matcherOptions(matcher, state);
            end
            pixels = zeros(1, numel(entries));
            overlaps = zeros(1, numel(entries));
            for index = 1:numel(entries)
                request = entries(index).Request;
                pixels(index) = numel(request.AnalysisImages{1});
                overlaps(index) = nnz(request.OverlapMask);
            end
            scheduledViewIds = strings(1, 0);
            scheduledPassIds = strings(1, 0);
            if ~isempty(entries)
                scheduledViewIds = unique([entries.ViewIds], "stable");
                scheduledPassIds = unique([entries.PassIds], "stable");
            end
            associationBudgets = runner.associationBudgets(entries, state);
            requestedAssociationRecords = numel(entries) * ...
                double(state.MaximumObservations);
            maximumScheduledAssociationRecords = sum(associationBudgets);
            budgetApplied = maximumScheduledAssociationRecords < ...
                requestedAssociationRecords;
            budgetAdvice = "";
            if budgetApplied
                budgetAdvice = sprintf( ...
                    "Total association budget limits %d requested records " + ...
                    "to %d, distributed deterministically across pairs.", ...
                    requestedAssociationRecords, ...
                    maximumScheduledAssociationRecords);
            end
            report = struct(Format="ProjectionSurfaceWorkbenchPreflight", ...
                Version=1, Supported=supported, Reason=reason, ...
                PairSchedule=string(state.PairSchedule), ...
                SelectedPairIds=string({entries.PairId}), ...
                SelectedViewIds=reshape(string(state.SelectedViewIds), 1, []), ...
                SelectedPassIds=reshape(string(state.SelectedPassIds), 1, []), ...
                ScheduledViewIds=scheduledViewIds, ...
                ScheduledPassIds=scheduledPassIds, ...
                CoordinateFrame=runner.Context.CoordinateFrame, ...
                PairDecisions=pairDecisions, ...
                MatcherAlgorithmId=matcherId, MatcherMetadata=metadata, ...
                MatcherOptions=options, ...
                GeometrySearch=string(state.GeometrySearch), ...
                RectificationState=runner.rectificationState(state), ...
                SearchBounds=runner.searchBounds(options, state), ...
                ConsistencyPolicy=string(state.ConsistencyPolicy), ...
                OcclusionPolicy=string(state.OcclusionPolicy), ...
                ExecutionPath=string(state.ExecutionPath), ...
                FallbackReason=fallback, ...
                ProcessingStage=string(state.ProcessingStage), ...
                FusionAlgorithm=string(state.FusionAlgorithm), ...
                ReconstructionStages=["pairwise" "association" ...
                "robustMultiRay" string(state.ProcessingStage)], ...
                EvidenceExplanation=[ ...
                "All scheduled pair evidence is offered to stable-observation association. " ...
                "Validity, confidence, occlusion, consistency, connectivity, residual, and conditioning gates select contributing rays."], ...
                ResourceEstimate=struct(PairCount=numel(entries), ...
                AnalysisPixelCount=sum(pixels), ...
                OverlapPixelCount=sum(overlaps), ...
                MaximumObservations=double(state.MaximumObservations), ...
                MaximumObservationsPerPair= ...
                double(state.MaximumObservations), ...
                RequestedAssociationRecordCount= ...
                requestedAssociationRecords, ...
                MaximumAssociationRecords= ...
                double(state.MaximumAssociationRecords), ...
                MaximumScheduledAssociationRecords= ...
                maximumScheduledAssociationRecords, ...
                AssociationRecordsPerPair=associationBudgets, ...
                AssociationBudgetApplied=budgetApplied, ...
                AssociationBudgetAdvice=budgetAdvice, ...
                ApproximateInputBytes=8 * 8 * sum(pixels), ...
                Bounded=true, IsWallClockPrediction=false));
        end

        function outcome = run(runner, state, runtimeControl)
            %run Execute selected pairwise, reconstruction, and fusion stages.
            if nargin < 3
                runtimeControl = struct();
            end
            runtimeControl = ProjectionSurfaceWorkbenchRunner. ...
                validateRuntimeControl(runtimeControl);
            preflight = runner.preflight(state);
            outcome = ProjectionSurfaceWorkbenchRunner.emptyOutcome(preflight);
            if ~preflight.Supported
                outcome.Status = "unsupported";
                outcome.Message = preflight.Reason;
                return
            end
            entries = runner.scheduledEntries(state);
            if isempty(entries)
                outcome.Status = "empty";
                outcome.Message = "No eligible pair is selected.";
                return
            end
            [matcher, matcherId] = runner.resolveMatcher(state);
            options = runner.matcherOptions(matcher, state);
            associationBudgets = runner.associationBudgets(entries, state);
            records = ProjectionSurfaceWorkbenchRunner.emptyRecords();
            pairRuns = repmat( ...
                ProjectionSurfaceWorkbenchRunner.emptyPairRun(), ...
                1, numel(entries));
            completed = 0;
            outcome.ProcessingStage = "pairwise";
            for index = 1:numel(entries)
                if ProjectionSurfaceWorkbenchRunner.cancelled(runtimeControl)
                    outcome.Status = "cancelled";
                    outcome.Message = "Cancellation accepted between pair stages.";
                    outcome.PairRuns = pairRuns(1:completed);
                    outcome.Diagnostics = runner.runDiagnostics( ...
                        outcome.PairRuns, struct(), struct(), struct());
                    return
                end
                entry = entries(index);
                base = (index - 1) / numel(entries);
                span = 0.7 / numel(entries);
                runner.publishProgress(runtimeControl, base * 0.7, ...
                    "pairwise", sprintf("Running %s (%d/%d)", ...
                    entry.PairId, index, numel(entries)));
                matcherRuntime = struct( ...
                    ProgressFcn=@(event) runner.forwardMatcherProgress( ...
                    runtimeControl, event, base, span, entry.PairId), ...
                    CancellationFcn=@() ...
                    ProjectionSurfaceWorkbenchRunner.cancelled(runtimeControl));
                pairRun = ProjectionSurfaceWorkbenchRunner.emptyPairRun();
                pairRun.PairId = entry.PairId;
                pairRun.ViewIds = entry.ViewIds;
                pairRun.MatcherAlgorithmId = matcherId;
                pairRun.Status = "running";
                pairRun.Stage = "matching";
                pairRun.Options = options;
                pairStarted = tic;
                try
                    result = matcher.match(entry.Request, options, matcherRuntime);
                    pairRecords = runner.recordsForResult(entry, result, ...
                        matcherId, associationBudgets(index));
                    records = [records pairRecords]; %#ok<AGROW>
                    pairRun.Status = "succeeded";
                    pairRun.Stage = "completed";
                    pairRun.CandidateCount = numel(result.States);
                    pairRun.AcceptedCorrespondenceCount = ...
                        nnz(result.States == "valid");
                    pairRun.RecordCount = numel(pairRecords);
                    pairRun.StateCounts = ...
                        ProjectionSurfaceWorkbenchRunner.stateCounts( ...
                        result.States);
                    pairRun.Execution = result.Execution;
                    pairRun.Provenance = result.Provenance;
                    pairRun.Evidence = runner.evidence(entry.Request, result);
                    outcome.LastCompletedPairId = entry.PairId;
                catch exception
                    if ProjectionSurfaceWorkbenchRunner. ...
                            isCancellationException(exception)
                        outcome.Status = "cancelled";
                        outcome.Message = "Cancellation accepted during pair matching.";
                        pairRun.Status = "cancelled";
                        pairRun.Identifier = string(exception.identifier);
                        pairRun.Message = string(exception.message);
                        pairRun.ElapsedSeconds = toc(pairStarted);
                        pairRuns(index) = pairRun;
                        outcome.PairRuns = pairRuns(1:index);
                        outcome.Diagnostics = runner.runDiagnostics( ...
                            outcome.PairRuns, struct(), struct(), struct());
                        return
                    end
                    pairRun.Status = "failed";
                    pairRun.Identifier = string(exception.identifier);
                    pairRun.Message = string(exception.message);
                    failure = ProjectionSurfaceWorkbenchRunner. ...
                        exceptionEvidence(exception);
                    pairRun.CauseIdentifier = failure.ExceptionIdentifier;
                    pairRun.CauseMessage = failure.ExceptionMessage;
                    pairRun.Failure = failure;
                end
                pairRun.ElapsedSeconds = toc(pairStarted);
                completed = index;
                pairRuns(index) = pairRun;
            end
            outcome.PairRuns = pairRuns;
            if isempty(records)
                failed = find(string({pairRuns.Status}) == "failed", 1);
                if isempty(failed)
                    outcome.Status = "empty";
                    outcome.Message = ...
                        "Matchers produced no finite valid pair observations.";
                else
                    outcome.Status = "failed";
                    outcome.Message = "Pair matching failed: " + ...
                        pairRuns(failed).Message;
                    outcome.Identifier = pairRuns(failed).Identifier;
                end
                outcome.Diagnostics = runner.runDiagnostics( ...
                    pairRuns, struct(), struct(), struct());
                return
            end
            runner.publishProgress(runtimeControl, 0.72, "association", ...
                "Associating stable full-source observations");
            associationOptions = runner.associationOptions(state);
            outcome.ProcessingStage = "association";
            runner.LastRuntimeEvent = struct();
            reconstructionRuntime = struct( ...
                AssociationProgressFcn=@(event) ...
                runner.forwardAssociationProgress(runtimeControl, event), ...
                ReconstructionProgressFcn=@(event) ...
                runner.forwardReconstructionProgress(runtimeControl, event), ...
                CancellationFcn=@() ...
                ProjectionSurfaceWorkbenchRunner.cancelled(runtimeControl));
            try
                [pointSet, reconstructionStatus, association] = ...
                    runner.reconstruct(records, associationOptions, struct(), ...
                    reconstructionRuntime);
            catch exception
                outcome.PairRuns = pairRuns;
                outcome.Identifier = string(exception.identifier);
                outcome.StageDiagnostics = runner.LastRuntimeEvent;
                if ProjectionSurfaceWorkbenchRunner. ...
                        isCancellationException(exception)
                    outcome.Status = "cancelled";
                    outcome.Message = ...
                        "Cancellation accepted during association or reconstruction.";
                else
                    outcome.Status = "failed";
                    outcome.Message = "Association or reconstruction failed: " + ...
                        string(exception.message);
                end
                outcome.Diagnostics = runner.runDiagnostics( ...
                    pairRuns, struct(), struct(), struct());
                return
            end
            if reconstructionStatus ~= "succeeded"
                outcome.Status = "empty";
                outcome.Message = ...
                    "Pair observations were rejected or geometrically ill-conditioned.";
                outcome.Diagnostics = runner.runDiagnostics( ...
                    pairRuns, association, struct(), struct());
                outcome.Association = association;
                outcome.StageDiagnostics = struct( ...
                    Association=association.Diagnostics.StageWorkCounts);
                return
            end
            runProvenance = struct( ...
                MatcherAlgorithmIds=unique(string( ...
                {pairRuns.MatcherAlgorithmId}), "stable"), ...
                PairIds=string({entries.PairId}), ...
                PairSchedule=string(state.PairSchedule), ...
                GeometrySearch=string(state.GeometrySearch), ...
                ConsistencyPolicy=string(state.ConsistencyPolicy), ...
                OcclusionPolicy=string(state.OcclusionPolicy), ...
                ExecutionPath=string(state.ExecutionPath), ...
                MaximumObservations=double(state.MaximumObservations), ...
                MaximumAssociationRecords= ...
                double(state.MaximumAssociationRecords), ...
                ProcessingStage=string(state.ProcessingStage), ...
                FusionAlgorithm=string(state.FusionAlgorithm));
            pointSet.Provenance.SurfaceWorkbenchRun = runProvenance;
            outcome.ProcessingStage = "reconstructionComplete";
            fusionResults = cell(1, 0);
            fusionResult = struct();
            if runner.needsFusion(state.ProcessingStage)
                runner.publishProgress(runtimeControl, 0.88, "fusion", ...
                    "Running selected surface fusion");
                outcome.ProcessingStage = "fusion";
                algorithm = runner.resolveFusion(state.FusionAlgorithm);
                request = runner.fusionRequest(pointSet);
                fusionRuntime = struct( ...
                    ProgressFcn=@(event) runner.forwardFusionProgress( ...
                    runtimeControl, event), ...
                    CancellationFcn=@() ...
                    ProjectionSurfaceWorkbenchRunner.cancelled(runtimeControl));
                try
                    fusionResult = algorithm.fuse( ...
                        request, algorithm.defaultOptions(), fusionRuntime);
                    fusionResults = {fusionResult};
                catch exception
                    if ProjectionSurfaceWorkbenchRunner. ...
                            isCancellationException(exception)
                        outcome.Status = "cancelled";
                        outcome.Message = "Cancellation accepted during fusion.";
                        outcome.PairRuns = pairRuns;
                        outcome.Association = association;
                        outcome.PointSet = pointSet;
                        outcome.Diagnostics = runner.runDiagnostics( ...
                            pairRuns, association, pointSet, struct());
                        return
                    end
                    outcome.Status = "failed";
                    outcome.Message = "Fusion failed: " + string(exception.message);
                    outcome.Identifier = string(exception.identifier);
                    outcome.PairRuns = pairRuns;
                    outcome.Association = association;
                    outcome.PointSet = pointSet;
                    outcome.Diagnostics = runner.runDiagnostics( ...
                        pairRuns, association, pointSet, struct());
                    return
                end
            end
            catalog = ProjectionSurfaceProductCatalog.create( ...
                pointSet, fusionResults);
            runner.publishProgress(runtimeControl, 1, "completed", ...
                "Surface products are ready for review");
            outcome.Status = "succeeded";
            if any(string({pairRuns.Status}) == "failed")
                outcome.Status = "partial";
            end
            outcome.Message = sprintf( ...
                "%d pair(s), %d valid reconstructed point(s).", ...
                numel(entries), pointSet.Diagnostics.ValidPointCount);
            outcome.Catalog = catalog;
            outcome.Association = association;
            outcome.PointSet = pointSet;
            outcome.FusionResult = fusionResult;
            outcome.Diagnostics = runner.runDiagnostics( ...
                pairRuns, association, pointSet, fusionResult);
            outcome.Provenance = runProvenance;
            outcome.ProcessingStage = "completed";
            outcome.StageDiagnostics = struct( ...
                Association=association.Diagnostics.StageWorkCounts, ...
                Reconstruction=pointSet.Diagnostics);
        end

        function ids = pairIds(runner)
            %pairIds Return all exact scene-bound pair identities.
            ids = string({runner.Context.PairEntries.PairId});
        end
    end

    methods (Access = private)
        function entries = scheduledEntries(runner, state)
            [entries, ~] = runner.schedulePlan(state);
        end

        function [entries, decisions] = schedulePlan(runner, state)
            candidates = runner.Context.PairEntries;
            count = numel(candidates);
            selectedViews = reshape(string(state.SelectedViewIds), 1, []);
            selectedPasses = reshape(string(state.SelectedPassIds), 1, []);
            selectedPairs = reshape(string(state.SelectedPairIds), 1, []);
            viewEligible = arrayfun(@(entry) ...
                all(ismember(entry.ViewIds, selectedViews)), candidates);
            passEligible = arrayfun(@(entry) ...
                all(ismember(entry.PassIds, selectedPasses)), candidates);
            plausible = arrayfun(@(entry) nnz(entry.Request.OverlapMask) > 0, ...
                candidates);
            quality = arrayfun(@(entry) ...
                runner.qualityEvidenceCount(entry) >= 3, candidates) & ...
                plausible;
            base = viewEligible & passEligible;
            schedule = string(state.PairSchedule);
            included = false(1, count);
            if schedule == "fast"
                included = base & plausible & ...
                    string({candidates.PairId}) == runner.Context.ActivePairId;
            elseif schedule == "balanced"
                eligible = find(base & quality);
                planned = runner.plannedSubset(candidates(eligible));
                included(eligible(planned)) = true;
            elseif schedule == "quality"
                included = base & quality;
            elseif schedule == "allPlausible"
                included = base & plausible;
            else
                included = base & plausible & ...
                    ismember(string({candidates.PairId}), selectedPairs);
            end
            decisions = repmat(struct(PairId="", Included=false, ...
                Reason=""), 1, count);
            for index = 1:count
                reason = "scheduled";
                if ~viewEligible(index)
                    reason = "omitted: one or both views are not selected";
                elseif ~passEligible(index)
                    reason = "omitted: one or both passes are not selected";
                elseif ~plausible(index)
                    reason = "omitted: no valid overlap";
                elseif schedule == "quality" && ~quality(index)
                    reason = "omitted: fewer than three accepted sparse seeds";
                elseif ~included(index)
                    reason = "omitted by " + schedule + " schedule";
                end
                decisions(index) = struct(PairId=candidates(index).PairId, ...
                    Included=included(index), Reason=reason);
            end
            entries = candidates(included);
        end

        function count = qualityEvidenceCount(~, entry)
            count = Inf;
            prediction = entry.Request.SearchPrediction;
            if isfield(prediction, "SparsePairMatch") && ...
                    isstruct(prediction.SparsePairMatch) && ...
                    isfield(prediction.SparsePairMatch, "Count")
                count = double(prediction.SparsePairMatch.Count);
            end
        end

        function selected = plannedSubset(~, candidates)
            selected = false(1, numel(candidates));
            connected = strings(1, 0);
            for index = 1:numel(candidates)
                views = candidates(index).ViewIds;
                if isempty(connected) || any(~ismember(views, connected))
                    selected(index) = true;
                    connected = unique([connected views], "stable");
                end
            end
            if ~any(selected) && ~isempty(candidates)
                selected(1) = true;
            end
        end

        function budgets = associationBudgets(~, entries, state)
            count = numel(entries);
            budgets = repmat(double(state.MaximumObservations), 1, count);
            totalBudget = double(state.MaximumAssociationRecords);
            requested = sum(budgets);
            if count == 0 || isinf(totalBudget) || totalBudget >= requested
                return
            end
            base = floor(totalBudget / count);
            remainder = totalBudget - base * count;
            budgets(:) = min(double(state.MaximumObservations), base);
            if remainder > 0
                indices = 1:min(count, remainder);
                budgets(indices) = min(double(state.MaximumObservations), ...
                    budgets(indices) + 1);
            end
        end

        function entry = entryForPair(runner, pairId)
            match = string({runner.Context.PairEntries.PairId}) == ...
                string(pairId);
            if nnz(match) ~= 1
                error("ProjectionSurfaceWorkbenchRunner:unknownPair", ...
                    "Pair '%s' is not in the scene-bound context.", pairId);
            end
            entry = runner.Context.PairEntries(match);
        end

        function [matcher, matcherId, supported, reason, fallback] = ...
                resolveMatcher(runner, state)
            method = string(state.DenseMethod);
            supported = true;
            reason = "";
            fallback = "";
            matcher = [];
            if method == "currentSgm"
                matcherId = "sightline.sgm";
            elseif method == "classicalTemplate"
                matcherId = "sightline.classical-template";
            else
                ids = runner.MatcherRegistry.list();
                builtIn = ["sightline.sgm" "sightline.classical-template"];
                custom = ids(~ismember(ids, builtIn));
                if isempty(custom)
                    matcherId = "external.unavailable";
                    supported = false;
                    reason = "No explicit external matcher is registered.";
                    return
                end
                matcherId = custom(1);
            end
            try
                matcher = runner.MatcherRegistry.resolve(matcherId);
            catch exception
                supported = false;
                reason = string(exception.message);
                return
            end
            metadata = matcher.metadata();
            path = string(state.ExecutionPath);
            if path == "gpuRequired" && ~metadata.GpuSupported
                supported = false;
                reason = sprintf( ...
                    "Matcher %s does not support an available GPU path.", ...
                    matcherId);
            elseif path == "gpuIfAvailable" && ~metadata.GpuSupported
                fallback = "GPU unavailable or unsupported; using deterministic CPU.";
            end
        end

        function options = matcherOptions(~, matcher, state)
            options = matcher.defaultOptions();
            metadata = matcher.metadata();
            if metadata.AlgorithmId == "sightline.sgm"
                options.MaximumSurfacePoints = double(state.MaximumObservations);
                options.UseGPU = string(state.ExecutionPath) ~= "cpu";
            elseif metadata.AlgorithmId == "sightline.classical-template"
                options.MaximumObservations = double(state.MaximumObservations);
            elseif isfield(options, "MaximumObservations")
                options.MaximumObservations = double(state.MaximumObservations);
            elseif isfield(options, "Count")
                options.Count = min(double(options.Count), ...
                    double(state.MaximumObservations));
            end
            options = matcher.validateOptions(options);
        end

        function records = recordsForResult( ...
                runner, entry, result, matcherId, maximumObservations)
            valid = result.States == "valid" & ...
                isfinite(result.MovingSourceRows) & ...
                isfinite(result.MovingSourceColumns) & ...
                isfinite(result.ReferenceSourceRows) & ...
                isfinite(result.ReferenceSourceColumns);
            indices = reshape(find(valid), 1, []);
            if maximumObservations <= 0
                indices = zeros(1, 0);
            end
            if isfinite(maximumObservations) && ...
                    numel(indices) > maximumObservations
                selected = unique(round(linspace( ...
                    1, numel(indices), maximumObservations)), "stable");
                indices = indices(selected);
            end
            records = repmat(ProjectionSurfaceWorkbenchRunner.emptyRecord(), ...
                1, numel(indices));
            if isempty(indices)
                return
            end
            rows = [reshape(result.MovingSourceRows(indices), 1, []); ...
                reshape(result.ReferenceSourceRows(indices), 1, [])];
            columns = [reshape(result.MovingSourceColumns(indices), 1, []); ...
                reshape(result.ReferenceSourceColumns(indices), 1, [])];
            [origins, vectors] = runner.sampleEntryRays( ...
                entry, rows, columns);
            for local = 1:numel(indices)
                resultIndex = indices(local);
                confidence = result.Confidence(resultIndex);
                if ~isfinite(confidence)
                    confidence = 0.5;
                end
                score = result.Score(resultIndex);
                recordId = "dense-record-" + extractBefore( ...
                    ProjectionGeometryFingerprint.hash(struct( ...
                    PairId=entry.PairId, ...
                    SourceRows=rows(:, local), ...
                    SourceColumns=columns(:, local), ...
                    Matcher=matcherId, ResultIndex=resultIndex)), 17);
                observationIds = [ ...
                    runner.observationId(entry.ViewIds(1), ...
                    rows(1, local), columns(1, local)); ...
                    runner.observationId(entry.ViewIds(2), ...
                    rows(2, local), columns(2, local))].';
                records(local) = struct( ...
                    RecordId=recordId, PairId=entry.PairId, ...
                    ViewIds=entry.ViewIds, PassIds=entry.PassIds, ...
                    ObservationIds=observationIds, ...
                    SourceObservationsPixels=[rows(:, local) columns(:, local)], ...
                    RayOriginsWorld=origins(:, :, local), ...
                    RayVectorsWorld=vectors(:, :, local), ...
                    MatchState="valid", Score=score, ...
                    Confidence=confidence, ...
                    TextureScore=max(0.1, confidence), ...
                    NavigationWeights=[1 1], ...
                    RadiometricValues=[NaN NaN], ...
                    RadiometricConsistency=1, ...
                    VisibilityStates=["visible" "visible"], ...
                    ProvisionalPointWorld=[], ...
                    PairwiseCovarianceWorldMetersSquared=[], ...
                    ModeId="");
            end
        end

        function [origins, vectors] = sampleEntryRays(~, entry, rows, columns)
            count = size(rows, 2);
            origins = zeros(3, 2, count);
            vectors = zeros(3, 2, count);
            scene = entry.Request.Context.Scene;
            layerIndices = double(entry.LayerIndices);
            for side = 1:2
                layer = scene.layers(layerIndices(side));
                [sideOrigins, sideVectors] = ...
                    layer.SourceGeometry.SampleRayFcn( ...
                    rows(side, :), columns(side, :));
                if ~isequal(size(sideOrigins), [3 count]) || ...
                        ~isequal(size(sideVectors), [3 count]) || ...
                        any(~isfinite(sideOrigins), "all") || ...
                        any(~isfinite(sideVectors), "all")
                    error("ProjectionSurfaceWorkbenchRunner:invalidRays", ...
                        "Scene source geometry returned invalid dense observation rays.");
                end
                rotation = ProjectionMeshBuilder.viewVectorRotationMatrix( ...
                    layer, layer.CurrentProjectionPlane);
                sideVectors = rotation * double(sideVectors);
                sideVectors = sideVectors ./ vecnorm(sideVectors, 2, 1);
                origins(:, side, :) = reshape(double(sideOrigins), 3, 1, count);
                vectors(:, side, :) = reshape(sideVectors, 3, 1, count);
            end
        end

        function id = observationId(~, viewId, row, column)
            tolerance = ProjectionDenseObservationAssociator. ...
                defaults().SourceObservationTolerancePixels;
            quantized = tolerance * round([row column] / tolerance);
            id = "obs-" + extractBefore( ...
                ProjectionGeometryFingerprint.hash(struct( ...
                ViewId=string(viewId), Row=quantized(1), ...
                Column=quantized(2))), 17);
        end

        function [pointSet, status, association] = ...
                reconstruct(runner, records, associationOptions, ...
                reconstructionOptions, runtimeControl)
            if nargin < 4
                reconstructionOptions = struct();
            end
            if nargin < 5
                runtimeControl = struct(AssociationProgressFcn=[], ...
                    ReconstructionProgressFcn=[], CancellationFcn=[]);
            end
            association = struct();
            pointSet = struct();
            status = "empty";
            if isempty(records)
                return
            end
            request = struct( ...
                Format=ProjectionDenseObservationAssociator.RequestFormat, ...
                Version=ProjectionDenseObservationAssociator.RequestVersion, ...
                WorldFrame=runner.Context.CoordinateFrame.WorldFrameId, ...
                Records=records);
            associationRuntime = struct(ProgressFcn=[], ...
                CancellationFcn=runtimeControl.CancellationFcn);
            if isfield(runtimeControl, "AssociationProgressFcn")
                associationRuntime.ProgressFcn = ...
                    runtimeControl.AssociationProgressFcn;
            end
            association = ProjectionDenseObservationAssociator.associate( ...
                request, associationOptions, associationRuntime);
            if isempty(association.Tracks)
                return
            end
            reconstructionRuntime = struct(ProgressFcn=[], ...
                CancellationFcn=runtimeControl.CancellationFcn);
            if isfield(runtimeControl, "ReconstructionProgressFcn")
                reconstructionRuntime.ProgressFcn = ...
                    runtimeControl.ReconstructionProgressFcn;
            end
            pointSet = ProjectionMultiRayReconstructor.reconstruct( ...
                association, reconstructionOptions, reconstructionRuntime);
            pointSet.CoordinateFrame = runner.Context.CoordinateFrame;
            if ~any([pointSet.Points.Valid])
                return
            end
            status = "succeeded";
        end

        function evidence = evidence(~, request, result)
            evidence = struct( ...
                PairId=result.PairId, ViewIds=result.ViewIds, ...
                MovingAnalysisImage=request.AnalysisImages{1}, ...
                ReferenceAnalysisImage=request.AnalysisImages{2}, ...
                MovingValidityMask=request.ValidityMasks{1}, ...
                ReferenceValidityMask=request.ValidityMasks{2}, ...
                OverlapMask=request.OverlapMask, ...
                MovingSourceRows=result.MovingSourceRows, ...
                MovingSourceColumns=result.MovingSourceColumns, ...
                ReferenceSourceRows=result.ReferenceSourceRows, ...
                ReferenceSourceColumns=result.ReferenceSourceColumns, ...
                States=result.States, Score=result.Score, ...
                Confidence=result.Confidence, ...
                MatcherDiagnostics=result.Diagnostics, ...
                CompleteIntermediateEvidenceRetained=true);
        end

        function options = associationOptions(~, state)
            options = ProjectionDenseObservationAssociator.defaults();
            switch string(state.ConsistencyPolicy)
                case "strict"
                    options.MinimumTextureScore = 0.15;
                    options.MinimumRadiometricConsistency = 0.15;
                    options.MinimumPairAngleDegrees = 0.25;
                    options.SourceObservationTolerancePixels = 0.15;
                case "permissive"
                    options.MinimumTextureScore = 0;
                    options.MinimumNavigationWeight = 0;
                    options.MinimumRadiometricConsistency = 0;
                    options.MinimumPairAngleDegrees = 0.01;
                    options.SourceObservationTolerancePixels = 0.5;
            end
        end

        function algorithm = resolveFusion(runner, value)
            if string(value) == "robustMultiRay"
                id = "sightline.fusion.robust-multi-ray";
            else
                id = "example.mode-centroid";
            end
            algorithm = runner.FusionRegistry.resolve(id);
        end

        function request = fusionRequest(~, pointSet)
            points = pointSet.Points([pointSet.Points.Valid]);
            coordinates = horzcat(points.PointWorld);
            lower = min(coordinates, [], 2);
            upper = max(coordinates, [], 2);
            padding = max(1, 0.01 * max(upper - lower));
            request = ProjectionSurfaceFusionRequest.validate(struct( ...
                PointSet=pointSet, RoiWorld=[lower - padding upper + padding], ...
                VoxelScalesMeters=padding, Seed=0, ...
                Context=struct(Source="surfaceWorkbench")));
        end

        function diagnostics = runDiagnostics(~, pairRuns, association, ...
                pointSet, fusionResult)
            candidateCount = sum([pairRuns.CandidateCount]);
            acceptedCount = sum([pairRuns.AcceptedCorrespondenceCount]);
            stateCounts = ProjectionSurfaceWorkbenchRunner.mergeStateCounts( ...
                {pairRuns.StateCounts});
            associationDiagnostics = struct();
            reconstructionDiagnostics = struct();
            fusionDiagnostics = struct();
            if ~isempty(fieldnames(association))
                associationDiagnostics = association.Diagnostics;
            end
            if ~isempty(fieldnames(pointSet))
                reconstructionDiagnostics = pointSet.Diagnostics;
            end
            if ~isempty(fieldnames(fusionResult))
                fusionDiagnostics = fusionResult.Diagnostics;
            end
            uncertaintyAvailable = false;
            if ~isempty(fieldnames(pointSet))
                valid = pointSet.Points([pointSet.Points.Valid]);
                uncertaintyAvailable = any(arrayfun(@(point) ...
                    all(isfinite(point.CovarianceWorldMetersSquared), "all"), ...
                    valid));
            end
            diagnostics = struct(CandidateCount=candidateCount, ...
                AcceptedCorrespondenceCount=acceptedCount, ...
                MatchStateCounts=stateCounts, ...
                Association=associationDiagnostics, ...
                Reconstruction=reconstructionDiagnostics, ...
                Fusion=fusionDiagnostics, ...
                UncertaintyAvailable=uncertaintyAvailable, ...
                PairCount=numel(pairRuns), ...
                FailedPairCount=nnz(string({pairRuns.Status}) == "failed"));
        end

        function state = rectificationState(~, selection)
            if string(selection.DenseMethod) == "currentSgm"
                state = "sparse-derived global rectification pending";
            else
                state = "regional local-strip search; no global rectification";
            end
        end

        function bounds = searchBounds(~, options, selection)
            bounds = struct(Policy=string(selection.GeometrySearch));
            if isfield(options, "DisparityRange")
                bounds.HorizontalPixels = options.DisparityRange;
            elseif isfield(options, "HorizontalDisparityRange")
                bounds.HorizontalPixels = options.HorizontalDisparityRange;
                bounds.VerticalPixels = options.VerticalDisparityRange;
            else
                bounds.Description = "registered matcher default";
            end
        end

        function tf = needsFusion(~, stage)
            tf = ismember(string(stage), ["fusionDerived" "voxelEvidence" ...
                "mesh" "grid" "dem" "registered" "demDifference"]);
        end

        function forwardMatcherProgress(runner, runtimeControl, event, ...
                base, span, pairId)
            fraction = base + span * min(max(double(event.Fraction), 0), 1);
            runner.publishProgress(runtimeControl, fraction, "pairwise", ...
                pairId + ": " + string(event.Stage));
        end

        function forwardFusionProgress(runner, runtimeControl, event)
            fraction = 0.88 + 0.1 * min(max(double(event.Fraction), 0), 1);
            runner.publishProgress(runtimeControl, fraction, "fusion", ...
                string(event.Stage));
        end

        function forwardAssociationProgress(runner, runtimeControl, event)
            fraction = 0.72 + 0.10 * ...
                min(max(double(event.Fraction), 0), 1);
            runner.LastRuntimeEvent = runner.runtimeEvent( ...
                event, fraction, "association");
            runner.publishProgress(runtimeControl, fraction, "association", ...
                string(event.Message));
        end

        function forwardReconstructionProgress(runner, runtimeControl, event)
            fraction = 0.82 + 0.06 * ...
                min(max(double(event.Fraction), 0), 1);
            runner.LastRuntimeEvent = runner.runtimeEvent( ...
                event, fraction, "reconstruction");
            runner.publishProgress(runtimeControl, fraction, ...
                "reconstruction", string(event.Message));
        end

        function value = runtimeEvent(~, event, fraction, parentStage)
            value = struct(ParentStage=string(parentStage), ...
                Stage=string(event.Stage), Fraction=double(fraction), ...
                Completed=double(event.Completed), ...
                Total=double(event.Total), ...
                ElapsedSeconds=double(event.ElapsedSeconds), ...
                Message=string(event.Message));
        end

        function publishProgress(~, runtimeControl, fraction, stage, message)
            if ~isempty(runtimeControl.ProgressFcn)
                runtimeControl.ProgressFcn(struct(Fraction=double(fraction), ...
                    Stage=string(stage), Message=string(message)));
            end
        end
    end

    methods (Static, Access = private)
        function context = validateContext(context)
            required = ["PairEntries" "ActivePairId"];
            if ~isstruct(context) || ~isscalar(context) || ...
                    any(~isfield(context, required)) || ...
                    ~isstruct(context.PairEntries) || ...
                    isempty(context.PairEntries)
                error("ProjectionSurfaceWorkbenchRunner:invalidContext", ...
                    "Context requires nonempty scene-bound pair entries and an active pair.");
            end
            templateFields = ["PairId" "ViewIds" "PassIds" ...
                "LayerIndices" "Request"];
            for index = 1:numel(context.PairEntries)
                entry = context.PairEntries(index);
                if any(~isfield(entry, templateFields))
                    error("ProjectionSurfaceWorkbenchRunner:invalidContext", ...
                        "Every pair entry requires identity, layers, and a matcher request.");
                end
                entry.PairId = string(entry.PairId);
                entry.ViewIds = reshape(string(entry.ViewIds), 1, []);
                entry.PassIds = reshape(string(entry.PassIds), 1, []);
                entry.LayerIndices = reshape(double(entry.LayerIndices), 1, []);
                entry.Request = ProjectionDenseMatchRequest.validate(entry.Request);
                if ~isscalar(entry.PairId) || strlength(entry.PairId) == 0 || ...
                        numel(entry.ViewIds) ~= 2 || ...
                        numel(entry.PassIds) ~= 2 || ...
                        numel(entry.LayerIndices) ~= 2 || ...
                        entry.Request.PairId ~= entry.PairId || ...
                        ~isequal(entry.Request.ViewIds, entry.ViewIds) || ...
                        ~isfield(entry.Request.Context, "Scene")
                    error("ProjectionSurfaceWorkbenchRunner:invalidContext", ...
                        "Pair entry identity and scene-bound request are inconsistent.");
                end
                context.PairEntries(index) = entry;
            end
            ids = string({context.PairEntries.PairId});
            if numel(unique(ids)) ~= numel(ids)
                error("ProjectionSurfaceWorkbenchRunner:invalidContext", ...
                    "Scene-bound PairId values must be unique.");
            end
            context.ActivePairId = string(context.ActivePairId);
            if ~isscalar(context.ActivePairId) || ...
                    ~ismember(context.ActivePairId, ids)
                error("ProjectionSurfaceWorkbenchRunner:invalidContext", ...
                    "ActivePairId must identify one bound pair entry.");
            end
            inferred = ProjectionSurfaceWorkbenchRunner. ...
                inferCoordinateFrame(context.PairEntries);
            if isfield(context, "CoordinateFrame")
                explicit = ProjectionCoordinateFrame.validate( ...
                    context.CoordinateFrame);
                if explicit.WorldFrameId ~= inferred.WorldFrameId
                    error("ProjectionSurfaceWorkbenchRunner:frameMismatch", ...
                        "Explicit and scene-declared world frames disagree.");
                end
                context.CoordinateFrame = explicit;
            else
                context.CoordinateFrame = inferred;
            end
        end

        function frame = inferCoordinateFrame(entries)
            frameIds = strings(1, 0);
            origins = zeros(3, 0);
            for index = 1:numel(entries)
                entry = entries(index);
                scene = entry.Request.Context.Scene;
                if ~isfield(scene, "renderOrigin") || ...
                        ~isnumeric(scene.renderOrigin) || ...
                        ~isequal(size(scene.renderOrigin), [3 1]) || ...
                        any(~isfinite(scene.renderOrigin))
                    error("ProjectionSurfaceWorkbenchRunner:invalidFrame", ...
                        "Every scene-bound pair requires a finite world render origin.");
                end
                for side = 1:2
                    layer = scene.layers(entry.LayerIndices(side));
                    if ~isfield(layer, "SourceGeometry") || ...
                            ~isstruct(layer.SourceGeometry) || ...
                            ~isfield(layer.SourceGeometry, "CoordinateFrame")
                        error("ProjectionSurfaceWorkbenchRunner:invalidFrame", ...
                            "Every source geometry must declare its coordinate frame.");
                    end
                    id = string(layer.SourceGeometry.CoordinateFrame);
                    if ~isscalar(id) || ismissing(id) || strlength(id) == 0
                        error("ProjectionSurfaceWorkbenchRunner:invalidFrame", ...
                            "Source coordinate-frame identity must be nonempty.");
                    end
                    frameIds(end + 1) = id; %#ok<AGROW>
                    origins(:, end + 1) = double(scene.renderOrigin); %#ok<AGROW>
                end
            end
            if numel(unique(frameIds)) ~= 1
                error("ProjectionSurfaceWorkbenchRunner:frameMismatch", ...
                    "Scheduled pair source geometries use inconsistent world frames.");
            end
            tolerance = 1e-9 * max(1, max(abs(origins), [], "all"));
            if any(vecnorm(origins - origins(:, 1), 2, 1) > tolerance)
                error("ProjectionSurfaceWorkbenchRunner:frameMismatch", ...
                    "Scheduled pair scene origins are inconsistent.");
            end
            frame = ProjectionCoordinateFrame.fromDeclaration( ...
                frameIds(1), origins(:, 1));
        end

        function runtime = validateRuntimeControl(runtime)
            defaults = struct(ProgressFcn=[], CancellationFcn=[]);
            if isempty(runtime)
                runtime = defaults;
                return
            end
            if ~isstruct(runtime) || ~isscalar(runtime) || ...
                    any(~ismember(string(fieldnames(runtime)), ...
                    string(fieldnames(defaults))))
                error("ProjectionSurfaceWorkbenchRunner:invalidRuntimeControl", ...
                    "Runtime control supports only progress and cancellation callbacks.");
            end
            names = fieldnames(runtime);
            for index = 1:numel(names)
                defaults.(names{index}) = runtime.(names{index});
            end
            for field = ["ProgressFcn" "CancellationFcn"]
                if ~(isempty(defaults.(field)) || ...
                        isa(defaults.(field), "function_handle"))
                    error("ProjectionSurfaceWorkbenchRunner:invalidRuntimeControl", ...
                        "%s must be empty or a function handle.", field);
                end
            end
            runtime = defaults;
        end

        function tf = cancelled(runtime)
            tf = ~isempty(runtime.CancellationFcn) && ...
                logical(runtime.CancellationFcn());
        end

        function tf = isCancellationException(exception)
            tf = ismember(string(exception.identifier), [ ...
                "ProjectionDenseMatcher:cancelled" ...
                "ProjectionDenseObservationAssociator:cancelled" ...
                "ProjectionMultiRayReconstructor:cancelled" ...
                "ProjectionSurfaceFusionAlgorithm:cancelled"]);
        end

        function value = exceptionEvidence(exception)
            underlying = exception;
            if ~isempty(exception.cause)
                underlying = exception.cause{1};
            end
            value = struct(WrapperIdentifier=string(exception.identifier), ...
                WrapperMessage=string(exception.message), ...
                ExceptionIdentifier=string(underlying.identifier), ...
                ExceptionMessage=string(underlying.message));
        end

        function result = sparseResult(request)
            pairMatch = request.Context.PairMatch;
            required = ["MovingSourceRows" "MovingSourceColumns" ...
                "ReferenceSourceRows" "ReferenceSourceColumns" "Count"];
            if ~isstruct(pairMatch) || ~isscalar(pairMatch) || ...
                    any(~isfield(pairMatch, required))
                error("ProjectionSurfaceWorkbenchRunner:invalidBootstrap", ...
                    "Every bound pair needs accepted sparse bootstrap observations.");
            end
            count = double(pairMatch.Count);
            scores = nan(count, 1);
            if isfield(pairMatch, "Scores") && ...
                    numel(pairMatch.Scores) == count
                scores = double(pairMatch.Scores(:));
            end
            confidence = ones(count, 1);
            finite = scores(isfinite(scores));
            if ~isempty(finite) && max(finite) > min(finite)
                confidence = (scores - min(finite)) / ...
                    (max(finite) - min(finite));
                confidence(~isfinite(confidence)) = 0.5;
            end
            result = ProjectionDenseMatchResult.validate(struct( ...
                MovingSourceRows=pairMatch.MovingSourceRows(:), ...
                MovingSourceColumns=pairMatch.MovingSourceColumns(:), ...
                ReferenceSourceRows=pairMatch.ReferenceSourceRows(:), ...
                ReferenceSourceColumns=pairMatch.ReferenceSourceColumns(:), ...
                States=repmat("valid", count, 1), Score=scores, ...
                Confidence=confidence, Diagnostics=struct( ...
                Source="acceptedSparseBootstrap"), ...
                Execution=struct(Device="cpu"), ...
                Provenance=struct(AlgorithmId="sparse-bootstrap")), request);
        end

        function counts = stateCounts(states)
            counts = struct();
            for state = ProjectionDenseMatchResult.States
                counts.(matlab.lang.makeValidName(state)) = ...
                    nnz(string(states) == state);
            end
        end

        function merged = mergeStateCounts(values)
            merged = ProjectionSurfaceWorkbenchRunner.stateCounts( ...
                strings(0, 1));
            for index = 1:numel(values)
                value = values{index};
                if isempty(fieldnames(value))
                    continue
                end
                names = fieldnames(merged);
                for nameIndex = 1:numel(names)
                    name = names{nameIndex};
                    merged.(name) = merged.(name) + value.(name);
                end
            end
        end

        function records = emptyRecords()
            records = repmat(ProjectionSurfaceWorkbenchRunner.emptyRecord(), ...
                1, 0);
        end

        function record = emptyRecord()
            record = struct(RecordId="", PairId="", ...
                ViewIds=strings(1, 2), PassIds=strings(1, 2), ...
                ObservationIds=strings(1, 2), ...
                SourceObservationsPixels=nan(2), ...
                RayOriginsWorld=nan(3, 2), RayVectorsWorld=nan(3, 2), ...
                MatchState="valid", Score=NaN, Confidence=1, ...
                TextureScore=1, NavigationWeights=ones(1, 2), ...
                RadiometricValues=nan(1, 2), ...
                RadiometricConsistency=1, ...
                VisibilityStates=["visible" "visible"], ...
                ProvisionalPointWorld=zeros(3, 0), ...
                PairwiseCovarianceWorldMetersSquared=[], ModeId="");
        end

        function run = emptyPairRun()
            run = struct(PairId="", ViewIds=strings(1, 0), ...
                MatcherAlgorithmId="", Status="notRun", ...
                Stage="notRun", Options=struct(), ElapsedSeconds=0, ...
                CandidateCount=0, AcceptedCorrespondenceCount=0, ...
                RecordCount=0, StateCounts=struct(), Execution=struct(), ...
                Provenance=struct(), Evidence=struct(), Identifier="", ...
                Message="", CauseIdentifier="", CauseMessage="", ...
                Failure=struct());
        end

        function outcome = emptyOutcome(preflight)
            outcome = struct(Format= ...
                ProjectionSurfaceWorkbenchRunner.Format, ...
                Version=ProjectionSurfaceWorkbenchRunner.Version, ...
                Status="notRun", Message="", Identifier="", ...
                ProcessingStage="preflight", LastCompletedPairId="", ...
                Preflight=preflight, ...
                PairRuns=repmat( ...
                ProjectionSurfaceWorkbenchRunner.emptyPairRun(), 1, 0), ...
                Association=struct(), PointSet=struct(), ...
                FusionResult=struct(), Catalog=struct(), ...
                Diagnostics=struct(), StageDiagnostics=struct(), ...
                Provenance=struct(), ...
                GraphicsStateIncluded=false);
        end
    end
end
