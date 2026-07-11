classdef ProjectionAlignmentGeometricModelTest < matlab.unittest.TestCase
    %ProjectionAlignmentGeometricModelTest Truthful robust 2-D model tests.

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
        function testSimilarityFitsRotationScaleTranslationAndRejectsOutliers( ...
                testCase)
            moving = ProjectionAlignmentGeometricModelTest.pointGrid();
            angle = deg2rad(12);
            scale = 1.03;
            linear = scale * [cos(angle) -sin(angle); ...
                sin(angle) cos(angle)];
            translation = [17; -9];
            reference = (linear * moving.' + translation).';
            reference(end - 1, :) = [500 -300];
            reference(end, :) = [-200 700];

            result = ProjectionAlignmentGeometricModel.fit( ...
                moving, reference, "similarity", ...
                struct(MaxDistancePixels=0.1));

            testCase.verifyEqual(result.Status, "fitted");
            testCase.verifyEqual(result.CoordinateSpace, "workingPixels");
            testCase.verifyEqual(result.Direction, "movingToReference");
            testCase.verifyEqual(result.AcceptedCount, size(moving, 1) - 2);
            testCase.verifyEqual(result.AcceptedMask(end - 1:end), ...
                [false; false]);
            testCase.verifyEqual(result.ModelMatrix(1:2, 1:2), linear, ...
                AbsTol=ProjectionAlignmentGeometricModelTest.Tol);
            testCase.verifyEqual(result.ModelMatrix(1:2, 3), translation, ...
                AbsTol=ProjectionAlignmentGeometricModelTest.Tol);
        end

        function testAffineFitsShearAndRejectsOutliers(testCase)
            moving = ProjectionAlignmentGeometricModelTest.pointGrid();
            linear = [1.02 0.08; -0.03 0.97];
            translation = [-4; 13];
            reference = (linear * moving.' + translation).';
            reference([2 end], :) = [300 -100; -150 400];

            result = ProjectionAlignmentGeometricModel.fit( ...
                moving, reference, "affine", ...
                struct(MaxDistancePixels=0.1));

            testCase.verifyEqual(result.Status, "fitted");
            testCase.verifyEqual(result.AcceptedCount, size(moving, 1) - 2);
            testCase.verifyEqual(result.AcceptedMask([2 end]), [false; false]);
            testCase.verifyEqual(result.ModelMatrix(1:2, 1:2), linear, ...
                AbsTol=ProjectionAlignmentGeometricModelTest.Tol);
            testCase.verifyEqual(result.ModelMatrix(1:2, 3), translation, ...
                AbsTol=ProjectionAlignmentGeometricModelTest.Tol);
        end

        function testExactRepeatProducesIdenticalRecords(testCase)
            moving = ProjectionAlignmentGeometricModelTest.pointGrid();
            reference = moving + [5 * ones(size(moving, 1), 1), ...
                -2 * ones(size(moving, 1), 1)];
            reference(end, :) = [1000 1000];

            first = ProjectionAlignmentGeometricModel.fit( ...
                moving, reference, "similarity", ...
                struct(MaxDistancePixels=1));
            second = ProjectionAlignmentGeometricModel.fit( ...
                moving, reference, "similarity", ...
                struct(MaxDistancePixels=1));

            testCase.verifyEqual(first, second);
        end

        function testInsufficientAndNonfinitePointsAreExplicit(testCase)
            result = ProjectionAlignmentGeometricModel.fit( ...
                [1 2; NaN 3], [4 5; 6 7], "affine", struct());

            testCase.verifyEqual(result.Status, "insufficientPoints");
            testCase.verifyEqual(result.FiniteMask, [true; false]);
            testCase.verifyEqual(result.AcceptedMask, [true; false]);
        end
    end

    methods (Static, Access = private)
        function points = pointGrid()
            [x, y] = meshgrid(0:4, 0:3);
            points = [x(:) y(:)];
        end
    end
end
