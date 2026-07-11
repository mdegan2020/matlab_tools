classdef ProjectionFullSourceInverseWarp
    %ProjectionFullSourceInverseWarp Map output points to full source samples.

    properties (Constant)
        Format = "ProjectionFullSourceInverseWarp"
        Version = 1
    end

    methods (Static)
        function model = prepare(mesh, plane, imageSize)
            %prepare Build a reusable projection-plane-to-source map topology.
            ProjectionFullSourceInverseWarp.validateMesh(mesh);
            PlanarProjection.validatePlane(plane);
            imageSize = ProjectionFullSourceInverseWarp.validateImageSize(imageSize);
            worldPoints = reshape(mesh.WorldPoints, 3, []);
            planeCoordinates = PlanarProjection.worldToPlane(worldPoints, plane);
            rowValues = repmat(mesh.RowIndices(:), 1, numel(mesh.ColumnIndices));
            columnValues = repmat(mesh.ColumnIndices(:).', ...
                numel(mesh.RowIndices), 1);
            interpolant = scatteredInterpolant( ...
                planeCoordinates(1, :).', planeCoordinates(2, :).', ...
                zeros(size(planeCoordinates, 2), 1), "linear", "none");

            model = struct();
            model.Format = ProjectionFullSourceInverseWarp.Format;
            model.Version = ProjectionFullSourceInverseWarp.Version;
            model.RuntimeOnly = true;
            model.ImageSize = imageSize;
            model.MeshRowIndices = double(mesh.RowIndices(:).');
            model.MeshColumnIndices = double(mesh.ColumnIndices(:).');
            model.PlaneCoordinates = planeCoordinates;
            model.RowValues = double(rowValues(:));
            model.ColumnValues = double(columnValues(:));
            model.InterpolantTemplate = interpolant;
            model.CoordinateTolerance = 1e-9 * max([1 imageSize]);
            ProjectionFullSourceInverseWarp.validate(model);
        end

        function model = validate(model)
            %validate Validate a prepared runtime inverse-warp model.
            requiredFields = ["Format", "Version", "RuntimeOnly", ...
                "ImageSize", "MeshRowIndices", "MeshColumnIndices", ...
                "PlaneCoordinates", "RowValues", "ColumnValues", ...
                "InterpolantTemplate", "CoordinateTolerance"];
            if ~isstruct(model) || ~isscalar(model) || ...
                    any(~isfield(model, requiredFields)) || ...
                    string(model.Format) ~= ProjectionFullSourceInverseWarp.Format || ...
                    double(model.Version) ~= ProjectionFullSourceInverseWarp.Version || ...
                    ~isa(model.InterpolantTemplate, "scatteredInterpolant")
                error("ProjectionFullSourceInverseWarp:invalidModel", ...
                    "Inverse-warp model has an invalid format or topology.");
            end
            model.ImageSize = ProjectionFullSourceInverseWarp.validateImageSize( ...
                model.ImageSize);
            pointCount = size(model.PlaneCoordinates, 2);
            if ~isnumeric(model.PlaneCoordinates) || ...
                    size(model.PlaneCoordinates, 1) ~= 2 || ...
                    any(~isfinite(model.PlaneCoordinates), "all") || ...
                    numel(model.RowValues) ~= pointCount || ...
                    numel(model.ColumnValues) ~= pointCount
                error("ProjectionFullSourceInverseWarp:invalidModel", ...
                    "Inverse-warp coordinates and values are inconsistent.");
            end
        end

        function mapping = mapCoordinates(model, queryPlaneCoordinates, outputSize)
            %mapCoordinates Return continuous full-source row/column positions.
            model = ProjectionFullSourceInverseWarp.validate(model);
            outputSize = ProjectionFullSourceInverseWarp.validateOutputSize( ...
                outputSize);
            if ~isnumeric(queryPlaneCoordinates) || ...
                    ~isequal(size(queryPlaneCoordinates), [2 prod(outputSize)]) || ...
                    any(~isfinite(queryPlaneCoordinates), "all")
                error("ProjectionFullSourceInverseWarp:invalidQuery", ...
                    "Query plane coordinates must be finite 2 x prod(OutputSize).");
            end

            interpolant = model.InterpolantTemplate;
            interpolant.Values = model.RowValues;
            rowCoordinates = reshape(interpolant( ...
                queryPlaneCoordinates(1, :).', ...
                queryPlaneCoordinates(2, :).'), outputSize);
            interpolant.Values = model.ColumnValues;
            columnCoordinates = reshape(interpolant( ...
                queryPlaneCoordinates(1, :).', ...
                queryPlaneCoordinates(2, :).'), outputSize);
            tolerance = model.CoordinateTolerance;
            validMask = isfinite(rowCoordinates) & isfinite(columnCoordinates) & ...
                rowCoordinates >= 1 - tolerance & ...
                rowCoordinates <= model.ImageSize(1) + tolerance & ...
                columnCoordinates >= 1 - tolerance & ...
                columnCoordinates <= model.ImageSize(2) + tolerance;
            rowCoordinates(validMask) = min(max( ...
                rowCoordinates(validMask), 1), model.ImageSize(1));
            columnCoordinates(validMask) = min(max( ...
                columnCoordinates(validMask), 1), model.ImageSize(2));

            mapping = struct();
            mapping.Format = "ProjectionFullSourceCoordinateMap";
            mapping.Version = 1;
            mapping.OutputSize = outputSize;
            mapping.ImageSize = model.ImageSize;
            mapping.RowCoordinates = rowCoordinates;
            mapping.ColumnCoordinates = columnCoordinates;
            mapping.ValidMask = validMask;
            mapping.CoordinateTolerance = tolerance;
        end

        function [outputImage, validMask] = sampleImage( ...
                imageData, mapping, interpolation, invalidFillValue)
            %sampleImage Sample every registered source band with one mapping.
            ProjectionFullSourceInverseWarp.validateImageData( ...
                imageData, mapping.ImageSize);
            ProjectionFullSourceInverseWarp.validateMapping(mapping);
            interpolation = ...
                ProjectionFullSourceInverseWarp.validateInterpolation( ...
                interpolation);
            if ~isnumeric(invalidFillValue) || ~isscalar(invalidFillValue)
                error("ProjectionFullSourceInverseWarp:invalidFillValue", ...
                    "InvalidFillValue must be a numeric scalar.");
            end
            invalidFillValue = double(invalidFillValue);

            bandCount = size(imageData, 3);
            outputImage = zeros([mapping.OutputSize bandCount]);
            validMask = mapping.ValidMask;
            for bandIndex = 1:bandCount
                sampledBand = ProjectionFullSourceInverseWarp.sampleBand( ...
                    double(imageData(:, :, bandIndex)), ...
                    mapping.RowCoordinates, mapping.ColumnCoordinates, ...
                    interpolation);
                bandValidMask = isfinite(sampledBand) & mapping.ValidMask;
                validMask = validMask & bandValidMask;
                sampledBand(~bandValidMask) = invalidFillValue;
                outputImage(:, :, bandIndex) = sampledBand;
            end
            if ~all(validMask, "all")
                invalidMask = repmat(~validMask, 1, 1, bandCount);
                outputImage(invalidMask) = invalidFillValue;
            end
            if bandCount == 1
                outputImage = outputImage(:, :, 1);
            end
        end

        function comparison = compareReadbacks(fullSource, sparseReference)
            %compareReadbacks Quantify full-source versus sparse compatibility.
            requiredFields = ["Image", "ValidMask"];
            if ~isstruct(fullSource) || ~isscalar(fullSource) || ...
                    ~isstruct(sparseReference) || ~isscalar(sparseReference) || ...
                    any(~isfield(fullSource, requiredFields)) || ...
                    any(~isfield(sparseReference, requiredFields)) || ...
                    ~isequal(size(fullSource.Image), size(sparseReference.Image)) || ...
                    ~isequal(size(fullSource.ValidMask), ...
                    size(sparseReference.ValidMask))
                error("ProjectionFullSourceInverseWarp:invalidComparison", ...
                    "Readbacks must contain equal-sized images and masks.");
            end
            commonMask = fullSource.ValidMask & sparseReference.ValidMask;
            bandCount = size(fullSource.Image, 3);
            bands = repmat(struct(MeanAbsoluteError=NaN, ...
                RootMeanSquareError=NaN, P95AbsoluteError=NaN, ...
                MaximumAbsoluteError=NaN), 1, bandCount);
            for bandIndex = 1:bandCount
                fullBand = fullSource.Image(:, :, bandIndex);
                sparseBand = sparseReference.Image(:, :, bandIndex);
                differences = sort(abs(double(fullBand(commonMask)) - ...
                    double(sparseBand(commonMask))));
                if isempty(differences)
                    continue
                end
                bands(bandIndex).MeanAbsoluteError = mean(differences);
                bands(bandIndex).RootMeanSquareError = ...
                    sqrt(mean(differences .^ 2));
                bands(bandIndex).P95AbsoluteError = differences( ...
                    max(1, ceil(0.95 * numel(differences))));
                bands(bandIndex).MaximumAbsoluteError = max(differences);
            end
            comparison = struct();
            comparison.Format = "ProjectionInverseWarpCompatibility";
            comparison.Version = 1;
            comparison.CommonValidPixelCount = nnz(commonMask);
            comparison.FullSourceValidPixelCount = nnz(fullSource.ValidMask);
            comparison.SparseReferenceValidPixelCount = ...
                nnz(sparseReference.ValidMask);
            comparison.ValidMaskMismatchCount = nnz(xor( ...
                fullSource.ValidMask, sparseReference.ValidMask));
            comparison.Bands = bands;
        end
    end

    methods (Static, Access = private)
        function sampledBand = sampleBand( ...
                band, rowCoordinates, columnCoordinates, interpolation)
            rowCount = size(band, 1);
            columnCount = size(band, 2);
            method = char(ProjectionFullSourceInverseWarp.interpMethod( ...
                interpolation));
            if rowCount > 1 && columnCount > 1
                sampledBand = interp2(band, columnCoordinates, ...
                    rowCoordinates, method, NaN);
            elseif rowCount == 1 && columnCount > 1
                sampledBand = interp1(1:columnCount, band(1, :), ...
                    columnCoordinates, method, NaN);
                sampledBand(abs(rowCoordinates - 1) > eps) = NaN;
            elseif rowCount > 1
                sampledBand = interp1((1:rowCount).', band(:, 1), ...
                    rowCoordinates, method, NaN);
                sampledBand(abs(columnCoordinates - 1) > eps) = NaN;
            else
                sampledBand = band(1) * ones(size(rowCoordinates));
                sampledBand(abs(rowCoordinates - 1) > eps | ...
                    abs(columnCoordinates - 1) > eps) = NaN;
            end
        end

        function validateMesh(mesh)
            requiredFields = ["WorldPoints", "RowIndices", "ColumnIndices"];
            if ~isstruct(mesh) || ~isscalar(mesh) || ...
                    any(~isfield(mesh, requiredFields)) || ...
                    size(mesh.WorldPoints, 1) ~= 3 || ...
                    size(mesh.WorldPoints, 2) ~= numel(mesh.RowIndices) || ...
                    size(mesh.WorldPoints, 3) ~= numel(mesh.ColumnIndices)
                error("ProjectionFullSourceInverseWarp:invalidMesh", ...
                    "Mesh must contain consistent world points and source indices.");
            end
        end

        function imageSize = validateImageSize(imageSize)
            if ~isnumeric(imageSize) || ~isvector(imageSize) || ...
                    numel(imageSize) < 2 || any(~isfinite(imageSize(1:2))) || ...
                    any(imageSize(1:2) < 1) || ...
                    any(fix(imageSize(1:2)) ~= imageSize(1:2))
                error("ProjectionFullSourceInverseWarp:invalidImageSize", ...
                    "ImageSize must begin with two positive integer dimensions.");
            end
            imageSize = double(imageSize(1:2));
        end

        function outputSize = validateOutputSize(outputSize)
            if ~isnumeric(outputSize) || ~isvector(outputSize) || ...
                    numel(outputSize) ~= 2 || any(~isfinite(outputSize)) || ...
                    any(outputSize < 1) || any(fix(outputSize) ~= outputSize)
                error("ProjectionFullSourceInverseWarp:invalidOutputSize", ...
                    "OutputSize must be a positive integer 2-vector.");
            end
            outputSize = double(outputSize(:).');
        end

        function validateImageData(imageData, imageSize)
            if ~(isnumeric(imageData) || islogical(imageData)) || ...
                    isempty(imageData) || size(imageData, 1) ~= imageSize(1) || ...
                    size(imageData, 2) ~= imageSize(2)
                error("ProjectionFullSourceInverseWarp:invalidImage", ...
                    "Source image dimensions must match the inverse-warp model.");
            end
        end

        function validateMapping(mapping)
            requiredFields = ["Format", "OutputSize", "ImageSize", ...
                "RowCoordinates", "ColumnCoordinates", "ValidMask"];
            if ~isstruct(mapping) || ~isscalar(mapping) || ...
                    any(~isfield(mapping, requiredFields)) || ...
                    string(mapping.Format) ~= "ProjectionFullSourceCoordinateMap" || ...
                    ~isequal(size(mapping.RowCoordinates), mapping.OutputSize) || ...
                    ~isequal(size(mapping.ColumnCoordinates), mapping.OutputSize) || ...
                    ~isequal(size(mapping.ValidMask), mapping.OutputSize)
                error("ProjectionFullSourceInverseWarp:invalidMapping", ...
                    "Mapping must be produced by mapCoordinates.");
            end
        end

        function interpolation = validateInterpolation(interpolation)
            interpolation = lower(string(interpolation));
            if ~isscalar(interpolation) || ...
                    ~ismember(interpolation, ["bilinear", "nearest"])
                error("ProjectionFullSourceInverseWarp:invalidInterpolation", ...
                    "Interpolation must be bilinear or nearest.");
            end
        end

        function method = interpMethod(interpolation)
            if interpolation == "bilinear"
                method = "linear";
            else
                method = "nearest";
            end
        end
    end
end
