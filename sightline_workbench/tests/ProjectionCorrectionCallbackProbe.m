classdef ProjectionCorrectionCallbackProbe < handle
    %ProjectionCorrectionCallbackProbe Mutable callback test recorder.

    properties
        Events string = strings(1, 0)
        Store = []
    end

    methods
        function record(probe, label, ~)
            probe.Events(end + 1) = string(label);
        end

        function reenter(probe, correctionSet)
            probe.Events(end + 1) = "accepted-reenter";
            probe.Store.accept(correctionSet.GenerationId);
        end

        function fail(probe, ~)
            probe.Events(end + 1) = "applied-fail";
            error("ProjectionCorrectionCallbackProbe:failure", ...
                "Deliberate callback failure.");
        end
    end
end
