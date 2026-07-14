classdef ProjectionPairViewpoint
    %ProjectionPairViewpoint Plan a presentation-only active-pair camera.

    properties (Constant)
        Format = "ProjectionPairViewpoint"
        Version = 1
    end

    methods (Static)
        function result = compute(scene, pair, options)
            %compute Return a fitted midpoint camera for one active pair.
            if nargin < 3
                options = struct();
            end
            options = ProjectionPairViewpoint.options(options);
            result = ProjectionPairViewpoint.emptyResult();

            [valid, explanation] = ...
                ProjectionPairViewpoint.validateInputs(scene, pair);
            if ~valid
                result.Explanation = explanation;
                return
            end

            result.PairId = string(pair.PairId);
            result.ViewIds = [string(pair.ReferenceViewId) ...
                string(pair.MovingViewId)];
            layerIndices = [pair.ReferenceLayerIndex pair.MovingLayerIndex];
            plane = scene.layers(layerIndices(1)).CurrentProjectionPlane;
            try
                PlanarProjection.validatePlane(plane);
                [meshes, footprints] = ProjectionPairViewpoint.pairFootprints( ...
                    scene.layers(layerIndices), plane);
                overlap = intersect(footprints(1), footprints(2));
            catch exception
                result.Explanation = "Pair geometry is unavailable: " + ...
                    string(exception.message);
                return
            end

            if ProjectionPairViewpoint.isEmptyOverlap(overlap)
                result.Explanation = ...
                    "The active pair has no usable shared footprint overlap.";
                return
            end

            [centroidX, centroidY] = centroid(overlap);
            centroidPlane = [centroidX; centroidY];
            if any(~isfinite(centroidPlane))
                result.Explanation = ...
                    "The shared pair footprint has no finite centroid.";
                return
            end

            [origins, originModes] = ...
                ProjectionPairViewpoint.representativeOrigins( ...
                scene.layers(layerIndices), meshes, overlap, ...
                centroidPlane, plane);
            if any(~isfinite(origins), "all")
                result.Explanation = [ ...
                    "Representative sensor origins are unavailable for " ...
                    "the active pair."];
                return
            end

            cameraPosition = mean(origins, 2);
            cameraTarget = PlanarProjection.reconstruct3d(centroidPlane, plane);
            viewDirection = cameraTarget - cameraPosition;
            viewDistance = norm(viewDirection);
            if ~isfinite(viewDistance) || viewDistance <= ...
                    ProjectionPairViewpoint.tolerance(cameraPosition)
                result.Explanation = ...
                    "The pair midpoint and overlap centroid do not define a camera.";
                return
            end
            viewDirection = viewDirection / viewDistance;
            [cameraUp, cameraRight] = ...
                ProjectionPairViewpoint.stableScreenBasis( ...
                viewDirection, plane);

            boundaryPlane = ProjectionPairViewpoint.boundaryPoints(overlap);
            footprintWorld = PlanarProjection.reconstruct3d( ...
                boundaryPlane, plane);
            relativePoints = footprintWorld - cameraTarget;
            footprintWidth = max(cameraRight.' * relativePoints) - ...
                min(cameraRight.' * relativePoints);
            footprintHeight = max(cameraUp.' * relativePoints) - ...
                min(cameraUp.' * relativePoints);
            desiredHeight = max(footprintHeight / options.FillFraction, ...
                footprintWidth / (options.AspectRatio * options.FillFraction));
            if ~isfinite(desiredHeight) || desiredHeight <= 0
                result.Explanation = ...
                    "The shared pair footprint cannot be fitted in the viewport.";
                return
            end
            viewAngle = rad2deg(2 * atan(desiredHeight / (2 * viewDistance)));
            viewAngle = min(max(viewAngle, options.MinimumViewAngleDegrees), ...
                options.MaximumViewAngleDegrees);

            result.Available = true;
            result.Explanation = "";
            result.OriginModes = originModes;
            result.RepresentativeOrigins = origins;
            result.OverlapPlaneCoordinates = boundaryPlane;
            result.OverlapCentroidPlaneCoordinates = centroidPlane;
            result.OverlapArea = area(overlap);
            result.Camera = struct( ...
                PositionWorld=cameraPosition, TargetWorld=cameraTarget, ...
                UpVector=cameraUp, ViewAngle=viewAngle, ...
                Projection="orthographic");
        end
    end

    methods (Static, Access = private)
        function result = emptyResult()
            result = struct(Format=ProjectionPairViewpoint.Format, ...
                Version=ProjectionPairViewpoint.Version, Available=false, ...
                Explanation="Pair viewpoint is unavailable.", PairId="", ...
                ViewIds=strings(1, 0), OriginModes=strings(1, 0), ...
                RepresentativeOrigins=zeros(3, 0), ...
                OverlapPlaneCoordinates=zeros(2, 0), ...
                OverlapCentroidPlaneCoordinates=zeros(2, 0), ...
                OverlapArea=0, Camera=struct());
        end

        function [valid, explanation] = validateInputs(scene, pair)
            valid = false;
            explanation = "Pair viewpoint requires an available active pair.";
            if ~isstruct(scene) || ~isscalar(scene) || ...
                    ~isfield(scene, "layers") || numel(scene.layers) < 2 || ...
                    ~isstruct(pair) || ~isscalar(pair)
                return
            end
            fields = ["PairId", "ReferenceViewId", "MovingViewId", ...
                "ReferenceLayerIndex", "MovingLayerIndex", "ViewsAvailable"];
            if any(~isfield(pair, fields)) || ~logical(pair.ViewsAvailable)
                return
            end
            indices = [pair.ReferenceLayerIndex pair.MovingLayerIndex];
            if any(~isfinite(indices)) || any(fix(indices) ~= indices) || ...
                    any(indices < 1) || any(indices > numel(scene.layers)) || ...
                    indices(1) == indices(2)
                explanation = "The active pair does not resolve to two layers.";
                return
            end
            requiredLayerFields = ["CurrentProjectionPlane", ...
                "SourceGeometry", "MeshSampling"];
            if any(~isfield(scene.layers(indices), requiredLayerFields), "all")
                explanation = ...
                    "The active pair is missing projection or source geometry.";
                return
            end
            valid = true;
            explanation = "";
        end

        function options = options(options)
            if isempty(options)
                options = struct();
            end
            if ~isstruct(options) || ~isscalar(options)
                error("ProjectionPairViewpoint:invalidOptions", ...
                    "Options must be a scalar struct.");
            end
            defaults = struct(AspectRatio=1, FillFraction=0.8, ...
                MinimumViewAngleDegrees=1e-6, ...
                MaximumViewAngleDegrees=60);
            names = fieldnames(options);
            for index = 1:numel(names)
                if ~isfield(defaults, names{index})
                    error("ProjectionPairViewpoint:invalidOptions", ...
                        "Unknown pair-viewpoint option %s.", names{index});
                end
                defaults.(names{index}) = options.(names{index});
            end
            numericFields = ["AspectRatio", "FillFraction", ...
                "MinimumViewAngleDegrees", "MaximumViewAngleDegrees"];
            for name = numericFields
                value = defaults.(name);
                if ~isnumeric(value) || ~isscalar(value) || ...
                        ~isfinite(value) || value <= 0
                    error("ProjectionPairViewpoint:invalidOptions", ...
                        "%s must be a positive finite scalar.", name);
                end
                defaults.(name) = double(value);
            end
            if defaults.FillFraction > 1 || ...
                    defaults.MinimumViewAngleDegrees >= ...
                    defaults.MaximumViewAngleDegrees
                error("ProjectionPairViewpoint:invalidOptions", ...
                    "FillFraction and view-angle limits are inconsistent.");
            end
            options = defaults;
        end

        function [meshes, footprints] = pairFootprints(layers, plane)
            footprints = repmat(polyshape(), 1, 2);
            for index = 1:2
                mesh = ProjectionMeshBuilder.buildLayerMesh( ...
                    layers(index), plane, zeros(3, 1));
                if index == 1
                    meshes = mesh;
                else
                    meshes(index) = mesh;
                end
                points = reshape(mesh.WorldPoints, 3, []);
                coordinates = PlanarProjection.worldToPlane(points, plane);
                coordinates = unique(coordinates.', "rows", "stable").';
                if size(coordinates, 2) < 3
                    error("ProjectionPairViewpoint:invalidFootprint", ...
                        "A pair layer does not define a two-dimensional footprint.");
                end
                hull = convhull(coordinates(1, :).', coordinates(2, :).');
                if numel(hull) > 1 && hull(1) == hull(end)
                    hull(end) = [];
                end
                vertices = ProjectionPairViewpoint.simplifyConvexVertices( ...
                    coordinates(:, hull));
                footprints(index) = polyshape( ...
                    vertices(1, :), vertices(2, :), Simplify=false);
            end
        end

        function vertices = simplifyConvexVertices(vertices)
            scale = max(1, max(abs(vertices), [], "all"));
            tolerance = 1e-10 * scale;
            changed = true;
            while changed && size(vertices, 2) > 3
                changed = false;
                count = size(vertices, 2);
                keep = true(1, count);
                for index = 1:count
                    previous = vertices(:, mod(index - 2, count) + 1);
                    current = vertices(:, index);
                    following = vertices(:, mod(index, count) + 1);
                    firstEdge = current - previous;
                    secondEdge = following - current;
                    if norm(firstEdge) <= tolerance || ...
                            abs(firstEdge(1) * secondEdge(2) - ...
                            firstEdge(2) * secondEdge(1)) <= ...
                            tolerance * max(norm(firstEdge), norm(secondEdge))
                        keep(index) = false;
                        changed = true;
                    end
                end
                if nnz(keep) >= 3
                    vertices = vertices(:, keep);
                else
                    changed = false;
                end
            end
        end

        function tf = isEmptyOverlap(overlap)
            points = ProjectionPairViewpoint.boundaryPoints(overlap);
            if size(points, 2) < 3
                tf = true;
                return
            end
            scale = max(1, max(abs(points), [], "all"));
            tf = area(overlap) <= 100 * eps(scale ^ 2);
        end

        function points = boundaryPoints(polygon)
            [x, y] = boundary(polygon);
            valid = isfinite(x) & isfinite(y);
            points = [x(valid).'; y(valid).'];
        end

        function [origins, modes] = representativeOrigins( ...
                layers, meshes, overlap, centroidPlane, plane)
            origins = NaN(3, 2);
            modes = strings(1, 2);
            boundaryPlane = ProjectionPairViewpoint.boundaryPoints(overlap);
            queryPlane = [centroidPlane, ...
                0.5 * (boundaryPlane + centroidPlane)];
            for index = 1:2
                [origin, mode] = ProjectionPairViewpoint.overlapOrigin( ...
                    layers(index), meshes(index), queryPlane, plane);
                origins(:, index) = origin;
                modes(index) = mode;
            end
        end

        function [origin, mode] = overlapOrigin( ...
                layer, mesh, queryPlane, plane)
            origin = NaN(3, 1);
            mode = "unavailable";
            source = layer.SourceGeometry;
            if isfield(source, "SampleRayFcn") && ...
                    isa(source.SampleRayFcn, "function_handle") && ...
                    isfield(source, "ImageSize")
                try
                    inverseModel = ProjectionFullSourceInverseWarp.prepare( ...
                        mesh, plane, source.ImageSize);
                    mapping = ProjectionFullSourceInverseWarp.mapCoordinates( ...
                        inverseModel, queryPlane, [1 size(queryPlane, 2)]);
                    valid = mapping.ValidMask(:).';
                    if any(valid)
                        [sampledOrigins, ~] = source.SampleRayFcn( ...
                            mapping.RowCoordinates(valid), ...
                            mapping.ColumnCoordinates(valid));
                        if isnumeric(sampledOrigins) && ...
                                size(sampledOrigins, 1) == 3 && ...
                                all(isfinite(sampledOrigins), "all")
                            origin = mean(sampledOrigins, 2);
                            mode = "sharedOverlap";
                            return
                        end
                    end
                catch
                    % Fall through to the established MI-3 reference origin.
                end
            end
            names = ["ReferenceOrigin", "G0"];
            for name = names
                if isfield(source, name)
                    candidate = source.(name);
                    if isnumeric(candidate) && numel(candidate) == 3 && ...
                            all(isfinite(candidate), "all")
                        origin = double(candidate(:));
                        mode = "referenceOriginFallback";
                        return
                    end
                end
            end
        end

        function [up, right] = stableScreenBasis(viewDirection, plane)
            try
                [up, right] = ...
                    ProjectionViewerHarness.presentationScreenBasis( ...
                    viewDirection, plane);
            catch exception
                error("ProjectionPairViewpoint:unstableUp", ...
                    "The current plane cannot define a stable camera up " + ...
                    "vector: %s", exception.message);
            end
        end

        function value = tolerance(values)
            value = 1e-12 * max(1, max(abs(values), [], "all"));
        end
    end
end
