classdef ProjectionMotionPlayback
    %ProjectionMotionPlayback Pure policy for bounded motion playback.

    properties (Constant)
        MinimumRateFps = 0.5
        MaximumRateFps = 10
        DefaultRateFps = 2
    end

    methods (Static)
        function rateFps = rate(rateFps)
            %rate Validate the operator-selected playback rate.
            if ~isnumeric(rateFps) || ~isscalar(rateFps) || ...
                    ~isfinite(rateFps) || ...
                    rateFps < ProjectionMotionPlayback.MinimumRateFps || ...
                    rateFps > ProjectionMotionPlayback.MaximumRateFps
                error("ProjectionMotionPlayback:invalidRate", ...
                    "Playback rate must be between 0.5 and 10 frames/second.");
            end
            rateFps = double(rateFps);
        end

        function delaySeconds = delay(rateFps)
            %delay Return the no-skip single-shot timer delay.
            delaySeconds = 1 / ProjectionMotionPlayback.rate(rateFps);
        end

        function lookahead = next(sequence, position, loop)
            %next Return at most one next-frame identity.
            [nextPosition, changed, boundary] = ...
                ProjectionMotionSequence.step(sequence, position, 1, loop);
            lookahead = struct(Available=changed, Boundary=boundary, ...
                Position=0, ViewId="", LayerIndex=0, Ready=false);
            if changed
                lookahead.Position = nextPosition;
                lookahead.ViewId = ...
                    string(sequence.Frames(nextPosition).ViewId);
            end
        end
    end
end
