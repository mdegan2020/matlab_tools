function summary = viewer_raster_preview_evaluation(options)
%viewer_raster_preview_evaluation Compare surface and CPU raster previews.
%
%   The production viewer remains in its existing surface mode. This
%   experiment compiles viewport-sized layer rasters, composites alpha and
%   visibility changes numerically, displays one opaque image object, and
%   compares its output with an actual viewer frame and exact readback.

if nargin < 1
    options = struct();
end
projectRoot = fileparts(fileparts(mfilename("fullpath")));
options = mergeOptions(options, projectRoot);
if options.WriteArtifacts && ~isfolder(options.OutputDirectory)
    mkdir(options.OutputDirectory);
end

scene = createEvaluationScene(options.ImageSize);
surfaceApp = ProjectionViewerApp(scene);
surfaceCleanup = onCleanup(@() delete(surfaceApp));
drawnow
[surfaceFigure, surfaceAxes] = viewerGraphics();
cameraState = surfaceApp.exportState().Camera;

rasterPlan = surfaceApp.compileRasterPreview(struct( ...
    OutputSize=options.OutputSize, SourceMode="displayTexture", ...
    Interpolation=options.Interpolation));
rasterResult = ProjectionRasterPreviewRenderer.composite( ...
    rasterPlan, scene.layers);
[rasterFigure, rasterAxes, rasterImage] = ...
    createRasterFigure(rasterResult.Image, options);
rasterCleanup = onCleanup(@() delete(rasterFigure));

visual = compareVisualOutputs(scene, surfaceAxes, rasterResult, ...
    rasterPlan, options);
surfaceTimings = evaluateSurfaceInteractions( ...
    surfaceApp, surfaceFigure, options);
rasterTimings = evaluateRasterInteractions( ...
    scene, cameraState, rasterPlan, rasterImage, rasterAxes, options);
surfaceMemory = surfaceMemoryDiagnostics(surfaceAxes);
rasterMemory = struct( ...
    ObjectCount=1, LayerRasterBytes=rasterPlan.RasterBytes, ...
    CompositeImageBytes=rasterResult.ImageBytes, ...
    TotalNumericBytes=rasterPlan.RasterBytes + rasterResult.ImageBytes);

summary = struct();
summary.Format = "ProjectionViewerRasterPreviewEvaluation";
summary.Version = 1;
summary.ImageSize = options.ImageSize;
summary.OutputSize = options.OutputSize;
summary.Iterations = options.Iterations;
summary.Surface = struct(Timings=surfaceTimings, Memory=surfaceMemory);
summary.Raster = struct(Timings=rasterTimings, Memory=rasterMemory, ...
    InitialCompileSeconds=rasterPlan.CompileSeconds, ...
    InitialCompositeSeconds=rasterResult.CompositeSeconds, ...
    CpuComplete=rasterPlan.CpuComplete && rasterResult.CpuComplete);
summary.Visual = visual.Metrics;
summary.Decision = "retainOptional";
summary.DecisionRationale = [ ...
    "Raster compositing is useful for diagnostics and alpha/visibility experiments.", ...
    "Camera changes still require CPU inverse-map recompilation and texture upload.", ...
    "The optimized surface path remains the production default until raster camera latency is competitive.", ...
    "Backend rendering remains independent and continues to use full source imagery."];
summary.GeneratedAt = string(datetime("now", TimeZone="local", ...
    Format="yyyy-MM-dd'T'HH:mm:ssXXX"));

printSummary(summary);
if options.WriteArtifacts
    writeArtifacts(summary, visual, options.OutputDirectory);
end
if options.KeepFiguresOpen
    clear rasterCleanup surfaceCleanup
end
end

function scene = createEvaluationScene(imageSize)
rowAxis = single(linspace(0, 1, imageSize(1))).';
columnAxis = single(linspace(0, 1, imageSize(2)));
gradient = 0.55 * rowAxis + 0.45 * columnAxis;
frequency = 18;
texture = 0.5 + 0.2 * sin(2 * pi * frequency * rowAxis) .* ...
    cos(2 * pi * frequency * columnAxis);
image1 = min(max(0.7 * gradient + 0.3 * texture, 0), 1);
image2 = min(max(0.7 * circshift(gradient, [3 5]) + ...
    0.3 * circshift(texture, [-2 4]), 0), 1);
