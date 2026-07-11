classdef ProjectionAlignmentSyntheticHarness
    %ProjectionAlignmentSyntheticHarness Build red/blue alignment smoke scenes.

    properties (Constant)
        Format = "ProjectionAlignmentSyntheticHarness"
        Version = 1
    end

    methods (Static)
        function scene = createSceneFromRgbTiff(imagePath, options)
            %createSceneFromRgbTiff Build a two-layer scene from a local RGB TIFF.
            if nargin < 2
                options = struct();
            end
            if nargin < 1 || ProjectionAlignmentSyntheticHarness.isEmptyPath(imagePath)
                imagePath = ProjectionViewerHarness.defaultImagePath();
            end

            imagePath = ProjectionAlignmentSyntheticHarness.validateImagePath(imagePath);
            rgbImage = imread(imagePath);
            scene = ProjectionAlignmentSyntheticHarness.createSceneFromRgbImage( ...
                rgbImage, imagePath, options);
        end

        function scene = createSceneFromRgbImage(rgbImage, imagePath, options)
            %createSceneFromRgbImage Build synthetic red/blue single-band layers.
            if nargin < 3
                options = struct();
            end
            if nargin < 2
                imagePath = "";
            end

            options = ProjectionAlignmentSyntheticHarness.mergeOptions(options);
            rgbImage = ProjectionAlignmentSyntheticHarness.validateRgbImage(rgbImage);
            imagePath = string(imagePath);

            redImage = rgbImage(:, :, 1);
            blueImage = rgbImage(:, :, 3);
            viewerOptions = ProjectionAlignmentSyntheticHarness.viewerOptions(options);
            layerPaths = ProjectionAlignmentSyntheticHarness.layerImagePaths(imagePath);
            scene = ProjectionViewerHarness.createSceneFromImages( ...
                {redImage, blueImage}, layerPaths, viewerOptions);
            scene = ProjectionAlignmentSyntheticHarness.applyKnownPerturbations( ...
                scene, imagePath, options);
        end
    end

    methods (Static, Access = private)
        function options = mergeOptions(options)
            if isempty(options)
                options = struct();
            end
            if ~isstruct(options) || ~isscalar(options)
                error("ProjectionAlignmentSyntheticHarness:invalidOptions", ...
                    "Options must be a scalar struct.");
            end

            defaults = struct();
            defaults.LayerNames = ["Synthetic red channel", "Synthetic blue channel"];
            defaults.ViewVectorAngularOffsetsDegrees = ...
                [0.006 -0.004 0.002; -0.005 0.003 -0.0015];
            defaults.ProjectionPlaneMode = "fit";
            defaults.RowStride = 8;
            defaults.ColumnStride = 8;
            defaults.PlatformDirection = [0; 0; 1];

            names = fieldnames(options);
            for k = 1:numel(names)
                defaults.(names{k}) = options.(names{k});
            end

            defaults.LayerNames = ProjectionAlignmentSyntheticHarness.validateLayerNames( ...
                defaults.LayerNames);
            defaults.ViewVectorAngularOffsetsDegrees = ...
                ProjectionAlignmentSyntheticHarness.validatePerturbations( ...
                defaults.ViewVectorAngularOffsetsDegrees);
            options = defaults;
        end

        function viewerOptions = viewerOptions(options)
            viewerOptions = options;
            viewerOptions = ProjectionAlignmentSyntheticHarness.removeFieldIfPresent( ...
                viewerOptions, "LayerNames");
            viewerOptions = ProjectionAlignmentSyntheticHarness.removeFieldIfPresent( ...
                viewerOptions, "ViewVectorAngularOffsetsDegrees");
            viewerOptions.Name = options.LayerNames;
        end

        function scene = applyKnownPerturbations(scene, imagePath, options)
            channels = ["red", "blue"];
            channelIndices = [1 3];
            perturbations = options.ViewVectorAngularOffsetsDegrees;

            for layerIndex = 1:2
                scene.layers(layerIndex).ViewVectorAngularOffsetsDegrees = ...
                    perturbations(layerIndex, :).';
                scene.layers(layerIndex).AlignmentMetadata = ...
                    ProjectionAlignmentSyntheticHarness.layerMetadata( ...
                    scene.layers(layerIndex), layerIndex, channels(layerIndex), ...
                    channelIndices(layerIndex), ...
                    perturbations(layerIndex, :));
            end

            scene.AlignmentMetadata = ProjectionAlignmentSyntheticHarness.sceneMetadata( ...
                scene, imagePath, channels, channelIndices, perturbations);
        end

        function metadata = sceneMetadata(scene, imagePath, channels, channelIndices, ...
                perturbations)
            metadata = struct();
            metadata.Format = ProjectionAlignmentSyntheticHarness.Format;
            metadata.Version = ProjectionAlignmentSyntheticHarness.Version;
            metadata.SourceImagePath = string(imagePath);
            metadata.SourceImageSize = scene.layers(1).ImageMetadata.ImageSize;
            metadata.LayerCount = numel(scene.layers);
            metadata.LayerChannels = channels;
            metadata.ChannelIndices = channelIndices;
            metadata.ViewVectorAngularOffsetsDegrees = perturbations;
            metadata.ExpectedCorrectionDeltaDegrees = -perturbations;
            metadata.KnownPerturbations = [scene.layers.AlignmentMetadata];
        end

        function metadata = layerMetadata(layer, layerIndex, channel, channelIndex, ...
                perturbationDegrees)
            metadata = struct();
            metadata.LayerIndex = layerIndex;
            metadata.Channel = channel;
            metadata.ChannelIndex = channelIndex;
            metadata.GeometryOffset = layer.SourceGeometry.GeometryOffset;
            metadata.OpticalYawRadians = layer.SourceGeometry.OpticalYawRadians;
            metadata.ViewVectorAngularOffsetsDegrees = perturbationDegrees;
            metadata.ExpectedCorrectionDeltaDegrees = -perturbationDegrees;
        end

        function layerPaths = layerImagePaths(imagePath)
            imagePath = string(imagePath);
            if strlength(imagePath) == 0
                layerPaths = ["synthetic_alignment_red", "synthetic_alignment_blue"];
                return
            end
            layerPaths = imagePath + ["#red", "#blue"];
        end

        function imageData = validateRgbImage(imageData)
            if ~(isnumeric(imageData) || islogical(imageData)) || isempty(imageData) || ...
                    ndims(imageData) ~= 3 || size(imageData, 3) ~= 3 || ...
                    any(~isfinite(imageData), "all")
                error("ProjectionAlignmentSyntheticHarness:invalidRgbImage", ...
                    "Synthetic alignment input must be a finite RGB image.");
            end
        end

        function names = validateLayerNames(names)
            names = string(names);
            names = reshape(names, 1, []);
            if numel(names) ~= 2 || any(strlength(names) == 0)
                error("ProjectionAlignmentSyntheticHarness:invalidOptions", ...
                    "LayerNames must contain exactly two nonempty names.");
            end
        end

        function perturbations = validatePerturbations(perturbations)
            if ~isnumeric(perturbations) || ~isequal(size(perturbations), [2 3]) || ...
                    any(~isfinite(perturbations), "all")
                error("ProjectionAlignmentSyntheticHarness:invalidOptions", ...
                    "ViewVectorAngularOffsetsDegrees must be a finite 2x3 numeric array.");
            end
            perturbations = double(perturbations);
        end

        function imagePath = validateImagePath(imagePath)
            if ~(ischar(imagePath) || (isstring(imagePath) && isscalar(imagePath))) || ...
                    strlength(string(imagePath)) == 0
                error("ProjectionAlignmentSyntheticHarness:invalidImagePath", ...
                    "Image path must be a nonempty character vector or scalar string.");
            end
            imagePath = string(imagePath);
            if ~isfile(imagePath)
                error("ProjectionAlignmentSyntheticHarness:fileNotFound", ...
                    "RGB TIFF fixture does not exist: %s", imagePath);
            end
        end

        function tf = isEmptyPath(imagePath)
            if isempty(imagePath)
                tf = true;
                return
            end
            if ischar(imagePath) || isstring(imagePath)
                tf = isscalar(string(imagePath)) && strlength(string(imagePath)) == 0;
                return
            end
            tf = false;
        end

        function value = removeFieldIfPresent(value, fieldName)
            if isfield(value, fieldName)
                value = rmfield(value, fieldName);
            end
        end
    end
end
