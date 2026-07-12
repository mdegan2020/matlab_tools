classdef ProjectionPrecisionInventoryTest < matlab.unittest.TestCase
    %ProjectionPrecisionInventoryTest Test the executable P0 inventory.

    methods (TestClassSetup)
        function addSourceToPath(testCase)
            projectRoot = fileparts(fileparts(mfilename("fullpath")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(projectRoot, "src")));
        end
    end

    methods (Test)
        function testInventoryCoversEveryApprovedRole(testCase)
            report = ProjectionPrecisionInventory.inspect();
            roles = string({report.Entries.Role});

            testCase.verifyEqual(report.Status, "complete");
            testCase.verifyTrue(report.P0Complete);
            testCase.verifyFalse(report.P2PolicySelected);
            testCase.verifyGreaterThanOrEqual(report.EntryCount, 16);
            testCase.verifyTrue(all(ismember([ ...
                "authoritativeGeometry" "derivedDisplay" ...
                "authoritativeBackend" "authoritativeSolver" ...
                "authoritativeCovariance" "derivedDenseIntermediate" ...
                "runtimeAcceleration"], roles)));
        end

        function testAuthoritativeScientificEntriesRemainDouble(testCase)
            report = ProjectionPrecisionInventory.inspect();
            entries = report.Entries;
            roles = string({entries.Role});
            authoritative = startsWith(roles, "authoritative") & ...
                roles ~= "authoritativeRadiometry";

            testCase.verifyTrue(all(string( ...
                {entries(authoritative).RequiredOrCandidateType}) == "double"));
            testCase.verifyEqual(report.AuthoritativeReference, "double");
        end

        function testRuntimeProbesMatchDocumentedBoundaries(testCase)
            probes = ProjectionPrecisionInventory.probeCurrentTypes();

            testCase.verifyEqual(probes.SourceImage, "uint16");
            testCase.verifyEqual(probes.SourceOrigins, "double");
            testCase.verifyEqual(probes.SourceVectors, "double");
            testCase.verifyEqual(probes.PlaneOrigin, "double");
            testCase.verifyEqual(probes.RenderOrigin, "double");
            testCase.verifyEqual(probes.MeshWorldPoints, "double");
            testCase.verifyEqual(probes.MeshRenderPoints, "double");
            testCase.verifyEqual(probes.BackendGridOrigin, "double");
            testCase.verifyEqual(probes.BackendGridBounds, "double");
            testCase.verifyEqual(probes.PreviewLevelImage, "uint16");
        end
    end
end
