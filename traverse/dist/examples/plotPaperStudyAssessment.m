function report = plotPaperStudyAssessment(options)
%PLOTPAPERSTUDYASSESSMENT Plot the immutable P2 held-out outcome.
%
% This function reads the committed result artifact. It never renders a scene,
% evaluates a cost, changes a threshold, or accesses the held-out case table.
%
% Traceability: algo/main.tex Sec. 11; docs/implementation_plan.md P2 step 4;
% docs/paper_study_preregistration.md statistical analysis plan.

arguments
    options.SourceFile (1, 1) string {mustBeFile} = defaultResultFile
    options.OutputFile (1, 1) string = defaultFigureFile
    options.Visible (1, 1) logical = false
end

a = jsondecode(fileread(options.SourceFile));
p = a.primaryStatistics;
d = a.denseComparisons;
r = a.researchDirectionDecisions;

dirs = string({p.Direction}).';
imp = 100 .* numericField(p, "RelativeImprovement");
lo = 100 .* numericField(p, "HolmCorrectedLowerRelativeImprovement");
hi = 100 .* numericField(p, "HolmCorrectedUpperRelativeImprovement");
cov = numericField(p, "MeanCoverageLoss");
worst = numericField(p, "MaximumSceneEpeIncreasePixels");

if options.Visible
    vis = "on";
else
    vis = "off";
end
fig = figure(Visible=vis, Color="w", Position=[100, 100, 1320, 820]);
layout = tiledlayout(fig, 2, 2, TileSpacing="compact", Padding="compact");
heading = title(layout, sprintf( ...
    "P2 synthetic held-out assessment\n" + ...
    "12 scenes; implementation %s; single preregistered run", ...
    string(a.sourceImplementationCommit)), FontWeight="bold");
heading.Color = [0.12, 0.12, 0.12];

ax = nexttile(layout);
b = bar(ax, 1:numel(dirs), imp, 0.68, FaceColor=[0.16, 0.43, 0.62]);
b.DisplayName = "Mean relative improvement";
hold(ax, "on");
errorbar(ax, 1:numel(dirs), imp, imp - lo, hi - imp, ...
    LineStyle="none", Color=[0.12, 0.12, 0.12], LineWidth=1.2, ...
    CapSize=8, DisplayName="Holm-corrected interval");
yline(ax, 0, Color=[0.30, 0.30, 0.30], HandleVisibility="off");
yline(ax, 5, "--", "5% minimum", Color=[0.72, 0.30, 0.16], ...
    LabelHorizontalAlignment="right", HandleVisibility="off");
text(ax, find(~isfinite(imp)), zeros(nnz(~isfinite(imp)), 1), ...
    "Incomplete", HorizontalAlignment="center", VerticalAlignment="bottom", ...
    FontWeight="bold", Color=[0.18, 0.18, 0.18]);
hold(ax, "off");
xticks(ax, 1:numel(dirs));
xticklabels(ax, dirs);
ylabel(ax, "Endpoint-EPE improvement (%)");
title(ax, "Primary sparse comparisons");
grid(ax, "on");
styleAxes(ax);
styleLegend(legend(ax, Location="southoutside", Orientation="horizontal"));

ax = nexttile(layout);
gate = [cov ./ 0.02, worst ./ 0.1];
bar(ax, 1:numel(dirs), gate, "grouped");
hold(ax, "on");
yline(ax, 1, "--", "maximum allowed", Color=[0.72, 0.30, 0.16], ...
    LabelHorizontalAlignment="right", HandleVisibility="off");
hold(ax, "off");
xticks(ax, 1:numel(dirs));
xticklabels(ax, dirs);
ylabel(ax, "Observed value / allowed maximum");
title(ax, "Common gate burden (lower is better)");
styleLegend(legend(ax, ["Coverage loss / 0.02", ...
    "Worst scene increase / 0.1 px"], Location="northwest"));
grid(ax, "on");
styleAxes(ax);

dd = string({d.Direction}).';
ds = string({d.Stage}).';
denseDirs = ["RD1", "RD3"];
dense = NaN(2, 2);
for k = 1:numel(denseDirs)
    dense(k, 1) = 100 .* numericField(d(dd == denseDirs(k) ...
        & ds == "RawWta"), "RelativeImprovement");
    dense(k, 2) = 100 .* numericField(d(dd == denseDirs(k) ...
        & ds == "FrozenSgm"), "RelativeImprovement");