sceneOptions = struct(RowStride=16, ColumnStride=16, ...
    PlatformDirection=[0; 0; 1]);
scene = ProjectionViewerHarness.createSceneFromImages( ...
    {image1, image2}, ["raster-reference.tif", "raster-moving.tif"], ...
    sceneOptions);
scene.layers(1).Alpha = 1;
scene.layers(2).Alpha = 0.55;
end

function [fig, ax] = viewerGraphics()
fig = findall(groot, "Type", "figure", ...
    "Name", "Sightline");
if isempty(fig)
    error("viewer_raster_preview_evaluation:missingViewer", ...
        "Unable to locate the projection viewer figure.");
end
fig = fig(1);
ax = findall(fig, "Type", "axes");
if isempty(ax)
    error("viewer_raster_preview_evaluation:missingViewer", ...
        "Unable to locate the projection viewer axes.");
end
ax = ax(1);
end

function [fig, ax, imageHandle] = createRasterFigure(imageData, options)
fig = uifigure(Name="Raster Preview Prototype", ...
    Position=[150 150 options.FigureSize]);
ax = uiaxes(fig, Position=[1 1 options.FigureSize]);
imageHandle = image(ax, imageData);
axis(ax, "image");
ax.Visible = "off";
drawnow
end

function visual = compareVisualOutputs(scene, surfaceAxes, rasterResult, ...
        rasterPlan, options)
drawnow
surfaceFrame = getframe(surfaceAxes);
surfaceImage = im2single(imresize(surfaceFrame.cdata, ...
    options.OutputSize, "bilinear"));
rasterImage = rasterResult.Image;
outputGrid = ProjectionViewportGrid.asOutputGrid(rasterPlan.ViewportGrid);
exact = ProjectionReadbackRenderer.renderScene(scene, struct( ...
    OutputGrid=outputGrid, Interpolation=options.Interpolation, ...
    InvalidFillValue=0, IncludeLayerReadbacks=false, UseGPU=false));
exactImage = normalizedRgb(exact.Image);
commonMask = rasterResult.ValidMask & exact.ValidMask;

visual = struct();
visual.SurfaceImage = surfaceImage;
visual.RasterImage = rasterImage;
visual.ExactImage = exactImage;
visual.CommonMask = commonMask;
visual.RasterExactDifference = abs(rasterImage - exactImage);
visual.SurfaceRasterDifference = abs(surfaceImage - rasterImage);
visual.Metrics = struct();
visual.Metrics.CommonValidPixelCount = nnz(commonMask);
visual.Metrics.CommonValidFraction = nnz(commonMask) / prod(options.OutputSize);
visual.Metrics.RasterVersusExact = differenceMetrics( ...
    rasterImage, exactImage, commonMask);
visual.Metrics.SurfaceVersusRaster = differenceMetrics( ...
    surfaceImage, rasterImage, commonMask);
end

function timings = evaluateSurfaceInteractions(app, fig, options)
alphaSlider = findSlider(fig, [0 1]);
twistSlider = findSlider(fig, [-85 85], 3);
visibilityCheckBox = findall(groot, "Tag", ...
    "ProjectionViewerLayerManagerVisibleCheckBox");
if isempty(visibilityCheckBox)
    error("viewer_raster_preview_evaluation:missingControl", ...
        "Unable to locate the visibility checkbox.");
end
visibilityCheckBox = visibilityCheckBox(1);
crosshairLines = findall(fig, "Type", "line", ...
    "-regexp", "Tag", "ProjectionViewerCrosshair.*");

alphaSamples = zeros(1, options.Iterations);
visibilitySamples = zeros(1, options.Iterations);
twistSamples = zeros(1, options.Iterations);
crosshairSamples = zeros(1, options.Iterations);
for k = 1:options.Iterations
    alphaValue = options.AlphaValues(1 + mod(k - 1, ...
        numel(options.AlphaValues)));
    frameTimer = tic;
    alphaSlider.ValueChangingFcn(alphaSlider, struct(Value=alphaValue));
    alphaSamples(k) = toc(frameTimer);

    visibilityCheckBox.Value = mod(k, 2) == 0;
    frameTimer = tic;
    visibilityCheckBox.ValueChangedFcn(visibilityCheckBox, ...
        struct(Value=visibilityCheckBox.Value));
    drawnow
    visibilitySamples(k) = toc(frameTimer);

    twistValue = options.TwistValues(1 + mod(k - 1, ...
        numel(options.TwistValues)));
    frameTimer = tic;
    twistSlider.ValueChangingFcn(twistSlider, struct(Value=twistValue));
    twistSamples(k) = toc(frameTimer);

    frameTimer = tic;
    updateCrosshairLines(crosshairLines, k, options.Iterations);
    drawnow
    crosshairSamples(k) = toc(frameTimer);
