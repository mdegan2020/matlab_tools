classdef ProjectionPairControllerTest < matlab.unittest.TestCase
    %ProjectionPairControllerTest Tests runtime pair scheduling and navigation.

    methods (TestClassSetup)
        function addSourceToPath(testCase)
            projectRoot = fileparts(fileparts(mfilename("fullpath")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(projectRoot, "src")));
        end
    end

    methods (Test)
        function testDefaultScheduleUsesRequiredCategoryOrder(testCase)
            scene = ProjectionPairControllerTest.makeTimedScene();

            controller = ProjectionPairController(scene);
            pairs = controller.Schedule.Pairs;

            testCase.verifyEqual(string({pairs.Category}), [ ...
                "samePassTemporalNeighbor", "samePassTemporalNeighbor", ...
                "samePassChord", "crossPass", "crossPass", "crossPass"]);
            testCase.verifyEqual( ...
                ProjectionPairControllerTest.directedViewPairs(pairs), [ ...
                "view-a" "view-b"; "view-b" "view-c"; ...
                "view-a" "view-c"; "view-a" "view-d"; ...
                "view-b" "view-d"; "view-c" "view-d"]);
        end

        function testSchedulePairIdentitySurvivesLayerReorder(testCase)
            scene = ProjectionPairControllerTest.makeTimedScene();
            original = ProjectionPairController(scene);
            reorderedScene = scene;
            reorderedScene.layers = reorderedScene.layers([4 2 1 3]);

            reordered = ProjectionPairController(reorderedScene);

            testCase.verifyEqual(string({reordered.Schedule.Pairs.PairId}), ...
                string({original.Schedule.Pairs.PairId}));
            testCase.verifyNotEqual( ...
                [reordered.Schedule.Pairs.ReferenceLayerIndex], ...
                [original.Schedule.Pairs.ReferenceLayerIndex]);
        end

        function testRoleSwapPreservesUnorderedIdentity(testCase)
            controller = ProjectionPairController( ...
                ProjectionPairControllerTest.makeTimedScene());
            before = controller.currentPair();

            after = controller.swapRoles();

            testCase.verifyEqual(after.PairId, before.PairId);
            testCase.verifyEqual(after.ReferenceViewId, before.MovingViewId);
            testCase.verifyEqual(after.MovingViewId, before.ReferenceViewId);
        end

        function testDisabledPairsAreSkippedUnlessReviewIncludesThem(testCase)
            controller = ProjectionPairController( ...
                ProjectionPairControllerTest.makeTimedScene());
            secondPairId = controller.Schedule.Pairs(2).PairId;
            controller.setPairEnabled(secondPairId, false);

            [normalPair, normalChanged] = controller.stepNext();
            controller.selectPair(controller.Schedule.Pairs(1).PairId);
            controller.setReviewDisabled(true);
            [reviewPair, reviewChanged] = controller.stepNext();

            testCase.verifyTrue(normalChanged);
            testCase.verifyEqual(normalPair.PairId, ...
                controller.Schedule.Pairs(3).PairId);
            testCase.verifyTrue(reviewChanged);
            testCase.verifyEqual(reviewPair.PairId, secondPairId);
        end

        function testSteppingStopsAtScheduleEnds(testCase)
            controller = ProjectionPairController( ...
                ProjectionPairControllerTest.makeTimedScene());
            firstPairId = controller.currentPair().PairId;
            [previousPair, previousChanged] = controller.stepPrevious();
            controller.selectPair(controller.Schedule.Pairs(end).PairId);
            [nextPair, nextChanged] = controller.stepNext();

            testCase.verifyFalse(previousChanged);
            testCase.verifyEqual(previousPair.PairId, firstPairId);
            testCase.verifyFalse(nextChanged);
            testCase.verifyEqual(nextPair.PairId, ...
                controller.Schedule.Pairs(end).PairId);
        end

        function testDirectViewSelectionRejectsSameView(testCase)
            controller = ProjectionPairController( ...
                ProjectionPairControllerTest.makeTimedScene());

            selected = controller.selectViews("view-c", "view-a");

            testCase.verifyEqual(selected.ReferenceViewId, "view-c");
            testCase.verifyEqual(selected.MovingViewId, "view-a");
            testCase.verifyError( ...
                @() controller.selectViews("view-a", "view-a"), ...
                "ProjectionViewMetadata:duplicatePairView");
        end

        function testScheduleChangesOnlyOnExplicitRegeneration(testCase)
            scene = ProjectionPairControllerTest.makeTimedScene();
            controller = ProjectionPairController(scene);
            originalPairIds = string({controller.Schedule.Pairs.PairId});
            originalGeneration = controller.Generation;
            addedScene = ProjectionPairControllerTest.addView(scene);

            controller.synchronizeScene(addedScene);
            synchronizedPairIds = string({controller.Schedule.Pairs.PairId});
            controller.regenerate(addedScene);

            testCase.verifyEqual(synchronizedPairIds, originalPairIds);
            testCase.verifyEqual(controller.Generation, originalGeneration + 1);
            testCase.verifyGreaterThan(numel(controller.Schedule.Pairs), ...
                numel(originalPairIds));
        end

        function testMissingTimingFallsBackToStableViewIdOrder(testCase)
            scene = ProjectionPairControllerTest.makeUntimedScene();
            reorderedScene = scene;
            reorderedScene.layers = reorderedScene.layers([3 1 2]);

            original = ProjectionPairController(scene);
            reordered = ProjectionPairController(reorderedScene);

            testCase.verifyEqual( ...
                ProjectionPairControllerTest.directedViewPairs( ...
                original.Schedule.Pairs), ...
                ["view-a" "view-b"; "view-b" "view-c"; ...
                "view-a" "view-c"]);
            testCase.verifyEqual(string({reordered.Schedule.Pairs.PairId}), ...
                string({original.Schedule.Pairs.PairId}));
            testCase.verifyEqual(original.Schedule.TimingFallbackPassIds, ...
                "pass-one");
        end

        function testEnabledAndStatusFieldsAreRuntimeState(testCase)
            controller = ProjectionPairController( ...
                ProjectionPairControllerTest.makeTimedScene());
            pairId = controller.currentPair().PairId;

            controller.setPairEnabled(pairId, false);
            controller.setPairStatus(pairId, "needsReview");
            pair = controller.currentPair();
            diagnostics = controller.diagnostics();

            testCase.verifyFalse(pair.Enabled);
            testCase.verifyEqual(pair.Status, "needsReview");
            testCase.verifyEqual(diagnostics.Format, ...
                ProjectionPairController.Format);
            testCase.verifyEqual(diagnostics.PairCount, 6);
        end
    end

    methods (Static, Access = private)
        function scene = makeTimedScene()
            scene = ProjectionPairControllerTest.makeScene(4);
            viewIds = ["view-c" "view-a" "view-d" "view-b"];
            passIds = ["pass-one" "pass-one" "pass-two" "pass-one"];
            startTimes = [2 0 0 1];
            for layerIndex = 1:4
                scene.layers(layerIndex).ViewId = viewIds(layerIndex);
                scene.layers(layerIndex).PassId = passIds(layerIndex);
                scene.layers(layerIndex).AcquisitionStartTime = ...
                    startTimes(layerIndex);
                scene.layers(layerIndex).LineRateHz = 1;
            end
            scene = ProjectionViewMetadata.ensureScene(scene);
        end

        function scene = makeUntimedScene()
            scene = ProjectionPairControllerTest.makeScene(3);
            viewIds = ["view-c" "view-a" "view-b"];
            for layerIndex = 1:3
                scene.layers(layerIndex).ViewId = viewIds(layerIndex);
                scene.layers(layerIndex).PassId = "pass-one";
                scene.layers(layerIndex).AcquisitionStartTime = [];
                scene.layers(layerIndex).LineRateHz = [];
            end
            scene = ProjectionViewMetadata.ensureScene(scene);
        end

        function scene = addView(scene)
            added = ProjectionPairControllerTest.makeScene(1).layers;
            added.ViewId = "view-e";
            added.PassId = "pass-two";
            added.AcquisitionStartTime = 1;
            added.LineRateHz = 1;
            added.LayerId = "added-layer";
            scene.layers(end + 1) = added;
            scene = ProjectionViewMetadata.ensureScene(scene);
        end

        function scene = makeScene(layerCount)
            images = cell(1, layerCount);
            paths = strings(1, layerCount);
            for layerIndex = 1:layerCount
                images{layerIndex} = uint8(layerIndex * ones(4, 5));
                paths(layerIndex) = "pair-view-" + string(layerIndex) + ".tif";
            end
            scene = ProjectionViewerHarness.createSceneFromImages( ...
                images, paths, struct(RowStride=1, ColumnStride=1));
        end

        function pairs = directedViewPairs(pairRecords)
            pairs = [string({pairRecords.ReferenceViewId}).', ...
                string({pairRecords.MovingViewId}).'];
        end
    end
end
