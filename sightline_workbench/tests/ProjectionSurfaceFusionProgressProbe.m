classdef ProjectionSurfaceFusionProgressProbe < handle
    %ProjectionSurfaceFusionProgressProbe Record runtime-only progress events.

    properties (SetAccess = private)
        Fractions (1, :) double = zeros(1, 0)
        Stages (1, :) string = strings(1, 0)
    end

    methods
        function record(probe, update)
            probe.Fractions(end + 1) = update.Fraction;
            probe.Stages(end + 1) = string(update.Stage);
        end
    end
end
