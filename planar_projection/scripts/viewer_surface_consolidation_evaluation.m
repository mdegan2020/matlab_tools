function summary = viewer_surface_consolidation_evaluation(options)
%viewer_surface_consolidation_evaluation Compare tiled and atlas alpha cost.
%
%   This renderer microbenchmark compares several adjacent texture-mapped
%   surfaces with one rectangular texture-atlas surface containing the same
%   texels. It isolates graphics-object/transparency cost; it does not claim
%   that irregular or curved projection coverage can always be consolidated.

if nargin < 1
    options = struct();
end
projectRoot = fileparts(fileparts(mfilename("fullpath")));
options = mergeOptions(options, projectRoot);
if options.WriteArtifacts && ~isfolder(options.OutputDirectory)
    mkdir(options.OutputDirectory);
end

tileTexture = createTileTexture(options.TileSize);
atlasTexture = repmat(tileTexture, ...
    options.TileGrid(1), options.TileGrid(2), 1);
tiledRecord = evaluateMode("tiled", tileTexture, atlasTexture, options);
atlasRecord = evaluateMode("atlas", tileTexture, atlasTexture, options);

summary = struct();
summary.Format = "ProjectionViewerSurfaceConsolidationEvaluation";
summary.Version = 1;
summary.TileGrid = options.TileGrid;
summary.TileSize = options.TileSize;
summary.Iterations = options.Iterations;
summary.Records = [tiledRecord atlasRecord];
summary.MedianSpeedup = tiledRecord.MedianSeconds / ...
    max(atlasRecord.MedianSeconds, eps);
summary.Limitations = [ ...
    "The atlas case uses one rectangular planar patch.", ...
    "Irregular visible coverage may require texture overfetch.", ...
    "Real projection meshes require equivalent geometry-error validation."];
summary.GeneratedAt = string(datetime("now", TimeZone="local", ...
    Format="yyyy-MM-dd'T'HH:mm:ssXXX"));

fprintf("Viewer surface consolidation evaluation\n");
fprintf("  tiled: %d surfaces, %.3f MiB, median %.3f ms, p95 %.3f ms\n", ...
    tiledRecord.SurfaceCount, tiledRecord.TextureBytes / 2^20, ...
    1000 * tiledRecord.MedianSeconds, 1000 * tiledRecord.P95Seconds);
fprintf("  atlas: %d surface,  %.3f MiB, median %.3f ms, p95 %.3f ms\n", ...
    atlasRecord.SurfaceCount, atlasRecord.TextureBytes / 2^20, ...
    1000 * atlasRecord.MedianSeconds, 1000 * atlasRecord.P95Seconds);
fprintf("  median speedup: %.2fx\n", summary.MedianSpeedup);

if options.WriteArtifacts
    writeArtifacts(summary, options.OutputDirectory);
end
end

function record = evaluateMode(mode, tileTexture, atlasTexture, options)
fig = uifigure(Name="Viewer Surface Consolidation Evaluation", ...
    Position=[100 100 options.FigureSize]);
cleanup = onCleanup(@() delete(fig));
ax = uiaxes(fig, Position=[1 1 options.FigureSize]);
hold(ax, "on");

switch mode
    case "tiled"
        surfaceHandles = createTiledSurfaces( ...
            ax, tileTexture, options.TileGrid);
        textureBytes = numel(surfaceHandles) * arrayBytes(tileTexture);
    case "atlas"
        surfaceHandles = createAtlasSurface( ...
            ax, atlasTexture, options.TileGrid);
        textureBytes = arrayBytes(atlasTexture);
    otherwise
        error("viewer_surface_consolidation_evaluation:invalidMode", ...
            "Unknown surface evaluation mode %s.", mode);
end

hold(ax, "off");
view(ax, 2);
axis(ax, "equal");
axis(ax, "tight");
ax.Visible = "off";
drawnow
set(surfaceHandles, "FaceAlpha", 0.5);
drawnow

samples = zeros(1, options.Iterations);
for k = 1:options.Iterations
    alpha = options.AlphaValues(1 + mod(k - 1, ...
        numel(options.AlphaValues)));
    frameTimer = tic;
    set(surfaceHandles, "FaceAlpha", alpha);
    drawnow
    samples(k) = toc(frameTimer);
end

sortedSamples = sort(samples);
record = struct(Mode=mode, SurfaceCount=numel(surfaceHandles), ...
    TextureBytes=textureBytes, MedianSeconds=median(samples), ...
    P95Seconds=sortedSamples(max(1, ceil(0.95 * numel(samples)))), ...
    MaximumSeconds=max(samples), SamplesSeconds=samples);
clear cleanup
end

