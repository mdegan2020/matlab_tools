classdef SyntheticRadiometry
    %SYNTHETICRADIOMETRY Deterministic quantized moving-image controls.
    %
    % Every operation begins and ends at the configured 10- or 12-bit
    % precision stored in uint16. Traceability: algo/main.tex Sec. 10.2,
    % radiometry factors in the synthetic geometry suite.

    methods (Static)
        function output = apply(image, bitDepth, kind, options)
            arguments
                image (:, :) uint16 {mustBeNonempty}
                bitDepth (1, 1) double {mustBeMember(bitDepth, [10, 12])}
                kind (1, 1) string {mustBeMember(kind, ...
                    ["identity", "gain-offset", "gamma", "blur", ...
                    "noise", "polarity", "shadow"])}
                options.Gain (1, 1) double ...
                    {mustBeFinite, mustBeNonnegative} = 0.8
                options.Offset (1, 1) double {mustBeFinite} = 0.1
                options.Gamma (1, 1) double ...
                    {mustBeFinite, mustBePositive} = 1.4
                options.BlurSigmaPixels (1, 1) double ...
                    {mustBeFinite, mustBeNonnegative} = 0.8
                options.NoiseSigma (1, 1) double ...
                    {mustBeFinite, mustBeNonnegative} = 0.02
                options.Seed (1, 1) double ...
                    {mustBeFinite, mustBeInteger, mustBeNonnegative} = 1
                options.ShadowAttenuation (1, 1) double ...
                    {mustBeFinite, mustBeGreaterThanOrEqual( ...
                    options.ShadowAttenuation, 0), ...
                    mustBeLessThanOrEqual( ...
                    options.ShadowAttenuation, 1)} = 0.45
                options.ShadowBoundaryFraction (1, 1) double ...
                    {mustBeFinite, mustBeGreaterThanOrEqual( ...
                    options.ShadowBoundaryFraction, 0), ...
                    mustBeLessThanOrEqual( ...
                    options.ShadowBoundaryFraction, 1)} = 0.55
            end

            levels = 2 ^ bitDepth - 1;
            x = double(image) ./ levels;
            switch kind
                case "identity"
                    y = x;
                case "gain-offset"
                    y = options.Gain .* x + options.Offset;
                case "gamma"
                    y = x .^ options.Gamma;
                case "blur"
                    g = SyntheticRadiometry.gaussianKernel( ...
                        options.BlurSigmaPixels);
                    y = conv2(g(:), g(:).', x, "same");
                case "noise"
                    stream = RandStream("mt19937ar", Seed=options.Seed);
                    y = x + options.NoiseSigma .* randn(stream, size(x));
                case "polarity"
                    y = 1 - x;
                case "shadow"
                    [yy, xx] = ndgrid( ...
                        (0:(size(x, 1) - 1)) ./ max(size(x, 1) - 1, 1), ...
                        (0:(size(x, 2) - 1)) ./ max(size(x, 2) - 1, 1));
                    shadow = xx + 0.35 .* yy ...
                        >= 1.35 .* options.ShadowBoundaryFraction;
                    y = x;
                    y(shadow) = options.ShadowAttenuation .* x(shadow);
            end
            y = min(max(y, 0), 1);
            output = uint16(round(levels .* y));
        end
    end

    methods (Static, Access = private)
        function g = gaussianKernel(sigma)
            if sigma == 0
                g = 1;
                return
            end
            radius = ceil(3 .* sigma);
            x = -radius:radius;
            g = exp(-(x .^ 2) ./ (2 .* sigma ^ 2));
            g = g ./ sum(g);
        end
    end
end
