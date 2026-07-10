classdef ProjectionAlignmentWorkingImageComparison
    %ProjectionAlignmentWorkingImageComparison Compare alignment radiometry modes.

    properties (Constant)
        Format = "ProjectionAlignmentWorkingImageComparison"
        Version = 1
        Modes = ["sparseIntensityScatteredInterpolant", ...
            "fullSourceInverseWarp"]
    end

    methods (Static)
        function comparison = evaluate(scene, request, options)
            %evaluate Measure repeatability, matching, solve, memory, and time.
            if nargin < 3
                options = struct();
            end
            scene = ProjectionLayerIdentity.ensureScene(scene);
            if nargin < 2 || isempty(request)
                request = struct();
            end
            request.Scene = scene;
            request = ProjectionAlignmentRequest.validate(request);
            options = ProjectionAlignmentWorkingImageComparison.mergeOptions( ...
                options, request);
            perturbedScene = ...
                ProjectionAlignmentWorkingImageComparison.perturbScene( ...
                scene, request, options.PerturbationDegrees);

            runs = repmat(ProjectionAlignmentWorkingImageComparison.emptyRun(), ...
                1, numel(ProjectionAlignmentWorkingImageComparison.Modes));
            summaries = repmat( ...
                ProjectionAlignmentWorkingImageComparison.emptySummary(), ...
                1, numel(runs));
            for modeIndex = 1:numel(runs)
                mode = ProjectionAlignmentWorkingImageComparison.Modes(modeIndex);
                [runs(modeIndex), summaries(modeIndex)] = ...
                    ProjectionAlignmentWorkingImageComparison.evaluateMode( ...
                    scene, perturbedScene, request, options, mode);
            end

            comparison = struct( ...
                Format=ProjectionAlignmentWorkingImageComparison.Format, ...
                Version=ProjectionAlignmentWorkingImageComparison.Version, ...
                RuntimeOnly=true, Request=request, Options=options, ...
                Runs=runs, Summary=struct( ...
                Format=ProjectionAlignmentWorkingImageComparison.Format + "Summary", ...
                Version=ProjectionAlignmentWorkingImageComparison.Version, ...
                PairDirection="movingToReference", ...
                PerturbationDegrees=options.PerturbationDegrees, ...
                Modes=summaries, DefaultDecision="pendingUserReview", ...
                CurrentDefault="sparseIntensityScatteredInterpolant"));
        end

        function summary = summary(comparison)
            %summary Return the JSON-safe comparison summary.
            ProjectionAlignmentWorkingImageComparison.validateComparison(comparison);
            summary = comparison.Summary;
        end

        function artifacts = writeArtifacts(outputDirectory, comparison)
            %writeArtifacts Save summaries and review PNGs for a decision gate.
            ProjectionAlignmentWorkingImageComparison.validateComparison(comparison);
            outputDirectory = string(outputDirectory);
            if ~isscalar(outputDirectory) || strlength(outputDirectory) == 0
                error("ProjectionAlignmentWorkingImageComparison:invalidOutput", ...
                    "Output directory must be a nonempty scalar path.");
            end
            if ~isfolder(outputDirectory)
                mkdir(outputDirectory);
            end

            summaryPath = fullfile(outputDirectory, "summary.json");
            ProjectionAlignmentWorkingImageComparison.writeText( ...
                summaryPath, jsonencode(comparison.Summary, PrettyPrint=true));
            matPath = fullfile(outputDirectory, "summary.mat");
            summary = comparison.Summary;
            save(matPath, "summary");

            imagePaths = strings(0, 1);
            overlayPaths = strings(0, 1);
            for modeIndex = 1:numel(comparison.Runs)
                run = comparison.Runs(modeIndex);
                for pairIndex = 1:numel(run.WorkingImages.PairWorkingImages)
                    pairWorking = run.WorkingImages.PairWorkingImages(pairIndex);
                    for layerPosition = 1:numel(pairWorking.LayerImages)
                        layerImage = pairWorking.LayerImages(layerPosition);
                        fileName = sprintf("%s_pair%02d_%s.png", ...
                            ProjectionAlignmentWorkingImageComparison.modeLabel( ...
                            run.Mode), pairIndex, layerImage.LayerId);
                        imagePath = fullfile(outputDirectory, fileName);
                        imwrite(ProjectionAlignmentWorkingImageComparison.reviewImage( ...
                            layerImage.Image, layerImage.ValidMask), imagePath);
                        imagePaths(end + 1, 1) = string(imagePath); %#ok<AGROW>
                    end
                    if run.MatchResult.Capabilities.HasShowMatchedFeatures
                        overlayName = sprintf("%s_pair%02d_matches.png", ...
                            ProjectionAlignmentWorkingImageComparison.modeLabel( ...
                            run.Mode), pairIndex);
                        overlayPath = fullfile(outputDirectory, overlayName);
                        fig = ProjectionAlignmentFeatureMatcher.showMatchedPair( ...
                            run.WorkingImages, run.MatchResult, pairIndex, ...
                            struct(Visible="off"));
                        cleanup = onCleanup(@() delete(fig));
                        exportgraphics(fig, overlayPath, Resolution=150);
                        clear cleanup
                        overlayPaths(end + 1, 1) = ...
                            string(overlayPath); %#ok<AGROW>
                    end
                end
            end
            artifacts = struct(OutputDirectory=outputDirectory, ...
                SummaryPath=string(summaryPath), MatPath=string(matPath), ...
                ImagePaths=imagePaths, OverlayPaths=overlayPaths);
        end
    end

    methods (Static, Access = private)
        function [run, summary] = evaluateMode(scene, perturbedScene, request, ...
                options, mode)
            renderOptions = options.RenderOptions;
            renderOptions.NumericalMode = mode;

            timer = tic;
            working = ProjectionAlignmentWorkingImageRenderer.render( ...
                scene, request, renderOptions);
            renderSeconds = toc(timer);
            timer = tic;
            repeat = ProjectionAlignmentWorkingImageRenderer.render( ...
                scene, request, renderOptions);
            repeatSeconds = toc(timer);
            timer = tic;
            perturbed = ProjectionAlignmentWorkingImageRenderer.render( ...
                perturbedScene, request, renderOptions);
            perturbedSeconds = toc(timer);

            timer = tic;
            matches = ProjectionAlignmentFeatureMatcher.match( ...
                working, request.Options);
            matchingSeconds = toc(timer);
            timer = tic;
            filtered = ProjectionAlignmentMatchFilter.filter( ...
                matches, request.Options);
            filteringSeconds = toc(timer);
            timer = tic;
            perturbedMatches = ProjectionAlignmentFeatureMatcher.match( ...
                perturbed, request.Options);
            perturbedMatchingSeconds = toc(timer);

            solve = ProjectionAlignmentWorkingImageComparison.solveSummary( ...
                scene, filtered, request.Options, options.RunSolve);
            run = struct(Mode=mode, WorkingImages=working, ...
                RepeatWorkingImages=repeat, PerturbedWorkingImages=perturbed, ...
                MatchResult=matches, FilteredMatchResult=filtered, ...
                PerturbedMatchResult=perturbedMatches);
            runInfo = whos("run");
            summary = struct(Mode=mode, ...
                GridKeys=working.GridKeys, OutputSizes=working.OutputSize, ...
                ExactRepeat= ...
                ProjectionAlignmentWorkingImageComparison.repeatMetrics( ...
                working, repeat), ...
                SmallPerturbation= ...
                ProjectionAlignmentWorkingImageComparison.perturbationMetrics( ...
                working, perturbed, matches, perturbedMatches), ...
                RawMatchCounts=[matches.Matches.Count], ...
                FilteredMatchCounts=[filtered.Matches.Count], ...
                FilterStageCounts= ...
                ProjectionAlignmentWorkingImageComparison.filterStageCounts( ...
                filtered), ...
                SpatialCoverageFraction= ...
                ProjectionAlignmentWorkingImageComparison.spatialCoverage( ...
                working, matches), ...
                TextureMetrics= ...
                ProjectionAlignmentWorkingImageComparison.textureMetrics(working), ...
                Solve=solve, RuntimeSeconds=struct(Render=renderSeconds, ...
                ExactRepeatRender=repeatSeconds, ...
                PerturbedRender=perturbedSeconds, Matching=matchingSeconds, ...
                Filtering=filteringSeconds, ...
                PerturbedMatching=perturbedMatchingSeconds), ...
                RuntimeBytes=runInfo.bytes);
        end

        function metrics = repeatMetrics(first, second)
            maxDifference = 0;
            maskEqual = true;
            for pairIndex = 1:numel(first.PairWorkingImages)
                firstPair = first.PairWorkingImages(pairIndex);
                secondPair = second.PairWorkingImages(pairIndex);
                for layerIndex = 1:numel(firstPair.LayerImages)
                    firstLayer = firstPair.LayerImages(layerIndex);
                    secondLayer = secondPair.LayerImages(layerIndex);
                    commonMask = firstLayer.ValidMask & secondLayer.ValidMask;
                    if any(commonMask, "all")
                        difference = abs(double(firstLayer.Image(commonMask)) - ...
                            double(secondLayer.Image(commonMask)));
                        maxDifference = max(maxDifference, max(difference));
                    end
                    maskEqual = maskEqual && ...
                        isequal(firstLayer.ValidMask, secondLayer.ValidMask);
                end
            end
            metrics = struct(GridKeysEqual=isequal(first.GridKeys, second.GridKeys), ...
                MasksEqual=maskEqual, MaxAbsoluteImageDifference=maxDifference);
        end

        function metrics = perturbationMetrics(baseline, perturbed, ...
                matches, perturbedMatches)
            baselineCounts = [matches.Matches.Count];
            perturbedCounts = [perturbedMatches.Matches.Count];
            denominator = max(baselineCounts, 1);
            metrics = struct(GridKeysEqual= ...
                baseline.GridKeys == perturbed.GridKeys, ...
                BaselineRawMatchCounts=baselineCounts, ...
                PerturbedRawMatchCounts=perturbedCounts, ...
                MatchCountRetentionFraction=perturbedCounts ./ denominator);
        end

        function counts = filterStageCounts(filtered)
            pipelines = filtered.Diagnostics.FilterPipeline;
            counts = repmat(struct(Pair=[0 0], Initial=0, OverlapMask=0, ...
                DescriptorScore=0, RatioUniqueness=0, GeometricOutlier=0, ...
                NativeDisplacement=0, Radial=0, Final=0), 1, numel(pipelines));
            for k = 1:numel(pipelines)
                stage = pipelines(k).StageCounts;
                counts(k) = struct(Pair=pipelines(k).Pair, ...
                    Initial=stage.Initial, OverlapMask=stage.OverlapMask, ...
                    DescriptorScore=stage.DescriptorScore, ...
                    RatioUniqueness=stage.RatioUniqueness, ...
                    GeometricOutlier=stage.GeometricOutlier, ...
                    NativeDisplacement=stage.NativeDisplacement, ...
                    Radial=stage.Radial, Final=pipelines(k).FinalCount);
            end
        end

        function coverage = spatialCoverage(working, matches)
            coverage = zeros(1, numel(matches.Matches));
            for k = 1:numel(matches.Matches)
                pairMatch = matches.Matches(k);
                if pairMatch.Count < 2
                    continue
                end
                pairWorking = working.PairWorkingImages(k);
                bounds = pairWorking.OutputGrid.Bounds;
                span = [diff(bounds.X), diff(bounds.Y)];
                points = [pairMatch.MovingPlaneCoordinates; ...
                    pairMatch.ReferencePlaneCoordinates];
                pointSpan = max(points, [], 1) - min(points, [], 1);
                coverage(k) = prod(min(pointSpan ./ max(span, eps), 1));
            end
        end

        function metrics = textureMetrics(working)
            layerCount = sum(arrayfun(@(pair) numel(pair.LayerImages), ...
                working.PairWorkingImages));
            metrics = repmat(struct(PairIndex=0, LayerId="", ...
                GradientRms=NaN, GradientP95=NaN, ValidFraction=0), ...
                1, layerCount);
            cursor = 0;
            for pairIndex = 1:numel(working.PairWorkingImages)
                pairWorking = working.PairWorkingImages(pairIndex);
                for layerIndex = 1:numel(pairWorking.LayerImages)
                    cursor = cursor + 1;
                    layer = pairWorking.LayerImages(layerIndex);
                    imageData = double(layer.Image);
                    [gx, gy] = gradient(imageData);
                    magnitude = hypot(gx, gy);
                    values = magnitude(layer.ValidMask & isfinite(magnitude));
                    metrics(cursor).PairIndex = pairIndex;
                    metrics(cursor).LayerId = layer.LayerId;
                    metrics(cursor).ValidFraction = nnz(layer.ValidMask) / ...
                        numel(layer.ValidMask);
                    if ~isempty(values)
                        metrics(cursor).GradientRms = sqrt(mean(values.^2));
                        metrics(cursor).GradientP95 = prctile(values, 95);
                    end
                end
            end
        end

        function summary = solveSummary(scene, filtered, alignmentOptions, runSolve)
            summary = struct(Attempted=false, Status="notRun", ...
                ErrorIdentifier="", ErrorMessage="", RmsBefore=NaN, ...
                RmsAfter=NaN, AnyBoundHit=false);
            if ~runSolve || isempty(filtered.Matches) || ...
                    any([filtered.Matches.Count] < 3)
                return
            end
            summary.Attempted = true;
            try
                result = ProjectionAlignmentOpkSolver.solve( ...
                    scene, filtered, alignmentOptions);
                summary.Status = result.Status;
                summary.RmsBefore = result.Residuals.RmsBefore;
                summary.RmsAfter = result.Residuals.RmsAfter;
                summary.AnyBoundHit = result.Diagnostics.AnyBoundHit;
            catch ME
                summary.Status = "error";
                summary.ErrorIdentifier = string(ME.identifier);
                summary.ErrorMessage = string(ME.message);
            end
        end

        function scene = perturbScene(scene, request, perturbationDegrees)
            schedule = ProjectionAlignmentScheduler.build(scene, request);
            movingLayerId = schedule.Pairs(1).MovingLayerId;
            layerIndex = ProjectionLayerIdentity.indexForId(scene, movingLayerId);
            offsets = ProjectionAlignmentWorkingImageComparison.layerOffsets( ...
                scene.layers(layerIndex));
            scene.layers(layerIndex).ViewVectorAngularOffsetsDegrees = ...
                offsets + perturbationDegrees(:);
        end

        function options = mergeOptions(options, request)
            if isempty(options)
                options = struct();
            end
            if ~isstruct(options) || ~isscalar(options)
                error("ProjectionAlignmentWorkingImageComparison:invalidOptions", ...
                    "Comparison options must be a scalar struct.");
            end
            defaults = struct(RenderOptions=struct(OutputSize=[512 512]), ...
                PerturbationDegrees=[1e-4 0 0], RunSolve=true);
            names = fieldnames(defaults);
            for k = 1:numel(names)
                if isfield(options, names{k})
                    defaults.(names{k}) = options.(names{k});
                end
            end
            perturbation = double(defaults.PerturbationDegrees(:).');
            if numel(perturbation) ~= 3 || any(~isfinite(perturbation))
                error("ProjectionAlignmentWorkingImageComparison:invalidOptions", ...
                    "PerturbationDegrees must be a finite three-vector.");
            end
            defaults.PerturbationDegrees = perturbation;
            defaults.RunSolve = logical(defaults.RunSolve);
            if ~isscalar(defaults.RunSolve)
                error("ProjectionAlignmentWorkingImageComparison:invalidOptions", ...
                    "RunSolve must be a scalar logical value.");
            end
            defaults.AlignmentOptions = request.Options;
            options = defaults;
        end

        function run = emptyRun()
            run = struct(Mode="", WorkingImages=struct(), ...
                RepeatWorkingImages=struct(), PerturbedWorkingImages=struct(), ...
                MatchResult=struct(), FilteredMatchResult=struct(), ...
                PerturbedMatchResult=struct());
        end

        function summary = emptySummary()
            summary = struct(Mode="", GridKeys=strings(0), ...
                OutputSizes=zeros(0, 2), ExactRepeat=struct(), ...
                SmallPerturbation=struct(), RawMatchCounts=zeros(1, 0), ...
                FilteredMatchCounts=zeros(1, 0), FilterStageCounts=struct([]), ...
                SpatialCoverageFraction=zeros(1, 0), TextureMetrics=struct([]), ...
                Solve=struct(), RuntimeSeconds=struct(), RuntimeBytes=0);
        end

        function imageData = reviewImage(imageData, validMask)
            imageData = double(imageData);
            values = imageData(validMask & isfinite(imageData));
            if isempty(values)
                imageData = zeros(size(imageData), "uint8");
                return
            end
            limits = prctile(values, [1 99]);
            if limits(2) <= limits(1)
                limits = [min(values) max(values)];
            end
            if limits(2) <= limits(1)
                imageData = zeros(size(imageData), "uint8");
                imageData(validMask) = 128;
                return
            end
            imageData = (imageData - limits(1)) / (limits(2) - limits(1));
            imageData = uint8(255 * min(max(imageData, 0), 1));
            imageData(~validMask) = 0;
        end

        function label = modeLabel(mode)
            if mode == "fullSourceInverseWarp"
                label = "full_source";
            else
                label = "sparse";
            end
        end

        function offsets = layerOffsets(layer)
            if isfield(layer, "ViewVectorAngularOffsetsDegrees")
                offsets = double(layer.ViewVectorAngularOffsetsDegrees(:));
            else
                offsets = zeros(3, 1);
            end
        end

        function validateComparison(comparison)
            if ~isstruct(comparison) || ~isscalar(comparison) || ...
                    ~isfield(comparison, "Format") || ...
                    string(comparison.Format) ~= ...
                    ProjectionAlignmentWorkingImageComparison.Format || ...
                    ~isfield(comparison, "Runs") || ...
                    ~isfield(comparison, "Summary")
                error("ProjectionAlignmentWorkingImageComparison:invalidComparison", ...
                    "Comparison must come from evaluate.");
            end
        end

        function writeText(filePath, text)
            fileId = fopen(filePath, "w");
            if fileId < 0
                error("ProjectionAlignmentWorkingImageComparison:fileWriteFailed", ...
                    "Unable to open %s for writing.", filePath);
            end
            cleanup = onCleanup(@() fclose(fileId));
            fprintf(fileId, "%s", text);
            clear cleanup
        end
    end
end
