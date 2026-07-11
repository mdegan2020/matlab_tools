classdef PlanarProjectionTest < matlab.unittest.TestCase
    %PlanarProjectionTest Unit tests for the PlanarProjection API.

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
        function testDefinePlaneReturnsExpectedAxes(testCase)
            G0 = [0; 0; 0];
            V0 = [0; 0; 1];
            V1 = [0; 1; 1];
            plane = PlanarProjection.definePlane(G0, V0, V1, 10);

            testCase.verifyEqual(plane.P0, [0; 0; 10], AbsTol=PlanarProjectionTest.Tol);
            testCase.verifyEqual(plane.basis, [1 0; 0 1; 0 0], AbsTol=PlanarProjectionTest.Tol);
            testCase.verifyEqual(plane.VN, [0; 0; 1], AbsTol=PlanarProjectionTest.Tol);
            PlanarProjectionTest.verifyPlaneFrame(testCase, plane);
        end

        function testDefinePlaneRejectsDegenerateYReference(testCase)
            testCase.verifyError( ...
                @() PlanarProjection.definePlane([0; 0; 0], [0; 0; 1], [0; 0; 1], 10), ...
                "PlanarProjection:degenerateGeometry");
        end

        function testDefineStereoPlaneContainsStereoPoints(testCase)
            plane = PlanarProjection.defineStereoPlane( ...
                [-1; 0; 0], [0; 0; 1], 10, ...
                [1; 0; 0], [0; 0; 1], 10);

            testCase.verifyEqual(plane.P0, [-1; 0; 10], AbsTol=PlanarProjectionTest.Tol);
            testCase.verifyEqual(plane.basis, [1 0; 0 1; 0 0], AbsTol=PlanarProjectionTest.Tol);
            testCase.verifyEqual(plane.VN, [0; 0; 1], AbsTol=PlanarProjectionTest.Tol);
            PlanarProjectionTest.verifyPlaneFrame(testCase, plane);
        end

        function testIntersectPlaneReturnsWorldAndPlaneCoordinates(testCase)
            plane = PlanarProjection.definePlaneFromBasis([0; 0; 5], [1; 0; 0], [0; 1; 0]);
            Vn = [0 1 -2; 0 2 -1; 5 5 5];
            [P, Q] = PlanarProjection.intersectPlane(Vn, [0; 0; 0], plane);

            testCase.verifyEqual(P, [0 1 -2; 0 2 -1; 5 5 5], AbsTol=PlanarProjectionTest.Tol);
            testCase.verifyEqual(Q, [0 1 -2; 0 2 -1], AbsTol=PlanarProjectionTest.Tol);
        end

        function testIntersectPlaneRejectsParallelRays(testCase)
            plane = PlanarProjection.definePlaneFromBasis([0; 0; 5], [1; 0; 0], [0; 1; 0]);

            testCase.verifyError( ...
                @() PlanarProjection.intersectPlane([1; 0; 0], [0; 0; 0], plane), ...
                "PlanarProjection:parallelRay");
        end

        function testReconstruct3dAndWorldToPlaneRoundTrip(testCase)
            plane = PlanarProjection.definePlaneFromBasis([1; 2; 3], [0; 1; 0], [0; 0; 1]);
            Q = [1 -2 4; 3 4 -5];
            P = PlanarProjection.reconstruct3d(Q, plane);
            QroundTrip = PlanarProjection.worldToPlane(P, plane);

            testCase.verifyEqual(QroundTrip, Q, AbsTol=PlanarProjectionTest.Tol);
        end

        function testMapPlaneToPlanePreservesCoplanarWorldPoint(testCase)
            plane1 = PlanarProjection.definePlaneFromBasis([0; 0; 0], [1; 0; 0], [0; 1; 0]);
            plane2 = PlanarProjection.definePlaneFromBasis([10; 20; 0], [1; 0; 0], [0; 1; 0]);
            Q1 = [11; 22];

            Q2 = PlanarProjection.mapPlaneToPlane(Q1, plane1, plane2);
            P1 = PlanarProjection.reconstruct3d(Q1, plane1);
            P2 = PlanarProjection.reconstruct3d(Q2, plane2);

            testCase.verifyEqual(Q2, [1; 2], AbsTol=PlanarProjectionTest.Tol);
            testCase.verifyEqual(P2, P1, AbsTol=PlanarProjectionTest.Tol);
        end

        function testDefineFitPlaneUsesClockwiseEdges(testCase)
            plane = PlanarProjection.defineFitPlane( ...
                [0; 0; 0], [0; 0; 1], ...
                [-2; -1; 5], [2; -1; 5], [2; 1; 5], [-2; 1; 5]);

            testCase.verifyEqual(plane.P0, [0; 0; 5], AbsTol=PlanarProjectionTest.Tol);
            testCase.verifyEqual(plane.basis, [1 0; 0 1; 0 0], AbsTol=PlanarProjectionTest.Tol);
            testCase.verifyEqual(plane.VN, [0; 0; 1], AbsTol=PlanarProjectionTest.Tol);
            PlanarProjectionTest.verifyPlaneFrame(testCase, plane);
        end

        function testDefineFrameCameraUsesPositiveFocalPlane(testCase)
            referencePlane = PlanarProjection.definePlaneFromBasis([0; 0; 10], [1; 0; 0], [0; 1; 0]);
            camera = PlanarProjection.defineFrameCamera([0; 0; 0], [0; 0; 1], 2, referencePlane);

            testCase.verifyEqual(camera.G0, [0; 0; 0], AbsTol=PlanarProjectionTest.Tol);
            testCase.verifyEqual(camera.V0, [0; 0; 1], AbsTol=PlanarProjectionTest.Tol);
            testCase.verifyEqual(camera.F, 2, AbsTol=PlanarProjectionTest.Tol);
            testCase.verifyEqual(camera.focalPlane.P0, [0; 0; 2], AbsTol=PlanarProjectionTest.Tol);
            PlanarProjectionTest.verifyPlaneFrame(testCase, camera.focalPlane);
        end

        function testProjectToCameraAndFromCameraRoundTripRays(testCase)
            referencePlane = PlanarProjection.definePlaneFromBasis([0; 0; 10], [1; 0; 0], [0; 1; 0]);
            camera = PlanarProjection.defineFrameCamera([0; 0; 0], [0; 0; 1], 2, referencePlane);
            P = [2 0; 4 -2; 4 2];

            [Q, Pp] = PlanarProjection.projectToCamera(P, camera);
            [Vn, PpRoundTrip] = PlanarProjection.projectFromCamera(Q, camera);

            testCase.verifyEqual(Q, [1 0; 2 -2], AbsTol=PlanarProjectionTest.Tol);
            testCase.verifyEqual(Pp, [1 0; 2 -2; 2 2], AbsTol=PlanarProjectionTest.Tol);
            testCase.verifyEqual(PpRoundTrip, Pp, AbsTol=PlanarProjectionTest.Tol);
            testCase.verifyEqual(PlanarProjection.normalizeVectors(Vn), ...
                PlanarProjection.normalizeVectors(P), AbsTol=PlanarProjectionTest.Tol);
        end

        function testProjectCameraToPlane(testCase)
            referencePlane = PlanarProjection.definePlaneFromBasis([0; 0; 10], [1; 0; 0], [0; 1; 0]);
            camera = PlanarProjection.defineFrameCamera([0; 0; 0], [0; 0; 1], 2, referencePlane);
            targetPlane = PlanarProjection.definePlaneFromBasis([0; 0; 10], [1; 0; 0], [0; 1; 0]);

            [Qplane, P] = PlanarProjection.projectCameraToPlane([1; 2], camera, targetPlane);

            testCase.verifyEqual(Qplane, [5; 10], AbsTol=PlanarProjectionTest.Tol);
            testCase.verifyEqual(P, [5; 10; 10], AbsTol=PlanarProjectionTest.Tol);
        end

        function testProjectPlaneToCamera(testCase)
            referencePlane = PlanarProjection.definePlaneFromBasis([0; 0; 10], [1; 0; 0], [0; 1; 0]);
            camera = PlanarProjection.defineFrameCamera([0; 0; 0], [0; 0; 1], 2, referencePlane);
            sourcePlane = PlanarProjection.definePlaneFromBasis([0; 0; 10], [1; 0; 0], [0; 1; 0]);

            [Qcamera, Pp] = PlanarProjection.projectPlaneToCamera([5; 10], sourcePlane, camera);

            testCase.verifyEqual(Qcamera, [1; 2], AbsTol=PlanarProjectionTest.Tol);
            testCase.verifyEqual(Pp, [1; 2; 2], AbsTol=PlanarProjectionTest.Tol);
        end

        function testTriangulateRaysIntersectsAtPoint(testCase)
            [P, residual, Pnear1, Pnear2] = PlanarProjection.triangulateRays( ...
                [0; 0; 0], [1; 0; 5], [2; 0; 0], [-1; 0; 5]);

            testCase.verifyEqual(P, [1; 0; 5], AbsTol=PlanarProjectionTest.Tol);
            testCase.verifyEqual(Pnear1, [1; 0; 5], AbsTol=PlanarProjectionTest.Tol);
            testCase.verifyEqual(Pnear2, [1; 0; 5], AbsTol=PlanarProjectionTest.Tol);
            testCase.verifyEqual(residual, 0, AbsTol=PlanarProjectionTest.Tol);
        end

        function testTriangulateRaysRejectsParallelRays(testCase)
            testCase.verifyError( ...
                @() PlanarProjection.triangulateRays([0; 0; 0], [0; 0; 1], [1; 0; 0], [0; 0; 1]), ...
                "PlanarProjection:parallelRay");
        end

        function testValidatePlaneRejectsMalformedPlane(testCase)
            badPlane = struct("P0", [0; 0; 0], "basis", eye(3), "VN", [0; 0; 1]);

            testCase.verifyError( ...
                @() PlanarProjection.validatePlane(badPlane), ...
                "PlanarProjection:invalidSize");
        end

        function testNormalizeVectorsColumnWise(testCase)
            Vn = [3 0; 4 0; 0 5];

            VnUnit = PlanarProjection.normalizeVectors(Vn);

            testCase.verifyEqual(VnUnit, [0.6 0; 0.8 0; 0 1], AbsTol=PlanarProjectionTest.Tol);
        end

        function testPointsToViewVectors(testCase)
            P = [1 2; 3 4; 5 6];

            Vn = PlanarProjection.pointsToViewVectors(P, [1; 1; 1]);

            testCase.verifyEqual(Vn, [0 1; 2 3; 4 5], AbsTol=PlanarProjectionTest.Tol);
        end

        function testProjectToCameraRejectsBehindCamera(testCase)
            referencePlane = PlanarProjection.definePlaneFromBasis([0; 0; 10], [1; 0; 0], [0; 1; 0]);
            camera = PlanarProjection.defineFrameCamera([0; 0; 0], [0; 0; 1], 2, referencePlane);

            testCase.verifyError( ...
                @() PlanarProjection.projectToCamera([0; 0; -1], camera), ...
                "PlanarProjection:behindCamera");
        end
    end

    methods (Static, Access = private)
        function verifyPlaneFrame(testCase, plane)
            VX = plane.basis(:, 1);
            VY = plane.basis(:, 2);

            testCase.verifyEqual(norm(VX), 1, AbsTol=PlanarProjectionTest.Tol);
            testCase.verifyEqual(norm(VY), 1, AbsTol=PlanarProjectionTest.Tol);
            testCase.verifyEqual(norm(plane.VN), 1, AbsTol=PlanarProjectionTest.Tol);
            testCase.verifyEqual(dot(VX, VY), 0, AbsTol=PlanarProjectionTest.Tol);
            testCase.verifyEqual(dot(VX, plane.VN), 0, AbsTol=PlanarProjectionTest.Tol);
            testCase.verifyEqual(dot(VY, plane.VN), 0, AbsTol=PlanarProjectionTest.Tol);
            testCase.verifyEqual(cross(VX, VY), plane.VN, AbsTol=PlanarProjectionTest.Tol);
        end
    end
end
