classdef ProjectionViewerDemCorrectionWorkflowTest < matlab.unittest.TestCase
    %ProjectionViewerDemCorrectionWorkflowTest B8 viewer invalidation.

    methods (TestClassSetup)
        function addPaths(testCase)
            root = fileparts(fileparts(mfilename("fullpath")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(root));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(root, "src")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(root, "tests")));
        end
    end

    methods (TestMethodSetup)
        function closeFigures(testCase)
            ProjectionViewerDemCorrectionWorkflowTest.closeAll();
            testCase.addTeardown(@() ...
                ProjectionViewerDemCorrectionWorkflowTest.closeAll());
        end
    end

    methods (Test)
        function testExplicitApplyInvalidatesViewerEvidenceAndRevertIsExact(testCase)
            testCase.assumeTrue(usejava("awt"));
            scene = ProjectionViewerDemCorrectionWorkflowTest.texturedScene();
            result = ProjectionSurfaceRegistrationFixture.cleanResult();
            app = ProjectionViewerApp(scene, [], [], ...
                struct(InitialGenerationId="scene-base"));
            testCase.addTeardown(@() delete(app));
            drawnow
            figure = ProjectionViewerDemCorrectionWorkflowTest. ...
                openAlignmentWorkbench();
            matchButton = findall(figure, "Tag", ...
                "ProjectionViewerAlignmentMatchButton");
            matchButton(1).ButtonPushedFcn(matchButton(1), struct());
            drawnow
            testCase.verifyEqual( ...
                app.alignmentDiagnostics().Stage.Session.Stage, "matched");

            proposed = app.proposeDemCorrection(result);
            app.acceptCorrection(proposed.GenerationId);
            testCase.verifyEqual( ...
                app.alignmentDiagnostics().Stage.Session.Stage, "matched");
            app.applyCorrection(proposed.GenerationId);
            afterApply = app.alignmentDiagnostics().Stage;
            effects = app.correctionDiagnostics().LastGeometryEffects;

            testCase.verifyEqual(afterApply.Session.Stage, "setup");
            testCase.verifyFalse(afterApply.HasRawMatches);
            testCase.verifyEqual(afterApply.DenseSurface.Status, "invalidated");
            testCase.verifyTrue(afterApply.DenseSurface.RecomputeRequired);
            testCase.verifyEqual(effects.Kind, "demPositionCorrection");
            testCase.verifyTrue(effects.RecomputeRequired);

            app.revertCorrection(proposed.GenerationId);
            testCase.verifyEmpty(app.currentCorrection("applied"));
            history = app.correctionHistory(proposed.GenerationId);
            testCase.verifyEqual(string({history.Lifecycle}), ...
                ["proposed" "accepted" "applied" "reverted"]);
            testCase.verifyEqual(app.correctionGenerationId(), "scene-base");
            testCase.verifyEqual( ...
                app.correctionDiagnostics().LastGeometryEffects.Transition, ...
                "revert");
        end
    end

    methods (Static, Access = private)
        function scene = texturedScene()
            [x, y] = meshgrid(1:48, 1:48);
            image = uint8(mod(3 * x + 5 * y + 30 * sin(x / 3), 256));
            scene = ProjectionViewerHarness.createSceneFromImages( ...
                {image image image}, ["a.tif" "b.tif" "c.tif"], ...
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

        function figure = openAlignmentWorkbench()
            figure = findall(groot, "Type", "figure", ...
                "Name", "Sightline Workbench");
            menu = findall(figure(1), "Tag", ...
                "ProjectionViewerAlignmentPanelMenuItem");
            menu(1).MenuSelectedFcn(menu(1), struct());
            drawnow
            launcher = findall(figure(1), "Tag", ...
                "ProjectionViewerAlignmentOpenWorkbenchButton");
            launcher(1).ButtonPushedFcn(launcher(1), struct());
            drawnow
            figure = findall(groot, "Type", "figure", ...
                "Name", "Alignment Workbench");
            figure = figure(1);
        end

        function closeAll()
            names = ["Sightline Workbench" "Alignment Workbench"];
            for name = names
                delete(findall(groot, "Type", "figure", "Name", name));
            end
        end
    end
end
