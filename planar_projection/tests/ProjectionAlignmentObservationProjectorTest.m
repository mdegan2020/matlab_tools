classdef ProjectionAlignmentObservationProjectorTest < matlab.unittest.TestCase
    %ProjectionAlignmentObservationProjectorTest Exact overlay reprojection.

    properties (Constant)
        Tol = 1e-12
    end

    methods (TestClassSetup)
        function addSourceToPath(testCase)
            projectRoot = fileparts(fileparts(mfilename("fullpath")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(projectRoot, "src")));
        end
    end

    methods (Test)
        function testExactRaysApplyCurrentProjectionOffset(testCase)
            [scene, plane] = ...
                ProjectionAlignmentObservationProjectorTest.makeScene(false);

            projection = ProjectionAlignmentObservationProjector.project( ...
                scene, "layer-id", [1 2], [2 3], plane);

            testCase.verifyEqual(projection.Method, "exactSampledRay");
            testCase.verifyEqual(projection.ValidMask, [true; true]);
            testCase.verifyEqual(projection.Status, ["valid"; "valid"]);
            testCase.verifyEqual(projection.PlaneCoordinates, ...
                [22 7; 32 17], ...
                AbsTol=ProjectionAlignmentObservationProjectorTest.Tol);
        end

        function testOneOutsideObservationDoesNotInvalidateNeighbors(testCase)
            [scene, plane] = ...
                ProjectionAlignmentObservationProjectorTest.makeScene(false);

            projection = ProjectionAlignmentObservationProjector.project( ...
                scene, 1, [1 11 2], [2 2 3], plane);

            testCase.verifyEqual(projection.ValidMask, [true; false; true]);
            testCase.verifyEqual(projection.Status, ...
                ["valid"; "outsideSource"; "valid"]);
            testCase.verifyEqual(projection.PlaneCoordinates([1 3], :), ...
                [22 7; 32 17], ...
                AbsTol=ProjectionAlignmentObservationProjectorTest.Tol);
            testCase.verifyTrue(all(isnan( ...
                projection.PlaneCoordinates(2, :))));
        end

        function testBehindSourceRayIsIndependentlyRejected(testCase)
            [scene, plane] = ...
                ProjectionAlignmentObservationProjectorTest.makeScene(true);

            projection = ProjectionAlignmentObservationProjector.project( ...
                scene, 1, 1, 2, plane);

            testCase.verifyFalse(projection.ValidMask);
            testCase.verifyEqual(projection.Status, "behindSource");
            testCase.verifyTrue(all(isnan(projection.PlaneCoordinates)));
        end
    end

    methods (Static, Access = private)
        function [scene, plane] = makeScene(reverseRay)
            plane = PlanarProjection.definePlaneFromBasis( ...
                [10; 0; 0], [0; 1; 0], [0; 0; 1]);
            sourceGeometry = struct();
            sourceGeometry.ImageSize = [10 10];
            if reverseRay
                sourceGeometry.SampleRayFcn = ...
                    @ProjectionAlignmentObservationProjectorTest.reverseRay;
            else
                sourceGeometry.SampleRayFcn = ...
                    @ProjectionAlignmentObservationProjectorTest.forwardRay;
            end
            layer = struct(LayerId="layer-id", ...
                SourceGeometry=sourceGeometry, CurrentProjectionPlane=plane, ...
                ViewVectorAngularOffsetsDegrees=zeros(3, 1), ...
                ProjectionOffsetMeters=[2; -3]);
            scene = struct(layers=layer, renderOrigin=zeros(3, 1));
        end

        function [origin, vector] = forwardRay(row, column)
            origin = zeros(3, numel(row));
            vector = [ones(1, numel(row)); column(:).'; row(:).'];
        end

        function [origin, vector] = reverseRay(row, column)
            [origin, vector] = ...
                ProjectionAlignmentObservationProjectorTest.forwardRay( ...
                row, column);
            vector(1, :) = -vector(1, :);
        end
    end
end
