classdef ProjectionPairGraphScheduler
    %ProjectionPairGraphScheduler Select an explainable quality pair graph.

    properties (Constant)
        Format = "ProjectionPairGraphSchedule"
        Version = 1
    end

    methods (Static)
        function graph = build(scene, layerIndices, layerIds, options)
            %build Score plausible pairs, select a forest, then add chords.
            ProjectionPairGraphScheduler.validateInputs( ...
                scene, layerIndices, layerIds, options);
            models = ProjectionPairGraphScheduler.viewModels( ...
                scene, layerIndices, layerIds);
            candidates = ProjectionPairGraphScheduler.candidates(models);
            candidates = ProjectionPairGraphScheduler.applyOverrides( ...
                candidates, options);
            [candidates, selectionOrder] = ...
                ProjectionPairGraphScheduler.select(candidates, models, options);
            selected = candidates(selectionOrder);
            for order = 1:numel(selected)
                selected(order).Order = order;
            end
            diagnostics = ProjectionPairGraphScheduler.diagnostics( ...
                candidates, selected, models, options);
            graph = struct(Format=ProjectionPairGraphScheduler.Format, ...
                Version=ProjectionPairGraphScheduler.Version, ...
                GenerationId=ProjectionPairGraphScheduler.generationId( ...
                candidates, selected, options), Options=options, ...
                ViewIds=string({models.LayerId}), Candidates=candidates, ...
                Selected=selected, PairCount=numel(selected), ...
                PredictedCost=diagnostics.PredictedCost, ...
                Diagnostics=diagnostics);
        end
    end

    methods (Static, Access = private)
        function validateInputs(scene, layerIndices, layerIds, options)
            if ~isstruct(scene) || ~isscalar(scene) || ...
                    ~isfield(scene, "layers") || ~isstruct(scene.layers)
                error("ProjectionPairGraphScheduler:invalidScene", ...
                    "Scene must contain a layers struct array.");
            end
            if ~isnumeric(layerIndices) || ~isvector(layerIndices) || ...
                    numel(layerIndices) < 2 || any(~isfinite(layerIndices)) || ...
                    any(fix(layerIndices) ~= layerIndices) || ...
                    any(layerIndices < 1) || ...
                    any(layerIndices > numel(scene.layers)) || ...
                    numel(unique(layerIndices)) ~= numel(layerIndices)
                error("ProjectionPairGraphScheduler:invalidLayers", ...
                    "Layer indices must select at least two unique scene layers.");
            end
            if ~isstring(layerIds) || ~isvector(layerIds) || ...
                    numel(layerIds) ~= numel(layerIndices) || ...
                    any(ismissing(layerIds)) || any(strlength(layerIds) == 0) || ...
                    numel(unique(layerIds)) ~= numel(layerIds)
                error("ProjectionPairGraphScheduler:invalidLayers", ...
                    "Layer IDs must be unique nonempty strings aligned to layers.");
            end
            required = ["QualitySpeed" "MaxPairs" "AllPlausiblePairs" ...
                "ForcedIncludePairIds" "ForcedExcludePairIds"];
            if ~isstruct(options) || ~isscalar(options) || ...
                    ~all(isfield(options, required))
                error("ProjectionPairGraphScheduler:invalidOptions", ...
                    "Validated scheduling options are required.");
            end
        end

        function models = viewModels(scene, layerIndices, layerIds)
            plane = scene.layers(layerIndices(1)).CurrentProjectionPlane;
            models = repmat(ProjectionPairGraphScheduler.emptyViewModel(), ...
                1, numel(layerIndices));
            for position = 1:numel(layerIndices)
                layer = scene.layers(layerIndices(position));
                [bounds, footprintAvailable] = ...
                    ProjectionPairGraphScheduler.footprintBounds(layer, plane);
                [axis, axisAvailable] = ...
                    ProjectionPairGraphScheduler.opticalAxis(layer);
                [pixelCount, bandCount, imageClass, imageAvailable] = ...
                    ProjectionPairGraphScheduler.imageSummary(layer);
                passId = "default-pass";
                if isfield(layer, "PassId")
                    passId = string(layer.PassId);
                end
                models(position) = struct(Position=position, ...
                    LayerIndex=layerIndices(position), ...
                    LayerId=layerIds(position), PassId=passId, ...
                    FootprintBounds=bounds, ...
                    FootprintAvailable=footprintAvailable, ...
                    OpticalAxis=axis, AxisAvailable=axisAvailable, ...
                    PixelCount=pixelCount, BandCount=bandCount, ...
                    ImageClass=imageClass, ImageAvailable=imageAvailable);
            end
        end

        function [bounds, available] = footprintBounds(layer, plane)
            bounds = nan(1, 4);
            available = false;
            if ~isfield(layer, "SourceGeometry")
                return
            end
            source = layer.SourceGeometry;
            if ~isstruct(source) || ~isfield(source, "ImageSize") || ...
                    ~isfield(source, "SampleRayFcn") || ...
                    ~isa(source.SampleRayFcn, "function_handle")
                return
            end
            imageSize = double(source.ImageSize(:).');
            if numel(imageSize) < 2 || any(imageSize(1:2) < 1)
                return
            end
            rows = [1 1 imageSize(1) imageSize(1)];
            columns = [1 imageSize(2) imageSize(2) 1];
            try
                [origins, vectors] = source.SampleRayFcn(rows, columns);
                origins = double(origins);
                vectors = double(vectors);
                if ~isequal(size(origins), [3 4]) || ...
                        ~isequal(size(vectors), [3 4]) || ...
                        any(~isfinite(origins), "all") || ...
                        any(~isfinite(vectors), "all")
                    return
                end
                denominator = sum(plane.VN .* vectors, 1);
                numerator = sum(plane.VN .* (plane.P0 - origins), 1);
                distances = numerator ./ denominator;
                valid = abs(denominator) > 1e-12 & distances > 0;
                if nnz(valid) < 3
                    return
                end
                points = origins(:, valid) + ...
                    vectors(:, valid) .* distances(valid);
                coordinates = PlanarProjection.worldToPlane(points, plane);
                bounds = [min(coordinates(1, :)) max(coordinates(1, :)) ...
                    min(coordinates(2, :)) max(coordinates(2, :))];
                available = all(isfinite(bounds)) && ...
                    bounds(2) > bounds(1) && bounds(4) > bounds(3);
            catch
                % Missing or incompatible lightweight geometry stays unavailable.
            end
        end

        function [axis, available] = opticalAxis(layer)
            axis = nan(3, 1);
            available = false;
            if ~isfield(layer, "SourceGeometry") || ...
                    ~isstruct(layer.SourceGeometry)
                return
            end
            source = layer.SourceGeometry;
            names = ["OpticalAxis" "V0"];
            for name = names
                if isfield(source, name)
                    candidate = source.(name);
                    candidate = double(candidate(:));
                    if numel(candidate) == 3 && all(isfinite(candidate)) && ...
                            norm(candidate) > 0
                        axis = candidate / norm(candidate);
                        available = true;
                        return
                    end
                end
            end
        end

        function [pixelCount, bandCount, imageClass, available] = ...
                imageSummary(layer)
            pixelCount = 0;
            bandCount = 1;
            imageClass = "unavailable";
            available = false;
            if isfield(layer, "Image") && isnumeric(layer.Image)
                imageSize = size(layer.Image);
                pixelCount = prod(imageSize(1:min(2, numel(imageSize))));
                if numel(imageSize) >= 3
                    bandCount = imageSize(3);
                end
                imageClass = string(class(layer.Image));
                available = true;
            elseif isfield(layer, "SourceGeometry") && ...
                    isfield(layer.SourceGeometry, "ImageSize")
                imageSize = double(layer.SourceGeometry.ImageSize(:).');
                pixelCount = prod(imageSize(1:min(2, numel(imageSize))));
            end
        end

        function candidates = candidates(models)
            count = numel(models) * (numel(models) - 1) / 2;
            candidates = repmat(ProjectionPairGraphScheduler.emptyCandidate(), ...
                1, count);
            cursor = 0;
            for first = 1:(numel(models) - 1)
                for second = (first + 1):numel(models)
                    cursor = cursor + 1;
                    candidates(cursor) = ...
                        ProjectionPairGraphScheduler.scoreCandidate( ...
                        models(first), models(second));
                end
            end
            [~, order] = sort(string({candidates.PairId}));
            candidates = candidates(order);
        end

        function candidate = scoreCandidate(first, second)
            identity = ProjectionViewMetadata.pairIdentity( ...
                first.LayerId, second.LayerId);
            [overlap, overlapAvailable] = ...
                ProjectionPairGraphScheduler.overlapScore(first, second);
            [angle, geometry, geometryAvailable] = ...
                ProjectionPairGraphScheduler.geometryScore(first, second);
            separation = abs(second.Position - first.Position);
            samePass = first.PassId == second.PassId;
            temporalPass = 1 / separation;
            if ~samePass
                temporalPass = max(temporalPass, 0.75);
            end
            radiometricAvailable = first.ImageAvailable && second.ImageAvailable;
            radiometric = 0.5;
            if radiometricAvailable
                radiometric = 0.5 * ...
                    double(first.BandCount == second.BandCount) + ...
                    0.5 * double(first.ImageClass == second.ImageClass);
            end
            proximity = 1 / separation;
            occlusion = 0.5;
            trackSupport = 0.5;
            quality = 0.30 * overlap + 0.20 * geometry + ...
                0.15 * temporalPass + 0.15 * radiometric + ...
                0.10 * proximity + 0.05 * occlusion + ...
                0.05 * trackSupport;
            plausible = ~overlapAvailable || overlap > 0;
            reason = "";
            state = "candidate";
            if ~plausible
                reason = "noProjectedOverlap";
                state = "rejected";
            end
            candidate = ProjectionPairGraphScheduler.emptyCandidate();
            candidate.PairId = identity.PairId;
            candidate.Pair = [first.LayerIndex second.LayerIndex];
            candidate.PairLayerIds = [first.LayerId second.LayerId];
            candidate.NodePositions = [first.Position second.Position];
            candidate.PassIds = [first.PassId second.PassId];
            candidate.SamePass = samePass;
            candidate.PositionSeparation = separation;
            candidate.ProjectedOverlap = overlap;
            candidate.OverlapAvailable = overlapAvailable;
            candidate.IntersectionAngleDegrees = angle;
            candidate.GeometryAvailable = geometryAvailable;
            candidate.GeometryScore = geometry;
            candidate.TemporalPassScore = temporalPass;
            candidate.RadiometricCompatibility = radiometric;
            candidate.RadiometricAvailable = radiometricAvailable;
            candidate.PredictedOcclusionScore = occlusion;
            candidate.ExistingTrackSupport = trackSupport;
            candidate.QualityScore = quality;
            candidate.SelectionScore = quality;
            candidate.PredictedCost = ...
                (first.PixelCount + second.PixelCount) / 1e6;
            candidate.Plausible = plausible;
            candidate.State = state;
            candidate.RejectionReason = reason;
        end

        function [score, available] = overlapScore(first, second)
            available = first.FootprintAvailable && second.FootprintAvailable;
            score = 0.5;
            if ~available
                return
            end
            firstBounds = first.FootprintBounds;
            secondBounds = second.FootprintBounds;
            width = max(0, min(firstBounds(2), secondBounds(2)) - ...
                max(firstBounds(1), secondBounds(1)));
            height = max(0, min(firstBounds(4), secondBounds(4)) - ...
                max(firstBounds(3), secondBounds(3)));
            intersectionArea = width * height;
            firstArea = diff(firstBounds(1:2)) * diff(firstBounds(3:4));
            secondArea = diff(secondBounds(1:2)) * diff(secondBounds(3:4));
            score = intersectionArea / min(firstArea, secondArea);
            score = min(1, max(0, score));
        end

        function [angle, score, available] = geometryScore(first, second)
            available = first.AxisAvailable && second.AxisAvailable;
            angle = NaN;
            score = 0.5;
            if ~available
                return
            end
            cosine = min(1, max(-1, dot(first.OpticalAxis, second.OpticalAxis)));
            angle = acosd(cosine);
            score = sind(min(angle, 90));
        end

        function candidates = applyOverrides(candidates, options)
            pairIds = string({candidates.PairId});
            unknownInclude = setdiff(options.ForcedIncludePairIds, pairIds);
            unknownExclude = setdiff(options.ForcedExcludePairIds, pairIds);
            if ~isempty(unknownInclude) || ~isempty(unknownExclude)
                error("ProjectionPairGraphScheduler:unknownOverride", ...
                    "Forced pair IDs must identify scheduled candidate pairs.");
            end
            for index = 1:numel(candidates)
                pairId = candidates(index).PairId;
                if ismember(pairId, options.ForcedExcludePairIds)
                    candidates(index).State = "rejected";
                    candidates(index).RejectionReason = "excludedByOperator";
                    candidates(index).Plausible = false;
                    candidates(index).Forced = true;
                elseif ismember(pairId, options.ForcedIncludePairIds)
                    candidates(index).State = "candidate";
                    candidates(index).RejectionReason = "";
                    candidates(index).Plausible = true;
                    candidates(index).Forced = true;
                    candidates(index).SelectionScore = Inf;
                end
            end
        end

        function [candidates, selectionOrder] = select(candidates, models, options)
            eligible = find([candidates.Plausible]);
            forced = find([candidates.Forced] & [candidates.Plausible]);
            budget = numel(eligible);
            if ~isempty(options.MaxPairs)
                budget = min(budget, options.MaxPairs);
            end
            if numel(forced) > budget
                error("ProjectionPairGraphScheduler:forcedPairsExceedBudget", ...
                    "Forced inclusions exceed the hard maximum pair count.");
            end
            parent = 1:numel(models);
            selectionOrder = zeros(1, 0);
            forced = ProjectionPairGraphScheduler.qualityOrder( ...
                candidates, forced);
            for index = forced
                [candidates, parent, selectionOrder] = ...
                    ProjectionPairGraphScheduler.selectEdge( ...
                    candidates, index, parent, selectionOrder, true);
            end
            remaining = setdiff(eligible, selectionOrder, "stable");
            remaining = ProjectionPairGraphScheduler.qualityOrder( ...
                candidates, remaining);
            for index = remaining
                if numel(selectionOrder) >= budget
                    break
                end
                nodes = candidates(index).NodePositions;
                if ProjectionPairGraphScheduler.root(parent, nodes(1)) ~= ...
                        ProjectionPairGraphScheduler.root(parent, nodes(2))
                    [candidates, parent, selectionOrder] = ...
                        ProjectionPairGraphScheduler.selectEdge( ...
                        candidates, index, parent, selectionOrder, false);
                end
            end
            target = ProjectionPairGraphScheduler.targetCount( ...
                numel(selectionOrder), numel(eligible), numel(models), ...
                budget, options);
            while numel(selectionOrder) < target
                chordCandidates = setdiff(eligible, selectionOrder, "stable");
                if isempty(chordCandidates)
                    break
                end
                candidates = ProjectionPairGraphScheduler.scoreChords( ...
                    candidates, chordCandidates, selectionOrder, numel(models));
                chordOrder = ProjectionPairGraphScheduler.qualityOrder( ...
                    candidates, chordCandidates);
                index = chordOrder(1);
                candidates(index).State = "selected";
                candidates(index).Role = "chord";
                candidates(index).SelectionReason = "loopClosingQuality";
                selectionOrder(end + 1) = index; %#ok<AGROW>
            end
            for index = eligible
                if candidates(index).State == "selected"
                    continue
                end
                candidates(index).State = "rejected";
                if numel(selectionOrder) >= budget
                    candidates(index).RejectionReason = "budgetLimit";
                else
                    candidates(index).RejectionReason = "qualityPolicy";
                end
            end
        end

        function [candidates, parent, selectionOrder] = selectEdge( ...
                candidates, index, parent, selectionOrder, forced)
            nodes = candidates(index).NodePositions;
            firstRoot = ProjectionPairGraphScheduler.root(parent, nodes(1));
            secondRoot = ProjectionPairGraphScheduler.root(parent, nodes(2));
            isTree = firstRoot ~= secondRoot;
            candidates(index).State = "selected";
            if isTree
                parent(parent == max(firstRoot, secondRoot)) = ...
                    min(firstRoot, secondRoot);
                candidates(index).Role = "tree";
                candidates(index).SelectionReason = "qualitySpanningForest";
            else
                candidates(index).Role = "chord";
                candidates(index).SelectionReason = "forcedLoopChord";
            end
            if forced
                candidates(index).SelectionReason = ...
                    "forced" + upper(extractBefore( ...
                    candidates(index).Role, 2)) + ...
                    extractAfter(candidates(index).Role, 1);
            end
            selectionOrder(end + 1) = index;
        end

        function target = targetCount(treeCount, eligibleCount, viewCount, ...
                budget, options)
            if options.AllPlausiblePairs
                target = eligibleCount;
            else
                switch options.QualitySpeed
                    case "fast"
                        target = treeCount;
                    case "balanced"
                        target = treeCount + max(1, ceil(viewCount / 3));
                    case "quality"
                        target = treeCount + max(1, viewCount);
                end
            end
            target = min([target eligibleCount budget]);
        end

        function candidates = scoreChords( ...
                candidates, chordIndices, selectedIndices, viewCount)
            selectedSeparations = [candidates(selectedIndices).PositionSeparation];
            degrees = zeros(1, viewCount);
            selectedPassPairs = strings(1, numel(selectedIndices));
            for offset = 1:numel(selectedIndices)
                selected = candidates(selectedIndices(offset));
                degrees(selected.NodePositions) = ...
                    degrees(selected.NodePositions) + 1;
                selectedPassPairs(offset) = strjoin(sort(selected.PassIds), "|");
            end
            for index = chordIndices
                separation = candidates(index).PositionSeparation;
                complementarity = min(1, separation / max(1, viewCount - 1));
                repeatedPenalty = 0;
                if any(selectedSeparations == separation)
                    repeatedPenalty = 0.05;
                end
                degreeBonus = 0.08 * nnz( ...
                    degrees(candidates(index).NodePositions) < 2);
                bridgeBonus = 0;
                if ~candidates(index).SamePass
                    passPair = strjoin(sort(candidates(index).PassIds), "|");
                    bridgeBonus = 0.08 * ...
                        double(nnz(selectedPassPairs == passPair) < 2);
                end
                candidates(index).SelectionScore = ...
                    candidates(index).QualityScore + ...
                    0.10 * complementarity + degreeBonus + bridgeBonus - ...
                    repeatedPenalty;
            end
        end

        function order = qualityOrder(candidates, indices)
            if isempty(indices)
                order = indices;
                return
            end
            scores = [candidates(indices).SelectionScore].';
            pairIds = string({candidates(indices).PairId}).';
            values = table(-scores, pairIds, indices(:), ...
                VariableNames=["NegativeScore" "PairId" "Index"]);
            values = sortrows(values, ["NegativeScore" "PairId"]);
            order = values.Index.';
        end

        function diagnostics = diagnostics(candidates, selected, models, options)
            selectedPairs = ProjectionPairGraphScheduler.pairMatrix(selected);
            treeMask = string({selected.Role}) == "tree";
            chordMask = string({selected.Role}) == "chord";
            selectedComponents = ProjectionPairGraphScheduler.components( ...
                selectedPairs, models);
            plausible = candidates([candidates.Plausible]);
            plausibleComponents = ProjectionPairGraphScheduler.components( ...
                ProjectionPairGraphScheduler.pairMatrix(plausible), models);
            degrees = zeros(1, numel(models));
            for pair = selectedPairs.'
                degrees(pair(1) == [models.LayerIndex]) = ...
                    degrees(pair(1) == [models.LayerIndex]) + 1;
                degrees(pair(2) == [models.LayerIndex]) = ...
                    degrees(pair(2) == [models.LayerIndex]) + 1;
            end
            degreeRecords = repmat(struct(ViewId="", LayerIndex=0, Degree=0), ...
                1, numel(models));
            for index = 1:numel(models)
                degreeRecords(index) = struct(ViewId=models(index).LayerId, ...
                    LayerIndex=models(index).LayerIndex, Degree=degrees(index));
            end
            cycles = ProjectionPairGraphScheduler.cycleBasis( ...
                selected(treeMask), selected(chordMask), models);
            rejectionMask = string({candidates.State}) == "rejected";
            rejected = candidates(rejectionMask);
            selectedCost = sum([selected.PredictedCost]);
            plausibleCost = sum([plausible.PredictedCost]);
            diagnostics = struct(TreePairIds=string({selected(treeMask).PairId}), ...
                ChordPairIds=string({selected(chordMask).PairId}), ...
                Components=selectedComponents, NodeDegrees=degreeRecords, ...
                CycleBasis=cycles, Rejections=rejected, ...
                InfeasibleConnectivity= ...
                numel(selectedComponents) > numel(plausibleComponents), ...
                PlausibleComponentCount=numel(plausibleComponents), ...
                SelectedComponentCount=numel(selectedComponents), ...
                BudgetLimited=nnz(string({rejected.RejectionReason}) == ...
                "budgetLimit") > 0, MaxPairs=options.MaxPairs, ...
                AllPlausiblePairs=options.AllPlausiblePairs, ...
                PredictedCost=struct(Unit="millionSourcePixels", ...
                Selected=selectedCost, AllPlausible=plausibleCost), ...
                AvailableSignals=struct(ProjectedOverlap= ...
                nnz([candidates.OverlapAvailable]), Geometry= ...
                nnz([candidates.GeometryAvailable]), ...
                TemporalPass=numel(candidates), ...
                RadiometricCompatibility=nnz([candidates.RadiometricAvailable]), ...
                PredictedOcclusion=0, ExistingTrackSupport=0, ...
                OperatorOverrides=nnz([candidates.Forced])));
        end

        function components = components(pairMatrix, models)
            parent = 1:numel(models);
            layerIndices = [models.LayerIndex];
            for pair = pairMatrix.'
                first = find(layerIndices == pair(1), 1, "first");
                second = find(layerIndices == pair(2), 1, "first");
                firstRoot = ProjectionPairGraphScheduler.root(parent, first);
                secondRoot = ProjectionPairGraphScheduler.root(parent, second);
                if firstRoot ~= secondRoot
                    parent(parent == max(firstRoot, secondRoot)) = ...
                        min(firstRoot, secondRoot);
                end
            end
            roots = arrayfun(@(index) ...
                ProjectionPairGraphScheduler.root(parent, index), ...
                1:numel(models));
            uniqueRoots = unique(roots);
            components = repmat(struct(ComponentId="", ViewIds=strings(1, 0), ...
                LayerIndices=zeros(1, 0)), 1, numel(uniqueRoots));
            for index = 1:numel(uniqueRoots)
                members = roots == uniqueRoots(index);
                viewIds = sort(string({models(members).LayerId}));
                components(index) = struct( ...
                    ComponentId="component-" + string(index), ...
                    ViewIds=viewIds, ...
                    LayerIndices=sort([models(members).LayerIndex]));
            end
        end

        function cycles = cycleBasis(treeEdges, chordEdges, models)
            cycles = struct("CycleId", {}, "ChordPairId", {}, ...
                "PairIds", {}, "ViewIds", {});
            if isempty(chordEdges)
                return
            end
            for chord = chordEdges
                [found, pathPairIds, pathViewIds] = ...
                    ProjectionPairGraphScheduler.treePath( ...
                    treeEdges, chord.NodePositions(1), ...
                    chord.NodePositions(2), models);
                if found
                    cycles(end + 1) = struct( ...
                        CycleId="cycle-" + string(numel(cycles) + 1), ...
                        ChordPairId=chord.PairId, ...
                        PairIds=[pathPairIds chord.PairId], ...
                        ViewIds=pathViewIds); %#ok<AGROW>
                end
            end
        end

        function [found, pairIds, viewIds] = treePath( ...
                treeEdges, startNode, targetNode, models)
            queue = startNode;
            visited = false(1, numel(models));
            visited(startNode) = true;
            previousNode = zeros(1, numel(models));
            previousEdge = zeros(1, numel(models));
            while ~isempty(queue)
                node = queue(1);
                queue(1) = [];
                if node == targetNode
                    break
                end
                for edgeIndex = 1:numel(treeEdges)
                    nodes = treeEdges(edgeIndex).NodePositions;
                    if ~ismember(node, nodes)
                        continue
                    end
                    neighbor = nodes(nodes ~= node);
                    if ~visited(neighbor)
                        visited(neighbor) = true;
                        previousNode(neighbor) = node;
                        previousEdge(neighbor) = edgeIndex;
                        queue(end + 1) = neighbor; %#ok<AGROW>
                    end
                end
            end
            found = visited(targetNode);
            pairIds = strings(1, 0);
            if ~found
                viewIds = strings(1, 0);
                return
            end
            nodePath = targetNode;
            cursor = targetNode;
            while cursor ~= startNode
                pairIds = [treeEdges(previousEdge(cursor)).PairId pairIds]; ...
                    %#ok<AGROW>
                cursor = previousNode(cursor);
                nodePath = [cursor nodePath]; %#ok<AGROW>
            end
            viewIds = string({models(nodePath).LayerId});
        end

        function matrix = pairMatrix(edges)
            if isempty(edges)
                matrix = zeros(0, 2);
            else
                matrix = reshape([edges.Pair], 2, []).';
            end
        end

        function root = root(parent, node)
            root = node;
            while parent(root) ~= root
                root = parent(root);
            end
        end

        function id = generationId(candidates, selected, options)
            payload = struct(Options=options, ...
                CandidatePairIds=string({candidates.PairId}), ...
                CandidateScores=[candidates.QualityScore], ...
                SelectedPairIds=string({selected.PairId}), ...
                SelectedRoles=string({selected.Role}));
            id = "pair-graph-" + extractBefore( ...
                ProjectionGeometryFingerprint.hash(payload), 17);
        end

        function model = emptyViewModel()
            model = struct(Position=0, LayerIndex=0, LayerId="", PassId="", ...
                FootprintBounds=nan(1, 4), FootprintAvailable=false, ...
                OpticalAxis=nan(3, 1), AxisAvailable=false, PixelCount=0, ...
                BandCount=1, ImageClass="unavailable", ImageAvailable=false);
        end

        function candidate = emptyCandidate()
            candidate = struct(PairId="", Pair=zeros(1, 2), ...
                PairLayerIds=strings(1, 2), NodePositions=zeros(1, 2), ...
                PassIds=strings(1, 2), SamePass=false, ...
                PositionSeparation=0, ProjectedOverlap=NaN, ...
                OverlapAvailable=false, IntersectionAngleDegrees=NaN, ...
                GeometryAvailable=false, GeometryScore=0, ...
                TemporalPassScore=0, RadiometricCompatibility=0, ...
                RadiometricAvailable=false, ...
                PredictedOcclusionScore=0.5, ExistingTrackSupport=0.5, ...
                QualityScore=0, SelectionScore=0, PredictedCost=0, ...
                Plausible=false, Forced=false, State="candidate", ...
                RejectionReason="", Role="", SelectionReason="", Order=0);
        end
    end
end
