classdef ProjectionAlignmentNetworkEvidence
    %ProjectionAlignmentNetworkEvidence Reduce tracks to unique solve edges.

    properties (Constant)
        Format = "ProjectionAlignmentNetworkEvidence"
        Version = 1
    end

    methods (Static)
        function evidence = prepare(matchResult, options)
            %prepare Select one deterministic spanning tree per feature track.
            ProjectionAlignmentNetworkEvidence.validateMatchResult(matchResult);
            options = ProjectionAlignmentOptions.validate(options);
            trackResult = ProjectionAlignmentNetworkEvidence.trackResult( ...
                matchResult);
            if options.Network.UseUniqueTrackEvidence
                recordMap = ProjectionAlignmentNetworkEvidence. ...
                    uniqueTrackRecordMap(trackResult);
            else
                recordMap = ProjectionAlignmentNetworkEvidence. ...
                    allRecordMap(matchResult, trackResult);
            end
            selectedIds = string({recordMap.RecordId});
            reduced = ProjectionAlignmentNetworkEvidence.subsetResult( ...
                matchResult, selectedIds);
            if isempty(reduced.Matches) || sum([reduced.Matches.Count]) == 0
                error("ProjectionAlignmentNetworkEvidence:noEvidence", ...
                    "No accepted unique track observations remain for solving.");
            end
            acceptedEdgeCount = nnz([trackResult.Edges.Accepted]);
            diagnostics = struct( ...
                InputPairCount=numel(matchResult.Matches), ...
                InputRecordCount=ProjectionAlignmentNetworkEvidence. ...
                currentRecordCount(matchResult), ...
                TrackCount=numel(trackResult.Tracks), ...
                AcceptedTrackEdgeCount=acceptedEdgeCount, ...
                SelectedPairCount=numel(reduced.Matches), ...
                SelectedRecordCount=numel(recordMap), ...
                RemovedCycleEdgeCount=max(0, ...
                acceptedEdgeCount - numel(recordMap)), ...
                UniqueTrackEvidence=options.Network.UseUniqueTrackEvidence);
            evidence = struct( ...
                Format=ProjectionAlignmentNetworkEvidence.Format, ...
                Version=ProjectionAlignmentNetworkEvidence.Version, ...
                GenerationId=ProjectionAlignmentNetworkEvidence. ...
                generationId(trackResult, recordMap, options), ...
                MatchResult=reduced, TrackResult=trackResult, ...
                RecordMap=recordMap, Diagnostics=diagnostics);
        end
    end

    methods (Static, Access = private)
        function validateMatchResult(matchResult)
            if ~isstruct(matchResult) || ~isscalar(matchResult) || ...
                    ~isfield(matchResult, "Matches") || ...
                    ~isstruct(matchResult.Matches) || isempty(matchResult.Matches)
                error("ProjectionAlignmentNetworkEvidence:invalidMatchResult", ...
                    "A nonempty pair-match result is required.");
            end
        end

        function trackResult = trackResult(matchResult)
            trackResult = ProjectionAlignmentTrackBuilder.build(matchResult);
            if isempty(trackResult.Tracks)
                error("ProjectionAlignmentNetworkEvidence:noTracks", ...
                    "Network solving requires at least one accepted feature track.");
            end
        end

        function recordMap = uniqueTrackRecordMap(trackResult)
            recordMap = ProjectionAlignmentNetworkEvidence.emptyRecordMap();
            observationIds = string({trackResult.Observations.ObservationId});
            for track = trackResult.Tracks
                nodeMask = ismember(observationIds, track.ObservationIds);
                edgeMask = [trackResult.Edges.Accepted] & ...
                    arrayfun(@(edge) all(nodeMask(edge.NodeIndices)), ...
                    trackResult.Edges);
                edgeIndices = find(edgeMask);
                edgeIndices = ProjectionAlignmentNetworkEvidence.qualityOrder( ...
                    trackResult.Edges, edgeIndices);
                parent = 1:numel(trackResult.Observations);
                selectedCount = 0;
                for edgeIndex = edgeIndices
                    edge = trackResult.Edges(edgeIndex);
                    firstRoot = ProjectionAlignmentNetworkEvidence.root( ...
                        parent, edge.NodeIndices(1));
                    secondRoot = ProjectionAlignmentNetworkEvidence.root( ...
                        parent, edge.NodeIndices(2));
                    if firstRoot == secondRoot
                        continue
                    end
                    parent(parent == max(firstRoot, secondRoot)) = ...
                        min(firstRoot, secondRoot);
                    recordMap(end + 1) = struct( ...
                        RecordId=edge.RecordId, TrackId=track.TrackId, ...
                        PairId=edge.PairId, DescriptorMetric= ...
                        edge.DescriptorMetric); %#ok<AGROW>
                    selectedCount = selectedCount + 1;
                end
                if selectedCount ~= track.ViewCount - 1
                    error("ProjectionAlignmentNetworkEvidence:disconnectedTrack", ...
                        "Track %s does not contain a connected accepted edge set.", ...
                        track.TrackId);
                end
            end
            if ~isempty(recordMap)
                [~, order] = sort(string({recordMap.RecordId}));
                recordMap = recordMap(order);
            end
        end

        function recordMap = allRecordMap(matchResult, trackResult)
            acceptedIds = string({trackResult.Edges([trackResult.Edges.Accepted]).RecordId});
            recordMap = ProjectionAlignmentNetworkEvidence.emptyRecordMap();
            for pairIndex = 1:numel(matchResult.Matches)
                pair = ProjectionAlignmentMatchLedger.ensurePair( ...
                    matchResult.Matches(pairIndex));
                rawIndices = ProjectionAlignmentNetworkEvidence.rawIndices(pair);
                for rawIndex = reshape(rawIndices, 1, [])
                    record = pair.MatchLedger(rawIndex);
                    if ~ismember(record.RecordId, acceptedIds)
                        continue
                    end
                    trackId = ProjectionAlignmentNetworkEvidence.trackIdForRecord( ...
                        trackResult, record.RecordId);
                    identity = ProjectionViewMetadata.pairIdentity( ...
                        record.PairLayerIds(1), record.PairLayerIds(2));
                    recordMap(end + 1) = struct( ...
                        RecordId=record.RecordId, TrackId=trackId, ...
                        PairId=identity.PairId, ...
                        DescriptorMetric=record.DescriptorMetric); %#ok<AGROW>
                end
            end
        end

        function trackId = trackIdForRecord(trackResult, recordId)
            trackId = "";
            for track = trackResult.Tracks
                if ismember(recordId, track.RecordIds)
                    trackId = track.TrackId;
                    return
                end
            end
        end

        function reduced = subsetResult(matchResult, selectedIds)
            reduced = matchResult;
            reducedMatches = struct([]);
            for pairIndex = 1:numel(matchResult.Matches)
                pair = ProjectionAlignmentMatchLedger.ensurePair( ...
                    matchResult.Matches(pairIndex));
                rawIndices = ProjectionAlignmentNetworkEvidence.rawIndices(pair);
                pair.MatchRecordIndices = rawIndices;
                currentIds = string({pair.MatchLedger(rawIndices).RecordId});
                keep = ismember(currentIds, selectedIds).';
                if ~any(keep)
                    continue
                end
                pair = ProjectionAlignmentNetworkEvidence.subsetPair(pair, keep);
                if isempty(reducedMatches)
                    reducedMatches = pair;
                else
                    reducedMatches(end + 1) = pair; %#ok<AGROW>
                end
            end
            reduced.Matches = reducedMatches;
            if isfield(reduced, "MatchLedger")
                reduced.MatchLedger = ProjectionAlignmentMatchLedger.combine(reduced);
            end
        end

        function pair = subsetPair(pair, keep)
            fields = ["MovingFeatureLocations" "ReferenceFeatureLocations" ...
                "MovingPlaneCoordinates" "ReferencePlaneCoordinates" ...
                "MovingSourceRows" "MovingSourceColumns" ...
                "ReferenceSourceRows" "ReferenceSourceColumns" ...
                "IndexPairs" "MatchMetric" "Scores" "MatchRecordIndices" ...
                "RefinementStatus" "RefinementQuality" ...
                "RefinementPeakMargin" "SourceUncertaintyPixels" ...
                "RefinementAcceptedMask" "MovingSourceJacobians" ...
                "ReferenceSourceJacobians"];
            for field = fields
                if isfield(pair, field)
                    value = pair.(field);
                    pair.(field) = value(keep, :);
                end
            end
            pair.Count = nnz(keep);
        end

        function rawIndices = rawIndices(pair)
            if isfield(pair, "MatchRecordIndices") && ...
                    numel(pair.MatchRecordIndices) == pair.Count
                rawIndices = pair.MatchRecordIndices(:);
            else
                rawIndices = (1:pair.Count).';
                pair.MatchRecordIndices = rawIndices;
            end
        end

        function order = qualityOrder(edges, indices)
            if isempty(indices)
                order = indices;
                return
            end
            metric = [edges(indices).DescriptorMetric].';
            metric(~isfinite(metric)) = Inf;
            recordIds = string({edges(indices).RecordId}).';
            values = table(metric, recordIds, indices(:), ...
                VariableNames=["Metric" "RecordId" "Index"]);
            values = sortrows(values, ["Metric" "RecordId"]);
            order = values.Index.';
        end

        function root = root(parent, node)
            root = node;
            while parent(root) ~= root
                root = parent(root);
            end
        end

        function count = currentRecordCount(matchResult)
            count = sum([matchResult.Matches.Count]);
        end

        function id = generationId(trackResult, recordMap, options)
            payload = struct(TrackGenerationId=trackResult.GenerationId, ...
                RecordIds=string({recordMap.RecordId}), ...
                TrackIds=string({recordMap.TrackId}), ...
                UniqueTrackEvidence=options.Network.UseUniqueTrackEvidence);
            id = "network-evidence-" + extractBefore( ...
                ProjectionGeometryFingerprint.hash(payload), 17);
        end

        function map = emptyRecordMap()
            map = struct("RecordId", {}, "TrackId", {}, "PairId", {}, ...
                "DescriptorMetric", {});
        end
    end
end
