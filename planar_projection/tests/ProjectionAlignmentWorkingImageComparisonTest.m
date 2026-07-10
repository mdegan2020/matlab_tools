classdef ProjectionAlignmentWorkingImageComparisonTest < matlab.unittest.TestCase
    %ProjectionAlignmentWorkingImageComparisonTest Renderer decision harness.

    methods (TestClassSetup)
        function addSourceToPath(testCase)
            projectRoot = fileparts(fileparts(mfilename("fullpath")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(projectRoot, "src")));
        end
    end

    methods (Test)
        function testEvaluateReportsBothModesAndRepeatability(testCase)
            [scene, request] = ...
                ProjectionAlignmentWorkingImageComparisonTest.makeInputs();

            comparison = ProjectionAlignmentWorkingImageComparison.evaluate( ...
                scene, request, struct(RenderOptions=struct( ...
                OutputSize=[80 80], Interpolation="nearest"), ...
                PerturbationDegrees=[1e-5 0 0], RunSolve=false));
            summary = ProjectionAlignmentWorkingImageComparison.summary(comparison);
            repeatSummaries = [summary.Modes.ExactRepeat];

            testCase.verifyEqual([summary.Modes.Mode], ...
                ProjectionAlignmentWorkingImageComparison.Modes);
            testCase.verifyTrue(all([repeatSummaries.GridKeysEqual]));
            testCase.verifyTrue(all([repeatSummaries.MasksEqual]));
            testCase.verifyEqual( ...
                [repeatSummaries.MaxAbsoluteImageDifference], [0 0]);
            testCase.verifyGreaterThan( ...
                min([summary.Modes.RawMatchCounts]), 0);
            testCase.verifyEqual(summary.DefaultDecision, "pendingUserReview");
            testCase.verifyEqual(summary.CurrentDefault, ...
                "sparseIntensityScatteredInterpolant");
            testCase.verifyEqual(summary.Modes(1).GridKeys, ...
                summary.Modes(2).GridKeys);
        end

        function testWriteArtifactsCreatesReviewFiles(testCase)
            [scene, request] = ...
                ProjectionAlignmentWorkingImageComparisonTest.makeInputs();
            comparison = ProjectionAlignmentWorkingImageComparison.evaluate( ...
                scene, request, struct(RenderOptions=struct(OutputSize=[40 40]), ...
                RunSolve=false));
            outputDirectory = tempname;
            testCase.addTeardown(@() ...
                ProjectionAlignmentWorkingImageComparisonTest.removeFolder( ...
                outputDirectory));

            artifacts = ProjectionAlignmentWorkingImageComparison.writeArtifacts( ...
                outputDirectory, comparison);

            testCase.verifyTrue(isfile(artifacts.SummaryPath));
            testCase.verifyTrue(isfile(artifacts.MatPath));
            testCase.verifyNumElements(artifacts.ImagePaths, 4);
            testCase.verifyTrue(all(isfile(artifacts.ImagePaths)));
            testCase.verifyNumElements(artifacts.OverlayPaths, 2);
            testCase.verifyTrue(all(isfile(artifacts.OverlayPaths)));
        end
    end

    methods (Static, Access = private)
        function [scene, request] = makeInputs()
            [x, y] = meshgrid(1:80, 1:80);
            imageData = uint8(mod(3 * x + 5 * y + ...
                40 * sin(x / 3) + 30 * cos(y / 5), 256));
            scene = ProjectionViewerHarness.createSceneFromImages( ...
                {imageData, imageData}, ["one.tif", "two.tif"], ...
                struct(RowStride=2, ColumnStride=2));
            options = ProjectionAlignmentOptions.validate(struct( ...
                Detector=struct(Method="sift", MaxFeatures=200), ...
                FilterPipeline=struct(GeometricMethod="none")));
            request = ProjectionAlignmentRequest.validate(struct(Scene=scene, ...
                LayerIndices=[2 1], ReferenceLayerIndex=1, ...
                AnalysisBands=[1 1], Options=options));
        end

        function removeFolder(folderPath)
            if isfolder(folderPath)
                rmdir(folderPath, "s");
            end
        end
    end
end
