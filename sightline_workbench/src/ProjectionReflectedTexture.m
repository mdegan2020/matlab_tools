classdef ProjectionReflectedTexture
    %ProjectionReflectedTexture Sample an image through continuous mirror addressing.

    methods (Static)
        function [mappedRows, mappedColumns] = mapCoordinates( ...
                imageSize, rowCoordinates, columnCoordinates)
            %mapCoordinates Map logical reflected coordinates into one source tile.
            imageSize = ProjectionReflectedTexture.validateImageSize(imageSize);
            [rowCoordinates, columnCoordinates] = ...
                ProjectionReflectedTexture.validateCoordinates( ...
                rowCoordinates, columnCoordinates);
            mappedRows = ProjectionReflectedTexture.mapAxis( ...
                rowCoordinates, imageSize(1));
            mappedColumns = ProjectionReflectedTexture.mapAxis( ...
                columnCoordinates, imageSize(2));
        end

        function values = sample(image, rowCoordinates, columnCoordinates, method)
            %sample Interpolate arbitrary-band source radiometry after reflection.
            if nargin < 4
                method = "linear";
            end
            ProjectionReflectedTexture.validateImage(image);
            method = lower(string(method));
            if ~isscalar(method) || ~ismember(method, ["linear" "nearest"])
                error("ProjectionReflectedTexture:invalidMethod", ...
                    "Interpolation method must be linear or nearest.");
            end
            [mappedRows, mappedColumns] = ...
                ProjectionReflectedTexture.mapCoordinates( ...
                [size(image, 1) size(image, 2)], ...
                rowCoordinates, columnCoordinates);
            querySize = size(mappedRows);
            bandCount = size(image, 3);
            values = zeros([querySize bandCount]);
            for bandIndex = 1:bandCount
                band = double(image(:, :, bandIndex));
                values(:, :, bandIndex) = interp2(band, mappedColumns, ...
                    mappedRows, char(method));
            end
            if bandCount == 1
                values = reshape(values, querySize);
            end
        end
    end

    methods (Static, Access = private)
        function mapped = mapAxis(coordinates, lengthValue)
            period = 2 * (lengthValue - 1);
            phase = mod(coordinates - 1, period);
            mapped = 1 + (lengthValue - 1) - abs(phase - (lengthValue - 1));
        end

        function imageSize = validateImageSize(imageSize)
            if ~isnumeric(imageSize) || ~isvector(imageSize) || ...
                    numel(imageSize) < 2 || any(~isfinite(imageSize(1:2))) || ...
                    any(imageSize(1:2) < 2) || ...
                    any(fix(imageSize(1:2)) ~= imageSize(1:2))
                error("ProjectionReflectedTexture:invalidImageSize", ...
                    "Image size must describe at least a 2-by-2 source tile.");
            end
            imageSize = double(imageSize(1:2));
        end

        function [rows, columns] = validateCoordinates(rows, columns)
            if ~isnumeric(rows) || ~isnumeric(columns) || isempty(rows) || ...
                    isempty(columns) || any(~isfinite(rows), "all") || ...
                    any(~isfinite(columns), "all")
                error("ProjectionReflectedTexture:invalidCoordinates", ...
                    "Texture coordinates must be nonempty finite numeric arrays.");
            end
            rows = double(rows);
            columns = double(columns);
            if isscalar(rows)
                rows = repmat(rows, size(columns));
            elseif isscalar(columns)
                columns = repmat(columns, size(rows));
            elseif ~isequal(size(rows), size(columns))
                error("ProjectionReflectedTexture:invalidCoordinates", ...
                    "Row and column coordinates must have equal sizes or be scalar.");
            end
        end

        function validateImage(image)
            if ~(isnumeric(image) || islogical(image)) || isempty(image) || ...
                    size(image, 1) < 2 || size(image, 2) < 2 || ...
                    ndims(image) > 3 || any(~isfinite(double(image)), "all")
                error("ProjectionReflectedTexture:invalidImage", ...
                    "Source texture must be a finite 2-D or 3-D numeric image.");
            end
        end
    end
end
