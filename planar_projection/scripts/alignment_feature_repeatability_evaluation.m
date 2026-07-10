function [summary, artifacts] = ...
        alignment_feature_repeatability_evaluation(imagePath, options)
%ALIGNMENT_FEATURE_REPEATABILITY_EVALUATION Audit every available detector.
%
% [summary, artifacts] = alignment_feature_repeatability_evaluation(...)
% runs every installed alignment detector twice on an unchanged oblique
% terrain pair and once after a small moving-layer OPK perturbation. It records
% exact-repeat identity, feature/match counts, perturbation retention, actual
% detector parameters, mask/metric rejections, matcher dispatch, and timing.

projectRoot = fileparts(fileparts(mfilename("fullpath")));
if nargin < 1 || isempty(imagePath)
    imagePath = fullfile(projectRoot, "test_data", "10.tif");
end
if nargin < 2 || isempty(options)
    options = struct();
end
options = mergeOptions(options, projectRoot);

[scene, ~] = ProjectionAlignmentObliqueTerrainHarness.createSceneFromRgbTiff( ...
    imagePath, options.SimulationOptions);
perturbedScene = perturbMovingLayer(scene, options.PerturbationDegrees);
baseRequest = ProjectionAlignmentRequest.validate(struct(Scene=scene, ...
    LayerIndices=[2 1], ReferenceLayerIndex=1, AnalysisBands=[1 1]));
perturbedRequest = baseRequest;
perturbedRequest.Scene = perturbedScene;
working = ProjectionAlignmentWorkingImageRenderer.render( ...
    scene, baseRequest, options.RenderOptions);
perturbedWorking = ProjectionAlignmentWorkingImageRenderer.render( ...
    perturbedScene, perturbedRequest, options.RenderOptions);

capabilities = ProjectionAlignmentFeatureMatcher.capabilities();
detectors = capabilities.AvailableDetectors;
records = repmat(emptyRecord(), 1, numel(detectors));
for k = 1:numel(detectors)
    alignmentOptions = ProjectionAlignmentOptions.validate(struct( ...
        Detector=struct(Method=detectors(k), ...
        MaxFeatures=options.MaxFeatures), ...
        Matcher=struct(Method="exhaustive", MaxRatio=options.MaxRatio)));
    first = ProjectionAlignmentFeatureMatcher.match( ...
        working, alignmentOptions);
    repeated = ProjectionAlignmentFeatureMatcher.match( ...
        working, alignmentOptions);
    perturbed = ProjectionAlignmentFeatureMatcher.match( ...
        perturbedWorking, alignmentOptions);

    record = emptyRecord();
    record.Detector = detectors(k);
    record.ExactFeatureRecords = exactFeatureRecords(first, repeated);
    record.ExactRawMatchRecords = exactMatchRecords(first, repeated);
    record.BaselineFeatureCounts = [first.Features.Count];
    record.PerturbedFeatureCounts = [perturbed.Features.Count];
    record.BaselineRawMatchCount = first.Matches.Count;
    record.PerturbedRawMatchCount = perturbed.Matches.Count;
    record.RawMatchRetentionFraction = perturbed.Matches.Count / ...
        max(first.Matches.Count, 1);
    record.BaselineDiagnostics = first.Diagnostics;
    record.PerturbedDiagnostics = perturbed.Diagnostics;
    records(k) = record;
end

summary = struct(Format="ProjectionAlignmentFeatureRepeatability", ...
    Version=1, SourcePath=string(imagePath), ...
    Simulation=scene.Simulation, ...
    PerturbationDegrees=options.PerturbationDegrees, ...
    WorkingGridKeys=working.GridKeys, ...
    PerturbedGridKeys=perturbedWorking.GridKeys, ...
    GridKeysEqual=isequal(working.GridKeys, perturbedWorking.GridKeys), ...
    MatcherPolicy="exhaustive", Detectors=records);

if ~isfolder(options.OutputDirectory)
    mkdir(options.OutputDirectory);
end
jsonPath = fullfile(options.OutputDirectory, "summary.json");
writeText(jsonPath, jsonencode(summary, PrettyPrint=true));
matPath = fullfile(options.OutputDirectory, "summary.mat");
save(matPath, "summary");
artifacts = struct(OutputDirectory=options.OutputDirectory, ...
    SummaryPath=string(jsonPath), MatPath=string(matPath));