end
ax = nexttile(layout);
bar(ax, 1:numel(denseDirs), dense, "grouped");
hold(ax, "on");
yline(ax, 0, Color=[0.30, 0.30, 0.30], HandleVisibility="off");
hold(ax, "off");
xticks(ax, 1:numel(denseDirs));
xticklabels(ax, ["RD1 point spin-2 vs T0", ...
    "RD3 gated {1,2,4} vs T3"]);
xtickangle(ax, 12);
ylabel(ax, "Endpoint-EPE improvement (%)");
title(ax, "Dense descriptive comparisons");
styleLegend(legend(ax, ["Raw WTA", "Frozen SGM"], ...
    Location="northoutside", Orientation="horizontal"));
grid(ax, "on");
styleAxes(ax);

rd3 = r(string({r.Direction}) == "RD3");
regime = [imp(dirs == "RD3"); ...
    100 .* rd3.Metric1Value; 100 .* rd3.Metric2Value];
ax = nexttile(layout);
bar(ax, 1:3, regime, 0.68, FaceColor=[0.15, 0.50, 0.45]);
hold(ax, "on");
yline(ax, 5, "--", "5% minimum", Color=[0.72, 0.30, 0.16], ...
    LabelHorizontalAlignment="right", HandleVisibility="off");
hold(ax, "off");
xticks(ax, 1:3);
xticklabels(ax, ["All scenes", "Normal radiometry", "Polarity reversed"]);
xtickangle(ax, 12);
ylabel(ax, "Endpoint-EPE improvement (%)");
title(ax, "RD3 known-factor diagnostic");
text(ax, 0.03, 0.96, sprintf("Runtime %.3fx (limit %.1fx); diagnostic-only", ...
    rd3.Metric3Value, rd3.Metric3Threshold), Units="normalized", ...
    VerticalAlignment="top", FontWeight="bold", Color=[0.18, 0.18, 0.18]);
grid(ax, "on");
styleAxes(ax);

if strlength(options.OutputFile) > 0
    folder = string(fileparts(options.OutputFile));
    if strlength(folder) > 0 && ~isfolder(folder)
        mkdir(folder);
    end
    exportgraphics(fig, options.OutputFile, Resolution=180);
end

report = struct( ...
    "Figure", fig, ...
    "SourceFile", options.SourceFile, ...
    "OutputFile", options.OutputFile, ...
    "Primary", table(dirs, imp, lo, hi, cov, worst, ...
        VariableNames=["Direction", "RelativeImprovementPercent", ...
        "CorrectedLowerPercent", "CorrectedUpperPercent", ...
        "CoverageLoss", "MaximumSceneIncreasePixels"]), ...
    "DenseDirections", denseDirs, ...
    "DenseRelativeImprovementPercent", dense, ...
    "Rd3RegimeImprovementPercent", regime, ...
    "Definition", "post-study rendering of committed evidence only");
end

function styleAxes(ax)
ax.Color = [1, 1, 1];
ax.XColor = [0.18, 0.18, 0.18];
ax.YColor = [0.18, 0.18, 0.18];
ax.GridColor = [0.78, 0.78, 0.78];
ax.GridAlpha = 0.55;
ax.Title.Color = [0.12, 0.12, 0.12];
ax.XLabel.Color = [0.18, 0.18, 0.18];
ax.YLabel.Color = [0.18, 0.18, 0.18];
end

function styleLegend(lgd)
lgd.Color = [1, 1, 1];
lgd.TextColor = [0.18, 0.18, 0.18];
lgd.EdgeColor = [0.60, 0.60, 0.60];
end

function x = numericField(s, name)
x = NaN(numel(s), 1);
for k = 1:numel(s)
    v = s(k).(name);
    if isnumeric(v) && isscalar(v)
        x(k) = double(v);
    end
end
end

function file = defaultResultFile()
root = fileparts(fileparts(mfilename("fullpath")));
file = string(fullfile(root, "config", "synthetic", ...
    "paper_study_heldout_v1.json"));
end

function file = defaultFigureFile()
root = fileparts(fileparts(mfilename("fullpath")));
file = string(fullfile(root, "docs", "figures", ...
    "paper_study_heldout_v1.png"));
end
