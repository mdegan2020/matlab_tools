classdef ProjectionAlignmentWorkingGrid
    %ProjectionAlignmentWorkingGrid Plan stable pair-overlap analysis grids.

    properties (Constant)
        Format = "ProjectionAlignmentWorkingGrid"
        Version = 1
    end

    methods (Static)
        function [grid, preparedLayers] = plan(scene, pair, options)
            %plan Build an isotropic, quantized grid over pair footprint overlap.
            if nargin < 3
                options = struct();
            end
            scene = ProjectionLayerIdentity.ensureScene(scene);
            pair = ProjectionAlignmentWorkingGrid.validatePair(scene, pair);
            options = ProjectionAlignmentWorkingGrid.mergeOptions(options);
            referencePlane = scene.layers(pair(2)).CurrentProjectionPlane;
            PlanarProjection.validatePlane(referencePlane);

            extents = repmat(struct(LayerIndex=0, LayerId="", ...
                Bounds=[NaN NaN NaN NaN]), 1, 2);
            preparedLayers = struct([]);
            resolutionCandidates = zeros(0, 1);
            for pairPosition = 1:2
                layerIndex = pair(pairPosition);
                layer = scene.layers(layerIndex);
                mesh = ProjectionMeshBuilder.buildLayerMesh( ...
                    layer, layer.CurrentProjectionPlane, scene.renderOrigin);
                coordinates = PlanarProjection.worldToPlane( ...
                    reshape(mesh.WorldPoints, 3, []), referencePlane);
                extents(pairPosition) = struct(LayerIndex=layerIndex, ...
                    LayerId=string(layer.LayerId), Bounds=[ ...
                    min(coordinates(1, :)), max(coordinates(1, :)), ...
                    min(coordinates(2, :)), max(coordinates(2, :))]);
                preparedLayer = struct(LayerIndex=layerIndex, Mesh=mesh);
                if isempty(preparedLayers)
                    preparedLayers = preparedLayer;
                else
                    preparedLayers(pairPosition) = preparedLayer;
                end
                resolutionCandidates = [resolutionCandidates; ...
                    ProjectionAlignmentWorkingGrid.layerResolutionCandidates( ...
                    layer, mesh)]; %#ok<AGROW>
            end

            rawBounds = [ ...
                max(extents(1).Bounds(1), extents(2).Bounds(1)), ...
                min(extents(1).Bounds(2), extents(2).Bounds(2)), ...
                max(extents(1).Bounds(3), extents(2).Bounds(3)), ...
                min(extents(1).Bounds(4), extents(2).Bounds(4))];
            if rawBounds(2) <= rawBounds(1) || rawBounds(4) <= rawBounds(3)
                error("ProjectionAlignmentWorkingGrid:noOverlap", ...
                    "Alignment layers %d and %d have no projection-plane footprint overlap.", ...
                    pair(1), pair(2));
            end

            baseResolution = ProjectionAlignmentWorkingGrid.baseResolution( ...
                options, resolutionCandidates);
            resolution = ProjectionAlignmentWorkingGrid.chooseResolution( ...
                rawBounds, baseResolution, options.OutputSize);
            [bounds, outputSize] = ProjectionAlignmentWorkingGrid.quantizedGrid( ...
                rawBounds, resolution);
            while ~isempty(options.OutputSize) && ...
                    any(outputSize > options.OutputSize)
                resolution = 2 * resolution;
                [bounds, outputSize] = ...
                    ProjectionAlignmentWorkingGrid.quantizedGrid( ...
                    rawBounds, resolution);
            end
            pixelCount = prod(outputSize);
            if ~options.AllowLargeOutput && pixelCount > options.MaxOutputPixels
                error("ProjectionAlignmentWorkingGrid:outputTooLarge", ...
                    "Pair working grid has %d pixels, exceeding MaxOutputPixels=%d.", ...
                    pixelCount, options.MaxOutputPixels);
            end

            grid = struct();
            grid.Format = ProjectionAlignmentWorkingGrid.Format;
            grid.Version = ProjectionAlignmentWorkingGrid.Version;
            grid.Pair = pair;
            grid.PairLayerIds = ProjectionLayerIdentity.idsForIndices(scene, pair);
            grid.ReferencePlane = referencePlane;
            grid.Origin = referencePlane.P0;
            grid.XAxis = referencePlane.basis(:, 1);
            grid.YAxis = referencePlane.basis(:, 2);
            grid.Normal = referencePlane.VN;
            grid.RawOverlapBounds = struct(X=rawBounds(1:2), ...
                Y=rawBounds(3:4));
            grid.Bounds = struct(X=bounds(1:2), Y=bounds(3:4));
            grid.OutputSize = outputSize;
            grid.ResolutionMetersPerPixel = resolution;
            grid.PixelSpacingMeters = [resolution resolution];
            grid.PixelCount = pixelCount;
            grid.LayerExtents = extents;
            grid.ResolutionCandidates = resolutionCandidates;
            grid.BaseResolutionMetersPerPixel = baseResolution;
            grid.QuantizationAnchor = [0 0];
            grid.GridKey = ProjectionAlignmentWorkingGrid.gridKey(grid);
        end
    end

    methods (Static, Access = private)
        function pair = validatePair(scene, pair)
            pair = double(pair(:).');
            if numel(pair) ~= 2 || any(~isfinite(pair)) || ...
                    any(fix(pair) ~= pair) || any(pair < 1) || ...
                    any(pair > numel(scene.layers)) || pair(1) == pair(2)
                error("ProjectionAlignmentWorkingGrid:invalidPair", ...
                    "Pair must select two distinct current scene layers.");
            end
        end

        function options = mergeOptions(options)
            if isempty(options)
                options = struct();
            end
            if ~isstruct(options) || ~isscalar(options)
                error("ProjectionAlignmentWorkingGrid:invalidOptions", ...
                    "Working-grid options must be a scalar struct.");
            end
            defaults = struct(OutputSize=[], ResolutionMetersPerPixel=[], ...
                MaxOutputPixels=100000000, AllowLargeOutput=false);
            names = fieldnames(defaults);
            for k = 1:numel(names)
                if isfield(options, names{k})
                    defaults.(names{k}) = options.(names{k});
                end
            end
            if ~isempty(defaults.OutputSize)
                defaults.OutputSize = ...
                    ProjectionAlignmentWorkingGrid.validateOutputSize( ...
                    defaults.OutputSize);
            end
            if ~isempty(defaults.ResolutionMetersPerPixel)
                defaults.ResolutionMetersPerPixel = ...
                    ProjectionAlignmentWorkingGrid.validatePositiveScalar( ...
                    defaults.ResolutionMetersPerPixel, ...
                    "ResolutionMetersPerPixel");
            end
            defaults.MaxOutputPixels = ...
                ProjectionAlignmentWorkingGrid.validatePositiveInteger( ...
                defaults.MaxOutputPixels, "MaxOutputPixels");
            defaults.AllowLargeOutput = logical(defaults.AllowLargeOutput);
            if ~isscalar(defaults.AllowLargeOutput)
                error("ProjectionAlignmentWorkingGrid:invalidOptions", ...
                    "AllowLargeOutput must be a scalar logical value.");
            end
            options = defaults;
        end

        function candidates = layerResolutionCandidates(layer, mesh)
            candidates = zeros(0, 1);
            sourceGeometry = layer.SourceGeometry;
            for fieldName = ["GSD", "PlatformStepMeters"]
                if isfield(sourceGeometry, fieldName)
                    value = sourceGeometry.(fieldName);
                    if isnumeric(value) && isscalar(value) && ...
                            isfinite(value) && value > 0
                        candidates(end + 1, 1) = double(value); %#ok<AGROW>
                    end
                end
            end
            if isfield(sourceGeometry, "IFOVRadians") && ...
                    isfield(sourceGeometry, "NominalRange")
                ifov = sourceGeometry.IFOVRadians;
                nominalRange = sourceGeometry.NominalRange;
                if isnumeric(ifov) && isscalar(ifov) && isfinite(ifov) && ...
                        ifov > 0 && isnumeric(nominalRange) && ...
                        isscalar(nominalRange) && isfinite(nominalRange) && ...
                        nominalRange > 0
                    candidates(end + 1, 1) = ...
                        double(ifov) * double(nominalRange);
                end
            end
            points = mesh.WorldPoints;
            if size(points, 2) > 1
                distances = squeeze(sqrt(sum(diff(points, 1, 2).^2, 1)));
                rowSteps = diff(double(mesh.RowIndices(:)));
                candidates = [candidates; ...
                    reshape(distances ./ rowSteps, [], 1)];
            end
            if size(points, 3) > 1
                distances = squeeze(sqrt(sum(diff(points, 1, 3).^2, 1)));
                columnSteps = diff(double(mesh.ColumnIndices(:))).';
                candidates = [candidates; ...
                    reshape(distances ./ columnSteps, [], 1)];
            end
            candidates = candidates(isfinite(candidates) & candidates > 0);
        end

        function resolution = baseResolution(options, candidates)
            if ~isempty(options.ResolutionMetersPerPixel)
                resolution = options.ResolutionMetersPerPixel;
                return
            end
            candidates = candidates(isfinite(candidates) & candidates > 0);
            if isempty(candidates)
                error("ProjectionAlignmentWorkingGrid:missingResolution", ...
                    "Unable to infer a physical working-image resolution.");
            end
            resolution = min(candidates);
        end

        function resolution = chooseResolution(bounds, baseResolution, targetSize)
            resolution = baseResolution;
            if isempty(targetSize)
                return
            end
            spans = [bounds(4) - bounds(3), bounds(2) - bounds(1)];
            availableIntervals = max(targetSize - 1, 1);
            requiredScale = max(spans ./ ...
                (availableIntervals * baseResolution));
            if requiredScale > 1
                resolution = baseResolution * 2 ^ ceil(log2(requiredScale));
            end
        end

        function [bounds, outputSize] = quantizedGrid(rawBounds, resolution)
            quotient = rawBounds / resolution;
            snapTolerance = 0.05;
            rounded = round(quotient);
            snappedMask = abs(quotient - rounded) <= snapTolerance;
            lowerX = floor(quotient(1));
            upperX = ceil(quotient(2));
            lowerY = floor(quotient(3));
            upperY = ceil(quotient(4));
            if snappedMask(1), lowerX = rounded(1); end
            if snappedMask(2), upperX = rounded(2); end
            if snappedMask(3), lowerY = rounded(3); end
            if snappedMask(4), upperY = rounded(4); end
            bounds = resolution * [lowerX, upperX, lowerY, upperY];
            outputSize = [round((bounds(4) - bounds(3)) / resolution) + 1, ...
                round((bounds(2) - bounds(1)) / resolution) + 1];
            outputSize = max(1, double(outputSize));
        end

        function key = gridKey(grid)
            key = sprintf("%s->%s_R%.17g_X%.17g_%.17g_Y%.17g_%.17g", ...
                grid.PairLayerIds(1), grid.PairLayerIds(2), ...
                grid.ResolutionMetersPerPixel, grid.Bounds.X(1), ...
                grid.Bounds.X(2), grid.Bounds.Y(1), grid.Bounds.Y(2));
        end

        function outputSize = validateOutputSize(outputSize)
            if ~isnumeric(outputSize) || numel(outputSize) ~= 2 || ...
                    any(~isfinite(outputSize)) || any(outputSize < 2) || ...
                    any(fix(outputSize) ~= outputSize)
                error("ProjectionAlignmentWorkingGrid:invalidOptions", ...
                    "OutputSize must contain two finite integers of at least 2.");
            end
            outputSize = double(outputSize(:).');
        end

        function value = validatePositiveScalar(value, name)
            if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value) || ...
                    value <= 0
                error("ProjectionAlignmentWorkingGrid:invalidOptions", ...
                    "%s must be a positive finite scalar.", name);
            end
            value = double(value);
        end

        function value = validatePositiveInteger(value, name)
            value = ProjectionAlignmentWorkingGrid.validatePositiveScalar( ...
                value, name);
            if fix(value) ~= value
                error("ProjectionAlignmentWorkingGrid:invalidOptions", ...
                    "%s must be a positive integer.", name);
            end
        end
    end
end
