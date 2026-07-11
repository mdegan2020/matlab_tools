function result = estimateVerticalScaleDifference(fixedImage, movingImage, varargin)
%ESTIMATEVERTICALSCALEDIFFERENCE Estimate vertical scale mismatch between images.
%
% result = estimateVerticalScaleDifference(fixedImage, movingImage)
% estimates the vertical scale factor that should be applied to movingImage
% so that it matches fixedImage. Inputs can be numeric image arrays or file
% names accepted by imread.
%
% The estimator is constrained to vertical scale. It samples columns from
% each image, builds robust vertical texture profiles in multiple x-strips,
% searches scale factors near 1.0, and treats vertical translation as a
% nuisance parameter.
%
% Important result fields:
%   scaleMovingToFixed    Scale applied to movingImage rows to match fixedImage
%   percentDifference     100*(scaleMovingToFixed - 1)
%   verticalOffsetPixels  Offset after scaling, in fixed-image row pixels
%   confidence            "high", "moderate", or "low"
%   stripTable            Per-strip estimates and correlations
%
% Name-value options:
%   ScaleRange              Search range, default [0.95 1.05]
%   CoarseStep              Coarse scale grid step, default 1e-3
%   FineStep                Fine scale grid step, default 1e-4
%   FineWindow              Half-width around coarse estimate, default 3e-3
%   MaxWorkingWidth         Maximum sampled columns per image, default 4096
%   NumStrips               Number of independent x-strips, default 9
%   ProfileMode             "gradientEnergy", "signedGradient", "rowMean",
%                           or "mixed", default "gradientEnergy"
%   Band                    Band to use for multiband imagery, default []
%   MaxVerticalOffsetPixels Maximum row shift to search, default []
%   MaxOffsetFraction       Used when MaxVerticalOffsetPixels is [], default .10
%   MinOverlapFraction      Minimum profile overlap during correlation, default .70
%   MinCorrelation          Minimum strip correlation for primary use, default .08
%   OutlierTolerance        Strip scale outlier cutoff, default .01
%   ProfileHighpassWindow   Moving-average trend window, default automatic
%   ClipSigma               Robust image/profile clipping threshold, default 6
%   ShowPlot                Plot per-strip diagnostics, default false
%   Verbose                 Print progress, default false
%
% Example:
%   r = estimateVerticalScaleDifference("time1.tif", "time2.tif");
%   fprintf("Vertical scale moving-to-fixed: %.6f (%.3f%%)\n", ...
%       r.scaleMovingToFixed, r.percentDifference);

parser = inputParser;
parser.FunctionName = mfilename;

isScalarPositive = @(x) isnumeric(x) && isscalar(x) && isfinite(x) && x > 0;
isScalarNonnegative = @(x) isnumeric(x) && isscalar(x) && isfinite(x) && x >= 0;
isScalarLogicalLike = @(x) (islogical(x) || isnumeric(x)) && isscalar(x);
isTextScalar = @(x) ischar(x) || (isstring(x) && isscalar(x));

addRequired(parser, "fixedImage");
addRequired(parser, "movingImage");
addParameter(parser, "ScaleRange", [0.95 1.05], ...
    @(x) isnumeric(x) && numel(x) == 2 && all(isfinite(x)) && x(1) > 0 && x(2) > x(1));
addParameter(parser, "CoarseStep", 1e-3, isScalarPositive);
addParameter(parser, "FineStep", 1e-4, isScalarPositive);
addParameter(parser, "FineWindow", 3e-3, isScalarPositive);
addParameter(parser, "MaxWorkingWidth", 4096, isScalarPositive);
addParameter(parser, "NumStrips", 9, isScalarPositive);
addParameter(parser, "ProfileMode", "gradientEnergy", isTextScalar);
addParameter(parser, "Band", [], @(x) isempty(x) || (isnumeric(x) && isscalar(x) && x >= 1));
addParameter(parser, "MaxVerticalOffsetPixels", [], @(x) isempty(x) || isScalarNonnegative(x));
addParameter(parser, "MaxOffsetFraction", 0.10, isScalarNonnegative);
addParameter(parser, "MinOverlapFraction", 0.70, ...
    @(x) isnumeric(x) && isscalar(x) && isfinite(x) && x > 0 && x <= 1);
addParameter(parser, "MinCorrelation", 0.08, ...
    @(x) isnumeric(x) && isscalar(x) && isfinite(x) && x >= -1 && x <= 1);
