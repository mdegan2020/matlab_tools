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

        function imageData = textureImage()
            [x, y] = meshgrid(1:80, 1:80);
            imageData = uint8(mod(3 * x + 5 * y + ...
                40 * sin(x / 3) + 30 * cos(y / 5), 256));
        end
    end
end
