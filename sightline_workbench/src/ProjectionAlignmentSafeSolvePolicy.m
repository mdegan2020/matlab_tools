classdef ProjectionAlignmentSafeSolvePolicy
    %ProjectionAlignmentSafeSolvePolicy Mark implausible GUI solves as failed.

    methods (Static)
        function result = apply(result, matchResult, options)
            %apply Add safe-solve diagnostics and fail unsafe solved results.
            if nargin < 2
                matchResult = struct();
            end
            if nargin < 3
                options = struct();
            end

            result = ProjectionAlignmentResult.validate(result);
            options = ProjectionAlignmentOptions.validate(options);
            policy = options.SafeSolvePolicy;
            diagnostics = ProjectionAlignmentSafeSolvePolicy.initialDiagnostics( ...
                policy, result, matchResult);

            if ~policy.Enabled
                diagnostics.Status = "disabled";
                result.Diagnostics.SafeSolvePolicy = diagnostics;
                result = ProjectionAlignmentResult.validate(result);
                return
            end

            if result.Status ~= "solved"
                diagnostics.Status = "skipped";
                result.Diagnostics.SafeSolvePolicy = diagnostics;
                result = ProjectionAlignmentResult.validate(result);
                return
            end

            reasons = strings(1, 0);
            warnings = strings(1, 0);
            if ~isempty(diagnostics.MatchCounts) && ...
                    diagnostics.MinMatchCount < ...
                    policy.MinSolverObservationsPerPair
                reasons(end + 1) = sprintf( ...
                    "Solve has fewer than the hard minimum of %d observations in an enabled pair.", ...
                    policy.MinSolverObservationsPerPair);
            elseif ~isempty(diagnostics.MatchCounts) && ...
                    diagnostics.MinMatchCount < ...
                    policy.MinPreferredObservationsPerPair
                warnings(end + 1) = sprintf( ...
                    "Low-confidence solve: each enabled pair should preferably have at least %d solver observations.", ...
                    policy.MinPreferredObservationsPerPair);
            end

            if policy.FailOnBoundHit && diagnostics.BoundHit
                reasons(end + 1) = ...
                    "Solve bound-limited: one or more parameters hit configured bounds.";
            end

            if ~isempty(policy.MinResidualImprovementFraction) && ...
                    isfinite(diagnostics.ResidualImprovementFraction) && ...
                    diagnostics.ResidualImprovementFraction < ...
                    policy.MinResidualImprovementFraction
                reasons(end + 1) = sprintf( ...
                    "Solve residual-limited: residual improvement %.1f%% is below %.1f%%.", ...
                    100 * diagnostics.ResidualImprovementFraction, ...
                    100 * policy.MinResidualImprovementFraction);
            end

            if isempty(reasons)
                if isempty(warnings)
                    diagnostics.Status = "passed";
                else
                    diagnostics.Status = "warning";
                    diagnostics.Warnings = warnings;
                    result.Warnings = [string(result.Warnings) warnings];
                end
            else
                diagnostics.Status = "failed";
                diagnostics.Reasons = reasons;
                result = ProjectionAlignmentSafeSolvePolicy.markFailed( ...
                    result, reasons);
            end

            result.Diagnostics.SafeSolvePolicy = diagnostics;
            result = ProjectionAlignmentResult.validate(result);
        end

        function tf = isActionable(result)
            %isActionable True when a result is safe to preview/apply.
            tf = false;
            if nargin < 1 || ~isstruct(result) || ~isscalar(result)
                return
            end
            result = ProjectionAlignmentResult.validate(result);
            tf = result.Status == "solved" && result.Convergence.Success && ...
                ~isempty(result.SolvedCorrections);
            if tf && isfield(result.Diagnostics, "SafeSolvePolicy")
                policy = result.Diagnostics.SafeSolvePolicy;
                if isfield(policy, "Status") && string(policy.Status) == "failed"
                    tf = false;
                end
            end
        end
    end

    methods (Static, Access = private)
        function diagnostics = initialDiagnostics(policy, result, matchResult)
            matchCounts = ProjectionAlignmentSafeSolvePolicy.matchCounts( ...
                matchResult, result);
            [rmsBefore, rmsAfter] = ...
                ProjectionAlignmentSafeSolvePolicy.residualRms(result);
            diagnostics = struct();
            diagnostics.Enabled = policy.Enabled;
            diagnostics.Status = "notRun";
            diagnostics.Reasons = strings(1, 0);
            diagnostics.Warnings = strings(1, 0);
            diagnostics.MinSolverObservationsPerPair = ...
                policy.MinSolverObservationsPerPair;
            diagnostics.MinPreferredObservationsPerPair = ...
                policy.MinPreferredObservationsPerPair;
            diagnostics.FailOnBoundHit = policy.FailOnBoundHit;
            diagnostics.MinResidualImprovementFraction = ...
                policy.MinResidualImprovementFraction;
            diagnostics.MatchCounts = matchCounts;
            diagnostics.MinMatchCount = ...
                ProjectionAlignmentSafeSolvePolicy.minOrNaN(matchCounts);
            diagnostics.BoundHit = ...
                ProjectionAlignmentSafeSolvePolicy.boundHit(result);
            diagnostics.RmsBefore = rmsBefore;
            diagnostics.RmsAfter = rmsAfter;
            diagnostics.ResidualMetric = ...
                ProjectionAlignmentSafeSolvePolicy.residualMetric(result);
            diagnostics.ResidualImprovementFraction = ...
                ProjectionAlignmentSafeSolvePolicy.improvementFraction( ...
                rmsBefore, rmsAfter);
        end

        function result = markFailed(result, reasons)
            result.Status = "failed";
            result.Convergence.Status = "failed";
            result.Convergence.Success = false;
            message = "Safe solve policy failed: " + strjoin(reasons, " ");
            if strlength(result.Convergence.Message) > 0
                result.Convergence.Message = result.Convergence.Message + ...
                    " " + message;
            else
                result.Convergence.Message = message;
            end
            result.Warnings = [string(result.Warnings) reasons];
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
            if isfield(result, "Diagnostics") && ...
                    isfield(result.Diagnostics, "AnyBoundHit")
                candidate = result.Diagnostics.AnyBoundHit;
                if (islogical(candidate) || isnumeric(candidate)) && ...
                        isscalar(candidate)
                    tf = logical(candidate);
                end
            end
        end

        function [rmsBefore, rmsAfter] = residualRms(result)
            if isfield(result, "Diagnostics") && ...
                    isfield(result.Diagnostics, "Comparison") && ...
                    isstruct(result.Diagnostics.Comparison) && ...
                    isfield(result.Diagnostics.Comparison, "ForwardRay3D")
                physical = result.Diagnostics.Comparison.ForwardRay3D;
                if isstruct(physical) && ...
                        all(isfield(physical, ["RmsBefore", "RmsAfter"])) && ...
                        all(isfinite([physical.RmsBefore, physical.RmsAfter]))
                    rmsBefore = double(physical.RmsBefore);
                    rmsAfter = double(physical.RmsAfter);
                    return
                end
            end
            rmsBefore = ProjectionAlignmentSafeSolvePolicy.diagnosticRms( ...
                result, "RmsBefore");
            rmsAfter = ProjectionAlignmentSafeSolvePolicy.diagnosticRms( ...
                result, "RmsAfter");
            if isnan(rmsBefore) && isfield(result, "Residuals")
                rmsBefore = ProjectionAlignmentSafeSolvePolicy.rmsOrNaN( ...
                    result.Residuals.Before);
            end
            if isnan(rmsAfter) && isfield(result, "Residuals")
                rmsAfter = ProjectionAlignmentSafeSolvePolicy.rmsOrNaN( ...
                    result.Residuals.After);
            end
        end

        function metric = residualMetric(result)
            metric = "activeLossFallback";
            if isfield(result, "Diagnostics") && ...
                    isfield(result.Diagnostics, "Comparison") && ...
                    isstruct(result.Diagnostics.Comparison) && ...
                    isfield(result.Diagnostics.Comparison, "ForwardRay3D")
                metric = "forwardRay3D";
            end
        end

        function value = diagnosticRms(result, fieldName)
            value = NaN;
            if isfield(result, "Diagnostics") && ...
                    isfield(result.Diagnostics, fieldName)
                candidate = result.Diagnostics.(fieldName);
                if isnumeric(candidate) && isscalar(candidate) && ...
                        isfinite(candidate)
                    value = double(candidate);
                end
            end
        end

        function fraction = improvementFraction(rmsBefore, rmsAfter)
            fraction = NaN;
            if ~isfinite(rmsBefore) || ~isfinite(rmsAfter) || rmsBefore <= eps
                return
            end
            fraction = (rmsBefore - rmsAfter) / rmsBefore;
        end

        function value = rmsOrNaN(values)
            if isempty(values)
                value = NaN;
                return
            end
            values = double(values(:));
            value = sqrt(mean(values.^2));
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
