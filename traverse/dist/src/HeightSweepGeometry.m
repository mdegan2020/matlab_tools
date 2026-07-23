classdef HeightSweepGeometry
    %HEIGHTSWEEPGEOMETRY Camera-constrained height-warp calculations.
    %
    % The forward warp maps reference pixels to moving pixels. Jacobians use
    % A(output coordinate, input coordinate) and are stored N-by-2-by-2.
    % Geometry remains double precision and invalid rows are explicit NaNs.
    %
    % Traceability: algorithm description Secs. 2.1, 2.3, and 5.1-5.3;
    % Eqs. (1)-(8), (52), (55), (57), (58), and (63).

    properties (SetAccess = private)
        ReferenceCamera
        MovingCamera
    end

    methods
        function obj = HeightSweepGeometry(referenceCamera, movingCamera)
            arguments
                referenceCamera (1, 1) {mustBeProjectCamera}
                movingCamera (1, 1) ...
                    {mustBeProjectCamera, ...
                    mustBeCompatibleCamera(movingCamera, referenceCamera)}
            end

            obj.ReferenceCamera = referenceCamera;
            obj.MovingCamera = movingCamera;
        end

        function [w, valid, inside] = warp(obj, p, z)
            %WARP Evaluate w(p,Z)=pi_M(pi_R^-1(p,Z)).
            % Traceability: Sec. 2.1, Eqs. (1)-(2); Algorithm 1, line 4.

            arguments
                obj (1, 1) HeightSweepGeometry
                p (:, 2) double {mustBeReal}
                z (:, 1) double ...
                    {mustBeReal, mustHaveOneOrNRows(z, p)}
            end

            [x, vr] = obj.ReferenceCamera.imageToWorldAtHeight(p, z);
            [w, vm] = obj.MovingCamera.worldToImage(x);
            valid = vr & vm;
            inside = valid & obj.MovingCamera.isInsideImage(w);
            w(~valid, :) = NaN;
        end

        function [t, kappa, valid] = heightDerivative(obj, p, z, options)
            %HEIGHTDERIVATIVE Central-difference dw/dZ in pixels per metre.
            % Traceability: Sec. 5.1, Eqs. (52), (53), and (55).

            arguments
                obj (1, 1) HeightSweepGeometry
                p (:, 2) double {mustBeReal}
                z (:, 1) double ...
                    {mustBeReal, mustHaveOneOrNRows(z, p)}
                options.DeltaHeight (1, 1) double ...
                    {mustBeFinite, mustBePositive} = 1
            end

            h = options.DeltaHeight;
            [wp, vp] = obj.warp(p, z + h);
            [wm, vm] = obj.warp(p, z - h);
            valid = vp & vm;
            t = (wp - wm) ./ (2 * h);
            t(~valid, :) = NaN;
            kappa = vecnorm(t, 2, 2);
        end

        function [a, valid] = warpJacobian(obj, p, z, options)
            %WARPJACOBIAN Central-difference dw/dp, N-by-2-by-2.
            % Traceability: Sec. 5.2, Eqs. (57) and (61); Algorithm 1, line 5.

            arguments
                obj (1, 1) HeightSweepGeometry
                p (:, 2) double {mustBeReal}
                z (:, 1) double ...
                    {mustBeReal, mustHaveOneOrNRows(z, p)}
                options.DeltaPixel (1, 1) double ...
                    {mustBeFinite, mustBePositive} = 0.5
            end

            h = options.DeltaPixel;
            ex = [h, 0];
            ey = [0, h];
            [wxp, vxp] = obj.warp(p + ex, z);
            [wxm, vxm] = obj.warp(p - ex, z);
            [wyp, vyp] = obj.warp(p + ey, z);
            [wym, vym] = obj.warp(p - ey, z);
            valid = vxp & vxm & vyp & vym;

            dx = (wxp - wxm) ./ (2 * h);
            dy = (wyp - wym) ./ (2 * h);
            a = zeros(size(p, 1), 2, 2);
            a(:, :, 1) = dx;
            a(:, :, 2) = dy;
            a(~valid, :, :) = NaN;
        end
    end

    methods (Static)
        function [fz, fb, detA, mu, dil, valid] = toWirtinger(a)
            %TOWIRTINGER Convert real warp Jacobians to complex derivatives.
            % Traceability: Sec. 2.3, Eqs. (4)-(8).

            arguments
                a (:, 2, 2) double {mustBeReal}
            end

            ux = a(:, 1, 1);
            uy = a(:, 1, 2);
            vx = a(:, 2, 1);
            vy = a(:, 2, 2);
            fz = 0.5 .* ((ux + vy) + 1i .* (vx - uy));
            fb = 0.5 .* ((ux - vy) + 1i .* (vx + uy));
            detA = ux .* vy - uy .* vx;
            valid = all(isfinite(reshape(a, size(a, 1), [])), 2) ...
                & abs(fz) > eps(max(1, abs(fz)));
            mu = fb ./ fz;
            mu(~valid) = NaN;
            qc = valid & detA > 0 & abs(mu) < 1;
            dil = (1 + abs(mu)) ./ (1 - abs(mu));
            dil(~qc) = NaN;
        end

        function as = surfaceJacobian(a, t, s)
            %SURFACEJACOBIAN Apply the local slanted-surface rank-one term.
            % Traceability: Sec. 5.3, Eq. (63), A_surf=A_0+t*s^T.

            arguments
                a (:, 2, 2) double {mustBeReal}
                t (:, 2) double ...
                    {mustBeReal, mustHaveSameRows(t, a)}
                s (:, 2) double ...
                    {mustBeReal, mustHaveOneOrNRows(s, t)}
            end

            if size(s, 1) == 1
                s = repmat(s, size(t, 1), 1);
            end
            as = a;
            as(:, 1, 1) = as(:, 1, 1) + t(:, 1) .* s(:, 1);
            as(:, 1, 2) = as(:, 1, 2) + t(:, 1) .* s(:, 2);
            as(:, 2, 1) = as(:, 2, 1) + t(:, 2) .* s(:, 1);
            as(:, 2, 2) = as(:, 2, 2) + t(:, 2) .* s(:, 2);
        end

        function [dz, along, cross, valid] = decomposeResidual(du, t)
            %DECOMPOSERESIDUAL Split displacement into height and cross-track.
            % Traceability: Sec. 5.7, Eqs. (77)-(78).

            arguments
                du (:, 2) double {mustBeReal}
                t (:, 2) double ...
                    {mustBeReal, mustHaveSameRows(t, du)}
            end

            d = sum(t .* t, 2);
            valid = all(isfinite(du), 2) & all(isfinite(t), 2) ...
                & d > eps(max(1, d));
            dz = sum(t .* du, 2) ./ d;
            along = dz .* t;
            cross = du - along;
            dz(~valid) = NaN;
            along(~valid, :) = NaN;
            cross(~valid, :) = NaN;
        end
    end
end

function mustHaveOneOrNRows(a, b)
if ~(size(a, 1) == 1 || size(a, 1) == size(b, 1))
    error("HeightSweepGeometry:RowCountMismatch", ...
        "Input must have one row or the same number of rows as the points.");
end
end

function mustHaveSameRows(a, b)
if size(a, 1) ~= size(b, 1)
    error("HeightSweepGeometry:RowCountMismatch", ...
        "Inputs must have the same number of rows.");
end
end

function mustBeProjectCamera(camera)
if ~(isa(camera, "PinholeCamera") || isa(camera, "Rpc00bCamera") ...
        || isa(camera, "PyramidLevelCamera") ...
        || isa(camera, "RpcImageCorrectionCamera") ...
        || isa(camera, "RpcImageWindowCamera"))
    error("HeightSweepGeometry:UnsupportedCamera", ...
        "Camera must implement a supported project camera contract.");
end
end

function mustBeCompatibleCamera(movingCamera, referenceCamera)
if movingCamera.WorldFrame ~= referenceCamera.WorldFrame ...
        || movingCamera.ElevationDatum ~= referenceCamera.ElevationDatum
    error("HeightSweepGeometry:IncompatibleCamera", ...
        "Reference and moving cameras must use the same world convention.");
end
end
