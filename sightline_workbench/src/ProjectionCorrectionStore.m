classdef ProjectionCorrectionStore < handle
    %ProjectionCorrectionStore Authoritative correction lifecycle and scene owner.

    properties (Access = private)
        SceneState struct
        BaseGenerationId string
        Entries struct = struct("Sequence", {}, "GenerationId", {}, ...
            "Lifecycle", {}, "Transition", {}, "CorrectionSet", {}, ...
            "ParentScene", {}, "AppliedScene", {}, "ParentAppliedSet", {})
        CurrentProposedIndex double = 0
        CurrentAcceptedIndex double = 0
        CurrentAppliedIndex double = 0
        Callbacks struct
        CallbackFailures struct = struct("Sequence", {}, "Transition", {}, ...
            "GenerationId", {}, "Identifier", {}, "Message", {})
        InTransition logical = false
        Sequence double = 0
        LastGeometryEffects struct = struct(Kind="none", ...
            Transition="", GeometryChanged=false, ...
            InvalidatedProducts=strings(1, 0), ...
            RequiredRecomputation=strings(1, 0), ...
            RecomputeRequired=false, ScopeViewIds=strings(1, 0), ...
            SourcePointSetGenerationId="")
    end

    methods
        function store = ProjectionCorrectionStore(scene, options)
            %ProjectionCorrectionStore Create a graphics-independent owner.
            if nargin < 2
                options = struct();
            end
            scene = ProjectionViewMetadata.ensureScene(scene);
            options = ProjectionCorrectionStore.validateOptions(options);
            store.SceneState = scene;
            store.BaseGenerationId = options.InitialGenerationId;
            store.Callbacks = struct(accepted={options.CorrectionAcceptedFcn}, ...
                applied={options.CorrectionAppliedFcn}, ...
                reverted={options.CorrectionRevertedFcn});
        end

        function scene = scene(store)
            %scene Return the current authoritative scene value.
            scene = store.SceneState;
        end

        function generationId = currentGenerationId(store)
            %currentGenerationId Return the exact current geometry generation.
            if store.CurrentAppliedIndex > 0
                generationId = store.Entries( ...
                    store.CurrentAppliedIndex).GenerationId;
            else
                generationId = store.BaseGenerationId;
            end
        end

        function tf = hasCurrent(store, lifecycle)
            %hasCurrent Report whether a named current lifecycle exists.
            tf = ~isempty(store.current(lifecycle));
        end

        function correctionSet = current(store, lifecycle)
            %current Return current proposed, accepted, or applied generation.
            lifecycle = lower(ProjectionCorrectionStore.scalarString( ...
                lifecycle, "lifecycle"));
            switch lifecycle
                case "proposed"
                    index = store.CurrentProposedIndex;
                case "accepted"
                    index = store.CurrentAcceptedIndex;
                case "applied"
                    index = store.CurrentAppliedIndex;
                otherwise
                    error("ProjectionCorrectionStore:invalidQuery", ...
                        "Current lifecycle query must be proposed, accepted, or applied.");
            end
            if index == 0
                correctionSet = [];
            else
                correctionSet = store.Entries(index).CorrectionSet;
            end
        end

        function records = history(store, generationId)
            %history Return immutable public lifecycle records.
            if nargin < 2
                selected = true(1, numel(store.Entries));
            else
                generationId = ProjectionCorrectionStore.scalarString( ...
                    generationId, "generationId");
                selected = string({store.Entries.GenerationId}) == generationId;
            end
            entries = store.Entries(selected);
            records = struct("Sequence", {}, "GenerationId", {}, ...
                "Lifecycle", {}, "Transition", {}, "CorrectionSet", {});
            for index = 1:numel(entries)
                records(index) = struct(Sequence=entries(index).Sequence, ...
                    GenerationId=entries(index).GenerationId, ...
                    Lifecycle=entries(index).Lifecycle, ...
                    Transition=entries(index).Transition, ...
                    CorrectionSet=entries(index).CorrectionSet);
            end
        end

        function value = diagnostics(store)
            %diagnostics Return lifecycle and callback failure diagnostics.
            value = struct(CurrentGenerationId=store.currentGenerationId(), ...
                HistoryCount=numel(store.Entries), ...
                CallbackFailures=store.CallbackFailures, ...
                TransitionInProgress=store.InTransition, ...
                LastGeometryEffects=store.LastGeometryEffects);
        end

        function synchronizeScene(store, scene, generationId)
            %synchronizeScene Adopt externally managed geometry before SDK use.
            guard = store.beginTransition(); %#ok<NASGU>
            if store.CurrentAppliedIndex > 0
                error("ProjectionCorrectionStore:appliedGenerationActive", ...
                    "Cannot synchronize while an applied generation is active.");
            end
            scene = ProjectionViewMetadata.ensureScene(scene);
            store.SceneState = scene;
            if nargin >= 3
                store.BaseGenerationId = ProjectionCorrectionStore.scalarString( ...
                    generationId, "generationId");
            end
        end

        function proposed = propose(store, correctionSet)
            %propose Record a new immutable solver proposal.
            guard = store.beginTransition(); %#ok<NASGU>
            proposed = ProjectionCorrectionSet.create(correctionSet);
            if proposed.Lifecycle ~= "proposed"
                error("ProjectionCorrectionStore:invalidLifecycle", ...
                    "Only a proposed CorrectionSet can enter propose.");
            end
            if store.CurrentProposedIndex > 0
                prior = store.Entries(store.CurrentProposedIndex).CorrectionSet;
                store.append(prior.withLifecycle("superseded"), ...
                    "supersedeByProposal");
            end
            store.CurrentProposedIndex = store.append(proposed, "propose");
        end

        function accepted = accept(store, generationId)
            %accept Accept one valid current proposal.
            guard = store.beginTransition(); %#ok<NASGU>
            [entry, index] = store.latest(generationId);
            if index ~= store.CurrentProposedIndex || ...
                    entry.Lifecycle ~= "proposed"
                error("ProjectionCorrectionStore:invalidLifecycle", ...
                    "Only the current proposed generation can be accepted.");
            end
            if ~entry.CorrectionSet.Failure.Valid
                error("ProjectionCorrectionStore:failedCorrection", ...
                    "A failed CorrectionSet cannot be accepted.");
            end
            if store.CurrentAcceptedIndex > 0
                prior = store.Entries(store.CurrentAcceptedIndex).CorrectionSet;
                store.append(prior.withLifecycle("superseded"), ...
                    "supersedeByAcceptance");
            end
            accepted = entry.CorrectionSet.withLifecycle("accepted");
            store.CurrentAcceptedIndex = store.append(accepted, "accept");
            store.CurrentProposedIndex = 0;
            store.deliverCallbacks("accepted", accepted);
        end

        function rejected = reject(store, generationId)
            %reject Reject a current proposed or accepted generation.
            guard = store.beginTransition(); %#ok<NASGU>
            [entry, index] = store.latest(generationId);
            if ~any(entry.Lifecycle == ["proposed" "accepted"])
                error("ProjectionCorrectionStore:invalidLifecycle", ...
                    "Only proposed or accepted generations can be rejected.");
            end
            rejected = entry.CorrectionSet.withLifecycle("rejected");
            store.append(rejected, "reject");
            store.clearCurrentIndex(index);
        end

        function superseded = supersede(store, generationId)
            %supersede Supersede a current proposed or accepted generation.
            guard = store.beginTransition(); %#ok<NASGU>
            [entry, index] = store.latest(generationId);
            if ~any(entry.Lifecycle == ["proposed" "accepted"])
                error("ProjectionCorrectionStore:invalidLifecycle", ...
                    "Only proposed or accepted generations can be superseded.");
            end
            superseded = entry.CorrectionSet.withLifecycle("superseded");
            store.append(superseded, "supersede");
            store.clearCurrentIndex(index);
        end

        function [scene, applied, effects] = apply(store, generationId)
            %apply Atomically validate, apply, verify, and publish a generation.
            guard = store.beginTransition(); %#ok<NASGU>
            generationId = ProjectionCorrectionStore.scalarString( ...
                generationId, "generationId");
            if store.CurrentAppliedIndex > 0 && ...
                    store.Entries(store.CurrentAppliedIndex).GenerationId == ...
                    generationId
                error("ProjectionCorrectionStore:alreadyApplied", ...
                    "Generation %s is already applied.", generationId);
            end
            [entry, index] = store.latest(generationId);
            if index ~= store.CurrentAcceptedIndex || ...
                    entry.Lifecycle ~= "accepted"
                error("ProjectionCorrectionStore:invalidLifecycle", ...
                    "Only the current accepted generation can be applied.");
            end
            correctionSet = entry.CorrectionSet;
            if ~correctionSet.Failure.Valid
                error("ProjectionCorrectionStore:failedCorrection", ...
                    "A failed CorrectionSet cannot be applied.");
            end
            expectedParent = store.currentGenerationId();
            if correctionSet.ParentGenerationId ~= expectedParent
                error("ProjectionCorrectionStore:wrongParent", ...
                    "Correction parent %s does not match current generation %s.", ...
                    correctionSet.ParentGenerationId, expectedParent);
            end
            correctionSet.assertCompatible(store.SceneState);

            parentScene = store.SceneState;
            candidateScene = ProjectionCorrectionStore.applyToCopy( ...
                parentScene, correctionSet);
            ProjectionCorrectionStore.verifyFingerprints( ...
                candidateScene, correctionSet, "CorrectedGeometryFingerprint");

            parentAppliedSet = store.current("applied");
            if store.CurrentAppliedIndex > 0
                prior = store.Entries(store.CurrentAppliedIndex).CorrectionSet;
                store.append(prior.withLifecycle("historical"), ...
                    "historicalAfterApply");
            end
            applied = correctionSet.withLifecycle("applied");
            store.SceneState = candidateScene;
            store.CurrentAppliedIndex = store.append(applied, "apply", ...
                parentScene, candidateScene, parentAppliedSet);
            store.CurrentAcceptedIndex = 0;
            effects = ProjectionDemCorrectionAdapter.effects( ...
                applied, "apply");
            store.LastGeometryEffects = effects;
            scene = store.SceneState;
            store.deliverCallbacks("applied", applied);
        end

        function [scene, reverted, effects] = revert(store, generationId)
            %revert Restore and verify the exact parent generation atomically.
            guard = store.beginTransition(); %#ok<NASGU>
            generationId = ProjectionCorrectionStore.scalarString( ...
                generationId, "generationId");
            if store.CurrentAppliedIndex == 0 || ...
                    store.Entries(store.CurrentAppliedIndex).GenerationId ~= ...
                    generationId
                error("ProjectionCorrectionStore:invalidLifecycle", ...
                    "Only the current applied generation can be reverted.");
            end
            entry = store.Entries(store.CurrentAppliedIndex);
            ProjectionCorrectionStore.verifyFingerprints(store.SceneState, ...
                entry.CorrectionSet, "CorrectedGeometryFingerprint");
            parentScene = entry.ParentScene;
            ProjectionCorrectionStore.verifyFingerprints(parentScene, ...
                entry.CorrectionSet, "ParentGeometryFingerprint");

            reverted = entry.CorrectionSet.withLifecycle("reverted");
            store.SceneState = parentScene;
            store.append(reverted, "revert", parentScene, struct(), []);
            store.CurrentAppliedIndex = 0;
            if ~isempty(entry.ParentAppliedSet)
                restored = entry.ParentAppliedSet.withLifecycle("applied");
                priorEntry = store.appliedEntry(restored.GenerationId);
                store.CurrentAppliedIndex = store.append(restored, ...
                    "restoreParentAfterRevert", priorEntry.ParentScene, ...
                    parentScene, priorEntry.ParentAppliedSet);
            end
            effects = ProjectionDemCorrectionAdapter.effects( ...
                reverted, "revert");
            store.LastGeometryEffects = effects;
            scene = store.SceneState;
            store.deliverCallbacks("reverted", reverted);
        end
    end

    methods (Static, Access = private)
        function options = validateOptions(options)
            if isempty(options)
                options = struct();
            end
            if ~isstruct(options) || ~isscalar(options)
                error("ProjectionCorrectionStore:invalidOptions", ...
                    "Correction store options must be a scalar struct.");
            end
            defaults = struct(InitialGenerationId="scene-base", ...
                CorrectionAcceptedFcn={{}}, CorrectionAppliedFcn={{}}, ...
                CorrectionRevertedFcn={{}});
            names = fieldnames(options);
            for index = 1:numel(names)
                if ~isfield(defaults, names{index})
                    error("ProjectionCorrectionStore:invalidOptions", ...
                        "Unknown correction store option %s.", names{index});
                end
                defaults.(names{index}) = options.(names{index});
            end
            defaults.InitialGenerationId = ...
                ProjectionCorrectionStore.scalarString( ...
                defaults.InitialGenerationId, "InitialGenerationId");
            callbackNames = ["CorrectionAcceptedFcn" ...
                "CorrectionAppliedFcn" "CorrectionRevertedFcn"];
            for name = callbackNames
                defaults.(name) = ProjectionCorrectionStore.callbacks( ...
                    defaults.(name), name);
            end
            options = defaults;
        end

        function callbacks = callbacks(value, name)
            if isempty(value)
                callbacks = {};
            elseif isa(value, "function_handle")
                callbacks = {value};
            elseif iscell(value) && ...
                    all(cellfun(@(item) isa(item, "function_handle"), value))
                callbacks = reshape(value, 1, []);
            else
                error("ProjectionCorrectionStore:invalidCallback", ...
                    "%s must contain only function handles.", name);
            end
        end

        function value = scalarString(value, name)
            value = string(value);
            if ~isscalar(value) || ismissing(value) || ...
                    strlength(strip(value)) == 0 || value ~= strip(value)
                error("ProjectionCorrectionStore:invalidString", ...
                    "%s must be a nonempty trimmed scalar string.", name);
            end
        end

        function scene = applyToCopy(scene, correctionSet)
            positionPlan = ProjectionDemCorrectionAdapter. ...
                applicationPlan(correctionSet);
            for index = 1:numel(correctionSet.Views)
                record = correctionSet.Views(index);
                layerIndex = ProjectionViewMetadata.indexForId( ...
                    scene, record.ViewId);
                scene.layers(layerIndex).ViewVectorAngularOffsetsDegrees = ...
                    rad2deg(record.EffectiveAttitudeRadians(:));
                scene.layers(layerIndex).ProjectionOffsetMeters = ...
                    record.EffectiveProjectionOffsetMeters(:);
                if positionPlan.Available && ...
                        ismember(record.ViewId, positionPlan.ScopeViewIds)
                    scene.layers(layerIndex).SourceGeometry = ...
                        ProjectionSourceGeometry.translateOrigins( ...
                        scene.layers(layerIndex).SourceGeometry, ...
                        positionPlan.TranslationWorldMeters);
                end
            end
        end

        function verifyFingerprints(scene, correctionSet, fieldName)
            for index = 1:numel(correctionSet.Views)
                record = correctionSet.Views(index);
                layerIndex = ProjectionViewMetadata.indexForId( ...
                    scene, record.ViewId);
                actual = ProjectionGeometryFingerprint.layer( ...
                    scene.layers(layerIndex));
                if actual ~= record.(fieldName)
                    error("ProjectionCorrectionStore:fingerprintMismatch", ...
                        "%s verification failed for ViewId %s: expected %s, got %s.", ...
                        fieldName, record.ViewId, record.(fieldName), actual);
                end
            end
        end
    end

    methods (Access = private)
        function cleanup = beginTransition(store)
            if store.InTransition
                error("ProjectionCorrectionStore:reentrantTransition", ...
                    "Correction transitions cannot be reentered from a callback.");
            end
            store.InTransition = true;
            cleanup = onCleanup(@() store.endTransition());
        end

        function endTransition(store)
            store.InTransition = false;
        end

        function index = append(store, correctionSet, transition, ...
                parentScene, appliedScene, parentAppliedSet)
            if nargin < 4
                parentScene = struct();
            end
            if nargin < 5
                appliedScene = struct();
            end
            if nargin < 6
                parentAppliedSet = [];
            end
            store.Sequence = store.Sequence + 1;
            record = struct(Sequence=store.Sequence, ...
                GenerationId=correctionSet.GenerationId, ...
                Lifecycle=correctionSet.Lifecycle, ...
                Transition=string(transition), ...
                CorrectionSet=correctionSet, ParentScene=parentScene, ...
                AppliedScene=appliedScene, ParentAppliedSet=parentAppliedSet);
            store.Entries(end + 1) = record;
            index = numel(store.Entries);
        end

        function [entry, index] = latest(store, generationId)
            generationId = ProjectionCorrectionStore.scalarString( ...
                generationId, "generationId");
            indices = find(string({store.Entries.GenerationId}) == generationId);
            if isempty(indices)
                error("ProjectionCorrectionStore:unknownGeneration", ...
                    "Unknown correction generation %s.", generationId);
            end
            index = indices(end);
            entry = store.Entries(index);
        end

        function entry = appliedEntry(store, generationId)
            indices = find(string({store.Entries.GenerationId}) == generationId & ...
                string({store.Entries.Lifecycle}) == "applied");
            if isempty(indices)
                error("ProjectionCorrectionStore:missingParentGeneration", ...
                    "Applied parent generation %s is unavailable.", generationId);
            end
            entry = store.Entries(indices(end));
        end

        function clearCurrentIndex(store, index)
            if store.CurrentProposedIndex == index
                store.CurrentProposedIndex = 0;
            end
            if store.CurrentAcceptedIndex == index
                store.CurrentAcceptedIndex = 0;
            end
        end

        function deliverCallbacks(store, transition, correctionSet)
            callbacks = store.Callbacks.(transition);
            for index = 1:numel(callbacks)
                try
                    callbacks{index}(correctionSet);
                catch exception
                    failure = struct(Sequence=store.Sequence, ...
                        Transition=string(transition), ...
                        GenerationId=correctionSet.GenerationId, ...
                        Identifier=string(exception.identifier), ...
                        Message=string(exception.message));
                    store.CallbackFailures(end + 1) = failure;
                end
            end
        end
    end
end
