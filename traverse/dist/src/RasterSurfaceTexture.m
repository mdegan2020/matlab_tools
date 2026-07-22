classdef RasterSurfaceTexture
    %RASTERSURFACETEXTURE Continuous ENU sampling of a local raster texture.
    %
    % Input radiometry is a single-channel double array in [0,1]. Geometric
    % inputs are local ENU [X,Y] metres. Source coordinates are one-based
    % [x,y]=[column,row] pixel centers and are sampled bilinearly. At zero
    % rotation, east maps toward increasing columns and north maps toward
    % decreasing rows. Any bilinear support touching the source mask or
    % extending outside the image is explicitly invalid.
    %
    % Traceability: algorithm description Secs. 10.2, 11.2, and 14.1;
    % continuous world/surface texture and explicit sampling validity.

    properties (SetAccess = private)
        Image (:, :) double
        ValidMask (:, :) logical
        MetresPerPixel (1, 1) double
        CenterPixelXY (1, 2) double
        WorldCenterXY (1, 2) double
        RotationDegrees (1, 1) double
        Identifier (1, 1) string
    end

    methods
        function obj = RasterSurfaceTexture(image, options)
            arguments
                image (:, :) double {mustBeReal, mustBeFinite, ...
                    mustBeNonempty, mustBeNonnegative, ...
                    mustBeLessThanOrEqual(image, 1)}
                options.ValidMask (:, :) logical ...
                    {mustMatchTextureSize(options.ValidMask, image)} = ...
                    true(size(image))
                options.MetresPerPixel (1, 1) double ...
                    {mustBeFinite, mustBePositive} = 1
                options.CenterPixelXY (1, 2) double {mustBeFinite} = ...
                    [(size(image, 2) + 1) / 2, ...
                    (size(image, 1) + 1) / 2]
                options.WorldCenterXY (1, 2) double {mustBeFinite} = [0, 0]
                options.RotationDegrees (1, 1) double {mustBeFinite} = 0
                options.Identifier (1, 1) string = "raster-texture"
            end

            obj.Image = image;
            obj.ValidMask = options.ValidMask;
            obj.MetresPerPixel = options.MetresPerPixel;
            obj.CenterPixelXY = options.CenterPixelXY;
            obj.WorldCenterXY = options.WorldCenterXY;
            obj.RotationDegrees = options.RotationDegrees;
            obj.Identifier = options.Identifier;
        end

        function [v, valid, sourceXY] = sample(obj, worldXY)
            %SAMPLE Bilinearly sample at local ENU [X,Y] coordinates.

            arguments
                obj (1, 1) RasterSurfaceTexture
                worldXY (:, 2) double {mustBeReal}
            end

            d = worldXY - obj.WorldCenterXY;
            c = cosd(obj.RotationDegrees);
            s = sind(obj.RotationDegrees);
            right = c .* d(:, 1) + s .* d(:, 2);
            up = -s .* d(:, 1) + c .* d(:, 2);
            x = obj.CenterPixelXY(1) + right ./ obj.MetresPerPixel;
            y = obj.CenterPixelXY(2) - up ./ obj.MetresPerPixel;
            sourceXY = [x, y];

            finite = all(isfinite(worldXY), 2) & isfinite(x) & isfinite(y);
            inside = finite & x >= 1 & x <= size(obj.Image, 2) ...
                & y >= 1 & y <= size(obj.Image, 1);
            maskWeight = interp2(double(obj.ValidMask), x, y, ...
                "linear", 0);
            valid = inside & maskWeight >= 1 - 64 * eps;
            v = interp2(obj.Image, x, y, "linear", NaN);
            valid = valid & isfinite(v);
            v(~valid) = NaN;
            sourceXY(~valid, :) = NaN;
        end
    end
end

function mustMatchTextureSize(mask, image)
if ~isequal(size(mask), size(image))
    error("RasterSurfaceTexture:MaskSizeMismatch", ...
        "ValidMask must have the same rows and columns as image.");
end
end
