classdef PinholePlaneOracle
    %PINHOLEPLANEORACLE Independent analytic truth for a constant-Z plane.
    %
    % This class does not call HeightSweepGeometry. It evaluates the plane
    % homography and its analytic derivatives directly from two pinhole
    % cameras, providing an independent oracle for the implementation under
    % test. Pixels are one-based [x,y]=[column,row]; ENU and Z use metres.
    %
    % Traceability: algorithm description Secs. 2.1 and 5.1-5.2;
    % Eqs. (1)-(2), (52), and (57); Appendix D.1.

    methods (Static)
        function h = homography(referenceCamera, movingCamera, z)
            %HOMOGRAPHY Map reference pixels to moving pixels on world Z=z.

            arguments
                referenceCamera (1, 1) PinholeCamera
                movingCamera (1, 1) PinholeCamera
                z (1, 1) double {mustBeFinite}
            end

            h = PinholePlaneOracle.surfaceHomography( ...
                referenceCamera, movingCamera, z, [0, 0]);
        end

        function h = surfaceHomography( ...
                referenceCamera, movingCamera, z0, slopeENU)
            %SURFACEHOMOGRAPHY Homography for Z=z0+sX*X+sY*Y.

            arguments
                referenceCamera (1, 1) PinholeCamera
                movingCamera (1, 1) PinholeCamera
                z0 (1, 1) double {mustBeFinite}
                slopeENU (1, 2) double {mustBeFinite}
            end

            n = [-slopeENU, 1].';
            b = (referenceCamera.C - movingCamera.C).';
            c = z0 - n.' * referenceCamera.C.';
            d = referenceCamera.R.' / referenceCamera.K;
            h = movingCamera.K * movingCamera.R ...
                * (c .* eye(3) + b * n.') * d;
        end

        function [w, valid, inside] = correspondence( ...
                referenceCamera, movingCamera, p, z)
            %CORRESPONDENCE Apply the analytic plane homography.

            arguments
                referenceCamera (1, 1) PinholeCamera
                movingCamera (1, 1) PinholeCamera
                p (:, 2) double {mustBeReal}
                z (1, 1) double {mustBeFinite}
            end

            [w, valid, inside] = PinholePlaneOracle.surfaceCorrespondence( ...
                referenceCamera, movingCamera, p, z, [0, 0]);
        end

        function [w, valid, inside] = surfaceCorrespondence( ...
                referenceCamera, movingCamera, p, z0, slopeENU)
            %SURFACECORRESPONDENCE Apply the analytic slanted-plane homography.

            arguments
                referenceCamera (1, 1) PinholeCamera
                movingCamera (1, 1) PinholeCamera
                p (:, 2) double {mustBeReal}
                z0 (1, 1) double {mustBeFinite}
                slopeENU (1, 2) double {mustBeFinite}
            end

            h = PinholePlaneOracle.surfaceHomography( ...
                referenceCamera, movingCamera, z0, slopeENU);
            [w, vh] = PinholePlaneOracle.apply(h, p);
            [~, ~, x, vr] = PinholePlaneOracle.surfaceHeight( ...
                referenceCamera, p, z0, slopeENU);
            [~, vm] = movingCamera.worldToImage(x);
            valid = vh & vr & vm;
            inside = valid & movingCamera.isInsideImage(w);
            w(~valid, :) = NaN;
        end

        function [a, valid] = warpJacobian( ...
                referenceCamera, movingCamera, p, z)
            %WARPJACOBIAN Analytic dw/dp for the constant-Z homography.

            arguments
                referenceCamera (1, 1) PinholeCamera
                movingCamera (1, 1) PinholeCamera
                p (:, 2) double {mustBeReal}
                z (1, 1) double {mustBeFinite}
            end

            [a, valid] = PinholePlaneOracle.surfaceWarpJacobian( ...
                referenceCamera, movingCamera, p, z, [0, 0]);
        end

        function [a, valid] = surfaceWarpJacobian( ...
                referenceCamera, movingCamera, p, z0, slopeENU)
            %SURFACEWARPJACOBIAN Analytic Jacobian of a plane homography.

            arguments
                referenceCamera (1, 1) PinholeCamera
                movingCamera (1, 1) PinholeCamera
                p (:, 2) double {mustBeReal}
                z0 (1, 1) double {mustBeFinite}
                slopeENU (1, 2) double {mustBeFinite}
            end

            h = PinholePlaneOracle.surfaceHomography( ...
                referenceCamera, movingCamera, z0, slopeENU);
            q = [p, ones(size(p, 1), 1)] * h.';
            d = q(:, 3) .^ 2;
            a = zeros(size(p, 1), 2, 2);
            a(:, 1, 1) = (h(1, 1) .* q(:, 3) ...
                - q(:, 1) .* h(3, 1)) ./ d;
            a(:, 1, 2) = (h(1, 2) .* q(:, 3) ...
                - q(:, 1) .* h(3, 2)) ./ d;
            a(:, 2, 1) = (h(2, 1) .* q(:, 3) ...
                - q(:, 2) .* h(3, 1)) ./ d;
            a(:, 2, 2) = (h(2, 2) .* q(:, 3) ...
                - q(:, 2) .* h(3, 2)) ./ d;
            [~, valid] = PinholePlaneOracle.surfaceCorrespondence( ...
                referenceCamera, movingCamera, p, z0, slopeENU);
            valid = valid & isfinite(d) & d > 0 ...
                & all(isfinite(reshape(a, size(a, 1), [])), 2);
            a(~valid, :, :) = NaN;
        end

        function [z, s, world, valid] = surfaceHeight( ...
                referenceCamera, p, z0, slopeENU)
            %SURFACEHEIGHT Exact Z(p) and dZ/dp for a world-coordinate plane.

            arguments
                referenceCamera (1, 1) PinholeCamera
                p (:, 2) double {mustBeReal}
                z0 (1, 1) double {mustBeFinite}
                slopeENU (1, 2) double {mustBeFinite}
            end

            ph = [p, ones(size(p, 1), 1)];
            dmat = referenceCamera.R.' / referenceCamera.K;
            d = ph * dmat.';
            n = [-slopeENU, 1].';
            den = d * n;
            c = z0 - referenceCamera.C * n;
            a = c ./ den;
            world = referenceCamera.C + a .* d;
            z = world(:, 3);
            dd = n.' * dmat(:, 1:2);
            dz = dmat(3, 1:2);
            s = c .* (dz .* den - d(:, 3) .* dd) ./ den .^ 2;
            valid = all(isfinite(p), 2) & all(isfinite(d), 2) ...
                & isfinite(den) & abs(den) > eps(max(1, abs(den))) ...
                & isfinite(a) & a > 0 & all(isfinite(s), 2);
            z(~valid) = NaN;
            s(~valid, :) = NaN;
            world(~valid, :) = NaN;
        end

        function [t, kappa, valid] = heightDerivative( ...
                referenceCamera, movingCamera, p, z)
            %HEIGHTDERIVATIVE Analytic dw/dZ in pixels per metre.

            arguments
                referenceCamera (1, 1) PinholeCamera
                movingCamera (1, 1) PinholeCamera
                p (:, 2) double {mustBeReal}
                z (1, 1) double {mustBeFinite}
            end

            h = PinholePlaneOracle.homography( ...
                referenceCamera, movingCamera, z);
            dh = movingCamera.K * movingCamera.R ...
                * referenceCamera.R.' / referenceCamera.K;
            ph = [p, ones(size(p, 1), 1)];
            q = ph * h.';
            dq = ph * dh.';
            d = q(:, 3) .^ 2;
            t = [(dq(:, 1) .* q(:, 3) - q(:, 1) .* dq(:, 3)) ./ d, ...
                (dq(:, 2) .* q(:, 3) - q(:, 2) .* dq(:, 3)) ./ d];
            [~, valid] = PinholePlaneOracle.correspondence( ...
                referenceCamera, movingCamera, p, z);
            valid = valid & isfinite(d) & d > 0 & all(isfinite(t), 2);
            t(~valid, :) = NaN;
            kappa = vecnorm(t, 2, 2);
        end

        function [sx, sy, sg, valid] = localSampling(camera, p, z)
            %LOCALSAMPLING One-pixel ENU plane sampling in metres per pixel.

            arguments
                camera (1, 1) PinholeCamera
                p (:, 2) double {mustBeReal}
                z (1, 1) double {mustBeFinite}
            end

            [x0, v0] = camera.imageToWorldAtHeight(p, z);
            [xx, vx] = camera.imageToWorldAtHeight(p + [1, 0], z);
            [xy, vy] = camera.imageToWorldAtHeight(p + [0, 1], z);
            valid = v0 & vx & vy;
            sx = vecnorm(xx - x0, 2, 2);
            sy = vecnorm(xy - x0, 2, 2);
            sg = sqrt(sx .* sy);
            sx(~valid) = NaN;
            sy(~valid) = NaN;
            sg(~valid) = NaN;
        end
    end

    methods (Static, Access = private)
        function [w, valid] = apply(h, p)
            q = [p, ones(size(p, 1), 1)] * h.';
            d = q(:, 3);
            valid = all(isfinite(p), 2) & all(isfinite(q), 2) ...
                & abs(d) > eps(max(1, abs(d)));
            w = q(:, 1:2) ./ d;
            w(~valid, :) = NaN;
        end
    end
end
