classdef HeightConfidenceCalibrator
    %HEIGHTCONFIDENCECALIBRATOR Empirical raw-cost confidence calibration.
    %
    % A dimensionless score combines the Eq. (123) second-label margin and
    % Eq. (124) local curvature over one label step. Equal-scene weights are
    % supplied by the experiment harness. Per-bin endpoint RMSE is fitted on
    % tuning scenes and constrained to decrease with confidence. Predicted
    % height uncertainty is sigma_p/||dw/dZ||. Traceability:
    % algo/main.tex Secs. 10.4 and 14.6; Eqs. (121)-(125).

    properties (SetAccess = private)
        MarginScale (1, 1) double
        CurvatureStepScale (1, 1) double
        ScoreBoundaries (1, :) double
        SigmaPixels (1, :) double
    end

    methods
        function obj = HeightConfidenceCalibrator(marginScale, ...
                curvatureStepScale, scoreBoundaries, sigmaPixels)
            arguments
                marginScale (1, 1) double {mustBeFinite, mustBePositive}
                curvatureStepScale (1, 1) double ...
                    {mustBeFinite, mustBePositive}
                scoreBoundaries (1, :) double {mustBeFinite}
                sigmaPixels (1, :) double ...
                    {mustBeFinite, mustBePositive}
            end

            obj.MarginScale = marginScale;
            obj.CurvatureStepScale = curvatureStepScale;
            obj.ScoreBoundaries = scoreBoundaries;
            obj.SigmaPixels = sigmaPixels;
        end

        function result = predict(obj, margin, curvatureStepCost, kappa)
            %PREDICT Calibrated image- and height-domain uncertainty.
            arguments
                obj (1, 1) HeightConfidenceCalibrator
                margin (:, :) double
                curvatureStepCost (:, :) double
                kappa (:, :) double
            end

            valid = isfinite(margin) & margin >= 0 ...
                & isfinite(curvatureStepCost) & curvatureStepCost > 0 ...
                & isfinite(kappa) & kappa > 0;
            score = nan(size(margin));
            score(valid) = log1p(margin(valid) ./ obj.MarginScale) ...
                + log1p(curvatureStepCost(valid) ...
                ./ obj.CurvatureStepScale);
            bin = zeros(size(margin));
            bin(valid) = discretize(score(valid), ...
                [-Inf, obj.ScoreBoundaries, Inf]);
            sigmaPixel = nan(size(margin));
            sigmaPixel(valid) = obj.SigmaPixels(bin(valid));
            sigmaHeight = nan(size(margin));
            sigmaHeight(valid) = sigmaPixel(valid) ./ kappa(valid);

            result = struct("Score", score, "BinIndex", bin, ...
                "SigmaPixels", sigmaPixel, ...
                "SigmaHeightMetres", sigmaHeight, "Valid", valid, ...
                "Definition", ...
                "log1p(margin/marginScale) + " ...
                + "log1p(curvature*labelStep^2/curvatureStepScale)");
        end

        function s = toStruct(obj)
            %TOSTRUCT Human-readable form suitable for a JSON manifest.
            s = struct("marginScale", obj.MarginScale, ...
                "curvatureStepScale", obj.CurvatureStepScale, ...
                "scoreBoundaries", obj.ScoreBoundaries, ...
                "sigmaPixels", obj.SigmaPixels, ...
                "definition", ...
                "log1p(margin/marginScale) + " ...
                + "log1p(curvature*labelStep^2/curvatureStepScale)");
        end
    end

    methods (Static)
        function [obj, report] = fit(margin, curvatureStepCost, ...
                epePixels, weight, options)
            %FIT Fit monotone endpoint-RMSE bins from tuning samples only.
            arguments
                margin (:, 1) double
                curvatureStepCost (:, 1) double
                epePixels (:, 1) double
                weight (:, 1) double {mustBeFinite, mustBeNonnegative}
                options.BinCount (1, 1) double ...
                    {mustBeFinite, mustBeInteger, ...
                    mustBeGreaterThanOrEqual(options.BinCount, 2)} = 6
            end

            valid = isfinite(margin) & margin >= 0 ...
                & isfinite(curvatureStepCost) & curvatureStepCost > 0 ...
                & isfinite(epePixels) & epePixels >= 0 & weight > 0;
            m = margin(valid);
            c = curvatureStepCost(valid);
            e = epePixels(valid);
            w = weight(valid);
            marginScale = HeightConfidenceCalibrator.weightedMedian( ...
                m(m > 0), w(m > 0));
            curvatureScale = HeightConfidenceCalibrator.weightedMedian( ...
                c(c > 0), w(c > 0));
            score = log1p(m ./ marginScale) ...
                + log1p(c ./ curvatureScale);

            [score, order] = sort(score);
            e = e(order);
            w = w(order);
            q = (1:options.BinCount - 1) ./ options.BinCount;
            [uniqueScore, ~, group] = unique(score);
            uniqueWeight = accumarray(group, w);
            cw = cumsum(uniqueWeight) ./ sum(uniqueWeight);
            boundaries = nan(size(q));
            for k = 1:numel(q)
                j = find(cw >= q(k), 1, "first");
                if j < numel(uniqueScore)
                    boundaries(k) = 0.5 .* (uniqueScore(j) ...
                        + uniqueScore(j + 1));
                end
            end
            boundaries = unique(boundaries(isfinite(boundaries)));
            bin = discretize(score, [-Inf, boundaries, Inf]);
            nb = numel(boundaries) + 1;
            count = accumarray(bin, 1, [nb, 1]);
            mass = accumarray(bin, w, [nb, 1]);
            mse = accumarray(bin, w .* e .^ 2, [nb, 1]) ./ mass;
            fittedMse = HeightConfidenceCalibrator.nonincreasingFit( ...
                mse, mass);
            sigma = sqrt(fittedMse);
            lower = [-Inf; boundaries(:)];
            upper = [boundaries(:); Inf];
            bins = table((1:nb).', lower, upper, count, mass, ...
                sqrt(mse), sigma, VariableNames=["Bin", "ScoreLower", ...
                "ScoreUpper", "SampleCount", "EqualSceneWeight", ...
                "EmpiricalEpeRmsePixels", "FittedSigmaPixels"]);

            obj = HeightConfidenceCalibrator(marginScale, ...
                curvatureScale, boundaries, sigma.');
            report = struct("Bins", bins, ...
                "ValidSampleCount", nnz(valid), ...
                "InvalidSampleCount", nnz(~valid), ...
                "Calibration", obj.toStruct, ...
                "MonotonicConstraint", ...
                "predicted endpoint RMSE is nonincreasing with score");
        end

        function obj = fromStruct(s)
            %FROMSTRUCT Restore committed calibration parameters.
            arguments
                s (1, 1) struct
            end

            obj = HeightConfidenceCalibrator( ...
                double(s.marginScale), double(s.curvatureStepScale), ...
                double(s.scoreBoundaries(:).'), ...
                double(s.sigmaPixels(:).'));
        end
    end

    methods (Static, Access = private)
        function value = weightedMedian(x, w)
            [x, order] = sort(x);
            w = w(order);
            value = x(find(cumsum(w) >= 0.5 .* sum(w), 1, "first"));
        end

        function fitted = nonincreasingFit(value, weight)
            % Weighted pool-adjacent-violators fit for descending values.
            n = numel(value);
            level = value(:);
            mass = weight(:);
            first = (1:n).';
            last = first;
            blocks = n;
            k = 1;
            while k < blocks
                if level(k) < level(k + 1)
                    total = mass(k) + mass(k + 1);
                    level(k) = (mass(k) .* level(k) ...
                        + mass(k + 1) .* level(k + 1)) ./ total;
                    mass(k) = total;
                    last(k) = last(k + 1);
                    level(k + 1:blocks - 1) = level(k + 2:blocks);
                    mass(k + 1:blocks - 1) = mass(k + 2:blocks);
                    first(k + 1:blocks - 1) = first(k + 2:blocks);
                    last(k + 1:blocks - 1) = last(k + 2:blocks);
                    blocks = blocks - 1;
                    k = max(k - 1, 1);
                else
                    k = k + 1;
                end
            end
            fitted = nan(n, 1);
            for k = 1:blocks
                fitted(first(k):last(k)) = level(k);
            end
        end
    end
end
