classdef ProjectionSurfaceWorkbenchModelTest < matlab.unittest.TestCase
    %ProjectionSurfaceWorkbenchModelTest B6 portable catalog/model contracts.

    methods (TestClassSetup)
        function addPaths(testCase)
            root = fileparts(fileparts(mfilename("fullpath")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(root));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(root, "src")));
        end
    end

    methods (Test)
        function testCatalogAdaptsEverySurfaceStageAndPlaceholder(testCase)
            catalog = ProjectionSurfaceWorkbenchFixture.catalogWithGaussian();
            model = ProjectionSurfaceWorkbenchModel(catalog);
            summaries = model.productSummaries();
            available = ProjectionSurfaceWorkbenchFixture.availableIds(catalog);
            stages = string({summaries.Stage});

            testCase.verifyTrue(all(ismember(["raw-pairwise" ...
                "robust-multi-view" "uncertainty-filtered" ...
                "fusion.sightline.fusion.hard-voxel" ...
                "fusion.sightline.fusion.gaussian-splat" ...
                "mesh-demo" "grid-demo"], available)));
            testCase.verifyTrue(all(ismember(["rawPairwise" ...
                "robustMultiView" "uncertaintyFiltered" "fusionDerived" ...
                "voxelEvidence" "mesh" "grid" "dem" "registered" ...
                "demDifference"], stages)));
            testCase.verifyEqual(ProjectionSurfaceProductCatalog.find( ...
                catalog, "dem").Status, "unavailable");
            testCase.verifyGreaterThan(catalog.Diagnostics.EstimatedMemoryBytes, 0);
            testCase.verifyFalse(catalog.Diagnostics.GraphicsStateIncluded);
        end

        function testCatalogCarriesSourceIntensityAndFullSourceLinks(testCase)
            catalog = ProjectionSurfaceWorkbenchFixture.catalog();
            raw = ProjectionSurfaceProductCatalog.find(catalog, "raw-pairwise");
            robust = ProjectionSurfaceProductCatalog.find( ...
                catalog, "robust-multi-view");
            fused = ProjectionSurfaceProductCatalog.find(catalog, ...
                "fusion.sightline.fusion.hard-voxel");
            links = robust.Points(1).ObservationLinks;

            testCase.verifyTrue(all(isfinite([raw.Points.SourceIntensity])));
            testCase.verifyTrue(all(isfinite([robust.Points.SourceIntensity])));
            testCase.verifyTrue(all(isfinite([fused.Points.SourceIntensity])));
            testCase.verifyEqual(string({links.ViewId}), ...
                ["view-a" "view-b" "view-c"]);
            testCase.verifyEqual(string({links.ObservationId}), ...
                ["obs-a" "obs-b" "obs-c"]);
            testCase.verifyEqual([links.SourceColumnPixels], [20 40 60]);
            testCase.verifyEqual([links.SourceRowPixels], [10 30 50]);
        end

        function testUncertaintyFilterPreservesCompleteAuthoritativeProduct(testCase)
            catalog = ProjectionSurfaceWorkbenchFixture.catalog();
            model = ProjectionSurfaceWorkbenchModel(catalog, struct( ...
                OutputProductId="uncertainty-filtered", ...
                MaximumUncertaintyMeters=0.2));
            payload = model.payload();
            authoritative = ProjectionSurfaceProductCatalog.find( ...
                model.catalogValue(), "robust-multi-view");

            testCase.verifyEqual(payload.FullPointCount, 8);
            testCase.verifyEqual(payload.FilteredPointCount, 4);
            testCase.verifyEqual(payload.DisplayPointCount, 4);
            testCase.verifyTrue(payload.CompleteProductRetained);
            testCase.verifyNumElements(authoritative.Points, 8);
            testCase.verifyLessThanOrEqual( ...
                max([payload.Points.UncertaintyMeters]), 0.2);
        end

        function testDecimationAndColorMappingsAreDeterministic(testCase)
            model = ProjectionSurfaceWorkbenchModel( ...
                ProjectionSurfaceWorkbenchFixture.catalog(), ...
                struct(DecimationLimit=3));
            first = model.payload("robust-multi-view", "pairPass");
            second = model.payload("robust-multi-view", "pairPass");
            colors = ProjectionSurfaceWorkbenchFixture.colorPayloads(model);

            testCase.verifyEqual(first.DisplayIndices, second.DisplayIndices);
            testCase.verifyEqual(first.DisplayIndices, [1 5 8]);
            testCase.verifyTrue(first.Decimated);
            testCase.verifyEqual(first.DisplayPointCount, 3);
            colorModes = string(cellfun(@(payload) char(payload.ColorMode), ...
                colors, UniformOutput=false));
            testCase.verifyEqual(colorModes, ...
                ProjectionSurfaceWorkbenchModel.colorModes());
            testCase.verifyTrue(colors{1}.ColorAvailable);
            testCase.verifyTrue(colors{2}.ColorAvailable);
            testCase.verifyEqual(first.ColorLabels, ...
                "pair:a-b+pair:a-c+pair:b-c | pass-1+pass-2");
        end

        function testMeshAndGridRemainNativeUntilDisplayIsDecimated(testCase)
            model = ProjectionSurfaceWorkbenchModel( ...
                ProjectionSurfaceWorkbenchFixture.catalog(), ...
                struct(DecimationLimit=10));
            mesh = model.payload("mesh-demo", "elevation");
            grid = model.payload("grid-demo", "elevation");
            model.configure(struct(DecimationLimit=2));
            meshDecimated = model.payload("mesh-demo", "elevation");
            gridDecimated = model.payload("grid-demo", "elevation");

            testCase.verifyEqual(mesh.Representation, "mesh");
            testCase.verifyEqual(grid.Representation, "grid");
            testCase.verifySize(mesh.Mesh.Faces, [2 3]);
            testCase.verifySize(grid.Grid.Z, [2 2]);
            testCase.verifyEqual(meshDecimated.Representation, "pointCloud");
            testCase.verifyEqual(gridDecimated.Representation, "pointCloud");
            testCase.verifyTrue(meshDecimated.CompleteProductRetained);
            testCase.verifyTrue(gridDecimated.CompleteProductRetained);
        end

        function testSelectionsStatisticsAndStateArePortable(testCase)
            catalog = ProjectionSurfaceWorkbenchFixture.catalog();
            model = ProjectionSurfaceWorkbenchModel(catalog);
            changes = struct(SelectedViewIds=["view-a" "view-c"], ...
                SelectedPassIds="pass-2", PairSchedule="operator", ...
                DenseMethod="classicalTemplate", GeometrySearch="terrainGrid", ...
                ProcessingStage="fusionDerived", ...
                FusionProductId="fusion.sightline.fusion.hard-voxel", ...
                DemRegistrationMode="preview", ...
                OutputProductId="fusion.sightline.fusion.hard-voxel", ...
                ComparisonProductId="robust-multi-view", ...
                ColorMode="uncertainty", MaximumUncertaintyGlyphs=1);
            model.configure(changes);
            state = model.state();
            stats = model.statistics(state.OutputProductId);
            network = model.networkStatistics();
            estimate = model.processingEstimate();

            testCase.verifyEqual(state.SelectedViewIds, ["view-a" "view-c"]);
            testCase.verifyEqual(state.PairSchedule, "operator");
            testCase.verifyEqual(state.DenseMethod, "classicalTemplate");
            testCase.verifyEqual(state.DemRegistrationMode, "preview");
            testCase.verifyEqual(state.Format, ...
                "ProjectionSurfaceWorkbenchState");
            testCase.verifyGreaterThan(state.EstimatedCatalogMemoryBytes, 0);
            testCase.verifyGreaterThan(stats.FullPointCount, 0);
            testCase.verifyEqual(network.SelectedViewCount, 2);
            testCase.verifyEqual(network.SelectedPassCount, 1);
            testCase.verifyEqual(network.RawPairwisePointCount, 3);
            testCase.verifyEqual(network.RobustMultiViewPointCount, 8);
            testCase.verifyEqual(estimate.ScheduledPairCount, 1);
            testCase.verifyGreaterThan(estimate.RelativeWorkUnits, 0);
            testCase.verifyFalse(estimate.IsWallClockPrediction);
            testCase.verifyFalse(state.GraphicsStateIncluded);
            testCase.verifyFalse(ProjectionSurfaceWorkbenchFixture. ...
                hasRuntimeHandle(state));
        end

        function testStrictCatalogAndConfigurationValidationFailClosed(testCase)
            catalog = ProjectionSurfaceWorkbenchFixture.catalog();
            duplicate = catalog;
            duplicate.Products(end + 1) = duplicate.Products(1);
            runtime = catalog;
            runtime.Diagnostics.Callback = @() true;
            malformedMesh = catalog;
            meshIndex = string({malformedMesh.Products.ProductId}) == "mesh-demo";
            malformedMesh.Products(meshIndex).Mesh.Faces(1) = 1000;
            model = ProjectionSurfaceWorkbenchModel(catalog);

            testCase.verifyError(@() ...
                ProjectionSurfaceProductCatalog.validate(duplicate), ...
                "ProjectionSurfaceProductCatalog:duplicateProductId");
            testCase.verifyError(@() ...
                ProjectionSurfaceProductCatalog.validate(runtime), ...
                "ProjectionSurfaceProductCatalog:invalidCatalog");
            testCase.verifyError(@() ...
                ProjectionSurfaceProductCatalog.validate(malformedMesh), ...
                "ProjectionSurfaceProductCatalog:invalidMesh");
            testCase.verifyError(@() model.configure( ...
                struct(OutputProductId="unknown")), ...
                "ProjectionSurfaceWorkbenchModel:unknownProduct");
            testCase.verifyError(@() model.configure( ...
                struct(SelectedViewIds="unknown")), ...
                "ProjectionSurfaceWorkbenchModel:invalidConfiguration");
            testCase.verifyError(@() model.configure(struct(Extra=true)), ...
                "ProjectionSurfaceWorkbenchModel:invalidConfiguration");
        end

        function testUnavailableAndUnknownProductsCannotRender(testCase)
            catalog = ProjectionSurfaceWorkbenchFixture.catalog();
            model = ProjectionSurfaceWorkbenchModel(catalog);

            testCase.verifyError(@() model.payload("dem", "elevation"), ...
                "ProjectionSurfaceWorkbenchModel:unavailableProduct");
            testCase.verifyError(@() model.payload("missing", "elevation"), ...
                "ProjectionSurfaceProductCatalog:unknownProduct");
            testCase.verifyError(@() model.observationLinks( ...
                "robust-multi-view", "missing"), ...
                "ProjectionSurfaceWorkbenchModel:unknownPoint");
        end
    end
end