function handles = createTiledSurfaces(ax, texture, tileGrid)
handles = gobjects(1, prod(tileGrid));
handleIndex = 0;
for rowIndex = 1:tileGrid(1)
    for columnIndex = 1:tileGrid(2)
        handleIndex = handleIndex + 1;
        xLimits = [columnIndex - 1, columnIndex];
        yLimits = [rowIndex - 1, rowIndex];
        handles(handleIndex) = surface(ax, ...
            [xLimits; xLimits], ...
            [yLimits(1) yLimits(1); yLimits(2) yLimits(2)], ...
            zeros(2), texture, FaceColor="texturemap", ...
            EdgeColor="none", LineStyle="none", FaceAlpha=1);
    end
end
end

function handle = createAtlasSurface(ax, texture, tileGrid)
xLimits = [0 tileGrid(2)];
yLimits = [0 tileGrid(1)];
handle = surface(ax, [xLimits; xLimits], ...
    [yLimits(1) yLimits(1); yLimits(2) yLimits(2)], ...
    zeros(2), texture, FaceColor="texturemap", ...
    EdgeColor="none", LineStyle="none", FaceAlpha=1);
end

function texture = createTileTexture(tileSize)
axisValues = single(linspace(0, 1, tileSize));
[x, y] = meshgrid(axisValues, axisValues);
gray = 0.5 * (x + y);
texture = repmat(gray, 1, 1, 3);
end

function options = mergeOptions(options, projectRoot)
if ~isstruct(options) || ~isscalar(options)
    error("viewer_surface_consolidation_evaluation:invalidOptions", ...
        "Options must be a scalar struct.");
end
defaults = struct(TileGrid=[3 4], TileSize=512, Iterations=12, ...
    AlphaValues=[0.2 0.5 0.8], FigureSize=[900 700], ...
    OutputDirectory=fullfile(projectRoot, ...
    "artifacts", "viewer_performance"), WriteArtifacts=true);
names = fieldnames(options);
for k = 1:numel(names)
    if ~isfield(defaults, names{k})
        error("viewer_surface_consolidation_evaluation:invalidOptions", ...
            "Unknown option %s.", names{k});
    end
    defaults.(names{k}) = options.(names{k});
end
defaults.TileGrid = validatePositiveIntegerVector( ...
    defaults.TileGrid, "TileGrid", 2);
defaults.TileSize = validatePositiveIntegerVector( ...
    defaults.TileSize, "TileSize", 1);
defaults.TileSize = defaults.TileSize(1);
defaults.Iterations = validatePositiveIntegerVector( ...
    defaults.Iterations, "Iterations", 1);
defaults.Iterations = defaults.Iterations(1);
defaults.FigureSize = validatePositiveIntegerVector( ...
    defaults.FigureSize, "FigureSize", 2);
if ~isnumeric(defaults.AlphaValues) || isempty(defaults.AlphaValues) || ...
        any(~isfinite(defaults.AlphaValues)) || ...
        any(defaults.AlphaValues <= 0 | defaults.AlphaValues >= 1)
    error("viewer_surface_consolidation_evaluation:invalidOptions", ...
        "AlphaValues must contain finite values strictly between zero and one.");
end
defaults.AlphaValues = double(defaults.AlphaValues(:).');
defaults.OutputDirectory = char(string(defaults.OutputDirectory));
if ~isscalar(defaults.WriteArtifacts) || ...
        ~(islogical(defaults.WriteArtifacts) || ...
        (isnumeric(defaults.WriteArtifacts) && ...
        any(defaults.WriteArtifacts == [0 1])))
    error("viewer_surface_consolidation_evaluation:invalidOptions", ...
        "WriteArtifacts must be a logical scalar.");
end
defaults.WriteArtifacts = logical(defaults.WriteArtifacts);
options = defaults;
end

function value = validatePositiveIntegerVector(value, name, count)
if ~isnumeric(value) || ~isvector(value) || numel(value) ~= count || ...
        any(~isfinite(value)) || any(value < 1) || any(fix(value) ~= value)
    error("viewer_surface_consolidation_evaluation:invalidOptions", ...
        "%s must be a positive integer vector with %d elements.", name, count);
end
value = double(reshape(value, 1, []));
end

function bytes = arrayBytes(value)
bytes = 4 * numel(value);
end

function writeArtifacts(summary, outputDirectory)
save(fullfile(outputDirectory, ...
    "viewer_surface_consolidation_evaluation.mat"), "summary", "-v7.3");
writelines(jsonencode(summary, PrettyPrint=true), ...
    fullfile(outputDirectory, ...
    "viewer_surface_consolidation_evaluation.json"));
records = summary.Records;
mode = [records.Mode].';
surfaceCount = [records.SurfaceCount].';
textureBytes = [records.TextureBytes].';
medianSeconds = [records.MedianSeconds].';
p95Seconds = [records.P95Seconds].';
maximumSeconds = [records.MaximumSeconds].';
resultTable = table(mode, surfaceCount, textureBytes, medianSeconds, ...
    p95Seconds, maximumSeconds);
writetable(resultTable, fullfile(outputDirectory, ...
    "viewer_surface_consolidation_evaluation.csv"));
end
