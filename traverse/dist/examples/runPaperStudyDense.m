function report = runPaperStudyDense(options)
%RUNPAPERSTUDYDENSE Execute the frozen P2 dense WTA/SGM comparison.
%
% Cases may run concurrently only on parpool("threads"). Each case uses the
% same exact truth, labels, frozen per-method scale, and physical-height SGM.
% The compact JSON contains metrics/provenance; optional raw products belong
% in an ignored MAT file. Traceability: algo/main.tex Secs. 10.4--10.5 and 15;
% implementation plan P2 steps 3e--4; D064.

arguments
    options.Mode (1, 1) string ...
        {mustBeMember(options.Mode, ["tuning", "heldout"])} = "tuning"
    options.StudyFile (1, 1) string = ...
        PaperStudyContract.defaultStudyFile
    options.OutcomeIdentifier (1, 1) string = "paper_study_dense_v1"
    options.OutputFile (1, 1) string = ""
    options.FullReportFile (1, 1) string = ""
    options.SourceImplementationCommit (1, 1) string = ""
    options.WorkingPrecision (1, 1) string ...
        {mustBeMember(options.WorkingPrecision, ...
        ["single", "double"])} = "single"
    options.RetainCostVolumes (1, 1) logical = false
    options.RetainCaseProducts (1, 1) logical = true
    options.UseParallel (1, 1) logical = true
    options.NumWorkers (1, 1) double ...
        {mustBeFinite, mustBeInteger, mustBeNonnegative} = 0
    options.Verbose (1, 1) logical = true
end

root = fileparts(fileparts(mfilename("fullpath")));
oldPath = path;
addpath(fullfile(root, "src"));
cleanup = onCleanup(@() path(oldPath));
contract = PaperStudyContract(options.StudyFile);
if contract.State ~= "policy-frozen"
    error("runPaperStudyDense:PolicyNotFrozen", ...
        "Dense P2 execution requires manifest state 'policy-frozen'.");
end
if options.Mode == "heldout"
    if isfield(contract.Manifest, "heldoutOutcome")
        error("runPaperStudyDense:HeldoutAlreadyComplete", ...
            "The committed manifest already records the single held-out run.");
    end
    cases = contract.heldoutCases;
else
    cases = contract.tuningCases;
end

n = height(cases);
caseResult = cell(n, 1);
manifest = contract.Manifest;
precision = options.WorkingPrecision;
retainVolumes = options.RetainCostVolumes;
timer = tic;
if options.UseParallel
    [pool, workers] = threadPool(options.NumWorkers);
    if options.Verbose
        fprintf("P2 dense %s: %d cases on %d thread workers\n", ...
            options.Mode, n, workers);
    end
    parfor (k = 1:n, workers)
        caseResult{k} = evaluateCase(cases(k, :), manifest, ...
            precision, retainVolumes);
    end
    execution = "parallel cases on parpool('threads')";
    poolClass = string(class(pool));
else
    workers = 1;
    poolClass = "none";
    for k = 1:n
        if options.Verbose
            fprintf("P2 dense %s %d/%d: %s\n", ...
                options.Mode, k, n, cases.Identifier(k));
        end
        caseResult{k} = evaluateCase(cases(k, :), manifest, ...
            precision, retainVolumes);
    end
    execution = "serial cases";
end
totalSeconds = toc(timer);

summaryPart = cell(n, 1);
scalePart = cell(n, 1);
caseSeconds = zeros(n, 1);
for k = 1:n
    t = caseResult{k}.Summary;
    t.Case = repmat(cases.Identifier(k), height(t), 1);
    t.Surface = repmat(cases.Surface(k), height(t), 1);
    t.Texture = repmat(cases.Texture(k), height(t), 1);
    t.ConvergenceDegrees = repmat( ...
        cases.ConvergenceDegrees(k), height(t), 1);
    t.ObliquityDegrees = repmat( ...
        cases.ObliquityDegrees(k), height(t), 1);
    t.Radiometry = repmat(cases.Radiometry(k), height(t), 1);
    t.CameraBias = repmat(cases.CameraBias(k), height(t), 1);
    summaryPart{k} = t;
    g = caseResult{k}.ScaleGroups;
    g.Case = repmat(cases.Identifier(k), height(g), 1);
    scalePart{k} = g;
    caseSeconds(k) = caseResult{k}.TotalSeconds;
