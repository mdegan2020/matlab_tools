function [summary, app] = viewer_performance_evaluation(options)
%viewer_performance_evaluation Run repeatable viewer interaction scenarios.
%
%   summary = viewer_performance_evaluation() runs alpha, crosshair, twist,
%   pan, zoom, WASD, and OPK scenarios against local TIFF fixtures when
%   available, or a deterministic synthetic single-channel scene otherwise.
%   Machine-specific artifacts are written below artifacts/viewer_performance.
%
%   [summary, app] = viewer_performance_evaluation(options) leaves the app
%   open for inspection. Supported options are ImagePaths, SyntheticImageSize,
%   ScenarioIterations, LodBoundaryAngles, UseSynthetic, SceneOptions,
%   OutputDirectory, WriteArtifacts, and KeepAppOpen.

if nargin < 1
    options = struct();
end

projectRoot = fileparts(fileparts(mfilename("fullpath")));
addpath(projectRoot);
addpath(fullfile(projectRoot, "src"));
options = mergeOptions(options, projectRoot);
if options.WriteArtifacts && ~isfolder(options.OutputDirectory)
    mkdir(options.OutputDirectory);
end

[scene, fixture] = createEvaluationScene(options, projectRoot);
launchTimer = tic;
app = ProjectionViewerApp(scene);
drawnow
launchSeconds = toc(launchTimer);
if nargout < 2 && ~options.KeepAppOpen
    cleanup = onCleanup(@() delete(app));
end

initialState = app.exportState();
initialDiagnostics = app.performanceDiagnostics();
scenarioNames = ["alpha", "crosshair", "twist", "pan", "zoomSlow", ...
    "zoomFast", "zoomReverse", "wasd", "opk"];
records = repmat(struct(Name="", ActiveWallSeconds=0, WallSeconds=0, ...
    ActiveDiagnostics=struct(), Diagnostics=struct(), Trace=struct()), ...
    1, numel(scenarioNames));

for scenarioIndex = 1:numel(scenarioNames)
    app.importState(initialState);
    drawnow
    app.resetPerformanceDiagnostics();
    scenarioTimer = tic;
    trace = runScenario(app, scenarioNames(scenarioIndex), options);
    drawnow
    activeWallSeconds = toc(scenarioTimer);
    activeDiagnostics = app.performanceDiagnostics();
    app.flushPreviewUpdates();
    drawnow
    records(scenarioIndex).Name = scenarioNames(scenarioIndex);
    records(scenarioIndex).ActiveWallSeconds = activeWallSeconds;
    records(scenarioIndex).WallSeconds = toc(scenarioTimer);
    records(scenarioIndex).ActiveDiagnostics = activeDiagnostics;
    records(scenarioIndex).Diagnostics = app.performanceDiagnostics();
    records(scenarioIndex).Trace = trace;
end

app.importState(initialState);
drawnow
finalState = app.exportState();

summary = struct();
summary.Format = "ProjectionViewerPerformanceEvaluation";
summary.Version = 1;
summary.Fixture = fixture;
summary.LaunchSeconds = launchSeconds;
summary.InitialDiagnostics = initialDiagnostics;
summary.Scenarios = records;
summary.FinalStateMatchesInitial = isequaln(finalState, initialState);
summary.GeneratedAt = string(datetime("now", TimeZone="local", ...
    Format="yyyy-MM-dd'T'HH:mm:ssXXX"));

printSummary(summary);
if options.WriteArtifacts
    writeArtifacts(summary, options.OutputDirectory);
end
if exist("cleanup", "var")
    clear cleanup
end
end

function options = mergeOptions(options, projectRoot)
if isempty(options)
    options = struct();
end
if ~isstruct(options) || ~isscalar(options)
    error("viewer_performance_evaluation:invalidOptions", ...
        "Options must be a scalar struct.");
end

defaults = struct();
defaults.ImagePaths = strings(1, 0);
defaults.SyntheticImageSize = [2048 2048];
defaults.ScenarioIterations = 6;
defaults.LodBoundaryAngles = [15 14.5];
defaults.UseSynthetic = false;
defaults.SceneOptions = struct(RowStride=64, ColumnStride=64, ...
    DisplayTextureMaxPixels=2e6, GSD=0.01, NominalRange=1e6, ...
    PlatformStepMeters=0.01);
