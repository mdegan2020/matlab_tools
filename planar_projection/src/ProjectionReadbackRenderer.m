classdef ProjectionReadbackRenderer
    %ProjectionReadbackRenderer Headless frame-camera readback prototype.

    methods (Static)
        function readback = renderScene(scene, options)
            %renderScene Render the first visible layer without MATLAB graphics.
            if nargin < 2
                options = struct();
            end

            ProjectionReadbackRenderer.validateScene(scene);
            layerIndex = ProjectionReadbackRenderer.firstVisibleLayerIndex(scene.layers);
            layer = scene.layers(layerIndex);
            options = ProjectionReadbackRenderer.mergeOptions(options, layer);
            plane = layer.CurrentProjectionPlane;

            mesh = ProjectionMeshBuilder.buildLayerMesh(layer, plane, scene.renderOrigin);
            [outputImage, validMask, cameraGrid, queryPlaneCoordinates] = ...
                ProjectionReadbackRenderer.renderLayer(scene.frameCamera, layer, plane, mesh, options);

            readback = struct();
            readback.Image = outputImage;
            readback.ValidMask = validMask;
            readback.OutputSize = options.OutputSize;
            readback.Interpolation = options.Interpolation;
            readback.LayerIndex = layerIndex;
            readback.CameraGrid = cameraGrid;
            readback.QueryPlaneCoordinates = queryPlaneCoordinates;
            readback.Mesh = mesh;
        end
    end

    methods (Static, Access = private)
        function validateScene(scene)
            if ~isstruct(scene) || ~isscalar(scene) || ~isfield(scene, "frameCamera") || ...
                    ~isfield(scene, "renderOrigin") || ~isfield(scene, "layers")
                error("ProjectionReadbackRenderer:invalidScene", ...
                    "Scene must contain frameCamera, renderOrigin, and layers.");
            end

            PlanarProjection.validateCamera(scene.frameCamera);
            if isempty(scene.layers) || ~isstruct(scene.layers)
                error("ProjectionReadbackRenderer:invalidScene", ...
                    "Scene must contain at least one layer.");
            end
        end

        function layerIndex = firstVisibleLayerIndex(layers)
            visible = [layers.Visible];
            layerIndex = find(visible, 1, "first");
            if isempty(layerIndex)
                error("ProjectionReadbackRenderer:noVisibleLayer", ...
                    "Scene must contain at least one visible layer.");
            end
        end

        function options = mergeOptions(options, layer)
            if isempty(options)
                options = struct();
            end
            if ~isstruct(options) || ~isscalar(options)
                error("ProjectionReadbackRenderer:invalidOptions", ...
                    "Options must be a scalar struct.");
            end

            defaults = struct();
            defaults.OutputSize = [numel(layer.MeshSampling.RowIndices), ...
                numel(layer.MeshSampling.ColumnIndices)];
            defaults.Interpolation = "bilinear";
            defaults.InvalidFillValue = NaN;

            names = fieldnames(options);
            for k = 1:numel(names)
                defaults.(names{k}) = options.(names{k});
            end

            defaults.OutputSize = ProjectionReadbackRenderer.validateOutputSize( ...
                defaults.OutputSize);
            defaults.Interpolation = ProjectionReadbackRenderer.validateInterpolation( ...
                defaults.Interpolation);
            defaults.InvalidFillValue = ProjectionReadbackRenderer.validateFillValue( ...
                defaults.InvalidFillValue, "InvalidFillValue");

            options = defaults;
        end

        function [outputImage, validMask, cameraGrid, queryPlaneCoordinates] = renderLayer( ...
                frameCamera, layer, plane, mesh, options)
            numRows = size(mesh.X, 1);
            numColumns = size(mesh.X, 2);
            worldPoints = reshape(mesh.WorldPoints, 3, []);
            [Qcamera, ~] = PlanarProjection.projectToCamera(worldPoints, frameCamera);
            cameraX = reshape(Qcamera(1, :), numRows, numColumns);
            cameraY = reshape(Qcamera(2, :), numRows, numColumns);

            queryX = linspace(min(cameraX, [], "all"), max(cameraX, [], "all"), ...
                options.OutputSize(2));
            queryY = linspace(max(cameraY, [], "all"), min(cameraY, [], "all"), ...
                options.OutputSize(1));
            [cameraGridX, cameraGridY] = meshgrid(queryX, queryY);
            queryCameraCoordinates = [cameraGridX(:).'; cameraGridY(:).'];

            [queryPlaneCoordinates, ~] = PlanarProjection.projectCameraToPlane( ...
                queryCameraCoordinates, frameCamera, plane);

            meshPlaneCoordinates = PlanarProjection.worldToPlane(worldPoints, plane);
            sampledImage = layer.Image(mesh.RowIndices, mesh.ColumnIndices, :);
            outputImage = ProjectionReadbackRenderer.interpolateImage( ...
                meshPlaneCoordinates, sampledImage, queryPlaneCoordinates, options);
            validMask = ProjectionReadbackRenderer.createValidMask(outputImage);

            cameraGrid = struct();
            cameraGrid.X = cameraGridX;
            cameraGrid.Y = cameraGridY;
        end

        function outputImage = interpolateImage(meshPlaneCoordinates, sampledImage, ...
                queryPlaneCoordinates, options)
            bandCount = size(sampledImage, 3);
            outputSize = options.OutputSize;
            outputImage = zeros([outputSize bandCount]);
            method = ProjectionReadbackRenderer.scatteredMethod(options.Interpolation);

            for bandIndex = 1:bandCount
                sampledBand = double(sampledImage(:, :, bandIndex));
                interpolant = scatteredInterpolant( ...
                    meshPlaneCoordinates(1, :).', meshPlaneCoordinates(2, :).', ...
                    sampledBand(:), method, "none");
                renderedBand = reshape(interpolant( ...
                    queryPlaneCoordinates(1, :).', queryPlaneCoordinates(2, :).'), ...
                    outputSize);
                renderedBand(isnan(renderedBand)) = options.InvalidFillValue;
                outputImage(:, :, bandIndex) = renderedBand;
            end

            if bandCount == 1
                outputImage = outputImage(:, :, 1);
            end
        end

        function validMask = createValidMask(outputImage)
            if ismatrix(outputImage)
                validMask = isfinite(outputImage);
            else
                validMask = all(isfinite(outputImage), 3);
            end
        end

        function outputSize = validateOutputSize(outputSize)
            if ~isnumeric(outputSize) || ~isequal(size(outputSize), [1 2]) || ...
                    any(~isfinite(outputSize)) || any(outputSize < 1) || ...
                    any(fix(outputSize) ~= outputSize)
                error("ProjectionReadbackRenderer:invalidOptions", ...
                    "OutputSize must be a finite positive 1x2 integer vector.");
            end
            outputSize = double(outputSize);
        end

        function interpolation = validateInterpolation(interpolation)
            interpolation = lower(string(interpolation));
            if ~isscalar(interpolation) || ~ismember(interpolation, ["bilinear", "nearest"])
                error("ProjectionReadbackRenderer:invalidOptions", ...
                    "Interpolation must be ""bilinear"" or ""nearest"".");
            end
        end

        function method = scatteredMethod(interpolation)
            switch interpolation
                case "bilinear"
                    method = "linear";
                case "nearest"
                    method = "nearest";
            end
        end

        function value = validateFillValue(value, name)
            if ~isnumeric(value) || ~isscalar(value)
                error("ProjectionReadbackRenderer:invalidOptions", ...
                    "%s must be a numeric scalar.", name);
            end
            value = double(value);
        end
    end
end
