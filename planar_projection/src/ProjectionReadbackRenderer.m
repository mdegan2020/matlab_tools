classdef ProjectionReadbackRenderer
    %ProjectionReadbackRenderer Headless frame-camera readback prototype.

    methods (Static)
        function readback = renderScene(scene, options)
            %renderScene Render visible layers without MATLAB graphics.
            if nargin < 2
                options = struct();
            end
            try
                plan = ProjectionBackendRenderPlan.compile(scene, options);
            catch ME
                if ME.identifier == "ProjectionBackendRenderPlan:invalidOptions"
                    error("ProjectionReadbackRenderer:invalidOptions", ...
                        "%s", ME.message);
                elseif ME.identifier == "ProjectionBackendRenderPlan:invalidScene"
                    error("ProjectionReadbackRenderer:invalidScene", ...
                        "%s", ME.message);
                elseif ME.identifier == "ProjectionBackendRenderPlan:noVisibleLayer"
                    error("ProjectionReadbackRenderer:noVisibleLayer", ...
                        "%s", ME.message);
                end
                rethrow(ME);
            end
            readback = ProjectionReadbackRenderer.renderPlan(plan);
        end

        function readback = renderPlan(plan, outputGrid)
            %renderPlan Render a compiled backend plan over an optional grid.
            plan = ProjectionBackendRenderPlan.validate(plan);
            if nargin < 2
                outputGrid = plan.OutputGrid;
            end
            outputGrid = ProjectionReadbackRenderer.validateOutputGrid(outputGrid);
            options = struct();
            options.OutputSize = plan.OutputSize;
            options.OutputGrid = outputGrid;
            options.Interpolation = plan.Interpolation;
            options.InvalidFillValue = plan.InvalidFillValue;
            options.IncludeLayerReadbacks = plan.IncludeLayerReadbacks;
            options.UseGPU = plan.UseGPU;
            options.GpuInfo = plan.GpuInfo;
            options.NumericalMode = plan.NumericalMode;
            if ~isempty(outputGrid)
                options.OutputSize = ProjectionReadbackRenderer.validateOutputSize( ...
                    outputGrid.OutputSize);
            end

            firstMesh = plan.Layers(1).Mesh;
            samplingGrid = ProjectionReadbackRenderer.createSamplingGrid( ...
                plan.FrameCamera, firstMesh, options);

            compositeImage = [];
            validMask = false(options.OutputSize);
            anaglyphOrdinal = 0;
            layerReadbacks = struct([]);

            for outputIndex = 1:numel(plan.Layers)
                layerPlan = plan.Layers(outputIndex);
                [layerImage, layerValidMask, queryPlaneCoordinates] = ...
                    ProjectionReadbackRenderer.renderLayer( ...
                    plan.FrameCamera, layerPlan, samplingGrid, options);

                [compositeImage, validMask, anaglyphOrdinal] = ...
                    ProjectionReadbackRenderer.blendLayer( ...
                    compositeImage, validMask, layerImage, layerValidMask, ...
                    layerPlan, options, anaglyphOrdinal);

                if options.IncludeLayerReadbacks
                    layerReadbacks(outputIndex).Image = layerImage;
                    layerReadbacks(outputIndex).ValidMask = layerValidMask;
                    layerReadbacks(outputIndex).LayerIndex = layerPlan.LayerIndex;
                    layerReadbacks(outputIndex).QueryPlaneCoordinates = queryPlaneCoordinates;
                    layerReadbacks(outputIndex).Mesh = layerPlan.Mesh;
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
            readback.LayerIndex = plan.LayerIndices(1);
            readback.LayerIndices = plan.LayerIndices;
            readback.CameraGrid = samplingGrid;
            readback.QueryPlaneCoordinates = ...
                ProjectionReadbackRenderer.firstLayerField(layerReadbacks, ...
                "QueryPlaneCoordinates");
            readback.Mesh = ProjectionReadbackRenderer.firstLayerField( ...
                layerReadbacks, "Mesh");
            readback.LayerReadbacks = layerReadbacks;
            readback.UseGPU = options.UseGPU;
            readback.GpuInfo = options.GpuInfo;
            readback.OutputGrid = outputGrid;
            readback.RenderPlan = ProjectionBackendRenderPlan.summary(plan);
        end
    end

    methods (Static, Access = private)
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
                frameCamera, layerPlan, samplingGrid, options)
            queryPlaneCoordinates = ProjectionReadbackRenderer.queryPlaneCoordinates( ...
                frameCamera, samplingGrid, layerPlan.Plane);
            if options.NumericalMode == "fullSourceInverseWarp"
                mapping = ProjectionFullSourceInverseWarp.mapCoordinates( ...
                    layerPlan.InverseWarp, queryPlaneCoordinates, ...
                    options.OutputSize);
                [outputImage, validMask] = ...
                    ProjectionFullSourceInverseWarp.sampleImage( ...
                    layerPlan.SourceImage, mapping, options.Interpolation, ...
                    options.InvalidFillValue);
            else
                [outputImage, validMask] = ProjectionReadbackRenderer.interpolateImage( ...
                    layerPlan.InterpolantTemplate, layerPlan.SampledImage, ...
                    queryPlaneCoordinates, options);
            end
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

        function [outputImage, validMask] = interpolateImage( ...
                interpolantTemplate, sampledImage, queryPlaneCoordinates, options)
            bandCount = size(sampledImage, 3);
            outputSize = options.OutputSize;
            outputImage = zeros([outputSize bandCount]);
            validMask = true(outputSize);
            interpolant = interpolantTemplate;

            for bandIndex = 1:bandCount
                sampledBand = double(sampledImage(:, :, bandIndex));
                interpolant.Values = sampledBand(:);
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

        function value = firstLayerField(layerReadbacks, fieldName)
            if isempty(layerReadbacks)
                value = [];
            else
                value = layerReadbacks(1).(fieldName);
            end
        end
    end
end
