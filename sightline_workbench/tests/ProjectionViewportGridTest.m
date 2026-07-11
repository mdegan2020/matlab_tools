classdef ProjectionViewportGridTest < matlab.unittest.TestCase
    %ProjectionViewportGridTest Tests for pure viewport-plane sampling.

    methods (TestClassSetup)
        function addSourceToPath(testCase)
            projectRoot = fileparts(fileparts(mfilename("fullpath")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(projectRoot, "src")));
        end
    end

    methods (Test)
        function testBuildCreatesRequestedOrthographicGrid(testCase)
            plane = PlanarProjection.definePlaneFromBasis( ...
                [0; 0; 0], [1; 0; 0], [0; 1; 0]);
            camera = struct(Position=[0; 0; 10], Target=[0; 0; 0], ...
                UpVector=[0; 1; 0], ViewAngle=20, ...
                Projection="orthographic");

            grid = ProjectionViewportGrid.build(camera, [5 9], plane);

            testCase.verifySize(grid.X, [5 9]);
            testCase.verifySize(grid.Y, [5 9]);
            testCase.verifySize(grid.ReferenceWorldPoints, [3 45]);
            testCase.verifyEqual(grid.ReferenceWorldPoints(3, :), ...
                zeros(1, 45), AbsTol=1e-12);
            testCase.verifyEqual(grid.X(1, :), -fliplr(grid.X(1, :)), ...
                AbsTol=1e-12);
            testCase.verifyEqual(grid.Y(:, 1), -flipud(grid.Y(:, 1)), ...
                AbsTol=1e-12);
        end

        function testTwistRotatesViewportAxesWithoutChangingExtent(testCase)
            plane = PlanarProjection.definePlaneFromBasis( ...
                [0; 0; 0], [1; 0; 0], [0; 1; 0]);
            camera = struct(Position=[0; 0; 10], Target=[0; 0; 0], ...
                UpVector=[0; 1; 0], ViewAngle=15);
            baseGrid = ProjectionViewportGrid.build(camera, [7 11], plane);
            camera.UpVector = [1; 0; 0];

            twistedGrid = ProjectionViewportGrid.build(camera, [7 11], plane);

            testCase.verifyEqual(twistedGrid.ViewWidth, baseGrid.ViewWidth, ...
                AbsTol=1e-12);
            testCase.verifyEqual(twistedGrid.ViewHeight, baseGrid.ViewHeight, ...
                AbsTol=1e-12);
            testCase.verifyEqual(abs(twistedGrid.RightVector.' * ...
                baseGrid.UpVector), 1, AbsTol=1e-12);
        end

        function testOutputGridReconstructsReferenceWorldPoints(testCase)
            plane = PlanarProjection.definePlaneFromBasis( ...
                [0; 0; 2], [1; 0; 0], [0; 1; 0]);
            camera = struct(Position=[0; 0; 12], Target=[0; 0; 2], ...
                UpVector=[0; 1; 0], ViewAngle=10);
            grid = ProjectionViewportGrid.build(camera, [6 8], plane);

            outputGrid = ProjectionViewportGrid.asOutputGrid(grid);
            queryX = linspace(outputGrid.Bounds.X(1), ...
                outputGrid.Bounds.X(2), outputGrid.OutputSize(2));
            queryY = linspace(outputGrid.Bounds.Y(2), ...
                outputGrid.Bounds.Y(1), outputGrid.OutputSize(1));
            [X, Y] = meshgrid(queryX, queryY);
            reconstructed = outputGrid.Origin + ...
                outputGrid.XAxis * X(:).' + outputGrid.YAxis * Y(:).';

            testCase.verifyEqual(reconstructed, grid.ReferenceWorldPoints, ...
                AbsTol=1e-12);
        end

        function testObliqueReferencePlaneUsesParallelRayIntersections(testCase)
            plane = PlanarProjection.definePlaneFromBasis( ...
                [0; 0; 0], [1; 0; 1], [0; 1; 0]);
            camera = struct(Position=[0; 0; 10], Target=[0; 0; 0], ...
                UpVector=[0; 1; 0], ViewAngle=12);

            grid = ProjectionViewportGrid.build(camera, [9 13], plane);
            planeCoordinates = PlanarProjection.worldToPlane( ...
                grid.ReferenceWorldPoints, plane);
            reconstructed = plane.P0 + plane.basis * planeCoordinates;

            testCase.verifyEqual(reconstructed, grid.ReferenceWorldPoints, ...
                AbsTol=1e-10);
        end

        function testPerspectiveCameraIsRejected(testCase)
            plane = PlanarProjection.definePlaneFromBasis( ...
                [0; 0; 0], [1; 0; 0], [0; 1; 0]);
            camera = struct(Position=[0; 0; 10], Target=[0; 0; 0], ...
                UpVector=[0; 1; 0], ViewAngle=10, ...
                Projection="perspective");

            testCase.verifyError( ...
                @() ProjectionViewportGrid.build(camera, [10 10], plane), ...
                "ProjectionViewportGrid:invalidCamera");
        end
    end
end
