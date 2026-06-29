function plan = buildfile
%buildfile Build tasks for PlanarProjection.

plan = buildplan(localfunctions);
plan.DefaultTasks = "test";
end

function testTask(~)
%testTask Run the unit test suite.

projectRoot = fileparts(mfilename("fullpath"));
addpath(fullfile(projectRoot, "src"));

results = runtests(fullfile(projectRoot, "tests"), ...
    "IncludeSubfolders", true, "Strict", true);
assertSuccess(results);
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
