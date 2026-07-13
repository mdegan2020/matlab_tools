classdef ProjectionSurfaceFusionTruthAuditTest < matlab.unittest.TestCase
    %ProjectionSurfaceFusionTruthAuditTest S6/B4 held-out spike evidence.

    methods (TestClassSetup)
        function addPaths(testCase)
            root = fileparts(fileparts(mfilename("fullpath")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(root, "src")));
        end
    end

    methods (Test)
        function testAuditComparesAllAlgorithmsAndScales(testCase)
            request = ProjectionSurfaceFusionFixture.request();
            truth = ProjectionSurfaceFusionTruthAuditTest.truth();
            report = ProjectionSurfaceFusionTruthAudit.run(request, truth);

            testCase.verifyEqual(report.Format, ...
                "ProjectionSurfaceFusionTruthAudit");
            testCase.verifyEqual(report.Direct.AlgorithmId, ...
                "sightline.fusion.robust-multi-ray");
            testCase.verifyEqual(report.Direct.ProductRole, ...
                "authoritativeReference");
            testCase.verifyEqual(report.HardVoxel.ProductRole, ...
                "diagnosticDerived");
            testCase.verifyNumElements(report.HardVoxel.ScaleResults, 3);
            testCase.verifyNumElements(report.GaussianSplat.ScaleResults, 3);
            testCase.verifyEqual([report.HardVoxel.ScaleResults.VoxelScaleMeters], ...
                [0.25 0.5 1]);
            testCase.verifyGreaterThanOrEqual(report.Direct.RuntimeSeconds, 0);
            testCase.verifyGreaterThan(report.GaussianSplat.MemoryBytes, 0);
            testCase.verifyNotEmpty(report.AuditFingerprint);
        end

        function testAuditPreservesUrbanModesAndSurfaceMetrics(testCase)
            report = ProjectionSurfaceFusionTruthAudit.run( ...
                ProjectionSurfaceFusionFixture.request(), ...
                ProjectionSurfaceFusionTruthAuditTest.truth());
            hardMetrics = report.HardVoxel.ScaleResults(2).Metrics;
            gaussianMetrics = report.GaussianSplat.ScaleResults(2).Metrics;

            testCase.verifyEqual(report.TruthSummary.ModeIds, ...
                ["parapet" "roof"]);
            testCase.verifyEqual(report.TruthSummary.SurfaceTypes, ...
                ["horizontalRoof" "verticalFeature"]);
            testCase.verifyFalse(report.TruthSummary.RawTruthRetained);
            testCase.verifyEqual(hardMetrics.ModeRecallFraction, 1);
            testCase.verifyEqual(gaussianMetrics.ModeRecallFraction, 1);
            testCase.verifyNumElements(hardMetrics.SurfaceTypes, 2);
            testCase.verifyTrue(isfinite(hardMetrics.VerticalRmseMeters));
            testCase.verifyTrue(isfinite(gaussianMetrics.AccuracyRmseMeters));
        end

        function testAuditIgnoresPairMultiplicityAndMakesExplicitDecision(testCase)
            report = ProjectionSurfaceFusionTruthAudit.run( ...
                ProjectionSurfaceFusionFixture.request(), ...
                ProjectionSurfaceFusionTruthAuditTest.truth());

            testCase.verifyTrue(report.PairMultiplicity.HardVoxelInvariant);
            testCase.verifyTrue(report.PairMultiplicity.GaussianSplatInvariant);
            testCase.verifyTrue(report.PairMultiplicity.Passed);
            testCase.verifyTrue(report.Decision.CompetingModesPreserved);
            testCase.verifyEqual(report.Decision.AuthoritativeAlgorithmId, ...
                "sightline.fusion.robust-multi-ray");
            testCase.verifyEqual(report.Decision.VoxelProductRole, ...
                "diagnosticDerived");
            testCase.verifyTrue(ismember(report.Decision.Outcome, ...
                ["retainDiagnosticCandidate" ...
                "abandonAuthoritativePromotion"]));
            testCase.verifyNotEmpty(report.Decision.Rationale);
        end

        function testTruthMustRemainHeldOutAndInsideRoi(testCase)
            request = ProjectionSurfaceFusionFixture.request();
            invalid = ProjectionSurfaceFusionTruthAuditTest.truth();
            invalid.PointsWorld(1, 1) = 20;
            embedded = request;
            embedded.Truth = ProjectionSurfaceFusionTruthAuditTest.truth();

            testCase.verifyError(@() ProjectionSurfaceFusionTruthAudit.run( ...
                request, invalid), ...
                "ProjectionSurfaceFusionTruthAudit:invalidTruth");
            testCase.verifyError(@() ProjectionSurfaceFusionTruthAudit.run( ...
                embedded, ProjectionSurfaceFusionTruthAuditTest.truth()), ...
                "ProjectionSurfaceFusionRequest:forbiddenData");
        end
    end

    methods (Static, Access = private)
        function truth = truth()
            points = [ ...
                -1.00 0.00 1.00 -1.00 0.00 1.00 -0.10 0.15; ...
                -1.00 -1.00 -1.00 0.00 0.00 0.00 0.00 0.05; ...
                10.00 10.00 10.00 10.00 10.00 10.00 12.00 12.00];
            truth = struct(WorldFrame="sceneWorld", PointsWorld=points, ...
                ModeIds=[repmat("roof", 1, 6) repmat("parapet", 1, 2)], ...
                SurfaceTypes=[repmat("horizontalRoof", 1, 6) ...
                repmat("verticalFeature", 1, 2)]);
        end
    end
end
