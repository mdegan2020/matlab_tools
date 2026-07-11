classdef ProjectionMotionPlaybackTest < matlab.unittest.TestCase
    %ProjectionMotionPlaybackTest Tests bounded playback policy.

    methods (TestClassSetup)
        function addSourceToPath(testCase)
            projectRoot = fileparts(fileparts(mfilename("fullpath")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(projectRoot, "src")));
        end
    end

    methods (Test)
        function testRateRangeAndDefaultDelay(testCase)
            testCase.verifyEqual(ProjectionMotionPlayback.DefaultRateFps, 2);
            testCase.verifyEqual(ProjectionMotionPlayback.delay(2), 0.5);
            testCase.verifyEqual(ProjectionMotionPlayback.rate(0.5), 0.5);
            testCase.verifyEqual(ProjectionMotionPlayback.rate(10), 10);
        end

        function testRateRejectsValuesOutsideOperatorRange(testCase)
            testCase.verifyError(@() ProjectionMotionPlayback.rate(0.49), ...
                "ProjectionMotionPlayback:invalidRate");
            testCase.verifyError(@() ProjectionMotionPlayback.rate(10.01), ...
                "ProjectionMotionPlayback:invalidRate");
        end

        function testLookaheadContainsAtMostOneFrame(testCase)
            scene = ProjectionMotionPlaybackTest.makeScene();
            sequence = ProjectionMotionSequence.build(scene, ...
                struct(LayerIndices=1:3));

            middle = ProjectionMotionPlayback.next(sequence, 1, false);
            boundary = ProjectionMotionPlayback.next(sequence, 3, false);
            looped = ProjectionMotionPlayback.next(sequence, 3, true);

            testCase.verifyTrue(middle.Available);
            testCase.verifyEqual(middle.Position, 2);
            testCase.verifyEqual(middle.ViewId, sequence.Frames(2).ViewId);
            testCase.verifyFalse(boundary.Available);
            testCase.verifyTrue(boundary.Boundary);
            testCase.verifyTrue(looped.Available);
            testCase.verifyEqual(looped.Position, 1);
        end
    end

    methods (Static, Access = private)
        function scene = makeScene()
            images = {uint8(ones(4)), uint8(2 * ones(4)), ...
                uint8(3 * ones(4))};
            scene = ProjectionViewerHarness.createSceneFromImages( ...
                images, ["one.tif" "two.tif" "three.tif"], ...
                struct(RowStride=2, ColumnStride=2));
        end
    end
end
