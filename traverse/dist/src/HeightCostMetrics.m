classdef HeightCostMetrics
    %HEIGHTCOSTMETRICS Diagnostics for unregularized elevation cost curves.
    %
    % Traceability: algo/main.tex Sec. 10.4 "Raw cost-curve diagnostics".
    % The reported quantities implement Z_(1), Z_(2), Delta C_12,
    % kappa_C, and epsilon_Z in Eqs. (121)-(125).

    methods (Static)
        function metrics = analyze(result, truthHeight)
            %ANALYZE Summarize every named channel returned by HeightCostCurve.
            arguments
                result (1, 1) struct
                truthHeight (:, 1) double {mustBeFinite, mustBeNonempty}
            end

            z = result.Height;
            names = fieldnames(result.Costs);
            metrics = struct;
            for j = 1:numel(names)
                name = names{j};
                c = result.Costs.(name);
                n = size(c, 1);
                nz = size(c, 2);
                [~, kt] = min(abs(z - truthHeight), [], 2);
                ks = HeightCostMetrics.rowArgmin(c);
                indTruth = sub2ind([n, nz], (1:n).', kt);
                ct = c(indTruth);
                nv = sum(isfinite(c), 2);
                rank = 1 + sum(c < ct, 2, "omitmissing");
                rank(~isfinite(ct)) = NaN;
                percentile = 100 .* (rank - 1) ./ max(nv - 1, 1);
                tieCount = sum(c == ct, 2);
                tieCount(~isfinite(ct)) = NaN;
                uniqueTruthBest = rank == 1 & tieCount == 1;

                second = nan(n, 1);
                count = zeros(n, 1);
                curvature = nan(n, 1);
                for i = 1:n
                    ci = c(i, :);
                    left = [inf, ci(1:end - 1)];
                    right = [ci(2:end), inf];
                    lm = isfinite(ci) & ci <= left & ci <= right ...
                        & (ci < left | ci < right);
                    v = sort(unique(ci(lm)));
                    count(i) = numel(v);
                    if numel(v) > 1
                        second(i) = v(2);
                    end
                    k = ks(i);
                    if isfinite(k) && k > 1 && k < nz ...
                            && all(isfinite(ci(k + (-1:1))))
                        h0 = z(k) - z(k - 1);
                        h1 = z(k + 1) - z(k);
                        curvature(i) = 2 .* ( ...
                            (ci(k + 1) - ci(k)) ./ h1 ...
                            - (ci(k) - ci(k - 1)) ./ h0) ./ (h0 + h1);
                    end
                end

                selected = result.SelectedHeight.(name);
                support = nan(n, 1);
                if isfield(result.SupportFraction, name)
                    s = result.SupportFraction.(name);
                    support = s(indTruth);
                end
                best = min(c, [], 2, "omitnan");
                best(nv == 0) = NaN;
                metrics.(name) = struct( ...
                    "TruthHeightMetres", truthHeight, ...
                    "TruthLabelMetres", reshape(z(kt), [], 1), ...
                    "TruthLabelRank", rank, ...
                    "TruthCostPercentile", percentile, ...
                    "TruthCostTieCount", tieCount, ...
                    "IsUniqueTruthBest", uniqueTruthBest, ...
                    "CostAtTruthLabel", ct, ...
                    "SelectedHeightMetres", selected, ...
                    "SelectedHeightErrorMetres", selected - truthHeight, ...
                    "BestCost", best, ...
                    "SecondDistinctLocalMinimumCost", second, ...
                    "DistinctMinimumMargin", second - best, ...
                    "SelectedCurvaturePerMetreSquared", curvature, ...
                    "NumberDistinctLocalMinima", count, ...
                    "NumberValidLabels", nv, ...
                    "ValidLabelFraction", nv ./ nz, ...
                    "SupportFractionAtTruth", support);
            end
        end
    end

    methods (Static, Access = private)
        function k = rowArgmin(c)
            [~, k] = min(c, [], 2, "omitnan");
            k = double(k);
            k(all(~isfinite(c), 2)) = NaN;
        end
    end
end
