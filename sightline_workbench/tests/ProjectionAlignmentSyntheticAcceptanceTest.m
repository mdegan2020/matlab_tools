classdef ProjectionAlignmentSyntheticAcceptanceTest < matlab.unittest.TestCase
    %ProjectionAlignmentSyntheticAcceptanceTest Multi-image truth matrix tests.

    methods (TestClassSetup)
        function addSourceToPath(testCase)
            projectRoot = fileparts(fileparts(mfilename("fullpath")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(projectRoot, "src")));
        end
    end

    methods (Test)
        function testDefaultMatrixCoversApprovedDimensions(testCase)
            testCase.assumeTrue(exist("lsqnonlin", "file") == 2);

            report = ProjectionAlignmentSyntheticAcceptance.run();

            testCase.verifyEqual(report.Status, "completed");
            testCase.verifyEqual(report.ScenarioCount, 8);
            testCase.verifyEqual(report.Coverage.ViewCounts, [2 3 4 6]);
            testCase.verifyEqual(sort(report.Coverage.GraphVariants), ...
                sort(["balanced" "allPlausible" "quality" "fast"]));
            testCase.verifyEqual(sort(report.Coverage.Configurations), ...
                sort(["singlePass" "multiplePasses"]));
            testCase.verifyTrue(report.Coverage.CorruptedEdge);
            testCase.verifyTrue(report.Coverage.Occlusion);
            testCase.verifyTrue(report.Coverage.TextureCoverage);
            testCase.verifyTrue(report.Coverage.Masks);
            testCase.verifyTrue(report.Coverage.InvalidGeometry);
            testCase.verifyTrue(report.Coverage.Uncertainty);
            testCase.verifyFalse(report.ThresholdsEstablished);
        end

        function testTruthIsHeldOutUntilReportComparison(testCase)
            testCase.assumeTrue(exist("lsqnonlin", "file") == 2);

            report = ProjectionAlignmentSyntheticAcceptance.run(struct( ...
                ScenarioNames="four-view-quality-multipass"));
            run = report.Runs;

            testCase.verifyFalse(run.TruthEnteredSolver);
            testCase.verifyEqual(run.TruthRole, ...
                "reported-input-with-held-out-zero-OPK-truth");
            testCase.verifySize(run.InjectedOffsetsDegrees, [4 3]);
            testCase.verifySize(run.SolvedOffsetsDegrees, [4 3]);
            testCase.verifyEqual(run.RecoveryErrorDegrees, ...
                run.SolvedOffsetsDegrees, AbsTol=1e-12);
            testCase.verifyTrue(run.GaugeValid);
            testCase.verifyGreaterThanOrEqual(run.Graph.TreePairCount, 3);
            testCase.verifyGreaterThan(run.Graph.ChordPairCount, 0);
            testCase.verifyLessThanOrEqual( ...
                run.ResidualRmsAfter, run.ResidualRmsBefore + 1e-12);
        end

        function testEvidenceExclusionsRemainExplicitAndOutsideSolver(testCase)
            testCase.assumeTrue(exist("lsqnonlin", "file") == 2);

            report = ProjectionAlignmentSyntheticAcceptance.run(struct( ...
                ScenarioNames="six-view-evidence-exclusions"));
            evidence = report.Runs.EvidenceClasses;

            testCase.verifyEqual(evidence.CandidateCount, 12);
            testCase.verifyEqual(evidence.VisibleTerrainCount, 8);
            testCase.verifyEqual(evidence.OccludedTerrainCount, 1);
            testCase.verifyEqual(evidence.TextureCoverageFailureCount, 1);
            testCase.verifyEqual(evidence.MaskedCount, 1);
            testCase.verifyEqual(evidence.InvalidGeometryCount, 1);
            testCase.verifyGreaterThan(evidence.SolverRecordCount, 0);
        end

        function testCorruptedEdgeIsPresentedAndAssociationRejectsConflict( ...
                testCase)
            testCase.assumeTrue(exist("lsqnonlin", "file") == 2);

            report = ProjectionAlignmentSyntheticAcceptance.run(struct( ...
                ScenarioNames="four-view-corrupted-edge"));
            corruption = report.Runs.Corruption;

            testCase.verifyTrue(corruption.Present);
            testCase.verifyNotEmpty(corruption.PairId);
            testCase.verifyEqual(corruption.RetainedRecordCount, 0);
            testCase.verifyEqual(report.Runs.Status, "completed");
        end

        function testSelectedScenariosAreExactlyRepeatable(testCase)
            testCase.assumeTrue(exist("lsqnonlin", "file") == 2);

            report = ProjectionAlignmentSyntheticAcceptance.runRepeatable( ...
                struct(ScenarioNames=["two-view-balanced" ...
                "six-view-evidence-exclusions"]));

            testCase.verifyEqual(report.Repeatability.Status, "verified");
            testCase.verifyTrue(report.Repeatability.Exact);
        end

        function testUnknownScenarioAndOptionAreRejected(testCase)
            testCase.verifyError(@() ...
                ProjectionAlignmentSyntheticAcceptance.run(struct( ...
                ScenarioNames="not-a-scenario")), ...
                "ProjectionAlignmentSyntheticAcceptance:unknownScenario");
            testCase.verifyError(@() ...
                ProjectionAlignmentSyntheticAcceptance.run(struct( ...
                Unsupported=true)), ...
                "ProjectionAlignmentSyntheticAcceptance:invalidOptions");
        end
    end
end
