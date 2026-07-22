classdef MultiHarmonicFusion
    %MULTIHARMONICFUSION Fixed and hand-gated {1,2,4} phase costs.
    %
    % Odd-harmonic polarity and every gate remain explicit outputs.
    % Traceability: algo/main.tex Secs. 8.1-8.3, Eqs. (101)-(109).

    methods (Static)
        function result = fuse(qr, qm, options)
            arguments
                qr (:, 3) double
                qm (:, 3) double {mustHaveSameRows(qm, qr)}
                options.FixedWeights (1, 3) double ...
                    {mustBeFinite, mustBeNonnegative, mustHavePositiveSum} ...
                    = [1, 1, 1]
                options.PolarityPreservedProbability (:, 1) double ...
                    {mustBeFinite, mustBeProbability, ...
                    mustHaveOneOrNRows( ...
                    options.PolarityPreservedProbability, qr)} = ones(1, 1)
                options.OrthogonalStructureProbability (:, 1) double ...
                    {mustBeFinite, mustBeProbability, ...
                    mustHaveOneOrNRows( ...
                    options.OrthogonalStructureProbability, qr)} = ones(1, 1)
                options.LowAngularNoiseProbability (:, 1) double ...
                    {mustBeFinite, mustBeProbability, ...
                    mustHaveOneOrNRows( ...
                    options.LowAngularNoiseProbability, qr)} = ones(1, 1)
                options.Epsilon (1, 1) double ...
                    {mustBeFinite, mustBePositive} = 1e-12
                options.MinimumAdaptiveWeightSum (1, 1) double ...
                    {mustBeFinite, mustBePositive} = 1e-6
            end

            n = size(qr, 1);
            pol = MultiHarmonicFusion.expand( ...
                options.PolarityPreservedProbability, n);
            orth = MultiHarmonicFusion.expand( ...
                options.OrthogonalStructureProbability, n);
            quiet = MultiHarmonicFusion.expand( ...
                options.LowAngularNoiseProbability, n);
            validHarmonic = isfinite(qr) & isfinite(qm) ...
                & abs(qr) > options.Epsilon & abs(qm) > options.Epsilon;
            sr = qr ./ abs(qr);
            sm = qm ./ abs(qm);
            cost = (1 - real(sr .* conj(sm))) ./ 2;
            cost(~validHarmonic) = NaN;
            confidence = sqrt(abs(qr) .* abs(qm));
            confidence(~validHarmonic) = 0;

            fixedWeights = options.FixedWeights ./ sum(options.FixedWeights);
            fixedWeights = repmat(fixedWeights, n, 1);
            fixedValid = all(validHarmonic | fixedWeights == 0, 2);
            cf = cost;
            cf(~validHarmonic) = 0;
            fixedCost = sum(fixedWeights .* cf, 2);
            fixedCost(~fixedValid) = NaN;

            % Eqs. (106)-(108), using paired descriptor confidence c_m.
            raw = confidence;
            raw(:, 1) = raw(:, 1) .* pol;
            raw(:, 3) = raw(:, 3) .* orth .* quiet;
            raw(~validHarmonic) = 0;
            weightSum = sum(raw, 2);
            adaptiveValid = weightSum >= options.MinimumAdaptiveWeightSum;
            adaptiveWeights = raw ./ weightSum;
            adaptiveWeights(~adaptiveValid, :) = NaN;
            ca = cost;
            ca(~validHarmonic) = 0;
            adaptiveCost = sum(adaptiveWeights .* ca, 2);
            adaptiveCost(~adaptiveValid) = NaN;

            % Eq. (109) phase-moment consistency diagnostics in [0,1].
            chi12 = (1 + real(sr(:, 2) .* conj(sr(:, 1) .^ 2))) ./ 2;
            chi24 = (1 + real(sr(:, 3) .* conj(sr(:, 2) .^ 2))) ./ 2;
            chi12(~all(validHarmonic(:, 1:2), 2)) = NaN;
            chi24(~all(validHarmonic(:, 2:3), 2)) = NaN;

            result = struct( ...
                "HarmonicOrders", [1, 2, 4], ...
                "PerHarmonicCost", cost, ...
                "PairedConfidence", confidence, ...
                "FixedWeights", fixedWeights, ...
                "FixedCost", fixedCost, ...
                "FixedValid", fixedValid, ...
                "AdaptiveWeights", adaptiveWeights, ...
                "AdaptiveCost", adaptiveCost, ...
                "AdaptiveValid", adaptiveValid, ...
                "RawAdaptiveWeightSum", weightSum, ...
                "Chi12", chi12, "Chi24", chi24, ...
                "PolarityPreservedProbability", pol, ...
                "OrthogonalStructureProbability", orth, ...
                "LowAngularNoiseProbability", quiet);
        end
    end

    methods (Static, Access = private)
        function x = expand(x, n)
            if size(x, 1) == 1
                x = repmat(x, n, 1);
            end
        end
    end
end

function mustHaveSameRows(a, b)
if size(a, 1) ~= size(b, 1)
    error("MultiHarmonicFusion:RowCountMismatch", ...
        "Descriptor arrays must have the same number of rows.");
end
end

function mustHaveOneOrNRows(a, b)
if ~(size(a, 1) == 1 || size(a, 1) == size(b, 1))
    error("MultiHarmonicFusion:RowCountMismatch", ...
        "A gate must have one row or one row per descriptor.");
end
end

function mustBeProbability(x)
if any(x < 0 | x > 1, "all")
    error("MultiHarmonicFusion:InvalidProbability", ...
        "Gate probabilities must lie in [0,1].");
end
end

function mustHavePositiveSum(x)
if sum(x) <= 0
    error("MultiHarmonicFusion:ZeroWeightSum", ...
        "At least one fixed harmonic weight must be positive.");
end
end
