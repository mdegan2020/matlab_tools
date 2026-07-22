classdef SyntheticPinholeRenderer
    %SYNTHETICPINHOLERENDERER Deterministic Phase A surface-image renderer.
    %
    % Two pinhole cameras independently sample one continuous world-surface
    % texture over a plane, two-level step, radial normalized sinc, or a
    % curved hillside with vertical-walled buildings. The texture may be
    % one of the deterministic analytic controls or a
    % RasterSurfaceTexture supplied by the caller. Rendering is
    % supersampled, Gaussian filtered in detector-pixel units, block averaged,
    % and quantized to 10- or 12-bit values stored in uint16. Display
    % conversion is intentionally outside this class.
    %
    % Traceability: algorithm description Secs. 2.1, 10.2, 11.2, and 14.1;
    % Algorithm 1 inputs and the synthetic-geometry program in Sec. 10.2.

    properties (SetAccess = private)
        Identifier (1, 1) string
        Suite (1, 1) string
        ReferenceTimestamp (1, 1) string
        MovingTimestamp (1, 1) string
        ImageSize (1, 2) double
        BitDepth (1, 1) double
        HorizontalFieldOfViewDegrees (1, 1) double
        CenterGsdMetres (1, 1) double
        MeanObliquityDegrees (1, 1) double
        ConvergenceDegrees (1, 1) double
        LookAzimuthDegrees (1, 1) double
        ReferenceRollDegrees (1, 1) double
        MovingRollDegrees (1, 1) double
        TrueHeightMetres (1, 1) double
        AlongTrackSlopeDegrees (1, 1) double
        CrossTrackSlopeDegrees (1, 1) double
        SurfaceSlopeENU (1, 2) double
        SurfaceType (1, 1) string
        StepHeightMetres (1, 1) double
        StepDirection (1, 1) string
        StepDirectionENU (1, 2) double
        StepPositionMetres (1, 1) double
        SincAmplitudeMetres (1, 1) double
        SincLobeSpacingMetres (1, 1) double
        SincCenterENU (1, 2) double
        TerrainCurvaturePerMetre (1, 1) double
        CurvatureCenterENU (1, 2) double
        Buildings (:, 5) double
        SearchRangeMetres (1, 2) double
        TargetMotionPerLabelPixels (1, 1) double
        Supersample (1, 1) double
        PsfSigmaPixels (1, 1) double
        TextureSeed (1, 1) double
        TextureType (1, 1) string
        IntrinsicMatrix (3, 3) double
        SlantRangeMetres (1, 1) double
        ReferenceCamera
        MovingCamera
    end

    methods
        function obj = SyntheticPinholeRenderer(identifier, imageSize, options)
            arguments
                identifier (1, 1) string
                imageSize (1, 2) double ...
                    {mustBeFinite, mustBeInteger, mustBePositive}
                options.Suite (1, 1) string = "development"
                options.ReferenceTimestamp (1, 1) string = ...
                    "2026-01-01T00:00:00Z"
                options.MovingTimestamp (1, 1) string = ...
                    "2026-01-01T00:00:01Z"
                options.BitDepth (1, 1) double ...
                    {mustBeMember(options.BitDepth, [10, 12])} = 10
                options.HorizontalFieldOfViewDegrees (1, 1) double ...
                    {mustBeFinite, mustBePositive, ...
                    mustBeLessThan(options.HorizontalFieldOfViewDegrees, 180)} ...
                    = 1
                options.CenterGsdMetres (1, 1) double ...
                    {mustBeFinite, mustBePositive} = 0.5
                options.MeanObliquityDegrees (1, 1) double ...
                    {mustBeFinite, mustBeNonnegative, ...
                    mustBeLessThan(options.MeanObliquityDegrees, 90)} = 55
                options.ConvergenceDegrees (1, 1) double ...
                    {mustBeFinite, mustBePositive, ...
                    mustBeLessThan(options.ConvergenceDegrees, 180)} = 1
                options.LookAzimuthDegrees (1, 1) double ...
                    {mustBeFinite} = 90
                options.ReferenceRollDegrees (1, 1) double ...
                    {mustBeFinite} = 0
                options.MovingRollDegrees (1, 1) double ...
                    {mustBeFinite} = 0
                options.TrueHeightMetres (1, 1) double {mustBeFinite} = 0
                options.AlongTrackSlopeDegrees (1, 1) double ...
                    {mustBeFinite, ...
                    mustBeGreaterThan(options.AlongTrackSlopeDegrees, -90), ...
                    mustBeLessThan(options.AlongTrackSlopeDegrees, 90)} = 0
                options.CrossTrackSlopeDegrees (1, 1) double ...
                    {mustBeFinite, ...
                    mustBeGreaterThan(options.CrossTrackSlopeDegrees, -90), ...
                    mustBeLessThan(options.CrossTrackSlopeDegrees, 90)} = 0
                options.SurfaceType (1, 1) string ...
                    {mustBeMember(options.SurfaceType, ...
                    ["plane", "step", "radial-sinc", ...
                    "hillside-buildings"])} ...
                    = "plane"
                options.StepHeightMetres (1, 1) double ...
                    {mustBeFinite, mustBeNonnegative} = 0
                options.StepDirection (1, 1) string ...
                    {mustBeMember(options.StepDirection, ...
                    ["along-track", "cross-track"])} = "along-track"
                options.StepPositionMetres (1, 1) double {mustBeFinite} = 0
                options.SincAmplitudeMetres (1, 1) double ...
                    {mustBeFinite, mustBePositive} = 60
                options.SincLobeSpacingMetres (1, 1) double ...
                    {mustBeFinite, mustBePositive} = 110
                options.SincCenterENU (1, 2) double {mustBeFinite} = [0, 0]
                options.TerrainCurvaturePerMetre (1, 1) double ...
                    {mustBeFinite} = 0
                options.CurvatureCenterENU (1, 2) double ...
                    {mustBeFinite} = [0, 0]
                options.Buildings (:, 5) double ...
                    {mustBeFinite, mustBeValidBuildingMatrix} = zeros(0, 5)
                options.SearchRangeMetres (1, 2) double ...
                    {mustBeFinite, mustBeIncreasing} = [-100, 100]
                options.TargetMotionPerLabelPixels (1, 1) double ...
                    {mustBeFinite, mustBePositive} = 0.25
                options.Supersample (1, 1) double ...
                    {mustBeFinite, mustBeInteger, mustBePositive} = 4
                options.PsfSigmaPixels (1, 1) double ...
                    {mustBeFinite, mustBeNonnegative} = 0.65
                options.TextureSeed (1, 1) double ...
                    {mustBeFinite, mustBeInteger, mustBeNonnegative} = 20260718
                options.TextureType (1, 1) string ...
                    {mustBeMember(options.TextureType, ...
                    ["natural", "single-edge", "corner", "grid", ...
                    "repeated", "low-texture"])} = "natural"
            end

            obj.Identifier = identifier;
            obj.Suite = options.Suite;
            obj.ReferenceTimestamp = options.ReferenceTimestamp;
            obj.MovingTimestamp = options.MovingTimestamp;
            obj.ImageSize = imageSize;
            obj.BitDepth = options.BitDepth;
            obj.HorizontalFieldOfViewDegrees = ...
                options.HorizontalFieldOfViewDegrees;
            obj.CenterGsdMetres = options.CenterGsdMetres;
            obj.MeanObliquityDegrees = options.MeanObliquityDegrees;
            obj.ConvergenceDegrees = options.ConvergenceDegrees;
            obj.LookAzimuthDegrees = options.LookAzimuthDegrees;
            obj.ReferenceRollDegrees = options.ReferenceRollDegrees;
            obj.MovingRollDegrees = options.MovingRollDegrees;
            obj.TrueHeightMetres = options.TrueHeightMetres;
            obj.AlongTrackSlopeDegrees = options.AlongTrackSlopeDegrees;
            obj.CrossTrackSlopeDegrees = options.CrossTrackSlopeDegrees;
            h = [sind(obj.LookAzimuthDegrees), ...
                cosd(obj.LookAzimuthDegrees)];
            c = [cosd(obj.LookAzimuthDegrees), ...
                -sind(obj.LookAzimuthDegrees)];
            obj.SurfaceSlopeENU = tand(obj.AlongTrackSlopeDegrees) .* h ...
                + tand(obj.CrossTrackSlopeDegrees) .* c;
            obj.SurfaceType = options.SurfaceType;
            obj.StepHeightMetres = options.StepHeightMetres;
            obj.StepDirection = options.StepDirection;
            if obj.StepDirection == "along-track"
                obj.StepDirectionENU = h;
            else
                obj.StepDirectionENU = c;
            end
            obj.StepPositionMetres = options.StepPositionMetres;
            obj.SincAmplitudeMetres = options.SincAmplitudeMetres;
            obj.SincLobeSpacingMetres = options.SincLobeSpacingMetres;
            obj.SincCenterENU = options.SincCenterENU;
            obj.TerrainCurvaturePerMetre = ...
                options.TerrainCurvaturePerMetre;
            obj.CurvatureCenterENU = options.CurvatureCenterENU;
            obj.Buildings = options.Buildings;
            obj.SearchRangeMetres = options.SearchRangeMetres;
            obj.TargetMotionPerLabelPixels = ...
                options.TargetMotionPerLabelPixels;
            obj.Supersample = options.Supersample;
            obj.PsfSigmaPixels = options.PsfSigmaPixels;
            obj.TextureSeed = options.TextureSeed;
            obj.TextureType = options.TextureType;

            [obj.ReferenceCamera, obj.MovingCamera, ...
                obj.IntrinsicMatrix, obj.SlantRangeMetres] = ...
                obj.createCameras;
        end

        function pair = renderPair(obj, options)
            %RENDERPAIR Independently render the reference and moving images.

            arguments
                obj (1, 1) SyntheticPinholeRenderer
                options.TextureType (1, 1) string ...
                    {mustBeMember(options.TextureType, ...
                    ["natural", "single-edge", "corner", "grid", ...
                    "repeated", "low-texture"])} = obj.TextureType
            end

            [r, rv] = obj.renderCamera(obj.ReferenceCamera, ...
                TextureType=options.TextureType);
            [m, mv] = obj.renderCamera(obj.MovingCamera, ...
                TextureType=options.TextureType);
            pair = struct( ...
                "Identifier", obj.Identifier, ...
                "ReferenceTimestamp", obj.ReferenceTimestamp, ...
                "MovingTimestamp", obj.MovingTimestamp, ...
                "ReferenceImage", r, ...
                "MovingImage", m, ...
                "ReferenceValid", rv, ...
                "MovingValid", mv, ...
                "BitDepth", obj.BitDepth, ...
                "TextureType", options.TextureType, ...
                "TrueHeightMetres", obj.TrueHeightMetres, ...
                "SurfaceSlopeENU", obj.SurfaceSlopeENU, ...
                "SurfaceNormalENU", obj.constantSurfaceNormal, ...
                "SurfaceType", obj.SurfaceType, ...
                "StepHeightMetres", obj.StepHeightMetres, ...
                "StepDirection", obj.StepDirection, ...
                "StepDirectionENU", obj.StepDirectionENU, ...
                "StepPositionMetres", obj.StepPositionMetres, ...
                "SincAmplitudeMetres", obj.SincAmplitudeMetres, ...
                "SincLobeSpacingMetres", obj.SincLobeSpacingMetres, ...
                "SincCenterENU", obj.SincCenterENU, ...
                "TerrainCurvaturePerMetre", ...
                obj.TerrainCurvaturePerMetre, ...
                "CurvatureCenterENU", obj.CurvatureCenterENU, ...
                "Buildings", obj.Buildings);
        end

        function pair = renderPairWithTexture(obj, texture)
            %RENDERPAIRWITHTEXTURE Render both views from a raster texture.

            arguments
                obj (1, 1) SyntheticPinholeRenderer
                texture (1, 1) RasterSurfaceTexture
            end

            [r, rv] = obj.renderCameraWithTexture( ...
                obj.ReferenceCamera, texture);
            [m, mv] = obj.renderCameraWithTexture( ...
                obj.MovingCamera, texture);
            pair = struct( ...
                "Identifier", obj.Identifier, ...
                "ReferenceTimestamp", obj.ReferenceTimestamp, ...
                "MovingTimestamp", obj.MovingTimestamp, ...
                "ReferenceImage", r, ...
                "MovingImage", m, ...
                "ReferenceValid", rv, ...
                "MovingValid", mv, ...
                "BitDepth", obj.BitDepth, ...
                "TextureType", "raster", ...
                "TextureIdentifier", texture.Identifier, ...
                "TrueHeightMetres", obj.TrueHeightMetres, ...
                "SurfaceSlopeENU", obj.SurfaceSlopeENU, ...
                "SurfaceNormalENU", obj.constantSurfaceNormal, ...
                "SurfaceType", obj.SurfaceType, ...
                "StepHeightMetres", obj.StepHeightMetres, ...
                "StepDirection", obj.StepDirection, ...
                "StepDirectionENU", obj.StepDirectionENU, ...
                "StepPositionMetres", obj.StepPositionMetres, ...
                "SincAmplitudeMetres", obj.SincAmplitudeMetres, ...
                "SincLobeSpacingMetres", obj.SincLobeSpacingMetres, ...
                "SincCenterENU", obj.SincCenterENU, ...
                "TerrainCurvaturePerMetre", ...
                obj.TerrainCurvaturePerMetre, ...
                "CurvatureCenterENU", obj.CurvatureCenterENU, ...
                "Buildings", obj.Buildings);
        end

        function [image, valid] = renderCamera(obj, camera, options)
            %RENDERCAMERA Sample the continuous plane through one camera.

            arguments
                obj (1, 1) SyntheticPinholeRenderer
                camera (1, 1) PinholeCamera
                options.TextureType (1, 1) string ...
                    {mustBeMember(options.TextureType, ...
                    ["natural", "single-edge", "corner", "grid", ...
                    "repeated", "low-texture"])} = obj.TextureType
            end

            [image, valid] = obj.renderCameraCore( ...
                camera, options.TextureType, []);
        end

        function [image, valid] = renderCameraWithTexture( ...
                obj, camera, texture)
            %RENDERCAMERAWITHTEXTURE Render one view from a raster texture.

            arguments
                obj (1, 1) SyntheticPinholeRenderer
                camera (1, 1) PinholeCamera
                texture (1, 1) RasterSurfaceTexture
            end

            [image, valid] = obj.renderCameraCore(camera, "", texture);
        end

        function [world, valid, kind] = surfaceIntersection(obj, camera, p)
            %SURFACEINTERSECTION Intersect rays with the configured surface.

            arguments
                obj (1, 1) SyntheticPinholeRenderer
                camera (1, 1) PinholeCamera
                p (:, 2) double {mustBeReal}
            end

            [world, valid, kind] = obj.intersectSurface(camera, p);
        end
    end

    methods (Static)
        function obj = fromJson(path)
            %FROMJSON Construct a renderer from a committed fixture file.

            arguments
                path (1, 1) string {mustBeFile}
            end

            c = jsondecode(fileread(path));
            obj = SyntheticPinholeRenderer( ...
                string(c.identifier), double(c.imageSize), ...
                Suite=string(c.suite), ...
                ReferenceTimestamp=string(c.referenceTimestamp), ...
                MovingTimestamp=string(c.movingTimestamp), ...
                BitDepth=double(c.bitDepth), ...
                HorizontalFieldOfViewDegrees= ...
                double(c.horizontalFieldOfViewDegrees), ...
                CenterGsdMetres=double(c.centerGsdMetres), ...
                MeanObliquityDegrees=double(c.meanObliquityDegrees), ...
                ConvergenceDegrees=double(c.convergenceDegrees), ...
                LookAzimuthDegrees=double(c.lookAzimuthDegrees), ...
                ReferenceRollDegrees=double(c.referenceRollDegrees), ...
                MovingRollDegrees=double(c.movingRollDegrees), ...
                TrueHeightMetres=double(c.trueHeightMetres), ...
                AlongTrackSlopeDegrees= ...
                double(c.alongTrackSlopeDegrees), ...
                CrossTrackSlopeDegrees= ...
                double(c.crossTrackSlopeDegrees), ...
                SurfaceType=string(c.surfaceType), ...
                StepHeightMetres=double(c.stepHeightMetres), ...
                StepDirection=string(c.stepDirection), ...
                StepPositionMetres=double(c.stepPositionMetres), ...
                SincAmplitudeMetres=fieldOr( ...
                c, "sincAmplitudeMetres", 60), ...
                SincLobeSpacingMetres=fieldOr( ...
                c, "sincLobeSpacingMetres", 110), ...
                SincCenterENU=fieldOr(c, "sincCenterENU", [0, 0]), ...
                TerrainCurvaturePerMetre=fieldOr( ...
                c, "terrainCurvaturePerMetre", 0), ...
                CurvatureCenterENU=fieldOr( ...
                c, "curvatureCenterENU", [0, 0]), ...
                Buildings=buildingField(c), ...
                SearchRangeMetres=double(c.searchRangeMetres), ...
                TargetMotionPerLabelPixels= ...
                double(c.targetMotionPerLabelPixels), ...
                Supersample=double(c.supersample), ...
                PsfSigmaPixels=double(c.psfSigmaPixels), ...
                TextureSeed=double(c.textureSeed), ...
                TextureType=string(c.textureType));
        end
    end

    methods (Access = private)
        function [image, valid] = renderCameraCore( ...
                obj, camera, textureType, rasterTexture)
            s = obj.Supersample;
            sigma = obj.PsfSigmaPixels * s;
            [g, radius] = SyntheticPinholeRenderer.gaussianKernel(sigma);
            nr = obj.ImageSize(1) * s;
            nc = obj.ImageSize(2) * s;
            rows = (1 - radius):(nr + radius);
            cols = (1 - radius):(nc + radius);
            y = 0.5 + (rows - 0.5) ./ s;
            x = 0.5 + (cols - 0.5) ./ s;
            [xx, yy] = meshgrid(x, y);
            p = [xx(:), yy(:)];
            [world, rayValid, kind] = obj.intersectSurface(camera, p);
            if isempty(rasterTexture)
                v = SyntheticPinholeRenderer.texture( ...
                    world(:, 1), world(:, 2), obj.TextureSeed, textureType);
            else
                [v, textureValid] = rasterTexture.sample(world(:, 1:2));
                rayValid = rayValid & textureValid;
            end
            if obj.SurfaceType == "hillside-buildings"
                % Stable face-dependent contrast makes the vertical geometry
                % visible without changing its natural raster texture.
                v(kind == 2) = min(1, 1.08 .* v(kind == 2));
                v(kind == 3) = 0.72 .* v(kind == 3);
                v(kind == 4) = 0.82 .* v(kind == 4);
            end
            v(~rayValid) = 0;
            v = reshape(v, size(xx));
            rayValid = reshape(rayValid, size(xx));

            num = conv2(g(:), g(:).', v, "same");
            den = conv2(g(:), g(:).', double(rayValid), "same");
            filtered = num ./ max(den, eps);
            keepRows = radius + (1:nr);
            keepCols = radius + (1:nc);
            filtered = filtered(keepRows, keepCols);
            support = den(keepRows, keepCols);

            filtered = reshape(filtered, s, obj.ImageSize(1), ...
                s, obj.ImageSize(2));
            support = reshape(support, s, obj.ImageSize(1), ...
                s, obj.ImageSize(2));
            detector = reshape(mean(mean(filtered, 1), 3), obj.ImageSize);
            support = reshape(min(min(support, [], 1), [], 3), ...
                obj.ImageSize);
            valid = support >= 1 - 256 * eps;
            detector = min(max(detector, 0), 1);
            levels = 2 ^ obj.BitDepth - 1;
            image = uint16(round(levels .* detector));
            image(~valid) = 0;
        end

        function [world, valid, kind] = intersectSurface(obj, camera, p)
            if obj.SurfaceType == "step"
                [world, valid] = obj.intersectStep(camera, p);
                kind = ones(size(p, 1), 1, "uint8");
                return
            elseif obj.SurfaceType == "radial-sinc"
                [world, valid] = obj.intersectSinc(camera, p);
                kind = ones(size(p, 1), 1, "uint8");
                return
            elseif obj.SurfaceType == "hillside-buildings"
                [world, valid, kind] = ...
                    obj.intersectHillsideBuildings(camera, p);
                return
            end
            q = [p, ones(size(p, 1), 1)] / camera.K.';
            d = q * camera.R;
            n = [-obj.SurfaceSlopeENU, 1].';
            den = d * n;
            num = obj.TrueHeightMetres - camera.C * n;
            a = num ./ den;
            world = camera.C + a .* d;
            valid = all(isfinite(p), 2) & all(isfinite(d), 2) ...
                & isfinite(den) & abs(den) > eps(max(1, abs(den))) ...
                & isfinite(a) & a > 0;
            world(~valid, :) = NaN;
            kind = ones(size(p, 1), 1, "uint8");
        end

        function [world, valid] = intersectStep(obj, camera, p)
            [low, al, vl] = SyntheticPinholeRenderer.intersectHeight( ...
                camera, p, obj.TrueHeightMetres);
            [high, ah, vh] = SyntheticPinholeRenderer.intersectHeight( ...
                camera, p, obj.TrueHeightMetres + obj.StepHeightMetres);
            ul = low(:, 1:2) * obj.StepDirectionENU.';
            uh = high(:, 1:2) * obj.StepDirectionENU.';
            vl = vl & ul < obj.StepPositionMetres;
            vh = vh & uh >= obj.StepPositionMetres;
            chooseHigh = vh & (~vl | ah < al);
            chooseLow = vl & ~chooseHigh;
            valid = chooseLow | chooseHigh;
            world = nan(size(p, 1), 3);
            world(chooseLow, :) = low(chooseLow, :);
            world(chooseHigh, :) = high(chooseHigh, :);
        end

        function [world, valid] = intersectSinc(obj, camera, p)
            % Smooth height-root solve for Z=Z0+A*sinc(r/L).
            % Traceability: algorithm description Secs. 2.1 and 10.2;
            % Eqs. (1)-(2) and the smooth-height-field synthetic program.
            n = size(p, 1);
            q = [p, ones(n, 1)] / camera.K.';
            d = q * camera.R;
            dz = d(:, 3);
            valid = all(isfinite(p), 2) & all(isfinite(d), 2) ...
                & abs(dz) > eps(max(1, abs(dz)));
            lo = repmat(obj.TrueHeightMetres - obj.SincAmplitudeMetres, ...
                n, 1);
            hi = repmat(obj.TrueHeightMetres + obj.SincAmplitudeMetres, ...
                n, 1);

            for k = 1:32
                z = (lo + hi) ./ 2;
                a = (z - camera.C(3)) ./ dz;
                xy = camera.C(1:2) + a .* d(:, 1:2);
                surface = obj.radialSincHeight(xy);
                belowSurface = surface >= z;
                lo(belowSurface) = z(belowSurface);
                hi(~belowSurface) = z(~belowSurface);
            end

            z = (lo + hi) ./ 2;
            a = (z - camera.C(3)) ./ dz;
            world = camera.C + a .* d;
            surface = obj.radialSincHeight(world(:, 1:2));
            valid = valid & isfinite(a) & a > 0 ...
                & all(isfinite(world), 2) & isfinite(surface) ...
                & abs(surface - z) <= 1e-6;
            world(~valid, :) = NaN;
        end

        function z = radialSincHeight(obj, xy)
            d = xy - obj.SincCenterENU;
            u = vecnorm(d, 2, 2) ./ obj.SincLobeSpacingMetres;
            s = ones(size(u));
            nz = u ~= 0;
            t = pi .* u(nz);
            s(nz) = sin(t) ./ t;
            z = obj.TrueHeightMetres + obj.SincAmplitudeMetres .* s;
        end

        function [world, valid, kind] = ...
                intersectHillsideBuildings(obj, camera, p)
            % Exact nearest-hit terrain/box solve for the facade scene.
            % Traceability: algorithm description Secs. 2.1, 10.2, and 13.
            n = size(p, 1);
            r = [p, ones(n, 1)] / camera.K.';
            d = r * camera.R;
            dc = camera.C(1:2) - obj.CurvatureCenterENU;
            qa = obj.TerrainCurvaturePerMetre ...
                .* sum(d(:, 1:2) .^ 2, 2);
            qb = d(:, 1:2) * obj.SurfaceSlopeENU.' ...
                + 2 .* obj.TerrainCurvaturePerMetre ...
                .* (d(:, 1:2) * dc.') - d(:, 3);
            qc = obj.TrueHeightMetres ...
                + camera.C(1:2) * obj.SurfaceSlopeENU.' ...
                + obj.TerrainCurvaturePerMetre .* sum(dc .^ 2) ...
                - camera.C(3);
            a = nan(n, 1);
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
            zt = obj.hillsideHeight(world(:, 1:2));
            valid = all(isfinite(p), 2) & all(isfinite(d), 2) ...
                & isfinite(a) & a > 0 & all(isfinite(world), 2) ...
                & abs(world(:, 3) - zt) <= 1e-6;
            world(~valid, :) = NaN;
            a(~valid) = NaN;
            kind = zeros(n, 1, "uint8");
            kind(valid) = 1;

            zr = obj.buildingRoofHeights;
            for k = 1:size(obj.Buildings, 1)
                bldg = obj.Buildings(k, :);
                xlim = bldg(1) + 0.5 .* bldg(3) .* [-1, 1];
                ylim = bldg(2) + 0.5 .* bldg(4) .* [-1, 1];
                ac = (zr(k) - camera.C(3)) ./ d(:, 3);
                wc = camera.C + ac .* d;
                vc = isfinite(ac) & ac > 0 ...
                    & wc(:, 1) >= xlim(1) & wc(:, 1) <= xlim(2) ...
                    & wc(:, 2) >= ylim(1) & wc(:, 2) <= ylim(2);
                [world, a, valid, kind] = obj.selectSurface( ...
                    world, a, valid, kind, wc, ac, vc, 2);

                for x = xlim
                    ac = (x - camera.C(1)) ./ d(:, 1);
                    wc = camera.C + ac .* d;
                    base = obj.hillsideHeight(wc(:, 1:2));
                    vc = isfinite(ac) & ac > 0 ...
                        & wc(:, 2) >= ylim(1) & wc(:, 2) <= ylim(2) ...
                        & wc(:, 3) >= base & wc(:, 3) <= zr(k);
                    [world, a, valid, kind] = obj.selectSurface( ...
                        world, a, valid, kind, wc, ac, vc, 3);
                end

                for y = ylim
                    ac = (y - camera.C(2)) ./ d(:, 2);
                    wc = camera.C + ac .* d;
                    base = obj.hillsideHeight(wc(:, 1:2));
                    vc = isfinite(ac) & ac > 0 ...
                        & wc(:, 1) >= xlim(1) & wc(:, 1) <= xlim(2) ...
                        & wc(:, 3) >= base & wc(:, 3) <= zr(k);
                    [world, a, valid, kind] = obj.selectSurface( ...
                        world, a, valid, kind, wc, ac, vc, 4);
                end
            end
            world(~valid, :) = NaN;
        end

        function z = hillsideHeight(obj, xy)
            d = xy - obj.CurvatureCenterENU;
            z = obj.TrueHeightMetres + xy * obj.SurfaceSlopeENU.' ...
                + obj.TerrainCurvaturePerMetre .* sum(d .^ 2, 2);
        end

        function z = buildingRoofHeights(obj)
            b = obj.Buildings;
            dx = b(:, 3) ./ 2;
            dy = b(:, 4) ./ 2;
            x = [b(:, 1) - dx, b(:, 1) + dx, ...
                b(:, 1) - dx, b(:, 1) + dx];
            y = [b(:, 2) - dy, b(:, 2) - dy, ...
                b(:, 2) + dy, b(:, 2) + dy];
            zc = reshape(obj.hillsideHeight([x(:), y(:)]), ...
                size(b, 1), 4);
            z = max(zc, [], 2) + b(:, 5);
        end

        function [world, a, valid, kind] = selectSurface( ...
                ~, world, a, valid, kind, candidate, ca, cv, ck)
            take = cv & (~valid | ca < a);
            world(take, :) = candidate(take, :);
            a(take) = ca(take);
            valid(take) = true;
            kind(take) = uint8(ck);
        end

        function n = constantSurfaceNormal(obj)
            if obj.SurfaceType == "radial-sinc" ...
                    || obj.SurfaceType == "hillside-buildings"
                n = [NaN, NaN, NaN];
            else
                n = [-obj.SurfaceSlopeENU, 1];
                n = n ./ norm(n);
            end
        end

        function [referenceCamera, movingCamera, k, slant] = ...
                createCameras(obj)
            width = obj.ImageSize(2);
            height = obj.ImageSize(1);
            f = (width / 2) / tand( ...
                obj.HorizontalFieldOfViewDegrees / 2);
            k = [f, 0, (width + 1) / 2; ...
                0, f, (height + 1) / 2; 0, 0, 1];
            angle = obj.MeanObliquityDegrees ...
                + [-0.5, 0.5] .* obj.ConvergenceDegrees;
            [rr, dr] = SyntheticPinholeRenderer.cameraRotation( ...
                angle(1), obj.LookAzimuthDegrees);
            [rm, dm] = SyntheticPinholeRenderer.cameraRotation( ...
                angle(2), obj.LookAzimuthDegrees);
            rr = SyntheticPinholeRenderer.applyRoll( ...
                rr, obj.ReferenceRollDegrees);
            rm = SyntheticPinholeRenderer.applyRoll( ...
                rm, obj.MovingRollDegrees);
            unitCamera = PinholeCamera(k, rr, -dr, obj.ImageSize);
            p0 = [(width + 1) / 2, (height + 1) / 2];
            [~, ~, g, valid] = PinholePlaneOracle.localSampling( ...
                unitCamera, p0, 0);
            if ~valid
                error("SyntheticPinholeRenderer:InvalidCameraGeometry", ...
                    "The configured center ray does not reach the Z=0 plane.");
            end
            slant = obj.CenterGsdMetres / g;
            referenceCamera = PinholeCamera( ...
                k, rr, -slant .* dr, obj.ImageSize);
            movingCamera = PinholeCamera( ...
                k, rm, -slant .* dm, obj.ImageSize);
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

        function [r, d] = cameraRotation(obliquity, azimuth)
            h = [sind(azimuth), cosd(azimuth), 0];
            d = sind(obliquity) .* h + [0, 0, -cosd(obliquity)];
            x = [cosd(azimuth), -sind(azimuth), 0];
            y = cross(d, x);
            y = y ./ norm(y);
            r = [x; y; d];
        end

        function r = applyRoll(r, rollDegrees)
            q = [cosd(rollDegrees), sind(rollDegrees), 0; ...
                -sind(rollDegrees), cosd(rollDegrees), 0; ...
                0, 0, 1];
            r = q * r;
        end

        function [g, radius] = gaussianKernel(sigma)
            if sigma == 0
                g = 1;
                radius = 0;
                return
            end
            radius = ceil(3 * sigma);
            x = -radius:radius;
            g = exp(-(x .^ 2) ./ (2 * sigma ^ 2));
            g = g ./ sum(g);
        end

        function v = texture(x, y, seed, type)
            phase = 2 * pi .* mod(double(seed) .* ...
                [0.61803398875, 0.41421356237, 0.73205080757, ...
                0.27182818285], 1);
            switch type
                case "natural"
                    v = 0.5 ...
                        + 0.15 .* sin(2 * pi .* ( ...
                        0.031 .* x + 0.047 .* y) + phase(1)) ...
                        + 0.13 .* cos(2 * pi .* ( ...
                        0.083 .* x - 0.052 .* y) + phase(2)) ...
                        + 0.10 .* sin(2 * pi .* ( ...
                        0.19 .* x + 0.11 .* y) + phase(3)) ...
                        + 0.07 .* sin(2 * pi .* 0.14 .* x + phase(4)) ...
                        .* cos(2 * pi .* 0.17 .* y - phase(4));
                case "single-edge"
                    u = 0.6 .* x + 0.8 .* y + 0.2 .* sin(phase(1));
                    v = 0.5 + 0.35 .* tanh(u ./ 0.6);
                case "corner"
                    v = 0.5 + 0.18 .* tanh(x ./ 0.6) ...
                        + 0.18 .* tanh(y ./ 0.6);
                case "grid"
                    v = 0.5 ...
                        + 0.18 .* sin(2 * pi .* x ./ 6 + phase(1)) ...
                        + 0.18 .* sin(2 * pi .* y ./ 7 + phase(2));
                case "repeated"
                    v = 0.5 + 0.30 .* cos( ...
                        2 * pi .* x ./ 3 + phase(1)) .* cos( ...
                        2 * pi .* y ./ 3 + phase(2));
                case "low-texture"
                    v = 0.5 ...
                        + 0.008 .* sin(2 * pi .* ( ...
                        0.015 .* x + 0.021 .* y) + phase(1)) ...
                        + 0.006 .* cos(2 * pi .* ( ...
                        0.024 .* x - 0.017 .* y) + phase(2));
            end
            v = min(max(v, 0), 1);
        end
    end
end

function mustBeIncreasing(x)
if x(1) >= x(2)
    error("SyntheticPinholeRenderer:InvalidSearchRange", ...
        "SearchRangeMetres must be strictly increasing.");
end
end

function mustBeValidBuildingMatrix(x)
if any(x(:, 3:5) <= 0, "all")
    error("SyntheticPinholeRenderer:InvalidBuildingDimensions", ...
        "Building width, depth, and height must be positive metres.");
end
end

function value = fieldOr(s, name, fallback)
if isfield(s, name)
    value = double(s.(name));
else
    value = fallback;
end
end

function value = buildingField(s)
if ~isfield(s, "buildings") || isempty(s.buildings)
    value = zeros(0, 5);
else
    value = double(s.buildings);
end
end
