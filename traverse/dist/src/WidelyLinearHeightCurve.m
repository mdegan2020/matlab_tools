classdef WidelyLinearHeightCurve
    %WIDELYLINEARHEIGHTCURVE Rendered Mode A/B residual height curves.
    %
    % For each camera-predicted height, moving gradients are sampled and
    % transported first. The direct residual is Mode A. Mode B separately fits
    % conformal-only and full y=a*x+b*conj(x) patch models. A free fit is never
    % folded into another cost. Traceability: algo/main.tex Secs. 7.1-7.5;
    % Eqs. (86)-(95), especially the residual model Eq. (96).

    properties (SetAccess = private)
        CostCurve
    end

    methods
        function obj = WidelyLinearHeightCurve(costCurve)
            arguments
                costCurve (1, 1) HeightCostCurve
            end

            obj.CostCurve = costCurve;
        end

        function result = evaluate(obj, p, z, options)
            arguments
                obj (1, 1) WidelyLinearHeightCurve
                p (:, 2) double {mustBeFinite, mustBeNonempty}
                z (1, :) double {mustBeFinite, mustBeNonempty}
                options.DeltaPixel (1, 1) double ...
                    {mustBeFinite, mustBePositive} = 0.5
                options.MinimumSupportFraction (1, 1) double ...
                    {mustBeFinite, ...
                    mustBeGreaterThanOrEqual( ...
                    options.MinimumSupportFraction, 0), ...
                    mustBeLessThanOrEqual( ...
                    options.MinimumSupportFraction, 1)} = 0.8
                options.MinimumGradient (1, 1) double ...
                    {mustBeFinite, mustBeNonnegative} = 1e-6
                options.RequireOrientationPreserving (1, 1) logical = true
                options.LambdaA (1, 1) double ...
                    {mustBeFinite, mustBeNonnegative} = 1e-12
                options.LambdaB (1, 1) double ...
                    {mustBeFinite, mustBeNonnegative} = 1e-10
                options.MaximumConditionNumber (1, 1) double ...
                    {mustBeFinite, mustBePositive} = 1e8
            end

            reference = obj.CostCurve.Reference;
            moving = obj.CostCurve.Moving;
            geometry = obj.CostCurve.Geometry;
            [ox, oy] = meshgrid( ...
                -reference.IntegrationRadius:reference.IntegrationRadius);
            off = [ox(:), oy(:)];
            n = size(p, 1);
            np = size(off, 1);
            nl = numel(z);
            pp = reshape(p, n, 1, 2) + reshape(off, 1, np, 2);
            pp = reshape(pp, n .* np, 2);
            kw = reference.IntegrationKernel(:);
            [gr, vgr] = reference.sampleGradient(pp);
            gr = reshape(gr, n, np);
            vgr = reshape(vgr, n, np) ...
                & abs(gr) >= options.MinimumGradient;

            direct = nan(n, nl);
            conformal = nan(n, nl);
            full = nan(n, nl);
            delta = nan(n, nl);
            a = complex(nan(n, nl));
            b = complex(nan(n, nl));
            mu = complex(nan(n, nl));
            condition = nan(n, nl);
            rank = zeros(n, nl);
            support = zeros(n, nl);
            fitValid = false(n, nl);
            physicalValid = false(n, nl);
            for k = 1:nl
                [w, vw] = geometry.warp(pp, z(k));
                [gm, vgm] = moving.sampleGradient(w);
                [aj, va] = geometry.warpJacobian( ...
                    pp, z(k), DeltaPixel=options.DeltaPixel);
                ht = ComplexGradientImage.transport(gm, aj);
                detA = aj(:, 1, 1) .* aj(:, 2, 2) ...
                    - aj(:, 1, 2) .* aj(:, 2, 1);
                orientationValid = ~options.RequireOrientationPreserving ...
                    | detA > 0;
                ht = reshape(ht, n, np);
                vht = reshape( ...
                    vgm & vw & va & orientationValid, n, np) ...
                    & abs(ht) >= options.MinimumGradient;
                for i = 1:n
                    validSample = vgr(i, :) & vht(i, :);
                    support(i, k) = sum(kw(validSample));
                    if support(i, k) < options.MinimumSupportFraction
                        continue
                    end
                    y = gr(i, :).';
                    x = ht(i, :).';
                    fit = WidelyLinearPatchModel.fit(y, x, kw, ...
                        ValidMask=validSample.', ...
                        LambdaA=options.LambdaA, ...
                        LambdaB=options.LambdaB, ...
                        Epsilon=reference.Epsilon, ...
                        EpsilonA=reference.Epsilon, ...
                        MaximumConditionNumber= ...
                        options.MaximumConditionNumber);
                    condition(i, k) = fit.ConditionNumber;
                    rank(i, k) = fit.DesignRank;
                    fitValid(i, k) = fit.FitValid;
                    physicalValid(i, k) = fit.PhysicalValid;
                    if ~fit.FitValid
                        continue
                    end
                    weight = kw .* double(validSample.');
                    yy = y;
                    xx = x;
                    yy(~validSample.') = 0;
                    xx(~validSample.') = 0;
                    den = sum(weight .* abs(yy) .^ 2) ...
                        + reference.Epsilon;
                    direct(i, k) = sum( ...
                        weight .* abs(yy - xx) .^ 2) ./ den;
                    conformal(i, k) = fit.ConformalResidualCost;
                    full(i, k) = fit.FullResidualCost;
                    delta(i, k) = fit.DeltaCost;
                    a(i, k) = fit.A;
                    b(i, k) = fit.B;
                    mu(i, k) = fit.Mu;
                end
            end

            costs = struct("Direct", direct, ...
                "ConformalFit", conformal, "FullFit", full);
            selected = struct;
            valid = struct;
            names = fieldnames(costs);
            for k = 1:numel(names)
                selected.(names{k}) = ...
                    WidelyLinearHeightCurve.selectHeight( ...
                    costs.(names{k}), z);
                valid.(names{k}) = isfinite(costs.(names{k}));
            end
            supportFraction = struct( ...
                "Direct", support, "ConformalFit", support, ...
                "FullFit", support);
            result = struct( ...
                "ReferencePixel", p, "Height", z, ...
                "Costs", costs, "SelectedHeight", selected, ...
                "Valid", valid, "SupportFraction", supportFraction, ...
                "A", a, "B", b, "Mu", mu, "DeltaCost", delta, ...
                "ConditionNumber", condition, "DesignRank", rank, ...
                "FitValid", fitValid, "PhysicalValid", physicalValid, ...
                "Regularization", "none", ...
                "Transport", "pointwise predicted real-Jacobian", ...
                "PixelConvention", ...
                "one-based [x,y]=[column,row] pixel centers", ...
                "WorldFrame", "local ENU metres", ...
                "ElevationDatum", "local synthetic ENU Z=0");
        end
    end

    methods (Static, Access = private)
        function selected = selectHeight(cost, z)
            [~, k] = min(cost, [], 2, "omitnan");
            selected = reshape(z(k), [], 1);
            selected(all(isnan(cost), 2)) = NaN;
        end
    end
end
