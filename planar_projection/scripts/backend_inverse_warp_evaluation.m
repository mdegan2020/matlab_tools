function summary = backend_inverse_warp_evaluation(options)
%backend_inverse_warp_evaluation Compare full-source and sparse radiometry.
%
%   This compatibility harness renders the same output grid with the new
%   full-source inverse warp and the retained sparse-intensity reference.

if nargin < 1
    options = struct();
end
projectRoot = fileparts(fileparts(mfilename("fullpath")));
options = mergeOptions(options, projectRoot);
if options.WriteArtifacts && ~isfolder(options.OutputDirectory)
    mkdir(options.OutputDirectory);
end

scene = createScene(options);
outputGrid = ProjectionBackendOutputGrid.plan(scene, ...
    struct(OutputSize=options.OutputSize));
baseOptions = struct(OutputGrid=outputGrid, ...
    Interpolation=options.Interpolation, InvalidFillValue=0, ...
    IncludeLayerReadbacks=false, UseGPU=false);

fullTimer = tic;
fullSource = ProjectionReadbackRenderer.renderScene(scene, ...
    withMode(baseOptions, "fullSourceInverseWarp"));
fullSeconds = toc(fullTimer);
sparseTimer = tic;
sparseReference = ProjectionReadbackRenderer.renderScene(scene, ...
    withMode(baseOptions, "sparseIntensityScatteredInterpolant"));
sparseSeconds = toc(sparseTimer);
comparison = ProjectionFullSourceInverseWarp.compareReadbacks( ...
    fullSource, sparseReference);

summary = struct();
summary.Format = "ProjectionBackendInverseWarpEvaluation";
summary.Version = 1;
summary.ImageSize = options.ImageSize;
summary.OutputSize = options.OutputSize;
summary.MeshStride = options.MeshStride;
summary.Interpolation = options.Interpolation;
summary.FullSourceSeconds = fullSeconds;
summary.SparseReferenceSeconds = sparseSeconds;
summary.FullSourcePlan = fullSource.RenderPlan;
summary.SparseReferencePlan = sparseReference.RenderPlan;
summary.Comparison = comparison;
summary.CpuComplete = true;
summary.GeneratedAt = string(datetime("now", TimeZone="local", ...
    Format="yyyy-MM-dd'T'HH:mm:ssXXX"));

fprintf("Backend inverse-warp compatibility evaluation\n");
fprintf("  full-source: %.3f ms, sparse reference: %.3f ms\n", ...
    1000 * fullSeconds, 1000 * sparseSeconds);
fprintf("  common valid pixels: %d, mask mismatches: %d\n", ...
    comparison.CommonValidPixelCount, comparison.ValidMaskMismatchCount);
for bandIndex = 1:numel(comparison.Bands)
    band = comparison.Bands(bandIndex);
    fprintf("  band %d: MAE %.6g, p95 %.6g, max %.6g\n", ...
        bandIndex, band.MeanAbsoluteError, ...
        band.P95AbsoluteError, band.MaximumAbsoluteError);
end

if options.WriteArtifacts
    save(fullfile(options.OutputDirectory, ...
        "backend_inverse_warp_evaluation.mat"), "summary", "-v7.3");
    writelines(jsonencode(summary, PrettyPrint=true), ...
        fullfile(options.OutputDirectory, ...
        "backend_inverse_warp_evaluation.json"));
end
end

function scene = createScene(options)
rowAxis = single(linspace(0, 1, options.ImageSize(1))).';
columnAxis = single(linspace(0, 1, options.ImageSize(2)));
gradient = 0.6 * rowAxis + 0.4 * columnAxis;
checkerboard = single(mod( ...
    floor(rowAxis * options.PatternCycles) + ...
    floor(columnAxis * options.PatternCycles), 2));
imageData = 0.55 * gradient + 0.45 * checkerboard;
sceneOptions = struct(RowStride=options.MeshStride, ...
    ColumnStride=options.MeshStride, PlatformDirection=[0; 0; 1]);
scene = ProjectionViewerHarness.createSceneFromImage( ...
    imageData, "inverse-warp-evaluation.tif", sceneOptions);
scene.layers.DisplayTexture = zeros(2, 2, 3, "single");
end

function options = withMode(options, mode)
options.NumericalMode = mode;
end

function options = mergeOptions(options, projectRoot)
if ~isstruct(options) || ~isscalar(options)
    error("backend_inverse_warp_evaluation:invalidOptions", ...
        "Options must be a scalar struct.");
end
defaults = struct(ImageSize=[384 512], OutputSize=[256 320], ...
    MeshStride=16, PatternCycles=48, Interpolation="bilinear", ...
    WriteArtifacts=true, OutputDirectory=fullfile(projectRoot, ...
    "artifacts", "backend_performance"));
names = fieldnames(options);
for k = 1:numel(names)
    if ~isfield(defaults, names{k})
        error("backend_inverse_warp_evaluation:invalidOptions", ...
            "Unknown option %s.", names{k});
    end
    defaults.(names{k}) = options.(names{k});
end
defaults.ImageSize = validatePositiveIntegerVector( ...
    defaults.ImageSize, "ImageSize", 2);
defaults.OutputSize = validatePositiveIntegerVector( ...
    defaults.OutputSize, "OutputSize", 2);
defaults.MeshStride = validatePositiveIntegerVector( ...
    defaults.MeshStride, "MeshStride", 1);
defaults.MeshStride = defaults.MeshStride(1);
defaults.PatternCycles = validatePositiveIntegerVector( ...
    defaults.PatternCycles, "PatternCycles", 1);
defaults.PatternCycles = defaults.PatternCycles(1);
defaults.Interpolation = lower(string(defaults.Interpolation));
if ~isscalar(defaults.Interpolation) || ...
        ~ismember(defaults.Interpolation, ["bilinear", "nearest"])
    error("backend_inverse_warp_evaluation:invalidOptions", ...
        "Interpolation must be bilinear or nearest.");
end
defaults.WriteArtifacts = validateLogicalScalar( ...
    defaults.WriteArtifacts, "WriteArtifacts");
defaults.OutputDirectory = char(string(defaults.OutputDirectory));
options = defaults;
end

function value = validatePositiveIntegerVector(value, name, count)
if ~isnumeric(value) || ~isvector(value) || numel(value) ~= count || ...
        any(~isfinite(value)) || any(value < 1) || any(fix(value) ~= value)
    error("backend_inverse_warp_evaluation:invalidOptions", ...
        "%s must be a positive integer vector with %d elements.", name, count);
end
value = double(value(:).');
end

function value = validateLogicalScalar(value, name)
if ~isscalar(value) || ~(islogical(value) || ...
        (isnumeric(value) && isfinite(value) && any(value == [0 1])))
    error("backend_inverse_warp_evaluation:invalidOptions", ...
        "%s must be a logical scalar.", name);
end
value = logical(value);
end
