classdef HeightSgm
    %HEIGHTSGM Physical-height semi-global matching reference.
    %
    % The pairwise path cost is min(lambdaZ*abs(Zl-Zk),Pmax), so both
    % parameters are explicit in dimensionless cost per metre / cost units.
    % Nonfinite candidates remain invalid; an all-invalid pixel breaks a path.
    % Traceability: algo/main.tex Sec. 5.6, Eqs. (71)-(75), generalized to
    % nonuniform physical labels as specified immediately after Eq. (75).
    % Array precision follows the input cost; geometry labels remain double.
    % Traceability: implementation plan Stages C3--C5 and C7.

    methods (Static)
        function result = aggregate(cost, z, options)
            arguments
                cost (:, :, :) ...
                    {mustBeNumeric, mustBeReal, mustBeFloating}
                z (1, :) double ...
                    {mustBeFinite, mustBeIncreasing, ...
                    mustMatchLabelCount(z, cost)}
                options.PenaltyPerMetre (1, 1) double ...
                    {mustBeFinite, mustBeNonnegative} = 0.02
                options.MaximumPenalty (1, 1) double ...
                    {mustBeFinite, mustBeNonnegative} = 0.2
                options.DirectionCount (1, 1) double ...
                    {mustBeMember(options.DirectionCount, [4, 8])} = 4
                options.StorePathCosts (1, 1) logical = false
            end

            timer = tic;
            dz = abs(z(:) - z);
            penaltyPerMetre = cast( ...
                options.PenaltyPerMetre, "like", cost);
            maximumPenalty = cast( ...
                options.MaximumPenalty, "like", cost);
            penalty = min(penaltyPerMetre .* cast(dz, "like", cost), ...
                maximumPenalty);
            directions = HeightSgm.directions(options.DirectionCount);
            sumCost = zeros(size(cost), "like", cost);
            count = zeros(size(cost));
            if options.StorePathCosts
                pathCosts = nan( ...
                    [size(cost), options.DirectionCount], "like", cost);
            else
                pathCosts = zeros([size(cost), 0], "like", cost);
            end
            directionSeconds = zeros(1, options.DirectionCount);
            for r = 1:options.DirectionCount
                directionTimer = tic;
                path = HeightSgm.aggregateDirection( ...
                    cost, z, penaltyPerMetre, ...
                    maximumPenalty, directions(r, :));
                directionSeconds(r) = toc(directionTimer);
                validPath = isfinite(path);
                sumCost(validPath) = sumCost(validPath) + path(validPath);
                count(validPath) = count(validPath) + 1;
                if options.StorePathCosts
                    pathCosts(:, :, :, r) = path;
                end
            end
            valid = isfinite(cost) & count == options.DirectionCount;
            aggregated = sumCost ./ cast(count, "like", cost);
            aggregated(~valid) = NaN;
            [rawHeight, rawIndex, rawBest, rawSecond, rawMargin] = ...
                HeightSgm.select(cost, z);
            [height, index, best, second, margin] = ...
                HeightSgm.select(aggregated, z);
            tracked = whos("cost", "sumCost", "count", "path", ...
                "aggregated", "pathCosts");
            trackedBytes = sum([tracked.bytes]);
            result = struct( ...
                "HeightLabelsMetres", z, ...
                "RawCost", cost, ...
                "AggregatedCost", aggregated, ...
                "RawHeightMetres", rawHeight, ...
                "RawLabelIndex", rawIndex, ...
                "RawBestCost", rawBest, ...
                "RawSecondBestCost", rawSecond, ...
                "RawCostMargin", rawMargin, ...
                "HeightMetres", height, ...
                "LabelIndex", index, ...
                "BestCost", best, ...
                "SecondBestCost", second, ...
                "CostMargin", margin, ...
                "Valid", any(valid, 3), ...
                "ValidCandidate", valid, ...
                "ValidDirectionCount", count, ...
                "PairwisePenalty", penalty, ...
                "PenaltyPerMetre", options.PenaltyPerMetre, ...
                "MaximumPenalty", options.MaximumPenalty, ...
                "PenaltyModel", ...
                "min(PenaltyPerMetre*abs(deltaZ),MaximumPenalty)", ...
                "DirectionsYX", directions, ...
                "DirectionCount", options.DirectionCount, ...
                "Precision", arrayPrecision(cost), ...
                "PathCosts", pathCosts, ...
                "DirectionRuntimeSeconds", directionSeconds, ...
                "TrackedArrayBytes", trackedBytes, ...
                "MemoryDefinition", ...
                "tracked payload lower bound at end of aggregation", ...
                "InvalidState", ...
                "not implemented; all-invalid pixels break each path", ...
                "RuntimeSeconds", toc(timer));
        end

        function result = aggregateVectorized(cost, z, options)
            %AGGREGATEVECTORIZED Batched scanline physical-height SGM.
            % The only loops are over directions, the sequential scan axis,
            % and the short label transition. Independent scanlines update
            % together. Traceability: Eqs. (71)--(75); implementation plan
            % Stage C4.

            arguments
                cost (:, :, :) ...
                    {mustBeNumeric, mustBeReal, mustBeFloating}
                z (1, :) double ...
                    {mustBeFinite, mustBeIncreasing, ...
                    mustMatchLabelCount(z, cost)}
                options.PenaltyPerMetre (1, 1) double ...
                    {mustBeFinite, mustBeNonnegative} = 0.02
                options.MaximumPenalty (1, 1) double ...
                    {mustBeFinite, mustBeNonnegative} = 0.2
                options.DirectionCount (1, 1) double ...
                    {mustBeMember(options.DirectionCount, [4, 8])} = 4
                options.StorePathCosts (1, 1) logical = false
                options.ReturnDirectionCount (1, 1) logical = false
            end

            timer = tic;
            [nr, nc, nl] = size(cost);
            penaltyPerMetre = cast( ...
                options.PenaltyPerMetre, "like", cost);
            maximumPenalty = cast( ...
                options.MaximumPenalty, "like", cost);
            dz = cast(abs(z(:) - z), "like", cost);
            labelStep = cast(diff(z), "like", cost);
            penalty = min(penaltyPerMetre .* dz, maximumPenalty);
            directions = HeightSgm.directions(options.DirectionCount);
            aggregated = zeros(size(cost), "like", cost);
            if options.StorePathCosts
                pathCosts = nan( ...
                    [size(cost), options.DirectionCount], "like", cost);
            else
                pathCosts = zeros([size(cost), 0], "like", cost);
            end
            directionSeconds = zeros(1, options.DirectionCount);
            maximumScanlineStateBytes = 0;

            for r = 1:options.DirectionCount
                directionTimer = tic;
                dy = directions(r, 1);
                dx = directions(r, 2);
                if dy == 0
                    previous = nan(nr, nl, "like", cost);
                    if dx > 0
                        scan = 1:nc;
                    else
                        scan = nc:-1:1;
                    end
                    for x = scan
                        c = reshape(cost(:, x, :), nr, nl);
                        current = HeightSgm.advanceBatch( ...
                            c, previous, labelStep, penaltyPerMetre, ...
                            maximumPenalty);
                        slice = reshape(aggregated(:, x, :), nr, nl);
                        slice = slice + current;
                        aggregated(:, x, :) = reshape(slice, nr, 1, nl);
                        if options.StorePathCosts
                            pathCosts(:, x, :, r) = ...
                                reshape(current, nr, 1, nl);
                        end
                        previous = current;
                        if x == scan(1)
                            stateInfo = whos( ...
                                "previous", "current", "c", "slice");
                            maximumScanlineStateBytes = max( ...
                                maximumScanlineStateBytes, ...
                                sum([stateInfo.bytes]));
                        end
                    end
                else
                    previous = nan(nc, nl, "like", cost);
                    if dy > 0
                        scan = 1:nr;
                    else
                        scan = nr:-1:1;
                    end
                    blank = nan(1, nl, "like", cost);
                    for y = scan
                        if dx > 0
                            prior = [blank; previous(1:(end - 1), :)];
                        elseif dx < 0
                            prior = [previous(2:end, :); blank];
                        else
                            prior = previous;
                        end
                        c = reshape(cost(y, :, :), nc, nl);
                        current = HeightSgm.advanceBatch( ...
                            c, prior, labelStep, penaltyPerMetre, ...
                            maximumPenalty);
                        slice = reshape(aggregated(y, :, :), nc, nl);
                        slice = slice + current;
                        aggregated(y, :, :) = reshape(slice, 1, nc, nl);
                        if options.StorePathCosts
                            pathCosts(y, :, :, r) = ...
                                reshape(current, 1, nc, nl);
                        end
                        previous = current;
                        if y == scan(1)
                            stateInfo = whos("previous", "prior", ...
                                "current", "c", "slice");
                            maximumScanlineStateBytes = max( ...
                                maximumScanlineStateBytes, ...
                                sum([stateInfo.bytes]));
                        end
                    end
                end
                directionSeconds(r) = toc(directionTimer);
            end

            valid = isfinite(cost);
            aggregated = aggregated ./ cast( ...
                options.DirectionCount, "like", cost);
            aggregated(~valid) = NaN;
            if options.ReturnDirectionCount
                count = uint8(valid) .* uint8(options.DirectionCount);
            else
                count = uint8(false([nr, nc, 0], "like", valid));
            end
            [rawHeight, rawIndex, rawBest, rawSecond, rawMargin] = ...
                HeightSgm.select(cost, z);
            [height, index, best, second, margin] = ...
                HeightSgm.select(aggregated, z);
            tracked = whos("cost", "aggregated", "pathCosts", "count");
            trackedBytes = sum([tracked.bytes]);
            result = struct( ...
                "HeightLabelsMetres", z, ...
                "RawCost", cost, ...
                "AggregatedCost", aggregated, ...
                "RawHeightMetres", rawHeight, ...
                "RawLabelIndex", rawIndex, ...
                "RawBestCost", rawBest, ...
                "RawSecondBestCost", rawSecond, ...
                "RawCostMargin", rawMargin, ...
                "HeightMetres", height, ...
                "LabelIndex", index, ...
                "BestCost", best, ...
                "SecondBestCost", second, ...
                "CostMargin", margin, ...
                "Valid", any(valid, 3), ...
                "ValidCandidate", valid, ...
                "ValidDirectionCount", count, ...
                "PairwisePenalty", penalty, ...
                "PenaltyPerMetre", options.PenaltyPerMetre, ...
                "MaximumPenalty", options.MaximumPenalty, ...
                "PenaltyModel", ...
                "min(PenaltyPerMetre*abs(deltaZ),MaximumPenalty)", ...
                "DirectionsYX", directions, ...
                "DirectionCount", options.DirectionCount, ...
                "Precision", arrayPrecision(cost), ...
                "PathCosts", pathCosts, ...
                "DirectionRuntimeSeconds", directionSeconds, ...
                "TrackedArrayBytes", trackedBytes, ...
                "MaximumScanlineStateBytes", ...
                maximumScanlineStateBytes, ...
                "MemoryDefinition", ...
                "tracked payload plus maximum explicit scanline state", ...
                "InvalidState", ...
                "all-invalid pixels reset each independent scanline", ...
                "Execution", "vectorized-scanline", ...
                "RuntimeSeconds", toc(timer));
        end

        function result = aggregateTileLabels(plan, costByTile, options)
            %AGGREGATETILELABELS Exact SGM across variable-label tile seams.
            %
            % Path state is carried in physical height. At a tile boundary,
            % the predecessor state is evaluated on the current tile's labels
            % with the exact truncated-linear pairwise penalty. Paths never
            % reset merely because the local label vector changes.
            %
            % Traceability: algo/main.tex Sec. 5.6, Eqs. (71)--(75), and
            % implementation plan C1 milestone 5.
            arguments
                plan table {mustBeSgmTilePlan}
                costByTile (:, 1) cell ...
                    {mustMatchSgmTileCosts(costByTile, plan)}
                options.PenaltyPerMetre (1, 1) double ...
                    {mustBeFinite, mustBeNonnegative} = 0.02
                options.MaximumPenalty (1, 1) double ...
                    {mustBeFinite, mustBeNonnegative} = 0.2
                options.DirectionCount (1, 1) double ...
                    {mustBeMember(options.DirectionCount, [4, 8])} = 8
                options.ReturnAggregatedCost (1, 1) logical = true
            end

            timer = tic;
            nr = max(plan.RowEnd);
            nc = max(plan.ColumnEnd);
            count = height(plan);
            tileRow = zeros(nr, nc, "uint32");
            localRow = zeros(nr, nc, "uint32");
            localColumn = zeros(nr, nc, "uint32");
            for k = 1:count
                rr = plan.RowStart(k):plan.RowEnd(k);
                cc = plan.ColumnStart(k):plan.ColumnEnd(k);
                if any(tileRow(rr, cc) ~= 0, "all")
                    error("HeightSgm:OverlappingTileCores", ...
                        "Tile %d overlaps an earlier tile core.", ...
                        plan.Tile(k));
                end
                tileRow(rr, cc) = uint32(k);
                [lr, lc] = ndgrid(uint32(1:numel(rr)), ...
                    uint32(1:numel(cc)));
                localRow(rr, cc) = lr;
                localColumn(rr, cc) = lc;
            end
            if any(tileRow == 0, "all")
                error("HeightSgm:IncompleteTilePartition", ...
                    "Tile cores must cover a complete rectangular image.");
            end

            precision = string(class(costByTile{1}));
            precisionBytes = 8;
            if precision == "single"
                precisionBytes = 4;
            end
            aggregate = cell(count, 1);
            inputCostBytes = 0;
            for k = 1:count
                aggregate{k} = zeros(size(costByTile{k}), precision);
                inputCostBytes = inputCostBytes ...
                    + numel(costByTile{k}) .* precisionBytes;
            end
            directions = HeightSgm.directions(options.DirectionCount);
            penaltyPerMetre = cast(options.PenaltyPerMetre, precision);
            maximumPenalty = cast(options.MaximumPenalty, precision);
            directionSeconds = zeros(1, options.DirectionCount);
            sameGridTransitionCount = 0;
            remappedTransitionCount = 0;
            resetCount = 0;
            maximumScanlineStateBytes = 0;

            for id = 1:options.DirectionCount
                directionTimer = tic;
                dy = directions(id, 1);
                dx = directions(id, 2);
                if dy == 0
                    if dx > 0
                        xScan = 1:nc;
                    else
                        xScan = nc:-1:1;
                    end
                    for y = 1:nr
                        previous = zeros(1, 0, precision);
                        previousLabels = zeros(1, 0);
                        for x = xScan
                            k = double(tileRow(y, x));
                            lr = double(localRow(y, x));
                            lc = double(localColumn(y, x));
                            z = plan.HeightLabelsMetres{k};
                            c = reshape(costByTile{k}(lr, lc, :), 1, []);
                            [current, same, remapped, reset] = ...
                                HeightSgm.advanceArbitraryLabels( ...
                                c, z, previous, previousLabels, ...
                                penaltyPerMetre, maximumPenalty);
                            aggregate{k}(lr, lc, :) = reshape( ...
                                reshape(aggregate{k}(lr, lc, :), 1, []) ...
                                + current, 1, 1, []);
                            previous = current;
                            previousLabels = z;
                            sameGridTransitionCount = ...
                                sameGridTransitionCount + same;
                            remappedTransitionCount = ...
                                remappedTransitionCount + remapped;
                            resetCount = resetCount + reset;
                        end
                        stateBytes = 2 .* numel(previous) .* precisionBytes ...
                            + numel(previousLabels) .* 8;
                        maximumScanlineStateBytes = max( ...
                            maximumScanlineStateBytes, stateBytes);
                    end
                else
                    if dy > 0
                        yScan = 1:nr;
                    else
                        yScan = nr:-1:1;
                    end
                    previous = cell(1, nc);
                    previousLabels = cell(1, nc);
                    for y = yScan
                        currentRow = cell(1, nc);
                        currentLabels = cell(1, nc);
                        for x = 1:nc
                            px = x - dx;
                            if px >= 1 && px <= nc
                                p = previous{px};
                                zp = previousLabels{px};
                            else
                                p = zeros(1, 0, precision);
                                zp = zeros(1, 0);
                            end
                            k = double(tileRow(y, x));
                            lr = double(localRow(y, x));
                            lc = double(localColumn(y, x));
                            z = plan.HeightLabelsMetres{k};
                            c = reshape(costByTile{k}(lr, lc, :), 1, []);
                            [current, same, remapped, reset] = ...
                                HeightSgm.advanceArbitraryLabels( ...
                                c, z, p, zp, penaltyPerMetre, ...
                                maximumPenalty);
                            aggregate{k}(lr, lc, :) = reshape( ...
                                reshape(aggregate{k}(lr, lc, :), 1, []) ...
                                + current, 1, 1, []);
                            currentRow{x} = current;
                            currentLabels{x} = z;
                            sameGridTransitionCount = ...
                                sameGridTransitionCount + same;
                            remappedTransitionCount = ...
                                remappedTransitionCount + remapped;
                            resetCount = resetCount + reset;
                        end
                        previous = currentRow;
                        previousLabels = currentLabels;
                        stateLabelCount = sum(cellfun(@numel, previous));
                        stateBytes = 2 .* stateLabelCount ...
                            .* (precisionBytes + 8);
                        maximumScanlineStateBytes = max( ...
                            maximumScanlineStateBytes, stateBytes);
                    end
                end
                directionSeconds(id) = toc(directionTimer);
            end

            rawHeight = nan(nr, nc);
            rawIndex = zeros(nr, nc);
            rawBest = nan(nr, nc, precision);
            rawSecond = nan(nr, nc, precision);
            rawMargin = nan(nr, nc, precision);
            selectedHeight = nan(nr, nc);
            selectedIndex = zeros(nr, nc);
            best = nan(nr, nc, precision);
            second = nan(nr, nc, precision);
            margin = nan(nr, nc, precision);
            valid = false(nr, nc);
            for k = 1:count
                finiteCost = isfinite(costByTile{k});
                aggregate{k} = aggregate{k} ...
                    ./ cast(options.DirectionCount, precision);
                aggregate{k}(~finiteCost) = NaN;
                z = plan.HeightLabelsMetres{k};
                [rh, ri, rb, rs, rm] = ...
                    HeightSgm.select(costByTile{k}, z);
                [sh, si, sb, ss, sm] = ...
                    HeightSgm.select(aggregate{k}, z);
                rr = plan.RowStart(k):plan.RowEnd(k);
                cc = plan.ColumnStart(k):plan.ColumnEnd(k);
                rawHeight(rr, cc) = rh;
                rawIndex(rr, cc) = ri;
                rawBest(rr, cc) = rb;
                rawSecond(rr, cc) = rs;
                rawMargin(rr, cc) = rm;
                selectedHeight(rr, cc) = sh;
                selectedIndex(rr, cc) = si;
                best(rr, cc) = sb;
                second(rr, cc) = ss;
                margin(rr, cc) = sm;
                valid(rr, cc) = any(finiteCost, 3);
            end
            if options.ReturnAggregatedCost
                aggregateResult = aggregate;
            else
                aggregateResult = cell(0, 1);
            end
            outputInfo = whos("rawHeight", "rawIndex", "rawBest", ...
                "rawSecond", "rawMargin", "selectedHeight", ...
                "selectedIndex", "best", "second", "margin", "valid", ...
                "tileRow");
            result = struct( ...
                "HeightLabelsMetres", zeros(1, 0), ...
                "HeightLabelsByTile", {plan.HeightLabelsMetres}, ...
                "TilePlan", plan, ...
                "TileIndex", tileRow, ...
                "RawCostByTile", {cell(0, 1)}, ...
                "AggregatedCostByTile", {aggregateResult}, ...
                "RawHeightMetres", rawHeight, ...
                "RawLabelIndex", rawIndex, ...
                "RawBestCost", rawBest, ...
                "RawSecondBestCost", rawSecond, ...
                "RawCostMargin", rawMargin, ...
                "HeightMetres", selectedHeight, ...
                "LabelIndex", selectedIndex, ...
                "BestCost", best, ...
                "SecondBestCost", second, ...
                "CostMargin", margin, ...
                "Valid", valid, ...
                "PenaltyPerMetre", options.PenaltyPerMetre, ...
                "MaximumPenalty", options.MaximumPenalty, ...
                "PenaltyModel", ...
                "min(PenaltyPerMetre*abs(deltaZ),MaximumPenalty)", ...
                "DirectionsYX", directions, ...
                "DirectionCount", options.DirectionCount, ...
                "Precision", precision, ...
                "DirectionRuntimeSeconds", directionSeconds, ...
                "SameGridTransitionCount", sameGridTransitionCount, ...
                "RemappedTransitionCount", remappedTransitionCount, ...
                "ResetCount", resetCount, ...
                "InputCostBytes", inputCostBytes, ...
                "AggregateCostBytes", inputCostBytes, ...
                "OutputArrayBytes", sum([outputInfo.bytes]), ...
                "MaximumScanlineStateBytes", ...
                maximumScanlineStateBytes, ...
                "MemoryDefinition", ...
                "input and aggregate local costs plus one scanline of path state", ...
                "InvalidState", ...
                "all-invalid pixels reset paths; tile seams do not", ...
                "SeamPolicy", ...
                "exact physical-height transition between neighboring local grids", ...
                "Execution", "variable-label-streamed-scanline", ...
                "RuntimeSeconds", toc(timer));
        end

        function result = aggregateTileLabelsStreamed( ...
                costStore, aggregateStore, options)
            %AGGREGATETILELABELSSTREAMED Two-pass row-of-tiles local SGM.
            %
            % Forward tile rows aggregate horizontal/downward paths. Reverse
            % tile rows add upward paths, normalize, select, and overwrite the
            % persisted aggregate. Only one cost/aggregate tile row and one
            % scanline of variable-grid path state are resident.
            %
            % Traceability: algo/main.tex Sec. 5.6, Eqs. (71)--(75), and
            % implementation plan C1 milestone 5.
            arguments
                costStore (1, 1) HeightTileStore ...
                    {mustBeCompleteHeightTileStore}
                aggregateStore (1, 1) HeightTileStore ...
                    {mustBeCompatibleEmptyHeightTileStore( ...
                    aggregateStore, costStore)}
                options.PenaltyPerMetre (1, 1) double ...
                    {mustBeFinite, mustBeNonnegative} = 0.02
                options.MaximumPenalty (1, 1) double ...
                    {mustBeFinite, mustBeNonnegative} = 0.2
                options.DirectionCount (1, 1) double ...
                    {mustBeMember(options.DirectionCount, [4, 8])} = 8
                options.ReturnAggregatedCost (1, 1) logical = false
                options.ReturnRawSelection (1, 1) logical = true
                options.ReturnTileIndex (1, 1) logical = false
                options.Products (1, :) string ...
                    {mustBeNonempty, mustBeSgmSelectionProducts} = ...
                    ["LabelIndex", "BestCost", "SecondBestCost", "Margin"]
            end

            timer = tic;
            products = unique(options.Products, "stable");
            needLabelIndex = any(products == "LabelIndex");
            needBest = any(products == "BestCost");
            needSecond = any(products == "SecondBestCost");
            needMargin = any(products == "Margin");
            plan = costStore.Plan;
            nr = max(plan.RowEnd);
            nc = max(plan.ColumnEnd);
            precision = costStore.Precision;
            directions = HeightSgm.directions(options.DirectionCount);
            forwardIds = find(directions(:, 1) >= 0);
            backwardIds = find(directions(:, 1) < 0);
            penaltyPerMetre = cast(options.PenaltyPerMetre, precision);
            maximumPenalty = cast(options.MaximumPenalty, precision);
            groups = costStore.rowGroups;
            forwardState = cell(options.DirectionCount, 1);
            backwardState = cell(options.DirectionCount, 1);
            blank = struct("Values", {cell(1, nc)}, ...
                "Labels", {cell(1, nc)});
            for id = reshape(forwardIds, 1, [])
                if directions(id, 1) ~= 0
                    forwardState{id} = blank;
                end
            end
            for id = reshape(backwardIds, 1, [])
                backwardState{id} = blank;
            end

            if options.ReturnRawSelection
                rawHeight = nan(nr, nc);
                rawIndex = zeros(nr, nc);
                rawBest = nan(nr, nc, precision);
                rawSecond = nan(nr, nc, precision);
                rawMargin = nan(nr, nc, precision);
            else
                rawHeight = zeros([nr, nc, 0]);
                rawIndex = zeros([nr, nc, 0]);
                rawBest = zeros([nr, nc, 0], precision);
                rawSecond = zeros([nr, nc, 0], precision);
                rawMargin = zeros([nr, nc, 0], precision);
            end
            selectedHeight = nan(nr, nc);
            selectedIndex = HeightSgm.optionalSelectionArray( ...
                [nr, nc], needLabelIndex, 0, "double");
            best = HeightSgm.optionalSelectionArray( ...
                [nr, nc], needBest, NaN, precision);
            second = HeightSgm.optionalSelectionArray( ...
                [nr, nc], needSecond, NaN, precision);
            margin = HeightSgm.optionalSelectionArray( ...
                [nr, nc], needMargin, NaN, precision);
            valid = false(nr, nc);
            if options.ReturnTileIndex
                tileIndex = zeros(nr, nc, "uint32");
                for k = 1:height(plan)
                    tileIndex(plan.RowStart(k):plan.RowEnd(k), ...
                        plan.ColumnStart(k):plan.ColumnEnd(k)) = ...
                        uint32(plan.Tile(k));
                end
            else
                tileIndex = zeros([nr, nc, 0], "uint32");
            end

            directionSeconds = zeros(1, options.DirectionCount);
            sameGridTransitionCount = 0;
            remappedTransitionCount = 0;
            resetCount = 0;
            maximumScanlineStateBytes = 0;
            maximumRowGroupPayloadBytes = 0;
            boundaryWinnerCount = 0;
            costStatsBefore = costStore.statistics;
            aggregateStatsBefore = aggregateStore.statistics;
            forwardTimer = tic;

            for g = 1:numel(groups)
                ids = groups{g};
                costs = costStore.readTiles(ids);
                partial = cellfun(@(c) zeros(size(c), "like", c), ...
                    costs, UniformOutput=false);
                if options.ReturnRawSelection
                    for k = 1:numel(ids)
                        id = ids(k);
                        z = plan.HeightLabelsMetres{id};
                        [rh, ri, rb, rs, rm] = ...
                            HeightSgm.select(costs{k}, z);
                        rr = plan.RowStart(id):plan.RowEnd(id);
                        cc = plan.ColumnStart(id):plan.ColumnEnd(id);
                        rawHeight(rr, cc) = rh;
                        rawIndex(rr, cc) = ri;
                        rawBest(rr, cc) = rb;
                        rawSecond(rr, cc) = rs;
                        rawMargin(rr, cc) = rm;
                    end
                end
                for id = reshape(forwardIds, 1, [])
                    directionTimer = tic;
                    [partial, forwardState{id}, counts, stateBytes] = ...
                        HeightSgm.accumulateVariableTileRow( ...
                        costs, partial, plan(ids, :), ...
                        directions(id, :), forwardState{id}, ...
                        penaltyPerMetre, maximumPenalty);
                    directionSeconds(id) = directionSeconds(id) ...
                        + toc(directionTimer);
                    sameGridTransitionCount = sameGridTransitionCount ...
                        + counts(1);
                    remappedTransitionCount = remappedTransitionCount ...
                        + counts(2);
                    resetCount = resetCount + counts(3);
                    maximumScanlineStateBytes = max( ...
                        maximumScanlineStateBytes, stateBytes);
                end
                maximumRowGroupPayloadBytes = max( ...
                    maximumRowGroupPayloadBytes, ...
                    HeightSgm.cellPayloadBytes(costs) ...
                    + HeightSgm.cellPayloadBytes(partial));
                aggregateStore.writeTiles(ids, partial);
            end
            forwardSeconds = toc(forwardTimer);

            backwardTimer = tic;
            for g = numel(groups):-1:1
                ids = groups{g};
                costs = costStore.readTiles(ids);
                partial = aggregateStore.readTiles(ids);
                for id = reshape(backwardIds, 1, [])
                    directionTimer = tic;
                    [partial, backwardState{id}, counts, stateBytes] = ...
                        HeightSgm.accumulateVariableTileRow( ...
                        costs, partial, plan(ids, :), ...
                        directions(id, :), backwardState{id}, ...
                        penaltyPerMetre, maximumPenalty);
                    directionSeconds(id) = directionSeconds(id) ...
                        + toc(directionTimer);
                    sameGridTransitionCount = sameGridTransitionCount ...
                        + counts(1);
                    remappedTransitionCount = remappedTransitionCount ...
                        + counts(2);
                    resetCount = resetCount + counts(3);
                    maximumScanlineStateBytes = max( ...
                        maximumScanlineStateBytes, stateBytes);
                end
                for k = 1:numel(ids)
                    id = ids(k);
                    finiteCost = isfinite(costs{k});
                    partial{k} = partial{k} ...
                        ./ cast(options.DirectionCount, precision);
                    partial{k}(~finiteCost) = NaN;
                    z = plan.HeightLabelsMetres{id};
                    [sh, si, sb, ss, sm] = ...
                        HeightSgm.select(partial{k}, z);
                    rr = plan.RowStart(id):plan.RowEnd(id);
                    cc = plan.ColumnStart(id):plan.ColumnEnd(id);
                    selectedHeight(rr, cc) = sh;
                    if needLabelIndex
                        selectedIndex(rr, cc) = si;
                    end
                    if needBest
                        best(rr, cc) = sb;
                    end
                    if needSecond
                        second(rr, cc) = ss;
                    end
                    if needMargin
                        margin(rr, cc) = sm;
                    end
                    tileValid = any(finiteCost, 3);
                    valid(rr, cc) = tileValid;
                    boundaryWinnerCount = boundaryWinnerCount + nnz( ...
                        tileValid & (si == 1 | si == numel(z)));
                end
                maximumRowGroupPayloadBytes = max( ...
                    maximumRowGroupPayloadBytes, ...
                    HeightSgm.cellPayloadBytes(costs) ...
                    + HeightSgm.cellPayloadBytes(partial));
                aggregateStore.writeTiles(ids, partial);
            end
            backwardSeconds = toc(backwardTimer);

            if options.ReturnAggregatedCost
                aggregateResult = aggregateStore.readTiles(1:height(plan));
            else
                aggregateResult = cell(0, 1);
            end
            costStatsAfter = costStore.statistics;
            aggregateStatsAfter = aggregateStore.statistics;
            fileIoSeconds = ...
                costStatsAfter.FileIoSeconds ...
                - costStatsBefore.FileIoSeconds ...
                + aggregateStatsAfter.FileIoSeconds ...
                - aggregateStatsBefore.FileIoSeconds;
            outputInfo = whos("rawHeight", "rawIndex", "rawBest", ...
                "rawSecond", "rawMargin", "selectedHeight", ...
                "selectedIndex", "best", "second", "margin", "valid", ...
                "tileIndex", "aggregateResult");
            result = struct( ...
                "HeightLabelsMetres", zeros(1, 0), ...
                "HeightLabelsByTile", {plan.HeightLabelsMetres}, ...
                "TilePlan", plan, ...
                "TileIndex", tileIndex, ...
                "RawCostByTile", {cell(0, 1)}, ...
                "AggregatedCostByTile", {aggregateResult}, ...
                "AggregateStore", aggregateStore, ...
                "RawHeightMetres", rawHeight, ...
                "RawLabelIndex", rawIndex, ...
                "RawBestCost", rawBest, ...
                "RawSecondBestCost", rawSecond, ...
                "RawCostMargin", rawMargin, ...
                "HeightMetres", selectedHeight, ...
                "LabelIndex", selectedIndex, ...
                "BestCost", best, ...
                "SecondBestCost", second, ...
                "CostMargin", margin, ...
                "Valid", valid, ...
                "Products", ["Height", "Validity", products], ...
                "BoundaryWinnerCount", boundaryWinnerCount, ...
                "BoundaryWinnerFraction", ...
                boundaryWinnerCount ./ max(nnz(valid), 1), ...
                "PenaltyPerMetre", options.PenaltyPerMetre, ...
                "MaximumPenalty", options.MaximumPenalty, ...
                "PenaltyModel", ...
                "min(PenaltyPerMetre*abs(deltaZ),MaximumPenalty)", ...
                "DirectionsYX", directions, ...
                "DirectionCount", options.DirectionCount, ...
                "Precision", precision, ...
                "DirectionRuntimeSeconds", directionSeconds, ...
                "SameGridTransitionCount", sameGridTransitionCount, ...
                "RemappedTransitionCount", remappedTransitionCount, ...
                "ResetCount", resetCount, ...
                "FileIoSeconds", fileIoSeconds, ...
                "CostStoreStatistics", costStatsAfter, ...
                "AggregateStoreStatistics", aggregateStatsAfter, ...
                "OutputArrayBytes", sum([outputInfo.bytes]), ...
                "MaximumRowGroupPayloadBytes", ...
                maximumRowGroupPayloadBytes, ...
                "MaximumScanlineStateBytes", ...
                maximumScanlineStateBytes, ...
                "RetainedRowGroupCount", 2, ...
                "RowGroupCount", numel(groups), ...
                "ForwardSeconds", forwardSeconds, ...
                "BackwardSeconds", backwardSeconds, ...
                "MemoryDefinition", ...
                "one cost/aggregate row of tiles, path scanline, and requested outputs", ...
                "InvalidState", ...
                "all-invalid pixels reset paths; tile seams do not", ...
                "SeamPolicy", ...
                "exact physical-height transition between neighboring local grids", ...
                "Execution", "streamed-variable-label-tile-row", ...
                "RuntimeSeconds", toc(timer));
        end

        function result = aggregateStreamed( ...
                costStore, aggregateStore, z, options)
            %AGGREGATESTREAMED Two-pass row-slab physical-height SGM.
            % Forward slabs aggregate horizontal and downward paths; reverse
            % slabs add upward paths, normalize, select, and persist final
            % aggregate costs. Traceability: Eqs. (71)--(75);
            % implementation plan Stage C5.

            arguments
                costStore (1, 1) HeightVolumeStore ...
                    {mustBeCompleteVolumeStore}
                aggregateStore (1, 1) HeightVolumeStore ...
                    {mustBeCompatibleEmptyVolumeStore( ...
                    aggregateStore, costStore)}
                z (1, :) double ...
                    {mustBeFinite, mustBeIncreasing, ...
                    mustMatchStoreLabels(z, costStore)}
                options.RowSlabRows (1, 1) double ...
                    {mustBeFinite, mustBeInteger, mustBePositive} = 128
                options.PenaltyPerMetre (1, 1) double ...
                    {mustBeFinite, mustBeNonnegative} = 0.02
                options.MaximumPenalty (1, 1) double ...
                    {mustBeFinite, mustBeNonnegative} = 0.2
                options.DirectionCount (1, 1) double ...
                    {mustBeMember(options.DirectionCount, [4, 8])} = 8
                options.ReturnAggregatedCost (1, 1) logical = false
            end

            timer = tic;
            shape = costStore.Shape;
            nr = shape(1);
            nc = shape(2);
            nl = shape(3);
            precision = costStore.Precision;
            slabRows = min(options.RowSlabRows, nr);
            starts = 1:slabRows:nr;
            directions = HeightSgm.directions(options.DirectionCount);
            forwardIds = find(directions(:, 1) >= 0);
            backwardIds = find(directions(:, 1) < 0);
            labelStep = cast(diff(z), precision);
            penaltyPerMetre = cast(options.PenaltyPerMetre, precision);
            maximumPenalty = cast(options.MaximumPenalty, precision);
            penalty = min(penaltyPerMetre ...
                .* cast(abs(z(:) - z), precision), maximumPenalty);
            forwardBoundary = cell(options.DirectionCount, 1);
            backwardBoundary = cell(options.DirectionCount, 1);
            for id = reshape([forwardIds; backwardIds], 1, [])
                if directions(id, 1) ~= 0
                    if any(forwardIds == id)
                        forwardBoundary{id} = nan(nc, nl, precision);
                    else
                        backwardBoundary{id} = nan(nc, nl, precision);
                    end
                end
            end

            rawHeight = nan(nr, nc);
            rawIndex = zeros(nr, nc);
            rawBest = nan(nr, nc, precision);
            rawSecond = nan(nr, nc, precision);
            rawMargin = nan(nr, nc, precision);
            height = nan(nr, nc);
            index = zeros(nr, nc);
            best = nan(nr, nc, precision);
            second = nan(nr, nc, precision);
            margin = nan(nr, nc, precision);
            valid = false(nr, nc);
            directionSeconds = zeros(1, options.DirectionCount);
            maximumScanlineStateBytes = 0;
            maximumSlabPayloadBytes = 0;
            costStatsBefore = costStore.statistics;
            aggregateStatsBefore = aggregateStore.statistics;
            forwardTimer = tic;

            for slab = 1:numel(starts)
                rows = starts(slab):min( ...
                    starts(slab) + slabRows - 1, nr);
                cost = costStore.readRows(rows);
                partial = zeros(size(cost), "like", cost);
                [rh, ri, rb, rs, rm] = HeightSgm.select(cost, z);
                rawHeight(rows, :) = rh;
                rawIndex(rows, :) = ri;
                rawBest(rows, :) = rb;
                rawSecond(rows, :) = rs;
                rawMargin(rows, :) = rm;
                for id = reshape(forwardIds, 1, [])
                    directionTimer = tic;
                    [partial, forwardBoundary{id}, stateBytes] = ...
                        HeightSgm.accumulateSlabDirection( ...
                        cost, partial, labelStep, penaltyPerMetre, ...
                        maximumPenalty, directions(id, :), ...
                        forwardBoundary{id});
                    directionSeconds(id) = directionSeconds(id) ...
                        + toc(directionTimer);
                    maximumScanlineStateBytes = max( ...
                        maximumScanlineStateBytes, stateBytes);
                end
                payload = whos("cost", "partial");
                maximumSlabPayloadBytes = max( ...
                    maximumSlabPayloadBytes, sum([payload.bytes]));
                aggregateStore.writeRows(rows, partial);
            end
            forwardSeconds = toc(forwardTimer);

            backwardTimer = tic;
            for slab = numel(starts):-1:1
                rows = starts(slab):min( ...
                    starts(slab) + slabRows - 1, nr);
                cost = costStore.readRows(rows);
                partial = aggregateStore.readRows(rows);
                for id = reshape(backwardIds, 1, [])
                    directionTimer = tic;
                    [partial, backwardBoundary{id}, stateBytes] = ...
                        HeightSgm.accumulateSlabDirection( ...
                        cost, partial, labelStep, penaltyPerMetre, ...
                        maximumPenalty, directions(id, :), ...
                        backwardBoundary{id});
                    directionSeconds(id) = directionSeconds(id) ...
                        + toc(directionTimer);
                    maximumScanlineStateBytes = max( ...
                        maximumScanlineStateBytes, stateBytes);
                end
                finiteCost = isfinite(cost);
                partial = partial ./ cast( ...
                    options.DirectionCount, "like", partial);
                partial(~finiteCost) = NaN;
                [sh, si, sb, ss, sm] = HeightSgm.select(partial, z);
                height(rows, :) = sh;
                index(rows, :) = si;
                best(rows, :) = sb;
                second(rows, :) = ss;
                margin(rows, :) = sm;
                valid(rows, :) = any(finiteCost, 3);
                aggregateStore.writeRows(rows, partial);
            end
            backwardSeconds = toc(backwardTimer);

            if options.ReturnAggregatedCost
                aggregated = aggregateStore.readRows(1:nr);
            else
                aggregated = zeros([nr, nc, 0], precision);
            end
            costStatsAfter = costStore.statistics;
            aggregateStatsAfter = aggregateStore.statistics;
            fileIoSeconds = ...
                costStatsAfter.FileIoSeconds ...
                - costStatsBefore.FileIoSeconds ...
                + aggregateStatsAfter.FileIoSeconds ...
                - aggregateStatsBefore.FileIoSeconds;
            outputInfo = whos("rawHeight", "rawIndex", "rawBest", ...
                "rawSecond", "rawMargin", "height", "index", "best", ...
                "second", "margin", "valid", "aggregated");
            outputBytes = sum([outputInfo.bytes]);
            result = struct( ...
                "HeightLabelsMetres", z, ...
                "RawCost", zeros([nr, nc, 0], precision), ...
                "AggregatedCost", aggregated, ...
                "AggregateStore", aggregateStore, ...
                "RawHeightMetres", rawHeight, ...
                "RawLabelIndex", rawIndex, ...
                "RawBestCost", rawBest, ...
                "RawSecondBestCost", rawSecond, ...
                "RawCostMargin", rawMargin, ...
                "HeightMetres", height, ...
                "LabelIndex", index, ...
                "BestCost", best, ...
                "SecondBestCost", second, ...
                "CostMargin", margin, ...
                "Valid", valid, ...
                "ValidCandidate", zeros([nr, nc, 0], "logical"), ...
                "ValidDirectionCount", zeros([nr, nc, 0], "uint8"), ...
                "PairwisePenalty", penalty, ...
                "PenaltyPerMetre", options.PenaltyPerMetre, ...
                "MaximumPenalty", options.MaximumPenalty, ...
                "PenaltyModel", ...
                "min(PenaltyPerMetre*abs(deltaZ),MaximumPenalty)", ...
                "DirectionsYX", directions, ...
                "DirectionCount", options.DirectionCount, ...
                "Precision", precision, ...
                "PathCosts", zeros([nr, nc, 0], precision), ...
                "DirectionRuntimeSeconds", directionSeconds, ...
                "FileIoSeconds", fileIoSeconds, ...
                "CostStoreStatistics", costStatsAfter, ...
                "AggregateStoreStatistics", aggregateStatsAfter, ...
                "OutputArrayBytes", outputBytes, ...
                "MaximumSlabPayloadBytes", maximumSlabPayloadBytes, ...
                "MaximumScanlineStateBytes", ...
                maximumScanlineStateBytes, ...
                "RetainedSlabCount", 2, ...
                "RowSlabRows", slabRows, ...
                "ForwardSeconds", forwardSeconds, ...
                "BackwardSeconds", backwardSeconds, ...
                "MemoryDefinition", ...
                "two row slabs, boundary states, requested full-image outputs", ...
                "InvalidState", ...
                "all-invalid pixels reset each independent scanline", ...
                "Execution", "streamed-row-slab", ...
                "RuntimeSeconds", toc(timer));
        end
    end

    methods (Static, Access = private)
        function a = optionalSelectionArray(sz, requested, fill, precision)
            if requested
                a = repmat(cast(fill, precision), sz);
            else
                a = zeros([sz, 0], precision);
            end
        end

        function [aggregate, outgoing, counts, maximumStateBytes] = ...
                accumulateVariableTileRow(costs, aggregate, plan, ...
                direction, incoming, penaltyPerMetre, maximumPenalty)
            nr = plan.RowEnd(1) - plan.RowStart(1) + 1;
            nc = max(plan.ColumnEnd);
            tile = zeros(1, nc);
            localColumn = zeros(1, nc);
            for k = 1:height(plan)
                cc = plan.ColumnStart(k):plan.ColumnEnd(k);
                tile(cc) = k;
                localColumn(cc) = 1:numel(cc);
            end
            dy = direction(1);
            dx = direction(2);
            same = 0;
            remapped = 0;
            reset = 0;
            maximumStateBytes = 0;
            if dy == 0
                if dx > 0
                    xScan = 1:nc;
                else
                    xScan = nc:-1:1;
                end
                for y = 1:nr
                    previous = zeros(1, 0, "like", costs{1});
                    previousLabels = zeros(1, 0);
                    for x = xScan
                        k = tile(x);
                        lc = localColumn(x);
                        z = plan.HeightLabelsMetres{k};
                        c = reshape(costs{k}(y, lc, :), 1, []);
                        [current, s, m, r] = ...
                            HeightSgm.advanceArbitraryLabels( ...
                            c, z, previous, previousLabels, ...
                            penaltyPerMetre, maximumPenalty);
                        aggregate{k}(y, lc, :) = reshape( ...
                            reshape(aggregate{k}(y, lc, :), 1, []) ...
                            + current, 1, 1, []);
                        previous = current;
                        previousLabels = z;
                        same = same + s;
                        remapped = remapped + m;
                        reset = reset + r;
                    end
                    maximumStateBytes = max(maximumStateBytes, ...
                        HeightSgm.pathStateBytes( ...
                        {previous}, {previousLabels}));
                end
                outgoing = struct("Values", {cell(1, nc)}, ...
                    "Labels", {cell(1, nc)});
            else
                previous = incoming.Values;
                previousLabels = incoming.Labels;
                if dy > 0
                    yScan = 1:nr;
                else
                    yScan = nr:-1:1;
                end
                for y = yScan
                    currentRow = cell(1, nc);
                    currentLabels = cell(1, nc);
                    for x = 1:nc
                        px = x - dx;
                        if px >= 1 && px <= nc
                            p = previous{px};
                            zp = previousLabels{px};
                        else
                            p = zeros(1, 0, "like", costs{1});
                            zp = zeros(1, 0);
                        end
                        k = tile(x);
                        lc = localColumn(x);
                        z = plan.HeightLabelsMetres{k};
                        c = reshape(costs{k}(y, lc, :), 1, []);
                        [current, s, m, r] = ...
                            HeightSgm.advanceArbitraryLabels( ...
                            c, z, p, zp, penaltyPerMetre, maximumPenalty);
                        aggregate{k}(y, lc, :) = reshape( ...
                            reshape(aggregate{k}(y, lc, :), 1, []) ...
                            + current, 1, 1, []);
                        currentRow{x} = current;
                        currentLabels{x} = z;
                        same = same + s;
                        remapped = remapped + m;
                        reset = reset + r;
                    end
                    previous = currentRow;
                    previousLabels = currentLabels;
                    maximumStateBytes = max(maximumStateBytes, ...
                        HeightSgm.pathStateBytes( ...
                        previous, previousLabels));
                end
                outgoing = struct("Values", {previous}, ...
                    "Labels", {previousLabels});
            end
            counts = [same, remapped, reset];
        end

        function bytes = pathStateBytes(values, labels)
            bytes = HeightSgm.cellPayloadBytes(values) ...
                + HeightSgm.cellPayloadBytes(labels);
        end

        function bytes = cellPayloadBytes(values)
            bytes = 0;
            for k = 1:numel(values)
                value = values{k}; %#ok<NASGU>
                info = whos("value");
                bytes = bytes + info.bytes;
            end
        end

        function [current, same, remapped, reset] = ...
                advanceArbitraryLabels(cost, z, previous, previousZ, ...
                penaltyPerMetre, maximumPenalty)
            validCost = isfinite(cost);
            validPrevious = isfinite(previous);
            same = 0;
            remapped = 0;
            reset = 0;
            if ~any(validCost)
                current = nan(size(cost), "like", cost);
                return
            end
            if ~any(validPrevious)
                current = cost;
                reset = 1;
            elseif isequal(z, previousZ)
                transition = HeightSgm.truncatedLinearTransition( ...
                    previous, z, penaltyPerMetre, maximumPenalty);
                current = cost + transition ...
                    - min(previous(validPrevious));
                same = 1;
            else
                pv = previous(validPrevious).';
                zv = previousZ(validPrevious).';
                penalty = min(penaltyPerMetre .* cast( ...
                    abs(zv - z), "like", cost), maximumPenalty);
                transition = min(pv + penalty, [], 1);
                current = cost + transition ...
                    - min(previous(validPrevious));
                remapped = 1;
            end
            current(~validCost) = NaN;
        end

        function path = aggregateDirection( ...
                cost, z, penaltyPerMetre, maximumPenalty, direction)
            [nr, nc, nl] = size(cost);
            dy = direction(1);
            dx = direction(2);
            [y, x] = ndgrid(1:nr, 1:nc);
            py = y - dy;
            px = x - dx;
            start = py < 1 | py > nr | px < 1 | px > nc;
            sy = y(start);
            sx = x(start);
            path = nan(size(cost), "like", cost);
            for s = 1:numel(sy)
                yy = sy(s);
                xx = sx(s);
                previous = nan(1, nl, "like", cost);
                while yy >= 1 && yy <= nr && xx >= 1 && xx <= nc
                    c = reshape(cost(yy, xx, :), 1, nl);
                    validCost = isfinite(c);
                    validPrevious = isfinite(previous);
                    if any(validCost)
                        if any(validPrevious)
                            % Eqs. (71)-(75), with the nonuniform physical-
                            % height truncated-linear metric from D022. The
                            % two ordered passes are the exact 1-D distance
                            % transform of min_k(prev_k+lambda*|Z_l-Z_k|),
                            % followed by the constant truncation branch.
                            % This is O(nLabels), rather than materializing
                            % the O(nLabels^2) transition at every pixel.
                            transition = ...
                                HeightSgm.truncatedLinearTransition( ...
                                previous, z, penaltyPerMetre, ...
                                maximumPenalty);
                            current = c + transition ...
                                - min(previous(validPrevious));
                        else
                            current = c;
                        end
                        current(~validCost) = NaN;
                    else
                        current = nan(1, nl, "like", cost);
                    end
                    path(yy, xx, :) = reshape(current, 1, 1, nl);
                    previous = current;
                    yy = yy + dy;
                    xx = xx + dx;
                end
            end
        end

        function transition = truncatedLinearTransition( ...
                previous, z, penaltyPerMetre, maximumPenalty)
            valid = isfinite(previous);
            base = min(previous(valid));
            transition = previous;
            transition(~valid) = Inf;
            for k = 2:numel(z)
                transition(k) = min(transition(k), ...
                    transition(k - 1) + penaltyPerMetre ...
                    .* cast(z(k) - z(k - 1), "like", previous));
            end
            for k = (numel(z) - 1):-1:1
                transition(k) = min(transition(k), ...
                    transition(k + 1) + penaltyPerMetre ...
                    .* cast(z(k + 1) - z(k), "like", previous));
            end
            transition = min(transition, base + maximumPenalty);
        end

        function current = advanceBatch( ...
                cost, previous, labelStep, ...
                penaltyPerMetre, maximumPenalty)
            %ADVANCEBATCH Exact nonuniform transition across scanlines.
            transition = previous;
            transition(~isfinite(transition)) = Inf;
            base = min(transition, [], 2);
            for k = 2:(numel(labelStep) + 1)
                transition(:, k) = min(transition(:, k), ...
                    transition(:, k - 1) ...
                    + penaltyPerMetre .* labelStep(k - 1));
            end
            for k = numel(labelStep):-1:1
                transition(:, k) = min(transition(:, k), ...
                    transition(:, k + 1) ...
                    + penaltyPerMetre .* labelStep(k));
            end
            transition = min(transition, base + maximumPenalty);
            current = cost + transition - base;
            reset = ~isfinite(base);
            current(reset, :) = cost(reset, :);
        end

        function [aggregate, outgoing, maximumStateBytes] = ...
                accumulateSlabDirection(cost, aggregate, labelStep, ...
                penaltyPerMetre, maximumPenalty, direction, incoming)
            %ACCUMULATESLABDIRECTION Add one bounded path slab in place.
            [nr, nc, nl] = size(cost);
            dy = direction(1);
            dx = direction(2);
            maximumStateBytes = 0;
            if dy == 0
                previous = nan(nr, nl, "like", cost);
                if dx > 0
                    scan = 1:nc;
                else
                    scan = nc:-1:1;
                end
                for x = scan
                    c = reshape(cost(:, x, :), nr, nl);
                    current = HeightSgm.advanceBatch( ...
                        c, previous, labelStep, ...
                        penaltyPerMetre, maximumPenalty);
                    slice = reshape(aggregate(:, x, :), nr, nl);
                    aggregate(:, x, :) = reshape( ...
                        slice + current, nr, 1, nl);
                    previous = current;
                    if x == scan(1)
                        state = whos("previous", "current", "c", "slice");
                        maximumStateBytes = sum([state.bytes]);
                    end
                end
                outgoing = zeros(0, nl, "like", cost);
            else
                previous = incoming;
                if dy > 0
                    scan = 1:nr;
                else
                    scan = nr:-1:1;
                end
                blank = nan(1, nl, "like", cost);
                for y = scan
                    if dx > 0
                        prior = [blank; previous(1:(end - 1), :)];
                    elseif dx < 0
                        prior = [previous(2:end, :); blank];
                    else
                        prior = previous;
                    end
                    c = reshape(cost(y, :, :), nc, nl);
                    current = HeightSgm.advanceBatch( ...
                        c, prior, labelStep, ...
                        penaltyPerMetre, maximumPenalty);
                    slice = reshape(aggregate(y, :, :), nc, nl);
                    aggregate(y, :, :) = reshape( ...
                        slice + current, 1, nc, nl);
                    previous = current;
                    if y == scan(1)
                        state = whos("previous", "prior", ...
                            "current", "c", "slice");
                        maximumStateBytes = sum([state.bytes]);
                    end
                end
                outgoing = previous;
            end
        end

        function directions = directions(count)
            directions = [0, 1; 0, -1; 1, 0; -1, 0; ...
                1, 1; -1, -1; 1, -1; -1, 1];
            directions = directions(1:count, :);
        end

        function [height, index, best, second, margin] = select(cost, z)
            [nr, nc, nl] = size(cost);
            c = reshape(cost, nr * nc, nl);
            c(~isfinite(c)) = Inf;
            if nl > 1
                [ordered, order] = mink(c, 2, 2);
                best = ordered(:, 1);
                index = order(:, 1);
                second = ordered(:, 2);
            else
                [best, index] = min(c, [], 2);
                second = inf(size(best), "like", best);
            end
            valid = isfinite(best);
            if isa(cost, "gpuArray")
                % GPU selection stays on-device. The future host coordinator
                % maps gathered label indices back to CPU-double elevations
                % before camera projection. Implementation plan Stage C7.
                labels = cast(z, "like", cost);
                height = nan(nr * nc, 1, "like", cost);
            else
                labels = z;
                height = nan(nr * nc, 1);
            end
            height(valid) = reshape(labels(index(valid)), [], 1);
            best(~valid) = NaN;
            second(~valid | ~isfinite(second)) = NaN;
            margin = second - best;
            index(~valid) = 0;
            height = reshape(height, nr, nc);
            index = reshape(index, nr, nc);
            best = reshape(best, nr, nc);
            second = reshape(second, nr, nc);
            margin = reshape(margin, nr, nc);
        end
    end
