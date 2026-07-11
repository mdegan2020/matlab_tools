classdef ProjectionLayerManager
    %ProjectionLayerManager Helpers for simple multi-layer scene workflows.

    methods (Static)
        function [scene, activeIndex] = setActiveLayer(scene, activeIndex)
            %setActiveLayer Set one layer alpha to one and all others to zero.
            ProjectionLayerManager.validateScene(scene);
            activeIndex = ProjectionLayerManager.validateLayerIndex(scene, activeIndex);

            for layerIndex = 1:numel(scene.layers)
                scene.layers(layerIndex).Alpha = double(layerIndex == activeIndex);
                scene.layers(layerIndex).Visible = true;
            end
        end

        function [scene, activeIndex] = cycleActiveLayer(scene, direction)
            %cycleActiveLayer Advance the single-active-layer change workflow.
            ProjectionLayerManager.validateScene(scene);
            if nargin < 2
                direction = 1;
            end
            direction = ProjectionLayerManager.validateDirection(direction);

            activeIndex = ProjectionLayerManager.currentActiveLayerIndex(scene);
            activeIndex = mod(activeIndex - 1 + direction, numel(scene.layers)) + 1;
            [scene, activeIndex] = ProjectionLayerManager.setActiveLayer(scene, activeIndex);
        end

        function scene = setLayerAlpha(scene, layerIndex, alpha)
            %setLayerAlpha Update one layer alpha.
            ProjectionLayerManager.validateScene(scene);
            layerIndex = ProjectionLayerManager.validateLayerIndex(scene, layerIndex);
            alpha = ProjectionLayerManager.validateAlpha(alpha);
            scene.layers(layerIndex).Alpha = alpha;
        end

        function scene = setLayerVisible(scene, layerIndex, visible)
            %setLayerVisible Update one layer visibility flag.
            ProjectionLayerManager.validateScene(scene);
            layerIndex = ProjectionLayerManager.validateLayerIndex(scene, layerIndex);
            scene.layers(layerIndex).Visible = logical(visible);
        end
    end

    methods (Static, Access = private)
        function validateScene(scene)
            if ~isstruct(scene) || ~isscalar(scene) || ~isfield(scene, "layers") || ...
                    isempty(scene.layers) || ~isstruct(scene.layers)
                error("ProjectionLayerManager:invalidScene", ...
                    "Scene must contain a nonempty struct array of layers.");
            end
        end

        function layerIndex = validateLayerIndex(scene, layerIndex)
            if ~isnumeric(layerIndex) || ~isscalar(layerIndex) || ~isfinite(layerIndex) || ...
                    layerIndex < 1 || layerIndex > numel(scene.layers) || ...
                    fix(layerIndex) ~= layerIndex
                error("ProjectionLayerManager:invalidLayerIndex", ...
                    "Layer index must select an existing scene layer.");
            end
            layerIndex = double(layerIndex);
        end

        function alpha = validateAlpha(alpha)
            if ~isnumeric(alpha) || ~isscalar(alpha) || ~isfinite(alpha) || ...
                    alpha < 0 || alpha > 1
                error("ProjectionLayerManager:invalidAlpha", ...
                    "Layer alpha must be a finite scalar in the range [0, 1].");
            end
            alpha = double(alpha);
        end

        function direction = validateDirection(direction)
            if ~isnumeric(direction) || ~isscalar(direction) || ~isfinite(direction) || ...
                    direction == 0 || fix(direction) ~= direction
                error("ProjectionLayerManager:invalidDirection", ...
                    "Cycle direction must be a nonzero integer scalar.");
            end
            direction = double(direction);
        end

        function activeIndex = currentActiveLayerIndex(scene)
            activeIndex = find([scene.layers.Visible] & [scene.layers.Alpha] >= 1, ...
                1, "first");
            if isempty(activeIndex)
                activeIndex = find([scene.layers.Visible], 1, "first");
            end
            if isempty(activeIndex)
                activeIndex = 1;
            end
        end
    end
end
