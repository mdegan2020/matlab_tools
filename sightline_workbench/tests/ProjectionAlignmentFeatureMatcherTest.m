classdef ProjectionAlignmentFeatureMatcherTest < matlab.unittest.TestCase
    %ProjectionAlignmentFeatureMatcherTest Tests feature detection and matching.

    methods (TestClassSetup)
        function addSourceToPath(testCase)
            projectRoot = fileparts(fileparts(mfilename("fullpath")));
            srcFolder = fullfile(projectRoot, "src");
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(srcFolder));
        end
    end

    methods (Test)
        function testCapabilitiesReportSupportedDetector(testCase)
            capabilities = ProjectionAlignmentFeatureMatcher.capabilities();

            testCase.verifyTrue(capabilities.HasExtractFeatures);
            testCase.verifyTrue(capabilities.HasMatchFeatures);
            testCase.verifyNotEmpty(capabilities.AvailableDetectors);
            testCase.verifyTrue(ismember(capabilities.DefaultDetector, ...
                capabilities.AvailableDetectors));
        end

        function testAutoDetectorUsesSupportedDefault(testCase)
            working = ProjectionAlignmentFeatureMatcherTest.makeTexturedWorkingImages();
            capabilities = ProjectionAlignmentFeatureMatcher.capabilities();

            result = ProjectionAlignmentFeatureMatcher.match(working);

            testCase.verifyEqual(result.Format, ProjectionAlignmentFeatureMatcher.Format);
            testCase.verifyTrue(ismember(result.Detector.Method, ...
                capabilities.AvailableDetectors));
            testCase.verifyGreaterThan(result.Diagnostics.TotalMatches, 0);
        end

        function testMatchWorkingImagesReturnsPairwiseMappings(testCase)
            working = ProjectionAlignmentFeatureMatcherTest.makeTexturedWorkingImages();
            options = struct(Detector=struct(Method="sift", MaxFeatures=100));

            result = ProjectionAlignmentFeatureMatcher.match(working, options);
            pairMatch = result.Matches;

            testCase.verifyEqual(result.Detector.Method, "sift");
            testCase.verifyEqual(pairMatch.Pair, [2 1]);
            testCase.verifyEqual(pairMatch.PairLayerIds, ...
                [working.LayerImages(2).LayerId, working.LayerImages(1).LayerId]);
            testCase.verifyEqual(pairMatch.PairDirection, "movingToReference");
            testCase.verifyGreaterThan(result.Features(1).Count, 0);
            testCase.verifyGreaterThan(result.Features(2).Count, 0);
            testCase.verifyGreaterThan(pairMatch.Count, 0);
            testCase.verifyNumElements(result.Diagnostics.PairDiagnostics, 1);
            testCase.verifyGreaterThan( ...
                result.Diagnostics.PairDiagnostics.Confidence, 0);
            testCase.verifySize(pairMatch.MovingFeatureLocations, [pairMatch.Count 2]);
            testCase.verifySize(pairMatch.ReferenceFeatureLocations, [pairMatch.Count 2]);
            testCase.verifySize(pairMatch.MovingPlaneCoordinates, [pairMatch.Count 2]);
            testCase.verifySize(pairMatch.ReferencePlaneCoordinates, [pairMatch.Count 2]);
            testCase.verifyTrue(all(isfinite(pairMatch.MovingPlaneCoordinates), "all"));
            testCase.verifyTrue(all(isfinite(pairMatch.ReferencePlaneCoordinates), "all"));
            testCase.verifyTrue(all(isfinite(pairMatch.MovingSourceRows)));
            testCase.verifyTrue(all(isfinite(pairMatch.ReferenceSourceColumns)));
            testCase.verifyNumElements(pairMatch.MatchLedger, pairMatch.Count);
            testCase.verifyNumElements(result.MatchLedger, pairMatch.Count);
        end

        function testAutoDetectorFindsManySyntheticRedBlueFixtureMatches(testCase)
            capabilities = ProjectionAlignmentFeatureMatcher.capabilities();
            testCase.assumeTrue(ismember("kaze", capabilities.AvailableDetectors));
            projectRoot = fileparts(fileparts(mfilename("fullpath")));
            imagePath = fullfile(projectRoot, "test_data", "10.tif");
            testCase.assumeTrue(isfile(imagePath));
            scene = ProjectionAlignmentSyntheticHarness.createSceneFromRgbTiff( ...
                imagePath);
            options = ProjectionAlignmentOptions.validate(struct( ...
                Detector=struct(Method="auto", MaxFeatures=1000), ...
                Matcher=struct(MaxRatio=0.9), ...
                FilterPipeline=struct(GeometricMethod="none")));
            request = ProjectionAlignmentRequest.validate(struct( ...
                Scene=scene, LayerIndices=[2 1], ReferenceLayerIndex=1, ...
                AnalysisBands=[1 1], Options=options));
            working = ProjectionAlignmentWorkingImageRenderer.render( ...
                scene, request, struct(OutputSize=[512 512], ...
                MaxOutputPixels=512 * 512));

            result = ProjectionAlignmentFeatureMatcher.match(working, options);
            filtered = ProjectionAlignmentMatchFilter.filter(result, options);

            testCase.verifyEqual(result.Detector.Method, "kaze");
            testCase.verifyGreaterThan(filtered.Matches.Count, 40);
            testCase.verifyGreaterThan( ...
                result.Diagnostics.PairDiagnostics.Confidence, 0.75);
        end

        function testConstantImagesReturnEmptyMatches(testCase)
            working = ProjectionAlignmentFeatureMatcherTest.makeConstantWorkingImages();
            options = struct(Detector=struct(Method="sift", MaxFeatures=100));

            result = ProjectionAlignmentFeatureMatcher.match(working, options);

            testCase.verifyEqual([result.Features.Count], [0 0]);
            testCase.verifyEqual(result.Matches.Count, 0);
            testCase.verifyEqual(result.Diagnostics.TotalMatches, 0);
        end

        function testDiagnosticViewCreatesInvisibleFigure(testCase)
            working = ProjectionAlignmentFeatureMatcherTest.makeTexturedWorkingImages();
            result = ProjectionAlignmentFeatureMatcher.match( ...
                working, struct(Detector=struct(Method="sift", MaxFeatures=100)));
            capabilities = ProjectionAlignmentFeatureMatcher.capabilities();
            testCase.assumeTrue(capabilities.HasShowMatchedFeatures);

            fig = ProjectionAlignmentFeatureMatcher.showMatchedPair( ...
                working, result, 1, struct(Visible="off"));
            testCase.addTeardown(@() delete(fig));

            testCase.verifyTrue(isvalid(fig));
            testCase.verifyEqual(string(fig.Visible), "off");
            testCase.verifyEqual(string(fig.Name), ...
                "Projection Alignment Matched Features");
        end

        function testMultiImageScheduleDetectsFeaturesOnEachPairGrid(testCase)
            imageData = ProjectionAlignmentFeatureMatcherTest.textureImage();
            scene = ProjectionViewerHarness.createSceneFromImages( ...
                {imageData, imageData, imageData}, ...
                ["layer1.tif", "layer2.tif", "layer3.tif"], ...
                struct(RowStride=1, ColumnStride=1));
            options = ProjectionAlignmentOptions.validate(struct( ...
                Detector=struct(Method="sift", MaxFeatures=100), ...
                Scheduling=struct(Strategy="centerStar", ...
                ReferenceLayerIndex=2)));
            request = ProjectionAlignmentRequest.validate(struct(Scene=scene, ...
                LayerIndices=[1 2 3], ReferenceLayerIndex=2, ...
                AnalysisBands=[1 1 1], Options=options));
            working = ProjectionAlignmentWorkingImageRenderer.render( ...
                scene, request, struct(OutputSize=[80 80]));

            result = ProjectionAlignmentFeatureMatcher.match(working, options);

            testCase.verifyNumElements(working.PairWorkingImages, 2);
            testCase.verifyNumElements(result.Features, 4);
            testCase.verifyEqual([result.Features.PairIndex], [1 1 2 2]);
            testCase.verifyEqual(string({result.Features.Role}), ...
                ["moving" "reference" "moving" "reference"]);
            testCase.verifyNumElements(result.Matches, 2);
            testCase.verifyTrue(all([result.Matches.Count] > 0));
        end

        function testFeatureSupportRejectsInvalidMaskBoundary(testCase)
            working = ...
                ProjectionAlignmentFeatureMatcherTest.makeLargeTexturedWorkingImages();
            imageSize = working.OutputSize;
            margin = 15;
            supportRadius = 6;
            validMask = false(imageSize);
            validMask((margin + 1):(end - margin), ...
                (margin + 1):(end - margin)) = true;
            working = ProjectionAlignmentFeatureMatcherTest.setWorkingMask( ...
                working, validMask);

            result = ProjectionAlignmentFeatureMatcher.match(working, struct( ...
                Detector=struct(Method="sift", MaxFeatures=500, ...
                MaskSupportRadiusPixels=supportRadius)));

            testCase.verifyTrue(all( ...
                result.Diagnostics.MaskRejectedFeatureCounts > 0));
            for k = 1:numel(result.Features)
                locations = result.Features(k).Locations;
                testCase.verifyGreaterThanOrEqual(locations(:, 1), ...
                    margin + supportRadius - 1);
                testCase.verifyLessThanOrEqual(locations(:, 1), ...
                    imageSize(2) - margin - supportRadius + 2);
                testCase.verifyGreaterThanOrEqual(locations(:, 2), ...
                    margin + supportRadius - 1);
                testCase.verifyLessThanOrEqual(locations(:, 2), ...
                    imageSize(1) - margin - supportRadius + 2);
            end
        end

        function testMetricThresholdAndAnalysisScaleAreApplied(testCase)
            working = ...
                ProjectionAlignmentFeatureMatcherTest.makeLargeTexturedWorkingImages();
            baseOptions = struct(Detector=struct(Method="sift", ...
                MaxFeatures=500, MaskSupportRadiusPixels=0));
            base = ProjectionAlignmentFeatureMatcher.match( ...
                working, baseOptions);
            maximumMetric = max(cellfun(@max, {base.Features.Metrics}));

            thresholded = ProjectionAlignmentFeatureMatcher.match(working, ...
                struct(Detector=struct(Method="sift", MaxFeatures=500, ...
                MetricThreshold=maximumMetric + 1, ...
                MaskSupportRadiusPixels=0)));
            scaled = ProjectionAlignmentFeatureMatcher.match(working, ...
                struct(Detector=struct(Method="sift", MaxFeatures=500, ...
                AnalysisScale=0.5, MaskSupportRadiusPixels=0)));

            testCase.verifyEqual([thresholded.Features.Count], [0 0]);
            testCase.verifyEqual( ...
                [thresholded.Features.MetricRejectedCount], ...
                [thresholded.Features.DetectedCount]);
            expectedSize = max(2, round(working.OutputSize * 0.5));
            testCase.verifyEqual(scaled.Features(1).PreparedImageSize, ...
                expectedSize);
            testCase.verifyEqual( ...
                scaled.Features(1).AnalysisScaleActual, ...
                expectedSize ./ working.OutputSize, AbsTol=1e-12);
            testCase.verifyEqual( ...
                scaled.Features(1).Normalization.Method, "validMinMax");
            testCase.verifyGreaterThanOrEqual( ...
                min(scaled.Features(1).Locations, [], 1), [1 1]);
            testCase.verifyLessThanOrEqual( ...
                max(scaled.Features(1).Locations, [], 1), ...
                fliplr(working.OutputSize));
        end

        function testEveryAvailableDetectorIsExactlyRepeatable(testCase)
            working = ...
                ProjectionAlignmentFeatureMatcherTest.makeLargeTexturedWorkingImages();
            capabilities = ProjectionAlignmentFeatureMatcher.capabilities();

            for method = capabilities.AvailableDetectors
                options = struct(Detector=struct(Method=method, ...
                    MaxFeatures=300), Matcher=struct(Method="exhaustive", ...
                    MaxRatio=0.9));
                first = ProjectionAlignmentFeatureMatcher.match(working, options);
                second = ProjectionAlignmentFeatureMatcher.match(working, options);

                testCase.verifyEqual(first.Detector.RequestedMethod, method);
                testCase.verifyEqual(first.Detector.Method, method);
                testCase.verifyFalse(first.Detector.FallbackUsed);
                ProjectionAlignmentFeatureMatcherTest.verifyRepeatableRecords( ...
                    testCase, first, second);
            end
        end

        function testMatcherDispatchAndThresholdsAreExplicit(testCase)
            working = ...
                ProjectionAlignmentFeatureMatcherTest.makeLargeTexturedWorkingImages();
            methods = ["nearestNeighborRatio", "exhaustive"];
            expectedSearch = ["Exhaustive", "Exhaustive"];

            for k = 1:numel(methods)
                options = struct(Detector=struct(Method="sift", ...
                    MaxFeatures=300), Matcher=struct(Method=methods(k), ...
                    MatchThreshold=50, MaxRatio=0.9, Unique=true));
                first = ProjectionAlignmentFeatureMatcher.match(working, options);
                second = ProjectionAlignmentFeatureMatcher.match(working, options);

                testCase.verifyEqual(first.Matcher.RequestedMethod, methods(k));
                testCase.verifyEqual(first.Matcher.SearchMethod, expectedSearch(k));
                testCase.verifyEqual(first.Matcher.MatchThreshold, 50);
                testCase.verifyEqual(first.Matcher.MaxRatio, 0.9);
                testCase.verifyTrue(first.Matcher.Unique);
                testCase.verifyEqual(first.Matches.MatcherSearchMethod, ...
                    expectedSearch(k));
                testCase.verifyEqual(first.Matches.IndexPairs, ...
                    second.Matches.IndexPairs);
                testCase.verifyEqual(first.Matches.MatchMetric, ...
                    second.Matches.MatchMetric);
            end
        end

        function testDiagnosticsExplainFeatureAndMatcherStages(testCase)
            working = ...
                ProjectionAlignmentFeatureMatcherTest.makeLargeTexturedWorkingImages();

            result = ProjectionAlignmentFeatureMatcher.match(working, struct( ...
                Detector=struct(Method="sift", MaxFeatures=75, ...
                AnalysisScale=0.75, MaskSupportRadiusPixels=5), ...
                Matcher=struct(Method="exhaustive")));

            testCase.verifyNumElements(result.Diagnostics.FeatureRecords, 2);
            testCase.verifyEqual(result.Diagnostics.Detector.Method, "sift");
            testCase.verifyEqual(result.Diagnostics.Matcher.SearchMethod, ...
                "Exhaustive");
            testCase.verifyGreaterThanOrEqual( ...
                result.Diagnostics.TimingSeconds.Preparation, 0);
            testCase.verifyGreaterThanOrEqual( ...
                result.Diagnostics.TimingSeconds.Detection, 0);
            testCase.verifyGreaterThanOrEqual( ...
                result.Diagnostics.TimingSeconds.DescriptorExtraction, 0);
            testCase.verifyGreaterThanOrEqual( ...
                result.Diagnostics.TimingSeconds.Matching, 0);
            records = result.Diagnostics.FeatureRecords;
            testCase.verifyEqual([records.FinalCount], ...
                result.Diagnostics.FeatureCounts);
            testCase.verifyEqual([records.MaskRejectedCount], ...
                result.Diagnostics.MaskRejectedFeatureCounts);
            testCase.verifyEqual([records.AnalysisScaleRequested], [0.75 0.75]);
        end
    end

    methods (Static, Access = private)
        function working = makeTexturedWorkingImages()
            imageData = ProjectionAlignmentFeatureMatcherTest.textureImage();
            scene = ProjectionViewerHarness.createSceneFromImages( ...
                {imageData, imageData}, ["layer1.tif", "layer2.tif"], ...
                struct(RowStride=1, ColumnStride=1));
            working = ProjectionAlignmentWorkingImageRenderer.render( ...
                scene, struct(LayerIndices=[1 2], AnalysisBands=[1 1]), ...
                struct(OutputSize=[80 80], Interpolation="nearest"));
        end

        function working = makeConstantWorkingImages()
            imageData = zeros(80, 80, "uint8");
            scene = ProjectionViewerHarness.createSceneFromImages( ...
                {imageData, imageData}, ["layer1.tif", "layer2.tif"], ...
                struct(RowStride=1, ColumnStride=1));
            working = ProjectionAlignmentWorkingImageRenderer.render( ...
                scene, struct(LayerIndices=[1 2], AnalysisBands=[1 1]), ...
                struct(OutputSize=[80 80], Interpolation="nearest"));
        end

        function working = makeLargeTexturedWorkingImages()
            [x, y] = meshgrid(1:320, 1:320);
            imageData = uint8(mod(3 * x + 5 * y + ...
                40 * sin(x / 3) + 30 * cos(y / 5) + ...
                20 * sin((x + y) / 7), 256));
            scene = ProjectionViewerHarness.createSceneFromImages( ...
                {imageData, imageData}, ["layer1.tif", "layer2.tif"], ...
                struct(RowStride=1, ColumnStride=1));
            working = ProjectionAlignmentWorkingImageRenderer.render( ...
                scene, struct(LayerIndices=[1 2], AnalysisBands=[1 1]), ...
                struct(OutputSize=[240 240], Interpolation="nearest"));
        end

        function working = setWorkingMask(working, validMask)
            for k = 1:numel(working.LayerImages)
                working.LayerImages(k).ValidMask = validMask;
            end
            working.PairOverlapMasks.Mask = validMask;
            working.PairOverlapMasks.Count = nnz(validMask);
            working.PairWorkingImages(1).LayerImages = working.LayerImages;
            working.PairWorkingImages(1).PairOverlapMasks = ...
                working.PairOverlapMasks;
        end

        function verifyRepeatableRecords(testCase, first, second)
            testCase.verifyEqual([first.Features.Count], ...
                [second.Features.Count]);
            testCase.verifyEqual([first.Features.DetectedCount], ...
                [second.Features.DetectedCount]);
            for k = 1:numel(first.Features)
                testCase.verifyEqual(first.Features(k).Locations, ...
                    second.Features(k).Locations);
                testCase.verifyEqual(first.Features(k).Metrics, ...
                    second.Features(k).Metrics);
                testCase.verifyEqual(first.Features(k).DescriptorSize, ...
                    second.Features(k).DescriptorSize);
                testCase.verifyEqual(first.Features(k).DetectorParameters, ...
                    second.Features(k).DetectorParameters);
            end
            testCase.verifyEqual(first.Matches.IndexPairs, ...
                second.Matches.IndexPairs);
            testCase.verifyEqual(first.Matches.MatchMetric, ...
                second.Matches.MatchMetric);
            testCase.verifyEqual(first.Matches.MovingSourceRows, ...
                second.Matches.MovingSourceRows);
            testCase.verifyEqual(first.Matches.ReferenceSourceColumns, ...
                second.Matches.ReferenceSourceColumns);
        end

        function imageData = textureImage()
            [x, y] = meshgrid(1:80, 1:80);
            imageData = uint8(mod(3 * x + 5 * y + ...
                40 * sin(x / 3) + 30 * cos(y / 5), 256));
        end
    end
end
