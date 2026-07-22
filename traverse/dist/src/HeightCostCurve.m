classdef HeightCostCurve
    %HEIGHTCOSTCURVE Sparse unregularized costs over candidate elevations.
    %
    % Patch samples are warped individually at a common height. The T3
    % channel samples native moving gradients, applies the local A^T at every
    % sample, then squares and integrates. The loop is only over height labels;
    % points and patch samples are vectorized.
    %
    % Traceability: algorithm description Secs. 3.3, 5.4-5.5, 6.2-6.3,
    % and 10.1; Eqs. (22), (25), (68)-(69), and (79)-(84); Algorithm 1,
    % lines 3-12. Census and normalized-gradient costs are the named
    % baselines in Sec. 10.1 ("Baseline methods").

    properties (SetAccess = private)
        Geometry
        Reference
        Moving
    end

    methods
        function obj = HeightCostCurve(geometry, referenceImage, ...
                movingImage, options)
            arguments
                geometry (1, 1) HeightSweepGeometry
                referenceImage (:, :) ...
                    {mustBeNumeric, mustBeReal, mustBeNonempty, ...
                    mustMatchReferenceImageSize(referenceImage, geometry)}
                movingImage (:, :) ...
                    {mustBeNumeric, mustBeReal, mustBeNonempty, ...
                    mustMatchMovingImageSize(movingImage, geometry)}
                options.DerivativeSigma (1, 1) double ...
                    {mustBeFinite, mustBePositive} = 1
                options.IntegrationSigma (1, 1) double ...
                    {mustBeFinite, mustBePositive} = 2
                options.Epsilon (1, 1) double ...
                    {mustBeFinite, mustBePositive} = 1e-12
                options.ReferenceValid (:, :) logical ...
                    {mustMatchMaskSize(options.ReferenceValid, ...
                    referenceImage)} = true(size(referenceImage))
                options.MovingValid (:, :) logical ...
                    {mustMatchMaskSize(options.MovingValid, ...
                    movingImage)} = true(size(movingImage))
                options.PrepareGradients (1, 1) logical = true
                options.WorkingPrecision (1, 1) string ...
                    {mustBeMember(options.WorkingPrecision, ...
                    ["single", "double"])} = "double"
            end

            obj.Geometry = geometry;
            obj.Reference = ComplexGradientImage(referenceImage, ...
                DerivativeSigma=options.DerivativeSigma, ...
                IntegrationSigma=options.IntegrationSigma, ...
                Epsilon=options.Epsilon, ...
                ValidMask=options.ReferenceValid, ...
                PrepareGradients=options.PrepareGradients, ...
                WorkingPrecision=options.WorkingPrecision);
            obj.Moving = ComplexGradientImage(movingImage, ...
                DerivativeSigma=options.DerivativeSigma, ...
                IntegrationSigma=options.IntegrationSigma, ...
                Epsilon=options.Epsilon, ...
                ValidMask=options.MovingValid, ...
                PrepareGradients=options.PrepareGradients, ...
                WorkingPrecision=options.WorkingPrecision);
        end

        function result = evaluate(obj, p, z, options)
            %EVALUATE Compute independent cost channels at N reference pixels.

            arguments
                obj (1, 1) HeightCostCurve
                p (:, 2) double {mustBeFinite, mustBeNonempty}
                z (1, :) double {mustBeFinite, mustBeNonempty}
                options.DeltaPixel (1, 1) double ...
                    {mustBeFinite, mustBePositive} = 0.5
                options.DeltaHeight (1, 1) double ...
                    {mustBeFinite, mustBePositive} = 0.5
                options.SurfaceSlope (:, 2) double ...
                    {mustBeFinite, ...
                    mustHaveOneOrNRows(options.SurfaceSlope, p)} = zeros(1, 2)
                options.MinimumSupportFraction (1, 1) double ...
                    {mustBeFinite, ...
                    mustBeGreaterThanOrEqual( ...
                    options.MinimumSupportFraction, 0), ...
                    mustBeLessThanOrEqual( ...
                    options.MinimumSupportFraction, 1)} = 0.8
                options.MinimumGradient (1, 1) double ...
                    {mustBeFinite, mustBeNonnegative} = 1e-6
                options.RequireOrientationPreserving (1, 1) logical = true
                options.HybridZnccWeight (1, 1) double ...
                    {mustBeFinite, mustBePositive} = 1
                options.HybridSpin2Weight (1, 1) double ...
                    {mustBeFinite, mustBePositive} = 1
                options.HybridZnccScale (1, 1) double ...
                    {mustBeFinite, mustBePositive} = 1
                options.HybridSpin2Scale (1, 1) double ...
                    {mustBeFinite, mustBePositive} = 1
                options.HybridClip (1, 1) double ...
                    {mustBeFinite, mustBePositive} = 1
                options.ProfileOperations (1, 1) logical = false
                options.Channels (1, :) string ...
                    {mustBeNonempty, mustBeMember(options.Channels, ...
                    ["Zncc", "Census", "NormalizedGradient", ...
                    "PointSpin2", "Spin2T0", "Spin2T1", "Spin2T2", ...
                    "Spin2T3", "Spin2T4", ...
                    "HybridZnccSpin2T3"])} = ...
                    ["Zncc", "Census", "NormalizedGradient", ...
                    "PointSpin2", "Spin2T0", "Spin2T1", "Spin2T2", ...
                    "Spin2T3", "Spin2T4", "HybridZnccSpin2T3"]
            end

            totalTimer = tic;
            operationSeconds = zeros(1, 5);
            if options.ProfileOperations
                operationTimer = tic;
            end
            [ox, oy] = meshgrid( ...
                -obj.Reference.IntegrationRadius: ...
                obj.Reference.IntegrationRadius);
            off = [ox(:), oy(:)];
            n = size(p, 1);
            np = size(off, 1);
            nl = numel(z);
            requested = unique(options.Channels, "stable");
            emitZncc = any(requested == "Zncc");
            emitCensus = any(requested == "Census");
            emitNgf = any(requested == "NormalizedGradient");
            emitPoint = any(requested == "PointSpin2");
            emitT0 = any(requested == "Spin2T0");
            emitT1 = any(requested == "Spin2T1");
            emitT2 = any(requested == "Spin2T2");
            emitT3 = any(requested == "Spin2T3");
            emitT4 = any(requested == "Spin2T4");
            emitHybrid = any(requested == "HybridZnccSpin2T3");
            needZncc = emitZncc || emitHybrid;
            needT3 = emitT3 || emitHybrid;
            needIntensity = needZncc || emitCensus;
            needTransportedGradient = emitNgf || emitPoint || needT3;
            needPatchGradient = needTransportedGradient || emitT4;
            needCenterSpin = emitT0 || emitT1 || emitT2;
            needPatchWarp = needIntensity || needTransportedGradient ...
                || needCenterSpin;
            needPatchJacobian = needTransportedGradient || emitT1 || emitT2;
            if (needPatchGradient || needCenterSpin) ...
                    && (~obj.Reference.GradientsPrepared ...
                    || ~obj.Moving.GradientsPrepared)
                error("HeightCostCurve:GradientsNotPrepared", ...
                    "The requested channel requires gradient/descriptor " ...
                    + "preparation. Construct HeightCostCurve with " ...
                    + "PrepareGradients=true.");
            end
            pp = reshape(p, n, 1, 2) + reshape(off, 1, np, 2);
            pp = reshape(pp, n * np, 2);
            operationCountNames = ["ReferenceBilinearLocations", ...
                "MovingBilinearLocations", "WarpCalls", ...
                "WarpPointEvaluations", "WarpJacobianCalls", ...
                "WarpJacobianPointEvaluations", ...
                "HeightDerivativeCalls", ...
                "HeightDerivativePointEvaluations", ...
                "CandidatePatchLocations"];
            operationCounts = [ ...
                n .* np .* (double(needIntensity) ...
                + double(needPatchGradient)) ...
                + n .* double(needCenterSpin), ...
                n .* np .* nl .* (double(needIntensity) ...
                + double(needTransportedGradient) + double(emitT4)) ...
                + n .* nl .* double(needCenterSpin), ...
                nl .* (double(needPatchWarp) + double(emitT4)), ...
                n .* np .* nl .* (double(needPatchWarp) ...
                + double(emitT4)), ...
                nl .* (double(needPatchJacobian) + double(emitT4)), ...
                n .* np .* nl .* (double(needPatchJacobian) ...
                + double(emitT4)), ...
                nl .* double(emitT4), ...
                n .* np .* nl .* double(emitT4), ...
                n .* np .* nl];
            kw = obj.Reference.IntegrationKernel(:).';
            slope = options.SurfaceSlope;
            if size(slope, 1) == 1
                slope = repmat(slope, n, 1);
            end
            slopePatch = zeros(0, 2);
            dzPatch = zeros(0, 1);
            if emitT4
                slopePatch = repmat(slope, np, 1);
                dzPatch = slope(:, 1) .* off(:, 1).' ...
                    + slope(:, 2) .* off(:, 2).';
                dzPatch = reshape(dzPatch, n * np, 1);
            end

            ir = zeros(n, 0);
            vir = false(n, 0);
            if needIntensity
                [ir, vir] = obj.Reference.sampleIntensity(pp);
                ir = reshape(ir, n, np);
                vir = reshape(vir, n, np);
            end
            gr = zeros(n, 0);
            vgr = false(n, 0);
            if needPatchGradient
                [gr, vgr] = obj.Reference.sampleGradient(pp);
                gr = reshape(gr, n, np);
                vgr = reshape(vgr, n, np) ...
                    & abs(gr) >= options.MinimumGradient;
            end
            qrPatch = zeros(n, 0);
            crPatch = zeros(n, 0);
            vqrPatch = false(n, 0);
            if needT3 || emitT4
                [qrPatch, crPatch, vqrPatch, ~] = ...
                    HeightCostCurve.spin2Descriptor( ...
                    gr, vgr, kw, options.MinimumSupportFraction, ...
                    obj.Reference.Epsilon);
            end
            qr0 = zeros(n, 0);
            vqr0 = false(n, 0);
            if needCenterSpin
                [qr0, vqr0] = obj.Reference.sampleQ2(p);
            end
            if options.ProfileOperations
                operationSeconds(1) = toc(operationTimer);
            end

            zncc = nan(n, double(needZncc) .* nl);
            census = nan(n, double(emitCensus) .* nl);
            ngf = nan(n, double(emitNgf) .* nl);
            point2 = nan(n, double(emitPoint) .* nl);
            t0 = nan(n, double(emitT0) .* nl);
            t1 = nan(n, double(emitT1) .* nl);
            t2 = nan(n, double(emitT2) .* nl);
            t3 = nan(n, double(needT3) .* nl);
            t4 = nan(n, double(emitT4) .* nl);
            t0c = nan(n, double(emitT0) .* nl);
            t1c = nan(n, double(emitT1) .* nl);
            t2c = nan(n, double(emitT2) .* nl);
            t3c = nan(n, double(needT3) .* nl);
            t4c = nan(n, double(emitT4) .* nl);
            supportI = zeros(n, double(needZncc) .* nl);
            supportC = zeros(n, double(emitCensus) .* nl);
            supportN = zeros(n, double(emitNgf) .* nl);
            supportP = zeros(n, double(emitPoint) .* nl);
            supportT3 = zeros(n, double(needT3) .* nl);
            supportT4 = zeros(n, double(emitT4) .* nl);

            for k = 1:nl
                w = zeros(0, 2);
                vw = false(0, 1);
                im = zeros(0, 1);
                vim = false(0, 1);
                gm = complex(zeros(0, 1));
                vgm = false(0, 1);
                if options.ProfileOperations && needPatchWarp
                    operationTimer = tic;
                end
                if needPatchWarp
                    [w, vw] = obj.Geometry.warp(pp, z(k));
                    if needIntensity
                        [im, vim] = obj.Moving.sampleIntensity(w);
                    end
                    if needTransportedGradient
                        [gm, vgm] = obj.Moving.sampleGradient(w);
                    end
                end
                if options.ProfileOperations && needPatchWarp
                    operationSeconds(2) = operationSeconds(2) ...
                        + toc(operationTimer);
                end

                a = zeros(0, 2, 2);
                va = false(0, 1);
                orientationValid = false(0, 1);
                ht = complex(zeros(0, 1));
                if options.ProfileOperations && needPatchJacobian
                    operationTimer = tic;
                end
                if needPatchJacobian
                    [a, va] = obj.Geometry.warpJacobian( ...
                        pp, z(k), DeltaPixel=options.DeltaPixel);
                    detA = a(:, 1, 1) .* a(:, 2, 2) ...
                        - a(:, 1, 2) .* a(:, 2, 1);
                    orientationValid = ...
                        ~options.RequireOrientationPreserving | detA > 0;
                    if needTransportedGradient
                        ht = ComplexGradientImage.transport(gm, a);
                    end
                end
                if options.ProfileOperations && needPatchJacobian
                    operationSeconds(3) = operationSeconds(3) ...
                        + toc(operationTimer);
                end

                if options.ProfileOperations ...
                        && (needIntensity || needTransportedGradient ...
                        || needCenterSpin)
                    operationTimer = tic;
                end

                if needIntensity
                    im = reshape(im, n, np);
                    vim = reshape(vim & vw, n, np);
                end
                vht = false(n, 0);
                if needTransportedGradient
                    ht = reshape(ht, n, np);
                    vht = reshape( ...
                        vgm & vw & va & orientationValid, n, np) ...
                        & abs(ht) >= options.MinimumGradient;
                end
                if needZncc
                    [zncc(:, k), ~, supportI(:, k)] = ...
                        HeightCostCurve.znccCost( ...
                        ir, im, vir & vim, kw, ...
                        options.MinimumSupportFraction, ...
                        obj.Reference.Epsilon);
                end
                if emitCensus
                    [census(:, k), supportC(:, k)] = ...
                        HeightCostCurve.censusCost( ...
                        ir, im, vir & vim, kw, ...
                        options.MinimumSupportFraction);
                end
                if emitNgf
                    [ngf(:, k), supportN(:, k)] = ...
                        HeightCostCurve.pointNgfCost( ...
                        gr, ht, vgr & vht, kw, ...
                        options.MinimumSupportFraction, ...
                        obj.Reference.Epsilon);
                end
                if emitPoint
                    [point2(:, k), supportP(:, k)] = ...
                        HeightCostCurve.pointSpin2Cost( ...
                        gr, ht, vgr & vht, kw, ...
                        options.MinimumSupportFraction, ...
                        obj.Reference.Epsilon);
                end
                if needT3
                    [qm, cm, vqm, supportT3(:, k)] = ...
                        HeightCostCurve.spin2Descriptor( ...
                        ht, vht, kw, options.MinimumSupportFraction, ...
                        obj.Reference.Epsilon);
                    [t3(:, k), t3c(:, k)] = HeightCostCurve.phaseCost( ...
                        qrPatch, qm, vqrPatch & vqm, crPatch, cm, ...
                        obj.Reference.Epsilon);
                end

                if needCenterSpin
                    wc = reshape(w, n, np, 2);
                    wc = reshape(wc(:, ceil(np / 2), :), n, 2);
                    [qm0, vqm0] = obj.Moving.sampleQ2(wc);
                    if emitT0
                        [t0(:, k), t0c(:, k)] = ...
                            HeightCostCurve.phaseCost( ...
                            qr0, qm0, vqr0 & vqm0, ...
                            abs(qr0), abs(qm0), obj.Reference.Epsilon);
                    end
                    if emitT1 || emitT2
                        ac = reshape(a, n, np, 2, 2);
                        ac = reshape( ...
                            ac(:, ceil(np / 2), :, :), n, 2, 2);
                        vac = reshape(va & orientationValid, n, np);
                        vac = vac(:, ceil(np / 2));
                    end
                    if emitT1
                        alpha = atan2( ...
                            ac(:, 2, 1) - ac(:, 1, 2), ...
                            ac(:, 1, 1) + ac(:, 2, 2));
                        r1 = exp(-2i .* alpha);
                        [t1(:, k), t1c(:, k)] = ...
                            HeightCostCurve.phaseCost( ...
                            qr0, qm0 .* r1, vqr0 & vqm0 & vac, ...
                            abs(qr0), abs(qm0), obj.Reference.Epsilon);
                    end
                    if emitT2
                        [fz, ~, ~, ~, ~, vf] = ...
                            HeightSweepGeometry.toWirtinger(ac);
                        rphi = conj(fz) ...
                            ./ (abs(fz) + obj.Reference.Epsilon);
                        [t2(:, k), t2c(:, k)] = ...
                            HeightCostCurve.phaseCost( ...
                            qr0, qm0 .* rphi .^ 2, ...
                            vqr0 & vqm0 & vac & vf, ...
                            abs(qr0), abs(qm0), obj.Reference.Epsilon);
                    end
                end
                if options.ProfileOperations ...
                        && (needIntensity || needTransportedGradient ...
                        || needCenterSpin)
                    operationSeconds(4) = operationSeconds(4) ...
                        + toc(operationTimer);
                end

                % Sec. 6.2 T4: sample the sloped patch and use Eq. (63).
                if emitT4
                    if options.ProfileOperations
                        operationTimer = tic;
                    end
                    z4 = z(k) + dzPatch;
                    [w4, vw4] = obj.Geometry.warp(pp, z4);
                    [gm4, vgm4] = obj.Moving.sampleGradient(w4);
                    [a4, va4] = obj.Geometry.warpJacobian( ...
                        pp, z4, DeltaPixel=options.DeltaPixel);
                    [tz, ~, vtz] = obj.Geometry.heightDerivative( ...
                        pp, z4, DeltaHeight=options.DeltaHeight);
                    as = HeightSweepGeometry.surfaceJacobian( ...
                        a4, tz, slopePatch);
                    ht4 = ComplexGradientImage.transport(gm4, as);
                    detAs = as(:, 1, 1) .* as(:, 2, 2) ...
                        - as(:, 1, 2) .* as(:, 2, 1);
                    vo4 = ~options.RequireOrientationPreserving | detAs > 0;
                    ht4 = reshape(ht4, n, np);
                    vht4 = reshape( ...
                        vgm4 & vw4 & va4 & vtz & vo4, n, np) ...
                        & abs(ht4) >= options.MinimumGradient;
                    [qm4, cm4, vqm4, supportT4(:, k)] = ...
                        HeightCostCurve.spin2Descriptor( ...
                        ht4, vht4, kw, options.MinimumSupportFraction, ...
                        obj.Reference.Epsilon);
                    [t4(:, k), t4c(:, k)] = ...
                        HeightCostCurve.phaseCost( ...
                        qrPatch, qm4, vqrPatch & vqm4, crPatch, cm4, ...
                        obj.Reference.Epsilon);
                    if options.ProfileOperations
                        operationSeconds(5) = operationSeconds(5) ...
                            + toc(operationTimer);
                    end
                end
            end

            % Eq. (67) fixed-scale development control and Eq. (133)
            % confidence factor. Validation-set scale fitting remains deferred.
            hybrid = nan(n, 0);
            if emitHybrid
                zc = min( ...
                    zncc ./ options.HybridZnccScale, options.HybridClip);
                sc = min(t3 ./ options.HybridSpin2Scale, ...
                    options.HybridClip);
                hybrid = options.HybridZnccWeight .* zc ...
                    + options.HybridSpin2Weight .* t3c .* sc;
                hybrid(~isfinite(zncc) | ~isfinite(t3) ...
                    | ~isfinite(t3c)) = NaN;
            end

            costs = struct;
            supportFraction = struct;
            for channelIndex = 1:numel(requested)
                name = char(requested(channelIndex));
                switch requested(channelIndex)
                    case "Zncc"
                        costs.(name) = zncc;
                        supportFraction.(name) = supportI;
                    case "Census"
                        costs.(name) = census;
                        supportFraction.(name) = supportC;
                    case "NormalizedGradient"
                        costs.(name) = ngf;
                        supportFraction.(name) = supportN;
                    case "PointSpin2"
                        costs.(name) = point2;
                        supportFraction.(name) = supportP;
                    case "Spin2T0"
                        costs.(name) = t0;
                    case "Spin2T1"
                        costs.(name) = t1;
                    case "Spin2T2"
                        costs.(name) = t2;
                    case "Spin2T3"
                        costs.(name) = t3;
                        supportFraction.(name) = supportT3;
                    case "Spin2T4"
                        costs.(name) = t4;
                        supportFraction.(name) = supportT4;
                    case "HybridZnccSpin2T3"
                        costs.(name) = hybrid;
                        supportFraction.(name) = min(supportI, supportT3);
                end
            end
            selected = struct;
            valid = struct;
            names = fieldnames(costs);
            for channelIndex = 1:numel(names)
                selected.(names{channelIndex}) = ...
                    HeightCostCurve.selectHeight( ...
                    costs.(names{channelIndex}), z);
                valid.(names{channelIndex}) = ...
                    isfinite(costs.(names{channelIndex}));
            end
            result = struct( ...
                "ReferencePixel", p, ...
                "Height", z, ...
                "ComputedChannels", requested, ...
                "Costs", costs, ...
                "SelectedHeight", selected, ...
                "Valid", valid, ...
                "SupportFraction", supportFraction, ...
                "Spin2T0Confidence", t0c, ...
                "Spin2T1Confidence", t1c, ...
                "Spin2T2Confidence", t2c, ...
                "Spin2T3Confidence", t3c, ...
                "Spin2T4Confidence", t4c, ...
                "SurfaceSlopeMetresPerPixel", slope, ...
                "Profiling", struct( ...
                "Enabled", options.ProfileOperations, ...
                "OperationNames", ["ReferencePreparation", ...
                "WarpAndMovingSampling", "JacobianAndTransport", ...
                "PatchCostsT0ThroughT3", "SlopeAwareT4"], ...
                "OperationSeconds", operationSeconds, ...
                "OperationCountNames", operationCountNames, ...
                "OperationCounts", operationCounts, ...
                "TotalSeconds", toc(totalTimer), ...
                "Definition", ...
                "elapsed wall time within one evaluate call"), ...
                "HybridDefinition", struct( ...
                "Equation", 67, ...
                "RecommendedBaselineEquation", 133, ...
                "ZnccWeight", options.HybridZnccWeight, ...
                "Spin2Weight", options.HybridSpin2Weight, ...
                "ZnccScale", options.HybridZnccScale, ...
                "Spin2Scale", options.HybridSpin2Scale, ...
                "Clip", options.HybridClip, ...
                "UsesSpin2Confidence", true));
        end
    end

    methods (Static, Access = private)
        function [q, c, valid, support] = spin2Descriptor( ...
                g, validSample, kw, minSupport, epsilon)
            w = validSample .* kw;
            support = sum(w, 2);
            gg = g;
            gg(~validSample) = 0;
            num = sum(w .* gg .^ 2, 2);
            den = sum(w .* abs(gg) .^ 2, 2);
            valid = support >= minSupport & den > epsilon;
            q = num ./ (den + epsilon);
            q(~valid) = NaN;
            c = abs(q);
        end

        function [cost, confidence] = phaseCost( ...
                qr, qm, valid, cr, cm, epsilon)
            % Angular residual from Eq. (25); confidence is returned separately.
            sr = qr ./ (abs(qr) + epsilon);
            sm = qm ./ (abs(qm) + epsilon);
            cost = (1 - real(sr .* conj(sm))) ./ 2;
            confidence = sqrt(cr .* cm);
            valid = valid & isfinite(cost) & isfinite(confidence);
            cost(~valid) = NaN;
            confidence(~valid) = NaN;
        end

        function [cost, support] = pointSpin2Cost( ...
                gr, gm, validSample, kw, minSupport, epsilon)
            ur = gr ./ sqrt(abs(gr) .^ 2 + epsilon ^ 2);
            um = gm ./ sqrt(abs(gm) .^ 2 + epsilon ^ 2);
            d = (1 - real(ur .^ 2 .* conj(um .^ 2))) ./ 2;
            w = validSample .* kw;
            support = sum(w, 2);
            d(~validSample) = 0;
            cost = sum(w .* d, 2) ./ support;
            cost(support < minSupport) = NaN;
        end

        function [cost, support] = pointNgfCost( ...
                gr, gm, validSample, kw, minSupport, epsilon)
            % Sec. 10.1 normalized-gradient dot-product/NGF baseline.
            ur = gr ./ sqrt(abs(gr) .^ 2 + epsilon ^ 2);
            um = gm ./ sqrt(abs(gm) .^ 2 + epsilon ^ 2);
            d = (1 - real(ur .* conj(um))) ./ 2;
            w = validSample .* kw;
            support = sum(w, 2);
            d(~validSample) = 0;
            cost = sum(w .* d, 2) ./ support;
            cost(support < minSupport) = NaN;
        end

        function [cost, support] = censusCost( ...
                r, m, validSample, kw, minSupport)
            % Sec. 10.1 Census baseline: weighted center comparisons.
            nc = ceil(size(r, 2) / 2);
            kc = kw;
            kc(nc) = 0;
            kc = kc ./ sum(kc);
            validSample = validSample & validSample(:, nc);
            validSample(:, nc) = false;
            br = r > r(:, nc);
            bm = m > m(:, nc);
            d = xor(br, bm);
            w = validSample .* kc;
            support = sum(w, 2);
            d(~validSample) = 0;
            cost = sum(w .* d, 2) ./ support;
            cost(support < minSupport) = NaN;
        end

        function [cost, valid, support] = znccCost( ...
                r, m, validSample, kw, minSupport, epsilon)
            w = validSample .* kw;
            support = sum(w, 2);
            rr = r;
            mm = m;
            rr(~validSample) = 0;
            mm(~validSample) = 0;
            mr = sum(w .* rr, 2) ./ support;
            mmu = sum(w .* mm, 2) ./ support;
            dr = (rr - mr) .* validSample;
            dm = (mm - mmu) .* validSample;
            num = sum(w .* dr .* dm, 2);
            vr = sum(w .* dr .^ 2, 2);
            vm = sum(w .* dm .^ 2, 2);
            valid = support >= minSupport & vr > epsilon & vm > epsilon;
            corr = num ./ sqrt(vr .* vm + epsilon);
            cost = (1 - corr) ./ 2;
            cost(~valid) = NaN;
        end

        function selected = selectHeight(cost, z)
            [~, k] = min(cost, [], 2, "omitnan");
            selected = reshape(z(k), [], 1);
            selected(all(isnan(cost), 2)) = NaN;
        end
    end
end

function mustMatchReferenceImageSize(image, geometry)
if ~isequal(size(image), geometry.ReferenceCamera.ImageSize)
    error("HeightCostCurve:ImageSizeMismatch", ...
        "Reference image size must match its camera ImageSize.");
end
end

function mustMatchMovingImageSize(image, geometry)
if ~isequal(size(image), geometry.MovingCamera.ImageSize)
    error("HeightCostCurve:ImageSizeMismatch", ...
        "Moving image size must match its camera ImageSize.");
end
end

function mustHaveOneOrNRows(a, p)
if ~(size(a, 1) == 1 || size(a, 1) == size(p, 1))
    error("HeightCostCurve:RowCountMismatch", ...
        "SurfaceSlope must have one row or one row per reference point.");
end
end

function mustMatchMaskSize(mask, image)
if ~isequal(size(mask), size(image))
    error("HeightCostCurve:MaskSizeMismatch", ...
        "Each validity mask must have the same size as its image.");
end
end