addParameter(parser, "OutlierTolerance", 0.01, isScalarPositive);
addParameter(parser, "ProfileHighpassWindow", [], @(x) isempty(x) || isScalarPositive(x));
addParameter(parser, "ClipSigma", 6, isScalarPositive);
addParameter(parser, "ShowPlot", false, isScalarLogicalLike);
addParameter(parser, "Verbose", false, isScalarLogicalLike);

parse(parser, fixedImage, movingImage, varargin{:});
opts = parser.Results;
opts.ScaleRange = double(opts.ScaleRange(:)).';
opts.MaxWorkingWidth = max(1, round(double(opts.MaxWorkingWidth)));
opts.NumStrips = max(1, round(double(opts.NumStrips)));
opts.ProfileMode = lower(string(opts.ProfileMode));
opts.ShowPlot = logical(opts.ShowPlot);
opts.Verbose = logical(opts.Verbose);

if opts.FineStep > opts.CoarseStep
    error("estimateVerticalScaleDifference:invalidStep", ...
        "FineStep must be less than or equal to CoarseStep.");
end

[fixed, fixedInfo] = readWorkingImage(fixedImage, opts);
[moving, movingInfo] = readWorkingImage(movingImage, opts);

if size(fixed, 1) < 20 || size(moving, 1) < 20
    error("estimateVerticalScaleDifference:imageTooSmall", ...
        "Both images must have at least 20 rows.");
end

if opts.Verbose
    fprintf("Working fixed image:  %d rows x %d columns\n", size(fixed, 1), size(fixed, 2));
    fprintf("Working moving image: %d rows x %d columns\n", size(moving, 1), size(moving, 2));
end

coarseScales = makeScaleGrid(opts.ScaleRange, opts.CoarseStep);
coarseStrips = estimateStrips(fixed, moving, coarseScales, opts);
[coarseScale, coarseUsedMask] = aggregateStripScales(coarseStrips, opts);

fineRange = [max(opts.ScaleRange(1), coarseScale - opts.FineWindow), ...
    min(opts.ScaleRange(2), coarseScale + opts.FineWindow)];
fineScales = makeScaleGrid(fineRange, opts.FineStep);

if numel(fineScales) < 3
    fineScales = coarseScales;
end

stripTable = estimateStrips(fixed, moving, fineScales, opts);
[scale, usedMask, scaleSpread] = aggregateStripScales(stripTable, opts);

stripTable.usedForEstimate = usedMask(:);
usedRows = stripTable(usedMask, :);

if isempty(usedRows)
    verticalOffset = NaN;
    correlation = NaN;
else
    offsetWeights = max(usedRows.correlation, 0).^2 + eps;
    verticalOffset = weightedMedian(usedRows.verticalOffsetPixels, offsetWeights);
    correlation = weightedMedian(usedRows.correlation, offsetWeights);
end

confidence = classifyConfidence(nnz(usedMask), correlation, scaleSpread);

result = struct();
result.scaleMovingToFixed = scale;
result.percentDifference = 100 * (scale - 1);
result.fixedToMovingScale = 1 / scale;
result.verticalOffsetPixels = verticalOffset;
result.correlation = correlation;
result.confidence = confidence;
result.scaleSpreadPercent = 100 * scaleSpread;
result.stripTable = stripTable;
result.coarseScaleMovingToFixed = coarseScale;
result.coarseStripTable = addUsedColumn(coarseStrips, coarseUsedMask);
result.fixedInfo = fixedInfo;
result.movingInfo = movingInfo;
result.options = opts;
result.scaleDefinition = ...
    "scaleMovingToFixed is the factor applied to movingImage rows to match fixedImage.";
result.offsetDefinition = ...
    "verticalOffsetPixels maps scaled moving row j to fixed row j + offset; positive means lower in fixed-image coordinates.";

if opts.ShowPlot
    plotDiagnostics(result);
end
end

function [gray, info] = readWorkingImage(imageInput, opts)
if ischar(imageInput) || (isstring(imageInput) && isscalar(imageInput))
    source = char(imageInput);
    raw = imread(source);
else
    source = "<array>";
    raw = imageInput;
end

if ~(isnumeric(raw) || islogical(raw)) || isempty(raw)
    error("estimateVerticalScaleDifference:invalidImage", ...
        "Image inputs must be nonempty numeric arrays, logical arrays, or image file names.");
end

