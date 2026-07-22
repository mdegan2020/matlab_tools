classdef ComplexLogHeightCurve
    %COMPLEXLOGHEIGHTCURVE Branch-free patch diagnostics over height.
    %
    % Moving gradients are transported by the predicted real Jacobian before
    % phase and amplitude residuals are formed. Patch nuisance rotation and
    % log gain are eliminated independently at every height. This curve is a
    % diagnostic, not a primary matching method. Traceability: algo/main.tex
    % Secs. 9.1--9.4; Eqs. (110)--(120), especially (114)--(115).

    properties (SetAccess = private)
        CostCurve
    end

    methods
        function obj = ComplexLogHeightCurve(costCurve)
            arguments
                costCurve (1, 1) HeightCostCurve
            end
            obj.CostCurve = costCurve;
        end

        function result = evaluate(obj, p, z, options)
            arguments
                obj (1, 1) ComplexLogHeightCurve
                p (:, 2) double {mustBeFinite, mustBeNonempty}
                z (1, :) double {mustBeFinite, mustBeNonempty}
                options.DeltaPixel (1, 1) double ...
                    {mustBeFinite, mustBePositive} = 0.5
                options.MinimumSupportFraction (1, 1) double ...
                    {mustBeFinite, mustBeGreaterThanOrEqual( ...
                    options.MinimumSupportFraction, 0), ...
                    mustBeLessThanOrEqual( ...
                    options.MinimumSupportFraction, 1)} = 0.8
                options.MinimumGradient (1, 1) double ...
                    {mustBeFinite, mustBePositive} = 1e-6
                options.GradientEnergyPercentile (1, 1) double ...
                    {mustBeFinite, mustBeGreaterThanOrEqual( ...
                    options.GradientEnergyPercentile, 0), ...
                    mustBeLessThanOrEqual( ...
                    options.GradientEnergyPercentile, 100)} = 10
                options.EpsilonGradient (1, 1) double ...
                    {mustBeFinite, mustBePositive} = 1e-12
                options.AmplitudeWeight (1, 1) double ...
                    {mustBeFinite, mustBeNonnegative} = 1
                options.PhaseWeight (1, 1) double ...
                    {mustBeFinite, mustBeNonnegative} = 1
                options.RequireOrientationPreserving (1, 1) logical = true
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
            kw = double(reference.IntegrationKernel(:).');
            energy = abs(double(reference.G(reference.GradientValid)));
            threshold = max(options.MinimumGradient, ...
                ComplexLogHeightCurve.percentile( ...
                energy, options.GradientEnergyPercentile));
            [gr, vgr] = reference.sampleGradient(pp);
            gr = reshape(double(gr), n, np);
            vgr = reshape(vgr, n, np) & abs(gr) >= threshold;

            cost = nan(n, nl);
            rotation = nan(n, nl);
            rotation2 = nan(n, nl);
            gain = nan(n, nl);
            amplitudeRms = nan(n, nl);
            phaseVariance = nan(n, nl);
            phase2Variance = nan(n, nl);
            support = zeros(n, nl);
            weakFraction = ones(n, nl);
            for k = 1:nl
                [w, vw] = geometry.warp(pp, z(k));
                [gm, vgm] = moving.sampleGradient(w);
                [a, va] = geometry.warpJacobian( ...
                    pp, z(k), DeltaPixel=options.DeltaPixel);
                ht = double(ComplexGradientImage.transport(gm, a));
                detA = a(:, 1, 1) .* a(:, 2, 2) ...
                    - a(:, 1, 2) .* a(:, 2, 1);
                orientationValid = ~options.RequireOrientationPreserving ...
                    | detA > 0;
                ht = reshape(ht, n, np);
                vht = reshape(vgm & vw & va & orientationValid, n, np) ...
                    & abs(ht) >= threshold;
                validSample = vgr & vht;
                ww = double(validSample) .* kw;
                sw = sum(ww, 2);
                support(:, k) = sw;
                weakFraction(:, k) = 1 - sum(validSample, 2) ./ np;
                good = sw >= options.MinimumSupportFraction;
                if ~any(good)
                    continue
                end

                da = zeros(n, np);
                dt = zeros(n, np);
                dt2 = zeros(n, np);
                da(validSample) = log((abs(gr(validSample)) ...
                    + options.EpsilonGradient) ./ ...
                    (abs(ht(validSample)) + options.EpsilonGradient));
                cross = gr(validSample) .* conj(ht(validSample));
                dt(validSample) = atan2(imag(cross), real(cross));
                cross2 = gr(validSample) .^ 2 ...
                    .* conj(ht(validSample) .^ 2);
                dt2(validSample) = atan2(imag(cross2), real(cross2));
                m1 = sum(ww .* exp(1i .* dt), 2);
                m2 = sum(ww .* exp(1i .* dt2), 2);
                alpha = angle(m1);
                alpha2 = 0.5 .* angle(m2);
                beta = sum(ww .* da, 2) ./ sw;
                ar = da - beta;
                pr = 1 - cos(dt - alpha);
                ar(~validSample) = 0;
                pr(~validSample) = 0;
                amp = sqrt(sum(ww .* ar .^ 2, 2) ./ sw);
                phase = 1 - abs(m1) ./ sw;
                phase2 = 1 - abs(m2) ./ sw;
                c = options.AmplitudeWeight .* amp .^ 2 ...
                    + options.PhaseWeight .* sum(ww .* pr, 2) ./ sw;
                cost(good, k) = c(good);
                rotation(good, k) = alpha(good);
                rotation2(good, k) = alpha2(good);
                gain(good, k) = beta(good);
                amplitudeRms(good, k) = amp(good);
                phaseVariance(good, k) = phase(good);
                phase2Variance(good, k) = phase2(good);
            end

            costs = struct("ResidualCost", cost);
            result = struct( ...
                "ReferencePixel", p, "Height", z, ...
                "Costs", costs, ...
                "SelectedHeight", struct("ResidualCost", ...
                ComplexLogHeightCurve.selectHeight(cost, z)), ...
                "Valid", struct("ResidualCost", isfinite(cost)), ...
                "SupportFraction", struct("ResidualCost", support), ...
                "RotationRadians", rotation, ...
                "Spin2RotationRadians", rotation2, ...
                "LogGain", gain, ...
                "AmplitudeResidualRms", amplitudeRms, ...
                "PhaseCircularVariance", phaseVariance, ...
                "Spin2CircularVariance", phase2Variance, ...
                "WeakGradientFraction", weakFraction, ...
                "GradientThreshold", threshold, ...
                "GradientEnergyPercentile", ...
                options.GradientEnergyPercentile, ...
                "Regularization", "none", ...
                "Role", "diagnostic-only", ...
                "Transport", "pointwise predicted real-Jacobian", ...
                "PixelConvention", ...
                "one-based [x,y]=[column,row] pixel centers", ...
                "WorldFrame", "local ENU metres", ...
                "ElevationDatum", "local synthetic ENU Z=0");
        end
    end

    methods (Static, Access = private)
        function z = selectHeight(cost, labels)
            [~, k] = min(cost, [], 2, "omitnan");
            z = reshape(labels(k), [], 1);
            z(all(~isfinite(cost), 2)) = NaN;
        end

        function y = percentile(x, q)
            x = sort(x(isfinite(x)));
            if isempty(x)
                y = NaN;
                return
            end
            k = 1 + (numel(x) - 1) .* q ./ 100;
            lo = floor(k);
            hi = ceil(k);
            y = x(lo) + (k - lo) .* (x(hi) - x(lo));
        end
    end
end
