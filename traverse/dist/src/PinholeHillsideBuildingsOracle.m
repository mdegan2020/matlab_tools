classdef PinholeHillsideBuildingsOracle
    %PINHOLEHILLSIDEBUILDINGSORACLE Truth for curved terrain and buildings.
    %
    % Terrain is the world-coordinate quadratic height field
    %
    %   Z(X,Y) = Z0 + s*[X;Y] + q*||(X,Y)-c||^2.
    %
    % Each row of Buildings is [centerE,centerN,widthE,depthN,height] in
    % metres. Footprints are aligned with ENU east/north. Roofs are
    % horizontal at max terrain elevation below the footprint plus height;
    % walls are vertical in local Z. Pixels are one-based
    % [x,y]=[column,row], and world coordinates are ENU [X,Y,Z] metres.
    %
    % Traceability: algorithm description Secs. 2.1, 10.2, 11.2, and 13;
    % Eqs. (1)-(2), (52), and the facade/depth-discontinuity study cases.

    methods (Static)
        function [z, g] = terrainHeight( ...
                xy, z0, s, q, options)
            %TERRAINHEIGHT Evaluate height and [dZ/dE,dZ/dN].

            arguments
                xy (:, 2) double {mustBeReal}
                z0 (1, 1) double {mustBeFinite}
                s (1, 2) double {mustBeFinite}
                q (1, 1) double {mustBeFinite}
                options.CurvatureCenterENU (1, 2) double ...
                    {mustBeFinite} = [0, 0]
            end

            d = xy - options.CurvatureCenterENU;
            z = z0 + xy * s.' + q .* sum(d .^ 2, 2);
            if nargout > 1
                g = s + 2 .* q .* d;
                g(~isfinite(z), :) = NaN;
            end
        end

        function z = roofHeights(buildings, z0, s, q, options)
            %ROOFHEIGHTS Return one flat-roof elevation per building.

            arguments
                buildings (:, 5) double ...
                    {mustBeFinite, mustBeValidBuildings}
                z0 (1, 1) double {mustBeFinite}
                s (1, 2) double {mustBeFinite}
                q (1, 1) double {mustBeFinite}
                options.CurvatureCenterENU (1, 2) double ...
                    {mustBeFinite} = [0, 0]
            end

            dx = buildings(:, 3) ./ 2;
            dy = buildings(:, 4) ./ 2;
            x = [buildings(:, 1) - dx, buildings(:, 1) + dx, ...
                buildings(:, 1) - dx, buildings(:, 1) + dx];
            y = [buildings(:, 2) - dy, buildings(:, 2) - dy, ...
                buildings(:, 2) + dy, buildings(:, 2) + dy];
            zc = PinholeHillsideBuildingsOracle.terrainHeight( ...
                [x(:), y(:)], z0, s, q, ...
                CurvatureCenterENU=options.CurvatureCenterENU);
            zc = reshape(zc, size(buildings, 1), 4);
            z = max(zc, [], 2) + buildings(:, 5);
        end

        function [world, z, valid, kind, buildingIndex] = intersect( ...
                camera, p, z0, s, q, buildings, options)
            %INTERSECT Return the nearest terrain, roof, or wall hit.
            % kind is 1=terrain, 2=roof, 3=east/west wall, 4=north/south
            % wall. buildingIndex is zero for terrain.

            arguments
                camera (1, 1) PinholeCamera
                p (:, 2) double {mustBeReal}
                z0 (1, 1) double {mustBeFinite}
                s (1, 2) double {mustBeFinite}
                q (1, 1) double {mustBeFinite}
                buildings (:, 5) double ...
                    {mustBeFinite, mustBeValidBuildings}
                options.CurvatureCenterENU (1, 2) double ...
                    {mustBeFinite} = [0, 0]
            end

            n = size(p, 1);
            r = [p, ones(n, 1)] / camera.K.';
            d = r * camera.R;
            [world, a, valid] = ...
                PinholeHillsideBuildingsOracle.intersectTerrain( ...
                camera, p, d, z0, s, q, options.CurvatureCenterENU);
            kind = zeros(n, 1, "uint8");
            kind(valid) = 1;
            buildingIndex = zeros(n, 1, "uint16");
            zr = PinholeHillsideBuildingsOracle.roofHeights( ...
                buildings, z0, s, q, ...
                CurvatureCenterENU=options.CurvatureCenterENU);

            for k = 1:size(buildings, 1)
                b = buildings(k, :);
                xlim = b(1) + 0.5 .* b(3) .* [-1, 1];
                ylim = b(2) + 0.5 .* b(4) .* [-1, 1];

                ar = (zr(k) - camera.C(3)) ./ d(:, 3);
                wr = camera.C + ar .* d;
                vr = isfinite(ar) & ar > 0 ...
                    & wr(:, 1) >= xlim(1) & wr(:, 1) <= xlim(2) ...
                    & wr(:, 2) >= ylim(1) & wr(:, 2) <= ylim(2);
                [world, a, valid, kind, buildingIndex] = ...
                    PinholeHillsideBuildingsOracle.select( ...
                    world, a, valid, kind, buildingIndex, wr, ar, vr, ...
                    2, k);

                for x = xlim
                    aw = (x - camera.C(1)) ./ d(:, 1);
                    ww = camera.C + aw .* d;
                    zt = PinholeHillsideBuildingsOracle.terrainHeight( ...
                        ww(:, 1:2), z0, s, q, ...
                        CurvatureCenterENU=options.CurvatureCenterENU);
                    vw = isfinite(aw) & aw > 0 ...
                        & ww(:, 2) >= ylim(1) & ww(:, 2) <= ylim(2) ...
                        & ww(:, 3) >= zt & ww(:, 3) <= zr(k);
                    [world, a, valid, kind, buildingIndex] = ...
                        PinholeHillsideBuildingsOracle.select( ...
                        world, a, valid, kind, buildingIndex, ...
                        ww, aw, vw, 3, k);
                end

                for y = ylim
                    aw = (y - camera.C(2)) ./ d(:, 2);
                    ww = camera.C + aw .* d;
                    zt = PinholeHillsideBuildingsOracle.terrainHeight( ...
                        ww(:, 1:2), z0, s, q, ...
                        CurvatureCenterENU=options.CurvatureCenterENU);
                    vw = isfinite(aw) & aw > 0 ...
                        & ww(:, 1) >= xlim(1) & ww(:, 1) <= xlim(2) ...
                        & ww(:, 3) >= zt & ww(:, 3) <= zr(k);
                    [world, a, valid, kind, buildingIndex] = ...
                        PinholeHillsideBuildingsOracle.select( ...
                        world, a, valid, kind, buildingIndex, ...
                        ww, aw, vw, 4, k);
                end
            end

            z = world(:, 3);
            world(~valid, :) = NaN;
            z(~valid) = NaN;
        end

        function [w, geometricValid, inside, movingVisible] = ...
                correspondence(referenceCamera, movingCamera, p, ...
                z0, s, q, buildings, options)
            %CORRESPONDENCE Project reference-visible points to image 2.

            arguments
                referenceCamera (1, 1) PinholeCamera
                movingCamera (1, 1) PinholeCamera
                p (:, 2) double {mustBeReal}
                z0 (1, 1) double {mustBeFinite}
                s (1, 2) double {mustBeFinite}
                q (1, 1) double {mustBeFinite}
                buildings (:, 5) double ...
                    {mustBeFinite, mustBeValidBuildings}
                options.CurvatureCenterENU (1, 2) double ...
                    {mustBeFinite} = [0, 0]
                options.VisibilityToleranceMetres (1, 1) double ...
                    {mustBeFinite, mustBePositive} = 1e-5
            end

            [world, ~, vr] = ...
                PinholeHillsideBuildingsOracle.intersect( ...
                referenceCamera, p, z0, s, q, buildings, ...
                CurvatureCenterENU=options.CurvatureCenterENU);
            [w, vm] = movingCamera.worldToImage(world);
            geometricValid = vr & vm;
            inside = geometricValid & movingCamera.isInsideImage(w);
            [visibleWorld, ~, vv] = ...
                PinholeHillsideBuildingsOracle.intersect( ...
                movingCamera, w, z0, s, q, buildings, ...
                CurvatureCenterENU=options.CurvatureCenterENU);
            same = vecnorm(visibleWorld - world, 2, 2) ...
                <= options.VisibilityToleranceMetres;
            movingVisible = inside & vv & same;
            w(~geometricValid, :) = NaN;
        end
    end

    methods (Static, Access = private)
        function [world, a, valid] = intersectTerrain( ...
                camera, p, d, z0, s, q, c)
            dc = camera.C(1:2) - c;
            qa = q .* sum(d(:, 1:2) .^ 2, 2);
            qb = d(:, 1:2) * s.' ...
                + 2 .* q .* (d(:, 1:2) * dc.') - d(:, 3);
            qc = z0 + camera.C(1:2) * s.' ...
                + q .* sum(dc .^ 2) - camera.C(3);
            a = nan(size(qb));
            linear = abs(qa) <= eps(max(1, abs(qa)));
            a(linear) = -qc ./ qb(linear);

            curved = ~linear;
            disc = qb .^ 2 - 4 .* qa .* qc;
            rootValid = curved & disc >= 0 & isfinite(disc);
            sd = sqrt(max(disc(rootValid), 0));
            b = qb(rootValid);
            aq = qa(rootValid);
            t = -0.5 .* (b + sign(b + (b == 0)) .* sd);
            r1 = t ./ aq;
            r2 = qc ./ t;
            r1(r1 <= 0 | ~isfinite(r1)) = inf;
            r2(r2 <= 0 | ~isfinite(r2)) = inf;
            ar = min(r1, r2);
            ar(~isfinite(ar)) = NaN;
            a(rootValid) = ar;

            world = camera.C + a .* d;
            z = PinholeHillsideBuildingsOracle.terrainHeight( ...
                world(:, 1:2), z0, s, q, CurvatureCenterENU=c);
            valid = all(isfinite(p), 2) & all(isfinite(d), 2) ...
                & isfinite(a) & a > 0 & all(isfinite(world), 2) ...
                & abs(world(:, 3) - z) <= 1e-7;
            world(~valid, :) = NaN;
            a(~valid) = NaN;
        end

        function [world, a, valid, kind, index] = select( ...
                world, a, valid, kind, index, candidate, ca, cv, ck, ci)
            take = cv & (~valid | ca < a);
            world(take, :) = candidate(take, :);
            a(take) = ca(take);
            valid(take) = true;
            kind(take) = uint8(ck);
            index(take) = uint16(ci);
        end
    end
end

function mustBeValidBuildings(x)
if any(x(:, 3:5) <= 0, "all")
    error("PinholeHillsideBuildingsOracle:InvalidBuildingDimensions", ...
        "Building width, depth, and height must be positive metres.");
end
end
