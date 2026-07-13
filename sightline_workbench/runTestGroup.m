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
progressPath = fullfile(tempdir, ...
    "sightline_workbench_test_progress.txt");
fprintf("TEST_PROGRESS_PATH=%s\n", progressPath);
results = matlab.unittest.TestResult.empty(1, 0);
for index = 1:numel(testPaths)
    writeProgress(progressPath, group.Name, group.Files(index), "running");
    fileResults = runtests(testPaths(index), ...
        "Strict", true, testOptions{:});
    results = [results fileResults]; %#ok<AGROW>
    fileState = "passed";
    if any([fileResults.Failed])
        fileState = "failed";
    elseif any([fileResults.Incomplete])
        fileState = "incomplete";
    end
    writeProgress(progressPath, group.Name, group.Files(index), fileState);
end
disp(table(results));
fprintf("GROUP_TOTAL=%d FAILED=%d INCOMPLETE=%d\n", ...
    numel(results), nnz([results.Failed]), nnz([results.Incomplete]));
assertSuccess(results);
end

function writeProgress(progressPath, groupName, fileName, state)
%writeProgress Persist the active test file for timeout diagnosis.

fileId = fopen(progressPath, "w");
if fileId < 0
    error("runTestGroup:progressFile", ...
        "Unable to write test progress file: %s", progressPath);
end
cleanup = onCleanup(@() fclose(fileId));
fprintf(fileId, "GROUP=%s\nFILE=%s\nSTATE=%s\nUPDATED=%s\n", ...
    groupName, fileName, state, ...
    string(datetime("now", TimeZone="UTC", ...
    Format="yyyy-MM-dd'T'HH:mm:ss.SSS'Z'")));
clear cleanup
end
