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
            samplingGrid = ProjectionReadbackRenderer.createSamplingGrid( ...
                scene.frameCamera, firstMesh, options);

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
                    scene.frameCamera, layer, plane, mesh, samplingGrid, options);

                [compositeImage, validMask, anaglyphOrdinal] = ...
                    ProjectionReadbackRenderer.blendLayer( ...
                    compositeImage, validMask, layerImage, layerValidMask, ...
                    layer, options, anaglyphOrdinal);

                if options.IncludeLayerReadbacks
                    layerReadbacks(outputIndex).Image = layerImage;
                    layerReadbacks(outputIndex).ValidMask = layerValidMask;
                    layerReadbacks(outputIndex).LayerIndex = layerIndex;
                    layerReadbacks(outputIndex).QueryPlaneCoordinates = queryPlaneCoordinates;
                    layerReadbacks(outputIndex).Mesh = mesh;
                end
            end

            if options.UseGPU
                compositeImage = ProjectionReadbackRenderer.gatherIfNeeded( ...
                    compositeImage);
                validMask = ProjectionReadbackRenderer.gatherIfNeeded(validMask);
            end

            readback = struct();
            readback.Image = compositeImage;
            readback.ValidMask = validMask;
            readback.OutputSize = options.OutputSize;
            readback.Interpolation = options.Interpolation;
            readback.LayerIndex = layerIndices(1);
            readback.LayerIndices = layerIndices;
            readback.CameraGrid = samplingGrid;
            readback.QueryPlaneCoordinates = ...
                ProjectionReadbackRenderer.firstLayerField(layerReadbacks, ...
                "QueryPlaneCoordinates");
            readback.Mesh = ProjectionReadbackRenderer.firstLayerField( ...
                layerReadbacks, "Mesh");
            readback.LayerReadbacks = layerReadbacks;
            readback.UseGPU = options.UseGPU;
            readback.GpuInfo = options.GpuInfo;
            if isfield(options, "OutputGrid")
                readback.OutputGrid = options.OutputGrid;
            else
                readback.OutputGrid = [];
            end
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
            defaults.OutputGrid = [];
            defaults.Interpolation = "bilinear";
            defaults.InvalidFillValue = NaN;
            defaults.IncludeLayerReadbacks = true;
            defaults.UseGPU = false;
            defaults.GpuInfo = ProjectionBackendGpuSupport.resolve(false);

            names = fieldnames(options);
            for k = 1:numel(names)
                defaults.(names{k}) = options.(names{k});
            end

            defaults.OutputGrid = ProjectionReadbackRenderer.validateOutputGrid( ...
                defaults.OutputGrid);
            if ~isempty(defaults.OutputGrid)
                defaults.OutputSize = ProjectionReadbackRenderer.validateOutputSize( ...
                    defaults.OutputGrid.OutputSize);
            else
                defaults.OutputSize = ProjectionReadbackRenderer.validateOutputSize( ...
                    defaults.OutputSize);
            end
            defaults.Interpolation = ProjectionReadbackRenderer.validateInterpolation( ...
                defaults.Interpolation);
            defaults.InvalidFillValue = ProjectionReadbackRenderer.validateFillValue( ...
                defaults.InvalidFillValue, "InvalidFillValue");
            defaults.IncludeLayerReadbacks = ...
                ProjectionReadbackRenderer.validateLogicalScalar( ...
                defaults.IncludeLayerReadbacks, "IncludeLayerReadbacks");
            defaults.UseGPU = ProjectionReadbackRenderer.validateLogicalScalar( ...
                defaults.UseGPU, "UseGPU");
            defaults.GpuInfo = ProjectionBackendGpuSupport.resolve(defaults.UseGPU);
            defaults.UseGPU = defaults.GpuInfo.Enabled;

            options = defaults;
        end

        function samplingGrid = createSamplingGrid(frameCamera, mesh, options)
            if ~isempty(options.OutputGrid)
                samplingGrid = ProjectionReadbackRenderer.createOutputSamplingGrid( ...
                    frameCamera, options.OutputGrid);
                return
            end

            samplingGrid = ProjectionReadbackRenderer.createCameraGrid( ...
                frameCamera, mesh, options.OutputSize);
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
            cameraGrid.QueryCameraCoordinates = [cameraGrid.X(:).'; cameraGrid.Y(:).'];
            cameraGrid.QueryWorldPoints = [];
        end

        function outputGrid = createOutputSamplingGrid(frameCamera, outputGrid)
            bounds = outputGrid.Bounds;
            queryX = linspace(bounds.X(1), bounds.X(2), outputGrid.OutputSize(2));
            queryY = linspace(bounds.Y(2), bounds.Y(1), outputGrid.OutputSize(1));
            [outputGrid.X, outputGrid.Y] = meshgrid(queryX, queryY);
            outputGrid.QueryWorldPoints = outputGrid.Origin + ...
                outputGrid.XAxis * outputGrid.X(:).' + ...
                outputGrid.YAxis * outputGrid.Y(:).';
            [queryCameraCoordinates, ~] = PlanarProjection.projectToCamera( ...
                outputGrid.QueryWorldPoints, frameCamera);
            outputGrid.QueryCameraCoordinates = queryCameraCoordinates;
        end

        function [outputImage, validMask, queryPlaneCoordinates] = renderLayer( ...
                frameCamera, layer, plane, mesh, samplingGrid, options)
            queryPlaneCoordinates = ProjectionReadbackRenderer.queryPlaneCoordinates( ...
                frameCamera, samplingGrid, plane);

            worldPoints = reshape(mesh.WorldPoints, 3, []);
            meshPlaneCoordinates = PlanarProjection.worldToPlane(worldPoints, plane);
            sampledImage = layer.Image(mesh.RowIndices, mesh.ColumnIndices, :);
            [outputImage, validMask] = ProjectionReadbackRenderer.interpolateImage( ...
                meshPlaneCoordinates, sampledImage, queryPlaneCoordinates, options);
        end

        function queryPlaneCoordinates = queryPlaneCoordinates( ...
                frameCamera, samplingGrid, plane)
            if isfield(samplingGrid, "QueryWorldPoints") && ...
                    ~isempty(samplingGrid.QueryWorldPoints)
                queryPlaneCoordinates = PlanarProjection.worldToPlane( ...
                    samplingGrid.QueryWorldPoints, plane);
                return
            end

            [queryPlaneCoordinates, ~] = PlanarProjection.projectCameraToPlane( ...
                samplingGrid.QueryCameraCoordinates, frameCamera, plane);
        end

        function [outputImage, validMask] = interpolateImage(meshPlaneCoordinates, sampledImage, ...
                queryPlaneCoordinates, options)
            bandCount = size(sampledImage, 3);
            outputSize = options.OutputSize;
            outputImage = zeros([outputSize bandCount]);
            validMask = true(outputSize);
            method = ProjectionReadbackRenderer.scatteredMethod(options.Interpolation);

            for bandIndex = 1:bandCount
                sampledBand = double(sampledImage(:, :, bandIndex));
                interpolant = scatteredInterpolant( ...
                    meshPlaneCoordinates(1, :).', meshPlaneCoordinates(2, :).', ...
                    sampledBand(:), method, "none");
                renderedBand = reshape(interpolant( ...
                    queryPlaneCoordinates(1, :).', queryPlaneCoordinates(2, :).'), ...
                    outputSize);
                bandValidMask = isfinite(renderedBand);
                validMask = validMask & bandValidMask;
                renderedBand(~bandValidMask) = options.InvalidFillValue;
                outputImage(:, :, bandIndex) = renderedBand;
            end

            if bandCount == 1
                outputImage = outputImage(:, :, 1);
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
            if options.UseGPU
                [compositeImage, validMask, layerImage, layerValidMask] = ...
                    ProjectionReadbackRenderer.moveBlendInputsToGpu( ...
                    compositeImage, validMask, layerImage, layerValidMask);
            end
            if isempty(compositeImage)
                compositeImage = ProjectionReadbackRenderer.zerosLike( ...
                    size(layerImage), layerImage);
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
            if options.UseGPU
                [compositeImage, validMask, layerImage, layerValidMask] = ...
                    ProjectionReadbackRenderer.moveBlendInputsToGpu( ...
                    compositeImage, validMask, layerImage, layerValidMask);
            end
            if isempty(compositeImage) || ismatrix(compositeImage)
                compositeImage = ProjectionReadbackRenderer.zerosLike( ...
                    [options.OutputSize 3], layerImage);
            end
            grayImage = ProjectionReadbackRenderer.grayscale(layerImage);
            grayImage = ProjectionReadbackRenderer.replaceInvalid(grayImage);
            contribution = ProjectionReadbackRenderer.zerosLike( ...
                [options.OutputSize 3], compositeImage);
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
                A = ProjectionReadbackRenderer.zerosLike(outputSize, B);
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

        function [compositeImage, validMask, layerImage, layerValidMask] = ...
                moveBlendInputsToGpu(compositeImage, validMask, layerImage, ...
                layerValidMask)
            if ~isempty(compositeImage)
                compositeImage = ProjectionReadbackRenderer.moveToGpu(compositeImage);
            end
            validMask = ProjectionReadbackRenderer.moveToGpu(validMask);
            layerImage = ProjectionReadbackRenderer.moveToGpu(layerImage);
            layerValidMask = ProjectionReadbackRenderer.moveToGpu(layerValidMask);
        end

        function value = moveToGpu(value)
            if ~isa(value, "gpuArray")
                value = gpuArray(value);
            end
        end

        function value = gatherIfNeeded(value)
            if isa(value, "gpuArray")
                value = gather(value);
            end
        end

        function imageData = zerosLike(outputSize, prototype)
            imageData = zeros(outputSize, "like", prototype);
        end

        function outputSize = validateOutputSize(outputSize)
            if ~isnumeric(outputSize) || ~isvector(outputSize) || numel(outputSize) ~= 2 || ...
                    any(~isfinite(outputSize)) || any(outputSize < 1) || ...
                    any(fix(outputSize) ~= outputSize)
                error("ProjectionReadbackRenderer:invalidOptions", ...
                    "OutputSize must be a finite positive 1x2 integer vector.");
            end
            outputSize = double(outputSize(:).');
        end

        function outputGrid = validateOutputGrid(outputGrid)
            if isempty(outputGrid)
                return
            end
            requiredFields = ["OutputSize", "Bounds", "Origin", "XAxis", "YAxis"];
            if ~isstruct(outputGrid) || ~isscalar(outputGrid) || ...
                    any(~isfield(outputGrid, requiredFields))
                error("ProjectionReadbackRenderer:invalidOptions", ...
                    "OutputGrid must be a scalar output-grid struct.");
            end
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

        function value = validateLogicalScalar(value, name)
            if ~(islogical(value) || isnumeric(value)) || ~isscalar(value)
                error("ProjectionReadbackRenderer:invalidOptions", ...
                    "%s must be a scalar logical value.", name);
            end
            value = logical(value);
        end

        function value = firstLayerField(layerReadbacks, fieldName)
            if isempty(layerReadbacks)
                value = [];
            else
                value = layerReadbacks(1).(fieldName);
            end
        end
    end
end
