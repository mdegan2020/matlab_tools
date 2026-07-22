classdef PinholeCamera
    %PINHOLECAMERA Vectorized one-based pinhole camera for synthetic tests.
    %
    % World-to-camera coordinates use x_c = R * (X - C). Pixel coordinates
    % are geometric [x,y] = [column,row], with integer coordinates at MATLAB
    % pixel centers. World and elevation units are metres; Z uses an
    % arbitrary synthetic vertical datum for this camera implementation.
    %
    % Traceability: algorithm description Sec. 2.1, Eqs. (1)-(2).

    properties (SetAccess = private)
        K (3, 3) double
        R (3, 3) double
        C (1, 3) double
        ImageSize (1, 2) double
        WorldFrame (1, 1) string = "local ENU metres"
        ElevationDatum (1, 1) string = "local synthetic ENU Z=0"
    end

    methods
        function obj = PinholeCamera(k, r, c, imageSize)
            arguments
                k (3, 3) double {mustBeFinite, mustBeNonsingular}
                r (3, 3) double {mustBeFinite, mustBeNonsingular}
                c (1, 3) double {mustBeFinite}
                imageSize (1, 2) double ...
                    {mustBeFinite, mustBeInteger, mustBePositive}
            end

            obj.K = k;
            obj.R = r;
            obj.C = c;
            obj.ImageSize = imageSize;
        end

        function [p, valid, depth] = worldToImage(obj, x)
            %WORLDTOIMAGE Project N world points into one-based pixels.
            % Traceability: algorithm description Sec. 2.1, Eq. (2).

            arguments
                obj (1, 1) PinholeCamera
                x (:, 3) double {mustBeReal}
            end

            xc = (x - obj.C) * obj.R.';
            q = xc * obj.K.';
            depth = xc(:, 3);
            d = q(:, 3);
            p = q(:, 1:2) ./ d;
            valid = all(isfinite(x), 2) & all(isfinite(q), 2) ...
                & depth > 0 & abs(d) > eps(max(1, abs(d)));
            p(~valid, :) = NaN;
            depth(~valid) = NaN;
        end

        function [x, valid] = imageToWorldAtHeight(obj, p, z)
            %IMAGETOWORLDATHEIGHT Intersect image rays with world Z=z.
            % Traceability: algorithm description Sec. 2.1, Eq. (1).

            arguments
                obj (1, 1) PinholeCamera
                p (:, 2) double {mustBeReal}
                z (:, 1) double ...
                    {mustBeReal, mustHaveOneOrNRows(z, p)}
            end

            n = size(p, 1);
            zz = PinholeCamera.expandHeight(z, n);
            q = [p, ones(n, 1)] / obj.K.';
            d = q * obj.R;
            dz = d(:, 3);
            a = (zz - obj.C(3)) ./ dz;
            x = obj.C + a .* d;
            valid = all(isfinite(p), 2) & isfinite(zz) ...
                & all(isfinite(d), 2) ...
                & abs(dz) > eps(max(1, abs(dz))) & a > 0;
            x(~valid, :) = NaN;
        end

        function valid = isInsideImage(obj, p, margin)
            %ISINSIDEIMAGE Test interpolation support inside the image.

            arguments
                obj (1, 1) PinholeCamera
                p (:, 2) double {mustBeReal}
                margin (1, 1) double ...
                    {mustBeFinite, mustBeNonnegative} = 0
            end

            valid = all(isfinite(p), 2) ...
                & p(:, 1) >= 1 + margin ...
                & p(:, 1) <= obj.ImageSize(2) - margin ...
                & p(:, 2) >= 1 + margin ...
                & p(:, 2) <= obj.ImageSize(1) - margin;
        end
    end

    methods (Static, Access = private)
        function z = expandHeight(z, n)
            if isscalar(z)
                z = repmat(z, n, 1);
            end
        end
    end
end

function mustBeNonsingular(a)
if rcond(a) <= eps(class(a))
    error("PinholeCamera:SingularMatrix", ...
        "Camera matrices must be nonsingular.");
end
end

function mustHaveOneOrNRows(z, p)
if ~(isscalar(z) || size(z, 1) == size(p, 1))
    error("PinholeCamera:HeightSizeMismatch", ...
        "Height must be scalar or have one row per pixel.");
end
end
