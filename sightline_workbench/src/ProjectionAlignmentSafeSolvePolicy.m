classdef ProjectionAlignmentSafeSolvePolicy
    %ProjectionAlignmentSafeSolvePolicy Classify correction actionability.

    methods (Static)
        function result = apply(result, matchResult, options)
            %apply Attach passed/review/rejected policy without changing solve truth.
            if nargin < 2
                matchResult = struct();
            end
            if nargin < 3
                options = struct();
            end

            result = ProjectionAlignmentResult.validate(result);
            options = ProjectionAlignmentOptions.validate(options);
            policy = options.SafeSolvePolicy;
            decision = ProjectionAlignmentSafeSolvePolicy.initialDecision( ...
                policy, result, matchResult);

            if ~policy.Enabled
                decision.Status = "disabled";
                decision.PreviewAllowed = decision.FiniteSolvedCorrection;
                decision.ApplyAllowed = decision.FiniteSolvedCorrection;
                result.Diagnostics.SafeSolvePolicy = decision;
                result = ProjectionAlignmentResult.validate(result);
                return
            end

            hardReasons = strings(1, 0);
            warnings = strings(1, 0);
            if result.Status ~= "solved" || ~result.Convergence.Success
                hardReasons(end + 1) = ...
                    "The alignment solver did not converge successfully.";
            end
            if ~decision.FiniteSolvedCorrection
                hardReasons(end + 1) = ...
                    "The solved correction contains missing or nonfinite values.";
            end
            if ~decision.FiniteResidualState
                hardReasons(end + 1) = ...
                    "The solved residual state is missing or nonfinite.";
            end

            if ~isempty(decision.MatchCounts) && ...
                    decision.MinMatchCount < ...
                    policy.MinSolverObservationsPerPair
                hardReasons(end + 1) = sprintf( ...
                    "Solve has fewer than the hard minimum of %d observations in an enabled pair.", ...
                    policy.MinSolverObservationsPerPair);
            elseif ~isempty(decision.MatchCounts) && ...
                    decision.MinMatchCount < ...
                    policy.MinPreferredObservationsPerPair
                warnings(end + 1) = sprintf( ...
                    "Low-confidence review: each enabled pair should preferably have at least %d solver observations.", ...
                    policy.MinPreferredObservationsPerPair);
            end

            if policy.FailOnBoundHit && decision.BoundHit
                hardReasons(end + 1) = ...
                    "One or more solved parameters hit configured bounds.";
            end
            if decision.UnsupportedUnobservableMode
                hardReasons(end + 1) = ...
                    "The solved network contains an unsupported unobservable mode.";
            end
            if decision.NonfiniteConditionOrCovariance
                hardReasons(end + 1) = ...
                    "The solved condition or covariance state is nonfinite.";
            end
            if ~isempty(policy.MaximumConditionNumber) && ...
                    isfinite(decision.ConditionNumber) && ...
                    decision.ConditionNumber > policy.MaximumConditionNumber
                hardReasons(end + 1) = sprintf( ...
                    "Condition number %.4g exceeds the configured maximum %.4g.", ...
                    decision.ConditionNumber, policy.MaximumConditionNumber);
            end
            if ~isempty(policy.MaximumAttitudeStandardDeviationDegrees) && ...
                    isfinite(decision.MaximumAttitudeStandardDeviationDegrees) && ...
                    decision.MaximumAttitudeStandardDeviationDegrees > ...
                    policy.MaximumAttitudeStandardDeviationDegrees
                hardReasons(end + 1) = sprintf( ...
                    "Attitude standard deviation %.4g deg exceeds the configured maximum %.4g deg.", ...
                    decision.MaximumAttitudeStandardDeviationDegrees, ...
                    policy.MaximumAttitudeStandardDeviationDegrees);
            end

            if ProjectionAlignmentSafeSolvePolicy.materiallyDegraded( ...
                    decision.RmsBefore, decision.RmsAfter, ...
                    policy.MaximumResidualDegradationFraction)
                hardReasons(end + 1) = sprintf( ...
                    "Authoritative RMS degraded from %.4g to %.4g beyond the configured tolerance.", ...
                    decision.RmsBefore, decision.RmsAfter);
            elseif ~isempty(policy.PreferredResidualImprovementFraction) && ...
                    isfinite(decision.ResidualImprovementFraction) && ...
                    decision.ResidualImprovementFraction < ...
                    policy.PreferredResidualImprovementFraction
                warnings(end + 1) = sprintf( ...
                    "Residual improvement %.1f%% is below the preferred %.1f%%.", ...
                    100 * decision.ResidualImprovementFraction, ...
                    100 * policy.PreferredResidualImprovementFraction);
            end

            if decision.IsNoOp
                warnings(end + 1) = ...
                    "The correction is state-equivalent at stored precision.";
            elseif decision.CorrectionSmallRelativeToUncertainty
                warnings(end + 1) = ...
                    "The incremental OPK correction is small relative to estimated uncertainty.";
            end

            decision.Warnings = unique(warnings, "stable");
            decision.HardRejectionReasons = unique(hardReasons, "stable");
            decision.Reasons = decision.HardRejectionReasons;
            decision.PreviewAllowed = decision.FiniteSolvedCorrection;
            if ~isempty(decision.HardRejectionReasons)
                decision.Status = "rejected";
                decision.ApplyAllowed = false;
            elseif isempty(decision.Warnings)
                decision.Status = "passed";
                decision.ApplyAllowed = true;
            else
                decision.Status = "review";
                decision.ApplyAllowed = true;
                decision.ConfirmationRequired = true;
            end
            result.Warnings = unique([string(result.Warnings) ...
                decision.Warnings decision.HardRejectionReasons], "stable");
            result.Diagnostics.SafeSolvePolicy = decision;
            result = ProjectionAlignmentResult.validate(result);
        end

        function tf = isActionable(result)
            %isActionable Compatibility alias for ApplyAllowed.
            decision = ProjectionAlignmentSafeSolvePolicy.decision(result);
            tf = decision.ApplyAllowed;
        end

        function tf = isPreviewAllowed(result)
            %isPreviewAllowed True for a finite solved correction.
            decision = ProjectionAlignmentSafeSolvePolicy.decision(result);
            tf = decision.PreviewAllowed;
        end

        function tf = isApplyAllowed(result)
            %isApplyAllowed True for passed and review corrections.
            decision = ProjectionAlignmentSafeSolvePolicy.decision(result);
            tf = decision.ApplyAllowed;
        end

        function decision = decision(result)
            %decision Return a normalized action decision for one result.
            decision = struct(Status="rejected", PreviewAllowed=false, ...
                ApplyAllowed=false, ConfirmationRequired=false, ...
                Warnings=strings(1, 0), ...
                HardRejectionReasons="No completed policy decision is available.");
            if nargin < 1 || ~isstruct(result) || ~isscalar(result)
                return
            end
            result = ProjectionAlignmentResult.validate(result);
            if isfield(result.Diagnostics, "SafeSolvePolicy") && ...
                    isstruct(result.Diagnostics.SafeSolvePolicy)
                stored = result.Diagnostics.SafeSolvePolicy;
                required = ["Status" "PreviewAllowed" "ApplyAllowed" ...
                    "ConfirmationRequired" "Warnings" ...
                    "HardRejectionReasons"];
                if all(isfield(stored, required))
                    decision = stored;
                    return
                end
            end
            finiteSolved = result.Status == "solved" && ...
                result.Convergence.Success && ...
                ProjectionAlignmentSafeSolvePolicy.finiteCorrections( ...
                result.SolvedCorrections);
            decision.Status = "unclassified";
            decision.PreviewAllowed = finiteSolved;
            decision.ApplyAllowed = finiteSolved;
            decision.ConfirmationRequired = false;
            decision.Warnings = strings(1, 0);
            decision.HardRejectionReasons = strings(1, 0);
        end
    end

    methods (Static, Access = private)
        function decision = initialDecision(policy, result, matchResult)
            counts = ProjectionAlignmentSafeSolvePolicy.matchCounts( ...
                matchResult, result);
            [rmsBefore, rmsAfter] = ...
                ProjectionAlignmentSafeSolvePolicy.residualRms(result);
            observability = ...
                ProjectionAlignmentSafeSolvePolicy.observability(result);
            [conditionNumber, maximumStandardDeviation, nonfinite] = ...
                ProjectionAlignmentSafeSolvePolicy.uncertainty(observability);
            maximumOpk = ...
                ProjectionAlignmentSafeSolvePolicy.maximumOpk(result);
            [objectiveBefore, objectiveAfter] = ...
                ProjectionAlignmentSafeSolvePolicy.activeObjective(result);
            decision = struct(Enabled=policy.Enabled, Status="notRun", ...
                PreviewAllowed=false, ApplyAllowed=false, ...
                ConfirmationRequired=false, Warnings=strings(1, 0), ...
                HardRejectionReasons=strings(1, 0), ...
                Reasons=strings(1, 0), ...
                MinSolverObservationsPerPair= ...
                policy.MinSolverObservationsPerPair, ...
                MinPreferredObservationsPerPair= ...
                policy.MinPreferredObservationsPerPair, ...
                FailOnBoundHit=policy.FailOnBoundHit, ...
                PreferredResidualImprovementFraction= ...
                policy.PreferredResidualImprovementFraction, ...
                MaximumResidualDegradationFraction= ...
                policy.MaximumResidualDegradationFraction, ...
                MatchCounts=counts, ...
                MinMatchCount= ...
                ProjectionAlignmentSafeSolvePolicy.minOrNaN(counts), ...
                BoundHit=ProjectionAlignmentSafeSolvePolicy.boundHit(result), ...
                RmsBefore=rmsBefore, RmsAfter=rmsAfter, ...
                ResidualMetric= ...
                ProjectionAlignmentSafeSolvePolicy.residualMetric(result), ...
                ResidualImprovementFraction= ...
                ProjectionAlignmentSafeSolvePolicy.improvementFraction( ...
                rmsBefore, rmsAfter), ...
                ActiveObjectiveBefore=objectiveBefore, ...
                ActiveObjectiveAfter=objectiveAfter, ...
                ActiveObjectiveChange=objectiveAfter - objectiveBefore, ...
                MaximumIncrementalOpkDegrees=maximumOpk, ...
                ConditionNumber=conditionNumber, ...
                MaximumAttitudeStandardDeviationDegrees= ...
                maximumStandardDeviation, ...
                UnsupportedUnobservableMode= ...
                ProjectionAlignmentSafeSolvePolicy.unsupported(observability), ...
                NonfiniteConditionOrCovariance=nonfinite, ...
                FiniteSolvedCorrection= ...
                result.Status == "solved" && ...
                ProjectionAlignmentSafeSolvePolicy.finiteCorrections( ...
                result.SolvedCorrections), ...
                FiniteResidualState= ...
                isfinite(rmsBefore) && isfinite(rmsAfter), ...
                IsNoOp=maximumOpk == 0, ...
                CorrectionSmallRelativeToUncertainty= ...
                isfinite(maximumStandardDeviation) && maximumOpk > 0 && ...
                maximumOpk <= maximumStandardDeviation);
        end

        function tf = finiteCorrections(corrections)
            tf = ~isempty(corrections);
            for index = 1:numel(corrections)
                fields = ["ViewVectorAngularOffsetsDegrees" ...
                    "ProjectionOffsetMeters" "SharedScale"];
                for field = fields
                    if isfield(corrections(index), field)
                        value = corrections(index).(field);
                        tf = tf && isnumeric(value) && ...
                            ~isempty(value) && all(isfinite(value), "all");
                    end
                end
            end
        end

        function maximum = maximumOpk(result)
            maximum = NaN;
            if isempty(result.SolvedCorrections)
                return
            end
            values = reshape([result.SolvedCorrections. ...
                ViewVectorAngularOffsetsDegrees], 3, []).';
            if all(isfinite(values), "all")
                maximum = max(abs(values), [], "all");
            end
        end

        function tf = materiallyDegraded(before, after, tolerance)
            tf = false;
            if isempty(tolerance) || ~isfinite(before) || ~isfinite(after)
                return
            end
            if before > eps
                tf = (after - before) / before > tolerance;
            else
                tf = after > sqrt(eps);
            end
        end

        function observability = observability(result)
            observability = struct();
            if ~isfield(result.Diagnostics, "Observability") || ...
                    ~isstruct(result.Diagnostics.Observability)
                return
            end
            observability = result.Diagnostics.Observability;
            if isfield(observability, "Solution") && ...
                    isstruct(observability.Solution)
                observability = observability.Solution;
            end
        end

        function tf = unsupported(observability)
            tf = isfield(observability, ...
                "HasUnsupportedUnobservableMode") && ...
                logical(observability.HasUnsupportedUnobservableMode);
        end

        function [conditionNumber, maximumStandardDeviation, nonfinite] = ...
                uncertainty(observability)
            conditionNumber = NaN;
            maximumStandardDeviation = NaN;
            nonfinite = false;
            if isfield(observability, "ConditionNumber")
                conditionNumber = double(observability.ConditionNumber);
                nonfinite = ~isscalar(conditionNumber) || ...
                    ~isfinite(conditionNumber);
            end
            covariance = [];
            if isfield(observability, "EffectiveAttitudeCovariance")
                covariance = double( ...
                    observability.EffectiveAttitudeCovariance);
            elseif isfield(observability, "ParameterCovariance")
                covariance = double(observability.ParameterCovariance);
            end
            if ~isempty(covariance)
                nonfinite = nonfinite || any(~isfinite(covariance), "all");
                diagonal = diag(covariance);
                if all(isfinite(diagonal)) && all(diagonal >= 0)
                    maximumStandardDeviation = sqrt(max(diagonal));
                else
                    nonfinite = true;
                end
            end
        end

        function counts = matchCounts(matchResult, result)
            counts = [];
            if isstruct(matchResult) && isfield(matchResult, "Matches") && ...
                    ~isempty(matchResult.Matches) && ...
                    isfield(matchResult.Matches, "Count")
                counts = double([matchResult.Matches.Count]);
            elseif isfield(result, "Matches") && ~isempty(result.Matches)
                counts = double([result.Matches.Count]);
            end
            counts = reshape(counts, 1, []);
        end

        function tf = boundHit(result)
            tf = false;
            if isfield(result.Diagnostics, "AnyBoundHit")
                value = result.Diagnostics.AnyBoundHit;
                if (islogical(value) || isnumeric(value)) && isscalar(value)
                    tf = logical(value);
                end
            end
        end

        function [before, after] = residualRms(result)
            if isfield(result.Diagnostics, "Comparison") && ...
                    isstruct(result.Diagnostics.Comparison) && ...
                    isfield(result.Diagnostics.Comparison, "ForwardRay3D")
                physical = result.Diagnostics.Comparison.ForwardRay3D;
                if isstruct(physical) && ...
                        all(isfield(physical, ["RmsBefore" "RmsAfter"])) && ...
                        all(isfinite([physical.RmsBefore physical.RmsAfter]))
                    before = double(physical.RmsBefore);
                    after = double(physical.RmsAfter);
                    return
                end
            end
            before = ProjectionAlignmentSafeSolvePolicy.diagnosticRms( ...
                result, "RmsBefore");
            after = ProjectionAlignmentSafeSolvePolicy.diagnosticRms( ...
                result, "RmsAfter");
            if isnan(before) && isfield(result, "Residuals")
                before = ProjectionAlignmentSafeSolvePolicy.rmsOrNaN( ...
                    result.Residuals.Before);
            end
            if isnan(after) && isfield(result, "Residuals")
                after = ProjectionAlignmentSafeSolvePolicy.rmsOrNaN( ...
                    result.Residuals.After);
            end
        end

        function metric = residualMetric(result)
            metric = "activeLossFallback";
            if isfield(result.Diagnostics, "Comparison") && ...
                    isstruct(result.Diagnostics.Comparison) && ...
                    isfield(result.Diagnostics.Comparison, "ForwardRay3D")
                metric = "forwardRay3D";
            end
        end

        function [before, after] = activeObjective(result)
            before = NaN;
            after = NaN;
            candidate = result.Convergence.Objective;
            if isnumeric(candidate) && isscalar(candidate) && ...
                    isfinite(candidate)
                after = double(candidate);
            end
            if ~isfield(result.Diagnostics, "ActiveObjective") || ...
                    ~isstruct(result.Diagnostics.ActiveObjective)
                return
            end
            active = result.Diagnostics.ActiveObjective;
            if all(isfield(active, ["Before" "After"])) && ...
                    all(isfinite([active.Before active.After]))
                before = double(active.Before);
                after = double(active.After);
            end
        end

        function value = diagnosticRms(result, fieldName)
            value = NaN;
            if isfield(result.Diagnostics, fieldName)
                candidate = result.Diagnostics.(fieldName);
                if isnumeric(candidate) && isscalar(candidate) && ...
                        isfinite(candidate)
                    value = double(candidate);
                end
            end
        end

        function fraction = improvementFraction(before, after)
            fraction = NaN;
            if isfinite(before) && isfinite(after) && before > eps
                fraction = (before - after) / before;
            end
        end

        function value = rmsOrNaN(values)
            value = NaN;
            if ~isempty(values)
                values = double(values(:));
                if all(isfinite(values))
                    value = sqrt(mean(values .^ 2));
                end
            end
        end

        function value = minOrNaN(values)
            if isempty(values)
                value = NaN;
            else
                value = min(values);
            end
        end
    end
end
