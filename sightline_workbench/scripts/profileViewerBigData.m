function [summary, profileInfo, app] = profileViewerBigData(options)
%profileViewerBigData Profile tiled viewer updates with repeated large imagery.
%
%   summary = profileViewerBigData profiles a two-layer viewer scene built
%   from the default prototype image repeated in a 4-by-4 grid. The helper
%   writes profile artifacts under artifacts/viewer_big_data_profile by
%   default.
%
%   summary = profileViewerBigData(options) accepts a scalar struct with
%   optional fields:
%       ImagePath        image to repeat; defaults to test_data/10.tif
%       RepeatGrid       1x2 repeat counts; defaults to [4 4]
%       LayerCount       number of repeated layers; defaults to 2
%       TipValues        projection tip values to profile
%       SceneOptions     options passed to ProjectionViewerHarness
%       OutputDirectory  artifact folder
%       WriteArtifacts   true/false, default true
%       KeepAppOpen      true/false, default false
%
%   [summary, profileInfo, app] leaves the app open for manual inspection.

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

baseImage = readProfileImage(options.ImagePath);
bigImage = repmat(baseImage, options.RepeatGrid(1), options.RepeatGrid(2), 1);
imageDataList = repmat({bigImage}, 1, options.LayerCount);
layerNames = "big_data_layer_" + string(1:options.LayerCount) + ".tif";

sceneTimer = tic;
scene = ProjectionViewerHarness.createSceneFromImages( ...
    imageDataList, layerNames, options.SceneOptions);
sceneSeconds = toc(sceneTimer);

appTimer = tic;
app = ProjectionViewerApp(scene);
drawnow
appLaunchSeconds = toc(appTimer);

if nargout < 3 && ~options.KeepAppOpen
    cleanup = onCleanup(@() delete(app));
end

[tileSurfaceCount, plainSurfaceCount, tileTextureSizes] = ...
    viewerSurfaceSummary();

tipSlider = findSliderInColumn(2);
profile clear
profile on
profileTimer = tic;
for k = 1:numel(options.TipValues)
    tipSlider.Value = options.TipValues(k);
    tipSlider.ValueChangedFcn(tipSlider, struct());
end
drawnow
profileWallSeconds = toc(profileTimer);
profile off

profileInfo = profile("info");
topFunctions = profileInfoToTable(profileInfo, options.TopFunctionCount);

summary = struct();
summary.ImagePath = string(options.ImagePath);
summary.BaseImageSize = imageSize(baseImage);
summary.RepeatedImageSize = imageSize(bigImage);
summary.LayerCount = options.LayerCount;
summary.RepeatGrid = options.RepeatGrid;
summary.SceneBuildSeconds = sceneSeconds;
summary.AppLaunchSeconds = appLaunchSeconds;
summary.ProfileWallSeconds = profileWallSeconds;
summary.TileSurfaceCount = tileSurfaceCount;
summary.PlainSurfaceCount = plainSurfaceCount;
summary.TileTextureSizes = tileTextureSizes;
summary.TopFunctions = topFunctions;

printSummary(summary);
if options.WriteArtifacts
    writeArtifacts(summary, profileInfo, options.OutputDirectory);
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
    error("profileViewerBigData:invalidOptions", ...
        "Options must be a scalar struct.");
end

defaults = struct();
defaults.ImagePath = ProjectionViewerHarness.defaultImagePath();
defaults.RepeatGrid = [4 4];
defaults.LayerCount = 2;
defaults.TipValues = linspace(-4, 4, 16);
defaults.SceneOptions = struct( ...
    RowStride=64, ColumnStride=64, ...
    DisplayTextureMaxPixels=2e6, ...
    GSD=0.01, NominalRange=1e6, PlatformStepMeters=0.01);
defaults.OutputDirectory = fullfile(projectRoot, ...
    "artifacts", "viewer_big_data_profile");
defaults.WriteArtifacts = true;
defaults.KeepAppOpen = false;
defaults.TopFunctionCount = 30;

names = fieldnames(options);
for k = 1:numel(names)
    defaults.(names{k}) = options.(names{k});
end

defaults.ImagePath = string(defaults.ImagePath);
defaults.RepeatGrid = validatePositiveIntegerVector( ...
    defaults.RepeatGrid, "RepeatGrid", 2);
defaults.LayerCount = validatePositiveIntegerScalar( ...
    defaults.LayerCount, "LayerCount");
defaults.TipValues = validateFiniteVector(defaults.TipValues, "TipValues");
defaults.OutputDirectory = char(string(defaults.OutputDirectory));
defaults.WriteArtifacts = validateLogicalScalar( ...
    defaults.WriteArtifacts, "WriteArtifacts");
defaults.KeepAppOpen = validateLogicalScalar( ...
    defaults.KeepAppOpen, "KeepAppOpen");
defaults.TopFunctionCount = validatePositiveIntegerScalar( ...
    defaults.TopFunctionCount, "TopFunctionCount");

options = defaults;
end

function imageData = readProfileImage(imagePath)
if isfile(imagePath)
    imageData = imread(imagePath);
    return
end

warning("profileViewerBigData:missingImage", ...
    "Image %s was not found; using a generated texture.", imagePath);
