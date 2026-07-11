classdef ProjectionLayerIdentityTest < matlab.unittest.TestCase
    %ProjectionLayerIdentityTest Tests stable scene-layer identity contracts.

    methods (TestClassSetup)
        function addSourceToPath(testCase)
            projectRoot = fileparts(fileparts(mfilename("fullpath")));
            srcFolder = fullfile(projectRoot, "src");
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(srcFolder));
        end
    end

    methods (Test)
        function testHarnessAssignsDistinctIdsForDuplicatePaths(testCase)
            scene = ProjectionLayerIdentityTest.makeDuplicatePathScene();

            layerIds = ProjectionLayerIdentity.ids(scene);

            testCase.verifySize(layerIds, [1 2]);
            testCase.verifyNotEqual(layerIds(1), layerIds(2));
            testCase.verifyEqual(layerIds, ["layer-000001", "layer-000002"]);
        end

        function testIdsRemainAttachedAcrossLayerReorder(testCase)
            scene = ProjectionLayerIdentityTest.makeDuplicatePathScene();
            originalIds = ProjectionLayerIdentity.ids(scene);
            reorderedScene = scene;
            reorderedScene.layers = reorderedScene.layers([2 1]);

            reorderedIds = ProjectionLayerIdentity.ids(reorderedScene);
            originalFirstIndex = ProjectionLayerIdentity.indexForId( ...
                reorderedScene, originalIds(1));

            testCase.verifyEqual(reorderedIds, originalIds([2 1]));
            testCase.verifyEqual(originalFirstIndex, 2);
        end

        function testEnsureLayersPreservesExistingAndMigratesMissingIds(testCase)
            layers = struct( ...
                "LayerId", {"sensor-a", ""}, ...
                "Name", {"duplicate", "duplicate"});

            migrated = ProjectionLayerIdentity.ensureLayers(layers);

            testCase.verifyEqual(string(migrated(1).LayerId), "sensor-a");
            testCase.verifyEqual(string(migrated(2).LayerId), "layer-000001");
        end

        function testDuplicateLayerIdsError(testCase)
            layers = struct( ...
                "LayerId", {"same-id", "same-id"}, ...
                "Name", {"one", "two"});

            testCase.verifyError( ...
                @() ProjectionLayerIdentity.ensureLayers(layers), ...
                "ProjectionLayerIdentity:duplicateId");
        end

        function testAlignmentRequestCarriesSceneLayerIds(testCase)
            scene = ProjectionLayerIdentityTest.makeDuplicatePathScene();

            request = ProjectionAlignmentRequest.validate(struct( ...
                Scene=scene, LayerIndices=[2 1], ReferenceLayerIndex=1));

            testCase.verifyEqual(request.LayerIds, ...
                [scene.layers(2).LayerId, scene.layers(1).LayerId]);
            testCase.verifyEqual(request.ReferenceLayerId, scene.layers(1).LayerId);
        end
    end

    methods (Static, Access = private)
        function scene = makeDuplicatePathScene()
            imageData = uint8(reshape(1:100, 10, 10));
            scene = ProjectionViewerHarness.createSceneFromImages( ...
                {imageData, imageData}, ["same.tif", "same.tif"], ...
                struct(RowStride=2, ColumnStride=2));
        end
    end
end
