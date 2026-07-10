classdef ProjectionAlignmentLayerResolver
    %ProjectionAlignmentLayerResolver Resolve alignment state by stable layer ID.

    methods (Static)
        function indices = pairIndices(scene, pairLike, priorScene)
            %pairIndices Resolve a moving-to-reference pair in the current scene.
            if nargin < 3
                priorScene = [];
            end
            scene = ProjectionLayerIdentity.ensureScene(scene);
            layerIds = ProjectionAlignmentLayerResolver.pairLayerIds( ...
                pairLike, priorScene);
            if ~isempty(layerIds)
                indices = [ProjectionLayerIdentity.indexForId(scene, layerIds(1)), ...
                    ProjectionLayerIdentity.indexForId(scene, layerIds(2))];
                return
            end

            if isstruct(pairLike) && isfield(pairLike, "Pair")
                indices = double(pairLike.Pair(:).');
            else
                indices = double(pairLike(:).');
            end
            if numel(indices) ~= 2 || any(~isfinite(indices)) || ...
                    any(indices < 1) || any(indices > numel(scene.layers))
                error("ProjectionAlignmentLayerResolver:invalidPair", ...
                    "An alignment pair must resolve to two current scene layers.");
            end
        end

        function value = reindex(scene, value, priorScene)
            %reindex Refresh known numeric alignment indices from stable IDs.
            if nargin < 3
                priorScene = [];
            end
            scene = ProjectionLayerIdentity.ensureScene(scene);
            if ~isempty(priorScene)
                priorScene = ProjectionLayerIdentity.ensureScene(priorScene);
            end
            value = ProjectionAlignmentLayerResolver.reindexValue( ...
                scene, value, priorScene);
        end
    end

    methods (Static, Access = private)
        function value = reindexValue(scene, value, priorScene)
            if iscell(value)
                for k = 1:numel(value)
                    value{k} = ProjectionAlignmentLayerResolver.reindexValue( ...
                        scene, value{k}, priorScene);
                end
                return
            end
            if ~isstruct(value) || isempty(value)
                return
            end

            for elementIndex = 1:numel(value)
                item = value(elementIndex);
                if isfield(item, "Scene")
                    item.Scene = scene;
                end

                pairIds = ProjectionAlignmentLayerResolver.pairLayerIds( ...
                    item, priorScene);
                if isfield(item, "Pair") && ~isempty(pairIds)
                    item.Pair = [ ...
                        ProjectionLayerIdentity.indexForId(scene, pairIds(1)), ...
                        ProjectionLayerIdentity.indexForId(scene, pairIds(2))];
                    if isfield(item, "PairKey")
                        item.PairKey = ProjectionAlignmentLayerResolver.pairKey( ...
                            item.Pair);
                    end
                elseif isfield(item, "Pair") && ~isempty(priorScene)
                    item.Pair = ProjectionAlignmentLayerResolver.remapIndices( ...
                        scene, priorScene, item.Pair);
                    if isfield(item, "PairKey")
                        item.PairKey = ProjectionAlignmentLayerResolver.pairKey( ...
                            item.Pair);
                    end
                end

                if isfield(item, "LayerId") && isfield(item, "LayerIndex") && ...
                        strlength(string(item.LayerId)) > 0
                    item.LayerIndex = ProjectionLayerIdentity.indexForId( ...
                        scene, item.LayerId);
                end
                if isfield(item, "LayerIds") && isfield(item, "LayerIndices") && ...
                        numel(item.LayerIds) == numel(item.LayerIndices) && ...
                        all(strlength(string(item.LayerIds)) > 0)
                    item.LayerIndices = arrayfun( ...
                        @(layerId) ProjectionLayerIdentity.indexForId( ...
                        scene, layerId), reshape(string(item.LayerIds), 1, []));
                elseif isfield(item, "LayerIndices") && ~isempty(priorScene)
                    item.LayerIndices = ProjectionAlignmentLayerResolver.remapIndices( ...
                        scene, priorScene, item.LayerIndices);
                end
                if isfield(item, "ReferenceLayerId") && ...
                        isfield(item, "ReferenceLayerIndex") && ...
                        strlength(string(item.ReferenceLayerId)) > 0
                    item.ReferenceLayerIndex = ProjectionLayerIdentity.indexForId( ...
                        scene, item.ReferenceLayerId);
                elseif isfield(item, "ReferenceLayerIndex") && ~isempty(priorScene)
                    item.ReferenceLayerIndex = ...
                        ProjectionAlignmentLayerResolver.remapIndices( ...
                        scene, priorScene, item.ReferenceLayerIndex);
                end

                fieldNames = fieldnames(item);
                for fieldIndex = 1:numel(fieldNames)
                    fieldName = fieldNames{fieldIndex};
                    if strcmp(fieldName, "Scene")
                        continue
                    end
                    fieldValue = item.(fieldName);
                    if isstruct(fieldValue) || iscell(fieldValue)
                        item.(fieldName) = ...
                            ProjectionAlignmentLayerResolver.reindexValue( ...
                            scene, fieldValue, priorScene);
                    end
                end
                value(elementIndex) = item;
            end
        end

        function layerIds = pairLayerIds(pairLike, priorScene)
            layerIds = strings(1, 0);
            if ~isstruct(pairLike) || ~isscalar(pairLike)
                return
            end
            if isfield(pairLike, "PairLayerIds") && ...
                    numel(pairLike.PairLayerIds) == 2 && ...
                    all(strlength(string(pairLike.PairLayerIds)) > 0)
                layerIds = reshape(string(pairLike.PairLayerIds), 1, []);
            elseif isfield(pairLike, "MovingLayerId") && ...
                    isfield(pairLike, "ReferenceLayerId") && ...
                    all(strlength([string(pairLike.MovingLayerId), ...
                    string(pairLike.ReferenceLayerId)]) > 0)
                layerIds = [string(pairLike.MovingLayerId), ...
                    string(pairLike.ReferenceLayerId)];
            elseif ~isempty(priorScene) && isfield(pairLike, "Pair")
                pair = double(pairLike.Pair(:).');
                if numel(pair) == 2 && all(pair >= 1) && ...
                        all(pair <= numel(priorScene.layers))
                    layerIds = ProjectionLayerIdentity.idsForIndices( ...
                        priorScene, pair);
                end
            end
        end

        function indices = remapIndices(scene, priorScene, indices)
            originalSize = size(indices);
            indices = double(indices(:).');
            if isempty(indices)
                indices = reshape(indices, originalSize);
                return
            end
            if any(~isfinite(indices)) || any(indices < 1) || ...
                    any(indices > numel(priorScene.layers))
                return
            end
            layerIds = ProjectionLayerIdentity.idsForIndices(priorScene, indices);
            for k = 1:numel(indices)
                indices(k) = ProjectionLayerIdentity.indexForId(scene, layerIds(k));
            end
            indices = reshape(indices, originalSize);
        end

        function key = pairKey(pair)
            key = sprintf("%d -> %d", pair(1), pair(2));
        end
    end
end
