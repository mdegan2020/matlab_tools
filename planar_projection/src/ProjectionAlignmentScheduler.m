classdef ProjectionAlignmentScheduler
    %ProjectionAlignmentScheduler Build and score pairwise alignment schedules.

    properties (Constant)
        Format = "ProjectionAlignmentPairSchedule"
        Version = 1
    end

    methods (Static)
        function schedule = build(scene, request)
            %build Return ordered layer pairs for multi-image matching.
            if nargin < 1
                scene = [];
            end
            if nargin < 2
                request = struct();
            end
            if ~isempty(scene) && ~isfield(request, "Scene")
                request.Scene = scene;
            end

            request = ProjectionAlignmentRequest.validate(request);
            options = request.Options.Scheduling;
            layerIndices = ProjectionAlignmentScheduler.selectedLayerIndices( ...
                scene, request, options);
            if numel(layerIndices) < 2
                error("ProjectionAlignmentScheduler:insufficientLayers", ...
                    "At least two scheduled layers are required.");
            end

            referenceIndex = ProjectionAlignmentScheduler.referenceIndex( ...
                layerIndices, request, options);
            pairMatrix = ProjectionAlignmentScheduler.strategyPairs( ...
                layerIndices, referenceIndex, options.Strategy);

            schedule = struct();
            schedule.Format = ProjectionAlignmentScheduler.Format;
            schedule.Version = ProjectionAlignmentScheduler.Version;
            schedule.Strategy = options.Strategy;
            schedule.PairSelection = options.PairSelection;
            schedule.IncludeHiddenLayers = options.IncludeHiddenLayers;
            schedule.LayerIndices = layerIndices;
            schedule.ReferenceLayerIndex = referenceIndex;
            schedule.Pairs = ProjectionAlignmentScheduler.pairStructs( ...
                pairMatrix, layerIndices, referenceIndex, options.Strategy);
            schedule.PairCount = numel(schedule.Pairs);
            schedule.Diagnostics = ProjectionAlignmentScheduler.scheduleDiagnostics( ...
                scene, request, layerIndices, schedule.Pairs);
        end

        function diagnostics = scoreMatches(matchResult)
            %scoreMatches Return pairwise match diagnostics and confidence.
            if ~isstruct(matchResult) || ~isscalar(matchResult) || ...
                    ~isfield(matchResult, "Matches")
                error("ProjectionAlignmentScheduler:invalidMatchResult", ...
                    "Match result must contain a Matches struct array.");
            end

            matches = matchResult.Matches;
            pairDiagnostics = struct("Pair", {}, "Order", {}, "MatchCount", {}, ...
                "FeatureCounts", {}, "OverlapPixelCount", {}, "Confidence", {});
            for k = 1:numel(matches)
                pairMatch = matches(k);
                featureCounts = ProjectionAlignmentScheduler.fieldOrDefault( ...
                    pairMatch, "FeatureCounts", [0 0]);
                matchCount = ProjectionAlignmentScheduler.fieldOrDefault( ...
                    pairMatch, "Count", 0);
                overlapCount = 0;
                if isfield(pairMatch, "OverlapMask")
                    overlapCount = nnz(pairMatch.OverlapMask);
                end
                pairDiagnostics(k).Pair = pairMatch.Pair;
                pairDiagnostics(k).Order = k;
                pairDiagnostics(k).MatchCount = matchCount;
                pairDiagnostics(k).FeatureCounts = featureCounts;
                pairDiagnostics(k).OverlapPixelCount = overlapCount;
                pairDiagnostics(k).Confidence = ...
                    ProjectionAlignmentScheduler.confidenceScore( ...
                    matchCount, featureCounts, overlapCount);
            end

            diagnostics = struct();
            diagnostics.PairDiagnostics = pairDiagnostics;
            diagnostics.TotalMatches = sum([pairDiagnostics.MatchCount]);
            diagnostics.MeanConfidence = ...
                ProjectionAlignmentScheduler.meanConfidence(pairDiagnostics);
        end
    end

    methods (Static, Access = private)
        function layerIndices = selectedLayerIndices(scene, request, options)
            if options.PairSelection == "all" && ...
                    ProjectionAlignmentScheduler.hasSceneLayers(scene)
                layerIndices = 1:numel(scene.layers);
            else
                layerIndices = request.LayerIndices;
            end

            if options.PairSelection ~= "all" && ~options.IncludeHiddenLayers && ...
                    ProjectionAlignmentScheduler.hasSceneLayers(scene)
                selectable = ProjectionAlignmentScheduler.selectableMask( ...
                    scene, layerIndices);
                layerIndices = layerIndices(selectable);
            end
        end

        function tf = hasSceneLayers(scene)
            tf = isstruct(scene) && isscalar(scene) && isfield(scene, "layers") && ...
                ~isempty(scene.layers) && isstruct(scene.layers);
        end

        function mask = selectableMask(scene, layerIndices)
            mask = true(1, numel(layerIndices));
            for k = 1:numel(layerIndices)
                layer = scene.layers(layerIndices(k));
                if isfield(layer, "Visible") && ~logical(layer.Visible)
                    mask(k) = false;
                end
                if isfield(layer, "Enabled") && ~logical(layer.Enabled)
                    mask(k) = false;
                end
            end
        end

        function referenceIndex = referenceIndex(layerIndices, request, options)
            referenceIndex = options.ReferenceLayerIndex;
            if isempty(referenceIndex)
                referenceIndex = request.ReferenceLayerIndex;
            end
            if isempty(referenceIndex) || ~ismember(referenceIndex, layerIndices)
                referenceIndex = layerIndices(ceil(numel(layerIndices) / 2));
            end
        end

        function pairs = strategyPairs(layerIndices, referenceIndex, strategy)
            switch strategy
                case {"centerOut", "twoImage"}
                    if strategy == "twoImage" && numel(layerIndices) ~= 2
                        error("ProjectionAlignmentScheduler:invalidTwoImageSchedule", ...
                            "twoImage scheduling requires exactly two layers.");
                    end
                    pairs = ProjectionAlignmentScheduler.centerOutPairs( ...
                        layerIndices, referenceIndex);
                case "centerStar"
                    pairs = ProjectionAlignmentScheduler.centerStarPairs( ...
                        layerIndices, referenceIndex);
                case "adjacentChain"
                    pairs = ProjectionAlignmentScheduler.adjacentChainPairs( ...
                        layerIndices);
                case "hybrid"
                    pairs = ProjectionAlignmentScheduler.uniquePairs([ ...
                        ProjectionAlignmentScheduler.centerOutPairs( ...
                        layerIndices, referenceIndex); ...
                        ProjectionAlignmentScheduler.centerStarPairs( ...
                        layerIndices, referenceIndex)]);
            end
        end

        function pairs = centerOutPairs(layerIndices, referenceIndex)
            refPosition = find(layerIndices == referenceIndex, 1, "first");
            maxDistance = max(refPosition - 1, numel(layerIndices) - refPosition);
            pairs = zeros(0, 2);
            for distance = 1:maxDistance
                leftPosition = refPosition - distance;
                if leftPosition >= 1
                    pairs(end + 1, :) = [ ...
                        layerIndices(leftPosition), ...
                        layerIndices(leftPosition + 1)]; %#ok<AGROW>
                end
                rightPosition = refPosition + distance;
                if rightPosition <= numel(layerIndices)
                    pairs(end + 1, :) = [ ...
                        layerIndices(rightPosition), ...
                        layerIndices(rightPosition - 1)]; %#ok<AGROW>
                end
            end
        end

        function pairs = centerStarPairs(layerIndices, referenceIndex)
            refPosition = find(layerIndices == referenceIndex, 1, "first");
            maxDistance = max(refPosition - 1, numel(layerIndices) - refPosition);
            pairs = zeros(0, 2);
            for distance = 1:maxDistance
                leftPosition = refPosition - distance;
                if leftPosition >= 1
                    pairs(end + 1, :) = [ ...
                        layerIndices(leftPosition), referenceIndex]; %#ok<AGROW>
                end
                rightPosition = refPosition + distance;
                if rightPosition <= numel(layerIndices)
                    pairs(end + 1, :) = [ ...
                        layerIndices(rightPosition), referenceIndex]; %#ok<AGROW>
                end
            end
        end

        function pairs = adjacentChainPairs(layerIndices)
            pairs = zeros(max(0, numel(layerIndices) - 1), 2);
            for k = 1:size(pairs, 1)
                pairs(k, :) = layerIndices(k:k + 1);
            end
        end

        function pairs = uniquePairs(pairs)
            if isempty(pairs)
                return
            end
            normalized = sort(pairs, 2);
            [~, keepIndices] = unique(normalized, "rows", "stable");
            pairs = pairs(sort(keepIndices), :);
        end

        function pairs = pairStructs(pairMatrix, layerIndices, referenceIndex, strategy)
            pairs = struct("Pair", {}, "Order", {}, "Strategy", {}, ...
                "DistanceFromReference", {}, "IsAdjacent", {}, ...
                "IncludesReference", {});
            referencePosition = find(layerIndices == referenceIndex, 1, "first");
            for k = 1:size(pairMatrix, 1)
                pair = pairMatrix(k, :);
                pairPositions = [ ...
                    find(layerIndices == pair(1), 1, "first"), ...
                    find(layerIndices == pair(2), 1, "first")];
                pairs(k).Pair = pair;
                pairs(k).Order = k;
                pairs(k).Strategy = strategy;
                pairs(k).DistanceFromReference = min(abs(pairPositions - ...
                    referencePosition));
                pairs(k).IsAdjacent = abs(diff(pairPositions)) == 1;
                pairs(k).IncludesReference = any(pair == referenceIndex);
            end
        end

        function diagnostics = scheduleDiagnostics(scene, request, layerIndices, pairs)
            diagnostics = struct();
            diagnostics.RequestedLayerIndices = request.LayerIndices;
            diagnostics.ScheduledLayerIndices = layerIndices;
            diagnostics.ExcludedLayerIndices = setdiff(request.LayerIndices, ...
                layerIndices, "stable");
            diagnostics.PairCount = numel(pairs);
            diagnostics.HiddenLayerIndices = ...
                ProjectionAlignmentScheduler.hiddenLayerIndices(scene, ...
                request.LayerIndices);
        end

        function hidden = hiddenLayerIndices(scene, layerIndices)
            hidden = zeros(1, 0);
            if ~ProjectionAlignmentScheduler.hasSceneLayers(scene)
                return
            end
            for k = 1:numel(layerIndices)
                layer = scene.layers(layerIndices(k));
                isHidden = isfield(layer, "Visible") && ~logical(layer.Visible);
                isDisabled = isfield(layer, "Enabled") && ~logical(layer.Enabled);
                if isHidden || isDisabled
                    hidden(end + 1) = layerIndices(k); %#ok<AGROW>
                end
            end
        end

        function score = confidenceScore(matchCount, featureCounts, overlapCount)
            featureCounts = double(featureCounts(:));
            featureSupport = max([min(featureCounts); 10]);
            featureRatioSupport = double(matchCount) / featureSupport;
            matchCountSupport = min(1, double(matchCount) / 50);
            overlapSupport = min(1, double(overlapCount) / 100);
            score = min(1, max(0, 0.6 * matchCountSupport + ...
                0.2 * featureRatioSupport + 0.2 * overlapSupport));
        end

        function value = meanConfidence(pairDiagnostics)
            if isempty(pairDiagnostics)
                value = 0;
            else
                value = mean([pairDiagnostics.Confidence]);
            end
        end

        function value = fieldOrDefault(source, fieldName, defaultValue)
            if isfield(source, fieldName)
                value = source.(fieldName);
            else
                value = defaultValue;
            end
        end
    end
end
