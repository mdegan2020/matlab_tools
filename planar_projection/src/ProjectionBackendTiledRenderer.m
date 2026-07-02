classdef ProjectionBackendTiledRenderer
    %ProjectionBackendTiledRenderer Serial tiled CPU backend renderer.

    methods (Static)
        function readback = renderScene(scene, options)
            %renderScene Render a scene in bounded row/column tiles.
            if nargin < 2
                options = struct();
            end

            options = ProjectionBackendTiledRenderer.mergeOptions(scene, options);
            outputGrid = options.OutputGrid;
            outputSize = outputGrid.OutputSize;
            tiles = ProjectionBackendTiledRenderer.tileRanges( ...
                outputSize, options.TileSize);

            compositeImage = [];
            validMask = false(outputSize);
            layerReadbacks = struct([]);
            layerIndex = [];
            layerIndices = [];
            tileReports = ProjectionBackendTiledRenderer.emptyTileReports();
            tileReportIndex = 0;

            for tileIndex = 1:numel(tiles)
                tile = tiles(tileIndex);
                tileOptions = options;
                tileOptions.OutputGrid = ProjectionBackendTiledRenderer.tileOutputGrid( ...
                    outputGrid, tile.RowRange, tile.ColumnRange);
                tileOptions.OutputSize = tileOptions.OutputGrid.OutputSize;

                tileTimer = tic;
                tileReadback = ProjectionReadbackRenderer.renderScene(scene, tileOptions);
                renderSeconds = toc(tileTimer);

                if isempty(layerIndices)
                    layerIndex = tileReadback.LayerIndex;
                    layerIndices = tileReadback.LayerIndices;
                end
                if isempty(compositeImage)
                    compositeImage = ProjectionBackendTiledRenderer.allocateImage( ...
                        outputSize, tileReadback.Image);
                end
                compositeImage = ProjectionBackendTiledRenderer.assignImageTile( ...
                    compositeImage, tile.RowRange, tile.ColumnRange, tileReadback.Image);
                validMask(tile.RowRange, tile.ColumnRange) = tileReadback.ValidMask;

                if options.IncludeLayerReadbacks
                    if isempty(layerReadbacks)
                        layerReadbacks = ...
                            ProjectionBackendTiledRenderer.initializeLayerReadbacks( ...
                            tileReadback.LayerReadbacks, outputSize);
                    end
                    layerReadbacks = ProjectionBackendTiledRenderer.assignLayerTiles( ...
                        layerReadbacks, tileReadback.LayerReadbacks, outputSize, ...
                        tile.RowRange, tile.ColumnRange);
                end

                tileReportIndex = tileReportIndex + 1;
                tileReports(tileReportIndex) = ProjectionBackendTiledRenderer.tileReport( ...
                    tile, tileReadback, renderSeconds);
            end

            readback = struct();
            readback.Image = compositeImage;
            readback.ValidMask = validMask;
            readback.OutputSize = outputSize;
            readback.Interpolation = lower(string(options.Interpolation));
            readback.LayerIndex = layerIndex;
            readback.LayerIndices = layerIndices;
            readback.CameraGrid = ProjectionBackendTiledRenderer.cameraGridSummary(outputGrid);
            readback.QueryPlaneCoordinates = ...
                ProjectionBackendTiledRenderer.firstLayerField( ...
                layerReadbacks, "QueryPlaneCoordinates");
            readback.Mesh = ProjectionBackendTiledRenderer.firstLayerField( ...
                layerReadbacks, "Mesh");
            readback.LayerReadbacks = layerReadbacks;
            readback.OutputGrid = outputGrid;
            readback.Tiled = true;
            readback.TileSize = options.TileSize;
            readback.TileCount = numel(tileReports);
            readback.TileReports = tileReports;
        end
    end

    methods (Static, Access = private)
        function options = mergeOptions(scene, options)
            if isempty(options)
                options = struct();
            end
            if ~isstruct(options) || ~isscalar(options)
                error("ProjectionBackendTiledRenderer:invalidOptions", ...
                    "Options must be a scalar struct.");
            end

            defaults = struct();
            defaults.OutputSize = [];
            defaults.OutputGrid = [];
            defaults.TileSize = [256 256];
            defaults.Interpolation = "bilinear";
            defaults.IncludeLayerReadbacks = true;

            names = fieldnames(options);
            for k = 1:numel(names)
                defaults.(names{k}) = options.(names{k});
            end

            defaults.TileSize = ProjectionBackendTiledRenderer.validateTileSize( ...
                defaults.TileSize);
            if isempty(defaults.OutputGrid)
                defaults.OutputGrid = ProjectionBackendOutputGrid.plan(scene, defaults);
            else
                defaults.OutputGrid = ProjectionBackendTiledRenderer.validateOutputGrid( ...
                    defaults.OutputGrid);
            end
            defaults.OutputSize = ProjectionBackendTiledRenderer.validateOutputSize( ...
                defaults.OutputGrid.OutputSize, "OutputGrid.OutputSize");
            defaults.IncludeLayerReadbacks = ...
                ProjectionBackendTiledRenderer.validateLogicalScalar( ...
                defaults.IncludeLayerReadbacks, "IncludeLayerReadbacks");
            defaults.Interpolation = lower(string(defaults.Interpolation));
            if ~isscalar(defaults.Interpolation) || ...
                    ~ismember(defaults.Interpolation, ["bilinear", "nearest"])
                error("ProjectionBackendTiledRenderer:invalidOptions", ...
                    "Interpolation must be bilinear or nearest.");
            end

            options = defaults;
        end

        function tiles = tileRanges(outputSize, tileSize)
            rowStarts = 1:tileSize(1):outputSize(1);
            columnStarts = 1:tileSize(2):outputSize(2);
            tiles = struct([]);
            tileIndex = 0;
            for rowStart = rowStarts
                rowEnd = min(rowStart + tileSize(1) - 1, outputSize(1));
                for columnStart = columnStarts
                    columnEnd = min(columnStart + tileSize(2) - 1, outputSize(2));
                    tileIndex = tileIndex + 1;
                    tiles(tileIndex).RowRange = rowStart:rowEnd;
                    tiles(tileIndex).ColumnRange = columnStart:columnEnd;
                end
            end
        end

        function tileGrid = tileOutputGrid(outputGrid, rowRange, columnRange)
            queryX = ProjectionBackendTiledRenderer.outputGridColumnCoordinates( ...
                outputGrid);
            queryY = ProjectionBackendTiledRenderer.outputGridRowCoordinates(outputGrid);

            tileGrid = outputGrid;
            tileGrid.OutputSize = [numel(rowRange), numel(columnRange)];
            tileGrid.Bounds.X = [queryX(columnRange(1)), queryX(columnRange(end))];
            tileGrid.Bounds.Y = [queryY(rowRange(end)), queryY(rowRange(1))];
            tileGrid.PixelCount = prod(tileGrid.OutputSize);
            tileGrid.ParentOutputSize = outputGrid.OutputSize;
            tileGrid.ParentRowRange = [rowRange(1), rowRange(end)];
            tileGrid.ParentColumnRange = [columnRange(1), columnRange(end)];
        end

        function queryX = outputGridColumnCoordinates(outputGrid)
            queryX = linspace(outputGrid.Bounds.X(1), outputGrid.Bounds.X(2), ...
                outputGrid.OutputSize(2));
        end

        function queryY = outputGridRowCoordinates(outputGrid)
            queryY = linspace(outputGrid.Bounds.Y(2), outputGrid.Bounds.Y(1), ...
                outputGrid.OutputSize(1));
        end

        function imageData = allocateImage(outputSize, sampleImage)
            if ismatrix(sampleImage)
                imageData = zeros(outputSize);
            else
                imageData = zeros([outputSize size(sampleImage, 3)]);
            end
        end

        function imageData = assignImageTile(imageData, rowRange, columnRange, tileImage)
            if ismatrix(imageData)
                imageData(rowRange, columnRange) = tileImage;
            else
                imageData(rowRange, columnRange, :) = tileImage;
            end
        end

        function layerReadbacks = initializeLayerReadbacks( ...
                tileLayerReadbacks, outputSize)
            template = struct(Image=[], ValidMask=[], LayerIndex=[], ...
                QueryPlaneCoordinates=[], Mesh=[]);
            layerReadbacks = repmat(template, 1, numel(tileLayerReadbacks));
            for k = 1:numel(tileLayerReadbacks)
                layerReadbacks(k).Image = ...
                    ProjectionBackendTiledRenderer.allocateImage( ...
                    outputSize, tileLayerReadbacks(k).Image);
                layerReadbacks(k).ValidMask = false(outputSize);
                layerReadbacks(k).LayerIndex = tileLayerReadbacks(k).LayerIndex;
                layerReadbacks(k).QueryPlaneCoordinates = ...
                    zeros(2, prod(outputSize));
                layerReadbacks(k).Mesh = tileLayerReadbacks(k).Mesh;
            end
        end

        function layerReadbacks = assignLayerTiles(layerReadbacks, ...
                tileLayerReadbacks, outputSize, rowRange, columnRange)
            tileIndices = ProjectionBackendTiledRenderer.tileLinearIndices( ...
                outputSize, rowRange, columnRange);
            for k = 1:numel(layerReadbacks)
                layerReadbacks(k).Image = ...
                    ProjectionBackendTiledRenderer.assignImageTile( ...
                    layerReadbacks(k).Image, rowRange, columnRange, ...
                    tileLayerReadbacks(k).Image);
                layerReadbacks(k).ValidMask(rowRange, columnRange) = ...
                    tileLayerReadbacks(k).ValidMask;
                layerReadbacks(k).QueryPlaneCoordinates(:, tileIndices) = ...
                    tileLayerReadbacks(k).QueryPlaneCoordinates;
            end
        end

        function tileIndices = tileLinearIndices(outputSize, rowRange, columnRange)
            linearIndices = reshape(1:prod(outputSize), outputSize);
            tileIndices = linearIndices(rowRange, columnRange);
            tileIndices = tileIndices(:).';
        end

        function reports = emptyTileReports()
            reports = struct(RowRange={}, ColumnRange={}, OutputSize={}, ...
                PixelCount={}, RenderSeconds={}, EstimatedMemoryBytes={});
        end

        function report = tileReport(tile, tileReadback, renderSeconds)
            tileInfo = whos("tileReadback");
            report = struct();
            report.RowRange = [tile.RowRange(1), tile.RowRange(end)];
            report.ColumnRange = [tile.ColumnRange(1), tile.ColumnRange(end)];
            report.OutputSize = tileReadback.OutputSize;
            report.PixelCount = prod(tileReadback.OutputSize);
            report.RenderSeconds = renderSeconds;
            report.EstimatedMemoryBytes = double(tileInfo.bytes);
        end

        function cameraGrid = cameraGridSummary(outputGrid)
            cameraGrid = outputGrid;
            cameraGrid.QueryWorldPoints = [];
            cameraGrid.QueryCameraCoordinates = [];
        end

        function outputGrid = validateOutputGrid(outputGrid)
            requiredFields = ["OutputSize", "Bounds", "Origin", "XAxis", "YAxis"];
            if ~isstruct(outputGrid) || ~isscalar(outputGrid) || ...
                    any(~isfield(outputGrid, requiredFields))
                error("ProjectionBackendTiledRenderer:invalidOptions", ...
                    "OutputGrid must be a scalar output-grid struct.");
            end
            outputGrid.OutputSize = ProjectionBackendTiledRenderer.validateOutputSize( ...
                outputGrid.OutputSize, "OutputGrid.OutputSize");
            outputGrid.Bounds = ProjectionBackendTiledRenderer.validateBounds( ...
                outputGrid.Bounds);
        end

        function bounds = validateBounds(bounds)
            if ~isstruct(bounds) || ~isscalar(bounds) || ...
                    ~isfield(bounds, "X") || ~isfield(bounds, "Y")
                error("ProjectionBackendTiledRenderer:invalidOptions", ...
                    "OutputGrid.Bounds must contain X and Y ranges.");
            end
            bounds.X = ProjectionBackendTiledRenderer.validateRange( ...
                bounds.X, "OutputGrid.Bounds.X");
            bounds.Y = ProjectionBackendTiledRenderer.validateRange( ...
                bounds.Y, "OutputGrid.Bounds.Y");
        end

        function value = validateRange(value, name)
            if ~isnumeric(value) || ~isvector(value) || numel(value) ~= 2 || ...
                    any(~isfinite(value))
                error("ProjectionBackendTiledRenderer:invalidOptions", ...
                    "%s must be a finite numeric two-element range.", name);
            end
            value = double(value(:).');
        end

        function tileSize = validateTileSize(tileSize)
            tileSize = ProjectionBackendTiledRenderer.validateOutputSize( ...
                tileSize, "TileSize");
        end

        function outputSize = validateOutputSize(outputSize, name)
            if ~isnumeric(outputSize) || ~isvector(outputSize) || numel(outputSize) ~= 2 || ...
                    any(~isfinite(outputSize)) || any(outputSize < 1) || ...
                    any(fix(outputSize) ~= outputSize)
                error("ProjectionBackendTiledRenderer:invalidOptions", ...
                    "%s must be a finite positive 1x2 integer vector.", name);
            end
            outputSize = double(outputSize(:).');
        end

        function value = validateLogicalScalar(value, name)
            if ~(islogical(value) || isnumeric(value)) || ~isscalar(value)
                error("ProjectionBackendTiledRenderer:invalidOptions", ...
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