end

function name = arrayPrecision(a)
if isa(a, "gpuArray")
    name = string(classUnderlying(a));
else
    name = string(class(a));
end
end

function mustBeSgmSelectionProducts(products)
mustBeMember(products, ...
    ["LabelIndex", "BestCost", "SecondBestCost", "Margin"]);
if numel(unique(products)) ~= numel(products)
    error("HeightSgm:DuplicateSelectionProduct", ...
        "Streamed SGM selection products must not contain duplicates.");
end
end

function mustBeIncreasing(x)
if numel(x) < 2 || any(diff(x) <= 0)
    error("HeightSgm:LabelsNotIncreasing", ...
        "At least two strictly increasing height labels are required.");
end
end

function mustMatchLabelCount(z, cost)
if numel(z) ~= size(cost, 3)
    error("HeightSgm:LabelCountMismatch", ...
        "The label vector must match the third cost-volume dimension.");
end
end

function mustBeFloating(a)
if ~isfloat(a)
    error("HeightSgm:FloatingPointRequired", ...
        "Cost volumes must use single or double precision.");
end
end

function mustBeCompleteVolumeStore(store)
stats = store.statistics;
if ~stats.Complete
    error("HeightSgm:IncompleteCostStore", ...
        "Every cost-store row must be written before streamed SGM.");