defaults.OutputDirectory = fullfile(projectRoot, ...
    "artifacts", "viewer_performance");
defaults.WriteArtifacts = true;
defaults.KeepAppOpen = false;

names = fieldnames(options);
for k = 1:numel(names)
    defaults.(names{k}) = options.(names{k});
end

defaults.ImagePaths = reshape(string(defaults.ImagePaths), 1, []);
defaults.SyntheticImageSize = validatePositiveIntegerVector( ...
    defaults.SyntheticImageSize, "SyntheticImageSize", 2);
defaults.ScenarioIterations = validatePositiveIntegerScalar( ...
    defaults.ScenarioIterations, "ScenarioIterations");
defaults.LodBoundaryAngles = validatePositiveFiniteVector( ...
    defaults.LodBoundaryAngles, "LodBoundaryAngles", 2);
defaults.UseSynthetic = validateLogicalScalar( ...
    defaults.UseSynthetic, "UseSynthetic");
if ~isstruct(defaults.SceneOptions) || ~isscalar(defaults.SceneOptions)
    error("viewer_performance_evaluation:invalidOptions", ...
        "SceneOptions must be a scalar struct.");
end
defaults.OutputDirectory = char(string(defaults.OutputDirectory));
defaults.WriteArtifacts = validateLogicalScalar( ...
    defaults.WriteArtifacts, "WriteArtifacts");
defaults.KeepAppOpen = validateLogicalScalar( ...
    defaults.KeepAppOpen, "KeepAppOpen");
options = defaults;
end

function [scene, fixture] = createEvaluationScene(options, projectRoot)
imagePaths = options.ImagePaths;
if isempty(imagePaths) && ~options.UseSynthetic
    defaultPaths = [string(fullfile(projectRoot, "test_data", "10.tif")), ...
        string(fullfile(projectRoot, "test_data", "102.tif"))];
    if all(isfile(defaultPaths))
        imagePaths = defaultPaths;
    end
end

if ~isempty(imagePaths)
    if any(~isfile(imagePaths))
        error("viewer_performance_evaluation:missingImage", ...
            "Every ImagePaths entry must identify an existing image.");
    end
    images = cellfun(@imread, cellstr(imagePaths), UniformOutput=false);
    names = arrayfun(@fileName, imagePaths);
    scene = ProjectionViewerHarness.createSceneFromImages( ...
        images, names, options.SceneOptions);
    fixture = struct();
    fixture.Source = "files";
    fixture.ImagePaths = imagePaths;
    fixture.ImageSizes = cellfun(@imageSize, images, UniformOutput=false);
    return
end

rows = options.SyntheticImageSize(1);
columns = options.SyntheticImageSize(2);
[x, y] = meshgrid(uint32(1:columns), uint32(1:rows));
firstImage = uint8(mod(3 * x + 5 * y, 256));
secondImage = circshift(firstImage, [7 11]);
scene = ProjectionViewerHarness.createSceneFromImages( ...
    {firstImage, secondImage}, ...
    ["synthetic_1.tif", "synthetic_2.tif"], options.SceneOptions);
fixture = struct();
fixture.Source = "synthetic";
fixture.ImagePaths = strings(1, 0);
fixture.ImageSizes = {imageSize(firstImage), imageSize(secondImage)};
end

function trace = runScenario(app, name, options)
fig = findall(groot, "Type", "figure", ...
    "Name", "Projection Viewer Prototype");
ax = findall(fig, "Type", "axes");
center = axesCenterPoint(ax);
iterations = options.ScenarioIterations;
trace = struct();

