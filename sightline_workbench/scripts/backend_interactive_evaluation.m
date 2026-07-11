%% Backend interactive evaluation setup
% Run this script section-by-section. The first sections launch the app and
% define the artifact directory; later sections run timed backend sweeps.

projectRoot = fileparts(fileparts(mfilename("fullpath")));
addpath(projectRoot);
addpath(fullfile(projectRoot, "src"));

artifactRoot = fullfile(projectRoot, "artifacts", "backend_evaluation");
if ~isfolder(artifactRoot)
    mkdir(artifactRoot);
end

diaryPath = fullfile(artifactRoot, "backend_interactive_evaluation.log");
if strcmp(get(0, "Diary"), "on")
    diary off
end
diary(diaryPath);

imagePaths = [ ...
    fullfile(projectRoot, "test_data", "10.tif"), ...
    fullfile(projectRoot, "test_data", "102.tif")];

fprintf("Backend evaluation artifacts: %s\n", artifactRoot);
fprintf("Diary: %s\n", diaryPath);

%% Recommended first invocation: launch and align interactively
% Adjust layers in the GUI, then run the following sections. Re-run this
% section only when you want to reset the app from source imagery.

app = runProjectionViewerPrototype(imagePaths);

%% Validate a native-ish backend job without rendering
% Omitting OutputSize asks the output-grid planner to keep approximate input
% resolution based on available source GSD, platform step, IFOV/range, and
% mesh-spacing candidates.

nativeJobOptions = struct();
nativeJobOptions.RenderOptions = struct(TileSize=[128 128]);
nativeJobOptions.Execution = struct(Mode="serial");
nativeJobOptions.Output = struct( ...
    Directory=fullfile(artifactRoot, "native_serial"), ...
    WriteFiles=true, ...
    Formats=["png", "tiff"]);

nativeJob = app.exportBackendJob(nativeJobOptions);
nativeJobPath = fullfile(artifactRoot, "native_serial_job.json");
ProjectionBackendJob.write(nativeJobPath, nativeJob);

nativeValidation = validateProjectionBackendJob(nativeJobPath);
nativeOutputSize = nativeValidation.OutputGrid.OutputSize;
nativeResolutionMetersPerPixel = ...
    nativeValidation.OutputGrid.ResolutionMetersPerPixel;
nativePixelSpacingMeters = nativeValidation.OutputGrid.PixelSpacingMeters;

nativeSummary = table( ...
    nativeOutputSize(1), nativeOutputSize(2), ...
    nativeResolutionMetersPerPixel, ...
    nativePixelSpacingMeters(1), nativePixelSpacingMeters(2), ...
    VariableNames=["Rows", "Columns", "ResolutionMetersPerPixel", ...
    "RowSpacingMeters", "ColumnSpacingMeters"]);
disp(nativeSummary);
writetable(nativeSummary, fullfile(artifactRoot, "native_validation_summary.csv"));

%% First backend render: native-ish resolution, serial tiled CPU

nativeRunTimer = tic;
nativeResult = ProjectionBackendProcessor.run(nativeJobPath);
nativeRunSeconds = toc(nativeRunTimer);

nativeRunSummary = table( ...
    nativeResult.OutputGrid.OutputSize(1), ...
    nativeResult.OutputGrid.OutputSize(2), ...
    nativeResult.Readback.TileCount, ...
    nativeResult.Timing.RenderSeconds, ...
    nativeResult.Timing.WriteSeconds, ...
    nativeResult.Timing.TotalSeconds, ...
    nativeRunSeconds, ...
    VariableNames=["Rows", "Columns", "TileCount", "RenderSeconds", ...
    "WriteSeconds", "TotalSeconds", "WallSeconds"]);
disp(nativeRunSummary);
writetable(nativeRunSummary, fullfile(artifactRoot, "native_run_summary.csv"));
save(fullfile(artifactRoot, "native_run_result.mat"), "nativeResult", ...
    "nativeRunSummary", "-v7.3");

%% Tile-size sweep with fixed output size
% This section writes one output folder per tile size and records timing.

