classdef ProjectionViewerPerformanceTest < matlab.unittest.TestCase
    %ProjectionViewerPerformanceTest Viewer instrumentation integration tests.

    methods (TestClassSetup)
        function addProjectPaths(testCase)
            projectRoot = fileparts(fileparts(mfilename("fullpath")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(projectRoot, "src")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(projectRoot, "scripts")));
        end
    end

    methods (Test)
        function testLaunchDiagnosticsReportRuntimeWork(testCase)
            scene = ProjectionViewerPerformanceTest.makeScene();
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow

            diagnostics = app.performanceDiagnostics();

            testCase.verifyEqual(diagnostics.Format, ...
                "ProjectionViewerPerformanceDiagnostics");
            testCase.verifyEqual(diagnostics.Version, 1);
            testCase.verifyGreaterThan(diagnostics.Counters.MeshBuilds, 0);
            testCase.verifyGreaterThan(diagnostics.Counters.SurfaceCreations, 0);
            testCase.verifyEqual(diagnostics.Viewer.LayerCount, 1);
            testCase.verifyEqual(diagnostics.Viewer.ImageSizes, [4 5 3]);
            testCase.verifyEqual(diagnostics.Viewer.VisibleSurfaceCount, 1);
            testCase.verifyGreaterThan( ...
                diagnostics.Viewer.VisibleTextureBytes, 0);
            testCase.verifyFalse( ...
                diagnostics.Viewer.AlignmentControlsCreated);
            testCase.verifyEqual(diagnostics.Viewer.AlignmentTableCount, 0);
            testCase.verifyEqual( ...
                diagnostics.Counters.AlignmentUiCreations, 0);
        end

        function testResetDoesNotChangeViewerState(testCase)
            scene = ProjectionViewerPerformanceTest.makeScene();
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow
            stateBefore = app.exportState();

            app.resetPerformanceDiagnostics();
            diagnostics = app.performanceDiagnostics();
            stateAfter = app.exportState();

            testCase.verifyEqual(diagnostics.Counters.FrameRequests, 0);
            testCase.verifyEqual(diagnostics.Counters.MeshBuilds, 0);
            testCase.verifyEqual(diagnostics.Counters.SurfaceCreations, 0);
            testCase.verifyEqual(stateAfter, stateBefore);
        end

        function testAlphaMetricsExcludeGeometryAndSurfaceWork(testCase)
            scene = ProjectionViewerPerformanceTest.makeScene();
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow
            fig = findall(groot, "Type", "figure", ...
                "Name", "Projection Viewer Prototype");
            alphaSlider = ProjectionViewerPerformanceTest.findSlider(fig, 5);
            app.resetPerformanceDiagnostics();

            alphaSlider.ValueChangingFcn(alphaSlider, struct(Value=0.5));
            diagnostics = app.performanceDiagnostics();

            testCase.verifyEqual(diagnostics.Counters.FrameRequests, 1);
            testCase.verifyEqual(diagnostics.Counters.RenderedFrames, 1);
            testCase.verifyEqual(diagnostics.Counters.MeshBuilds, 0);
            testCase.verifyEqual(diagnostics.Counters.SurfaceCreations, 0);
            testCase.verifyEqual(diagnostics.Counters.SurfaceDeletions, 0);
            testCase.verifyEqual(diagnostics.Timings.AlphaSeconds.Count, 1);
        end

        function testRapidAlphaRequestsCoalesceAndReleaseIsExact(testCase)
            scene = ProjectionViewerPerformanceTest.makeScene();
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow
            fig = findall(groot, "Type", "figure", ...
                "Name", "Projection Viewer Prototype");
            alphaSlider = ProjectionViewerPerformanceTest.findSlider(fig, 5);
            surfaceHandle = findall(fig, "Type", "surface", ...
                "Tag", "ProjectionViewerLayerSurface");
            app.configurePreviewBudget(struct( ...
                AlphaPreviewMinIntervalSeconds=10));
            app.resetPerformanceDiagnostics();

            alphaSlider.ValueChangingFcn(alphaSlider, struct(Value=0.8));
            alphaSlider.ValueChangingFcn(alphaSlider, struct(Value=0.6));
            alphaSlider.ValueChangingFcn(alphaSlider, struct(Value=0.4));
            activeDiagnostics = app.performanceDiagnostics();
            activeState = app.exportState();

            testCase.verifyEqual(activeDiagnostics.Counters.AlphaRequests, 3);
            testCase.verifyEqual( ...
                activeDiagnostics.Counters.AlphaCoalescedRequests, 2);
            testCase.verifyEqual(activeDiagnostics.Counters.RenderedFrames, 1);
            testCase.verifyEqual(activeDiagnostics.Counters.MeshBuilds, 0);
            testCase.verifyEqual(activeDiagnostics.Counters.TileRefreshes, 0);
            testCase.verifyEqual(activeState.Layers.Alpha, 0.4);
            testCase.verifyEqual(surfaceHandle.FaceAlpha, 0.8);
            testCase.verifyTrue( ...
                activeDiagnostics.Viewer.PendingAlphaMask);

            alphaSlider.Value = 0.4;
            alphaSlider.ValueChangedFcn(alphaSlider, struct());
            settledDiagnostics = app.performanceDiagnostics();

            testCase.verifyEqual(surfaceHandle.FaceAlpha, 0.4);
            testCase.verifyFalse( ...
                settledDiagnostics.Viewer.PendingAlphaMask);
            testCase.verifyEqual( ...
                settledDiagnostics.Counters.AlphaFinalizations, 1);
            testCase.verifyEqual(settledDiagnostics.Counters.RenderedFrames, 2);
        end

        function testExactZeroAlphaHidesAndPositiveAlphaRestoresSurface(testCase)
            scene = ProjectionViewerPerformanceTest.makeScene();
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow
            fig = findall(groot, "Type", "figure", ...
                "Name", "Projection Viewer Prototype");
            alphaSlider = ProjectionViewerPerformanceTest.findSlider(fig, 5);
            surfaceHandle = findall(fig, "Type", "surface", ...
                "Tag", "ProjectionViewerLayerSurface");
            app.resetPerformanceDiagnostics();

            alphaSlider.Value = 0;
            alphaSlider.ValueChangedFcn(alphaSlider, struct());
            zeroState = app.exportState();
            testCase.verifyEqual(string(surfaceHandle.Visible), "off");
            testCase.verifyTrue(zeroState.Layers.Visible);
            testCase.verifyEqual(zeroState.Layers.Alpha, 0);

            alphaSlider.Value = 0.5;
            alphaSlider.ValueChangedFcn(alphaSlider, struct());
            diagnostics = app.performanceDiagnostics();

            testCase.verifyEqual(string(surfaceHandle.Visible), "on");
            testCase.verifyEqual(surfaceHandle.FaceAlpha, 0.5);
            testCase.verifyEqual( ...
                diagnostics.Counters.AlphaVisibilityTransitions, 2);
            testCase.verifyEqual(diagnostics.Counters.MeshBuilds, 0);
            testCase.verifyEqual(diagnostics.Counters.TileRefreshes, 0);
        end

        function testCrosshairMotionOnlyUpdatesStableLineGeometry(testCase)
            scene = ProjectionViewerPerformanceTest.makeScene();
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow
            fig = findall(groot, "Type", "figure", ...
                "Name", "Projection Viewer Prototype");
            ax = findall(fig, "Type", "axes");
            menuItem = findall(fig, ...
                "Tag", "ProjectionViewerCrosshairMenuItem");
            fig.CurrentPoint = ProjectionViewerPerformanceTest.axesCenter(ax);
            menuItem.MenuSelectedFcn(menuItem, struct());
            horizontal = findall(fig, ...
                "Tag", "ProjectionViewerCrosshairHorizontal");
            vertical = findall(fig, ...
                "Tag", "ProjectionViewerCrosshairVertical");
            app.resetPerformanceDiagnostics();

            fig.CurrentPoint = fig.CurrentPoint + [4 3];
            fig.WindowButtonMotionFcn(fig, struct());
            horizontalAfter = findall(fig, ...
                "Tag", "ProjectionViewerCrosshairHorizontal");
            verticalAfter = findall(fig, ...
                "Tag", "ProjectionViewerCrosshairVertical");
            diagnostics = app.performanceDiagnostics();

            testCase.verifyEqual(horizontalAfter, horizontal);
            testCase.verifyEqual(verticalAfter, vertical);
            testCase.verifyEqual(diagnostics.Counters.PointerMotionCallbacks, 1);
            testCase.verifyEqual(diagnostics.Counters.CrosshairGeometryUpdates, 1);
            testCase.verifyEqual(diagnostics.Counters.OverlayRestacks, 0);
            testCase.verifyEqual(diagnostics.Counters.MeshBuilds, 0);
            testCase.verifyEqual(diagnostics.Counters.TileRefreshes, 0);
            testCase.verifyEqual(diagnostics.Counters.SurfaceCreations, 0);
            testCase.verifyEqual(diagnostics.Counters.SurfaceDeletions, 0);
        end

        function testCrosshairOutsideAxesDoesNotRepeatGraphicsUpdates(testCase)
            scene = ProjectionViewerPerformanceTest.makeScene();
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow
            fig = findall(groot, "Type", "figure", ...
                "Name", "Projection Viewer Prototype");
            menuItem = findall(fig, ...
                "Tag", "ProjectionViewerCrosshairMenuItem");
            testCase.verifyEmpty(fig.WindowButtonMotionFcn);
            menuItem.MenuSelectedFcn(menuItem, struct());
            testCase.verifyNotEmpty(fig.WindowButtonMotionFcn);
            fig.CurrentPoint = [0 0];
            fig.WindowButtonMotionFcn(fig, struct());
            app.resetPerformanceDiagnostics();

            fig.WindowButtonMotionFcn(fig, struct());
            fig.WindowButtonMotionFcn(fig, struct());
            diagnostics = app.performanceDiagnostics();
            menuItem.MenuSelectedFcn(menuItem, struct());

            testCase.verifyEqual(diagnostics.Counters.CrosshairGeometryUpdates, 0);
            testCase.verifyEqual(diagnostics.Counters.CrosshairVisibilityUpdates, 0);
            testCase.verifyEmpty(fig.WindowButtonMotionFcn);
        end

        function testPanTemporarilyActivatesPointerMotionCallback(testCase)
            scene = ProjectionViewerPerformanceTest.makeScene();
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow
            fig = findall(groot, "Type", "figure", ...
                "Name", "Projection Viewer Prototype");
            ax = findall(fig, "Type", "axes");
            fig.SelectionType = "normal";
            fig.CurrentPoint = ProjectionViewerPerformanceTest.axesCenter(ax);

            fig.WindowButtonDownFcn(fig, struct());
            activeCallback = fig.WindowButtonMotionFcn;
            fig.WindowButtonUpFcn(fig, struct());

            testCase.verifyNotEmpty(activeCallback);
            testCase.verifyEmpty(fig.WindowButtonMotionFcn);
        end

        function testRapidZoomDefersAndCoalescesTileReconciliation(testCase)
            scene = ProjectionViewerPerformanceTest.makeTiledScene();
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow
            fig = findall(groot, "Type", "figure", ...
                "Name", "Projection Viewer Prototype");
            ax = findall(fig, "Type", "axes");
            fig.CurrentPoint = ProjectionViewerPerformanceTest.axesCenter(ax);
            initialAngle = ax.CameraViewAngle;
            app.resetPerformanceDiagnostics();

            fig.WindowScrollWheelFcn(fig, struct(VerticalScrollCount=-1));
            fig.WindowScrollWheelFcn(fig, struct(VerticalScrollCount=-1));
            fig.WindowScrollWheelFcn(fig, struct(VerticalScrollCount=-1));
            activeDiagnostics = app.performanceDiagnostics();

            testCase.verifyEqual(activeDiagnostics.Counters.TileRefreshes, 0);
            testCase.verifyEqual(activeDiagnostics.Counters.MeshBuilds, 0);
            testCase.verifyEqual(activeDiagnostics.Counters.SurfaceCreations, 0);
            testCase.verifyEqual(activeDiagnostics.Counters.SurfaceDeletions, 0);
            testCase.verifyEqual( ...
                activeDiagnostics.Counters.CameraScheduleRequests, 3);
            testCase.verifyEqual(activeDiagnostics.Counters.CoalescedRequests, 2);
            testCase.verifyTrue(activeDiagnostics.Viewer.CameraReconcilePending);
            expectedAngle = initialAngle / 1.12 ^ 3;
            testCase.verifyEqual(ax.CameraViewAngle, expectedAngle, ...
                AbsTol=1e-10);

            app.flushPreviewUpdates();
            settledDiagnostics = app.performanceDiagnostics();

            testCase.verifyEqual(settledDiagnostics.Counters.TileRefreshes, 1);
            testCase.verifyEqual( ...
                settledDiagnostics.Counters.CameraReconciliations, 1);
            testCase.verifyFalse(settledDiagnostics.Viewer.CameraReconcilePending);
            testCase.verifyEqual( ...
                settledDiagnostics.Counters.BlankPreviewTransitions, 0);
        end

        function testTwistChangingAvoidsActiveTileAndMeshWork(testCase)
            scene = ProjectionViewerPerformanceTest.makeTiledScene();
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow
            fig = findall(groot, "Type", "figure", ...
                "Name", "Projection Viewer Prototype");
            twistSlider = ProjectionViewerPerformanceTest.findSlider(fig, 4);
            app.resetPerformanceDiagnostics();

            twistSlider.ValueChangingFcn(twistSlider, struct(Value=2));
            twistSlider.ValueChangingFcn(twistSlider, struct(Value=4));
            activeDiagnostics = app.performanceDiagnostics();
            state = app.exportState();

            testCase.verifyEqual(activeDiagnostics.Counters.TileRefreshes, 0);
            testCase.verifyEqual(activeDiagnostics.Counters.MeshBuilds, 0);
            testCase.verifyEqual(activeDiagnostics.Counters.SurfaceCreations, 0);
            testCase.verifyEqual(activeDiagnostics.Counters.SurfaceDeletions, 0);
            testCase.verifyEqual(activeDiagnostics.Counters.CoalescedRequests, 1);
            testCase.verifyEqual(state.View.TwistDegrees, 4, ...
                AbsTol=1e-12);

            app.flushPreviewUpdates();
            settledDiagnostics = app.performanceDiagnostics();

            testCase.verifyEqual( ...
                settledDiagnostics.Counters.CameraReconciliations, 1);
            testCase.verifyFalse(settledDiagnostics.Viewer.CameraReconcilePending);
        end

        function testCameraTimerReconcilesLatestStateAfterQuietPeriod(testCase)
            scene = ProjectionViewerPerformanceTest.makeTiledScene();
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow
            fig = findall(groot, "Type", "figure", ...
                "Name", "Projection Viewer Prototype");
            ax = findall(fig, "Type", "axes");
            fig.CurrentPoint = ProjectionViewerPerformanceTest.axesCenter(ax);
            app.resetPerformanceDiagnostics();

            fig.WindowScrollWheelFcn(fig, struct(VerticalScrollCount=1));
            pause(0.18);
            drawnow
            diagnostics = app.performanceDiagnostics();

            testCase.verifyEqual(diagnostics.Counters.CameraScheduleRequests, 1);
            testCase.verifyEqual(diagnostics.Counters.CameraReconciliations, 1);
            testCase.verifyEqual(diagnostics.Counters.TileRefreshes, 1);
            testCase.verifyFalse(diagnostics.Viewer.CameraReconcilePending);
        end

        function testSettledCameraRefreshUsesCachedVectorizedGeometry(testCase)
            scene = ProjectionViewerPerformanceTest.makeTiledScene();
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow
            fig = findall(groot, "Type", "figure", ...
                "Name", "Projection Viewer Prototype");
            ax = findall(fig, "Type", "axes");
            fig.CurrentPoint = ProjectionViewerPerformanceTest.axesCenter(ax);
            app.resetPerformanceDiagnostics();

            fig.WindowScrollWheelFcn(fig, struct(VerticalScrollCount=1));
            app.flushPreviewUpdates();
            diagnostics = app.performanceDiagnostics();

            testCase.verifyEqual(diagnostics.Counters.MeshBuilds, 0);
            testCase.verifyEqual(diagnostics.Counters.GeometryCacheMisses, 0);
            testCase.verifyGreaterThan( ...
                diagnostics.Counters.GeometryCacheHits, 0);
            testCase.verifyEqual(diagnostics.Counters.CameraStateQueries, 1);
            testCase.verifyGreaterThan( ...
                diagnostics.Counters.VectorizedTileTests, 0);
            testCase.verifyGreaterThan( ...
                diagnostics.Viewer.PredictedCandidateCounts, 0);
            testCase.verifyGreaterThan( ...
                diagnostics.Viewer.PredictedTextureBytes, 0);
            testCase.verifySize( ...
                diagnostics.Viewer.LevelTexelsPerScreenPixel, [1 2]);
        end

        function testHiddenTiledLayerIsExcludedFromCameraRefresh(testCase)
            scene = ProjectionViewerPerformanceTest.makeTwoTiledScene();
            scene.layers(1).Visible = false;
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow
            fig = findall(groot, "Type", "figure", ...
                "Name", "Projection Viewer Prototype");
            ax = findall(fig, "Type", "axes");
            fig.CurrentPoint = ProjectionViewerPerformanceTest.axesCenter(ax);
            app.resetPerformanceDiagnostics();

            fig.WindowScrollWheelFcn(fig, struct(VerticalScrollCount=1));
            app.flushPreviewUpdates();
            diagnostics = app.performanceDiagnostics();

            testCase.verifyEqual( ...
                diagnostics.Viewer.PredictedCandidateCounts(1), 0);
            testCase.verifyGreaterThan( ...
                diagnostics.Viewer.PredictedCandidateCounts(2), 0);
            testCase.verifyEqual(diagnostics.Counters.CameraStateQueries, 1);
            testCase.verifyEqual(diagnostics.Counters.MeshBuilds, 0);
        end

        function testGeometryCacheInvalidatesAfterProjectionChange(testCase)
            scene = ProjectionViewerPerformanceTest.makeTiledScene();
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow
            fig = findall(groot, "Type", "figure", ...
                "Name", "Projection Viewer Prototype");
            ax = findall(fig, "Type", "axes");
            tipSlider = ProjectionViewerPerformanceTest.findSlider(fig, 2);
            fig.CurrentPoint = ProjectionViewerPerformanceTest.axesCenter(ax);
            tipSlider.Value = 2;
            tipSlider.ValueChangedFcn(tipSlider, struct());
            app.resetPerformanceDiagnostics();

            fig.WindowScrollWheelFcn(fig, struct(VerticalScrollCount=1));
            app.flushPreviewUpdates();
            invalidatedDiagnostics = app.performanceDiagnostics();
            app.resetPerformanceDiagnostics();
            fig.WindowScrollWheelFcn(fig, struct(VerticalScrollCount=-1));
            app.flushPreviewUpdates();
            cachedDiagnostics = app.performanceDiagnostics();

            testCase.verifyEqual( ...
                invalidatedDiagnostics.Counters.GeometryCacheMisses, 1);
            testCase.verifyGreaterThan( ...
                invalidatedDiagnostics.Counters.MeshBuilds, 0);
            testCase.verifyEqual(cachedDiagnostics.Counters.GeometryCacheMisses, 0);
            testCase.verifyEqual(cachedDiagnostics.Counters.MeshBuilds, 0);
            testCase.verifyGreaterThan( ...
                cachedDiagnostics.Counters.GeometryCacheHits, 0);
        end

        function testDisplayTileSizeDoesNotChangeBackendInputs(testCase)
            scene = ProjectionViewerPerformanceTest.makeTiledScene();
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow
            stateBefore = app.exportState();
            jobBefore = app.exportBackendJob(struct(RenderOptions=struct( ...
                OutputSize=[4 5])));

            options = app.configurePreviewTiling(struct(TileSize=512));
            diagnostics = app.performanceDiagnostics();
            stateAfter = app.exportState();
            jobAfter = app.exportBackendJob(struct(RenderOptions=struct( ...
                OutputSize=[4 5])));

            testCase.verifyEqual(options.TileSize, 512);
            testCase.verifyEqual(diagnostics.Viewer.DisplayTileSize, 512);
            testCase.verifyEqual(stateAfter, stateBefore);
            testCase.verifyEqual(jobAfter.Scene.layers.Image, ...
                jobBefore.Scene.layers.Image);
            testCase.verifyEqual(jobAfter.Scene.layers.Image, scene.layers.Image);
        end

        function testGeometryCacheInvalidatesForOpkAndProjectionOffset(testCase)
            scene = ProjectionViewerPerformanceTest.makeTiledScene();
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow
            fig = findall(groot, "Type", "figure", ...
                "Name", "Projection Viewer Prototype");
            ax = findall(fig, "Type", "axes");
            fig.CurrentPoint = ProjectionViewerPerformanceTest.axesCenter(ax);

            app.resetPerformanceDiagnostics();
            fig.WindowKeyPressFcn(fig, struct(Key="i", Modifier="i"));
            opkDiagnostics = app.performanceDiagnostics();
            app.resetPerformanceDiagnostics();
            fig.WindowScrollWheelFcn(fig, struct(VerticalScrollCount=1));
            app.flushPreviewUpdates();
            cachedOpkDiagnostics = app.performanceDiagnostics();

            app.resetPerformanceDiagnostics();
            fig.WindowKeyPressFcn(fig, struct(Key="w", Modifier="w"));
            offsetDiagnostics = app.performanceDiagnostics();
            app.resetPerformanceDiagnostics();
            fig.WindowScrollWheelFcn(fig, struct(VerticalScrollCount=-1));
            app.flushPreviewUpdates();
            reconciledOffsetDiagnostics = app.performanceDiagnostics();
            app.resetPerformanceDiagnostics();
            fig.WindowScrollWheelFcn(fig, struct(VerticalScrollCount=-1));
            app.flushPreviewUpdates();
            cachedOffsetDiagnostics = app.performanceDiagnostics();

            testCase.verifyEqual(opkDiagnostics.Counters.GeometryCacheMisses, 1);
            testCase.verifyGreaterThan(opkDiagnostics.Counters.MeshBuilds, 0);
            testCase.verifyEqual(opkDiagnostics.Counters.SampleFcnCalls, 0);
            testCase.verifyEqual( ...
                cachedOpkDiagnostics.Counters.GeometryCacheMisses, 0);
            testCase.verifyEqual(cachedOpkDiagnostics.Counters.MeshBuilds, 0);
            testCase.verifyEqual( ...
                offsetDiagnostics.Counters.RigidProjectionTranslations, 1);
            testCase.verifyEqual(offsetDiagnostics.Counters.MeshBuilds, 0);
            testCase.verifyEqual(offsetDiagnostics.Counters.SampleFcnCalls, 0);
            testCase.verifyEqual( ...
                offsetDiagnostics.Counters.LayerGeometryRefreshes, 0);
            testCase.verifyEqual( ...
                reconciledOffsetDiagnostics.Counters.GeometryCacheMisses, 1);
            testCase.verifyEqual( ...
                reconciledOffsetDiagnostics.Counters.SampleFcnCalls, 0);
            testCase.verifyEqual( ...
                cachedOffsetDiagnostics.Counters.GeometryCacheMisses, 0);
            testCase.verifyEqual(cachedOffsetDiagnostics.Counters.MeshBuilds, 0);
        end

        function testSelectedOpkRefreshTargetsOneLayerAndReusesSamples(testCase)
            scene = ProjectionViewerPerformanceTest.makeTwoScene();
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow
            fig = findall(groot, "Type", "figure", ...
                "Name", "Projection Viewer Prototype");
            app.resetPerformanceDiagnostics();

            fig.WindowKeyPressFcn(fig, struct(Key="i", Modifier="i"));
            diagnostics = app.performanceDiagnostics();

            testCase.verifyEqual( ...
                diagnostics.Counters.LayerGeometryRefreshes, 1);
            testCase.verifyEqual(diagnostics.Counters.MeshBuilds, 1);
            testCase.verifyEqual(diagnostics.Counters.SampleFcnCalls, 0);
            testCase.verifyGreaterThanOrEqual( ...
                diagnostics.Counters.SampleCacheHits, 1);
        end

        function testWasdUsesExactRigidSelectedLayerTranslation(testCase)
            scene = ProjectionViewerPerformanceTest.makeTwoScene();
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow
            fig = findall(groot, "Type", "figure", ...
                "Name", "Projection Viewer Prototype");
            sampleRows = [1 4];
            sampleColumns = [1 5];
            [originsBefore, vectorsBefore] = ...
                scene.layers(2).SourceGeometry.SampleFcn( ...
                sampleRows, sampleColumns);
            app.resetPerformanceDiagnostics();

            fig.WindowKeyPressFcn(fig, struct(Key="w", Modifier="w"));
            diagnostics = app.performanceDiagnostics();
            job = app.exportBackendJob(struct(RenderOptions=struct( ...
                OutputSize=[4 5])));
            [originsAfter, vectorsAfter] = ...
                job.Scene.layers(2).SourceGeometry.SampleFcn( ...
                sampleRows, sampleColumns);

            testCase.verifyEqual( ...
                diagnostics.Counters.RigidProjectionTranslations, 1);
            testCase.verifyEqual( ...
                diagnostics.Counters.LayerGeometryRefreshes, 0);
            testCase.verifyEqual(diagnostics.Counters.MeshBuilds, 0);
            testCase.verifyEqual(diagnostics.Counters.SampleFcnCalls, 0);
            testCase.verifyEqual(originsAfter, originsBefore);
            testCase.verifyEqual(vectorsAfter, vectorsBefore);
            testCase.verifyEqual( ...
                job.Scene.layers(1).ProjectionOffsetMeters, [0; 0]);
            testCase.verifyNotEqual( ...
                job.Scene.layers(2).ProjectionOffsetMeters, [0; 0]);
        end

        function testSharedTipRefreshesEveryLayerUsingCachedSamples(testCase)
            scene = ProjectionViewerPerformanceTest.makeTwoScene();
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow
            fig = findall(groot, "Type", "figure", ...
                "Name", "Projection Viewer Prototype");
            tipSlider = ProjectionViewerPerformanceTest.findSlider(fig, 2);
            tipSlider.Value = 1;
            app.resetPerformanceDiagnostics();

            tipSlider.ValueChangedFcn(tipSlider, struct());
            diagnostics = app.performanceDiagnostics();

            testCase.verifyEqual( ...
                diagnostics.Counters.LayerGeometryRefreshes, 2);
            testCase.verifyEqual(diagnostics.Counters.MeshBuilds, 2);
            testCase.verifyEqual(diagnostics.Counters.SampleFcnCalls, 0);
            testCase.verifyGreaterThanOrEqual( ...
                diagnostics.Counters.SampleCacheHits, 2);
        end

        function testViewportShiftPreservesOverlapAndReusesPool(testCase)
            scene = ProjectionViewerPerformanceTest.makeReusableTiledScene();
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow
            app.configurePreviewTiling(struct(TileSize=512));
            drawnow
            fig = findall(groot, "Type", "figure", ...
                "Name", "Projection Viewer Prototype");
            ax = findall(fig, "Type", "axes");
            ax.CameraViewAngle = 0.5;
            center = ProjectionViewerPerformanceTest.axesCenter(ax);
            fig.CurrentPoint = center;
            fig.WindowScrollWheelFcn(fig, struct(VerticalScrollCount=0));
            app.flushPreviewUpdates();
            initialSurfaces = ProjectionViewerPerformanceTest.activeTileSurfaces(ax);
            app.resetPerformanceDiagnostics();

            ProjectionViewerPerformanceTest.dragCamera(fig, center, [-700 0]);
            app.flushPreviewUpdates();
            shiftedSurfaces = ProjectionViewerPerformanceTest.activeTileSurfaces(ax);
            shiftedDiagnostics = app.performanceDiagnostics();
            ProjectionViewerPerformanceTest.dragCamera(fig, center, [700 0]);
            app.flushPreviewUpdates();
            returnedDiagnostics = app.performanceDiagnostics();

            testCase.verifyTrue( ...
                ProjectionViewerPerformanceTest.commonTileHandlesMatch( ...
                initialSurfaces, shiftedSurfaces));
            testCase.verifyGreaterThan( ...
                shiftedDiagnostics.Counters.SurfaceHandleReuses, 0);
            testCase.verifyEqual(shiftedDiagnostics.Counters.SurfaceCreations, 0);
            testCase.verifyEqual(shiftedDiagnostics.Counters.TexturePreparations, 0);
            testCase.verifyEqual(shiftedDiagnostics.Counters.TextureUploadBytes, 0);
            testCase.verifyGreaterThan( ...
                shiftedDiagnostics.Counters.SurfacePoolRetirements, 0);
            testCase.verifyGreaterThan(returnedDiagnostics.Counters.SurfacePoolHits, 0);
            testCase.verifyGreaterThan(returnedDiagnostics.Counters.TileCacheHits, 0);
            testCase.verifyEqual(returnedDiagnostics.Counters.TexturePreparations, 0);
            testCase.verifyGreaterThan( ...
                returnedDiagnostics.Counters.TextureUploadBytes, 0);
            testCase.verifyLessThanOrEqual( ...
                returnedDiagnostics.Viewer.TileDataCache.TotalBytes, ...
                returnedDiagnostics.Viewer.TileDataCache.MaxBytes);
        end

        function testPreviewCacheAndSurfacePoolBudgetsAreConfigurable(testCase)
            scene = ProjectionViewerPerformanceTest.makeTiledScene();
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow

            options = app.configurePreviewCache( ...
                struct(MaxBytes=1024, SampleMaxBytes=2048, ...
                SurfacePoolMaxCount=2));
            app.configurePreviewTiling(struct(TileSize=512));
            diagnostics = app.performanceDiagnostics();

            testCase.verifyEqual(options.MaxBytes, 1024);
            testCase.verifyEqual(options.SampleMaxBytes, 2048);
            testCase.verifyEqual(options.SurfacePoolMaxCount, 2);
            testCase.verifyEqual(diagnostics.Viewer.TileDataCache.MaxBytes, 1024);
            testCase.verifyEqual( ...
                diagnostics.Viewer.SampledGeometryCache.MaxBytes, 2048);
            testCase.verifyLessThanOrEqual( ...
                diagnostics.Viewer.TileDataCache.TotalBytes, 1024);
            testCase.verifyEqual(diagnostics.Viewer.SurfacePoolLimit, 2);
            testCase.verifyLessThanOrEqual( ...
                diagnostics.Viewer.SurfacePoolCount, 2);
        end

        function testGlobalPreviewBudgetCoarsensWithoutChangingState(testCase)
            scene = ProjectionViewerPerformanceTest.makeTwoReusableTiledScene();
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow
            app.configurePreviewTiling(struct(TileSize=256));
            app.configurePreviewBudget(struct( ...
                MaxVisibleSurfaces=192, ...
                MaxVisibleTextureBytes=512 * 1024^2, ...
                AutomaticTilePolicy=false));
            fig = findall(groot, "Type", "figure", ...
                "Name", "Projection Viewer Prototype");
            ax = findall(fig, "Type", "axes");
            ax.CameraViewAngle = 0.5;
            fig.CurrentPoint = ProjectionViewerPerformanceTest.axesCenter(ax);
            ProjectionViewerPerformanceTest.settleCameraPreview( ...
                app, fig, 8);
            unbudgetedDiagnostics = app.performanceDiagnostics();
            stateBefore = app.exportState();
            app.resetPerformanceDiagnostics();

            options = app.configurePreviewBudget(struct( ...
                MaxVisibleSurfaces=4, MaxVisibleTextureBytes=16 * 1024^2, ...
                TargetMaxTilesPerLayer=12, AutomaticTilePolicy=true));
            diagnostics = app.performanceDiagnostics();
            stateAfter = app.exportState();

            testCase.verifyEqual(options.MaxVisibleSurfaces, 4);
            testCase.verifyEqual(options.MaxVisibleTextureBytes, 16 * 1024^2);
            testCase.verifyEqual(stateAfter, stateBefore);
            testCase.verifyGreaterThan( ...
                unbudgetedDiagnostics.Viewer.VisibleTileSurfaceCount, 4);
            testCase.verifyLessThanOrEqual( ...
                diagnostics.Viewer.VisibleTileSurfaceCount, 4);
            testCase.verifyLessThanOrEqual( ...
                diagnostics.Viewer.VisibleTextureBytes, 16 * 1024^2);
            testCase.verifyEqual( ...
                diagnostics.Viewer.LayerSurfaceBudgets, [2 2]);
            testCase.verifyTrue(any( ...
                diagnostics.Viewer.BudgetLimitedLayerMask));
            testCase.verifyGreaterThan( ...
                diagnostics.Counters.BudgetLimitedLodSelections, 0);
        end

        function testLazyPyramidAndScalarTileReuseAvoidRgbExpansion(testCase)
            scene = ProjectionViewerPerformanceTest.makeReusableTiledScene();
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow
            app.configurePreviewTiling(struct(TileSize=512));
            diagnostics = app.performanceDiagnostics();
            fig = findall(groot, "Type", "figure", ...
                "Name", "Projection Viewer Prototype");
            surfaces = ProjectionViewerPerformanceTest.activeTileSurfaces( ...
                findall(fig, "Type", "axes"));

            testCase.verifyTrue(all(arrayfun( ...
                @(surfaceHandle) ismatrix(surfaceHandle.CData), surfaces)));
            testCase.verifyGreaterThan( ...
                diagnostics.Counters.ScalarTexturePreparations, 0);
            testCase.verifyEqual( ...
                diagnostics.Counters.RgbFallbackTexturePreparations, 0);
            testCase.verifyLessThan( ...
                diagnostics.Viewer.PyramidMaterializedLevelCounts, ...
                diagnostics.Viewer.PyramidLevelCounts);

            alphaBlendMenu = findall(fig, ...
                "Tag", "ProjectionViewerAlphaBlendMenuItem");
            app.resetPerformanceDiagnostics();
            alphaBlendMenu.MenuSelectedFcn(alphaBlendMenu, struct());
            repeatedDiagnostics = app.performanceDiagnostics();

            testCase.verifyEqual( ...
                repeatedDiagnostics.Counters.ScalarTexturePreparations, 0);
            testCase.verifyEqual( ...
                repeatedDiagnostics.Counters.TexturePreparations, 0);
            testCase.verifyGreaterThan( ...
                repeatedDiagnostics.Counters.TileCacheHits, 0);
        end

        function testMixedSingleAndRgbTiledLayersUseExplicitTexturePaths(testCase)
            scene = ProjectionViewerPerformanceTest.makeMixedTiledScene();
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow
            fig = findall(groot, "Type", "figure", ...
                "Name", "Projection Viewer Prototype");
            surfaces = ProjectionViewerPerformanceTest.activeTileSurfaces( ...
                findall(fig, "Type", "axes"));
            dimensions = arrayfun( ...
                @(surfaceHandle) ndims(surfaceHandle.CData), surfaces);
            diagnostics = app.performanceDiagnostics();

            testCase.verifyTrue(any(dimensions == 2));
            testCase.verifyTrue(any(dimensions == 3));
            testCase.verifyGreaterThan( ...
                diagnostics.Counters.ScalarTexturePreparations, 0);
            testCase.verifyGreaterThan( ...
                diagnostics.Counters.RgbFallbackTexturePreparations, 0);
        end

        function testFileBackedPreviewKeepsBackendFullImage(testCase)
            imageData = zeros(2001, 2001, "uint8");
            imagePath = string(tempname) + ".tif";
            imwrite(imageData, imagePath);
            testCase.addTeardown(@() delete(imagePath));
            scene = ProjectionViewerHarness.createDefaultScene( ...
                imagePath, struct(RowStride=250, ColumnStride=250, ...
                DisplayTextureMaxPixels=10000));
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow

            diagnostics = app.performanceDiagnostics();
            job = app.exportBackendJob(struct(RenderOptions=struct( ...
                OutputSize=[4 5])));

            testCase.verifyEqual( ...
                diagnostics.Viewer.PyramidSourceModes, "file");
            testCase.verifyLessThan( ...
                diagnostics.Viewer.PyramidMaterializedLevelCounts, ...
                diagnostics.Viewer.PyramidLevelCounts);
            testCase.verifyEqual(job.Scene.layers.Image, imageData);
        end

        function testEvaluationRunsAllScenariosAndRestoresState(testCase)
            options = struct(SyntheticImageSize=[64 64], ...
                SyntheticLayerCount=1, SyntheticPattern="constant", ...
                DisplayTileSize=512, ScenarioIterations=2, ...
                UseSynthetic=true, WriteArtifacts=false);

            [summary, app] = viewer_performance_evaluation(options);
            testCase.addTeardown(@() delete(app));

            testCase.verifyEqual([summary.Scenarios.Name], ...
                ["alpha", "crosshair", "twist", "pan", "zoomSlow", ...
                "zoomFast", "zoomReverse", "wasd", "opk"]);
            testCase.verifyTrue(summary.FinalStateMatchesInitial);
            testCase.verifyEqual(summary.DisplayTileSize, 512);
            testCase.verifyEqual(numel(summary.Fixture.ImageSizes), 1);
            testCase.verifyEqual(summary.Fixture.Pattern, "constant");
            testCase.verifyEqual( ...
                summary.Scenarios(1).Diagnostics.Counters.FrameRequests, 2);
            testCase.verifyGreaterThanOrEqual( ...
                summary.Scenarios(2).Diagnostics.Counters.CrosshairUpdates, 2);
            testCase.verifyEqual( ...
                summary.Scenarios(3).Diagnostics.Counters.RenderedFrames, 2);
        end

        function testSurfaceConsolidationEvaluationUsesEqualTexelBudgets(testCase)
            summary = viewer_surface_consolidation_evaluation(struct( ...
                TileGrid=[2 2], TileSize=32, Iterations=2, ...
                FigureSize=[400 300], WriteArtifacts=false));

            testCase.verifyEqual([summary.Records.SurfaceCount], [4 1]);
            testCase.verifyEqual( ...
                summary.Records(1).TextureBytes, ...
                summary.Records(2).TextureBytes);
            testCase.verifyGreaterThan( ...
                [summary.Records.MedianSeconds], [0 0]);
            testCase.verifyGreaterThan(summary.MedianSpeedup, 0);
            testCase.verifyNotEmpty(summary.Limitations);
        end

        function testRasterPreviewEvaluationExercisesBothGraphicsPaths(testCase)
            summary = viewer_raster_preview_evaluation(struct( ...
                ImageSize=[96 128], OutputSize=[72 96], ...
                FigureSize=[220 180], Iterations=2, ...
                WriteArtifacts=false));

            testCase.verifyEqual(summary.Format, ...
                "ProjectionViewerRasterPreviewEvaluation");
            testCase.verifyEqual(summary.Surface.Memory.ObjectCount, 2);
            testCase.verifyEqual(summary.Raster.Memory.ObjectCount, 1);
            testCase.verifyTrue(summary.Raster.CpuComplete);
            testCase.verifyEqual(summary.Decision, "retainOptional");
            testCase.verifyGreaterThan( ...
                summary.Visual.CommonValidPixelCount, 0);
            testCase.verifyGreaterThan( ...
                summary.Surface.Timings.Alpha.MedianSeconds, 0);
            testCase.verifyGreaterThan( ...
                summary.Raster.Timings.Visibility.MedianSeconds, 0);
            testCase.verifyGreaterThan( ...
                summary.Raster.Timings.Twist.MedianSeconds, 0);
            testCase.verifyGreaterThan( ...
                summary.Surface.Timings.Crosshair.MedianSeconds, 0);
        end
    end

    methods (Static, Access = private)
        function scene = makeScene()
            imageData = uint8(reshape(1:60, 4, 5, 3));
            scene = ProjectionViewerHarness.createSceneFromImage( ...
                imageData, "synthetic.tif", ...
                struct(RowStride=2, ColumnStride=2));
        end

        function scene = makeTiledScene()
            imageData = zeros(2001, 2001, "uint8");
            options = struct(GSD=0.01, NominalRange=1e6, ...
                PlatformStepMeters=0.01, RowStride=250, ...
                ColumnStride=250, DisplayTextureMaxPixels=10000);
            scene = ProjectionViewerHarness.createSceneFromImage( ...
                imageData, "large.tif", options);
        end

        function scene = makeTwoScene()
            imageData = uint8(reshape(1:60, 4, 5, 3));
            options = struct(RowStride=2, ColumnStride=2);
            scene = ProjectionViewerHarness.createSceneFromImages( ...
                {imageData, imageData}, ...
                ["synthetic_1.tif", "synthetic_2.tif"], options);
        end

        function scene = makeTwoTiledScene()
            imageData = zeros(2001, 2001, "uint8");
            options = struct(GSD=0.01, NominalRange=1e6, ...
                PlatformStepMeters=0.01, RowStride=250, ...
                ColumnStride=250, DisplayTextureMaxPixels=10000);
            scene = ProjectionViewerHarness.createSceneFromImages( ...
                {imageData, imageData}, ["large_1.tif", "large_2.tif"], ...
                options);
        end

        function scene = makeTwoReusableTiledScene()
            imageData = zeros(2001, 2001, "uint8");
            options = struct(GSD=0.01, NominalRange=1000, ...
                PlatformStepMeters=0.01, RowStride=250, ...
                ColumnStride=250, DisplayTextureMaxPixels=10000);
            scene = ProjectionViewerHarness.createSceneFromImages( ...
                {imageData, imageData}, ...
                ["reusable_1.tif", "reusable_2.tif"], options);
        end

        function scene = makeMixedTiledScene()
            singleBand = zeros(2001, 2001, "uint8");
            rgb = zeros(2001, 2001, 3, "uint8");
            options = struct(GSD=0.01, NominalRange=1000, ...
                PlatformStepMeters=0.01, RowStride=250, ...
                ColumnStride=250, DisplayTextureMaxPixels=10000);
            scene = ProjectionViewerHarness.createSceneFromImages( ...
                {singleBand, rgb}, ["single.tif", "rgb.tif"], options);
        end

        function scene = makeReusableTiledScene()
            imageData = zeros(2001, 2001, "uint8");
            options = struct(GSD=0.01, NominalRange=1000, ...
                PlatformStepMeters=0.01, RowStride=250, ...
                ColumnStride=250, DisplayTextureMaxPixels=10000);
            scene = ProjectionViewerHarness.createSceneFromImage( ...
                imageData, "reusable_large.tif", options);
        end

        function slider = findSlider(fig, column)
            sliders = findall(fig, "-isa", "matlab.ui.control.Slider");
            columns = arrayfun(@(value) value.Layout.Column, sliders);
            slider = sliders(columns == column);
        end

        function point = axesCenter(ax)
            position = ax.InnerPosition;
            point = position(1:2) + position(3:4) / 2;
        end

        function surfaces = activeTileSurfaces(ax)
            surfaces = findall(ax, "Type", "surface", ...
                "Tag", "ProjectionViewerPreviewTileSurface");
        end

        function dragCamera(fig, center, pixelDelta)
            fig.SelectionType = "normal";
            fig.CurrentPoint = center;
            fig.WindowButtonDownFcn(fig, struct());
            fig.CurrentPoint = center + pixelDelta;
            fig.WindowButtonMotionFcn(fig, struct());
            fig.WindowButtonUpFcn(fig, struct());
        end

        function tf = commonTileHandlesMatch(firstSurfaces, secondSurfaces)
            firstKeys = string(arrayfun( ...
                @(value) string(value.UserData), firstSurfaces));
            secondKeys = string(arrayfun( ...
                @(value) string(value.UserData), secondSurfaces));
            commonKeys = intersect(firstKeys, secondKeys);
            tf = ~isempty(commonKeys);
            for key = reshape(commonKeys, 1, [])
                firstHandle = firstSurfaces(firstKeys == key);
                secondHandle = secondSurfaces(secondKeys == key);
                tf = tf && isscalar(firstHandle) && isscalar(secondHandle) && ...
                    firstHandle == secondHandle;
            end
        end

        function settleCameraPreview(app, fig, iterationCount)
            for k = 1:iterationCount
                fig.WindowScrollWheelFcn( ...
                    fig, struct(VerticalScrollCount=0));
                app.flushPreviewUpdates();
            end
        end
    end
end
