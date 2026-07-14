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
                workbench, "ProjectionViewerAlignmentSoloPairCheckBox"), ...
                ProjectionViewerActivePairWorkflowTest.findTagged( ...
                workbench, "ProjectionViewerAlignmentPairViewButton"), ...
                ProjectionViewerActivePairWorkflowTest.findTagged( ...
                workbench, "ProjectionViewerAlignmentRestoreViewButton"), ...
                ProjectionViewerActivePairWorkflowTest.findTagged( ...
                workbench, "ProjectionViewerAlignmentSwapEyesButton"), ...
                ProjectionViewerActivePairWorkflowTest.findTagged( ...
                workbench, "ProjectionViewerAlignmentResetEyesButton")];

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

        function testSoloPairTurnoverReconcilesCurrentLodWithoutBlank(testCase)
            app = ProjectionViewerApp( ...
                ProjectionViewerActivePairWorkflowTest.makeTiledScene());
            testCase.addTeardown(@() delete(app));
            viewer = findall(groot, "Type", "figure", ...
                "Name", "Sightline");
            viewer.Position = [100 100 360 300];
            drawnow
            app.configurePreviewTiling(struct(TileSize=64, ...
                MinTiledImagePixels=1, MaxVisibleTilesPerLayer=96));
            workbench = ProjectionViewerActivePairWorkflowTest.showWorkbench();
            solo = ProjectionViewerActivePairWorkflowTest.findTagged( ...
                workbench, "ProjectionViewerAlignmentSoloPairCheckBox");
            next = ProjectionViewerActivePairWorkflowTest.findTagged( ...
                workbench, "ProjectionViewerAlignmentNextPairButton");
            testCase.press(solo);
            firstPair = app.alignmentDiagnostics().ActivePair;
            firstIndices = [firstPair.ReferenceLayerIndex ...
                firstPair.MovingLayerIndex];
            axesHandle = findall(viewer, "Type", "axes");
            viewer.CurrentObject = axesHandle;
            position = axesHandle.InnerPosition;
            viewer.CurrentPoint = position(1:2) + position(3:4) / 2;
            for index = 1:16
                viewer.WindowScrollWheelFcn( ...
                    viewer, struct(VerticalScrollCount=-1));
            end
            app.flushPreviewUpdates();
            beforeTurnover = app.performanceDiagnostics();
            outsideIndices = setdiff(1:4, firstIndices);
            testCase.verifyTrue(any( ...
                beforeTurnover.Viewer.CurrentLevelIndices(outsideIndices) ~= ...
                beforeTurnover.Viewer.CurrentLevelIndices(firstIndices(1))));

            testCase.press(next);
            afterTurnover = app.performanceDiagnostics();
            secondPair = app.alignmentDiagnostics().ActivePair;
            secondIndices = [secondPair.ReferenceLayerIndex ...
                secondPair.MovingLayerIndex];
            incomingIndices = setdiff(secondIndices, firstIndices);

            testCase.verifyNotEqual(secondPair.PairId, firstPair.PairId);
            testCase.verifyEqual( ...
                afterTurnover.Viewer.CurrentLevelIndices(secondIndices), ...
                repmat(afterTurnover.Viewer.CurrentLevelIndices( ...
                secondIndices(1)), 1, 2));
            testCase.verifyEqual( ...
                afterTurnover.Viewer.PendingLevelIndices(secondIndices), ...
                [0 0]);
            testCase.verifyNotEqual( ...
                afterTurnover.Viewer.CurrentLevelIndices(incomingIndices), ...
                beforeTurnover.Viewer.CurrentLevelIndices(incomingIndices));
            testCase.verifyGreaterThan( ...
                afterTurnover.Viewer.VisibleTileSurfaceCount, 0);
            testCase.verifyEqual( ...
                afterTurnover.Counters.BlankPreviewTransitions, 0);

            workbench.CloseRequestFcn(workbench, struct());
            restored = app.performanceDiagnostics();
            testCase.verifyEqual(restored.Viewer.CurrentLevelIndices, ...
                repmat(restored.Viewer.CurrentLevelIndices(1), 1, 4));
            testCase.verifyEqual(restored.Viewer.PendingLevelIndices, ...
                zeros(1, 4));
            testCase.verifyEqual( ...
                restored.Counters.BlankPreviewTransitions, 0);
        end

        function testPairViewpointAppliesAndRestoresCameraOnly(testCase)
            [app, workbench] = ...
                ProjectionViewerActivePairWorkflowTest.openWorkbench();
            testCase.addTeardown(@() delete(app));
            pairView = ProjectionViewerActivePairWorkflowTest.findTagged( ...
                workbench, "ProjectionViewerAlignmentPairViewButton");
            restore = ProjectionViewerActivePairWorkflowTest.findTagged( ...
                workbench, "ProjectionViewerAlignmentRestoreViewButton");
            before = app.exportState();

            testCase.verifyEmpty(findall(workbench, "Tag", ...
                "ProjectionViewerAlignmentFollowPairCheckBox"));
            testCase.press(pairView);
            drawnow

            after = app.exportState();
            diagnostics = app.alignmentDiagnostics().PairViewpoint;
            testCase.verifyTrue(diagnostics.Available);
            testCase.verifyTrue(diagnostics.RestoreAvailable);
            testCase.verifyNotEqual(after.Camera.Position, ...
                before.Camera.Position);
            testCase.verifyEqual(after.Camera.Position - after.Camera.Target, ...
                (diagnostics.Plan.Camera.PositionWorld - ...
                diagnostics.Plan.Camera.TargetWorld).', AbsTol=1e-8);
            testCase.verifyEqual(after.Camera.UpVector, ...
                diagnostics.Plan.Camera.UpVector.', AbsTol=1e-10);
            testCase.verifyEqual(after.Camera.ViewAngle, ...
                diagnostics.Plan.Camera.ViewAngle, AbsTol=1e-10);
            testCase.verifyEqual(after.Projection, before.Projection);
            testCase.verifyEqual(after.View, before.View);
            testCase.verifyEqual(after.Layers, before.Layers);

            testCase.press(restore);
            drawnow

            restored = app.exportState();
            testCase.verifyEqual(restored.Camera, before.Camera, AbsTol=1e-10);
            testCase.verifyFalse( ...
                app.alignmentDiagnostics().PairViewpoint.RestoreAvailable);
        end

        function testPairTrackingOwnershipMovedToLayerManager(testCase)
            [app, workbench] = ...
                ProjectionViewerActivePairWorkflowTest.openWorkbench();
            testCase.addTeardown(@() delete(app));
            manager = findall(groot, "Tag", ...
                "ProjectionViewerLayerManagerFigure");

            testCase.verifyEmpty(findall(workbench, "Tag", ...
                "ProjectionViewerAlignmentFollowPairCheckBox"));
            testCase.verifyNumElements(findall(manager, "Tag", ...
                "ProjectionViewerLayerManagerTrackCameraCheckBox"), 1);
            testCase.verifyFalse( ...
                app.alignmentDiagnostics().PairViewpoint.FollowEnabled);
        end

        function testUnavailablePairViewpointIsDisabledWithExplanation(testCase)
            scene = ProjectionViewerActivePairWorkflowTest.makeScene();
            scene.layers(4).ProjectionOffsetMeters = [1e6; 0];
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            workbench = ProjectionViewerActivePairWorkflowTest.showWorkbench();
            pairView = ProjectionViewerActivePairWorkflowTest.findTagged( ...
                workbench, "ProjectionViewerAlignmentPairViewButton");

            testCase.verifyEqual(pairView.Enable, ...
                matlab.lang.OnOffSwitchState.off);
            testCase.verifyEmpty(findall(workbench, "Tag", ...
                "ProjectionViewerAlignmentFollowPairCheckBox"));
            testCase.verifyNotEmpty(pairView.Tooltip);
            testCase.verifySubstring(string(pairView.Tooltip), ...
                "no usable shared");
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
                "Name", "Sightline");
            menuItem = findall(viewer(1), "Tag", ...
                "ProjectionViewerAlignmentPanelMenuItem");
            menuItem.MenuSelectedFcn(menuItem, struct());
            drawnow
            workbench = findall(groot, "Type", "figure", ...
                "Name", "Alignment Workbench");
            workbench = workbench(1);
        end

        function component = findTagged(parent, tag)
            component = findall(parent, "Tag", tag);
            component = component(1);
        end

        function slider = twistSlider(viewer)
            sliders = findall(viewer, "Type", "uislider");
            isTwist = false(size(sliders));
            for index = 1:numel(sliders)
                isTwist(index) = isequal(sliders(index).Layout.Column, 4);
            end
            slider = sliders(find(isTwist, 1, "first"));
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

        function scene = makeTiledScene()
            images = cell(1, 4);
            paths = strings(1, 4);
            for layerIndex = 1:4
                images{layerIndex} = uint8( ...
                    (layerIndex - 1) * ones(512, 512));
                paths(layerIndex) = "pair-lod-" + ...
                    string(layerIndex) + ".tif";
            end
            scene = ProjectionViewerHarness.createSceneFromImages( ...
                images, paths, struct(RowStride=32, ColumnStride=32));
            for layerIndex = 1:4
                scene.layers(layerIndex).ViewId = ...
                    "pair-lod-view-" + string(layerIndex);
                scene.layers(layerIndex).PassId = "pair-lod-pass";
                scene.layers(layerIndex).AcquisitionStartTime = layerIndex;
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
                "Name", "Sightline"));
        end
    end
end
