classdef ProjectionPairController < handle
    %ProjectionPairController Own a runtime-only multi-image pair schedule.

    properties (Constant)
        Format = "ProjectionRuntimePairSchedule"
        Version = 1
    end

    properties (SetAccess = private)
        Schedule struct = struct()
        ActivePairId string = ""
        ReferenceViewId string = ""
        MovingViewId string = ""
        IncludeDisabledInReview logical = false
        Generation double = 0
    end

    methods
        function controller = ProjectionPairController(scene)
            %ProjectionPairController Build the initial explicit schedule.
            if nargin < 1
                error("ProjectionPairController:missingScene", ...
                    "A scene is required to build the pair schedule.");
            end
            controller.regenerate(scene);
        end

        function regenerate(controller, scene)
            %regenerate Explicitly replace the runtime schedule from a scene.
            scene = ProjectionViewMetadata.ensureScene(scene);
            controller.Generation = controller.Generation + 1;
            controller.Schedule = ProjectionPairController.buildSchedule( ...
                scene, controller.Generation);
            controller.IncludeDisabledInReview = false;
            if isempty(controller.Schedule.Pairs)
                controller.ActivePairId = "";
                controller.ReferenceViewId = "";
                controller.MovingViewId = "";
                return
            end
            firstPair = controller.Schedule.Pairs(1);
            controller.ActivePairId = firstPair.PairId;
            controller.ReferenceViewId = firstPair.ReferenceViewId;
            controller.MovingViewId = firstPair.MovingViewId;
        end

        function synchronizeScene(controller, scene)
            %synchronizeScene Refresh indices without replacing schedule order.
            scene = ProjectionViewMetadata.ensureScene(scene);
            if ~isfield(controller.Schedule, "Pairs")
                error("ProjectionPairController:missingSchedule", ...
                    "Regenerate the controller before synchronizing a scene.");
            end
            currentViewIds = ProjectionViewMetadata.ids(scene);
            for pairIndex = 1:numel(controller.Schedule.Pairs)
                pair = controller.Schedule.Pairs(pairIndex);
                referenceIndex = find(currentViewIds == ...
                    pair.ReferenceViewId, 1, "first");
                movingIndex = find(currentViewIds == ...
                    pair.MovingViewId, 1, "first");
                pair.ReferenceLayerIndex = ...
                    ProjectionPairController.optionalIndex(referenceIndex);
                pair.MovingLayerIndex = ...
                    ProjectionPairController.optionalIndex(movingIndex);
                pair.ViewsAvailable = ...
                    ~isnan(pair.ReferenceLayerIndex) && ...
                    ~isnan(pair.MovingLayerIndex);
                controller.Schedule.Pairs(pairIndex) = pair;
            end
            controller.Schedule.ViewIdsPresent = currentViewIds;
        end

        function pair = currentPair(controller)
            %currentPair Return the active pair with current directed roles.
            if strlength(controller.ActivePairId) == 0
                pair = ProjectionPairController.emptyPair();
                return
            end
            pairIndex = controller.pairIndex(controller.ActivePairId);
            pair = controller.Schedule.Pairs(pairIndex);
            pair.ReferenceViewId = controller.ReferenceViewId;
            pair.MovingViewId = controller.MovingViewId;
            if pair.ViewsAvailable
                viewIds = controller.Schedule.ViewIdsPresent;
                pair.ReferenceLayerIndex = find( ...
                    viewIds == pair.ReferenceViewId, 1, "first");
                pair.MovingLayerIndex = find( ...
                    viewIds == pair.MovingViewId, 1, "first");
            end
        end

        function pair = selectPair(controller, pairId)
            %selectPair Directly select a scheduled unordered pair.
            pairIndex = controller.pairIndex(pairId);
            pair = controller.Schedule.Pairs(pairIndex);
            controller.ActivePairId = pair.PairId;
            controller.ReferenceViewId = pair.ReferenceViewId;
            controller.MovingViewId = pair.MovingViewId;
            pair = controller.currentPair();
        end

        function pair = selectViews(controller, referenceViewId, movingViewId)
            %selectViews Select one scheduled pair and assign directed roles.
            identity = ProjectionViewMetadata.pairIdentity( ...
                referenceViewId, movingViewId);
            controller.pairIndex(identity.PairId);
            controller.ActivePairId = identity.PairId;
            controller.ReferenceViewId = string(referenceViewId);
            controller.MovingViewId = string(movingViewId);
            pair = controller.currentPair();
        end

        function pair = swapRoles(controller)
            %swapRoles Exchange moving/reference without changing pair identity.
            previousReference = controller.ReferenceViewId;
            controller.ReferenceViewId = controller.MovingViewId;
            controller.MovingViewId = previousReference;
            pair = controller.currentPair();
        end

        function [pair, changed] = stepNext(controller)
            %stepNext Select the next reviewable scheduled pair without wrapping.
            [pair, changed] = controller.step(1);
        end

        function [pair, changed] = stepPrevious(controller)
            %stepPrevious Select the previous reviewable pair without wrapping.
            [pair, changed] = controller.step(-1);
        end

        function setPairEnabled(controller, pairId, isEnabled)
            %setPairEnabled Update runtime network enablement for one pair.
            pairIndex = controller.pairIndex(pairId);
            if ~islogical(isEnabled) || ~isscalar(isEnabled)
                error("ProjectionPairController:invalidEnabled", ...
                    "Pair enabled state must be a logical scalar.");
            end
            controller.Schedule.Pairs(pairIndex).Enabled = isEnabled;
        end

        function setPairStatus(controller, pairId, status)
            %setPairStatus Update the runtime status label for one pair.
            pairIndex = controller.pairIndex(pairId);
            status = string(status);
            if ~isscalar(status) || ismissing(status) || ...
                    strlength(strip(status)) == 0 || status ~= strip(status)
                error("ProjectionPairController:invalidStatus", ...
                    "Pair status must be a trimmed nonempty scalar string.");
            end
            controller.Schedule.Pairs(pairIndex).Status = status;
        end

        function setReviewDisabled(controller, includeDisabled)
            %setReviewDisabled Include disabled pairs while stepping in review mode.
            if ~islogical(includeDisabled) || ~isscalar(includeDisabled)
                error("ProjectionPairController:invalidReviewMode", ...
                    "Review mode must be a logical scalar.");
            end
            controller.IncludeDisabledInReview = includeDisabled;
        end

        function snapshot = diagnostics(controller)
            %diagnostics Return a graphics-free runtime state snapshot.
            snapshot = struct();
            snapshot.Format = controller.Format;
            snapshot.Version = controller.Version;
            snapshot.Generation = controller.Generation;
            snapshot.ActivePairId = controller.ActivePairId;
            snapshot.ReferenceViewId = controller.ReferenceViewId;
            snapshot.MovingViewId = controller.MovingViewId;
            snapshot.IncludeDisabledInReview = ...
                controller.IncludeDisabledInReview;
            snapshot.PairCount = numel(controller.Schedule.Pairs);
            snapshot.Schedule = controller.Schedule;
        end
    end

    methods (Access = private)
        function pairIndex = pairIndex(controller, pairId)
            pairId = string(pairId);
            if ~isscalar(pairId) || ismissing(pairId) || ...
                    strlength(pairId) == 0
                error("ProjectionPairController:invalidPairId", ...
                    "PairId must be a nonempty scalar string.");
            end
            pairIds = string({controller.Schedule.Pairs.PairId});
            pairIndex = find(pairIds == pairId, 1, "first");
            if isempty(pairIndex)
                error("ProjectionPairController:unknownPair", ...
                    "PairId %s is not present in the runtime schedule.", pairId);
            end
        end

        function [pair, changed] = step(controller, direction)
            currentIndex = controller.pairIndex(controller.ActivePairId);
            pairs = controller.Schedule.Pairs;
            if controller.IncludeDisabledInReview
                selectable = true(1, numel(pairs));
            else
                selectable = [pairs.Enabled];
            end
            candidateIndices = find(selectable);
            if direction > 0
                nextIndex = candidateIndices(candidateIndices > currentIndex);
                if ~isempty(nextIndex)
                    nextIndex = nextIndex(1);
                end
            else
                nextIndex = candidateIndices(candidateIndices < currentIndex);
                if ~isempty(nextIndex)
                    nextIndex = nextIndex(end);
                end
            end
            changed = ~isempty(nextIndex);
            if changed
                pair = controller.selectPair(pairs(nextIndex).PairId);
            else
                pair = controller.currentPair();
            end
        end
    end

    methods (Static, Access = private)
        function schedule = buildSchedule(scene, generation)
            viewRecords = ProjectionPairController.viewRecords(scene);
            passIds = sort(unique(string({viewRecords.PassId})));
            pairs = repmat(ProjectionPairController.emptyPair(), 0, 1);
            timingFallbackPassIds = strings(1, 0);

            orderedByPass = cell(1, numel(passIds));
            timingBasisByPass = strings(1, numel(passIds));
            for passIndex = 1:numel(passIds)
                passMask = string({viewRecords.PassId}) == passIds(passIndex);
                passRecords = viewRecords(passMask);
                [passRecords, timingBasis] = ...
                    ProjectionPairController.orderPassViews(passRecords);
                orderedByPass{passIndex} = passRecords;
                timingBasisByPass(passIndex) = timingBasis;
                if timingBasis == "stableViewId"
                    timingFallbackPassIds(end + 1) = passIds(passIndex); %#ok<AGROW>
                end
            end

            for passIndex = 1:numel(passIds)
                passRecords = orderedByPass{passIndex};
                for viewIndex = 1:max(0, numel(passRecords) - 1)
                    pairs(end + 1) = ProjectionPairController.makePair( ...
                        passRecords(viewIndex), passRecords(viewIndex + 1), ...
                        "samePassTemporalNeighbor", ...
                        timingBasisByPass(passIndex)); %#ok<AGROW>
                end
            end

            for passIndex = 1:numel(passIds)
                passRecords = orderedByPass{passIndex};
                for gap = 2:max(1, numel(passRecords) - 1)
                    for viewIndex = 1:(numel(passRecords) - gap)
                        pairs(end + 1) = ProjectionPairController.makePair( ...
                            passRecords(viewIndex), ...
                            passRecords(viewIndex + gap), ...
                            "samePassChord", ...
                            timingBasisByPass(passIndex)); %#ok<AGROW>
                    end
                end
            end

            for firstPassIndex = 1:max(0, numel(passIds) - 1)
                firstPass = orderedByPass{firstPassIndex};
                for secondPassIndex = (firstPassIndex + 1):numel(passIds)
                    secondPass = orderedByPass{secondPassIndex};
                    for firstViewIndex = 1:numel(firstPass)
                        for secondViewIndex = 1:numel(secondPass)
                            pairs(end + 1) = ProjectionPairController.makePair( ...
                                firstPass(firstViewIndex), ...
                                secondPass(secondViewIndex), ...
                                "crossPass", "passOrder"); %#ok<AGROW>
                        end
                    end
                end
            end

            for pairIndex = 1:numel(pairs)
                pairs(pairIndex).Order = pairIndex;
            end
            schedule = struct();
            schedule.Format = ProjectionPairController.Format;
            schedule.Version = ProjectionPairController.Version;
            schedule.Generation = generation;
            schedule.ViewIds = sort(string({viewRecords.ViewId}));
            schedule.ViewIdsPresent = ProjectionViewMetadata.ids(scene);
            schedule.PassIds = passIds;
            schedule.Pairs = pairs;
            schedule.TimingFallbackPassIds = timingFallbackPassIds;
            schedule.CategoryCounts = ProjectionPairController.categoryCounts(pairs);
        end

        function records = viewRecords(scene)
            layers = scene.layers;
            records = repmat(struct(ViewId="", PassId="", LayerId="", ...
                LayerIndex=0, Name="", TimingStatus=struct(), ...
                RepresentativeTime=[]), 1, numel(layers));
            for layerIndex = 1:numel(layers)
                layer = layers(layerIndex);
                timingStatus = ProjectionViewMetadata.timingStatus(layer);
                representativeTime = [];
                if timingStatus.Available
                    representativePosition = (timingStatus.LineCount + 1) / 2;
                    representativeTime = ProjectionViewMetadata.sampleLineTimes( ...
                        layer, representativePosition);
                end
                records(layerIndex) = struct( ...
                    ViewId=string(layer.ViewId), ...
                    PassId=string(layer.PassId), ...
                    LayerId=string(layer.LayerId), ...
                    LayerIndex=layerIndex, Name=string(layer.Name), ...
                    TimingStatus=timingStatus, ...
                    RepresentativeTime=representativeTime);
            end
        end

        function [records, timingBasis] = orderPassViews(records)
            viewIds = string({records.ViewId});
            timingAvailable = arrayfun( ...
                @(record) record.TimingStatus.Available, records);
            timingClasses = arrayfun( ...
                @(record) string(class(record.RepresentativeTime)), ...
                records);
            useTiming = all(timingAvailable) && ...
                isscalar(unique(timingClasses));
            if useTiming
                try
                    order = ProjectionPairController.timeOrder(records, ...
                        timingClasses(1), viewIds);
                    records = records(order);
                    timingBasis = "acquisitionTime";
                    return
                catch
                    % Mixed or incompatible datetime zones use stable identity.
                end
            end
            [~, order] = sort(viewIds);
            records = records(order);
            timingBasis = "stableViewId";
        end

        function order = timeOrder(records, timingClass, viewIds)
            switch timingClass
                case {"double", "single"}
                    timeValues = double([records.RepresentativeTime]);
                case "duration"
                    timeValues = seconds([records.RepresentativeTime]);
                case "datetime"
                    timeValues = [records.RepresentativeTime];
                otherwise
                    error("ProjectionPairController:unsupportedTime", ...
                        "Unsupported representative-time class %s.", timingClass);
            end
            [~, viewOrder] = sort(viewIds);
            stableRank = zeros(size(viewOrder));
            stableRank(viewOrder) = 1:numel(viewOrder);
            tableValues = table(timeValues(:), stableRank(:), ...
                VariableNames=["Time" "StableRank"]);
            [~, order] = sortrows(tableValues, ["Time" "StableRank"]);
        end

        function pair = makePair(referenceRecord, movingRecord, category, timingBasis)
            identity = ProjectionViewMetadata.pairIdentity( ...
                referenceRecord.ViewId, movingRecord.ViewId);
            pair = ProjectionPairController.emptyPair();
            pair.PairId = identity.PairId;
            pair.ViewIds = identity.ViewIds;
            pair.ReferenceViewId = referenceRecord.ViewId;
            pair.MovingViewId = movingRecord.ViewId;
            pair.ReferenceLayerIndex = referenceRecord.LayerIndex;
            pair.MovingLayerIndex = movingRecord.LayerIndex;
            pair.ReferencePassId = referenceRecord.PassId;
            pair.MovingPassId = movingRecord.PassId;
            pair.Category = string(category);
            pair.TimingBasis = string(timingBasis);
            pair.Enabled = true;
            pair.Status = "notReviewed";
            pair.ViewsAvailable = true;
        end

        function counts = categoryCounts(pairs)
            categories = ["samePassTemporalNeighbor", ...
                "samePassChord", "crossPass", "remaining"];
            counts = struct();
            pairCategories = string({pairs.Category});
            for category = categories
                counts.(category) = nnz(pairCategories == category);
            end
        end

        function pair = emptyPair()
            pair = struct(PairId="", ViewIds=strings(1, 2), ...
                ReferenceViewId="", MovingViewId="", ...
                ReferenceLayerIndex=NaN, MovingLayerIndex=NaN, ...
                ReferencePassId="", MovingPassId="", Category="", ...
                TimingBasis="", Order=0, Enabled=true, ...
                Status="notReviewed", ViewsAvailable=false);
        end

        function index = optionalIndex(index)
            if isempty(index)
                index = NaN;
            else
                index = double(index);
            end
        end
    end
end
