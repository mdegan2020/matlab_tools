classdef ProjectionAlignmentSolveProgressProbe < handle
    %ProjectionAlignmentSolveProgressProbe Capture runtime-only progress updates.

    properties
        Updates cell = {}
        CancelOnSensitivity logical = false
        CancellationRequested logical = false
    end

    methods
        function record(probe, update)
            probe.Updates{end + 1} = update;
            if probe.CancelOnSensitivity && ...
                    string(update.Stage) == "sensitivityChild"
                probe.CancellationRequested = true;
            end
        end

        function tf = cancelled(probe)
            tf = probe.CancellationRequested;
        end

        function stages = stages(probe)
            stages = strings(1, numel(probe.Updates));
            for index = 1:numel(probe.Updates)
                stages(index) = string(probe.Updates{index}.Stage);
            end
        end
    end
end
