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
    end
end
