classdef ProjectionViewerActivePairWorkflowTest < matlab.uitest.TestCase
    %ProjectionViewerActivePairWorkflowTest Tests MI-2 Workbench controls.

    methods (TestClassSetup)
        function addSourceToPath(testCase)
            projectRoot = fileparts(fileparts(mfilename("fullpath")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(projectRoot, "src")));
        end
    end

    methods (TestMethodSetup)
        function closeExistingFigures(testCase)
            ProjectionViewerActivePairWorkflowTest.closeFigures();
            testCase.addTeardown( ...
                @ProjectionViewerActivePairWorkflowTest.closeFigures);
        end
    end

    methods (Test)
        function testActivePairBarUsesCompactResponsiveRows(testCase)
            [app, workbench] = ...
                ProjectionViewerActivePairWorkflowTest.openWorkbench();
            testCase.addTeardown(@() delete(app));
            activePanel = ProjectionViewerActivePairWorkflowTest.findTagged( ...
                workbench, "ProjectionViewerAlignmentActivePairPanel");
            setupPanel = ProjectionViewerActivePairWorkflowTest.findTagged( ...
                workbench, "ProjectionViewerAlignmentSetupPanel");
            workflowPanel = ProjectionViewerActivePairWorkflowTest.findTagged( ...
                workbench, "ProjectionViewerAlignmentWorkflowPanel");
            controls = [ ...
                ProjectionViewerActivePairWorkflowTest.findTagged( ...
                workbench, "ProjectionViewerAlignmentPreviousPairButton"), ...
                ProjectionViewerActivePairWorkflowTest.findTagged( ...
                workbench, "ProjectionViewerAlignmentReferenceDropDown"), ...
                ProjectionViewerActivePairWorkflowTest.findTagged( ...
                workbench, "ProjectionViewerAlignmentMovingDropDown"), ...
                ProjectionViewerActivePairWorkflowTest.findTagged( ...
                workbench, "ProjectionViewerAlignmentSwapPairButton"), ...
                ProjectionViewerActivePairWorkflowTest.findTagged( ...
                workbench, "ProjectionViewerAlignmentNextPairButton"), ...
                ProjectionViewerActivePairWorkflowTest.findTagged( ...
                workbench, "ProjectionViewerAlignmentPairEnabledCheckBox"), ...
                ProjectionViewerActivePairWorkflowTest.findTagged( ...
                workbench, "ProjectionViewerAlignmentSoloPairCheckBox")];

            testCase.verifyEqual(activePanel.Layout.Row, 2);
            testCase.verifyEqual(setupPanel.Layout.Row, 3);
            testCase.verifyEqual(workflowPanel.Layout.Row, 4);
            testCase.verifyTrue(all(arrayfun( ...
                @(control) control.Parent == controls(1).Parent, controls)));
            for sizePixels = [1000 700; 1400 900].'
                workbench.Position(3:4) = sizePixels.';
                drawnow
                testCase.verifyTrue(all(arrayfun( ...
                    @(control) all(control.Position(3:4) > 0), controls)));
            end
        end

        function testNavigationDoesNotRunAlignmentOrRebuildRendering(testCase)
            [app, workbench] = ...
                ProjectionViewerActivePairWorkflowTest.openWorkbench();
            testCase.addTeardown(@() delete(app));
            swapButton = ProjectionViewerActivePairWorkflowTest.findTagged( ...
                workbench, "ProjectionViewerAlignmentSwapPairButton");
            nextButton = ProjectionViewerActivePairWorkflowTest.findTagged( ...
                workbench, "ProjectionViewerAlignmentNextPairButton");
            before = app.alignmentDiagnostics();
            stateBefore = app.exportState();
            app.resetPerformanceDiagnostics();

            testCase.press(swapButton);
            testCase.press(nextButton);
            drawnow

            after = app.alignmentDiagnostics();
            performance = app.performanceDiagnostics();
            stateAfter = app.exportState();
            testCase.verifyNotEqual(after.ActivePair.PairId, ...
                before.ActivePair.PairId);
            testCase.verifyEqual(after.Stage, before.Stage);
            testCase.verifyEqual( ...
                ProjectionViewerActivePairWorkflowTest.corrections(stateAfter), ...
                ProjectionViewerActivePairWorkflowTest.corrections(stateBefore));
            testCase.verifyEqual( ...
                performance.Counters.LayerGeometryRefreshes, 0);
            testCase.verifyEqual(performance.Counters.SampleFcnCalls, 0);
            testCase.verifyEqual(performance.Counters.SurfaceCreations, 0);
        end

        function testSameViewIsRejectedWithoutChangingActivePair(testCase)
            [app, workbench] = ...
                ProjectionViewerActivePairWorkflowTest.openWorkbench();
            testCase.addTeardown(@() delete(app));
            reference = ProjectionViewerActivePairWorkflowTest.findTagged( ...
                workbench, "ProjectionViewerAlignmentReferenceDropDown");
            moving = ProjectionViewerActivePairWorkflowTest.findTagged( ...
                workbench, "ProjectionViewerAlignmentMovingDropDown");
            before = app.alignmentDiagnostics().ActivePair;

            moving.Value = reference.Value;
            moving.ValueChangedFcn(moving, struct());
            drawnow

            after = app.alignmentDiagnostics().ActivePair;
            testCase.verifyEqual(after.PairId, before.PairId);
            testCase.verifyNotEqual(reference.Value, moving.Value);
        end

        function testPairEnabledStateControlsSelectedMatchSchedule(testCase)
            [app, workbench] = ...
                ProjectionViewerActivePairWorkflowTest.openWorkbench();
            testCase.addTeardown(@() delete(app));
            enabledButton = ...
                ProjectionViewerActivePairWorkflowTest.findTagged( ...
                workbench, "ProjectionViewerAlignmentPairEnabledCheckBox");

            testCase.press(enabledButton);
            drawnow

            diagnostics = app.alignmentDiagnostics();
            testCase.verifyFalse(diagnostics.ActivePair.Enabled);
            testCase.verifyEqual(diagnostics.EnabledPairCount, 0);
        end

        function testSoloFollowsPairAndRestoresVisibilityOnClose(testCase)
            scene = ProjectionViewerActivePairWorkflowTest.makeScene();
            scene.layers(2).Visible = false;
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            workbench = ProjectionViewerActivePairWorkflowTest.showWorkbench();
            solo = ProjectionViewerActivePairWorkflowTest.findTagged( ...
                workbench, "ProjectionViewerAlignmentSoloPairCheckBox");
            nextButton = ProjectionViewerActivePairWorkflowTest.findTagged( ...
                workbench, "ProjectionViewerAlignmentNextPairButton");
            visibleBefore = [app.exportState().Layers.Visible];

            testCase.press(solo);
            firstSolo = app.alignmentDiagnostics();
            testCase.verifyTrue(firstSolo.SoloPairActive);
            testCase.verifyEqual(nnz(firstSolo.EffectiveLayerVisibility), 2);
            app.resetPerformanceDiagnostics();
            testCase.press(nextButton);
            secondSolo = app.alignmentDiagnostics();
            performance = app.performanceDiagnostics();
            testCase.verifyNotEqual(secondSolo.ActivePair.PairId, ...
                firstSolo.ActivePair.PairId);
            expectedMask = false(1, 4);
            expectedMask([secondSolo.ActivePair.ReferenceLayerIndex ...
                secondSolo.ActivePair.MovingLayerIndex]) = true;
            testCase.verifyEqual( ...
                secondSolo.EffectiveLayerVisibility, expectedMask);
            testCase.verifyEqual( ...
                performance.Counters.LayerGeometryRefreshes, 0);
            testCase.verifyEqual(performance.Counters.SampleFcnCalls, 0);
            testCase.verifyEqual(performance.Counters.SurfaceCreations, 0);

            workbench.CloseRequestFcn(workbench, struct());
            drawnow
            restored = app.alignmentDiagnostics();
            testCase.verifyFalse(restored.SoloPairActive);
            testCase.verifyEqual([app.exportState().Layers.Visible], ...
                visibleBefore);
        end
    end

    methods (Static, Access = private)
        function [app, workbench] = openWorkbench()
            app = ProjectionViewerApp( ...
                ProjectionViewerActivePairWorkflowTest.makeScene());
            drawnow
            workbench = ProjectionViewerActivePairWorkflowTest.showWorkbench();
        end

        function workbench = showWorkbench()
            viewer = findall(groot, "Type", "figure", ...
                "Name", "Sightline Workbench");
            menuItem = findall(viewer(1), "Tag", ...
                "ProjectionViewerAlignmentPanelMenuItem");
            menuItem.MenuSelectedFcn(menuItem, struct());
            drawnow
            launcher = findall(viewer(1), "Tag", ...
                "ProjectionViewerAlignmentOpenWorkbenchButton");
            launcher.ButtonPushedFcn(launcher, struct());
            drawnow
            workbench = findall(groot, "Type", "figure", ...
                "Name", "Alignment Workbench");
            workbench = workbench(1);
        end

        function component = findTagged(parent, tag)
            component = findall(parent, "Tag", tag);
            component = component(1);
        end

        function scene = makeScene()
            images = cell(1, 4);
            paths = strings(1, 4);
            for layerIndex = 1:4
                [x, y] = meshgrid(1:24, 1:20);
                images{layerIndex} = uint8(mod( ...
                    7 * x + 11 * y + layerIndex, 255));
                paths(layerIndex) = "active-pair-" + ...
                    string(layerIndex) + ".tif";
            end
            scene = ProjectionViewerHarness.createSceneFromImages( ...
                images, paths, struct(RowStride=4, ColumnStride=4));
            for layerIndex = 1:4
                scene.layers(layerIndex).ViewId = ...
                    "view-" + string(char('a' + layerIndex - 1));
                scene.layers(layerIndex).PassId = "pass-one";
                scene.layers(layerIndex).AcquisitionStartTime = layerIndex - 1;
                scene.layers(layerIndex).LineRateHz = 1;
            end
            scene = ProjectionViewMetadata.ensureScene(scene);
        end

        function values = corrections(state)
            values = [[state.Layers.ProjectionOffsetMeters].'; ...
                [state.Layers.ViewVectorAngularOffsetsDegrees].'];
        end

        function closeFigures()
            delete(findall(groot, "Type", "figure", ...
                "Name", "Alignment Workbench"));
            delete(findall(groot, "Type", "figure", ...
                "Name", "Sightline Workbench"));
        end
    end
end