end
end

function mustBeCompatibleEmptyVolumeStore(candidate, reference)
if ~isequal(candidate.Shape, reference.Shape) ...
        || candidate.Precision ~= reference.Precision
    error("HeightSgm:StoreMismatch", ...
        "Cost and aggregate stores must have equal shape and precision.");
end
stats = candidate.statistics;
if stats.WrittenRowCount ~= 0
    error("HeightSgm:AggregateStoreNotEmpty", ...
        "The aggregate store must be unwritten before streamed SGM.");
end
end

function mustMatchStoreLabels(z, store)
stored = reshape(double(store.Metadata.HeightLabelsMetres), 1, []);
if numel(z) ~= store.Shape(3) || ~isequal(z, stored)
    error("HeightSgm:StoreLabelMismatch", ...
        "Height labels must exactly match the volume-store metadata.");
end
end

function mustBeSgmTilePlan(plan)
required = ["Tile", "RowStart", "RowEnd", "ColumnStart", ...
    "ColumnEnd", "LabelCount", "HeightLabelsMetres"];
if isempty(plan) || ~all(ismember(required, string(plan.Properties.VariableNames)))
    error("HeightSgm:InvalidTilePlan", ...
        "Tile plan must be nonempty and contain the required variables.");
end
values = [plan.Tile; plan.RowStart; plan.RowEnd; ...
    plan.ColumnStart; plan.ColumnEnd; plan.LabelCount];
