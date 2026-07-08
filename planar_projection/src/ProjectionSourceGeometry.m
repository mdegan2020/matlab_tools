classdef ProjectionSourceGeometry
    %ProjectionSourceGeometry Source-geometry adapters for projection layers.

    methods (Static)
        function sourceGeometry = fromGrid(imageSize, rowPostIndices, ...
                columnPostIndices, origins, viewVectors, options)
            %fromGrid Build a SampleFcn-backed source geometry from sparse posts.
            if nargin < 6
                options = struct();
            end

            options = ProjectionSourceGeometry.mergeOptions(options);
            imageSize = ProjectionSourceGeometry.validateImageSize(imageSize);
            rowPostIndices = ProjectionSourceGeometry.validatePostIndices( ...
                rowPostIndices, imageSize(1), "rowPostIndices");
            columnPostIndices = ProjectionSourceGeometry.validatePostIndices( ...
                columnPostIndices, imageSize(2), "columnPostIndices");
            origins = ProjectionSourceGeometry.validateOrigins( ...
                origins, numel(columnPostIndices));
            viewVectors = ProjectionSourceGeometry.validateViewVectors( ...
                viewVectors, numel(rowPostIndices), numel(columnPostIndices));

            geometryData = struct();
            geometryData.ImageSize = imageSize;
            geometryData.CoordinateFrame = string(options.CoordinateFrame);
            geometryData.InterpolationMethod = string(options.InterpolationMethod);
            geometryData.RowPostIndices = rowPostIndices;
            geometryData.ColumnPostIndices = columnPostIndices;
            geometryData.Origins = origins;
            geometryData.GridViewVectors = viewVectors;
            geometryData.ViewVectors = viewVectors;
            geometryData.ReferenceOrigin = ProjectionSourceGeometry.referenceOrigin( ...
                geometryData, options);
            geometryData.OpticalAxis = ProjectionSourceGeometry.opticalAxis( ...
                geometryData, options);
            geometryData.PlatformDirection = ProjectionSourceGeometry.platformDirection( ...
                geometryData, options);
            geometryData.RowAxis = ProjectionSourceGeometry.rowAxis( ...
                geometryData, options);
            geometryData.ImageXAxis = ProjectionSourceGeometry.imageXAxis( ...
                geometryData, options);
            geometryData.ImageYAxis = ProjectionSourceGeometry.imageYAxis( ...
                geometryData, options);
            geometryData.Attitudes = [];
            geometryData.WorldVectors = [];
            geometryData.Metadata = ProjectionSourceGeometry.metadata( ...
                geometryData, options);

            geometryData = ProjectionSourceGeometry.addOptionalScalars( ...
                geometryData, options);
            geometryData = ProjectionSourceGeometry.addIfov(geometryData, options);

            sourceGeometry = geometryData;
            sourceGeometry.SampleFcn = @(rowIndices, columnIndices) ...
                ProjectionSourceGeometry.sampleGridGeometry( ...
                geometryData, rowIndices, columnIndices);
            sourceGeometry.SampleRayFcn = @(rowPositions, columnPositions) ...
                ProjectionSourceGeometry.sampleGridRays( ...
                geometryData, rowPositions, columnPositions);
        end
    end

    methods (Static, Access = private)
        function options = mergeOptions(options)
            if isempty(options)
                options = struct();
            end
            if ~isstruct(options) || ~isscalar(options)
                error("ProjectionSourceGeometry:invalidOptions", ...
                    "Options must be a scalar struct.");
            end

            defaults = struct();
            defaults.CoordinateFrame = "sensor-grid";
            defaults.InterpolationMethod = "linear";
            defaults.ReferenceOrigin = [];
            defaults.OpticalAxis = [];
            defaults.PlatformDirection = [];
            defaults.RowAxis = [];
            defaults.ImageXAxis = [];
            defaults.ImageYAxis = [];
            defaults.GSD = [];
            defaults.PlatformStepMeters = [];
            defaults.NominalRange = [];
            defaults.IFOVDegrees = [];
            defaults.IFOVRadians = [];
            defaults.Metadata = struct();

            names = fieldnames(options);
            for k = 1:numel(names)
                defaults.(names{k}) = options.(names{k});
            end

            defaults.CoordinateFrame = string(defaults.CoordinateFrame);
            if ~isscalar(defaults.CoordinateFrame) || ...
                    strlength(defaults.CoordinateFrame) == 0
                error("ProjectionSourceGeometry:invalidOptions", ...
                    "CoordinateFrame must be a nonempty scalar string.");
            end

            defaults.InterpolationMethod = lower(string(defaults.InterpolationMethod));
            if ~isscalar(defaults.InterpolationMethod) || ...
                    ~any(defaults.InterpolationMethod == ["linear", "nearest"])
                error("ProjectionSourceGeometry:invalidOptions", ...
                    "InterpolationMethod must be linear or nearest.");
            end

            if ~isstruct(defaults.Metadata) || ~isscalar(defaults.Metadata)
                error("ProjectionSourceGeometry:invalidOptions", ...
                    "Metadata must be a scalar struct.");
            end

            options = defaults;
        end

        function imageSize = validateImageSize(imageSize)
            if ~isnumeric(imageSize) || ~isequal(size(imageSize), [1 2]) || ...
                    any(~isfinite(imageSize)) || any(imageSize < 1) || ...
                    any(fix(imageSize) ~= imageSize)
                error("ProjectionSourceGeometry:invalidImageSize", ...
                    "ImageSize must be a finite positive 1x2 integer vector.");
            end
            imageSize = double(imageSize);
        end

        function indices = validatePostIndices(indices, imageLength, name)
            if ~isnumeric(indices) || isempty(indices) || ~isvector(indices) || ...
                    any(~isfinite(indices)) || any(indices < 1) || ...
                    any(indices > imageLength) || any(fix(indices) ~= indices)
                error("ProjectionSourceGeometry:invalidPostIndices", ...
                    "%s must contain finite positive integer image indices.", name);
            end

            indices = double(indices(:).');
            if any(diff(indices) <= 0)
                error("ProjectionSourceGeometry:invalidPostIndices", ...
                    "%s must be strictly increasing.", name);
            end
            if indices(1) ~= 1 || indices(end) ~= imageLength
                error("ProjectionSourceGeometry:invalidPostIndices", ...
                    "%s must include the first and last image indices.", name);
            end
        end

        function origins = validateOrigins(origins, numColumns)
            if ~isnumeric(origins) || ~isequal(size(origins), [3 numColumns]) || ...
                    any(~isfinite(origins), "all")
                error("ProjectionSourceGeometry:invalidOrigins", ...
                    "Origins must be a finite 3 x numColumnPosts numeric array.");
            end
            origins = double(origins);
        end

        function viewVectors = validateViewVectors(viewVectors, numRows, numColumns)
            if ~isnumeric(viewVectors) || size(viewVectors, 1) ~= 3 || ...
                    size(viewVectors, 2) ~= numRows || ...
                    size(viewVectors, 3) ~= numColumns || ...
                    any(~isfinite(viewVectors), "all")
                error("ProjectionSourceGeometry:invalidViewVectors", ...
                    "ViewVectors must be a finite 3 x numRowPosts x numColumnPosts numeric array.");
            end

            viewVectors = double(viewVectors);
            viewVectors = ProjectionSourceGeometry.normalizeVectors(viewVectors);
        end

        function [G, V] = sampleGridGeometry(geometryData, rowIndices, columnIndices)
            rowIndices = ProjectionSourceGeometry.validateSampleIndices( ...
                rowIndices, geometryData.ImageSize(1), "rowIndices");
            columnIndices = ProjectionSourceGeometry.validateSampleIndices( ...
                columnIndices, geometryData.ImageSize(2), "columnIndices");

            G = ProjectionSourceGeometry.sampleOrigins(geometryData, columnIndices);
            V = ProjectionSourceGeometry.sampleViewVectors( ...
                geometryData, rowIndices, columnIndices);
        end

        function [G, V] = sampleGridRays(geometryData, rowPositions, columnPositions)
            [rowPositions, columnPositions] = ...
                ProjectionSourceGeometry.validateObservationPositions( ...
                rowPositions, columnPositions, geometryData.ImageSize);

            G = ProjectionSourceGeometry.sampleOrigins(geometryData, columnPositions);
            V = ProjectionSourceGeometry.sampleObservationViewVectors( ...
                geometryData, rowPositions, columnPositions);
        end

        function indices = validateSampleIndices(indices, upperBound, name)
            if ~isnumeric(indices) || isempty(indices) || ~isvector(indices) || ...
                    any(~isfinite(indices)) || any(indices < 1) || ...
                    any(indices > upperBound) || any(fix(indices) ~= indices)
                error("ProjectionSourceGeometry:invalidSampleIndices", ...
                    "%s must contain finite positive integer image indices.", name);
            end
            indices = double(indices(:).');
        end

        function [rowPositions, columnPositions] = validateObservationPositions( ...
                rowPositions, columnPositions, imageSize)
            rowPositions = ProjectionSourceGeometry.validateSamplePositions( ...
                rowPositions, imageSize(1), "rowPositions");
            columnPositions = ProjectionSourceGeometry.validateSamplePositions( ...
                columnPositions, imageSize(2), "columnPositions");
            if isscalar(rowPositions) && ~isscalar(columnPositions)
                rowPositions = repmat(rowPositions, size(columnPositions));
            elseif isscalar(columnPositions) && ~isscalar(rowPositions)
                columnPositions = repmat(columnPositions, size(rowPositions));
            elseif numel(rowPositions) ~= numel(columnPositions)
                error("ProjectionSourceGeometry:invalidSamplePositions", ...
                    "rowPositions and columnPositions must have the same number of elements.");
            end
        end

        function positions = validateSamplePositions(positions, upperBound, name)
            if ~isnumeric(positions) || isempty(positions) || ~isvector(positions) || ...
                    any(~isfinite(positions)) || any(positions < 1) || ...
                    any(positions > upperBound)
                error("ProjectionSourceGeometry:invalidSamplePositions", ...
                    "%s must contain finite image positions in bounds.", name);
            end
            positions = double(positions(:).');
        end

        function G = sampleOrigins(geometryData, columnPositions)
            columnPositions = double(columnPositions(:).');
            if isscalar(geometryData.ColumnPostIndices)
                G = repmat(geometryData.Origins, 1, numel(columnPositions));
                return
            end

            G = interp1(geometryData.ColumnPostIndices, ...
                geometryData.Origins.', columnPositions, ...
                char(geometryData.InterpolationMethod)).';
        end

        function V = sampleViewVectors(geometryData, rowPositions, columnPositions)
            rowPositions = double(rowPositions(:).');
            columnPositions = double(columnPositions(:).');
            numRows = numel(rowPositions);
            numColumns = numel(columnPositions);
            V = zeros(3, numRows, numColumns);

            rowPosts = geometryData.RowPostIndices;
            columnPosts = geometryData.ColumnPostIndices;
            for componentIndex = 1:3
                componentGrid = squeeze( ...
                    geometryData.GridViewVectors(componentIndex, :, :));
                componentValues = ProjectionSourceGeometry.sampleComponentGrid( ...
                    componentGrid, rowPosts, columnPosts, rowPositions, ...
                    columnPositions, geometryData.InterpolationMethod);
                V(componentIndex, :, :) = reshape( ...
                    componentValues, 1, numRows, numColumns);
            end

            V = ProjectionSourceGeometry.normalizeVectors(V);
        end

        function V = sampleObservationViewVectors(geometryData, rowPositions, ...
                columnPositions)
            rowPositions = double(rowPositions(:).');
            columnPositions = double(columnPositions(:).');
            V = zeros(3, numel(rowPositions));

            rowPosts = geometryData.RowPostIndices;
            columnPosts = geometryData.ColumnPostIndices;
            for componentIndex = 1:3
                componentGrid = squeeze( ...
                    geometryData.GridViewVectors(componentIndex, :, :));
                V(componentIndex, :) = ...
                    ProjectionSourceGeometry.sampleObservationComponentGrid( ...
                    componentGrid, rowPosts, columnPosts, rowPositions, ...
                    columnPositions, geometryData.InterpolationMethod);
            end

            V = ProjectionSourceGeometry.normalizeVectors(V);
        end

        function values = sampleObservationComponentGrid(componentGrid, rowPosts, ...
                columnPosts, rowPositions, columnPositions, interpolationMethod)
            if isscalar(rowPosts) && isscalar(columnPosts)
                values = repmat(componentGrid(1, 1), 1, numel(rowPositions));
                return
            end

            if isscalar(rowPosts)
                values = interp1(columnPosts, componentGrid(1, :), ...
                    columnPositions, char(interpolationMethod));
                return
            end

            if isscalar(columnPosts)
                values = interp1(rowPosts, componentGrid(:, 1), ...
                    rowPositions, char(interpolationMethod));
                return
            end

            values = interp2(columnPosts, rowPosts, componentGrid, ...
                columnPositions, rowPositions, char(interpolationMethod));
        end

        function values = sampleComponentGrid(componentGrid, rowPosts, columnPosts, ...
                rowPositions, columnPositions, interpolationMethod)
            numRows = numel(rowPositions);
            numColumns = numel(columnPositions);
            if isscalar(rowPosts) && isscalar(columnPosts)
                values = repmat(componentGrid(1, 1), numRows, numColumns);
                return
            end

            if isscalar(rowPosts)
                columnValues = interp1(columnPosts, componentGrid(1, :), ...
                    columnPositions, char(interpolationMethod));
                values = repmat(columnValues, numRows, 1);
                return
            end

            if isscalar(columnPosts)
                rowValues = interp1(rowPosts, componentGrid(:, 1), ...
                    rowPositions, char(interpolationMethod));
                values = repmat(rowValues(:), 1, numColumns);
                return
            end

            [rowGrid, columnGrid] = ndgrid(rowPositions, columnPositions);
            values = interp2(columnPosts, rowPosts, componentGrid, ...
                columnGrid, rowGrid, char(interpolationMethod));
        end

        function referenceOrigin = referenceOrigin(geometryData, options)
            referenceOrigin = ProjectionSourceGeometry.optionVector( ...
                options.ReferenceOrigin, "ReferenceOrigin", false);
            if ~isempty(referenceOrigin)
                return
            end

            centerColumn = (geometryData.ImageSize(2) + 1) / 2;
            referenceOrigin = ProjectionSourceGeometry.sampleOrigins( ...
                geometryData, centerColumn);
        end

        function opticalAxis = opticalAxis(geometryData, options)
            opticalAxis = ProjectionSourceGeometry.optionVector( ...
                options.OpticalAxis, "OpticalAxis", true);
            if ~isempty(opticalAxis)
                return
            end

            centerRow = (geometryData.ImageSize(1) + 1) / 2;
            centerColumn = (geometryData.ImageSize(2) + 1) / 2;
            opticalAxis = ProjectionSourceGeometry.sampleViewVectors( ...
                geometryData, centerRow, centerColumn);
            opticalAxis = opticalAxis(:, 1, 1);
        end

        function platformDirection = platformDirection(geometryData, options)
            platformDirection = ProjectionSourceGeometry.optionVector( ...
                options.PlatformDirection, "PlatformDirection", true);
            if ~isempty(platformDirection)
                return
            end

            if size(geometryData.Origins, 2) < 2
                error("ProjectionSourceGeometry:invalidGeometry", ...
                    "PlatformDirection must be supplied when only one column origin is provided.");
            end
            platformDirection = ProjectionSourceGeometry.unitVector( ...
                geometryData.Origins(:, end) - geometryData.Origins(:, 1), ...
                "PlatformDirection");
        end

        function rowAxis = rowAxis(geometryData, options)
            rowAxis = ProjectionSourceGeometry.optionVector( ...
                options.RowAxis, "RowAxis", true);
            if ~isempty(rowAxis)
                return
            end

            if numel(geometryData.RowPostIndices) < 2
                error("ProjectionSourceGeometry:invalidGeometry", ...
                    "RowAxis must be supplied when only one row post is provided.");
            end

            centerColumn = (geometryData.ImageSize(2) + 1) / 2;
            rowIndices = ProjectionSourceGeometry.centerAdjacentIndices( ...
                geometryData.ImageSize(1));
            V = ProjectionSourceGeometry.sampleViewVectors( ...
                geometryData, rowIndices, centerColumn);
            rowAxis = ProjectionSourceGeometry.unitVector( ...
                V(:, 2, 1) - V(:, 1, 1), "RowAxis");
        end

        function imageXAxis = imageXAxis(geometryData, options)
            imageXAxis = ProjectionSourceGeometry.optionVector( ...
                options.ImageXAxis, "ImageXAxis", true);
            if isempty(imageXAxis)
                imageXAxis = geometryData.PlatformDirection;
            end
        end

        function imageYAxis = imageYAxis(geometryData, options)
            imageYAxis = ProjectionSourceGeometry.optionVector( ...
                options.ImageYAxis, "ImageYAxis", true);
            if isempty(imageYAxis)
                imageYAxis = geometryData.RowAxis;
            end
        end

        function indices = centerAdjacentIndices(imageLength)
            if imageLength <= 1
                indices = 1;
                return
            end

            firstIndex = max(1, floor((imageLength + 1) / 2));
            secondIndex = min(imageLength, firstIndex + 1);
            if secondIndex == firstIndex
                firstIndex = firstIndex - 1;
            end
            indices = [firstIndex secondIndex];
        end

        function geometryData = addOptionalScalars(geometryData, options)
            optionalNames = ["GSD", "PlatformStepMeters", "NominalRange"];
            for name = optionalNames
                value = options.(name);
                if isempty(value)
                    continue
                end
                geometryData.(name) = ProjectionSourceGeometry.validatePositiveScalar( ...
                    value, name);
            end
        end

        function geometryData = addIfov(geometryData, options)
            if ~isempty(options.IFOVDegrees)
                ifovDegrees = ProjectionSourceGeometry.validatePositiveScalar( ...
                    options.IFOVDegrees, "IFOVDegrees");
            elseif ~isempty(options.IFOVRadians)
                ifovRadians = ProjectionSourceGeometry.validatePositiveScalar( ...
                    options.IFOVRadians, "IFOVRadians");
                ifovDegrees = rad2deg(ifovRadians);
            else
                ifovDegrees = ProjectionSourceGeometry.estimateIfovDegrees(geometryData);
            end

            if ~isempty(ifovDegrees)
                geometryData.IFOVDegrees = ifovDegrees;
                geometryData.IFOVRadians = deg2rad(ifovDegrees);
            end
        end

        function ifovDegrees = estimateIfovDegrees(geometryData)
            V = geometryData.GridViewVectors;
            anglesRadians = zeros(0, 1);
            rowSpacing = diff(geometryData.RowPostIndices);
            for rowIndex = 1:numel(rowSpacing)
                dots = squeeze(sum(V(:, rowIndex, :) .* V(:, rowIndex + 1, :), 1));
                anglesRadians = [anglesRadians; ...
                    ProjectionSourceGeometry.vectorAngles(dots(:)) / rowSpacing(rowIndex)]; %#ok<AGROW>
            end

            columnSpacing = diff(geometryData.ColumnPostIndices);
            for columnIndex = 1:numel(columnSpacing)
                dots = squeeze(sum(V(:, :, columnIndex) .* V(:, :, columnIndex + 1), 1));
                anglesRadians = [anglesRadians; ...
                    ProjectionSourceGeometry.vectorAngles(dots(:)) / columnSpacing(columnIndex)]; %#ok<AGROW>
            end

            anglesRadians = anglesRadians(isfinite(anglesRadians) & anglesRadians > 1e-12);
            if isempty(anglesRadians)
                ifovDegrees = [];
            else
                ifovDegrees = rad2deg(median(anglesRadians));
            end
        end

        function angles = vectorAngles(dots)
            dots = min(max(double(dots), -1), 1);
            angles = acos(dots);
        end

        function metadata = metadata(geometryData, options)
            metadata = options.Metadata;
            metadata.Description = "Sparse grid source geometry";
            metadata.CPUReferencePath = true;
            metadata.RowPostCount = numel(geometryData.RowPostIndices);
            metadata.ColumnPostCount = numel(geometryData.ColumnPostIndices);
            metadata.InterpolationMethod = geometryData.InterpolationMethod;
        end

        function vector = optionVector(vector, name, normalize)
            if isempty(vector)
                vector = [];
                return
            end

            if normalize
                vector = ProjectionSourceGeometry.unitVector(vector, name);
            else
                vector = ProjectionSourceGeometry.validateVector(vector, name);
            end
        end

        function vector = validateVector(vector, name)
            if ~isnumeric(vector) || ~isequal(size(vector), [3 1]) || ...
                    any(~isfinite(vector))
                error("ProjectionSourceGeometry:invalidVector", ...
                    "%s must be a finite numeric 3x1 vector.", name);
            end
            vector = double(vector);
        end

        function vector = unitVector(vector, name)
            vector = ProjectionSourceGeometry.validateVector(vector, name);
            magnitude = norm(vector);
            if magnitude <= 1e-12
                error("ProjectionSourceGeometry:invalidVector", ...
                    "%s must have nonzero length.", name);
            end
            vector = vector / magnitude;
        end

        function vectors = normalizeVectors(vectors)
            vectorNorms = sqrt(sum(vectors.^2, 1));
            if any(vectorNorms <= 1e-12, "all")
                error("ProjectionSourceGeometry:invalidViewVectors", ...
                    "ViewVectors must have nonzero length.");
            end
            vectors = vectors ./ vectorNorms;
        end

        function value = validatePositiveScalar(value, name)
            if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value) || value <= 0
                error("ProjectionSourceGeometry:invalidScalar", ...
                    "%s must be a positive finite scalar.", name);
            end
            value = double(value);
        end
    end
end
