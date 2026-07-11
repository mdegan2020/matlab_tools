function demo_estimateVerticalScaleDifference
%DEMO_ESTIMATEVERTICALSCALEDIFFERENCE Synthetic example for the estimator.

originalRng = rng;
cleanup = onCleanup(@() rng(originalRng));
rng(11, "twister");

fixedHeight = 1600;
width = 3000;
trueScaleMovingToFixed = 1.0275;

base = randn(fixedHeight, width, "single");
base = conv2(base, ones(5, 5, "single") / 25, "same");

rowPattern = single(0.8 * sin((1:fixedHeight)' / 21) + 0.4 * cos((1:fixedHeight)' / 57));
colPattern = single(0.5 * sin((1:width) / 43));
fixedImage = base + rowPattern + colPattern;

movingImage = resizeRows(fixedImage, 1 / trueScaleMovingToFixed);
movingImage = 1.15 * movingImage + 0.15 * randn(size(movingImage), "single");

result = estimateVerticalScaleDifference( ...
    fixedImage, movingImage, ...
    "ScaleRange", [0.98 1.05], ...
    "MaxWorkingWidth", 1800, ...
    "NumStrips", 7, ...
    "ProfileMode", "mixed");

fprintf("True moving-to-fixed vertical scale:      %.6f\n", trueScaleMovingToFixed);
fprintf("Estimated moving-to-fixed vertical scale: %.6f\n", result.scaleMovingToFixed);
fprintf("Estimated difference:                     %.4f%%\n", result.percentDifference);
fprintf("Confidence:                               %s\n", result.confidence);
end

function resized = resizeRows(imageIn, scale)
newHeight = max(3, round(size(imageIn, 1) * scale));
queryRows = linspace(1, size(imageIn, 1), newHeight).';
resized = interp1((1:size(imageIn, 1)).', double(imageIn), queryRows, "linear", "extrap");
resized = single(resized);
end
