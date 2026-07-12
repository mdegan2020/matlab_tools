classdef ProjectionViewerPrecisionValidationTest < matlab.unittest.TestCase
    %ProjectionViewerPrecisionValidationTest Test P1 long-range evidence.

    methods (TestClassSetup)
        function addSourceToPath(testCase)
            projectRoot = fileparts(fileparts(mfilename("fullpath")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(projectRoot, "src")));
        end
    end

    methods (Test)
        function testDefaultMatrixCoversRequiredAndStretchRanges(testCase)
            report = ProjectionViewerPrecisionValidation.run();

            testCase.verifyEqual(report.Status, "passed");
            testCase.verifyTrue(report.P1Complete);
            testCase.verifyTrue(ismember(100000, report.RangesMeters));
            testCase.verifyTrue(ismember(200000, report.RangesMeters));
            testCase.verifyGreaterThan(report.GeometricHorizonMeters, 200000);
            testCase.verifyEqual(unique(string( ...
                {report.Records.OriginRegime})), ...
                ["largeTranslated" "local"]);
        end

        function testLocalShiftSinglePathMeetsDisplayGate(testCase)
            report = ProjectionViewerPrecisionValidation.run();

            testCase.verifyLessThan( ...
                report.MaximumLocalSingleScreenErrorPixels, 0.1);
            testCase.verifyTrue(report.LocalSingleEyeOrderingPreserved);
            testCase.verifyTrue(report.LocalSingleFinite);
            testCase.verifyEqual(report.SafeBoundary, ...
                "subtract double render origin before single cast");
        end

        function testUnsafeAbsoluteSinglePathExposesLargeOriginRisk(testCase)
            report = ProjectionViewerPrecisionValidation.run();
            records = report.Records;
            large = string({records.OriginRegime}) == "largeTranslated";

            testCase.verifyTrue(report.UnsafeAbsoluteSingleWorse);
            testCase.verifyTrue(any( ...
                [records(large).AbsoluteSingleMaximumScreenErrorPixels] > ...
                report.DisplayGatePixels));
            testCase.verifyTrue(any(~[ ...
                records(large).AbsoluteSingleEyeOrderingPreserved]));
        end

        function testHorizonLimitsStretchForLowerFeasibleAltitude(testCase)
            report = ProjectionViewerPrecisionValidation.run(struct( ...
                ObserverHaeMeters=1000));

            testCase.verifyGreaterThanOrEqual( ...
                report.GeometricHorizonMeters, report.RequiredRangeMeters);
            testCase.verifyLessThan(report.StretchRangeMeters, 200000);
            testCase.verifyEqual(report.StretchRangeMeters, ...
                report.GeometricHorizonMeters, AbsTol=1e-9);
        end

        function testInfeasibleAltitudeAndUnknownOptionAreRejected(testCase)
            testCase.verifyError(@() ...
                ProjectionViewerPrecisionValidation.run(struct( ...
                ObserverHaeMeters=100)), ...
                "ProjectionViewerPrecisionValidation:infeasibleRequiredRange");
            testCase.verifyError(@() ...
                ProjectionViewerPrecisionValidation.run(struct(Unknown=true)), ...
                "ProjectionViewerPrecisionValidation:invalidOptions");
        end
    end
end
