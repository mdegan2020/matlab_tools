classdef ProjectionBackendOutputWriter
    %ProjectionBackendOutputWriter Write backend render products and metadata.

    properties (Constant)
        MetadataFormat = "ProjectionBackendMetadata"
        MetadataVersion = 1
    end

    methods (Static)
        function outputFiles = write(result)
            %write Write composite, per-layer images, masks, and metadata.
            output = result.Output;
            outputDirectory = ProjectionBackendOutputWriter.prepareOutputDirectory( ...
                output.Directory);
            formats = reshape(string(output.Formats), 1, []);

            outputFiles = struct();
            outputFiles.Directory = outputDirectory;
            outputFiles.Composite = struct([]);
            outputFiles.CompositeMask = "";
            outputFiles.Layers = struct([]);
            outputFiles.Metadata = "";

            if output.IncludeComposite
                outputFiles.Composite = ProjectionBackendOutputWriter.writeImageFormats( ...
                    result.Readback.Image, outputDirectory, "composite", formats);
                outputFiles.CompositeMask = ProjectionBackendOutputWriter.writeMask( ...
                    result.Readback.ValidMask, outputDirectory, "composite_mask");
            end

            if output.IncludeLayers
                outputFiles.Layers = ProjectionBackendOutputWriter.writeLayerOutputs( ...
                    result.Readback.LayerReadbacks, result.Scene.layers, ...
                    outputDirectory, formats);
            end

            outputFiles.Metadata = string(fullfile(outputDirectory, "metadata.json"));
            ProjectionBackendOutputWriter.writeMetadata( ...
                result, outputFiles, outputFiles.Metadata);
        end
    end

    methods (Static, Access = private)
        function outputDirectory = prepareOutputDirectory(outputDirectory)
            outputDirectory = string(outputDirectory);
            if strlength(outputDirectory) == 0
                error("ProjectionBackendOutputWriter:invalidOutputDirectory", ...
                    "Output.Directory must be nonempty when writing backend outputs.");
            end
            if ~isfolder(outputDirectory)
                mkdir(outputDirectory);
            end
        end

        function files = writeImageFormats(imageData, outputDirectory, baseName, formats)
            files = struct([]);
            for formatIndex = 1:numel(formats)
                format = formats(formatIndex);
                filePath = fullfile(outputDirectory, baseName + ...
                    ProjectionBackendOutputWriter.extension(format));
                ProjectionBackendOutputWriter.writeImage(imageData, filePath, format);
                files(formatIndex).Format = format;
                files(formatIndex).Path = string(filePath);
            end
        end

        function maskPath = writeMask(mask, outputDirectory, baseName)
            maskPath = string(fullfile(outputDirectory, baseName + ".png"));
            imwrite(logical(mask), maskPath);
        end

        function layers = writeLayerOutputs(layerReadbacks, sceneLayers, ...
                outputDirectory, formats)
            layers = struct([]);
            for outputIndex = 1:numel(layerReadbacks)
                layerIndex = layerReadbacks(outputIndex).LayerIndex;
                baseName = ProjectionBackendOutputWriter.layerBaseName( ...
                    layerIndex, sceneLayers(layerIndex));
                layers(outputIndex).LayerIndex = layerIndex;
                layers(outputIndex).ImageFiles = ...
                    ProjectionBackendOutputWriter.writeImageFormats( ...
                    layerReadbacks(outputIndex).Image, outputDirectory, ...
                    baseName, formats);
                layers(outputIndex).MaskPath = ProjectionBackendOutputWriter.writeMask( ...
                    layerReadbacks(outputIndex).ValidMask, outputDirectory, ...
                    baseName + "_mask");
            end
        end

        function writeMetadata(result, outputFiles, metadataPath)
            metadata = ProjectionBackendOutputWriter.metadata(result, outputFiles);
            jsonText = jsonencode(metadata, PrettyPrint=true);
            fid = fopen(metadataPath, "w");
            if fid < 0
                error("ProjectionBackendOutputWriter:fileOpenFailed", ...
                    "Unable to open metadata file for writing: %s", metadataPath);
            end
            cleaner = onCleanup(@() fclose(fid));
            fprintf(fid, "%s\n", jsonText);
            clear cleaner
        end

        function metadata = metadata(result, outputFiles)
            metadata = struct();
            metadata.Format = ProjectionBackendOutputWriter.MetadataFormat;
            metadata.Version = ProjectionBackendOutputWriter.MetadataVersion;
            metadata.Status = result.Status;
            metadata.LayerIndices = result.Readback.LayerIndices;
            metadata.RenderOptions = result.RenderOptions;
            metadata.Output = result.Output;
            metadata.Execution = result.Execution;
            metadata.OutputGrid = ProjectionBackendOutputWriter.metadataGrid( ...
                result.OutputGrid);
            metadata.GpuInfo = result.GpuInfo;
            metadata.OutputFiles = outputFiles;
            metadata.Timing = result.Timing;
            if ~isempty(result.ViewerState)
                metadata.ViewerStateSummary = ...
                    ProjectionBackendOutputWriter.viewerStateSummary(result.ViewerState);
            else
                metadata.ViewerStateSummary = [];
            end
        end

        function grid = metadataGrid(outputGrid)
            grid = struct();
            grid.Format = outputGrid.Format;
            grid.Version = outputGrid.Version;
            grid.LayerIndices = outputGrid.LayerIndices;
            grid.TwistDegrees = outputGrid.TwistDegrees;
            grid.Bounds = outputGrid.Bounds;
            grid.OutputSize = outputGrid.OutputSize;
            grid.ResolutionMetersPerPixel = outputGrid.ResolutionMetersPerPixel;
            grid.PixelSpacingMeters = outputGrid.PixelSpacingMeters;
            grid.PixelCount = outputGrid.PixelCount;
        end

        function summary = viewerStateSummary(viewerState)
            summary = struct();
            summary.Format = string(viewerState.Format);
            summary.Version = viewerState.Version;
            summary.LayerCount = viewerState.LayerCount;
            summary.SelectedLayerIndex = viewerState.SelectedLayerIndex;
            summary.TipDegrees = viewerState.Projection.TipDegrees;
            summary.TiltDegrees = viewerState.Projection.TiltDegrees;
            summary.TwistDegrees = viewerState.View.TwistDegrees;
        end

        function writeImage(imageData, filePath, format)
            imageData = ProjectionBackendOutputWriter.prepareImageForWrite(imageData);
            switch format
                case "png"
                    imwrite(imageData, filePath);
                case "tiff"
                    imwrite(imageData, filePath, "tif");
                otherwise
                    error("ProjectionBackendOutputWriter:unsupportedFormat", ...
                        "Unsupported output format %s.", format);
            end
        end

        function imageData = prepareImageForWrite(imageData)
            imageData = double(imageData);
            imageData(~isfinite(imageData)) = 0;
            minValue = min(imageData, [], "all");
            maxValue = max(imageData, [], "all");
            if minValue < 0 || maxValue > 1
                if maxValue > minValue
                    imageData = (imageData - minValue) / (maxValue - minValue);
                else
                    imageData = zeros(size(imageData));
                end
            end
            imageData = min(max(imageData, 0), 1);
        end

        function extension = extension(format)
            switch format
                case "png"
                    extension = ".png";
                case "tiff"
                    extension = ".tif";
                otherwise
                    error("ProjectionBackendOutputWriter:unsupportedFormat", ...
                        "Unsupported output format %s.", format);
            end
        end

        function baseName = layerBaseName(layerIndex, layer)
            layerName = string(ProjectionBackendOutputWriter.fieldOrDefault( ...
                layer, "Name", ""));
            safeName = ProjectionBackendOutputWriter.safeName(layerName);
            baseName = sprintf("layer_%03d_%s", layerIndex, safeName);
        end

        function safeName = safeName(name)
            name = lower(string(name));
            if strlength(name) == 0
                safeName = "unnamed";
                return
            end
            safeName = regexprep(name, "[^a-z0-9]+", "_");
            safeName = regexprep(safeName, "^_+|_+$", "");
            if strlength(safeName) == 0
                safeName = "unnamed";
            end
        end

        function value = fieldOrDefault(value, fieldName, defaultValue)
            if isfield(value, fieldName)
                value = value.(fieldName);
            else
                value = defaultValue;
            end
        end
    end
end
