classdef RpcImageWindowCamera
    %RPCIMAGEWINDOWCAMERA Native ROI and downsample coordinate adapter.
    %
    % NativeROI is inclusive one-based [yStart,yEnd,xStart,xEnd] at 1x.
    % It never changes with DownsampleFactor. Working pixels map to the
    % native full detector as
    %   pNative=[xStart-1,yStart-1]+s*(pWorking-0.5)+0.5.
    %
    % Traceability: data contract Phase B0 coordinate convention;
    % long-range workplan R1 recovery milestone; D075.

    properties (SetAccess = private)
        BaseCamera
        NativeROI (1, 4) double
        NativeOriginXY (1, 2) double
        NativeWindowSize (1, 2) double
        DownsampleFactor (1, 1) double
        ImageSize (1, 2) double
        FullImageSize (1, 2) double
        WorldFrame (1, 1) string
        ElevationDatum (1, 1) string
        PixelConvention (1, 1) string = ...
            "one-based [x,y]=[column,row] window pixel centers"
    end

    methods
        function obj = RpcImageWindowCamera(baseCamera, nativeROI, options)
            arguments
                baseCamera (1, 1) {mustBeNativeRpcCamera}
                nativeROI (1, 4) double ...
                    {mustBeFinite, mustBeInteger, mustBePositive}
                options.DownsampleFactor (1, 1) double ...
                    {mustBeFinite, mustBeInteger, mustBePositive} = 1
            end

            if nativeROI(2) < nativeROI(1) || nativeROI(4) < nativeROI(3) ...
                    || nativeROI(2) > baseCamera.ImageSize(1) ...
                    || nativeROI(4) > baseCamera.ImageSize(2)
                error("RpcImageWindowCamera:InvalidNativeROI", ...
                    "NativeROI must be inclusive " ...
                    + "[yStart,yEnd,xStart,xEnd] inside the " ...
                    + "factor-one native image.");
            end
            obj.BaseCamera = baseCamera;
            obj.NativeROI = nativeROI;
            obj.NativeOriginXY = [nativeROI(3) - 1, nativeROI(1) - 1];
            obj.NativeWindowSize = ...
                [nativeROI(2) - nativeROI(1) + 1, ...
                nativeROI(4) - nativeROI(3) + 1];
            obj.DownsampleFactor = options.DownsampleFactor;
            obj.ImageSize = ceil(obj.NativeWindowSize ...
                ./ obj.DownsampleFactor);
            obj.FullImageSize = baseCamera.ImageSize;
            obj.WorldFrame = baseCamera.WorldFrame;
            obj.ElevationDatum = baseCamera.ElevationDatum;
        end

        function [pixelXY, valid, diagnostic] = worldToImage(obj, world)
            arguments
                obj (1, 1) RpcImageWindowCamera
                world (:, 3) double {mustBeReal}
            end

            [nativePixelXY, valid, baseDiagnostic] = ...
                obj.BaseCamera.worldToImage(world);
            pixelXY = obj.nativeToWorking(nativePixelXY);
            pixelXY(~valid, :) = NaN;
            diagnostic = struct("Base", baseDiagnostic, ...
                "NativePixelXY", nativePixelXY, ...
                "NativeROIYX", obj.NativeROI, ...
                "DownsampleFactor", obj.DownsampleFactor, ...
                "CoordinateMap", ...
                "pWorking=(pNative-origin-0.5)/s+0.5");
        end

        function [world, valid, diagnostic] = ...
                imageToWorldAtHeight(obj, pixelXY, height)
            arguments
                obj (1, 1) RpcImageWindowCamera
                pixelXY (:, 2) double {mustBeReal}
                height (:, 1) double ...
                    {mustBeReal, mustHaveOneOrNRows(height, pixelXY)}
            end

            nativePixelXY = obj.workingToNative(pixelXY);
            [world, valid, baseDiagnostic] = ...
                obj.BaseCamera.imageToWorldAtHeight(nativePixelXY, height);
            valid = valid & obj.isInsideImage(pixelXY);
            world(~valid, :) = NaN;
            diagnostic = struct("Base", baseDiagnostic, ...
                "NativePixelXY", nativePixelXY, ...
                "NativeROIYX", obj.NativeROI, ...
                "DownsampleFactor", obj.DownsampleFactor, ...
                "CoordinateMap", ...
                "pNative=origin+s*(pWorking-0.5)+0.5");
        end

        function valid = isInsideImage(obj, pixelXY, margin)
            arguments
                obj (1, 1) RpcImageWindowCamera
                pixelXY (:, 2) double {mustBeReal}
                margin (1, 1) double {mustBeFinite, mustBeNonnegative} = 0
            end

            nativePixelXY = obj.workingToNative(pixelXY);
            valid = all(isfinite(pixelXY), 2) ...
                & pixelXY(:, 1) >= 1 + margin ...
                & pixelXY(:, 1) <= obj.ImageSize(2) - margin ...
                & pixelXY(:, 2) >= 1 + margin ...
                & pixelXY(:, 2) <= obj.ImageSize(1) - margin ...
                & nativePixelXY(:, 1) >= obj.NativeROI(3) ...
                & nativePixelXY(:, 1) <= obj.NativeROI(4) ...
                & nativePixelXY(:, 2) >= obj.NativeROI(1) ...
                & nativePixelXY(:, 2) <= obj.NativeROI(2);
            valid = valid & obj.BaseCamera.isInsideImage(nativePixelXY);
        end

        function nativePixelXY = workingToNative(obj, workingPixelXY)
            arguments
                obj (1, 1) RpcImageWindowCamera
                workingPixelXY (:, 2) double {mustBeReal}
            end
            nativePixelXY = obj.NativeOriginXY ...
                + obj.DownsampleFactor .* (workingPixelXY - 0.5) + 0.5;
        end

        function workingPixelXY = nativeToWorking(obj, nativePixelXY)
            arguments
                obj (1, 1) RpcImageWindowCamera
                nativePixelXY (:, 2) double {mustBeReal}
            end
            workingPixelXY = (nativePixelXY - obj.NativeOriginXY - 0.5) ...
                ./ obj.DownsampleFactor + 0.5;
        end
    end
end

function mustBeNativeRpcCamera(camera)
valid = isa(camera, "Rpc00bCamera") ...
    || isa(camera, "RpcImageCorrectionCamera");
if ~valid || camera.DownsampleFactor ~= 1
    error("RpcImageWindowCamera:NativeCameraRequired", ...
        "BaseCamera must be a factor-one RPC camera or correction wrapper.");
end
end

function mustHaveOneOrNRows(height, pixelXY)
if ~(isscalar(height) || size(height, 1) == size(pixelXY, 1))
    error("RpcImageWindowCamera:HeightSizeMismatch", ...
        "Height must be scalar or have one row per pixel.");
end
end
