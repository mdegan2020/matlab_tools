classdef ProjectionLayerManagerTest < matlab.unittest.TestCase
    %ProjectionLayerManagerTest Tests for multi-layer workflow helpers.

    methods (TestClassSetup)
        function addSourceToPath(testCase)
            projectRoot = fileparts(fileparts(mfilename("fullpath")));
            srcFolder = fullfile(projectRoot, "src");
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(srcFolder));
        end
    end

    methods (Test)
        function testSetActiveLayerSetsOneLayerToFullAlpha(testCase)
            scene = ProjectionLayerManagerTest.makeTwoLayerScene();

            [scene, activeIndex] = ProjectionLayerManager.setActiveLayer(scene, 2);

            testCase.verifyEqual(activeIndex, 2);
            testCase.verifyEqual([scene.layers.Alpha], [0 1]);
            testCase.verifyEqual([scene.layers.Visible], [true true]);
        end

        function testCycleActiveLayerAdvancesChangeWorkflow(testCase)
            scene = ProjectionLayerManagerTest.makeTwoLayerScene();
            [scene, ~] = ProjectionLayerManager.setActiveLayer(scene, 1);

            [scene, activeIndex] = ProjectionLayerManager.cycleActiveLayer(scene);

            testCase.verifyEqual(activeIndex, 2);
            testCase.verifyEqual([scene.layers.Alpha], [0 1]);
        end

        function testSetLayerVisibilityAndAlpha(testCase)
            scene = ProjectionLayerManagerTest.makeTwoLayerScene();

            scene = ProjectionLayerManager.setLayerAlpha(scene, 1, 0.35);
            scene = ProjectionLayerManager.setLayerVisible(scene, 2, false);

            testCase.verifyEqual(scene.layers(1).Alpha, 0.35, AbsTol=1e-12);
            testCase.verifyFalse(scene.layers(2).Visible);
        end
    end

    methods (Static, Access = private)
        function scene = makeTwoLayerScene()
            imageData = ones(4, 5);
            scene = ProjectionViewerHarness.createSceneFromImage( ...
                imageData, "layer1.tif", ProjectionLayerManagerTest.makeOptions());
            secondLayer = scene.layers;
            secondLayer.Name = "Layer 2";
            secondLayer.Image = 2 * imageData;
            secondLayer.DisplayTexture = ProjectionViewerHarness.prepareDisplayTexture(secondLayer.Image);
            scene.layers = [scene.layers secondLayer];
        end

        function options = makeOptions()
            options = struct();
            options.RowStride = 1;
            options.ColumnStride = 1;
            options.PlatformDirection = [0; 0; 1];
        end
    end
end
