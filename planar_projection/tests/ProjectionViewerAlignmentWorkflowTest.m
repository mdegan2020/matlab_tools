classdef ProjectionViewerAlignmentWorkflowTest < matlab.unittest.TestCase
    %ProjectionViewerAlignmentWorkflowTest Tests viewer alignment controls.

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
            delete(findall(groot, "Type", "figure", ...
                "Name", "Projection Viewer Prototype"));
            testCase.addTeardown(@() delete(findall(groot, "Type", "figure", ...
                "Name", "Projection Viewer Prototype")));
        end
    end

    methods (Test)
        function testAlignmentControlsExistWithTwoLayerDefaults(testCase)
            scene = ProjectionViewerAlignmentWorkflowTest.makeTexturedScene(false);
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow

            fig = ProjectionViewerAlignmentWorkflowTest.findViewerFigure();
            referenceDropDown = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentReferenceDropDown");
            movingDropDown = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentMovingDropDown");
            presetDropDown = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentPresetDropDown");
            scopeDropDown = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentScopeDropDown");
            detectorDropDown = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentDetectorDropDown");
            lossDropDown = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentLossDropDown");
            roiButton = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentRoiButton");
            clearRoiButton = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentClearRoiButton");
            clearOverlaysButton = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentClearOverlaysButton");
            matchButton = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentMatchButton");
            solveButton = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentSolveButton");
            cancelButton = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentCancelButton");
            previewButton = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentPreviewButton");
            applyButton = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentApplyButton");
            revertButton = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentRevertButton");
            clearOverlaysMenuItem = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerClearAlignmentOverlaysMenuItem");
            pairTable = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentPairTable");

            testCase.verifyEqual(str2double(string(referenceDropDown.Value)), 1);
            testCase.verifyEqual(str2double(string(movingDropDown.Value)), 2);
            testCase.verifyEqual(string(presetDropDown.Value), "fast");
            testCase.verifyEqual(string(scopeDropDown.Value), "selectedPair");
            testCase.verifyEqual(string(detectorDropDown.Value), "auto");
            testCase.verifyEqual(string(lossDropDown.Value), "projectionPlane2D");
            testCase.verifyEqual(string(roiButton.Enable), "on");
            testCase.verifyEqual(string(clearRoiButton.Enable), "on");
            testCase.verifyEqual(string(clearOverlaysButton.Enable), "on");
            testCase.verifyEqual(string(matchButton.Enable), "on");
            testCase.verifyEqual(string(solveButton.Enable), "off");
            testCase.verifyEqual(string(cancelButton.Enable), "off");
            testCase.verifyEqual(string(previewButton.Enable), "off");
            testCase.verifyEqual(string(applyButton.Enable), "off");
            testCase.verifyEqual(string(revertButton.Enable), "off");
            testCase.verifyEqual(string(clearOverlaysMenuItem.Text), ...
                "Clear alignment overlays");
            testCase.verifyEqual(height(pairTable.Data), 1);
            testCase.verifyTrue(pairTable.Data.Enabled(1));
            testCase.verifyEqual(string(pairTable.Data.Pair(1)), "2 -> 1");
            testCase.verifyTrue(all(ismember(["Matches", "Inliers", "Confidence"], ...
                string(pairTable.Data.Properties.VariableNames))));
        end

        function testPairTableCanDisableAlignmentPairs(testCase)
            scene = ProjectionViewerAlignmentWorkflowTest.makeTexturedScene(false);
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow

            fig = ProjectionViewerAlignmentWorkflowTest.findViewerFigure();
            pairTable = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentPairTable");
            matchButton = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentMatchButton");
            statusLabel = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentStatusLabel");
            data = pairTable.Data;
            data.Enabled(:) = false;
            pairTable.Data = data;

            matchButton.ButtonPushedFcn(matchButton, struct());
            drawnow

            testCase.verifyTrue(contains(string(statusLabel.Text), ...
                "No enabled alignment pairs"));
        end

        function testAlignmentDiagnosticsReportsSamplerAndMeshCost(testCase)
            scene = ProjectionViewerAlignmentWorkflowTest.makeTexturedScene(false);
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow

            diagnostics = app.alignmentDiagnostics();

            testCase.verifyEqual(diagnostics.LayerCount, 2);
            testCase.verifyEqual(diagnostics.EnabledPairs, [2 1]);
            testCase.verifyEqual(diagnostics.EnabledPairCount, 1);
            testCase.verifyTrue(diagnostics.AllLayersHaveObservationRaySampler);
            testCase.verifyEqual([diagnostics.Layers.DefaultMeshVertexCount], ...
                [6400 6400]);
            testCase.verifyEqual(diagnostics.RenderOptions.OutputSize, [512 512]);
        end

        function testRoiButtonDrawsProjectionPlaneRectangle(testCase)
            scene = ProjectionViewerAlignmentWorkflowTest.makeTexturedScene(false);
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow

            fig = ProjectionViewerAlignmentWorkflowTest.findViewerFigure();
            ax = findall(fig, "Type", "axes");
            roiButton = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentRoiButton");
            clearRoiButton = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentClearRoiButton");
            statusLabel = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentStatusLabel");

            roiButton.ButtonPushedFcn(roiButton, struct());
            drawnow

            roiLine = findall(fig, "Tag", "ProjectionViewerAlignmentRoi");
            testCase.verifyNumElements(roiLine, 1);
            testCase.verifyEqual(string(roiLine.Type), "line");
            testCase.verifyNumElements(roiLine.XData, 5);
            testCase.verifyEqual(roiLine.XData(1), roiLine.XData(end), ...
                AbsTol=ProjectionViewerAlignmentWorkflowTest.Tol);
            testCase.verifyEqual(roiLine.YData(1), roiLine.YData(end), ...
                AbsTol=ProjectionViewerAlignmentWorkflowTest.Tol);
            testCase.verifyEqual(roiLine.ZData(1), roiLine.ZData(end), ...
                AbsTol=ProjectionViewerAlignmentWorkflowTest.Tol);
            testCase.verifyTrue(all(isfinite(roiLine.XData)));
            testCase.verifyTrue(all(isfinite(roiLine.YData)));
            testCase.verifyTrue(all(isfinite(roiLine.ZData)));
            testCase.verifyTrue(all(roiLine.XData >= ax.XLim(1) & ...
                roiLine.XData <= ax.XLim(2)));
            testCase.verifyTrue(all(roiLine.YData >= ax.YLim(1) & ...
                roiLine.YData <= ax.YLim(2)));
            testCase.verifyTrue(contains(string(statusLabel.Text), "ROI active"));

            clearRoiButton.ButtonPushedFcn(clearRoiButton, struct());
            drawnow

            testCase.verifyEmpty(findall(fig, "Tag", ...
                "ProjectionViewerAlignmentRoi"));
            testCase.verifyTrue(contains(string(statusLabel.Text), ...
                "ROI cleared"));
        end

        function testAlignmentMatchSolvePreviewApplyAndRevertThroughControls(testCase)
            capabilities = ProjectionAlignmentFeatureMatcher.capabilities();
            testCase.assumeTrue(ismember("sift", capabilities.AvailableDetectors));
            testCase.assumeTrue(exist("lsqnonlin", "file") == 2);

            scene = ProjectionViewerAlignmentWorkflowTest.makeTexturedScene(true);
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow

            fig = ProjectionViewerAlignmentWorkflowTest.findViewerFigure();
            referenceDropDown = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentReferenceDropDown");
            movingDropDown = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentMovingDropDown");
            detectorDropDown = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentDetectorDropDown");
            matchButton = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentMatchButton");
            solveButton = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentSolveButton");
            previewButton = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentPreviewButton");
            applyButton = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentApplyButton");
            revertButton = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentRevertButton");
            clearOverlaysButton = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentClearOverlaysButton");
            clearOverlaysMenuItem = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerClearAlignmentOverlaysMenuItem");
            statusLabel = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentStatusLabel");

            referenceDropDown.Value = "1";
            movingDropDown.Value = "2";
            detectorDropDown.Value = "sift";
            stateBefore = app.exportState();

            matchButton.ButtonPushedFcn(matchButton, struct());
            drawnow

            stateAfterMatch = app.exportState();
            diagnosticsAfterMatch = app.alignmentDiagnostics();
            testCase.verifyEqual(string(solveButton.Enable), "on");
            testCase.verifyEqual(string(previewButton.Enable), "off");
            testCase.verifyEqual(string(applyButton.Enable), "off");
            testCase.verifyEqual(string(revertButton.Enable), "off");
            testCase.verifyTrue(contains(string(statusLabel.Text), ...
                "Ready to solve"));
            testCase.verifyTrue(diagnosticsAfterMatch.Stage.HasRequest);
            testCase.verifyTrue(diagnosticsAfterMatch.Stage.HasWorkingImages);
            testCase.verifyTrue(diagnosticsAfterMatch.Stage.HasRawMatches);
            testCase.verifyTrue(diagnosticsAfterMatch.Stage.HasFilteredMatches);
            testCase.verifyFalse(diagnosticsAfterMatch.Stage.HasSolveResult);
            testCase.verifyGreaterThan( ...
                diagnosticsAfterMatch.Stage.FilteredMatchCount, 0);
            testCase.verifyEqual( ...
                ProjectionViewerAlignmentWorkflowTest.viewVectorOffsets( ...
                stateAfterMatch), ...
                ProjectionViewerAlignmentWorkflowTest.viewVectorOffsets( ...
                stateBefore), ...
                AbsTol=ProjectionViewerAlignmentWorkflowTest.Tol);
            testCase.verifyNotEmpty(findall(fig, "Tag", ...
                "ProjectionViewerAlignmentMatchOverlay"));

            solveButton.ButtonPushedFcn(solveButton, struct());
            drawnow

            stateAfterSolve = app.exportState();
            diagnosticsAfterSolve = app.alignmentDiagnostics();
            testCase.verifyEqual(string(previewButton.Enable), "on");
            testCase.verifyEqual(string(applyButton.Enable), "on");
            testCase.verifyEqual(string(revertButton.Enable), "on");
            testCase.verifyTrue(contains(string(statusLabel.Text), "RMS"));
            testCase.verifyTrue(diagnosticsAfterSolve.Stage.HasSolveResult);
            testCase.verifyEqual( ...
                ProjectionViewerAlignmentWorkflowTest.viewVectorOffsets(stateAfterSolve), ...
                ProjectionViewerAlignmentWorkflowTest.viewVectorOffsets(stateBefore), ...
                AbsTol=ProjectionViewerAlignmentWorkflowTest.Tol);
            testCase.verifyNotEmpty(findall(fig, "Tag", ...
                "ProjectionViewerAlignmentMatchOverlay"));
            testCase.verifyNotEmpty(findall(fig, "Tag", ...
                "ProjectionViewerAlignmentReferenceInlierOverlay"));

            clearOverlaysMenuItem.MenuSelectedFcn(clearOverlaysMenuItem, struct());
            drawnow
            stateAfterContextClear = app.exportState();
            testCase.verifyEmpty(findall(fig, "Tag", ...
                "ProjectionViewerAlignmentMatchOverlay"));
            testCase.verifyEmpty(findall(fig, "Tag", ...
                "ProjectionViewerAlignmentMovingInlierOverlay"));
            testCase.verifyEmpty(findall(fig, "Tag", ...
                "ProjectionViewerAlignmentReferenceInlierOverlay"));
            testCase.verifyTrue(contains(string(statusLabel.Text), ...
                "overlays cleared"));
            testCase.verifyEqual( ...
                ProjectionViewerAlignmentWorkflowTest.viewVectorOffsets( ...
                stateAfterContextClear), ...
                ProjectionViewerAlignmentWorkflowTest.viewVectorOffsets( ...
                stateAfterSolve), ...
                AbsTol=ProjectionViewerAlignmentWorkflowTest.Tol);
            testCase.verifyEqual(string(previewButton.Enable), "on");
            testCase.verifyEqual(string(applyButton.Enable), "on");
            testCase.verifyEqual(string(revertButton.Enable), "on");

            previewButton.ButtonPushedFcn(previewButton, struct());
            drawnow
            statePreview = app.exportState();
            testCase.verifyGreaterThan(norm( ...
                ProjectionViewerAlignmentWorkflowTest.viewVectorOffsets(statePreview) - ...
                ProjectionViewerAlignmentWorkflowTest.viewVectorOffsets(stateBefore), ...
                "fro"), 1e-5);
            testCase.verifyNotEmpty(findall(fig, "Tag", ...
                "ProjectionViewerAlignmentMatchOverlay"));

            clearOverlaysButton.ButtonPushedFcn(clearOverlaysButton, struct());
            drawnow
            stateAfterButtonClear = app.exportState();
            testCase.verifyEmpty(findall(fig, "Tag", ...
                "ProjectionViewerAlignmentMatchOverlay"));
            testCase.verifyEqual( ...
                ProjectionViewerAlignmentWorkflowTest.viewVectorOffsets( ...
                stateAfterButtonClear), ...
                ProjectionViewerAlignmentWorkflowTest.viewVectorOffsets( ...
                statePreview), ...
                AbsTol=ProjectionViewerAlignmentWorkflowTest.Tol);

            applyButton.ButtonPushedFcn(applyButton, struct());
            drawnow
            stateApplied = app.exportState();
            testCase.verifyEqual( ...
                ProjectionViewerAlignmentWorkflowTest.viewVectorOffsets(stateApplied), ...
                ProjectionViewerAlignmentWorkflowTest.viewVectorOffsets(statePreview), ...
                AbsTol=ProjectionViewerAlignmentWorkflowTest.Tol);

            revertButton.ButtonPushedFcn(revertButton, struct());
            drawnow
            stateReverted = app.exportState();
            testCase.verifyEqual( ...
                ProjectionViewerAlignmentWorkflowTest.viewVectorOffsets(stateReverted), ...
                ProjectionViewerAlignmentWorkflowTest.viewVectorOffsets(stateBefore), ...
                AbsTol=ProjectionViewerAlignmentWorkflowTest.Tol);
        end

        function testSolveReusesStoredMatchesAfterPairDisable(testCase)
            capabilities = ProjectionAlignmentFeatureMatcher.capabilities();
            testCase.assumeTrue(ismember("sift", capabilities.AvailableDetectors));
            testCase.assumeTrue(exist("lsqnonlin", "file") == 2);

            scene = ProjectionViewerAlignmentWorkflowTest.makeTexturedScene(true, 3);
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow

            fig = ProjectionViewerAlignmentWorkflowTest.findViewerFigure();
            scopeDropDown = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentScopeDropDown");
            detectorDropDown = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentDetectorDropDown");
            matchButton = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentMatchButton");
            solveButton = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentSolveButton");
            pairTable = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentPairTable");
            statusLabel = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentStatusLabel");

            scopeDropDown.Value = "visibleLayers";
            detectorDropDown.Value = "sift";
            matchButton.ButtonPushedFcn(matchButton, struct());
            drawnow
            diagnosticsAfterMatch = app.alignmentDiagnostics();
            data = pairTable.Data;
            data.Enabled(1) = false;
            pairTable.Data = data;

            solveButton.ButtonPushedFcn(solveButton, struct());
            drawnow
            diagnosticsAfterSolve = app.alignmentDiagnostics();
            dataAfterSolve = pairTable.Data;

            testCase.verifyGreaterThan(height(dataAfterSolve), 1);
            testCase.verifyTrue(any(~dataAfterSolve.Enabled));
            testCase.verifyTrue(contains(string(statusLabel.Text), "RMS"));
            testCase.verifyEqual(diagnosticsAfterSolve.Stage.RawMatchCount, ...
                diagnosticsAfterMatch.Stage.RawMatchCount);
            testCase.verifyGreaterThan( ...
                diagnosticsAfterMatch.Stage.FilteredMatchCount, ...
                diagnosticsAfterSolve.Stage.SolvedMatchCount);
        end

        function testRayToRayLossRunsThroughControls(testCase)
            capabilities = ProjectionAlignmentFeatureMatcher.capabilities();
            testCase.assumeTrue(ismember("sift", capabilities.AvailableDetectors));
            testCase.assumeTrue(exist("lsqnonlin", "file") == 2);

            scene = ProjectionViewerAlignmentWorkflowTest.makeTexturedScene(true);
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow

            fig = ProjectionViewerAlignmentWorkflowTest.findViewerFigure();
            detectorDropDown = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentDetectorDropDown");
            lossDropDown = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentLossDropDown");
            matchButton = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentMatchButton");
            solveButton = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentSolveButton");
            previewButton = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentPreviewButton");
            statusLabel = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentStatusLabel");

            detectorDropDown.Value = "sift";
            lossDropDown.Value = "rayToRay3D";
            matchButton.ButtonPushedFcn(matchButton, struct());
            drawnow
            solveButton.ButtonPushedFcn(solveButton, struct());
            drawnow

            testCase.verifyTrue(contains(string(statusLabel.Text), "RMS"));
            testCase.verifyEqual(string(matchButton.Enable), "on");
            testCase.verifyEqual(string(solveButton.Enable), "on");
            testCase.verifyEqual(string(previewButton.Enable), "on");
        end
    end

    methods (Static, Access = private)
        function scene = makeTexturedScene(includePerturbation, layerCount)
            if nargin < 2
                layerCount = 2;
            end
            [x, y] = meshgrid(1:80, 1:80);
            imageData = uint8(mod(3 * x + 5 * y + ...
                40 * sin(x / 3) + 30 * cos(y / 5), 256));
            imageList = repmat({imageData}, 1, layerCount);
            imagePaths = "layer" + string(1:layerCount) + ".tif";
            scene = ProjectionViewerHarness.createSceneFromImages( ...
                imageList, imagePaths, struct(RowStride=1, ColumnStride=1));
            if includePerturbation
                omegaOffsets = linspace(0.004, -0.004, layerCount);
                for layerIndex = 1:layerCount
                    scene.layers(layerIndex).ViewVectorAngularOffsetsDegrees = ...
                        [omegaOffsets(layerIndex); 0; 0];
                end
            end
        end

        function fig = findViewerFigure()
            fig = findall(groot, "Type", "figure", ...
                "Name", "Projection Viewer Prototype");
            fig = fig(1);
        end

        function component = findTagged(parent, tag)
            components = findall(parent, "Tag", tag);
            component = components(1);
        end

        function offsets = viewVectorOffsets(state)
            offsets = reshape([state.Layers.ViewVectorAngularOffsetsDegrees], ...
                3, []).';
        end
    end
end