switch name
    case "alpha"
        runAlphaScenario(fig, iterations);
    case "crosshair"
        runCrosshairScenario(fig, center, iterations);
    case "twist"
        runTwistScenario(fig, iterations);
    case "pan"
        runPanScenario(fig, center, iterations);
    case "zoomSlow"
        trace = runZoomBoundaryScenario( ...
            app, fig, ax, center, options.LodBoundaryAngles, "slow");
    case "zoomFast"
        trace = runZoomBoundaryScenario( ...
            app, fig, ax, center, options.LodBoundaryAngles, "fast");
    case "zoomReverse"
        trace = runZoomBoundaryScenario( ...
            app, fig, ax, center, options.LodBoundaryAngles, "reverse");
    case "wasd"
        runKeyPairScenario(fig, "w", "s", iterations);
    case "opk"
        runKeyPairScenario(fig, "i", "k", iterations);
    otherwise
        error("viewer_performance_evaluation:unknownScenario", ...
            "Unknown viewer scenario %s.", name);
end
drawnow
end

function runAlphaScenario(fig, iterations)
slider = findSliderInColumn(fig, 5);
for k = 1:iterations
    value = 0.25 + 0.5 * mod(k, 2);
    slider.ValueChangingFcn(slider, struct(Value=value));
end
end

function runCrosshairScenario(fig, center, iterations)
menuItem = findall(fig, "Tag", "ProjectionViewerCrosshairMenuItem");
menuItem.MenuSelectedFcn(menuItem, struct());
for k = 1:iterations
    fig.CurrentPoint = center + [mod(k, 3) - 1, mod(k, 2)];
    fig.WindowButtonMotionFcn(fig, struct());
end
menuItem.MenuSelectedFcn(menuItem, struct());
end

function runTwistScenario(fig, iterations)
slider = findSliderInColumn(fig, 4);
for k = 1:iterations
    value = 3 * (-1) ^ k;
    slider.ValueChangingFcn(slider, struct(Value=value));
end
end

function runPanScenario(fig, center, iterations)
fig.SelectionType = "normal";
for k = 1:iterations
    direction = (-1) ^ k;
    fig.CurrentPoint = center;
    fig.WindowButtonDownFcn(fig, struct());
    fig.CurrentPoint = center + direction * [6 4];
    fig.WindowButtonMotionFcn(fig, struct());
    fig.WindowButtonUpFcn(fig, struct());
end
end

function trace = runZoomBoundaryScenario(app, fig, ax, center, ...
        boundaryAngles, mode)
fig.CurrentPoint = center;
switch mode
    case {"slow", "fast"}
        angles = boundaryAngles;
    case "reverse"
        angles = [boundaryAngles boundaryAngles(1)];
    otherwise
        error("viewer_performance_evaluation:unknownZoomMode", ...
            "Unknown zoom boundary mode %s.", mode);
end

initialDiagnostics = app.performanceDiagnostics();
layerCount = initialDiagnostics.Viewer.LayerCount;
downsamples = zeros(numel(angles), layerCount);
tileCounts = zeros(size(downsamples));
for k = 1:numel(angles)
    ax.CameraViewAngle = angles(k);
    fig.WindowScrollWheelFcn(fig, struct(VerticalScrollCount=0));
    if mode == "slow"
        drawnow
    end
    diagnostics = app.performanceDiagnostics();
    downsamples(k, :) = diagnostics.Viewer.CurrentDownsamples;
    tileCounts(k, :) = diagnostics.Viewer.CurrentTileCounts;
end
trace = struct(AnglesDegrees=angles, Downsamples=downsamples, ...
    TileCounts=tileCounts, ...
    CrossedLevel=any(diff(downsamples, 1, 1) ~= 0, "all"));
end

function runKeyPairScenario(fig, firstKey, secondKey, iterations)
for k = 1:iterations
    key = firstKey;
    if mod(k, 2) == 0
        key = secondKey;
    end
    fig.WindowKeyPressFcn(fig, struct(Key=key, Modifier=key));
end
end

function slider = findSliderInColumn(fig, column)
sliders = findall(fig, "-isa", "matlab.ui.control.Slider");
columns = arrayfun(@(value) value.Layout.Column, sliders);
slider = sliders(columns == column);
if numel(slider) ~= 1
    error("viewer_performance_evaluation:missingSlider", ...
        "Expected one slider in layout column %d.", column);
end
end

function point = axesCenterPoint(ax)
axesPosition = ax.InnerPosition;
point = axesPosition(1:2) + axesPosition(3:4) / 2;
end

function name = fileName(path)
[~, base, extension] = fileparts(path);
name = string(base) + string(extension);
end

