classdef ComplexGradientImage
    %COMPLEXGRADIENTIMAGE Complex gradients and harmonic descriptors.
    %
    % Gradients use g=Ix+i*Iy, where x is image column and y is image row.
    % Invalid derivative or integration support remains explicit in masks and
    % is represented by NaN in public descriptor arrays.
    %
    % Traceability: algorithm description Secs. 2.2, 3.1-3.3, and 4;
    % Eqs. (3), (10)-(25), and (47); Algorithm 2.

    properties (SetAccess = private)
        Image (:, :)
        InputValid (:, :) logical
        Gx (:, :)
        Gy (:, :)
        G (:, :)
        GradientValid (:, :) logical
        Q2 (:, :)
        Energy (:, :)
        Coherence (:, :)
        DescriptorValid (:, :) logical
        DerivativeSigma (1, 1) double
        IntegrationSigma (1, 1) double
        DerivativeRadius (1, 1) double
        IntegrationRadius (1, 1) double
        IntegrationKernel (:, :)
        Epsilon (1, 1) double
        GradientsPrepared (1, 1) logical
        WorkingPrecision (1, 1) string
    end

    methods
        function obj = ComplexGradientImage(image, options)
            arguments
                image (:, :) ...
                    {mustBeNumeric, mustBeReal, mustBeNonempty}
                options.DerivativeSigma (1, 1) double ...
                    {mustBeFinite, mustBePositive} = 1
                options.IntegrationSigma (1, 1) double ...
                    {mustBeFinite, mustBePositive} = 2
                options.Epsilon (1, 1) double ...
                    {mustBeFinite, mustBePositive} = 1e-12
                options.ValidMask (:, :) logical ...
                    {mustMatchImageSize(options.ValidMask, image)} = ...
                    true(size(image))
                options.PrepareGradients (1, 1) logical = true
                options.WorkingPrecision (1, 1) string ...
                    {mustBeMember(options.WorkingPrecision, ...
                    ["single", "double"])} = "double"
            end

            obj.Image = cast(image, options.WorkingPrecision);
            obj.InputValid = options.ValidMask & isfinite(obj.Image);
            obj.Image(~obj.InputValid) = NaN;
            obj.DerivativeSigma = options.DerivativeSigma;
            obj.IntegrationSigma = options.IntegrationSigma;
            obj.Epsilon = options.Epsilon;
            obj.GradientsPrepared = options.PrepareGradients;
            obj.WorkingPrecision = options.WorkingPrecision;

            [kd, dd, rd] = ComplexGradientImage.derivativeKernels( ...
                options.DerivativeSigma);
            [ki, ri] = ComplexGradientImage.gaussianKernel( ...
                options.IntegrationSigma);
            obj.DerivativeRadius = rd;
            obj.IntegrationRadius = ri;
            kd = cast(kd, "like", obj.Image);
            dd = cast(dd, "like", obj.Image);
            ki = cast(ki, "like", obj.Image);
            obj.IntegrationKernel = ki(:) * ki(:).';

            if ~options.PrepareGradients
                obj.Gx = zeros(0, "like", obj.Image);
                obj.Gy = zeros(0, "like", obj.Image);
                obj.G = complex(zeros(0, "like", obj.Image));
                obj.GradientValid = false(0);
                obj.Q2 = complex(zeros(0, "like", obj.Image));
                obj.Energy = zeros(0, "like", obj.Image);
                obj.Coherence = zeros(0, "like", obj.Image);
                obj.DescriptorValid = false(0);
                return
            end

            finiteInput = obj.InputValid;
            x = obj.Image;
            x(~finiteInput) = 0;
            obj.Gx = conv2(kd(:), dd(:).', x, "same");
            obj.Gy = conv2(dd(:), kd(:).', x, "same");
            obj.G = complex(obj.Gx, obj.Gy);

            supportKernel = ones(2 * rd + 1, "like", obj.Image);
            support = conv2(cast(finiteInput, "like", obj.Image), ...
                supportKernel, "same");
            obj.GradientValid = support == numel(supportKernel);
            obj.G(~obj.GradientValid) = NaN;
            obj.Gx(~obj.GradientValid) = NaN;
            obj.Gy(~obj.GradientValid) = NaN;

            % Eqs. (11)-(12), (19): square, integrate, then normalize.
            g = obj.G;
            g(~obj.GradientValid) = 0;
            kappa = conv2(g .^ 2, obj.IntegrationKernel, "same");
            tau = conv2(abs(g) .^ 2, obj.IntegrationKernel, "same");
            validWeight = conv2(cast(obj.GradientValid, "like", obj.Image), ...
                obj.IntegrationKernel, "same");
            one = cast(1, "like", obj.Image);
            epsilon = cast(options.Epsilon, "like", obj.Image);
            obj.DescriptorValid = validWeight >= one ...
                - cast(64, "like", obj.Image) .* eps(one) ...
                & tau > epsilon;
            obj.Q2 = kappa ./ (tau + epsilon);
            obj.Energy = tau;
            obj.Coherence = abs(obj.Q2);
            obj.Q2(~obj.DescriptorValid) = NaN;
            obj.Energy(~obj.DescriptorValid) = NaN;
            obj.Coherence(~obj.DescriptorValid) = NaN;
        end

        function [v, valid] = sampleIntensity(obj, p)
            %SAMPLEINTENSITY Bilinear sample at one-based [x,y] coordinates.
            % Traceability: Appendix D.2, image gradients and resampling.

            arguments
                obj (1, 1) ComplexGradientImage
                p (:, 2) double {mustBeReal}
            end

            valid = ComplexGradientImage.inside(p, size(obj.Image), 0);
            v = interp2(obj.Image, p(:, 1), p(:, 2), "linear", NaN);
            valid = valid & isfinite(v);
            v(~valid) = NaN;
        end

        function [g, valid] = sampleGradient(obj, p)
            %SAMPLEGRADIENT Bilinear sample of native moving gradients.
            % Traceability: Sec. 5.2, Algorithm 1, line 6.

            arguments
                obj (1, 1) ComplexGradientImage
                p (:, 2) double {mustBeReal}
            end

            if ~obj.GradientsPrepared
                error("ComplexGradientImage:GradientsNotPrepared", ...
                    "Gradient sampling requires PrepareGradients=true.");
            end

            gx = interp2(obj.Gx, p(:, 1), p(:, 2), "linear", NaN);
            gy = interp2(obj.Gy, p(:, 1), p(:, 2), "linear", NaN);
            s = interp2(double(obj.GradientValid), ...
                p(:, 1), p(:, 2), "linear", 0);
            valid = ComplexGradientImage.inside( ...
                p, size(obj.Image), obj.DerivativeRadius) ...
                & s >= 1 - 64 * eps & isfinite(gx) & isfinite(gy);
            g = complex(gx, gy);
            g(~valid) = NaN;
        end

        function [q, valid] = sampleQ2(obj, p)
            %SAMPLEQ2 Bilinear sample of the scalar-warp T0 descriptor.
            % Traceability: Sec. 6.2, transport variant T0.

            arguments
                obj (1, 1) ComplexGradientImage
                p (:, 2) double {mustBeReal}
            end


            if ~obj.GradientsPrepared
                error("ComplexGradientImage:GradientsNotPrepared", ...
                    "Descriptor sampling requires PrepareGradients=true.");
            end

            qr = interp2(real(obj.Q2), p(:, 1), p(:, 2), "linear", NaN);
            qi = interp2(imag(obj.Q2), p(:, 1), p(:, 2), "linear", NaN);
            s = interp2(double(obj.DescriptorValid), ...
                p(:, 1), p(:, 2), "linear", 0);
            margin = obj.DerivativeRadius + obj.IntegrationRadius;
            valid = ComplexGradientImage.inside(p, size(obj.Image), margin) ...
                & s >= 1 - 64 * eps & isfinite(qr) & isfinite(qi);
            q = complex(qr, qi);
            q(~valid) = NaN;
        end

        function [q, c, valid] = harmonics(obj, m, options)
            %HARMONICS Compute q_m for a short vector of harmonic orders.
            % Traceability: Sec. 4, Eq. (47); Algorithm 2.

            arguments
                obj (1, 1) ComplexGradientImage
                m (1, :) double ...
                    {mustBeFinite, mustBeInteger, mustBePositive}
                options.EpsilonGradient (1, 1) double ...
                    {mustBeFinite, mustBePositive} = 1e-6
            end


            if ~obj.GradientsPrepared
                error("ComplexGradientImage:GradientsNotPrepared", ...
                    "Harmonics require PrepareGradients=true.");
            end

            g = obj.G;
            g(~obj.GradientValid) = 0;
            r2 = abs(g) .^ 2;
            u = g ./ sqrt(r2 + options.EpsilonGradient ^ 2);
            eta = r2 .* cast(obj.GradientValid, "like", obj.Image);
            d = conv2(eta, obj.IntegrationKernel, "same") ...
                + cast(obj.Epsilon, "like", obj.Image);
            q = complex(zeros([size(g), numel(m)], "like", obj.Image));
            for k = 1:numel(m)
                q(:, :, k) = conv2(eta .* u .^ m(k), ...
                    obj.IntegrationKernel, "same") ./ d;
            end
            valid = repmat(obj.DescriptorValid, 1, 1, numel(m));
            q(~valid) = NaN;
            c = abs(q);
        end
    end

    methods (Static)
        function [h, hxy] = transport(g, a)
            %TRANSPORT Apply exact real-Jacobian gradient pullback A^T*g.
            % Traceability: Sec. 5.2, Eq. (58); Algorithm 1, line 7.

            arguments
                g (:, 1) double
                a (:, 2, 2) double ...
                    {mustBeReal, mustHaveSameRows(a, g)}
            end

            gx = real(g);
            gy = imag(g);
            hx = a(:, 1, 1) .* gx + a(:, 2, 1) .* gy;
            hy = a(:, 1, 2) .* gx + a(:, 2, 2) .* gy;
            h = complex(hx, hy);
            hxy = [hx, hy];
        end

        function d = harmonicLoss(deltaTheta, m)
            %HARMONICLOSS Angular harmonic penalty.
            % Traceability: Sec. 4, Eq. (48).

            arguments
                deltaTheta double {mustBeReal, mustBeFinite}
                m (1, 1) double ...
                    {mustBeFinite, mustBeInteger, mustBePositive}
            end

            d = (1 - cos(m .* deltaTheta)) ./ 2;
        end
    end

    methods (Static, Access = private)
        function [g, d, radius] = derivativeKernels(sigma)
            radius = ceil(3 * sigma);
            x = -radius:radius;
            g = exp(-(x .^ 2) ./ (2 * sigma ^ 2));
            g = g ./ sum(g);
            d = -(x ./ sigma ^ 2) .* g;
            d = d ./ (-sum(x .* d));
        end

        function [g, radius] = gaussianKernel(sigma)
            radius = ceil(3 * sigma);
            x = -radius:radius;
            g = exp(-(x .^ 2) ./ (2 * sigma ^ 2));
            g = g ./ sum(g);
        end

        function valid = inside(p, imageSize, margin)
            valid = all(isfinite(p), 2) ...
                & p(:, 1) >= 1 + margin ...
                & p(:, 1) <= imageSize(2) - margin ...
                & p(:, 2) >= 1 + margin ...
                & p(:, 2) <= imageSize(1) - margin;
        end
    end
end

function mustHaveSameRows(a, b)
if size(a, 1) ~= size(b, 1)
    error("ComplexGradientImage:RowCountMismatch", ...
        "Gradients and Jacobians must have the same number of rows.");
end
end

function mustMatchImageSize(mask, image)
if ~isequal(size(mask), size(image))
    error("ComplexGradientImage:MaskSizeMismatch", ...
        "ValidMask must have the same size as the image.");
end
end
