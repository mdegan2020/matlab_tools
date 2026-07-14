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
            originalRng = rng;
            testCase.addTeardown(@() rng(originalRng));
            rng("default");
            names = ["Sightline", "Alignment Workbench"];
            for name = names
                delete(findall(groot, "Type", "figure", "Name", name));
            end
            testCase.addTeardown(@() ...
                ProjectionViewerAlignmentWorkflowTest.closeAlignmentFigures());
        end
    end

    methods (Test)
        function testAlignmentControlsExistWithTwoLayerDefaults(testCase)
            scene = ProjectionViewerAlignmentWorkflowTest.makeTexturedScene(false);
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            app.setAlignmentReviewConfirmationFcn(@(~, ~) true);
            drawnow

            fig = ProjectionViewerAlignmentWorkflowTest.findViewerFigure();
            diagnostics = app.alignmentDiagnostics();
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
            pairGraphModeDropDown = ...
                ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentPairGraphModeDropDown");
            maxPairsSpinner = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentMaxPairsSpinner");
            allPairsCheckBox = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentAllPairsCheckBox");
            networkConfigurationDropDown = ...
                ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentNetworkConfigurationDropDown");
            lossDropDown = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentLossDropDown");
            coplanarityDropDown = ...
                ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentCoplanarityDropDown");
            referenceMotionCheckBox = ...
                ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentReferenceMotionCheckBox");
            roiButton = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentRoiButton");
            clearRoiButton = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentClearRoiButton");
            clearOverlaysButton = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentClearOverlaysButton");
            acceptedOverlayCheckBox = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentAcceptedOverlayCheckBox");
            rejectedOverlayCheckBox = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentRejectedOverlayCheckBox");
            worstOverlayCheckBox = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentWorstOverlayCheckBox");
            featureOverlayCheckBox = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentFeatureOverlayCheckBox");
            deleteMatchButton = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentDeleteMatchButton");
            undoCurationButton = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentUndoCurationButton");
            surfaceWorkbenchButton = ...
                ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentSurfaceWorkbenchButton");
            matchButton = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentMatchButton");
            filterButton = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentFilterButton");
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
            matchTable = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentMatchTable");

            testCase.verifyEqual(str2double(string(referenceDropDown.Value)), 1);
            testCase.verifyEqual(str2double(string(movingDropDown.Value)), 2);
            testCase.verifyEqual(string(presetDropDown.Value), "fast");
            testCase.verifyEqual(string(scopeDropDown.Value), "selectedPair");
            testCase.verifyEqual(string(detectorDropDown.Value), "auto");
            testCase.verifyEqual(string(pairGraphModeDropDown.Value), "balanced");
            testCase.verifyEqual(maxPairsSpinner.Value, 20);
            testCase.verifyFalse(allPairsCheckBox.Value);
            testCase.verifyEqual( ...
                string(networkConfigurationDropDown.Value), "multiplePasses");
            testCase.verifyEqual(string(lossDropDown.Value), "projectionPlane2D");
            testCase.verifyEqual(string(coplanarityDropDown.Value), "none");
            testCase.verifyTrue(referenceMotionCheckBox.Value);
            testCase.verifyTrue(ismember("epipolarCoplanarity", ...
                string(lossDropDown.ItemsData)));
            testCase.verifyTrue(ismember("robustMad", ...
                string(coplanarityDropDown.ItemsData)));
            testCase.verifyEqual(diagnostics.Request.FilterGeometricMethod, ...
                "similarity");
            testCase.verifyEqual( ...
                diagnostics.Request.FilterCoplanarityMethod, "none");
            testCase.verifyEqual( ...
                diagnostics.Request.FilterNativeDisplacementMethod, "none");
            testCase.verifyTrue(diagnostics.Request.AllowReferenceMotion);
            testCase.verifyEqual( ...
                diagnostics.Request.PairGraphQualitySpeed, "balanced");
            testCase.verifyEqual(diagnostics.Request.PairGraphMaxPairs, 20);
            testCase.verifyFalse( ...
                diagnostics.Request.PairGraphAllPlausiblePairs);
            testCase.verifyEqual( ...
                diagnostics.Request.NetworkConfiguration, "multiplePasses");
            testCase.verifyEqual(diagnostics.Request.KappaBoundDegrees, 15);
            testCase.verifyEqual( ...
                diagnostics.Request.SafeMinSolverObservationsPerPair, 3);
            testCase.verifyEqual( ...
                diagnostics.Request.SafeMinPreferredObservationsPerPair, 10);
            testCase.verifyTrue(diagnostics.Request.SafeFailOnBoundHit);
            testCase.verifyEqual( ...
                diagnostics.Request. ...
                SafePreferredResidualImprovementFraction, 0.10, ...
                AbsTol=ProjectionViewerAlignmentWorkflowTest.Tol);
            testCase.verifyEqual(string(roiButton.Enable), "on");
            testCase.verifyEqual(string(clearRoiButton.Enable), "on");
            testCase.verifyEqual(string(clearOverlaysButton.Enable), "on");
            testCase.verifyTrue(acceptedOverlayCheckBox.Value);
            testCase.verifyFalse(rejectedOverlayCheckBox.Value);
            testCase.verifyFalse(worstOverlayCheckBox.Value);
            testCase.verifyTrue(featureOverlayCheckBox.Value);
            testCase.verifyEqual(string(deleteMatchButton.Enable), "on");
            testCase.verifyEqual(string(undoCurationButton.Enable), "on");
            testCase.verifyEmpty(findall(fig, "Tag", ...
                "ProjectionViewerAlignmentDenseSurfaceButton"));
            testCase.verifyEqual(string(surfaceWorkbenchButton.Text), ...
                "Surface Workbench...");
            testCase.verifyEqual(string(surfaceWorkbenchButton.Enable), "off");
            testCase.verifyEqual(string(matchButton.Enable), "on");
            testCase.verifyEqual(string(filterButton.Enable), "off");
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
            testCase.verifyTrue(all(ismember( ...
                ["RawMatches", "FilteredMatches", "Confidence"], ...
                string(pairTable.Data.Properties.VariableNames))));
            testCase.verifyEqual(height(matchTable.Data), 0);
            testCase.verifyTrue(all(ismember( ...
                ["Enabled", "Pair", "MatchIndex", "ResidualAfter", "State"], ...
                string(matchTable.Data.Properties.VariableNames))));
        end

        function testVisibleScopeUsesPairGraphControls(testCase)
            scene = ProjectionViewerAlignmentWorkflowTest.makeTexturedScene( ...
                false, 4);
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow

            fig = ProjectionViewerAlignmentWorkflowTest.findViewerFigure();
            scopeDropDown = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentScopeDropDown");
            graphModeDropDown = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentPairGraphModeDropDown");
            maxPairsSpinner = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentMaxPairsSpinner");
            allPairsCheckBox = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentAllPairsCheckBox");
            networkConfigurationDropDown = ...
                ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentNetworkConfigurationDropDown");

            graphModeDropDown.Value = "quality";
            maxPairsSpinner.Value = 3;
            allPairsCheckBox.Value = true;
            networkConfigurationDropDown.Value = ...
                "independentViewsCustomPriors";
            scopeDropDown.Value = "visibleLayers";
            scopeDropDown.ValueChangedFcn(scopeDropDown, struct());
            drawnow
            diagnostics = app.alignmentDiagnostics();

            testCase.verifyEqual( ...
                diagnostics.Request.SchedulingStrategy, "qualityGraph");
            testCase.verifyEqual( ...
                diagnostics.Request.LossMode, "epipolarCoplanarity");
            testCase.verifyEqual( ...
                diagnostics.Request.PairGraphQualitySpeed, "quality");
            testCase.verifyEqual(diagnostics.Request.PairGraphMaxPairs, 3);
            testCase.verifyTrue( ...
                diagnostics.Request.PairGraphAllPlausiblePairs);
            testCase.verifyEqual(diagnostics.Request.NetworkConfiguration, ...
                "independentViewsCustomPriors");
            testCase.verifyLessThanOrEqual(diagnostics.Schedule.PairCount, 3);
            testCase.verifyTrue(isfield( ...
                diagnostics.Schedule.Diagnostics, "PairGraph"));
            testCase.verifyTrue( ...
                diagnostics.Schedule.Diagnostics.PairGraph.BudgetLimited);
        end

        function testAlignmentWorkbenchUsesGroupedStagedLayout(testCase)
            scene = ProjectionViewerAlignmentWorkflowTest.makeTexturedScene(false);
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow

            fig = ProjectionViewerAlignmentWorkflowTest.findViewerFigure();
            setupPanel = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentSetupPanel");
            settingsPanel = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentSettingsPanel");
            workflowPanel = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentWorkflowPanel");
            pairPanel = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentPairPanel");
            matchPanel = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentMatchPanel");
            diagnosticsPanel = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentDiagnosticsPanel");
            matchButton = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentMatchButton");
            filterButton = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentFilterButton");
            solveButton = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentSolveButton");
            previewButton = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentPreviewButton");
            applyButton = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentApplyButton");
            revertButton = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentRevertButton");
            referenceMotion = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentReferenceMotionCheckBox");
            pairTable = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentPairTable");
            matchTable = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentMatchTable");
            diagnostics = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentDiagnosticsTextArea");

            activePanel = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentActivePairPanel");
            testCase.verifyEqual(activePanel.Layout.Row, 2);
            testCase.verifyEqual(setupPanel.Layout.Row, 3);
            testCase.verifyEqual(setupPanel.Layout.Column, 1);
            testCase.verifyEqual(settingsPanel.Layout.Row, 3);
            testCase.verifyEqual(settingsPanel.Layout.Column, 2);
            testCase.verifyEqual(workflowPanel.Layout.Row, 4);
            testCase.verifyEqual(workflowPanel.Layout.Column, [1 2]);
            testCase.verifyEqual(string(referenceMotion.Text), ...
                "Allow reference motion");
            testCase.verifyEqual([matchButton.Layout.Column ...
                filterButton.Layout.Column solveButton.Layout.Column ...
                previewButton.Layout.Column applyButton.Layout.Column ...
                revertButton.Layout.Column], 1:6);
            testCase.verifyEqual(matchButton.Parent, filterButton.Parent);
            testCase.verifyEqual(filterButton.Parent, solveButton.Parent);
            testCase.verifyEqual(pairTable.Parent.Parent, pairPanel);
            testCase.verifyEqual(matchTable.Parent.Parent, matchPanel);
            testCase.verifyEqual(diagnostics.Parent.Parent, diagnosticsPanel);
        end

        function testVisibleLayerSolveUsesGlobalNetworkEntryPoint(testCase)
            capabilities = ProjectionAlignmentFeatureMatcher.capabilities();
            testCase.assumeTrue(ismember("sift", capabilities.AvailableDetectors));
            testCase.assumeTrue(exist("lsqnonlin", "file") == 2);
            scene = ProjectionViewerAlignmentWorkflowTest.makeTexturedScene( ...
                true, 3);
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

            detectorDropDown.Value = "sift";
            scopeDropDown.Value = "visibleLayers";
            scopeDropDown.ValueChangedFcn(scopeDropDown, struct());
            matchButton.ButtonPushedFcn(matchButton, struct());
            drawnow
            workbench = findall(groot, "Tag", ...
                "ProjectionViewerAlignmentWorkbench");
            rawRows = height(ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentMatchTable").Data);
            ProjectionViewerAlignmentWorkflowTest.hideAndReopenWorkbench(app);
            testCase.verifyEqual(height( ...
                ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentMatchTable").Data), rawRows);
            testCase.verifyEqual(findall(groot, "Tag", ...
                "ProjectionViewerAlignmentWorkbench"), workbench);
            ProjectionViewerAlignmentWorkflowTest.filterMatches();
            solveButton.ButtonPushedFcn(solveButton, struct());
            drawnow
            diagnostics = app.alignmentDiagnostics();

            testCase.verifyEqual( ...
                diagnostics.LastSolve.RequestSummary.SolverMode, ...
                "globalConstantOpkNetwork");
            testCase.verifyEqual(diagnostics.LastSolve.LossMode, ...
                "epipolarCoplanarity");
            testCase.verifyEqual(diagnostics.LastSolve.Network.Model, ...
                "globalConstantOpk");
            testCase.verifyTrue( ...
                diagnostics.LastSolve.Network.RayOriginsFixed);
            testCase.verifyEqual( ...
                diagnostics.Request.NetworkSensitivityPolicy, "deferred");
            testCase.verifyEqual( ...
                diagnostics.LastSolve.Network.LeaveOnePairOutSummary.State, ...
                "deferred");
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
            moveDownButton = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerMoveLayerDownButton");
            statusLabel = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentStatusLabel");
            data = pairTable.Data;
            data.Enabled(:) = false;
            pairTable.Data = data;

            moveDownButton.ButtonPushedFcn(moveDownButton, struct());
            drawnow

            testCase.verifyFalse(pairTable.Data.Enabled(1));
            testCase.verifyEqual(string(pairTable.Data.Pair(1)), "1 -> 2");

            matchButton.ButtonPushedFcn(matchButton, struct());
            drawnow

            testCase.verifyTrue(contains(string(statusLabel.Text), ...
                "No enabled alignment pairs"));
        end

        function testMatchAndFilterAreSeparateStages(testCase)
            capabilities = ProjectionAlignmentFeatureMatcher.capabilities();
            testCase.assumeTrue(ismember("sift", capabilities.AvailableDetectors));
            scene = ProjectionViewerAlignmentWorkflowTest.makeTexturedScene(false);
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow

            fig = ProjectionViewerAlignmentWorkflowTest.findViewerFigure();
            detector = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentDetectorDropDown");
            matchButton = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentMatchButton");
            filterButton = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentFilterButton");
            solveButton = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentSolveButton");
            detector.Value = "sift";

            matchButton.ButtonPushedFcn(matchButton, struct());
            drawnow
            afterMatch = app.alignmentDiagnostics();

            testCase.verifyEqual(afterMatch.Stage.Session.Stage, "matched");
            testCase.verifyFalse(afterMatch.Stage.Session.Stale.Match);
            testCase.verifyTrue(afterMatch.Stage.Session.Stale.Filter);
            testCase.verifyEqual(string(filterButton.Enable), "on");
            testCase.verifyEqual(string(solveButton.Enable), "off");

            filterButton.ButtonPushedFcn(filterButton, struct());
            drawnow
            afterFilter = app.alignmentDiagnostics();

            testCase.verifyEqual(afterFilter.Stage.Session.Stage, "curated");
            testCase.verifyFalse(afterFilter.Stage.Session.Stale.Filter);
            testCase.verifyEqual(string(solveButton.Enable), "on");
        end

        function testAlignmentDiagnosticsReportsSamplerAndMeshCost(testCase)
            scene = ProjectionViewerAlignmentWorkflowTest.makeTexturedScene(false);
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow

            ProjectionViewerAlignmentWorkflowTest.findViewerFigure();
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

            scene = ProjectionViewerAlignmentWorkflowTest.makeTexturedScene(true, 3);
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            app.setAlignmentReviewConfirmationFcn(@(~, ~) true);
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
            surfaceWorkbenchButton = ...
                ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentSurfaceWorkbenchButton");
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
            ProjectionViewerAlignmentWorkflowTest.filterMatches();

            stateAfterMatch = app.exportState();
            diagnosticsAfterMatch = app.alignmentDiagnostics();
            testCase.verifyEqual(string(solveButton.Enable), "on");
            testCase.verifyEqual(string(previewButton.Enable), "off");
            testCase.verifyEqual(string(applyButton.Enable), "off");
            testCase.verifyEqual(string(revertButton.Enable), "off");
            testCase.verifyEqual(string(surfaceWorkbenchButton.Enable), "off");
            testCase.verifyTrue(contains(string(statusLabel.Text), ...
                "Ready to solve"));
            testCase.verifyTrue(diagnosticsAfterMatch.Stage.HasRequest);
            testCase.verifyTrue(diagnosticsAfterMatch.Stage.HasWorkingImages);
            testCase.verifyTrue(diagnosticsAfterMatch.Stage.HasRawMatches);
            testCase.verifyTrue(diagnosticsAfterMatch.Stage.HasFilteredMatches);
            testCase.verifyFalse(diagnosticsAfterMatch.Stage.HasSolveResult);
            testCase.verifyEqual( ...
                diagnosticsAfterMatch.Stage.FeatureDiagnostics.Detector.Method, ...
                "sift");
            testCase.verifyEqual( ...
                diagnosticsAfterMatch.Stage.FeatureDiagnostics.Matcher.SearchMethod, ...
                "Exhaustive");
            testCase.verifyNotEmpty( ...
                diagnosticsAfterMatch.Stage.FilterDiagnostics);
            testCase.verifyEqual( ...
                diagnosticsAfterMatch.Stage.FilterDiagnostics.StageCounts.Initial, ...
                diagnosticsAfterMatch.Stage.RawMatchCount);
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
            filteredRows = height(ProjectionViewerAlignmentWorkflowTest. ...
                findTagged(fig, "ProjectionViewerAlignmentMatchTable").Data);
            ProjectionViewerAlignmentWorkflowTest.hideAndReopenWorkbench(app);
            testCase.verifyEqual(height( ...
                ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentMatchTable").Data), ...
                filteredRows);
            testCase.verifyEqual(string(solveButton.Enable), "on");

            solveButton.ButtonPushedFcn(solveButton, struct());
            drawnow

            stateAfterSolve = app.exportState();
            diagnosticsAfterSolve = app.alignmentDiagnostics();
            testCase.verifyEqual(string(previewButton.Enable), "on");
            testCase.verifyEqual(string(applyButton.Enable), "on");
            testCase.verifyEqual(string(revertButton.Enable), "off");
            testCase.verifyTrue(contains(string(statusLabel.Text), "RMS"));
            testCase.verifyTrue(diagnosticsAfterSolve.Stage.HasSolveResult);
            testCase.verifyEqual( ...
                ProjectionViewerAlignmentWorkflowTest.viewVectorOffsets(stateAfterSolve), ...
                ProjectionViewerAlignmentWorkflowTest.viewVectorOffsets(stateBefore), ...
                AbsTol=ProjectionViewerAlignmentWorkflowTest.Tol);
            testCase.verifyNotEmpty(findall(fig, "Tag", ...
                "ProjectionViewerAlignmentMatchOverlay"));
            testCase.verifyNotEmpty(findall(fig, "Tag", ...
                "ProjectionViewerAlignmentReferenceMatchOverlay"));
            ProjectionViewerAlignmentWorkflowTest.hideAndReopenWorkbench(app);
            testCase.verifyEqual(string(previewButton.Enable), "on");
            testCase.verifyEqual(string(applyButton.Enable), "on");
            testCase.verifyEqual(string(revertButton.Enable), "off");

            clearOverlaysMenuItem.MenuSelectedFcn(clearOverlaysMenuItem, struct());
            drawnow
            stateAfterContextClear = app.exportState();
            testCase.verifyEmpty(findall(fig, "Tag", ...
                "ProjectionViewerAlignmentMatchOverlay"));
            testCase.verifyEmpty(findall(fig, "Tag", ...
                "ProjectionViewerAlignmentMovingMatchOverlay"));
            testCase.verifyEmpty(findall(fig, "Tag", ...
                "ProjectionViewerAlignmentReferenceMatchOverlay"));
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
            testCase.verifyEqual(string(revertButton.Enable), "off");

            app.resetPerformanceDiagnostics();
            previewButton.ButtonPushedFcn(previewButton, struct());
            drawnow
            statePreview = app.exportState();
            previewPerformance = app.performanceDiagnostics();
            changedLayerCount = nnz(any(abs( ...
                ProjectionViewerAlignmentWorkflowTest.viewVectorOffsets( ...
                statePreview) - ...
                ProjectionViewerAlignmentWorkflowTest.viewVectorOffsets( ...
                stateBefore)) > ProjectionViewerAlignmentWorkflowTest.Tol, 2));
            testCase.verifyGreaterThan(norm( ...
                ProjectionViewerAlignmentWorkflowTest.viewVectorOffsets(statePreview) - ...
                ProjectionViewerAlignmentWorkflowTest.viewVectorOffsets(stateBefore), ...
                "fro"), 1e-5);
            testCase.verifyNotEmpty(findall(fig, "Tag", ...
                "ProjectionViewerAlignmentMatchOverlay"));
            testCase.verifyEqual( ...
                previewPerformance.Counters.LayerGeometryRefreshes, ...
                changedLayerCount);
            testCase.verifyLessThan(changedLayerCount, statePreview.LayerCount);
            testCase.verifyEqual( ...
                previewPerformance.Counters.SampleFcnCalls, 0);
            testCase.verifyEqual(string(surfaceWorkbenchButton.Enable), "on");
            testCase.verifyEqual(string(revertButton.Enable), "on");
            ProjectionViewerAlignmentWorkflowTest.hideAndReopenWorkbench(app);
            testCase.verifyEqual(string(revertButton.Enable), "on");
            testCase.verifyEqual(string(surfaceWorkbenchButton.Enable), "on");

            surfaceWorkbenchButton.ButtonPushedFcn( ...
                surfaceWorkbenchButton, struct());
            drawnow
            workbench = app.surfaceWorkbenchHandle();
            testCase.assertNotEmpty(workbench, string(statusLabel.Text));
            workbenchState = workbench.modelState();
            workbenchDiagnostics = workbench.diagnostics();
            focusedWorkbench = app.openSurfaceWorkbench();
            testCase.verifySameHandle(focusedWorkbench, workbench);
            testCase.verifyTrue(workbenchDiagnostics.RunnerBound);
            testCase.verifyNumElements(workbenchState.SelectedPairIds, 1);
            testCase.verifyEqual(workbenchState.PairSchedule, "quality");
            testCase.verifyNumElements( ...
                workbenchDiagnostics.Preflight.SelectedPairIds, 1);

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
            testCase.verifyEqual(string(surfaceWorkbenchButton.Enable), "on");
            ProjectionViewerAlignmentWorkflowTest.hideAndReopenWorkbench(app);
            testCase.verifyEqual(string(revertButton.Enable), "on");

            revertButton.ButtonPushedFcn(revertButton, struct());
            drawnow
            stateReverted = app.exportState();
            testCase.verifyEqual( ...
                ProjectionViewerAlignmentWorkflowTest.viewVectorOffsets(stateReverted), ...
                ProjectionViewerAlignmentWorkflowTest.viewVectorOffsets(stateBefore), ...
                AbsTol=ProjectionViewerAlignmentWorkflowTest.Tol);
            testCase.verifyEqual(string(surfaceWorkbenchButton.Enable), "off");

            resetButton = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentResetButton");
            resetButton.ButtonPushedFcn(resetButton, struct());
            drawnow
            testCase.verifyEqual(height( ...
                ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentMatchTable").Data), 0);
            testCase.verifyEqual(string(previewButton.Enable), "off");
            testCase.verifyEqual(string(applyButton.Enable), "off");
            testCase.verifyEqual(string(revertButton.Enable), "off");
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
            ProjectionViewerAlignmentWorkflowTest.filterMatches();
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

        function testMatchTableCanDisableMatchAndResolve(testCase)
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
            matchButton = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentMatchButton");
            solveButton = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentSolveButton");
            previewButton = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentPreviewButton");
            matchTable = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentMatchTable");
            rejectedOverlayCheckBox = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentRejectedOverlayCheckBox");
            worstOverlayCheckBox = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentWorstOverlayCheckBox");
            featureOverlayCheckBox = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentFeatureOverlayCheckBox");
            statusLabel = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentStatusLabel");

            detectorDropDown.Value = "sift";
            matchButton.ButtonPushedFcn(matchButton, struct());
            drawnow
            ProjectionViewerAlignmentWorkflowTest.filterMatches();
            dataAfterMatch = matchTable.Data;
            testCase.assumeTrue(height(dataAfterMatch) > 3);
            testCase.verifyTrue(all(dataAfterMatch.Enabled));
            testCase.verifyTrue(all(isnan(dataAfterMatch.ResidualAfter)));

            solveButton.ButtonPushedFcn(solveButton, struct());
            drawnow
            diagnosticsAfterFirstSolve = app.alignmentDiagnostics();
            dataAfterSolve = matchTable.Data;
            finiteResiduals = dataAfterSolve.ResidualAfter( ...
                isfinite(dataAfterSolve.ResidualAfter));
            testCase.verifyTrue(all(diff(finiteResiduals) <= 0));
            testCase.verifyEqual( ...
                diagnosticsAfterFirstSolve.Stage.SolvedMatchCount, ...
                diagnosticsAfterFirstSolve.Stage.FilteredMatchCount);

            worstOverlayCheckBox.Value = true;
            worstOverlayCheckBox.ValueChangedFcn(worstOverlayCheckBox, struct());
            drawnow
            worstOverlay = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentWorstMatchOverlay");
            testCase.verifyEqual( ...
                ProjectionViewerAlignmentWorkflowTest.overlaySegmentCount(worstOverlay), ...
                max(1, ceil(0.10 * numel(finiteResiduals))));

            featureOverlayCheckBox.Value = false;
            featureOverlayCheckBox.ValueChangedFcn(featureOverlayCheckBox, struct());
            drawnow
            testCase.verifyEmpty(findall(fig, "Tag", ...
                "ProjectionViewerAlignmentMovingMatchOverlay"));
            testCase.verifyNotEmpty(findall(fig, "Tag", ...
                "ProjectionViewerAlignmentMatchOverlay"));
            featureOverlayCheckBox.Value = true;
            featureOverlayCheckBox.ValueChangedFcn(featureOverlayCheckBox, struct());
            drawnow

            matchTable.CellSelectionCallback(matchTable, struct(Indices=[1 1]));
            drawnow
            testCase.verifyNotEmpty(findall(fig, "Tag", ...
                "ProjectionViewerAlignmentSelectedMatchOverlay"));

            disabledPair = dataAfterSolve.Pair(1);
            disabledMatchIndex = dataAfterSolve.MatchIndex(1);
            editedData = dataAfterSolve;
            editedData.Enabled(1) = false;
            matchTable.Data = editedData;
            matchTable.CellEditCallback(matchTable, struct());
            drawnow
            diagnosticsAfterEdit = app.alignmentDiagnostics();

            testCase.verifyEmpty(findall(fig, "Tag", ...
                "ProjectionViewerAlignmentRejectedMatchOverlay"));
            rejectedOverlayCheckBox.Value = true;
            rejectedOverlayCheckBox.ValueChangedFcn(rejectedOverlayCheckBox, ...
                struct());
            drawnow
            testCase.verifyNotEmpty(findall(fig, "Tag", ...
                "ProjectionViewerAlignmentRejectedMatchOverlay"));
            rejectedOverlayCheckBox.Value = false;
            rejectedOverlayCheckBox.ValueChangedFcn(rejectedOverlayCheckBox, ...
                struct());
            drawnow
            testCase.verifyEmpty(findall(fig, "Tag", ...
                "ProjectionViewerAlignmentRejectedMatchOverlay"));
            testCase.verifyFalse(diagnosticsAfterEdit.Stage.HasSolveResult);
            testCase.verifyEqual( ...
                diagnosticsAfterEdit.Stage.Session.Stage, "curated");
            testCase.verifyFalse( ...
                diagnosticsAfterEdit.Stage.Session.Stale.Match);
            testCase.verifyFalse( ...
                diagnosticsAfterEdit.Stage.Session.Stale.Filter);
            testCase.verifyTrue( ...
                diagnosticsAfterEdit.Stage.Session.Stale.Solve);
            testCase.verifyEqual( ...
                diagnosticsAfterEdit.Stage.Session.MatchRevision, ...
                diagnosticsAfterFirstSolve.Stage.Session.MatchRevision);
            testCase.verifyEqual( ...
                diagnosticsAfterEdit.Stage.CuratedMatchCount, ...
                diagnosticsAfterFirstSolve.Stage.FilteredMatchCount - 1);
            testCase.verifyEqual(string(previewButton.Enable), "off");
            testCase.verifyTrue(contains(string(statusLabel.Text), ...
                "curation updated"));

            solveButton.ButtonPushedFcn(solveButton, struct());
            drawnow
            diagnosticsAfterSecondSolve = app.alignmentDiagnostics();
            dataAfterSecondSolve = matchTable.Data;
            disabledMask = dataAfterSecondSolve.Pair == disabledPair & ...
                dataAfterSecondSolve.MatchIndex == disabledMatchIndex;

            testCase.verifyEqual( ...
                diagnosticsAfterSecondSolve.Stage.SolvedMatchCount, ...
                diagnosticsAfterFirstSolve.Stage.SolvedMatchCount - 1);
            testCase.verifyFalse( ...
                diagnosticsAfterSecondSolve.Stage.Session.Stale.Solve);
            testCase.verifyTrue(any(disabledMask));
            testCase.verifyFalse(dataAfterSecondSolve.Enabled(disabledMask));
            testCase.verifyEqual( ...
                string(dataAfterSecondSolve.State(disabledMask)), "disabled");
        end

        function testLowCountSolveWarnsAndKeepsActionsEnabled(testCase)
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
            surfaceWorkbenchButton = ...
                ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentSurfaceWorkbenchButton");
            matchTable = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentMatchTable");
            statusLabel = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentStatusLabel");

            detectorDropDown.Value = "sift";
            matchButton.ButtonPushedFcn(matchButton, struct());
            drawnow
            ProjectionViewerAlignmentWorkflowTest.filterMatches();
            dataAfterMatch = matchTable.Data;
            testCase.assumeGreaterThanOrEqual(height(dataAfterMatch), 10);

            editedData = dataAfterMatch;
            editedData.Enabled(:) = false;
            editedData.Enabled(1:3) = true;
            matchTable.Data = editedData;
            matchTable.CellEditCallback(matchTable, struct());
            drawnow

            testCase.verifyEqual(string(solveButton.Enable), "on");
            solveButton.ButtonPushedFcn(solveButton, struct());
            drawnow

            diagnosticsAfterSolve = app.alignmentDiagnostics();
            solvedData = matchTable.Data;
            testCase.verifyTrue(contains(string(statusLabel.Text), ...
                "Low-confidence"));
            testCase.verifyTrue(diagnosticsAfterSolve.Stage.HasSolveResult);
            testCase.verifyEqual(diagnosticsAfterSolve.Stage.SolvedMatchCount, 3);
            testCase.verifyEqual(nnz(solvedData.Enabled), 3);
            testCase.verifyEqual(string(previewButton.Enable), "on");
            testCase.verifyEqual(string(applyButton.Enable), "on");
            testCase.verifyEqual(string(revertButton.Enable), "off");

            stateBeforePreview = app.exportState();
            generationBeforeApply = app.correctionGenerationId();
            previewButton.ButtonPushedFcn(previewButton, struct());
            drawnow
            previewState = app.exportState();
            testCase.verifyEqual(string(revertButton.Enable), "on");
            testCase.verifyEqual(string(surfaceWorkbenchButton.Enable), "on");

            app.setAlignmentReviewConfirmationFcn( ...
                @(decision, summary) ...
                ProjectionViewerAlignmentWorkflowTest.verifyReviewPrompt( ...
                testCase, decision, summary, false));
            applyButton.ButtonPushedFcn(applyButton, struct());
            drawnow
            testCase.verifyEqual(app.correctionGenerationId(), ...
                generationBeforeApply);
            testCase.verifyEqual(app.exportState(), previewState);
            testCase.verifyEqual(string(revertButton.Enable), "on");

            app.setAlignmentReviewConfirmationFcn( ...
                @(decision, summary) ...
                ProjectionViewerAlignmentWorkflowTest.verifyReviewPrompt( ...
                testCase, decision, summary, true));
            applyButton.ButtonPushedFcn(applyButton, struct());
            drawnow
            testCase.verifyNotEqual(app.correctionGenerationId(), ...
                generationBeforeApply);
            testCase.verifyEqual(string(surfaceWorkbenchButton.Enable), "on");
            revertButton.ButtonPushedFcn(revertButton, struct());
            drawnow
            testCase.verifyEqual(app.correctionGenerationId(), ...
                generationBeforeApply);
            testCase.verifyEqual(app.exportState(), stateBeforePreview);
            testCase.verifyEqual(string(surfaceWorkbenchButton.Enable), "off");
        end

        function testOverlayClickDeleteAndUndoCuration(testCase)
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
            matchButton = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentMatchButton");
            solveButton = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentSolveButton");
            previewButton = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentPreviewButton");
            matchTable = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentMatchTable");
            deleteButton = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentDeleteMatchButton");
            undoButton = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentUndoCurationButton");

            detectorDropDown.Value = "sift";
            matchButton.ButtonPushedFcn(matchButton, struct());
            drawnow
            ProjectionViewerAlignmentWorkflowTest.filterMatches();
            solveButton.ButtonPushedFcn(solveButton, struct());
            drawnow
            diagnosticsAfterSolve = app.alignmentDiagnostics();
            acceptedOverlay = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentMatchOverlay");
            overlayRecord = acceptedOverlay.UserData(1);
            clickPoint = [acceptedOverlay.XData(1), acceptedOverlay.YData(1), ...
                acceptedOverlay.ZData(1)];

            acceptedOverlay.ButtonDownFcn(acceptedOverlay, ...
                struct(IntersectionPoint=clickPoint));
            drawnow
            tableData = matchTable.Data;
            selectedMask = tableData.Pair == overlayRecord.PairKey & ...
                tableData.MatchIndex == overlayRecord.MatchIndex;
            selectedRow = find(selectedMask, 1, "first");

            testCase.verifyNotEmpty(selectedRow);
            testCase.verifyNotEmpty(findall(fig, "Tag", ...
                "ProjectionViewerAlignmentSelectedMatchOverlay"));
            if isprop(matchTable, "Selection")
                testCase.verifyEqual(matchTable.Selection(1), selectedRow);
            end

            deleteButton.ButtonPushedFcn(deleteButton, struct());
            drawnow
            dataAfterDelete = matchTable.Data;
            deletedMask = dataAfterDelete.Pair == overlayRecord.PairKey & ...
                dataAfterDelete.MatchIndex == overlayRecord.MatchIndex;
            diagnosticsAfterDelete = app.alignmentDiagnostics();

            testCase.verifyTrue(any(deletedMask));
            testCase.verifyFalse(dataAfterDelete.Enabled(deletedMask));
            testCase.verifyEqual(string(dataAfterDelete.State(deletedMask)), ...
                "deleted");
            testCase.verifyEqual( ...
                diagnosticsAfterDelete.Stage.CuratedMatchCount, ...
                diagnosticsAfterSolve.Stage.FilteredMatchCount - 1);
            testCase.verifyFalse(diagnosticsAfterDelete.Stage.HasSolveResult);
            testCase.verifyEqual(string(previewButton.Enable), "off");

            undoButton.ButtonPushedFcn(undoButton, struct());
            drawnow
            dataAfterUndo = matchTable.Data;
            restoredMask = dataAfterUndo.Pair == overlayRecord.PairKey & ...
                dataAfterUndo.MatchIndex == overlayRecord.MatchIndex;
            diagnosticsAfterUndo = app.alignmentDiagnostics();

            testCase.verifyTrue(any(restoredMask));
            testCase.verifyTrue(dataAfterUndo.Enabled(restoredMask));
            testCase.verifyNotEqual(string(dataAfterUndo.State(restoredMask)), ...
                "deleted");
            testCase.verifyEqual( ...
                diagnosticsAfterUndo.Stage.CuratedMatchCount, ...
                diagnosticsAfterSolve.Stage.FilteredMatchCount);
        end

        function testOverlayCoordinatesRemainFixedAcrossLayerReorder(testCase)
            capabilities = ProjectionAlignmentFeatureMatcher.capabilities();
            testCase.assumeTrue(ismember("sift", capabilities.AvailableDetectors));

            scene = ProjectionViewerAlignmentWorkflowTest.makeTexturedScene(false);
            referenceId = string(scene.layers(1).LayerId);
            movingId = string(scene.layers(2).LayerId);
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow

            fig = ProjectionViewerAlignmentWorkflowTest.findViewerFigure();
            detectorDropDown = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentDetectorDropDown");
            matchButton = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentMatchButton");
            moveDownButton = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerMoveLayerDownButton");
            referenceDropDown = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentReferenceDropDown");
            movingDropDown = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentMovingDropDown");
            matchTable = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentMatchTable");

            detectorDropDown.Value = "sift";
            matchButton.ButtonPushedFcn(matchButton, struct());
            drawnow
            overlayBefore = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentMatchOverlay");
            coordinatesBefore = ...
                ProjectionViewerAlignmentWorkflowTest.overlayCoordinates( ...
                overlayBefore);

            moveDownButton.ButtonPushedFcn(moveDownButton, struct());
            drawnow

            overlayAfter = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentMatchOverlay");
            coordinatesAfter = ...
                ProjectionViewerAlignmentWorkflowTest.overlayCoordinates( ...
                overlayAfter);
            stateAfter = app.exportState();
            referenceIndex = str2double(string(referenceDropDown.Value));
            movingIndex = str2double(string(movingDropDown.Value));

            testCase.verifyEqual(coordinatesAfter, coordinatesBefore, ...
                AbsTol=ProjectionViewerAlignmentWorkflowTest.Tol);
            testCase.verifyEqual(string(stateAfter.Layers(1).LayerId), movingId);
            testCase.verifyEqual(string(stateAfter.Layers(2).LayerId), referenceId);
            testCase.verifyEqual( ...
                string(stateAfter.Layers(referenceIndex).LayerId), referenceId);
            testCase.verifyEqual( ...
                string(stateAfter.Layers(movingIndex).LayerId), movingId);
            testCase.verifyTrue(all(matchTable.Data.Pair == "1 -> 2"));
            testCase.verifyEqual(overlayAfter.UserData(1).PairLayerIds, ...
                [movingId referenceId]);
        end

        function testClearingRoiRestoresPreRoiMatchesWithoutRematch(testCase)
            capabilities = ProjectionAlignmentFeatureMatcher.capabilities();
            testCase.assumeTrue(ismember("sift", capabilities.AvailableDetectors));

            scene = ProjectionViewerAlignmentWorkflowTest.makeTexturedScene(false);
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow

            fig = ProjectionViewerAlignmentWorkflowTest.findViewerFigure();
            detectorDropDown = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentDetectorDropDown");
            roiButton = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentRoiButton");
            clearRoiButton = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentClearRoiButton");
            matchButton = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentMatchButton");

            detectorDropDown.Value = "sift";
            roiButton.ButtonPushedFcn(roiButton, struct());
            matchButton.ButtonPushedFcn(matchButton, struct());
            drawnow
            ProjectionViewerAlignmentWorkflowTest.filterMatches();
            withRoi = app.alignmentDiagnostics();

            clearRoiButton.ButtonPushedFcn(clearRoiButton, struct());
            drawnow
            cleared = app.alignmentDiagnostics();

            testCase.verifyTrue(withRoi.Stage.RoiActive);
            testCase.verifyGreaterThanOrEqual( ...
                withRoi.Stage.PreRoiMatchCount, ...
                withRoi.Stage.FilteredMatchCount);
            testCase.verifyEqual(withRoi.Stage.RoiRejectedRecordCount, ...
                withRoi.Stage.PreRoiMatchCount - ...
                withRoi.Stage.FilteredMatchCount);
            testCase.verifyFalse(cleared.Stage.RoiActive);
            testCase.verifyEqual(cleared.Stage.FilteredMatchCount, ...
                cleared.Stage.PreRoiMatchCount);
            testCase.verifyEqual(cleared.Stage.RawMatchCount, ...
                withRoi.Stage.RawMatchCount);
            testCase.verifyTrue(cleared.Stage.HasWorkingImages);
        end

        function testRepeatedMatchReusesStableWorkingImages(testCase)
            capabilities = ProjectionAlignmentFeatureMatcher.capabilities();
            testCase.assumeTrue(ismember("sift", capabilities.AvailableDetectors));

            scene = ProjectionViewerAlignmentWorkflowTest.makeTexturedScene(false);
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow

            fig = ProjectionViewerAlignmentWorkflowTest.findViewerFigure();
            detectorDropDown = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentDetectorDropDown");
            matchButton = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentMatchButton");
            detectorDropDown.Value = "sift";

            matchButton.ButtonPushedFcn(matchButton, struct());
            drawnow
            first = app.alignmentDiagnostics();
            matchButton.ButtonPushedFcn(matchButton, struct());
            drawnow
            second = app.alignmentDiagnostics();

            testCase.verifyEqual(first.Stage.WorkingImageCacheMisses, 1);
            testCase.verifyEqual(first.Stage.WorkingImageCacheHits, 0);
            testCase.verifyEqual(second.Stage.WorkingImageCacheMisses, 1);
            testCase.verifyEqual(second.Stage.WorkingImageCacheHits, 1);
            testCase.verifyEqual(second.Stage.RawMatchCount, ...
                first.Stage.RawMatchCount);
        end

        function testAlignmentOverlaysRefreshAfterLayerNudge(testCase)
            capabilities = ProjectionAlignmentFeatureMatcher.capabilities();
            testCase.assumeTrue(ismember("sift", capabilities.AvailableDetectors));

            scene = ProjectionViewerAlignmentWorkflowTest.makeTexturedScene(false);
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow

            fig = ProjectionViewerAlignmentWorkflowTest.findViewerFigure();
            detectorDropDown = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentDetectorDropDown");
            matchButton = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentMatchButton");

            detectorDropDown.Value = "sift";
            matchButton.ButtonPushedFcn(matchButton, struct());
            drawnow
            overlay = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentMatchOverlay");
            coordinatesBefore = ...
                ProjectionViewerAlignmentWorkflowTest.overlayCoordinates(overlay);

            fig.WindowKeyPressFcn(fig, ...
                ProjectionViewerAlignmentWorkflowTest.makeKeyEvent("w"));
            drawnow
            overlayAfterNudge = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentMatchOverlay");
            coordinatesAfter = ...
                ProjectionViewerAlignmentWorkflowTest.overlayCoordinates( ...
                overlayAfterNudge);

            testCase.verifyGreaterThan( ...
                ProjectionViewerAlignmentWorkflowTest.finiteCoordinateDelta( ...
                coordinatesBefore, coordinatesAfter), 1e-6);
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
            ProjectionViewerAlignmentWorkflowTest.filterMatches();
            solveButton.ButtonPushedFcn(solveButton, struct());
            drawnow

            testCase.verifyTrue(contains(string(statusLabel.Text), "RMS"));
            testCase.verifyEqual(string(matchButton.Enable), "on");
            testCase.verifyEqual(string(solveButton.Enable), "on");
            testCase.verifyEqual(string(previewButton.Enable), "on");
        end

        function testEpipolarLossRunsThroughControls(testCase)
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
            matchTable = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentMatchTable");
            statusLabel = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentStatusLabel");

            detectorDropDown.Value = "sift";
            lossDropDown.Value = "epipolarCoplanarity";
            matchButton.ButtonPushedFcn(matchButton, struct());
            drawnow
            ProjectionViewerAlignmentWorkflowTest.filterMatches();
            solveButton.ButtonPushedFcn(solveButton, struct());
            drawnow

            diagnostics = app.alignmentDiagnostics();
            testCase.verifyEqual(diagnostics.Request.LossMode, ...
                "epipolarCoplanarity");
            testCase.verifyTrue(all(isfinite( ...
                matchTable.Data.ResidualAfter)));
            testCase.verifyFalse(startsWith(string(statusLabel.Text), ...
                "Alignment failed:"));
        end

        function testShiftLeftDragAppliesAndUndoesCommonAnchor(testCase)
            capabilities = ProjectionAlignmentFeatureMatcher.capabilities();
            testCase.assumeTrue(ismember("sift", capabilities.AvailableDetectors));
            testCase.assumeTrue(exist("lsqnonlin", "file") == 2);

            scene = ProjectionViewerAlignmentWorkflowTest.makeTexturedScene(true);
            app = ProjectionViewerApp(scene);
            testCase.addTeardown(@() delete(app));
            drawnow

            fig = ProjectionViewerAlignmentWorkflowTest.findViewerFigure();
            ax = findall(fig, "Type", "axes");
            detectorDropDown = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentDetectorDropDown");
            matchButton = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentMatchButton");
            undoButton = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentUndoCurationButton");
            statusLabel = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentStatusLabel");

            detectorDropDown.Value = "sift";
            matchButton.ButtonPushedFcn(matchButton, struct());
            drawnow
            ProjectionViewerAlignmentWorkflowTest.filterMatches();
            acceptedOverlay = ProjectionViewerAlignmentWorkflowTest.findTagged( ...
                fig, "ProjectionViewerAlignmentMatchOverlay");
            clickPoint = [acceptedOverlay.XData(1), acceptedOverlay.YData(1), ...
                acceptedOverlay.ZData(1)];
            acceptedOverlay.ButtonDownFcn(acceptedOverlay, ...
                struct(IntersectionPoint=clickPoint));
            drawnow

            stateBefore = app.exportState();
            opkBefore = ProjectionViewerAlignmentWorkflowTest. ...
                viewVectorOffsets(stateBefore);
            offsetBefore = reshape( ...
                [stateBefore.Layers.ProjectionOffsetMeters], 2, []).';
            center = ax.InnerPosition(1:2) + ax.InnerPosition(3:4) / 2;
            fig.WindowKeyPressFcn(fig, ...
                ProjectionViewerAlignmentWorkflowTest.makeKeyEvent("shift"));
            fig.SelectionType = "normal";
            fig.CurrentPoint = center;
            fig.WindowButtonDownFcn(fig, struct(Modifier="shift"));
            testCase.assertNotEmpty(fig.WindowButtonMotionFcn);
            fig.CurrentPoint = center + [4 3];
            fig.WindowButtonMotionFcn(fig, struct());
            testCase.verifyTrue(isvalid(acceptedOverlay), ...
                "Live anchor preview should not rebuild the full overlay set.");
            fig.WindowButtonUpFcn(fig, struct());
            fig.WindowKeyReleaseFcn(fig, ...
                ProjectionViewerAlignmentWorkflowTest.makeKeyEvent("shift"));
            drawnow

            stateAfter = app.exportState();
            opkAfter = ProjectionViewerAlignmentWorkflowTest. ...
                viewVectorOffsets(stateAfter);
            offsetAfter = reshape( ...
                [stateAfter.Layers.ProjectionOffsetMeters], 2, []).';
            delta = opkAfter - opkBefore;
            diagnostics = app.alignmentDiagnostics();

            testCase.verifyEqual(delta(1, 1:2), delta(2, 1:2), ...
                AbsTol=1e-8);
            testCase.verifyGreaterThan(norm(delta(1, 1:2)), 0);
            testCase.verifyEqual(delta(:, 3), zeros(2, 1), AbsTol=1e-12);
            testCase.verifyEqual(offsetAfter, offsetBefore, AbsTol=1e-12);
            testCase.verifyEqual(diagnostics.Stage.ManualAdjustmentCount, 1);
            testCase.verifyFalse(diagnostics.Stage.HasSolveResult);
            testCase.verifyTrue(contains(string(statusLabel.Text), ...
                "Common anchor applied"));

            undoButton.ButtonPushedFcn(undoButton, struct());
            drawnow
            undoneState = app.exportState();
            undoneOpk = ProjectionViewerAlignmentWorkflowTest. ...
                viewVectorOffsets(undoneState);
            undoneDiagnostics = app.alignmentDiagnostics();

            testCase.verifyEqual(undoneOpk, opkBefore, AbsTol=1e-10);
            testCase.verifyEqual( ...
                undoneDiagnostics.Stage.ManualAdjustmentUndoCount, 0);
            testCase.verifyTrue(contains(string(statusLabel.Text), ...
                "Undid common-anchor"));

            fig.WindowKeyPressFcn(fig, ...
                ProjectionViewerAlignmentWorkflowTest.makeKeyEvent("shift"));
            fig.SelectionType = "normal";
            fig.CurrentPoint = center;
            fig.WindowButtonDownFcn(fig, struct(Modifier="shift"));
            fig.CurrentPoint = center + [3 2];
            fig.WindowButtonMotionFcn(fig, struct());
            fig.WindowKeyPressFcn(fig, ...
                ProjectionViewerAlignmentWorkflowTest.makeKeyEvent("escape"));
            fig.WindowButtonUpFcn(fig, struct());
            fig.WindowKeyReleaseFcn(fig, ...
                ProjectionViewerAlignmentWorkflowTest.makeKeyEvent("shift"));
            drawnow
            cancelledState = app.exportState();
            cancelledOpk = ProjectionViewerAlignmentWorkflowTest. ...
                viewVectorOffsets(cancelledState);

            testCase.verifyEqual(cancelledOpk, opkBefore, AbsTol=1e-10);
            testCase.verifyTrue(contains(string(statusLabel.Text), "cancelled"));
        end
    end

    methods (Static, Access = private)
        function closeAlignmentFigures()
            names = ["Sightline", "Alignment Workbench"];
            for name = names
                delete(findall(groot, "Type", "figure", "Name", name));
            end
        end

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
                "Name", "Sightline");
            fig = fig(1);
            if isempty(findall(groot, "Type", "figure", ...
                    "Name", "Alignment Workbench"))
                menuItem = findall(fig, "Tag", ...
                    "ProjectionViewerAlignmentPanelMenuItem");
                menuItem.MenuSelectedFcn(menuItem, struct());
                drawnow
            end
        end

        function component = findTagged(parent, tag)
            components = findall(parent, "Tag", tag);
            if isempty(components)
                components = findall(groot, "Tag", tag);
            end
            component = components(1);
        end

        function filterMatches()
            filterButton = findall(groot, "Tag", ...
                "ProjectionViewerAlignmentFilterButton");
            filterButton = filterButton(1);
            filterButton.ButtonPushedFcn(filterButton, struct());
            drawnow
        end

        function hideAndReopenWorkbench(app)
            workbench = findall(groot, "Tag", ...
                "ProjectionViewerAlignmentWorkbench");
            workbench.CloseRequestFcn(workbench, struct());
            drawnow
            assert(string(workbench.Visible) == "off")
            assert(isvalid(app))
            viewer = findall(groot, "Type", "figure", "Name", "Sightline");
            menuItem = findall(viewer, "Tag", ...
                "ProjectionViewerAlignmentPanelMenuItem");
            menuItem.MenuSelectedFcn(menuItem, struct());
            drawnow
            assert(string(workbench.Visible) == "on")
        end

        function offsets = viewVectorOffsets(state)
            offsets = reshape([state.Layers.ViewVectorAngularOffsetsDegrees], ...
                3, []).';
        end

        function event = makeKeyEvent(key)
            event = struct(Key=key, Modifier=key);
        end

        function coordinates = overlayCoordinates(overlay)
            coordinates = [overlay.XData(:), overlay.YData(:), ...
                overlay.ZData(:)];
        end

        function delta = finiteCoordinateDelta(before, after)
            finiteMask = isfinite(before) & isfinite(after);
            delta = norm(after(finiteMask) - before(finiteMask));
        end

        function count = overlaySegmentCount(overlay)
            count = nnz(isnan(overlay.XData));
        end

        function confirmed = verifyReviewPrompt( ...
                testCase, decision, summary, confirmed)
            testCase.verifyEqual(decision.Status, "review");
            requiredText = ["RMS" "Active objective" "observations" ...
                "tracks" "spatial coverage" "Condition" ...
                "attitude sigma" "bound hit"];
            testCase.verifyTrue(all(contains(summary, requiredText)));
        end
    end
end