end
visibilityCheckBox.Value = true;
visibilityCheckBox.ValueChangedFcn(visibilityCheckBox, struct(Value=true));
twistSlider.Value = 0;
twistSlider.ValueChangedFcn(twistSlider, struct());
alphaSlider.Value = 0.55;
alphaSlider.ValueChangedFcn(alphaSlider, struct());
app.flushPreviewUpdates();

timings = timingSummary(alphaSamples, visibilitySamples, ...
    twistSamples, crosshairSamples);
end

function timings = evaluateRasterInteractions(scene, cameraState, plan, ...
        imageHandle, ax, options)
layers = scene.layers;
alphaSamples = zeros(1, options.Iterations);
visibilitySamples = zeros(1, options.Iterations);
twistSamples = zeros(1, options.Iterations);
crosshairSamples = zeros(1, options.Iterations);
crosshairLines = [line(ax, [0 1], [0.5 0.5], Color="cyan"), ...
    line(ax, [0.5 0.5], [0 1], Color="cyan")];

for k = 1:options.Iterations
    layers(2).Alpha = options.AlphaValues(1 + mod(k - 1, ...
        numel(options.AlphaValues)));
    frameTimer = tic;
    result = ProjectionRasterPreviewRenderer.composite(plan, layers);
    imageHandle.CData = result.Image;
    drawnow
    alphaSamples(k) = toc(frameTimer);

    layers(2).Visible = mod(k, 2) == 0;
    frameTimer = tic;
    result = ProjectionRasterPreviewRenderer.composite(plan, layers);
    imageHandle.CData = result.Image;
    drawnow
    visibilitySamples(k) = toc(frameTimer);
    layers(2).Visible = true;

    twistValue = options.TwistValues(1 + mod(k - 1, ...
        numel(options.TwistValues)));
    twistedCamera = twistCamera(cameraState, twistValue);
    frameTimer = tic;
    twistedPlan = ProjectionRasterPreviewRenderer.compile(scene, ...
        twistedCamera, struct(OutputSize=options.OutputSize, ...
        SourceMode="displayTexture", Interpolation=options.Interpolation));
    result = ProjectionRasterPreviewRenderer.composite(twistedPlan, layers);
    imageHandle.CData = result.Image;
    drawnow
    twistSamples(k) = toc(frameTimer);

    frameTimer = tic;
    updateCrosshairLines(crosshairLines, k, options.Iterations);
    drawnow
    crosshairSamples(k) = toc(frameTimer);
end
timings = timingSummary(alphaSamples, visibilitySamples, ...
    twistSamples, crosshairSamples);
end

function slider = findSlider(fig, expectedLimits, layoutColumn)
sliders = findall(fig, "Type", "uislider");
matches = arrayfun(@(candidate) isequal(candidate.Limits, expectedLimits), ...
    sliders);
if nargin >= 3
    matches = matches & arrayfun( ...
        @(candidate) candidate.Layout.Column == layoutColumn, sliders);
end
slider = sliders(matches);
if numel(slider) ~= 1
    error("viewer_raster_preview_evaluation:missingControl", ...
        "Unable to locate the requested viewer slider.");
end
end

function updateCrosshairLines(lines, index, count)
if isempty(lines)
    return
end
coordinate = (index - 0.5) / count;
lines(1).XData = [0 1];
lines(1).YData = [coordinate coordinate];
if numel(lines) > 1
    lines(2).XData = [coordinate coordinate];
    lines(2).YData = [0 1];
end
set(lines, "Visible", "on");
end

function camera = twistCamera(camera, twistDegrees)
viewDirection = camera.Target(:) - camera.Position(:);
viewDirection = viewDirection / norm(viewDirection);
angle = deg2rad(twistDegrees);
K = [0 -viewDirection(3) viewDirection(2); ...
    viewDirection(3) 0 -viewDirection(1); ...
    -viewDirection(2) viewDirection(1) 0];
