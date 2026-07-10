classdef ProjectionAlignmentWorkingGridTest < matlab.unittest.TestCase
    %ProjectionAlignmentWorkingGridTest Pair-overlap grid stability tests.

    properties (Constant)
        Tol = 1e-10
    end

    methods (TestClassSetup)
        function addSourceToPath(testCase)
            projectRoot = fileparts(fileparts(mfilename("fullpath")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(projectRoot, "src")));
        end
    end

    methods (Test)
        function testGridUsesQuantizedPairOverlapAndIsotropicPixels(testCase)
            scene = ProjectionAlignmentWorkingGridTest.makeScene();

            grid = ProjectionAlignmentWorkingGrid.plan( ...
                scene, [2 1], struct(OutputSize=[64 80]));

            testCase.verifyEqual(grid.Pair, [2 1]);
            testCase.verifyEqual(grid.PairLayerIds, ...
                [scene.layers(2).LayerId scene.layers(1).LayerId]);
            testCase.verifyLessThanOrEqual(grid.OutputSize, [64 80]);
            testCase.verifyEqual(grid.PixelSpacingMeters, ...
                [1 1] * grid.ResolutionMetersPerPixel, ...
                AbsTol=ProjectionAlignmentWorkingGridTest.Tol);
            testCase.verifyEqual(grid.RawOverlapBounds.X(1), ...
                max(grid.LayerExtents(1).Bounds(1), ...
                grid.LayerExtents(2).Bounds(1)), ...
                AbsTol=ProjectionAlignmentWorkingGridTest.Tol);
            testCase.verifyEqual(grid.RawOverlapBounds.X(2), ...
                min(grid.LayerExtents(1).Bounds(2), ...
                grid.LayerExtents(2).Bounds(2)), ...
                AbsTol=ProjectionAlignmentWorkingGridTest.Tol);
        end

        function testSmallOffsetPerturbationKeepsGridSchedule(testCase)
            scene = ProjectionAlignmentWorkingGridTest.makeScene();
            grid = ProjectionAlignmentWorkingGrid.plan( ...
                scene, [2 1], struct(OutputSize=[64 80]));
            perturbed = scene;
            perturbation = 0.01 * grid.ResolutionMetersPerPixel;
            perturbed.layers(2).ProjectionOffsetMeters = ...
                perturbed.layers(2).ProjectionOffsetMeters + [perturbation; 0];

            perturbedGrid = ProjectionAlignmentWorkingGrid.plan( ...
                perturbed, [2 1], struct(OutputSize=[64 80]));

            testCase.verifyEqual(perturbedGrid.GridKey, grid.GridKey);
            testCase.verifyEqual(perturbedGrid.Bounds, grid.Bounds);
            testCase.verifyEqual(perturbedGrid.OutputSize, grid.OutputSize);
        end

        function testFullSourceModeUsesSameGridAsSparseMode(testCase)
            scene = ProjectionAlignmentWorkingGridTest.makeScene();
            request = struct(LayerIndices=[2 1], AnalysisBands=[1 1]);
            baseOptions = struct(OutputSize=[64 80], ...
                NumericalMode="sparseIntensityScatteredInterpolant");

            sparse = ProjectionAlignmentWorkingImageRenderer.render( ...
                scene, request, baseOptions);
            fullSourceOptions = baseOptions;
            fullSourceOptions.NumericalMode = "fullSourceInverseWarp";
            fullSource = ProjectionAlignmentWorkingImageRenderer.render( ...
                scene, request, fullSourceOptions);

            testCase.verifyEqual(fullSource.GridKeys, sparse.GridKeys);
            testCase.verifyEqual(fullSource.OutputSize, sparse.OutputSize);
            testCase.verifyEqual(fullSource.NumericalMode, ...
                "fullSourceInverseWarp");
            testCase.verifyEqual(sparse.NumericalMode, ...
                "sparseIntensityScatteredInterpolant");
        end
    end

    methods (Static, Access = private)
        function scene = makeScene()
            [x, y] = meshgrid(1:80, 1:64);
            imageData = uint8(mod(3 * x + 5 * y, 256));
            scene = ProjectionViewerHarness.createSceneFromImages( ...
                {imageData, imageData}, ["one.tif", "two.tif"], ...
                struct(RowStride=4, ColumnStride=4, GSD=0.5, ...
                PlatformStepMeters=0.5));
        end
    end
end
