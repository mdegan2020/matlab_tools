classdef ProjectionSoloPairVisibility
    %ProjectionSoloPairVisibility Runtime-only solo-pair visibility state.

    methods (Static)
        function state = activate(scene, referenceViewId, movingViewId)
            scene = ProjectionViewMetadata.ensureScene(scene);
            pair = ProjectionViewMetadata.pairIdentity( ...
                referenceViewId, movingViewId);
            viewIds = ProjectionViewMetadata.ids(scene);
            if any(~ismember(pair.ViewIds, viewIds))
                error("ProjectionSoloPairVisibility:unknownView", ...
                    "Both solo-pair views must exist in the scene.");
            end

            state = struct();
            state.Active = true;
            state.ReferenceViewId = string(referenceViewId);
            state.MovingViewId = string(movingViewId);
            state.SnapshotViewIds = viewIds;
            state.SnapshotVisible = logical([scene.layers.Visible]);
        end

        function state = follow(state, scene, referenceViewId, movingViewId)
            if ~ProjectionSoloPairVisibility.isActive(state)
                state = ProjectionSoloPairVisibility.activate( ...
                    scene, referenceViewId, movingViewId);
                return
            end
            pair = ProjectionViewMetadata.pairIdentity( ...
                referenceViewId, movingViewId);
            viewIds = ProjectionViewMetadata.ids( ...
                ProjectionViewMetadata.ensureScene(scene));
            if any(~ismember(pair.ViewIds, viewIds))
                error("ProjectionSoloPairVisibility:unknownView", ...
                    "Both solo-pair views must exist in the scene.");
            end
            state.ReferenceViewId = string(referenceViewId);
            state.MovingViewId = string(movingViewId);
        end

        function mask = effectiveMask(state, scene)
            scene = ProjectionViewMetadata.ensureScene(scene);
            if ~ProjectionSoloPairVisibility.isActive(state)
                mask = logical([scene.layers.Visible]);
                return
            end
            viewIds = ProjectionViewMetadata.ids(scene);
            mask = ismember(viewIds, ...
                [state.ReferenceViewId state.MovingViewId]);
        end

        function scene = restore(scene, state)
            scene = ProjectionViewMetadata.ensureScene(scene);
            if ~ProjectionSoloPairVisibility.isActive(state)
                return
            end
            viewIds = ProjectionViewMetadata.ids(scene);
            for snapshotIndex = 1:numel(state.SnapshotViewIds)
                layerIndex = find(viewIds == state.SnapshotViewIds(snapshotIndex), ...
                    1, "first");
                if ~isempty(layerIndex)
                    scene.layers(layerIndex).Visible = ...
                        state.SnapshotVisible(snapshotIndex);
                end
            end
        end

        function tf = isActive(state)
            tf = isstruct(state) && isscalar(state) && ...
                isfield(state, "Active") && logical(state.Active);
        end
    end
end
