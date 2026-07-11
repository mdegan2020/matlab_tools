classdef ProjectionViewerStereoEyeWorkflowTest < matlab.uitest.TestCase
    %ProjectionViewerStereoEyeWorkflowTest Tests MI-3 eye controls.

    methods (TestClassSetup)
        function addSourceToPath(testCase)
            projectRoot = fileparts(fileparts(mfilename("fullpath")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(projectRoot, "src")));
        end
    end

    methods (TestMethodSetup)
        function closeExistingFigures(testCase)
            ProjectionViewerStereoEyeWorkflowTest.closeFigures();
            testCase.addTeardown( ...
                @ProjectionViewerStereoEyeWorkflowTest.closeFigures);
        end
    end

    methods (Test)
        function testRoleSwapKeepsPhysicalEyesAndRedChannel(testCase)
            [app, viewer, workbench] = ...
                ProjectionViewerStereoEyeWorkflowTest.openWorkbench();
            testCase.addTeardown(@() delete(app));
            swapRoles = ProjectionViewerStereoEyeWorkflowTest.findTagged( ...
                workbench, "ProjectionViewerAlignmentSwapPairButton");
            before = app.alignmentDiagnostics();
            redLayerBefore = ...
                ProjectionViewerStereoEyeWorkflowTest.redLayerIndex(viewer);
            stateBefore = app.exportState();
            app.resetPerformanceDiagnostics();

            testCase.press(swapRoles);
            drawnow

            after = app.alignmentDiagnostics();
            performance = app.performanceDiagnostics();
            testCase.verifyEqual(after.ActivePair.PairId, ...
                before.ActivePair.PairId);
            testCase.verifyEqual(after.StereoEyes.LeftViewId, ...
                before.StereoEyes.LeftViewId);
            testCase.verifyEqual(after.StereoEyes.RightViewId, ...
                before.StereoEyes.RightViewId);
            testCase.verifyEqual( ...
                ProjectionViewerStereoEyeWorkflowTest.redLayerIndex(viewer), ...
                redLayerBefore);
            testCase.verifyEqual(app.exportState(), stateBefore);
            testCase.verifyEqual( ...
                performance.Counters.LayerGeometryRefreshes, 0);
            testCase.verifyEqual(performance.Counters.SampleFcnCalls, 0);
        end

        function testLayerReorderKeepsViewIdentityEyes(testCase)
            [app, viewer] = ...
                ProjectionViewerStereoEyeWorkflowTest.openWorkbench();
            testCase.addTeardown(@() delete(app));
            moveDown = ProjectionViewerStereoEyeWorkflowTest.findTagged( ...
                viewer, "ProjectionViewerMoveLayerDownButton");
            before = app.alignmentDiagnostics();
            redLayerBefore = ...
                ProjectionViewerStereoEyeWorkflowTest.redLayerIndex(viewer);

            testCase.press(moveDown);
            drawnow

            after = app.alignmentDiagnostics();
            redLayerAfter = ...
                ProjectionViewerStereoEyeWorkflowTest.redLayerIndex(viewer);
            testCase.verifyEqual(after.StereoEyes.LeftViewId, ...
                before.StereoEyes.LeftViewId);
            testCase.verifyEqual(after.StereoEyes.RightViewId, ...
                before.StereoEyes.RightViewId);
            testCase.verifyNotEqual(redLayerAfter, redLayerBefore);
        end

        function testManualEyeSwapResetIsRuntimeOnly(testCase)
            [app, viewer, workbench] = ...
                ProjectionViewerStereoEyeWorkflowTest.openWorkbench();
            testCase.addTeardown(@() delete(app));
            swapEyes = ProjectionViewerStereoEyeWorkflowTest.findTagged( ...
                workbench, "ProjectionViewerAlignmentSwapEyesButton");
            resetEyes = ProjectionViewerStereoEyeWorkflowTest.findTagged( ...
                workbench, "ProjectionViewerAlignmentResetEyesButton");
            eyeStatus = ProjectionViewerStereoEyeWorkflowTest.findTagged( ...
                workbench, "ProjectionViewerAlignmentStereoEyeStatusLabel");
            stateBefore = app.exportState();
            automatic = app.alignmentDiagnostics().StereoEyes;
            redLayerBefore = ...
                ProjectionViewerStereoEyeWorkflowTest.redLayerIndex(viewer);

            testCase.press(swapEyes);
            drawnow

            manual = app.alignmentDiagnostics().StereoEyes;
            redLayerManual = ...
                ProjectionViewerStereoEyeWorkflowTest.redLayerIndex(viewer);
            testCase.verifyTrue(manual.ManualOverride);
            testCase.verifyEqual(manual.LeftViewId, automatic.RightViewId);
            testCase.verifyNotEqual(redLayerManual, redLayerBefore);
            testCase.verifyTrue(contains(string(eyeStatus.Text), ...
                "manual override"));
            testCase.verifyEqual(resetEyes.Enable, ...
                matlab.lang.OnOffSwitchState.on);
            testCase.verifyEqual(app.exportState(), stateBefore);

            testCase.press(resetEyes);
            drawnow

            reset = app.alignmentDiagnostics().StereoEyes;
            testCase.verifyFalse(reset.ManualOverride);
            testCase.verifyEqual(reset.LeftViewId, automatic.LeftViewId);
            testCase.verifyEqual( ...
                ProjectionViewerStereoEyeWorkflowTest.redLayerIndex(viewer), ...
                redLayerBefore);
            testCase.verifyEqual(app.exportState(), stateBefore);
        end

        function testMissingRepresentativeOriginUsesSafeFallback(testCase)
            scene = ProjectionViewerStereoEyeWorkflowTest.makeScene();
            scene.layers(1).SourceGeometry.ReferenceOrigin = nan(3, 1);
            scene.layers(2).SourceGeometry.ReferenceOrigin = nan(3, 1);

            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow
            viewer = findall(groot, "Type", "figure", ...
                "Name", "Sightline Workbench");
            diagnostics = app.alignmentDiagnostics();

            testCase.verifyEqual( ...
                ProjectionViewerStereoEyeWorkflowTest.redLayerIndex(viewer(1)), 1);
            testCase.verifyEqual(diagnostics.StereoEyes.Status, "unavailable");
        end
    end

    methods (Static, Access = private)
        function [app, viewer, workbench] = openWorkbench()
            app = ProjectionViewerApp( ...
                ProjectionViewerStereoEyeWorkflowTest.makeScene());
            drawnow
            viewer = findall(groot, "Type", "figure", ...
                "Name", "Sightline Workbench");
            viewer = viewer(1);
            menuItem = findall(viewer, "Tag", ...
                "ProjectionViewerAlignmentPanelMenuItem");
            menuItem.MenuSelectedFcn(menuItem, struct());
            drawnow
            launcher = findall(viewer, "Tag", ...
                "ProjectionViewerAlignmentOpenWorkbenchButton");
            launcher.ButtonPushedFcn(launcher, struct());
            drawnow
            workbench = findall(groot, "Type", "figure", ...
                "Name", "Alignment Workbench");
            workbench = workbench(1);
        end

        function scene = makeScene()
            imageA = uint8(repmat(reshape(1:60, 4, 5, 3), 4, 4, 1));
            imageB = uint8(repmat(reshape(61:120, 4, 5, 3), 4, 4, 1));
            scene = ProjectionViewerHarness.createSceneFromImages( ...
                {imageA, imageB}, ["eye-a.tif" "eye-b.tif"], ...
                struct(RowStride=4, ColumnStride=4));
            scene.layers(1).ViewId = "view-a";
            scene.layers(2).ViewId = "view-b";
            scene.layers(1).SourceGeometry.ReferenceOrigin = [0; -2; 0];
            scene.layers(2).SourceGeometry.ReferenceOrigin = [0; 2; 0];
            scene.layers(1).BlendMode = "redBlueAnaglyph";
            scene.layers(2).BlendMode = "redBlueAnaglyph";
            scene = ProjectionViewMetadata.ensureScene(scene);
        end

        function layerIndex = redLayerIndex(viewer)
            axesHandle = findall(viewer, "Type", "axes");
            surfaces = findall(axesHandle, "Type", "surface", ...
                "Tag", "ProjectionViewerLayerSurface");
            surfaces = flip(reshape(surfaces, 1, []));
            firstMean = squeeze(mean(surfaces(1).CData, [1 2]));
            secondMean = squeeze(mean(surfaces(2).CData, [1 2]));
            dominance = [firstMean(1) - firstMean(3), ...
                secondMean(1) - secondMean(3)];
            [~, layerIndex] = max(dominance);
        end

        function component = findTagged(parent, tag)
            component = findall(parent, "Tag", tag);
            component = component(1);
        end

        function closeFigures()
            delete(findall(groot, "Type", "figure", ...
                "Name", "Alignment Workbench"));
            delete(findall(groot, "Type", "figure", ...
                "Name", "Sightline Workbench"));
        end
    end
end