for record = records
    format = "%s: exact features=%d matches=%d raw=%d perturbed=%d " + ...
        "retention=%.3f\n";
    fprintf(format, record.Detector, record.ExactFeatureRecords, ...
        record.ExactRawMatchRecords, record.BaselineRawMatchCount, ...
        record.PerturbedRawMatchCount, record.RawMatchRetentionFraction);
end
fprintf("Feature repeatability artifacts: %s\n", artifacts.OutputDirectory);
end

function options = mergeOptions(options, projectRoot)
if ~isstruct(options) || ~isscalar(options)
    error("alignment_feature_repeatability_evaluation:invalidOptions", ...
        "Options must be a scalar struct.");
end
defaults = struct(OutputDirectory=fullfile(projectRoot, "artifacts", ...
    "alignment_feature_repeatability"), ...
    SimulationOptions=struct(), ...
    RenderOptions=struct(OutputSize=[768 768]), ...
    PerturbationDegrees=[0.01 0 0], MaxFeatures=2000, MaxRatio=0.9);
names = fieldnames(defaults);
for k = 1:numel(names)
    if isfield(options, names{k})
        defaults.(names{k}) = options.(names{k});
    end
end
defaults.OutputDirectory = string(defaults.OutputDirectory);
defaults.PerturbationDegrees = double(defaults.PerturbationDegrees(:).');
if ~isscalar(defaults.OutputDirectory) || ...
        strlength(defaults.OutputDirectory) == 0 || ...
        numel(defaults.PerturbationDegrees) ~= 3 || ...
        any(~isfinite(defaults.PerturbationDegrees)) || ...
        ~isnumeric(defaults.MaxFeatures) || ~isscalar(defaults.MaxFeatures) || ...
        fix(defaults.MaxFeatures) ~= defaults.MaxFeatures || ...
        defaults.MaxFeatures < 1 || ~isnumeric(defaults.MaxRatio) || ...
        ~isscalar(defaults.MaxRatio) || ~isfinite(defaults.MaxRatio) || ...
        defaults.MaxRatio <= 0 || defaults.MaxRatio > 1
    error("alignment_feature_repeatability_evaluation:invalidOptions", ...
        "Output, perturbation, feature-count, or match-ratio option is invalid.");
end
options = defaults;
end

function scene = perturbMovingLayer(scene, perturbationDegrees)
layer = scene.layers(2);
if isfield(layer, "ViewVectorAngularOffsetsDegrees")
    offsets = double(layer.ViewVectorAngularOffsetsDegrees(:));
else
    offsets = zeros(3, 1);
end
layer.ViewVectorAngularOffsetsDegrees = ...
    offsets + perturbationDegrees(:);
scene.layers(2) = layer;
end

function record = emptyRecord()
record = struct(Detector="", ExactFeatureRecords=false, ...
    ExactRawMatchRecords=false, BaselineFeatureCounts=zeros(1, 0), ...
    PerturbedFeatureCounts=zeros(1, 0), BaselineRawMatchCount=0, ...
    PerturbedRawMatchCount=0, RawMatchRetentionFraction=NaN, ...
    BaselineDiagnostics=struct(), PerturbedDiagnostics=struct());
end

function tf = exactFeatureRecords(first, second)
tf = numel(first.Features) == numel(second.Features);
if ~tf
    return
end
for k = 1:numel(first.Features)
    tf = tf && isequal(first.Features(k).Locations, ...
        second.Features(k).Locations) && ...
        isequal(first.Features(k).Metrics, second.Features(k).Metrics) && ...
        isequal(first.Features(k).DescriptorSize, ...
        second.Features(k).DescriptorSize);
end
end

function tf = exactMatchRecords(first, second)
tf = isequal(first.Matches.IndexPairs, second.Matches.IndexPairs) && ...
    isequal(first.Matches.MatchMetric, second.Matches.MatchMetric) && ...
    isequal(first.Matches.MovingSourceRows, ...
    second.Matches.MovingSourceRows) && ...
    isequal(first.Matches.ReferenceSourceColumns, ...
    second.Matches.ReferenceSourceColumns);
end

function writeText(filePath, value)
fileId = fopen(filePath, "w");
if fileId < 0
    error("alignment_feature_repeatability_evaluation:fileWriteFailed", ...
        "Unable to open %s for writing.", filePath);
end
cleanup = onCleanup(@() fclose(fileId));
fprintf(fileId, "%s", value);
clear cleanup
end
