classdef ProjectionAlignmentNetworkSolver
    %ProjectionAlignmentNetworkSolver Global constant-OPK network entry point.

    properties (Constant)
        Format = "ProjectionAlignmentNetworkResult"
        Version = 1
    end

    methods (Static)
        function result = solve(scene, matchResult, options, runtimeControl)
            %solve Optimize all unique track evidence in one network solve.
            if nargin < 3
                options = struct();
            end
            if nargin < 4
                runtimeControl = struct();
            end
            explicitLoss = isstruct(options) && isfield(options, "LossMode");
            if ~isstruct(options) || ~isscalar(options)
                error("ProjectionAlignmentNetworkSolver:invalidOptions", ...
                    "Network options must be a scalar struct.");
            end
            if ~isfield(options, "Network") || isempty(options.Network)
                options.Network = struct();
            end
            options.Network.Enabled = true;
            if ~explicitLoss
                options.LossMode = "epipolarCoplanarity";
            end
            options = ProjectionAlignmentOptions.validate(options);
            if options.Network.GaugePolicy == "fixedReference"
                options.MovableParameters.AllowReferenceMotion = false;
            else
                options.MovableParameters.AllowReferenceMotion = true;
            end
            scene = ProjectionViewMetadata.ensureScene(scene);
            evidence = ProjectionAlignmentNetworkEvidence.prepare( ...
                matchResult, options);
            components = ProjectionAlignmentNetworkSolver.components( ...
                scene, evidence.MatchResult);
            gauge = ProjectionAlignmentNetworkSolver.gaugeDiagnostics( ...
                scene, components, options);
            if any(~[gauge.Valid])
                invalid = gauge(find(~[gauge.Valid], 1, "first"));
                error("ProjectionAlignmentNetworkSolver:gaugeDeficientComponent", ...
                    "Component %s has no valid %s gauge: %s", ...
                    invalid.ComponentId, options.Network.GaugePolicy, ...
                    invalid.Reason);
            end
            result = ProjectionAlignmentOpkSolver.solve( ...
                scene, evidence.MatchResult, options, runtimeControl);
            result.RequestSummary.SolverMode = "globalConstantOpkNetwork";
            result.RequestSummary.GaugePolicy = options.Network.GaugePolicy;
            result.Diagnostics.Network = ...
                ProjectionAlignmentNetworkSolver.networkDiagnostics( ...
                scene, result, evidence, components, gauge, options);
        end

        function correctionSet = solveCorrectionSet( ...
                scene, matchResult, options, correctionOptions, runtimeControl)
            %solveCorrectionSet Return immutable SDK output for one network solve.
            if nargin < 3
                options = struct();
            end
            if nargin < 4
                correctionOptions = struct();
            end
            if nargin < 5
                runtimeControl = struct();
            end
            result = ProjectionAlignmentNetworkSolver.solve( ...
                scene, matchResult, options, runtimeControl);
            correctionSet = ...
                ProjectionCorrectionOpkAdapter.fromAlignmentResult( ...
                scene, result, correctionOptions);
        end

        function alignedScene = applyCorrections(scene, result)
            %applyCorrections Atomically return a scene with all network values.
            alignedScene = ProjectionAlignmentOpkSolver.applyCorrections( ...
                scene, result);
        end

        function revertedScene = revertCorrections(scene, result)
            %revertCorrections Restore the complete pre-network correction state.
            revertedScene = ProjectionAlignmentOpkSolver.revertCorrections( ...
                scene, result);
        end
    end

    methods (Static, Access = private)
        function components = components(scene, matchResult)
            involved = unique(reshape([matchResult.Matches.Pair], 1, []));
            parent = 1:numel(involved);
            for pairMatch = matchResult.Matches
                first = find(involved == pairMatch.Pair(1), 1, "first");
                second = find(involved == pairMatch.Pair(2), 1, "first");
                firstRoot = ProjectionAlignmentNetworkSolver.root(parent, first);
                secondRoot = ProjectionAlignmentNetworkSolver.root(parent, second);
                if firstRoot ~= secondRoot
                    parent(parent == max(firstRoot, secondRoot)) = ...
                        min(firstRoot, secondRoot);
                end
            end
            roots = arrayfun(@(index) ...
                ProjectionAlignmentNetworkSolver.root(parent, index), ...
                1:numel(involved));
            uniqueRoots = unique(roots);
            viewIds = ProjectionViewMetadata.ids(scene);
            components = repmat(struct(ComponentId="", ...
                LayerIndices=zeros(1, 0), ViewIds=strings(1, 0), ...
                PassIds=strings(1, 0), PairIds=strings(1, 0)), ...
                1, numel(uniqueRoots));
            for componentIndex = 1:numel(uniqueRoots)
                members = roots == uniqueRoots(componentIndex);
                layerIndices = sort(involved(members));
                pairMask = arrayfun(@(pair) all(ismember( ...
                    pair.Pair, layerIndices)), matchResult.Matches);
                pairIds = strings(1, nnz(pairMask));
                selectedPairs = matchResult.Matches(pairMask);
                for pairIndex = 1:numel(selectedPairs)
                    pairViewIds = viewIds(selectedPairs(pairIndex).Pair);
                    identity = ProjectionViewMetadata.pairIdentity( ...
                        pairViewIds(1), pairViewIds(2));
                    pairIds(pairIndex) = identity.PairId;
                end
                passIds = string({scene.layers(layerIndices).PassId});
                components(componentIndex) = struct( ...
                    ComponentId="component-" + string(componentIndex), ...
                    LayerIndices=layerIndices, ...
                    ViewIds=viewIds(layerIndices), ...
                    PassIds=sort(unique(passIds)), ...
                    PairIds=sort(pairIds));
            end
        end

        function gauge = gaugeDiagnostics(scene, components, options)
            priorWeights = [options.Regularization.OmegaWeight ...
                options.Regularization.PhiWeight ...
                options.Regularization.KappaWeight];
            priorAvailable = options.Regularization.OverallWeight > 0 && ...
                all(priorWeights > 0);
            gauge = repmat(struct(ComponentId="", Policy="", Valid=false, ...
                FixedReferenceViewId="", PriorGaugeAvailable=false, ...
                Reason=""), 1, numel(components));
            for index = 1:numel(components)
                hasFixedReference = options.Network.GaugePolicy == ...
                    "fixedReference" && ismember( ...
                    options.Network.FixedReferenceViewId, ...
                    components(index).ViewIds);
                valid = priorAvailable || hasFixedReference;
                reason = "";
                if ~valid
                    reason = "no fixed reference or positive balanced OPK prior";
                end
                gauge(index) = struct( ...
                    ComponentId=components(index).ComponentId, ...
                    Policy=options.Network.GaugePolicy, Valid=valid, ...
                    FixedReferenceViewId= ...
                    options.Network.FixedReferenceViewId, ...
                    PriorGaugeAvailable=priorAvailable, Reason=reason);
            end
            if options.Network.GaugePolicy == "fixedReference"
                allViewIds = ProjectionViewMetadata.ids(scene);
                if ~ismember(options.Network.FixedReferenceViewId, allViewIds)
                    error("ProjectionAlignmentNetworkSolver:unknownFixedReference", ...
                        "FixedReferenceViewId is not present in the scene.");
                end
            end
        end

        function diagnostics = networkDiagnostics( ...
                scene, result, evidence, components, gauge, options)
            diagnostics = struct( ...
                Format=ProjectionAlignmentNetworkSolver.Format, ...
                Version=ProjectionAlignmentNetworkSolver.Version, ...
                Model="globalConstantOpk", ...
                DefaultResidual="epipolarCoplanarity", ...
                ActiveResidual=result.Residuals.LossMode, ...
                RayOriginsFixed=true, GaugePolicy=options.Network.GaugePolicy, ...
                Configuration=options.Network.Configuration, ...
                Evidence=evidence.Diagnostics, RecordMap=evidence.RecordMap, ...
                Components=components, ...
                Gauge=gauge, WeakViews= ...
                ProjectionAlignmentNetworkSolver.weakViews(scene, result), ...
                ViewCovariance=ProjectionAlignmentNetworkSolver. ...
                viewCovariance(scene, result), ...
                ResidualsByTrack=ProjectionAlignmentNetworkSolver. ...
                residualsByTrack(result, evidence), ...
                ResidualsByPass=ProjectionAlignmentNetworkSolver. ...
                residualsByPass(scene, result), ...
                ResidualsByImageRegion=ProjectionAlignmentNetworkSolver. ...
                residualsByRegion(scene, result), ...
                ResidualsByTimeInterval=ProjectionAlignmentNetworkSolver. ...
                residualsByTimeInterval(scene, result), ...
                PassCorrections=result.Diagnostics.AttitudeModel.Passes, ...
                PriorContribution=result.Diagnostics.PriorContribution, ...
                PriorDominanceByPass=ProjectionAlignmentNetworkSolver. ...
                priorDominanceByPass(result), ...
                PositionLikeResidual=ProjectionAlignmentNetworkSolver. ...
                positionLikeResidual(result), ...
                Robustification=result.Diagnostics.Robustification);
            diagnostics.ConflictConcentration = ...
                ProjectionAlignmentNetworkSolver.conflictConcentration( ...
                diagnostics.ResidualsByPass, ...
                diagnostics.ResidualsByTimeInterval);
            diagnostics.LeaveOnePairOut = ...
                ProjectionAlignmentNetworkSolver.leaveOnePairOut( ...
                scene, result, evidence, options);
        end

        function weak = weakViews(scene, result)
            modes = result.Diagnostics.Observability.Solution.Modes;
            statuses = string({modes.Status});
            weakModeMask = ~ismember(statuses, ["dataObserved" "fixed"]);
            weak = struct("ViewId", {}, "LayerId", {}, "WeakModes", {});
            for correction = result.SolvedCorrections
                layerIndex = correction.LayerIndex;
                layerId = string(scene.layers(layerIndex).LayerId);
                containsLayer = contains(string({modes.Name}), layerId);
                modeNames = string({modes(weakModeMask & containsLayer).Name});
                if isempty(modeNames)
                    continue
                end
                weak(end + 1) = struct( ...
                    ViewId=string(scene.layers(layerIndex).ViewId), ...
                    LayerId=layerId, WeakModes=modeNames); %#ok<AGROW>
            end
        end

        function values = priorDominanceByPass(result)
            passes = result.Diagnostics.AttitudeModel.Passes;
            modes = result.Diagnostics.Observability.Solution.Modes;
            names = string({modes.Name});
            statuses = string({modes.Status});
            values = repmat(struct(PassId="", ModeCount=0, ...
                PriorDominatedModeCount=0, DataObservedModeCount=0, ...
                PriorDominated=false), 1, numel(passes));
            for index = 1:numel(passes)
                prefix = "pass:" + passes(index).PassId + ":";
                mask = startsWith(names, prefix);
                passStatuses = statuses(mask);
                values(index) = struct(PassId=passes(index).PassId, ...
                    ModeCount=nnz(mask), ...
                    PriorDominatedModeCount= ...
                    nnz(passStatuses == "priorDominated"), ...
                    DataObservedModeCount=nnz(passStatuses == "dataObserved"), ...
                    PriorDominated=~isempty(passStatuses) && ...
                    all(ismember(passStatuses, ...
                    ["priorDominated" "fixed"] )));
            end
        end

        function value = positionLikeResidual(result)
            records = result.Diagnostics.MatchRecords;
            if isempty(records)
                value = struct(CorrelationByCoordinate=nan(1, 4), ...
                    MaximumAbsoluteCorrelation=NaN, Detected=false, ...
                    Threshold=0.5);
                return
            end
            residuals = [records.ResidualAfter].';
            coordinates = [[records.MovingSourceRow].' ...
                [records.MovingSourceColumn].' ...
                [records.ReferenceSourceRow].' ...
                [records.ReferenceSourceColumn].'];
            correlations = nan(1, size(coordinates, 2));
            for index = 1:size(coordinates, 2)
                correlations(index) = ProjectionAlignmentNetworkSolver. ...
                    correlation(residuals, coordinates(:, index));
            end
            maximum = max(abs(correlations), [], "omitnan");
            if isempty(maximum)
                maximum = NaN;
            end
            value = struct(CorrelationByCoordinate=correlations, ...
                MaximumAbsoluteCorrelation=maximum, ...
                Detected=isfinite(maximum) && maximum >= 0.5, Threshold=0.5);
        end

        function value = correlation(first, second)
            first = double(first(:));
            second = double(second(:));
            first = first - mean(first);
            second = second - mean(second);
            denominator = norm(first) * norm(second);
            if denominator <= eps
                value = NaN;
            else
                value = dot(first, second) / denominator;
            end
        end

        function values = viewCovariance(scene, result)
            covariance = result.Diagnostics.Observability.Solution. ...
                EffectiveAttitudeCovariance;
            values = repmat(struct(ViewId="", LayerId="", ...
                Unit="degreesSquared", CovarianceDegreesSquared=zeros(3), ...
                StandardDeviationDegrees=zeros(1, 3), Status="available"), ...
                1, numel(result.SolvedCorrections));
            for position = 1:numel(result.SolvedCorrections)
                correction = result.SolvedCorrections(position);
                indices = 3 * (position - 1) + (1:3);
                block = covariance(indices, indices);
                values(position) = struct( ...
                    ViewId=string(scene.layers(correction.LayerIndex).ViewId), ...
                    LayerId=string(correction.LayerId), ...
                    Unit="degreesSquared", ...
                    CovarianceDegreesSquared=block, ...
                    StandardDeviationDegrees=sqrt(max(0, diag(block))).', ...
                    Status="available");
            end
        end

        function summaries = residualsByTrack(result, evidence)
            ledger = result.MatchLedger;
            mapIds = string({evidence.RecordMap.RecordId});
            trackIds = string({evidence.RecordMap.TrackId});
            keys = strings(1, 0);
            before = zeros(1, 0);
            after = zeros(1, 0);
            for record = ledger
                mapIndex = find(mapIds == record.RecordId, 1, "first");
                if isempty(mapIndex) || ~record.StageMasks.SolverObservation
                    continue
                end
                keys(end + 1) = trackIds(mapIndex); %#ok<AGROW>
                before(end + 1) = ...
                    record.Residuals.ActiveResidualBefore; %#ok<AGROW>
                after(end + 1) = ...
                    record.Residuals.ActiveResidualAfter; %#ok<AGROW>
            end
            summaries = ProjectionAlignmentNetworkSolver.summaries( ...
                keys, before, after, "TrackId");
        end

        function summaries = residualsByPass(scene, result)
            keys = strings(1, 0);
            before = zeros(1, 0);
            after = zeros(1, 0);
            for record = result.MatchLedger
                if ~record.StageMasks.SolverObservation
                    continue
                end
                layerIndices = ProjectionAlignmentNetworkSolver. ...
                    recordLayerIndices(scene, record);
                passIds = unique(string({scene.layers(layerIndices).PassId}));
                for passId = passIds
                    keys(end + 1) = passId; %#ok<AGROW>
                    before(end + 1) = ...
                        record.Residuals.ActiveResidualBefore; %#ok<AGROW>
                    after(end + 1) = ...
                        record.Residuals.ActiveResidualAfter; %#ok<AGROW>
                end
            end
            summaries = ProjectionAlignmentNetworkSolver.summaries( ...
                keys, before, after, "PassId");
        end

        function summaries = residualsByRegion(scene, result)
            keys = strings(1, 0);
            before = zeros(1, 0);
            after = zeros(1, 0);
            for record = result.MatchLedger
                if ~record.StageMasks.SolverObservation
                    continue
                end
                layerIndices = ProjectionAlignmentNetworkSolver. ...
                    recordLayerIndices(scene, record);
                rows = [record.MovingSourceRowPixels ...
                    record.ReferenceSourceRowPixels];
                columns = [record.MovingSourceColumnPixels ...
                    record.ReferenceSourceColumnPixels];
                for side = 1:2
                    viewId = string(scene.layers(layerIndices(side)).ViewId);
                    region = ProjectionAlignmentNetworkSolver.regionName( ...
                        scene.layers(layerIndices(side)), rows(side), columns(side));
                    keys(end + 1) = viewId + ":" + region; %#ok<AGROW>
                    before(end + 1) = ...
                        record.Residuals.ActiveResidualBefore; %#ok<AGROW>
                    after(end + 1) = ...
                        record.Residuals.ActiveResidualAfter; %#ok<AGROW>
                end
            end
            summaries = ProjectionAlignmentNetworkSolver.summaries( ...
                keys, before, after, "ViewRegionId");
        end

        function summaries = residualsByTimeInterval(scene, result)
            [intervalIds, ~] = ...
                ProjectionAlignmentNetworkSolver.timeIntervals(scene);
            keys = strings(1, 0);
            before = zeros(1, 0);
            after = zeros(1, 0);
            for record = result.MatchLedger
                if ~record.StageMasks.SolverObservation
                    continue
                end
                layerIndices = ProjectionAlignmentNetworkSolver. ...
                    recordLayerIndices(scene, record);
                for layerIndex = layerIndices
                    keys(end + 1) = intervalIds(layerIndex); %#ok<AGROW>
                    before(end + 1) = ...
                        record.Residuals.ActiveResidualBefore; %#ok<AGROW>
                    after(end + 1) = ...
                        record.Residuals.ActiveResidualAfter; %#ok<AGROW>
                end
            end
            summaries = ProjectionAlignmentNetworkSolver.summaries( ...
                keys, before, after, "TimeIntervalId");
        end

        function [intervalIds, basis] = timeIntervals(scene)
            intervalIds = strings(1, numel(scene.layers));
            basis = strings(1, numel(scene.layers));
            passIds = string({scene.layers.PassId});
            for passId = unique(passIds, "stable")
                members = find(passIds == passId);
                order = members;
                timingAvailable = false;
                times = cell(1, numel(members));
                for offset = 1:numel(members)
                    layer = scene.layers(members(offset));
                    if isfield(layer, "AcquisitionStartTime") && ...
                            ~isempty(layer.AcquisitionStartTime)
                        times{offset} = layer.AcquisitionStartTime;
                    end
                end
                if all(~cellfun(@isempty, times))
                    try
                        [~, localOrder] = sort([times{:}]);
                        order = members(localOrder);
                        timingAvailable = true;
                    catch
                        % Stable scene order remains the explicit fallback.
                    end
                end
                for rank = 1:numel(order)
                    fraction = (rank - 0.5) / numel(order);
                    interval = "middle";
                    if fraction <= 1 / 3
                        interval = "early";
                    elseif fraction > 2 / 3
                        interval = "late";
                    end
                    intervalIds(order(rank)) = passId + ":" + interval;
                    basis(order(rank)) = "layerOrderFallback";
                    if timingAvailable
                        basis(order(rank)) = "acquisitionTime";
                    end
                end
            end
        end

        function value = conflictConcentration(passSummaries, timeSummaries)
            passConflict = ProjectionAlignmentNetworkSolver. ...
                concentration(passSummaries, "PassId");
            timeConflict = ProjectionAlignmentNetworkSolver. ...
                concentration(timeSummaries, "TimeIntervalId");
            value = struct(Pass=passConflict, TimeInterval=timeConflict, ...
                Concentrated=passConflict.Concentrated || ...
                timeConflict.Concentrated);
        end

        function value = concentration(summaries, keyName)
            value = struct(GroupId="", RatioToMedian=NaN, ...
                Concentrated=false);
            if isempty(summaries)
                return
            end
            rmsValues = [summaries.RmsAfter];
            [worst, index] = max(rmsValues);
            baseline = median(rmsValues(isfinite(rmsValues)));
            ratio = worst / max(baseline, eps);
            value.GroupId = string(summaries(index).(keyName));
            value.RatioToMedian = ratio;
            value.Concentrated = numel(summaries) > 1 && ratio >= 2;
        end

        function diagnostics = leaveOnePairOut( ...
                scene, baseline, evidence, options)
            diagnostics = struct("PairId", {}, "Status", {}, ...
                "MaxAttitudeChangeDegrees", {}, ...
                "RmsAttitudeChangeDegrees", {}, "MissingViewIds", {}, ...
                "Explanation", {});
            if ~options.Network.ComputeLeaveOnePairOut || ...
                    numel(evidence.MatchResult.Matches) < 2
                return
            end
            childOptions = options;
            childOptions.Network.ComputeLeaveOnePairOut = false;
            baselineIds = string({baseline.SolvedCorrections.LayerId});
            baselineOpk = reshape([baseline.SolvedCorrections. ...
                ViewVectorAngularOffsetsDegrees], 3, []).';
            viewIds = ProjectionViewMetadata.ids(scene);
            for pairIndex = 1:numel(evidence.MatchResult.Matches)
                iterationOptions = childOptions;
                omitted = evidence.MatchResult.Matches(pairIndex);
                pairViewIds = viewIds(omitted.Pair);
                identity = ProjectionViewMetadata.pairIdentity( ...
                    pairViewIds(1), pairViewIds(2));
                reduced = evidence.MatchResult;
                reduced.Matches(pairIndex) = [];
                retainedLayers = unique(reshape( ...
                    [reduced.Matches.Pair], 1, []));
                retainedLayerIds = string( ...
                    {scene.layers(retainedLayers).LayerId});
                priorMask = ismember( ...
                    iterationOptions.PointingPriors.LayerIds, retainedLayerIds);
                iterationOptions.PointingPriors.LayerIds = ...
                    iterationOptions.PointingPriors.LayerIds(priorMask);
                iterationOptions.PointingPriors.SigmaDegrees = ...
                    iterationOptions.PointingPriors.SigmaDegrees(priorMask, :);
                diagnostic = struct(PairId=identity.PairId, Status="failed", ...
                    MaxAttitudeChangeDegrees=NaN, ...
                    RmsAttitudeChangeDegrees=NaN, ...
                    MissingViewIds=strings(1, 0), Explanation="");
                try
                    child = ProjectionAlignmentNetworkSolver.solve( ...
                        scene, reduced, iterationOptions);
                    if child.Status ~= "solved" || ...
                            ~child.Convergence.Success
                        error("ProjectionAlignmentNetworkSolver:looSolveFailed", ...
                            "Leave-one-pair-out child solve did not converge.");
                    end
                    childIds = string({child.SolvedCorrections.LayerId});
                    commonIds = intersect(baselineIds, childIds, "stable");
                    changes = zeros(numel(commonIds), 1);
                    for idIndex = 1:numel(commonIds)
                        baselineIndex = find( ...
                            baselineIds == commonIds(idIndex), 1, "first");
                        childIndex = find( ...
                            childIds == commonIds(idIndex), 1, "first");
                        childOpk = child.SolvedCorrections(childIndex). ...
                            ViewVectorAngularOffsetsDegrees;
                        changes(idIndex) = norm( ...
                            childOpk - baselineOpk(baselineIndex, :));
                    end
                    missingLayerIds = setdiff(baselineIds, childIds, "stable");
                    missingViewIds = strings(1, numel(missingLayerIds));
                    for missingIndex = 1:numel(missingLayerIds)
                        layerIndex = find(string({scene.layers.LayerId}) == ...
                            missingLayerIds(missingIndex), 1, "first");
                        missingViewIds(missingIndex) = ...
                            string(scene.layers(layerIndex).ViewId);
                    end
                    diagnostic.Status = "solved";
                    diagnostic.MaxAttitudeChangeDegrees = max(changes);
                    diagnostic.RmsAttitudeChangeDegrees = rms(changes);
                    diagnostic.MissingViewIds = missingViewIds;
                    diagnostic.Explanation = "none";
                catch ME
                    diagnostic.Explanation = string(ME.message);
                end
                diagnostics(end + 1) = diagnostic; %#ok<AGROW>
            end
        end

        function indices = recordLayerIndices(scene, record)
            layerIds = string({scene.layers.LayerId});
            first = find(layerIds == record.PairLayerIds(1), 1, "first");
            second = find(layerIds == record.PairLayerIds(2), 1, "first");
            if isempty(first) || isempty(second)
                error("ProjectionAlignmentNetworkSolver:unknownRecordLayer", ...
                    "A solver record references an unknown layer identity.");
            end
            indices = [first second];
        end

        function name = regionName(layer, row, column)
            imageSize = double(layer.SourceGeometry.ImageSize(:).');
            vertical = "top";
            horizontal = "left";
            if row > (imageSize(1) + 1) / 2
                vertical = "bottom";
            end
            if column > (imageSize(2) + 1) / 2
                horizontal = "right";
            end
            name = vertical + horizontal;
        end

        function values = summaries(keys, before, after, keyName)
            uniqueKeys = sort(unique(keys));
            template = struct();
            template.(keyName) = "";
            template.Count = 0;
            template.RmsBefore = NaN;
            template.RmsAfter = NaN;
            template.MaxBefore = NaN;
            template.MaxAfter = NaN;
            values = repmat(template, 1, numel(uniqueKeys));
            for index = 1:numel(uniqueKeys)
                mask = keys == uniqueKeys(index);
                value = template;
                value.(keyName) = uniqueKeys(index);
                value.Count = nnz(mask);
                value.RmsBefore = rms(before(mask));
                value.RmsAfter = rms(after(mask));
                value.MaxBefore = max(before(mask));
                value.MaxAfter = max(after(mask));
                values(index) = value;
            end
        end

        function root = root(parent, node)
            root = node;
            while parent(root) ~= root
                root = parent(root);
            end
        end
    end
end
