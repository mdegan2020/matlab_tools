classdef ProjectionStereoCursorModel
    %ProjectionStereoCursorModel Runtime-only world-space stereo cursor geometry.

    properties (Constant)
        Format = "ProjectionStereoCursorProjection"
        Version = 1
    end

    methods (Static)
        function options = defaults()
            %defaults Return deterministic bounded inverse-projection options.
            options = struct(CoarseGridSize=[9 9], MaximumIterations=18, ...
                MaximumStarts=4, FiniteDifferencePixels=0.02, ...
                StepTolerancePixels=1e-7, BoundaryTolerancePixels=1e-5, ...
                OutsideTolerancePixels=0.05, ...
                PixelMissTolerance=0.75, MinimumMissToleranceMeters=1e-6);
        end

        function point = worldPoint(plane, anchorPlaneCoordinates, heightMeters)
            %worldPoint Form Pcursor = Pplane + z * VN.
            PlanarProjection.validatePlane(plane);
            if ~isnumeric(anchorPlaneCoordinates) || ...
                    numel(anchorPlaneCoordinates) ~= 2 || ...
                    any(~isfinite(anchorPlaneCoordinates), "all")
                error("ProjectionStereoCursorModel:invalidAnchor", ...
                    "Anchor plane coordinates must be a finite numeric 2-vector.");
            end
            if ~isnumeric(heightMeters) || ~isscalar(heightMeters) || ...
                    ~isfinite(heightMeters)
                error("ProjectionStereoCursorModel:invalidHeight", ...
                    "Cursor height must be a finite scalar in metres.");
            end
            anchor = PlanarProjection.reconstruct3d( ...
                double(anchorPlaneCoordinates(:)), plane);
            point = anchor + double(heightMeters) * plane.VN;
        end

        function result = projectPair(scene, viewIds, worldPoint, plane, options)
            %projectPair Project one physical point through two stable views.
            if nargin < 5
                options = struct();
            end
            scene = ProjectionViewMetadata.ensureScene(scene);
            PlanarProjection.validatePlane(plane);
            worldPoint = ProjectionStereoCursorModel.validateWorldPoint(worldPoint);
            viewIds = reshape(string(viewIds), 1, []);
            if numel(viewIds) ~= 2 || any(ismissing(viewIds)) || ...
                    any(strlength(viewIds) == 0) || viewIds(1) == viewIds(2)
                error("ProjectionStereoCursorModel:invalidPair", ...
                    "ViewIds must name two distinct stable views.");
            end
            options = ProjectionStereoCursorModel.mergeOptions(options);
            projections = repmat( ...
                ProjectionStereoCursorModel.emptyProjection(), 1, 2);
            for index = 1:2
                projections(index) = ProjectionStereoCursorModel.projectView( ...
                    scene, viewIds(index), worldPoint, plane, options);
            end
            identity = ProjectionViewMetadata.pairIdentity(viewIds(1), viewIds(2));
            result = struct(Format=ProjectionStereoCursorModel.Format, ...
                Version=ProjectionStereoCursorModel.Version, ...
                PairId=identity.PairId, ViewIds=viewIds, ...
                WorldPoint=worldPoint, Projections=projections, ...
                ValidCount=nnz([projections.Valid]), RuntimeOnly=true, ...
                GraphicsStateIncluded=false);
        end
    end

    methods (Static, Access = private)
        function projection = projectView(scene, viewId, worldPoint, plane, options)
            projection = ProjectionStereoCursorModel.emptyProjection();
            projection.ViewId = viewId;
            try
                layerIndex = ProjectionViewMetadata.indexForId(scene, viewId);
            catch
                projection.Status = "missingView";
                return
            end
            layer = scene.layers(layerIndex);
            projection.LayerIndex = layerIndex;
            projection.LayerId = string(layer.LayerId);
            if ~isfield(layer, "SourceGeometry") || ...
                    ~isstruct(layer.SourceGeometry) || ...
                    ~isfield(layer.SourceGeometry, "ImageSize") || ...
                    ~isfield(layer.SourceGeometry, "SampleRayFcn") || ...
                    ~isa(layer.SourceGeometry.SampleRayFcn, "function_handle")
                projection.Status = "unsupportedSourceGeometry";
                return
            end

            inverse = ProjectionStereoCursorModel.inverseObservation( ...
                layer, worldPoint, plane, options);
            projection.SourceCoordinates = inverse.SourceCoordinates;
            projection.RangeMeters = inverse.RangeMeters;
            projection.RayMissMeters = inverse.RayMissMeters;
            projection.PixelToleranceMeters = inverse.PixelToleranceMeters;
            projection.IterationCount = inverse.IterationCount;
            projection.Status = inverse.Status;
            if ~inverse.Valid
                return
            end

            source = inverse.SourceCoordinates;
            planeProjection = ProjectionAlignmentObservationProjector.project( ...
                scene, projection.LayerId, source(1), source(2), plane);
            if ~planeProjection.ValidMask(1)
                projection.Status = string(planeProjection.Status(1));
                return
            end
            projection.PlaneCoordinates = ...
                planeProjection.PlaneCoordinates(1, :);
            projection.DisplayWorldPoint = PlanarProjection.reconstruct3d( ...
                projection.PlaneCoordinates(:), plane);
            projection.Valid = true;
            projection.Status = "valid";
            projection.Method = "iterativeSampleRayInverse+exactPlaneProjection";
        end

        function inverse = inverseObservation(layer, worldPoint, plane, options)
            imageSize = double(layer.SourceGeometry.ImageSize(:).');
            inverse = struct(Valid=false, Status="samplingFailure", ...
                SourceCoordinates=[NaN NaN], RangeMeters=NaN, ...
                RayMissMeters=NaN, PixelToleranceMeters=NaN, ...
                IterationCount=0);
            if numel(imageSize) ~= 2 || any(~isfinite(imageSize)) || ...
                    any(imageSize < 1)
                inverse.Status = "invalidImageSize";
                return
            end
            rotation = ProjectionMeshBuilder.viewVectorRotationMatrix(layer, plane);
            rowGrid = linspace(1, imageSize(1), ...
                min(options.CoarseGridSize(1), imageSize(1)));
            columnGrid = linspace(1, imageSize(2), ...
                min(options.CoarseGridSize(2), imageSize(2)));
            [columns, rows] = meshgrid(columnGrid, rowGrid);
            candidates = [rows(:) columns(:)];
            metrics = inf(size(candidates, 1), 1);
            ranges = nan(size(metrics));
            for index = 1:size(candidates, 1)
                sample = ProjectionStereoCursorModel.rayResidual( ...
                    layer, worldPoint, rotation, candidates(index, :));
                if sample.Sampled && sample.RangeMeters > 0
                    metrics(index) = sample.RayMissMeters;
                    ranges(index) = sample.RangeMeters;
                end
            end
            finite = find(isfinite(metrics));
            if isempty(finite)
                inverse.Status = ProjectionStereoCursorModel.behindOrSampling( ...
                    layer, worldPoint, rotation, candidates);
                return
            end
            [~, order] = sort(metrics(finite), "ascend");
            starts = finite(order(1:min(options.MaximumStarts, numel(order))));
            best = struct(Q=[NaN NaN], Sample=struct(), Iterations=0, ...
                BoundaryStep=[NaN NaN]);
            bestMiss = Inf;
            for startIndex = reshape(starts, 1, [])
                refined = ProjectionStereoCursorModel.refine( ...
                    layer, worldPoint, rotation, candidates(startIndex, :), ...
                    imageSize, options);
                if refined.Sample.Sampled && ...
                        refined.Sample.RangeMeters > 0 && ...
                        refined.Sample.RayMissMeters < bestMiss
                    best = refined;
                    bestMiss = refined.Sample.RayMissMeters;
                end
            end
            if ~isfinite(bestMiss)
                inverse.Status = "samplingFailure";
                return
            end

            pixelScale = ProjectionStereoCursorModel.pixelScale( ...
                layer, worldPoint, rotation, best.Q, imageSize, best.Sample);
            missTolerance = max(options.MinimumMissToleranceMeters, ...
                options.PixelMissTolerance * pixelScale);
            outside = ProjectionStereoCursorModel.pointsOutside( ...
                best.Q, best.BoundaryStep, imageSize, options);
            inverse.SourceCoordinates = best.Q;
            inverse.RangeMeters = best.Sample.RangeMeters;
            inverse.RayMissMeters = best.Sample.RayMissMeters;
            inverse.PixelToleranceMeters = missTolerance;
            inverse.IterationCount = best.Iterations;
            if outside
                inverse.Status = "outsideSourceFootprint";
            elseif best.Sample.RangeMeters <= 0
                inverse.Status = "behindSource";
            elseif best.Sample.RayMissMeters > missTolerance
                inverse.Status = "rayModelMismatch";
            else
                inverse.Valid = true;
                inverse.Status = "valid";
            end
        end

        function refined = refine(layer, worldPoint, rotation, q, imageSize, options)
            sample = ProjectionStereoCursorModel.rayResidual( ...
                layer, worldPoint, rotation, q);
            boundaryStep = [0 0];
            iterations = 0;
            for iteration = 1:options.MaximumIterations
                [jacobian, valid] = ProjectionStereoCursorModel.jacobian( ...
                    layer, worldPoint, rotation, q, imageSize, options);
                if ~valid || rank(jacobian) < 2
                    break
                end
                step = -pinv(jacobian) * sample.Residual;
                step = reshape(step, 1, 2);
                boundaryStep = step;
                if norm(step) <= options.StepTolerancePixels
                    break
                end
                maximumStep = max(1, 0.25 * max(imageSize));
                if norm(step) > maximumStep
                    step = step * maximumStep / norm(step);
                end
                improved = false;
                for scale = [1 0.5 0.25 0.125 0.0625]
                    trialQ = min(max(q + scale * step, [1 1]), imageSize);
                    trial = ProjectionStereoCursorModel.rayResidual( ...
                        layer, worldPoint, rotation, trialQ);
                    if trial.Sampled && trial.RangeMeters > 0 && ...
                            trial.RayMissMeters < sample.RayMissMeters
                        q = trialQ;
                        sample = trial;
                        improved = true;
                        break
                    end
                end
                iterations = iteration;
                if ~improved
                    break
                end
            end
            [jacobian, valid] = ProjectionStereoCursorModel.jacobian( ...
                layer, worldPoint, rotation, q, imageSize, options);
            if valid && rank(jacobian) >= 2
                boundaryStep = reshape( ...
                    -pinv(jacobian) * sample.Residual, 1, 2);
            end
            refined = struct(Q=q, Sample=sample, Iterations=iterations, ...
                BoundaryStep=boundaryStep);
        end

        function [jacobian, valid] = jacobian( ...
                layer, worldPoint, rotation, q, imageSize, options)
            jacobian = nan(3, 2);
            for dimension = 1:2
                delta = max(options.FiniteDifferencePixels, ...
                    1e-6 * imageSize(dimension));
                lower = q;
                upper = q;
                lower(dimension) = max(1, q(dimension) - delta);
                upper(dimension) = min(imageSize(dimension), ...
                    q(dimension) + delta);
                width = upper(dimension) - lower(dimension);
                if width <= eps
                    valid = false;
                    return
                end
                lowerSample = ProjectionStereoCursorModel.rayResidual( ...
                    layer, worldPoint, rotation, lower);
                upperSample = ProjectionStereoCursorModel.rayResidual( ...
                    layer, worldPoint, rotation, upper);
                if ~lowerSample.Sampled || ~upperSample.Sampled
                    valid = false;
                    return
                end
                jacobian(:, dimension) = ...
                    (upperSample.Residual - lowerSample.Residual) / width;
            end
            valid = all(isfinite(jacobian), "all");
        end

        function sample = rayResidual(layer, worldPoint, rotation, q)
            sample = struct(Sampled=false, RangeMeters=NaN, ...
                RayMissMeters=Inf, Residual=nan(3, 1), ...
                Origin=nan(3, 1), Vector=nan(3, 1));
            try
                [origin, vector] = layer.SourceGeometry.SampleRayFcn(q(1), q(2));
                origin = double(origin);
                vector = rotation * double(vector);
                if ~isequal(size(origin), [3 1]) || ...
                        ~isequal(size(vector), [3 1]) || ...
                        any(~isfinite(origin)) || any(~isfinite(vector)) || ...
                        norm(vector) <= eps
                    return
                end
                vector = vector / norm(vector);
                difference = worldPoint - origin;
                range = vector.' * difference;
                residual = difference - range * vector;
                sample.Sampled = true;
                sample.RangeMeters = range;
                sample.RayMissMeters = norm(residual);
                sample.Residual = residual;
                sample.Origin = origin;
                sample.Vector = vector;
            catch
                return
            end
        end

        function scale = pixelScale( ...
                layer, worldPoint, rotation, q, imageSize, center)
            distances = zeros(1, 0);
            for dimension = 1:2
                for direction = [-1 1]
                    neighborQ = q;
                    neighborQ(dimension) = min(max( ...
                        q(dimension) + direction, 1), imageSize(dimension));
                    if neighborQ(dimension) == q(dimension)
                        continue
                    end
                    neighbor = ProjectionStereoCursorModel.rayResidual( ...
                        layer, worldPoint, rotation, neighborQ);
                    if neighbor.Sampled
                        centerPoint = center.Origin + ...
                            center.RangeMeters * center.Vector;
                        neighborPoint = neighbor.Origin + ...
                            center.RangeMeters * neighbor.Vector;
                        distances(end + 1) = norm( ...
                            neighborPoint - centerPoint) / ...
                            abs(neighborQ(dimension) - q(dimension)); %#ok<AGROW>
                    end
                end
            end
            distances = distances(isfinite(distances) & distances > 0);
            if isempty(distances)
                scale = max(1, abs(center.RangeMeters)) * 1e-6;
            else
                scale = max(distances);
            end
        end

        function tf = pointsOutside(q, step, imageSize, options)
            lower = q <= 1 + options.BoundaryTolerancePixels & ...
                step < -options.OutsideTolerancePixels;
            upper = q >= imageSize - options.BoundaryTolerancePixels & ...
                step > options.OutsideTolerancePixels;
            tf = any(lower | upper);
        end

        function status = behindOrSampling(layer, worldPoint, rotation, candidates)
            sampled = false;
            allBehind = true;
            for index = 1:size(candidates, 1)
                sample = ProjectionStereoCursorModel.rayResidual( ...
                    layer, worldPoint, rotation, candidates(index, :));
                sampled = sampled || sample.Sampled;
                if sample.Sampled && sample.RangeMeters > 0
                    allBehind = false;
                    break
                end
            end
            if sampled && allBehind
                status = "behindSource";
            else
                status = "samplingFailure";
            end
        end

        function projection = emptyProjection()
            projection = struct(ViewId="", LayerId="", LayerIndex=NaN, ...
                Valid=false, Status="unavailable", ...
                SourceCoordinates=[NaN NaN], ...
                PlaneCoordinates=[NaN NaN], ...
                DisplayWorldPoint=nan(3, 1), RangeMeters=NaN, ...
                RayMissMeters=NaN, PixelToleranceMeters=NaN, ...
                IterationCount=0, Method="iterativeSampleRayInverse");
        end

        function options = mergeOptions(overrides)
            options = ProjectionStereoCursorModel.defaults();
            if isempty(overrides)
                return
            end
            if ~isstruct(overrides) || ~isscalar(overrides)
                error("ProjectionStereoCursorModel:invalidOptions", ...
                    "Options must be a scalar struct.");
            end
            names = fieldnames(overrides);
            known = string(fieldnames(options));
            for index = 1:numel(names)
                if ~any(string(names{index}) == known)
                    error("ProjectionStereoCursorModel:unknownOption", ...
                        "Unknown option %s.", names{index});
                end
                options.(names{index}) = overrides.(names{index});
            end
            ProjectionStereoCursorModel.validateOptions(options);
        end

        function validateOptions(options)
            integerNames = ["MaximumIterations" "MaximumStarts"];
            for name = integerNames
                value = options.(name);
                if ~isnumeric(value) || ~isscalar(value) || ...
                        ~isfinite(value) || value < 1 || fix(value) ~= value
                    error("ProjectionStereoCursorModel:invalidOptions", ...
                        "%s must be a positive integer.", name);
                end
            end
            if ~isnumeric(options.CoarseGridSize) || ...
                    numel(options.CoarseGridSize) ~= 2 || ...
                    any(~isfinite(options.CoarseGridSize)) || ...
                    any(options.CoarseGridSize < 2) || ...
                    any(fix(options.CoarseGridSize) ~= options.CoarseGridSize)
                error("ProjectionStereoCursorModel:invalidOptions", ...
                    "CoarseGridSize must contain two integers >= 2.");
            end
            scalarNames = ["FiniteDifferencePixels" ...
                "StepTolerancePixels" "BoundaryTolerancePixels" ...
                "OutsideTolerancePixels" "PixelMissTolerance" ...
                "MinimumMissToleranceMeters"];
            for name = scalarNames
                value = options.(name);
                if ~isnumeric(value) || ~isscalar(value) || ...
                        ~isfinite(value) || value <= 0
                    error("ProjectionStereoCursorModel:invalidOptions", ...
                        "%s must be a positive finite scalar.", name);
                end
            end
        end

        function point = validateWorldPoint(point)
            if ~isnumeric(point) || ~isequal(size(point), [3 1]) || ...
                    any(~isfinite(point))
                error("ProjectionStereoCursorModel:invalidWorldPoint", ...
                    "WorldPoint must be a finite numeric 3x1 point.");
            end
            point = double(point);
        end
    end
end
