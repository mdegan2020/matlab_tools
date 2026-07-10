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

        function testEvaluationRunsAllScenariosAndRestoresState(testCase)
            options = struct(SyntheticImageSize=[64 64], ...
                ScenarioIterations=2, UseSynthetic=true, ...
                WriteArtifacts=false);

            [summary, app] = viewer_performance_evaluation(options);
            testCase.addTeardown(@() delete(app));

            testCase.verifyEqual([summary.Scenarios.Name], ...
                ["alpha", "crosshair", "twist", "pan", "zoomSlow", ...
                "zoomFast", "zoomReverse", "wasd", "opk"]);
            testCase.verifyTrue(summary.FinalStateMatchesInitial);
            testCase.verifyEqual( ...
                summary.Scenarios(1).Diagnostics.Counters.FrameRequests, 2);
            testCase.verifyGreaterThanOrEqual( ...
                summary.Scenarios(2).Diagnostics.Counters.CrosshairUpdates, 2);
            testCase.verifyEqual( ...
                summary.Scenarios(3).Diagnostics.Counters.RenderedFrames, 2);
        end
    end

    methods (Static, Access = private)
        function scene = makeScene()
            imageData = uint8(reshape(1:60, 4, 5, 3));
            scene = ProjectionViewerHarness.createSceneFromImage( ...
                imageData, "synthetic.tif", ...
                struct(RowStride=2, ColumnStride=2));
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
    end
end
