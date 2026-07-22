classdef HeightSweepArrayKernels
    %HEIGHTSWEEPARRAYKERNELS Array-only sampling and local-cost kernels.
    %
    % These methods contain no camera, pool, file, or host-transfer calls.
    % Geometry supplies one-based [x,y]=[column,row] coordinates separately.
    % The layout is [row,column,label], and invalid samples remain explicit.
    %
    % Traceability: algo/main.tex Algorithm 1, lines 4--9; Secs. 5.4,
    % 10.1, and 14.6; Eqs. (58), (68)--(69);
    % implementation plan Stages C1, C3, and C6.

    methods (Static)
        function [v, valid] = bilinear(image, p, options)
            %BILINEAR Vectorized one-based bilinear sampling.
            % A neighbor is required exactly when its bilinear weight is
            % nonzero. Thus integer pixel centers, including image edges,
            % agree with interp2(...,"linear",NaN), while fractional samples
            % require every contributing neighbor to be finite and valid.

            arguments
                image (:, :) {mustBeNumeric, mustBeReal, mustBeFloating, ...
                    mustHaveBilinearCell}
                p (:, 2) double {mustBeReal}
                options.ValidMask (:, :) logical ...
                    {mustMatchArraySize(options.ValidMask, image)} = ...
                    true(size(image))
            end

            nr = size(image, 1);
            nc = size(image, 2);
            x = p(:, 1);
            y = p(:, 2);
            inside = isfinite(x) & isfinite(y) ...
                & x >= 1 & x <= nc & y >= 1 & y <= nr;
            x(~inside) = 1;
            y(~inside) = 1;

            x0 = floor(x);
            y0 = floor(y);
            edgeX = x0 == nc;
            edgeY = y0 == nr;
            x0(edgeX) = nc - 1;
            y0(edgeY) = nr - 1;
            tx = x - x0;
            ty = y - y0;
            x1 = x0 + 1;
            y1 = y0 + 1;

            i00 = sub2ind([nr, nc], y0, x0);
            i10 = sub2ind([nr, nc], y0, x1);
            i01 = sub2ind([nr, nc], y1, x0);
            i11 = sub2ind([nr, nc], y1, x1);
            w00 = (1 - tx) .* (1 - ty);
            w10 = tx .* (1 - ty);
            w01 = (1 - tx) .* ty;
            w11 = tx .* ty;
            weights = cast([w00, w10, w01, w11], "like", image);
            index = [i00, i10, i01, i11];
            samples = image(index);
            sampleValid = options.ValidMask(index) & isfinite(samples);
            required = weights > 0;
            valid = inside & all(~required | sampleValid, 2);
            samples(~sampleValid) = 0;
            v = sum(samples .* weights, 2);
            v(~valid) = NaN;
        end

        function [cost, valid, support] = maskedZncc( ...
                reference, moving, sampleValid, kernel, options)
            %MASKEDZNCC Dense masked local moments for Eqs. (68)--(69).
            % Input spatial dimensions include the complete integration halo;
            % valid convolution returns only tile-core centers.

            arguments
                reference (:, :) ...
                    {mustBeNumeric, mustBeReal, mustBeFloating}
                moving (:, :, :) ...
                    {mustBeNumeric, mustBeReal, mustBeFloating, ...
                    mustMatchSpatialSize(moving, reference)}
                sampleValid (:, :, :) logical ...
                    {mustMatchArraySize(sampleValid, moving)}
                kernel (:, :) {mustBeNumeric, mustBeReal, ...
                    mustBeFinite, mustBeNonnegative, ...
                    mustFitSpatialSupport(kernel, reference)}
                options.MinimumSupportFraction (1, 1) double ...
                    {mustBeFinite, ...
                    mustBeGreaterThanOrEqual( ...
                    options.MinimumSupportFraction, 0), ...
                    mustBeLessThanOrEqual( ...
                    options.MinimumSupportFraction, 1)} = 0.8
                options.Epsilon (1, 1) double ...
                    {mustBeFinite, mustBePositive} = 1e-12
            end

            k = cast(kernel, "like", moving);
            k = reshape(k, size(k, 1), size(k, 2), 1);
            v = cast(sampleValid, "like", moving);
            r = cast(reference, "like", moving);
            r(~isfinite(r)) = 0;
            m = moving;
            m(~isfinite(m)) = 0;

            support = convn(v, k, "valid");
            sr = convn(v .* r, k, "valid");
            sm = convn(v .* m, k, "valid");
            srr = convn(v .* r .^ 2, k, "valid");
            smm = convn(v .* m .^ 2, k, "valid");
            srm = convn(v .* r .* m, k, "valid");
            numerator = srm - sr .* sm ./ support;
            varianceReference = srr - sr .^ 2 ./ support;
            varianceMoving = smm - sm .^ 2 ./ support;
            epsilon = cast(options.Epsilon, "like", moving);
            minimumSupport = cast( ...
                options.MinimumSupportFraction, "like", moving);
            valid = support >= minimumSupport ...
                & varianceReference > epsilon & varianceMoving > epsilon;
            correlation = numerator ./ sqrt( ...
                varianceReference .* varianceMoving + epsilon);
            cost = (cast(1, "like", moving) - correlation) ./ 2;
            cost(~valid) = NaN;
        end

        function h = transportGradient(gx, gy, a)
            %TRANSPORTGRADIENT Apply A^T to vectorized native gradients.
            % Traceability: algo/main.tex Eq. (58), Algorithm 1 line 7;
            % implementation plan Stage C6.

            arguments
                gx (:, 1) {mustBeNumeric, mustBeReal, mustBeFloating}
                gy (:, 1) {mustBeNumeric, mustBeReal, mustBeFloating, ...
                    mustMatchArraySize(gy, gx)}
                a (:, 2, 2) {mustBeNumeric, mustBeReal, ...
                    mustMatchRows(a, gx)}
            end

            a11 = cast(a(:, 1, 1), "like", gx);
            a12 = cast(a(:, 1, 2), "like", gx);
            a21 = cast(a(:, 2, 1), "like", gx);
            a22 = cast(a(:, 2, 2), "like", gx);
            hx = a11 .* gx + a21 .* gy;
            hy = a12 .* gx + a22 .* gy;
            h = complex(hx, hy);
        end

        function [cost, confidence, valid, support] = spin2T3( ...
                reference, referenceValid, moving, movingValid, ...
                kernel, options)
            %SPIN2T3 Dense exact-transport spin-2 descriptor cost.
            % Inputs include the full integration halo; valid convolution
            % returns tile-core centers. Traceability: Eqs. (22), (25),
            % and (58); implementation plan Stage C6.

            arguments
                reference (:, :) {mustBeNumeric, mustBeFloating}
                referenceValid (:, :) logical ...
                    {mustMatchArraySize(referenceValid, reference)}
                moving (:, :, :) {mustBeNumeric, mustBeFloating, ...
                    mustMatchSpatialSize(moving, reference)}
                movingValid (:, :, :) logical ...
                    {mustMatchArraySize(movingValid, moving)}
                kernel (:, :) {mustBeNumeric, mustBeReal, ...
                    mustBeFinite, mustBeNonnegative, ...
                    mustFitSpatialSupport(kernel, reference)}
                options.MinimumSupportFraction (1, 1) double ...
                    {mustBeFinite, ...
                    mustBeGreaterThanOrEqual( ...
                    options.MinimumSupportFraction, 0), ...
                    mustBeLessThanOrEqual( ...
                    options.MinimumSupportFraction, 1)} = 0.8
                options.Epsilon (1, 1) double ...
                    {mustBeFinite, mustBePositive} = 1e-12
            end

            k = cast(kernel, "like", moving);
            k = reshape(k, size(k, 1), size(k, 2), 1);
            vr = cast(referenceValid, "like", moving);
            vm = cast(movingValid, "like", moving);
            r = cast(reference, "like", moving);
            r(~referenceValid) = 0;
            m = moving;
            m(~movingValid) = 0;
            supportReference = convn(vr, k, "valid");
            numeratorReference = convn(vr .* r .^ 2, k, "valid");
            energyReference = convn(vr .* abs(r) .^ 2, k, "valid");
            support = convn(vm, k, "valid");
            numeratorMoving = convn(vm .* m .^ 2, k, "valid");
            energyMoving = convn(vm .* abs(m) .^ 2, k, "valid");
            epsilon = cast(options.Epsilon, "like", moving);
            minimumSupport = cast( ...
                options.MinimumSupportFraction, "like", moving);
            validReference = supportReference >= minimumSupport ...
                & energyReference > epsilon;
            validMoving = support >= minimumSupport ...
                & energyMoving > epsilon;
            qr = numeratorReference ./ (energyReference + epsilon);
            qm = numeratorMoving ./ (energyMoving + epsilon);
            sr = qr ./ (abs(qr) + epsilon);
            sm = qm ./ (abs(qm) + epsilon);
            cost = (cast(1, "like", moving) ...
                - real(sr .* conj(sm))) ./ cast(2, "like", moving);
            confidence = sqrt(abs(qr) .* abs(qm));
            valid = validReference & validMoving ...
                & isfinite(cost) & isfinite(confidence);
            cost(~valid) = NaN;
            confidence(~valid) = NaN;
        end
    end
