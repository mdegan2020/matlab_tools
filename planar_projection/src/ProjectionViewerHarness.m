classdef ProjectionViewerHarness
    %ProjectionViewerHarness Build the first synthetic projection scene.
    %
    % The harness intentionally returns plain structs. Graphics handles and
    % mesh-generation details belong to later milestones.

    methods (Static)
        function scene = createDefaultScene(imagePath, options)
            %createDefaultScene Load one or more images and build a scene.
            if nargin < 2
                options = struct();
            end
            if nargin < 1 || ProjectionViewerHarness.isEmptyImagePathInput(imagePath)
                imagePath = ProjectionViewerHarness.defaultImagePath();
            end

            imagePaths = ProjectionViewerHarness.normalizeImagePaths(imagePath);
            imageDataList = cell(1, numel(imagePaths));
            for imageIndex = 1:numel(imagePaths)
                imageDataList{imageIndex} = imread(imagePaths(imageIndex));
            end

            scene = ProjectionViewerHarness.createSceneFromImages( ...
                imageDataList, imagePaths, options);
        end

        function scene = createSceneFromImage(imageData, imagePath, options)
            %createSceneFromImage Build a synthetic scene from in-memory image data.
            if nargin < 2
                imagePath = "";
            end
            if nargin < 3
                options = struct();
            end

            scene = ProjectionViewerHarness.createSceneFromImages( ...
                {imageData}, imagePath, options);
        end

        function scene = createSceneFromImages(imageDataList, imagePaths, options)
            %createSceneFromImages Build a scene with one layer per image.
            if nargin < 2
                imagePaths = strings(1, 0);
            end
            if nargin < 3
                options = struct();
            end

            options = ProjectionViewerHarness.mergeOptions(options);
            imageDataList = ProjectionViewerHarness.normalizeImageDataList(imageDataList);
            layerCount = numel(imageDataList);
            imagePaths = ProjectionViewerHarness.normalizeLayerImagePaths( ...
                imagePaths, layerCount);

            for layerIndex = 1:layerCount
                ProjectionViewerHarness.validateImageData(imageDataList{layerIndex});
            end

            referenceImageSize = [size(imageDataList{1}, 1), size(imageDataList{1}, 2)];
            referenceGeometry = ProjectionViewerHarness.createSyntheticSourceGeometry( ...
                referenceImageSize, options);
            basePlane = ProjectionViewerHarness.createBaseProjectionPlane( ...
                referenceGeometry, options);
            frameCamera = PlanarProjection.defineFrameCamera( ...
                referenceGeometry.ReferenceOrigin, referenceGeometry.OpticalAxis, ...
                options.FrameFocalLength, basePlane);

            for layerIndex = 1:layerCount
                layerOptions = ProjectionViewerHarness.createLayerOptions( ...
                    options, layerIndex, layerCount, imagePaths(layerIndex));
                imageData = imageDataList{layerIndex};
                imageSize = [size(imageData, 1), size(imageData, 2)];
                sourceGeometry = ProjectionViewerHarness.createSyntheticSourceGeometry( ...
                    imageSize, layerOptions);
                meshSampling = ProjectionViewerHarness.createMeshSampling( ...
                    imageSize, layerOptions.RowStride, layerOptions.ColumnStride);
                layer = ProjectionViewerHarness.createLayer( ...
                    imageData, imagePaths(layerIndex), sourceGeometry, basePlane, ...
                    meshSampling, layerOptions);
                if layerIndex == 1
                    layers = layer;
                else
                    layers(layerIndex) = layer;
                end
            end

            preview = struct();
            preview.MeshSampling = layers(1).MeshSampling;
            preview.LayerMeshSampling = [layers.MeshSampling];
            preview.DisplayTextureSize = size(layers(1).DisplayTexture);
            preview.LayerDisplayTextureSize = arrayfun( ...
                @(layer) size(layer.DisplayTexture), layers, UniformOutput=false);

            renderOptions = struct();
            renderOptions.Interpolation = "bilinear";
            renderOptions.UseGPU = false;
            renderOptions.InvalidIntersectionPolicy = "error";

            scene = struct();
            scene.frameCamera = frameCamera;
            scene.renderOrigin = basePlane.P0;
            scene.preview = preview;
            scene.renderOptions = renderOptions;
            scene.layers = layers;
        end

        function options = realDataOptions(overrides)
            %realDataOptions Return defaults for programmatic real-data scenes.
            if nargin < 1
                overrides = struct();
            end

            options = struct();
            options.RowStride = 16;
            options.ColumnStride = 8;
            options.FrameFocalLength = 1;
            options.CoordinateFrame = "real-world";
            options.InterpolationMethod = "linear";
            options.ReferenceOrigin = [];
            options.OpticalAxis = [];
            options.PlatformDirection = [];
            options.RowAxis = [];
            options.ImageXAxis = [];
            options.ImageYAxis = [];
            options.GSD = [];
            options.PlatformStepMeters = [];
            options.NominalRange = [];
            options.IFOVDegrees = [];
            options.IFOVRadians = [];
            options.Metadata = struct();
            options.DisplayTextureMaxPixels = 2e6;

            options = ProjectionViewerHarness.mergeRealDataOptions( ...
                options, overrides);
        end

        function scene = createRealDataScene(layerNames, imageDataList, ...
                geometryDefinitions, projectionPlane, options)
            %createRealDataScene Build a viewer scene from real imagery and geometry.
            if nargin < 5
                options = ProjectionViewerHarness.realDataOptions();
            else
                options = ProjectionViewerHarness.realDataOptions(options);
            end

            projectionPlane = ProjectionViewerHarness.validateProjectionPlane( ...
                projectionPlane);
            imageDataList = ProjectionViewerHarness.normalizeImageDataList( ...
                imageDataList);
            layerCount = numel(imageDataList);
            layerNames = ProjectionViewerHarness.normalizeLayerNames( ...
                layerNames, layerCount);
            geometryDefinitions = ...
                ProjectionViewerHarness.normalizeGeometryDefinitions( ...
                geometryDefinitions, layerCount);

            for layerIndex = 1:layerCount
                ProjectionViewerHarness.validateRealImageData( ...
                    imageDataList{layerIndex});
            end

            nominalSceneCenters = zeros(3, layerCount);
            for layerIndex = 1:layerCount
                imageData = imageDataList{layerIndex};
                imageSize = [size(imageData, 1), size(imageData, 2)];
                sourceGeometry = ProjectionViewerHarness.createRealSourceGeometry( ...
                    imageSize, geometryDefinitions{layerIndex}, options);
                nominalSceneCenters(:, layerIndex) = ...
                    sourceGeometry.NominalSceneCenter;
                sourceGeometry.LayerIndex = layerIndex;
                sourceGeometry.LayerCount = layerCount;
                sourceGeometry.Metadata.LayerIndex = layerIndex;
                sourceGeometry.Metadata.LayerCount = layerCount;
                sourceGeometry.Metadata.LayerName = layerNames(layerIndex);
                meshSampling = ProjectionViewerHarness.createMeshSampling( ...
                    imageSize, options.RowStride, options.ColumnStride);
                layerOptions = options;
                layerOptions.Name = layerNames(layerIndex);
                layer = ProjectionViewerHarness.createLayer( ...
                    imageData, "", sourceGeometry, projectionPlane, ...
                    meshSampling, layerOptions);
                if layerIndex == 1
                    layers = layer;
                else
                    layers(layerIndex) = layer;
                end
            end

            preview = ProjectionViewerHarness.createPreviewMetadata(layers);
            renderOptions = ProjectionViewerHarness.defaultRenderOptions();

            scene = struct();
            scene.frameCamera = ProjectionViewerHarness.createRealDataFrameCamera( ...
                projectionPlane, nominalSceneCenters, options.FrameFocalLength);
            scene.renderOrigin = projectionPlane.P0;
            scene.preview = preview;
            scene.renderOptions = renderOptions;
            scene.layers = layers;
        end

        function sourceGeometry = createRealSourceGeometry(imageSize, ...
                geometryDefinition, options)
            %createRealSourceGeometry Adapt sparse real geometry to SampleFcn.
            if nargin < 3
                options = ProjectionViewerHarness.realDataOptions();
            else
                options = ProjectionViewerHarness.realDataOptions(options);
            end

            imageSize = ProjectionViewerHarness.validateImageSize(imageSize);
            geometryDefinition = ProjectionViewerHarness.validateRealGeometryDefinition( ...
                geometryDefinition);
            sourceOptions = ProjectionViewerHarness.realSourceOptions( ...
                options, geometryDefinition);
            sourceGeometry = ProjectionSourceGeometry.fromGrid( ...
                imageSize, geometryDefinition.RowPostIndices, ...
                geometryDefinition.ColumnPostIndices, ...
                geometryDefinition.ViewVectorOrigins, ...
                geometryDefinition.ViewVectors, sourceOptions);
            sourceGeometry.NominalSceneCenter = geometryDefinition.NominalSceneCenter;
            sourceGeometry.ViewVectorOrigins = geometryDefinition.ViewVectorOrigins;
            sourceGeometry.Metadata.NominalSceneCenter = ...
                geometryDefinition.NominalSceneCenter;
            sourceGeometry.Metadata.GeometryDefinitionFormat = ...
                "ProjectionViewerRealDataGeometry";
        end

        function scene = applyProjectionPlane(scene, projectionPlane)
            %applyProjectionPlane Rebase every scene layer onto an explicit plane.
            projectionPlane = ProjectionViewerHarness.validateProjectionPlane(projectionPlane);
            ProjectionViewerHarness.validateProjectionScene(scene);

            for layerIndex = 1:numel(scene.layers)
                scene.layers(layerIndex).BaseProjectionPlane = projectionPlane;
                scene.layers(layerIndex).CurrentProjectionPlane = projectionPlane;
            end

            scene.renderOrigin = projectionPlane.P0;
            scene.frameCamera = PlanarProjection.defineFrameCamera( ...
                scene.frameCamera.G0, scene.frameCamera.V0, ...
                scene.frameCamera.F, projectionPlane);
        end

        function sourceGeometry = createSyntheticSourceGeometry(imageSize, options)
            %createSyntheticSourceGeometry Create compact linear-array geometry.
            if nargin < 2
                options = struct();
            end
            options = ProjectionViewerHarness.mergeOptions(options);
            imageSize = ProjectionViewerHarness.validateImageSize(imageSize);

            height = imageSize(1);
            width = imageSize(2);
            centerRow = (height + 1) / 2;
            centerColumn = (width + 1) / 2;

            platformDirection = ProjectionViewerHarness.unitVector( ...
                options.PlatformDirection, "PlatformDirection");
            referenceOrigin = ProjectionViewerHarness.validateVector( ...
                options.GeometryOffset, "GeometryOffset");
            opticalAxis = ProjectionViewerHarness.rotateVectorAboutAxis( ...
                [1; 0; 0], platformDirection, options.OpticalYawRadians);
            opticalAxis = ProjectionViewerHarness.unitVector(opticalAxis, "OpticalAxis");
            rowAxis = ProjectionViewerHarness.rotateVectorAboutAxis( ...
                [0; 1; 0], platformDirection, options.OpticalYawRadians);
            rowAxis = ProjectionViewerHarness.unitVector(rowAxis, "RowAxis");

            rowOffsets = ((1:height) - centerRow) * options.GSD;
            cameraRays = opticalAxis * options.NominalRange + rowAxis * rowOffsets;
            cameraRays = cameraRays ./ sqrt(sum(cameraRays.^2, 1));

            columnOffsets = ((1:width) - centerColumn) * options.PlatformStepMeters;
            origins = referenceOrigin + platformDirection * columnOffsets;

            geometryData = struct();
            geometryData.ImageSize = imageSize;
            geometryData.CoordinateFrame = string(options.CoordinateFrame);
            geometryData.GSD = options.GSD;
            geometryData.NominalRange = options.NominalRange;
            geometryData.PlatformStepMeters = options.PlatformStepMeters;
            geometryData.ImageCenter = [centerRow, centerColumn];
            geometryData.ReferenceOrigin = referenceOrigin;
            geometryData.OpticalAxis = opticalAxis;
            geometryData.RowAxis = rowAxis;
            geometryData.PlatformDirection = platformDirection;
            geometryData.ImageXAxis = platformDirection;
            geometryData.ImageYAxis = rowAxis;
            geometryData.Origins = origins;
            geometryData.CameraRays = cameraRays;
            geometryData.Attitudes = [];
            geometryData.WorldVectors = [];
            geometryData.GeometryOffset = referenceOrigin;
            geometryData.OpticalYawRadians = options.OpticalYawRadians;
            geometryData.LayerIndex = options.LayerIndex;
            geometryData.LayerCount = options.LayerCount;
            geometryData.Metadata = ProjectionViewerHarness.createSourceMetadata(imageSize, options);

            sourceGeometry = geometryData;
            sourceGeometry.SampleFcn = @(rowIndices, columnIndices) ...
                ProjectionViewerHarness.sampleSyntheticGeometry( ...
                geometryData, rowIndices, columnIndices);
        end

        function meshSampling = createMeshSampling(imageSize, rowStride, columnStride)
            %createMeshSampling Build default sampled row and column indices.
            imageSize = ProjectionViewerHarness.validateImageSize(imageSize);
            rowStride = ProjectionViewerHarness.validatePositiveInteger(rowStride, "RowStride");
            columnStride = ProjectionViewerHarness.validatePositiveInteger(columnStride, "ColumnStride");

            rowIndices = unique([1:rowStride:imageSize(1), imageSize(1)], "stable");
            columnIndices = unique([1:columnStride:imageSize(2), imageSize(2)], "stable");

            meshSampling = struct();
            meshSampling.RowStride = rowStride;
            meshSampling.ColumnStride = columnStride;
            meshSampling.RowIndices = rowIndices;
            meshSampling.ColumnIndices = columnIndices;
        end

        function textureData = prepareDisplayTexture(imageData)
            %prepareDisplayTexture Convert RGB or single-band imagery for display.
            ProjectionViewerHarness.validateImageData(imageData);

            if size(imageData, 3) == 3
                textureData = imageData;
                if isfloat(textureData)
                    textureData = min(max(textureData, 0), 1);
                end
                return
            end

            gray = ProjectionViewerHarness.scaleSingleBandForDisplay(imageData);
            textureData = repmat(gray, 1, 1, 3);
        end

        function imagePath = defaultImagePath()
            %defaultImagePath Return the local ignored prototype TIFF path.
            projectRoot = fileparts(fileparts(mfilename("fullpath")));
            imagePath = string(fullfile(projectRoot, "test_data", "10.tif"));
        end
    end

    methods (Static, Access = private)
        function options = mergeOptions(options)
            if isempty(options)
                options = struct();
            end
            if ~isstruct(options) || ~isscalar(options)
                error("ProjectionViewerHarness:invalidOptions", ...
                    "Options must be a scalar struct.");
            end

            defaults = struct();
            defaults.Name = "Test image";
            defaults.GSD = 0.5;
            defaults.NominalRange = 10000;
            defaults.RowStride = 16;
            defaults.ColumnStride = 8;
            defaults.PlatformDirection = [0; 0; 1];
            defaults.PlatformStepMeters = [];
            defaults.FrameFocalLength = 1;
            defaults.CoordinateFrame = "synthetic-world";
            defaults.ProjectionPlaneMode = "current";
            defaults.ProjectionPlane = [];
            defaults.GeometryOffset = [0; 0; 0];
            defaults.OpticalYawRadians = 0;
            defaults.LayerIndex = 1;
            defaults.LayerCount = 1;
            defaults.DisplayTextureMaxPixels = Inf;

            names = fieldnames(options);
            for k = 1:numel(names)
                defaults.(names{k}) = options.(names{k});
            end

            defaults.GSD = ProjectionViewerHarness.validatePositiveScalar(defaults.GSD, "GSD");
            defaults.NominalRange = ProjectionViewerHarness.validatePositiveScalar( ...
                defaults.NominalRange, "NominalRange");
            defaults.RowStride = ProjectionViewerHarness.validatePositiveInteger( ...
                defaults.RowStride, "RowStride");
            defaults.ColumnStride = ProjectionViewerHarness.validatePositiveInteger( ...
                defaults.ColumnStride, "ColumnStride");
            defaults.FrameFocalLength = ProjectionViewerHarness.validatePositiveScalar( ...
                defaults.FrameFocalLength, "FrameFocalLength");
            defaults.GeometryOffset = ProjectionViewerHarness.validateVector( ...
                defaults.GeometryOffset, "GeometryOffset");
            defaults.OpticalYawRadians = ProjectionViewerHarness.validateFiniteScalar( ...
                defaults.OpticalYawRadians, "OpticalYawRadians");
            defaults.LayerIndex = ProjectionViewerHarness.validatePositiveInteger( ...
                defaults.LayerIndex, "LayerIndex");
            defaults.LayerCount = ProjectionViewerHarness.validatePositiveInteger( ...
                defaults.LayerCount, "LayerCount");
            defaults.DisplayTextureMaxPixels = ...
                ProjectionViewerHarness.validatePositiveScalarOrInf( ...
                defaults.DisplayTextureMaxPixels, "DisplayTextureMaxPixels");

            if isempty(defaults.PlatformStepMeters)
                defaults.PlatformStepMeters = defaults.GSD;
            end
            defaults.PlatformStepMeters = ProjectionViewerHarness.validatePositiveScalar( ...
                defaults.PlatformStepMeters, "PlatformStepMeters");

            options = defaults;
        end

        function layerOptions = createLayerOptions(options, layerIndex, layerCount, imagePath)
            layerOptions = options;
            layerOptions.Name = ProjectionViewerHarness.layerName( ...
                options.Name, imagePath, layerIndex, layerCount);
            layerOptions.LayerIndex = layerIndex;
            layerOptions.LayerCount = layerCount;
            [geometryOffset, opticalYawRadians] = ...
                ProjectionViewerHarness.layerGeometryPerturbation( ...
                options, layerIndex, layerCount);
            layerOptions.GeometryOffset = geometryOffset;
            layerOptions.OpticalYawRadians = opticalYawRadians;
        end

        function tf = isEmptyImagePathInput(imagePath)
            if isempty(imagePath)
                tf = true;
                return
            end
            if iscell(imagePath)
                tf = isempty(imagePath);
                return
            end
            if ischar(imagePath) || isstring(imagePath)
                imagePath = string(imagePath);
                tf = isscalar(imagePath) && strlength(imagePath) == 0;
                return
            end
            tf = false;
        end

        function imagePaths = normalizeImagePaths(imagePath)
            if iscell(imagePath)
                imagePaths = string(imagePath);
            elseif ischar(imagePath) || isstring(imagePath)
                imagePaths = string(imagePath);
            else
                error("ProjectionViewerHarness:invalidImagePath", ...
                    "Image paths must be a string array, character vector, or cell array of character vectors.");
            end

            imagePaths = reshape(imagePaths, 1, []);
            if isempty(imagePaths) || any(strlength(imagePaths) == 0)
                error("ProjectionViewerHarness:invalidImagePath", ...
                    "Image paths must be nonempty.");
            end
        end

        function imageDataList = normalizeImageDataList(imageDataList)
            if iscell(imageDataList)
                imageDataList = reshape(imageDataList, 1, []);
            else
                imageDataList = {imageDataList};
            end

            if isempty(imageDataList)
                error("ProjectionViewerHarness:invalidImage", ...
                    "At least one image is required.");
            end
        end

        function imagePaths = normalizeLayerImagePaths(imagePaths, layerCount)
            if isempty(imagePaths)
                imagePaths = strings(1, layerCount);
                return
            end
            if iscell(imagePaths)
                imagePaths = string(imagePaths);
            elseif ischar(imagePaths) || isstring(imagePaths)
                imagePaths = string(imagePaths);
            else
                error("ProjectionViewerHarness:invalidImagePath", ...
                    "Image paths must be a string array, character vector, or cell array of character vectors.");
            end

            imagePaths = reshape(imagePaths, 1, []);
            if numel(imagePaths) ~= layerCount
                error("ProjectionViewerHarness:invalidImagePath", ...
                    "The number of image paths must match the number of images.");
            end
        end

        function layerNames = normalizeLayerNames(layerNames, layerCount)
            if iscell(layerNames)
                layerNames = string(layerNames);
            elseif ischar(layerNames) || isstring(layerNames)
                layerNames = string(layerNames);
            else
                error("ProjectionViewerHarness:invalidLayerName", ...
                    "Layer names must be a string array, character vector, or cell array of character vectors.");
            end

            layerNames = reshape(layerNames, 1, []);
            if numel(layerNames) ~= layerCount || any(strlength(layerNames) == 0)
                error("ProjectionViewerHarness:invalidLayerName", ...
                    "Layer names must contain one nonempty name per image.");
            end
        end

        function geometryDefinitions = normalizeGeometryDefinitions( ...
                geometryDefinitions, layerCount)
            if iscell(geometryDefinitions)
                geometryDefinitions = reshape(geometryDefinitions, 1, []);
            elseif isstruct(geometryDefinitions)
                geometryDefinitions = reshape(num2cell(geometryDefinitions), 1, []);
            else
                error("ProjectionViewerHarness:invalidGeometryDefinition", ...
                    "Geometry definitions must be a cell array or struct array.");
            end

            if numel(geometryDefinitions) ~= layerCount
                error("ProjectionViewerHarness:invalidGeometryDefinition", ...
                    "The number of geometry definitions must match the number of images.");
            end
        end

        function name = layerName(optionName, imagePath, layerIndex, layerCount)
            optionNames = string(optionName);
            if isempty(optionNames)
                error("ProjectionViewerHarness:invalidOptions", ...
                    "Name must contain at least one value.");
            end
            if numel(optionNames) > 1 && numel(optionNames) ~= layerCount
                error("ProjectionViewerHarness:invalidOptions", ...
                    "Name must be scalar or match the number of images.");
            end

            if numel(optionNames) > 1
                name = optionNames(layerIndex);
            elseif layerCount == 1
                name = optionNames(1);
            elseif strlength(imagePath) > 0
                [~, baseName, extension] = fileparts(char(imagePath));
                name = string(baseName) + string(extension);
            else
                name = sprintf("%s %d", optionNames(1), layerIndex);
            end

            if strlength(name) == 0
                name = sprintf("Layer %d", layerIndex);
            end
        end

        function [geometryOffset, opticalYawRadians] = layerGeometryPerturbation( ...
                options, layerIndex, layerCount)
            if layerCount == 1
                geometryOffset = [0; 0; 0];
                opticalYawRadians = 0;
                return
            end

            layerCoordinate = double(layerIndex) - (double(layerCount) + 1) / 2;
            platformDirection = ProjectionViewerHarness.unitVector( ...
                options.PlatformDirection, "PlatformDirection");
            rowOffset = layerCoordinate * 0.5 * options.GSD;
            platformOffset = layerCoordinate * 0.5 * options.PlatformStepMeters;
            geometryOffset = rowOffset * [0; 1; 0] + ...
                platformOffset * platformDirection;
            opticalYawRadians = layerCoordinate * 0.5 * options.GSD / ...
                options.NominalRange;
        end

        function layer = createLayer(imageData, imagePath, sourceGeometry, basePlane, meshSampling, options)
            imageMetadata = struct();
            imageMetadata.ImagePath = string(imagePath);
            imageMetadata.ImageSize = [size(imageData, 1), size(imageData, 2)];
            imageMetadata.BandCount = size(imageData, 3);
            imageMetadata.Class = string(class(imageData));

            layer = struct();
            layer.Name = string(options.Name);
            layer.Image = imageData;
            layer.DisplayTexture = ProjectionViewerHarness.prepareLayerDisplayTexture( ...
                imageData, options);
            layer.ImagePath = string(imagePath);
            layer.ImageMetadata = imageMetadata;
            layer.SourceGeometry = sourceGeometry;
            layer.BaseProjectionPlane = basePlane;
            layer.CurrentProjectionPlane = basePlane;
            layer.MeshSampling = meshSampling;
            layer.ProjectionOffsetMeters = [0; 0];
            layer.ViewVectorAngularOffsetsDegrees = [0; 0; 0];
            layer.Alpha = 1.0;
            layer.BlendMode = "alpha";
            layer.Visible = true;
        end

        function textureData = prepareLayerDisplayTexture(imageData, options)
            if isfield(options, "DisplayTextureMaxPixels")
                maxPixels = ProjectionViewerHarness.validatePositiveScalarOrInf( ...
                    options.DisplayTextureMaxPixels, "DisplayTextureMaxPixels");
                imageData = ProjectionViewerHarness.downsampleImageForDisplayTexture( ...
                    imageData, maxPixels);
            end

            textureData = ProjectionViewerHarness.prepareDisplayTexture(imageData);
        end

        function imageData = downsampleImageForDisplayTexture(imageData, maxPixels)
            if ~isfinite(maxPixels)
                return
            end

            imagePixels = double(size(imageData, 1)) * double(size(imageData, 2));
            if imagePixels <= maxPixels
                return
            end

            stride = ceil(sqrt(imagePixels / maxPixels));
            rowIndices = unique([1:stride:size(imageData, 1), ...
                size(imageData, 1)], "stable");
            columnIndices = unique([1:stride:size(imageData, 2), ...
                size(imageData, 2)], "stable");
            imageData = imageData(rowIndices, columnIndices, :);
        end

        function plane = createBaseProjectionPlane(sourceGeometry, options)
            if ~isempty(options.ProjectionPlane)
                plane = ProjectionViewerHarness.validateProjectionPlane(options.ProjectionPlane);
                return
            end

            mode = ProjectionViewerHarness.validateProjectionPlaneMode( ...
                options.ProjectionPlaneMode);
            if any(mode == ["current", "default", "basis"])
                plane = ProjectionViewerHarness.createCurrentProjectionPlane(sourceGeometry);
            elseif any(mode == ["fit", "fitplane"])
                plane = ProjectionViewerHarness.createFitProjectionPlane(sourceGeometry);
            elseif any(mode == ["stereo", "stereoplane"])
                plane = ProjectionViewerHarness.createStereoProjectionPlane(sourceGeometry);
            end
        end

        function plane = createCurrentProjectionPlane(sourceGeometry)
            planeOrigin = sourceGeometry.ReferenceOrigin + ...
                sourceGeometry.NominalRange * sourceGeometry.OpticalAxis;
            plane = PlanarProjection.definePlaneFromBasis( ...
                planeOrigin, sourceGeometry.RowAxis, sourceGeometry.PlatformDirection);
        end

        function plane = createFitProjectionPlane(sourceGeometry)
            currentPlane = ProjectionViewerHarness.createCurrentProjectionPlane(sourceGeometry);
            [P1, P2, P3, P4] = ProjectionViewerHarness.fitPlaneCornerPoints( ...
                currentPlane, sourceGeometry);
            plane = PlanarProjection.defineFitPlane( ...
                sourceGeometry.ReferenceOrigin, sourceGeometry.OpticalAxis, ...
                P1, P2, P3, P4);
        end

        function plane = createStereoProjectionPlane(sourceGeometry)
            if sourceGeometry.ImageSize(2) > 1
                G1 = sourceGeometry.Origins(:, 1);
                G2 = sourceGeometry.Origins(:, end);
            else
                halfStep = 0.5 * sourceGeometry.PlatformStepMeters;
                G1 = sourceGeometry.ReferenceOrigin - halfStep * sourceGeometry.PlatformDirection;
                G2 = sourceGeometry.ReferenceOrigin + halfStep * sourceGeometry.PlatformDirection;
            end

            plane = PlanarProjection.defineStereoPlane( ...
                G1, sourceGeometry.OpticalAxis, sourceGeometry.NominalRange, ...
                G2, sourceGeometry.OpticalAxis, sourceGeometry.NominalRange);
        end

        function [P1, P2, P3, P4] = fitPlaneCornerPoints(plane, sourceGeometry)
            rowHalfSpan = max(0.5 * (sourceGeometry.ImageSize(1) - 1) * ...
                sourceGeometry.GSD, 0.5 * sourceGeometry.GSD);
            columnHalfSpan = max(0.5 * (sourceGeometry.ImageSize(2) - 1) * ...
                sourceGeometry.PlatformStepMeters, ...
                0.5 * sourceGeometry.PlatformStepMeters);

            rowAxis = plane.basis(:, 1);
            columnAxis = plane.basis(:, 2);
            P1 = plane.P0 - rowHalfSpan * rowAxis - columnHalfSpan * columnAxis;
            P2 = plane.P0 + rowHalfSpan * rowAxis - columnHalfSpan * columnAxis;
            P3 = plane.P0 + rowHalfSpan * rowAxis + columnHalfSpan * columnAxis;
            P4 = plane.P0 - rowHalfSpan * rowAxis + columnHalfSpan * columnAxis;
        end

        function metadata = createSourceMetadata(imageSize, options)
            metadata = struct();
            metadata.Description = "Synthetic linear-array geometry";
            metadata.ImageHeightMeters = imageSize(1) * options.GSD;
            metadata.ImageWidthMeters = imageSize(2) * options.PlatformStepMeters;
            metadata.CPUReferencePath = true;
            metadata.LayerIndex = options.LayerIndex;
            metadata.LayerCount = options.LayerCount;
            metadata.GeometryOffset = options.GeometryOffset;
            metadata.OpticalYawRadians = options.OpticalYawRadians;
        end

        function preview = createPreviewMetadata(layers)
            preview = struct();
            preview.MeshSampling = layers(1).MeshSampling;
            preview.LayerMeshSampling = [layers.MeshSampling];
            preview.DisplayTextureSize = size(layers(1).DisplayTexture);
            preview.LayerDisplayTextureSize = arrayfun( ...
                @(layer) size(layer.DisplayTexture), layers, UniformOutput=false);
        end

        function renderOptions = defaultRenderOptions()
            renderOptions = struct();
            renderOptions.Interpolation = "bilinear";
            renderOptions.UseGPU = false;
            renderOptions.InvalidIntersectionPolicy = "error";
        end

        function frameCamera = createRealDataFrameCamera( ...
                projectionPlane, nominalSceneCenters, frameFocalLength)
            if ~isnumeric(nominalSceneCenters) || ...
                    size(nominalSceneCenters, 1) ~= 3 || ...
                    isempty(nominalSceneCenters) || ...
                    any(~isfinite(nominalSceneCenters), "all")
                error("ProjectionViewerHarness:invalidGeometryDefinition", ...
                    "Nominal scene centers must form a finite 3 x N numeric array.");
            end

            cameraOrigin = mean(double(nominalSceneCenters), 2);
            cameraAxis = ProjectionViewerHarness.unitVector( ...
                projectionPlane.P0 - cameraOrigin, "FrameCameraViewDirection");
            frameCamera = PlanarProjection.defineFrameCamera( ...
                cameraOrigin, cameraAxis, frameFocalLength, projectionPlane);
        end

        function options = mergeRealDataOptions(options, overrides)
            if isempty(overrides)
                overrides = struct();
            end
            if ~isstruct(overrides) || ~isscalar(overrides)
                error("ProjectionViewerHarness:invalidRealDataOptions", ...
                    "Real-data options must be a scalar struct.");
            end

            names = fieldnames(overrides);
            for k = 1:numel(names)
                options.(names{k}) = overrides.(names{k});
            end

            options.RowStride = ProjectionViewerHarness.validatePositiveInteger( ...
                options.RowStride, "RowStride");
            options.ColumnStride = ProjectionViewerHarness.validatePositiveInteger( ...
                options.ColumnStride, "ColumnStride");
            options.FrameFocalLength = ProjectionViewerHarness.validatePositiveScalar( ...
                options.FrameFocalLength, "FrameFocalLength");
            options.DisplayTextureMaxPixels = ...
                ProjectionViewerHarness.validatePositiveScalarOrInf( ...
                options.DisplayTextureMaxPixels, "DisplayTextureMaxPixels");
            options.CoordinateFrame = ProjectionViewerHarness.validateScalarString( ...
                options.CoordinateFrame, "CoordinateFrame");
            options.InterpolationMethod = lower( ...
                ProjectionViewerHarness.validateScalarString( ...
                options.InterpolationMethod, "InterpolationMethod"));
            if ~any(options.InterpolationMethod == ["linear", "nearest"])
                error("ProjectionViewerHarness:invalidRealDataOptions", ...
                    "InterpolationMethod must be linear or nearest.");
            end
            if ~isstruct(options.Metadata) || ~isscalar(options.Metadata)
                error("ProjectionViewerHarness:invalidRealDataOptions", ...
                    "Metadata must be a scalar struct.");
            end

            vectorOptionNames = ["ReferenceOrigin", "OpticalAxis", ...
                "PlatformDirection", "RowAxis", "ImageXAxis", "ImageYAxis"];
            for optionName = vectorOptionNames
                if ~isempty(options.(optionName))
                    options.(optionName) = ProjectionViewerHarness.validateVector( ...
                        options.(optionName), optionName);
                end
            end

            scalarOptionNames = ["GSD", "PlatformStepMeters", ...
                "NominalRange", "IFOVDegrees", "IFOVRadians"];
            for optionName = scalarOptionNames
                if ~isempty(options.(optionName))
                    options.(optionName) = ProjectionViewerHarness.validatePositiveScalar( ...
                        options.(optionName), optionName);
                end
            end
        end

        function geometryDefinition = validateRealGeometryDefinition( ...
                geometryDefinition)
            if ~isstruct(geometryDefinition) || ~isscalar(geometryDefinition)
                error("ProjectionViewerHarness:invalidGeometryDefinition", ...
                    "Each geometry definition must be a scalar struct.");
            end

            geometryDefinition.RowPostIndices = ...
                ProjectionViewerHarness.validatePostIndexVector( ...
                ProjectionViewerHarness.requiredGeometryField( ...
                geometryDefinition, ["RowPostIndices", "RowIndices"], ...
                "row post indices"), "RowPostIndices");
            geometryDefinition.ColumnPostIndices = ...
                ProjectionViewerHarness.validatePostIndexVector( ...
                ProjectionViewerHarness.requiredGeometryField( ...
                geometryDefinition, ["ColumnPostIndices", "ColumnIndices"], ...
                "column post indices"), "ColumnPostIndices");
            geometryDefinition.ViewVectorOrigins = ...
                ProjectionViewerHarness.validateOriginPosts( ...
                ProjectionViewerHarness.requiredGeometryField( ...
                geometryDefinition, ["ViewVectorOrigins", "Origins"], ...
                "view-vector origins"));
            geometryDefinition.ViewVectors = ...
                ProjectionViewerHarness.validateViewVectorPosts( ...
                ProjectionViewerHarness.requiredGeometryField( ...
                geometryDefinition, "ViewVectors", "view vectors"));
            geometryDefinition.NominalSceneCenter = ...
                ProjectionViewerHarness.validateThreeVector( ...
                ProjectionViewerHarness.requiredGeometryField( ...
                geometryDefinition, ["NominalSceneCenter", "SceneCenter"], ...
                "nominal scene center"), "NominalSceneCenter");
        end

        function sourceOptions = realSourceOptions(options, geometryDefinition)
            sourceOptions = struct();
            optionNames = ["CoordinateFrame", "InterpolationMethod", ...
                "ReferenceOrigin", "OpticalAxis", "PlatformDirection", ...
                "RowAxis", "ImageXAxis", "ImageYAxis", "GSD", ...
                "PlatformStepMeters", "NominalRange", "IFOVDegrees", ...
                "IFOVRadians"];
            for optionName = optionNames
                sourceOptions.(optionName) = options.(optionName);
                if isfield(geometryDefinition, optionName)
                    sourceOptions.(optionName) = geometryDefinition.(optionName);
                end
            end

            sourceOptions.Metadata = options.Metadata;
            if isfield(geometryDefinition, "Metadata")
                if ~isstruct(geometryDefinition.Metadata) || ...
                        ~isscalar(geometryDefinition.Metadata)
                    error("ProjectionViewerHarness:invalidGeometryDefinition", ...
                        "Geometry Metadata must be a scalar struct.");
                end
                metadataNames = fieldnames(geometryDefinition.Metadata);
                for k = 1:numel(metadataNames)
                    sourceOptions.Metadata.(metadataNames{k}) = ...
                        geometryDefinition.Metadata.(metadataNames{k});
                end
            end

            sourceOptions = ProjectionViewerHarness.mergeRealDataOptions( ...
                ProjectionViewerHarness.realDataOptions(), sourceOptions);
        end

        function value = requiredGeometryField(geometryDefinition, fieldNames, label)
            fieldNames = string(fieldNames);
            for k = 1:numel(fieldNames)
                fieldName = fieldNames(k);
                if isfield(geometryDefinition, fieldName)
                    value = geometryDefinition.(fieldName);
                    return
                end
            end

            error("ProjectionViewerHarness:invalidGeometryDefinition", ...
                "Each geometry definition must include %s.", label);
        end

        function [G, V] = sampleSyntheticGeometry(geometryData, rowIndices, columnIndices)
            rowIndices = ProjectionViewerHarness.validateIndices( ...
                rowIndices, geometryData.ImageSize(1), "rowIndices");
            columnIndices = ProjectionViewerHarness.validateIndices( ...
                columnIndices, geometryData.ImageSize(2), "columnIndices");

            G = geometryData.Origins(:, columnIndices);
            rowRays = geometryData.CameraRays(:, rowIndices);
            V = repmat(reshape(rowRays, 3, numel(rowIndices), 1), ...
                1, 1, numel(columnIndices));
        end

        function validateImageData(imageData)
            if ~(isnumeric(imageData) || islogical(imageData)) || isempty(imageData) || ...
                    ndims(imageData) > 3 || any(~isfinite(imageData), "all")
                error("ProjectionViewerHarness:invalidImage", ...
                    "Image data must be a finite numeric or logical 2-D or 3-D array.");
            end

            bandCount = size(imageData, 3);
            if bandCount ~= 1 && bandCount ~= 3
                error("ProjectionViewerHarness:unsupportedBandCount", ...
                    "Image data must be single-band or RGB.");
            end
        end

        function validateRealImageData(imageData)
            if ~isa(imageData, "uint8")
                error("ProjectionViewerHarness:invalidRealImage", ...
                    "Real-data images must be uint8 single-band or RGB arrays.");
            end
            ProjectionViewerHarness.validateImageData(imageData);
        end

        function imageSize = validateImageSize(imageSize)
            if ~isnumeric(imageSize) || ~isequal(size(imageSize), [1 2]) || ...
                    any(~isfinite(imageSize)) || any(imageSize < 1) || ...
                    any(fix(imageSize) ~= imageSize)
                error("ProjectionViewerHarness:invalidImageSize", ...
                    "ImageSize must be a finite positive 1x2 integer vector.");
            end
            imageSize = double(imageSize);
        end

        function indices = validateIndices(indices, upperBound, name)
            if ~isnumeric(indices) || isempty(indices) || ~isvector(indices) || ...
                    any(~isfinite(indices)) || any(indices < 1) || ...
                    any(indices > upperBound) || any(fix(indices) ~= indices)
                error("ProjectionViewerHarness:invalidIndex", ...
                    "%s must contain finite positive integer image indices.", name);
            end
            indices = double(indices(:).');
        end

        function value = validatePositiveScalar(value, name)
            if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value) || value <= 0
                error("ProjectionViewerHarness:invalidScalar", ...
                    "%s must be a positive finite scalar.", name);
            end
            value = double(value);
        end

        function value = validatePositiveScalarOrInf(value, name)
            if ~isnumeric(value) || ~isscalar(value) || isnan(value) || value <= 0
                error("ProjectionViewerHarness:invalidScalar", ...
                    "%s must be a positive scalar.", name);
            end
            value = double(value);
        end

        function value = validatePositiveInteger(value, name)
            if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value) || ...
                    value < 1 || fix(value) ~= value
                error("ProjectionViewerHarness:invalidInteger", ...
                    "%s must be a positive integer scalar.", name);
            end
            value = double(value);
        end

        function value = validateFiniteScalar(value, name)
            if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value)
                error("ProjectionViewerHarness:invalidScalar", ...
                    "%s must be a finite scalar.", name);
            end
            value = double(value);
        end

        function value = validateVector(value, name)
            if ~isnumeric(value) || ~isequal(size(value), [3 1]) || ...
                    any(~isfinite(value))
                error("ProjectionViewerHarness:invalidVector", ...
                    "%s must be a finite numeric 3x1 vector.", name);
            end
            value = double(value);
        end

        function value = validateThreeVector(value, name)
            if ~isnumeric(value) || numel(value) ~= 3 || ...
                    any(~isfinite(value), "all")
                error("ProjectionViewerHarness:invalidGeometryDefinition", ...
                    "%s must be a finite numeric 3-vector.", name);
            end
            value = double(value(:));
        end

        function value = validateScalarString(value, name)
            if ~(ischar(value) || isstring(value)) || ...
                    ~isscalar(string(value)) || strlength(string(value)) == 0
                error("ProjectionViewerHarness:invalidRealDataOptions", ...
                    "%s must be a nonempty scalar string.", name);
            end
            value = string(value);
        end

        function indices = validatePostIndexVector(indices, name)
            if ~isnumeric(indices) || isempty(indices) || ~isvector(indices) || ...
                    any(~isfinite(indices)) || any(indices < 1) || ...
                    any(fix(indices) ~= indices)
                error("ProjectionViewerHarness:invalidGeometryDefinition", ...
                    "%s must contain finite positive integer image indices.", name);
            end

            indices = double(indices(:).');
            if any(diff(indices) <= 0)
                error("ProjectionViewerHarness:invalidGeometryDefinition", ...
                    "%s must be strictly increasing.", name);
            end
        end

        function origins = validateOriginPosts(origins)
            if ~isnumeric(origins) || size(origins, 1) ~= 3 || ...
                    isempty(origins) || any(~isfinite(origins), "all")
                error("ProjectionViewerHarness:invalidGeometryDefinition", ...
                    "View-vector origins must be a finite 3 x N numeric array.");
            end
            origins = double(origins);
        end

        function viewVectors = validateViewVectorPosts(viewVectors)
            if ~isnumeric(viewVectors) || size(viewVectors, 1) ~= 3 || ...
                    isempty(viewVectors) || ndims(viewVectors) > 3 || ...
                    any(~isfinite(viewVectors), "all")
                error("ProjectionViewerHarness:invalidGeometryDefinition", ...
                    "View vectors must be a finite 3 x M x N numeric array.");
            end
            viewVectors = double(viewVectors);
        end

        function mode = validateProjectionPlaneMode(mode)
            if ~(ischar(mode) || isstring(mode)) || ~isscalar(string(mode)) || ...
                    strlength(string(mode)) == 0
                error("ProjectionViewerHarness:invalidProjectionPlaneMode", ...
                    "ProjectionPlaneMode must be current, fit, or stereo.");
            end

            mode = lower(string(mode));
            validModes = ["current", "default", "basis", "fit", ...
                "fitplane", "stereo", "stereoplane"];
            if ~any(mode == validModes)
                error("ProjectionViewerHarness:invalidProjectionPlaneMode", ...
                    "ProjectionPlaneMode must be current, fit, or stereo.");
            end
        end

        function plane = validateProjectionPlane(plane)
            if ~isstruct(plane) || ~isscalar(plane)
                error("ProjectionViewerHarness:invalidProjectionPlane", ...
                    "ProjectionPlane must be a scalar plane struct.");
            end
            PlanarProjection.validatePlane(plane);
        end

        function validateProjectionScene(scene)
            if ~isstruct(scene) || ~isscalar(scene) || ...
                    ~isfield(scene, "layers") || ~isfield(scene, "frameCamera") || ...
                    ~isfield(scene, "renderOrigin") || isempty(scene.layers)
                error("ProjectionViewerHarness:invalidScene", ...
                    "Scene must contain layers, frameCamera, and renderOrigin.");
            end

            if ~isstruct(scene.layers)
                error("ProjectionViewerHarness:invalidScene", ...
                    "Scene layers must be a struct array.");
            end
            PlanarProjection.validateCamera(scene.frameCamera);
        end

        function V = unitVector(V, name)
            if ~isnumeric(V) || ~isequal(size(V), [3 1]) || any(~isfinite(V))
                error("ProjectionViewerHarness:invalidVector", ...
                    "%s must be a finite numeric 3x1 vector.", name);
            end

            magnitude = norm(V);
            if magnitude <= 1e-12
                error("ProjectionViewerHarness:invalidVector", ...
                    "%s must have nonzero length.", name);
            end
            V = double(V) / magnitude;
        end

        function rotatedVector = rotateVectorAboutAxis(vector, axis, angle)
            vector = vector(:);
            axis = axis(:) / norm(axis);
            K = [0 -axis(3) axis(2); axis(3) 0 -axis(1); -axis(2) axis(1) 0];
            R = cos(angle) * eye(3) + (1 - cos(angle)) * (axis * axis.') + sin(angle) * K;
            rotatedVector = R * vector;
        end

        function gray = scaleSingleBandForDisplay(imageData)
            if islogical(imageData)
                gray = single(imageData);
                return
            end

            if isinteger(imageData)
                minValue = single(intmin(class(imageData)));
                maxValue = single(intmax(class(imageData)));
                gray = (single(imageData) - minValue) / (maxValue - minValue);
                return
            end

            gray = single(imageData);
            minValue = min(gray, [], "all");
            maxValue = max(gray, [], "all");
            if minValue >= 0 && maxValue <= 1
                return
            end
            if maxValue > minValue
                gray = (gray - minValue) / (maxValue - minValue);
            else
                gray = zeros(size(gray), "single");
            end
        end
    end
end
