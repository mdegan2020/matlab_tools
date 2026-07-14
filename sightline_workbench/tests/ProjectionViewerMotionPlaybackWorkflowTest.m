classdef ProjectionViewerMotionPlaybackWorkflowTest < matlab.uitest.TestCase
    %ProjectionViewerMotionPlaybackWorkflowTest Tests measured playback UI.

    methods (TestClassSetup)
        function addSourceToPath(testCase)
            projectRoot = fileparts(fileparts(mfilename("fullpath")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(projectRoot, "src")));
        end
    end

    methods (TestMethodSetup)
        function closeExistingRuntime(testCase)
            ProjectionViewerMotionPlaybackWorkflowTest.closeRuntime();
            testCase.addTeardown( ...
                @ProjectionViewerMotionPlaybackWorkflowTest.closeRuntime);
        end
    end

    methods (Test)
        function testPlaybackControlsUseBoundedDefaultPolicy(testCase)
            app = ProjectionViewerApp( ...
                ProjectionViewerMotionPlaybackWorkflowTest.makeScene());
            testCase.addTeardown(@() delete(app));
            ProjectionViewerMotionPlaybackWorkflowTest.openAndStart(testCase);
            window = ProjectionViewerMotionPlaybackWorkflowTest.motionWindow();
            rate = ProjectionViewerMotionPlaybackWorkflowTest.tagged( ...
                window, "ProjectionViewerMotionRateSpinner");
            play = ProjectionViewerMotionPlaybackWorkflowTest.tagged( ...
                window, "ProjectionViewerMotionPlayPauseButton");

            testCase.verifyEqual(rate.Limits, [0.5 10]);
            testCase.verifyEqual(rate.Value, 2);
            testCase.verifyEqual(string(play.Text), "Play");
            testCase.press(play);
            ProjectionViewerMotionPlaybackWorkflowTest.stopPlaybackTimer();
            diagnostics = app.motionDiagnostics();

            testCase.verifyTrue(diagnostics.Playing);
            testCase.verifyEqual(diagnostics.RateFps, 2);
            testCase.verifyEqual(diagnostics.LookaheadCount, 1);
            testCase.verifyEqual(diagnostics.Lookahead.Position, 2);
            testCase.verifyEqual(string(play.Text), "Pause");
            testCase.verifyFalse(isfield(app.exportState(), "Motion"));
        end

        function testSpaceIsPlaybackOnlyInsideMotionMode(testCase)
            scene = ProjectionViewerMotionPlaybackWorkflowTest.makeScene();
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            viewer = ProjectionViewerMotionPlaybackWorkflowTest.viewer();
            axes = findall(viewer, "Type", "axes");
            viewer.CurrentObject = axes;
            initialVisibility = [app.exportState().Layers.Visible];

            viewer.WindowKeyPressFcn(viewer, ...
                ProjectionViewerMotionPlaybackWorkflowTest.keyEvent("space"));
            testCase.verifyFalse(app.exportState().Layers(3).Visible);
            viewer.WindowKeyReleaseFcn(viewer, ...
                ProjectionViewerMotionPlaybackWorkflowTest.keyEvent("space"));
            testCase.verifyEqual( ...
                [app.exportState().Layers.Visible], initialVisibility);

            ProjectionViewerMotionPlaybackWorkflowTest.openAndStart(testCase);
            motionVisibility = [app.exportState().Layers.Visible];
            viewer.WindowKeyPressFcn(viewer, ...
                ProjectionViewerMotionPlaybackWorkflowTest.keyEvent("space"));
            ProjectionViewerMotionPlaybackWorkflowTest.stopPlaybackTimer();
            testCase.verifyTrue(app.motionDiagnostics().Playing);
            viewer.WindowKeyReleaseFcn(viewer, ...
                ProjectionViewerMotionPlaybackWorkflowTest.keyEvent("space"));
            viewer.WindowKeyPressFcn(viewer, ...
                ProjectionViewerMotionPlaybackWorkflowTest.keyEvent("space"));

            testCase.verifyFalse(app.motionDiagnostics().Playing);
            testCase.verifyEqual( ...
                [app.exportState().Layers.Visible], motionVisibility);
        end

        function testManualStepPausesThenMovesExactlyOnce(testCase)
            app = ProjectionViewerApp( ...
                ProjectionViewerMotionPlaybackWorkflowTest.makeScene());
            testCase.addTeardown(@() delete(app));
            ProjectionViewerMotionPlaybackWorkflowTest.openAndStart(testCase);
            window = ProjectionViewerMotionPlaybackWorkflowTest.motionWindow();
            testCase.press(ProjectionViewerMotionPlaybackWorkflowTest.tagged( ...
                window, "ProjectionViewerMotionPlayPauseButton"));
            ProjectionViewerMotionPlaybackWorkflowTest.stopPlaybackTimer();

            testCase.press(ProjectionViewerMotionPlaybackWorkflowTest.tagged( ...
                window, "ProjectionViewerMotionNextButton"));
            diagnostics = app.motionDiagnostics();

            testCase.verifyFalse(diagnostics.Playing);
            testCase.verifyEqual(diagnostics.Position, 2);
            testCase.verifySubstring(diagnostics.PauseReason, "manual step");
            testCase.verifyEqual(diagnostics.PlaybackFrameCount, 0);
        end

        function testPlaybackNeverSkipsAndPausesAtNoWrapBoundary(testCase)
            app = ProjectionViewerApp( ...
                ProjectionViewerMotionPlaybackWorkflowTest.makeScene());
            testCase.addTeardown(@() delete(app));
            ProjectionViewerMotionPlaybackWorkflowTest.openAndStart(testCase);
            testCase.press(ProjectionViewerMotionPlaybackWorkflowTest.tagged( ...
                ProjectionViewerMotionPlaybackWorkflowTest.motionWindow(), ...
                "ProjectionViewerMotionPlayPauseButton"));
            ProjectionViewerMotionPlaybackWorkflowTest.firePlaybackTick();
            first = app.motionDiagnostics();
            ProjectionViewerMotionPlaybackWorkflowTest.firePlaybackTick();
            second = app.motionDiagnostics();
            performance = app.performanceDiagnostics();

            testCase.verifyEqual(first.Position, 2);
            testCase.verifyTrue(first.Playing);
            testCase.verifyEqual(second.Position, 3);
            testCase.verifyFalse(second.Playing);
            testCase.verifyEqual(second.PlaybackFrameCount, 2);
            testCase.verifySubstring(second.PauseReason, "end");
            testCase.verifyEqual(performance.Counters.MotionPlaybackTicks, 2);
            testCase.verifyEqual(performance.Counters.MotionFrameSwitches, 2);
        end

        function testFocusLossAndLayerMutationPauseWithReasons(testCase)
            app = ProjectionViewerApp( ...
                ProjectionViewerMotionPlaybackWorkflowTest.makeScene());
            testCase.addTeardown(@() delete(app));
            ProjectionViewerMotionPlaybackWorkflowTest.openAndStart(testCase);
            window = ProjectionViewerMotionPlaybackWorkflowTest.motionWindow();
            play = ProjectionViewerMotionPlaybackWorkflowTest.tagged( ...
                window, "ProjectionViewerMotionPlayPauseButton");
            viewer = ProjectionViewerMotionPlaybackWorkflowTest.viewer();
            axes = findall(viewer, "Type", "axes");
            testCase.press(play);
            ProjectionViewerMotionPlaybackWorkflowTest.stopPlaybackTimer();
            viewer.CurrentObject = [];
            ProjectionViewerMotionPlaybackWorkflowTest.firePlaybackTick();
            focusPaused = app.motionDiagnostics();

            testCase.verifyFalse(focusPaused.Playing);
            testCase.verifySubstring(focusPaused.PauseReason, "focus");

            viewer.CurrentObject = axes;
            testCase.press(play);
            ProjectionViewerMotionPlaybackWorkflowTest.stopPlaybackTimer();
            viewer.WindowKeyPressFcn(viewer, struct( ...
                Key="uparrow", Modifier="shift"));
            ProjectionViewerMotionPlaybackWorkflowTest.firePlaybackTick();
            mutationPaused = app.motionDiagnostics();

            testCase.verifyFalse(mutationPaused.Playing);
            testCase.verifySubstring(mutationPaused.PauseReason, ...
                "sequence or a layer changed");
        end

        function testPlaybackInteractionAndCacheMetricsStayBounded(testCase)
            app = ProjectionViewerApp( ...
                ProjectionViewerMotionPlaybackWorkflowTest.makeScene());
            testCase.addTeardown(@() delete(app));
            ProjectionViewerMotionPlaybackWorkflowTest.openAndStart(testCase);
            window = ProjectionViewerMotionPlaybackWorkflowTest.motionWindow();
            testCase.press(ProjectionViewerMotionPlaybackWorkflowTest.tagged( ...
                window, "ProjectionViewerMotionPlayPauseButton"));
            ProjectionViewerMotionPlaybackWorkflowTest.stopPlaybackTimer();
            viewer = ProjectionViewerMotionPlaybackWorkflowTest.viewer();
            axes = findall(viewer, "Type", "axes");
            position = getpixelposition(axes, true);
            center = position(1:2) + position(3:4) / 2;
            viewer.CurrentObject = axes;
            viewer.CurrentPoint = center;
            crosshair = ProjectionViewerMotionPlaybackWorkflowTest.tagged( ...
                viewer, "ProjectionViewerCrosshairMenuItem");
            crosshair.MenuSelectedFcn(crosshair, struct());
            app.resetPerformanceDiagnostics();

            viewer.CurrentPoint = center + [3 2];
            viewer.WindowButtonMotionFcn(viewer, struct());
            viewer.WindowScrollWheelFcn(viewer, ...
                struct(VerticalScrollCount=1));
            viewer.SelectionType = "normal";
            viewer.CurrentPoint = center;
            viewer.WindowButtonDownFcn(viewer, struct());
            viewer.CurrentPoint = center + [4 3];
            viewer.WindowButtonMotionFcn(viewer, struct());
            viewer.WindowButtonUpFcn(viewer, struct());
            viewer.CurrentObject = axes;
            ProjectionViewerMotionPlaybackWorkflowTest.firePlaybackTick();
            diagnostics = app.motionDiagnostics();
            performance = app.performanceDiagnostics();

            testCase.verifyTrue(diagnostics.Playing);
            testCase.verifyLessThanOrEqual(diagnostics.LookaheadCount, 1);
            testCase.verifyEqual(performance.Viewer.Motion.LookaheadLimit, 1);
            testCase.verifyLessThanOrEqual( ...
                performance.Viewer.TileDataCache.TotalBytes, ...
                performance.Viewer.TileDataCache.MaxBytes);
            testCase.verifyLessThanOrEqual( ...
                performance.Viewer.SampledGeometryCache.TotalBytes, ...
                performance.Viewer.SampledGeometryCache.MaxBytes);
            testCase.verifyGreaterThanOrEqual( ...
                performance.Counters.PointerMotionCallbacks, 2);
            testCase.verifyEqual(performance.Counters.MotionPlaybackTicks, 1);
            testCase.verifyEqual( ...
                performance.Timings.MotionFrameSwitchSeconds.Count, 1);
            testCase.verifyEqual(performance.Counters.MeshBuilds, 0);
        end
    end

    methods (Static, Access = private)
        function scene = makeScene()
            images = {uint8(ones(12, 13)), uint8(2 * ones(12, 13)), ...
                uint8(3 * ones(12, 13))};
            scene = ProjectionViewerHarness.createSceneFromImages( ...
                images, ["play-1.tif" "play-2.tif" "play-3.tif"], ...
                struct(RowStride=3, ColumnStride=3));
            for index = 1:3
                scene.layers(index).ViewId = "play-view-" + string(index);
                scene.layers(index).PassId = "play-pass";
                scene.layers(index).AcquisitionStartTime = index;
            end
            scene = ProjectionViewMetadata.ensureScene(scene);
        end

        function openAndStart(~)
            menu = findall(groot, "Tag", ...
                "ProjectionViewerLayerManagerMenuItem");
            menu(1).MenuSelectedFcn(menu(1), struct());
            drawnow
            layer = findall(groot, "Tag", ...
                "ProjectionViewerLayerManagerLayerDropDown");
            layer(1).Value = 1;
            layer(1).ValueChangedFcn(layer(1), struct(Value=1));
            mode = ProjectionViewerMotionPlaybackWorkflowTest.tagged( ...
                ProjectionViewerMotionPlaybackWorkflowTest.motionWindow(), ...
                "ProjectionViewerLayerManagerModeDropDown");
            mode.Value = "single";
            mode.ValueChangedFcn(mode, struct());
            drawnow
        end

        function firePlaybackTick()
            timers = timerfindall("Tag", ...
                "ProjectionViewerMotionPlaybackTimer");
            timerObject = timers(1);
            if string(timerObject.Running) == "on"
                stop(timerObject);
            end
            callback = timerObject.TimerFcn;
            callback(timerObject, struct());
            if isvalid(timerObject) && string(timerObject.Running) == "on"
                stop(timerObject);
            end
            drawnow
        end

        function stopPlaybackTimer()
            timers = timerfindall("Tag", ...
                "ProjectionViewerMotionPlaybackTimer");
            if ~isempty(timers) && string(timers(1).Running) == "on"
                stop(timers(1));
            end
        end

        function figureHandle = viewer()
            figures = findall(groot, "Type", "figure", ...
                "Name", "Sightline");
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

        function event = keyEvent(key)
            event = struct(Key=key, Modifier=strings(1, 0));
        end

        function closeRuntime()
            delete(findall(groot, "Type", "figure", ...
                "Name", "Sightline"));
            delete(findall(groot, "Tag", ...
                "ProjectionViewerLayerManagerFigure"));
            timers = timerfindall("Tag", ...
                "ProjectionViewerMotionPlaybackTimer");
            if ~isempty(timers)
                stop(timers);
                delete(timers);
            end
        end
    end
end