rawSize = size(raw);
if numel(rawSize) < 3
    rawSize(3) = 1;
end

if ndims(raw) > 3
    error("estimateVerticalScaleDifference:invalidImageRank", ...
        "Images with more than 3 dimensions are not supported.");
end

width = size(raw, 2);
if width > opts.MaxWorkingWidth
    cols = unique(round(linspace(1, width, opts.MaxWorkingWidth)));
    raw = raw(:, cols, :);
else
    cols = 1:width;
end

gray = convertToGray(raw, opts.Band);

info = struct();
info.source = source;
info.originalSize = rawSize;
info.workingSize = size(gray);
info.sampledColumnCount = numel(cols);
info.firstSampledColumn = cols(1);
info.lastSampledColumn = cols(end);
end

function gray = convertToGray(raw, band)
if ~isempty(band)
    if ismatrix(raw) || band > size(raw, 3)
        error("estimateVerticalScaleDifference:invalidBand", ...
            "Requested Band exceeds the number of image bands.");
    end
    gray = single(raw(:, :, band));
    return
end

if ismatrix(raw)
    gray = single(raw);
    return
end

numBands = size(raw, 3);
raw = single(raw);

if numBands == 3
    gray = 0.2989 * raw(:, :, 1) + 0.5870 * raw(:, :, 2) + 0.1140 * raw(:, :, 3);
else
    gray = mean(raw, 3);
end
end

function scales = makeScaleGrid(scaleRange, step)
lo = scaleRange(1);
hi = scaleRange(2);
count = floor((hi - lo) / step);
scales = lo + (0:count) * step;

if scales(end) < hi
    scales(end + 1) = hi;
end

