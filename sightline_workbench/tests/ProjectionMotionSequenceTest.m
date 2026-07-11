classdef ProjectionMotionSequenceTest < matlab.unittest.TestCase
    %ProjectionMotionSequenceTest Tests motion membership and ordering.

    methods (TestClassSetup)
        function addSourceToPath(testCase)
            projectRoot = fileparts(fileparts(mfilename("fullpath")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(projectRoot, "src")));
        end
    end

    methods (Test)
        function testAutomaticOrderGroupsPassesAndSortsComparableTimes(testCase)
            scene = ProjectionMotionSequenceTest.makeScene(4);
            scene = ProjectionMotionSequenceTest.setMetadata(scene, ...
                ["pass-a" "pass-b" "pass-a" "pass-b"], ...
                {20, datetime(2026, 1, 1, 0, 0, 2, TimeZone="UTC"), ...
                10, datetime(2026, 1, 1, 0, 0, 1, TimeZone="UTC")});

            sequence = ProjectionMotionSequence.build(scene);

            testCase.verifyTrue(sequence.Available);
            testCase.verifyEqual(sequence.LayerIndices, [3 1 4 2]);
            testCase.verifyEqual(sequence.OrderingMode, "timeWithinPass");
            testCase.verifyFalse(sequence.UsedStableFallback);
        end

        function testCallerOrderIsAuthoritative(testCase)
            scene = ProjectionMotionSequenceTest.makeScene(3);

            sequence = ProjectionMotionSequence.build(scene, ...
                struct(LayerIndices=[3 1 2]));

            testCase.verifyEqual(sequence.LayerIndices, [3 1 2]);
            testCase.verifyEqual(sequence.OrderingMode, "caller");
        end

        function testIncomparableClocksUseStableFallbackWithoutInterleave(testCase)
            scene = ProjectionMotionSequenceTest.makeScene(4);
            scene.layers(1).ViewId = "view-z";
            scene.layers(2).ViewId = "view-a";
            scene.layers(3).ViewId = "view-d";
            scene.layers(4).ViewId = "view-c";
            scene = ProjectionMotionSequenceTest.setMetadata(scene, ...
                ["pass-a" "pass-a" "pass-b" "pass-b"], ...
                {1, datetime(2026, 1, 1, TimeZone="UTC"), [], []});

            sequence = ProjectionMotionSequence.build(scene);

            testCase.verifyEqual(sequence.LayerIndices, [2 1 4 3]);
            testCase.verifyEqual(sequence.OrderingMode, "stableFallback");
            testCase.verifyTrue(sequence.UsedStableFallback);
            testCase.verifyNotEmpty(sequence.Warnings);
        end

        function testPassAndViewFiltersRequireTwoFrames(testCase)
            scene = ProjectionMotionSequenceTest.makeScene(4);
            scene = ProjectionMotionSequenceTest.setMetadata(scene, ...
                ["pass-a" "pass-a" "pass-b" "pass-b"], ...
                {1, 2, 1, 2});
            passOnly = ProjectionMotionSequence.build(scene, ...
                struct(PassIds="pass-b"));
            oneView = ProjectionMotionSequence.build(scene, ...
                struct(IncludedViewIds="view-1"));

            testCase.verifyEqual(passOnly.LayerIndices, [3 4]);
            testCase.verifyTrue(passOnly.Available);
            testCase.verifyFalse(oneView.Available);
            testCase.verifySubstring(oneView.Explanation, "at least two");
        end

        function testStepIsNoWrapByDefaultAndLoopsWhenRequested(testCase)
            scene = ProjectionMotionSequenceTest.makeScene(3);
            sequence = ProjectionMotionSequence.build(scene, ...
                struct(LayerIndices=[1 2 3]));

            [stopped, stoppedChanged, stoppedBoundary] = ...
                ProjectionMotionSequence.step(sequence, 3, 1, false);
            [looped, loopedChanged, loopedBoundary] = ...
                ProjectionMotionSequence.step(sequence, 3, 1, true);

            testCase.verifyEqual(stopped, 3);
            testCase.verifyFalse(stoppedChanged);
            testCase.verifyTrue(stoppedBoundary);
            testCase.verifyEqual(looped, 1);
            testCase.verifyTrue(loopedChanged);
            testCase.verifyTrue(loopedBoundary);
        end
    end

    methods (Static, Access = private)
        function scene = makeScene(count)
            images = cell(1, count);
            paths = strings(1, count);
            for index = 1:count
                images{index} = uint8(index * ones(8, 9));
                paths(index) = "motion-" + string(index) + ".tif";
            end
            scene = ProjectionViewerHarness.createSceneFromImages( ...
                images, paths, struct(RowStride=2, ColumnStride=2));
            for index = 1:count
                scene.layers(index).ViewId = "view-" + string(index);
            end
        end

        function scene = setMetadata(scene, passes, times)
            for index = 1:numel(scene.layers)
                scene.layers(index).PassId = passes(index);
                scene.layers(index).AcquisitionStartTime = times{index};
            end
            scene = ProjectionViewMetadata.ensureScene(scene);
        end
    end
end
