function results = runTestGroup(groupName, testOptions)
%runTestGroup Run one authoritative logical test group.

arguments
    groupName (1, 1) string
    testOptions (1, :) cell = {}
end

projectRoot = fileparts(mfilename("fullpath"));
addpath(fullfile(projectRoot, "src"));
group = projectionTestGroups(groupName);
testPaths = fullfile(projectRoot, "tests", group.Files);

fprintf("TEST_GROUP=%s FILES=%d\n", group.Name, numel(group.Files));
results = runtests(cellstr(testPaths), "Strict", true, testOptions{:});
disp(table(results));
fprintf("GROUP_TOTAL=%d FAILED=%d INCOMPLETE=%d\n", ...
    numel(results), nnz([results.Failed]), nnz([results.Incomplete]));
assertSuccess(results);
end
