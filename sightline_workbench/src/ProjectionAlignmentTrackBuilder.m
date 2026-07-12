classdef ProjectionAlignmentTrackBuilder
    %ProjectionAlignmentTrackBuilder Reconcile pair matches into safe tracks.

    properties (Constant)
        Format = "ProjectionAlignmentTracks"
        Version = 1
    end

    methods (Static)
        function options = defaults()
            %defaults Return deterministic track-reconciliation options.
            options = struct( ...
                ObservationMergeTolerancePixels=0.25, ...
                PathConsistencyTolerancePixels=0.5, ...
                MaximumDescriptorMetric=Inf, ...
                MaximumPlaneDisagreementMeters=Inf, ...
                IncludeOnlyAcceptedRecords=true);
        end

        function result = build(matchResult, options)
            %build Reconcile accepted pair records and diagnose alternate paths.
            if nargin < 2
                options = struct();
            end
            ProjectionAlignmentTrackBuilder.validateMatchResult(matchResult);
            options = ProjectionAlignmentTrackBuilder.validateOptions(options);
            [edges, inputRecordCount] = ...
                ProjectionAlignmentTrackBuilder.collectEdges(matchResult, options);
            [observations, edges] = ...
                ProjectionAlignmentTrackBuilder.clusterObservations( ...
                edges, options.ObservationMergeTolerancePixels);
            edges = ProjectionAlignmentTrackBuilder.reconcileEdges( ...
                edges, observations, options);
            tracks = ProjectionAlignmentTrackBuilder.tracks( ...
                edges, observations);
            pathDiagnostics = ProjectionAlignmentTrackBuilder.pathDiagnostics( ...
                edges, observations, options.PathConsistencyTolerancePixels);

            result = struct(Format=ProjectionAlignmentTrackBuilder.Format, ...
                Version=ProjectionAlignmentTrackBuilder.Version, ...
                GenerationId=ProjectionAlignmentTrackBuilder.generationId( ...
                edges, observations, options), ...
                Options=options, Observations=observations, Edges=edges, ...
                Tracks=tracks, PathDiagnostics=pathDiagnostics, ...
                Diagnostics=ProjectionAlignmentTrackBuilder.diagnostics( ...
                inputRecordCount, edges, observations, tracks, pathDiagnostics));
        end
    end

    methods (Static, Access = private)
        function validateMatchResult(matchResult)
            if ~isstruct(matchResult) || ~isscalar(matchResult) || ...
                    ~isfield(matchResult, "Matches") || ...
                    ~isstruct(matchResult.Matches)
                error("ProjectionAlignmentTrackBuilder:invalidMatchResult", ...
                    "Match result must contain a Matches struct array.");
            end
        end

        function options = validateOptions(options)
            defaults = ProjectionAlignmentTrackBuilder.defaults();
            if isempty(options)
                options = struct();
            end
            if ~isstruct(options) || ~isscalar(options)
                error("ProjectionAlignmentTrackBuilder:invalidOptions", ...
                    "Track options must be a scalar struct.");
            end
            names = fieldnames(options);
            for index = 1:numel(names)
                if ~isfield(defaults, names{index})
                    error("ProjectionAlignmentTrackBuilder:invalidOptions", ...
                        "Unknown track option %s.", names{index});
                end
                defaults.(names{index}) = options.(names{index});
            end
            positiveNames = ["ObservationMergeTolerancePixels" ...
                "PathConsistencyTolerancePixels"];
            for name = positiveNames
                value = defaults.(name);
                if ~isnumeric(value) || ~isscalar(value) || ...
                        ~isfinite(value) || value <= 0
                    error("ProjectionAlignmentTrackBuilder:invalidOptions", ...
                        "%s must be a finite positive scalar.", name);
                end
                defaults.(name) = double(value);
            end
            limitNames = ["MaximumDescriptorMetric" ...
                "MaximumPlaneDisagreementMeters"];
            for name = limitNames
                value = defaults.(name);
                if ~isnumeric(value) || ~isscalar(value) || isnan(value) || ...
                        value < 0
                    error("ProjectionAlignmentTrackBuilder:invalidOptions", ...
                        "%s must be a nonnegative scalar or Inf.", name);
                end
                defaults.(name) = double(value);
            end
            if ~islogical(defaults.IncludeOnlyAcceptedRecords) || ...
                    ~isscalar(defaults.IncludeOnlyAcceptedRecords)
                error("ProjectionAlignmentTrackBuilder:invalidOptions", ...
                    "IncludeOnlyAcceptedRecords must be a logical scalar.");
            end
            options = defaults;
        end

        function [edges, inputRecordCount] = collectEdges(matchResult, options)
            edges = ProjectionAlignmentTrackBuilder.emptyEdges();
            inputRecordCount = 0;
            for pairIndex = 1:numel(matchResult.Matches)
                pairMatch = ProjectionAlignmentMatchLedger.ensurePair( ...
                    matchResult.Matches(pairIndex));
                records = pairMatch.MatchLedger;
                inputRecordCount = inputRecordCount + numel(records);
                for recordIndex = 1:numel(records)
                    record = records(recordIndex);
                    if options.IncludeOnlyAcceptedRecords && ...
                            (~record.Accepted || record.Disabled || ...
                            record.ManualState ~= "enabled")
                        continue
                    end
                    edge = ProjectionAlignmentTrackBuilder.edge( ...
                        record, pairIndex);
                    edges(end + 1) = edge; %#ok<AGROW>
                end
            end
            if ~isempty(edges)
                edgeKeys = string({edges.PairId}) + "|" + ...
                    string({edges.RecordId});
                [~, order] = sort(edgeKeys);
                edges = edges(order);
            end
        end

        function edge = edge(record, pairIndex)
            pairIdentity = ProjectionViewMetadata.pairIdentity( ...
                record.PairLayerIds(1), record.PairLayerIds(2));
            endpoints = repmat(ProjectionAlignmentTrackBuilder.emptyEndpoint(), ...
                1, 2);
            endpoints(1) = struct(ViewId=record.PairLayerIds(1), ...
                SourceRowPixels=record.MovingSourceRowPixels, ...
                SourceColumnPixels=record.MovingSourceColumnPixels, ...
                PlaneMeters=record.MovingPlaneMeters, ...
                FeatureIndex=record.MovingFeatureIndex);
            endpoints(2) = struct(ViewId=record.PairLayerIds(2), ...
                SourceRowPixels=record.ReferenceSourceRowPixels, ...
                SourceColumnPixels=record.ReferenceSourceColumnPixels, ...
                PlaneMeters=record.ReferencePlaneMeters, ...
                FeatureIndex=record.ReferenceFeatureIndex);
            edge = ProjectionAlignmentTrackBuilder.emptyEdge();
            edge.RecordId = record.RecordId;
            edge.PairId = pairIdentity.PairId;
            edge.PairIndex = pairIndex;
            edge.ViewIds = record.PairLayerIds;
            edge.Endpoints = endpoints;
            edge.DescriptorMetric = record.DescriptorMetric;
            edge.MatchScore = record.MatchScore;
            edge.PlaneDisagreementMeters = norm( ...
                record.MovingPlaneMeters - record.ReferencePlaneMeters);
        end

        function [observations, edges] = clusterObservations(edges, tolerance)
            observations = repmat( ...
                ProjectionAlignmentTrackBuilder.emptyObservation(), 1, 0);
            if isempty(edges)
                return
            end
            candidates = ProjectionAlignmentTrackBuilder.endpointCandidates(edges);
            viewIds = sort(unique(string({candidates.ViewId})));
            candidateNodeIndices = zeros(1, numel(candidates));
            for viewId = viewIds
                viewCandidateIndices = find(string({candidates.ViewId}) == viewId);
                coordinates = [[candidates(viewCandidateIndices).SourceRowPixels].' ...
                    [candidates(viewCandidateIndices).SourceColumnPixels].'];
                [~, localOrder] = sortrows(coordinates, [1 2]);
                viewCandidateIndices = viewCandidateIndices(localOrder);
                viewObservations = ProjectionAlignmentTrackBuilder. ...
                    clusterViewCandidates(candidates, viewCandidateIndices, ...
                    viewId, tolerance);
                startIndex = numel(observations);
                observations = [observations viewObservations]; %#ok<AGROW>
                for localIndex = 1:numel(viewObservations)
                    memberIndices = viewObservations(localIndex).CandidateIndices;
                    candidateNodeIndices(memberIndices) = startIndex + localIndex;
                end
            end
            for candidateIndex = 1:numel(candidates)
                edgeIndex = candidates(candidateIndex).EdgeIndex;
                side = candidates(candidateIndex).Side;
                edges(edgeIndex).NodeIndices(side) = ...
                    candidateNodeIndices(candidateIndex);
            end
            observations = rmfield(observations, "CandidateIndices");
        end

        function candidates = endpointCandidates(edges)
            candidateCount = 2 * numel(edges);
            candidates = repmat(struct(ViewId="", SourceRowPixels=NaN, ...
                SourceColumnPixels=NaN, RecordId="", EdgeIndex=0, Side=0), ...
                1, candidateCount);
            cursor = 0;
            for edgeIndex = 1:numel(edges)
                for side = 1:2
                    cursor = cursor + 1;
                    endpoint = edges(edgeIndex).Endpoints(side);
                    candidates(cursor) = struct(ViewId=endpoint.ViewId, ...
                        SourceRowPixels=endpoint.SourceRowPixels, ...
                        SourceColumnPixels=endpoint.SourceColumnPixels, ...
                        RecordId=edges(edgeIndex).RecordId, ...
                        EdgeIndex=edgeIndex, Side=side);
                end
            end
        end

        function observations = clusterViewCandidates( ...
                candidates, candidateIndices, viewId, tolerance)
            memberLists = cell(1, 0);
            centers = zeros(0, 2);
            for candidateIndex = candidateIndices
                coordinate = [candidates(candidateIndex).SourceRowPixels ...
                    candidates(candidateIndex).SourceColumnPixels];
                distances = vecnorm(centers - coordinate, 2, 2);
                matches = find(distances <= tolerance);
                if isempty(matches)
                    centers(end + 1, :) = coordinate; %#ok<AGROW>
                    memberLists{end + 1} = candidateIndex; %#ok<AGROW>
                else
                    [~, closestOffset] = min(distances(matches));
                    clusterIndex = matches(closestOffset);
                    memberLists{clusterIndex}(end + 1) = candidateIndex;
                    rows = [candidates(memberLists{clusterIndex}).SourceRowPixels];
                    columns = ...
                        [candidates(memberLists{clusterIndex}).SourceColumnPixels];
                    centers(clusterIndex, :) = [mean(rows) mean(columns)];
                end
            end
            observations = repmat( ...
                ProjectionAlignmentTrackBuilder.emptyObservation(), ...
                1, size(centers, 1));
            for clusterIndex = 1:size(centers, 1)
                members = memberLists{clusterIndex};
                observations(clusterIndex) = struct( ...
                    ObservationId=sprintf("%s:obs-%06d", viewId, clusterIndex), ...
                    ViewId=viewId, SourceRowPixels=centers(clusterIndex, 1), ...
                    SourceColumnPixels=centers(clusterIndex, 2), ...
                    CandidateCount=numel(members), ...
                    RecordIds=sort(unique(string({candidates(members).RecordId}))), ...
                    CandidateIndices=members);
            end
        end

        function edges = reconcileEdges(edges, observations, options)
            if isempty(edges)
                return
            end
            quality = [edges.DescriptorMetric].';
            quality(~isfinite(quality)) = Inf;
            pairIds = string({edges.PairId}).';
            recordIds = string({edges.RecordId}).';
            ordering = table(quality, pairIds, recordIds, (1:numel(edges)).', ...
                VariableNames=["Quality" "PairId" "RecordId" "EdgeIndex"]);
            ordering = sortrows(ordering, ["Quality" "PairId" "RecordId"]);
            parent = 1:numel(observations);
            for orderIndex = 1:height(ordering)
                edgeIndex = ordering.EdgeIndex(orderIndex);
                edge = edges(edgeIndex);
                reason = ProjectionAlignmentTrackBuilder.precheckReason( ...
                    edge, options);
                if strlength(reason) > 0
                    edges(edgeIndex).State = "rejected";
                    edges(edgeIndex).RejectionReason = reason;
                    continue
                end
                firstRoot = ProjectionAlignmentTrackBuilder.root( ...
                    parent, edge.NodeIndices(1));
                secondRoot = ProjectionAlignmentTrackBuilder.root( ...
                    parent, edge.NodeIndices(2));
                if firstRoot ~= secondRoot
                    firstViews = ProjectionAlignmentTrackBuilder.componentViews( ...
                        parent, firstRoot, observations);
                    secondViews = ProjectionAlignmentTrackBuilder.componentViews( ...
                        parent, secondRoot, observations);
                    if any(ismember(firstViews, secondViews))
                        edges(edgeIndex).State = "rejected";
                        edges(edgeIndex).RejectionReason = ...
                            "duplicateViewConflict";
                        continue
                    end
                    parent(parent == max(firstRoot, secondRoot)) = ...
                        min(firstRoot, secondRoot);
                end
                edges(edgeIndex).Accepted = true;
                edges(edgeIndex).State = "accepted";
                edges(edgeIndex).RejectionReason = "";
            end
        end

        function reason = precheckReason(edge, options)
            reason = "";
            if isfinite(edge.DescriptorMetric) && ...
                    edge.DescriptorMetric > options.MaximumDescriptorMetric
                reason = "descriptorInconsistent";
            elseif isfinite(edge.PlaneDisagreementMeters) && ...
                    edge.PlaneDisagreementMeters > ...
                    options.MaximumPlaneDisagreementMeters
                reason = "geometryInconsistent";
            end
        end

        function tracks = tracks(edges, observations)
            tracks = ProjectionAlignmentTrackBuilder.emptyTracks();
            if isempty(observations)
                return
            end
            parent = ProjectionAlignmentTrackBuilder.acceptedParents( ...
                edges, numel(observations));
            roots = unique(arrayfun(@(index) ...
                ProjectionAlignmentTrackBuilder.root(parent, index), ...
                1:numel(observations)));
            for root = roots
                nodeIndices = find(arrayfun(@(index) ...
                    ProjectionAlignmentTrackBuilder.root(parent, index) == root, ...
                    1:numel(observations)));
                if numel(nodeIndices) < 2
                    continue
                end
                viewIds = string({observations(nodeIndices).ViewId});
                [~, order] = sort(viewIds);
                nodeIndices = nodeIndices(order);
                observationIds = string({observations(nodeIndices).ObservationId});
                edgeMask = [edges.Accepted] & ...
                    arrayfun(@(edge) all(ismember(edge.NodeIndices, nodeIndices)), edges);
                track = struct( ...
                    TrackId="track-" + extractBefore( ...
                    ProjectionGeometryFingerprint.hash(observationIds), 17), ...
                    ObservationIds=observationIds, ViewIds=viewIds(order), ...
                    SourceRowsPixels=[observations(nodeIndices).SourceRowPixels], ...
                    SourceColumnsPixels= ...
                    [observations(nodeIndices).SourceColumnPixels], ...
                    RecordIds=sort(string({edges(edgeMask).RecordId})), ...
                    ViewCount=numel(nodeIndices), EdgeCount=nnz(edgeMask), ...
                    State="valid", RejectionReasons=strings(1, 0));
                tracks(end + 1) = track; %#ok<AGROW>
            end
            if ~isempty(tracks)
                [~, order] = sort(string({tracks.TrackId}));
                tracks = tracks(order);
            end
        end

        function diagnostics = pathDiagnostics(edges, observations, tolerance)
            diagnostics = ProjectionAlignmentTrackBuilder.emptyPathDiagnostics();
            if isempty(edges) || isempty(observations)
                return
            end
            acceptedParents = ProjectionAlignmentTrackBuilder.acceptedParents( ...
                edges, numel(observations));
            for edgeIndex = 1:numel(edges)
                edge = edges(edgeIndex);
                [found, startNode, directEndNode, composedEndNode, ...
                    nodePath, edgePath] = ...
                    ProjectionAlignmentTrackBuilder.alternatePath( ...
                    edges, observations, acceptedParents, edgeIndex);
                if ~found
                    continue
                end
                directCoordinate = [ ...
                    observations(directEndNode).SourceRowPixels ...
                    observations(directEndNode).SourceColumnPixels];
                composedCoordinate = [ ...
                    observations(composedEndNode).SourceRowPixels ...
                    observations(composedEndNode).SourceColumnPixels];
                disagreement = norm(directCoordinate - composedCoordinate);
                consistent = disagreement <= tolerance;
                state = "inconsistent";
                if consistent
                    state = "consistent";
                end
                pathObservationIds = string( ...
                    {observations(nodePath).ObservationId});
                pathRecordIds = string({edges(edgePath).RecordId});
                diagnostics(end + 1) = struct( ...
                    DiagnosticId=sprintf("path-%06d", numel(diagnostics) + 1), ...
                    DirectRecordId=edge.RecordId, DirectPairId=edge.PairId, ...
                    StartObservationId=observations(startNode).ObservationId, ...
                    DirectEndObservationId= ...
                    observations(directEndNode).ObservationId, ...
                    ComposedEndObservationId= ...
                    observations(composedEndNode).ObservationId, ...
                    PathObservationIds=pathObservationIds, ...
                    PathRecordIds=pathRecordIds, ...
                    CycleViewIds=string({observations(nodePath).ViewId}), ...
                    EndDisagreementPixels=disagreement, ...
                    Consistent=consistent, DirectEdgeAccepted=edge.Accepted, ...
                    State=state); %#ok<AGROW>
            end
        end

        function [found, startNode, directEndNode, composedEndNode, ...
                nodePath, edgePath] = alternatePath( ...
                edges, observations, parents, excludedEdgeIndex)
            edge = edges(excludedEdgeIndex);
            found = false;
            startNode = 0;
            directEndNode = 0;
            composedEndNode = 0;
            nodePath = zeros(1, 0);
            edgePath = zeros(1, 0);
            for orientation = 1:2
                startCandidate = edge.NodeIndices(orientation);
                endCandidate = edge.NodeIndices(3 - orientation);
                targetViewId = observations(endCandidate).ViewId;
                if edge.Accepted
                    targetCandidates = endCandidate;
                else
                    startRoot = ProjectionAlignmentTrackBuilder.root( ...
                        parents, startCandidate);
                    componentMask = arrayfun(@(index) ...
                        ProjectionAlignmentTrackBuilder.root(parents, index) == ...
                        startRoot, 1:numel(observations));
                    targetCandidates = find(componentMask & ...
                        string({observations.ViewId}) == targetViewId);
                    targetCandidates(targetCandidates == endCandidate) = [];
                end
                for targetCandidate = targetCandidates
                    [pathFound, candidateNodePath, candidateEdgePath] = ...
                        ProjectionAlignmentTrackBuilder.breadthFirstPath( ...
                        edges, startCandidate, targetCandidate, excludedEdgeIndex, ...
                        numel(observations));
                    if pathFound
                        found = true;
                        startNode = startCandidate;
                        directEndNode = endCandidate;
                        composedEndNode = targetCandidate;
                        nodePath = candidateNodePath;
                        edgePath = candidateEdgePath;
                        return
                    end
                end
            end
        end

        function [found, nodePath, edgePath] = breadthFirstPath( ...
                edges, startNode, targetNode, excludedEdgeIndex, nodeCount)
            queue = startNode;
            visited = false(1, nodeCount);
            visited(startNode) = true;
            previousNode = zeros(1, nodeCount);
            previousEdge = zeros(1, nodeCount);
            while ~isempty(queue)
                node = queue(1);
                queue(1) = [];
                if node == targetNode
                    break
                end
                for edgeIndex = 1:numel(edges)
                    if edgeIndex == excludedEdgeIndex || ~edges(edgeIndex).Accepted || ...
                            ~ismember(node, edges(edgeIndex).NodeIndices)
                        continue
                    end
                    neighbor = edges(edgeIndex).NodeIndices( ...
                        edges(edgeIndex).NodeIndices ~= node);
                    if ~visited(neighbor)
                        visited(neighbor) = true;
                        previousNode(neighbor) = node;
                        previousEdge(neighbor) = edgeIndex;
                        queue(end + 1) = neighbor; %#ok<AGROW>
                    end
                end
            end
            found = visited(targetNode);
            nodePath = zeros(1, 0);
            edgePath = zeros(1, 0);
            if ~found
                return
            end
            nodePath = targetNode;
            cursor = targetNode;
            while cursor ~= startNode
                edgePath = [previousEdge(cursor) edgePath]; %#ok<AGROW>
                cursor = previousNode(cursor);
                nodePath = [cursor nodePath]; %#ok<AGROW>
            end
        end

        function parent = acceptedParents(edges, observationCount)
            parent = 1:observationCount;
            for edge = edges([edges.Accepted])
                firstRoot = ProjectionAlignmentTrackBuilder.root( ...
                    parent, edge.NodeIndices(1));
                secondRoot = ProjectionAlignmentTrackBuilder.root( ...
                    parent, edge.NodeIndices(2));
                if firstRoot ~= secondRoot
                    parent(parent == max(firstRoot, secondRoot)) = ...
                        min(firstRoot, secondRoot);
                end
            end
        end

        function root = root(parent, node)
            root = node;
            while parent(root) ~= root
                root = parent(root);
            end
        end

        function viewIds = componentViews(parent, root, observations)
            memberMask = arrayfun(@(index) ...
                ProjectionAlignmentTrackBuilder.root(parent, index) == root, ...
                1:numel(observations));
            viewIds = string({observations(memberMask).ViewId});
        end

        function id = generationId(edges, observations, options)
            payload = struct(Options=options, ...
                ObservationIds=string({observations.ObservationId}), ...
                EdgeRecordIds=string({edges.RecordId}), ...
                EdgeStates=string({edges.State}), ...
                EdgeReasons=string({edges.RejectionReason}));
            id = "tracks-" + extractBefore( ...
                ProjectionGeometryFingerprint.hash(payload), 17);
        end

        function value = diagnostics(inputRecordCount, edges, observations, ...
                tracks, pathDiagnostics)
            acceptedMask = [edges.Accepted];
            states = string({pathDiagnostics.State});
            value = struct(InputRecordCount=inputRecordCount, ...
                EligibleEdgeCount=numel(edges), ...
                ObservationCount=numel(observations), ...
                TrackCount=numel(tracks), ...
                AcceptedEdgeCount=nnz(acceptedMask), ...
                RejectedEdgeCount=nnz(~acceptedMask), ...
                ConflictCount=nnz(string({edges.RejectionReason}) == ...
                "duplicateViewConflict"), ...
                PathDiagnosticCount=numel(pathDiagnostics), ...
                ConsistentPathCount=nnz(states == "consistent"), ...
                InconsistentPathCount=nnz(states == "inconsistent"));
        end

        function endpoint = emptyEndpoint()
            endpoint = struct(ViewId="", SourceRowPixels=NaN, ...
                SourceColumnPixels=NaN, PlaneMeters=[NaN NaN], FeatureIndex=0);
        end

        function edge = emptyEdge()
            edge = struct(RecordId="", PairId="", PairIndex=0, ...
                ViewIds=strings(1, 2), ...
                Endpoints=repmat( ...
                ProjectionAlignmentTrackBuilder.emptyEndpoint(), 1, 2), ...
                NodeIndices=zeros(1, 2), DescriptorMetric=NaN, ...
                MatchScore=NaN, PlaneDisagreementMeters=NaN, ...
                Accepted=false, State="candidate", RejectionReason="");
        end

        function edges = emptyEdges()
            edges = repmat(ProjectionAlignmentTrackBuilder.emptyEdge(), 1, 0);
        end

        function observation = emptyObservation()
            observation = struct(ObservationId="", ViewId="", ...
                SourceRowPixels=NaN, SourceColumnPixels=NaN, ...
                CandidateCount=0, RecordIds=strings(1, 0), ...
                CandidateIndices=zeros(1, 0));
        end

        function observations = emptyObservations()
            observation = ProjectionAlignmentTrackBuilder.emptyObservation();
            observation = rmfield(observation, "CandidateIndices");
            observations = repmat(observation, 1, 0);
        end

        function tracks = emptyTracks()
            tracks = struct("TrackId", {}, "ObservationIds", {}, ...
                "ViewIds", {}, "SourceRowsPixels", {}, ...
                "SourceColumnsPixels", {}, "RecordIds", {}, ...
                "ViewCount", {}, "EdgeCount", {}, "State", {}, ...
                "RejectionReasons", {});
        end

        function diagnostics = emptyPathDiagnostics()
            diagnostics = struct("DiagnosticId", {}, "DirectRecordId", {}, ...
                "DirectPairId", {}, "StartObservationId", {}, ...
                "DirectEndObservationId", {}, "ComposedEndObservationId", {}, ...
                "PathObservationIds", {}, "PathRecordIds", {}, ...
                "CycleViewIds", {}, "EndDisagreementPixels", {}, ...
                "Consistent", {}, "DirectEdgeAccepted", {}, "State", {});
        end
    end
end
