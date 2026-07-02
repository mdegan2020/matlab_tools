classdef ProjectionViewerAppInteractionTest < matlab.unittest.TestCase
    %ProjectionViewerAppInteractionTest Tests for programmatic viewer callbacks.

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
        function testImageAxesDecorationsAreHidden(testCase)
            scene = ProjectionViewerAppInteractionTest.makeScene();
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow

            fig = findall(groot, "Type", "figure", ...
                "Name", "Projection Viewer Prototype");
            ax = findall(fig, "Type", "axes");

            testCase.verifyEqual(string(ax.Title.String), "");
            testCase.verifyEqual(string(ax.XLabel.String), "");
            testCase.verifyEqual(string(ax.YLabel.String), "");
            testCase.verifyEqual(string(ax.ZLabel.String), "");
            testCase.verifyEmpty(ax.XTick);
            testCase.verifyEmpty(ax.YTick);
            testCase.verifyEmpty(ax.ZTick);
            testCase.verifyEqual(string(ax.Box), "off");
            testCase.verifyEqual(string(ax.Visible), "off");
        end

        function testCommandButtonsUseCompactGrid(testCase)
            scene = ProjectionViewerAppInteractionTest.makeScene();
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow

            fig = findall(groot, "Type", "figure", ...
                "Name", "Projection Viewer Prototype");
            saveButton = ProjectionViewerAppInteractionTest.findButton(fig, "Save");
            loadButton = ProjectionViewerAppInteractionTest.findButton(fig, "Load");
            cycleButton = ProjectionViewerAppInteractionTest.findButton(fig, "Cycle");
            resetButton = ProjectionViewerAppInteractionTest.findButton(fig, "Reset");

            testCase.verifyEqual(saveButton.Parent, loadButton.Parent);
            testCase.verifyEqual(saveButton.Parent, cycleButton.Parent);
            testCase.verifyEqual(saveButton.Parent, resetButton.Parent);
            testCase.verifyEqual( ...
                ProjectionViewerAppInteractionTest.layoutPosition(saveButton), [1 1]);
            testCase.verifyEqual( ...
                ProjectionViewerAppInteractionTest.layoutPosition(loadButton), [1 2]);
            testCase.verifyEqual( ...
                ProjectionViewerAppInteractionTest.layoutPosition(cycleButton), [2 1]);
            testCase.verifyEqual( ...
                ProjectionViewerAppInteractionTest.layoutPosition(resetButton), [2 2]);
        end

        function testLayerStyleControlsAreStacked(testCase)
            scene = ProjectionViewerAppInteractionTest.makeScene();
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow

            fig = findall(groot, "Type", "figure", ...
                "Name", "Projection Viewer Prototype");
            visibleCheckBox = findall(fig, "-isa", "matlab.ui.control.CheckBox");
            blendDropDown = ProjectionViewerAppInteractionTest.findBlendDropDown(fig);

            testCase.verifyEqual(visibleCheckBox.Parent, blendDropDown.Parent);
            testCase.verifyEqual( ...
                ProjectionViewerAppInteractionTest.layoutPosition(visibleCheckBox), [1 1]);
            testCase.verifyEqual( ...
                ProjectionViewerAppInteractionTest.layoutPosition(blendDropDown), [2 1]);
        end

        function testControlScrollAdjustsTwistWithoutZoomOrMeshChange(testCase)
            scene = ProjectionViewerAppInteractionTest.makeScene();
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow

            fig = findall(groot, "Type", "figure", ...
                "Name", "Projection Viewer Prototype");
            ax = findall(fig, "Type", "axes");
            twistSlider = ProjectionViewerAppInteractionTest.findSliderInColumn(fig, 4);
            surfaceHandle = findall(ax, "Type", "surface");
            x0 = surfaceHandle(1).XData;
            y0 = surfaceHandle(1).YData;
            z0 = surfaceHandle(1).ZData;
            initialCameraViewAngle = ax.CameraViewAngle;
            initialUpVector = camup(ax);

            fig.WindowKeyPressFcn(fig, ...
                ProjectionViewerAppInteractionTest.makeKeyEvent("control"));
            fig.WindowScrollWheelFcn(fig, ...
                ProjectionViewerAppInteractionTest.makeScrollEvent(-3));
            drawnow

            testCase.verifyEqual(twistSlider.Value, 3, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyEqual(ax.CameraViewAngle, initialCameraViewAngle, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyGreaterThan(norm(camup(ax) - initialUpVector), 1e-9);
            testCase.verifyEqual(surfaceHandle(1).XData, x0, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyEqual(surfaceHandle(1).YData, y0, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyEqual(surfaceHandle(1).ZData, z0, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);

            fig.WindowKeyReleaseFcn(fig, ...
                ProjectionViewerAppInteractionTest.makeKeyEvent("control"));
            fig.WindowScrollWheelFcn(fig, ...
                ProjectionViewerAppInteractionTest.makeScrollEvent(-3));
            drawnow

            testCase.verifyEqual(twistSlider.Value, 3, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
        end

        function testShiftScrollAdjustsTipWithoutZoom(testCase)
            scene = ProjectionViewerAppInteractionTest.makeScene();
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow

            fig = findall(groot, "Type", "figure", ...
                "Name", "Projection Viewer Prototype");
            ax = findall(fig, "Type", "axes");
            tipSlider = ProjectionViewerAppInteractionTest.findSliderInColumn(fig, 2);
            surfaceHandle = findall(ax, "Type", "surface");
            initialXData = surfaceHandle(1).XData;
            initialYData = surfaceHandle(1).YData;
            initialZData = surfaceHandle(1).ZData;
            initialCameraViewAngle = ax.CameraViewAngle;

            fig.WindowKeyPressFcn(fig, ...
                ProjectionViewerAppInteractionTest.makeKeyEvent("shift"));
            fig.WindowScrollWheelFcn(fig, ...
                ProjectionViewerAppInteractionTest.makeScrollEvent(-4));
            drawnow

            testCase.verifyEqual(tipSlider.Value, 4, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyEqual(ax.CameraViewAngle, initialCameraViewAngle, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyGreaterThan(ProjectionViewerAppInteractionTest.surfaceChange( ...
                surfaceHandle(1), initialXData, initialYData, initialZData), 1e-9);

            fig.WindowKeyReleaseFcn(fig, ...
                ProjectionViewerAppInteractionTest.makeKeyEvent("shift"));
            fig.WindowScrollWheelFcn(fig, ...
                ProjectionViewerAppInteractionTest.makeScrollEvent(-2));
            drawnow

            testCase.verifyEqual(tipSlider.Value, 4, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
        end

        function testAltScrollAdjustsTiltWithoutZoom(testCase)
            scene = ProjectionViewerAppInteractionTest.makeScene();
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow

            fig = findall(groot, "Type", "figure", ...
                "Name", "Projection Viewer Prototype");
            ax = findall(fig, "Type", "axes");
            tiltSlider = ProjectionViewerAppInteractionTest.findSliderInColumn(fig, 3);
            surfaceHandle = findall(ax, "Type", "surface");
            initialXData = surfaceHandle(1).XData;
            initialYData = surfaceHandle(1).YData;
            initialZData = surfaceHandle(1).ZData;
            initialCameraViewAngle = ax.CameraViewAngle;

            fig.WindowKeyPressFcn(fig, ...
                ProjectionViewerAppInteractionTest.makeKeyEvent("alt"));
            fig.WindowScrollWheelFcn(fig, ...
                ProjectionViewerAppInteractionTest.makeScrollEvent(-5));
            drawnow

            testCase.verifyEqual(tiltSlider.Value, 5, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyEqual(ax.CameraViewAngle, initialCameraViewAngle, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyGreaterThan(ProjectionViewerAppInteractionTest.surfaceChange( ...
                surfaceHandle(1), initialXData, initialYData, initialZData), 1e-9);

            fig.WindowKeyReleaseFcn(fig, ...
                ProjectionViewerAppInteractionTest.makeKeyEvent("alt"));
            fig.WindowScrollWheelFcn(fig, ...
                ProjectionViewerAppInteractionTest.makeScrollEvent(-2));
            drawnow

            testCase.verifyEqual(tiltSlider.Value, 5, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
        end

        function testLayerSpecificAlphaDragUpdatesSelectedLayerOnly(testCase)
            scene = ProjectionViewerAppInteractionTest.makeTwoImageScene();
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow

            fig = findall(groot, "Type", "figure", ...
                "Name", "Projection Viewer Prototype");
            ax = findall(fig, "Type", "axes");
            layerDropDown = ProjectionViewerAppInteractionTest.findLayerDropDown(fig);
            alphaSlider = ProjectionViewerAppInteractionTest.findSliderInColumn(fig, 5);

            layerDropDown.Value = 2;
            layerDropDown.ValueChangedFcn(layerDropDown, struct("Value", 2));
            drawnow
            pause(0.04)

            alphaSlider.ValueChangingFcn(alphaSlider, struct("Value", 0.4));
            drawnow
            alphaSlider.Value = 0.4;
            alphaSlider.ValueChangedFcn(alphaSlider, struct());
            drawnow

            surfaceHandles = findall(ax, "Type", "surface");
            hasLayer2Texture = any(arrayfun( ...
                @(surfaceHandle) isequal(surfaceHandle.CData, ...
                scene.layers(2).DisplayTexture), surfaceHandles));
            layerSurfaces = ProjectionViewerAppInteractionTest.findLayerSurfaces( ...
                ax, scene);
            testCase.verifyTrue(hasLayer2Texture);
            testCase.verifyEqual(alphaSlider.Value, 0.4, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyEqual(layerSurfaces(1).FaceAlpha, 1, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyEqual(layerSurfaces(2).FaceAlpha, 0.4, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
        end

        function testInitialSelectionTargetsTopLayer(testCase)
            scene = ProjectionViewerAppInteractionTest.makeTwoImageScene();
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow

            fig = findall(groot, "Type", "figure", ...
                "Name", "Projection Viewer Prototype");
            ax = findall(fig, "Type", "axes");
            layerDropDown = ProjectionViewerAppInteractionTest.findLayerDropDown(fig);
            alphaSlider = ProjectionViewerAppInteractionTest.findSliderInColumn(fig, 5);

            alphaSlider.Value = 0.35;
            alphaSlider.ValueChangedFcn(alphaSlider, struct());
            drawnow

            layerSurfaces = ProjectionViewerAppInteractionTest.findLayerSurfaces( ...
                ax, scene);

            testCase.verifyEqual(layerDropDown.Value, 2);
            testCase.verifyEqual(layerSurfaces(1).FaceAlpha, 1, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyEqual(layerSurfaces(2).FaceAlpha, 0.35, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
        end

        function testWasdNudgesSelectedLayerOnly(testCase)
            scene = ProjectionViewerAppInteractionTest.makeTwoImageScene();
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow

            fig = findall(groot, "Type", "figure", ...
                "Name", "Projection Viewer Prototype");
            ax = findall(fig, "Type", "axes");
            layerSurfaces = ProjectionViewerAppInteractionTest.findLayerSurfaces( ...
                ax, scene);
            layer1X0 = layerSurfaces(1).XData;
            layer1Y0 = layerSurfaces(1).YData;
            layer1Z0 = layerSurfaces(1).ZData;
            layer2Center0 = ProjectionViewerAppInteractionTest.surfaceCenter( ...
                layerSurfaces(2));

            fig.WindowKeyPressFcn(fig, ...
                ProjectionViewerAppInteractionTest.makeKeyEvent("w"));
            drawnow

            layerSurfaces = ProjectionViewerAppInteractionTest.findLayerSurfaces( ...
                ax, scene);
            layer1Change = ProjectionViewerAppInteractionTest.surfaceChange( ...
                layerSurfaces(1), layer1X0, layer1Y0, layer1Z0);
            layer2Delta = ProjectionViewerAppInteractionTest.surfaceCenter( ...
                layerSurfaces(2)) - layer2Center0;

            testCase.verifyEqual(layer1Change, 0, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyEqual(layer2Delta, [0; 0; 0.5], AbsTol=1e-9);
        end

        function testAlphaChangeDoesNotMoveNudgedLayer(testCase)
            scene = ProjectionViewerAppInteractionTest.makeTwoImageScene();
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow

            fig = findall(groot, "Type", "figure", ...
                "Name", "Projection Viewer Prototype");
            ax = findall(fig, "Type", "axes");
            alphaSlider = ProjectionViewerAppInteractionTest.findSliderInColumn(fig, 5);

            fig.WindowKeyPressFcn(fig, ...
                ProjectionViewerAppInteractionTest.makeKeyEvent("w"));
            drawnow

            layerSurfaces = ProjectionViewerAppInteractionTest.findLayerSurfaces( ...
                ax, scene);
            layer2X = layerSurfaces(2).XData;
            layer2Y = layerSurfaces(2).YData;
            layer2Z = layerSurfaces(2).ZData;

            alphaSlider.ValueChangingFcn(alphaSlider, struct("Value", 0.4));
            drawnow
            layerSurfaces = ProjectionViewerAppInteractionTest.findLayerSurfaces( ...
                ax, scene);

            testCase.verifyEqual(layerSurfaces(2).XData, layer2X, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyEqual(layerSurfaces(2).YData, layer2Y, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyEqual(layerSurfaces(2).ZData, layer2Z, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyEqual(layerSurfaces(2).FaceAlpha, 0.4, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);

            alphaSlider.Value = 0.7;
            alphaSlider.ValueChangedFcn(alphaSlider, struct());
            drawnow
            layerSurfaces = ProjectionViewerAppInteractionTest.findLayerSurfaces( ...
                ax, scene);

            testCase.verifyEqual(layerSurfaces(2).XData, layer2X, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyEqual(layerSurfaces(2).YData, layer2Y, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyEqual(layerSurfaces(2).ZData, layer2Z, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyEqual(layerSurfaces(2).FaceAlpha, 0.7, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
        end

        function testViewVectorCorrectionKeysAdjustSelectedLayerOnly(testCase)
            scene = ProjectionViewerAppInteractionTest.makeTwoImageScene();
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow

            fig = findall(groot, "Type", "figure", ...
                "Name", "Projection Viewer Prototype");
            ax = findall(fig, "Type", "axes");
            opkLabel = ProjectionViewerAppInteractionTest.findOpkLabel(fig);
            ifovDegrees = ProjectionViewerAppInteractionTest.layerIfovDegrees( ...
                scene.layers(2));
            layerSurfaces = ProjectionViewerAppInteractionTest.findLayerSurfaces( ...
                ax, scene);
            layer1X = layerSurfaces(1).XData;
            layer1Y = layerSurfaces(1).YData;
            layer1Z = layerSurfaces(1).ZData;
            layer2X = layerSurfaces(2).XData;
            layer2Y = layerSurfaces(2).YData;
            layer2Z = layerSurfaces(2).ZData;

            fig.WindowKeyPressFcn(fig, ...
                ProjectionViewerAppInteractionTest.makeKeyEvent("i"));
            drawnow
            layerSurfaces = ProjectionViewerAppInteractionTest.findLayerSurfaces( ...
                ax, scene);
            phiChange = ProjectionViewerAppInteractionTest.surfaceChange( ...
                layerSurfaces(2), layer2X, layer2Y, layer2Z);

            testCase.verifyEqual(ProjectionViewerAppInteractionTest.surfaceChange( ...
                layerSurfaces(1), layer1X, layer1Y, layer1Z), 0, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyGreaterThan(phiChange, 1e-3);
            testCase.verifyEqual(string(opkLabel.Text), ...
                ProjectionViewerAppInteractionTest.opkText([0; ifovDegrees; 0]));

            fig.WindowKeyPressFcn(fig, ...
                ProjectionViewerAppInteractionTest.makeKeyEvent("k"));
            drawnow
            layerSurfaces = ProjectionViewerAppInteractionTest.findLayerSurfaces( ...
                ax, scene);

            testCase.verifyEqual(layerSurfaces(2).XData, layer2X, AbsTol=1e-9);
            testCase.verifyEqual(layerSurfaces(2).YData, layer2Y, AbsTol=1e-9);
            testCase.verifyEqual(layerSurfaces(2).ZData, layer2Z, AbsTol=1e-9);
            testCase.verifyEqual(string(opkLabel.Text), ...
                ProjectionViewerAppInteractionTest.opkText([0; 0; 0]));

            fig.WindowKeyPressFcn(fig, ...
                ProjectionViewerAppInteractionTest.makeKeyEvent("l"));
            drawnow
            layerSurfaces = ProjectionViewerAppInteractionTest.findLayerSurfaces( ...
                ax, scene);
            omegaChange = ProjectionViewerAppInteractionTest.surfaceChange( ...
                layerSurfaces(2), layer2X, layer2Y, layer2Z);

            testCase.verifyGreaterThan(omegaChange, 1e-3);
            testCase.verifyEqual(string(opkLabel.Text), ...
                ProjectionViewerAppInteractionTest.opkText([ifovDegrees; 0; 0]));

            fig.WindowKeyPressFcn(fig, ...
                ProjectionViewerAppInteractionTest.makeKeyEvent("j"));
            drawnow
            layerSurfaces = ProjectionViewerAppInteractionTest.findLayerSurfaces( ...
                ax, scene);

            testCase.verifyEqual(layerSurfaces(2).XData, layer2X, AbsTol=1e-9);
            testCase.verifyEqual(layerSurfaces(2).YData, layer2Y, AbsTol=1e-9);
            testCase.verifyEqual(layerSurfaces(2).ZData, layer2Z, AbsTol=1e-9);
            testCase.verifyEqual(string(opkLabel.Text), ...
                ProjectionViewerAppInteractionTest.opkText([0; 0; 0]));

            fig.WindowKeyPressFcn(fig, ...
                ProjectionViewerAppInteractionTest.makeKeyEvent("o"));
            drawnow
            layerSurfaces = ProjectionViewerAppInteractionTest.findLayerSurfaces( ...
                ax, scene);
            kappaChange = ProjectionViewerAppInteractionTest.surfaceChange( ...
                layerSurfaces(2), layer2X, layer2Y, layer2Z);

            testCase.verifyGreaterThan(kappaChange, 1e-3);
            testCase.verifyEqual(string(opkLabel.Text), ...
                ProjectionViewerAppInteractionTest.opkText([0; 0; 0.1]));

            fig.WindowKeyPressFcn(fig, ...
                ProjectionViewerAppInteractionTest.makeKeyEvent("u"));
            drawnow
            layerSurfaces = ProjectionViewerAppInteractionTest.findLayerSurfaces( ...
                ax, scene);

            testCase.verifyEqual(layerSurfaces(2).XData, layer2X, AbsTol=1e-9);
            testCase.verifyEqual(layerSurfaces(2).YData, layer2Y, AbsTol=1e-9);
            testCase.verifyEqual(layerSurfaces(2).ZData, layer2Z, AbsTol=1e-9);
            testCase.verifyEqual(string(opkLabel.Text), ...
                ProjectionViewerAppInteractionTest.opkText([0; 0; 0]));
        end

        function testExportImportStateRestoresViewerConfiguration(testCase)
            scene = ProjectionViewerAppInteractionTest.makeTwoImageScene();
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow

            state = app.exportState();
            state.SelectedLayerIndex = 2;
            state.Projection.TipDegrees = 5.5;
            state.Projection.TiltDegrees = -4.25;
            state.View.TwistDegrees = 3.75;
            state.Camera.ViewAngle = 11;
            state.Layers(1).Alpha = 0.35;
            state.Layers(1).Visible = false;
            state.Layers(1).BlendMode = "redBlueAnaglyph";
            state.Layers(1).ProjectionOffsetMeters = [0.5 -0.25];
            state.Layers(1).ViewVectorAngularOffsetsDegrees = [0.01 0.02 0.03];
            state.Layers(2).Alpha = 0.45;
            state.Layers(2).Visible = true;
            state.Layers(2).BlendMode = "alpha";
            state.Layers(2).ProjectionOffsetMeters = [-0.75 1.25];
            state.Layers(2).ViewVectorAngularOffsetsDegrees = [-0.04 0.05 -0.06];
            state = ProjectionViewerState.validate(state, 2);

            app.importState(state);
            actual = app.exportState();

            testCase.verifyEqual(actual.SelectedLayerIndex, 2);
            testCase.verifyEqual(actual.Projection.TipDegrees, 5.5, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyEqual(actual.Projection.TiltDegrees, -4.25, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyEqual(actual.View.TwistDegrees, 3.75, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyEqual(actual.Camera.ViewAngle, 11, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyEqual(actual.Layers(1).Alpha, 0.35, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyFalse(actual.Layers(1).Visible);
            testCase.verifyEqual(actual.Layers(1).BlendMode, "redBlueAnaglyph");
            testCase.verifyEqual(actual.Layers(1).ProjectionOffsetMeters, ...
                [0.5 -0.25], AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyEqual(actual.Layers(1).ViewVectorAngularOffsetsDegrees, ...
                [0.01 0.02 0.03], AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyEqual(actual.Layers(2).Alpha, 0.45, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyEqual(actual.Layers(2).ProjectionOffsetMeters, ...
                [-0.75 1.25], AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyEqual(actual.Layers(2).ViewVectorAngularOffsetsDegrees, ...
                [-0.04 0.05 -0.06], AbsTol=ProjectionViewerAppInteractionTest.Tol);
        end

        function testSaveLoadStateRoundTrip(testCase)
            scene = ProjectionViewerAppInteractionTest.makeTwoImageScene();
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow

            state = app.exportState();
            state.SelectedLayerIndex = 2;
            state.Projection.TipDegrees = 2.25;
            state.Layers(2).Alpha = 0.25;
            state.Layers(2).ProjectionOffsetMeters = [1.25 -1.5];
            state = ProjectionViewerState.validate(state, 2);
            app.importState(state);
            filePath = fullfile(tempdir, "projection_viewer_app_state_test.json");
            testCase.addTeardown(@() delete(filePath));

            app.saveState(filePath);
            resetState = app.exportState();
            resetState.Projection.TipDegrees = 0;
            resetState.Layers(2).Alpha = 1;
            resetState.Layers(2).ProjectionOffsetMeters = [0 0];
            app.importState(ProjectionViewerState.validate(resetState, 2));
            loadedState = app.loadState(filePath);
            actual = app.exportState();
            jsonText = fileread(filePath);

            testCase.verifyTrue(contains(jsonText, '"ProjectionOffsetMeters"'));
            testCase.verifyEqual(loadedState.Projection.TipDegrees, 2.25, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyEqual(actual.Layers(2).Alpha, 0.25, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyEqual(actual.Layers(2).ProjectionOffsetMeters, ...
                [1.25 -1.5], AbsTol=ProjectionViewerAppInteractionTest.Tol);
        end

        function testConstructorAcceptsViewerState(testCase)
            scene = ProjectionViewerAppInteractionTest.makeTwoImageScene();
            state = ProjectionViewerAppInteractionTest.makeViewerState(scene);

            app = ProjectionViewerApp(scene, [], state);
            testCase.addTeardown(@() delete(app));
            drawnow

            actual = app.exportState();

            testCase.verifyEqual(actual.SelectedLayerIndex, 2);
            testCase.verifyEqual(actual.Projection.TipDegrees, ...
                state.Projection.TipDegrees, AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyEqual(actual.View.TwistDegrees, ...
                state.View.TwistDegrees, AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyEqual(actual.Layers(2).Alpha, state.Layers(2).Alpha, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyEqual(actual.Layers(2).ProjectionOffsetMeters, ...
                state.Layers(2).ProjectionOffsetMeters, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
        end

        function testTipTiltControlsSharedProjectionPlane(testCase)
            scene = ProjectionViewerAppInteractionTest.makeTwoImageScene();
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow

            fig = findall(groot, "Type", "figure", ...
                "Name", "Projection Viewer Prototype");
            ax = findall(fig, "Type", "axes");
            layerDropDown = ProjectionViewerAppInteractionTest.findLayerDropDown(fig);
            tipSlider = ProjectionViewerAppInteractionTest.findSliderInColumn(fig, 2);
            layerSurfaces = ProjectionViewerAppInteractionTest.findLayerSurfaces( ...
                ax, scene);
            layer1X0 = layerSurfaces(1).XData;
            layer1Y0 = layerSurfaces(1).YData;
            layer1Z0 = layerSurfaces(1).ZData;
            layer2X0 = layerSurfaces(2).XData;
            layer2Y0 = layerSurfaces(2).YData;
            layer2Z0 = layerSurfaces(2).ZData;

            layerDropDown.Value = 2;
            layerDropDown.ValueChangedFcn(layerDropDown, struct("Value", 2));
            tipSlider.Value = 6;
            tipSlider.ValueChangedFcn(tipSlider, struct());
            drawnow

            layerSurfaces = ProjectionViewerAppInteractionTest.findLayerSurfaces( ...
                ax, scene);
            layer1Change = ProjectionViewerAppInteractionTest.surfaceChange( ...
                layerSurfaces(1), layer1X0, layer1Y0, layer1Z0);
            layer2Change = ProjectionViewerAppInteractionTest.surfaceChange( ...
                layerSurfaces(2), layer2X0, layer2Y0, layer2Z0);
            layerDropDown.Value = 1;
            layerDropDown.ValueChangedFcn(layerDropDown, struct("Value", 1));
            drawnow

            testCase.verifyGreaterThan(layer1Change, 1e-9);
            testCase.verifyGreaterThan(layer2Change, 1e-9);
            testCase.verifyEqual(tipSlider.Value, 6, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
        end

        function testMultiLayerPreviewUsesStableDepthBias(testCase)
            scene = ProjectionViewerAppInteractionTest.makeTwoImageScene();
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow

            fig = findall(groot, "Type", "figure", ...
                "Name", "Projection Viewer Prototype");
            ax = findall(fig, "Type", "axes");
            layerSurfaces = ProjectionViewerAppInteractionTest.findLayerSurfaces( ...
                ax, scene);
            viewDirection = ProjectionViewerAppInteractionTest.cameraViewDirection(ax);

            layer1Depth = ProjectionViewerAppInteractionTest.meanSurfaceDepth( ...
                layerSurfaces(1), viewDirection);
            layer2Depth = ProjectionViewerAppInteractionTest.meanSurfaceDepth( ...
                layerSurfaces(2), viewDirection);

            testCase.verifyEqual(layer2Depth - layer1Depth, -1, ...
                AbsTol=1e-8);
        end

        function testFirstTipChangePreservesAxesScale(testCase)
            scene = ProjectionViewerAppInteractionTest.makeTwoImageScene();
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow

            fig = findall(groot, "Type", "figure", ...
                "Name", "Projection Viewer Prototype");
            ax = findall(fig, "Type", "axes");
            tipSlider = ProjectionViewerAppInteractionTest.findSliderInColumn(fig, 2);
            initialCameraViewAngle = ax.CameraViewAngle;
            initialXLim = ax.XLim;
            initialYLim = ax.YLim;
            initialZLim = ax.ZLim;
            initialPlotBoxAspectRatio = ax.PlotBoxAspectRatio;

            tipSlider.Value = 1;
            tipSlider.ValueChangedFcn(tipSlider, struct());
            drawnow

            testCase.verifyEqual(ax.CameraViewAngle, initialCameraViewAngle, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyEqual(ax.XLim, initialXLim, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyEqual(ax.YLim, initialYLim, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyEqual(ax.ZLim, initialZLim, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyEqual(ax.PlotBoxAspectRatio, initialPlotBoxAspectRatio, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
        end
    end

    methods (Static, Access = private)
        function scene = makeScene()
            imageData = uint8(reshape(1:60, 4, 5, 3));
            options = struct();
            options.RowStride = 2;
            options.ColumnStride = 2;
            scene = ProjectionViewerHarness.createSceneFromImage( ...
                imageData, "synthetic.tif", options);
        end

        function scene = makeTwoImageScene()
            imageData1 = uint8(reshape(1:60, 4, 5, 3));
            imageData2 = uint8(reshape(1:72, 6, 4, 3));
            options = struct();
            options.RowStride = 2;
            options.ColumnStride = 2;
            scene = ProjectionViewerHarness.createSceneFromImages( ...
                {imageData1, imageData2}, ["layer1.tif", "layer2.tif"], ...
                options);
        end

        function dropdown = findLayerDropDown(fig)
            dropdowns = findall(fig, "-isa", "matlab.ui.control.DropDown");
            isLayerDropDown = false(size(dropdowns));
            for k = 1:numel(dropdowns)
                isLayerDropDown(k) = isnumeric(dropdowns(k).ItemsData) && ...
                    isequal(dropdowns(k).ItemsData, 1:numel(dropdowns(k).Items));
            end
            dropdown = dropdowns(isLayerDropDown);
        end

        function dropdown = findBlendDropDown(fig)
            dropdowns = findall(fig, "-isa", "matlab.ui.control.DropDown");
            isBlendDropDown = false(size(dropdowns));
            for k = 1:numel(dropdowns)
                items = reshape(string(dropdowns(k).Items), 1, []);
                isBlendDropDown(k) = isequal(items, ["alpha", "redBlueAnaglyph"]);
            end
            dropdown = dropdowns(isBlendDropDown);
        end

        function button = findButton(fig, text)
            buttons = findall(fig, "-isa", "matlab.ui.control.Button");
            buttonTexts = strings(size(buttons));
            for k = 1:numel(buttons)
                buttonTexts(k) = string(buttons(k).Text);
            end
            button = buttons(buttonTexts == string(text));
        end

        function position = layoutPosition(component)
            position = [component.Layout.Row component.Layout.Column];
        end

        function slider = findSliderInColumn(fig, column)
            sliders = findall(fig, "-isa", "matlab.ui.control.Slider");
            sliderColumns = arrayfun(@(slider) slider.Layout.Column, sliders);
            slider = sliders(sliderColumns == column);
        end

        function label = findOpkLabel(fig)
            labels = findall(fig, "-isa", "matlab.ui.control.Label");
            labelTexts = strings(size(labels));
            for k = 1:numel(labels)
                labelTexts(k) = string(labels(k).Text);
            end
            label = labels(startsWith(labelTexts, "Omega "));
        end

        function ifovDegrees = layerIfovDegrees(layer)
            imageSize = layer.SourceGeometry.ImageSize;
            rowIndices = ProjectionViewerAppInteractionTest.centerAdjacentIndices( ...
                imageSize(1));
            columnIndex = round((imageSize(2) + 1) / 2);
            [~, V] = layer.SourceGeometry.SampleFcn(rowIndices, columnIndex);
            v1 = V(:, 1, 1) / norm(V(:, 1, 1));
            v2 = V(:, 2, 1) / norm(V(:, 2, 1));
            ifovDegrees = rad2deg(acos(max(min(dot(v1, v2), 1), -1)));
        end

        function indices = centerAdjacentIndices(count)
            if count <= 1
                indices = 1;
                return
            end

            firstIndex = max(1, floor((count + 1) / 2));
            secondIndex = min(count, firstIndex + 1);
            if secondIndex == firstIndex
                firstIndex = firstIndex - 1;
            end
            indices = [firstIndex secondIndex];
        end

        function text = opkText(offsetsDegrees)
            text = string(sprintf("Omega %.4f deg\nPhi %.4f deg\nKappa %.3f deg", ...
                offsetsDegrees(1), offsetsDegrees(2), offsetsDegrees(3)));
        end

        function state = makeViewerState(scene)
            state = struct();
            state.Format = "ProjectionViewerState";
            state.Version = 1;
            state.LayerCount = numel(scene.layers);
            state.SelectedLayerIndex = 2;
            state.Projection = struct(TipDegrees=3.5, TiltDegrees=-2.5);
            state.View = struct(TwistDegrees=1.25);
            state.Layers = [ ...
                ProjectionViewerAppInteractionTest.makeViewerLayerState( ...
                scene.layers(1), 1, 1, [0 0], [0 0 0]), ...
                ProjectionViewerAppInteractionTest.makeViewerLayerState( ...
                scene.layers(2), 2, 0.3, [0.5 -0.75], [0.01 0.02 0.03])];
        end

        function layerState = makeViewerLayerState(layer, index, alpha, ...
                projectionOffsetMeters, viewVectorAngularOffsetsDegrees)
            layerState = struct();
            layerState.Index = index;
            layerState.Name = layer.Name;
            layerState.ImagePath = layer.ImagePath;
            layerState.Alpha = alpha;
            layerState.Visible = true;
            layerState.BlendMode = "alpha";
            layerState.ProjectionOffsetMeters = projectionOffsetMeters;
            layerState.ViewVectorAngularOffsetsDegrees = ...
                viewVectorAngularOffsetsDegrees;
        end

        function surfaces = findLayerSurfaces(ax, scene)
            surfaceHandles = findall(ax, "Type", "surface");
            surfaces = gobjects(1, numel(scene.layers));
            for layerIndex = 1:numel(scene.layers)
                isLayerSurface = arrayfun( ...
                    @(surfaceHandle) isequal(surfaceHandle.CData, ...
                    scene.layers(layerIndex).DisplayTexture), surfaceHandles);
                surfaces(layerIndex) = surfaceHandles(isLayerSurface);
            end
        end

        function viewDirection = cameraViewDirection(ax)
            viewDirection = camtarget(ax).' - campos(ax).';
            viewDirection = viewDirection / norm(viewDirection);
        end

        function depth = meanSurfaceDepth(surfaceHandle, viewDirection)
            points = [surfaceHandle.XData(:).'; ...
                surfaceHandle.YData(:).'; surfaceHandle.ZData(:).'];
            depth = mean(viewDirection(:).' * points);
        end

        function center = surfaceCenter(surfaceHandle)
            center = [mean(surfaceHandle.XData, "all"); ...
                mean(surfaceHandle.YData, "all"); ...
                mean(surfaceHandle.ZData, "all")];
        end

        function event = makeKeyEvent(key)
            event = struct();
            event.Key = key;
            event.Modifier = key;
        end

        function event = makeScrollEvent(verticalScrollCount)
            event = struct();
            event.VerticalScrollCount = verticalScrollCount;
        end

        function change = surfaceChange(surfaceHandle, x0, y0, z0)
            change = max([max(abs(surfaceHandle.XData - x0), [], "all"), ...
                max(abs(surfaceHandle.YData - y0), [], "all"), ...
                max(abs(surfaceHandle.ZData - z0), [], "all")]);
        end
    end
end
