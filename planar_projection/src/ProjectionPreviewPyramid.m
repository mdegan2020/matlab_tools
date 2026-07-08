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
        end

        function tiles = emptyTiles()
            %emptyTiles Return an empty preview tile struct array.
            tiles = ProjectionPreviewPyramid.makeEmptyTiles();
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
            levels = struct("Image", {}, "RowIndices", {}, ...
                "ColumnIndices", {}, "Downsample", {}, "ImageSize", {});
            while true
                levelIndex = levelIndex + 1;
                rowIndices = ProjectionPreviewPyramid.levelIndices( ...
                    imageSize(1), factor);
                columnIndices = ProjectionPreviewPyramid.levelIndices( ...
                    imageSize(2), factor);

                if factor == 1
                    levels(levelIndex).Image = imageData;
                else
                    levels(levelIndex).Image = imageData(rowIndices, columnIndices, :);
                end
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

        function texture = tileTexture(pyramid, tile)
            %tileTexture Return the image data for a single pyramid tile.
            ProjectionPreviewPyramid.validatePyramid(pyramid);
            tile = ProjectionPreviewPyramid.validateTile(tile);
            level = pyramid.Levels(tile.LevelIndex);
            texture = level.Image( ...
                tile.LevelRowLimits(1):tile.LevelRowLimits(2), ...
                tile.LevelColumnLimits(1):tile.LevelColumnLimits(2), :);
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
            tile.SourceRowLimits = [ ...
                level.RowIndices(rowStart), level.RowIndices(rowEnd)];
            tile.SourceColumnLimits = [ ...
                level.ColumnIndices(columnStart), ...
                level.ColumnIndices(columnEnd)];
            tile.TextureSize = [rowEnd - rowStart + 1, ...
                columnEnd - columnStart + 1];
        end

        function indices = levelIndices(upperBound, factor)
            indices = unique([1:factor:upperBound, upperBound], "stable");
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
    end
end