function sizeVector = imageSize(imageData)
sizeVector = [size(imageData, 1), size(imageData, 2), size(imageData, 3)];
end

function writeArtifacts(summary, outputDirectory)
save(fullfile(outputDirectory, "viewer_performance_evaluation.mat"), ...
    "summary", "-v7.3");
json = jsonencode(summary, PrettyPrint=true);
writelines(json, fullfile(outputDirectory, ...
    "viewer_performance_evaluation.json"));

scenarioCount = numel(summary.Scenarios);
names = strings(scenarioCount, 1);
wallSeconds = zeros(scenarioCount, 1);
activeWallSeconds = zeros(scenarioCount, 1);
frameRequests = zeros(scenarioCount, 1);
renderedFrames = zeros(scenarioCount, 1);
meshBuilds = zeros(scenarioCount, 1);
surfaceCreations = zeros(scenarioCount, 1);
surfaceDeletions = zeros(scenarioCount, 1);
tileCandidates = zeros(scenarioCount, 1);
for k = 1:scenarioCount
    record = summary.Scenarios(k);
    counters = record.Diagnostics.Counters;
    names(k) = record.Name;
    activeWallSeconds(k) = record.ActiveWallSeconds;
    wallSeconds(k) = record.WallSeconds;
    frameRequests(k) = counters.FrameRequests;
    renderedFrames(k) = counters.RenderedFrames;
    meshBuilds(k) = counters.MeshBuilds;
    surfaceCreations(k) = counters.SurfaceCreations;
    surfaceDeletions(k) = counters.SurfaceDeletions;
    tileCandidates(k) = counters.TileCandidates;
end
scenarioTable = table(names, activeWallSeconds, wallSeconds, ...
    frameRequests, renderedFrames, ...
    meshBuilds, surfaceCreations, surfaceDeletions, tileCandidates, ...
    VariableNames=["Scenario", "ActiveWallSeconds", "WallSeconds", ...
    "FrameRequests", "RenderedFrames", "MeshBuilds", "SurfaceCreations", ...
    "SurfaceDeletions", "TileCandidates"]);
writetable(scenarioTable, fullfile(outputDirectory, ...
    "viewer_performance_scenarios.csv"));
end

function printSummary(summary)
fprintf("Viewer performance evaluation\n");
fprintf("  Fixture: %s, launch: %.3f s\n", ...
    summary.Fixture.Source, summary.LaunchSeconds);
for k = 1:numel(summary.Scenarios)
    record = summary.Scenarios(k);
    counters = record.Diagnostics.Counters;
    fprintf("  %-10s active %.3f s, settled %.3f s, frames %d/%d, meshes %d, surfaces +%d/-%d\n", ...
        record.Name, record.ActiveWallSeconds, record.WallSeconds, ...
        counters.RenderedFrames, ...
        counters.FrameRequests, counters.MeshBuilds, ...
        counters.SurfaceCreations, counters.SurfaceDeletions);
end
end

function value = validatePositiveIntegerVector(value, name, count)
if ~isnumeric(value) || ~isvector(value) || numel(value) ~= count || ...
        any(~isfinite(value)) || any(value < 1) || any(fix(value) ~= value)
    error("viewer_performance_evaluation:invalidOptions", ...
        "%s must be a positive integer vector with %d elements.", name, count);
end
value = double(reshape(value, 1, []));
end

function value = validatePositiveIntegerScalar(value, name)
value = validatePositiveIntegerVector(value, name, 1);
value = value(1);
end

function value = validatePositiveFiniteVector(value, name, count)
if ~isnumeric(value) || ~isvector(value) || numel(value) ~= count || ...
        any(~isfinite(value)) || any(value <= 0)
    error("viewer_performance_evaluation:invalidOptions", ...
        "%s must be a positive finite vector with %d elements.", name, count);
end
value = double(reshape(value, 1, []));
end

function value = validateLogicalScalar(value, name)
if ~(islogical(value) || isnumeric(value)) || ~isscalar(value)
    error("viewer_performance_evaluation:invalidOptions", ...
        "%s must be a logical scalar.", name);
end
value = logical(value);
end
