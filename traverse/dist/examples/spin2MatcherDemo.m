function [result, accuracy] = spin2MatcherDemo
%SPIN2MATCHERDEMO Run a deterministic translated-image diagnostic.

projectRoot = fileparts(fileparts(mfilename("fullpath")));
addpath(fullfile(projectRoot, "src"));
pathCleanup = onCleanup(@() rmpath(fullfile(projectRoot, "src")));

imageHeight = 160;
imageWidth = 192;
[x, y] = meshgrid(single(1:imageWidth), single(1:imageHeight));
texture = sin(single(0.11) .* x + single(0.03) .* y) ...
    + single(0.7) .* cos(single(0.05) .* x - single(0.13) .* y) ...
    + single(0.5) .* sin(single(0.009) .* x .* y);
texture = (texture - min(texture, [], "all")) ...
    ./ (max(texture, [], "all") - min(texture, [], "all"));
referenceImage = uint8(round(single(255) .* texture));

expectedDx = 5;
expectedDy = -3;
sourceImage = zeros(size(referenceImage), "uint8");
referenceRows = (1-expectedDy):imageHeight;
referenceColumns = 1:(imageWidth-expectedDx);
sourceImage(referenceRows + expectedDy, ...
    referenceColumns + expectedDx) = referenceImage( ...
    referenceRows, referenceColumns);

matcher = Spin2Matcher(referenceImage, sourceImage);
matcher.prepareComplexGradients;
[dx, dy] = meshgrid(-7:7, -5:5);
result = matcher.match([dx(:), dy(:)], ...
    PatchRadius=5, Stride=8, TileSize=[64, 64]);

trustedRows = result.ReferenceY + expectedDy >= 6 ...
    & result.ReferenceY + expectedDy <= imageHeight - 5;
trustedColumns = result.ReferenceX + expectedDx >= 6 ...
    & result.ReferenceX + expectedDx <= imageWidth - 5;
trusted = result.Valid & trustedRows & trustedColumns;
correct = result.DisplacementX == expectedDx ...
    & result.DisplacementY == expectedDy;
accuracy = mean(correct(trusted));
fprintf("Trusted-grid displacement accuracy: %.2f%%\n", 100 * accuracy);

[referenceX, referenceY] = meshgrid( ...
    result.ReferenceX, result.ReferenceY);
figure(Name="Spin-2 matcher diagnostic");
tiledlayout(1, 3, Padding="compact", TileSpacing="compact");
nexttile;
imagesc(referenceImage);
axis image;
title("Reference");
nexttile;
imagesc(sourceImage);
axis image;
title("Source");
nexttile;
imagesc(referenceImage);
axis image;
hold on;
quiver(referenceX(result.Valid), referenceY(result.Valid), ...
    result.DisplacementX(result.Valid), ...
    result.DisplacementY(result.Valid), 0, "r");
title(sprintf("Matches (%.1f%% correct)", 100 * accuracy));
colormap gray;
end
