classdef HeightImagePyramid
    %HEIGHTIMAGEPYRAMID Filtered images with exact center coordinates.
    %
    % Every level is filtered directly from the base image. One-based
    % geometric pixels map as
    %
    %   pBase = factor * (pLevel - 0.5) + 0.5.
    %
    % A level pixel is valid only when its antialiasing support is entirely
    % valid to single-precision tolerance. Axis order is [x,y]=[column,row].
    %
    % Traceability: long-range workplan C1.1; data contract Phase B0
    % processed/full-resolution pixel-center convention.

    properties (SetAccess = private)
        BaseImageSize (1, 2) double
        Factors (1, :) double
        Images (1, :) cell
        ValidMasks (1, :) cell
        LevelSizes (:, 2) double
        MinimumValidWeight (1, 1) double
        FilterDescription (1, 1) string = ...
            "imresize bilinear with Antialiasing=true; direct from base"
        PixelConvention (1, 1) string = ...
            "one-based [x,y]=[column,row] pixel centers"
    end

    methods
        function obj = HeightImagePyramid(image, validMask, factors, options)
            arguments
                image (:, :) ...
                    {mustBeNumeric, mustBeReal, mustBeNonempty}
                validMask (:, :) logical ...
                    {mustMatchImageSize(validMask, image)}
                factors (1, :) double {mustBePyramidFactors}
                options.MinimumValidWeight (1, 1) double ...
                    {mustBeFinite, mustBePositive, ...
                    mustBeLessThanOrEqual(options.MinimumValidWeight, 1)} ...
                    = 1 - 64 .* eps("single")
            end

            obj.BaseImageSize = size(image);
            obj.Factors = factors;
            obj.MinimumValidWeight = options.MinimumValidWeight;
            obj.Images = cell(size(factors));
            obj.ValidMasks = cell(size(factors));
            obj.LevelSizes = zeros(numel(factors), 2);

            base = image;
            base(~validMask) = 0;
            for k = 1:numel(factors)
                factor = factors(k);
                if factor == 1
                    levelImage = base;
                    weight = single(validMask);
                else
                    levelImage = imresize(base, 1 ./ factor, "bilinear", ...
                        "Antialiasing", true);
                    weight = imresize(single(validMask), 1 ./ factor, ...
                        "bilinear", "Antialiasing", true);
                end
                levelValid = weight >= obj.MinimumValidWeight;
                levelImage(~levelValid) = 0;
                expectedSize = ceil(obj.BaseImageSize ./ factor);
                if ~isequal(size(levelImage), expectedSize)
                    error("HeightImagePyramid:UnexpectedLevelSize", ...
                        "Filtered factor %g returned [%d,%d], expected [%d,%d].", ...
                        factor, size(levelImage, 1), size(levelImage, 2), ...
                        expectedSize(1), expectedSize(2));
                end
                obj.Images{k} = levelImage;
                obj.ValidMasks{k} = levelValid;
                obj.LevelSizes(k, :) = size(levelImage);
            end
        end

        function level = getLevel(obj, factor)
            %GETLEVEL Return one immutable level description.
            arguments
                obj (1, 1) HeightImagePyramid
                factor (1, 1) double ...
                    {mustBeFinite, mustBeInteger, mustBePositive}
            end

            index = find(obj.Factors == factor, 1);
            if isempty(index)
                error("HeightImagePyramid:UnknownFactor", ...
                    "Factor %g is not present in this pyramid.", factor);
            end
            level = struct( ...
                "Factor", factor, ...
                "Image", obj.Images{index}, ...
                "ValidMask", obj.ValidMasks{index}, ...
                "ImageSize", obj.LevelSizes(index, :), ...
                "LevelToBaseScaleXY", [factor, factor], ...
                "LevelToBaseOffsetXY", 0.5 .* [1 - factor, 1 - factor], ...
                "PixelConvention", obj.PixelConvention, ...
                "FilterDescription", obj.FilterDescription);
        end
    end

    methods (Static)
        function basePixelXY = levelToBase(levelPixelXY, factor)
            arguments
                levelPixelXY (:, 2) double {mustBeReal}
                factor (1, 1) double ...
                    {mustBeFinite, mustBeInteger, mustBePositive}
            end

            basePixelXY = factor .* (levelPixelXY - 0.5) + 0.5;
        end

        function levelPixelXY = baseToLevel(basePixelXY, factor)
            arguments
                basePixelXY (:, 2) double {mustBeReal}
                factor (1, 1) double ...
                    {mustBeFinite, mustBeInteger, mustBePositive}
            end

            levelPixelXY = (basePixelXY - 0.5) ./ factor + 0.5;
        end

        function factors = selectFactors( ...
                imageSize, overviewMaximumDimension, decimation, options)
            %SELECTFACTORS Return overview-to-base integer factors.
            arguments
                imageSize (1, 2) double ...
                    {mustBeFinite, mustBeInteger, mustBePositive}
                overviewMaximumDimension (1, 1) double ...
                    {mustBeFinite, mustBeInteger, mustBePositive}
                decimation (1, 1) double ...
                    {mustBeFinite, mustBeInteger, ...
                    mustBeGreaterThanOrEqual(decimation, 2)} = 2
                options.IncludeIntermediateLevels (1, 1) logical = true
            end

            ratio = max(imageSize) ./ overviewMaximumDimension;
            exponent = max(0, ceil(log(max(ratio, 1)) ./ log(decimation)));
            overview = decimation .^ exponent;
            if options.IncludeIntermediateLevels
                factors = overview;
                while factors(end) > 1
                    factors(end + 1) = factors(end) ./ decimation; %#ok<AGROW>
                end
            else
                factors = unique([overview, 1], "stable");
            end
        end
    end
end

function mustMatchImageSize(mask, image)
if ~isequal(size(mask), size(image))
    error("HeightImagePyramid:MaskSizeMismatch", ...
        "The validity mask must match the image size.");
end
end

function mustBePyramidFactors(factors)
valid = ~isempty(factors) && all(isfinite(factors)) ...
    && all(factors > 0) && all(factors == fix(factors)) ...
    && factors(end) == 1 && all(diff(factors) < 0);
if ~valid
    error("HeightImagePyramid:InvalidFactors", ...
        "Factors must be unique descending positive integers ending at one.");
end
end
