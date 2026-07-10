classdef ProjectionAlignmentObservationProjector
    %ProjectionAlignmentObservationProjector Reproject source observations safely.

    methods (Static)
        function projection = project(scene, layerReference, rows, columns, plane)
            %project Return current plane coordinates and per-observation validity.
            scene = ProjectionLayerIdentity.ensureScene(scene);
            PlanarProjection.validatePlane(plane);
            layerIndex = ProjectionAlignmentObservationProjector.layerIndex( ...
                scene, layerReference);
            layer = scene.layers(layerIndex);
            layer.CurrentProjectionPlane = plane;

            rows = double(rows(:));
            columns = double(columns(:));
            if numel(rows) ~= numel(columns)
                error("ProjectionAlignmentObservationProjector:sizeMismatch", ...
                    "Observation rows and columns must have the same length.");
            end

            count = numel(rows);
            points = nan(count, 2);
            valid = false(count, 1);
            status = repmat("outsideSource", count, 1);
            imageSize = double(layer.SourceGeometry.ImageSize(:).');
            candidateMask = isfinite(rows) & isfinite(columns) & ...
                rows >= 1 & rows <= imageSize(1) & ...
                columns >= 1 & columns <= imageSize(2);

            sourceGeometry = layer.SourceGeometry;
            if isfield(sourceGeometry, "SampleRayFcn") && ...
                    isa(sourceGeometry.SampleRayFcn, "function_handle")
                [points, valid, status] = ...
                    ProjectionAlignmentObservationProjector.projectExactRays( ...
                    layer, rows, columns, plane, points, valid, status, ...
                    candidateMask);
                method = "exactSampledRay";
            else
                [points, valid, status] = ...
                    ProjectionAlignmentObservationProjector.projectMeshFallback( ...
                    layer, rows, columns, plane, scene.renderOrigin, points, ...
                    valid, status, candidateMask);
                method = "sampledMeshInterpolation";
            end

            projection = struct(LayerIndex=layerIndex, ...
                LayerId=string(layer.LayerId), PlaneCoordinates=points, ...
                ValidMask=valid, Status=status, Method=method);
        end
    end

    methods (Static, Access = private)
        function layerIndex = layerIndex(scene, layerReference)
            if isstring(layerReference) || ischar(layerReference)
                layerIndex = ProjectionLayerIdentity.indexForId( ...
                    scene, string(layerReference));
            elseif isnumeric(layerReference) && isscalar(layerReference) && ...
                    isfinite(layerReference) && layerReference >= 1 && ...
                    layerReference <= numel(scene.layers)
                layerIndex = round(double(layerReference));
            else
                error("ProjectionAlignmentObservationProjector:invalidLayer", ...
                    "Layer reference must be a current numeric index or stable layer ID.");
            end
        end

        function [points, valid, status] = projectExactRays(layer, rows, ...
                columns, plane, points, valid, status, candidateMask)
            rotation = ProjectionMeshBuilder.viewVectorRotationMatrix(layer, plane);
            projectionOffset = ProjectionMeshBuilder.projectionOffsetMeters(layer);
            offsetWorld = plane.basis * projectionOffset;
            tolerance = 1e-12;
            candidateIndices = reshape(find(candidateMask), 1, []);
            if isempty(candidateIndices)
                return
            end

            try
                [origins, vectors] = layer.SourceGeometry.SampleRayFcn( ...
                    rows(candidateIndices), columns(candidateIndices));
                if ~isnumeric(origins) || ...
                        ~isequal(size(origins), [3 numel(candidateIndices)]) || ...
                        ~isnumeric(vectors) || ...
                        ~isequal(size(vectors), [3 numel(candidateIndices)])
                    error("ProjectionAlignmentObservationProjector:invalidBatch", ...
                        "SampleRayFcn returned incompatible batch arrays.");
                end
                [points, valid, status] = ...
                    ProjectionAlignmentObservationProjector.projectRayArrays( ...
                    origins, vectors, candidateIndices, rotation, offsetWorld, ...
                    plane, points, valid, status, tolerance);
                return
            catch
                % A custom sampler may only accept scalars. Fall back per point
                % so one invalid observation never invalidates its neighbors.
            end

            for observationIndex = candidateIndices
                try
                    [origin, vector] = layer.SourceGeometry.SampleRayFcn( ...
                        rows(observationIndex), columns(observationIndex));
                    if ~isnumeric(origin) || ~isequal(size(origin), [3 1]) || ...
                            ~isnumeric(vector) || ~isequal(size(vector), [3 1])
                        status(observationIndex) = "invalidSampledRay";
                        continue
                    end
                    [points, valid, status] = ...
                        ProjectionAlignmentObservationProjector.projectRayArrays( ...
                        origin, vector, observationIndex, rotation, offsetWorld, ...
                        plane, points, valid, status, tolerance);
                catch
                    status(observationIndex) = "samplingFailure";
                end
            end
        end

        function [points, valid, status] = projectRayArrays(origins, vectors, ...
                observationIndices, rotation, offsetWorld, plane, points, ...
                valid, status, tolerance)
            origins = double(origins);
            vectors = double(vectors);
            finiteRayMask = all(isfinite(origins), 1) & ...
                all(isfinite(vectors), 1) & ...
                sqrt(sum(vectors.^2, 1)) > tolerance;
            status(observationIndices(~finiteRayMask)) = "invalidSampledRay";
            if ~any(finiteRayMask)
                return
            end

            rayIndices = observationIndices(finiteRayMask);
            rayOrigins = origins(:, finiteRayMask);
            rayVectors = rotation * vectors(:, finiteRayMask);
            denominators = plane.VN.' * rayVectors;
            parallelMask = abs(denominators) <= tolerance;
            status(rayIndices(parallelMask)) = "parallelToPlane";
            candidateRayMask = ~parallelMask;
            if ~any(candidateRayMask)
                return
            end

            forwardIndices = rayIndices(candidateRayMask);
            forwardOrigins = rayOrigins(:, candidateRayMask);
            forwardVectors = rayVectors(:, candidateRayMask);
            ranges = (plane.VN.' * (plane.P0 - forwardOrigins)) ./ ...
                denominators(candidateRayMask);
            behindMask = ~isfinite(ranges) | ranges <= tolerance;
            status(forwardIndices(behindMask)) = "behindSource";
            projectedMask = ~behindMask;
            if ~any(projectedMask)
                return
            end

            projectedIndices = forwardIndices(projectedMask);
            worldPoints = forwardOrigins(:, projectedMask) + ...
                forwardVectors(:, projectedMask) .* ranges(projectedMask) + ...
                offsetWorld;
            planePoints = PlanarProjection.worldToPlane(worldPoints, plane).';
            finiteProjectionMask = all(isfinite(planePoints), 2);
            status(projectedIndices(~finiteProjectionMask)) = ...
                "nonfiniteProjection";
            points(projectedIndices(finiteProjectionMask), :) = ...
                planePoints(finiteProjectionMask, :);
            valid(projectedIndices(finiteProjectionMask)) = true;
            status(projectedIndices(finiteProjectionMask)) = "valid";
        end

        function [points, valid, status] = projectMeshFallback(layer, rows, ...
                columns, plane, renderOrigin, points, valid, status, candidateMask)
            if ~any(candidateMask)
                return
            end
            try
                mesh = ProjectionMeshBuilder.buildLayerMesh( ...
                    layer, plane, renderOrigin);
            catch
                status(candidateMask) = "meshProjectionFailure";
                return
            end

            worldPoints = nan(3, numel(rows));
            for componentIndex = 1:3
                componentGrid = squeeze(mesh.WorldPoints(componentIndex, :, :));
                worldPoints(componentIndex, candidateMask) = interp2( ...
                    mesh.ColumnIndices, mesh.RowIndices, componentGrid, ...
                    columns(candidateMask).', rows(candidateMask).', ...
                    "linear", NaN);
            end
            finiteMask = candidateMask & all(isfinite(worldPoints), 1).';
            if any(finiteMask)
                planePoints = PlanarProjection.worldToPlane( ...
                    worldPoints(:, finiteMask), plane).';
                points(finiteMask, :) = planePoints;
                valid(finiteMask) = all(isfinite(planePoints), 2);
                status(finiteMask & valid) = "valid";
            end
            status(candidateMask & ~valid) = "outsideSampledMesh";
        end
    end
end
