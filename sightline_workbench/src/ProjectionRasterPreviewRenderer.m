classdef ProjectionRasterPreviewRenderer
    %ProjectionRasterPreviewRenderer CPU prototype for one-raster preview.
    %
    % This runtime-only path renders normalized display data. It never changes
    % scene imagery and is not a backend renderer.

    properties (Constant)
        Format = "ProjectionRasterPreviewPlan"
        Version = 1
    end

    methods (Static)
        function result = render(scene, cameraState, options)
            %render Compile and composite a raster preview on the CPU.
            if nargin < 3
                options = struct();
            end
            plan = ProjectionRasterPreviewRenderer.compile( ...
                scene, cameraState, options);
            result = ProjectionRasterPreviewRenderer.composite( ...
                plan, scene.layers);
            result.Plan = plan;
        end

        function plan = compile(scene, cameraState, options)
            %compile Build viewport-sized per-layer rasters for fast blending.
            if nargin < 3
                options = struct();
            end
            ProjectionRasterPreviewRenderer.validateScene(scene);
            options = ProjectionRasterPreviewRenderer.mergeOptions(options);
            visibleLayerIndices = find([scene.layers.Visible]);
            if isempty(visibleLayerIndices)
                referenceLayerIndex = 1;
            else
                referenceLayerIndex = visibleLayerIndices(1);
            end
            compiledLayerIndices = 1:numel(scene.layers);

            worldCameraState = ProjectionRasterPreviewRenderer.worldCameraState( ...
                cameraState, scene.renderOrigin);
            referenceLayer = scene.layers(referenceLayerIndex);
            viewportGrid = ProjectionViewportGrid.build( ...
                worldCameraState, options.OutputSize, ...
                referenceLayer.CurrentProjectionPlane);

            layerPlans = struct([]);
            compileTimer = tic;
            for outputIndex = 1:numel(compiledLayerIndices)
                layerIndex = compiledLayerIndices(outputIndex);
                layer = scene.layers(layerIndex);
                layerTimer = tic;
                mesh = ProjectionMeshBuilder.buildLayerMesh( ...
                    layer, layer.CurrentProjectionPlane, scene.renderOrigin);
                queryWorldPoints = ProjectionViewportGrid.worldPointsForPlane( ...
                    viewportGrid, layer.CurrentProjectionPlane);
                [rowPositions, columnPositions, inverseValidMask] = ...
                    ProjectionRasterPreviewRenderer.inverseMap( ...
                    mesh, queryWorldPoints, layer.CurrentProjectionPlane, ...
                    options.OutputSize, layer.SourceGeometry.ImageSize);
                [sourceImage, rowPositions, columnPositions] = ...
                    ProjectionRasterPreviewRenderer.sourceImageAndCoordinates( ...
                    layer, options.SourceMode, rowPositions, columnPositions);
                [layerImage, sampleValidMask] = ...
                    ProjectionRasterPreviewRenderer.sampleImage( ...
                    sourceImage, rowPositions, columnPositions, ...
                    options.Interpolation, options.InvalidFillValue);
                validMask = inverseValidMask & sampleValidMask;
                layerImage(repmat(~validMask, 1, 1, 3)) = ...
                    options.InvalidFillValue;

                layerPlan = struct();
                layerPlan.LayerIndex = layerIndex;
                layerPlan.Image = layerImage;
                layerPlan.ValidMask = validMask;
                layerPlan.SourceMode = options.SourceMode;
                layerPlan.SourceTextureSize = size(sourceImage);
                layerPlan.MeshVertexCount = numel(mesh.X);
                layerPlan.CompileSeconds = toc(layerTimer);
                layerPlan.RasterBytes = ...
                    ProjectionRasterPreviewRenderer.arrayBytes(layerImage) + ...
                    ProjectionRasterPreviewRenderer.arrayBytes(validMask);
                if isempty(layerPlans)
                    layerPlans = layerPlan;
                else
                    layerPlans(outputIndex) = layerPlan;
                end
            end

            plan = struct();
            plan.Format = ProjectionRasterPreviewRenderer.Format;
            plan.Version = ProjectionRasterPreviewRenderer.Version;
            plan.OutputSize = options.OutputSize;
            plan.Interpolation = options.Interpolation;
            plan.SourceMode = options.SourceMode;
            plan.InvalidFillValue = options.InvalidFillValue;
            plan.LayerIndices = compiledLayerIndices;
            plan.ReferenceLayerIndex = referenceLayerIndex;
            plan.ViewportGrid = viewportGrid;
            plan.Layers = layerPlans;
            plan.CompileSeconds = toc(compileTimer);
            plan.RasterBytes = sum([layerPlans.RasterBytes]);
            plan.CpuComplete = true;
        end

        function result = composite(plan, layers)
            %composite Numerically blend a compiled viewport plan.
            ProjectionRasterPreviewRenderer.validatePlan(plan);
            if ~isstruct(layers) || isempty(layers)
                error("ProjectionRasterPreviewRenderer:invalidLayers", ...
                    "Layers must be a nonempty layer struct array.");
            end

            compositeTimer = tic;
            outputImage = zeros([plan.OutputSize 3], "single");
            validMask = false(plan.OutputSize);
            anaglyphOrdinal = 0;
            compositedLayerIndices = zeros(1, 0);
            for planIndex = 1:numel(plan.Layers)
                layerPlan = plan.Layers(planIndex);
                layerIndex = layerPlan.LayerIndex;
                if layerIndex > numel(layers)
                    error("ProjectionRasterPreviewRenderer:invalidLayers", ...
                        "Layer array does not contain compiled layer %d.", layerIndex);
                end
                layer = layers(layerIndex);
                if ~logical(layer.Visible) || double(layer.Alpha) <= 0
                    continue
                end
                compositedLayerIndices(end + 1) = layerIndex; %#ok<AGROW>
                blendMode = lower(string(layer.BlendMode));
                alpha = single(layer.Alpha);
                switch blendMode
                    case "alpha"
                        alphaMask = alpha * single(layerPlan.ValidMask);
                        alphaMask = repmat(alphaMask, 1, 1, 3);
                        outputImage = outputImage .* (1 - alphaMask) + ...
                            layerPlan.Image .* alphaMask;
                    case "redblueanaglyph"
                        anaglyphOrdinal = anaglyphOrdinal + 1;
                        grayImage = mean(layerPlan.Image, 3);
                        contribution = zeros(size(outputImage), "single");
                        channelIndex = 1 + 2 * double( ...
                            mod(anaglyphOrdinal, 2) == 0);
                        contribution(:, :, channelIndex) = alpha * grayImage;
                        contribution(repmat(~layerPlan.ValidMask, 1, 1, 3)) = 0;
                        outputImage = max(outputImage, contribution);
                    otherwise
                        error("ProjectionRasterPreviewRenderer:invalidBlendMode", ...
                            "Unsupported layer blend mode ""%s"".", layer.BlendMode);
                end
                validMask = validMask | layerPlan.ValidMask;
            end

            result = struct();
            result.Format = "ProjectionRasterPreviewResult";
            result.Version = 1;
            result.Image = outputImage;
            result.ValidMask = validMask;
            result.OutputSize = plan.OutputSize;
            result.LayerIndices = compositedLayerIndices;
            result.SourceMode = plan.SourceMode;
            result.Interpolation = plan.Interpolation;
            result.CompositeSeconds = toc(compositeTimer);
            result.ImageBytes = ...
                ProjectionRasterPreviewRenderer.arrayBytes(outputImage);
            result.CpuComplete = true;
        end
    end

    methods (Static, Access = private)
        function validateScene(scene)
            requiredFields = ["layers", "renderOrigin"];
            if ~isstruct(scene) || ~isscalar(scene) || ...
                    any(~isfield(scene, requiredFields)) || ...
                    isempty(scene.layers) || ~isstruct(scene.layers)
                error("ProjectionRasterPreviewRenderer:invalidScene", ...
                    "Scene must contain renderOrigin and a nonempty layer array.");
            end
            if ~isnumeric(scene.renderOrigin) || ...
                    ~isequal(size(scene.renderOrigin), [3 1]) || ...
                    any(~isfinite(scene.renderOrigin))
                error("ProjectionRasterPreviewRenderer:invalidScene", ...
                    "Scene renderOrigin must be a finite numeric 3x1 vector.");
            end
        end

        function options = mergeOptions(options)
            if isempty(options)
                options = struct();
            end
            if ~isstruct(options) || ~isscalar(options)
                error("ProjectionRasterPreviewRenderer:invalidOptions", ...
                    "Options must be a scalar struct.");
            end
            defaults = struct(OutputSize=[360 640], ...
                Interpolation="bilinear", SourceMode="displayTexture", ...
                InvalidFillValue=single(0));
            names = fieldnames(options);
            for k = 1:numel(names)
                if ~isfield(defaults, names{k})
                    error("ProjectionRasterPreviewRenderer:invalidOptions", ...
                        "Unknown raster preview option %s.", names{k});
                end
                defaults.(names{k}) = options.(names{k});
            end
            defaults.OutputSize = ...
                ProjectionRasterPreviewRenderer.validateOutputSize( ...
                defaults.OutputSize);
            defaults.Interpolation = lower(string(defaults.Interpolation));
            if ~isscalar(defaults.Interpolation) || ...
                    ~ismember(defaults.Interpolation, ["bilinear", "nearest"])
                error("ProjectionRasterPreviewRenderer:invalidOptions", ...
                    "Interpolation must be ""bilinear"" or ""nearest"".");
            end
            defaults.SourceMode = lower(string(defaults.SourceMode));
            if ~isscalar(defaults.SourceMode) || ...
                    ~ismember(defaults.SourceMode, ...
                    ["displaytexture", "fullsourcedisplay"])
                error("ProjectionRasterPreviewRenderer:invalidOptions", ...
                    "SourceMode must be ""displayTexture"" or ""fullSourceDisplay"".");
            end
            if ~isnumeric(defaults.InvalidFillValue) || ...
                    ~isscalar(defaults.InvalidFillValue) || ...
                    ~isfinite(defaults.InvalidFillValue)
                error("ProjectionRasterPreviewRenderer:invalidOptions", ...
                    "InvalidFillValue must be a finite numeric scalar.");
            end
            defaults.InvalidFillValue = single(defaults.InvalidFillValue);
            options = defaults;
        end

        function outputSize = validateOutputSize(outputSize)
            if ~isnumeric(outputSize) || ~isvector(outputSize) || ...
                    numel(outputSize) ~= 2 || any(~isfinite(outputSize)) || ...
                    any(outputSize < 1) || any(fix(outputSize) ~= outputSize)
                error("ProjectionRasterPreviewRenderer:invalidOptions", ...
                    "OutputSize must be a positive integer 2-vector.");
            end
            outputSize = double(outputSize(:).');
        end

        function cameraState = worldCameraState(cameraState, renderOrigin)
            if ~isstruct(cameraState) || ~isscalar(cameraState) || ...
                    ~isfield(cameraState, "Position") || ...
                    ~isfield(cameraState, "Target")
                error("ProjectionRasterPreviewRenderer:invalidCamera", ...
                    "Camera state must contain Position and Target.");
            end
            cameraState.Position = double(cameraState.Position(:)) + renderOrigin;
            cameraState.Target = double(cameraState.Target(:)) + renderOrigin;
        end

        function [rowPositions, columnPositions, validMask] = inverseMap( ...
                mesh, queryWorldPoints, plane, outputSize, imageSize)
            meshPlaneCoordinates = PlanarProjection.worldToPlane( ...
                reshape(mesh.WorldPoints, 3, []), plane);
            queryPlaneCoordinates = PlanarProjection.worldToPlane( ...
                queryWorldPoints, plane);
            rowValues = repmat(mesh.RowIndices(:), 1, numel(mesh.ColumnIndices));
            columnValues = repmat(mesh.ColumnIndices(:).', ...
                numel(mesh.RowIndices), 1);
            rowInterpolant = scatteredInterpolant( ...
                meshPlaneCoordinates(1, :).', meshPlaneCoordinates(2, :).', ...
                rowValues(:), "linear", "none");
            columnInterpolant = scatteredInterpolant( ...
                meshPlaneCoordinates(1, :).', meshPlaneCoordinates(2, :).', ...
                columnValues(:), "linear", "none");
            rowPositions = reshape(rowInterpolant( ...
                queryPlaneCoordinates(1, :).', ...
                queryPlaneCoordinates(2, :).'), outputSize);
            columnPositions = reshape(columnInterpolant( ...
                queryPlaneCoordinates(1, :).', ...
                queryPlaneCoordinates(2, :).'), outputSize);
            imageSize = double(imageSize(:).');
            validMask = isfinite(rowPositions) & isfinite(columnPositions) & ...
                rowPositions >= 1 & rowPositions <= imageSize(1) & ...
                columnPositions >= 1 & columnPositions <= imageSize(2);
        end

        function [imageData, rowPositions, columnPositions] = ...
                sourceImageAndCoordinates(layer, sourceMode, ...
                rowPositions, columnPositions)
            sourceSize = double(layer.SourceGeometry.ImageSize(:).');
            switch sourceMode
                case "displaytexture"
                    imageData = layer.DisplayTexture;
                    textureSize = [size(imageData, 1), size(imageData, 2)];
                    rowPositions = ProjectionRasterPreviewRenderer.scaleCoordinates( ...
                        rowPositions, sourceSize(1), textureSize(1));
                    columnPositions = ProjectionRasterPreviewRenderer.scaleCoordinates( ...
                        columnPositions, sourceSize(2), textureSize(2));
                case "fullsourcedisplay"
                    imageData = ProjectionViewerHarness.prepareDisplayTexture( ...
                        layer.Image);
            end
            imageData = ProjectionRasterPreviewRenderer.normalizedRgb(imageData);
        end

        function scaled = scaleCoordinates(values, sourceLength, targetLength)
            if sourceLength <= 1 || targetLength <= 1
                scaled = ones(size(values));
                return
            end
            scaled = 1 + (values - 1) * (targetLength - 1) / ...
                (sourceLength - 1);
        end

        function imageData = normalizedRgb(imageData)
            if islogical(imageData)
                imageData = single(imageData);
            elseif isinteger(imageData)
                imageData = im2single(imageData);
            else
                imageData = single(min(max(imageData, 0), 1));
            end
            if ismatrix(imageData)
                imageData = repmat(imageData, 1, 1, 3);
            elseif size(imageData, 3) ~= 3
                imageData = repmat(mean(imageData, 3), 1, 1, 3);
            end
        end

        function [sampledImage, validMask] = sampleImage( ...
                imageData, rowPositions, columnPositions, ...
                interpolation, invalidFillValue)
            if interpolation == "bilinear"
                method = "linear";
            else
                method = "nearest";
            end
            sampledImage = zeros([size(rowPositions) 3], "single");
            validMask = true(size(rowPositions));
            for bandIndex = 1:3
                band = interp2(imageData(:, :, bandIndex), ...
                    columnPositions, rowPositions, method, NaN);
                bandValidMask = isfinite(band);
                validMask = validMask & bandValidMask;
                band(~bandValidMask) = invalidFillValue;
                sampledImage(:, :, bandIndex) = band;
            end
        end

        function validatePlan(plan)
            requiredFields = ["Format", "Version", "OutputSize", ...
                "SourceMode", "Interpolation", "Layers"];
            if ~isstruct(plan) || ~isscalar(plan) || ...
                    any(~isfield(plan, requiredFields)) || ...
                    string(plan.Format) ~= ProjectionRasterPreviewRenderer.Format || ...
                    double(plan.Version) ~= ProjectionRasterPreviewRenderer.Version
                error("ProjectionRasterPreviewRenderer:invalidPlan", ...
                    "Plan must be produced by ProjectionRasterPreviewRenderer.compile.");
            end
        end

        function bytes = arrayBytes(value)
            if islogical(value)
                bytes = double(numel(value));
                return
            end
            details = whos("value");
            bytes = double(details.bytes);
        end
    end
end
