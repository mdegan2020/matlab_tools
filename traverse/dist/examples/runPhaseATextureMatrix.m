function report = runPhaseATextureMatrix(options)
%RUNPHASEATEXTUREMATRIX Compare raw costs across world-texture families.
%
% Camera geometry, image formation, bit depth, patch support, and height labels
% are identical for every case. Traceability: algo/main.tex Secs. 10.1-10.2
% and 10.4, and Stage 1 in Sec. 14.2. Invalid low-texture results stay invalid.

arguments
    options.ConfigFile (1, 1) string = ""
    options.Display (1, 1) logical = true
end

root = fileparts(fileparts(mfilename("fullpath")));
oldPath = path;
addpath(fullfile(root, "src"));
cleanup = onCleanup(@() path(oldPath));
if strlength(options.ConfigFile) == 0
    options.ConfigFile = fullfile(root, "config", "synthetic", ...
        "pinhole_smoke_96_v1.json");
end

renderer = SyntheticPinholeRenderer.fromJson(options.ConfigFile);
geom = HeightSweepGeometry( ...
    renderer.ReferenceCamera, renderer.MovingCamera);
p = textureSamplePixels(renderer.ImageSize);
[~, kappa, valid] = PinholePlaneOracle.heightDerivative( ...
    renderer.ReferenceCamera, renderer.MovingCamera, p, ...
    renderer.TrueHeightMetres);
step = renderer.TargetMotionPerLabelPixels ./ median(kappa(valid));
z = textureHeightLabels(renderer.SearchRangeMetres, step);
levels = 2 ^ renderer.BitDepth - 1;
names = ["natural", "single-edge", "corner", "grid", "repeated", ...
    "low-texture"];

cases = repmat(struct( ...
    "Name", "", "ReferenceImage", uint16.empty, ...
    "MovingImage", uint16.empty, "CostCurve", struct, ...
    "Metrics", struct, "RenderSeconds", NaN, "CostSeconds", NaN), ...
    numel(names), 1);
for k = 1:numel(names)
    timer = tic;
    pair = renderer.renderPair(TextureType=names(k));
    renderSeconds = toc(timer);
    curve = HeightCostCurve(geom, ...
        double(pair.ReferenceImage) ./ levels, ...
        double(pair.MovingImage) ./ levels, ...
        DerivativeSigma=1, IntegrationSigma=2, ...
        ReferenceValid=pair.ReferenceValid, MovingValid=pair.MovingValid);
    timer = tic;
    cost = curve.evaluate(p, z, MinimumSupportFraction=0.95);
    costSeconds = toc(timer);
    metrics = HeightCostMetrics.analyze(cost, ...
        repmat(renderer.TrueHeightMetres, size(p, 1), 1));
    cases(k) = struct( ...
        "Name", names(k), ...
        "ReferenceImage", pair.ReferenceImage, ...
        "MovingImage", pair.MovingImage, ...
        "CostCurve", cost, "Metrics", metrics, ...
        "RenderSeconds", renderSeconds, "CostSeconds", costSeconds);
end

channels = string(fieldnames(cases(1).CostCurve.Costs));
ns = numel(names);
nc = numel(channels);
error = nan(ns, nc);
rank = nan(ns, nc);
validFraction = zeros(ns, nc);
uniqueBestFraction = nan(ns, nc);
for i = 1:ns
    for j = 1:nc
        q = cases(i).Metrics.(channels(j));
        error(i, j) = q.SelectedHeightErrorMetres(3);
        rank(i, j) = q.TruthLabelRank(3);
        good = isfinite(q.TruthLabelRank);
        validFraction(i, j) = mean(good);
        if any(good)
            uniqueBestFraction(i, j) = mean(q.IsUniqueTruthBest(good));
        end
    end
end

report = struct( ...
    "ConfigurationIdentifier", renderer.Identifier, ...
    "ScenarioNames", names, ...
    "ChannelNames", channels, ...
    "SamplePixels", p, ...
    "HeightLabelsMetres", z, ...
    "Cases", cases, ...
    "CenterSelectedHeightErrorMetres", error, ...
    "CenterTruthLabelRank", rank, ...
    "ValidPointFraction", validFraction, ...
    "UniqueTruthBestFraction", uniqueBestFraction, ...
    "TotalRenderSeconds", sum([cases.RenderSeconds]), ...
    "TotalCostSeconds", sum([cases.CostSeconds]));

fprintf("Phase A texture matrix: %s, %d textures, %d channels\n", ...
    renderer.Identifier, ns, nc);
fprintf("  Center values are [selected error m / truth rank]:\n");
fprintf("  %-12s", "texture");
fprintf(" %18s", channels);
fprintf("\n");
for i = 1:ns
    fprintf("  %-12s", names(i));
    for j = 1:nc
        fprintf(" %8.2f/%-8.0f", error(i, j), rank(i, j));
    end
    fprintf("\n");
end
fprintf("  Valid-point/unique-truth-best fractions by channel:\n");
for i = 1:ns
    fprintf("  %-12s", names(i));
    for j = 1:nc
        fprintf(" %5.2f/%-5.2f", ...
            validFraction(i, j), uniqueBestFraction(i, j));
    end
    fprintf("\n");
end
fprintf("  Runtime: render %.3f s, sparse costs %.3f s\n", ...
    report.TotalRenderSeconds, report.TotalCostSeconds);

if options.Display
    showTextureImages(report, renderer.BitDepth);
    showTextureCurves(report, renderer.TrueHeightMetres);
end

clear cleanup
end

function p = textureSamplePixels(imageSize)
cx = (imageSize(2) + 1) / 2;
cy = (imageSize(1) + 1) / 2;
d = 0.18 .* [imageSize(2), imageSize(1)];
p = [cx - d(1), cy; cx, cy - d(2); cx, cy; ...
    cx, cy + d(2); cx + d(1), cy];
end

function z = textureHeightLabels(range, step)
n0 = floor(abs(range(1)) / step);
n1 = floor(abs(range(2)) / step);
z = (-n0:n1) .* step;
end

function showTextureImages(report, bitDepth)
fig = uifigure(Name="Phase A texture families", ...
    Position=[80, 80, 1200, 700]);
grid = uigridlayout(fig, [2, 3]);
mode = string(bitDepth) + "-bit";
for k = 1:numel(report.Cases)
    v = viewer2d(grid);
    title(v, report.ScenarioNames(k));
    imageshow(report.Cases(k).ReferenceImage, Parent=v, ...
        DisplayRangeMode=mode);
end
end

function showTextureCurves(report, truth)
figure(Name="Phase A texture raw height costs");
tiledlayout(2, 3);
for i = 1:numel(report.Cases)
    nexttile;
    hold on;
    for j = 1:numel(report.ChannelNames)
        name = report.ChannelNames(j);
        plot(report.HeightLabelsMetres, ...
            report.Cases(i).CostCurve.Costs.(name)(3, :), ...
            LineWidth=1);
    end
    xline(truth, "--k", "Truth");
    grid on;
    xlabel("Elevation Z (m)");
    ylabel("Unregularized cost");
    title(report.ScenarioNames(i));
end
legend(report.ChannelNames, Location="eastoutside");
end
