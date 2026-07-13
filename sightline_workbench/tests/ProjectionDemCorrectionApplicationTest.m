classdef ProjectionDemCorrectionApplicationTest < matlab.unittest.TestCase
    %ProjectionDemCorrectionApplicationTest B8 atomic position application.

    methods (TestClassSetup)
        function addPaths(testCase)
            root = fileparts(fileparts(mfilename("fullpath")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(root, "src")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(root, "tests")));
        end
    end

    methods (Test)
        function testBindingUsesLiveScopeAndCorrectedFingerprints(testCase)
            scene = ProjectionDemCorrectionApplicationTest.scene();
            result = ProjectionSurfaceRegistrationFixture.cleanResult();
            correction = ProjectionDemCorrectionAdapter.bind( ...
                scene, result, struct(ParentGenerationId="scene-base"));
            plan = ProjectionDemCorrectionAdapter.applicationPlan(correction);

            testCase.verifyEqual(correction.Lifecycle, "proposed");
            testCase.verifyEqual(correction.ParentGenerationId, "scene-base");
            testCase.verifyEqual(plan.TranslationWorldMeters, ...
                result.Transform.TranslationWorldMeters);
            testCase.verifyEqual(plan.SceneWorldFrame, "sceneWorld");
            testCase.verifyEqual(sort(plan.ScopeViewIds), ...
                ["view-a" "view-b" "view-c"]);
            testCase.verifyFalse(correction.Diagnostics.AutoApply);
            testCase.verifyTrue( ...
                correction.Diagnostics.ExplicitPositionApplyPrepared);
            for view = correction.Views
                index = ProjectionViewMetadata.indexForId(scene, view.ViewId);
                testCase.verifyEqual(view.ParentGeometryFingerprint, ...
                    ProjectionGeometryFingerprint.layer(scene.layers(index)));
                testCase.verifyNotEqual(view.CorrectedGeometryFingerprint, ...
                    view.ParentGeometryFingerprint);
                testCase.verifyEqual(view.IncrementRotationMatrix, eye(3));
            end
        end

        function testApplyTranslatesOriginsAndInvalidatesDependencies(testCase)
            [store, correction, scene, result] = ...
                ProjectionDemCorrectionApplicationTest.store();
            [originBefore, vectorBefore] = ...
                scene.layers(1).SourceGeometry.SampleRayFcn(2.5, 3.5);
            explicitBefore = scene.layers(1).SourceGeometry.Origins;
            store.propose(correction);
            store.accept(correction.GenerationId);
            [appliedScene, applied, effects] = ...
                store.apply(correction.GenerationId);
            [originAfter, vectorAfter] = ...
                appliedScene.layers(1).SourceGeometry.SampleRayFcn(2.5, 3.5);
            explicitAfter = appliedScene.layers(1).SourceGeometry.Origins;

            testCase.verifyEqual(applied.Lifecycle, "applied");
            testCase.verifyEqual(originAfter - originBefore, ...
                result.Transform.TranslationWorldMeters, AbsTol=1e-12);
            testCase.verifyEqual(explicitAfter - explicitBefore, ...
                result.Transform.TranslationWorldMeters .* ...
                ones(1, size(explicitBefore, 2)), AbsTol=1e-12);
            testCase.verifyEqual(vectorAfter, vectorBefore, AbsTol=1e-14);
            testCase.verifyEqual(effects.Kind, "demPositionCorrection");
            testCase.verifyTrue(effects.RecomputeRequired);
            testCase.verifyTrue(all(ismember(["rawMatches" ...
                "alignmentSolve" "denseObservations" "multiRayPoints" ...
                "fusionProducts" "demRegistration"], ...
                effects.InvalidatedProducts)));
            testCase.verifyEqual( ...
                store.diagnostics().LastGeometryEffects, effects);
        end

        function testRevertRestoresExactParentButStillRequiresRecompute(testCase)
            [store, correction, scene] = ...
                ProjectionDemCorrectionApplicationTest.store();
            before = ProjectionGeometryFingerprint.scene(scene);
            store.propose(correction);
            store.accept(correction.GenerationId);
            store.apply(correction.GenerationId);
            [revertedScene, reverted, effects] = ...
                store.revert(correction.GenerationId);

            testCase.verifyEqual(reverted.Lifecycle, "reverted");
            testCase.verifyEqual( ...
                ProjectionGeometryFingerprint.scene(revertedScene), before);
            testCase.verifyEqual(effects.Transition, "revert");
            testCase.verifyTrue(effects.RecomputeRequired);
            testCase.verifyFalse(store.hasCurrent("applied"));
            testCase.verifyEqual(store.currentGenerationId(), "scene-base");
        end

        function testFingerprintFailureIsAtomic(testCase)
            [~, correction, scene] = ...
                ProjectionDemCorrectionApplicationTest.store();
            data = correction.toStruct();
            data.Views(3).CorrectedGeometryFingerprint = ...
                string(repmat('0', 1, 64));
            tampered = ProjectionCorrectionSet.create(data);
            store = ProjectionCorrectionStore(scene, ...
                struct(InitialGenerationId="scene-base"));
            before = ProjectionGeometryFingerprint.scene(scene);
            store.propose(tampered);
            store.accept(tampered.GenerationId);

            testCase.verifyError(@() store.apply(tampered.GenerationId), ...
                "ProjectionCorrectionStore:fingerprintMismatch");
            testCase.verifyEqual( ...
                ProjectionGeometryFingerprint.scene(store.scene()), before);
            testCase.verifyTrue(store.hasCurrent("accepted"));
            testCase.verifyFalse(store.hasCurrent("applied"));
        end

        function testUnboundPreviewAndUnsupportedTermsCannotApply(testCase)
            result = ProjectionSurfaceRegistrationFixture.cleanResult();
            source = ProjectionCorrectionSet.create(result.CorrectionSetData);
            data = source.toStruct();
            data.Blocks(end + 1) = struct(Name="forbidden rotation", ...
                Type="rotationMatrix", Scope="network", ...
                TargetId=data.Geometry.SourcePointSetGenerationId, ...
                Values=eye(3), Units="dimensionless", ...
                Frame="sceneWorld", Semantics="unexpected");
            unsupported = ProjectionCorrectionSet.create(data);

            testCase.verifyError(@() ...
                ProjectionDemCorrectionAdapter.applicationPlan(source), ...
                "ProjectionDemCorrectionAdapter:unboundProposal");
            testCase.verifyError(@() ProjectionDemCorrectionAdapter.bind( ...
                ProjectionDemCorrectionApplicationTest.scene(), ...
                unsupported, struct(ParentGenerationId="scene-base")), ...
                "ProjectionDemCorrectionAdapter:unsupportedBlocks");
        end

        function testFrameScopeAndPassMismatchesFailBeforeMutation(testCase)
            scene = ProjectionDemCorrectionApplicationTest.scene();
            result = ProjectionSurfaceRegistrationFixture.cleanResult();
            frameData = result.CorrectionSetData;
            index = string({frameData.Blocks.Type}) == ...
                "globalPositionTranslation";
            frameData.Blocks(index).Frame = "otherWorld";
            frameResult = result;
            frameResult.CorrectionSetData = frameData;
            missing = scene;
            missing.layers(3) = [];
            passMismatch = scene;
            passMismatch.layers(3).PassId = "pass-other";

            testCase.verifyError(@() ProjectionDemCorrectionAdapter.bind( ...
                scene, frameResult, ...
                struct(ParentGenerationId="scene-base")), ...
                "ProjectionDemCorrectionAdapter:frameMismatch");
            testCase.verifyError(@() ProjectionDemCorrectionAdapter.bind( ...
                missing, result, struct(ParentGenerationId="scene-base")), ...
                "ProjectionDemCorrectionAdapter:missingView");
            testCase.verifyError(@() ProjectionDemCorrectionAdapter.bind( ...
                passMismatch, result, ...
                struct(ParentGenerationId="scene-base")), ...
                "ProjectionDemCorrectionAdapter:passMismatch");
        end

        function testAmbiguityRequiresSeparateExplicitOverride(testCase)
            scene = ProjectionDemCorrectionApplicationTest.scene();
            ambiguous = ProjectionSurfaceRegistrationService.run( ...
                ProjectionSurfaceRegistrationFixture.flatRequest());

            testCase.verifyError(@() ProjectionDemCorrectionAdapter.bind( ...
                scene, ambiguous, struct(ParentGenerationId="scene-base")), ...
                "ProjectionDemCorrectionAdapter:ambiguousRegistration");
            correction = ProjectionDemCorrectionAdapter.bind(scene, ambiguous, ...
                struct(ParentGenerationId="scene-base", ...
                AllowAmbiguous=true));
            testCase.verifyEqual( ...
                correction.Diagnostics.RegistrationStatus, "ambiguous");
            testCase.verifyTrue(correction.Diagnostics.AllowAmbiguous);
        end

        function testOriginTranslatorUpdatesAliasesAndFailsClosed(testCase)
            scene = ProjectionDemCorrectionApplicationTest.scene();
            source = scene.layers(1).SourceGeometry;
            source.ViewVectorOrigins = source.Origins;
            source.G0 = source.ReferenceOrigin;
            source.Metadata.ReferenceOrigin = source.ReferenceOrigin;
            source.GeometryRevisionToken = ...
                ProjectionGeometryFingerprint.deriveSourceRevision(source);
            translation = [4; -3; 2];
            shifted = ProjectionSourceGeometry.translateOrigins( ...
                source, translation);
            unsupported = struct(Foo=1);
            unsupported.GeometryRevisionToken = ...
                ProjectionGeometryFingerprint.deriveSourceRevision(unsupported);

            testCase.verifyEqual(shifted.Origins - source.Origins, ...
                translation .* ones(1, size(source.Origins, 2)), ...
                AbsTol=1e-14);
            testCase.verifyEqual( ...
                shifted.ViewVectorOrigins - source.ViewVectorOrigins, ...
                translation .* ones(1, size(source.ViewVectorOrigins, 2)), ...
                AbsTol=1e-14);
            testCase.verifyEqual(shifted.G0 - source.G0, translation);
            testCase.verifyEqual(shifted.Metadata.ReferenceOrigin - ...
                source.Metadata.ReferenceOrigin, translation);
            testCase.verifyNotEqual(shifted.GeometryRevisionToken, ...
                source.GeometryRevisionToken);
            testCase.verifyError(@() ...
                ProjectionSourceGeometry.translateOrigins( ...
                unsupported, translation), ...
                "ProjectionSourceGeometry:unsupportedPositionCorrection");
        end
    end

    methods (Static)
        function scene = scene()
            images = {uint8(ones(8, 9)), uint8(2 * ones(8, 9)), ...
                uint8(3 * ones(8, 9))};
            scene = ProjectionViewerHarness.createSceneFromImages( ...
                images, ["dem-a.tif" "dem-b.tif" "dem-c.tif"], ...
                struct(RowStride=2, ColumnStride=2, ...
                CoordinateFrame="sceneWorld"));
            viewIds = ["view-a" "view-b" "view-c"];
            passIds = ["pass-1" "pass-1" "pass-2"];
            for index = 1:3
                scene.layers(index).ViewId = viewIds(index);
                scene.layers(index).PassId = passIds(index);
            end
            scene = ProjectionViewMetadata.ensureScene(scene);
        end
    end

    methods (Static, Access = private)
        function [store, correction, scene, result] = store()
            scene = ProjectionDemCorrectionApplicationTest.scene();
            result = ProjectionSurfaceRegistrationFixture.cleanResult();
            correction = ProjectionDemCorrectionAdapter.bind( ...
                scene, result, struct(ParentGenerationId="scene-base"));
            store = ProjectionCorrectionStore(scene, ...
                struct(InitialGenerationId="scene-base"));
        end
    end
end