[x, y] = meshgrid(uint16(1:2048), uint16(1:2048));
imageData = uint8(mod(3 * x + 5 * y, 256));
end

function [tileSurfaceCount, plainSurfaceCount, tileTextureSizes] = ...
        viewerSurfaceSummary()
fig = findall(groot, "Type", "figure", "Name", "Projection Viewer Prototype");
ax = findall(fig, "Type", "axes");
tileSurfaces = findall(ax, "Type", "surface", ...
    "Tag", "ProjectionViewerPreviewTileSurface");
plainSurfaces = findall(ax, "Type", "surface", ...
    "Tag", "ProjectionViewerLayerSurface");
tileSurfaceCount = numel(tileSurfaces);
plainSurfaceCount = numel(plainSurfaces);
tileTextureSizes = zeros(tileSurfaceCount, 2);
for k = 1:tileSurfaceCount
    tileTextureSizes(k, :) = size(tileSurfaces(k).CData, [1 2]);
end
end

function slider = findSliderInColumn(column)
fig = findall(groot, "Type", "figure", "Name", "Projection Viewer Prototype");
sliders = findall(fig, "-isa", "matlab.ui.control.Slider");
for k = 1:numel(sliders)
    if sliders(k).Layout.Column == column
        slider = sliders(k);
        return
    end
end

error("profileViewerBigData:missingSlider", ...
    "Could not find a slider in layout column %d.", column);
end

function topFunctions = profileInfoToTable(profileInfo, count)
functionTable = struct2table(profileInfo.FunctionTable);
if isempty(functionTable)
    topFunctions = table();
    return
end

functionTable = sortrows(functionTable, "TotalTime", "descend");
if ~ismember("SelfTime", string(functionTable.Properties.VariableNames))
    functionTable.SelfTime = NaN(height(functionTable), 1);
end
count = min(count, height(functionTable));
topFunctions = functionTable(1:count, ...
    ["FunctionName", "NumCalls", "TotalTime", "SelfTime"]);
end

function writeArtifacts(summary, profileInfo, outputDirectory)
save(fullfile(outputDirectory, "viewer_big_data_profile.mat"), ...
    "summary", "profileInfo", "-v7.3");
writetable(summary.TopFunctions, ...
    fullfile(outputDirectory, "viewer_big_data_top_functions.csv"));

runSummary = table( ...
    summary.BaseImageSize(1), summary.BaseImageSize(2), ...
    summary.RepeatedImageSize(1), summary.RepeatedImageSize(2), ...
    summary.LayerCount, summary.TileSurfaceCount, ...
    summary.PlainSurfaceCount, summary.SceneBuildSeconds, ...
    summary.AppLaunchSeconds, summary.ProfileWallSeconds, ...
    VariableNames=["BaseRows", "BaseColumns", "RepeatedRows", ...
    "RepeatedColumns", "LayerCount", "TileSurfaceCount", ...
    "PlainSurfaceCount", "SceneBuildSeconds", "AppLaunchSeconds", ...
    "ProfileWallSeconds"]);
writetable(runSummary, ...
    fullfile(outputDirectory, "viewer_big_data_summary.csv"));
end

function printSummary(summary)
fprintf("Big-data viewer profile\n");
fprintf("  Image: %s\n", summary.ImagePath);
fprintf("  Base image: %dx%d\n", ...
    summary.BaseImageSize(1), summary.BaseImageSize(2));
fprintf("  Repeated image: %dx%d, layers: %d\n", ...
    summary.RepeatedImageSize(1), summary.RepeatedImageSize(2), ...
    summary.LayerCount);
fprintf("  Scene build: %.3f s, app launch: %.3f s, profile: %.3f s\n", ...
    summary.SceneBuildSeconds, summary.AppLaunchSeconds, ...
    summary.ProfileWallSeconds);
fprintf("  Tile surfaces: %d, plain surfaces: %d\n", ...
    summary.TileSurfaceCount, summary.PlainSurfaceCount);
disp(summary.TopFunctions);
end

function value = validatePositiveIntegerVector(value, name, count)
if ~isnumeric(value) || ~isvector(value) || numel(value) ~= count || ...
        any(~isfinite(value)) || any(value < 1) || any(fix(value) ~= value)
    error("profileViewerBigData:invalidOptions", ...
        "%s must be a positive integer vector with %d elements.", name, count);
end
value = double(reshape(value, 1, []));
end

function value = validatePositiveIntegerScalar(value, name)
value = validatePositiveIntegerVector(value, name, 1);
value = value(1);
end

function value = validateFiniteVector(value, name)
if ~isnumeric(value) || isempty(value) || ~isvector(value) || ...
        any(~isfinite(value))
    error("profileViewerBigData:invalidOptions", ...
        "%s must be a nonempty finite numeric vector.", name);
end
value = double(reshape(value, 1, []));
end

function value = validateLogicalScalar(value, name)
if ~(islogical(value) || isnumeric(value)) || ~isscalar(value)
    error("profileViewerBigData:invalidOptions", ...
        "%s must be a logical scalar.", name);
end
value = logical(value);
end

function sizeVector = imageSize(imageData)
sizeVector = [size(imageData, 1), size(imageData, 2), size(imageData, 3)];
end
