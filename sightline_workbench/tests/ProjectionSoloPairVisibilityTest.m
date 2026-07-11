classdef ProjectionSoloPairVisibilityTest < matlab.unittest.TestCase
    %ProjectionSoloPairVisibilityTest Tests runtime solo-pair state.

    methods (TestClassSetup)
        function addSourceToPath(testCase)
            projectRoot = fileparts(fileparts(mfilename("fullpath")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(projectRoot, "src")));
        end
    end

    methods (Test)
        function testSoloShowsOnlySelectedPairWithoutChangingScene(testCase)
            scene = ProjectionSoloPairVisibilityTest.makeScene(3);
            scene.layers(1).Visible = false;
            before = [scene.layers.Visible];

            state = ProjectionSoloPairVisibility.activate( ...
                scene, "view-a", "view-c");

            testCase.verifyEqual( ...
                ProjectionSoloPairVisibility.effectiveMask(state, scene), ...
                [true false true]);
            testCase.verifyEqual([scene.layers.Visible], before);
        end

        function testFollowChangesPairAndPreservesSnapshot(testCase)
            scene = ProjectionSoloPairVisibilityTest.makeScene(3);
            scene.layers(2).Visible = false;
            state = ProjectionSoloPairVisibility.activate( ...
                scene, "view-a", "view-b");

            state = ProjectionSoloPairVisibility.follow( ...
                state, scene, "view-b", "view-c");

            testCase.verifyEqual( ...
                ProjectionSoloPairVisibility.effectiveMask(state, scene), ...
                [false true true]);
            testCase.verifyEqual(state.SnapshotVisible, [true false true]);
        end

        function testRestoreSurvivingViewsAndLeaveAddedViewAlone(testCase)
            scene = ProjectionSoloPairVisibilityTest.makeScene(3);
            scene.layers(2).Visible = false;
            state = ProjectionSoloPairVisibility.activate( ...
                scene, "view-a", "view-b");
            changed = scene;
            changed.layers = changed.layers([3 1]);
            added = ProjectionSoloPairVisibilityTest.makeScene(1).layers;
            added.ViewId = "view-added";
            added.LayerId = "layer-added";
            added.Visible = false;
            changed.layers(end + 1) = added;
            changed.layers(1).Visible = false;
            changed.layers(2).Visible = false;

            restored = ProjectionSoloPairVisibility.restore(changed, state);

            testCase.verifyEqual(ProjectionViewMetadata.ids(restored), ...
                ["view-c" "view-a" "view-added"]);
            testCase.verifyEqual([restored.layers.Visible], ...
                [true true false]);
        end

        function testSameAndUnknownViewsAreRejected(testCase)
            scene = ProjectionSoloPairVisibilityTest.makeScene(2);

            testCase.verifyError(@() ProjectionSoloPairVisibility.activate( ...
                scene, "view-a", "view-a"), ...
                "ProjectionViewMetadata:duplicatePairView");
            testCase.verifyError(@() ProjectionSoloPairVisibility.activate( ...
                scene, "view-a", "missing"), ...
                "ProjectionSoloPairVisibility:unknownView");
        end
    end

    methods (Static, Access = private)
        function scene = makeScene(layerCount)
            images = cell(1, layerCount);
            paths = strings(1, layerCount);
            for layerIndex = 1:layerCount
                images{layerIndex} = uint8(layerIndex * ones(4, 5));
                paths(layerIndex) = "solo-view-" + string(layerIndex) + ".tif";
            end
            scene = ProjectionViewerHarness.createSceneFromImages( ...
                images, paths, struct(RowStride=1, ColumnStride=1));
            for layerIndex = 1:layerCount
                scene.layers(layerIndex).ViewId = ...
                    "view-" + string(char('a' + layerIndex - 1));
            end
            scene = ProjectionViewMetadata.ensureScene(scene);
        end
    end
end