end

function mustHaveBilinearCell(image)
if any(size(image) < 2)
    error("HeightSweepArrayKernels:ImageTooSmall", ...
        "Bilinear sampling requires at least two rows and two columns.");
end
end

function mustBeFloating(a)
if ~isfloat(a)
    error("HeightSweepArrayKernels:FloatingPointRequired", ...
        "Array kernels require single- or double-precision inputs.");
end
end

function mustMatchArraySize(a, b)
if ~isequal(size(a), size(b))
    error("HeightSweepArrayKernels:SizeMismatch", ...
        "Array sizes must match exactly.");
end
end

function mustMatchSpatialSize(a, b)
if ~isequal(size(a, 1), size(b, 1)) ...
        || ~isequal(size(a, 2), size(b, 2))
    error("HeightSweepArrayKernels:SpatialSizeMismatch", ...
        "The first two array dimensions must match.");
end
end

function mustFitSpatialSupport(kernel, image)
if any(size(kernel) > size(image))
    error("HeightSweepArrayKernels:KernelTooLarge", ...
        "The local kernel must fit within the spatial input dimensions.");
end
end

function mustMatchRows(a, b)
if size(a, 1) ~= size(b, 1)
    error("HeightSweepArrayKernels:RowCountMismatch", ...
        "Gradient and Jacobian row counts must match.");
end
end
