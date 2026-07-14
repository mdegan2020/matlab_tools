classdef ProjectionViewerAppInteractionTest < matlab.unittest.TestCase
    %ProjectionViewerAppInteractionTest Tests for programmatic viewer callbacks.

    properties (Constant)
        Tol = 1e-10
    end

    methods (TestClassSetup)
        function addSourceToPath(testCase)
            projectRoot = fileparts(fileparts(mfilename("fullpath")));
            srcFolder = fullfile(projectRoot, "src");
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(projectRoot));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(srcFolder));
        end
    end

    methods (TestMethodSetup)
        function closeExistingViewer(testCase)
            ProjectionViewerAppInteractionTest.closeOwnedWindowsAndTimers();
            testCase.addTeardown( ...
                @ProjectionViewerAppInteractionTest.closeOwnedWindowsAndTimers);
        end
    end

    methods (Test)
        function testRd4ShellOpensManagerAndWorkbenchDirectly(testCase)
            app = ProjectionViewerApp( ...
                ProjectionViewerAppInteractionTest.makeTwoImageScene());
            testCase.addTeardown(@() delete(app));
            drawnow

            viewer = findall(groot, "Type", "figure", ...
                "Name", "Sightline");
            manager = findall(groot, "Tag", ...
                "ProjectionViewerLayerManagerFigure");
            alignmentMenu = ProjectionViewerAppInteractionTest.findMenuItem( ...
                "ProjectionViewerAlignmentPanelMenuItem");

            testCase.verifyNumElements(manager, 1);
            testCase.verifyEqual(string(viewer.Name), "Sightline");
            testCase.verifyEqual(string(manager.Name), "Layer Manager");
            mode = findall(manager, "Tag", ...
                "ProjectionViewerLayerManagerModeDropDown");
            testCase.verifyEqual(string(mode.Value), "viewAll");
            testCase.verifyEqual(string(alignmentMenu.Text), ...
                "Alignment Workbench...");
            testCase.verifyEmpty(findall(viewer, "Tag", ...
                "ProjectionViewerAlignmentGrid"));
            testCase.verifyEmpty(findall(viewer, "Tag", ...
                "ProjectionViewerLayerManagerLayerDropDown"));
            testCase.verifyEmpty(findall(viewer, "Tag", ...
                "ProjectionViewerLayerManagerVisibleCheckBox"));
            sliders = findall(viewer, "-isa", ...
                "matlab.ui.control.Slider");
            testCase.verifyNumElements(sliders, 4);
            testCase.verifyEqual(sliders(1).Parent.RowHeight, ...
                {'fit', 'fit'});
            overlay = findall(viewer, "Tag", ...
                "ProjectionViewerViewVectorOverlay");
            testCase.verifyEqual(overlay.Parent, viewer);
            testCase.verifyEqual(string(overlay.Enable), "off");

            managerMenu = ProjectionViewerAppInteractionTest.findMenuItem( ...
                "ProjectionViewerLayerManagerMenuItem");
            managerMenu.MenuSelectedFcn(managerMenu, struct());
            drawnow
            testCase.verifyEqual(findall(groot, "Tag", ...
                "ProjectionViewerLayerManagerFigure"), manager);

            alignmentMenu.MenuSelectedFcn(alignmentMenu, struct());
            drawnow
            testCase.verifyNumElements(findall(groot, "Name", ...
                "Alignment Workbench"), 1);
            testCase.verifyEmpty(findall(viewer, "Tag", ...
                "ProjectionViewerAlignmentOpenWorkbenchButton"));
        end

        function testImageAxesDecorationsAreHidden(testCase)
            scene = ProjectionViewerAppInteractionTest.makeScene();
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow

            fig = findall(groot, "Type", "figure", ...
                "Name", "Sightline");
            ax = findall(fig, "Type", "axes");

            testCase.verifyEqual(string(ax.Title.String), "");
            testCase.verifyEqual(string(ax.XLabel.String), "");
            testCase.verifyEqual(string(ax.YLabel.String), "");
            testCase.verifyEqual(string(ax.ZLabel.String), "");
            testCase.verifyEmpty(ax.XTick);
            testCase.verifyEmpty(ax.YTick);
            testCase.verifyEmpty(ax.ZTick);
            testCase.verifyEqual(string(ax.Box), "off");
            testCase.verifyEqual(string(ax.Visible), "off");
        end

        function testImageContextMenuContainsViewerCommands(testCase)
            scene = ProjectionViewerAppInteractionTest.makeScene();
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow

            fig = findall(groot, "Type", "figure", ...
                "Name", "Sightline");
            ax = findall(fig, "Type", "axes");
            surfaceHandle = findall(ax, "Type", "surface");
            saveMenu = ProjectionViewerAppInteractionTest.findMenuItem( ...
                "ProjectionViewerSaveMenuItem");
            loadMenu = ProjectionViewerAppInteractionTest.findMenuItem( ...
                "ProjectionViewerLoadMenuItem");
            cycleMenu = ProjectionViewerAppInteractionTest.findMenuItem( ...
                "ProjectionViewerCycleMenuItem");
            resetMenu = ProjectionViewerAppInteractionTest.findMenuItem( ...
                "ProjectionViewerResetMenuItem");
            helpMenu = ProjectionViewerAppInteractionTest.findMenuItem( ...
                "ProjectionViewerHelpMenuItem");
            crosshairMenu = ProjectionViewerAppInteractionTest.findMenuItem( ...
                "ProjectionViewerCrosshairMenuItem");
            outlineMenu = ProjectionViewerAppInteractionTest.findMenuItem( ...
                "ProjectionViewerActiveLayerOutlineMenuItem");
            invertUpMenu = ProjectionViewerAppInteractionTest.findMenuItem( ...
                "ProjectionViewerInvertCameraUpMenuItem");
            alignmentPanelMenu = ProjectionViewerAppInteractionTest.findMenuItem( ...
                "ProjectionViewerAlignmentPanelMenuItem");
            blendMenu = ProjectionViewerAppInteractionTest.findMenuItem( ...
                "ProjectionViewerBlendModeMenu");
            alphaBlendMenu = ProjectionViewerAppInteractionTest.findMenuItem( ...
                "ProjectionViewerAlphaBlendMenuItem");
            anaglyphBlendMenu = ProjectionViewerAppInteractionTest.findMenuItem( ...
                "ProjectionViewerAnaglyphBlendMenuItem");

            testCase.verifyEqual( ...
                [string(saveMenu.Text) string(loadMenu.Text) ...
                string(cycleMenu.Text) string(resetMenu.Text) ...
                string(helpMenu.Text) string(crosshairMenu.Text) ...
                string(alignmentPanelMenu.Text) string(blendMenu.Text)], ...
                ["Save" "Load" "Cycle" "Reset" "Help" "Crosshair" ...
                "Alignment Workbench..." "Blend mode"]);
            testCase.verifyEqual(ax.ContextMenu, saveMenu.Parent);
            testCase.verifyEqual(surfaceHandle(1).ContextMenu, saveMenu.Parent);
            testCase.verifyEmpty(ProjectionViewerAppInteractionTest.findButton(fig, "Save"));
            testCase.verifyEmpty(ProjectionViewerAppInteractionTest.findButton(fig, "Load"));
            testCase.verifyEmpty(ProjectionViewerAppInteractionTest.findButton(fig, "Cycle"));
            testCase.verifyEmpty(ProjectionViewerAppInteractionTest.findButton(fig, "Reset"));
            testCase.verifyEqual(string(crosshairMenu.Checked), "off");
            testCase.verifyEqual(string(outlineMenu.Text), ...
                "Active layer outline");
            testCase.verifyEqual(string(outlineMenu.Checked), "on");
            testCase.verifyEqual(string(invertUpMenu.Text), ...
                "Invert desired up and reset camera");
            testCase.verifyEqual(string(invertUpMenu.Checked), "off");
            testCase.verifyEqual(string(alignmentPanelMenu.Checked), "off");
            testCase.verifyEqual(alphaBlendMenu.Parent, blendMenu);
            testCase.verifyEqual(anaglyphBlendMenu.Parent, blendMenu);
            testCase.verifyEqual(string(alphaBlendMenu.Checked), "on");
            testCase.verifyEqual(string(anaglyphBlendMenu.Checked), "off");
        end

        function testInvertDesiredUpResetsCameraWithoutScientificMutation(testCase)
            app = ProjectionViewerApp( ...
                ProjectionViewerAppInteractionTest.makeTwoImageScene());
            testCase.addTeardown(@() delete(app));
            drawnow

            fig = findall(groot, "Type", "figure", "Name", "Sightline");
            ax = findall(fig, "Type", "axes");
            invertUpMenu = ProjectionViewerAppInteractionTest.findMenuItem( ...
                "ProjectionViewerInvertCameraUpMenuItem");
            initialState = app.exportState();
            initialUp = initialState.Camera.UpVector / ...
                norm(initialState.Camera.UpVector);
            ax.CameraPosition = ax.CameraPosition + [13 -7 5];
            ax.CameraTarget = ax.CameraTarget + [2 3 -4];

            invertUpMenu.MenuSelectedFcn(invertUpMenu, struct());
            drawnow
            invertedState = app.exportState();
            invertedUp = invertedState.Camera.UpVector / ...
                norm(invertedState.Camera.UpVector);

            testCase.verifyEqual(string(invertUpMenu.Checked), "on");
            testCase.verifyEqual(dot(invertedUp, initialUp), -1, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyEqual(invertedState.View.TwistDegrees, 0);
            testCase.verifyEqual(invertedState.Layers, initialState.Layers);
            testCase.verifyEqual(invertedState.Projection, ...
                initialState.Projection);
            testCase.verifyFalse(isfield(invertedState, "CameraUpInverted"));

            invertUpMenu.MenuSelectedFcn(invertUpMenu, struct());
            drawnow
            restoredState = app.exportState();
            restoredUp = restoredState.Camera.UpVector / ...
                norm(restoredState.Camera.UpVector);
            testCase.verifyEqual(string(invertUpMenu.Checked), "off");
            testCase.verifyEqual(dot(restoredUp, initialUp), 1, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
        end

        function testAddImageExpandsLiveSceneAndResetBaseline(testCase)
            scene = ProjectionViewerAppInteractionTest.makeTwoImageScene();
            originalViewId = scene.layers(1).ViewId;
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow
            stateBefore = app.exportState();
            imageData = uint8(reshape(1:90, 5, 6, 3));
            sourceGeometry = ...
                ProjectionViewerHarness.createSyntheticSourceGeometry([5 6]);
            wrongGeometry = ...
                ProjectionViewerHarness.createSyntheticSourceGeometry([4 6]);

            testCase.verifyError(@() app.addImage( ...
                imageData, wrongGeometry), ...
                "ProjectionViewerHarness:imageGeometrySizeMismatch");
            testCase.verifyEqual(app.exportState(), stateBefore);
            testCase.verifyError(@() app.addImage( ...
                imageData, sourceGeometry, ...
                struct(ViewId=originalViewId)), ...
                "ProjectionViewMetadata:duplicateViewId");
            testCase.verifyEqual(app.exportState(), stateBefore);
            options = struct(Name="Added image", ViewId="added-view", ...
                PassId="added-pass", AcquisitionStartTime=3, ...
                LineRateHz=2);
            result = app.addImage(imageData, sourceGeometry, options);
            drawnow
            stateAfter = app.exportState();
            diagnostics = app.performanceDiagnostics();
            manager = findall(groot, "Tag", ...
                "ProjectionViewerLayerManagerFigure");
            tableControl = findall(manager, "Tag", ...
                "ProjectionViewerMotionTable");
            passControl = findall(manager, "Tag", ...
                "ProjectionViewerMotionPassDropDown");
            addedRow = string(tableControl.Data.ViewId) == "added-view";

            testCase.verifyEqual(result.LayerIndex, 3);
            testCase.verifyEqual(result.LayerCount, 3);
            testCase.verifyEqual(result.PairCount, 3);
            testCase.verifyEqual(result.ViewId, "added-view");
            testCase.verifyEqual(stateAfter.LayerCount, 3);
            testCase.verifyEqual(stateAfter.Layers(1:2), ...
                stateBefore.Layers);
            testCase.verifyEqual(stateAfter.Camera, stateBefore.Camera);
            testCase.verifyEqual(diagnostics.Viewer.LayerCount, 3);
            testCase.verifyTrue(tableControl.Data.Include(addedRow));
            testCase.verifyTrue(ismember("added-pass", ...
                string(passControl.ItemsData)));
            resetMenu = ProjectionViewerAppInteractionTest.findMenuItem( ...
                "ProjectionViewerResetMenuItem");
            resetMenu.MenuSelectedFcn(resetMenu, struct());
            drawnow
            testCase.verifyEqual(app.exportState().LayerCount, 3);
        end

        function testAlignmentContextMenuFocusesOneWorkbench(testCase)
            scene = ProjectionViewerAppInteractionTest.makeScene();
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow

            fig = findall(groot, "Type", "figure", ...
                "Name", "Sightline");
            alignmentPanelMenu = ProjectionViewerAppInteractionTest.findMenuItem( ...
                "ProjectionViewerAlignmentPanelMenuItem");

            testCase.verifyEmpty(findall(fig, "Tag", ...
                "ProjectionViewerAlignmentGrid"));
            testCase.verifyEmpty(findall(fig, "Tag", ...
                "ProjectionViewerAlignmentPairTable"));
            testCase.verifyEmpty(findall(fig, "Tag", ...
                "ProjectionViewerAlignmentMatchTable"));
            alignmentPanelMenu.MenuSelectedFcn(alignmentPanelMenu, struct());
            drawnow

            workbench = findall(groot, "Type", "figure", ...
                "Name", "Alignment Workbench");
            testCase.verifyNumElements(workbench, 1);
            testCase.verifyEqual(string(workbench.WindowStyle), "normal");
            diagnosticsAfterWorkbench = app.performanceDiagnostics();
            testCase.verifyTrue( ...
                diagnosticsAfterWorkbench.Viewer.AlignmentWorkbenchCreated);
            testCase.verifyEqual( ...
                diagnosticsAfterWorkbench.Viewer.AlignmentTableCount, 2);
            testCase.verifyEqual( ...
                diagnosticsAfterWorkbench.Counters.AlignmentWorkbenchCreations, 1);

            alignmentPanelMenu.MenuSelectedFcn(alignmentPanelMenu, struct());
            drawnow
            focusedWorkbench = findall(groot, "Type", "figure", ...
                "Name", "Alignment Workbench");
            testCase.verifyEqual(focusedWorkbench, workbench);
            diagnosticsAfterFocus = app.performanceDiagnostics();
            testCase.verifyEqual( ...
                diagnosticsAfterFocus.Counters.AlignmentWorkbenchCreations, 1);

            workbench.CloseRequestFcn(workbench, struct());
            drawnow
            alignmentPanelMenu.MenuSelectedFcn(alignmentPanelMenu, struct());
            drawnow
            reopenedWorkbench = findall(groot, "Type", "figure", ...
                "Name", "Alignment Workbench");
            testCase.verifyNumElements(reopenedWorkbench, 1);
            diagnosticsAfterReopen = app.performanceDiagnostics();
            testCase.verifyEqual( ...
                diagnosticsAfterReopen.Counters.AlignmentWorkbenchCreations, 2);
            testCase.verifyEmpty(findall(fig, "Tag", ...
                "ProjectionViewerAlignmentGrid"));
        end

        function testHelpContextMenuOpensNonModalDialog(testCase)
            scene = ProjectionViewerAppInteractionTest.makeScene();
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow

            fig = findall(groot, "Type", "figure", ...
                "Name", "Sightline");
            helpMenu = ProjectionViewerAppInteractionTest.findMenuItem( ...
                "ProjectionViewerHelpMenuItem");

            helpMenu.MenuSelectedFcn(helpMenu, struct());
            drawnow

            helpFig = findall(groot, "Type", "figure", ...
                "Name", "Projection Viewer Help");
            helpTextArea = findall(helpFig, "-isa", "matlab.ui.control.TextArea");

            testCase.verifyNotEmpty(helpFig);
            testCase.verifyNotEqual(helpFig, fig);
            testCase.verifyEqual(string(fig.Visible), "on");
            testCase.verifyEqual(string(helpFig.Visible), "on");
            testCase.verifyTrue(any(contains(string(helpTextArea.Value), ...
                "Alt/Option + left drag: adjust selected-layer omega and phi")));
            testCase.verifyTrue(any(contains(string(helpTextArea.Value), ...
                "Up/Down arrows: adjust Tip by 0.5 deg")));
            testCase.verifyTrue(any(contains(string(helpTextArea.Value), ...
                "Left/Right arrows: adjust Tilt by 0.5 deg")));
        end

        function testMainCloseOwnsChildrenTimersAndNotCallerFigure(testCase)
            app = ProjectionViewerApp( ...
                ProjectionViewerAppInteractionTest.makeTwoImageScene());
            testCase.addTeardown(@() delete(app));
            callerFigure = uifigure(Name="Caller-owned sentinel");
            testCase.addTeardown(@() delete(callerFigure));
            drawnow
            viewer = findall(groot, "Type", "figure", ...
                "Name", "Sightline");

            alignmentMenu = ProjectionViewerAppInteractionTest.findMenuItem( ...
                "ProjectionViewerAlignmentPanelMenuItem");
            alignmentMenu.MenuSelectedFcn(alignmentMenu, struct());
            helpMenu = ProjectionViewerAppInteractionTest.findMenuItem( ...
                "ProjectionViewerHelpMenuItem");
            helpMenu.MenuSelectedFcn(helpMenu, struct());
            motionWindow = findall(groot, "Tag", ...
                "ProjectionViewerLayerManagerFigure");
            mode = ProjectionViewerAppInteractionTest.findTaggedComponent( ...
                motionWindow, "ProjectionViewerLayerManagerModeDropDown");
            mode.Value = "single";
            mode.ValueChangedFcn(mode, struct());
            playButton = ProjectionViewerAppInteractionTest.findTaggedComponent( ...
                motionWindow, "ProjectionViewerMotionPlayPauseButton");
            playButton.ButtonPushedFcn(playButton, struct());
            drawnow

            closeViewer = viewer.CloseRequestFcn;
            closeViewer(viewer, struct());
            drawnow

            testCase.verifyFalse(isvalid(viewer));
            testCase.verifyEmpty(findall(groot, "Name", ...
                "Alignment Workbench"));
            testCase.verifyEmpty(findall(groot, "Name", ...
                "Projection Viewer Help"));
            testCase.verifyEmpty(findall(groot, "Tag", ...
                "ProjectionViewerLayerManagerFigure"));
            testCase.verifyEmpty(timerfindall("Tag", ...
                "ProjectionViewerMotionPlaybackTimer"));
            testCase.verifyTrue(isvalid(callerFigure));
            testCase.verifyWarningFree(@() closeViewer([], struct()));
        end

        function testChildFirstThenProgrammaticDeleteIsIdempotent(testCase)
            app = ProjectionViewerApp( ...
                ProjectionViewerAppInteractionTest.makeTwoImageScene());
            viewer = findall(groot, "Type", "figure", ...
                "Name", "Sightline");
            alignmentMenu = ProjectionViewerAppInteractionTest.findMenuItem( ...
                "ProjectionViewerAlignmentPanelMenuItem");
            alignmentMenu.MenuSelectedFcn(alignmentMenu, struct());
            helpMenu = ProjectionViewerAppInteractionTest.findMenuItem( ...
                "ProjectionViewerHelpMenuItem");
            helpMenu.MenuSelectedFcn(helpMenu, struct());
            drawnow

            children = [findall(groot, "Name", "Alignment Workbench"); ...
                findall(groot, "Name", "Projection Viewer Help"); ...
                findall(groot, "Tag", "ProjectionViewerLayerManagerFigure")];
            for child = reshape(children, 1, [])
                child.CloseRequestFcn(child, struct());
            end
            drawnow

            testCase.verifyTrue(isvalid(viewer));
            testCase.verifyEmpty(findall(groot, "Name", ...
                "Alignment Workbench"));
            testCase.verifyEmpty(findall(groot, "Name", ...
                "Projection Viewer Help"));
            testCase.verifyEmpty(findall(groot, "Tag", ...
                "ProjectionViewerLayerManagerFigure"));
            testCase.verifyWarningFree(@() delete(app));
            testCase.verifyWarningFree(@() delete(app));
            testCase.verifyFalse(isvalid(viewer));
        end

        function testCrosshairContextMenuToggleTracksPointer(testCase)
            scene = ProjectionViewerAppInteractionTest.makeScene();
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow

            fig = findall(groot, "Type", "figure", ...
                "Name", "Sightline");
            ax = findall(fig, "Type", "axes");
            crosshairMenu = ProjectionViewerAppInteractionTest.findMenuItem( ...
                "ProjectionViewerCrosshairMenuItem");
            pointer = ProjectionViewerAppInteractionTest.axesCenterPoint(ax);
            [rightVector, upVector] = ProjectionViewerAppInteractionTest.cameraScreenBasis(ax);

            crosshairMenu.MenuSelectedFcn(crosshairMenu, struct());
            drawnow
            fig.CurrentPoint = pointer;
            fig.WindowButtonMotionFcn(fig, struct());

            horizontal = ProjectionViewerAppInteractionTest.findTaggedComponent( ...
                fig, "ProjectionViewerCrosshairHorizontal");
            vertical = ProjectionViewerAppInteractionTest.findTaggedComponent( ...
                fig, "ProjectionViewerCrosshairVertical");

            testCase.verifyEqual(string(crosshairMenu.Checked), "on");
            testCase.verifyEqual(string(horizontal.Visible), "on");
            testCase.verifyEqual(string(vertical.Visible), "on");
            testCase.verifyEqual(horizontal.Color, [0 1 1]);
            testCase.verifyEqual(vertical.Color, [0 1 1]);
            testCase.verifyGreaterThan( ...
                ProjectionViewerAppInteractionTest.lineLength(horizontal), 0);
            testCase.verifyGreaterThan( ...
                ProjectionViewerAppInteractionTest.lineLength(vertical), 0);
            testCase.verifyGreaterThan(abs(dot( ...
                ProjectionViewerAppInteractionTest.lineDelta(horizontal), ...
                rightVector)), 0);
            testCase.verifyGreaterThan(abs(dot( ...
                ProjectionViewerAppInteractionTest.lineDelta(vertical), ...
                upVector)), 0);

            crosshairMenu.MenuSelectedFcn(crosshairMenu, struct());
            drawnow

            testCase.verifyEqual(string(crosshairMenu.Checked), "off");
            testCase.verifyEqual(string(horizontal.Visible), "off");
            testCase.verifyEqual(string(vertical.Visible), "off");
        end

        function testLayerDropDownIsWideForLongLayerNames(testCase)
            scene = ProjectionViewerAppInteractionTest.makeTwoImageScene();
            scene.layers(2).Name = ...
                "this_is_a_deliberately_long_50_character_layer_file.tif";
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow

            fig = findall(groot, "Type", "figure", ...
                "Name", "Sightline");
            layerDropDown = ProjectionViewerAppInteractionTest.findLayerDropDown(fig);

            testCase.verifyEqual(string(layerDropDown.Tag), ...
                "ProjectionViewerLayerManagerLayerDropDown");
            testCase.verifyEqual(layerDropDown.Layout.Column, [2 4]);
            testCase.verifyTrue(contains(string(layerDropDown.Items{2}), ...
                string(scene.layers(2).Name)));
        end

        function testTipTiltAndTwistRangesAreEightyFiveDegrees(testCase)
            scene = ProjectionViewerAppInteractionTest.makeScene();
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow

            fig = findall(groot, "Type", "figure", ...
                "Name", "Sightline");
            tipSlider = ProjectionViewerAppInteractionTest.findSliderInColumn(fig, 2);
            tiltSlider = ProjectionViewerAppInteractionTest.findSliderInColumn(fig, 3);
            twistSlider = ProjectionViewerAppInteractionTest.findSliderInColumn(fig, 4);

            testCase.verifyEqual(tipSlider.Limits, [-85 85]);
            testCase.verifyEqual(tiltSlider.Limits, [-85 85]);
            testCase.verifyEqual(twistSlider.Limits, [-85 85]);
            testCase.verifyEqual(tipSlider.MajorTicks, [-85 -45 0 45 85]);
            testCase.verifyEqual(tiltSlider.MajorTicks, [-85 -45 0 45 85]);
            testCase.verifyEqual(twistSlider.MajorTicks, [-85 -45 0 45 85]);
        end

        function testExtremeTipTiltMeshesStayInsideStabilizedAxesLimits(testCase)
            scene = ProjectionViewerAppInteractionTest.makeTwoImageScene();
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow

            fig = findall(groot, "Type", "figure", ...
                "Name", "Sightline");
            ax = findall(fig, "Type", "axes");
            tipSlider = ProjectionViewerAppInteractionTest.findSliderInColumn(fig, 2);
            tiltSlider = ProjectionViewerAppInteractionTest.findSliderInColumn(fig, 3);

            tipSlider.Value = 85;
            tipSlider.ValueChangedFcn(tipSlider, struct());
            tiltSlider.Value = -85;
            tiltSlider.ValueChangedFcn(tiltSlider, struct());
            drawnow
            surfaceHandles = findall(ax, "Type", "surface");
            bounds = ProjectionViewerAppInteractionTest.surfaceBounds(surfaceHandles);

            testCase.verifyGreaterThanOrEqual(bounds.Minimum(1), ax.XLim(1));
            testCase.verifyLessThanOrEqual(bounds.Maximum(1), ax.XLim(2));
            testCase.verifyGreaterThanOrEqual(bounds.Minimum(2), ax.YLim(1));
            testCase.verifyLessThanOrEqual(bounds.Maximum(2), ax.YLim(2));
            testCase.verifyGreaterThanOrEqual(bounds.Minimum(3), ax.ZLim(1));
            testCase.verifyLessThanOrEqual(bounds.Maximum(3), ax.ZLim(2));
        end

        function testStartupBoundsSkipInvalidExtremeTipTiltSamples(testCase)
            imageData = zeros(500, 500, "uint8");
            scene = ProjectionViewerHarness.createSceneFromImage( ...
                imageData, "wide-synthetic.tif", ...
                struct(RowStride=64, ColumnStride=64));

            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow
            fig = findall(groot, "Type", "figure", ...
                "Name", "Sightline");
            ax = findall(fig, "Type", "axes");

            testCase.verifyNotEmpty(ax);
            testCase.verifyTrue(all(isfinite(ax.XLim)));
            testCase.verifyTrue(all(isfinite(ax.YLim)));
            testCase.verifyTrue(all(isfinite(ax.ZLim)));
        end

        function testInitialViewFramesSurfaceToHalfViewport(testCase)
            imageData = zeros(500, 500, "uint8");
            scene = ProjectionViewerHarness.createSceneFromImage( ...
                imageData, "wide-synthetic.tif", ...
                struct(GSD=1, PlatformStepMeters=1, ...
                RowStride=64, ColumnStride=64));

            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow
            fig = findall(groot, "Type", "figure", ...
                "Name", "Sightline");
            ax = findall(fig, "Type", "axes");
            fillFraction = ProjectionViewerAppInteractionTest.surfaceViewportFill(ax);

            testCase.verifyGreaterThan(fillFraction, 0.45);
            testCase.verifyLessThan(fillFraction, 0.55);
        end

        function testDoubleLeftClickCyclesLayer(testCase)
            scene = ProjectionViewerAppInteractionTest.makeTwoImageScene();
            scene.layers(1).Alpha = 0.35;
            scene.layers(2).Alpha = 0.65;
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow

            fig = findall(groot, "Type", "figure", ...
                "Name", "Sightline");
            ax = findall(fig, "Type", "axes");
            layerDropDown = ProjectionViewerAppInteractionTest.findLayerDropDown(fig);

            fig.CurrentPoint = ProjectionViewerAppInteractionTest.axesCenterPoint(ax);
            fig.SelectionType = "open";
            fig.WindowButtonDownFcn(fig, struct());
            drawnow
            state = app.exportState();

            testCase.verifyEqual(layerDropDown.Value, 1);
            testCase.verifyTrue(state.Layers(1).Visible);
            testCase.verifyFalse(state.Layers(2).Visible);
            testCase.verifyEqual(state.Layers(1).Alpha, 0.35, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyEqual(state.Layers(2).Alpha, 0.65, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
        end

        function testSpacebarHoldTogglesSelectedLayerVisibility(testCase)
            scene = ProjectionViewerAppInteractionTest.makeTwoImageScene();
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow

            fig = findall(groot, "Type", "figure", ...
                "Name", "Sightline");
            ax = findall(fig, "Type", "axes");
            visibleCheckBox = findall(groot, "Tag", ...
                "ProjectionViewerLayerManagerVisibleCheckBox");
            layerSurfaces = ProjectionViewerAppInteractionTest.findLayerSurfaces( ...
                ax, scene);

            fig.WindowKeyPressFcn(fig, ...
                ProjectionViewerAppInteractionTest.makeKeyEvent("space"));
            drawnow
            hiddenState = app.exportState();

            testCase.verifyFalse(visibleCheckBox.Value);
            testCase.verifyEqual(string(layerSurfaces(2).Visible), "off");
            testCase.verifyFalse(hiddenState.Layers(2).Visible);

            fig.WindowKeyReleaseFcn(fig, ...
                ProjectionViewerAppInteractionTest.makeKeyEvent("space"));
            drawnow
            shownState = app.exportState();

            testCase.verifyTrue(visibleCheckBox.Value);
            testCase.verifyEqual(string(layerSurfaces(2).Visible), "on");
            testCase.verifyTrue(shownState.Layers(2).Visible);
        end

        function testLayerManagerContainsOrderingAndVisibilityControls(testCase)
            scene = ProjectionViewerAppInteractionTest.makeScene();
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow

            fig = findall(groot, "Type", "figure", ...
                "Name", "Sightline");
            visibleCheckBox = findall(groot, "Tag", ...
                "ProjectionViewerLayerManagerVisibleCheckBox");
            moveUpButton = ProjectionViewerAppInteractionTest.findTaggedComponent( ...
                fig, "ProjectionViewerMoveLayerUpButton");
            moveDownButton = ProjectionViewerAppInteractionTest.findTaggedComponent( ...
                fig, "ProjectionViewerMoveLayerDownButton");

            testCase.verifyEqual(moveUpButton.Parent, moveDownButton.Parent);
            testCase.verifyEqual(moveUpButton.Parent, visibleCheckBox.Parent);
            testCase.verifyEqual( ...
                ProjectionViewerAppInteractionTest.layoutPosition(moveUpButton), [1 5]);
            testCase.verifyEqual( ...
                ProjectionViewerAppInteractionTest.layoutPosition(moveDownButton), [1 6]);
            testCase.verifyEqual( ...
                ProjectionViewerAppInteractionTest.layoutPosition(visibleCheckBox), ...
                [1 7 8]);
            testCase.verifyEmpty(ProjectionViewerAppInteractionTest.findBlendDropDown(fig));
        end

        function testBlendModeContextMenuUpdatesVisibleLayersAndPreview(testCase)
            scene = ProjectionViewerAppInteractionTest.makeTwoImageScene();
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow

            fig = findall(groot, "Type", "figure", ...
                "Name", "Sightline");
            ax = findall(fig, "Type", "axes");
            layerSurfaces = ProjectionViewerAppInteractionTest.findLayerSurfaces( ...
                ax, scene);
            anaglyphBlendMenu = ProjectionViewerAppInteractionTest.findMenuItem( ...
                "ProjectionViewerAnaglyphBlendMenuItem");
            alphaBlendMenu = ProjectionViewerAppInteractionTest.findMenuItem( ...
                "ProjectionViewerAlphaBlendMenuItem");
            presentationMenu = ProjectionViewerAppInteractionTest.findMenuItem( ...
                "ProjectionViewerAnaglyphControlsMenu");

            anaglyphBlendMenu.MenuSelectedFcn(anaglyphBlendMenu, struct());
            drawnow
            state = app.exportState();

            testCase.verifyEqual(state.Layers(1).BlendMode, "redBlueAnaglyph");
            testCase.verifyEqual(state.Layers(2).BlendMode, "redBlueAnaglyph");
            testCase.verifyEqual(string(anaglyphBlendMenu.Checked), "on");
            testCase.verifyEqual(string(alphaBlendMenu.Checked), "off");
            testCase.verifyClass(layerSurfaces(1).CData, "single");
            testCase.verifyClass(layerSurfaces(2).CData, "single");
            testCase.verifyEqual(layerSurfaces(1).CData(:, :, 2), ...
                0.08 * ones(size(layerSurfaces(1).CData(:, :, 2)), ...
                "single"), AbsTol=1e-6);
            testCase.verifyEqual(layerSurfaces(2).CData(:, :, 2), ...
                0.08 * ones(size(layerSurfaces(2).CData(:, :, 2)), ...
                "single"), AbsTol=1e-6);
            layer1Mean = squeeze(mean(layerSurfaces(1).CData, [1 2]));
            layer2Mean = squeeze(mean(layerSurfaces(2).CData, [1 2]));
            actualRedLayerIndex = 1 + double(layer2Mean(1) > layer2Mean(3));
            expectedRedLayerIndex = ...
                ProjectionViewerAppInteractionTest.expectedRedLayerIndex( ...
                scene, ax);
            channelDominance = [layer1Mean(1) - layer1Mean(3), ...
                layer2Mean(1) - layer2Mean(3)];
            testCase.verifyEqual(double(sort(sign(channelDominance))), [-1 1]);
            testCase.verifyEqual(actualRedLayerIndex, ...
                expectedRedLayerIndex);
            testCase.verifyEqual(layerSurfaces(1).FaceAlpha, 0.70, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyEqual(layerSurfaces(2).FaceAlpha, 0.70, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyEqual(string(presentationMenu.Enable), "on");

            alphaBlendMenu.MenuSelectedFcn(alphaBlendMenu, struct());
            drawnow
            state = app.exportState();

            testCase.verifyEqual(state.Layers(1).BlendMode, "alpha");
            testCase.verifyEqual(state.Layers(2).BlendMode, "alpha");
            testCase.verifyEqual(string(anaglyphBlendMenu.Checked), "off");
            testCase.verifyEqual(string(alphaBlendMenu.Checked), "on");
            testCase.verifyEqual(layerSurfaces(1).CData, ...
                scene.layers(1).DisplayTexture);
            testCase.verifyEqual(layerSurfaces(2).CData, ...
                scene.layers(2).DisplayTexture);
            testCase.verifyEqual(layerSurfaces(1).FaceAlpha, 1, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyEqual(layerSurfaces(2).FaceAlpha, 1, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyEqual(string(presentationMenu.Enable), "off");
        end

        function testTwistRefreshesGeometryDerivedEyeAssignment(testCase)
            scene = ...
                ProjectionViewerAppInteractionTest.makeTwistCrossingAnaglyphScene();
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow

            fig = findall(groot, "Type", "figure", ...
                "Name", "Sightline");
            ax = findall(fig, "Type", "axes");
            twistSlider = ...
                ProjectionViewerAppInteractionTest.findSliderInColumn(fig, 4);
            anaglyphBlendMenu = ProjectionViewerAppInteractionTest.findMenuItem( ...
                "ProjectionViewerAnaglyphBlendMenuItem");

            anaglyphBlendMenu.MenuSelectedFcn(anaglyphBlendMenu, struct());
            drawnow
            initialSurfaces = ...
                ProjectionViewerAppInteractionTest.findLayerSurfacesByTag(ax);
            initialRedLayerIndex = ...
                ProjectionViewerAppInteractionTest.redLayerIndex( ...
                initialSurfaces);

            twistSlider.Value = 85;
            twistSlider.ValueChangedFcn(twistSlider, struct());
            drawnow
            twistedSurfaces = ...
                ProjectionViewerAppInteractionTest.findLayerSurfacesByTag(ax);
            actualRedLayerIndex = ...
                ProjectionViewerAppInteractionTest.redLayerIndex( ...
                twistedSurfaces);
            expectedRedLayerIndex = ...
                ProjectionViewerAppInteractionTest.expectedRedLayerIndex( ...
                scene, ax);

            testCase.verifyNotEqual(actualRedLayerIndex, ...
                initialRedLayerIndex);
            testCase.verifyEqual(actualRedLayerIndex, ...
                expectedRedLayerIndex);
        end

        function testAnaglyphPresentationControlsAreRuntimeOnly(testCase)
            scene = ProjectionViewerAppInteractionTest.makeTwoImageScene();
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow

            fig = findall(groot, "Type", "figure", ...
                "Name", "Sightline");
            ax = findall(fig, "Type", "axes");
            anaglyphBlendMenu = ProjectionViewerAppInteractionTest.findMenuItem( ...
                "ProjectionViewerAnaglyphBlendMenuItem");
            nearerMenu = ProjectionViewerAppInteractionTest.findMenuItem( ...
                "ProjectionViewerAnaglyphMoveNearerMenuItem");
            resetMenu = ProjectionViewerAppInteractionTest.findMenuItem( ...
                "ProjectionViewerAnaglyphResetPresentationMenuItem");

            anaglyphBlendMenu.MenuSelectedFcn(anaglyphBlendMenu, struct());
            drawnow
            app.resetPerformanceDiagnostics();
            stateBefore = app.exportState();
            layerSurfaces = ...
                ProjectionViewerAppInteractionTest.findLayerSurfacesByTag(ax);
            layer1X0 = layerSurfaces(1).XData;
            layer1Y0 = layerSurfaces(1).YData;
            layer1Z0 = layerSurfaces(1).ZData;

            nearerMenu.MenuSelectedFcn(nearerMenu, struct());
            drawnow
            stateAfter = app.exportState();
            layerSurfaces = ...
                ProjectionViewerAppInteractionTest.findLayerSurfacesByTag(ax);
            layer1Change = ProjectionViewerAppInteractionTest.surfaceChange( ...
                layerSurfaces(1), layer1X0, layer1Y0, layer1Z0);

            testCase.verifyGreaterThan(layer1Change, 0);
            testCase.verifyEqual(stateAfter, stateBefore);
            diagnostics = app.performanceDiagnostics();
            testCase.verifyEqual( ...
                diagnostics.Counters.LayerGeometryRefreshes, 0);
            testCase.verifyEqual(diagnostics.Counters.SampleFcnCalls, 0);

            resetMenu.MenuSelectedFcn(resetMenu, struct());
            drawnow
            layerSurfaces = ...
                ProjectionViewerAppInteractionTest.findLayerSurfacesByTag(ax);
            resetChange = ProjectionViewerAppInteractionTest.surfaceChange( ...
                layerSurfaces(1), layer1X0, layer1Y0, layer1Z0);
            testCase.verifyLessThan(resetChange, 1e-8);
        end

        function testLayerOrderButtonsSwapAdjacentLayers(testCase)
            scene = ProjectionViewerAppInteractionTest.makeThreeImageScene();
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow

            fig = findall(groot, "Type", "figure", ...
                "Name", "Sightline");
            layerDropDown = ProjectionViewerAppInteractionTest.findLayerDropDown(fig);
            moveUpButton = ProjectionViewerAppInteractionTest.findTaggedComponent( ...
                fig, "ProjectionViewerMoveLayerUpButton");
            moveDownButton = ProjectionViewerAppInteractionTest.findTaggedComponent( ...
                fig, "ProjectionViewerMoveLayerDownButton");

            layerDropDown.Value = 2;
            layerDropDown.ValueChangedFcn(layerDropDown, struct("Value", 2));
            moveUpButton.ButtonPushedFcn(moveUpButton, struct());
            drawnow
            movedUpState = app.exportState();

            testCase.verifyEqual(layerDropDown.Value, 3);
            testCase.verifyEqual([movedUpState.Layers.Name], ...
                ["layer1.tif" "layer3.tif" "layer2.tif"]);
            testCase.verifyTrue(contains(string(layerDropDown.Items{3}), "layer2.tif"));

            moveDownButton.ButtonPushedFcn(moveDownButton, struct());
            drawnow
            movedDownState = app.exportState();

            testCase.verifyEqual(layerDropDown.Value, 2);
            testCase.verifyEqual([movedDownState.Layers.Name], ...
                ["layer1.tif" "layer2.tif" "layer3.tif"]);
            testCase.verifyTrue(contains(string(layerDropDown.Items{2}), "layer2.tif"));
        end

        function testControlScrollAdjustsTwistWithoutZoomOrMeshChange(testCase)
            scene = ProjectionViewerAppInteractionTest.makeScene();
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow

            fig = findall(groot, "Type", "figure", ...
                "Name", "Sightline");
            ax = findall(fig, "Type", "axes");
            twistSlider = ProjectionViewerAppInteractionTest.findSliderInColumn(fig, 4);
            surfaceHandle = findall(ax, "Type", "surface");
            x0 = surfaceHandle(1).XData;
            y0 = surfaceHandle(1).YData;
            z0 = surfaceHandle(1).ZData;
            initialCameraViewAngle = ax.CameraViewAngle;
            initialUpVector = camup(ax);

            fig.WindowKeyPressFcn(fig, ...
                ProjectionViewerAppInteractionTest.makeKeyEvent("control"));
            fig.WindowScrollWheelFcn(fig, ...
                ProjectionViewerAppInteractionTest.makeScrollEvent(-3));
            drawnow

            testCase.verifyEqual(twistSlider.Value, 3, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyEqual(ax.CameraViewAngle, initialCameraViewAngle, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyGreaterThan(norm(camup(ax) - initialUpVector), 1e-9);
            testCase.verifyEqual(surfaceHandle(1).XData, x0, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyEqual(surfaceHandle(1).YData, y0, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyEqual(surfaceHandle(1).ZData, z0, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);

            fig.WindowKeyReleaseFcn(fig, ...
                ProjectionViewerAppInteractionTest.makeKeyEvent("control"));
            fig.WindowScrollWheelFcn(fig, ...
                ProjectionViewerAppInteractionTest.makeScrollEvent(-3));
            drawnow

            testCase.verifyEqual(twistSlider.Value, 3, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
        end

        function testShiftScrollAdjustsTipWithoutZoom(testCase)
            scene = ProjectionViewerAppInteractionTest.makeScene();
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow

            fig = findall(groot, "Type", "figure", ...
                "Name", "Sightline");
            ax = findall(fig, "Type", "axes");
            tipSlider = ProjectionViewerAppInteractionTest.findSliderInColumn(fig, 2);
            surfaceHandle = findall(ax, "Type", "surface");
            initialXData = surfaceHandle(1).XData;
            initialYData = surfaceHandle(1).YData;
            initialZData = surfaceHandle(1).ZData;
            initialCameraViewAngle = ax.CameraViewAngle;

            fig.WindowKeyPressFcn(fig, ...
                ProjectionViewerAppInteractionTest.makeKeyEvent("shift"));
            fig.WindowScrollWheelFcn(fig, ...
                ProjectionViewerAppInteractionTest.makeScrollEvent(-4));
            drawnow

            testCase.verifyEqual(tipSlider.Value, 4, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyEqual(ax.CameraViewAngle, initialCameraViewAngle, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyGreaterThan(ProjectionViewerAppInteractionTest.surfaceChange( ...
                surfaceHandle(1), initialXData, initialYData, initialZData), 1e-9);

            fig.WindowKeyReleaseFcn(fig, ...
                ProjectionViewerAppInteractionTest.makeKeyEvent("shift"));
            fig.WindowScrollWheelFcn(fig, ...
                ProjectionViewerAppInteractionTest.makeScrollEvent(-2));
            drawnow

            testCase.verifyEqual(tipSlider.Value, 4, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
        end

        function testAltScrollAdjustsTiltWithoutZoom(testCase)
            scene = ProjectionViewerAppInteractionTest.makeScene();
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow

            fig = findall(groot, "Type", "figure", ...
                "Name", "Sightline");
            ax = findall(fig, "Type", "axes");
            tiltSlider = ProjectionViewerAppInteractionTest.findSliderInColumn(fig, 3);
            surfaceHandle = findall(ax, "Type", "surface");
            initialXData = surfaceHandle(1).XData;
            initialYData = surfaceHandle(1).YData;
            initialZData = surfaceHandle(1).ZData;
            initialCameraViewAngle = ax.CameraViewAngle;

            fig.WindowKeyPressFcn(fig, ...
                ProjectionViewerAppInteractionTest.makeKeyEvent("alt"));
            fig.WindowScrollWheelFcn(fig, ...
                ProjectionViewerAppInteractionTest.makeScrollEvent(-5));
            drawnow

            testCase.verifyEqual(tiltSlider.Value, 5, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyEqual(ax.CameraViewAngle, initialCameraViewAngle, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyGreaterThan(ProjectionViewerAppInteractionTest.surfaceChange( ...
                surfaceHandle(1), initialXData, initialYData, initialZData), 1e-9);

            fig.WindowKeyReleaseFcn(fig, ...
                ProjectionViewerAppInteractionTest.makeKeyEvent("alt"));
            fig.WindowScrollWheelFcn(fig, ...
                ProjectionViewerAppInteractionTest.makeScrollEvent(-2));
            drawnow

            testCase.verifyEqual(tiltSlider.Value, 5, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
        end

        function testShiftArrowKeysAdjustTipAndTiltWithoutZoom(testCase)
            scene = ProjectionViewerAppInteractionTest.makeScene();
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow

            fig = findall(groot, "Type", "figure", ...
                "Name", "Sightline");
            ax = findall(fig, "Type", "axes");
            tipSlider = ProjectionViewerAppInteractionTest.findSliderInColumn(fig, 2);
            tiltSlider = ProjectionViewerAppInteractionTest.findSliderInColumn(fig, 3);
            surfaceHandle = findall(ax, "Type", "surface");
            initialXData = surfaceHandle(1).XData;
            initialYData = surfaceHandle(1).YData;
            initialZData = surfaceHandle(1).ZData;
            initialCameraViewAngle = ax.CameraViewAngle;
            fig.CurrentObject = ax;

            fig.WindowKeyPressFcn(fig, ...
                ProjectionViewerAppInteractionTest.makeKeyEvent( ...
                "uparrow", "shift"));
            fig.WindowKeyPressFcn(fig, ...
                ProjectionViewerAppInteractionTest.makeKeyEvent( ...
                "rightarrow", "shift"));
            drawnow
            adjustedState = app.exportState();

            testCase.verifyEqual(tipSlider.Value, 0.5, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyEqual(tiltSlider.Value, 0.5, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyEqual(adjustedState.Projection.TipDegrees, 0.5, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyEqual(adjustedState.Projection.TiltDegrees, 0.5, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyEqual(ax.CameraViewAngle, initialCameraViewAngle, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyGreaterThan(ProjectionViewerAppInteractionTest.surfaceChange( ...
                surfaceHandle(1), initialXData, initialYData, initialZData), 1e-9);

            fig.WindowKeyPressFcn(fig, ...
                ProjectionViewerAppInteractionTest.makeKeyEvent( ...
                "downarrow", "shift"));
            fig.WindowKeyPressFcn(fig, ...
                ProjectionViewerAppInteractionTest.makeKeyEvent( ...
                "leftarrow", "shift"));
            drawnow
            resetState = app.exportState();

            testCase.verifyEqual(tipSlider.Value, 0, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyEqual(tiltSlider.Value, 0, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyEqual(resetState.Projection.TipDegrees, 0, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyEqual(resetState.Projection.TiltDegrees, 0, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyEqual(ax.CameraViewAngle, initialCameraViewAngle, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
        end

        function testPlainLeftRightSelectLayersWithoutVisibilityChange(testCase)
            scene = ProjectionViewerAppInteractionTest.makeThreeImageScene();
            scene.layers(2).Visible = false;
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow

            fig = findall(groot, "Type", "figure", ...
                "Name", "Sightline");
            ax = findall(fig, "Type", "axes");
            visibilityBefore = [app.exportState().Layers.Visible];
            fig.CurrentObject = ax;

            fig.WindowKeyPressFcn(fig, ...
                ProjectionViewerAppInteractionTest.makeKeyEvent("leftarrow"));
            afterLeft = app.exportState();
            fig.WindowKeyPressFcn(fig, ...
                ProjectionViewerAppInteractionTest.makeKeyEvent("rightarrow"));
            afterRight = app.exportState();

            testCase.verifyEqual(afterLeft.SelectedLayerIndex, 2);
            testCase.verifyEqual(afterRight.SelectedLayerIndex, 3);
            testCase.verifyEqual([afterLeft.Layers.Visible], visibilityBefore);
            testCase.verifyEqual([afterRight.Layers.Visible], visibilityBefore);
        end

        function testPlainUpDownReuseVerticalLayerNudge(testCase)
            scene = ProjectionViewerAppInteractionTest.makeTwoImageScene();
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow

            fig = findall(groot, "Type", "figure", ...
                "Name", "Sightline");
            ax = findall(fig, "Type", "axes");
            initial = app.exportState();
            fig.CurrentObject = ax;

            fig.WindowKeyPressFcn(fig, ...
                ProjectionViewerAppInteractionTest.makeKeyEvent("uparrow"));
            nudged = app.exportState();
            fig.WindowKeyPressFcn(fig, ...
                ProjectionViewerAppInteractionTest.makeKeyEvent("downarrow"));
            restored = app.exportState();

            testCase.verifyNotEqual( ...
                nudged.Layers(2).ProjectionOffsetMeters, ...
                initial.Layers(2).ProjectionOffsetMeters);
            testCase.verifyEqual( ...
                restored.Layers(2).ProjectionOffsetMeters, ...
                initial.Layers(2).ProjectionOffsetMeters, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyEqual( ...
                restored.Layers(1).ProjectionOffsetMeters, ...
                initial.Layers(1).ProjectionOffsetMeters, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
        end

        function testArrowKeysDoNotStealControlFocus(testCase)
            scene = ProjectionViewerAppInteractionTest.makeThreeImageScene();
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow

            fig = findall(groot, "Type", "figure", ...
                "Name", "Sightline");
            tipSlider = ...
                ProjectionViewerAppInteractionTest.findSliderInColumn(fig, 2);
            initial = app.exportState();

            fig.CurrentObject = [];
            fig.WindowKeyPressFcn(fig, ...
                ProjectionViewerAppInteractionTest.makeKeyEvent("leftarrow"));
            fig.CurrentObject = tipSlider;
            fig.WindowKeyPressFcn(fig, ...
                ProjectionViewerAppInteractionTest.makeKeyEvent( ...
                "uparrow", "shift"));
            after = app.exportState();

            testCase.verifyEqual(after.SelectedLayerIndex, ...
                initial.SelectedLayerIndex);
            testCase.verifyEqual(after.Projection, initial.Projection);
            testCase.verifyEqual(after.Layers, initial.Layers);
        end

        function testLayerSpecificAlphaDragUpdatesSelectedLayerOnly(testCase)
            scene = ProjectionViewerAppInteractionTest.makeTwoImageScene();
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow

            fig = findall(groot, "Type", "figure", ...
                "Name", "Sightline");
            ax = findall(fig, "Type", "axes");
            layerDropDown = ProjectionViewerAppInteractionTest.findLayerDropDown(fig);
            alphaSlider = ProjectionViewerAppInteractionTest.findSliderInColumn(fig, 5);

            layerDropDown.Value = 2;
            layerDropDown.ValueChangedFcn(layerDropDown, struct("Value", 2));
            drawnow
            pause(0.04)

            alphaSlider.ValueChangingFcn(alphaSlider, struct("Value", 0.4));
            drawnow
            alphaSlider.Value = 0.4;
            alphaSlider.ValueChangedFcn(alphaSlider, struct());
            drawnow

            surfaceHandles = findall(ax, "Type", "surface");
            hasLayer2Texture = any(arrayfun( ...
                @(surfaceHandle) isequal(surfaceHandle.CData, ...
                scene.layers(2).DisplayTexture), surfaceHandles));
            layerSurfaces = ProjectionViewerAppInteractionTest.findLayerSurfaces( ...
                ax, scene);
            testCase.verifyTrue(hasLayer2Texture);
            testCase.verifyEqual(alphaSlider.Value, 0.4, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyEqual(layerSurfaces(1).FaceAlpha, 1, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyEqual(layerSurfaces(2).FaceAlpha, 0.4, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
        end

        function testInitialSelectionTargetsTopLayer(testCase)
            scene = ProjectionViewerAppInteractionTest.makeTwoImageScene();
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow

            fig = findall(groot, "Type", "figure", ...
                "Name", "Sightline");
            ax = findall(fig, "Type", "axes");
            layerDropDown = ProjectionViewerAppInteractionTest.findLayerDropDown(fig);
            alphaSlider = ProjectionViewerAppInteractionTest.findSliderInColumn(fig, 5);

            alphaSlider.Value = 0.35;
            alphaSlider.ValueChangedFcn(alphaSlider, struct());
            drawnow

            layerSurfaces = ProjectionViewerAppInteractionTest.findLayerSurfaces( ...
                ax, scene);

            testCase.verifyEqual(layerDropDown.Value, 2);
            testCase.verifyEqual(layerSurfaces(1).FaceAlpha, 1, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyEqual(layerSurfaces(2).FaceAlpha, 0.35, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
        end

        function testWasdNudgesSelectedLayerOnly(testCase)
            scene = ProjectionViewerAppInteractionTest.makeTwoImageScene();
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow

            fig = findall(groot, "Type", "figure", ...
                "Name", "Sightline");
            ax = findall(fig, "Type", "axes");
            layerSurfaces = ProjectionViewerAppInteractionTest.findLayerSurfaces( ...
                ax, scene);
            layer1X0 = layerSurfaces(1).XData;
            layer1Y0 = layerSurfaces(1).YData;
            layer1Z0 = layerSurfaces(1).ZData;
            layer2Center0 = ProjectionViewerAppInteractionTest.surfaceCenter( ...
                layerSurfaces(2));

            fig.WindowKeyPressFcn(fig, ...
                ProjectionViewerAppInteractionTest.makeKeyEvent("w"));
            drawnow

            layerSurfaces = ProjectionViewerAppInteractionTest.findLayerSurfaces( ...
                ax, scene);
            layer1Change = ProjectionViewerAppInteractionTest.surfaceChange( ...
                layerSurfaces(1), layer1X0, layer1Y0, layer1Z0);
            layer2Delta = ProjectionViewerAppInteractionTest.surfaceCenter( ...
                layerSurfaces(2)) - layer2Center0;

            testCase.verifyEqual(layer1Change, 0, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyEqual(layer2Delta, [0; 0; 0.5], AbsTol=1e-9);
        end

        function testControlLeftDragTranslatesSelectedLayerOnly(testCase)
            scene = ProjectionViewerAppInteractionTest.makeTwoImageScene();
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow

            fig = findall(groot, "Type", "figure", ...
                "Name", "Sightline");
            ax = findall(fig, "Type", "axes");
            initialCameraPosition = campos(ax);
            initialCameraTarget = camtarget(ax);
            layerSurfaces = ProjectionViewerAppInteractionTest.findLayerSurfaces( ...
                ax, scene);
            layer1X0 = layerSurfaces(1).XData;
            layer1Y0 = layerSurfaces(1).YData;
            layer1Z0 = layerSurfaces(1).ZData;
            layer2Center0 = ProjectionViewerAppInteractionTest.surfaceCenter( ...
                layerSurfaces(2));

            fig.WindowKeyPressFcn(fig, ...
                ProjectionViewerAppInteractionTest.makeKeyEvent("control"));
            ProjectionViewerAppInteractionTest.dragFigurePointer( ...
                fig, ax, "normal", [40 24]);
            fig.WindowKeyReleaseFcn(fig, ...
                ProjectionViewerAppInteractionTest.makeKeyEvent("control"));
            drawnow

            layerSurfaces = ProjectionViewerAppInteractionTest.findLayerSurfaces( ...
                ax, scene);
            layer2CenterDelta = ProjectionViewerAppInteractionTest.surfaceCenter( ...
                layerSurfaces(2)) - layer2Center0;
            screenDelta = ProjectionViewerAppInteractionTest.screenDeltaComponents( ...
                ax, layer2CenterDelta);
            state = app.exportState();

            testCase.verifyEqual(campos(ax), initialCameraPosition, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyEqual(camtarget(ax), initialCameraTarget, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyEqual(ProjectionViewerAppInteractionTest.surfaceChange( ...
                layerSurfaces(1), layer1X0, layer1Y0, layer1Z0), 0, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyGreaterThan(norm(state.Layers(2).ProjectionOffsetMeters), 0);
            testCase.verifyEqual(state.Layers(1).ProjectionOffsetMeters, [0 0], ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyGreaterThan(screenDelta(1), 0);
            testCase.verifyGreaterThan(screenDelta(2), 0);
        end

        function testAlphaChangeDoesNotMoveNudgedLayer(testCase)
            scene = ProjectionViewerAppInteractionTest.makeTwoImageScene();
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow

            fig = findall(groot, "Type", "figure", ...
                "Name", "Sightline");
            ax = findall(fig, "Type", "axes");
            alphaSlider = ProjectionViewerAppInteractionTest.findSliderInColumn(fig, 5);

            fig.WindowKeyPressFcn(fig, ...
                ProjectionViewerAppInteractionTest.makeKeyEvent("w"));
            drawnow

            layerSurfaces = ProjectionViewerAppInteractionTest.findLayerSurfaces( ...
                ax, scene);
            layer2X = layerSurfaces(2).XData;
            layer2Y = layerSurfaces(2).YData;
            layer2Z = layerSurfaces(2).ZData;

            alphaSlider.ValueChangingFcn(alphaSlider, struct("Value", 0.4));
            drawnow
            layerSurfaces = ProjectionViewerAppInteractionTest.findLayerSurfaces( ...
                ax, scene);

            testCase.verifyEqual(layerSurfaces(2).XData, layer2X, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyEqual(layerSurfaces(2).YData, layer2Y, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyEqual(layerSurfaces(2).ZData, layer2Z, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyEqual(layerSurfaces(2).FaceAlpha, 0.4, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);

            alphaSlider.Value = 0.7;
            alphaSlider.ValueChangedFcn(alphaSlider, struct());
            drawnow
            layerSurfaces = ProjectionViewerAppInteractionTest.findLayerSurfaces( ...
                ax, scene);

            testCase.verifyEqual(layerSurfaces(2).XData, layer2X, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyEqual(layerSurfaces(2).YData, layer2Y, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyEqual(layerSurfaces(2).ZData, layer2Z, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyEqual(layerSurfaces(2).FaceAlpha, 0.7, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
        end

        function testViewVectorCorrectionKeysAdjustSelectedLayerOnly(testCase)
            scene = ProjectionViewerAppInteractionTest.makeTwoImageScene();
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow

            fig = findall(groot, "Type", "figure", ...
                "Name", "Sightline");
            ax = findall(fig, "Type", "axes");
            opkLabel = ProjectionViewerAppInteractionTest.findOpkLabel(fig);
            ifovDegrees = ProjectionViewerAppInteractionTest.layerIfovDegrees( ...
                scene.layers(2));
            layerSurfaces = ProjectionViewerAppInteractionTest.findLayerSurfaces( ...
                ax, scene);
            layer1X = layerSurfaces(1).XData;
            layer1Y = layerSurfaces(1).YData;
            layer1Z = layerSurfaces(1).ZData;
            layer2X = layerSurfaces(2).XData;
            layer2Y = layerSurfaces(2).YData;
            layer2Z = layerSurfaces(2).ZData;

            fig.WindowKeyPressFcn(fig, ...
                ProjectionViewerAppInteractionTest.makeKeyEvent("i"));
            drawnow
            layerSurfaces = ProjectionViewerAppInteractionTest.findLayerSurfaces( ...
                ax, scene);
            phiChange = ProjectionViewerAppInteractionTest.surfaceChange( ...
                layerSurfaces(2), layer2X, layer2Y, layer2Z);

            testCase.verifyEqual(ProjectionViewerAppInteractionTest.surfaceChange( ...
                layerSurfaces(1), layer1X, layer1Y, layer1Z), 0, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyGreaterThan(phiChange, 1e-3);
            testCase.verifyEqual(string(opkLabel.Text), ...
                ProjectionViewerAppInteractionTest.opkText([0; ifovDegrees; 0]));

            fig.WindowKeyPressFcn(fig, ...
                ProjectionViewerAppInteractionTest.makeKeyEvent("k"));
            drawnow
            layerSurfaces = ProjectionViewerAppInteractionTest.findLayerSurfaces( ...
                ax, scene);

            testCase.verifyEqual(layerSurfaces(2).XData, layer2X, AbsTol=1e-9);
            testCase.verifyEqual(layerSurfaces(2).YData, layer2Y, AbsTol=1e-9);
            testCase.verifyEqual(layerSurfaces(2).ZData, layer2Z, AbsTol=1e-9);
            testCase.verifyEqual(string(opkLabel.Text), ...
                ProjectionViewerAppInteractionTest.opkText([0; 0; 0]));

            fig.WindowKeyPressFcn(fig, ...
                ProjectionViewerAppInteractionTest.makeKeyEvent("l"));
            drawnow
            layerSurfaces = ProjectionViewerAppInteractionTest.findLayerSurfaces( ...
                ax, scene);
            omegaChange = ProjectionViewerAppInteractionTest.surfaceChange( ...
                layerSurfaces(2), layer2X, layer2Y, layer2Z);

            testCase.verifyGreaterThan(omegaChange, 1e-3);
            testCase.verifyEqual(string(opkLabel.Text), ...
                ProjectionViewerAppInteractionTest.opkText([ifovDegrees; 0; 0]));

            fig.WindowKeyPressFcn(fig, ...
                ProjectionViewerAppInteractionTest.makeKeyEvent("j"));
            drawnow
            layerSurfaces = ProjectionViewerAppInteractionTest.findLayerSurfaces( ...
                ax, scene);

            testCase.verifyEqual(layerSurfaces(2).XData, layer2X, AbsTol=1e-9);
            testCase.verifyEqual(layerSurfaces(2).YData, layer2Y, AbsTol=1e-9);
            testCase.verifyEqual(layerSurfaces(2).ZData, layer2Z, AbsTol=1e-9);
            testCase.verifyEqual(string(opkLabel.Text), ...
                ProjectionViewerAppInteractionTest.opkText([0; 0; 0]));

            fig.WindowKeyPressFcn(fig, ...
                ProjectionViewerAppInteractionTest.makeKeyEvent("o"));
            drawnow
            layerSurfaces = ProjectionViewerAppInteractionTest.findLayerSurfaces( ...
                ax, scene);
            kappaChange = ProjectionViewerAppInteractionTest.surfaceChange( ...
                layerSurfaces(2), layer2X, layer2Y, layer2Z);

            testCase.verifyGreaterThan(kappaChange, 1e-3);
            testCase.verifyEqual(string(opkLabel.Text), ...
                ProjectionViewerAppInteractionTest.opkText([0; 0; 0.1]));

            fig.WindowKeyPressFcn(fig, ...
                ProjectionViewerAppInteractionTest.makeKeyEvent("u"));
            drawnow
            layerSurfaces = ProjectionViewerAppInteractionTest.findLayerSurfaces( ...
                ax, scene);

            testCase.verifyEqual(layerSurfaces(2).XData, layer2X, AbsTol=1e-9);
            testCase.verifyEqual(layerSurfaces(2).YData, layer2Y, AbsTol=1e-9);
            testCase.verifyEqual(layerSurfaces(2).ZData, layer2Z, AbsTol=1e-9);
            testCase.verifyEqual(string(opkLabel.Text), ...
                ProjectionViewerAppInteractionTest.opkText([0; 0; 0]));
        end

        function testAltLeftDragAdjustsOmegaPhiSelectedLayerOnly(testCase)
            scene = ProjectionViewerAppInteractionTest.makeTwoImageScene();
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow

            fig = findall(groot, "Type", "figure", ...
                "Name", "Sightline");
            ax = findall(fig, "Type", "axes");
            opkLabel = ProjectionViewerAppInteractionTest.findOpkLabel(fig);
            initialCameraPosition = campos(ax);
            initialCameraTarget = camtarget(ax);
            layerSurfaces = ProjectionViewerAppInteractionTest.findLayerSurfaces( ...
                ax, scene);
            layer1X0 = layerSurfaces(1).XData;
            layer1Y0 = layerSurfaces(1).YData;
            layer1Z0 = layerSurfaces(1).ZData;
            layer2Center0 = ProjectionViewerAppInteractionTest.surfaceCenter( ...
                layerSurfaces(2));

            fig.WindowKeyPressFcn(fig, ...
                ProjectionViewerAppInteractionTest.makeKeyEvent("alt"));
            ProjectionViewerAppInteractionTest.dragFigurePointer( ...
                fig, ax, "normal", [60 36], "alt");
            fig.WindowKeyReleaseFcn(fig, ...
                ProjectionViewerAppInteractionTest.makeKeyEvent("alt"));
            drawnow

            layerSurfaces = ProjectionViewerAppInteractionTest.findLayerSurfaces( ...
                ax, scene);
            layer2CenterDelta = ProjectionViewerAppInteractionTest.surfaceCenter( ...
                layerSurfaces(2)) - layer2Center0;
            screenDelta = ProjectionViewerAppInteractionTest.screenDeltaComponents( ...
                ax, layer2CenterDelta);
            state = app.exportState();
            offsets = state.Layers(2).ViewVectorAngularOffsetsDegrees;

            testCase.verifyEqual(campos(ax), initialCameraPosition, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyEqual(camtarget(ax), initialCameraTarget, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyEqual(ProjectionViewerAppInteractionTest.surfaceChange( ...
                layerSurfaces(1), layer1X0, layer1Y0, layer1Z0), 0, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyEqual(state.Layers(1).ViewVectorAngularOffsetsDegrees, ...
                [0 0 0], AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyGreaterThan(norm(offsets(1:2)), 0);
            testCase.verifyEqual(offsets(3), 0, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyEqual(state.Layers(2).ProjectionOffsetMeters, [0 0], ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyGreaterThan(screenDelta(1), 0);
            testCase.verifyGreaterThan(screenDelta(2), 0);
            testCase.verifyEqual(string(opkLabel.Text), ...
                ProjectionViewerAppInteractionTest.opkText(offsets));
        end

        function testControlAlternateSelectionDragTranslatesLayerWithoutOmegaPhi(testCase)
            scene = ProjectionViewerAppInteractionTest.makeTwoImageScene();
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow

            fig = findall(groot, "Type", "figure", ...
                "Name", "Sightline");
            ax = findall(fig, "Type", "axes");

            fig.WindowKeyPressFcn(fig, ...
                ProjectionViewerAppInteractionTest.makeKeyEvent("control"));
            ProjectionViewerAppInteractionTest.dragFigurePointer( ...
                fig, ax, "alt", [60 36], "control");
            fig.WindowKeyReleaseFcn(fig, ...
                ProjectionViewerAppInteractionTest.makeKeyEvent("control"));
            drawnow
            state = app.exportState();

            testCase.verifyEqual(state.Layers(2).ViewVectorAngularOffsetsDegrees, ...
                [0 0 0], AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyGreaterThan(norm(state.Layers(2).ProjectionOffsetMeters), 0);
        end

        function testExportImportStateRestoresViewerConfiguration(testCase)
            scene = ProjectionViewerAppInteractionTest.makeTwoImageScene();
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow

            state = app.exportState();
            state.SelectedLayerIndex = 2;
            state.Projection.TipDegrees = 5.5;
            state.Projection.TiltDegrees = -4.25;
            state.View.TwistDegrees = 3.75;
            state.Camera.ViewAngle = 11;
            state.Layers(1).Alpha = 0.35;
            state.Layers(1).Visible = false;
            state.Layers(1).BlendMode = "redBlueAnaglyph";
            state.Layers(1).ProjectionOffsetMeters = [0.5 -0.25];
            state.Layers(1).ViewVectorAngularOffsetsDegrees = [0.01 0.02 0.03];
            state.Layers(2).Alpha = 0.45;
            state.Layers(2).Visible = true;
            state.Layers(2).BlendMode = "alpha";
            state.Layers(2).ProjectionOffsetMeters = [-0.75 1.25];
            state.Layers(2).ViewVectorAngularOffsetsDegrees = [-0.04 0.05 -0.06];
            state = ProjectionViewerState.validate(state, 2);

            app.importState(state);
            actual = app.exportState();

            testCase.verifyEqual(actual.SelectedLayerIndex, 2);
            testCase.verifyEqual(actual.Projection.TipDegrees, 5.5, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyEqual(actual.Projection.TiltDegrees, -4.25, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyEqual(actual.View.TwistDegrees, 3.75, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyEqual(actual.Camera.ViewAngle, 11, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyEqual(actual.Layers(1).Alpha, 0.35, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyFalse(actual.Layers(1).Visible);
            testCase.verifyEqual(actual.Layers(1).BlendMode, "redBlueAnaglyph");
            testCase.verifyEqual(actual.Layers(1).ProjectionOffsetMeters, ...
                [0.5 -0.25], AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyEqual(actual.Layers(1).ViewVectorAngularOffsetsDegrees, ...
                [0.01 0.02 0.03], AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyEqual(actual.Layers(2).Alpha, 0.45, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyEqual(actual.Layers(2).ProjectionOffsetMeters, ...
                [-0.75 1.25], AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyEqual(actual.Layers(2).ViewVectorAngularOffsetsDegrees, ...
                [-0.04 0.05 -0.06], AbsTol=ProjectionViewerAppInteractionTest.Tol);
        end

        function testSaveLoadStateRoundTrip(testCase)
            scene = ProjectionViewerAppInteractionTest.makeTwoImageScene();
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow

            state = app.exportState();
            state.SelectedLayerIndex = 2;
            state.Projection.TipDegrees = 2.25;
            state.Layers(2).Alpha = 0.25;
            state.Layers(2).ProjectionOffsetMeters = [1.25 -1.5];
            state = ProjectionViewerState.validate(state, 2);
            app.importState(state);
            filePath = fullfile(tempdir, "projection_viewer_app_state_test.json");
            testCase.addTeardown(@() delete(filePath));

            app.saveState(filePath);
            resetState = app.exportState();
            resetState.Projection.TipDegrees = 0;
            resetState.Layers(2).Alpha = 1;
            resetState.Layers(2).ProjectionOffsetMeters = [0 0];
            app.importState(ProjectionViewerState.validate(resetState, 2));
            loadedState = app.loadState(filePath);
            actual = app.exportState();
            jsonText = fileread(filePath);

            testCase.verifyTrue(contains(jsonText, '"ProjectionOffsetMeters"'));
            testCase.verifyEqual(loadedState.Projection.TipDegrees, 2.25, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyEqual(actual.Layers(2).Alpha, 0.25, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyEqual(actual.Layers(2).ProjectionOffsetMeters, ...
                [1.25 -1.5], AbsTol=ProjectionViewerAppInteractionTest.Tol);
        end

        function testResetRestoresNeutralViewerAndLayerState(testCase)
            scene = ProjectionViewerAppInteractionTest.makeThreeImageScene();
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow

            fig = findall(groot, "Type", "figure", ...
                "Name", "Sightline");
            ax = findall(fig, "Type", "axes");
            layerDropDown = ProjectionViewerAppInteractionTest.findLayerDropDown(fig);
            tipSlider = ProjectionViewerAppInteractionTest.findSliderInColumn(fig, 2);
            tiltSlider = ProjectionViewerAppInteractionTest.findSliderInColumn(fig, 3);
            twistSlider = ProjectionViewerAppInteractionTest.findSliderInColumn(fig, 4);
            alphaSlider = ProjectionViewerAppInteractionTest.findSliderInColumn(fig, 5);
            visibleCheckBox = findall(groot, "Tag", ...
                "ProjectionViewerLayerManagerVisibleCheckBox");
            moveUpButton = ProjectionViewerAppInteractionTest.findTaggedComponent( ...
                fig, "ProjectionViewerMoveLayerUpButton");
            anaglyphBlendMenu = ProjectionViewerAppInteractionTest.findMenuItem( ...
                "ProjectionViewerAnaglyphBlendMenuItem");
            resetMenu = ProjectionViewerAppInteractionTest.findMenuItem( ...
                "ProjectionViewerResetMenuItem");

            layerDropDown.Value = 2;
            layerDropDown.ValueChangedFcn(layerDropDown, struct("Value", 2));
            moveUpButton.ButtonPushedFcn(moveUpButton, struct());
            tipSlider.Value = 30;
            tipSlider.ValueChangedFcn(tipSlider, struct());
            tiltSlider.Value = -25;
            tiltSlider.ValueChangedFcn(tiltSlider, struct());
            twistSlider.Value = 12;
            twistSlider.ValueChangedFcn(twistSlider, struct());
            alphaSlider.Value = 0.35;
            alphaSlider.ValueChangedFcn(alphaSlider, struct());
            visibleCheckBox.Value = false;
            visibleCheckBox.ValueChangedFcn(visibleCheckBox, struct("Value", false));
            anaglyphBlendMenu.MenuSelectedFcn(anaglyphBlendMenu, struct());
            fig.WindowKeyPressFcn(fig, ...
                ProjectionViewerAppInteractionTest.makeKeyEvent("w"));
            fig.WindowKeyPressFcn(fig, ...
                ProjectionViewerAppInteractionTest.makeKeyEvent("i"));
            drawnow

            resetMenu.MenuSelectedFcn(resetMenu, struct());
            drawnow
            actual = app.exportState();

            testCase.verifyEqual(actual.SelectedLayerIndex, 3);
            testCase.verifyEqual([actual.Layers.Name], ...
                ["layer1.tif" "layer2.tif" "layer3.tif"]);
            testCase.verifyEqual(actual.Projection.TipDegrees, 0, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyEqual(actual.Projection.TiltDegrees, 0, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyEqual(actual.View.TwistDegrees, 0, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyEqual([actual.Layers.Alpha], [1 1 1], ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyEqual([actual.Layers.Visible], [true true true]);
            testCase.verifyEqual([actual.Layers.BlendMode], ...
                ["alpha" "alpha" "alpha"]);
            testCase.verifyEqual( ...
                ProjectionViewerAppInteractionTest.layerProjectionOffsets(actual), ...
                zeros(3, 2), AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyEqual( ...
                ProjectionViewerAppInteractionTest.layerViewVectorOffsets(actual), ...
                zeros(3, 3), AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyEqual(layerDropDown.Value, 3);
            testCase.verifyTrue(contains(string(layerDropDown.Items{2}), "layer2.tif"));
            testCase.verifyTrue(all(ax.ZLim > [-Inf -Inf]));
        end

        function testExportBackendJobFromCurrentViewerState(testCase)
            tempFolder = string(tempname);
            mkdir(tempFolder);
            testCase.addTeardown(@() ...
                ProjectionViewerAppInteractionTest.removeFolder(tempFolder));
            scene = ProjectionViewerAppInteractionTest.makeTwoImageScene();
            state = ProjectionViewerAppInteractionTest.makeViewerState(scene);
            app = ProjectionViewerApp(scene, [], state);
            testCase.addTeardown(@() delete(app));
            drawnow
            options = struct(RenderOptions=struct(OutputSize=[3 4], ...
                TileSize=[2 2]));
            jobPath = fullfile(tempFolder, "viewer_backend_job.json");

            job = app.exportBackendJob(options);
            validation = ProjectionBackendProcessor.validate(job);
            app.writeBackendJob(jobPath, options);
            pathValidation = validateProjectionBackendJob(jobPath);

            testCase.verifyEqual(job.ViewerState.SelectedLayerIndex, 2);
            testCase.verifyEqual(job.RenderOptions.OutputSize, [3 4]);
            testCase.verifyEqual(validation.Status, "valid");
            testCase.verifyTrue(validation.StateApplied);
            testCase.verifyTrue(isfile(jobPath));
            testCase.verifyEqual(pathValidation.OutputGrid.OutputSize, [3 4]);
        end

        function testLargeLayerUsesTiledPreviewAndExportsFullImage(testCase)
            imageData = zeros(2001, 2001, "uint8");
            options = struct();
            options.GSD = 0.01;
            options.NominalRange = 1e6;
            options.PlatformStepMeters = 0.01;
            options.RowStride = 250;
            options.ColumnStride = 250;
            options.DisplayTextureMaxPixels = 10000;
            scene = ProjectionViewerHarness.createSceneFromImage( ...
                imageData, "large.tif", options);
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow
            fig = findall(groot, "Type", "figure", ...
                "Name", "Sightline");
            ax = findall(fig, "Type", "axes");
            tipSlider = ProjectionViewerAppInteractionTest.findSliderInColumn(fig, 2);
            tileSurfaces = findall(ax, "Type", "surface", ...
                "Tag", "ProjectionViewerPreviewTileSurface");
            testCase.assertNotEmpty(tileSurfaces);
            firstTileSurface = tileSurfaces(1);
            firstTileX = firstTileSurface.XData;
            firstTileY = firstTileSurface.YData;
            firstTileZ = firstTileSurface.ZData;

            tipSlider.Value = 5;
            tipSlider.ValueChangedFcn(tipSlider, struct());
            drawnow
            updatedTileSurfaces = findall(ax, "Type", "surface", ...
                "Tag", "ProjectionViewerPreviewTileSurface");

            job = app.exportBackendJob(struct(RenderOptions=struct( ...
                OutputSize=[5 6])));

            testCase.verifyTrue(ProjectionViewerAppInteractionTest.sameGraphicsHandles( ...
                tileSurfaces, updatedTileSurfaces));
            testCase.verifyGreaterThan(ProjectionViewerAppInteractionTest.surfaceChange( ...
                firstTileSurface, firstTileX, firstTileY, firstTileZ), 1e-9);
            testCase.verifyTrue(size(scene.layers.DisplayTexture, 1) < ...
                size(imageData, 1));
            testCase.verifySize(job.Scene.layers.Image, [2001 2001]);
            testCase.verifyEqual(job.Scene.layers.Image, imageData);
        end

        function testSpacebarVisibilityReusesTiledPreviewSurfaces(testCase)
            imageData = zeros(2001, 2001, "uint8");
            options = struct();
            options.GSD = 0.01;
            options.NominalRange = 1e6;
            options.PlatformStepMeters = 0.01;
            options.RowStride = 250;
            options.ColumnStride = 250;
            options.DisplayTextureMaxPixels = 10000;
            scene = ProjectionViewerHarness.createSceneFromImage( ...
                imageData, "large.tif", options);
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow
            fig = findall(groot, "Type", "figure", ...
                "Name", "Sightline");
            ax = findall(fig, "Type", "axes");
            tileSurfaces = findall(ax, "Type", "surface", ...
                "Tag", "ProjectionViewerPreviewTileSurface");
            testCase.assertNotEmpty(tileSurfaces);

            fig.WindowKeyPressFcn(fig, ...
                ProjectionViewerAppInteractionTest.makeKeyEvent("space"));
            drawnow
            hiddenTileSurfaces = findall(ax, "Type", "surface", ...
                "Tag", "ProjectionViewerPreviewTileSurface");

            testCase.verifyTrue(ProjectionViewerAppInteractionTest.sameGraphicsHandles( ...
                tileSurfaces, hiddenTileSurfaces));
            testCase.verifyTrue(all(string([hiddenTileSurfaces.Visible]) == "off"));

            fig.WindowKeyReleaseFcn(fig, ...
                ProjectionViewerAppInteractionTest.makeKeyEvent("space"));
            drawnow
            shownTileSurfaces = findall(ax, "Type", "surface", ...
                "Tag", "ProjectionViewerPreviewTileSurface");

            testCase.verifyTrue(ProjectionViewerAppInteractionTest.sameGraphicsHandles( ...
                tileSurfaces, shownTileSurfaces));
            testCase.verifyTrue(all(string([shownTileSurfaces.Visible]) == "on"));
        end

        function testConstructorAcceptsViewerState(testCase)
            scene = ProjectionViewerAppInteractionTest.makeTwoImageScene();
            state = ProjectionViewerAppInteractionTest.makeViewerState(scene);

            app = ProjectionViewerApp(scene, [], state);
            testCase.addTeardown(@() delete(app));
            drawnow

            actual = app.exportState();

            testCase.verifyEqual(actual.SelectedLayerIndex, 2);
            testCase.verifyEqual(actual.Projection.TipDegrees, ...
                state.Projection.TipDegrees, AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyEqual(actual.View.TwistDegrees, ...
                state.View.TwistDegrees, AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyEqual(actual.Layers(2).Alpha, state.Layers(2).Alpha, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyEqual(actual.Layers(2).ProjectionOffsetMeters, ...
                state.Layers(2).ProjectionOffsetMeters, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
        end

        function testTipTiltControlsSharedProjectionPlane(testCase)
            scene = ProjectionViewerAppInteractionTest.makeTwoImageScene();
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow

            fig = findall(groot, "Type", "figure", ...
                "Name", "Sightline");
            ax = findall(fig, "Type", "axes");
            layerDropDown = ProjectionViewerAppInteractionTest.findLayerDropDown(fig);
            tipSlider = ProjectionViewerAppInteractionTest.findSliderInColumn(fig, 2);
            layerSurfaces = ProjectionViewerAppInteractionTest.findLayerSurfaces( ...
                ax, scene);
            layer1X0 = layerSurfaces(1).XData;
            layer1Y0 = layerSurfaces(1).YData;
            layer1Z0 = layerSurfaces(1).ZData;
            layer2X0 = layerSurfaces(2).XData;
            layer2Y0 = layerSurfaces(2).YData;
            layer2Z0 = layerSurfaces(2).ZData;

            layerDropDown.Value = 2;
            layerDropDown.ValueChangedFcn(layerDropDown, struct("Value", 2));
            tipSlider.Value = 6;
            tipSlider.ValueChangedFcn(tipSlider, struct());
            drawnow

            layerSurfaces = ProjectionViewerAppInteractionTest.findLayerSurfaces( ...
                ax, scene);
            layer1Change = ProjectionViewerAppInteractionTest.surfaceChange( ...
                layerSurfaces(1), layer1X0, layer1Y0, layer1Z0);
            layer2Change = ProjectionViewerAppInteractionTest.surfaceChange( ...
                layerSurfaces(2), layer2X0, layer2Y0, layer2Z0);
            layerDropDown.Value = 1;
            layerDropDown.ValueChangedFcn(layerDropDown, struct("Value", 1));
            drawnow

            testCase.verifyGreaterThan(layer1Change, 1e-9);
            testCase.verifyGreaterThan(layer2Change, 1e-9);
            testCase.verifyEqual(tipSlider.Value, 6, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
        end

        function testMultiLayerPreviewUsesStableDepthBias(testCase)
            scene = ProjectionViewerAppInteractionTest.makeTwoImageScene();
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow

            fig = findall(groot, "Type", "figure", ...
                "Name", "Sightline");
            ax = findall(fig, "Type", "axes");
            layerSurfaces = ProjectionViewerAppInteractionTest.findLayerSurfaces( ...
                ax, scene);
            viewDirection = ProjectionViewerAppInteractionTest.cameraViewDirection(ax);

            layer1Depth = ProjectionViewerAppInteractionTest.meanSurfaceDepth( ...
                layerSurfaces(1), viewDirection);
            layer2Depth = ProjectionViewerAppInteractionTest.meanSurfaceDepth( ...
                layerSurfaces(2), viewDirection);

            testCase.verifyEqual(layer2Depth - layer1Depth, -1, ...
                AbsTol=1e-8);
        end

        function testFirstTipChangePreservesAxesScale(testCase)
            scene = ProjectionViewerAppInteractionTest.makeTwoImageScene();
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow

            fig = findall(groot, "Type", "figure", ...
                "Name", "Sightline");
            ax = findall(fig, "Type", "axes");
            tipSlider = ProjectionViewerAppInteractionTest.findSliderInColumn(fig, 2);
            initialCameraViewAngle = ax.CameraViewAngle;
            initialXLim = ax.XLim;
            initialYLim = ax.YLim;
            initialZLim = ax.ZLim;
            initialPlotBoxAspectRatio = ax.PlotBoxAspectRatio;

            tipSlider.Value = 1;
            tipSlider.ValueChangedFcn(tipSlider, struct());
            drawnow

            testCase.verifyEqual(ax.CameraViewAngle, initialCameraViewAngle, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyEqual(ax.XLim, initialXLim, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyEqual(ax.YLim, initialYLim, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyEqual(ax.ZLim, initialZLim, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
            testCase.verifyEqual(ax.PlotBoxAspectRatio, initialPlotBoxAspectRatio, ...
                AbsTol=ProjectionViewerAppInteractionTest.Tol);
        end
    end

    methods (Static, Access = private)
        function closeOwnedWindowsAndTimers()
            timers = timerfindall("Tag", ...
                "ProjectionViewerMotionPlaybackTimer");
            for timerObject = reshape(timers, 1, [])
                if string(timerObject.Running) == "on"
                    stop(timerObject);
                end
                delete(timerObject);
            end
            figureNames = ["Sightline" "Alignment Workbench" ...
                "Projection Viewer Help" "Layer Manager"];
            for figureName = figureNames
                delete(findall(groot, "Type", "figure", ...
                    "Name", figureName));
            end
        end

        function scene = makeScene()
            imageData = uint8(reshape(1:60, 4, 5, 3));
            options = struct();
            options.RowStride = 2;
            options.ColumnStride = 2;
            scene = ProjectionViewerHarness.createSceneFromImage( ...
                imageData, "synthetic.tif", options);
        end

        function scene = makeTwoImageScene()
            imageData1 = uint8(reshape(1:60, 4, 5, 3));
            imageData2 = uint8(reshape(1:72, 6, 4, 3));
            options = struct();
            options.RowStride = 2;
            options.ColumnStride = 2;
            scene = ProjectionViewerHarness.createSceneFromImages( ...
                {imageData1, imageData2}, ["layer1.tif", "layer2.tif"], ...
                options);
        end

        function scene = makeThreeImageScene()
            imageData1 = uint8(reshape(1:60, 4, 5, 3));
            imageData2 = uint8(reshape(1:72, 6, 4, 3));
            imageData3 = uint8(reshape(1:90, 5, 6, 3));
            options = struct();
            options.RowStride = 2;
            options.ColumnStride = 2;
            scene = ProjectionViewerHarness.createSceneFromImages( ...
                {imageData1, imageData2, imageData3}, ...
                ["layer1.tif", "layer2.tif", "layer3.tif"], options);
        end

        function scene = makeTwistCrossingAnaglyphScene()
            scene = ProjectionViewerAppInteractionTest.makeTwoImageScene();
            referenceOrigin = ...
                scene.layers(1).SourceGeometry.ReferenceOrigin;
            scene.layers(2).SourceGeometry.ReferenceOrigin = ...
                referenceOrigin + [0; 0.25; -0.25];
        end

        function removeFolder(folder)
            if isfolder(folder)
                rmdir(folder, "s");
            end
        end

        function menuItem = findMenuItem(tag)
            menuItems = findall(groot, "Tag", tag);
            menuItem = menuItems(1);
        end

        function component = findTaggedComponent(parent, tag)
            components = findall(parent, "Tag", tag);
            if isempty(components)
                components = findall(groot, "Tag", tag);
            end
            component = components(1);
        end

        function dropdown = findLayerDropDown(~)
            dropdown = findall(groot, "Tag", ...
                "ProjectionViewerLayerManagerLayerDropDown");
        end

        function dropdown = findBlendDropDown(fig)
            dropdowns = findall(fig, "-isa", "matlab.ui.control.DropDown");
            isBlendDropDown = false(size(dropdowns));
            for k = 1:numel(dropdowns)
                items = reshape(string(dropdowns(k).Items), 1, []);
                isBlendDropDown(k) = isequal(items, ["alpha", "redBlueAnaglyph"]);
            end
            dropdown = dropdowns(isBlendDropDown);
        end

        function button = findButton(fig, text)
            buttons = findall(fig, "-isa", "matlab.ui.control.Button");
            buttonTexts = strings(size(buttons));
            for k = 1:numel(buttons)
                buttonTexts(k) = string(buttons(k).Text);
            end
            button = buttons(buttonTexts == string(text));
        end

        function position = layoutPosition(component)
            position = [component.Layout.Row component.Layout.Column];
        end

        function slider = findSliderInColumn(fig, column)
            sliders = findall(fig, "-isa", "matlab.ui.control.Slider");
            sliderColumns = arrayfun(@(slider) slider.Layout.Column, sliders);
            slider = sliders(sliderColumns == column - 1);
        end

        function label = findOpkLabel(fig)
            labels = findall(fig, "-isa", "matlab.ui.control.Label");
            labelTexts = strings(size(labels));
            for k = 1:numel(labels)
                labelTexts(k) = string(labels(k).Text);
            end
            label = labels(startsWith(labelTexts, "Omega "));
        end

        function ifovDegrees = layerIfovDegrees(layer)
            imageSize = layer.SourceGeometry.ImageSize;
            rowIndices = ProjectionViewerAppInteractionTest.centerAdjacentIndices( ...
                imageSize(1));
            columnIndex = round((imageSize(2) + 1) / 2);
            [~, V] = layer.SourceGeometry.SampleFcn(rowIndices, columnIndex);
            v1 = V(:, 1, 1) / norm(V(:, 1, 1));
            v2 = V(:, 2, 1) / norm(V(:, 2, 1));
            ifovDegrees = rad2deg(acos(max(min(dot(v1, v2), 1), -1)));
        end

        function indices = centerAdjacentIndices(count)
            if count <= 1
                indices = 1;
                return
            end

            firstIndex = max(1, floor((count + 1) / 2));
            secondIndex = min(count, firstIndex + 1);
            if secondIndex == firstIndex
                firstIndex = firstIndex - 1;
            end
            indices = [firstIndex secondIndex];
        end

        function text = opkText(offsetsDegrees)
            text = string(sprintf("Omega %.4f deg\nPhi %.4f deg\nKappa %.3f deg", ...
                offsetsDegrees(1), offsetsDegrees(2), offsetsDegrees(3)));
        end

        function offsets = layerProjectionOffsets(state)
            offsets = reshape([state.Layers.ProjectionOffsetMeters], 2, []).';
        end

        function offsets = layerViewVectorOffsets(state)
            offsets = reshape([state.Layers.ViewVectorAngularOffsetsDegrees], 3, []).';
        end

        function state = makeViewerState(scene)
            state = struct();
            state.Format = "ProjectionViewerState";
            state.Version = 1;
            state.LayerCount = numel(scene.layers);
            state.SelectedLayerIndex = 2;
            state.Projection = struct(TipDegrees=3.5, TiltDegrees=-2.5);
            state.View = struct(TwistDegrees=1.25);
            state.Layers = [ ...
                ProjectionViewerAppInteractionTest.makeViewerLayerState( ...
                scene.layers(1), 1, 1, [0 0], [0 0 0]), ...
                ProjectionViewerAppInteractionTest.makeViewerLayerState( ...
                scene.layers(2), 2, 0.3, [0.5 -0.75], [0.01 0.02 0.03])];
        end

        function layerState = makeViewerLayerState(layer, index, alpha, ...
                projectionOffsetMeters, viewVectorAngularOffsetsDegrees)
            layerState = struct();
            layerState.Index = index;
            layerState.Name = layer.Name;
            layerState.ImagePath = layer.ImagePath;
            layerState.Alpha = alpha;
            layerState.Visible = true;
            layerState.BlendMode = "alpha";
            layerState.ProjectionOffsetMeters = projectionOffsetMeters;
            layerState.ViewVectorAngularOffsetsDegrees = ...
                viewVectorAngularOffsetsDegrees;
        end

        function surfaces = findLayerSurfaces(ax, scene)
            surfaceHandles = findall(ax, "Type", "surface");
            surfaces = gobjects(1, numel(scene.layers));
            for layerIndex = 1:numel(scene.layers)
                isLayerSurface = arrayfun( ...
                    @(surfaceHandle) isequal(surfaceHandle.CData, ...
                    scene.layers(layerIndex).DisplayTexture), surfaceHandles);
                surfaces(layerIndex) = surfaceHandles(isLayerSurface);
            end
        end

        function surfaces = findLayerSurfacesByTag(ax)
            surfaces = findall(ax, "Type", "surface", ...
                "Tag", "ProjectionViewerLayerSurface");
            surfaces = flip(reshape(surfaces, 1, []));
        end

        function layerIndex = redLayerIndex(surfaces)
            layer1Mean = squeeze(mean(surfaces(1).CData, [1 2]));
            layer2Mean = squeeze(mean(surfaces(2).CData, [1 2]));
            channelDominance = [layer1Mean(1) - layer1Mean(3), ...
                layer2Mean(1) - layer2Mean(3)];
            [~, layerIndex] = max(channelDominance);
        end

        function layerIndex = expectedRedLayerIndex(scene, ax)
            origins = [scene.layers(1).SourceGeometry.ReferenceOrigin, ...
                scene.layers(2).SourceGeometry.ReferenceOrigin];
            [rightVector, ~] = ...
                ProjectionViewerAppInteractionTest.cameraScreenBasis(ax);
            [~, layerIndex] = min(rightVector.' * origins);
        end

        function viewDirection = cameraViewDirection(ax)
            viewDirection = camtarget(ax).' - campos(ax).';
            viewDirection = viewDirection / norm(viewDirection);
        end

        function depth = meanSurfaceDepth(surfaceHandle, viewDirection)
            points = [surfaceHandle.XData(:).'; ...
                surfaceHandle.YData(:).'; surfaceHandle.ZData(:).'];
            depth = mean(viewDirection(:).' * points);
        end

        function center = surfaceCenter(surfaceHandle)
            center = [mean(surfaceHandle.XData, "all"); ...
                mean(surfaceHandle.YData, "all"); ...
                mean(surfaceHandle.ZData, "all")];
        end

        function dragFigurePointer(fig, ax, selectionType, pixelDelta, modifier)
            if nargin < 5
                modifier = "control";
            end
            startPoint = ProjectionViewerAppInteractionTest.axesCenterPoint(ax);
            fig.SelectionType = selectionType;
            fig.CurrentPoint = startPoint;
            fig.WindowButtonDownFcn(fig, ...
                ProjectionViewerAppInteractionTest.makeMouseEvent(modifier));
            fig.CurrentPoint = startPoint + pixelDelta;
            fig.WindowButtonMotionFcn(fig, struct());
            fig.WindowButtonUpFcn(fig, struct());
        end

        function point = axesCenterPoint(ax)
            axesPosition = ax.InnerPosition;
            point = axesPosition(1:2) + axesPosition(3:4) / 2;
        end

        function delta = lineDelta(lineHandle)
            delta = [lineHandle.XData(2) - lineHandle.XData(1); ...
                lineHandle.YData(2) - lineHandle.YData(1); ...
                lineHandle.ZData(2) - lineHandle.ZData(1)];
            delta = delta / norm(delta);
        end

        function length = lineLength(lineHandle)
            length = norm([lineHandle.XData(2) - lineHandle.XData(1); ...
                lineHandle.YData(2) - lineHandle.YData(1); ...
                lineHandle.ZData(2) - lineHandle.ZData(1)]);
        end

        function [rightVector, upVector] = cameraScreenBasis(ax)
            viewDirection = ProjectionViewerAppInteractionTest.cameraViewDirection(ax);
            upVector = camup(ax).';
            upVector = upVector / norm(upVector);
            rightVector = cross(viewDirection, upVector);
            rightVector = rightVector / norm(rightVector);
        end

        function fillFraction = surfaceViewportFill(ax)
            surfaceHandles = findall(ax, "Type", "surface");
            points = zeros(3, 0);
            for k = 1:numel(surfaceHandles)
                surfaceHandle = surfaceHandles(k);
                points = [points, [surfaceHandle.XData(:).'; ...
                    surfaceHandle.YData(:).'; ...
                    surfaceHandle.ZData(:).']]; %#ok<AGROW>
            end

            [rightVector, upVector] = ...
                ProjectionViewerAppInteractionTest.cameraScreenBasis(ax);
            cameraPosition = campos(ax).';
            cameraTarget = camtarget(ax).';
            viewDistance = norm(cameraTarget - cameraPosition);
            axesPosition = ax.InnerPosition;
            viewHeight = 2 * viewDistance * tan( ...
                deg2rad(ax.CameraViewAngle) / 2);
            viewWidth = viewHeight * max(axesPosition(3), 1) / ...
                max(axesPosition(4), 1);
            projectedWidth = max(rightVector.' * points) - ...
                min(rightVector.' * points);
            projectedHeight = max(upVector.' * points) - ...
                min(upVector.' * points);
            fillFraction = max(projectedWidth / viewWidth, ...
                projectedHeight / viewHeight);
        end

        function screenDelta = screenDeltaComponents(ax, worldDelta)
            cameraPosition = campos(ax).';
            cameraTarget = camtarget(ax).';
            viewDirection = cameraTarget - cameraPosition;
            viewDirection = viewDirection / norm(viewDirection);
            upVector = camup(ax).';
            upVector = upVector / norm(upVector);
            rightVector = cross(viewDirection, upVector);
            rightVector = rightVector / norm(rightVector);
            screenDelta = [rightVector.' * worldDelta; upVector.' * worldDelta];
        end

        function bounds = surfaceBounds(surfaceHandles)
            minimums = [Inf; Inf; Inf];
            maximums = [-Inf; -Inf; -Inf];
            for k = 1:numel(surfaceHandles)
                surfaceHandle = surfaceHandles(k);
                minimums = min(minimums, [min(surfaceHandle.XData, [], "all"); ...
                    min(surfaceHandle.YData, [], "all"); ...
                    min(surfaceHandle.ZData, [], "all")]);
                maximums = max(maximums, [max(surfaceHandle.XData, [], "all"); ...
                    max(surfaceHandle.YData, [], "all"); ...
                    max(surfaceHandle.ZData, [], "all")]);
            end
            bounds = struct(Minimum=minimums, Maximum=maximums);
        end

        function event = makeKeyEvent(key, modifier)
            if nargin < 2
                modifier = key;
            end
            event = struct();
            event.Key = key;
            event.Modifier = modifier;
        end

        function event = makeMouseEvent(modifier)
            event = struct();
            event.Modifier = modifier;
        end

        function event = makeScrollEvent(verticalScrollCount)
            event = struct();
            event.VerticalScrollCount = verticalScrollCount;
        end

        function change = surfaceChange(surfaceHandle, x0, y0, z0)
            change = max([max(abs(surfaceHandle.XData - x0), [], "all"), ...
                max(abs(surfaceHandle.YData - y0), [], "all"), ...
                max(abs(surfaceHandle.ZData - z0), [], "all")]);
        end

        function tf = sameGraphicsHandles(firstHandles, secondHandles)
            if numel(firstHandles) ~= numel(secondHandles)
                tf = false;
                return
            end

            tf = true;
            for k = 1:numel(firstHandles)
                tf = tf && any(firstHandles(k) == secondHandles);
            end
        end
    end
end
