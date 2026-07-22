classdef PinholeStepOracle
    %PINHOLESTEPORACLE Independent truth for a discontinuous 2.5-D step.
    %
    % The surface contains two horizontal half-planes. The low half satisfies
    % dot([X,Y],direction)<position; the high half is the complementary side.
    % If a ray intersects neither half-plane, it would strike the omitted
    % vertical wall and is explicitly invalid. The nearest valid intersection
    % is visible. Moving-view occlusion is evaluated by tracing the projected
    % ray back through the same surface.
    %
    % Traceability: algorithm description Secs. 10.2, 11.2, and 13;
    % synthetic piecewise-plane and depth-discontinuity failure cases.

    methods (Static)
        function [world, z, valid] = intersect( ...
                camera, p, baseHeight, stepHeight, directionENU, position)
            %INTERSECT Find the first visible horizontal half-plane.

            arguments
                camera (1, 1) PinholeCamera
                p (:, 2) double {mustBeReal}
                baseHeight (1, 1) double {mustBeFinite}
                stepHeight (1, 1) double ...
                    {mustBeFinite, mustBeNonnegative}
                directionENU (1, 2) double {mustBeFinite, mustBeUnitVector}
                position (1, 1) double {mustBeFinite} = 0
            end

            [low, al, vl] = PinholeStepOracle.intersectHeight( ...
                camera, p, baseHeight);
            [high, ah, vh] = PinholeStepOracle.intersectHeight( ...
                camera, p, baseHeight + stepHeight);
            ul = low(:, 1:2) * directionENU.';
            uh = high(:, 1:2) * directionENU.';
            vl = vl & ul < position;
            vh = vh & uh >= position;
            chooseHigh = vh & (~vl | ah < al);
            chooseLow = vl & ~chooseHigh;
            valid = chooseLow | chooseHigh;
            world = nan(size(p, 1), 3);
            z = nan(size(p, 1), 1);
            world(chooseLow, :) = low(chooseLow, :);
            world(chooseHigh, :) = high(chooseHigh, :);
            z(chooseLow) = baseHeight;
            z(chooseHigh) = baseHeight + stepHeight;
        end

        function [w, geometricValid, inside, movingVisible] = ...
                correspondence(referenceCamera, movingCamera, p, ...
                baseHeight, stepHeight, directionENU, options)
            %CORRESPONDENCE Project reference-visible step points to image 2.

            arguments
                referenceCamera (1, 1) PinholeCamera
                movingCamera (1, 1) PinholeCamera
                p (:, 2) double {mustBeReal}
                baseHeight (1, 1) double {mustBeFinite}
                stepHeight (1, 1) double ...
                    {mustBeFinite, mustBeNonnegative}
                directionENU (1, 2) double {mustBeFinite, mustBeUnitVector}
                options.PositionMetres (1, 1) double {mustBeFinite} = 0
                options.VisibilityToleranceMetres (1, 1) double ...
                    {mustBeFinite, mustBePositive} = 1e-6
            end

            [world, ~, vr] = PinholeStepOracle.intersect( ...
                referenceCamera, p, baseHeight, stepHeight, directionENU, ...
                options.PositionMetres);
            [w, vm] = movingCamera.worldToImage(world);
            geometricValid = vr & vm;
            inside = geometricValid & movingCamera.isInsideImage(w);
            [visibleWorld, ~, vv] = PinholeStepOracle.intersect( ...
                movingCamera, w, baseHeight, stepHeight, directionENU, ...
                options.PositionMetres);
            same = vecnorm(visibleWorld - world, 2, 2) ...
                <= options.VisibilityToleranceMetres;
            movingVisible = inside & vv & same;
            w(~geometricValid, :) = NaN;
        end
    end

    methods (Static, Access = private)
        function [world, a, valid] = intersectHeight(camera, p, z)
            q = [p, ones(size(p, 1), 1)] / camera.K.';
            d = q * camera.R;
            dz = d(:, 3);
            a = (z - camera.C(3)) ./ dz;
            world = camera.C + a .* d;
            valid = all(isfinite(p), 2) & all(isfinite(d), 2) ...
                & isfinite(dz) & abs(dz) > eps(max(1, abs(dz))) ...
                & isfinite(a) & a > 0;
            world(~valid, :) = NaN;
            a(~valid) = NaN;
        end
    end
end

function mustBeUnitVector(x)
if abs(norm(x) - 1) > 64 * eps
    error("PinholeStepOracle:DirectionMustBeUnitVector", ...
        "directionENU must be a unit vector.");
end
end
