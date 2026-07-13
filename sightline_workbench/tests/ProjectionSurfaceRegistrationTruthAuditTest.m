classdef ProjectionSurfaceRegistrationTruthAuditTest < matlab.unittest.TestCase
    %ProjectionSurfaceRegistrationTruthAuditTest S7 held-out acceptance.

    methods (TestClassSetup)
        function addPaths(testCase)
            root = fileparts(fileparts(mfilename("fullpath")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(root, "src")));
        end
    end

    methods (Test)
        function testAuditRecoversHeldOutTransformWithoutApplying(testCase)
            report = ProjectionSurfaceRegistrationTruthAudit.run( ...
                ProjectionSurfaceRegistrationFixture.cleanRequest(), ...
                ProjectionSurfaceRegistrationFixture.truth(), 10);

            testCase.verifyEqual(report.Format, ...
                "ProjectionSurfaceRegistrationTruthAudit");
            testCase.verifyEqual(report.BaselineStatus, "succeeded");
            testCase.verifyLessThan(report.BaselineErrorNormMeters, 1e-3);
            testCase.verifyTrue(report.ImageryOnlyProductPreserved);
            testCase.verifyFalse(report.AutoApplied);
            testCase.verifyTrue(report.OperationalTruthSeparated);
            testCase.verifyNotEmpty(report.AuditFingerprint);
        end

        function testMonteCarloCoverageIncludesSharedDemUncertainty(testCase)
            report = ProjectionSurfaceRegistrationTruthAudit.run( ...
                ProjectionSurfaceRegistrationFixture.cleanRequest(), ...
                ProjectionSurfaceRegistrationFixture.truth(), 25);

            testCase.verifyTrue(report.MonteCarlo.AllReviewable);
            testCase.verifyGreaterThanOrEqual( ...
                report.MonteCarlo.Coverage90Fraction, 0.8);
            testCase.verifyLessThanOrEqual( ...
                report.MonteCarlo.Coverage90Fraction, 1);
            testCase.verifySize( ...
                report.MonteCarlo.EmpiricalCovarianceMetersSquared, [3 3]);
            testCase.verifyTrue(all(isfinite( ...
                report.MonteCarlo.RmseMeters)));
        end

        function testUrbanMaskVoidAndOutlierSensitivityRemainEvidence(testCase)
            report = ProjectionSurfaceRegistrationTruthAudit.run( ...
                ProjectionSurfaceRegistrationFixture.maskedOutlierRequest(), ...
                ProjectionSurfaceRegistrationFixture.truth(), 10);

            testCase.verifyLessThan(report.BaselineErrorNormMeters, 0.2);
            testCase.verifyLessThan(report.BaselineResiduals.Final.RmsMeters, ...
                report.BaselineResiduals.Initial.RmsMeters);
            testCase.verifyTrue(report.BaselineSensitivity.Evaluated);
            testCase.verifyTrue(any(startsWith( ...
                report.BaselineRejectionReasons, "pointMask:building")));
            testCase.verifyTrue(any(report.BaselineRejectionReasons == ...
                "outsideDemOrVoidOrExcludedCell"));
            testCase.verifyLessThan( ...
                report.BaselineSupport.CoverageFraction, 1);
        end

        function testTruthMustRemainHeldOutAndTrialsAreBounded(testCase)
            request = ProjectionSurfaceRegistrationFixture.cleanRequest();
            embedded = request;
            embedded.Truth = ProjectionSurfaceRegistrationFixture.truth();
            invalidTruth = ProjectionSurfaceRegistrationFixture.truth();
            invalidTruth.TranslationEnuMeters(1) = NaN;

            testCase.verifyError(@() ProjectionSurfaceRegistrationTruthAudit.run( ...
                embedded, ProjectionSurfaceRegistrationFixture.truth(), 10), ...
                "ProjectionSurfaceRegistrationRequest:forbiddenData");
            testCase.verifyError(@() ProjectionSurfaceRegistrationTruthAudit.run( ...
                request, invalidTruth, 10), ...
                "ProjectionSurfaceRegistrationTruthAudit:invalidTruth");
            testCase.verifyError(@() ProjectionSurfaceRegistrationTruthAudit.run( ...
                request, ProjectionSurfaceRegistrationFixture.truth(), 2), ...
                "ProjectionSurfaceRegistrationTruthAudit:invalidTrials");
        end
    end
end
