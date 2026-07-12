classdef ProjectionCorrectionStoreTest < matlab.unittest.TestCase
    %ProjectionCorrectionStoreTest Tests atomic correction lifecycle behavior.

    methods (TestClassSetup)
        function addProjectPaths(testCase)
            projectRoot = fileparts(fileparts(mfilename("fullpath")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(projectRoot, "src")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(projectRoot, "tests")));
        end
    end

    methods (Test)
        function testLifecycleApplyAndExactRevert(testCase)
            [scene, correctionSet] = ProjectionCorrectionStoreTest.fixture();
            parentFingerprints = ProjectionGeometryFingerprint.scene(scene);
            store = ProjectionCorrectionStore(scene, ...
                struct(InitialGenerationId="base-generation"));

            store.propose(correctionSet);
            accepted = store.accept(correctionSet.GenerationId);
            [appliedScene, applied] = store.apply(correctionSet.GenerationId);

            testCase.verifyEqual(accepted.Lifecycle, "accepted");
            testCase.verifyEqual(applied.Lifecycle, "applied");
            testCase.verifyEqual(store.current("applied").GenerationId, ...
                correctionSet.GenerationId);
            ProjectionCorrectionStoreTest.verifyScopeFingerprints( ...
                testCase, appliedScene, correctionSet, ...
                "CorrectedGeometryFingerprint");

            [revertedScene, reverted] = store.revert(correctionSet.GenerationId);
            revertedFingerprints = ProjectionGeometryFingerprint.scene(revertedScene);
            history = store.history(correctionSet.GenerationId);

            testCase.verifyEqual(reverted.Lifecycle, "reverted");
            testCase.verifyEqual(revertedFingerprints, parentFingerprints);
            testCase.verifyFalse(store.hasCurrent("applied"));
            testCase.verifyEqual(string({history.Lifecycle}), ...
                ["proposed" "accepted" "applied" "reverted"]);
            testCase.verifyError(@() store.apply(correctionSet.GenerationId), ...
                "ProjectionCorrectionStore:invalidLifecycle");
        end

        function testApplyIsAtomicWhenAnyCorrectedFingerprintFails(testCase)
            [scene, correctionSet] = ProjectionCorrectionStoreTest.fixture();
            data = correctionSet.toStruct();
            data.Views(2).CorrectedGeometryFingerprint = ...
                string(repmat('0', 1, 64));
            invalid = ProjectionCorrectionSet.create(data);
            before = ProjectionGeometryFingerprint.scene(scene);
            store = ProjectionCorrectionStore(scene, ...
                struct(InitialGenerationId="base-generation"));
            store.propose(invalid);
            store.accept(invalid.GenerationId);

            testCase.verifyError(@() store.apply(invalid.GenerationId), ...
                "ProjectionCorrectionStore:fingerprintMismatch");

            testCase.verifyEqual( ...
                ProjectionGeometryFingerprint.scene(store.scene()), before);
            testCase.verifyFalse(store.hasCurrent("applied"));
            testCase.verifyTrue(store.hasCurrent("accepted"));
            testCase.verifyEqual(string({store.history().Lifecycle}), ...
                ["proposed" "accepted"]);
        end

        function testInvalidLifecycleFailureWrongParentAndMissingViewAreRejected(testCase)
            [scene, correctionSet] = ProjectionCorrectionStoreTest.fixture();
            wrongParentData = correctionSet.toStruct();
            wrongParentData.ParentGenerationId = "other-parent";
            wrongParent = ProjectionCorrectionSet.create(wrongParentData);
            wrongParentStore = ProjectionCorrectionStore(scene, ...
                struct(InitialGenerationId="base-generation"));
            wrongParentStore.propose(wrongParent);
            wrongParentStore.accept(wrongParent.GenerationId);

            failedData = correctionSet.toStruct();
            failedData.Failure = struct(Valid=false, Code="failedSolve", ...
                Explanation="The solver failed.");
            failed = ProjectionCorrectionSet.create(failedData);
            failedStore = ProjectionCorrectionStore(scene, ...
                struct(InitialGenerationId="base-generation"));
            failedStore.propose(failed);

            missingScene = scene;
            missingScene.layers(2) = [];
            missingStore = ProjectionCorrectionStore(missingScene, ...
                struct(InitialGenerationId="base-generation"));
            missingStore.propose(correctionSet);
            missingStore.accept(correctionSet.GenerationId);

            rejectedStore = ProjectionCorrectionStore(scene, ...
                struct(InitialGenerationId="base-generation"));
            rejectedStore.propose(correctionSet);
            rejectedStore.reject(correctionSet.GenerationId);

            testCase.verifyError( ...
                @() wrongParentStore.apply(wrongParent.GenerationId), ...
                "ProjectionCorrectionStore:wrongParent");
            testCase.verifyError(@() failedStore.accept(failed.GenerationId), ...
                "ProjectionCorrectionStore:failedCorrection");
            testCase.verifyError( ...
                @() missingStore.apply(correctionSet.GenerationId), ...
                "ProjectionCorrectionSet:missingView");
            testCase.verifyError( ...
                @() rejectedStore.apply(correctionSet.GenerationId), ...
                "ProjectionCorrectionStore:invalidLifecycle");
        end

        function testCallbacksAreOrderedGuardedAndFailureIsolated(testCase)
            [scene, correctionSet] = ProjectionCorrectionStoreTest.fixture();
            probe = ProjectionCorrectionCallbackProbe();
            options = struct(InitialGenerationId="base-generation", ...
                CorrectionAcceptedFcn={{ ...
                @(set) probe.record("accepted-first", set), ...
                @probe.reenter}}, ...
                CorrectionAppliedFcn={{ ...
                @(set) probe.record("applied-first", set), @probe.fail}}, ...
                CorrectionRevertedFcn= ...
                @(set) probe.record("reverted-first", set));
            store = ProjectionCorrectionStore(scene, options);
            probe.Store = store;

            store.propose(correctionSet);
            store.accept(correctionSet.GenerationId);
            store.apply(correctionSet.GenerationId);
            store.revert(correctionSet.GenerationId);
            diagnostics = store.diagnostics();

            testCase.verifyEqual(probe.Events, ["accepted-first" ...
                "accepted-reenter" "applied-first" "applied-fail" ...
                "reverted-first"]);
            testCase.verifyEqual(numel(diagnostics.CallbackFailures), 2);
            testCase.verifyEqual( ...
                string({diagnostics.CallbackFailures.Identifier}), ...
                ["ProjectionCorrectionStore:reentrantTransition" ...
                "ProjectionCorrectionCallbackProbe:failure"]);
            testCase.verifyFalse(store.hasCurrent("applied"));
        end

        function testSupersededAndHistoricalGenerationsCannotApply(testCase)
            [scene, first] = ProjectionCorrectionStoreTest.fixture();
            store = ProjectionCorrectionStore(scene, ...
                struct(InitialGenerationId="base-generation"));
            store.propose(first);
            superseded = store.supersede(first.GenerationId);

            second = ProjectionCorrectionStoreTest.makeSet( ...
                scene, "store-generation-002", "base-generation");
            store.propose(second);
            store.accept(second.GenerationId);
            [secondScene, ~] = store.apply(second.GenerationId);

            third = ProjectionCorrectionStoreTest.makeSet( ...
                secondScene, "store-generation-003", second.GenerationId);
            store.propose(third);
            store.accept(third.GenerationId);
            [thirdScene, ~] = store.apply(third.GenerationId);

            testCase.verifyEqual(superseded.Lifecycle, "superseded");
            testCase.verifyError(@() store.apply(first.GenerationId), ...
                "ProjectionCorrectionStore:invalidLifecycle");
            testCase.verifyError(@() store.apply(second.GenerationId), ...
                "ProjectionCorrectionStore:invalidLifecycle");
            testCase.verifyNotEqual( ...
                ProjectionGeometryFingerprint.scene(thirdScene), ...
                ProjectionGeometryFingerprint.scene(secondScene));

            [restoredSecond, ~] = store.revert(third.GenerationId);
            testCase.verifyEqual( ...
                ProjectionGeometryFingerprint.scene(restoredSecond), ...
                ProjectionGeometryFingerprint.scene(secondScene));
            testCase.verifyEqual(store.current("applied").GenerationId, ...
                second.GenerationId);
            testCase.verifyError(@() store.apply(third.GenerationId), ...
                "ProjectionCorrectionStore:invalidLifecycle");
        end

        function testViewerExposesHeadlessHistoryAndLaunchCallbacks(testCase)
            testCase.assumeTrue(usejava("awt"));
            [scene, correctionSet] = ProjectionCorrectionStoreTest.fixture();
            probe = ProjectionCorrectionCallbackProbe();
            options = struct(InitialGenerationId="base-generation", ...
                CorrectionAcceptedFcn= ...
                @(set) probe.record("accepted", set), ...
                CorrectionAppliedFcn= ...
                @(set) probe.record("applied", set), ...
                CorrectionRevertedFcn= ...
                @(set) probe.record("reverted", set));
            app = ProjectionViewerApp(scene, [], [], options);
            testCase.addTeardown(@() delete(app));

            app.proposeCorrectionSet(correctionSet);
            app.acceptCorrection(correctionSet.GenerationId);
            app.applyCorrection(correctionSet.GenerationId);
            app.revertCorrection(correctionSet.GenerationId);

            testCase.verifyEqual(probe.Events, ...
                ["accepted" "applied" "reverted"]);
            testCase.verifyEqual(numel(app.correctionHistory()), 4);
            testCase.verifyEqual(app.correctionGenerationId(), ...
                "base-generation");
            testCase.verifyFalse( ...
                app.correctionDiagnostics().TransitionInProgress);
        end
    end

    methods (Static, Access = private)
        function [scene, correctionSet] = fixture()
            images = {uint8(ones(8, 9)), uint8(2 * ones(8, 9))};
            scene = ProjectionViewerHarness.createSceneFromImages( ...
                images, ["store-1.tif" "store-2.tif"], ...
                struct(RowStride=2, ColumnStride=2));
            scene.layers(1).ViewId = "store-view-1";
            scene.layers(2).ViewId = "store-view-2";
            scene.layers(1).PassId = "pass-a";
            scene.layers(2).PassId = "pass-a";
            scene.layers(1).ViewVectorAngularOffsetsDegrees = [1; 2; 3];
            scene.layers(2).ViewVectorAngularOffsetsDegrees = [-1; 0.5; 0];
            scene.layers(1).ProjectionOffsetMeters = [0.2; -0.1];
            scene.layers(2).ProjectionOffsetMeters = [-0.2; 0.1];
            scene = ProjectionViewMetadata.ensureScene(scene);
            correctionSet = ProjectionCorrectionStoreTest.makeSet( ...
                scene, "store-generation-001", "base-generation");
        end

        function correctionSet = makeSet(scene, generationId, parentGenerationId)
            result = ProjectionCorrectionStoreTest.result(scene);
            options = struct(GenerationId=generationId, ...
                ParentGenerationId=parentGenerationId, ...
                Lifecycle="proposed", ...
                CreatedAt="2026-07-11T12:00:00.000Z");
            correctionSet = ProjectionCorrectionOpkAdapter.fromAlignmentResult( ...
                scene, result, options);
        end

        function result = result(scene)
            starting = ProjectionCorrectionStoreTest.corrections(scene, false);
            solved = ProjectionCorrectionStoreTest.corrections(scene, true);
            layerIds = string({scene.layers.LayerId});
            result = struct(Status="solved", SolvedCorrections=solved, ...
                Convergence=struct(Status="converged", Success=true, ...
                Iterations=3, FunctionEvaluations=9, ExitFlag=1, ...
                Objective=0.1, FirstOrderOptimality=1e-8, Message="ok"), ...
                Diagnostics=struct(StartingCorrections=starting, ...
                BoundsDegrees=[1 1 1], ...
                AttitudeModel=struct(Model="commonPlusDifferential", ...
                LayerIds=layerIds, CommonDeltaDegrees=[0.1 -0.05 0.02], ...
                DifferentialDeltaDegrees=[0.2 0.1 -0.02; ...
                -0.2 -0.1 0.02], PriorPrecision=ones(2, 3)), ...
                Observability=struct(Solution=struct(ConditionNumber=15))));
            result = ProjectionAlignmentResult.validate(result);
        end

        function corrections = corrections(scene, solved)
            corrections = repmat(struct(LayerIndex=0, LayerId="", ...
                ViewVectorAngularOffsetsDegrees=zeros(1, 3), ...
                ProjectionOffsetMeters=zeros(1, 2), SharedScale=1), 1, 2);
            deltas = [0.3 0.05 0; -0.1 -0.15 0.04];
            offsets = [0.05 -0.02; -0.03 0.04];
            for index = 1:2
                layer = scene.layers(index);
                corrections(index).LayerIndex = index;
                corrections(index).LayerId = string(layer.LayerId);
                corrections(index).ViewVectorAngularOffsetsDegrees = ...
                    double(layer.ViewVectorAngularOffsetsDegrees(:).');
                corrections(index).ProjectionOffsetMeters = ...
                    double(layer.ProjectionOffsetMeters(:).');
                if solved
                    corrections(index).ViewVectorAngularOffsetsDegrees = ...
                        corrections(index).ViewVectorAngularOffsetsDegrees + ...
                        deltas(index, :);
                    corrections(index).ProjectionOffsetMeters = ...
                        corrections(index).ProjectionOffsetMeters + ...
                        offsets(index, :);
                end
            end
        end

        function verifyScopeFingerprints( ...
                testCase, scene, correctionSet, fieldName)
            for index = 1:numel(correctionSet.Views)
                view = correctionSet.Views(index);
                layerIndex = ProjectionViewMetadata.indexForId(scene, view.ViewId);
                testCase.verifyEqual( ...
                    ProjectionGeometryFingerprint.layer(scene.layers(layerIndex)), ...
                    view.(fieldName));
            end
        end
    end
end
