classdef ProjectionPreviewTileGeometry
    %ProjectionPreviewTileGeometry Cache display-tile render-space footprints.
    %
    % The returned structs contain only derived numeric geometry and tile
    % bounds. They are runtime-only viewer data and are safe to discard.

    methods (Static)
        function cache = build(layer, pyramid, plane, renderOrigin, ...
                tileSize, meshBuilderFcn)
            %build Sample each level's shared tile-boundary grid once.
            if nargin < 5 || isempty(tileSize)
                tileSize = pyramid.Options.TileSize;
            end
            if nargin < 6 || isempty(meshBuilderFcn)
                meshBuilderFcn = @ProjectionMeshBuilder.buildLayerMesh;
            end
            if ~isa(meshBuilderFcn, "function_handle")
                error("ProjectionPreviewTileGeometry:invalidMeshBuilder", ...
                    "MeshBuilderFcn must be a function handle.");
            end

            levelCount = numel(pyramid.Levels);
            levels = repmat(struct(Tiles=ProjectionPreviewPyramid.emptyTiles(), ...
                RenderCorners=zeros(3, 4, 0), ...
                SampledRenderPoints=zeros(3, 0)), ...
                1, levelCount);
            for levelIndex = 1:levelCount
                tiles = ProjectionPreviewPyramid.tileBounds( ...
                    pyramid, levelIndex, tileSize);
                [rowIndices, columnIndices] = ...
                    ProjectionPreviewTileGeometry.tileBoundaryIndices(tiles);
                sampledLayer = layer;
                sampledLayer.MeshSampling = struct( ...
                    RowStride=1, ColumnStride=1, ...
                    RowIndices=rowIndices, ColumnIndices=columnIndices);
                mesh = meshBuilderFcn(sampledLayer, plane, renderOrigin);
                levels(levelIndex).Tiles = tiles;
                levels(levelIndex).RenderCorners = ...
                    ProjectionPreviewTileGeometry.tileRenderCorners(mesh, tiles);
                levels(levelIndex).SampledRenderPoints = ...
                    reshape(mesh.RenderPoints, 3, []);
            end

            cache = struct();
            cache.ImageSize = double(pyramid.ImageSize);
            cache.TileSize = double(tileSize);
            cache.Levels = levels;
            cache.LayerRenderPoints = levels(1).SampledRenderPoints;
            cache.MeshBuildCount = levelCount;
        end

        function [visibleMask, diagnostics] = visibleMask( ...
                cache, levelIndex, cameraContext)
            %visibleMask Vectorize screen-space tile overlap testing.
            level = cache.Levels(levelIndex);
            corners = level.RenderCorners;
            tileCount = size(corners, 3);
            if tileCount == 0
                visibleMask = false(1, 0);
                diagnostics = struct(CandidateCount=0, VisibleCount=0, ...
                    VisibleTexturePixels=0);
                return
            end

            points = reshape(corners, 3, []);
            centered = points - cameraContext.Center(:);
            screenX = reshape(cameraContext.RightVector(:).' * centered, ...
                4, tileCount);
            screenY = reshape(cameraContext.UpVector(:).' * centered, ...
                4, tileCount);
            haloScale = 1 + cameraContext.HaloFraction;
            halfWidth = 0.5 * cameraContext.ViewWidth * haloScale;
            halfHeight = 0.5 * cameraContext.ViewHeight * haloScale;
            visibleMask = max(screenX, [], 1) >= -halfWidth & ...
                min(screenX, [], 1) <= halfWidth & ...
                max(screenY, [], 1) >= -halfHeight & ...
                min(screenY, [], 1) <= halfHeight;

            tiles = level.Tiles(visibleMask);
            diagnostics = struct();
            diagnostics.CandidateCount = tileCount;
            diagnostics.VisibleCount = nnz(visibleMask);
            if isempty(tiles)
                diagnostics.VisibleTexturePixels = 0;
            else
                textureSizes = reshape([tiles.TextureSize], 2, []);
                diagnostics.VisibleTexturePixels = sum(prod(textureSizes, 1));
            end
        end

        function [projectedWidthPixels, projectedHeightPixels] = ...
                projectedExtentPixels(cache, cameraContext)
            %projectedExtentPixels Project cached layer extent to the viewport.
            points = cache.LayerRenderPoints;
            projectedWidth = max(cameraContext.RightVector(:).' * points) - ...
                min(cameraContext.RightVector(:).' * points);
            projectedHeight = max(cameraContext.UpVector(:).' * points) - ...
                min(cameraContext.UpVector(:).' * points);
            projectedWidthPixels = max(projectedWidth / ...
                max(cameraContext.ViewWidth, eps) * ...
                cameraContext.ViewportWidthPixels, 1);
            projectedHeightPixels = max(projectedHeight / ...
                max(cameraContext.ViewHeight, eps) * ...
                cameraContext.ViewportHeightPixels, 1);
        end
    end

    methods (Static, Access = private)
        function [rowIndices, columnIndices] = tileBoundaryIndices(tiles)
            rowLimits = reshape([tiles.SourceRowLimits], 2, []).';
            columnLimits = reshape([tiles.SourceColumnLimits], 2, []).';
            rowIndices = unique(rowLimits(:).', "sorted");
            columnIndices = unique(columnLimits(:).', "sorted");
        end

        function corners = tileRenderCorners(mesh, tiles)
            tileCount = numel(tiles);
            corners = zeros(3, 4, tileCount);
            for tileIndex = 1:tileCount
                [~, rowLocations] = ismember( ...
                    tiles(tileIndex).SourceRowLimits, mesh.RowIndices);
                [~, columnLocations] = ismember( ...
                    tiles(tileIndex).SourceColumnLimits, mesh.ColumnIndices);
                corners(:, :, tileIndex) = [ ...
                    mesh.RenderPoints(:, rowLocations(1), columnLocations(1)), ...
                    mesh.RenderPoints(:, rowLocations(1), columnLocations(2)), ...
                    mesh.RenderPoints(:, rowLocations(2), columnLocations(2)), ...
                    mesh.RenderPoints(:, rowLocations(2), columnLocations(1))];
            end
        end
    end
end
