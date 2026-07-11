classdef ProjectionViewportGrid
    %ProjectionViewportGrid Build a pure orthographic viewport sampling grid.

    methods (Static)
        function grid = build(cameraState, outputSize, referencePlane)
            %build Intersect orthographic viewport rays with a reference plane.
            cameraState = ProjectionViewportGrid.validateCameraState(cameraState);
            outputSize = ProjectionViewportGrid.validateOutputSize(outputSize);
            PlanarProjection.validatePlane(referencePlane);

            position = cameraState.Position;
            target = cameraState.Target;
            viewDirection = target - position;
            viewDistance = norm(viewDirection);
            viewDirection = viewDirection / viewDistance;
            upVector = cameraState.UpVector - viewDirection * ...
                (viewDirection.' * cameraState.UpVector);
            upVector = upVector / norm(upVector);
            rightVector = cross(viewDirection, upVector);
            rightVector = rightVector / norm(rightVector);
            upVector = cross(rightVector, viewDirection);
            upVector = upVector / norm(upVector);

            viewHeight = 2 * viewDistance * tan( ...
                deg2rad(cameraState.ViewAngle) / 2);
            viewWidth = viewHeight * outputSize(2) / outputSize(1);
            xCoordinates = linspace(-0.5 * viewWidth, ...
                0.5 * viewWidth, outputSize(2));
            yCoordinates = linspace(0.5 * viewHeight, ...
                -0.5 * viewHeight, outputSize(1));
            [screenX, screenY] = meshgrid(xCoordinates, yCoordinates);
            screenWorldPoints = target + ...
                rightVector * screenX(:).' + upVector * screenY(:).';
            referenceWorldPoints = ProjectionViewportGrid.intersectRays( ...
                screenWorldPoints, viewDirection, referencePlane);
            referenceOrigin = ProjectionViewportGrid.intersectRays( ...
                target, viewDirection, referencePlane);
            xAxis = ProjectionViewportGrid.intersectionDerivative( ...
                rightVector, viewDirection, referencePlane);
            yAxis = ProjectionViewportGrid.intersectionDerivative( ...
                upVector, viewDirection, referencePlane);

            grid = struct();
            grid.Format = "ProjectionViewportGrid";
            grid.Version = 1;
            grid.OutputSize = outputSize;
            grid.CameraState = cameraState;
            grid.ViewDirection = viewDirection;
            grid.RightVector = rightVector;
            grid.UpVector = upVector;
            grid.ViewDistance = viewDistance;
            grid.ViewWidth = viewWidth;
            grid.ViewHeight = viewHeight;
            grid.X = screenX;
            grid.Y = screenY;
            grid.ScreenWorldPoints = screenWorldPoints;
            grid.ReferenceWorldPoints = referenceWorldPoints;
            grid.ReferencePlane = referencePlane;
            grid.ReferenceOrigin = referenceOrigin;
            grid.ReferenceXAxis = xAxis;
            grid.ReferenceYAxis = yAxis;
        end

        function worldPoints = worldPointsForPlane(grid, plane)
            %worldPointsForPlane Intersect the cached viewport rays with a plane.
            ProjectionViewportGrid.validateGrid(grid);
            PlanarProjection.validatePlane(plane);
            worldPoints = ProjectionViewportGrid.intersectRays( ...
                grid.ScreenWorldPoints, grid.ViewDirection, plane);
        end

        function outputGrid = asOutputGrid(grid)
            %asOutputGrid Return a ProjectionReadbackRenderer-compatible grid.
            ProjectionViewportGrid.validateGrid(grid);
            outputGrid = struct();
            outputGrid.OutputSize = grid.OutputSize;
            outputGrid.Bounds = struct( ...
                X=[-0.5 * grid.ViewWidth, 0.5 * grid.ViewWidth], ...
                Y=[-0.5 * grid.ViewHeight, 0.5 * grid.ViewHeight]);
            outputGrid.Origin = grid.ReferenceOrigin;
            outputGrid.XAxis = grid.ReferenceXAxis;
            outputGrid.YAxis = grid.ReferenceYAxis;
            outputGrid.ReferencePlane = grid.ReferencePlane;
        end
    end

    methods (Static, Access = private)
        function cameraState = validateCameraState(cameraState)
            requiredFields = ["Position", "Target", "UpVector", "ViewAngle"];
            if ~isstruct(cameraState) || ~isscalar(cameraState) || ...
                    any(~isfield(cameraState, requiredFields))
                error("ProjectionViewportGrid:invalidCamera", ...
                    "Camera state must contain Position, Target, UpVector, and ViewAngle.");
            end
            cameraState.Position = ProjectionViewportGrid.validatePoint( ...
                cameraState.Position, "Position");
            cameraState.Target = ProjectionViewportGrid.validatePoint( ...
                cameraState.Target, "Target");
            cameraState.UpVector = ProjectionViewportGrid.validatePoint( ...
                cameraState.UpVector, "UpVector");
            if norm(cameraState.Target - cameraState.Position) <= eps || ...
                    norm(cameraState.UpVector) <= eps
                error("ProjectionViewportGrid:invalidCamera", ...
                    "Camera view and up vectors must be nonzero.");
            end
            viewDirection = cameraState.Target - cameraState.Position;
            if norm(cross(viewDirection, cameraState.UpVector)) <= ...
                    eps * norm(viewDirection) * norm(cameraState.UpVector)
                error("ProjectionViewportGrid:invalidCamera", ...
                    "Camera up vector must not be parallel to the view direction.");
            end
            if ~isnumeric(cameraState.ViewAngle) || ...
                    ~isscalar(cameraState.ViewAngle) || ...
                    ~isfinite(cameraState.ViewAngle) || ...
                    cameraState.ViewAngle <= 0 || cameraState.ViewAngle >= 180
                error("ProjectionViewportGrid:invalidCamera", ...
                    "Camera ViewAngle must be in the open interval (0, 180) degrees.");
            end
            cameraState.ViewAngle = double(cameraState.ViewAngle);
            if isfield(cameraState, "Projection") && ...
                    lower(string(cameraState.Projection)) ~= "orthographic"
                error("ProjectionViewportGrid:invalidCamera", ...
                    "Raster preview currently requires an orthographic camera.");
            end
        end

        function point = validatePoint(point, name)
            if ~isnumeric(point) || numel(point) ~= 3 || ...
                    any(~isfinite(point), "all")
                error("ProjectionViewportGrid:invalidCamera", ...
                    "Camera %s must be a finite numeric 3-vector.", name);
            end
            point = double(point(:));
        end

        function outputSize = validateOutputSize(outputSize)
            if ~isnumeric(outputSize) || ~isvector(outputSize) || ...
                    numel(outputSize) ~= 2 || any(~isfinite(outputSize)) || ...
                    any(outputSize < 1) || any(fix(outputSize) ~= outputSize)
                error("ProjectionViewportGrid:invalidOutputSize", ...
                    "OutputSize must be a positive integer 2-vector.");
            end
            outputSize = double(outputSize(:).');
        end

        function worldPoints = intersectRays(points, direction, plane)
            denominator = plane.VN.' * direction;
            tolerance = 1e-12 * max(1, norm(plane.VN) * norm(direction));
            if abs(denominator) <= tolerance
                error("ProjectionViewportGrid:parallelPlane", ...
                    "Viewport rays are parallel to the requested projection plane.");
            end
            ranges = plane.VN.' * (plane.P0 - points) / denominator;
            worldPoints = points + direction * ranges;
        end

        function derivative = intersectionDerivative( ...
                screenAxis, viewDirection, plane)
            denominator = plane.VN.' * viewDirection;
            derivative = screenAxis - viewDirection * ...
                ((plane.VN.' * screenAxis) / denominator);
        end

        function validateGrid(grid)
            requiredFields = ["Format", "OutputSize", "ViewDirection", ...
                "ViewWidth", "ViewHeight", "ScreenWorldPoints", ...
                "ReferencePlane", "ReferenceOrigin", ...
                "ReferenceXAxis", "ReferenceYAxis"];
            if ~isstruct(grid) || ~isscalar(grid) || ...
                    any(~isfield(grid, requiredFields)) || ...
                    string(grid.Format) ~= "ProjectionViewportGrid"
                error("ProjectionViewportGrid:invalidGrid", ...
                    "Grid must be produced by ProjectionViewportGrid.build.");
            end
        end
    end
end
