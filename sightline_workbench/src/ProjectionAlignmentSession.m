classdef ProjectionAlignmentSession < handle
    %ProjectionAlignmentSession Graphics-free staged alignment workflow state.

    properties
        Request struct = struct()
        WorkingImages struct = struct()
        RawMatchResult struct = struct()
        PreRoiMatchResult struct = struct()
        FilteredMatchResult struct = struct()
        CuratedMatchMask cell = {}
        DeletedMatchMask cell = {}
        CurationUndoStack cell = {}
        ManualAdjustmentUndoStack cell = {}
        ManualAdjustmentHistory cell = {}
        SelectedMatchRows double = []
        Result struct = struct()
        RoiBounds double = []
        CancelRequested logical = false
        WorkingImageCacheKey struct = struct()
        WorkingImageCacheValue struct = struct()
        WorkingImageCacheHits double = 0
        WorkingImageCacheMisses double = 0
        ControlState struct = struct()
        StatusText string = "Alignment not run"
        ActiveStage string = ""
        ActiveStatus string = ""
        LastCompletedStage string = ""
        LastCompletedStatus string = ""
    end

    properties (SetAccess = private)
        Stage string = "setup"
        Revision uint64 = uint64(0)
        MatchRevision uint64 = uint64(0)
        FilterRevision uint64 = uint64(0)
        SolveRevision uint64 = uint64(0)
        PreviewRevision uint64 = uint64(0)
        ApplyRevision uint64 = uint64(0)
    end

    methods
        function reset(session)
            session.clearComputation();
            session.RoiBounds = [];
            session.clearWorkingImageCache();
            session.ControlState = struct();
            session.StatusText = "Alignment reset.";
        end

        function clearComputation(session)
            session.Request = struct();
            session.WorkingImages = struct();
            session.RawMatchResult = struct();
            session.PreRoiMatchResult = struct();
            session.FilteredMatchResult = struct();
            session.CuratedMatchMask = {};
            session.DeletedMatchMask = {};
            session.CurationUndoStack = {};
            session.ManualAdjustmentUndoStack = {};
            session.ManualAdjustmentHistory = {};
            session.SelectedMatchRows = [];
            session.Result = struct();
            session.CancelRequested = false;
            session.ActiveStage = "";
            session.ActiveStatus = "";
            session.LastCompletedStage = "";
            session.LastCompletedStatus = "";
            session.StatusText = "Alignment reset.";
            session.bumpRevision();
            session.Stage = "setup";
            session.MatchRevision = uint64(0);
            session.FilterRevision = uint64(0);
            session.SolveRevision = uint64(0);
            session.PreviewRevision = uint64(0);
            session.ApplyRevision = uint64(0);
        end

        function storeMatches(session, request, workingImages, rawMatches, ...
                preRoiMatches, filteredMatches, curatedMask, deletedMask)
            session.storeRawMatches(request, workingImages, rawMatches);
            session.storeFilteredMatches(preRoiMatches, filteredMatches, ...
                curatedMask, deletedMask);
        end

        function storeRawMatches(session, request, workingImages, rawMatches)
            session.Request = request;
            session.WorkingImages = workingImages;
            session.RawMatchResult = rawMatches;
            session.PreRoiMatchResult = struct();
            session.FilteredMatchResult = struct();
            session.CuratedMatchMask = {};
            session.DeletedMatchMask = {};
            session.CurationUndoStack = {};
            session.SelectedMatchRows = [];
            session.Result = struct();
            session.CancelRequested = false;
            session.bumpRevision();
            session.Stage = "matched";
            session.MatchRevision = session.Revision;
            session.FilterRevision = uint64(0);
            session.SolveRevision = uint64(0);
            session.PreviewRevision = uint64(0);
            session.ApplyRevision = uint64(0);
        end

        function storeFilteredMatches(session, preRoiMatches, ...
                filteredMatches, curatedMask, deletedMask)
            session.PreRoiMatchResult = preRoiMatches;
            session.FilteredMatchResult = filteredMatches;
            session.CuratedMatchMask = curatedMask;
            session.DeletedMatchMask = deletedMask;
            session.CurationUndoStack = {};
            session.SelectedMatchRows = [];
            session.Result = struct();
            session.bumpRevision();
            session.Stage = "curated";
            session.FilterRevision = session.Revision;
            session.SolveRevision = uint64(0);
            session.PreviewRevision = uint64(0);
            session.ApplyRevision = uint64(0);
        end

        function replaceFilteredMatches(session, filteredMatches, ...
                curatedMask, deletedMask)
            session.FilteredMatchResult = filteredMatches;
            session.CuratedMatchMask = curatedMask;
            session.DeletedMatchMask = deletedMask;
            session.CurationUndoStack = {};
            session.SelectedMatchRows = [];
            session.invalidateSolve();
            session.FilterRevision = session.Revision;
        end

        function invalidateSolve(session)
            session.Result = struct();
            session.bumpRevision();
            session.Stage = "curated";
            session.SolveRevision = uint64(0);
            session.PreviewRevision = uint64(0);
            session.ApplyRevision = uint64(0);
        end

        function invalidateMatch(session)
            session.Result = struct();
            session.bumpRevision();
            session.Stage = "setup";
            session.MatchRevision = uint64(0);
            session.FilterRevision = uint64(0);
            session.SolveRevision = uint64(0);
            session.PreviewRevision = uint64(0);
            session.ApplyRevision = uint64(0);
        end

        function invalidateFilter(session)
            session.Result = struct();
            session.bumpRevision();
            if session.MatchRevision > 0
                session.Stage = "matched";
            else
                session.Stage = "setup";
            end
            session.FilterRevision = uint64(0);
            session.SolveRevision = uint64(0);
            session.PreviewRevision = uint64(0);
            session.ApplyRevision = uint64(0);
        end

        function storeSolve(session, result)
            session.Result = result;
            session.bumpRevision();
            status = "solved";
            if isstruct(result) && isfield(result, "Status")
                status = string(result.Status);
            end
            if status == "solved"
                session.Stage = "solved";
                session.SolveRevision = session.Revision;
            else
                session.Stage = status;
                session.SolveRevision = uint64(0);
            end
            session.PreviewRevision = uint64(0);
            session.ApplyRevision = uint64(0);
        end

        function storeManualAdjustment(session, record)
            if ~isstruct(record) || ~isscalar(record)
                error("ProjectionAlignmentSession:invalidManualAdjustment", ...
                    "Manual adjustment record must be a scalar struct.");
            end
            session.invalidateSolve();
            record.Revision = double(session.Revision);
            record.Undone = false;
            session.ManualAdjustmentUndoStack{end + 1} = record;
            session.ManualAdjustmentHistory{end + 1} = record;
        end

        function [record, found] = popManualAdjustment(session)
            found = ~isempty(session.ManualAdjustmentUndoStack);
            record = struct();
            if ~found
                return
            end
            record = session.ManualAdjustmentUndoStack{end};
            session.ManualAdjustmentUndoStack(end) = [];
            for k = numel(session.ManualAdjustmentHistory):-1:1
                candidate = session.ManualAdjustmentHistory{k};
                if isfield(candidate, "Revision") && ...
                        candidate.Revision == record.Revision
                    candidate.Undone = true;
                    session.ManualAdjustmentHistory{k} = candidate;
                    break
                end
            end
            session.invalidateSolve();
        end

        function markPreviewed(session)
            session.bumpRevision();
            session.Stage = "previewed";
            session.PreviewRevision = session.Revision;
            session.ApplyRevision = uint64(0);
        end

        function markApplied(session)
            session.bumpRevision();
            session.Stage = "applied";
            session.ApplyRevision = session.Revision;
        end

        function markReverted(session)
            session.bumpRevision();
            if session.SolveRevision > 0
                session.Stage = "solved";
            else
                session.Stage = "curated";
            end
            session.PreviewRevision = uint64(0);
            session.ApplyRevision = uint64(0);
        end

        function requestCancel(session)
            session.CancelRequested = true;
        end

        function clearCancel(session)
            session.CancelRequested = false;
        end

        function beginStage(session, stage, status)
            session.ActiveStage = string(stage);
            session.ActiveStatus = string(status);
            session.StatusText = string(status);
        end

        function completeStage(session, stage, status)
            session.LastCompletedStage = string(stage);
            session.LastCompletedStatus = string(status);
            session.ActiveStage = "";
            session.ActiveStatus = "";
            session.StatusText = string(status);
        end

        function stopStage(session, status)
            session.ActiveStage = "";
            session.ActiveStatus = "";
            session.StatusText = string(status);
        end

        function clearWorkingImageCache(session)
            session.WorkingImageCacheKey = struct();
            session.WorkingImageCacheValue = struct();
            session.WorkingImageCacheHits = 0;
            session.WorkingImageCacheMisses = 0;
        end

        function state = diagnostics(session)
            state = struct();
            state.Stage = session.Stage;
            state.Revision = double(session.Revision);
            state.MatchRevision = double(session.MatchRevision);
            state.FilterRevision = double(session.FilterRevision);
            state.SolveRevision = double(session.SolveRevision);
            state.PreviewRevision = double(session.PreviewRevision);
            state.ApplyRevision = double(session.ApplyRevision);
            state.Stale = struct( ...
                Match=session.MatchRevision == 0, ...
                Filter=session.FilterRevision == 0, ...
                Solve=session.SolveRevision == 0, ...
                Preview=session.PreviewRevision == 0, ...
                Apply=session.ApplyRevision == 0);
            state.ManualAdjustmentCount = ...
                numel(session.ManualAdjustmentHistory);
            state.ManualAdjustmentUndoCount = ...
                numel(session.ManualAdjustmentUndoStack);
            state.StatusText = session.StatusText;
            state.ActiveStage = session.ActiveStage;
            state.ActiveStatus = session.ActiveStatus;
            state.LastCompletedStage = session.LastCompletedStage;
            state.LastCompletedStatus = session.LastCompletedStatus;
        end
    end

    methods (Access = private)
        function bumpRevision(session)
            session.Revision = session.Revision + 1;
        end
    end
end
