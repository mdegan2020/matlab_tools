function report = runPhaseARadiometryMatrix(options)
%RUNPHASEARADIOMETRYMATRIX Compare raw costs under radiometric controls.
%
% The reference image, exact camera geometry, elevation labels, patch support,
% and 10-/12-bit quantization are held fixed. Only the moving image radiometry
% changes. Traceability: algo/main.tex Secs. 10.1-10.2 and 10.4, and Stage 1
% in Sec. 14.2. No hybrid score or regularization is evaluated.

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
pair = renderer.renderPair;
geom = HeightSweepGeometry( ...
    renderer.ReferenceCamera, renderer.MovingCamera);
p = radiometrySamplePixels(renderer.ImageSize);
[~, kappa, valid] = PinholePlaneOracle.heightDerivative( ...
    renderer.ReferenceCamera, renderer.MovingCamera, p, ...
    renderer.TrueHeightMetres);
step = renderer.TargetMotionPerLabelPixels ./ median(kappa(valid));
z = radiometryHeightLabels(renderer.SearchRangeMetres, step);
levels = 2 ^ renderer.BitDepth - 1;
r = double(pair.ReferenceImage) ./ levels;

names = ["identity", "gain-offset", "gamma", "blur", "noise", ...
    "polarity"];
cases = repmat(struct( ...
    "Name", "", "MovingImage", uint16.empty, "CostCurve", struct, ...
    "Metrics", struct, "Seconds", NaN), numel(names), 1);
for k = 1:numel(names)
    m = SyntheticRadiometry.apply(pair.MovingImage, ...
        renderer.BitDepth, names(k), Seed=renderer.TextureSeed + 101);
    curve = HeightCostCurve(geom, r, double(m) ./ levels, ...
        DerivativeSigma=1, IntegrationSigma=2, ...
        ReferenceValid=pair.ReferenceValid, MovingValid=pair.MovingValid);
    timer = tic;
    cost = curve.evaluate(p, z, MinimumSupportFraction=0.95);
    seconds = toc(timer);
    metrics = HeightCostMetrics.analyze(cost, ...
        repmat(renderer.TrueHeightMetres, size(p, 1), 1));
    cases(k) = struct( ...
        "Name", names(k), "MovingImage", m, "CostCurve", cost, ...
        "Metrics", metrics, "Seconds", seconds);
end

channels = string(fieldnames(cases(1).CostCurve.Costs));
nc = numel(channels);
ns = numel(names);
error = nan(ns, nc);
rank = nan(ns, nc);
percentile = nan(ns, nc);
margin = nan(ns, nc);
for i = 1:ns
    for j = 1:nc
        q = cases(i).Metrics.(channels(j));
        error(i, j) = q.SelectedHeightErrorMetres(3);
        rank(i, j) = q.TruthLabelRank(3);
        percentile(i, j) = q.TruthCostPercentile(3);
        margin(i, j) = q.DistinctMinimumMargin(3);
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
    "CenterTruthCostPercentile", percentile, ...
    "CenterDistinctMinimumMargin", margin, ...
    "TotalSeconds", sum([cases.Seconds]));

fprintf("Phase A radiometry matrix: %s, %d scenarios, %d channels\n", ...
    renderer.Identifier, ns, nc);
fprintf("  Center values are [selected error m / truth rank]:\n");
fprintf("  %-12s", "scenario");
fprintf(" %18s", channels);
fprintf("\n");
for i = 1:ns
    fprintf("  %-12s", names(i));
    for j = 1:nc
        fprintf(" %8.2f/%-8.0f", error(i, j), rank(i, j));
    end
    fprintf("\n");
end
fprintf("  Sparse cost runtime: %.3f s\n", report.TotalSeconds);

if options.Display
    showRadiometryCurves(report, renderer.TrueHeightMetres);
end

clear cleanup
end

function p = radiometrySamplePixels(imageSize)
cx = (imageSize(2) + 1) / 2;
cy = (imageSize(1) + 1) / 2;
d = 0.18 .* [imageSize(2), imageSize(1)];
p = [cx - d(1), cy; cx, cy - d(2); cx, cy; ...
    cx, cy + d(2); cx + d(1), cy];
end

function z = radiometryHeightLabels(range, step)
n0 = floor(abs(range(1)) / step);
n1 = floor(abs(range(2)) / step);
z = (-n0:n1) .* step;
end

function showRadiometryCurves(report, truth)
figure(Name="Phase A radiometry raw height costs");
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
