classdef ProjectionDenseSurfaceSyntheticTerrain
    %ProjectionDenseSurfaceSyntheticTerrain Compact asymmetric terrain truth.

    properties (Constant)
        Format = "ProjectionDenseSurfaceSyntheticTerrain"
        Version = 1
    end

    methods (Static)
        function terrain = create(config, plan)
            %create Build compact continuous terrain parameters and normalization.
            config = ProjectionDenseSurfaceSyntheticConfig.validate(config);
            ProjectionDenseSurfaceSyntheticTerrain.validatePlan(plan);
            bounds = double(plan.ProjectedTerrainBoundsMeters);
            span = [bounds(2) - bounds(1), bounds(4) - bounds(3)];
            bounds = bounds + 0.05 * [-span(1) span(1) -span(2) span(2)];
            center = [mean(bounds(1:2)) mean(bounds(3:4))];
            intersectionStep = min( ...
                config.terrain.characteristic_lengths_meters) / 6;
            intersectionSamples = ...
                ProjectionDenseSurfaceSyntheticTerrain.intersectionSampleCount( ...
                config, plan, intersectionStep);
            terrain = struct( ...
                Format=ProjectionDenseSurfaceSyntheticTerrain.Format, ...
                Version=ProjectionDenseSurfaceSyntheticTerrain.Version, ...
                Model=config.terrain.model, BoundsMeters=bounds, CenterMeters=center, ...
                MinimumHeightMeters=config.terrain.minimum_height_meters, ...
                MaximumHeightMeters=config.terrain.maximum_height_meters, ...
                CharacteristicLengthsMeters= ...
                config.terrain.characteristic_lengths_meters, ...
                AsymmetryWeights=config.terrain.asymmetry_weights, ...
                RawMinimum=0, RawMaximum=1, ...
                IntersectionStepMeters=intersectionStep, ...
                IntersectionSampleCount=intersectionSamples);

            gridSize = 257;
            x = linspace(bounds(1), bounds(2), gridSize);
            y = linspace(bounds(3), bounds(4), gridSize);
            [xGrid, yGrid] = meshgrid(x, y);
            raw = ProjectionDenseSurfaceSyntheticTerrain.rawHeight( ...
                terrain, xGrid, yGrid);
            terrain.RawMinimum = min(raw, [], "all");
            terrain.RawMaximum = max(raw, [], "all");
            if terrain.RawMaximum - terrain.RawMinimum <= eps
                error("ProjectionDenseSurfaceSyntheticTerrain:degenerateTerrain", ...
                    "Terrain components do not produce a usable height range.");
            end
        end

        function height = height(terrain, x, y)
            %height Sample the continuous terrain with configured extrema.
            ProjectionDenseSurfaceSyntheticTerrain.validateTerrain(terrain);
            [x, y] = ProjectionDenseSurfaceSyntheticTerrain.validateCoordinates(x, y);
            raw = ProjectionDenseSurfaceSyntheticTerrain.rawHeight(terrain, x, y);
            fraction = (raw - terrain.RawMinimum) / ...
                (terrain.RawMaximum - terrain.RawMinimum);
            fraction = min(max(fraction, 0), 1);
            height = terrain.MinimumHeightMeters + fraction * ...
                (terrain.MaximumHeightMeters - terrain.MinimumHeightMeters);
        end

        function [points, status, ranges] = intersectRays(terrain, origins, vectors)
            %intersectRays Find the first forward ray intersection with terrain.
            ProjectionDenseSurfaceSyntheticTerrain.validateTerrain(terrain);
            [origins, vectors] = ...
                ProjectionDenseSurfaceSyntheticTerrain.validateRays( ...
                origins, vectors);
            rayCount = size(vectors, 2);
            top = terrain.MaximumHeightMeters;
            bottom = terrain.MinimumHeightMeters;
            vertical = vectors(3, :);
            topRange = (top - origins(3, :)) ./ vertical;
            bottomRange = (bottom - origins(3, :)) ./ vertical;
            valid = vertical < -eps & isfinite(topRange) & ...
                isfinite(bottomRange) & topRange > 0 & bottomRange > topRange;
            topRange(~valid) = 0;
            bottomRange(~valid) = 0;

            lower = topRange;
            upper = bottomRange;
            sampleCount = terrain.IntersectionSampleCount;

            previousRange = topRange;
            previousResidual = ...
                ProjectionDenseSurfaceSyntheticTerrain.rayResidual( ...
                terrain, origins, vectors, previousRange);
            found = valid & previousResidual <= 0;
            upper(found) = topRange(found);
            for sampleIndex = 2:sampleCount
                fraction = (sampleIndex - 1) / (sampleCount - 1);
                currentRange = topRange + fraction * (bottomRange - topRange);
                currentResidual = ...
                    ProjectionDenseSurfaceSyntheticTerrain.rayResidual( ...
                    terrain, origins, vectors, currentRange);
                crossing = valid & ~found & previousResidual > 0 & ...
                    currentResidual <= 0;
                lower(crossing) = previousRange(crossing);
                upper(crossing) = currentRange(crossing);
                found(crossing) = true;
                previousRange = currentRange;
                previousResidual = currentResidual;
            end

            for iteration = 1:15
                midpoint = 0.5 * (lower + upper);
                residual = ProjectionDenseSurfaceSyntheticTerrain.rayResidual( ...
                    terrain, origins, vectors, midpoint);
                above = found & residual > 0;
                below = found & ~above;
                lower(above) = midpoint(above);
                upper(below) = midpoint(below);
            end
            ranges = 0.5 * (lower + upper);
            ranges(~found) = NaN;
            points = origins + vectors .* ranges;
            points(:, ~found) = NaN;
            status = repmat("invalidGeometry", 1, rayCount);
            status(found) = "visibleTerrain";
        end

        function status = classifyVisibility(terrain, origins, points, toleranceMeters)
            %classifyVisibility Label terrain points as visible, occluded, or invalid.
            if nargin < 4
                toleranceMeters = 0.05;
            end
            toleranceMeters = ...
                ProjectionDenseSurfaceSyntheticTerrain.positiveScalar( ...
                toleranceMeters, "toleranceMeters");
            [origins, points] = ...
                ProjectionDenseSurfaceSyntheticTerrain.validatePointPairs( ...
                origins, points);
            displacement = points - origins;
            targetRanges = vecnorm(displacement, 2, 1);
            safeRanges = targetRanges;
            invalidRange = ~isfinite(safeRanges) | safeRanges <= 0;
            safeRanges(invalidRange) = 1;
            vectors = displacement ./ safeRanges;
            vectors(:, invalidRange) = repmat([0; 0; -1], 1, nnz(invalidRange));
            [~, hitStatus, hitRanges] = ...
                ProjectionDenseSurfaceSyntheticTerrain.intersectRays( ...
                terrain, origins, vectors);
            terrainResidual = abs(points(3, :) - ...
                ProjectionDenseSurfaceSyntheticTerrain.height( ...
                terrain, points(1, :), points(2, :)));
            valid = isfinite(targetRanges) & targetRanges > 0 & ...
                terrainResidual <= toleranceMeters & hitStatus == "visibleTerrain";
            visible = valid & abs(hitRanges - targetRanges) <= toleranceMeters;
            occluded = valid & hitRanges < targetRanges - toleranceMeters;
            status = repmat("invalidGeometry", 1, size(points, 2));
            status(occluded) = "terrainOcclusion";
            status(visible) = "visibleTerrain";
        end

        function audit = auditOcclusion(terrain, origins)
            %auditOcclusion Check deterministic terrain samples for hidden points.
            ProjectionDenseSurfaceSyntheticTerrain.validateTerrain(terrain);
            origins = ProjectionDenseSurfaceSyntheticTerrain.validateOrigins(origins);
            sampleCount = 49;
            x = linspace(terrain.BoundsMeters(1), terrain.BoundsMeters(2), sampleCount);
            y = linspace(terrain.BoundsMeters(3), terrain.BoundsMeters(4), sampleCount);
            [xGrid, yGrid] = meshgrid(x, y);
            zGrid = ProjectionDenseSurfaceSyntheticTerrain.height( ...
                terrain, xGrid, yGrid);
            points = [xGrid(:).'; yGrid(:).'; zGrid(:).'];
            total = 0;
            occluded = 0;
            perViewFractions = zeros(1, size(origins, 2));
            for viewIndex = 1:size(origins, 2)
                viewOrigins = repmat(origins(:, viewIndex), 1, size(points, 2));
                status = ProjectionDenseSurfaceSyntheticTerrain.classifyVisibility( ...
                    terrain, viewOrigins, points, 0.1);
                validCount = nnz(status ~= "invalidGeometry");
                occludedCount = nnz(status == "terrainOcclusion");
                total = total + validCount;
                occluded = occluded + occludedCount;
                perViewFractions(viewIndex) = occludedCount / max(validCount, 1);
            end
            audit = struct(Passed=occluded > 0, SampleCount=total, ...
                OccludedCount=occluded, OccludedFraction=occluded / max(total, 1), ...
                PerViewOccludedFraction=perViewFractions);
        end
    end

    methods (Static, Access = private)
        function raw = rawHeight(terrain, x, y)
            dx = x - terrain.CenterMeters(1);
            dy = y - terrain.CenterMeters(2);
            lengths = terrain.CharacteristicLengthsMeters;
            weights = terrain.AsymmetryWeights;
            radius = hypot(dx, dy);
            scaledRadius = radius / lengths(1);
            primary = ones(size(scaledRadius));
            nonzero = scaledRadius ~= 0;
            primary(nonzero) = sin(pi * scaledRadius(nonzero)) ./ ...
                (pi * scaledRadius(nonzero));
            window = exp(-0.5 * (radius / max(lengths)) .^ 2);
            raw = weights(1) * primary .* window;
            for componentIndex = 2:numel(lengths)
                angle = 0.37 + 0.61 * componentIndex;
                along = cos(angle) * dx + sin(angle) * dy;
                across = -sin(angle) * dx + cos(angle) * dy;
                phase = 0.43 * componentIndex;
                component = sin(2 * pi * along / lengths(componentIndex) + phase) .* ...
                    cos(2 * pi * across / (1.7 * lengths(componentIndex)) - ...
                    0.5 * phase) .* exp(-0.5 * (radius / ...
                    (2.5 * lengths(componentIndex))) .^ 2);
                raw = raw + weights(componentIndex) * component;
            end
        end

        function sampleCount = intersectionSampleCount(config, plan, step)
            halfFov = 0.5 * config.image.cross_track_fov_degrees;
            maximumRatio = 0;
            for viewIndex = 1:numel(plan.Views)
                view = plan.Views(viewIndex);
                rolls = view.RollDegrees + [-halfFov halfFov];
                pitches = [view.PitchStartDegrees view.PitchEndDegrees];
                for rollIndex = 1:2
                    for pitchIndex = 1:2
                        ray = ProjectionDenseSurfaceSyntheticPlanner.boresightRay( ...
                            rolls(rollIndex), pitches(pitchIndex));
                        ratio = norm(ray(1:2)) / abs(ray(3));
                        maximumRatio = max(maximumRatio, ratio);
                    end
                end
            end
            heightSpan = config.terrain.maximum_height_meters - ...
                config.terrain.minimum_height_meters;
            maximumHorizontalSpan = 1.02 * heightSpan * maximumRatio;
            sampleCount = max(3, ceil(maximumHorizontalSpan / step) + 1);
        end

        function residual = rayResidual(terrain, origins, vectors, ranges)
            x = origins(1, :) + vectors(1, :) .* ranges;
            y = origins(2, :) + vectors(2, :) .* ranges;
            z = origins(3, :) + vectors(3, :) .* ranges;
            residual = z - ProjectionDenseSurfaceSyntheticTerrain.height( ...
                terrain, x, y);
        end

        function [origins, vectors] = validateRays(origins, vectors)
            origins = ProjectionDenseSurfaceSyntheticTerrain.validateOrigins(origins);
            if ~isnumeric(vectors) || size(vectors, 1) ~= 3 || ...
                    any(~isfinite(vectors), "all") || size(vectors, 2) < 1
                error("ProjectionDenseSurfaceSyntheticTerrain:invalidRays", ...
                    "View vectors must be a finite 3-by-N numeric array.");
            end
            vectors = double(vectors);
            if size(origins, 2) == 1 && size(vectors, 2) > 1
                origins = repmat(origins, 1, size(vectors, 2));
            elseif size(origins, 2) ~= size(vectors, 2)
                error("ProjectionDenseSurfaceSyntheticTerrain:invalidRays", ...
                    "Ray origins and vectors must have matching column counts.");
            end
            lengths = vecnorm(vectors, 2, 1);
            if any(lengths <= eps)
                error("ProjectionDenseSurfaceSyntheticTerrain:invalidRays", ...
                    "View vectors must have nonzero length.");
            end
            vectors = vectors ./ lengths;
        end

        function origins = validateOrigins(origins)
            if ~isnumeric(origins) || size(origins, 1) ~= 3 || ...
                    size(origins, 2) < 1 || any(~isfinite(origins), "all")
                error("ProjectionDenseSurfaceSyntheticTerrain:invalidOrigins", ...
                    "Origins must be a finite 3-by-N numeric array.");
            end
            origins = double(origins);
        end

        function [origins, points] = validatePointPairs(origins, points)
            origins = ProjectionDenseSurfaceSyntheticTerrain.validateOrigins(origins);
            points = ProjectionDenseSurfaceSyntheticTerrain.validateOrigins(points);
            if size(origins, 2) == 1 && size(points, 2) > 1
                origins = repmat(origins, 1, size(points, 2));
            elseif size(origins, 2) ~= size(points, 2)
                error("ProjectionDenseSurfaceSyntheticTerrain:invalidPoints", ...
                    "Origins and terrain points must have matching column counts.");
            end
        end

        function [x, y] = validateCoordinates(x, y)
            if ~isnumeric(x) || ~isnumeric(y) || isempty(x) || isempty(y) || ...
                    any(~isfinite(x), "all") || any(~isfinite(y), "all")
                error("ProjectionDenseSurfaceSyntheticTerrain:invalidCoordinates", ...
                    "Terrain coordinates must be nonempty finite numeric arrays.");
            end
            x = double(x);
            y = double(y);
            if isscalar(x)
                x = repmat(x, size(y));
            elseif isscalar(y)
                y = repmat(y, size(x));
            elseif ~isequal(size(x), size(y))
                error("ProjectionDenseSurfaceSyntheticTerrain:invalidCoordinates", ...
                    "Terrain X and Y coordinates must have equal sizes or be scalar.");
            end
        end

        function value = positiveScalar(value, name)
            if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value) || value <= 0
                error("ProjectionDenseSurfaceSyntheticTerrain:invalidTolerance", ...
                    "%s must be a positive finite scalar.", name);
            end
            value = double(value);
        end

        function validatePlan(plan)
            if ~isstruct(plan) || ~isscalar(plan) || ...
                    ~isfield(plan, "Format") || ...
                    string(plan.Format) ~= ProjectionDenseSurfaceSyntheticPlanner.Format || ...
                    ~isfield(plan, "Feasible") || ~plan.Feasible || ...
                    ~isfield(plan, "ProjectedTerrainBoundsMeters")
                error("ProjectionDenseSurfaceSyntheticTerrain:invalidPlan", ...
                    "Terrain creation requires a feasible synthetic collection plan.");
            end
        end

        function validateTerrain(terrain)
            required = ["Format" "BoundsMeters" "CenterMeters" ...
                "MinimumHeightMeters" "MaximumHeightMeters" ...
                "CharacteristicLengthsMeters" "AsymmetryWeights" ...
                "RawMinimum" "RawMaximum" "IntersectionStepMeters" ...
                "IntersectionSampleCount"];
            if ~isstruct(terrain) || ~isscalar(terrain) || ...
                    ~all(isfield(terrain, required)) || ...
                    string(terrain.Format) ~= ...
                    ProjectionDenseSurfaceSyntheticTerrain.Format
                error("ProjectionDenseSurfaceSyntheticTerrain:invalidTerrain", ...
                    "Terrain must come from create.");
            end
        end
    end
end
