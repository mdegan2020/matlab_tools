classdef ProjectionMeshBuilder
    %ProjectionMeshBuilder Build sampled projection meshes without graphics.

    methods (Static)
        function mesh = buildLayerMesh(layer, plane, renderOrigin, options)
            %buildLayerMesh Intersect sampled source rays with a projection plane.
            if nargin < 2 || isempty(plane)
                plane = ProjectionMeshBuilder.currentPlaneFromLayer(layer);
            end
            if nargin < 3 || isempty(renderOrigin)
                renderOrigin = [0; 0; 0];
            end
            if nargin < 4
                options = struct();
            end

            ProjectionMeshBuilder.validateLayer(layer);
            PlanarProjection.validatePlane(plane);
            renderOrigin = ProjectionMeshBuilder.validatePoint(renderOrigin, "renderOrigin");
            options = ProjectionMeshBuilder.mergeOptions(options);

            rowIndices = double(layer.MeshSampling.RowIndices(:).');
            columnIndices = double(layer.MeshSampling.ColumnIndices(:).');
            [G, V] = layer.SourceGeometry.SampleFcn(rowIndices, columnIndices);

            numRows = numel(rowIndices);
            numColumns = numel(columnIndices);
            ProjectionMeshBuilder.validateSampledGeometry(G, V, numRows, numColumns);

            [worldPoints, ranges] = ProjectionMeshBuilder.intersectSampledRays( ...
                G, V, plane, options);
            renderPoints = worldPoints - reshape(renderOrigin, 3, 1, 1);

            mesh = struct();
            mesh.X = reshape(renderPoints(1, :, :), numRows, numColumns);
            mesh.Y = reshape(renderPoints(2, :, :), numRows, numColumns);
            mesh.Z = reshape(renderPoints(3, :, :), numRows, numColumns);
            mesh.RowIndices = rowIndices;
            mesh.ColumnIndices = columnIndices;
            mesh.Texture = layer.DisplayTexture;
            mesh.Alpha = ProjectionMeshBuilder.validateAlpha(layer.Alpha);
            mesh.Visible = layer.Visible;
            mesh.BlendMode = string(layer.BlendMode);
            mesh.RenderOrigin = renderOrigin;
            mesh.WorldPoints = worldPoints;
            mesh.RenderPoints = renderPoints;
            mesh.Ranges = ranges;
            mesh.SampledOrigins = G;
            mesh.SampledVectors = V;
        end

        function plane = applyPlaneTipTilt(basePlane, tipRadians, tiltRadians)
            %applyPlaneTipTilt Rotate a plane about its local X and Y axes.
            PlanarProjection.validatePlane(basePlane);
            tipRadians = ProjectionMeshBuilder.validateScalar(tipRadians, "tipRadians");
            tiltRadians = ProjectionMeshBuilder.validateScalar(tiltRadians, "tiltRadians");

            Rtip = ProjectionMeshBuilder.rotationAboutAxis(basePlane.basis(:, 1), tipRadians);
            Rtilt = ProjectionMeshBuilder.rotationAboutAxis(basePlane.basis(:, 2), tiltRadians);
            R = Rtilt * Rtip;

            VX = R * basePlane.basis(:, 1);
            VY = R * basePlane.basis(:, 2);
            plane = PlanarProjection.definePlaneFromBasis(basePlane.P0, VX, VY);
        end
    end

    methods (Static, Access = private)
        function plane = currentPlaneFromLayer(layer)
            if ~isstruct(layer) || ~isfield(layer, "CurrentProjectionPlane")
                error("ProjectionMeshBuilder:invalidLayer", ...
                    "Layer must contain CurrentProjectionPlane when no plane is supplied.");
            end
            plane = layer.CurrentProjectionPlane;
        end

        function options = mergeOptions(options)
            if isempty(options)
                options = struct();
            end
            if ~isstruct(options) || ~isscalar(options)
                error("ProjectionMeshBuilder:invalidOptions", ...
                    "Options must be a scalar struct.");
            end

            defaults = struct();
            defaults.InvalidIntersectionPolicy = "error";

            names = fieldnames(options);
            for k = 1:numel(names)
                defaults.(names{k}) = options.(names{k});
            end

            defaults.InvalidIntersectionPolicy = string(defaults.InvalidIntersectionPolicy);
            if defaults.InvalidIntersectionPolicy ~= "error"
                error("ProjectionMeshBuilder:invalidOptions", ...
                    "InvalidIntersectionPolicy must be ""error"".");
            end

            options = defaults;
        end

        function validateLayer(layer)
            requiredFields = ["SourceGeometry", "MeshSampling", "DisplayTexture", ...
                "Alpha", "Visible", "BlendMode"];
            if ~isstruct(layer) || ~isscalar(layer) || ...
                    any(~isfield(layer, requiredFields))
                error("ProjectionMeshBuilder:invalidLayer", ...
                    "Layer must contain source geometry, mesh sampling, texture, alpha, visibility, and blend mode.");
            end

            sourceGeometry = layer.SourceGeometry;
            meshSampling = layer.MeshSampling;
            if ~isstruct(sourceGeometry) || ~isfield(sourceGeometry, "SampleFcn") || ...
                    ~isa(sourceGeometry.SampleFcn, "function_handle")
                error("ProjectionMeshBuilder:invalidLayer", ...
                    "Layer SourceGeometry must expose a SampleFcn function handle.");
            end
            if ~isstruct(meshSampling) || ~isfield(meshSampling, "RowIndices") || ...
                    ~isfield(meshSampling, "ColumnIndices")
                error("ProjectionMeshBuilder:invalidLayer", ...
                    "Layer MeshSampling must contain RowIndices and ColumnIndices.");
            end

            ProjectionMeshBuilder.validateIndices(meshSampling.RowIndices, "RowIndices");
            ProjectionMeshBuilder.validateIndices(meshSampling.ColumnIndices, "ColumnIndices");
            ProjectionMeshBuilder.validateAlpha(layer.Alpha);
        end

        function validateIndices(indices, name)
            if ~isnumeric(indices) || isempty(indices) || ~isvector(indices) || ...
                    any(~isfinite(indices)) || any(indices < 1) || ...
                    any(fix(indices) ~= indices)
                error("ProjectionMeshBuilder:invalidSampling", ...
                    "%s must contain positive integer indices.", name);
            end
        end

        function validateSampledGeometry(G, V, numRows, numColumns)
            if ~isnumeric(G) || ~isequal(size(G), [3 numColumns]) || ...
                    any(~isfinite(G), "all")
                error("ProjectionMeshBuilder:invalidSampledGeometry", ...
                    "SampleFcn must return G as a finite 3 x numColumns array.");
            end

            if ~isnumeric(V) || size(V, 1) ~= 3 || size(V, 2) ~= numRows || ...
                    size(V, 3) ~= numColumns || any(~isfinite(V), "all")
                error("ProjectionMeshBuilder:invalidSampledGeometry", ...
                    "SampleFcn must return V as a finite 3 x numRows x numColumns array.");
            end
        end

        function [P, ranges] = intersectSampledRays(G, V, plane, options)
            numRows = size(V, 2);
            numColumns = size(V, 3);
            normal = reshape(plane.VN, 3, 1, 1);
            denom = reshape(sum(V .* normal, 1), numRows, numColumns);

            if any(abs(denom) <= ProjectionMeshBuilder.defaultTolerance(), "all")
                error("ProjectionMeshBuilder:parallelRay", ...
                    "One or more sampled source rays are parallel to the projection plane.");
            end

            numer = plane.VN.' * (plane.P0 - G);
            ranges = repmat(numer, numRows, 1) ./ denom;
            if options.InvalidIntersectionPolicy == "error" && ...
                    any(ranges <= ProjectionMeshBuilder.defaultTolerance(), "all")
                error("ProjectionMeshBuilder:behindSource", ...
                    "One or more sampled intersections are behind the source origin.");
            end

            P = reshape(G, 3, 1, numColumns) + V .* reshape(ranges, 1, numRows, numColumns);
        end

        function value = validateAlpha(value)
            if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value) || ...
                    value < 0 || value > 1
                error("ProjectionMeshBuilder:invalidAlpha", ...
                    "Layer alpha must be a finite scalar in the range [0, 1].");
            end
            value = double(value);
        end

        function P = validatePoint(P, name)
            if ~isnumeric(P) || ~isequal(size(P), [3 1]) || any(~isfinite(P))
                error("ProjectionMeshBuilder:invalidPoint", ...
                    "%s must be a finite numeric 3x1 vector.", name);
            end
            P = double(P);
        end

        function value = validateScalar(value, name)
            if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value)
                error("ProjectionMeshBuilder:invalidScalar", ...
                    "%s must be a finite numeric scalar.", name);
            end
            value = double(value);
        end

        function R = rotationAboutAxis(axis, angle)
            axis = axis / norm(axis);
            K = [0 -axis(3) axis(2); axis(3) 0 -axis(1); -axis(2) axis(1) 0];
            R = cos(angle) * eye(3) + (1 - cos(angle)) * (axis * axis.') + sin(angle) * K;
        end

        function tol = defaultTolerance()
            tol = 1e-10;
        end
    end
end