rotation = eye(3) + sin(angle) * K + (1 - cos(angle)) * (K * K);
camera.UpVector = rotation * camera.UpVector(:);
end

function timings = timingSummary(alpha, visibility, twist, crosshair)
timings = struct(Alpha=sampleSummary(alpha), ...
    Visibility=sampleSummary(visibility), ...
    Twist=sampleSummary(twist), ...
    Crosshair=sampleSummary(crosshair));
end

function summary = sampleSummary(samples)
sortedSamples = sort(samples);
summary = struct(MedianSeconds=median(samples), ...
    P95Seconds=sortedSamples(max(1, ceil(0.95 * numel(samples)))), ...
    MaximumSeconds=max(samples), SamplesSeconds=samples);
end

function diagnostics = surfaceMemoryDiagnostics(ax)
surfaceHandles = findall(ax, "Type", "surface");
numericBytes = 0;
textureBytes = 0;
for k = 1:numel(surfaceHandles)
    textureBytes = textureBytes + arrayBytes(surfaceHandles(k).CData);
    numericBytes = numericBytes + arrayBytes(surfaceHandles(k).XData) + ...
        arrayBytes(surfaceHandles(k).YData) + ...
        arrayBytes(surfaceHandles(k).ZData) + ...
        arrayBytes(surfaceHandles(k).CData);
end
diagnostics = struct(ObjectCount=numel(surfaceHandles), ...
    TextureBytes=textureBytes, TotalNumericBytes=numericBytes);
end

function metrics = differenceMetrics(first, second, mask)
mask3 = repmat(mask, 1, 1, 3);
differences = double(abs(first(mask3) - second(mask3)));
if isempty(differences)
    metrics = struct(MeanAbsoluteError=NaN, RootMeanSquareError=NaN, ...
        P95AbsoluteError=NaN, MaximumAbsoluteError=NaN);
    return
end
differences = sort(differences);
metrics = struct(MeanAbsoluteError=mean(differences), ...
    RootMeanSquareError=sqrt(mean(differences .^ 2)), ...
    P95AbsoluteError=differences(max(1, ceil(0.95 * numel(differences)))), ...
    MaximumAbsoluteError=max(differences));
end

function imageData = normalizedRgb(imageData)
imageData = single(min(max(imageData, 0), 1));
if ismatrix(imageData)
    imageData = repmat(imageData, 1, 1, 3);
elseif size(imageData, 3) ~= 3
    imageData = repmat(mean(imageData, 3), 1, 1, 3);
end
end

function bytes = arrayBytes(value)
if islogical(value)
    bytes = double(numel(value));
    return
end
details = whos("value");
bytes = double(details.bytes);
end

function options = mergeOptions(options, projectRoot)
if ~isstruct(options) || ~isscalar(options)
    error("viewer_raster_preview_evaluation:invalidOptions", ...
        "Options must be a scalar struct.");
end
defaults = struct(ImageSize=[480 640], OutputSize=[300 400], ...
    FigureSize=[500 400], Iterations=6, ...
    AlphaValues=[0.2 0.55 0.85], TwistValues=[-10 0 10], ...
    Interpolation="bilinear", KeepFiguresOpen=false, ...
    WriteArtifacts=true, OutputDirectory=fullfile(projectRoot, ...
    "artifacts", "viewer_performance"));
names = fieldnames(options);
for k = 1:numel(names)
    if ~isfield(defaults, names{k})
        error("viewer_raster_preview_evaluation:invalidOptions", ...
            "Unknown option %s.", names{k});
    end
    defaults.(names{k}) = options.(names{k});
end
defaults.ImageSize = validatePositiveIntegerVector( ...
    defaults.ImageSize, "ImageSize", 2);
defaults.OutputSize = validatePositiveIntegerVector( ...
    defaults.OutputSize, "OutputSize", 2);
defaults.FigureSize = validatePositiveIntegerVector( ...
    defaults.FigureSize, "FigureSize", 2);
defaults.Iterations = validatePositiveIntegerVector( ...
    defaults.Iterations, "Iterations", 1);
defaults.Iterations = defaults.Iterations(1);
defaults.AlphaValues = validateFiniteVector( ...
    defaults.AlphaValues, "AlphaValues", [0 1]);
