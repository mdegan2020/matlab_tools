classdef ProjectionAlignmentLayerResolverTest < matlab.unittest.TestCase
    %ProjectionAlignmentLayerResolverTest Stable identity through layer reorder.

    methods (TestClassSetup)
        function addSourceToPath(testCase)
            projectRoot = fileparts(fileparts(mfilename("fullpath")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(projectRoot, "src")));
        end
    end

    methods (Test)
        function testPairIndicesFollowStableIdsAcrossReorder(testCase)
            priorScene = ProjectionAlignmentLayerResolverTest.makeScene();
            currentScene = priorScene;
            currentScene.layers = currentScene.layers([2 1]);
            pairMatch = struct(Pair=[2 1], ...
                PairLayerIds=["moving-id", "reference-id"]);

            indices = ProjectionAlignmentLayerResolver.pairIndices( ...
                currentScene, pairMatch, priorScene);

            testCase.verifyEqual(indices, [1 2]);
        end

        function testReindexRefreshesNestedPairsAndCorrections(testCase)
            priorScene = ProjectionAlignmentLayerResolverTest.makeScene();
            currentScene = priorScene;
            currentScene.layers = currentScene.layers([2 1]);
            pairMatch = struct(Pair=[2 1], ...
                PairLayerIds=["moving-id", "reference-id"], ...
                PairKey="2 -> 1");
            correction = struct(LayerIndex=2, LayerId="moving-id");
            value = struct(Scene=priorScene, LayerIndices=[2 1], ...
                LayerIds=["moving-id", "reference-id"], ...
                ReferenceLayerIndex=1, ReferenceLayerId="reference-id", ...
                Matches=pairMatch, SolvedCorrections=correction);

            reindexed = ProjectionAlignmentLayerResolver.reindex( ...
                currentScene, value, priorScene);

            testCase.verifyEqual(reindexed.LayerIndices, [1 2]);
            testCase.verifyEqual(reindexed.ReferenceLayerIndex, 2);
            testCase.verifyEqual(reindexed.Matches.Pair, [1 2]);
            testCase.verifyEqual(reindexed.Matches.PairKey, "1 -> 2");
            testCase.verifyEqual(reindexed.SolvedCorrections.LayerIndex, 1);
            testCase.verifyEqual(ProjectionLayerIdentity.ids(reindexed.Scene), ...
                ["moving-id", "reference-id"]);
        end

        function testLegacyPairUsesPriorSceneIdentity(testCase)
            priorScene = ProjectionAlignmentLayerResolverTest.makeScene();
            currentScene = priorScene;
            currentScene.layers = currentScene.layers([2 1]);

            reindexed = ProjectionAlignmentLayerResolver.reindex( ...
                currentScene, struct(Pair=[2 1]), priorScene);

            testCase.verifyEqual(reindexed.Pair, [1 2]);
        end
    end

    methods (Static, Access = private)
        function scene = makeScene()
            layers = struct("LayerId", {"reference-id", "moving-id"}, ...
                "Name", {"reference", "moving"});
            scene = struct(layers=layers, renderOrigin=zeros(3, 1));
        end
    end
end
