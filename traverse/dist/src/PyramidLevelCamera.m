classdef PyramidLevelCamera
    %PYRAMIDLEVELCAMERA Exact pixel-center adapter for one pyramid level.
    %
    % The base camera remains authoritative. This adapter changes only image
    % coordinates using pBase=f*(pLevel-0.5)+0.5 and its inverse. World
    % coordinates, elevation datum, and geometry precision are unchanged.
    %
    % Traceability: algo/main.tex Eqs. (1)-(2), (52), and (55);
    % long-range workplan C1.1.

    properties (SetAccess = private)
        BaseCamera
        Factor (1, 1) double
        ImageSize (1, 2) double
        WorldFrame (1, 1) string
        ElevationDatum (1, 1) string
        PixelConvention (1, 1) string = ...
            "one-based [x,y]=[column,row] pyramid pixel centers"
    end

    methods
        function obj = PyramidLevelCamera(baseCamera, factor)
            arguments
                baseCamera (1, 1) {mustBeSupportedBaseCamera}
                factor (1, 1) double ...
                    {mustBeFinite, mustBeInteger, mustBePositive}
            end

            obj.BaseCamera = baseCamera;
            obj.Factor = factor;
            obj.ImageSize = ceil(baseCamera.ImageSize ./ factor);
            obj.WorldFrame = baseCamera.WorldFrame;
            obj.ElevationDatum = baseCamera.ElevationDatum;
        end

        function [pixelXY, valid, diagnostic] = worldToImage(obj, world)
            arguments
                obj (1, 1) PyramidLevelCamera
                world (:, 3) double {mustBeReal}
            end

            [basePixelXY, valid, baseDiagnostic] = ...
                obj.BaseCamera.worldToImage(world);
            pixelXY = obj.baseToLevel(basePixelXY);
            pixelXY(~valid, :) = NaN;
            diagnostic = struct( ...
                "Base", baseDiagnostic, ...
                "BasePixelXY", basePixelXY, ...
                "Factor", obj.Factor, ...
                "CoordinateMap", "pLevel=(pBase-0.5)/factor+0.5");
        end

        function [world, valid, diagnostic] = ...
                imageToWorldAtHeight(obj, pixelXY, height)
            arguments
                obj (1, 1) PyramidLevelCamera
                pixelXY (:, 2) double {mustBeReal}
                height (:, 1) double ...
                    {mustBeReal, mustHaveOneOrNRows(height, pixelXY)}
            end

            basePixelXY = obj.levelToBase(pixelXY);
            if isa(obj.BaseCamera, "Rpc00bCamera")
                [world, valid, baseDiagnostic] = ...
                    obj.BaseCamera.imageToWorldAtHeight(basePixelXY, height);
            else
                [world, valid] = ...
                    obj.BaseCamera.imageToWorldAtHeight(basePixelXY, height);
                baseDiagnostic = struct;
            end
            diagnostic = struct( ...
                "Base", baseDiagnostic, ...
                "BasePixelXY", basePixelXY, ...
                "Factor", obj.Factor, ...
                "CoordinateMap", "pBase=factor*(pLevel-0.5)+0.5");
        end

        function valid = isInsideImage(obj, pixelXY, margin)
            arguments
                obj (1, 1) PyramidLevelCamera
                pixelXY (:, 2) double {mustBeReal}
                margin (1, 1) double ...
                    {mustBeFinite, mustBeNonnegative} = 0
            end

            valid = all(isfinite(pixelXY), 2) ...
                & pixelXY(:, 1) >= 1 + margin ...
                & pixelXY(:, 1) <= obj.ImageSize(2) - margin ...
                & pixelXY(:, 2) >= 1 + margin ...
                & pixelXY(:, 2) <= obj.ImageSize(1) - margin;
            valid = valid & obj.BaseCamera.isInsideImage( ...
                obj.levelToBase(pixelXY));
        end

        function basePixelXY = levelToBase(obj, levelPixelXY)
            arguments
                obj (1, 1) PyramidLevelCamera
                levelPixelXY (:, 2) double {mustBeReal}
            end

            basePixelXY = HeightImagePyramid.levelToBase( ...
                levelPixelXY, obj.Factor);
        end

        function levelPixelXY = baseToLevel(obj, basePixelXY)
            arguments
                obj (1, 1) PyramidLevelCamera
                basePixelXY (:, 2) double {mustBeReal}
            end

            levelPixelXY = HeightImagePyramid.baseToLevel( ...
                basePixelXY, obj.Factor);
        end
    end
end

function mustBeSupportedBaseCamera(camera)
if ~(isa(camera, "PinholeCamera") || isa(camera, "Rpc00bCamera"))
    error("PyramidLevelCamera:UnsupportedBaseCamera", ...
        "Base camera must be a PinholeCamera or Rpc00bCamera.");
end
end

function mustHaveOneOrNRows(height, pixelXY)
if ~(isscalar(height) || size(height, 1) == size(pixelXY, 1))
    error("PyramidLevelCamera:HeightSizeMismatch", ...
        "Height must be scalar or have one row per pixel.");
end
end
