classdef ProjectionAlignmentSchedulerTest < matlab.unittest.TestCase
    %ProjectionAlignmentSchedulerTest Tests multi-image pair scheduling.

    methods (TestClassSetup)
        function addSourceToPath(testCase)
            projectRoot = fileparts(fileparts(mfilename("fullpath")));
            srcFolder = fullfile(projectRoot, "src");
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(srcFolder));
        end
    end

    methods (Test)
        function testDefaultCenterOutScheduleUsesMiddleReference(testCase)
            scene = ProjectionAlignmentSchedulerTest.makeScene(7);

            schedule = ProjectionAlignmentScheduler.build(scene, struct());

            testCase.verifyEqual(schedule.Format, ...
                ProjectionAlignmentScheduler.Format);
            testCase.verifyEqual(schedule.ReferenceLayerIndex, 4);
            testCase.verifyEqual(schedule.LayerIndices, 1:7);
            testCase.verifyEqual( ...
                ProjectionAlignmentSchedulerTest.pairMatrix(schedule), ...
                [3 4; 5 4; 2 3; 6 5; 1 2; 7 6]);
        end

        function testEvenLayerCenterStarUsesLowerMiddleReference(testCase)
            scene = ProjectionAlignmentSchedulerTest.makeScene(6);
            request = struct(Options=struct(Scheduling=struct( ...
                Strategy="centerStar")));

            schedule = ProjectionAlignmentScheduler.build(scene, request);

            testCase.verifyEqual(schedule.ReferenceLayerIndex, 3);
            testCase.verifyEqual( ...
                ProjectionAlignmentSchedulerTest.pairMatrix(schedule), ...
                [2 3; 4 3; 1 3; 5 3; 6 3]);
            testCase.verifyTrue(all([schedule.Pairs.IncludesReference]));
        end

        function testAdjacentChainAndHybridStrategies(testCase)
            scene = ProjectionAlignmentSchedulerTest.makeScene(5);

            adjacent = ProjectionAlignmentScheduler.build(scene, struct( ...
                Options=struct(Scheduling=struct(Strategy="adjacentChain"))));
            hybrid = ProjectionAlignmentScheduler.build(scene, struct( ...
                Options=struct(Scheduling=struct(Strategy="hybrid"))));

            testCase.verifyEqual( ...
                ProjectionAlignmentSchedulerTest.pairMatrix(adjacent), ...
                [1 2; 2 3; 3 4; 4 5]);
            testCase.verifyEqual( ...
                ProjectionAlignmentSchedulerTest.pairMatrix(hybrid), ...
                [2 3; 4 3; 1 2; 5 4; 1 3; 5 3]);
        end

        function testHiddenLayersAreExcludedByDefault(testCase)
            scene = ProjectionAlignmentSchedulerTest.makeScene(5);
            scene.layers(2).Visible = false;
            scene.layers(4).Visible = false;

            visibleSchedule = ProjectionAlignmentScheduler.build(scene, struct());
            allSchedule = ProjectionAlignmentScheduler.build(scene, struct( ...
                Options=struct(Scheduling=struct(PairSelection="all"))));
            includeHidden = ProjectionAlignmentScheduler.build(scene, struct( ...
                Options=struct(Scheduling=struct(IncludeHiddenLayers=true))));

            testCase.verifyEqual(visibleSchedule.LayerIndices, [1 3 5]);
            testCase.verifyEqual(visibleSchedule.ReferenceLayerIndex, 3);
            testCase.verifyEqual( ...
                ProjectionAlignmentSchedulerTest.pairMatrix(visibleSchedule), ...
                [1 3; 5 3]);
            testCase.verifyEqual(visibleSchedule.Diagnostics.ExcludedLayerIndices, ...
                [2 4]);
            testCase.verifyEqual(allSchedule.LayerIndices, 1:5);
            testCase.verifyEqual(includeHidden.LayerIndices, 1:5);
        end

        function testTwoImageScheduleRequiresExactlyTwoLayers(testCase)
            scene = ProjectionAlignmentSchedulerTest.makeScene(3);
            request = struct(Options=struct(Scheduling=struct( ...
                Strategy="twoImage")));

            testCase.verifyError( ...
                @() ProjectionAlignmentScheduler.build(scene, request), ...
                "ProjectionAlignmentScheduler:invalidTwoImageSchedule");
        end

        function testMatchScoringReportsPairConfidence(testCase)
            matchResult = struct(Matches=[ ...
                ProjectionAlignmentSchedulerTest.makePairMatch([1 2], 5, ...
                [20 20], true(2, 2)), ...
                ProjectionAlignmentSchedulerTest.makePairMatch([2 3], 20, ...
                [20 25], true(10, 10))]);

            diagnostics = ProjectionAlignmentScheduler.scoreMatches(matchResult);

            testCase.verifyEqual(diagnostics.TotalMatches, 25);
            testCase.verifyNumElements(diagnostics.PairDiagnostics, 2);
            testCase.verifyEqual(diagnostics.PairDiagnostics(1).Pair, [1 2]);
            testCase.verifyGreaterThan( ...
                diagnostics.PairDiagnostics(2).Confidence, ...
                diagnostics.PairDiagnostics(1).Confidence);
            testCase.verifyGreaterThanOrEqual(diagnostics.MeanConfidence, 0);
            testCase.verifyLessThanOrEqual(diagnostics.MeanConfidence, 1);
        end
    end

    methods (Static, Access = private)
        function scene = makeScene(layerCount)
            images = cell(1, layerCount);
            paths = strings(1, layerCount);
            for k = 1:layerCount
                images{k} = uint8(k * ones(4, 5));
                paths(k) = sprintf("layer%d.tif", k);
            end
            scene = ProjectionViewerHarness.createSceneFromImages( ...
                images, paths, struct(RowStride=1, ColumnStride=1));
        end

        function pairs = pairMatrix(schedule)
            pairs = reshape([schedule.Pairs.Pair], 2, []).';
        end

        function pairMatch = makePairMatch(pair, count, featureCounts, overlapMask)
            pairMatch = struct();
            pairMatch.Pair = pair;
            pairMatch.Count = count;
            pairMatch.FeatureCounts = featureCounts;
            pairMatch.OverlapMask = overlapMask;
        end
    end
end
