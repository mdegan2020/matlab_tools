classdef ZnccSpin2Hybrid
    %ZNCCSPIN2HYBRID Robustly scaled ZNCC/T3 baseline data term.
    %
    % Scales are validation-set weighted median absolute deviations. Costs
    % are clipped to a shared range before the confidence-weighted Eq. (133)
    % fusion. Complete scenes receive equal total weight during scale fit.
    % Traceability: algo/main.tex Sec. 8.4; Eqs. (67) and (133).

    properties (SetAccess = private)
        ZnccScale (1, 1) double
        Spin2Scale (1, 1) double
        ZnccWeight (1, 1) double
        Spin2Weight (1, 1) double
        Clip (1, 1) double
    end

    methods
        function obj = ZnccSpin2Hybrid(znccScale, spin2Scale, ...
                znccWeight, spin2Weight, clip)
            arguments
                znccScale (1, 1) double {mustBeFinite, mustBePositive}
                spin2Scale (1, 1) double {mustBeFinite, mustBePositive}
                znccWeight (1, 1) double ...
                    {mustBeFinite, mustBeNonnegative}
                spin2Weight (1, 1) double ...
                    {mustBeFinite, mustBeNonnegative}
                clip (1, 1) double {mustBeFinite, mustBePositive} = 1
            end

            obj.ZnccScale = znccScale;
            obj.Spin2Scale = spin2Scale;
            obj.ZnccWeight = znccWeight;
            obj.Spin2Weight = spin2Weight;
            obj.Clip = clip;
        end

        function cost = combine(obj, zncc, spin2, spin2Confidence)
            %COMBINE Apply the frozen robust scales and Eq. (133) weights.
            arguments
                obj (1, 1) ZnccSpin2Hybrid
                zncc double
                spin2 double
                spin2Confidence double
            end

            if obj.Spin2Weight == 0
                % Preserve the raw-ZNCC endpoint exactly for the baseline
                % comparison; positive scaling cannot change its WTA.
                cost = zncc ./ obj.ZnccScale;
                cost(~isfinite(zncc)) = NaN;
                return
            end
            if obj.ZnccWeight == 0
                cost = obj.Spin2Weight .* spin2Confidence ...
                    .* min(spin2 ./ obj.Spin2Scale, obj.Clip);
                cost(~isfinite(spin2) ...
                    | ~isfinite(spin2Confidence)) = NaN;
                return
            end
            z = min(zncc ./ obj.ZnccScale, obj.Clip);
            s = min(spin2 ./ obj.Spin2Scale, obj.Clip);
            cost = obj.ZnccWeight .* z ...
                + obj.Spin2Weight .* spin2Confidence .* s;
            cost(~isfinite(zncc) | ~isfinite(spin2) ...
                | ~isfinite(spin2Confidence)) = NaN;
        end

        function s = toStruct(obj)
            s = struct("znccScale", obj.ZnccScale, ...
                "spin2Scale", obj.Spin2Scale, ...
                "znccWeight", obj.ZnccWeight, ...
                "spin2Weight", obj.Spin2Weight, "clip", obj.Clip, ...
                "definition", ...
                "Eq. (133), validation-scene weighted-MAD scales");
        end
    end

    methods (Static)
        function scales = fitScales(znccByScene, spin2ByScene)
            %FITSCALES Equal-scene weighted MAD for the two raw channels.
            arguments
                znccByScene (:, 1) cell {mustBeNonempty}
                spin2ByScene (:, 1) cell {mustBeNonempty}
            end

            [z, wz] = ZnccSpin2Hybrid.stackFinite(znccByScene);
            [s, ws] = ZnccSpin2Hybrid.stackFinite(spin2ByScene);
            scales = struct( ...
                "ZnccScale", ZnccSpin2Hybrid.weightedMad(z, wz), ...
                "Spin2Scale", ZnccSpin2Hybrid.weightedMad(s, ws), ...
                "SceneCount", numel(znccByScene), ...
                "Definition", ...
                "weighted median absolute deviation; each scene weight one");
        end

        function obj = fromStruct(s)
            arguments
                s (1, 1) struct
            end

            obj = ZnccSpin2Hybrid(double(s.znccScale), ...
                double(s.spin2Scale), double(s.znccWeight), ...
                double(s.spin2Weight), double(s.clip));
        end
    end

    methods (Static, Access = private)
        function [x, w] = stackFinite(values)
            n = numel(values);
            x = cell(n, 1);
            w = cell(n, 1);
            for k = 1:n
                v = values{k}(:);
                v = v(isfinite(v));
                x{k} = v;
                w{k} = ones(size(v)) ./ numel(v);
            end
            x = vertcat(x{:});
            w = vertcat(w{:});
        end

        function value = weightedMad(x, w)
            center = ZnccSpin2Hybrid.weightedMedian(x, w);
            value = ZnccSpin2Hybrid.weightedMedian(abs(x - center), w);
        end

        function value = weightedMedian(x, w)
            [x, order] = sort(x);
            w = w(order);
            value = x(find(cumsum(w) >= 0.5 .* sum(w), 1, "first"));
        end
    end
end
