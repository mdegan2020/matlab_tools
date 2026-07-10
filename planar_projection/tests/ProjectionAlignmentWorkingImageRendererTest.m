classdef ProjectionAlignmentWorkingImageRendererTest < matlab.unittest.TestCase
    %ProjectionAlignmentWorkingImageRendererTest Tests projection-plane images.

    properties (Constant)
        Tol = 1e-10
    end

    methods (TestClassSetup)
        function addSourceToPath(testCase)
            projectRoot = fileparts(fileparts(mfilename("fullpath")));
            srcFolder = fullfile(projectRoot, "src");
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(srcFolder));
        end
    end

    methods (Test)
        function testRenderSelectedLayersToCommonProjectionPlane(testCase)
            scene = ProjectionAlignmentWorkingImageRendererTest.makeTwoLayerScene();
            request = struct(LayerIndices=[1 2], AnalysisBands=[1 1]);

            working = ProjectionAlignmentWorkingImageRenderer.render( ...
                scene, request, struct(OutputSize=[6 7]));

            testCase.verifyEqual(working.Format, ...
                ProjectionAlignmentWorkingImageRenderer.Format);
            testCase.verifyEqual(working.LayerIndices, [1 2]);
            testCase.verifyEqual(working.ReferenceLayerIndex, 1);
            testCase.verifyEqual(working.OutputSize, [6 7]);
            testCase.verifyEqual(working.NumericalMode, ...
                "sparseIntensityScatteredInterpolant");
            testCase.verifyNumElements(working.LayerImages, 2);
            testCase.verifySize(working.LayerImages(1).Image, [6 7]);
            testCase.verifySize(working.LayerImages(2).Image, [6 7]);
            testCase.verifySize(working.LayerMasks, [6 7 2]);
            testCase.verifySize(working.PixelToPlane.Coordinates, [2 42]);
            testCase.verifyEqual(working.PairOverlapMasks.Pair, [2 1]);
            testCase.verifyGreaterThan(working.PairOverlapMasks.Count, 0);
        end

        function testAnalysisBandSelectionUsesSingleBandImages(testCase)
            scene = ProjectionAlignmentWorkingImageRendererTest.makeRgbTwoLayerScene();
            request = struct(LayerIndices=[1 2], AnalysisBands=[2 3]);

            working = ProjectionAlignmentWorkingImageRenderer.render( ...
                scene, request, struct(OutputSize=[4 5], Interpolation="nearest"));
            firstImage = working.LayerImages(1).Image;
            secondImage = working.LayerImages(2).Image;

            testCase.verifyTrue(ismatrix(firstImage));
            testCase.verifyTrue(ismatrix(secondImage));
            testCase.verifyEqual(firstImage(working.LayerImages(1).ValidMask), ...
                20 * ones(nnz(working.LayerImages(1).ValidMask), 1), ...
                AbsTol=ProjectionAlignmentWorkingImageRendererTest.Tol);
            testCase.verifyEqual(secondImage(working.LayerImages(2).ValidMask), ...
                60 * ones(nnz(working.LayerImages(2).ValidMask), 1), ...
                AbsTol=ProjectionAlignmentWorkingImageRendererTest.Tol);
        end

        function testSourceObservationMapsAreFiniteForValidPixels(testCase)
            scene = ProjectionAlignmentWorkingImageRendererTest.makeTwoLayerScene();
            request = struct(LayerIndices=[1 2], AnalysisBands=[1 1]);

            working = ProjectionAlignmentWorkingImageRenderer.render( ...
                scene, request, struct(OutputSize=[6 7]));
            sourceRows = working.LayerImages(1).SourceRows( ...
                working.LayerImages(1).SourceObservationMask);
            sourceColumns = working.LayerImages(1).SourceColumns( ...
                working.LayerImages(1).SourceObservationMask);

            testCase.verifyGreaterThan(numel(sourceRows), 0);
            testCase.verifyTrue(all(isfinite(sourceRows)));
            testCase.verifyTrue(all(isfinite(sourceColumns)));
            testCase.verifyGreaterThanOrEqual(min(sourceRows), 1);
            testCase.verifyLessThanOrEqual(max(sourceRows), 4);
            testCase.verifyGreaterThanOrEqual(min(sourceColumns), 1);
            testCase.verifyLessThanOrEqual(max(sourceColumns), 5);
        end

        function testPairOverlapMaskRequiresBothLayerMasks(testCase)
            scene = ProjectionAlignmentWorkingImageRendererTest.makeTwoLayerScene();
            request = struct(LayerIndices=[1 2], AnalysisBands=[1 1]);

            working = ProjectionAlignmentWorkingImageRenderer.render( ...
                scene, request, struct(OutputSize=[6 7]));
            expectedMask = working.LayerImages(1).ValidMask & ...
                working.LayerImages(2).ValidMask;

            testCase.verifyEqual(working.PairOverlapMasks.Mask, expectedMask);
            testCase.verifyEqual(working.PairOverlapMasks.Count, nnz(expectedMask));
        end

        function testPairOverlapMasksFollowConfiguredSchedule(testCase)
            scene = ProjectionAlignmentWorkingImageRendererTest.makeMultiLayerScene(5);
            request = struct();
            request.Options = struct(Scheduling=struct(Strategy="centerStar"));

            working = ProjectionAlignmentWorkingImageRenderer.render( ...
                scene, request, struct(OutputSize=[4 5]));

            pairs = reshape([working.PairOverlapMasks.Pair], 2, []).';
            testCase.verifyEqual(working.Schedule.ReferenceLayerIndex, 3);
            testCase.verifyEqual(pairs, [2 3; 4 3; 1 3; 5 3]);
        end

        function testWorkingMeshDoesNotUseDisplayDepthStagger(testCase)
            scene = ProjectionAlignmentWorkingImageRendererTest.makeTwoLayerScene();
            request = struct(LayerIndices=[1 2], AnalysisBands=[1 1]);
            directMesh = ProjectionMeshBuilder.buildLayerMesh( ...
                scene.layers(2), scene.layers(2).CurrentProjectionPlane, ...
                scene.renderOrigin);

            working = ProjectionAlignmentWorkingImageRenderer.render( ...
                scene, request, struct(OutputSize=[5 6]));

            testCase.verifyEqual(working.LayerImages(2).Mesh.WorldPoints, ...
                directMesh.WorldPoints, ...
                AbsTol=ProjectionAlignmentWorkingImageRendererTest.Tol);
        end

        function testInvalidAnalysisBandErrors(testCase)
            scene = ProjectionAlignmentWorkingImageRendererTest.makeRgbTwoLayerScene();
            request = struct(LayerIndices=[1 2], AnalysisBands=[4 1]);

            testCase.verifyError( ...
                @() ProjectionAlignmentWorkingImageRenderer.render( ...
                scene, request, struct(OutputSize=[4 5])), ...
                "ProjectionAlignmentWorkingImageRenderer:invalidAnalysisBand");
        end
    end

    methods (Static, Access = private)
        function scene = makeTwoLayerScene()
            imageData1 = reshape(1:20, 4, 5);
            imageData2 = reshape(101:120, 4, 5);
            options = struct(RowStride=1, ColumnStride=1, ...
                GSD=0.5, PlatformStepMeters=0.5);
            scene = ProjectionViewerHarness.createSceneFromImages( ...
                {imageData1, imageData2}, ["layer1.tif", "layer2.tif"], options);
        end

        function scene = makeRgbTwoLayerScene()
            imageData1 = cat(3, 10 * ones(4, 5), 20 * ones(4, 5), ...
                30 * ones(4, 5));
            imageData2 = cat(3, 40 * ones(4, 5), 50 * ones(4, 5), ...
                60 * ones(4, 5));
            options = struct(RowStride=1, ColumnStride=1, ...
                GSD=0.5, PlatformStepMeters=0.5);
            scene = ProjectionViewerHarness.createSceneFromImages( ...
                {imageData1, imageData2}, ["layer1.tif", "layer2.tif"], options);
        end

        function scene = makeMultiLayerScene(layerCount)
            images = cell(1, layerCount);
            paths = strings(1, layerCount);
            for k = 1:layerCount
                images{k} = k * ones(4, 5);
                paths(k) = sprintf("layer%d.tif", k);
            end
            scene = ProjectionViewerHarness.createSceneFromImages( ...
                images, paths, struct(RowStride=1, ColumnStride=1, ...
                GSD=0.5, PlatformStepMeters=0.5));
        end
    end
end
