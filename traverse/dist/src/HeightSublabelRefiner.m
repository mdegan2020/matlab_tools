classdef HeightSublabelRefiner
    %HEIGHTSUBLABELREFINER Guarded three-point parabolic height refinement.
    %
    % Labels and outputs are metres. The nonuniform-grid quadratic reduces to
    % algo/main.tex Sec. 5.7, Eq. (76), on a uniform grid. Discrete selection
    % remains an input and is never overwritten when refinement is invalid.

    methods (Static)
        function result = refine(z, index, previous, center, next, options)
            arguments
                z (1, :) double ...
                    {mustBeFinite, mustBeIncreasing, mustHaveThreeElements}
                index (:, :) double ...
                    {mustBeFinite, mustBeInteger, mustBeNonnegative}
                previous (:, :) double ...
                    {mustHaveSameSize(previous, index)}
                center (:, :) double ...
                    {mustHaveSameSize(center, index)}
                next (:, :) double {mustHaveSameSize(next, index)}
                options.ValidMask (:, :) logical ...
                    {mustHaveSameSize(options.ValidMask, index)} = ...
                    true(size(index))
                options.MinimumCurvature (1, 1) double ...
                    {mustBeFinite, mustBeNonnegative} = 0
                options.MaximumOffsetFraction (1, 1) double ...
                    {mustBeFinite, mustBePositive, ...
                    mustBeLessThanOrEqual( ...
                    options.MaximumOffsetFraction, 1)} = 1
            end

            nl = numel(z);
            interior = options.ValidMask & index > 1 & index < nl;
            finiteNeighbors = interior & isfinite(previous) ...
                & isfinite(center) & isfinite(next);
            positiveCurvature = false(size(index));
            withinInterval = false(size(index));
            curvature = nan(size(index));
            offset = nan(size(index));
            discrete = nan(size(index));
            candidate = find(finiteNeighbors);
            k = index(candidate);
            if ~isempty(candidate)
                hm = reshape(z(k) - z(k - 1), [], 1);
                hp = reshape(z(k + 1) - z(k), [], 1);
                cm = reshape(previous(candidate), [], 1);
                c0 = reshape(center(candidate), [], 1);
                cp = reshape(next(candidate), [], 1);
                slopeMinus = (c0 - cm) ./ hm;
                slopePlus = (cp - c0) ./ hp;
                a = (slopePlus - slopeMinus) ./ (hm + hp);
                b = slopeMinus + a .* hm;
                curv = 2 .* a;
                delta = -b ./ curv;
                goodCurvature = isfinite(curv) ...
                    & curv > options.MinimumCurvature;
                goodInterval = goodCurvature ...
                    & delta >= -options.MaximumOffsetFraction .* hm ...
                    & delta <= options.MaximumOffsetFraction .* hp;
                curvature(candidate) = curv;
                positiveCurvature(candidate) = goodCurvature;
                withinInterval(candidate) = goodInterval;
                offset(candidate(goodInterval)) = delta(goodInterval);
            end
            selected = options.ValidMask & index > 0 & index <= nl;
            discrete(selected) = reshape(z(index(selected)), [], 1);
            valid = finiteNeighbors & positiveCurvature & withinInterval;
            refined = discrete;
            refined(valid) = discrete(valid) + offset(valid);
            refined(~valid) = NaN;

            result = struct( ...
                "DiscreteHeightMetres", discrete, ...
                "RefinedHeightMetres", refined, ...
                "OffsetMetres", offset, ...
                "CurvaturePerMetreSquared", curvature, ...
                "Valid", valid, ...
                "InteriorMinimum", interior, ...
                "FiniteNeighbors", finiteNeighbors, ...
                "PositiveCurvature", positiveCurvature, ...
                "WithinNeighborInterval", withinInterval, ...
                "MaximumOffsetFraction", options.MaximumOffsetFraction, ...
                "MinimumCurvature", options.MinimumCurvature, ...
                "FailurePolicy", ...
                "invalid refinement; discrete height remains separate");
        end
    end
end

function mustHaveSameSize(a, b)
if ~isequal(size(a), size(b))
    error("HeightSublabelRefiner:SizeMismatch", ...
        "Index, cost, and validity arrays must have identical sizes.");
end
end

function mustHaveThreeElements(x)
if numel(x) < 3
    error("HeightSublabelRefiner:TooFewLabels", ...
        "At least three height labels are required for refinement.");
end
end

function mustBeIncreasing(x)
if any(diff(x) <= 0)
    error("HeightSublabelRefiner:LabelsNotIncreasing", ...
        "Height labels must be strictly increasing.");
end
end