fixedOutputSize = nativeOutputSize;
tileSizeCases = [ ...
    64 64; ...
    128 128; ...
    256 256; ...
    128 256; ...
    256 128];

tileSweepRows = table();
for caseIndex = 1:size(tileSizeCases, 1)
    tileSize = tileSizeCases(caseIndex, :);
    runName = sprintf("tile_%03dx%03d", tileSize(1), tileSize(2));
    outputDirectory = fullfile(artifactRoot, "tile_sweep", runName);

    jobOptions = struct();
    jobOptions.RenderOptions = struct(OutputSize=fixedOutputSize, ...
        TileSize=tileSize);
    jobOptions.Execution = struct(Mode="serial");
    jobOptions.Output = struct(Directory=outputDirectory, WriteFiles=true, ...
        Formats="png");

    job = app.exportBackendJob(jobOptions);
    jobPath = fullfile(artifactRoot, "tile_sweep", runName + "_job.json");
    if ~isfolder(fileparts(jobPath))
        mkdir(fileparts(jobPath));
    end
    ProjectionBackendJob.write(jobPath, job);

    validationTimer = tic;
    validation = validateProjectionBackendJob(jobPath);
    validationSeconds = toc(validationTimer);

    runTimer = tic;
    result = ProjectionBackendProcessor.run(jobPath);
    wallSeconds = toc(runTimer);

    newRow = table( ...
        string(runName), tileSize(1), tileSize(2), ...
        validation.OutputGrid.OutputSize(1), ...
        validation.OutputGrid.OutputSize(2), ...
        result.Readback.TileCount, ...
        validationSeconds, result.Timing.RenderSeconds, ...
        result.Timing.WriteSeconds, result.Timing.TotalSeconds, wallSeconds, ...
        VariableNames=["RunName", "TileRows", "TileColumns", "Rows", ...
        "Columns", "TileCount", "ValidationSeconds", "RenderSeconds", ...
        "WriteSeconds", "TotalSeconds", "WallSeconds"]);
    tileSweepRows = [tileSweepRows; newRow]; %#ok<AGROW>
    disp(newRow);
end

writetable(tileSweepRows, fullfile(artifactRoot, "tile_sweep_summary.csv"));
save(fullfile(artifactRoot, "tile_sweep_summary.mat"), "tileSweepRows");

%% Output-size sweep with fixed tile size
% This section varies OutputSize explicitly. Use the previous validation
% section if you want to compare each fixed size against the native-ish plan.

fixedTileSize = [128 128];
nativeRows = nativeOutputSize(1);
nativeColumns = nativeOutputSize(2);
outputSizeCases = unique(round([ ...
    nativeRows nativeColumns; ...
    0.5 * nativeRows 0.5 * nativeColumns; ...
    0.75 * nativeRows 0.75 * nativeColumns; ...
    1.25 * nativeRows 1.25 * nativeColumns; ...
    1.5 * nativeRows 1.5 * nativeColumns]), "rows");
outputSizeCases = max(outputSizeCases, 2);

outputSweepRows = table();
for caseIndex = 1:size(outputSizeCases, 1)
    outputSize = outputSizeCases(caseIndex, :);
    runName = sprintf("output_%04dx%04d", outputSize(1), outputSize(2));
    outputDirectory = fullfile(artifactRoot, "output_sweep", runName);

    jobOptions = struct();
    jobOptions.RenderOptions = struct(OutputSize=outputSize, ...
        TileSize=fixedTileSize);
    jobOptions.Execution = struct(Mode="serial");
    jobOptions.Output = struct(Directory=outputDirectory, WriteFiles=true, ...
        Formats="png");

    job = app.exportBackendJob(jobOptions);
    jobPath = fullfile(artifactRoot, "output_sweep", runName + "_job.json");
    if ~isfolder(fileparts(jobPath))
        mkdir(fileparts(jobPath));
    end
    ProjectionBackendJob.write(jobPath, job);

    validationTimer = tic;
    validation = validateProjectionBackendJob(jobPath);
    validationSeconds = toc(validationTimer);

    runTimer = tic;
    result = ProjectionBackendProcessor.run(jobPath);
    wallSeconds = toc(runTimer);

    pixelCount = prod(validation.OutputGrid.OutputSize);
    newRow = table( ...
        string(runName), outputSize(1), outputSize(2), pixelCount, ...
        result.Readback.TileCount, validationSeconds, ...
        result.Timing.RenderSeconds, result.Timing.WriteSeconds, ...
        result.Timing.TotalSeconds, wallSeconds, ...
        VariableNames=["RunName", "Rows", "Columns", "PixelCount", ...
        "TileCount", "ValidationSeconds", "RenderSeconds", ...
        "WriteSeconds", "TotalSeconds", "WallSeconds"]);
    outputSweepRows = [outputSweepRows; newRow]; %#ok<AGROW>
    disp(newRow);
