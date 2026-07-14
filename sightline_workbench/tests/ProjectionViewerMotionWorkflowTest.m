classdef ProjectionViewerMotionWorkflowTest < matlab.uitest.TestCase
    %ProjectionViewerMotionWorkflowTest Tests manual motion-imagery UI.

    methods (TestClassSetup)
        function addSourceToPath(testCase)
            projectRoot = fileparts(fileparts(mfilename("fullpath")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(projectRoot, "src")));
        end
    end

    methods (TestMethodSetup)
        function closeExistingFigures(testCase)
            ProjectionViewerMotionWorkflowTest.closeFigures();
            testCase.addTeardown( ...
                @ProjectionViewerMotionWorkflowTest.closeFigures);
        end
    end

    methods (Test)
        function testLayerManagerOpensByDefaultInViewAll(testCase)
            scene = ProjectionViewerMotionWorkflowTest.makeScene();
            scene.layers(2).Visible = false;
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            viewer = ProjectionViewerMotionWorkflowTest.viewer();

            testCase.verifyNumElements(findall(groot, "Tag", ...
                "ProjectionViewerLayerManagerFigure"), 1);
            testCase.verifyEmpty(findall(viewer, "Tag", ...
                "ProjectionViewerMotionLeftEdgeButton"));

            ProjectionViewerMotionWorkflowTest.openMotionWindow();
            window = ProjectionViewerMotionWorkflowTest.motionWindow();
            data = ProjectionViewerMotionWorkflowTest.tagged( ...
                window, "ProjectionViewerMotionTable").Data;

            testCase.verifyTrue(all(data.Include));
            testCase.verifyEqual(data.Visible, [true; false; true]);
            testCase.verifyEqual(height(data), numel(scene.layers));
            testCase.verifyEqual(string(data.ViewId), ...
                reshape(ProjectionViewMetadata.ids(scene), [], 1));
            testCase.verifyEmpty(findall(viewer, "Tag", ...
                "ProjectionViewerMotionLeftEdgeButton"));
            testCase.verifyFalse(app.motionDiagnostics().Active);
            testCase.verifyEqual(app.motionDiagnostics().Mode, "viewAll");
        end

        function testPassAndPerViewFiltersRequireTwoFrames(testCase)
            scene = ProjectionViewerMotionWorkflowTest.makeScene();
            scene.layers(1).PassId = "pass-a";
            scene.layers(2).PassId = "pass-a";
            scene.layers(3).PassId = "pass-b";
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            ProjectionViewerMotionWorkflowTest.openMotionWindow();
            window = ProjectionViewerMotionWorkflowTest.motionWindow();
            pass = ProjectionViewerMotionWorkflowTest.tagged( ...
                window, "ProjectionViewerMotionPassDropDown");
            mode = ProjectionViewerMotionWorkflowTest.tagged( ...
                window, "ProjectionViewerLayerManagerModeDropDown");
            status = ProjectionViewerMotionWorkflowTest.tagged( ...
                window, "ProjectionViewerMotionStatusLabel");

            pass.Value = "pass-b";
            pass.ValueChangedFcn(pass, struct());
            mode.Value = "pair";
            mode.ValueChangedFcn(mode, struct());
            testCase.verifyFalse(app.motionDiagnostics().Active);
            testCase.verifySubstring(string(status.Text), "at least two");

            pass.Value = "pass-a";
            pass.ValueChangedFcn(pass, struct());
            mode.Value = "pair";
            mode.ValueChangedFcn(mode, struct());
            testCase.verifyTrue(app.motionDiagnostics().Active);
            tableControl = ProjectionViewerMotionWorkflowTest.tagged( ...
                window, "ProjectionViewerMotionTable");
            data = tableControl.Data;
            data.Include(2) = false;
            tableControl.Data = data;
            tableControl.CellEditCallback(tableControl, struct());
            testCase.verifyFalse(app.motionDiagnostics().Active);
            testCase.verifySubstring(string(status.Text), "at least two");
        end

        function testSteppingUsesOneFrameAndExitRestoresExactState(testCase)
            scene = ProjectionViewerMotionWorkflowTest.makeScene();
            scene.layers(1).Visible = false;
            scene.layers(2).Alpha = 0.55;
            scene.layers(2).BlendMode = "redBlueAnaglyph";
            scene.layers(3).BlendMode = "redBlueAnaglyph";
            scene.layers(3).ProjectionOffsetMeters = [0.4; -0.2];
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            viewer = ProjectionViewerMotionWorkflowTest.viewer();
            axes = findall(viewer, "Type", "axes");
            layer = ProjectionViewerMotionWorkflowTest.layerDropDown([]);
            layer.Value = 1;
            layer.ValueChangedFcn(layer, struct(Value=1));
            before = app.exportState();
            ProjectionViewerMotionWorkflowTest.openAndStartMotion(testCase);
            first = app.motionDiagnostics();

            testCase.verifyTrue(first.Active);
            testCase.verifyEqual(nnz(first.EffectiveVisibility), 1);
            testCase.verifyEqual(first.KeyboardMode, "single");
            testCase.verifyEqual(app.exportState().Camera, before.Camera);
            scientificBefore = app.exportState().Layers;
            viewer.CurrentObject = axes;
            viewer.WindowKeyPressFcn(viewer, ...
                ProjectionViewerMotionWorkflowTest.keyEvent("rightarrow"));
            second = app.motionDiagnostics();
            viewer.WindowKeyPressFcn(viewer, ...
                ProjectionViewerMotionWorkflowTest.keyEvent("uparrow"));
            afterReserved = app.exportState();

            testCase.verifyEqual(second.Position, 2);
            testCase.verifyEqual(afterReserved.Layers, scientificBefore);
            viewer.WindowKeyPressFcn(viewer, ...
                ProjectionViewerMotionWorkflowTest.keyEvent("rightarrow"));
            viewer.WindowKeyPressFcn(viewer, ...
                ProjectionViewerMotionWorkflowTest.keyEvent("rightarrow"));
            testCase.verifyEqual(app.motionDiagnostics().Position, 3);

            viewer.WindowKeyPressFcn(viewer, ...
                ProjectionViewerMotionWorkflowTest.keyEvent("escape"));
            testCase.verifyEqual(app.exportState(), before);
            testCase.verifyFalse(app.motionDiagnostics().Active);
        end

        function testLoopIdentityPinAndPersistentButtons(testCase)
            scene = ProjectionViewerMotionWorkflowTest.makeScene();
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            ProjectionViewerMotionWorkflowTest.openAndStartMotion(testCase);
            window = ProjectionViewerMotionWorkflowTest.motionWindow();
            viewer = ProjectionViewerMotionWorkflowTest.viewer();
            identity = ProjectionViewerMotionWorkflowTest.tagged( ...
                viewer, "ProjectionViewerMotionIdentityLabel");
            loop = ProjectionViewerMotionWorkflowTest.tagged( ...
                window, "ProjectionViewerMotionLoopCheckBox");
            hover = ProjectionViewerMotionWorkflowTest.tagged( ...
                window, "ProjectionViewerMotionHoverCheckBox");
            pin = ProjectionViewerMotionWorkflowTest.tagged( ...
                window, "ProjectionViewerMotionPinCheckBox");

            testCase.verifyEqual(string(identity.Visible), "on");
            testCase.verifySubstring(string(identity.Text), "1/3");
            pin.Value = true;
            pin.ValueChangedFcn(pin, struct());
            hover.Value = false;
            hover.ValueChangedFcn(hover, struct());
            left = ProjectionViewerMotionWorkflowTest.tagged( ...
                viewer, "ProjectionViewerMotionLeftEdgeButton");
            right = ProjectionViewerMotionWorkflowTest.tagged( ...
                viewer, "ProjectionViewerMotionRightEdgeButton");
            testCase.verifyEqual(string([left.Visible right.Visible]), ...
                ["on" "on"]);

            loop.Value = true;
            loop.ValueChangedFcn(loop, struct());
            next = ProjectionViewerMotionWorkflowTest.tagged( ...
                window, "ProjectionViewerMotionNextButton");
            testCase.press(next);
            testCase.press(next);
            testCase.press(next);
            diagnostics = app.motionDiagnostics();
            testCase.verifyEqual(diagnostics.Position, 1);
            testCase.verifyTrue(diagnostics.IdentityPinned);
            testCase.verifyEqual(string(identity.Visible), "on");
        end

        function testFallbackWarningRemainsVisible(testCase)
            scene = ProjectionViewerMotionWorkflowTest.makeScene();
            scene.layers(1).AcquisitionStartTime = 1;
            scene.layers(2).AcquisitionStartTime = ...
                datetime(2026, 1, 1, TimeZone="UTC");
            scene.layers(3).AcquisitionStartTime = [];
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            ProjectionViewerMotionWorkflowTest.openAndStartMotion(testCase);
            diagnostics = app.motionDiagnostics();
            status = ProjectionViewerMotionWorkflowTest.tagged( ...
                ProjectionViewerMotionWorkflowTest.motionWindow(), ...
                "ProjectionViewerMotionStatusLabel");

            testCase.verifyNotEmpty(diagnostics.Warning);
            testCase.verifySubstring(string(status.Text), "Warning:");
            testCase.verifyTrue(diagnostics.Sequence.UsedStableFallback);
        end

        function testHoverUpdatesAvoidGeometryAndTileWork(testCase)
            scene = ProjectionViewerMotionWorkflowTest.makeScene();
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            ProjectionViewerMotionWorkflowTest.openAndStartMotion(testCase);
            viewer = ProjectionViewerMotionWorkflowTest.viewer();
            axes = findall(viewer, "Type", "axes");
            position = getpixelposition(axes, true);
            app.resetPerformanceDiagnostics();

            viewer.CurrentPoint = [position(1) + 2, ...
                position(2) + position(4) / 2];
            viewer.WindowButtonMotionFcn(viewer, struct());
            viewer.CurrentPoint = position(1:2) + position(3:4) / 2;
            viewer.WindowButtonMotionFcn(viewer, struct());
            viewer.CurrentPoint = [position(1) + position(3) - 2, ...
                position(2) + position(4) / 2];
            viewer.WindowButtonMotionFcn(viewer, struct());
            performance = app.performanceDiagnostics();

            testCase.verifyEqual(performance.Counters.MeshBuilds, 0);
            testCase.verifyEqual(performance.Counters.TileRefreshes, 0);
            testCase.verifyEqual(performance.Counters.SurfaceCreations, 0);
            testCase.verifyEqual( ...
                performance.Counters.PointerMotionCallbacks, 3);
            testCase.verifyGreaterThanOrEqual( ...
                performance.Counters.MotionHoverStateChanges, 2);
            testCase.verifyEqual( ...
                performance.Timings.MotionHoverSeconds.Count, 3);
        end

        function testZoomedTiledFrameChangeReconcilesLodWithoutBlank(testCase)
            app = ProjectionViewerApp( ...
                ProjectionViewerMotionWorkflowTest.makeTiledScene());
            testCase.addTeardown(@() delete(app));
            viewer = ProjectionViewerMotionWorkflowTest.viewer();
            viewer.Position = [100 100 360 300];
            drawnow
            app.configurePreviewTiling(struct(TileSize=64, ...
                MinTiledImagePixels=1, MaxVisibleTilesPerLayer=96));
            ProjectionViewerMotionWorkflowTest.openAndStartMotion(testCase);
            axesHandle = findall(viewer, "Type", "axes");
            viewer.CurrentObject = axesHandle;
            position = axesHandle.InnerPosition;
            viewer.CurrentPoint = position(1:2) + position(3:4) / 2;
            for index = 1:16
                viewer.WindowScrollWheelFcn( ...
                    viewer, struct(VerticalScrollCount=-1));
            end
            app.flushPreviewUpdates();
            before = app.performanceDiagnostics();
            testCase.verifyNotEqual( ...
                before.Viewer.CurrentLevelIndices(1), ...
                before.Viewer.CurrentLevelIndices(2));

            next = ProjectionViewerMotionWorkflowTest.tagged( ...
                ProjectionViewerMotionWorkflowTest.motionWindow(), ...
                "ProjectionViewerMotionNextButton");
            testCase.press(next);
            drawnow
            after = app.performanceDiagnostics();

            testCase.verifyEqual(after.Viewer.CurrentLevelIndices(2), ...
                after.Viewer.CurrentLevelIndices(1));
            testCase.verifyEqual(after.Viewer.DesiredLevelIndices(2), ...
                after.Viewer.CurrentLevelIndices(2));
            testCase.verifyGreaterThan( ...
                after.Viewer.VisibleTileSurfaceCount, 0);
            testCase.verifyEqual( ...
                after.Counters.BlankPreviewTransitions, 0);

            for index = 1:16
                viewer.WindowScrollWheelFcn( ...
                    viewer, struct(VerticalScrollCount=1));
            end
            app.flushPreviewUpdates();
            zoomedOut = app.performanceDiagnostics();
            testCase.verifyNotEqual( ...
                zoomedOut.Viewer.CurrentLevelIndices(1), ...
                zoomedOut.Viewer.CurrentLevelIndices(2));
            previous = ProjectionViewerMotionWorkflowTest.tagged( ...
                ProjectionViewerMotionWorkflowTest.motionWindow(), ...
                "ProjectionViewerMotionPreviousButton");
            testCase.press(previous);
            reversed = app.performanceDiagnostics();
            testCase.verifyEqual(reversed.Viewer.CurrentLevelIndices(1), ...
                reversed.Viewer.DesiredLevelIndices(1));

            loop = ProjectionViewerMotionWorkflowTest.tagged( ...
                ProjectionViewerMotionWorkflowTest.motionWindow(), ...
                "ProjectionViewerMotionLoopCheckBox");
            loop.Value = true;
            loop.ValueChangedFcn(loop, struct());
            testCase.press(previous);
            loopedReverse = app.performanceDiagnostics();
            testCase.verifyEqual(app.motionDiagnostics().Position, 3);
            testCase.verifyEqual( ...
                loopedReverse.Viewer.CurrentLevelIndices(3), ...
                loopedReverse.Viewer.DesiredLevelIndices(3));
            testCase.press(next);
            loopedForward = app.performanceDiagnostics();
            testCase.verifyEqual(app.motionDiagnostics().Position, 1);
            testCase.verifyEqual( ...
                loopedForward.Viewer.CurrentLevelIndices(1), ...
                loopedForward.Viewer.DesiredLevelIndices(1));
            testCase.verifyEqual( ...
                loopedForward.Counters.BlankPreviewTransitions, 0);
        end

        function testPlaybackRejectsStaleLookaheadAfterCameraChange(testCase)
            app = ProjectionViewerApp( ...
                ProjectionViewerMotionWorkflowTest.makeTiledScene());
            testCase.addTeardown(@() delete(app));
            viewer = ProjectionViewerMotionWorkflowTest.viewer();
            viewer.Position = [100 100 360 300];
            drawnow
            app.configurePreviewTiling(struct(TileSize=64, ...
                MinTiledImagePixels=1, MaxVisibleTilesPerLayer=96));
            ProjectionViewerMotionWorkflowTest.openAndStartMotion(testCase);
            axesHandle = findall(viewer, "Type", "axes");
            viewer.CurrentObject = axesHandle;
            position = axesHandle.InnerPosition;
            viewer.CurrentPoint = position(1:2) + position(3:4) / 2;
            play = ProjectionViewerMotionWorkflowTest.tagged( ...
                ProjectionViewerMotionWorkflowTest.motionWindow(), ...
                "ProjectionViewerMotionPlayPauseButton");
            testCase.press(play);
            beforeCameraChange = app.performanceDiagnostics();

            for index = 1:12
                viewer.WindowScrollWheelFcn( ...
                    viewer, struct(VerticalScrollCount=-1));
            end
            playbackTimer = timerfindall("Tag", ...
                "ProjectionViewerMotionPlaybackTimer");
            stop(playbackTimer);
            playbackTimer.TimerFcn(playbackTimer, struct());
            drawnow
            afterTick = app.performanceDiagnostics();

            testCase.verifyGreaterThan( ...
                afterTick.Viewer.CameraScheduleGeneration, ...
                beforeCameraChange.Viewer.CameraScheduleGeneration);
            testCase.verifyEqual(app.motionDiagnostics().Position, 2);
            testCase.verifyEqual(afterTick.Viewer.CurrentLevelIndices(2), ...
                afterTick.Viewer.DesiredLevelIndices(2));
            testCase.verifyGreaterThan( ...
                afterTick.Viewer.VisibleTileSurfaceCount, 0);
            testCase.verifyEqual( ...
                afterTick.Counters.BlankPreviewTransitions, 0);
        end

        function testSelectionAndVisibilityReconcileHiddenTiledLayer(testCase)
            scene = ProjectionViewerMotionWorkflowTest.makeTiledScene();
            scene.layers(2).Visible = false;
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            viewer = ProjectionViewerMotionWorkflowTest.viewer();
            viewer.Position = [100 100 360 300];
            drawnow
            app.configurePreviewTiling(struct(TileSize=64, ...
                MinTiledImagePixels=1, MaxVisibleTilesPerLayer=96));
            axesHandle = findall(viewer, "Type", "axes");
            viewer.CurrentObject = axesHandle;
            position = axesHandle.InnerPosition;
            viewer.CurrentPoint = position(1:2) + position(3:4) / 2;
            for index = 1:16
                viewer.WindowScrollWheelFcn( ...
                    viewer, struct(VerticalScrollCount=-1));
            end
            app.flushPreviewUpdates();
            hidden = app.performanceDiagnostics();
            testCase.verifyNotEqual(hidden.Viewer.CurrentLevelIndices(2), ...
                hidden.Viewer.CurrentLevelIndices(1));

            layerDropDown = ...
                ProjectionViewerMotionWorkflowTest.layerDropDown(viewer);
            layerDropDown.Value = 2;
            layerDropDown.ValueChangedFcn( ...
                layerDropDown, struct(Value=2));
            selected = app.performanceDiagnostics();
            testCase.verifyEqual(selected.Viewer.CurrentLevelIndices(2), ...
                selected.Viewer.DesiredLevelIndices(2));

            for index = 1:16
                viewer.WindowScrollWheelFcn( ...
                    viewer, struct(VerticalScrollCount=1));
            end
            app.flushPreviewUpdates();
            staleAgain = app.performanceDiagnostics();
            testCase.verifyNotEqual( ...
                staleAgain.Viewer.CurrentLevelIndices(2), ...
                staleAgain.Viewer.CurrentLevelIndices(1));
            visibleCheckBox = findall(groot, "Tag", ...
                "ProjectionViewerLayerManagerVisibleCheckBox");
            visibleCheckBox.Value = true;
            visibleCheckBox.ValueChangedFcn( ...
                visibleCheckBox, struct(Value=true));
            visible = app.performanceDiagnostics();
            testCase.verifyEqual(visible.Viewer.CurrentLevelIndices(2), ...
                visible.Viewer.DesiredLevelIndices(2));
            testCase.verifyGreaterThan( ...
                visible.Viewer.VisibleTileSurfaceCount, 0);
            testCase.verifyEqual( ...
                visible.Counters.BlankPreviewTransitions, 0);
        end

        function testPresentationMasksPreserveStoredVisibility(testCase)
            scene = ProjectionViewerMotionWorkflowTest.makeScene();
            [scene.layers.Visible] = deal(false);
            scene.layers(2).Visible = true;
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            window = ProjectionViewerMotionWorkflowTest.motionWindow();
            layer = ProjectionViewerMotionWorkflowTest.layerDropDown([]);
            layer.Value = 1;
            layer.ValueChangedFcn(layer, struct(Value=1));

            testCase.verifyEqual( ...
                app.motionDiagnostics().EffectiveVisibility, ...
                [false true false]);
            ProjectionViewerMotionWorkflowTest.setMode(window, "single");
            testCase.verifyEqual( ...
                app.motionDiagnostics().EffectiveVisibility, ...
                [true false false]);
            testCase.verifyEqual( ...
                [app.exportState().Layers.Visible], [false true false]);

            ProjectionViewerMotionWorkflowTest.setMode(window, "pair");
            testCase.verifyEqual( ...
                app.motionDiagnostics().EffectiveVisibility, ...
                [true true false]);
            tableControl = ProjectionViewerMotionWorkflowTest.tagged( ...
                window, "ProjectionViewerMotionTable");
            data = tableControl.Data;
            data.Visible = [false; false; true];
            tableControl.Data = data;
            tableControl.CellEditCallback(tableControl, struct());
            testCase.verifyEqual( ...
                [app.exportState().Layers.Visible], [false false true]);
            testCase.verifyEqual(nnz( ...
                app.motionDiagnostics().EffectiveVisibility), 2);

            ProjectionViewerMotionWorkflowTest.setMode(window, "viewAll");
            testCase.verifyEqual( ...
                app.motionDiagnostics().EffectiveVisibility, ...
                [false false true]);
            testCase.press(ProjectionViewerMotionWorkflowTest.tagged( ...
                window, "ProjectionViewerLayerManagerAllVisibleButton"));
            testCase.verifyTrue(all([app.exportState().Layers.Visible]));
            testCase.press(ProjectionViewerMotionWorkflowTest.tagged( ...
                window, "ProjectionViewerLayerManagerNoneVisibleButton"));
            testCase.verifyFalse(any([app.exportState().Layers.Visible]));
        end

        function testPairTurnoverIsOverlappingAndExactlyReversible(testCase)
            app = ProjectionViewerApp( ...
                ProjectionViewerMotionWorkflowTest.makeFourFrameScene());
            testCase.addTeardown(@() delete(app));
            window = ProjectionViewerMotionWorkflowTest.motionWindow();
            layer = ProjectionViewerMotionWorkflowTest.layerDropDown([]);
            layer.Value = 1;
            layer.ValueChangedFcn(layer, struct(Value=1));
            ProjectionViewerMotionWorkflowTest.setMode(window, "pair");
            first = app.motionDiagnostics();
            firstIds = string({first.Sequence.Frames(1:2).ViewId});

            testCase.press(ProjectionViewerMotionWorkflowTest.tagged( ...
                window, "ProjectionViewerMotionNextButton"));
            second = app.motionDiagnostics();
            secondIds = string({second.Sequence.Frames(2:3).ViewId});
            testCase.verifyEqual(second.Position, 2);
            testCase.verifyEqual(firstIds(2), secondIds(1));
            testCase.verifyEqual(nnz(second.EffectiveVisibility), 2);

            testCase.press(ProjectionViewerMotionWorkflowTest.tagged( ...
                window, "ProjectionViewerMotionPreviousButton"));
            reversed = app.motionDiagnostics();
            testCase.verifyEqual(reversed.Position, first.Position);
            testCase.verifyEqual(reversed.EffectiveVisibility, ...
                first.EffectiveVisibility);
            pair = app.alignmentDiagnostics().ActivePair;
            testCase.verifyEqual( ...
                [string(pair.ReferenceViewId) string(pair.MovingViewId)], ...
                firstIds);
        end

        function testPairTrackCameraReturnsWithoutDrift(testCase)
            app = ProjectionViewerApp( ...
                ProjectionViewerMotionWorkflowTest.makeFourFrameScene());
            testCase.addTeardown(@() delete(app));
            window = ProjectionViewerMotionWorkflowTest.motionWindow();
            layer = ProjectionViewerMotionWorkflowTest.layerDropDown([]);
            layer.Value = 1;
            layer.ValueChangedFcn(layer, struct(Value=1));
            ProjectionViewerMotionWorkflowTest.setMode(window, "pair");
            track = ProjectionViewerMotionWorkflowTest.tagged( ...
                window, "ProjectionViewerLayerManagerTrackCameraCheckBox");
            track.Value = true;
            track.ValueChangedFcn(track, struct());
            firstCamera = app.exportState().Camera;

            next = ProjectionViewerMotionWorkflowTest.tagged( ...
                window, "ProjectionViewerMotionNextButton");
            previous = ProjectionViewerMotionWorkflowTest.tagged( ...
                window, "ProjectionViewerMotionPreviousButton");
            testCase.press(next);
            secondCamera = app.exportState().Camera;
            testCase.press(previous);
            returnedCamera = app.exportState().Camera;

            testCase.verifyTrue(app.motionDiagnostics().TrackCamera);
            testCase.verifyNotEqual(secondCamera.Position, ...
                firstCamera.Position);
            testCase.verifyEqual(returnedCamera, firstCamera, AbsTol=1e-10);
        end

        function testLayerReorderKeepsActivePairViewIdsStable(testCase)
            app = ProjectionViewerApp( ...
                ProjectionViewerMotionWorkflowTest.makeFourFrameScene());
            testCase.addTeardown(@() delete(app));
            window = ProjectionViewerMotionWorkflowTest.motionWindow();
            layer = ProjectionViewerMotionWorkflowTest.layerDropDown([]);
            layer.Value = 1;
            layer.ValueChangedFcn(layer, struct(Value=1));
            ProjectionViewerMotionWorkflowTest.setMode(window, "pair");
            before = app.motionDiagnostics();
            beforeIds = string({before.Sequence.Frames(1:2).ViewId});

            testCase.press(ProjectionViewerMotionWorkflowTest.tagged( ...
                window, "ProjectionViewerMoveLayerUpButton"));
            after = app.motionDiagnostics();
            currentOrderIds = strings(1, 4);
            for frame = after.Sequence.Frames
                currentOrderIds(frame.LayerIndex) = string(frame.ViewId);
            end
            visibleIds = currentOrderIds(after.EffectiveVisibility);

            testCase.verifyEqual(string({after.Sequence.Frames(1:2).ViewId}), ...
                beforeIds);
            testCase.verifyEqual(sort(visibleIds), sort(beforeIds));
            testCase.verifyEqual(numel(unique( ...
                string(after.Sequence.ViewIds))), 4);
        end

        function testSelectedFootprintOutlineIsTopmostWithoutRerender(testCase)
            app = ProjectionViewerApp( ...
                ProjectionViewerMotionWorkflowTest.makeScene());
            testCase.addTeardown(@() delete(app));
            viewer = ProjectionViewerMotionWorkflowTest.viewer();
            axesHandle = findall(viewer, "Type", "axes");
            outline = findall(axesHandle, "Tag", ...
                "ProjectionViewerSelectedFootprintOutline");

            testCase.verifyNumElements(outline, 1);
            testCase.verifyEqual(outline.Color, [1 1 0]);
            testCase.verifyEqual(string(outline.Clipping), "on");
            testCase.verifyEqual(string(outline.Visible), "on");
            surfaces = findall(axesHandle, "Type", "surface");
            children = axesHandle.Children;
            outlinePosition = find(children == outline, 1);
            for surface = reshape(surfaces, 1, [])
                testCase.verifyLessThan(outlinePosition, ...
                    find(children == surface, 1));
            end

            app.resetPerformanceDiagnostics();
            layer = ProjectionViewerMotionWorkflowTest.layerDropDown([]);
            layer.Value = 1;
            layer.ValueChangedFcn(layer, struct(Value=1));
            performance = app.performanceDiagnostics();
            testCase.verifyEqual(performance.Counters.MeshBuilds, 0);
            testCase.verifyEqual(performance.Counters.SurfaceCreations, 0);
            testCase.verifyEqual( ...
                performance.Counters.LayerGeometryRefreshes, 0);
            testCase.verifyEqual(string(outline.Visible), "on");
            testCase.verifyFalse(isfield(app.exportState(), ...
                "SelectedFootprintOutline"));
        end

        function testSingleViewSupportsOneEligibleLayer(testCase)
            scene = ProjectionViewerMotionWorkflowTest.makeScene();
            scene.layers = scene.layers(1);
            scene.layers(1).Visible = false;
            scene = ProjectionViewMetadata.ensureScene(scene);
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            window = ProjectionViewerMotionWorkflowTest.motionWindow();

            ProjectionViewerMotionWorkflowTest.setMode(window, "single");
            testCase.verifyTrue(app.motionDiagnostics().Active);
            testCase.verifyEqual( ...
                app.motionDiagnostics().EffectiveVisibility, true);
            testCase.verifyFalse(app.exportState().Layers.Visible);

            ProjectionViewerMotionWorkflowTest.setMode(window, "pair");
            testCase.verifyTrue(app.motionDiagnostics().Active);
            testCase.verifyEqual(app.motionDiagnostics().Mode, "single");
            testCase.verifySubstring(string( ...
                ProjectionViewerMotionWorkflowTest.tagged(window, ...
                "ProjectionViewerMotionStatusLabel").Text), ...
                "at least two");

            ProjectionViewerMotionWorkflowTest.setMode(window, "viewAll");
            ProjectionViewerMotionWorkflowTest.setMode(window, "pair");
            testCase.verifyFalse(app.motionDiagnostics().Active);
            testCase.verifyEqual(app.motionDiagnostics().Mode, "viewAll");
        end

        function testDeleteAfterExternalViewerCloseIsWarningFree(testCase)
            app = ProjectionViewerApp( ...
                ProjectionViewerMotionWorkflowTest.makeScene());
            ProjectionViewerMotionWorkflowTest.openAndStartMotion(testCase);
            delete(ProjectionViewerMotionWorkflowTest.viewer());

            testCase.verifyWarningFree(@() delete(app));
        end
    end

    methods (Static, Access = private)
        function scene = makeScene()
            images = {uint8(ones(8, 9)), uint8(2 * ones(8, 9)), ...
                uint8(3 * ones(8, 9))};
            scene = ProjectionViewerHarness.createSceneFromImages( ...
                images, ["motion-1.tif" "motion-2.tif" "motion-3.tif"], ...
                struct(RowStride=2, ColumnStride=2));
            for index = 1:3
                scene.layers(index).ViewId = "motion-view-" + string(index);
                scene.layers(index).PassId = "motion-pass";
                scene.layers(index).AcquisitionStartTime = index;
            end
            scene = ProjectionViewMetadata.ensureScene(scene);
        end

        function scene = makeTiledScene()
            images = {zeros(512, 512, "uint8"), ...
                ones(512, 512, "uint8"), 2 * ones(512, 512, "uint8")};
            scene = ProjectionViewerHarness.createSceneFromImages( ...
                images, ["lod-1.tif" "lod-2.tif" "lod-3.tif"], ...
                struct(RowStride=32, ColumnStride=32));
            for index = 1:3
                scene.layers(index).ViewId = "lod-view-" + string(index);
                scene.layers(index).PassId = "lod-pass";
                scene.layers(index).AcquisitionStartTime = index;
            end
            scene = ProjectionViewMetadata.ensureScene(scene);
        end

        function scene = makeFourFrameScene()
            images = {uint8(ones(12, 13, 3)), ...
                uint8(2 * ones(12, 13, 3)), ...
                uint8(3 * ones(12, 13, 3)), ...
                uint8(4 * ones(12, 13, 3))};
            scene = ProjectionViewerHarness.createSceneFromImages( ...
                images, "pair-" + string(1:4) + ".tif", ...
                struct(RowStride=3, ColumnStride=3));
            lateral = [-0.3 -0.1 0.1 0.3];
            for index = 1:4
                scene.layers(index).ViewId = "pair-view-" + string(index);
                scene.layers(index).PassId = "pair-pass";
                scene.layers(index).AcquisitionStartTime = index;
                scene.layers(index).SourceGeometry.ReferenceOrigin = ...
                    [0; lateral(index); 0];
            end
            scene = ProjectionViewMetadata.ensureScene(scene);
        end

        function setMode(window, mode)
            control = ProjectionViewerMotionWorkflowTest.tagged( ...
                window, "ProjectionViewerLayerManagerModeDropDown");
            control.Value = mode;
            control.ValueChangedFcn(control, struct());
            drawnow
        end

        function openMotionWindow()
            menu = findall(groot, "Tag", ...
                "ProjectionViewerLayerManagerMenuItem");
            menu(1).MenuSelectedFcn(menu(1), struct());
            drawnow
        end

        function openAndStartMotion(~)
            ProjectionViewerMotionWorkflowTest.openMotionWindow();
            layer = ProjectionViewerMotionWorkflowTest.layerDropDown([]);
            layer.Value = 1;
            layer.ValueChangedFcn(layer, struct(Value=1));
            mode = ProjectionViewerMotionWorkflowTest.tagged( ...
                ProjectionViewerMotionWorkflowTest.motionWindow(), ...
                "ProjectionViewerLayerManagerModeDropDown");
            mode.Value = "single";
            mode.ValueChangedFcn(mode, struct());
            drawnow
        end

        function figureHandle = viewer()
            figures = findall(groot, "Type", "figure", ...
                "Name", "Sightline Workbench");
            figureHandle = figures(1);
        end

        function figureHandle = motionWindow()
            figures = findall(groot, "Tag", ...
                "ProjectionViewerLayerManagerFigure");
            figureHandle = figures(1);
        end

        function component = tagged(parent, tag)
            components = findall(parent, "Tag", tag);
            component = components(1);
        end

        function dropdown = layerDropDown(~)
            dropdown = findall(groot, "Tag", ...
                "ProjectionViewerLayerManagerLayerDropDown");
        end

        function event = keyEvent(key)
            event = struct(Key=key, Modifier=strings(1, 0));
        end

        function closeFigures()
            delete(findall(groot, "Type", "figure", ...
                "Name", "Sightline Workbench"));
            delete(findall(groot, "Tag", ...
                "ProjectionViewerLayerManagerFigure"));
        end
    end
end
