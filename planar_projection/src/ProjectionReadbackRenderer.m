classdef ProjectionReadbackRenderer
    %ProjectionReadbackRenderer Headless frame-camera readback prototype.

    methods (Static)
        function readback = renderScene(scene, options)
            %renderScene Render visible layers without MATLAB graphics.
            if nargin < 2
                options = struct();
            end

            ProjectionReadbackRenderer.validateScene(scene);
            layerIndices = ProjectionReadbackRenderer.visibleLayerIndices(scene.layers);
            firstLayer = scene.layers(layerIndices(1));
            options = ProjectionReadbackRenderer.mergeOptions(options, firstLayer);

            firstPlane = firstLayer.CurrentProjectionPlane;
            firstMesh = ProjectionMeshBuilder.buildLayerMesh( ...
                firstLayer, firstPlane, scene.renderOrigin);
            cameraGrid = ProjectionReadbackRenderer.createCameraGrid( ...
                scene.frameCamera, firstMesh, options.OutputSize);

            compositeImage = [];
            validMask = false(options.OutputSize);
            anaglyphOrdinal = 0;
            layerReadbacks = struct([]);

            for outputIndex = 1:numel(layerIndices)
                layerIndex = layerIndices(outputIndex);
                layer = scene.layers(layerIndex);
                plane = layer.CurrentProjectionPlane;
                mesh = ProjectionMeshBuilder.buildLayerMesh(layer, plane, scene.renderOrigin);
                [layerImage, layerValidMask, queryPlaneCoordinates] = ...
                    ProjectionReadbackRenderer.renderLayer( ...
                    scene.frameCamera, layer, plane, mesh, cameraGrid, options);

                [compositeImage, validMask, anaglyphOrdinal] = ...
                    ProjectionReadbackRenderer.blendLayer( ...
                    compositeImage, validMask, layerImage, layerValidMask, ...
                    layer, options, anaglyphOrdinal);

                layerReadbacks(outputIndex).Image = layerImage;
                layerReadbacks(outputIndex).ValidMask = layerValidMask;
                layerReadbacks(outputIndex).LayerIndex = layerIndex;
                layerReadbacks(outputIndex).QueryPlaneCoordinates = queryPlaneCoordinates;
                layerReadbacks(outputIndex).Mesh = mesh;
            end

            readback = struct();
            readback.Image = compositeImage;
            readback.ValidMask = validMask;
            readback.OutputSize = options.OutputSize;
            readback.Interpolation = options.Interpolation;
            readback.LayerIndex = layerIndices(1);
            readback.LayerIndices = layerIndices;
            readback.CameraGrid = cameraGrid;
            readback.QueryPlaneCoordinates = layerReadbacks(1).QueryPlaneCoordinates;
            readback.Mesh = layerReadbacks(1).Mesh;
            readback.LayerReadbacks = layerReadbacks;
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

        function layerIndices = visibleLayerIndices(layers)
            visible = [layers.Visible];
            layerIndices = find(visible);
            if isempty(layerIndices)
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

        function cameraGrid = createCameraGrid(frameCamera, mesh, outputSize)
            numRows = size(mesh.X, 1);
            numColumns = size(mesh.X, 2);
            worldPoints = reshape(mesh.WorldPoints, 3, []);
            [Qcamera, ~] = PlanarProjection.projectToCamera(worldPoints, frameCamera);
            cameraX = reshape(Qcamera(1, :), numRows, numColumns);
            cameraY = reshape(Qcamera(2, :), numRows, numColumns);

            queryX = linspace(min(cameraX, [], "all"), max(cameraX, [], "all"), ...
                outputSize(2));
            queryY = linspace(max(cameraY, [], "all"), min(cameraY, [], "all"), ...
                outputSize(1));
            [cameraGrid.X, cameraGrid.Y] = meshgrid(queryX, queryY);
        end

        function [outputImage, validMask, queryPlaneCoordinates] = renderLayer( ...
                frameCamera, layer, plane, mesh, cameraGrid, options)
            queryCameraCoordinates = [cameraGrid.X(:).'; cameraGrid.Y(:).'];

            [queryPlaneCoordinates, ~] = PlanarProjection.projectCameraToPlane( ...
                queryCameraCoordinates, frameCamera, plane);

            worldPoints = reshape(mesh.WorldPoints, 3, []);
            meshPlaneCoordinates = PlanarProjection.worldToPlane(worldPoints, plane);
            sampledImage = layer.Image(mesh.RowIndices, mesh.ColumnIndices, :);
            outputImage = ProjectionReadbackRenderer.interpolateImage( ...
                meshPlaneCoordinates, sampledImage, queryPlaneCoordinates, options);
            validMask = ProjectionReadbackRenderer.createValidMask(outputImage);
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

        function [compositeImage, validMask, anaglyphOrdinal] = blendLayer( ...
                compositeImage, validMask, layerImage, layerValidMask, layer, ...
                options, anaglyphOrdinal)
            blendMode = lower(string(layer.BlendMode));
            alpha = double(layer.Alpha);

            switch blendMode
                case "alpha"
                    [compositeImage, validMask] = ProjectionReadbackRenderer.alphaBlend( ...
                        compositeImage, validMask, layerImage, layerValidMask, alpha, options);
                case "redblueanaglyph"
                    anaglyphOrdinal = anaglyphOrdinal + 1;
                    [compositeImage, validMask] = ProjectionReadbackRenderer.anaglyphBlend( ...
                        compositeImage, validMask, layerImage, layerValidMask, ...
                        alpha, options, anaglyphOrdinal);
                otherwise
                    error("ProjectionReadbackRenderer:invalidBlendMode", ...
                        "Unsupported layer blend mode ""%s"".", layer.BlendMode);
            end
        end

        function [compositeImage, validMask] = alphaBlend( ...
                compositeImage, validMask, layerImage, layerValidMask, alpha, options)
            if isempty(compositeImage)
                compositeImage = zeros(size(layerImage));
            end
            [compositeImage, layerImage] = ProjectionReadbackRenderer.matchBandCounts( ...
                compositeImage, layerImage, options.OutputSize);
            layerImage = ProjectionReadbackRenderer.replaceInvalid(layerImage);
            alphaMask = alpha * double(layerValidMask);
            if ~ismatrix(compositeImage)
                alphaMask = repmat(alphaMask, 1, 1, size(compositeImage, 3));
            end
            compositeImage = compositeImage .* (1 - alphaMask) + layerImage .* alphaMask;
            validMask = validMask | layerValidMask;
        end

        function [compositeImage, validMask] = anaglyphBlend( ...
                compositeImage, validMask, layerImage, layerValidMask, alpha, ...
                options, anaglyphOrdinal)
            if isempty(compositeImage) || ismatrix(compositeImage)
                compositeImage = zeros([options.OutputSize 3]);
            end
            grayImage = ProjectionReadbackRenderer.grayscale(layerImage);
            grayImage = ProjectionReadbackRenderer.replaceInvalid(grayImage);
            contribution = zeros([options.OutputSize 3]);
            channelIndex = 1 + 2 * double(mod(anaglyphOrdinal, 2) == 0);
            contribution(:, :, channelIndex) = grayImage;
            contribution = alpha * contribution;
            contribution(repmat(~layerValidMask, 1, 1, 3)) = 0;
            compositeImage = max(compositeImage, contribution);
            validMask = validMask | layerValidMask;
        end

        function [A, B] = matchBandCounts(A, B, outputSize)
            if ismatrix(A) && ~ismatrix(B)
                A = repmat(A, 1, 1, size(B, 3));
            elseif ~ismatrix(A) && ismatrix(B)
                B = repmat(B, 1, 1, size(A, 3));
            elseif isempty(A)
                A = zeros(outputSize);
            end
        end

        function grayImage = grayscale(imageData)
            if ismatrix(imageData)
                grayImage = imageData;
            else
                grayImage = mean(imageData, 3);
            end
        end

        function imageData = replaceInvalid(imageData)
            imageData(~isfinite(imageData)) = 0;
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