end

writetable(outputSweepRows, fullfile(artifactRoot, "output_sweep_summary.csv"));
save(fullfile(artifactRoot, "output_sweep_summary.mat"), "outputSweepRows");

%% Optional serial-vs-threads comparison
% This uses parpool("threads") only. It writes one serial and one threads run
% at the same output size and tile size for a quick equivalence/timing check.

comparisonOutputSize = nativeOutputSize;
comparisonTileSize = [128 128];
comparisonModes = ["serial", "threads"];
comparisonRows = table();
comparisonResults = cell(1, numel(comparisonModes));

for modeIndex = 1:numel(comparisonModes)
    executionMode = comparisonModes(modeIndex);
    runName = "compare_" + executionMode;
    outputDirectory = fullfile(artifactRoot, "execution_compare", runName);

    jobOptions = struct();
    jobOptions.RenderOptions = struct(OutputSize=comparisonOutputSize, ...
        TileSize=comparisonTileSize);
    jobOptions.Execution = struct(Mode=executionMode);
    jobOptions.Output = struct(Directory=outputDirectory, WriteFiles=true, ...
        Formats="png");

    job = app.exportBackendJob(jobOptions);
    jobPath = fullfile(artifactRoot, "execution_compare", runName + "_job.json");
    if ~isfolder(fileparts(jobPath))
        mkdir(fileparts(jobPath));
    end
    ProjectionBackendJob.write(jobPath, job);

    runTimer = tic;
    result = ProjectionBackendProcessor.run(jobPath);
    wallSeconds = toc(runTimer);
    comparisonResults{modeIndex} = result;

    newRow = table( ...
        executionMode, result.Readback.TileCount, ...
        result.Timing.RenderSeconds, result.Timing.WriteSeconds, ...
        result.Timing.TotalSeconds, wallSeconds, ...
        VariableNames=["ExecutionMode", "TileCount", "RenderSeconds", ...
        "WriteSeconds", "TotalSeconds", "WallSeconds"]);
    comparisonRows = [comparisonRows; newRow]; %#ok<AGROW>
    disp(newRow);
end

if numel(comparisonResults) == 2
    maxAbsDifference = max(abs(comparisonResults{1}.Readback.Image - ...
        comparisonResults{2}.Readback.Image), [], "all");
    maskMismatchCount = nnz(comparisonResults{1}.Readback.ValidMask ~= ...
        comparisonResults{2}.Readback.ValidMask);
else
    maxAbsDifference = NaN;
    maskMismatchCount = NaN;
end

comparisonSummary = table(maxAbsDifference, maskMismatchCount, ...
    VariableNames=["MaxAbsDifference", "MaskMismatchCount"]);
disp(comparisonSummary);

writetable(comparisonRows, fullfile(artifactRoot, "execution_compare_summary.csv"));
writetable(comparisonSummary, ...
    fullfile(artifactRoot, "execution_compare_equivalence.csv"));
save(fullfile(artifactRoot, "execution_compare_results.mat"), ...
    "comparisonRows", "comparisonSummary", "comparisonResults", "-v7.3");

%% Stop logging

diary off
