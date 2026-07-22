classdef PinholeSincOracle
    %PINHOLESINCORACLE Independent truth for a smooth radial sinc surface.
    %
    % The world-coordinate surface is
    %
    %   Z(X,Y) = Z0 + A sinc(r/L),
    %   r = hypot(X-Xc,Y-Yc),
    %   sinc(u) = sin(pi*u)/(pi*u).
    %
    % Pixels are one-based [x,y]=[column,row]. World coordinates are local
    % ENU [X,Y,Z] metres. Ray intersections use an independently coded
    % height-bracket bisection and do not call SyntheticPinholeRenderer or
    % HeightSweepGeometry.
    %
    % Traceability: algorithm description Secs. 2.1, 10.2, 11.2, and 14.1;
    % Eqs. (1)-(2), (52), and Algorithm 1 truth diagnostics.

    methods (Static)
        function [z, slopeENU] = surfaceHeight( ...
                worldXY, baseHeight, amplitude, lobeSpacing, centerENU)
            %SURFACEHEIGHT Evaluate Z and [dZ/dE,dZ/dN] in metres/metre.

            arguments
                worldXY (:, 2) double {mustBeReal}
                baseHeight (1, 1) double {mustBeFinite}
                amplitude (1, 1) double {mustBeFinite, mustBePositive}
                lobeSpacing (1, 1) double {mustBeFinite, mustBePositive}
                centerENU (1, 2) double {mustBeFinite} = [0, 0]
            end

            d = worldXY - centerENU;
            r = vecnorm(d, 2, 2);
            u = r ./ lobeSpacing;
            s = ones(size(u));
            nz = u ~= 0;
            t = pi .* u(nz);
            s(nz) = sin(t) ./ t;
            z = baseHeight + amplitude .* s;

            if nargout > 1
                ds = zeros(size(u));
                ds(nz) = pi .* (t .* cos(t) - sin(t)) ./ (t .^ 2);
                radial = amplitude .* ds ./ lobeSpacing;
                unit = zeros(size(d));
                unit(nz, :) = d(nz, :) ./ r(nz);
                slopeENU = radial .* unit;
                slopeENU(~isfinite(z), :) = NaN;
            end
        end

        function [world, z, valid] = intersect( ...
                camera, p, baseHeight, amplitude, lobeSpacing, options)
            %INTERSECT Find the unique camera-ray/sinc-surface intersection.

            arguments
                camera (1, 1) PinholeCamera
                p (:, 2) double {mustBeReal}
                baseHeight (1, 1) double {mustBeFinite}
                amplitude (1, 1) double {mustBeFinite, mustBePositive}
                lobeSpacing (1, 1) double {mustBeFinite, mustBePositive}
                options.CenterENU (1, 2) double {mustBeFinite} = [0, 0]
                options.BisectionIterations (1, 1) double ...
                    {mustBeFinite, mustBeInteger, mustBePositive} = 48
                options.SurfaceToleranceMetres (1, 1) double ...
                    {mustBeFinite, mustBePositive} = 1e-9
            end

            n = size(p, 1);
            q = [p, ones(n, 1)] / camera.K.';
            d = q * camera.R;
            dz = d(:, 3);
            valid = all(isfinite(p), 2) & all(isfinite(d), 2) ...
                & abs(dz) > eps(max(1, abs(dz)));
            lo = repmat(baseHeight - amplitude, n, 1);
            hi = repmat(baseHeight + amplitude, n, 1);

            for k = 1:options.BisectionIterations
                mid = (lo + hi) ./ 2;
                a = (mid - camera.C(3)) ./ dz;
                xy = camera.C(1:2) + a .* d(:, 1:2);
                surface = PinholeSincOracle.surfaceHeight( ...
                    xy, baseHeight, amplitude, lobeSpacing, ...
                    options.CenterENU);
                belowSurface = surface >= mid;
                lo(belowSurface) = mid(belowSurface);
                hi(~belowSurface) = mid(~belowSurface);
            end

            z = (lo + hi) ./ 2;
            a = (z - camera.C(3)) ./ dz;
            world = camera.C + a .* d;
            surface = PinholeSincOracle.surfaceHeight( ...
                world(:, 1:2), baseHeight, amplitude, lobeSpacing, ...
                options.CenterENU);
            valid = valid & isfinite(a) & a > 0 ...
                & all(isfinite(world), 2) & isfinite(surface) ...
                & abs(surface - z) <= options.SurfaceToleranceMetres;
            world(~valid, :) = NaN;
            z(~valid) = NaN;
        end

        function [w, geometricValid, inside, movingVisible] = ...
                correspondence(referenceCamera, movingCamera, p, ...
                baseHeight, amplitude, lobeSpacing, options)
            %CORRESPONDENCE Project reference-visible sinc points to image 2.

            arguments
                referenceCamera (1, 1) PinholeCamera
                movingCamera (1, 1) PinholeCamera
                p (:, 2) double {mustBeReal}
                baseHeight (1, 1) double {mustBeFinite}
                amplitude (1, 1) double {mustBeFinite, mustBePositive}
                lobeSpacing (1, 1) double {mustBeFinite, mustBePositive}
                options.CenterENU (1, 2) double {mustBeFinite} = [0, 0]
                options.VisibilityToleranceMetres (1, 1) double ...
                    {mustBeFinite, mustBePositive} = 1e-5
            end

            [world, ~, vr] = PinholeSincOracle.intersect( ...
                referenceCamera, p, baseHeight, amplitude, lobeSpacing, ...
                CenterENU=options.CenterENU);
            [w, vm] = movingCamera.worldToImage(world);
            geometricValid = vr & vm;
            inside = geometricValid & movingCamera.isInsideImage(w);
            [visibleWorld, ~, vv] = PinholeSincOracle.intersect( ...
                movingCamera, w, baseHeight, amplitude, lobeSpacing, ...
                CenterENU=options.CenterENU);
            same = vecnorm(visibleWorld - world, 2, 2) ...
                <= options.VisibilityToleranceMetres;
            movingVisible = inside & vv & same;
            w(~geometricValid, :) = NaN;
        end
    end
end