scales = unique(scales(:).');
end

function stripTable = estimateStrips(fixed, moving, scales, opts)
numStrips = min(opts.NumStrips, min(size(fixed, 2), size(moving, 2)));
fixedEdges = round(linspace(1, size(fixed, 2) + 1, numStrips + 1));
movingEdges = round(linspace(1, size(moving, 2) + 1, numStrips + 1));

emptyRow = struct( ...
    "strip", NaN, ...
    "fixedColumnStart", NaN, ...
    "fixedColumnEnd", NaN, ...
    "movingColumnStart", NaN, ...
    "movingColumnEnd", NaN, ...
    "scale", NaN, ...
    "verticalOffsetPixels", NaN, ...
    "correlation", NaN, ...
    "overlapPixels", NaN, ...
    "profileLengthFixed", NaN, ...
    "profileLengthMoving", NaN);
stripRows = repmat(emptyRow, numStrips, 1);

for k = 1:numStrips
    fixedCols = fixedEdges(k):(fixedEdges(k + 1) - 1);
    movingCols = movingEdges(k):(movingEdges(k + 1) - 1);

    [fixedProfile, fixedOk] = makeVerticalProfile(fixed(:, fixedCols), opts);
    [movingProfile, movingOk] = makeVerticalProfile(moving(:, movingCols), opts);

    row = emptyRow;
    row.strip = k;
    row.fixedColumnStart = fixedCols(1);
    row.fixedColumnEnd = fixedCols(end);
    row.movingColumnStart = movingCols(1);
    row.movingColumnEnd = movingCols(end);
    row.profileLengthFixed = numel(fixedProfile);
    row.profileLengthMoving = numel(movingProfile);

    if fixedOk && movingOk
        maxLag = resolveMaxLag(opts, numel(fixedProfile));
        minOverlap = max(20, round(opts.MinOverlapFraction * ...
            min(numel(fixedProfile), numel(movingProfile))));
        [row.scale, row.verticalOffsetPixels, row.correlation, row.overlapPixels] = ...
            estimateProfileScale(fixedProfile, movingProfile, scales, maxLag, minOverlap);
    end

    stripRows(k) = row;
end

stripTable = struct2table(stripRows);
end

function [profile, isUsable] = makeVerticalProfile(strip, opts)
strip = robustNormalizeImage(strip, opts.ClipSigma);

switch opts.ProfileMode
    case "rowmean"
        profile = mean(strip, 2, "omitnan");
    case "signedgradient"
        profile = mean(diff(strip, 1, 1), 2, "omitnan");
    case "gradientenergy"
        profile = mean(abs(diff(strip, 1, 1)), 2, "omitnan");
    case "mixed"
        signedGradient = mean(diff(strip, 1, 1), 2, "omitnan");
        gradientEnergy = mean(abs(diff(strip, 1, 1)), 2, "omitnan");
        [signedGradient, signedOk] = standardizeProfile( ...
            highpassProfile(signedGradient, opts.ProfileHighpassWindow));
        [gradientEnergy, energyOk] = standardizeProfile( ...
            highpassProfile(gradientEnergy, opts.ProfileHighpassWindow));

        if signedOk && energyOk
            profile = signedGradient + 0.5 * gradientEnergy;
        elseif signedOk
            profile = signedGradient;
        else
            profile = gradientEnergy;
        end
        [profile, isUsable] = standardizeProfile(profile);
        return
    otherwise
        error("estimateVerticalScaleDifference:invalidProfileMode", ...
            "ProfileMode must be gradientEnergy, signedGradient, rowMean, or mixed.");
end

profile = highpassProfile(profile, opts.ProfileHighpassWindow);
[profile, isUsable] = standardizeProfile(profile);
end

function x = robustNormalizeImage(x, clipSigma)
x = single(x);
finiteMask = isfinite(x);

if ~any(finiteMask(:))
    x = zeros(size(x), "single");
    return
end

sample = x(finiteMask);
maxSamples = 1000000;
if numel(sample) > maxSamples
    sample = sample(round(linspace(1, numel(sample), maxSamples)));
end

sample = double(sample(:));
center = median(sample);
scale = 1.4826 * median(abs(sample - center));

if ~(isfinite(scale) && scale > 0)
    scale = std(sample);
end

if ~(isfinite(scale) && scale > 0)
    scale = 1;
end

x = (x - single(center)) ./ single(scale);
x(~finiteMask) = 0;
x = min(max(x, -single(clipSigma)), single(clipSigma));
end

function profile = highpassProfile(profile, windowSize)
profile = double(profile(:));

if isempty(windowSize)
    windowSize = max(21, round(0.02 * numel(profile)));
end

windowSize = max(3, round(windowSize));
if mod(windowSize, 2) == 0
    windowSize = windowSize + 1;
end

if numel(profile) > windowSize
    profile = profile - movmean(profile, windowSize, "Endpoints", "shrink");
else
    profile = profile - mean(profile, "omitnan");
end
end

function [profile, isUsable] = standardizeProfile(profile)
profile = double(profile(:));
finiteMask = isfinite(profile);

if ~any(finiteMask)
    profile = zeros(size(profile));
    isUsable = false;
    return
end

replacement = median(profile(finiteMask));
profile(~finiteMask) = replacement;
profile = profile - median(profile);

scale = 1.4826 * median(abs(profile));
if ~(isfinite(scale) && scale > 0)
    scale = std(profile);
end

if ~(isfinite(scale) && scale > 0)
    profile = zeros(size(profile));
    isUsable = false;
    return
end

profile = profile ./ scale;
profile = min(max(profile, -6), 6);
profile = profile - mean(profile);
rmsValue = sqrt(mean(profile .^ 2));
isUsable = isfinite(rmsValue) && rmsValue > 1e-8;

if isUsable
    profile = profile ./ rmsValue;
end
end

function maxLag = resolveMaxLag(opts, profileLength)
if isempty(opts.MaxVerticalOffsetPixels)
    maxLag = round(opts.MaxOffsetFraction * profileLength);
else
    maxLag = round(opts.MaxVerticalOffsetPixels);
end

maxLag = max(0, min(maxLag, profileLength - 1));
end

function [bestScale, bestShift, bestScore, bestOverlap] = estimateProfileScale( ...
    fixedProfile, movingProfile, scales, maxLag, minOverlap)
bestScale = NaN;
bestShift = NaN;
bestScore = -Inf;
bestOverlap = NaN;

for idx = 1:numel(scales)
    candidateScale = scales(idx);
    scaledMoving = resizeProfile(movingProfile, candidateScale);
    [score, shift, overlap] = bestNormalizedCorrelation( ...
        fixedProfile, scaledMoving, maxLag, minOverlap);

    if score > bestScore
        bestScale = candidateScale;
        bestShift = shift;
        bestScore = score;
        bestOverlap = overlap;
    end
end

if isinf(bestScore)
    bestScore = NaN;
end
end

function resized = resizeProfile(profile, scale)
profile = double(profile(:));
newLength = max(3, round(numel(profile) * scale));
query = linspace(1, numel(profile), newLength).';
resized = interp1((1:numel(profile)).', profile, query, "linear", "extrap");
[resized, ~] = standardizeProfile(resized);
end

function [bestScore, bestShift, bestOverlap] = bestNormalizedCorrelation( ...
    fixedProfile, movingProfile, maxLag, minOverlap)
fixedProfile = double(fixedProfile(:));
movingProfile = double(movingProfile(:));

numFixed = numel(fixedProfile);
numMoving = numel(movingProfile);

rawCorrelation = conv(fixedProfile, flipud(movingProfile), "full");
shifts = ((1:numel(rawCorrelation)) - numMoving).';

fixedEnergy = [0; cumsum(fixedProfile .^ 2)];
movingEnergy = [0; cumsum(movingProfile .^ 2)];

fixedStart = max(1, 1 + shifts);
fixedEnd = min(numFixed, numMoving + shifts);
movingStart = max(1, 1 - shifts);
movingEnd = min(numMoving, numFixed - shifts);
overlap = fixedEnd - fixedStart + 1;

valid = abs(shifts) <= maxLag & overlap >= minOverlap;
scores = -Inf(size(shifts));

if any(valid)
    validIndex = find(valid);
    sumFixed = fixedEnergy(fixedEnd(validIndex) + 1) - fixedEnergy(fixedStart(validIndex));
    sumMoving = movingEnergy(movingEnd(validIndex) + 1) - movingEnergy(movingStart(validIndex));
    denominator = sqrt(sumFixed .* sumMoving);
    goodDenominator = denominator > eps;
    validIndex = validIndex(goodDenominator);
    denominator = denominator(goodDenominator);
    scores(validIndex) = rawCorrelation(validIndex) ./ denominator;
end

[bestScore, bestIndex] = max(scores);
bestShift = shifts(bestIndex);
bestOverlap = overlap(bestIndex);
end

function [scale, usedMask, spread] = aggregateStripScales(stripTable, opts)
scales = stripTable.scale;
scores = stripTable.correlation;
valid = isfinite(scales) & isfinite(scores) & scores >= opts.MinCorrelation;

if nnz(valid) < 2
    valid = isfinite(scales) & isfinite(scores);
end

if ~any(valid)
    error("estimateVerticalScaleDifference:noValidStrips", ...
        "No usable strip estimates were found. Try ProfileMode=""rowMean"" or increase MaxWorkingWidth.");
end

weights = max(scores(valid), 0) .^ 2 + eps;
initialScale = weightedMedian(scales(valid), weights);
inlierMask = valid & abs(scales - initialScale) <= opts.OutlierTolerance;

if nnz(inlierMask) >= 2
    valid = inlierMask;
end

weights = max(scores(valid), 0) .^ 2 + eps;
scale = weightedMedian(scales(valid), weights);
spread = 1.4826 * median(abs(scales(valid) - scale));
usedMask = valid;
end

function value = weightedMedian(values, weights)
values = double(values(:));
weights = double(weights(:));
valid = isfinite(values) & isfinite(weights) & weights > 0;
values = values(valid);
weights = weights(valid);

if isempty(values)
    value = NaN;
    return
end

[values, order] = sort(values);
weights = weights(order);
cumulativeWeight = cumsum(weights);
cutoff = 0.5 * cumulativeWeight(end);
index = find(cumulativeWeight >= cutoff, 1, "first");
value = values(index);
end

function confidence = classifyConfidence(numUsed, correlation, scaleSpread)
if numUsed < 2 || ~isfinite(correlation) || correlation < 0.08 || scaleSpread > 0.01
    confidence = "low";
elseif correlation < 0.15 || scaleSpread > 0.003
    confidence = "moderate";
else
    confidence = "high";
end
end

function stripTable = addUsedColumn(stripTable, usedMask)
stripTable.usedForEstimate = usedMask(:);
end

function plotDiagnostics(result)
stripTable = result.stripTable;
figure("Name", "Vertical Scale Difference Diagnostics");

yyaxis left
plot(stripTable.strip, 100 * (stripTable.scale - 1), "o-", "LineWidth", 1.2);
ylabel("Scale difference (%)");
hold on
yline(result.percentDifference, "--", "Estimate");

yyaxis right
plot(stripTable.strip, stripTable.correlation, "s-", "LineWidth", 1.2);
ylabel("Correlation");

xlabel("Strip");
title("Per-strip vertical scale estimates");
grid on
end
