classdef ProjectionViewerStereoCursorWorkflowTest < matlab.uitest.TestCase
    %ProjectionViewerStereoCursorWorkflowTest Tests RD-6 viewport integration.

    properties (Constant)
        Tol = 1e-8
    end

    methods (TestClassSetup)
        function addPaths(testCase)
            root = fileparts(fileparts(mfilename("fullpath")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(root));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(root, "src")));
        end
    end

    methods (TestMethodSetup)
        function closeFigures(testCase)
            ProjectionViewerStereoCursorWorkflowTest.closeAllFigures();
            testCase.addTeardown( ...
                @ProjectionViewerStereoCursorWorkflowTest.closeAllFigures);
        end
    end

    methods (Test)
        function testMenuHeightBindingsBoundsAndCleanupAreRuntimeOnly(testCase)
            app = ProjectionViewerApp( ...
                ProjectionViewerStereoCursorWorkflowTest.scene(2));
            testCase.addTeardown(@() delete(app));
            drawnow
            viewer = ProjectionViewerStereoCursorWorkflowTest.viewer();
            axesHandle = findall(viewer, "Type", "axes");
            stateBefore = app.exportState();

            initial = app.placeStereoCursor([0 0], 0);
            app.stereoCursorOptions(struct( ...
                HeightStepMeters=2, HeightLimitsMeters=[-3 3]));
            menu = ProjectionViewerStereoCursorWorkflowTest.tagged( ...
                "ProjectionViewerStereoCursorMenuItem");
            reposition = ProjectionViewerStereoCursorWorkflowTest.tagged( ...
                "ProjectionViewerStereoCursorRepositionMenuItem");
            label = ProjectionViewerStereoCursorWorkflowTest.tagged( ...
                "ProjectionViewerStereoCursorOverlay");
            markers = findall(viewer, "-regexp", "Tag", ...
                "^ProjectionViewerStereoCursorMarker");

            viewer.WindowScrollWheelFcn(viewer, ...
                struct(VerticalScrollCount=-1, Modifier="shift"));
            normal = app.stereoCursorDiagnostics();
            viewer.WindowScrollWheelFcn(viewer, ...
                struct(VerticalScrollCount=-1, ...
                Modifier=["shift" "control"]));
            fine = app.stereoCursorDiagnostics();
            viewer.WindowScrollWheelFcn(viewer, ...
                struct(VerticalScrollCount=-1, ...
                Modifier=["shift" "alt"]));
            bounded = app.stereoCursorDiagnostics();
            viewer.CurrentObject = axesHandle;
            viewer.WindowKeyPressFcn(viewer, ...
                struct(Key="uparrow", Modifier="shift"));
            viewer.WindowKeyReleaseFcn(viewer, ...
                struct(Key="shift", Modifier="shift"));
            afterTip = app.stereoCursorDiagnostics();
            viewerState = app.exportState();

            testCase.verifyTrue(initial.Enabled);
            testCase.verifyEqual(menu.Checked, ...
                matlab.lang.OnOffSwitchState.on);
            testCase.verifyEqual(reposition.Enable, ...
                matlab.lang.OnOffSwitchState.on);
            testCase.verifyNumElements(markers, 2);
            testCase.verifyEqual(nnz(string({markers.Visible}) == "on"), 2);
            testCase.verifyEqual(normal.HeightMeters, 2, ...
                AbsTol=ProjectionViewerStereoCursorWorkflowTest.Tol);
            testCase.verifyEqual(fine.HeightMeters, 2.2, ...
                AbsTol=ProjectionViewerStereoCursorWorkflowTest.Tol);
            testCase.verifyEqual(bounded.HeightMeters, 3, ...
                AbsTol=ProjectionViewerStereoCursorWorkflowTest.Tol);
            testCase.verifyEqual(afterTip.HeightMeters, 3, ...
                AbsTol=ProjectionViewerStereoCursorWorkflowTest.Tol);
            testCase.verifyEqual(viewerState.Projection.TipDegrees, 0.5, ...
                AbsTol=ProjectionViewerStereoCursorWorkflowTest.Tol);
            testCase.verifyTrue(any(contains( ...
                string(label.String), "+ along VN")));

            menu.MenuSelectedFcn(menu, struct());
            disabled = app.stereoCursorDiagnostics();
            testCase.verifyFalse(disabled.Enabled);
            testCase.verifyEqual(menu.Checked, ...
                matlab.lang.OnOffSwitchState.off);
            testCase.verifyEqual(nnz(string({markers.Visible}) == "on"), 0);
            testCase.verifyEqual(label.Visible, ...
                matlab.lang.OnOffSwitchState.off);
            stateAfter = app.exportState();
            stateBefore.Projection.TipDegrees = 0.5;
            testCase.verifyEqual(stateAfter, stateBefore);
        end

        function testRoleSwapLayerReorderAndPairTurnoverUseStableViews(testCase)
            app = ProjectionViewerApp( ...
                ProjectionViewerStereoCursorWorkflowTest.scene(3));
            testCase.addTeardown(@() delete(app));
            drawnow
            app.placeStereoCursor([0 0], 4);
            before = app.stereoCursorDiagnostics();
            redBefore = before.Eyes.RedViewId;

            alignmentMenu = ProjectionViewerStereoCursorWorkflowTest.tagged( ...
                "ProjectionViewerAlignmentPanelMenuItem");
            alignmentMenu.MenuSelectedFcn(alignmentMenu, struct());
            drawnow
            swapRoles = ProjectionViewerStereoCursorWorkflowTest.tagged( ...
                "ProjectionViewerAlignmentSwapPairButton");
            testCase.press(swapRoles);
            drawnow
            swapped = app.stereoCursorDiagnostics();

            moveDown = ProjectionViewerStereoCursorWorkflowTest.tagged( ...
                "ProjectionViewerMoveLayerDownButton");
            testCase.press(moveDown);
            drawnow
            reordered = app.stereoCursorDiagnostics();

            previous = ProjectionViewerStereoCursorWorkflowTest.tagged( ...
                "ProjectionViewerAlignmentPreviousPairButton");
            testCase.verifyEqual(previous.Enable, ...
                matlab.lang.OnOffSwitchState.on);
            testCase.press(previous);
            drawnow
            turned = app.stereoCursorDiagnostics();
            active = app.alignmentDiagnostics().ActivePair;

            testCase.verifyEqual(swapped.PairId, before.PairId);
            testCase.verifyEqual(swapped.ViewIds, before.ViewIds);
            testCase.verifyEqual(swapped.Eyes.RedViewId, redBefore);
            testCase.verifyEqual(reordered.PairId, before.PairId);
            testCase.verifyEqual(reordered.ViewIds, before.ViewIds);
            testCase.verifyEqual(reordered.Eyes.RedViewId, redBefore);
            testCase.verifyNotEqual(turned.PairId, before.PairId);
            testCase.verifyEqual(turned.PairId, active.PairId);
            testCase.verifyEqual(turned.ViewIds, sort( ...
                [active.ReferenceViewId active.MovingViewId]));
            testCase.verifyEqual(turned.Projection.ValidCount, 2);
            testCase.verifyTrue(any(turned.Eyes.RedViewId == turned.ViewIds));

            manager = ProjectionViewerStereoCursorWorkflowTest.tagged( ...
                "ProjectionViewerLayerManagerFigure");
            pairMode = findall(manager, "Tag", ...
                "ProjectionViewerLayerManagerModeDropDown");
            pairMode.Value = "pair";
            pairMode.ValueChangedFcn(pairMode, struct());
            drawnow
            pairView = app.stereoCursorDiagnostics();
            pairViewActive = app.alignmentDiagnostics().ActivePair;
            testCase.verifyEqual(pairView.PairId, pairViewActive.PairId);
            testCase.verifyEqual(pairView.ViewIds, sort( ...
                [pairViewActive.ReferenceViewId ...
                pairViewActive.MovingViewId]));
            testCase.verifyEqual(pairView.Projection.ValidCount, 2);
        end

        function testPanZoomTwistInvalidStateAndImportPreserveScience(testCase)
            app = ProjectionViewerApp( ...
                ProjectionViewerStereoCursorWorkflowTest.scene(2));
            testCase.addTeardown(@() delete(app));
            drawnow
            viewer = ProjectionViewerStereoCursorWorkflowTest.viewer();
            axesHandle = findall(viewer, "Type", "axes");
            before = app.placeStereoCursor([0 0], 5);
            beforeAngle = axesHandle.CameraViewAngle;

            center = axesHandle.InnerPosition(1:2) + ...
                axesHandle.InnerPosition(3:4) / 2;
            viewer.SelectionType = "normal";
            viewer.CurrentPoint = center;
            viewer.WindowButtonDownFcn(viewer, struct());
            viewer.CurrentPoint = center + [12 8];
            viewer.WindowButtonMotionFcn(viewer, struct());
            viewer.WindowButtonUpFcn(viewer, struct());
            viewer.CurrentPoint = center;
            viewer.WindowScrollWheelFcn(viewer, ...
                struct(VerticalScrollCount=-1));
            viewer.WindowScrollWheelFcn(viewer, ...
                struct(VerticalScrollCount=-2, Modifier="control"));
            drawnow
            after = app.stereoCursorDiagnostics();

            testCase.verifyNotEqual(axesHandle.CameraViewAngle, beforeAngle);
            testCase.verifyNotEqual(after.AnchorPlaneCoordinates, ...
                before.AnchorPlaneCoordinates);
            testCase.verifyEqual(after.HeightMeters, before.HeightMeters);
            testCase.verifyNotEqual(after.WorldPoint, before.WorldPoint);
            testCase.verifyNotEqual( ...
                [after.Projection.Projections.SourceCoordinates], ...
                [before.Projection.Projections.SourceCoordinates]);

            invalid = app.placeStereoCursor([1e6 0], 0);
            markers = findall(viewer, "-regexp", "Tag", ...
                "^ProjectionViewerStereoCursorMarker");
            label = ProjectionViewerStereoCursorWorkflowTest.tagged( ...
                "ProjectionViewerStereoCursorOverlay");
            testCase.verifyEqual(invalid.Status, "invalid");
            testCase.verifyEqual(invalid.Projection.ValidCount, 0);
            testCase.verifyEqual(nnz(string({markers.Visible}) == "on"), 0);
            testCase.verifyTrue(any(contains(string(label.String), ...
                "outsideSourceFootprint")));

            state = app.exportState();
            app.importState(state);
            testCase.verifyFalse(app.stereoCursorDiagnostics().Enabled);
            testCase.verifyFalse(isfield(state, "StereoCursor"));
        end

        function testCursorFollowsPointerAndUsesHeightReadout(testCase)
            app = ProjectionViewerApp( ...
                ProjectionViewerStereoCursorWorkflowTest.scene(2));
            testCase.addTeardown(@() delete(app));
            drawnow
            viewer = ProjectionViewerStereoCursorWorkflowTest.viewer();
            axesHandle = findall(viewer, "Type", "axes");
            viewer.Pointer = "hand";
            initial = app.placeStereoCursor([0 0], -3);
            viewVector = ProjectionViewerStereoCursorWorkflowTest.tagged( ...
                "ProjectionViewerViewVectorOverlay");
            center = axesHandle.InnerPosition(1:2) + ...
                axesHandle.InnerPosition(3:4) / 2;
            viewer.CurrentObject = axesHandle;
            viewer.CurrentPoint = center + [35 18];
            drawnow
            viewer.WindowButtonMotionFcn(viewer, struct());
            followed = app.stereoCursorDiagnostics();

            testCase.verifyEqual(string(viewer.Pointer), "crosshair");
            testCase.verifyNotEmpty(viewer.WindowButtonMotionFcn);
            testCase.verifyNotEqual(followed.AnchorPlaneCoordinates, ...
                initial.AnchorPlaneCoordinates);
            testCase.verifyEqual(followed.HeightMeters, -3, ...
                AbsTol=ProjectionViewerStereoCursorWorkflowTest.Tol);
            testCase.verifyTrue(contains(string(viewVector.Text), ...
                "Stereo cursor -3.000 m below projection plane"));

            menu = ProjectionViewerStereoCursorWorkflowTest.tagged( ...
                "ProjectionViewerStereoCursorMenuItem");
            menu.MenuSelectedFcn(menu, struct());
            testCase.verifyEqual(string(viewer.Pointer), "hand");
            testCase.verifyFalse(contains(string(viewVector.Text), ...
                "Stereo cursor"));
        end
    end

    methods (Static, Access = private)
        function scene = scene(count)
            images = arrayfun(@(index) ...
                uint8(index * ones(32, 40, 3)), ...
                1:count, UniformOutput=false);
            paths = "cursor-ui-" + string(1:count) + ".tif";
            scene = ProjectionViewerHarness.createSceneFromImages( ...
                images, paths, struct(RowStride=4, ColumnStride=4));
            for index = 1:count
                scene.layers(index).ViewId = "cursor-ui-view-" + index;
                scene.layers(index).PassId = "cursor-ui-pass";
                scene.layers(index).AcquisitionStartTime = index;
                scene.layers(index).BlendMode = "redBlueAnaglyph";
            end
            scene = ProjectionViewMetadata.ensureScene(scene);
        end

        function viewer = viewer()
            viewer = findall(groot, "Type", "figure", ...
                "Name", "Sightline");
            viewer = viewer(1);
        end

        function component = tagged(tag)
            component = findall(groot, "Tag", tag);
            component = component(1);
        end

        function closeAllFigures()
            figures = findall(groot, "Type", "figure");
            delete(figures);
        end
    end
end
