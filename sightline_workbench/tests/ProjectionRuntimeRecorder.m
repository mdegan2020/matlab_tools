classdef ProjectionRuntimeRecorder < handle
    %ProjectionRuntimeRecorder Capture progress and deterministic cancellation.

    properties
        Events struct = struct("Fraction", {}, "Stage", {}, ...
            "Completed", {}, "Total", {}, "ElapsedSeconds", {}, ...
            "Message", {})
        CancellationCallCount (1, 1) double = 0
        CancelAfterCalls (1, 1) double = Inf
        CancelStage (1, 1) string = ""
        LastParentStage (1, 1) string = ""
    end

    methods
        function record(recorder, event)
            recorder.Events(end + 1) = event;
            if isfield(event, "ParentStage")
                recorder.LastParentStage = string(event.ParentStage);
            elseif isfield(event, "Stage")
                recorder.LastParentStage = string(event.Stage);
            end
        end

        function recordRunner(recorder, event)
            recorder.LastParentStage = string(event.Stage);
        end

        function value = cancel(recorder)
            recorder.CancellationCallCount = ...
                recorder.CancellationCallCount + 1;
            callLimitReached = ...
                recorder.CancellationCallCount >= recorder.CancelAfterCalls;
            stageReached = strlength(recorder.CancelStage) > 0 && ...
                recorder.LastParentStage == recorder.CancelStage;
            value = logical(callLimitReached || stageReached);
        end
    end
end
