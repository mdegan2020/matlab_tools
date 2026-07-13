classdef ProjectionDenseTemplateMatcherTest < matlab.unittest.TestCase
    %ProjectionDenseTemplateMatcherTest B2 classical matcher tests.

    properties (TestParameter)
        costMethod = {"zncc", "gradientCorrelation", ...
            "censusRank", "phaseCorrelation"}
    end

    methods (TestClassSetup)
        function addSourcePath(testCase)
            projectRoot = fileparts(fileparts(mfilename("fullpath")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(projectRoot, "src")));
        end
    end

    methods (Test)
        function testEveryCostFamilyRecoversKnownTranslation(testCase, costMethod)
            request = ProjectionDenseTemplateMatcherTest.request(3, 0, false);
            matcher = ProjectionDenseTemplateMatcher();

            result = matcher.match(request, struct(CostMethod=costMethod, ...
                SampleStride=6, HorizontalDisparityRange=[0 6], ...
                VerticalDisparityRange=[0 0], ...
                MinimumUniquenessMargin=0.001));
            valid = result.States == "valid";
            disparities = result.MovingSourceColumns(valid) - ...
                result.ReferenceSourceColumns(valid);

            testCase.verifyGreaterThan(nnz(valid), 30);
            testCase.verifyEqual(median(disparities), 3, AbsTol=0.1);
            testCase.verifyLessThan(max(abs(disparities - 3)), 0.5);
            testCase.verifyEqual(result.Diagnostics.CostMethod, costMethod);
            testCase.verifyFalse(result.Diagnostics.ConfidenceCalibrated);
        end

        function testSubpixelMappingAndQualityDiagnosticsAreContinuous(testCase)
            request = ProjectionDenseTemplateMatcherTest.request(3.25, 0, false);
            matcher = ProjectionDenseTemplateMatcher();

            result = matcher.match(request, struct(SampleStride=6, ...
                HorizontalDisparityRange=[0 6], ...
                VerticalDisparityRange=[0 0], ...
                MinimumUniquenessMargin=0.001));
            valid = result.States == "valid";
            disparities = result.MovingSourceColumns(valid) - ...
                result.ReferenceSourceColumns(valid);

            testCase.verifyGreaterThan(nnz(valid), 30);
            testCase.verifyEqual(median(disparities), 3.25, AbsTol=0.2);
            testCase.verifyTrue(any(abs(disparities - round(disparities)) > 0.01));
            testCase.verifyTrue(all(isfinite( ...
                result.Diagnostics.UniquenessMargin(valid))));
            testCase.verifyTrue(all(isfinite( ...
                result.Diagnostics.LeftRightConsistencyPixels(valid))));
            testCase.verifyTrue(all(isfinite( ...
                result.Diagnostics.GeometricPredictionResidualPixels(valid))));
        end

        function testLowTextureMaskAndOverlapHaveExplicitStates(testCase)
            request = ProjectionDenseTemplateMatcherTest.request(3, 0, true);
            matcher = ProjectionDenseTemplateMatcher();

            result = matcher.match(request, struct(SampleStride=4, ...
                HorizontalDisparityRange=[0 6], ...
                VerticalDisparityRange=[0 0]));

            testCase.verifyTrue(any(result.States == "insufficientTexture"));
            testCase.verifyTrue(any(result.States == "masked"));
            testCase.verifyTrue(any(result.States == "outsideOverlap"));
            testCase.verifyTrue(all(ismember(result.States, ...
                ProjectionDenseMatchResult.States)));
        end

        function testRegionalNoSupportIsNotSilentlyMatched(testCase)
            request = ProjectionDenseTemplateMatcherTest.request(3, 0, false);
            sparse = struct(MovingPoints=[8 8; 20 20], ...
                ReferencePoints=[5 8; 17 20], ...
                TrackIds=["a" "b"]);
            request = ProjectionDenseSearchPredictor.attach(request, sparse, ...
                struct(RegionSize=[20 28], AllowUnseededSearch=false));
            matcher = ProjectionDenseTemplateMatcher();

            result = matcher.match(request, struct(SampleStride=5, ...
                HorizontalDisparityRange=[0 6], ...
                VerticalDisparityRange=[0 0], ...
                MinimumUniquenessMargin=0.001));

            testCase.verifyTrue(any(result.States == "valid"));
            testCase.verifyTrue(any(result.States == "geometrySearchFailure"));
            testCase.verifyEqual(result.Provenance.SearchPredictionFormat, ...
                ProjectionDenseSearchPredictor.Format);
        end

        function testConsistencyRejectsVerticalMisrectification(testCase)
            request = ProjectionDenseTemplateMatcherTest.request(3, 2, false);
            matcher = ProjectionDenseTemplateMatcher();

            result = matcher.match(request, struct(SampleStride=5, ...
                HorizontalDisparityRange=[0 6], ...
                VerticalDisparityRange=[-3 3], ...
                ConsistencyTolerancePixels=0.1, ...
                MinimumUniquenessMargin=0.001));

            testCase.verifyTrue(any(result.States == "occluded"));
            testCase.verifyTrue(any( ...
                result.Diagnostics.LeftRightConsistencyPixels > 0.1));
        end

        function testRepeatabilityProvenanceAndCancellation(testCase)
            request = ProjectionDenseTemplateMatcherTest.request(3, 0, false);
            matcher = ProjectionDenseTemplateMatcher();
            options = struct(SampleStride=8, ...
                HorizontalDisparityRange=[0 6], ...
                VerticalDisparityRange=[0 0], ...
                MinimumUniquenessMargin=0.001);

            first = matcher.match(request, options);
            second = matcher.match(request, options);

            testCase.verifyEqual(first.States, second.States);
            testCase.verifyEqual(first.MovingSourceRows, ...
                second.MovingSourceRows);
            testCase.verifyEqual(first.ReferenceSourceColumns, ...
                second.ReferenceSourceColumns);
            testCase.verifyEqual(first.Provenance.AlgorithmId, ...
                "sightline.classical-template");
            testCase.verifyEqual(first.Execution.Device, "cpu");
            testCase.verifyError(@() matcher.match(request, options, ...
                struct(CancellationFcn=@() true)), ...
                "ProjectionDenseMatcher:cancelled");
        end
    end

    methods (Static, Access = private)
        function request = request(disparity, verticalShift, degraded)
            stream = RandStream("mt19937ar", Seed=4);
            moving = imgaussfilt(rand(stream, 40, 56), 0.7);
            [columns, rows] = meshgrid(1:56, 1:40);
            reference = interp2(moving, columns + disparity, ...
                rows + verticalShift, "linear", 0);
            firstMask = true(size(moving));
            secondMask = true(size(moving));
            overlap = true(size(moving));
            if degraded
                moving(14:26, 20:36) = 0.5;
                reference(14:26, 20:36) = 0.5;
                firstMask(4:10, 4:10) = false;
                overlap(30:36, 40:50) = false;
            end
            request = ProjectionDenseMatchRequest.validate(struct( ...
                PairId="pair:template-test", ...
                ViewIds=["moving" "reference"], ...
                AnalysisImages={{moving, reference}}, ...
                ValidityMasks={{firstMask, secondMask}}, ...
                SourceRows={{double(rows), double(rows)}}, ...
                SourceColumns={{double(columns), double(columns)}}, ...
                OverlapMask=overlap));
        end
    end
end
