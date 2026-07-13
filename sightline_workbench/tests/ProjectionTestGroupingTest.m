classdef ProjectionTestGroupingTest < matlab.unittest.TestCase
    %ProjectionTestGroupingTest Test the authoritative test-group manifest.

    methods (TestClassSetup)
        function addProjectRootToPath(testCase)
            projectRoot = fileparts(fileparts(mfilename("fullpath")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                projectRoot));
        end
    end

    methods (Test)
        function testEveryTestFileBelongsToExactlyOneGroup(testCase)
            projectRoot = fileparts(fileparts(mfilename("fullpath")));
            discovered = dir(fullfile(projectRoot, "tests", "*Test.m"));
            discoveredNames = sort(string({discovered.name}));
            groups = projectionTestGroups();
            assignedNames = string([groups.Files]);

            testCase.verifyEqual(sort(unique(assignedNames)), discoveredNames);
            testCase.verifyEqual(numel(unique(assignedNames)), ...
                numel(assignedNames));
        end

        function testLogicalGroupNamesRemainStable(testCase)
            groups = projectionTestGroups();

            testCase.verifyEqual(string({groups.Name}), ...
                ["coreGeometryState" "alignment" "backendSurface" ...
                "viewerAlignmentUi" "viewerPresentationWorkflows" ...
                "viewerPerformancePrecision"]);
            testCase.verifyTrue(all(strlength(string( ...
                {groups.Description})) > 0));
        end

        function testNamedGroupSelectionReturnsOnlyRequestedGroup(testCase)
            group = projectionTestGroups("alignment");

            testCase.verifyEqual(group.Name, "alignment");
            testCase.verifyTrue(all(startsWith(group.Files, ...
                ["ProjectionAlignment" "ProjectionCorrection" ...
                "ProjectionDemCorrection"], ...
                "IgnoreCase", false), "all"));
        end

        function testUnknownGroupIsRejected(testCase)
            testCase.verifyError(@() projectionTestGroups("unknown"), ...
                "projectionTestGroups:unknownGroup");
        end
    end
end