defaults.TwistValues = validateFiniteVector( ...
    defaults.TwistValues, "TwistValues", [-85 85]);
defaults.Interpolation = lower(string(defaults.Interpolation));
if ~isscalar(defaults.Interpolation) || ...
        ~ismember(defaults.Interpolation, ["bilinear", "nearest"])
    error("viewer_raster_preview_evaluation:invalidOptions", ...
        "Interpolation must be ""bilinear"" or ""nearest"".");
end
defaults.KeepFiguresOpen = validateLogicalScalar( ...
    defaults.KeepFiguresOpen, "KeepFiguresOpen");
defaults.WriteArtifacts = validateLogicalScalar( ...
    defaults.WriteArtifacts, "WriteArtifacts");
defaults.OutputDirectory = char(string(defaults.OutputDirectory));
options = defaults;
end

function value = validatePositiveIntegerVector(value, name, count)
if ~isnumeric(value) || ~isvector(value) || numel(value) ~= count || ...
        any(~isfinite(value)) || any(value < 1) || any(fix(value) ~= value)
    error("viewer_raster_preview_evaluation:invalidOptions", ...
        "%s must be a positive integer vector with %d elements.", name, count);
end
value = double(reshape(value, 1, []));
end

function value = validateFiniteVector(value, name, limits)
if ~isnumeric(value) || isempty(value) || ~isvector(value) || ...
        any(~isfinite(value)) || any(value < limits(1)) || ...
        any(value > limits(2))
    error("viewer_raster_preview_evaluation:invalidOptions", ...
        "%s must be a finite vector in [%g, %g].", ...
        name, limits(1), limits(2));
end
value = double(value(:).');
end

function value = validateLogicalScalar(value, name)
if ~isscalar(value) || ~(islogical(value) || ...
        (isnumeric(value) && isfinite(value) && any(value == [0 1])))
    error("viewer_raster_preview_evaluation:invalidOptions", ...
        "%s must be a logical scalar.", name);
end
value = logical(value);
end

function printSummary(summary)
fprintf("Viewer raster preview evaluation\n");
fprintf("  surface objects: %d, raster objects: %d\n", ...
    summary.Surface.Memory.ObjectCount, summary.Raster.Memory.ObjectCount);
fprintf("  alpha median: surface %.3f ms, raster %.3f ms\n", ...
    1000 * summary.Surface.Timings.Alpha.MedianSeconds, ...
    1000 * summary.Raster.Timings.Alpha.MedianSeconds);
fprintf("  visibility median: surface %.3f ms, raster %.3f ms\n", ...
    1000 * summary.Surface.Timings.Visibility.MedianSeconds, ...
    1000 * summary.Raster.Timings.Visibility.MedianSeconds);
fprintf("  twist median: surface %.3f ms, raster %.3f ms\n", ...
    1000 * summary.Surface.Timings.Twist.MedianSeconds, ...
    1000 * summary.Raster.Timings.Twist.MedianSeconds);
fprintf("  raster/exact MAE %.5f, p95 %.5f\n", ...
    summary.Visual.RasterVersusExact.MeanAbsoluteError, ...
    summary.Visual.RasterVersusExact.P95AbsoluteError);
fprintf("  surface/raster MAE %.5f, p95 %.5f\n", ...
    summary.Visual.SurfaceVersusRaster.MeanAbsoluteError, ...
    summary.Visual.SurfaceVersusRaster.P95AbsoluteError);
fprintf("  decision: %s\n", summary.Decision);
end

function writeArtifacts(summary, visual, outputDirectory)
save(fullfile(outputDirectory, ...
    "viewer_raster_preview_evaluation.mat"), "summary", "-v7.3");
writelines(jsonencode(summary, PrettyPrint=true), ...
    fullfile(outputDirectory, "viewer_raster_preview_evaluation.json"));
imwrite(visual.SurfaceImage, fullfile(outputDirectory, ...
    "viewer_raster_surface.png"));
imwrite(visual.RasterImage, fullfile(outputDirectory, ...
    "viewer_raster_prototype.png"));
imwrite(visual.ExactImage, fullfile(outputDirectory, ...
    "viewer_raster_exact.png"));
imwrite(min(5 * visual.RasterExactDifference, 1), ...
    fullfile(outputDirectory, "viewer_raster_exact_difference_5x.png"));
end
