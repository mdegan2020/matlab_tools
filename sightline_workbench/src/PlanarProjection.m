classdef PlanarProjection
    %PlanarProjection Static geometry utilities for 2D/3D projection.
    %
    % Conventions:
    %   P, G: 3x1 points in the world/system frame.
    %   V:    3x1 vector in the world/system frame.
    %   Pn:   3xN collection of points.
    %   Vn:   3xN collection of vectors.
    %   Q:    2xN coordinates local to a plane.
    %
    % Plane structs contain:
    %   P0:    3x1 plane origin.
    %   basis: 3x2 matrix [VX VY].
    %   VN:    3x1 plane normal, with cross(VX, VY) = VN.

    methods (Static)
        function plane = definePlane(G0, V0, V1, R0)
            %definePlane Define a plane from a view origin and two view directions.
            G0 = PlanarProjection.mustBePoint(G0, "G0");
            V0 = PlanarProjection.unitVector(V0, "V0");
            V1 = PlanarProjection.mustBePoint(V1, "V1");
            R0 = PlanarProjection.mustBePositiveScalar(R0, "R0");

            P0 = G0 + R0 * V0;
            denom = dot(V1, V0);
            PlanarProjection.mustBeNonzero(denom, "PlanarProjection:parallelRay", ...
                "V1 is parallel to the plane.");

            t = dot(P0 - G0, V0) / denom;
            if t <= PlanarProjection.defaultTolerance()
                error("PlanarProjection:degenerateGeometry", ...
                    "V1 must define an intersection point in front of G0.");
            end

            P1 = G0 + t * V1;
            VY = P1 - P0;
            VY = PlanarProjection.unitVector(VY, "P1 - P0");
            VX = cross(VY, V0);
            VX = PlanarProjection.unitVector(VX, "VX");
            VY = cross(V0, VX);

            plane = PlanarProjection.makePlane(P0, VX, VY, V0);
        end

        function plane = defineStereoPlane(G1, V1, R1, G2, V2, R2)
            %defineStereoPlane Define a plane constrained by two stereo view points.
            G1 = PlanarProjection.mustBePoint(G1, "G1");
            G2 = PlanarProjection.mustBePoint(G2, "G2");
            V1 = PlanarProjection.unitVector(V1, "V1");
            V2 = PlanarProjection.unitVector(V2, "V2");
            R1 = PlanarProjection.mustBePositiveScalar(R1, "R1");
            R2 = PlanarProjection.mustBePositiveScalar(R2, "R2");

            P1 = G1 + R1 * V1;
            P2 = G2 + R2 * V2;

            VX = PlanarProjection.unitVector(P2 - P1, "P2 - P1");
            VMean = V1 + V2;
            VMean = PlanarProjection.unitVector(VMean, "V1 + V2");

            VN = VMean - dot(VMean, VX) * VX;
            VN = PlanarProjection.unitVector(VN, "mean view direction projected onto plane normal");
            VY = cross(VN, VX);

            plane = PlanarProjection.makePlane(P1, VX, VY, VN);
        end

        function [P, Q] = intersectPlane(Vn, G, plane)
            %intersectPlane Intersect view vectors from one origin with a plane.
            Vn = PlanarProjection.mustBeVectorSet(Vn, "Vn");
            G = PlanarProjection.mustBePoint(G, "G");
            PlanarProjection.validatePlane(plane);

            denom = plane.VN.' * Vn;
            if any(abs(denom) <= PlanarProjection.defaultTolerance())
                error("PlanarProjection:parallelRay", ...
                    "One or more view vectors are parallel to the plane.");
            end

            numer = dot(plane.P0 - G, plane.VN);
            t = numer ./ denom;
            P = G + Vn .* t;
            Q = plane.basis.' * (P - plane.P0);
        end

        function plane = defineFitPlane(G0, V0, P1, P2, P3, P4)
            %defineFitPlane Define a best-fit plane from four ordered points.
            G0 = PlanarProjection.mustBePoint(G0, "G0");
            V0 = PlanarProjection.unitVector(V0, "V0");
            P1 = PlanarProjection.mustBePoint(P1, "P1");
            P2 = PlanarProjection.mustBePoint(P2, "P2");
            P3 = PlanarProjection.mustBePoint(P3, "P3");
            P4 = PlanarProjection.mustBePoint(P4, "P4");

            Pn = [P1 P2 P3 P4];
            P0 = mean(Pn, 2);
            if dot(P0 - G0, V0) <= PlanarProjection.defaultTolerance()
                error("PlanarProjection:degenerateGeometry", ...
                    "The fitted plane centroid must be in front of G0 along V0.");
            end

            centered = Pn - P0;
            if rank(centered, PlanarProjection.defaultTolerance()) < 2
                error("PlanarProjection:degenerateGeometry", ...
                    "P1, P2, P3, and P4 must define a nondegenerate plane.");
            end

            [U, ~, ~] = svd(centered, "econ");
            VN = U(:, end);
            if dot(VN, V0) < 0
                VN = -VN;
            end

            VXfit = (P2 - P1) + (P3 - P4);
            VYfit = (P4 - P1) + (P3 - P2);
            VXfit = PlanarProjection.projectOntoPlane(VXfit, VN);
            VYfit = PlanarProjection.projectOntoPlane(VYfit, VN);
            PlanarProjection.mustBeNonzero(norm(VXfit), "PlanarProjection:degenerateGeometry", ...
                "+X fit direction is degenerate.");
            PlanarProjection.mustBeNonzero(norm(VYfit), "PlanarProjection:degenerateGeometry", ...
                "+Y fit direction is degenerate.");

            VX0 = PlanarProjection.unitVector(VXfit, "VXfit");
            VY0 = cross(VN, VX0);
            B = [VX0 VY0];
            A = [VXfit VYfit];
            A2 = B.' * A;
            [U2, ~, V2] = svd(A2);
            D = diag([1, det(U2 * V2.')]);
            R2 = U2 * D * V2.';
            basis = B * R2;

            VX = basis(:, 1);
            VY = basis(:, 2);
            if dot(cross(VX, VY), VN) < 0
                VX = -VX;
                VY = -VY;
            end

            plane = PlanarProjection.makePlane(P0, VX, VY, VN);
        end

        function Q2 = mapPlaneToPlane(Q1, plane1, plane2)
            %mapPlaneToPlane Express source-plane coordinates on a destination plane.
            Q1 = PlanarProjection.mustBePlaneCoordinateSet(Q1, "Q1");
            PlanarProjection.validatePlane(plane1);
            PlanarProjection.validatePlane(plane2);

            P = PlanarProjection.reconstruct3d(Q1, plane1);
            Q2 = PlanarProjection.worldToPlane(P, plane2);
        end

        function P = reconstruct3d(Q, plane)
            %reconstruct3d Convert plane-local 2D coordinates to 3D points.
            Q = PlanarProjection.mustBePlaneCoordinateSet(Q, "Q");
            PlanarProjection.validatePlane(plane);

            P = plane.P0 + plane.basis * Q;
        end

        function camera = defineFrameCamera(G0, V0, F, referencePlane)
            %defineFrameCamera Define a simple positive-focal-plane frame camera.
            G0 = PlanarProjection.mustBePoint(G0, "G0");
            V0 = PlanarProjection.unitVector(V0, "V0");
            F = PlanarProjection.mustBePositiveScalar(F, "F");
            PlanarProjection.validatePlane(referencePlane);

            VX = PlanarProjection.projectOntoPlane(referencePlane.basis(:, 1), V0);
            VX = PlanarProjection.unitVector(VX, "referencePlane +X projected onto focal plane");
            VY = cross(V0, VX);
            focalPlane = PlanarProjection.makePlane(G0 + F * V0, VX, VY, V0);

            camera = struct("G0", G0, "V0", V0, "F", F, "focalPlane", focalPlane);
            PlanarProjection.validateCamera(camera);
        end

        function [Q, Pp] = projectToCamera(P, camera)
            %projectToCamera Project 3D points onto a camera focal plane.
            P = PlanarProjection.mustBeVectorSet(P, "P");
            PlanarProjection.validateCamera(camera);

            Vn = P - camera.G0;
            depth = camera.V0.' * Vn;
            if any(depth <= PlanarProjection.defaultTolerance())
                error("PlanarProjection:behindCamera", ...
                    "All points must be in front of the camera.");
            end

            [Pp, Q] = PlanarProjection.intersectPlane(Vn, camera.G0, camera.focalPlane);
        end

        function [Vn, Pp] = projectFromCamera(Q, camera)
            %projectFromCamera Convert camera focal-plane coordinates to view vectors.
            Q = PlanarProjection.mustBePlaneCoordinateSet(Q, "Q");
            PlanarProjection.validateCamera(camera);

            Pp = PlanarProjection.reconstruct3d(Q, camera.focalPlane);
            Vn = Pp - camera.G0;
        end

        function [Qcamera, Pp] = projectPlaneToCamera(Qplane, plane, camera)
            %projectPlaneToCamera Project points on a plane into camera coordinates.
            P = PlanarProjection.reconstruct3d(Qplane, plane);
            [Qcamera, Pp] = PlanarProjection.projectToCamera(P, camera);
        end

        function [Qplane, P] = projectCameraToPlane(Qcamera, camera, plane)
            %projectCameraToPlane Project camera focal-plane coordinates onto a plane.
            [Vn, ~] = PlanarProjection.projectFromCamera(Qcamera, camera);
            [P, Qplane] = PlanarProjection.intersectPlane(Vn, camera.G0, plane);
        end

        function Q = worldToPlane(P, plane)
            %worldToPlane Express 3D points in plane-local 2D coordinates.
            P = PlanarProjection.mustBeVectorSet(P, "P");
            PlanarProjection.validatePlane(plane);

            Q = plane.basis.' * (P - plane.P0);
        end

        function Vn = pointsToViewVectors(P, G)
            %pointsToViewVectors Form view vectors from an origin to 3D points.
            P = PlanarProjection.mustBeVectorSet(P, "P");
            G = PlanarProjection.mustBePoint(G, "G");

            Vn = P - G;
        end

        function VnUnit = normalizeVectors(Vn)
            %normalizeVectors Normalize each column of a 3xN vector set.
            Vn = PlanarProjection.mustBeVectorSet(Vn, "Vn");

            norms = sqrt(sum(Vn.^2, 1));
            if any(norms <= PlanarProjection.defaultTolerance())
                error("PlanarProjection:degenerateGeometry", ...
                    "Cannot normalize zero-length vectors.");
            end

            VnUnit = Vn ./ norms;
        end

        function plane = definePlaneFromBasis(P0, VX, VY)
            %definePlaneFromBasis Define a plane from an origin and two basis vectors.
            P0 = PlanarProjection.mustBePoint(P0, "P0");
            VX = PlanarProjection.unitVector(VX, "VX");
            VY = PlanarProjection.mustBePoint(VY, "VY");
            VY = VY - dot(VY, VX) * VX;
            VY = PlanarProjection.unitVector(VY, "VY projected perpendicular to VX");
            VN = cross(VX, VY);
            VN = PlanarProjection.unitVector(VN, "VN");
            VY = cross(VN, VX);

            plane = PlanarProjection.makePlane(P0, VX, VY, VN);
        end

        function plane = definePlaneFromNormal(P0, VN, VXref)
            %definePlaneFromNormal Define a plane from an origin, normal, and +X reference.
            P0 = PlanarProjection.mustBePoint(P0, "P0");
            VN = PlanarProjection.unitVector(VN, "VN");
            VXref = PlanarProjection.mustBePoint(VXref, "VXref");
            VX = PlanarProjection.projectOntoPlane(VXref, VN);
            VX = PlanarProjection.unitVector(VX, "VXref projected onto plane");
            VY = cross(VN, VX);

            plane = PlanarProjection.makePlane(P0, VX, VY, VN);
        end

        function [P, residual, Pnear1, Pnear2] = triangulateRays(G1, V1, G2, V2)
            %triangulateRays Find closest 3D points for corresponding ray pairs.
            V1 = PlanarProjection.normalizeVectors(V1);
            V2 = PlanarProjection.normalizeVectors(V2);
            N = PlanarProjection.mustHaveSameColumnCount(V1, V2, "V1", "V2");
            G1 = PlanarProjection.expandOrigin(G1, N, "G1");
            G2 = PlanarProjection.expandOrigin(G2, N, "G2");

            b = sum(V1 .* V2, 1);
            W0 = G1 - G2;
            d = sum(V1 .* W0, 1);
            e = sum(V2 .* W0, 1);
            denom = 1 - b.^2;
            if any(abs(denom) <= PlanarProjection.defaultTolerance())
                error("PlanarProjection:parallelRay", ...
                    "One or more ray pairs are parallel or nearly parallel.");
            end

            s = (b .* e - d) ./ denom;
            t = (e - b .* d) ./ denom;
            Pnear1 = G1 + V1 .* s;
            Pnear2 = G2 + V2 .* t;
            P = 0.5 * (Pnear1 + Pnear2);
            residual = sqrt(sum((Pnear1 - Pnear2).^2, 1));
        end

        function tf = validatePlane(plane, tol)
            %validatePlane Validate plane struct shape and right-handed basis.
            if nargin < 2
                tol = PlanarProjection.defaultTolerance();
            end
            if ~isstruct(plane) || ~isfield(plane, "P0") || ...
                    ~isfield(plane, "basis") || ~isfield(plane, "VN")
                error("PlanarProjection:invalidPlane", ...
                    "Plane must be a struct with fields P0, basis, and VN.");
            end

            PlanarProjection.mustBePoint(plane.P0, "plane.P0");
            PlanarProjection.mustBeMatrixSize(plane.basis, [3 2], "plane.basis");
            PlanarProjection.mustBePoint(plane.VN, "plane.VN");

            VX = plane.basis(:, 1);
            VY = plane.basis(:, 2);
            checks = [ ...
                abs(norm(VX) - 1), ...
                abs(norm(VY) - 1), ...
                abs(norm(plane.VN) - 1), ...
                abs(dot(VX, VY)), ...
                abs(dot(VX, plane.VN)), ...
                abs(dot(VY, plane.VN)), ...
                abs(dot(cross(VX, VY), plane.VN) - 1)];
            if any(checks > tol)
                error("PlanarProjection:invalidPlane", ...
                    "Plane basis must be unit length, orthogonal, and right-handed.");
            end

            tf = true;
        end

        function tf = validateCamera(camera, tol)
            %validateCamera Validate frame camera struct shape and focal plane.
            if nargin < 2
                tol = PlanarProjection.defaultTolerance();
            end
            if ~isstruct(camera) || ~isfield(camera, "G0") || ...
                    ~isfield(camera, "V0") || ~isfield(camera, "F") || ...
                    ~isfield(camera, "focalPlane")
                error("PlanarProjection:invalidCamera", ...
                    "Camera must be a struct with fields G0, V0, F, and focalPlane.");
            end

            PlanarProjection.mustBePoint(camera.G0, "camera.G0");
            PlanarProjection.mustBePoint(camera.V0, "camera.V0");
            PlanarProjection.mustBePositiveScalar(camera.F, "camera.F");
            PlanarProjection.validatePlane(camera.focalPlane, tol);

            if abs(norm(camera.V0) - 1) > tol || ...
                    norm(camera.focalPlane.P0 - (camera.G0 + camera.F * camera.V0)) > tol || ...
                    norm(camera.focalPlane.VN - camera.V0) > tol
                error("PlanarProjection:invalidCamera", ...
                    "Camera V0, F, and focalPlane are inconsistent.");
            end

            tf = true;
        end
    end

    methods (Static, Access = private)
        function tol = defaultTolerance()
            tol = 1e-10;
        end

        function plane = makePlane(P0, VX, VY, VN)
            VX = PlanarProjection.unitVector(VX, "VX");
            VY = PlanarProjection.unitVector(VY, "VY");
            VN = PlanarProjection.unitVector(VN, "VN");
            plane = struct("P0", P0, "basis", [VX VY], "VN", VN);
            PlanarProjection.validatePlane(plane);
        end

        function V = projectOntoPlane(V, VN)
            V = V - dot(V, VN) * VN;
        end

        function X = mustBePoint(X, name)
            PlanarProjection.mustBeMatrixSize(X, [3 1], name);
        end

        function X = mustBeVectorSet(X, name)
            if ~isnumeric(X) || ~ismatrix(X) || size(X, 1) ~= 3 || isempty(X) || ...
                    any(~isfinite(X), "all")
                error("PlanarProjection:invalidSize", ...
                    "%s must be a finite numeric 3xN array.", name);
            end
        end

        function Q = mustBePlaneCoordinateSet(Q, name)
            if ~isnumeric(Q) || ~ismatrix(Q) || size(Q, 1) ~= 2 || isempty(Q) || ...
                    any(~isfinite(Q), "all")
                error("PlanarProjection:invalidSize", ...
                    "%s must be a finite numeric 2xN array.", name);
            end
        end

        function X = mustBeMatrixSize(X, expectedSize, name)
            if ~isnumeric(X) || ~isequal(size(X), expectedSize) || any(~isfinite(X), "all")
                error("PlanarProjection:invalidSize", ...
                    "%s must be a finite numeric %dx%d array.", ...
                    name, expectedSize(1), expectedSize(2));
            end
        end

        function value = mustBePositiveScalar(value, name)
            if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value) || value <= 0
                error("PlanarProjection:invalidScalar", ...
                    "%s must be a positive finite scalar.", name);
            end
        end

        function V = unitVector(V, name)
            V = PlanarProjection.mustBePoint(V, name);
            n = norm(V);
            PlanarProjection.mustBeNonzero(n, "PlanarProjection:degenerateGeometry", ...
                "%s must have nonzero length.", name);
            V = V / n;
        end

        function mustBeNonzero(value, errorId, message, varargin)
            if abs(value) <= PlanarProjection.defaultTolerance()
                error(errorId, message, varargin{:});
            end
        end

        function N = mustHaveSameColumnCount(A, B, nameA, nameB)
            N = size(A, 2);
            if size(B, 2) ~= N
                error("PlanarProjection:invalidSize", ...
                    "%s and %s must have the same number of columns.", nameA, nameB);
            end
        end

        function G = expandOrigin(G, N, name)
            if isnumeric(G) && ismatrix(G) && size(G, 1) == 3 && ...
                    any(size(G, 2) == [1 N]) && all(isfinite(G), "all")
                if size(G, 2) == 1 && N > 1
                    G = repmat(G, 1, N);
                end
                return
            end

            error("PlanarProjection:invalidSize", ...
                "%s must be a finite numeric 3x1 or 3xN array.", name);
        end
    end
end
