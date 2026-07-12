function plan = buildfile
%buildfile Build tasks for PlanarProjection.

plan = buildplan(localfunctions);
plan.DefaultTasks = "test";
end

function testTask(~)
%testTask Run the unit test suite.

runTests();
end

function testCoreGeometryStateTask(~)
%testCoreGeometryStateTask Run core geometry and state tests.

runTestGroup("coreGeometryState");
end

function testAlignmentTask(~)
%testAlignmentTask Run sparse and network alignment tests.

runTestGroup("alignment");
end

function testBackendSurfaceTask(~)
%testBackendSurfaceTask Run backend and surface tests.

runTestGroup("backendSurface");
end

function testViewerUiWorkflowsTask(~)
%testViewerUiWorkflowsTask Run viewer UI workflow tests.

runTestGroup("viewerUiWorkflows");
end

function testViewerPerformancePrecisionTask(~)
%testViewerPerformancePrecisionTask Run viewer performance/precision tests.

runTestGroup("viewerPerformancePrecision");
end

function coverageTask(~)
%coverageTask Run tests and generate an HTML coverage report.

import matlab.unittest.TestRunner
import matlab.unittest.plugins.CodeCoveragePlugin
import matlab.unittest.plugins.codecoverage.CoverageReport

projectRoot = fileparts(mfilename("fullpath"));
srcFolder = fullfile(projectRoot, "src");
testsFolder = fullfile(projectRoot, "tests");
coverageFolder = fullfile(projectRoot, "coverage-report");

addpath(srcFolder);

runner = TestRunner.withTextOutput;
runner.addPlugin(CodeCoveragePlugin.forFolder(srcFolder, ...
    Producing=CoverageReport(coverageFolder)));
results = runner.run(testsuite(testsFolder, "IncludeSubfolders", true));
assertSuccess(results);
end
