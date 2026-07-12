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
        function testDefaultQualityGraphBuildsForestAndLoopChords(testCase)
            scene = ProjectionAlignmentSchedulerTest.makeScene(7);

            schedule = ProjectionAlignmentScheduler.build(scene, struct());

            testCase.verifyEqual(schedule.Format, ...
                ProjectionAlignmentScheduler.Format);
            testCase.verifyEqual(schedule.Strategy, "qualityGraph");
            testCase.verifyEqual(schedule.ReferenceLayerIndex, 4);
            testCase.verifyEqual(schedule.LayerIndices, 1:7);
            testCase.verifyEqual(schedule.PairCount, 9);
            testCase.verifyNumElements( ...
                schedule.Diagnostics.PairGraph.TreePairIds, 6);
            testCase.verifyNumElements( ...
                schedule.Diagnostics.PairGraph.ChordPairIds, 3);
            testCase.verifyNumElements( ...
                schedule.Diagnostics.PairGraph.CycleBasis, 3);
            testCase.verifyEqual( ...
                schedule.Diagnostics.PairGraph.SelectedComponentCount, 1);
            testCase.verifyTrue(all([schedule.Pairs.QualityScore] >= 0));
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
            testCase.verifyEqual(sortrows(sort( ...
                ProjectionAlignmentSchedulerTest.pairMatrix(visibleSchedule), ...
                2)), [1 3; 3 5]);
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

        function testQualitySpeedAndAllPlausibleControlsPairCount(testCase)
            scene = ProjectionAlignmentSchedulerTest.makeScene(5);
            fast = ProjectionAlignmentScheduler.build(scene, struct( ...
                Options=struct(Scheduling=struct(QualitySpeed="fast"))));
            quality = ProjectionAlignmentScheduler.build(scene, struct( ...
                Options=struct(Scheduling=struct(QualitySpeed="quality"))));
            allPairs = ProjectionAlignmentScheduler.build(scene, struct( ...
                Options=struct(Scheduling=struct(AllPlausiblePairs=true))));

            testCase.verifyEqual(fast.PairCount, 4);
            testCase.verifyGreaterThan(quality.PairCount, fast.PairCount);
            testCase.verifyEqual(allPairs.PairCount, ...
                nnz([allPairs.Graph.Candidates.Plausible]));
            testCase.verifyEqual( ...
                allPairs.Diagnostics.PairGraph.PredictedCost.Selected, ...
                allPairs.Diagnostics.PairGraph.PredictedCost.AllPlausible, ...
                AbsTol=1e-12);
        end

        function testHardMaxReportsInfeasibleConnectivity(testCase)
            scene = ProjectionAlignmentSchedulerTest.makeScene(6);
            schedule = ProjectionAlignmentScheduler.build(scene, struct( ...
                Options=struct(Scheduling=struct(MaxPairs=3, ...
                QualitySpeed="quality"))));

            testCase.verifyEqual(schedule.PairCount, 3);
            testCase.verifyTrue( ...
                schedule.Diagnostics.PairGraph.BudgetLimited);
            testCase.verifyTrue( ...
                schedule.Diagnostics.PairGraph.InfeasibleConnectivity);
            testCase.verifyGreaterThan( ...
                schedule.Diagnostics.PairGraph.SelectedComponentCount, 1);
        end

        function testForcedIncludeExcludeArePreservedAndExplained(testCase)
            scene = ProjectionAlignmentSchedulerTest.makeScene(5);
            baseline = ProjectionAlignmentScheduler.build(scene, struct( ...
                Options=struct(Scheduling=struct(QualitySpeed="fast"))));
            candidates = baseline.Graph.Candidates;
            forcedInclude = candidates(end).PairId;
            forcedExclude = candidates(1).PairId;
            request = struct(Options=struct(Scheduling=struct( ...
                QualitySpeed="fast", ForcedIncludePairIds=forcedInclude, ...
                ForcedExcludePairIds=forcedExclude)));

            schedule = ProjectionAlignmentScheduler.build(scene, request);

            selectedIds = string({schedule.Pairs.PairId});
            testCase.verifyTrue(ismember(forcedInclude, selectedIds));
            testCase.verifyFalse(ismember(forcedExclude, selectedIds));
            excluded = schedule.Graph.Candidates( ...
                string({schedule.Graph.Candidates.PairId}) == forcedExclude);
            testCase.verifyEqual(excluded.RejectionReason, ...
                "excludedByOperator");
            included = schedule.Graph.Candidates( ...
                string({schedule.Graph.Candidates.PairId}) == forcedInclude);
            testCase.verifyTrue(included.Forced);
            testCase.verifyEqual(included.State, "selected");
        end

        function testQualityGraphIsDeterministic(testCase)
            scene = ProjectionAlignmentSchedulerTest.makeScene(6);

            first = ProjectionAlignmentScheduler.build(scene, struct());
            second = ProjectionAlignmentScheduler.build(scene, struct());

            testCase.verifyEqual(second.Graph.GenerationId, ...
                first.Graph.GenerationId);
            testCase.verifyEqual(string({second.Pairs.PairId}), ...
                string({first.Pairs.PairId}));
            testCase.verifyEqual(string({second.Pairs.GraphRole}), ...
                string({first.Pairs.GraphRole}));
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
