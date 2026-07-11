classdef ProjectionBackendOutputGrid
    %ProjectionBackendOutputGrid Plan backend output grid extents and axes.

    properties (Constant)
        Format = "ProjectionBackendOutputGrid"
        Version = 1
    end

    methods (Static)
        function [grid, preparedLayers] = plan(scene, viewerState, options)
            %plan Plan a full-extent output grid over visible scene layers.
            if nargin < 2
                viewerState = [];
            end
            if nargin < 3
                options = struct();
            end
            if ProjectionBackendOutputGrid.isOptionsOnly(viewerState)
                options = viewerState;
                viewerState = [];
            end

            ProjectionBackendOutputGrid.validateScene(scene);
            options = ProjectionBackendOutputGrid.mergeOptions(options);
            twistDegrees = ProjectionBackendOutputGrid.twistDegrees(viewerState, options);
            if ~isempty(viewerState)
                [scene, ~] = ProjectionViewerState.applyToScene(scene, viewerState);
            end

            layerIndices = ProjectionBackendOutputGrid.visibleLayerIndices(scene.layers);
            referencePlane = scene.layers(layerIndices(1)).CurrentProjectionPlane;
            [xAxis, yAxis] = ProjectionBackendOutputGrid.outputAxes( ...
                referencePlane, twistDegrees);

            allX = zeros(0, 1);
            allY = zeros(0, 1);
            layerExtents = struct([]);
            preparedLayers = struct([]);
            resolutionCandidates = zeros(0, 1);
            for outputIndex = 1:numel(layerIndices)
                layerIndex = layerIndices(outputIndex);
                layer = scene.layers(layerIndex);
                mesh = ProjectionMeshBuilder.buildLayerMesh( ...
                    layer, layer.CurrentProjectionPlane, scene.renderOrigin);
                preparedLayer = struct(LayerIndex=layerIndex, Mesh=mesh);
                if isempty(preparedLayers)
                    preparedLayers = preparedLayer;
                else
                    preparedLayers(outputIndex) = preparedLayer;
                end
                coordinates = ProjectionBackendOutputGrid.projectPointsToAxes( ...
                    mesh.WorldPoints, referencePlane.P0, xAxis, yAxis);
                extent = ProjectionBackendOutputGrid.extentFromCoordinates(coordinates);
                layerExtents(outputIndex).LayerIndex = layerIndex;
                layerExtents(outputIndex).Bounds = extent;
                layerExtents(outputIndex).MeshRowCount = size(mesh.WorldPoints, 2);
                layerExtents(outputIndex).MeshColumnCount = size(mesh.WorldPoints, 3);

                allX = [allX; coordinates(1, :).']; %#ok<AGROW>
                allY = [allY; coordinates(2, :).']; %#ok<AGROW>
                resolutionCandidates = [resolutionCandidates; ...
                    ProjectionBackendOutputGrid.layerResolutionCandidates(layer, mesh)]; %#ok<AGROW>
            end

            bounds = struct();
            bounds.X = [min(allX), max(allX)];
            bounds.Y = [min(allY), max(allY)];
            resolutionMeters = ProjectionBackendOutputGrid.chooseResolution( ...
                options, resolutionCandidates);
            outputSize = ProjectionBackendOutputGrid.outputSizeFromBounds( ...
                bounds, resolutionMeters, options);
            ProjectionBackendOutputGrid.validatePixelCount(outputSize, options);

            grid = struct();
            grid.Format = ProjectionBackendOutputGrid.Format;
            grid.Version = ProjectionBackendOutputGrid.Version;
            grid.LayerIndices = layerIndices;
            grid.LayerExtents = layerExtents;
            grid.ReferencePlane = referencePlane;
            grid.TwistDegrees = twistDegrees;
            grid.XAxis = xAxis;
            grid.YAxis = yAxis;
            grid.Normal = referencePlane.VN;
            grid.Origin = referencePlane.P0;
            grid.Bounds = bounds;
            grid.OutputSize = outputSize;
            grid.ResolutionMetersPerPixel = resolutionMeters;
            grid.PixelSpacingMeters = ProjectionBackendOutputGrid.pixelSpacing( ...
                bounds, outputSize);
            grid.PixelCount = prod(outputSize);
            grid.MaxOutputPixels = options.MaxOutputPixels;
            grid.AllowLargeOutput = options.AllowLargeOutput;
            grid.ResolutionCandidates = resolutionCandidates;
        end
    end

    methods (Static, Access = private)
        function tf = isOptionsOnly(value)
            tf = isstruct(value) && isscalar(value) && ...
                ~ProjectionViewerState.isState(value);
        end

        function options = mergeOptions(options)
            if isempty(options)
                options = struct();
            end
            if ~isstruct(options) || ~isscalar(options)
                error("ProjectionBackendOutputGrid:invalidOptions", ...
                    "Output-grid options must be a scalar struct.");
            end

            defaults = struct();
            defaults.OutputSize = [];
            defaults.ResolutionMetersPerPixel = [];
            defaults.MaxOutputPixels = 100000000;
            defaults.AllowLargeOutput = false;
            defaults.TwistDegrees = [];

            names = fieldnames(options);
            for k = 1:numel(names)
                defaults.(names{k}) = options.(names{k});
            end

            if ~isempty(defaults.OutputSize)
                defaults.OutputSize = ProjectionBackendOutputGrid.validateOutputSize( ...
                    defaults.OutputSize);
            end
            if ~isempty(defaults.ResolutionMetersPerPixel)
                defaults.ResolutionMetersPerPixel = ...
                    ProjectionBackendOutputGrid.validatePositiveScalar( ...
                    defaults.ResolutionMetersPerPixel, "ResolutionMetersPerPixel");
            end
            defaults.MaxOutputPixels = ProjectionBackendOutputGrid.validatePositiveInteger( ...
                defaults.MaxOutputPixels, "MaxOutputPixels");
            defaults.AllowLargeOutput = ProjectionBackendOutputGrid.validateLogicalScalar( ...
                defaults.AllowLargeOutput, "AllowLargeOutput");
            if ~isempty(defaults.TwistDegrees)
                defaults.TwistDegrees = ProjectionBackendOutputGrid.validateFiniteScalar( ...
                    defaults.TwistDegrees, "TwistDegrees");
            end

            options = defaults;
        end

        function validateScene(scene)
            if ~isstruct(scene) || ~isscalar(scene) || ~isfield(scene, "layers") || ...
                    ~isfield(scene, "renderOrigin") || isempty(scene.layers) || ...
                    ~isstruct(scene.layers)
                error("ProjectionBackendOutputGrid:invalidScene", ...
                    "Scene must contain renderOrigin and a nonempty layer struct array.");
            end
            if ~isnumeric(scene.renderOrigin) || ~isequal(size(scene.renderOrigin), [3 1]) || ...
                    any(~isfinite(scene.renderOrigin))
                error("ProjectionBackendOutputGrid:invalidScene", ...
                    "Scene renderOrigin must be a finite numeric 3x1 vector.");
            end
        end

        function layerIndices = visibleLayerIndices(layers)
            if ~all(isfield(layers, "Visible"))
                error("ProjectionBackendOutputGrid:invalidScene", ...
                    "Scene layers must contain Visible flags.");
            end
            layerIndices = find([layers.Visible]);
            if isempty(layerIndices)
                error("ProjectionBackendOutputGrid:noVisibleLayer", ...
                    "At least one visible layer is required to plan an output grid.");
            end
        end

        function twistDegrees = twistDegrees(viewerState, options)
            if ~isempty(options.TwistDegrees)
                twistDegrees = options.TwistDegrees;
                return
            end
            if isempty(viewerState)
                twistDegrees = 0;
                return
            end
            viewerState = ProjectionViewerState.validate(viewerState);
            twistDegrees = viewerState.View.TwistDegrees;
        end

        function [xAxis, yAxis] = outputAxes(plane, twistDegrees)
            PlanarProjection.validatePlane(plane);
            R = ProjectionBackendOutputGrid.rotationAboutAxis( ...
                plane.VN, deg2rad(twistDegrees));
            xAxis = R * plane.basis(:, 1);
            yAxis = R * plane.basis(:, 2);
        end

        function coordinates = projectPointsToAxes(worldPoints, origin, xAxis, yAxis)
            points = reshape(worldPoints, 3, []);
            relativePoints = points - origin;
            coordinates = [xAxis.' * relativePoints; yAxis.' * relativePoints];
        end

        function extent = extentFromCoordinates(coordinates)
            extent = struct();
            extent.X = [min(coordinates(1, :)), max(coordinates(1, :))];
            extent.Y = [min(coordinates(2, :)), max(coordinates(2, :))];
        end

        function candidates = layerResolutionCandidates(layer, mesh)
            candidates = zeros(0, 1);
            sourceGeometry = layer.SourceGeometry;
            candidates = [candidates; ...
                ProjectionBackendOutputGrid.optionalPositiveScalar( ...
                sourceGeometry, "GSD")];
            candidates = [candidates; ...
                ProjectionBackendOutputGrid.optionalPositiveScalar( ...
                sourceGeometry, "PlatformStepMeters")];

            if isfield(sourceGeometry, "IFOVRadians") && ...
                    isfield(sourceGeometry, "NominalRange")
                ifov = ProjectionBackendOutputGrid.optionalPositiveScalar( ...
                    sourceGeometry, "IFOVRadians");
                nominalRange = ProjectionBackendOutputGrid.optionalPositiveScalar( ...
                    sourceGeometry, "NominalRange");
                if ~isempty(ifov) && ~isempty(nominalRange)
                    candidates = [candidates; ifov * nominalRange];
                end
            end

            candidates = [candidates; ...
                ProjectionBackendOutputGrid.meshSpacingCandidates(mesh)];
            candidates = candidates(isfinite(candidates) & candidates > 0);
        end

        function value = optionalPositiveScalar(source, fieldName)
            value = [];
            if ~isfield(source, fieldName)
                return
            end
            candidate = source.(fieldName);
            if isnumeric(candidate) && isscalar(candidate) && isfinite(candidate) && ...
                    candidate > 0
                value = double(candidate);
            end
        end

        function candidates = meshSpacingCandidates(mesh)
            points = mesh.WorldPoints;
            candidates = zeros(0, 1);
            if size(points, 2) > 1
                rowDiff = diff(points, 1, 2);
                rowSpacing = sqrt(sum(rowDiff.^2, 1));
                candidates = [candidates; rowSpacing(:)];
            end
            if size(points, 3) > 1
                columnDiff = diff(points, 1, 3);
                columnSpacing = sqrt(sum(columnDiff.^2, 1));
                candidates = [candidates; columnSpacing(:)];
            end
        end

        function resolution = chooseResolution(options, candidates)
            if ~isempty(options.ResolutionMetersPerPixel)
                resolution = options.ResolutionMetersPerPixel;
                return
            end
            candidates = candidates(isfinite(candidates) & candidates > 0);
            if isempty(candidates)
                error("ProjectionBackendOutputGrid:missingResolution", ...
                    "Unable to infer output resolution; supply ResolutionMetersPerPixel.");
            end
            resolution = min(candidates);
        end

        function outputSize = outputSizeFromBounds(bounds, resolution, options)
            if ~isempty(options.OutputSize)
                outputSize = options.OutputSize;
                return
            end
            width = max(bounds.X(2) - bounds.X(1), 0);
            height = max(bounds.Y(2) - bounds.Y(1), 0);
            outputSize = [ ...
                max(1, ceil(height / resolution) + 1), ...
                max(1, ceil(width / resolution) + 1)];
            outputSize = double(outputSize);
        end

        function spacing = pixelSpacing(bounds, outputSize)
            height = max(bounds.Y(2) - bounds.Y(1), 0);
            width = max(bounds.X(2) - bounds.X(1), 0);
            rowSpacing = ProjectionBackendOutputGrid.axisSpacing(height, outputSize(1));
            columnSpacing = ProjectionBackendOutputGrid.axisSpacing(width, outputSize(2));
            spacing = [rowSpacing, columnSpacing];
        end

        function spacing = axisSpacing(span, sampleCount)
            if sampleCount <= 1
                spacing = span;
            else
                spacing = span / (sampleCount - 1);
            end
        end

        function validatePixelCount(outputSize, options)
            pixelCount = prod(outputSize);
            if ~options.AllowLargeOutput && pixelCount > options.MaxOutputPixels
                error("ProjectionBackendOutputGrid:outputTooLarge", ...
                    "Planned output grid has %d pixels, exceeding MaxOutputPixels=%d.", ...
                    pixelCount, options.MaxOutputPixels);
            end
        end

        function outputSize = validateOutputSize(outputSize)
            if ~isnumeric(outputSize) || ~isvector(outputSize) || numel(outputSize) ~= 2 || ...
                    any(~isfinite(outputSize)) || any(outputSize < 1) || ...
                    any(fix(outputSize) ~= outputSize)
                error("ProjectionBackendOutputGrid:invalidOptions", ...
                    "OutputSize must be a finite positive 1x2 integer vector.");
            end
            outputSize = double(outputSize(:).');
        end

        function value = validatePositiveScalar(value, name)
            if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value) || value <= 0
                error("ProjectionBackendOutputGrid:invalidOptions", ...
                    "%s must be a positive finite scalar.", name);
            end
            value = double(value);
        end

        function value = validatePositiveInteger(value, name)
            value = ProjectionBackendOutputGrid.validatePositiveScalar(value, name);
            if fix(value) ~= value
                error("ProjectionBackendOutputGrid:invalidOptions", ...
                    "%s must be a positive integer scalar.", name);
            end
        end

        function value = validateFiniteScalar(value, name)
            if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value)
                error("ProjectionBackendOutputGrid:invalidOptions", ...
                    "%s must be a finite numeric scalar.", name);
            end
            value = double(value);
        end

        function value = validateLogicalScalar(value, name)
            if ~(islogical(value) || isnumeric(value)) || ~isscalar(value)
                error("ProjectionBackendOutputGrid:invalidOptions", ...
                    "%s must be a scalar logical value.", name);
            end
            value = logical(value);
        end

        function R = rotationAboutAxis(axis, angle)
            axis = axis(:) / norm(axis);
            K = [0 -axis(3) axis(2); axis(3) 0 -axis(1); -axis(2) axis(1) 0];
            R = cos(angle) * eye(3) + (1 - cos(angle)) * (axis * axis.') + sin(angle) * K;
        end
    end
end
