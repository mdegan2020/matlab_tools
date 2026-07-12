function results = runTests(varargin)
%runTests Run the PlanarProjection MATLAB unit test suite.

projectRoot = fileparts(mfilename("fullpath"));
addpath(fullfile(projectRoot, "src"));
groups = projectionTestGroups();
results = matlab.unittest.TestResult.empty(1, 0);
for index = 1:numel(groups)
    groupResults = runTestGroup(groups(index).Name, varargin);
    results = [results groupResults]; %#ok<AGROW>
end

fprintf("SUITE_TOTAL=%d FAILED=%d INCOMPLETE=%d\n", ...
    numel(results), nnz([results.Failed]), nnz([results.Incomplete]));
end
