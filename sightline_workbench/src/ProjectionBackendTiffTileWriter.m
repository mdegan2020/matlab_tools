classdef ProjectionBackendTiffTileWriter < handle
    %ProjectionBackendTiffTileWriter Incremental tiled TIFF product writer.

    properties (Access = private)
        Output
        SceneLayers
        LayerIndices
        OutputSize
        TileSize
        OutputDirectory
        TiffObjects = {}
        TemporaryPaths = strings(1, 0)
        FinalPaths = strings(1, 0)
        CommittedPaths = strings(1, 0)
        CompositeImageSink = []
        CompositeMaskSink = []
        LayerImageSinks = []
        LayerMaskSinks = []
        Completed = false
    end

    methods
        function obj = ProjectionBackendTiffTileWriter( ...
                output, sceneLayers, layerIndices, outputSize, tileSize)
            obj.Output = output;
            obj.SceneLayers = sceneLayers;
            obj.LayerIndices = double(layerIndices(:).');
            obj.OutputSize = double(outputSize(:).');
            obj.TileSize = double(tileSize(:).');
            if any(mod(obj.TileSize, 16) ~= 0)
                error("ProjectionBackendTiffTileWriter:invalidTileSize", ...
                    "Streaming TIFF tile dimensions must be multiples of 16.");
            end
            formats = reshape(lower(string(output.Formats)), 1, []);
            if ~isequal(formats, "tiff")
                error("ProjectionBackendTiffTileWriter:unsupportedFormat", ...
                    "Bounded streaming currently supports TIFF-only output.");
            end
            obj.OutputDirectory = string(output.Directory);
            if ~isfolder(obj.OutputDirectory)
                mkdir(obj.OutputDirectory);
            end
            obj.LayerImageSinks = zeros(1, numel(obj.LayerIndices));
            obj.LayerMaskSinks = zeros(1, numel(obj.LayerIndices));
        end

        function writeTile(obj, tile, tileReadback)
            %writeTile Write one renderer tile to every requested product.
            if obj.Completed
                error("ProjectionBackendTiffTileWriter:alreadyCompleted", ...
                    "Cannot write after TIFF products have been finalized.");
            end
            if obj.Output.IncludeComposite
                composite = obj.prepareImageTile(tileReadback.Image);
                mask = obj.prepareMaskTile(tileReadback.ValidMask);
                if isempty(obj.CompositeImageSink)
                    obj.CompositeImageSink = obj.openSink( ...
                        "composite.tif", obj.bandCount(composite));
                    obj.CompositeMaskSink = obj.openSink( ...
                        "composite_mask.tif", 1);
                end
                obj.writeSink(obj.CompositeImageSink, tile, composite);
                obj.writeSink(obj.CompositeMaskSink, tile, mask);
            end

            if obj.Output.IncludeLayers
                if numel(tileReadback.LayerReadbacks) ~= numel(obj.LayerIndices)
                    error("ProjectionBackendTiffTileWriter:layerMismatch", ...
                        "Tile layer readbacks do not match the render plan.");
                end
                for outputIndex = 1:numel(obj.LayerIndices)
                    layerReadback = tileReadback.LayerReadbacks(outputIndex);
                    layerIndex = obj.LayerIndices(outputIndex);
                    if layerReadback.LayerIndex ~= layerIndex
                        error("ProjectionBackendTiffTileWriter:layerMismatch", ...
                            "Tile layer order does not match the render plan.");
                    end
                    imageTile = obj.prepareImageTile(layerReadback.Image);
                    maskTile = obj.prepareMaskTile(layerReadback.ValidMask);
                    if obj.LayerImageSinks(outputIndex) == 0
                        baseName = obj.layerBaseName( ...
                            layerIndex, obj.SceneLayers(layerIndex));
                        obj.LayerImageSinks(outputIndex) = obj.openSink( ...
                            baseName + ".tif", obj.bandCount(imageTile));
                        obj.LayerMaskSinks(outputIndex) = obj.openSink( ...
                            baseName + "_mask.tif", 1);
                    end
                    obj.writeSink(obj.LayerImageSinks(outputIndex), ...
                        tile, imageTile);
                    obj.writeSink(obj.LayerMaskSinks(outputIndex), ...
                        tile, maskTile);
                end
            end
        end

        function outputFiles = finalize(obj)
            %finalize Close temporary TIFFs and atomically publish each file.
            if obj.Completed
                error("ProjectionBackendTiffTileWriter:alreadyCompleted", ...
                    "TIFF products have already been finalized.");
            end
            obj.closeAll();
            try
                for pathIndex = 1:numel(obj.TemporaryPaths)
                    finalPath = obj.FinalPaths(pathIndex);
                    if isfile(finalPath)
                        delete(finalPath);
                    end
                    [moved, message] = movefile( ...
                        obj.TemporaryPaths(pathIndex), finalPath);
                    if ~moved
                        error("ProjectionBackendTiffTileWriter:publishFailed", ...
                            "Unable to publish %s: %s", finalPath, message);
                    end
                    obj.CommittedPaths(end + 1) = finalPath;
                end
                obj.Completed = true;
                outputFiles = obj.outputFiles();
            catch exception
                obj.abort();
                rethrow(exception)
            end
        end

        function abort(obj)
            %abort Close open TIFFs and remove incomplete products.
            if obj.Completed
                return
            end
            obj.closeAll();
            obj.deletePaths(obj.TemporaryPaths);
            obj.deletePaths(obj.CommittedPaths);
            obj.CommittedPaths = strings(1, 0);
        end

        function delete(obj)
            obj.abort();
        end
    end

    methods (Access = private)
        function sinkIndex = openSink(obj, fileName, bandCount)
            finalPath = string(fullfile(obj.OutputDirectory, fileName));
            temporaryPath = finalPath + ".partial";
            if isfile(temporaryPath)
                delete(temporaryPath);
            end
            tiffObject = Tiff(char(temporaryPath), "w");
            tags = struct();
            tags.ImageLength = obj.OutputSize(1);
            tags.ImageWidth = obj.OutputSize(2);
            tags.TileLength = obj.TileSize(1);
            tags.TileWidth = obj.TileSize(2);
            tags.BitsPerSample = 8;
            tags.SamplesPerPixel = bandCount;
            tags.SampleFormat = Tiff.SampleFormat.UInt;
            tags.PlanarConfiguration = Tiff.PlanarConfiguration.Chunky;
            tags.Compression = Tiff.Compression.None;
            if bandCount == 3
                tags.Photometric = Tiff.Photometric.RGB;
            else
                tags.Photometric = Tiff.Photometric.MinIsBlack;
                if bandCount > 1
                    tags.ExtraSamples = repmat( ...
                        Tiff.ExtraSamples.Unspecified, 1, bandCount - 1);
                end
            end
            tags.Software = "Sightline Workbench";
            try
                setTag(tiffObject, tags);
            catch exception
                close(tiffObject);
                if isfile(temporaryPath)
                    delete(temporaryPath);
                end
                rethrow(exception)
            end

            obj.TiffObjects{end + 1} = tiffObject;
            obj.TemporaryPaths(end + 1) = temporaryPath;
            obj.FinalPaths(end + 1) = finalPath;
            sinkIndex = numel(obj.TiffObjects);
        end

        function writeSink(obj, sinkIndex, tile, imageTile)
            tiffObject = obj.TiffObjects{sinkIndex};
            paddedTile = obj.paddedTile(imageTile);
            tileNumber = computeTile(tiffObject, ...
                [tile.RowRange(1), tile.ColumnRange(1)]);
            writeEncodedTile(tiffObject, tileNumber, paddedTile);
        end

        function padded = paddedTile(obj, imageTile)
            bandCount = obj.bandCount(imageTile);
            if bandCount == 1
                padded = zeros(obj.TileSize, "uint8");
                padded(1:size(imageTile, 1), 1:size(imageTile, 2)) = imageTile;
            else
                padded = zeros([obj.TileSize bandCount], "uint8");
                padded(1:size(imageTile, 1), 1:size(imageTile, 2), :) = ...
                    imageTile;
            end
        end

        function imageTile = prepareImageTile(~, imageTile)
            imageTile = double(imageTile);
            imageTile(~isfinite(imageTile)) = 0;
            if any(imageTile < 0 | imageTile > 1, "all")
                error("ProjectionBackendTiffTileWriter:radiometryOutOfRange", ...
                    "Streaming currently requires normalized [0,1] radiometry; use in-memory output until Pack 4 defines scaling policy.");
            end
            imageTile = uint8(round(255 * imageTile));
        end

        function maskTile = prepareMaskTile(~, maskTile)
            maskTile = uint8(logical(maskTile)) * 255;
        end

        function count = bandCount(~, imageData)
            if ismatrix(imageData)
                count = 1;
            else
                count = size(imageData, 3);
            end
        end

        function closeAll(obj)
            for sinkIndex = 1:numel(obj.TiffObjects)
                tiffObject = obj.TiffObjects{sinkIndex};
                if ~isempty(tiffObject)
                    try
                        close(tiffObject);
                    catch
                    end
                end
            end
            obj.TiffObjects = {};
        end

        function outputFiles = outputFiles(obj)
            outputFiles = struct(Directory=obj.OutputDirectory, ...
                Composite=struct([]), CompositeMask="", Layers=struct([]), ...
                Metadata="", AlignmentDiagnostics="", AlignedViewerState="");
            if obj.Output.IncludeComposite
                outputFiles.Composite = struct(Format="tiff", ...
                    Path=string(fullfile(obj.OutputDirectory, "composite.tif")));
                outputFiles.CompositeMask = string(fullfile( ...
                    obj.OutputDirectory, "composite_mask.tif"));
            end
            if obj.Output.IncludeLayers
                layers = struct([]);
                for outputIndex = 1:numel(obj.LayerIndices)
                    layerIndex = obj.LayerIndices(outputIndex);
                    baseName = obj.layerBaseName( ...
                        layerIndex, obj.SceneLayers(layerIndex));
                    layers(outputIndex).LayerIndex = layerIndex;
                    layers(outputIndex).ImageFiles = struct( ...
                        Format="tiff", Path=string(fullfile( ...
                        obj.OutputDirectory, baseName + ".tif")));
                    layers(outputIndex).MaskPath = string(fullfile( ...
                        obj.OutputDirectory, baseName + "_mask.tif"));
                end
                outputFiles.Layers = layers;
            end
        end

        function baseName = layerBaseName(~, layerIndex, layer)
            layerName = "";
            if isfield(layer, "Name")
                layerName = string(layer.Name);
            end
            safeName = lower(layerName);
            safeName = regexprep(safeName, "[^a-z0-9]+", "_");
            safeName = regexprep(safeName, "^_+|_+$", "");
            if strlength(safeName) == 0
                safeName = "unnamed";
            end
            baseName = string(sprintf( ...
                "layer_%03d_%s", layerIndex, safeName));
        end

        function deletePaths(~, paths)
            for pathIndex = 1:numel(paths)
                if isfile(paths(pathIndex))
                    delete(paths(pathIndex));
                end
            end
        end
    end
end
