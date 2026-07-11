classdef ProjectionBackendSourceProvider
    %ProjectionBackendSourceProvider Runtime source-region access for backend tiles.

    methods (Static)
        function provider = fromLayer(layer)
            if isfield(layer, "BackendSource") && ...
                    ~isempty(layer.BackendSource)
                descriptor = layer.BackendSource;
                kind = lower(string(descriptor.Kind));
                if ~isscalar(kind) || kind ~= "tiff"
                    error("ProjectionBackendSourceProvider:unsupportedKind", ...
                        "BackendSource.Kind must be tiff.");
                end
                path = string(descriptor.Path);
                if ~isfile(path)
                    error("ProjectionBackendSourceProvider:fileNotFound", ...
                        "Backend TIFF source does not exist: %s", path);
                end
                info = imfinfo(path);
                imageSize = [info(1).Height info(1).Width];
                sample = imread(path, PixelRegion={[1 1], [1 1]});
                provider = struct(Kind="tiff", Path=path, Image=[], ...
                    ImageSize=imageSize, BandCount=size(sample, 3), ...
                    SourceClass=string(class(sample)), RuntimeOnly=true);
            else
                image = layer.Image;
                provider = struct(Kind="memory", Path="", Image=image, ...
                    ImageSize=[size(image, 1) size(image, 2)], ...
                    BandCount=size(image, 3), ...
                    SourceClass=string(class(image)), RuntimeOnly=true);
            end
            if ~isequal(double(provider.ImageSize), ...
                    double(layer.SourceGeometry.ImageSize(1:2)))
                error("ProjectionBackendSourceProvider:sizeMismatch", ...
                    "Backend source size must match SourceGeometry.ImageSize.");
            end
            ProjectionBackendSourceProvider.validate(provider);
        end

        function provider = validate(provider)
            required = ["Kind", "Path", "Image", "ImageSize", ...
                "BandCount", "SourceClass", "RuntimeOnly"];
            if ~isstruct(provider) || ~isscalar(provider) || ...
                    any(~isfield(provider, required)) || ...
                    ~isscalar(string(provider.Kind)) || ...
                    ~ismember(string(provider.Kind), ["memory", "tiff"])
                error("ProjectionBackendSourceProvider:invalidProvider", ...
                    "Source provider is invalid.");
            end
            if ~isnumeric(provider.ImageSize) || ...
                    ~isequal(size(provider.ImageSize), [1 2]) || ...
                    any(provider.ImageSize < 1)
                error("ProjectionBackendSourceProvider:invalidProvider", ...
                    "Source provider ImageSize must be a positive 1x2 vector.");
            end
        end

        function [imageData, regionalMapping, region] = readForMapping( ...
                provider, mapping)
            provider = ProjectionBackendSourceProvider.validate(provider);
            validRows = mapping.RowCoordinates(mapping.ValidMask);
            validColumns = mapping.ColumnCoordinates(mapping.ValidMask);
            if isempty(validRows)
                rowRange = [1 1];
                columnRange = [1 1];
            else
                rowRange = [floor(min(validRows)) ceil(max(validRows))];
                columnRange = [floor(min(validColumns)) ceil(max(validColumns))];
                rowRange = min(max(rowRange, 1), provider.ImageSize(1));
                columnRange = min(max(columnRange, 1), provider.ImageSize(2));
            end
            rows = rowRange(1):rowRange(2);
            columns = columnRange(1):columnRange(2);
            if provider.Kind == "memory"
                imageData = provider.Image(rows, columns, :);
            else
                imageData = imread(provider.Path, ...
                    PixelRegion={rowRange, columnRange});
            end
            regionalMapping = mapping;
            regionalMapping.ImageSize = [numel(rows) numel(columns)];
            regionalMapping.RowCoordinates = mapping.RowCoordinates - ...
                rowRange(1) + 1;
            regionalMapping.ColumnCoordinates = mapping.ColumnCoordinates - ...
                columnRange(1) + 1;
            region = struct(RowRange=rowRange, ColumnRange=columnRange, ...
                PixelCount=numel(rows) * numel(columns), Kind=provider.Kind);
        end

        function summary = summary(provider)
            provider = ProjectionBackendSourceProvider.validate(provider);
            summary = rmfield(provider, "Image");
        end
    end
end