if any(~isfinite(values)) || any(values < 1) ...
        || any(values ~= fix(values)) ...
        || any(plan.RowEnd < plan.RowStart) ...
        || any(plan.ColumnEnd < plan.ColumnStart) ...
        || numel(unique(plan.Tile)) ~= height(plan)
    error("HeightSgm:InvalidTilePlan", ...
        "Tile identifiers, bounds, and label counts must be valid integers.");
end
if ~iscell(plan.HeightLabelsMetres) ...
        || any(cellfun(@(z) ~isa(z, "double") || ~isrow(z) ...
        || numel(z) < 3 || any(~isfinite(z)) ...
        || any(diff(z) <= 0), plan.HeightLabelsMetres)) ...
        || any(cellfun(@numel, plan.HeightLabelsMetres) ~= plan.LabelCount)
    error("HeightSgm:InvalidTilePlan", ...
        "Each tile needs a finite, increasing double label row.");
end
end

function mustMatchSgmTileCosts(costs, plan)
if numel(costs) ~= height(plan)
    error("HeightSgm:TileCostCountMismatch", ...
        "There must be one cost volume per tile-plan row.");
end

precision = "";
for k = 1:numel(costs)
    cost = costs{k};
    expected = [plan.RowEnd(k) - plan.RowStart(k) + 1, ...
        plan.ColumnEnd(k) - plan.ColumnStart(k) + 1, ...
        plan.LabelCount(k)];
    if ~isnumeric(cost) || ~isreal(cost) || ~isfloat(cost) ...
            || ~isequal(size(cost), expected)
        error("HeightSgm:InvalidTileCost", ...
            "Tile %d cost must be a floating array of its planned size.", ...
            plan.Tile(k));
    end
    if k == 1
        precision = string(class(cost));
    elseif string(class(cost)) ~= precision
        error("HeightSgm:MixedTileCostPrecision", ...
            "All tile cost volumes must use one precision.");
    end
end
end

function mustBeCompleteHeightTileStore(store)
if ~store.statistics.Complete
    error("HeightSgm:IncompleteHeightTileStore", ...
        "Every cost-store tile must be written before streamed SGM.");
end
end

function mustBeCompatibleEmptyHeightTileStore(candidate, reference)
if candidate.Precision ~= reference.Precision ...
        || ~isequal(candidate.Plan, reference.Plan)
    error("HeightSgm:HeightTileStoreMismatch", ...
        "Cost and aggregate tile stores must have equal plan and precision.");
end
if candidate.statistics.WrittenTileCount ~= 0
    error("HeightSgm:AggregateHeightTileStoreNotEmpty", ...
        "The aggregate tile store must be unwritten before streamed SGM.");
end
end
