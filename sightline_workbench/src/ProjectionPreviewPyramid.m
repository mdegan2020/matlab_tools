classdef ProjectionPreviewPyramid
    %ProjectionPreviewPyramid Build display-only image pyramids and tiles.
    %
    % This helper is intentionally app-facing only. It never changes layer
    % imagery used by backend rendering or readback.

    methods (Static)
        function options = defaultOptions(overrides)
            %defaultOptions Return display-preview tiling defaults.
            if nargin < 1
                overrides = struct();
            end
            if isempty(overrides)
                overrides = struct();
            end
            if ~isstruct(overrides) || ~isscalar(overrides)
                error("ProjectionPreviewPyramid:invalidOptions", ...
                    "Preview pyramid options must be a scalar struct.");
            end

            options = struct();
            options.TileSize = 1024;
            options.MinTiledImagePixels = 4e6;
            options.MaxTileMeshVertices = 33;
            options.MaxVisibleTilesPerLayer = 96;
            options.LazyLevels = true;
            options.ReductionMethod = "box";
            options.SourcePath = "";
            options.UseFileSource = true;
            options.UseScalarSingleBandTextures = true;

            names = fieldnames(overrides);
            for k = 1:numel(names)
                options.(names{k}) = overrides.(names{k});
            end

            options.TileSize = ProjectionPreviewPyramid.validatePositiveInteger( ...
                options.TileSize, "TileSize");
            options.MinTiledImagePixels = ...
                ProjectionPreviewPyramid.validatePositiveScalar( ...
                options.MinTiledImagePixels, "MinTiledImagePixels");
            options.MaxTileMeshVertices = ...
                ProjectionPreviewPyramid.validatePositiveInteger( ...
                options.MaxTileMeshVertices, "MaxTileMeshVertices");
            options.MaxVisibleTilesPerLayer = ...
                ProjectionPreviewPyramid.validatePositiveInteger( ...
                options.MaxVisibleTilesPerLayer, "MaxVisibleTilesPerLayer");
            options.LazyLevels = ProjectionPreviewPyramid.validateLogical( ...
                options.LazyLevels, "LazyLevels");
            options.ReductionMethod = string(validatestring( ...
                string(options.ReductionMethod), "box"));
            options.SourcePath = string(options.SourcePath);
            if ~isscalar(options.SourcePath) || ismissing(options.SourcePath)
                error("ProjectionPreviewPyramid:invalidOptions", ...
                    "SourcePath must be a string scalar.");
            end
            options.UseFileSource = ProjectionPreviewPyramid.validateLogical( ...
                options.UseFileSource, "UseFileSource");
            options.UseScalarSingleBandTextures = ...
                ProjectionPreviewPyramid.validateLogical( ...
                options.UseScalarSingleBandTextures, ...
                "UseScalarSingleBandTextures");
        end

        function tiles = emptyTiles()
            %emptyTiles Return an empty preview tile struct array.
            tiles = ProjectionPreviewPyramid.makeEmptyTiles();
        end

        function key = tileKey(tile)
            %tileKey Return a stable display-tile identity.
            tile = ProjectionPreviewPyramid.validateTile(tile);
            key = string(sprintf("L%d_R%d-%d_C%d-%d", ...
                tile.LevelIndex, tile.LevelRowLimits(1), ...
                tile.LevelRowLimits(2), tile.LevelColumnLimits(1), ...
                tile.LevelColumnLimits(2)));
        end

        function pyramid = build(imageData, options)
            %build Construct a decimated display pyramid.
            if nargin < 2
                options = ProjectionPreviewPyramid.defaultOptions();
            else
                options = ProjectionPreviewPyramid.defaultOptions(options);
            end
            ProjectionPreviewPyramid.validateImageData(imageData);

            imageSize = [size(imageData, 1), size(imageData, 2)];
            factor = 1;
            levelIndex = 0;
            useFileSource = options.UseFileSource && ...
                ProjectionPreviewPyramid.canUseFileSource( ...
                imageData, options.SourcePath);
            levels = struct("Image", {}, "Materialized", {}, ...
                "RowIndices", {}, "ColumnIndices", {}, ...
                "Downsample", {}, "ImageSize", {});
            while true
                levelIndex = levelIndex + 1;
                rowIndices = ProjectionPreviewPyramid.levelIndices( ...
                    imageSize(1), factor);
                columnIndices = ProjectionPreviewPyramid.levelIndices( ...
                    imageSize(2), factor);

                shouldMaterialize = ~options.LazyLevels || ...
                    (factor == 1 && ~useFileSource);
                if shouldMaterialize && factor == 1
                    levels(levelIndex).Image = imageData;
                elseif shouldMaterialize
                    levels(levelIndex).Image = ...
                        ProjectionPreviewPyramid.reduceImage( ...
                        imageData, [numel(rowIndices), numel(columnIndices)], ...
                        options.ReductionMethod);
                else
                    levels(levelIndex).Image = [];
                end
                levels(levelIndex).Materialized = shouldMaterialize;
                levels(levelIndex).RowIndices = rowIndices;
                levels(levelIndex).ColumnIndices = columnIndices;
                levels(levelIndex).Downsample = factor;
                levels(levelIndex).ImageSize = ...
                    [numel(rowIndices), numel(columnIndices)];

                if max(levels(levelIndex).ImageSize) <= options.TileSize
                    break
                end
                factor = factor * 2;
            end

            pyramid = struct();
            pyramid.ImageSize = imageSize;
            pyramid.BandCount = size(imageData, 3);
            pyramid.ImageClass = string(class(imageData));
            pyramid.Levels = levels;
            pyramid.Options = options;
            if useFileSource
                sourceMode = "file";
                memoryImage = [];
            else
                sourceMode = "memory";
                memoryImage = imageData;
            end
            pyramid.Source = struct(Mode=sourceMode, ...
                Path=options.SourcePath, MemoryImage=memoryImage);
        end

        function tf = shouldUseTiling(pyramid, options)
            %shouldUseTiling Return true when a layer should use tiled preview.
            if nargin < 2
                options = pyramid.Options;
            else
                options = ProjectionPreviewPyramid.defaultOptions(options);
            end
            ProjectionPreviewPyramid.validatePyramid(pyramid);

            tf = prod(double(pyramid.ImageSize)) > ...
                options.MinTiledImagePixels && numel(pyramid.Levels) > 1;
        end

        function levelIndex = selectLevel(pyramid, desiredDownsample)
            %selectLevel Choose the finest level no finer than screen demand.
            ProjectionPreviewPyramid.validatePyramid(pyramid);
            desiredDownsample = ProjectionPreviewPyramid.validatePositiveScalar( ...
                desiredDownsample, "desiredDownsample");

            downsamples = [pyramid.Levels.Downsample];
            levelIndex = find(downsamples <= desiredDownsample, 1, "last");
            if isempty(levelIndex)
                levelIndex = 1;
            end
            levelIndex = min(levelIndex, numel(pyramid.Levels));
        end

        function [levelIndex, diagnostics] = selectLevelWithHysteresis( ...
                pyramid, desiredDownsample, currentLevelIndex, ...
                promoteThreshold, demoteThreshold)
            %selectLevelWithHysteresis Choose a stable stateful preview LOD.
            ProjectionPreviewPyramid.validatePyramid(pyramid);
            desiredDownsample = ProjectionPreviewPyramid.validatePositiveScalar( ...
                desiredDownsample, "desiredDownsample");
            currentLevelIndex = ProjectionPreviewPyramid.validateLevelIndex( ...
                currentLevelIndex, numel(pyramid.Levels));
            promoteThreshold = ProjectionPreviewPyramid.validatePositiveScalar( ...
                promoteThreshold, "promoteThreshold");
            demoteThreshold = ProjectionPreviewPyramid.validatePositiveScalar( ...
                demoteThreshold, "demoteThreshold");
            if promoteThreshold >= 1 || demoteThreshold <= 1 || ...
                    promoteThreshold >= demoteThreshold
                error("ProjectionPreviewPyramid:invalidHysteresis", ...
                    "LOD promotion must be below one and demotion must be above one.");
            end

            levelCount = numel(pyramid.Levels);
            desiredLevelIndex = ProjectionPreviewPyramid.selectLevel( ...
                pyramid, desiredDownsample);
            currentDownsample = ...
                pyramid.Levels(currentLevelIndex).Downsample;
            levelTexelsPerScreenPixel = ...
                desiredDownsample / currentDownsample;
            levelIndex = currentLevelIndex;

            if levelTexelsPerScreenPixel < promoteThreshold && ...
                    currentLevelIndex > 1
                levelIndex = min(desiredLevelIndex, currentLevelIndex - 1);
            elseif levelTexelsPerScreenPixel > demoteThreshold && ...
                    currentLevelIndex < levelCount
                levelIndex = max(desiredLevelIndex, currentLevelIndex + 1);
            end

            diagnostics = struct();
            diagnostics.CurrentLevelIndex = currentLevelIndex;
            diagnostics.DesiredLevelIndex = desiredLevelIndex;
            diagnostics.SelectedLevelIndex = levelIndex;
            diagnostics.LevelTexelsPerScreenPixel = ...
                levelTexelsPerScreenPixel;
            diagnostics.WasSuppressed = levelIndex == currentLevelIndex && ...
                desiredLevelIndex ~= currentLevelIndex;
        end

        function tiles = tileBounds(pyramid, levelIndex, tileSize)
            %tileBounds Return level and source-image bounds for each tile.
            ProjectionPreviewPyramid.validatePyramid(pyramid);
            levelIndex = ProjectionPreviewPyramid.validateLevelIndex( ...
                levelIndex, numel(pyramid.Levels));
            if nargin < 3 || isempty(tileSize)
                tileSize = pyramid.Options.TileSize;
            end
            tileSize = ProjectionPreviewPyramid.validatePositiveInteger( ...
                tileSize, "tileSize");

            level = pyramid.Levels(levelIndex);
            rowStarts = 1:tileSize:level.ImageSize(1);
            columnStarts = 1:tileSize:level.ImageSize(2);
            tiles = ProjectionPreviewPyramid.emptyTiles();
            tileIndex = 0;
            for rowStart = rowStarts
                rowEnd = min(rowStart + tileSize - 1, level.ImageSize(1));
                for columnStart = columnStarts
                    columnEnd = min(columnStart + tileSize - 1, ...
                        level.ImageSize(2));
                    tileIndex = tileIndex + 1;
                    tiles(tileIndex) = ProjectionPreviewPyramid.makeTile( ...
                        level, levelIndex, rowStart, rowEnd, ...
                        columnStart, columnEnd);
                end
            end
        end

        function [texture, pyramid, wasMaterialized] = tileTexture(pyramid, tile)
            %tileTexture Return the image data for a single pyramid tile.
            ProjectionPreviewPyramid.validatePyramid(pyramid);
            tile = ProjectionPreviewPyramid.validateTile(tile);
            wasMaterialized = false;
            if tile.LevelIndex == 1 && pyramid.Source.Mode == "file" && ...
                    ~pyramid.Levels(1).Materialized
                texture = ProjectionPreviewPyramid.readFileRegion( ...
                    pyramid.Source.Path, tile.LevelRowLimits, ...
                    tile.LevelColumnLimits);
                return
            end
            [pyramid, wasMaterialized] = ...
                ProjectionPreviewPyramid.materializeLevel( ...
                pyramid, tile.LevelIndex);
            level = pyramid.Levels(tile.LevelIndex);
            texture = level.Image( ...
                tile.LevelRowLimits(1):tile.LevelRowLimits(2), ...
                tile.LevelColumnLimits(1):tile.LevelColumnLimits(2), :);
        end

        function [pyramid, wasMaterialized] = materializeLevel( ...
                pyramid, levelIndex)
            %materializeLevel Lazily create one antialiased pyramid level.
            ProjectionPreviewPyramid.validatePyramid(pyramid);
            levelIndex = ProjectionPreviewPyramid.validateLevelIndex( ...
                levelIndex, numel(pyramid.Levels));
            wasMaterialized = false;
            if pyramid.Levels(levelIndex).Materialized
                return
            end

            sourceImage = ProjectionPreviewPyramid.readFullSource(pyramid);
            if levelIndex == 1
                levelImage = sourceImage;
            else
                levelImage = ProjectionPreviewPyramid.reduceImage( ...
                    sourceImage, pyramid.Levels(levelIndex).ImageSize, ...
                    pyramid.Options.ReductionMethod);
            end
            pyramid.Levels(levelIndex).Image = levelImage;
            pyramid.Levels(levelIndex).Materialized = true;
            wasMaterialized = true;
        end

        function diagnostics = storageDiagnostics(pyramid)
            %storageDiagnostics Report runtime preview-level materialization.
            ProjectionPreviewPyramid.validatePyramid(pyramid);
            materializedMask = [pyramid.Levels.Materialized];
            materializedBytes = 0;
            additionalMaterializedBytes = 0;
            for levelIndex = find(materializedMask)
                levelImage = pyramid.Levels(levelIndex).Image;
                levelBytes = ...
                    numel(levelImage) * ...
                    ProjectionPreviewPyramid.classBytes(class(levelImage));
                materializedBytes = materializedBytes + levelBytes;
                if levelIndex > 1 || pyramid.Source.Mode == "file"
                    additionalMaterializedBytes = ...
                        additionalMaterializedBytes + levelBytes;
                end
            end
            diagnostics = struct( ...
                SourceMode=pyramid.Source.Mode, ...
                LevelCount=numel(pyramid.Levels), ...
                MaterializedLevelCount=nnz(materializedMask), ...
                MaterializedBytes=double(materializedBytes), ...
                AdditionalMaterializedBytes= ...
                double(additionalMaterializedBytes));
        end

        function meshSampling = tileMeshSampling(~, tile, maxVertices)
            %tileMeshSampling Return full-resolution sample coordinates.
            tile = ProjectionPreviewPyramid.validateTile(tile);
            if nargin < 3 || isempty(maxVertices)
                maxVertices = 33;
            end
            maxVertices = ProjectionPreviewPyramid.validatePositiveInteger( ...
                maxVertices, "maxVertices");

            rowCount = min(maxVertices, tile.TextureSize(1));
            columnCount = min(maxVertices, tile.TextureSize(2));
            rowIndices = ProjectionPreviewPyramid.integerSpan( ...
                tile.SourceRowLimits, rowCount);
            columnIndices = ProjectionPreviewPyramid.integerSpan( ...
                tile.SourceColumnLimits, columnCount);

            meshSampling = struct();
            meshSampling.RowStride = max(1, round( ...
                diff(tile.SourceRowLimits) / max(numel(rowIndices) - 1, 1)));
            meshSampling.ColumnStride = max(1, round( ...
                diff(tile.SourceColumnLimits) / max(numel(columnIndices) - 1, 1)));
            meshSampling.RowIndices = rowIndices;
            meshSampling.ColumnIndices = columnIndices;
        end
    end

    methods (Static, Access = private)
        function tiles = makeEmptyTiles()
            tiles = struct("LevelIndex", {}, "Downsample", {}, ...
                "LevelRowLimits", {}, "LevelColumnLimits", {}, ...
                "SourceRowLimits", {}, "SourceColumnLimits", {}, ...
                "TextureSize", {});
        end

        function tile = makeTile(level, levelIndex, rowStart, rowEnd, ...
                columnStart, columnEnd)
            tile = struct();
            tile.LevelIndex = levelIndex;
            tile.Downsample = level.Downsample;
            tile.LevelRowLimits = [rowStart, rowEnd];
            tile.LevelColumnLimits = [columnStart, columnEnd];
            tile.SourceRowLimits = ProjectionPreviewPyramid.tileSourceLimits( ...
                level.RowIndices, rowStart, rowEnd);
            tile.SourceColumnLimits = ProjectionPreviewPyramid.tileSourceLimits( ...
                level.ColumnIndices, columnStart, columnEnd);
            tile.TextureSize = [rowEnd - rowStart + 1, ...
                columnEnd - columnStart + 1];
        end

        function limits = tileSourceLimits(indices, startIndex, endIndex)
            if startIndex > 1
                lowerLimit = round((indices(startIndex - 1) + ...
                    indices(startIndex)) / 2);
            else
                lowerLimit = indices(startIndex);
            end

            if endIndex < numel(indices)
                upperLimit = round((indices(endIndex) + ...
                    indices(endIndex + 1)) / 2);
            else
                upperLimit = indices(endIndex);
            end

            limits = double([lowerLimit, upperLimit]);
        end

        function indices = levelIndices(upperBound, factor)
            sampleCount = max(2, ceil(double(upperBound) / factor));
            if upperBound == 1
                sampleCount = 1;
            end
            indices = unique(round(linspace( ...
                1, double(upperBound), sampleCount)), "stable");
            indices = double(indices);
        end

        function indices = integerSpan(limits, count)
            count = max(1, double(count));
            if limits(1) == limits(2) || count == 1
                indices = double(limits(1));
                return
            end

            indices = unique(round(linspace(limits(1), limits(2), count)), ...
                "stable");
            indices = unique([indices, limits(2)], "stable");
            indices = double(indices);
        end

        function validateImageData(imageData)
            if ~(isnumeric(imageData) || islogical(imageData)) || ...
                    isempty(imageData) || ndims(imageData) > 3
                error("ProjectionPreviewPyramid:invalidImage", ...
                    "Image data must be a nonempty numeric or logical 2-D or 3-D array.");
            end
            if isfloat(imageData) && any(~isfinite(imageData), "all")
                error("ProjectionPreviewPyramid:invalidImage", ...
                    "Floating-point image data must be finite.");
            end
        end

        function validatePyramid(pyramid)
            if ~isstruct(pyramid) || ~isscalar(pyramid) || ...
                    ~isfield(pyramid, "ImageSize") || ...
                    ~isfield(pyramid, "Levels") || isempty(pyramid.Levels)
                error("ProjectionPreviewPyramid:invalidPyramid", ...
                    "Pyramid must be a scalar preview pyramid struct.");
            end
        end

        function tile = validateTile(tile)
            requiredFields = ["LevelIndex", "Downsample", "LevelRowLimits", ...
                "LevelColumnLimits", "SourceRowLimits", ...
                "SourceColumnLimits", "TextureSize"];
            if ~isstruct(tile) || ~isscalar(tile) || ...
                    any(~isfield(tile, requiredFields))
                error("ProjectionPreviewPyramid:invalidTile", ...
                    "Tile must be a scalar preview tile struct.");
            end
        end

        function levelIndex = validateLevelIndex(levelIndex, levelCount)
            if ~isnumeric(levelIndex) || ~isscalar(levelIndex) || ...
                    ~isfinite(levelIndex) || levelIndex < 1 || ...
                    levelIndex > levelCount || fix(levelIndex) ~= levelIndex
                error("ProjectionPreviewPyramid:invalidLevelIndex", ...
                    "Level index must select a pyramid level.");
            end
            levelIndex = double(levelIndex);
        end

        function value = validatePositiveScalar(value, name)
            if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value) || ...
                    value <= 0
                error("ProjectionPreviewPyramid:invalidScalar", ...
                    "%s must be a positive finite scalar.", name);
            end
            value = double(value);
        end

        function value = validatePositiveInteger(value, name)
            if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value) || ...
                    value < 1 || fix(value) ~= value
                error("ProjectionPreviewPyramid:invalidInteger", ...
                    "%s must be a positive integer scalar.", name);
            end
            value = double(value);
        end

        function value = validateLogical(value, name)
            if ~isscalar(value) || ...
                    ~(islogical(value) || ...
                    (isnumeric(value) && isfinite(value) && ...
                    any(value == [0 1])))
                error("ProjectionPreviewPyramid:invalidOptions", ...
                    "%s must be a logical scalar.", name);
            end
            value = logical(value);
        end

        function tf = canUseFileSource(imageData, sourcePath)
            tf = false;
            if strlength(sourcePath) == 0 || ~isfile(sourcePath)
                return
            end
            try
                sample = ProjectionPreviewPyramid.readFileRegion( ...
                    sourcePath, [1 min(2, size(imageData, 1))], ...
                    [1 min(2, size(imageData, 2))]);
                info = imfinfo(char(sourcePath));
                tf = info(1).Height == size(imageData, 1) && ...
                    info(1).Width == size(imageData, 2) && ...
                    size(sample, 3) == size(imageData, 3) && ...
                    strcmp(class(sample), class(imageData));
            catch
                tf = false;
            end
        end

        function imageData = readFullSource(pyramid)
            if pyramid.Source.Mode == "file"
                imageData = imread(char(pyramid.Source.Path));
            else
                imageData = pyramid.Source.MemoryImage;
            end
        end

        function imageData = readFileRegion(path, rowLimits, columnLimits)
            imageData = imread(char(path), "PixelRegion", ...
                {double(rowLimits), double(columnLimits)});
        end

        function reduced = reduceImage(imageData, outputSize, method)
            % Reduce directly from full source so LODs do not accumulate blur.
            % imresize owns filter support and edge extension semantics.
            reduced = imresize(imageData, double(outputSize), char(method), ...
                Antialiasing=true);
        end

        function bytes = classBytes(className)
            switch string(className)
                case {"logical", "uint8", "int8"}
                    bytes = 1;
                case {"uint16", "int16"}
                    bytes = 2;
                case {"uint32", "int32", "single"}
                    bytes = 4;
                case {"uint64", "int64", "double"}
                    bytes = 8;
                otherwise
                    error("ProjectionPreviewPyramid:unsupportedImageClass", ...
                        "Unsupported image class %s.", className);
            end
        end
    end
end
