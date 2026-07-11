classdef ProjectionBackendTiledRenderer
    %ProjectionBackendTiledRenderer Bounded serial/thread backend tile pipeline.

    methods (Static)
        function readback = renderScene(scene, options, execution, renderPlan)
            %renderScene Render a scene in bounded row/column tiles.
            if nargin < 2
                options = struct();
            end
            if nargin < 3
                execution = struct();
            end
            if nargin < 4
                renderPlan = [];
            end

            [options, preparedLayers] = ProjectionBackendTiledRenderer.mergeOptions( ...
                scene, options, execution);
            if isempty(renderPlan)
                renderPlan = ProjectionBackendRenderPlan.compile( ...
                    scene, options, preparedLayers);
            else
                renderPlan = ProjectionBackendRenderPlan.validate(renderPlan);
                ProjectionBackendTiledRenderer.validatePlanOptions( ...
                    renderPlan, options);
            end
            outputGrid = options.OutputGrid;
            outputSize = outputGrid.OutputSize;
            tiles = ProjectionBackendTiledRenderer.tileRanges( ...
                outputSize, options.TileSize);

            compositeImage = [];
            validMask = false(outputSize);
            layerReadbacks = struct([]);
            layerIndex = renderPlan.LayerIndices(1);
            layerIndices = renderPlan.LayerIndices;
            useGPU = renderPlan.UseGPU;
            gpuInfo = renderPlan.GpuInfo;
            [tileReports, peakInFlightTiles] = ...
                ProjectionBackendTiledRenderer.consumeTiles( ...
                renderPlan, options, outputGrid, tiles, @consumeTile, false);
            layerReadbacks = ...
                ProjectionBackendTiledRenderer.flattenQueryCoordinates( ...
                layerReadbacks);

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
            readback.ExecutionMode = options.ExecutionMode;
            readback.UseGPU = useGPU;
            readback.GpuInfo = gpuInfo;
            readback.TileSize = options.TileSize;
            readback.TileCount = numel(tileReports);
            readback.TileReports = tileReports;
            readback.MaximumInFlightTiles = options.MaximumInFlightTiles;
            readback.PeakInFlightTiles = peakInFlightTiles;
            readback.ReturnedInMemory = true;
            readback.Streaming = false;
            readback.StreamWriteSeconds = 0;
            readback.RenderPlan = ProjectionBackendRenderPlan.summary(renderPlan);

            function consumeTile(tile, tileReadback)
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
                            tileReadback.LayerReadbacks, outputSize, ...
                            options.IncludeQueryCoordinates);
                    end
                    layerReadbacks = ProjectionBackendTiledRenderer.assignLayerTiles( ...
                        layerReadbacks, tileReadback.LayerReadbacks, ...
                        tile.RowRange, tile.ColumnRange, ...
                        options.IncludeQueryCoordinates);
                end
            end
        end

        function readback = streamScene( ...
                scene, options, execution, renderPlan, tileConsumer)
            %streamScene Render bounded tiles and release each after consumption.
            if nargin < 3
                execution = struct();
            end
            if nargin < 4
                renderPlan = [];
            end
            if nargin < 5 || ~isa(tileConsumer, "function_handle")
                error("ProjectionBackendTiledRenderer:invalidConsumer", ...
                    "A tile-consumer function handle is required.");
            end
            [options, preparedLayers] = ...
                ProjectionBackendTiledRenderer.mergeOptions( ...
                scene, options, execution);
            if isempty(renderPlan)
                renderPlan = ProjectionBackendRenderPlan.compile( ...
                    scene, options, preparedLayers);
            else
                renderPlan = ProjectionBackendRenderPlan.validate(renderPlan);
                ProjectionBackendTiledRenderer.validatePlanOptions( ...
                    renderPlan, options);
            end

            outputGrid = options.OutputGrid;
            tiles = ProjectionBackendTiledRenderer.tileRanges( ...
                outputGrid.OutputSize, options.TileSize);
            [tileReports, peakInFlightTiles] = ...
                ProjectionBackendTiledRenderer.consumeTiles( ...
                renderPlan, options, outputGrid, tiles, tileConsumer, true);
            streamWriteSeconds = sum([tileReports.WriteSeconds]);

            readback = struct();
            readback.Image = [];
            readback.ValidMask = [];
            readback.OutputSize = outputGrid.OutputSize;
            readback.Interpolation = lower(string(options.Interpolation));
            readback.LayerIndex = renderPlan.LayerIndices(1);
            readback.LayerIndices = renderPlan.LayerIndices;
            readback.CameraGrid = ...
                ProjectionBackendTiledRenderer.cameraGridSummary(outputGrid);
            readback.QueryPlaneCoordinates = [];
            readback.Mesh = [];
            readback.LayerReadbacks = struct([]);
            readback.OutputGrid = outputGrid;
            readback.Tiled = true;
            readback.ExecutionMode = options.ExecutionMode;
            readback.UseGPU = renderPlan.UseGPU;
            readback.GpuInfo = renderPlan.GpuInfo;
            readback.TileSize = options.TileSize;
            readback.TileCount = numel(tileReports);
            readback.TileReports = tileReports;
            readback.MaximumInFlightTiles = options.MaximumInFlightTiles;
            readback.PeakInFlightTiles = peakInFlightTiles;
            readback.ReturnedInMemory = false;
            readback.Streaming = true;
            readback.StreamWriteSeconds = streamWriteSeconds;
            readback.RenderPlan = ProjectionBackendRenderPlan.summary(renderPlan);
        end
    end

    methods (Static, Access = private)
        function [options, preparedLayers] = mergeOptions(scene, options, execution)
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
            defaults.IncludeQueryCoordinates = true;
            defaults.ExecutionMode = "serial";
            defaults.MaximumInFlightTiles = 4;
            defaults.NumericalMode = "fullSourceInverseWarp";

            names = fieldnames(options);
            for k = 1:numel(names)
                defaults.(names{k}) = options.(names{k});
            end

            defaults.ExecutionMode = ...
                ProjectionBackendTiledRenderer.validateExecutionMode( ...
                ProjectionBackendTiledRenderer.fieldOrDefault( ...
                execution, "Mode", defaults.ExecutionMode));
            defaults.MaximumInFlightTiles = ...
                ProjectionBackendTiledRenderer.validatePositiveInteger( ...
                ProjectionBackendTiledRenderer.fieldOrDefault( ...
                execution, "MaximumInFlightTiles", ...
                defaults.MaximumInFlightTiles), ...
                "Execution.MaximumInFlightTiles");
            if isempty(defaults.TileSize)
                defaults.TileSize = [256 256];
            end
            defaults.TileSize = ProjectionBackendTiledRenderer.validateTileSize( ...
                defaults.TileSize);
            preparedLayers = struct([]);
            if isempty(defaults.OutputGrid)
                [defaults.OutputGrid, preparedLayers] = ...
                    ProjectionBackendOutputGrid.plan(scene, defaults);
            else
                defaults.OutputGrid = ProjectionBackendTiledRenderer.validateOutputGrid( ...
                    defaults.OutputGrid);
            end
            defaults.OutputSize = ProjectionBackendTiledRenderer.validateOutputSize( ...
                defaults.OutputGrid.OutputSize, "OutputGrid.OutputSize");
            defaults.IncludeLayerReadbacks = ...
                ProjectionBackendTiledRenderer.validateLogicalScalar( ...
                defaults.IncludeLayerReadbacks, "IncludeLayerReadbacks");
            defaults.IncludeQueryCoordinates = ...
                ProjectionBackendTiledRenderer.validateLogicalScalar( ...
                defaults.IncludeQueryCoordinates, "IncludeQueryCoordinates");
            defaults.Interpolation = lower(string(defaults.Interpolation));
            if ~isscalar(defaults.Interpolation) || ...
                    ~ismember(defaults.Interpolation, ["bilinear", "nearest"])
                error("ProjectionBackendTiledRenderer:invalidOptions", ...
                    "Interpolation must be bilinear or nearest.");
            end

            options = defaults;
        end

        function [tileReports, peakInFlightTiles] = consumeTiles( ...
                renderPlan, options, outputGrid, tiles, tileConsumer, ...
                measureConsumer)
            if options.ExecutionMode == "threads"
                [tileReports, peakInFlightTiles] = ...
                    ProjectionBackendTiledRenderer.consumeTilesInThreads( ...
                    renderPlan, options, outputGrid, tiles, tileConsumer, ...
                    measureConsumer);
                return
            end
            tileReports = ProjectionBackendTiledRenderer.emptyTileReports();
            peakInFlightTiles = min(1, numel(tiles));
            for tileIndex = 1:numel(tiles)
                tile = tiles(tileIndex);
                [tileReadback, report] = ...
                    ProjectionBackendTiledRenderer.renderTile( ...
                    renderPlan, options, outputGrid, tile);
                report.TileIndex = tileIndex;
                report.CompletionOrdinal = tileIndex;
                report = ProjectionBackendTiledRenderer.consumeTile( ...
                    tileConsumer, tile, tileReadback, report, measureConsumer);
                tileReports(tileIndex) = report;
            end
        end

        function [tileReports, peakInFlightTiles] = consumeTilesInThreads( ...
                renderPlan, options, outputGrid, tiles, tileConsumer, ...
                measureConsumer)
            pool = ProjectionBackendTiledRenderer.ensureThreadPool();
            maximumInFlight = min(options.MaximumInFlightTiles, numel(tiles));
            futures = parallel.FevalFuture.empty;
            nextTileIndex = 1;
            completionOrdinal = 0;
            peakInFlightTiles = 0;
            tileReports = ProjectionBackendTiledRenderer.emptyTileReports();
            try
                while nextTileIndex <= numel(tiles) || ~isempty(futures)
                    while nextTileIndex <= numel(tiles) && ...
                            numel(futures) < maximumInFlight
                        tile = tiles(nextTileIndex);
                        futures(end + 1) = parfeval(pool, ...
                            @ProjectionBackendTiledRenderer.renderTileTask, 1, ...
                            renderPlan, options, outputGrid, tile, ...
                            nextTileIndex); %#ok<AGROW>
                        nextTileIndex = nextTileIndex + 1;
                    end
                    peakInFlightTiles = max( ...
                        peakInFlightTiles, numel(futures));
                    [completedIndex, tileResult] = fetchNext(futures);
                    futures(completedIndex) = [];
                    if ~tileResult.Succeeded
                        ProjectionBackendTiledRenderer.cancelFutures(futures);
                        error("ProjectionBackendTiledRenderer:tileFailed", ...
                            "Tile %d rows [%d %d] columns [%d %d] failed (%s): %s", ...
                            tileResult.TileIndex, ...
                            tileResult.Tile.RowRange([1 end]), ...
                            tileResult.Tile.ColumnRange([1 end]), ...
                            tileResult.ErrorIdentifier, tileResult.ErrorMessage);
                    end
                    completionOrdinal = completionOrdinal + 1;
                    report = tileResult.Report;
                    report.TileIndex = tileResult.TileIndex;
                    report.CompletionOrdinal = completionOrdinal;
                    report = ProjectionBackendTiledRenderer.consumeTile( ...
                        tileConsumer, tileResult.Tile, tileResult.Readback, ...
                        report, measureConsumer);
                    tileReports(tileResult.TileIndex) = report;
                end
            catch exception
                ProjectionBackendTiledRenderer.cancelFutures(futures);
                rethrow(exception)
            end
        end

        function result = renderTileTask( ...
                renderPlan, options, outputGrid, tile, tileIndex)
            result = struct(TileIndex=tileIndex, Tile=tile, ...
                Succeeded=false, Readback=[], Report=[], ...
                ErrorIdentifier="", ErrorMessage="");
            try
                [result.Readback, result.Report] = ...
                    ProjectionBackendTiledRenderer.renderTile( ...
                    renderPlan, options, outputGrid, tile);
                result.Succeeded = true;
            catch exception
                result.ErrorIdentifier = string(exception.identifier);
                result.ErrorMessage = string(exception.message);
            end
        end

        function report = consumeTile( ...
                tileConsumer, tile, tileReadback, report, measureConsumer)
            if measureConsumer
                writeTimer = tic;
                tileConsumer(tile, tileReadback);
                report.WriteSeconds = toc(writeTimer);
            else
                tileConsumer(tile, tileReadback);
            end
        end

        function cancelFutures(futures)
            if ~isempty(futures)
                cancel(futures);
            end
        end

        function pool = ensureThreadPool()
            pool = gcp("nocreate");
            if isempty(pool)
                pool = parpool("threads");
                return
            end
            if ~ProjectionBackendTiledRenderer.isThreadPool(pool)
                error("ProjectionBackendTiledRenderer:processPoolActive", ...
                    "Execution.Mode=""threads"" requires a thread pool. Delete the active process-based pool or use Execution.Mode=""serial"".");
            end
        end

        function tf = isThreadPool(pool)
            tf = contains(string(class(pool)), "ThreadPool");
        end

        function [tileReadback, report] = renderTile( ...
                renderPlan, options, outputGrid, tile)
            tileOptions = options;
            tileOptions.OutputGrid = ProjectionBackendTiledRenderer.tileOutputGrid( ...
                outputGrid, tile.RowRange, tile.ColumnRange);
            tileOptions.OutputSize = tileOptions.OutputGrid.OutputSize;

            tileTimer = tic;
            tileReadback = ProjectionReadbackRenderer.renderPlan( ...
                renderPlan, tileOptions.OutputGrid);
            renderSeconds = toc(tileTimer);
            report = ProjectionBackendTiledRenderer.tileReport( ...
                tile, tileReadback, renderSeconds);
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
                tileLayerReadbacks, outputSize, includeQueryCoordinates)
            template = struct(Image=[], ValidMask=[], LayerIndex=[], ...
                QueryPlaneCoordinates=[], Mesh=[]);
            layerReadbacks = repmat(template, 1, numel(tileLayerReadbacks));
            for k = 1:numel(tileLayerReadbacks)
                layerReadbacks(k).Image = ...
                    ProjectionBackendTiledRenderer.allocateImage( ...
                    outputSize, tileLayerReadbacks(k).Image);
                layerReadbacks(k).ValidMask = false(outputSize);
                layerReadbacks(k).LayerIndex = tileLayerReadbacks(k).LayerIndex;
                if includeQueryCoordinates
                    layerReadbacks(k).QueryPlaneCoordinates = ...
                        zeros([2 outputSize]);
                end
                layerReadbacks(k).Mesh = tileLayerReadbacks(k).Mesh;
            end
        end

        function layerReadbacks = assignLayerTiles(layerReadbacks, ...
                tileLayerReadbacks, rowRange, columnRange, ...
                includeQueryCoordinates)
            for k = 1:numel(layerReadbacks)
                layerReadbacks(k).Image = ...
                    ProjectionBackendTiledRenderer.assignImageTile( ...
                    layerReadbacks(k).Image, rowRange, columnRange, ...
                    tileLayerReadbacks(k).Image);
                layerReadbacks(k).ValidMask(rowRange, columnRange) = ...
                    tileLayerReadbacks(k).ValidMask;
                if includeQueryCoordinates
                    layerReadbacks(k).QueryPlaneCoordinates( ...
                        :, rowRange, columnRange) = reshape( ...
                        tileLayerReadbacks(k).QueryPlaneCoordinates, ...
                        [2 numel(rowRange) numel(columnRange)]);
                end
            end
        end

        function layerReadbacks = flattenQueryCoordinates(layerReadbacks)
            for k = 1:numel(layerReadbacks)
                if ~isempty(layerReadbacks(k).QueryPlaneCoordinates)
                    layerReadbacks(k).QueryPlaneCoordinates = reshape( ...
                        layerReadbacks(k).QueryPlaneCoordinates, 2, []);
                end
            end
        end

        function reports = emptyTileReports()
            reports = struct(TileIndex={}, CompletionOrdinal={}, ...
                RowRange={}, ColumnRange={}, OutputSize={}, ...
                PixelCount={}, RenderSeconds={}, WriteSeconds={}, ...
                EstimatedMemoryBytes={});
        end

        function report = tileReport(tile, tileReadback, renderSeconds)
            tileInfo = whos("tileReadback");
            report = struct();
            report.TileIndex = [];
            report.CompletionOrdinal = [];
            report.RowRange = [tile.RowRange(1), tile.RowRange(end)];
            report.ColumnRange = [tile.ColumnRange(1), tile.ColumnRange(end)];
            report.OutputSize = tileReadback.OutputSize;
            report.PixelCount = prod(tileReadback.OutputSize);
            report.RenderSeconds = renderSeconds;
            report.WriteSeconds = 0;
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

        function value = validatePositiveInteger(value, name)
            if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value) || ...
                    value < 1 || fix(value) ~= value
                error("ProjectionBackendTiledRenderer:invalidOptions", ...
                    "%s must be a finite positive integer.", name);
            end
            value = double(value);
        end

        function mode = validateExecutionMode(mode)
            mode = lower(string(mode));
            if ~isscalar(mode) || ~ismember(mode, ["serial", "threads"])
                error("ProjectionBackendTiledRenderer:invalidOptions", ...
                    "Execution mode must be serial or threads.");
            end
        end

        function value = fieldOrDefault(value, fieldName, defaultValue)
            if isstruct(value) && isscalar(value) && isfield(value, fieldName)
                value = value.(fieldName);
            else
                value = defaultValue;
            end
        end

        function validatePlanOptions(renderPlan, options)
            if ~isequal(double(renderPlan.OutputSize), ...
                    double(options.OutputGrid.OutputSize)) || ...
                    renderPlan.Interpolation ~= lower(string(options.Interpolation)) || ...
                    lower(string(renderPlan.NumericalMode)) ~= ...
                    lower(string(options.NumericalMode)) || ...
                    renderPlan.IncludeLayerReadbacks ~= ...
                    logical(options.IncludeLayerReadbacks) || ...
                    renderPlan.IncludeQueryCoordinates ~= ...
                    logical(options.IncludeQueryCoordinates)
                error("ProjectionBackendTiledRenderer:planMismatch", ...
                    "Render plan does not match tiled output or interpolation options.");
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
