classdef ProjectionViewerHarness
    %ProjectionViewerHarness Build the first synthetic projection scene.
    %
    % The harness intentionally returns plain structs. Graphics handles and
    % mesh-generation details belong to later milestones.

    methods (Static)
        function scene = createDefaultScene(imagePath, options)
            %createDefaultScene Load an image and build a single-layer scene.
            if nargin < 1 || strlength(string(imagePath)) == 0
                imagePath = ProjectionViewerHarness.defaultImagePath();
            end
            if nargin < 2
                options = struct();
            end

            imagePath = string(imagePath);
            imageData = imread(imagePath);
            scene = ProjectionViewerHarness.createSceneFromImage(imageData, imagePath, options);
        end

        function scene = createSceneFromImage(imageData, imagePath, options)
            %createSceneFromImage Build a synthetic scene from in-memory image data.
            if nargin < 2
                imagePath = "";
            end
            if nargin < 3
                options = struct();
            end

            options = ProjectionViewerHarness.mergeOptions(options);
            ProjectionViewerHarness.validateImageData(imageData);

            imageSize = [size(imageData, 1), size(imageData, 2)];
            sourceGeometry = ProjectionViewerHarness.createSyntheticSourceGeometry(imageSize, options);
            meshSampling = ProjectionViewerHarness.createMeshSampling( ...
                imageSize, options.RowStride, options.ColumnStride);
            basePlane = ProjectionViewerHarness.createBaseProjectionPlane(sourceGeometry);
            frameCamera = PlanarProjection.defineFrameCamera( ...
                sourceGeometry.ReferenceOrigin, sourceGeometry.OpticalAxis, ...
                options.FrameFocalLength, basePlane);

            layer = ProjectionViewerHarness.createLayer( ...
                imageData, imagePath, sourceGeometry, basePlane, meshSampling, options);

            preview = struct();
            preview.MeshSampling = meshSampling;
            preview.DisplayTextureSize = size(layer.DisplayTexture);

            renderOptions = struct();
            renderOptions.Interpolation = "bilinear";
            renderOptions.UseGPU = false;
            renderOptions.InvalidIntersectionPolicy = "error";

            scene = struct();
            scene.frameCamera = frameCamera;
            scene.renderOrigin = basePlane.P0;
            scene.preview = preview;
            scene.renderOptions = renderOptions;
            scene.layers = layer;
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

            referenceOrigin = [0; 0; 0];
            opticalAxis = [1; 0; 0];
            rowAxis = [0; 1; 0];
            platformDirection = ProjectionViewerHarness.unitVector( ...
                options.PlatformDirection, "PlatformDirection");

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
            geometryData.Origins = origins;
            geometryData.CameraRays = cameraRays;
            geometryData.Attitudes = [];
            geometryData.WorldVectors = [];
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

            if isempty(defaults.PlatformStepMeters)
                defaults.PlatformStepMeters = defaults.GSD;
            end
            defaults.PlatformStepMeters = ProjectionViewerHarness.validatePositiveScalar( ...
                defaults.PlatformStepMeters, "PlatformStepMeters");

            options = defaults;
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
            layer.DisplayTexture = ProjectionViewerHarness.prepareDisplayTexture(imageData);
            layer.ImagePath = string(imagePath);
            layer.ImageMetadata = imageMetadata;
            layer.SourceGeometry = sourceGeometry;
            layer.BaseProjectionPlane = basePlane;
            layer.CurrentProjectionPlane = basePlane;
            layer.MeshSampling = meshSampling;
            layer.Alpha = 1.0;
            layer.BlendMode = "alpha";
            layer.Visible = true;
        end

        function plane = createBaseProjectionPlane(sourceGeometry)
            planeOrigin = sourceGeometry.ReferenceOrigin + ...
                sourceGeometry.NominalRange * sourceGeometry.OpticalAxis;
            plane = PlanarProjection.definePlaneFromBasis( ...
                planeOrigin, sourceGeometry.RowAxis, sourceGeometry.PlatformDirection);
        end

        function metadata = createSourceMetadata(imageSize, options)
            metadata = struct();
            metadata.Description = "Synthetic linear-array geometry";
            metadata.ImageHeightMeters = imageSize(1) * options.GSD;
            metadata.ImageWidthMeters = imageSize(2) * options.PlatformStepMeters;
            metadata.CPUReferencePath = true;
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

        function value = validatePositiveInteger(value, name)
            if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value) || ...
                    value < 1 || fix(value) ~= value
                error("ProjectionViewerHarness:invalidInteger", ...
                    "%s must be a positive integer scalar.", name);
            end
            value = double(value);
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
