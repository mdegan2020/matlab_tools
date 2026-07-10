classdef ProjectionViewerPerformanceMonitorTest < matlab.unittest.TestCase
    %ProjectionViewerPerformanceMonitorTest Tests bounded viewer metrics.

    methods (TestClassSetup)
        function addSourceToPath(testCase)
            projectRoot = fileparts(fileparts(mfilename("fullpath")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(projectRoot, "src")));
        end
    end

    methods (Test)
        function testSnapshotSummarizesBoundedSamples(testCase)
            monitor = ProjectionViewerPerformanceMonitor(3);
            monitor.increment("MeshBuilds", 2);
            monitor.recordTiming("FrameSeconds", 1);
            monitor.recordTiming("FrameSeconds", 2);
            monitor.recordTiming("FrameSeconds", 3);
            monitor.recordTiming("FrameSeconds", 4);

            snapshot = monitor.snapshot();

            testCase.verifyEqual(snapshot.Counters.MeshBuilds, 2);
            testCase.verifyEqual(snapshot.Timings.FrameSeconds.Count, 4);
            testCase.verifyEqual( ...
                snapshot.Timings.FrameSeconds.RetainedSampleCount, 3);
            testCase.verifyEqual( ...
                snapshot.Timings.FrameSeconds.TotalSeconds, 10, AbsTol=1e-12);
            testCase.verifyEqual( ...
                snapshot.Timings.FrameSeconds.MedianSeconds, 3, AbsTol=1e-12);
            testCase.verifyEqual( ...
                snapshot.Timings.FrameSeconds.P95Seconds, 4, AbsTol=1e-12);
            testCase.verifyEqual( ...
                snapshot.Timings.FrameSeconds.MaximumSeconds, 4, AbsTol=1e-12);
        end

        function testResetClearsMetrics(testCase)
            monitor = ProjectionViewerPerformanceMonitor();
            monitor.increment("SurfaceCreations");
            monitor.recordTiming("FrameSeconds", 0.01);

            monitor.reset();
            snapshot = monitor.snapshot();

            testCase.verifyEqual(snapshot.Counters.SurfaceCreations, 0);
            testCase.verifyEmpty(fieldnames(snapshot.Timings));
            testCase.verifyGreaterThanOrEqual(snapshot.ElapsedSeconds, 0);
        end

        function testInvalidCounterAmountErrors(testCase)
            monitor = ProjectionViewerPerformanceMonitor();

            testCase.verifyError(@() monitor.increment("MeshBuilds", -1), ...
                "ProjectionViewerPerformanceMonitor:invalidAmount");
        end
    end
end
