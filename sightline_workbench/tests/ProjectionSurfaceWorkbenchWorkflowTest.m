classdef ProjectionSurfaceWorkbenchWorkflowTest < matlab.unittest.TestCase
    %ProjectionSurfaceWorkbenchWorkflowTest B6 floating UI and 3-D workflows.

    methods (TestClassSetup)
        function addPaths(testCase)
            root = fileparts(fileparts(mfilename("fullpath")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(root));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(root, "src")));
        end
    end

    methods (TestMethodSetup)
        function closeExistingFigures(testCase)
            delete(findall(groot, "Type", "figure", "Name", ...
                "Surface Workbench"));
            delete(findall(groot, "Type", "figure", "Name", ...
                "Surface 3-D Viewer"));
            testCase.addTeardown(@() delete(findall(groot, "Type", ...
                "figure", "Name", "Surface Workbench")));
            testCase.addTeardown(@() delete(findall(groot, "Type", ...
                "figure", "Name", "Surface 3-D Viewer")));
        end
    end

    methods (Test)
        function testWorkbenchIsSeparateResponsiveAndViewerIsLazy(testCase)
            app = ProjectionSurfaceWorkbenchApp( ...
                ProjectionSurfaceWorkbenchFixture.catalog());
            testCase.addTeardown(@() delete(app));
            drawnow
            snapshot = app.componentSnapshot();
            diagnostics = app.diagnostics();
            figureHandle = app.figureHandle();

            testCase.verifyEqual(string(figureHandle.Name), "Surface Workbench");
            testCase.verifyEqual(snapshot.FigureTag, ...
                "ProjectionSurfaceWorkbenchFigure");
            testCase.verifyEqual(snapshot.GridRows, 3);
            testCase.verifyEqual(snapshot.GridColumns, 3);
            testCase.verifyEqual(string(figureHandle.Children.RowHeight), ...
                ["fit" "1x" "fit"]);
            testCase.verifyFalse(diagnostics.ViewerOpen);
            testCase.verifyEqual( ...
                diagnostics.NetworkStatistics.CatalogPairCount, 3);
            testCase.verifyEqual( ...
                diagnostics.NetworkStatistics.RobustMultiViewPointCount, 8);
            testCase.verifyGreaterThan( ...
                diagnostics.ProcessingEstimate.RelativeWorkUnits, 0);
            testCase.verifyFalse( ...
                diagnostics.ProcessingEstimate.IsWallClockPrediction);
            testCase.verifyEmpty(app.viewerHandle());
            testCase.verifyNumElements(findall(figureHandle, "Tag", ...
                "ProjectionSurfaceWorkbenchNetworkTable"), 1);
            testCase.verifyNumElements(findall(figureHandle, "Tag", ...
                "ProjectionSurfaceWorkbenchProductTable"), 1);
        end

        function testWorkbenchSelectionsRemainGraphicsIndependent(testCase)
            app = ProjectionSurfaceWorkbenchApp( ...
                ProjectionSurfaceWorkbenchFixture.catalog());
            testCase.addTeardown(@() delete(app));
            changes = struct(SelectedViewIds=["view-a" "view-b"], ...
                SelectedPassIds="pass-1", PairSchedule="fast", ...
                DenseMethod="external", GeometrySearch="widePrior", ...
                ProcessingStage="voxelEvidence", ...
                OutputProductId= ...
                "voxel.sightline.fusion.hard-voxel.scale-2", ...
                ColorMode="evidenceWeight", DecimationLimit=4);
            app.setSelection(changes);
            state = app.modelState();

            testCase.verifyEqual(state.SelectedViewIds, ["view-a" "view-b"]);
            testCase.verifyEqual(state.SelectedPassIds, "pass-1");
            testCase.verifyEqual(state.PairSchedule, "fast");
            testCase.verifyEqual(state.OutputProductId, ...
                "voxel.sightline.fusion.hard-voxel.scale-2");
            testCase.verifyEqual(state.ColorMode, "evidenceWeight");
            testCase.verifyEqual(state.DecimationLimit, 4);
            testCase.verifyFalse(state.GraphicsStateIncluded);
            testCase.verifyFalse(ProjectionSurfaceWorkbenchFixture. ...
                hasRuntimeHandle(state));
        end

        function testProgressAndCancellationStayRuntimeOnly(testCase)
            app = ProjectionSurfaceWorkbenchApp( ...
                ProjectionSurfaceWorkbenchFixture.catalog());
            testCase.addTeardown(@() delete(app));
            app.setProgress(0.375, "fusion", "Accumulating evidence");
            beforeCancel = app.diagnostics();
            app.requestCancel();
            afterCancel = app.diagnostics();
            app.resetCancellation();

            testCase.verifyEqual(beforeCancel.Progress.Fraction, 0.375);
            testCase.verifyEqual(beforeCancel.Progress.Stage, "fusion");
            testCase.verifyEqual(beforeCancel.Progress.Message, ...
                "Accumulating evidence");
            testCase.verifyTrue(afterCancel.CancellationRequested);
            testCase.verifyTrue(afterCancel.GraphicsStateSerialized == false);
            testCase.verifyFalse(app.isCancellationRequested());
            testCase.verifyError(@() app.setProgress(2, "bad"), ...
                "ProjectionSurfaceWorkbenchApp:invalidProgress");
        end

        function testViewerLinksSelectionAndBoundsUncertaintyGlyphs(testCase)
            app = ProjectionSurfaceWorkbenchApp( ...
                ProjectionSurfaceWorkbenchFixture.catalog(), ...
                struct(MaximumUncertaintyGlyphs=1));
            testCase.addTeardown(@() delete(app));
            viewer = app.openViewer();
            drawnow
            viewer.selectDisplayPoint(1);
            drawnow
            info = viewer.selectedPointInfo();
            diagnostics = viewer.diagnostics();

            testCase.verifyTrue(info.Selected);
            testCase.verifyEqual(string({info.ObservationLinks.ViewId}), ...
                ["view-a" "view-b" "view-c"]);
            testCase.verifyEqual(diagnostics.UncertaintyGlyphCount, 1);
            testCase.verifyEqual(diagnostics.UncertaintyGlyphAxisCount, 3);
            testCase.verifyLessThanOrEqual( ...
                diagnostics.UncertaintyGlyphCount, ...
                diagnostics.MaximumUncertaintyGlyphs);
            testCase.verifyFalse(diagnostics.GraphicsStateSerialized);
            testCase.verifyTrue(diagnostics.CompleteProductRetained);
            testCase.verifyNumElements(findall(viewer.figureHandle(), "Tag", ...
                "ProjectionSurface3DObservationTable"), 1);
        end

        function testViewerRendersPointVoxelMeshAndGridProducts(testCase)
            app = ProjectionSurfaceWorkbenchApp( ...
                ProjectionSurfaceWorkbenchFixture.catalog());
            testCase.addTeardown(@() delete(app));
            viewer = app.openViewer();
            testCase.addTeardown(@() delete(viewer));
            viewer.setProduct("robust-multi-view");
            pointDiagnostics = viewer.diagnostics();
            viewer.setProduct( ...
                "voxel.sightline.fusion.hard-voxel.scale-2");
            voxelDiagnostics = viewer.diagnostics();
            viewer.setProduct("mesh-demo");
            meshDiagnostics = viewer.diagnostics();
            viewer.setProduct("grid-demo");
            gridDiagnostics = viewer.diagnostics();
            drawnow

            testCase.verifyEqual(pointDiagnostics.DisplayRepresentation, ...
                "pointCloud");
            testCase.verifyEqual(voxelDiagnostics.DisplayRepresentation, "voxel");
            testCase.verifyEqual(meshDiagnostics.DisplayRepresentation, "mesh");
            testCase.verifyEqual(gridDiagnostics.DisplayRepresentation, "grid");
            testCase.verifyEqual(pointDiagnostics.PrimaryObjectCount, 1);
            testCase.verifyEqual(voxelDiagnostics.PrimaryObjectCount, 1);
            testCase.verifyEqual(meshDiagnostics.PrimaryObjectCount, 1);
            testCase.verifyEqual(gridDiagnostics.PrimaryObjectCount, 1);
            testCase.verifyNumElements(findall(viewer.figureHandle(), "Tag", ...
                "ProjectionSurface3DGridObject"), 1);
        end

        function testComparisonAndDecimationPreserveFullResult(testCase)
            app = ProjectionSurfaceWorkbenchApp( ...
                ProjectionSurfaceWorkbenchFixture.catalog());
            testCase.addTeardown(@() delete(app));
            viewer = app.openViewer();
            viewer.setProduct("robust-multi-view");
            viewer.setDecimationLimit(3);
            viewer.setComparison("raw-pairwise");
            diagnostics = viewer.diagnostics();

            testCase.verifyEqual(diagnostics.FullPointCount, 8);
            testCase.verifyEqual(diagnostics.DisplayPointCount, 3);
            testCase.verifyTrue(diagnostics.Decimated);
            testCase.verifyEqual(diagnostics.ComparisonObjectCount, 1);
            testCase.verifyTrue(diagnostics.CompleteProductRetained);
            testCase.verifyNumElements(findall(viewer.figureHandle(), "Tag", ...
                "ProjectionSurface3DComparisonObject"), 1);
        end

        function testViewerCloseAndReopenLifecycleIsOwnedByWorkbench(testCase)
            app = ProjectionSurfaceWorkbenchApp( ...
                ProjectionSurfaceWorkbenchFixture.catalog());
            testCase.addTeardown(@() delete(app));
            first = app.openViewer();
            firstFigure = first.figureHandle();
            firstFigure.CloseRequestFcn(firstFigure, struct());
            drawnow
            second = app.openViewer();
            drawnow

            testCase.verifyFalse(isvalid(firstFigure));
            testCase.verifyTrue(isvalid(second));
            testCase.verifyTrue(isvalid(second.figureHandle()));
            testCase.verifyTrue(app.diagnostics().ViewerOpen);
            testCase.verifyNotEqual(second, first);
        end

        function testViewerUsesStandardInteractionsInspectModeAndCameraPersistence(testCase)
            app = ProjectionSurfaceWorkbenchApp( ...
                ProjectionSurfaceWorkbenchFixture.catalog());
            testCase.addTeardown(@() delete(app));
            viewer = app.openViewer();
            axesHandle = viewer.axesHandle();
            initialObject = findall(viewer.figureHandle(), "Tag", ...
                "ProjectionSurface3DPointObject");
            axesHandle.CameraPosition = [100 200 300];
            axesHandle.CameraTarget = [1 2 3];
            expected = viewer.cameraState();
            testCase.verifyEmpty(initialObject.ButtonDownFcn);

            viewer.setColorMode("uncertainty");
            viewer.setDecimationLimit(4);
            viewer.setComparison("raw-pairwise");
            preserved = viewer.cameraState();

            testCase.verifyGreaterThanOrEqual(expected.InteractionCount, 2);
            testCase.verifyEqual(preserved.Position, expected.Position, ...
                AbsTol=1e-12);
            testCase.verifyEqual(preserved.Target, expected.Target, ...
                AbsTol=1e-12);
            viewer.setInspectMode(true);
            inspectObject = findall(viewer.figureHandle(), "Tag", ...
                "ProjectionSurface3DPointObject");
            testCase.verifyNotEmpty(inspectObject.ButtonDownFcn);
            testCase.verifyTrue(viewer.cameraState().InspectMode);
            viewer.setVerticalExaggeration(5);
            testCase.verifyEqual(viewer.diagnostics().VerticalExaggeration, 5);
            viewer.setViewpoint("top");
            testCase.verifyTrue(viewer.cameraState().Valid);
            testCase.verifyNumElements(findall(viewer.figureHandle(), "Tag", ...
                "ProjectionSurface3DInspectCheckBox"), 1);
        end

        function testDisplayFrameControlUsesExplicitAxisLabels(testCase)
            app = ProjectionSurfaceWorkbenchApp( ...
                ProjectionSurfaceWorkbenchFixture.catalog());
            testCase.addTeardown(@() delete(app));
            viewer = app.openViewer();

            viewer.setDisplayFrame("originRelativeWorld");
            axesHandle = viewer.axesHandle();
            diagnostics = viewer.diagnostics();

            testCase.verifyEqual(diagnostics.DisplayFrameId, ...
                "originRelativeWorld");
            testCase.verifyEqual(string(axesHandle.XLabel.String), ...
                "World X - origin (m)");
            testCase.verifyEqual(string(axesHandle.YLabel.String), ...
                "World Y - origin (m)");
            testCase.verifyEqual(string(axesHandle.ZLabel.String), ...
                "World Z - origin (m)");
            testCase.verifyNumElements(findall(viewer.figureHandle(), "Tag", ...
                "ProjectionSurface3DDisplayFrameDropDown"), 1);
        end

        function testStandaloneSavedRunEntryPointOpensValidatedCatalog(testCase)
            catalog = ProjectionSurfaceWorkbenchFixture.catalog();
            path = string(tempname) + ".mat";
            testCase.addTeardown(@() ...
                ProjectionSurfaceWorkbenchWorkflowTest.deleteIfPresent(path));
            save(path, "catalog", "-v7");

            [app, loaded] = openSurfaceWorkbenchRun(path);
            testCase.addTeardown(@() delete(app));

            testCase.verifyEqual(loaded.Catalog.GenerationId, ...
                catalog.GenerationId);
            testCase.verifyFalse(app.diagnostics().RunnerBound);
            testCase.verifyEqual(string(app.figureHandle().Name), ...
                "Surface Workbench");
        end
    end

    methods (Static, Access = private)
        function deleteIfPresent(path)
            if isfile(path)
                delete(path);
            end
        end
    end
end
