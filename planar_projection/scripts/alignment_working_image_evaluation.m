function [comparison, artifacts] = alignment_working_image_evaluation( ...
        scene, request, options)
%ALIGNMENT_WORKING_IMAGE_EVALUATION Build Pack 2 renderer review artifacts.
%
% [comparison, artifacts] = alignment_working_image_evaluation(scene, ...
%     request, options) compares sparse alignment radiometry with full-source
% inverse-warp alignment radiometry on the same quantized pair grids. When no
% scene is supplied, the local ignored test_data/10.tif synthetic red/blue
% fixture is used.

if nargin < 1 || isempty(scene)
    projectRoot = fileparts(fileparts(mfilename("fullpath")));
    imagePath = fullfile(projectRoot, "test_data", "10.tif");
    if ~isfile(imagePath)
        error("alignment_working_image_evaluation:missingFixture", ...
            "Supply a real-data scene or make %s available.", imagePath);
    end
    scene = ProjectionAlignmentSyntheticHarness.createSceneFromRgbTiff( ...
        imagePath);
end
if nargin < 2 || isempty(request)
    alignmentOptions = ProjectionAlignmentOptions.validate(struct( ...
        Detector=struct(Method="auto", MaxFeatures=1000), ...
        Matcher=struct(MaxRatio=0.9), ...
        FilterPipeline=struct(GeometricMethod="similarity", ...
        NativeDisplacementMethod="mad")));
    request = struct(Scene=scene, LayerIndices=[2 1], ...
        ReferenceLayerIndex=1, AnalysisBands=[1 1], ...
        Options=alignmentOptions);
end
if nargin < 3 || isempty(options)
    options = struct();
end
if ~isstruct(options) || ~isscalar(options)
    error("alignment_working_image_evaluation:invalidOptions", ...
        "Options must be a scalar struct.");
end

projectRoot = fileparts(fileparts(mfilename("fullpath")));
if isfield(options, "OutputDirectory")
    outputDirectory = string(options.OutputDirectory);
    comparisonOptions = rmfield(options, "OutputDirectory");
else
    outputDirectory = fullfile(projectRoot, "artifacts", ...
        "alignment_working_image_comparison");
    comparisonOptions = options;
end

comparison = ProjectionAlignmentWorkingImageComparison.evaluate( ...
    scene, request, comparisonOptions);
artifacts = ProjectionAlignmentWorkingImageComparison.writeArtifacts( ...
    outputDirectory, comparison);

summary = comparison.Summary;
for modeIndex = 1:numel(summary.Modes)
    mode = summary.Modes(modeIndex);
    fprintf("%s: raw=%s filtered=%s coverage=%s render=%.3fs match=%.3fs\n", ...
        mode.Mode, mat2str(mode.RawMatchCounts), ...
        mat2str(mode.FilteredMatchCounts), ...
        mat2str(mode.SpatialCoverageFraction, 3), ...
        mode.RuntimeSeconds.Render, mode.RuntimeSeconds.Matching);
end
fprintf("Review artifacts: %s\n", artifacts.OutputDirectory);
fprintf("Renderer default decision remains pending real-data user review.\n");
end
