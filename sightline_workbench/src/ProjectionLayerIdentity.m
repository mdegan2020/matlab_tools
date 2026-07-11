classdef ProjectionLayerIdentity
    %ProjectionLayerIdentity Assign and resolve stable serializable layer IDs.

    properties (Constant)
        Prefix = "layer-"
    end

    methods (Static)
        function scene = ensureScene(scene)
            %ensureScene Return a scene whose layers have unique stable IDs.
            if ~isstruct(scene) || ~isscalar(scene) || ...
                    ~isfield(scene, "layers") || isempty(scene.layers) || ...
                    ~isstruct(scene.layers)
                error("ProjectionLayerIdentity:invalidScene", ...
                    "Scene must contain a nonempty struct array of layers.");
            end

            scene.layers = ProjectionLayerIdentity.ensureLayers(scene.layers);
        end

        function layers = ensureLayers(layers)
            %ensureLayers Add missing IDs and validate existing layer IDs.
            if isempty(layers) || ~isstruct(layers)
                error("ProjectionLayerIdentity:invalidLayers", ...
                    "Layers must be a nonempty struct array.");
            end
            if ~isfield(layers, "LayerId")
                [layers.LayerId] = deal("");
            end

            layerIds = strings(1, numel(layers));
            for layerIndex = 1:numel(layers)
                layerIds(layerIndex) = ProjectionLayerIdentity.validateOptionalId( ...
                    layers(layerIndex).LayerId, layerIndex);
            end

            nonemptyIds = unique(layerIds(strlength(layerIds) > 0), "stable");
            for idIndex = 1:numel(nonemptyIds)
                duplicateIndices = find(layerIds == nonemptyIds(idIndex));
                if numel(duplicateIndices) > 1
                    if ProjectionLayerIdentity.isGeneratedId(nonemptyIds(idIndex))
                        layerIds(duplicateIndices(2:end)) = "";
                    else
                        error("ProjectionLayerIdentity:duplicateId", ...
                            "Nonempty LayerId values must be unique within a scene.");
                    end
                end
            end

            nextNumber = 1;
            for layerIndex = 1:numel(layers)
                if strlength(layerIds(layerIndex)) == 0
                    [layerIds(layerIndex), nextNumber] = ...
                        ProjectionLayerIdentity.nextAvailableId( ...
                        layerIds, nextNumber);
                end
                layers(layerIndex).LayerId = layerIds(layerIndex);
            end
        end

        function layerIds = ids(scene)
            %ids Return scene layer IDs in current storage order.
            scene = ProjectionLayerIdentity.ensureScene(scene);
            layerIds = reshape(string({scene.layers.LayerId}), 1, []);
        end

        function layerIds = idsForIndices(scene, layerIndices)
            %idsForIndices Return stable IDs for selected current layer indices.
            scene = ProjectionLayerIdentity.ensureScene(scene);
            layerIndices = ProjectionLayerIdentity.validateIndices( ...
                layerIndices, numel(scene.layers));
            allIds = ProjectionLayerIdentity.ids(scene);
            layerIds = allIds(layerIndices);
        end

        function layerIndex = indexForId(scene, layerId)
            %indexForId Resolve one stable layer ID to the current scene index.
            scene = ProjectionLayerIdentity.ensureScene(scene);
            layerId = ProjectionLayerIdentity.validateRequiredId(layerId, "layerId");
            layerIds = ProjectionLayerIdentity.ids(scene);
            matches = find(layerIds == layerId);
            if isempty(matches)
                error("ProjectionLayerIdentity:unknownId", ...
                    "LayerId %s is not present in the scene.", layerId);
            end
            if numel(matches) ~= 1
                error("ProjectionLayerIdentity:duplicateId", ...
                    "LayerId %s is not unique within the scene.", layerId);
            end
            layerIndex = matches(1);
        end
    end

    methods (Static, Access = private)
        function value = validateOptionalId(value, layerIndex)
            if isempty(value)
                value = "";
                return
            end
            value = string(value);
            if ~isscalar(value) || ismissing(value)
                error("ProjectionLayerIdentity:invalidId", ...
                    "Scene layer %d LayerId must be a scalar string.", layerIndex);
            end
            value = strip(value);
        end

        function value = validateRequiredId(value, name)
            value = string(value);
            if ~isscalar(value) || ismissing(value) || strlength(strip(value)) == 0
                error("ProjectionLayerIdentity:invalidId", ...
                    "%s must be a nonempty scalar string.", name);
            end
            value = strip(value);
        end

        function [layerId, nextNumber] = nextAvailableId(layerIds, nextNumber)
            while true
                layerId = string(sprintf("%s%06d", ...
                    ProjectionLayerIdentity.Prefix, nextNumber));
                nextNumber = nextNumber + 1;
                if ~any(layerIds == layerId)
                    return
                end
            end
        end

        function tf = isGeneratedId(layerId)
            expression = "^" + ProjectionLayerIdentity.Prefix + "\d{6}$";
            tf = ~isempty(regexp(char(layerId), char(expression), "once"));
        end

        function indices = validateIndices(indices, layerCount)
            if ~isnumeric(indices) || isempty(indices) || ~isvector(indices) || ...
                    any(~isfinite(indices)) || any(indices < 1) || ...
                    any(indices > layerCount) || any(fix(indices) ~= indices)
                error("ProjectionLayerIdentity:invalidIndices", ...
                    "Layer indices must refer to existing scene layers.");
            end
            indices = double(reshape(indices, 1, []));
        end
    end
end
