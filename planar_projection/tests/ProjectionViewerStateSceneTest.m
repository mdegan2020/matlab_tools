classdef ProjectionViewerStateSceneTest < matlab.unittest.TestCase
    %ProjectionViewerStateSceneTest Tests for headless state-to-scene application.

    properties (Constant)
        Tol = 1e-10
    end

    methods (TestClassSetup)
        function addSourceToPath(testCase)
            projectRoot = fileparts(fileparts(mfilename("fullpath")));
            srcFolder = fullfile(projectRoot, "src");
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(srcFolder));
        end
    end

    methods (TestMethodSetup)
        function closeExistingViewer(testCase)
            delete(findall(groot, "Type", "figure", ...
                "Name", "Projection Viewer Prototype"));
            testCase.addTeardown(@() delete(findall(groot, "Type", "figure", ...
                "Name", "Projection Viewer Prototype")));
        end
    end

    methods (Test)
        function testApplyToSceneAcceptsAppExportedState(testCase)
            scene = ProjectionViewerStateSceneTest.makeTwoImageScene();
            state = ProjectionViewerStateSceneTest.makeViewerState(scene);
            app = ProjectionViewerApp(scene, [], state);
            testCase.addTeardown(@() delete(app));
            drawnow
            exportedState = app.exportState();

            [appliedScene, appliedState] = ProjectionViewerState.applyToScene( ...
                scene, exportedState);

            testCase.verifyEqual(appliedState, exportedState);
            ProjectionViewerStateSceneTest.verifySceneMatchesState( ...
                testCase, appliedScene, exportedState);
        end

        function testApplyToSceneUpdatesLayerStateAndCurrentPlane(testCase)
            scene = ProjectionViewerStateSceneTest.makeTwoImageScene();
            state = ProjectionViewerStateSceneTest.makeViewerState(scene);

            appliedScene = ProjectionViewerState.applyToScene(scene, state);
            expectedPlane = ProjectionMeshBuilder.applyPlaneTipTilt( ...
                scene.layers(1).BaseProjectionPlane, ...
                deg2rad(state.Projection.TipDegrees), ...
                deg2rad(state.Projection.TiltDegrees));

            testCase.verifyEqual(appliedScene.layers(1).CurrentProjectionPlane, ...
                expectedPlane, AbsTol=ProjectionViewerStateSceneTest.Tol);
            testCase.verifyEqual(appliedScene.layers(2).CurrentProjectionPlane, ...
                expectedPlane, AbsTol=ProjectionViewerStateSceneTest.Tol);
            testCase.verifyEqual(appliedScene.layers(1).Alpha, 0.35, ...
                AbsTol=ProjectionViewerStateSceneTest.Tol);
            testCase.verifyFalse(appliedScene.layers(1).Visible);
            testCase.verifyEqual(appliedScene.layers(1).BlendMode, "redBlueAnaglyph");
            testCase.verifyEqual(appliedScene.layers(2).ProjectionOffsetMeters, ...
                [-0.75; 1.25], AbsTol=ProjectionViewerStateSceneTest.Tol);
            testCase.verifyEqual( ...
                appliedScene.layers(2).ViewVectorAngularOffsetsDegrees, ...
                [-0.04; 0.05; -0.06], AbsTol=ProjectionViewerStateSceneTest.Tol);
        end

        function testApplyToSceneRejectsLayerCountMismatch(testCase)
            scene = ProjectionViewerStateSceneTest.makeTwoImageScene();
            state = ProjectionViewerStateSceneTest.makeViewerState(scene);
            state.Layers = state.Layers(1);

            testCase.verifyError( ...
                @() ProjectionViewerState.applyToScene(scene, state), ...
                "ProjectionViewerState:layerCountMismatch");
        end

        function testApplyToSceneRejectsLayerOrderMismatch(testCase)
            scene = ProjectionViewerStateSceneTest.makeTwoImageScene();
            state = ProjectionViewerStateSceneTest.makeViewerState(scene);
            state.Layers(1).Name = state.Layers(2).Name;

            testCase.verifyError( ...
                @() ProjectionViewerState.applyToScene(scene, state), ...
                "ProjectionViewerState:layerOrderMismatch");
        end

        function testApplyToSceneRejectsImagePathMismatch(testCase)
            scene = ProjectionViewerStateSceneTest.makeTwoImageScene();
            state = ProjectionViewerStateSceneTest.makeViewerState(scene);
            state.Layers(2).ImagePath = "different_layer.tif";

            testCase.verifyError( ...
                @() ProjectionViewerState.applyToScene(scene, state), ...
                "ProjectionViewerState:imagePathMismatch");
        end

        function testBackendProcessorAppliesViewerState(testCase)
            scene = ProjectionViewerStateSceneTest.makeTwoImageScene();
            state = ProjectionViewerStateSceneTest.makeViewerState(scene);
            job = struct(Scene=scene, ViewerState=state);

            result = ProjectionBackendProcessor.run(job);
            expectedPlane = ProjectionMeshBuilder.applyPlaneTipTilt( ...
                scene.layers(1).BaseProjectionPlane, ...
                deg2rad(state.Projection.TipDegrees), ...
                deg2rad(state.Projection.TiltDegrees));

            testCase.verifyEqual(result.Status, "stateApplied");
            testCase.verifyEqual(result.Scene.layers(2).CurrentProjectionPlane, ...
                expectedPlane, AbsTol=ProjectionViewerStateSceneTest.Tol);
            testCase.verifyEqual(result.Scene.layers(2).Alpha, 0.45, ...
                AbsTol=ProjectionViewerStateSceneTest.Tol);
            testCase.verifyEqual(result.Job.Scene, result.Scene);
            testCase.verifyEqual(result.ViewerState.View.TwistDegrees, ...
                state.View.TwistDegrees, AbsTol=ProjectionViewerStateSceneTest.Tol);
        end
    end

    methods (Static, Access = private)
        function scene = makeTwoImageScene()
            imageData1 = uint8(reshape(1:60, 4, 5, 3));
            imageData2 = uint8(reshape(1:72, 6, 4, 3));
            options = struct(RowStride=2, ColumnStride=2);
            scene = ProjectionViewerHarness.createSceneFromImages( ...
                {imageData1, imageData2}, ["layer1.tif", "layer2.tif"], ...
                options);
        end

        function state = makeViewerState(scene)
            state = struct();
            state.Format = ProjectionViewerState.Format;
            state.Version = ProjectionViewerState.Version;
            state.LayerCount = numel(scene.layers);
            state.SelectedLayerIndex = 2;
            state.Projection = struct(TipDegrees=5.5, TiltDegrees=-4.25);
            state.View = struct(TwistDegrees=3.75);
            state.Layers = [ ...
                ProjectionViewerStateSceneTest.makeViewerLayerState( ...
                scene.layers(1), 1, 0.35, false, "redBlueAnaglyph", ...
                [0.5 -0.25], [0.01 0.02 0.03]), ...
                ProjectionViewerStateSceneTest.makeViewerLayerState( ...
                scene.layers(2), 2, 0.45, true, "alpha", ...
                [-0.75 1.25], [-0.04 0.05 -0.06])];
        end

        function layerState = makeViewerLayerState(layer, index, alpha, visible, ...
                blendMode, projectionOffsetMeters, viewVectorAngularOffsetsDegrees)
            layerState = struct();
            layerState.Index = index;
            layerState.Name = layer.Name;
            layerState.ImagePath = layer.ImagePath;
            layerState.Alpha = alpha;
            layerState.Visible = visible;
            layerState.BlendMode = blendMode;
            layerState.ProjectionOffsetMeters = projectionOffsetMeters;
            layerState.ViewVectorAngularOffsetsDegrees = ...
                viewVectorAngularOffsetsDegrees;
        end

        function verifySceneMatchesState(testCase, scene, state)
            testCase.verifyNumElements(scene.layers, numel(state.Layers));
            for layerIndex = 1:numel(state.Layers)
                ProjectionViewerStateSceneTest.verifyLayerMatchesState( ...
                    testCase, scene.layers(layerIndex), state.Layers(layerIndex));
            end
        end

        function verifyLayerMatchesState(testCase, layer, layerState)
            testCase.verifyEqual(layer.Alpha, layerState.Alpha, ...
                AbsTol=ProjectionViewerStateSceneTest.Tol);
            testCase.verifyEqual(layer.Visible, layerState.Visible);
            testCase.verifyEqual(layer.BlendMode, layerState.BlendMode);
            testCase.verifyEqual(layer.ProjectionOffsetMeters, ...
                layerState.ProjectionOffsetMeters(:), ...
                AbsTol=ProjectionViewerStateSceneTest.Tol);
            testCase.verifyEqual(layer.ViewVectorAngularOffsetsDegrees, ...
                layerState.ViewVectorAngularOffsetsDegrees(:), ...
                AbsTol=ProjectionViewerStateSceneTest.Tol);
        end
    end
end
