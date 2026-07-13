classdef ProjectionSurfaceRegistrationWorkflowTest < matlab.unittest.TestCase
    %ProjectionSurfaceRegistrationWorkflowTest S7 Workbench/viewer preview.

    methods (TestClassSetup)
        function addPaths(testCase)
            root = fileparts(fileparts(mfilename("fullpath")));
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
        function testWorkbenchSelectsDemPreviewAndViewerRendersGrid(testCase)
            catalog = ProjectionSurfaceRegistrationFixture.registeredCatalog();
            app = ProjectionSurfaceWorkbenchApp(catalog);
            testCase.addTeardown(@() delete(app));
            app.setSelection(struct(ProcessingStage="dem", ...
                DemRegistrationMode="preview", OutputProductId="dem", ...
                ColorMode="elevation"));
            viewer = app.openViewer();
            drawnow
            state = app.modelState();
            diagnostics = viewer.diagnostics();

            testCase.verifyEqual(state.ProcessingStage, "dem");
            testCase.verifyEqual(state.DemRegistrationMode, "preview");
            testCase.verifyEqual(state.OutputProductId, "dem");
            testCase.verifyEqual(diagnostics.SourceRepresentation, "grid");
            testCase.verifyEqual(diagnostics.DisplayRepresentation, "grid");
            testCase.verifyEqual(diagnostics.PrimaryObjectCount, 1);
            testCase.verifyNumElements(findall(viewer.figureHandle(), "Tag", ...
                "ProjectionSurface3DGridObject"), 1);
        end

        function testRegisteredComparisonDifferenceAndSourceLinksArePreserved(testCase)
            catalog = ProjectionSurfaceRegistrationFixture.registeredCatalog();
            app = ProjectionSurfaceWorkbenchApp(catalog, struct( ...
                OutputProductId="registered", ...
                ComparisonProductId="robust-multi-view", ...
                ProcessingStage="registered", ...
                DemRegistrationMode="registered", ...
                ColorMode="demDifference"));
            testCase.addTeardown(@() delete(app));
            viewer = app.openViewer();
            drawnow
            viewer.selectDisplayPoint(1);
            info = viewer.selectedPointInfo();
            diagnostics = viewer.diagnostics();

            testCase.verifyEqual(diagnostics.ProductId, "registered");
            testCase.verifyEqual(diagnostics.ComparisonObjectCount, 1);
            testCase.verifyTrue(diagnostics.CompleteProductRetained);
            testCase.verifyTrue(info.Selected);
            testCase.verifyEqual(string({info.ObservationLinks.ViewId}), ...
                ["view-a" "view-b" "view-c"]);
            testCase.verifyFalse(app.diagnostics().GraphicsStateSerialized);
            testCase.verifyFalse(app.diagnostics().State.GraphicsStateIncluded);
        end
    end
end
