classdef RpcImageCorrectionCamera
    %RPCIMAGECORRECTIONCAMERA Three-mode native-pixel RPC correction.
    %
    % Parameters are [dx,dy,thetaRadians] in the native full-resolution
    % detector coordinates. The rigid image transform is applied after
    % worldToImage and inverted before imageToWorldAtHeight. RPC
    % coefficients are never modified.
    %
    % This is an image-coordinate proxy for the future rigorous camera's
    % physical adjustable parameters, not an OPK correction to RPC00B.
    % Traceability: long-range workplan R1 recovery milestone; D074.

    properties (SetAccess = private)
        BaseCamera
        Parameters (1, 3) double
        RotationCenterXY (1, 2) double
        ImageSize (1, 2) double
        FullImageSize (1, 2) double
        DownsampleFactor (1, 1) double = 1
        WorldFrame (1, 1) string
        ElevationDatum (1, 1) string
        PixelConvention (1, 1) string = ...
            "one-based native [x,y]=[sample,line] pixel centers"
    end

    methods
        function obj = RpcImageCorrectionCamera(baseCamera, parameters)
            arguments
                baseCamera (1, 1) Rpc00bCamera
                parameters (1, 3) double {mustBeFinite, mustBeReal} = [0, 0, 0]
            end

            if baseCamera.DownsampleFactor ~= 1
                error("RpcImageCorrectionCamera:NativeCameraRequired", ...
                    "The correction must wrap a factor-one native RPC camera.");
            end
            obj.BaseCamera = baseCamera;
            obj.Parameters = parameters;
            obj.FullImageSize = baseCamera.FullImageSize;
            obj.ImageSize = baseCamera.ImageSize;
            obj.RotationCenterXY = ...
                [(obj.ImageSize(2) + 1) ./ 2, (obj.ImageSize(1) + 1) ./ 2];
            obj.WorldFrame = baseCamera.WorldFrame;
            obj.ElevationDatum = baseCamera.ElevationDatum;
        end

        function [pixelXY, valid, diagnostic] = worldToImage(obj, world)
            arguments
                obj (1, 1) RpcImageCorrectionCamera
                world (:, 3) double {mustBeReal}
            end

            [basePixelXY, valid, baseDiagnostic] = ...
                obj.BaseCamera.worldToImage(world);
            pixelXY = obj.apply(basePixelXY);
            pixelXY(~valid, :) = NaN;
            diagnostic = struct("Base", baseDiagnostic, ...
                "BasePixelXY", basePixelXY, ...
                "ParametersNativePixelsRadians", obj.Parameters, ...
                "RotationCenterXY", obj.RotationCenterXY, ...
                "CoordinateMap", "pCorrected=R*(pBase-center)+center+[dx,dy]");
        end

        function [world, valid, diagnostic] = ...
                imageToWorldAtHeight(obj, pixelXY, height)
            arguments
                obj (1, 1) RpcImageCorrectionCamera
                pixelXY (:, 2) double {mustBeReal}
                height (:, 1) double ...
                    {mustBeReal, mustHaveOneOrNRows(height, pixelXY)}
            end

            basePixelXY = obj.invert(pixelXY);
            [world, valid, baseDiagnostic] = ...
                obj.BaseCamera.imageToWorldAtHeight(basePixelXY, height);
            valid = valid & obj.isInsideImage(pixelXY);
            world(~valid, :) = NaN;
            diagnostic = struct("Base", baseDiagnostic, ...
                "BasePixelXY", basePixelXY, ...
                "ParametersNativePixelsRadians", obj.Parameters, ...
                "RotationCenterXY", obj.RotationCenterXY, ...
                "CoordinateMap", "pBase=R'*(pCorrected-center-[dx,dy])+center");
        end

        function valid = isInsideImage(obj, pixelXY, margin)
            arguments
                obj (1, 1) RpcImageCorrectionCamera
                pixelXY (:, 2) double {mustBeReal}
                margin (1, 1) double {mustBeFinite, mustBeNonnegative} = 0
            end

            valid = all(isfinite(pixelXY), 2) ...
                & pixelXY(:, 1) >= 1 + margin ...
                & pixelXY(:, 1) <= obj.ImageSize(2) - margin ...
                & pixelXY(:, 2) >= 1 + margin ...
                & pixelXY(:, 2) <= obj.ImageSize(1) - margin;
            valid = valid & obj.BaseCamera.isInsideImage(obj.invert(pixelXY));
        end

        function correctedPixelXY = apply(obj, basePixelXY)
            arguments
                obj (1, 1) RpcImageCorrectionCamera
                basePixelXY (:, 2) double {mustBeReal}
            end

            t = obj.Parameters(3);
            r = [cos(t), -sin(t); sin(t), cos(t)];
            correctedPixelXY = (basePixelXY - obj.RotationCenterXY) * r.' ...
                + obj.RotationCenterXY + obj.Parameters(1:2);
        end

        function basePixelXY = invert(obj, correctedPixelXY)
            arguments
                obj (1, 1) RpcImageCorrectionCamera
                correctedPixelXY (:, 2) double {mustBeReal}
            end

            t = obj.Parameters(3);
            r = [cos(t), -sin(t); sin(t), cos(t)];
            basePixelXY = (correctedPixelXY - obj.RotationCenterXY ...
                - obj.Parameters(1:2)) * r + obj.RotationCenterXY;
        end
    end
end

function mustHaveOneOrNRows(height, pixelXY)
if ~(isscalar(height) || size(height, 1) == size(pixelXY, 1))
    error("RpcImageCorrectionCamera:HeightSizeMismatch", ...
        "Height must be scalar or have one row per pixel.");
end
end
