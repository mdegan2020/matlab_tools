classdef ProjectionViewerMotionWorkflowTest < matlab.uitest.TestCase
    %ProjectionViewerMotionWorkflowTest Tests manual motion-imagery UI.

    methods (TestClassSetup)
        function addSourceToPath(testCase)
            projectRoot = fileparts(fileparts(mfilename("fullpath")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(projectRoot, "src")));
        end
    end

    methods (TestMethodSetup)
        function closeExistingFigures(testCase)
            ProjectionViewerMotionWorkflowTest.closeFigures();
            testCase.addTeardown( ...
                @ProjectionViewerMotionWorkflowTest.closeFigures);
        end
    end

    methods (Test)
        function testContextLaunchIsLazyAndDefaultsToAllViews(testCase)
            scene = ProjectionViewerMotionWorkflowTest.makeScene();
            scene.layers(2).Visible = false;
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            viewer = ProjectionViewerMotionWorkflowTest.viewer();

            testCase.verifyEmpty(findall(groot, "Tag", ...
                "ProjectionViewerMotionFigure"));
            testCase.verifyEmpty(findall(viewer, "Tag", ...
                "ProjectionViewerMotionLeftEdgeButton"));

            ProjectionViewerMotionWorkflowTest.openMotionWindow();
            window = ProjectionViewerMotionWorkflowTest.motionWindow();
            data = ProjectionViewerMotionWorkflowTest.tagged( ...
                window, "ProjectionViewerMotionTable").Data;

            testCase.verifyTrue(all(data.Include));
            testCase.verifyEqual(height(data), numel(scene.layers));
            testCase.verifyEqual(string(data.ViewId), ...
                reshape(ProjectionViewMetadata.ids(scene), [], 1));
            testCase.verifyEmpty(findall(viewer, "Tag", ...
                "ProjectionViewerMotionLeftEdgeButton"));
            testCase.verifyFalse(app.motionDiagnostics().Active);
        end

        function testPassAndPerViewFiltersRequireTwoFrames(testCase)
            scene = ProjectionViewerMotionWorkflowTest.makeScene();
            scene.layers(1).PassId = "pass-a";
            scene.layers(2).PassId = "pass-a";
            scene.layers(3).PassId = "pass-b";
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            ProjectionViewerMotionWorkflowTest.openMotionWindow();
            window = ProjectionViewerMotionWorkflowTest.motionWindow();
            pass = ProjectionViewerMotionWorkflowTest.tagged( ...
                window, "ProjectionViewerMotionPassDropDown");
            start = ProjectionViewerMotionWorkflowTest.tagged( ...
                window, "ProjectionViewerMotionStartExitButton");
            status = ProjectionViewerMotionWorkflowTest.tagged( ...
                window, "ProjectionViewerMotionStatusLabel");

            pass.Value = "pass-b";
            pass.ValueChangedFcn(pass, struct());
            testCase.verifyEqual(string(start.Enable), "off");
            testCase.verifySubstring(string(status.Text), "at least two");

            pass.Value = "pass-a";
            pass.ValueChangedFcn(pass, struct());
            testCase.verifyEqual(string(start.Enable), "on");
            tableControl = ProjectionViewerMotionWorkflowTest.tagged( ...
                window, "ProjectionViewerMotionTable");
            data = tableControl.Data;
            data.Include(2) = false;
            tableControl.Data = data;
            tableControl.CellEditCallback(tableControl, struct());
            testCase.verifyEqual(string(start.Enable), "off");
        end

        function testSteppingUsesOneFrameAndExitRestoresExactState(testCase)
            scene = ProjectionViewerMotionWorkflowTest.makeScene();
            scene.layers(1).Visible = false;
            scene.layers(2).Alpha = 0.55;
            scene.layers(2).BlendMode = "redBlueAnaglyph";
            scene.layers(3).BlendMode = "redBlueAnaglyph";
            scene.layers(3).ProjectionOffsetMeters = [0.4; -0.2];
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            viewer = ProjectionViewerMotionWorkflowTest.viewer();
            axes = findall(viewer, "Type", "axes");
            before = app.exportState();
            ProjectionViewerMotionWorkflowTest.openAndStartMotion(testCase);
            first = app.motionDiagnostics();

            testCase.verifyTrue(first.Active);
            testCase.verifyEqual(nnz(first.EffectiveVisibility), 1);
            testCase.verifyEqual(first.KeyboardMode, "motion");
            testCase.verifyEqual(app.exportState().Camera, before.Camera);
            scientificBefore = app.exportState().Layers;
            viewer.CurrentObject = axes;
            viewer.WindowKeyPressFcn(viewer, ...
                ProjectionViewerMotionWorkflowTest.keyEvent("rightarrow"));
            second = app.motionDiagnostics();
            viewer.WindowKeyPressFcn(viewer, ...
                ProjectionViewerMotionWorkflowTest.keyEvent("uparrow"));
            afterReserved = app.exportState();

            testCase.verifyEqual(second.Position, 2);
            testCase.verifyEqual(afterReserved.Layers, scientificBefore);
            viewer.WindowKeyPressFcn(viewer, ...
                ProjectionViewerMotionWorkflowTest.keyEvent("rightarrow"));
            viewer.WindowKeyPressFcn(viewer, ...
                ProjectionViewerMotionWorkflowTest.keyEvent("rightarrow"));
            testCase.verifyEqual(app.motionDiagnostics().Position, 3);

            viewer.WindowKeyPressFcn(viewer, ...
                ProjectionViewerMotionWorkflowTest.keyEvent("escape"));
            testCase.verifyEqual(app.exportState(), before);
            testCase.verifyFalse(app.motionDiagnostics().Active);
        end

        function testLoopIdentityPinAndPersistentButtons(testCase)
            scene = ProjectionViewerMotionWorkflowTest.makeScene();
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            ProjectionViewerMotionWorkflowTest.openAndStartMotion(testCase);
            window = ProjectionViewerMotionWorkflowTest.motionWindow();
            viewer = ProjectionViewerMotionWorkflowTest.viewer();
            identity = ProjectionViewerMotionWorkflowTest.tagged( ...
                viewer, "ProjectionViewerMotionIdentityLabel");
            loop = ProjectionViewerMotionWorkflowTest.tagged( ...
                window, "ProjectionViewerMotionLoopCheckBox");
            hover = ProjectionViewerMotionWorkflowTest.tagged( ...
                window, "ProjectionViewerMotionHoverCheckBox");
            pin = ProjectionViewerMotionWorkflowTest.tagged( ...
                window, "ProjectionViewerMotionPinCheckBox");

            testCase.verifyEqual(string(identity.Visible), "on");
            testCase.verifySubstring(string(identity.Text), "1/3");
            pin.Value = true;
            pin.ValueChangedFcn(pin, struct());
            hover.Value = false;
            hover.ValueChangedFcn(hover, struct());
            left = ProjectionViewerMotionWorkflowTest.tagged( ...
                viewer, "ProjectionViewerMotionLeftEdgeButton");
            right = ProjectionViewerMotionWorkflowTest.tagged( ...
                viewer, "ProjectionViewerMotionRightEdgeButton");
            testCase.verifyEqual(string([left.Visible right.Visible]), ...
                ["on" "on"]);

            loop.Value = true;
            loop.ValueChangedFcn(loop, struct());
            next = ProjectionViewerMotionWorkflowTest.tagged( ...
                window, "ProjectionViewerMotionNextButton");
            testCase.press(next);
            testCase.press(next);
            testCase.press(next);
            diagnostics = app.motionDiagnostics();
            testCase.verifyEqual(diagnostics.Position, 1);
            testCase.verifyTrue(diagnostics.IdentityPinned);
            testCase.verifyEqual(string(identity.Visible), "on");
        end

        function testFallbackWarningRemainsVisible(testCase)
            scene = ProjectionViewerMotionWorkflowTest.makeScene();
            scene.layers(1).AcquisitionStartTime = 1;
            scene.layers(2).AcquisitionStartTime = ...
                datetime(2026, 1, 1, TimeZone="UTC");
            scene.layers(3).AcquisitionStartTime = [];
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            ProjectionViewerMotionWorkflowTest.openAndStartMotion(testCase);
            diagnostics = app.motionDiagnostics();
            status = ProjectionViewerMotionWorkflowTest.tagged( ...
                ProjectionViewerMotionWorkflowTest.motionWindow(), ...
                "ProjectionViewerMotionStatusLabel");

            testCase.verifyNotEmpty(diagnostics.Warning);
            testCase.verifySubstring(string(status.Text), "Warning:");
            testCase.verifyTrue(diagnostics.Sequence.UsedStableFallback);
        end

        function testHoverUpdatesAvoidGeometryAndTileWork(testCase)
            scene = ProjectionViewerMotionWorkflowTest.makeScene();
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            ProjectionViewerMotionWorkflowTest.openAndStartMotion(testCase);
            viewer = ProjectionViewerMotionWorkflowTest.viewer();
            axes = findall(viewer, "Type", "axes");
            position = getpixelposition(axes, true);
            app.resetPerformanceDiagnostics();

            viewer.CurrentPoint = [position(1) + 2, ...
                position(2) + position(4) / 2];
            viewer.WindowButtonMotionFcn(viewer, struct());
            viewer.CurrentPoint = position(1:2) + position(3:4) / 2;
            viewer.WindowButtonMotionFcn(viewer, struct());
            viewer.CurrentPoint = [position(1) + position(3) - 2, ...
                position(2) + position(4) / 2];
            viewer.WindowButtonMotionFcn(viewer, struct());
            performance = app.performanceDiagnostics();

            testCase.verifyEqual(performance.Counters.MeshBuilds, 0);
            testCase.verifyEqual(performance.Counters.TileRefreshes, 0);
            testCase.verifyEqual(performance.Counters.SurfaceCreations, 0);
            testCase.verifyEqual( ...
                performance.Counters.PointerMotionCallbacks, 3);
            testCase.verifyGreaterThanOrEqual( ...
                performance.Counters.MotionHoverStateChanges, 2);
            testCase.verifyEqual( ...
                performance.Timings.MotionHoverSeconds.Count, 3);
        end

        function testDeleteAfterExternalViewerCloseIsWarningFree(testCase)
            app = ProjectionViewerApp( ...
                ProjectionViewerMotionWorkflowTest.makeScene());
            ProjectionViewerMotionWorkflowTest.openAndStartMotion(testCase);
            delete(ProjectionViewerMotionWorkflowTest.viewer());

            testCase.verifyWarningFree(@() delete(app));
        end
    end

    methods (Static, Access = private)
        function scene = makeScene()
            images = {uint8(ones(8, 9)), uint8(2 * ones(8, 9)), ...
                uint8(3 * ones(8, 9))};
            scene = ProjectionViewerHarness.createSceneFromImages( ...
                images, ["motion-1.tif" "motion-2.tif" "motion-3.tif"], ...
                struct(RowStride=2, ColumnStride=2));
            for index = 1:3
                scene.layers(index).ViewId = "motion-view-" + string(index);
                scene.layers(index).PassId = "motion-pass";
                scene.layers(index).AcquisitionStartTime = index;
            end
            scene = ProjectionViewMetadata.ensureScene(scene);
        end

        function openMotionWindow()
            menu = findall(groot, "Tag", ...
                "ProjectionViewerMotionImageryMenuItem");
            menu(1).MenuSelectedFcn(menu(1), struct());
            drawnow
        end

        function openAndStartMotion(testCase)
            ProjectionViewerMotionWorkflowTest.openMotionWindow();
            start = ProjectionViewerMotionWorkflowTest.tagged( ...
                ProjectionViewerMotionWorkflowTest.motionWindow(), ...
                "ProjectionViewerMotionStartExitButton");
            testCase.press(start);
            drawnow
        end

        function figureHandle = viewer()
            figures = findall(groot, "Type", "figure", ...
                "Name", "Sightline Workbench");
            figureHandle = figures(1);
        end

        function figureHandle = motionWindow()
            figures = findall(groot, "Tag", ...
                "ProjectionViewerMotionFigure");
            figureHandle = figures(1);
        end

        function component = tagged(parent, tag)
            components = findall(parent, "Tag", tag);
            component = components(1);
        end

        function event = keyEvent(key)
            event = struct(Key=key, Modifier=strings(1, 0));
        end

        function closeFigures()
            delete(findall(groot, "Type", "figure", ...
                "Name", "Sightline Workbench"));
            delete(findall(groot, "Tag", ...
                "ProjectionViewerMotionFigure"));
        end
    end
end
