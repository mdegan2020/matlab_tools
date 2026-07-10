classdef ProjectionAlignmentWorkingImageRenderer
    %ProjectionAlignmentWorkingImageRenderer Render projection-plane analysis images.

    properties (Constant)
        Format = "ProjectionAlignmentWorkingImages"
        Version = 2
    end

    methods (Static)
        function workingImages = render(scene, request, options)
            %render Render selected layers into common projection-plane images.
            if nargin < 3
                options = struct();
            end
            if nargin < 2
                request = struct();
            end

            scene = ProjectionLayerIdentity.ensureScene(scene);
            ProjectionAlignmentWorkingImageRenderer.validateScene(scene);
            request = ProjectionAlignmentWorkingImageRenderer.validateRequest(scene, request);
            options = ProjectionAlignmentWorkingImageRenderer.mergeOptions(options);
            schedule = ProjectionAlignmentScheduler.build(scene, request);
            request = ProjectionAlignmentWorkingImageRenderer.requestForSchedule( ...
                request, schedule);
            selectedScene = ProjectionAlignmentWorkingImageRenderer.selectedScene( ...
                scene, request);
            outputGrid = ProjectionAlignmentWorkingImageRenderer.outputGrid( ...
                selectedScene, options);
            readback = ProjectionReadbackRenderer.renderScene(selectedScene, struct( ...
                OutputGrid=outputGrid, ...
                Interpolation=options.Interpolation, ...
                InvalidFillValue=options.InvalidFillValue, ...
                IncludeLayerReadbacks=true, ...
                NumericalMode="sparseIntensityScatteredInterpolant"));

            samplingGrid = readback.CameraGrid;
            layerImages = ProjectionAlignmentWorkingImageRenderer.layerImages( ...
                readback, request, samplingGrid, selectedScene);
            workingImages = struct();
            workingImages.Format = ProjectionAlignmentWorkingImageRenderer.Format;
            workingImages.Version = ProjectionAlignmentWorkingImageRenderer.Version;
            workingImages.LayerIndices = request.LayerIndices;
            workingImages.LayerIds = request.LayerIds;
            workingImages.ReferenceLayerIndex = request.ReferenceLayerIndex;
            workingImages.ReferenceLayerId = request.ReferenceLayerId;
            workingImages.AnalysisBands = request.AnalysisBands;
            workingImages.Schedule = schedule;
            workingImages.OutputSize = outputGrid.OutputSize;
            workingImages.Interpolation = options.Interpolation;
            workingImages.NumericalMode = ...
                "sparseIntensityScatteredInterpolant";
            workingImages.ProjectionPlane = outputGrid.ReferencePlane;
            workingImages.OutputGrid = outputGrid;
            workingImages.PixelToPlane = ...
                ProjectionAlignmentWorkingImageRenderer.pixelToPlane(samplingGrid);
            workingImages.LayerImages = layerImages;
            workingImages.LayerMasks = ProjectionAlignmentWorkingImageRenderer.layerMasks( ...
                layerImages, outputGrid.OutputSize);
            workingImages.PairOverlapMasks = ...
                ProjectionAlignmentWorkingImageRenderer.pairOverlapMasks( ...
                layerImages, schedule.Pairs);
        end
    end

    methods (Static, Access = private)
        function request = validateRequest(scene, request)
            if isempty(request)
                request = struct();
            end
            if ~isstruct(request) || ~isscalar(request)
                error("ProjectionAlignmentWorkingImageRenderer:invalidRequest", ...
                    "Alignment request must be a scalar struct.");
            end
            if ~isfield(request, "Scene")
                request.Scene = scene;
            end
            request = ProjectionAlignmentRequest.validate(request);
        end

        function validateScene(scene)
            if ~isstruct(scene) || ~isscalar(scene) || ~isfield(scene, "layers") || ...
                    ~isfield(scene, "renderOrigin") || isempty(scene.layers) || ...
                    ~isstruct(scene.layers)
                error("ProjectionAlignmentWorkingImageRenderer:invalidScene", ...
                    "Scene must contain renderOrigin and a nonempty layer struct array.");
            end
        end

        function request = requestForSchedule(request, schedule)
            sourceLayerIndices = request.LayerIndices;
            sourceLayerIds = request.LayerIds;
            sourceBands = request.AnalysisBands;
            scheduledBands = ones(1, numel(schedule.LayerIndices));
            scheduledLayerIds = strings(1, numel(schedule.LayerIndices));
            for k = 1:numel(schedule.LayerIndices)
                sourcePosition = find(sourceLayerIndices == schedule.LayerIndices(k), ...
                    1, "first");
                if ~isempty(sourcePosition)
                    scheduledBands(k) = sourceBands(sourcePosition);
                    if numel(sourceLayerIds) >= sourcePosition
                        scheduledLayerIds(k) = sourceLayerIds(sourcePosition);
                    end
                end
            end
            request.LayerIndices = schedule.LayerIndices;
            request.LayerIds = scheduledLayerIds;
            request.ReferenceLayerIndex = schedule.ReferenceLayerIndex;
            request.ReferenceLayerId = schedule.ReferenceLayerId;
            request.AnalysisBands = scheduledBands;
        end

        function options = mergeOptions(options)
            if isempty(options)
                options = struct();
            end
            if ~isstruct(options) || ~isscalar(options)
                error("ProjectionAlignmentWorkingImageRenderer:invalidOptions", ...
                    "Options must be a scalar struct.");
            end

            defaults = struct();
            defaults.OutputSize = [];
            defaults.ResolutionMetersPerPixel = [];
            defaults.MaxOutputPixels = 100000000;
            defaults.AllowLargeOutput = false;
            defaults.Interpolation = "bilinear";
            defaults.InvalidFillValue = NaN;

            names = fieldnames(options);
            for k = 1:numel(names)
                defaults.(names{k}) = options.(names{k});
            end

            if ~isempty(defaults.OutputSize)
                defaults.OutputSize = ...
                    ProjectionAlignmentWorkingImageRenderer.validateOutputSize( ...
                    defaults.OutputSize);
            end
            if ~isempty(defaults.ResolutionMetersPerPixel)
                defaults.ResolutionMetersPerPixel = ...
                    ProjectionAlignmentWorkingImageRenderer.validatePositiveScalar( ...
                    defaults.ResolutionMetersPerPixel, ...
                    "ResolutionMetersPerPixel");
            end
            defaults.MaxOutputPixels = ...
                ProjectionAlignmentWorkingImageRenderer.validatePositiveInteger( ...
                defaults.MaxOutputPixels, "MaxOutputPixels");
            defaults.AllowLargeOutput = ...
                ProjectionAlignmentWorkingImageRenderer.validateLogicalScalar( ...
                defaults.AllowLargeOutput, "AllowLargeOutput");
            defaults.Interpolation = ...
                ProjectionAlignmentWorkingImageRenderer.validateInterpolation( ...
                defaults.Interpolation);
            defaults.InvalidFillValue = ...
                ProjectionAlignmentWorkingImageRenderer.validateNumericScalar( ...
                defaults.InvalidFillValue, "InvalidFillValue");
            options = defaults;
        end

        function selectedScene = selectedScene(scene, request)
            selectedScene = scene;
            for layerIndex = 1:numel(selectedScene.layers)
                selectedScene.layers(layerIndex).Visible = false;
            end

            for requestIndex = 1:numel(request.LayerIndices)
                layerIndex = request.LayerIndices(requestIndex);
                bandIndex = request.AnalysisBands(requestIndex);
                layer = selectedScene.layers(layerIndex);
                layer.Image = ProjectionAlignmentWorkingImageRenderer.selectBand( ...
                    layer.Image, bandIndex, layerIndex);
                layer.Visible = true;
                selectedScene.layers(layerIndex) = layer;
            end
        end

        function imageBand = selectBand(imageData, bandIndex, layerIndex)
            bandCount = size(imageData, 3);
            if bandIndex > bandCount
                error("ProjectionAlignmentWorkingImageRenderer:invalidAnalysisBand", ...
                    "Analysis band %d exceeds layer %d band count.", ...
                    bandIndex, layerIndex);
            end
            imageBand = imageData(:, :, bandIndex);
        end

        function outputGrid = outputGrid(scene, options)
            gridOptions = struct();
            gridOptions.OutputSize = options.OutputSize;
            gridOptions.ResolutionMetersPerPixel = options.ResolutionMetersPerPixel;
            gridOptions.MaxOutputPixels = options.MaxOutputPixels;
            gridOptions.AllowLargeOutput = options.AllowLargeOutput;
            outputGrid = ProjectionBackendOutputGrid.plan(scene, gridOptions);
        end

        function layerImages = layerImages(readback, request, samplingGrid, selectedScene)
            layerReadbacks = readback.LayerReadbacks;
            for k = 1:numel(layerReadbacks)
                layerReadback = layerReadbacks(k);
                layer = selectedScene.layers(layerReadback.LayerIndex);
                [sourceRows, sourceColumns, sourceMask] = ...
                    ProjectionAlignmentWorkingImageRenderer.sourceObservationMap( ...
                    layerReadback, samplingGrid.OutputSize, layer.CurrentProjectionPlane);
                layerImage = struct();
                layerImage.LayerIndex = layerReadback.LayerIndex;
                layerImage.LayerId = string(layer.LayerId);
                layerImage.AnalysisBand = ...
                    ProjectionAlignmentWorkingImageRenderer.analysisBandForLayer( ...
                    request, layerReadback.LayerIndex);
                layerImage.Image = layerReadback.Image;
                layerImage.ValidMask = layerReadback.ValidMask;
                layerImage.PlaneCoordinates = layerReadback.QueryPlaneCoordinates;
                layerImage.SourceRows = sourceRows;
                layerImage.SourceColumns = sourceColumns;
                layerImage.SourceObservationMask = sourceMask;
                layerImage.Mesh = layerReadback.Mesh;
                if k == 1
                    layerImages = layerImage;
                else
                    layerImages(k) = layerImage;
                end
            end
        end

        function analysisBand = analysisBandForLayer(request, layerIndex)
            requestPosition = find(request.LayerIndices == layerIndex, 1, "first");
            if isempty(requestPosition)
                error("ProjectionAlignmentWorkingImageRenderer:invalidReadback", ...
                    "Readback layer is not part of the alignment request.");
            end
            analysisBand = request.AnalysisBands(requestPosition);
        end

        function pixelMap = pixelToPlane(outputGrid)
            pixelMap = struct();
            pixelMap.X = outputGrid.X;
            pixelMap.Y = outputGrid.Y;
            pixelMap.Coordinates = [outputGrid.X(:).'; outputGrid.Y(:).'];
        end

        function masks = layerMasks(layerImages, outputSize)
            masks = false([outputSize numel(layerImages)]);
            for k = 1:numel(layerImages)
                masks(:, :, k) = layerImages(k).ValidMask;
            end
        end

        function pairMasks = pairOverlapMasks(layerImages, pairs)
            pairMasks = struct("Pair", {}, "PairLayerIds", {}, ...
                "MovingLayerId", {}, "ReferenceLayerId", {}, ...
                "PairDirection", {}, "Mask", {}, "Count", {});
            for pairIndex = 1:numel(pairs)
                pair = pairs(pairIndex).Pair;
                movingLayer = ProjectionAlignmentWorkingImageRenderer.layerImageByIndex( ...
                    layerImages, pair(1));
                referenceLayer = ProjectionAlignmentWorkingImageRenderer.layerImageByIndex( ...
                    layerImages, pair(2));
                mask = movingLayer.ValidMask & referenceLayer.ValidMask;
                pairMasks(pairIndex).Pair = pair;
                pairMasks(pairIndex).PairLayerIds = [ ...
                    movingLayer.LayerId, referenceLayer.LayerId];
                pairMasks(pairIndex).MovingLayerId = movingLayer.LayerId;
                pairMasks(pairIndex).ReferenceLayerId = referenceLayer.LayerId;
                pairMasks(pairIndex).PairDirection = "movingToReference";
                pairMasks(pairIndex).Mask = mask;
                pairMasks(pairIndex).Count = nnz(mask);
            end
        end

        function layerImage = layerImageByIndex(layerImages, layerIndex)
            matches = [layerImages.LayerIndex] == layerIndex;
            if ~any(matches)
                error("ProjectionAlignmentWorkingImageRenderer:missingLayerImage", ...
                    "Scheduled layer %d was not rendered.", layerIndex);
            end
            layerImage = layerImages(find(matches, 1, "first"));
        end

        function [sourceRows, sourceColumns, sourceMask] = sourceObservationMap( ...
                layerReadback, outputSize, plane)
            mesh = layerReadback.Mesh;
            worldPoints = reshape(mesh.WorldPoints, 3, []);
            meshPlaneCoordinates = PlanarProjection.worldToPlane( ...
                worldPoints, plane);
            [rowGrid, columnGrid] = ndgrid(mesh.RowIndices, mesh.ColumnIndices);
            queryPlaneCoordinates = layerReadback.QueryPlaneCoordinates;
            rowInterpolant = scatteredInterpolant( ...
                meshPlaneCoordinates(1, :).', meshPlaneCoordinates(2, :).', ...
                rowGrid(:), "linear", "none");
            columnInterpolant = scatteredInterpolant( ...
                meshPlaneCoordinates(1, :).', meshPlaneCoordinates(2, :).', ...
                columnGrid(:), "linear", "none");
            sourceRows = reshape(rowInterpolant( ...
                queryPlaneCoordinates(1, :).', queryPlaneCoordinates(2, :).'), ...
                outputSize);
            sourceColumns = reshape(columnInterpolant( ...
                queryPlaneCoordinates(1, :).', queryPlaneCoordinates(2, :).'), ...
                outputSize);
            sourceMask = layerReadback.ValidMask & isfinite(sourceRows) & ...
                isfinite(sourceColumns);
            sourceRows(~sourceMask) = NaN;
            sourceColumns(~sourceMask) = NaN;
        end

        function outputSize = validateOutputSize(outputSize)
            if ~isnumeric(outputSize) || ~isvector(outputSize) || numel(outputSize) ~= 2 || ...
                    any(~isfinite(outputSize)) || any(outputSize < 1) || ...
                    any(fix(outputSize) ~= outputSize)
                error("ProjectionAlignmentWorkingImageRenderer:invalidOptions", ...
                    "OutputSize must be a finite positive 1x2 integer vector.");
            end
            outputSize = double(outputSize(:).');
        end

        function value = validatePositiveScalar(value, name)
            if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value) || value <= 0
                error("ProjectionAlignmentWorkingImageRenderer:invalidOptions", ...
                    "%s must be a positive finite scalar.", name);
            end
            value = double(value);
        end

        function value = validatePositiveInteger(value, name)
            value = ProjectionAlignmentWorkingImageRenderer.validatePositiveScalar( ...
                value, name);
            if fix(value) ~= value
                error("ProjectionAlignmentWorkingImageRenderer:invalidOptions", ...
                    "%s must be a positive integer.", name);
            end
        end

        function value = validateLogicalScalar(value, name)
            if ~(islogical(value) || isnumeric(value)) || ~isscalar(value)
                error("ProjectionAlignmentWorkingImageRenderer:invalidOptions", ...
                    "%s must be a scalar logical value.", name);
            end
            value = logical(value);
        end

        function value = validateNumericScalar(value, name)
            if ~isnumeric(value) || ~isscalar(value)
                error("ProjectionAlignmentWorkingImageRenderer:invalidOptions", ...
                    "%s must be a numeric scalar.", name);
            end
            value = double(value);
        end

        function interpolation = validateInterpolation(interpolation)
            interpolation = lower(string(interpolation));
            if ~isscalar(interpolation) || ~ismember(interpolation, ["bilinear", "nearest"])
                error("ProjectionAlignmentWorkingImageRenderer:invalidOptions", ...
                    "Interpolation must be bilinear or nearest.");
            end
        end
    end
end