end
summary = vertcat(summaryPart{:});
scaleGroups = vertcat(scalePart{:});
heldout = options.Mode == "heldout";
artifact = struct( ...
    "identifier", options.OutcomeIdentifier, ...
    "sourceStudyIdentifier", contract.Identifier, ...
    "sourceImplementationCommit", ...
    options.SourceImplementationCommit, ...
    "mode", options.Mode, ...
    "state", options.Mode + "-dense-complete", ...
    "valid", true, ...
    "caseIdentifiers", cases.Identifier.', ...
    "heldoutAccessed", heldout, ...
    "methods", string(contract.Manifest.frozenPolicy.denseMethods), ...
    "regularization", contract.Manifest.regularization, ...
    "workingPrecision", options.WorkingPrecision, ...
    "retainCostVolumes", options.RetainCostVolumes, ...
    "execution", execution, ...
    "numWorkers", workers, ...
    "caseSeconds", caseSeconds.', ...
    "totalSeconds", totalSeconds, ...
    "summary", table2struct(summary), ...
    "scaleGroups", table2struct(scaleGroups));
if ~options.RetainCaseProducts
    caseResult = cell(0, 1);
end
report = struct( ...
    "Mode", options.Mode, ...
    "StudyIdentifier", contract.Identifier, ...
    "StudyState", contract.State, ...
    "CaseIdentifiers", cases.Identifier.', ...
    "Methods", string(contract.Manifest.frozenPolicy.denseMethods), ...
    "Summary", summary, ...
    "ScaleGroups", scaleGroups, ...
    "CaseResults", {caseResult}, ...
    "CaseProductsRetained", options.RetainCaseProducts, ...
    "HeldoutAccessed", heldout, ...
    "Execution", execution, ...
    "PoolClass", poolClass, ...
    "NumWorkers", workers, ...
    "CaseSeconds", caseSeconds, ...
    "TotalSeconds", totalSeconds, ...
    "SummaryArtifact", artifact);
if options.OutputFile ~= ""
    writelines(jsonencode(artifact, PrettyPrint=true), options.OutputFile);
end
if options.FullReportFile ~= ""
    save(options.FullReportFile, "report", "-v7.3");
end
if options.Verbose
    fprintf("P2 dense %s complete: %d cases, %.3f s, " ...
        + "held-out accessed: %s\n", options.Mode, n, totalSeconds, ...
        string(heldout));
    disp(groupsummary(summary, ["Method", "Stage"], "mean", ...
        ["EndpointEpeRmsePixels", "HeightRmseMetres", "Coverage", ...
        "Bad05PixelFraction"]));
end
clear cleanup
end

function out = evaluateCase(caseRow, manifest, precision, retainVolumes)
c = PaperStudySyntheticCase(caseRow, manifest);
r = c.render(WorkingPrecision=precision);
out = PaperStudyDenseEvaluator(manifest).evaluate(r, ...
    RetainCostVolumes=retainVolumes);
end

function [pool, n] = threadPool(requested)
pool = gcp("nocreate");
if isempty(pool)
    pool = parpool("threads");
end
if ~isa(pool, "parallel.ThreadPool")
    error("runPaperStudyDense:ThreadPoolRequired", ...
        "Dense P2 execution requires parpool('threads').");
end
if requested == 0
    n = pool.NumWorkers;
else
    n = requested;
end
if n > pool.NumWorkers
    error("runPaperStudyDense:TooManyWorkers", ...
        "NumWorkers cannot exceed the thread pool size of %d.", ...
        pool.NumWorkers);
end
end
