classdef ProjectionDenseSgmTruthAuditTest < matlab.unittest.TestCase
    %ProjectionDenseSgmTruthAuditTest B0 SGM truth-evidence tests.

    methods (TestClassSetup)
        function addSourcePath(testCase)
            projectRoot = fileparts(fileparts(mfilename("fullpath")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(projectRoot, "src")));
        end
    end

    methods (Test)
        function testDefaultMatrixCoversRequiredAuditDimensions(testCase)
            cases = ProjectionDenseSgmTruthAudit.defaultCases();

            report = ProjectionDenseSgmTruthAudit.run(cases);
            coverage = report.DimensionCoverage;

            testCase.verifyEqual(numel(cases), 11);
            testCase.verifyGreaterThanOrEqual(numel(coverage.RangeClasses), 2);
            testCase.verifyGreaterThanOrEqual( ...
                numel(unique(coverage.IntersectionAngleDegrees)), 3);
            testCase.verifyEqual(coverage.ReliefClasses, ...
                ["constant" "twoLevel"]);
            testCase.verifyEqual(coverage.OcclusionClasses, ...
                ["none" "centralStrip"]);
            testCase.verifyEqual(coverage.RadiometricPairs, ...
                ["sameBand" "crossBand"]);
            testCase.verifyEqual(coverage.NavigationErrorClasses, ...
                ["pointingOnly" "combinedNavigation"]);
            testCase.verifyEqual(coverage.RectificationErrorsPixels, [0 2]);
            testCase.verifyEqual(coverage.TextureClasses, ...
                ["random" "repetitive" "low"]);
            testCase.verifyTrue(coverage.CpuIncluded);
            testCase.verifyTrue(coverage.GpuRequestIncluded);
            testCase.verifyFalse(report.AutomaticBestMatcherSelected);
            testCase.verifyFalse(report.ThresholdsEstablished);
        end

        function testNominalCaseReportsAllRequiredMetrics(testCase)
            caseDefinition = ProjectionDenseSgmTruthAuditTest.caseById("nominal");

            report = ProjectionDenseSgmTruthAudit.run(caseDefinition);
            metric = report.Records.Metrics;

            testCase.verifyEqual(report.Status, "complete");
            testCase.verifyFalse(report.OperationalInputContainsTruth);
            testCase.verifyTrue( ...
                report.HeldOutEvaluationTruthUsedOnlyAfterMatching);
            testCase.verifyGreaterThan(metric.CandidateTruthCount, 1000);
            testCase.verifyGreaterThan(metric.Completeness, 0.8);
            testCase.verifyLessThan( ...
                metric.SubpixelP95AbsoluteErrorPixels, 0.5);
            testCase.verifyLessThan(metric.GrossOutlierRate, 0.1);
            testCase.verifyGreaterThan(metric.HeightSampleCount, 1000);
            testCase.verifyLessThan(metric.HeightP95AbsoluteErrorMeters, 2);
            testCase.verifyGreaterThan( ...
                metric.LeftRightConsistencyFraction, 0.95);
            testCase.verifyGreaterThan(report.Records.MemoryBytes, 0);
            testCase.verifyGreaterThan(report.Records.RuntimeSeconds, 0);
        end

        function testAuditQuantifiesKnownSgmFailureModes(testCase)
            cases = ProjectionDenseSgmTruthAuditTest.casesById( ...
                ["nominal" "cross-band" "combined-navigation" ...
                "rectification-error" "low-texture"]);

            report = ProjectionDenseSgmTruthAudit.run(cases);
            nominal = report.Records(1).Metrics;
            crossBand = report.Records(2).Metrics;
            navigation = report.Records(3).Metrics;
            rectification = report.Records(4).Metrics;
            lowTexture = report.Records(5).Metrics;

            testCase.verifyGreaterThan(crossBand.GrossOutlierRate, 0.9);
            testCase.verifyGreaterThan( ...
                crossBand.SubpixelP95AbsoluteErrorPixels, 5);
            testCase.verifyGreaterThan(navigation.HeightP95AbsoluteErrorMeters, ...
                nominal.HeightP95AbsoluteErrorMeters);
            testCase.verifyGreaterThan( ...
                rectification.SubpixelP95AbsoluteErrorPixels, 2);
            testCase.verifyLessThan( ...
                rectification.LeftRightConsistencyFraction, 0.9);
            testCase.verifyGreaterThan(lowTexture.GrossOutlierRate, 0.9);
            testCase.verifyLessThan( ...
                lowTexture.LeftRightConsistencyFraction, 0.1);
        end

        function testOcclusionBehaviorIsExplicit(testCase)
            caseDefinition = ProjectionDenseSgmTruthAuditTest. ...
                caseById("relief-occlusion");

            report = ProjectionDenseSgmTruthAudit.run(caseDefinition);
            metric = report.Records.Metrics;

            testCase.verifyGreaterThan(metric.OccludedTruthCount, 0);
            testCase.verifyGreaterThan(metric.OcclusionFalseValidRate, 0);
            testCase.verifyLessThanOrEqual(metric.OcclusionFalseValidRate, 1);
            testCase.verifyGreaterThan(metric.ReliefMeters, 0);
            testCase.verifyEqual(metric.DisparityTruthRangePixels, [2 8]);
        end

        function testGpuRequestIsCapabilityCheckedAndCpuRemainsAvailable(testCase)
            caseDefinition = ProjectionDenseSgmTruthAuditTest. ...
                caseById("gpu-request");
            expected = ProjectionGpuSupport.resolve(true);

            report = ProjectionDenseSgmTruthAudit.run(caseDefinition);
            execution = report.Records.Execution;

            testCase.verifyTrue(execution.RequestedGpu);
            testCase.verifyEqual(execution.GpuInfo, expected);
            testCase.verifyEqual(execution.Actual, ...
                ProjectionDenseSgmTruthAuditTest.expectedExecution(expected));
            testCase.verifyEqual(report.Status, "complete");
        end

        function testRepeatableRunMatchesExactlyWithoutVolatileEvidence(testCase)
            caseDefinition = ProjectionDenseSgmTruthAuditTest.caseById("nominal");

            report = ProjectionDenseSgmTruthAudit.runRepeatable(caseDefinition);

            testCase.verifyEqual(report.Repeatability.Status, "verified");
            testCase.verifyTrue(report.Repeatability.Exact);
            testCase.verifyGreaterThan( ...
                report.Repeatability.FirstRunRuntimeSeconds, 0);
            testCase.verifyGreaterThan( ...
                report.Repeatability.SecondRunRuntimeSeconds, 0);
        end

        function testCompactArtifactsExcludeOperationalImages(testCase)
            caseDefinition = ProjectionDenseSgmTruthAuditTest.caseById("nominal");
            outputDirectory = string(tempname);
            testCase.addTeardown(@() ...
                ProjectionDenseSgmTruthAuditTest.removeDirectory( ...
                outputDirectory));

            report = ProjectionDenseSgmTruthAudit.run(caseDefinition, ...
                struct(WriteArtifacts=true, ...
                OutputDirectory=outputDirectory));
            jsonText = string(fileread(report.Artifacts.ReportJsonPath));
            matVariables = whos("-file", report.Artifacts.ReportMatPath);

            testCase.verifyTrue(isfile(report.Artifacts.ReportMatPath));
            testCase.verifyTrue(isfile(report.Artifacts.ReportJsonPath));
            testCase.verifyEqual(string({matVariables.name}), "report");
            testCase.verifyFalse(contains(jsonText, "MovingImage"));
            testCase.verifyFalse(contains(jsonText, "ReferenceImage"));
            testCase.verifyTrue(contains(jsonText, ...
                '"OperationalInputContainsTruth": false'));
        end
    end

    methods (Static, Access = private)
        function caseDefinition = caseById(id)
            caseDefinition = ...
                ProjectionDenseSgmTruthAuditTest.casesById(id);
        end

        function selected = casesById(ids)
            cases = ProjectionDenseSgmTruthAudit.defaultCases();
            allIds = string({cases.Id});
            ids = string(ids(:).');
            selected = repmat(cases(1), 1, numel(ids));
            for index = 1:numel(ids)
                selected(index) = cases(find(allIds == ids(index), ...
                    1, "first"));
            end
        end

        function execution = expectedExecution(gpuInfo)
            execution = "cpu";
            if gpuInfo.Enabled
                execution = "gpu";
            end
        end

        function removeDirectory(path)
            if isfolder(path)
                rmdir(path, "s");
            end
        end
    end
end
