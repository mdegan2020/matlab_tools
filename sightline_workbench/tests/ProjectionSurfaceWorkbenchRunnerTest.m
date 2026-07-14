classdef ProjectionSurfaceWorkbenchRunnerTest < matlab.unittest.TestCase
    %ProjectionSurfaceWorkbenchRunnerTest Scene-bound RD-5 execution tests.

    methods (TestClassSetup)
        function addPaths(testCase)
            root = fileparts(fileparts(mfilename("fullpath")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(root));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(root, "src")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(root, "tests")));
        end
    end

    methods (TestMethodSetup)
        function closeFigures(testCase)
            testCase.addTeardown(@() close(findall(groot, "Type", "figure")));
        end
    end

    methods (Test)
        function testPreflightReportsExactBoundedProposalAndFallback(testCase)
            [runner, catalog, configuration] = ...
                ProjectionSurfaceWorkbenchRunnerTest.fixture();
            state = ProjectionSurfaceWorkbenchRunnerTest.state( ...
                catalog, configuration, struct(DenseMethod="external", ...
                PairSchedule="quality", ExecutionPath="gpuIfAvailable", ...
                MaximumObservations=8));

            report = runner.preflight(state);

            testCase.verifyTrue(report.Supported);
            testCase.verifyEqual(report.MatcherAlgorithmId, "test.fixture");
            testCase.verifyNumElements(report.SelectedPairIds, 3);
            testCase.verifyEqual(report.SelectedViewIds, catalog.ViewIds);
            testCase.verifyEqual(report.GeometrySearch, "sparseSeeded");
            testCase.verifyEqual(report.ExecutionPath, "gpuIfAvailable");
            testCase.verifyNotEmpty(report.FallbackReason);
            testCase.verifyEqual(report.ResourceEstimate.PairCount, 3);
            testCase.verifyEqual( ...
                report.ResourceEstimate.MaximumObservations, 8);
            testCase.verifyTrue(report.ResourceEstimate.Bounded);
            testCase.verifyFalse( ...
                report.ResourceEstimate.IsWallClockPrediction);
        end

        function testCustomMatcherRunRetainsEvidenceAndMultiViewTruth(testCase)
            [runner, catalog, configuration] = ...
                ProjectionSurfaceWorkbenchRunnerTest.fixture();
            state = ProjectionSurfaceWorkbenchRunnerTest.state( ...
                catalog, configuration, struct(DenseMethod="external", ...
                PairSchedule="quality", MaximumObservations=8));

            outcome = runner.run(state);
            valid = outcome.PointSet.Points( ...
                [outcome.PointSet.Points.Valid]);

            testCase.verifyEqual(outcome.Status, "succeeded");
            testCase.verifyNumElements(outcome.PairRuns, 3);
            testCase.verifyTrue(all(string({outcome.PairRuns.Status}) == ...
                "succeeded"));
            testCase.verifyEqual( ...
                outcome.Diagnostics.AcceptedCorrespondenceCount, 12);
            testCase.verifyEqual( ...
                outcome.Diagnostics.Reconstruction.ValidPointCount, 4);
            testCase.verifyTrue(all([valid.IndependentViewCount] == 3));
            testCase.verifyTrue(outcome.Diagnostics.UncertaintyAvailable);
            testCase.verifyTrue(all(arrayfun(@(run) ...
                run.Evidence.CompleteIntermediateEvidenceRetained, ...
                outcome.PairRuns)));
            testCase.verifyTrue(all(arrayfun(@(run) ...
                isequal(size(run.Evidence.MovingAnalysisImage), [32 32]), ...
                outcome.PairRuns)));
            testCase.verifyFalse(outcome.GraphicsStateIncluded);
        end

        function testTemplateMatcherIsIdentifiableAndRepeatable(testCase)
            [runner, catalog, configuration] = ...
                ProjectionSurfaceWorkbenchRunnerTest.fixture();
            state = ProjectionSurfaceWorkbenchRunnerTest.state( ...
                catalog, configuration, struct( ...
                DenseMethod="classicalTemplate", PairSchedule="fast", ...
                MaximumObservations=8));

            report = runner.preflight(state);
            first = runner.run(state);
            second = runner.run(state);

            testCase.verifyEqual(report.MatcherAlgorithmId, ...
                "sightline.classical-template");
            testCase.verifyEqual(first.Status, "succeeded");
            testCase.verifyEqual(first.PairRuns.MatcherAlgorithmId, ...
                "sightline.classical-template");
            testCase.verifyGreaterThan( ...
                first.Diagnostics.AcceptedCorrespondenceCount, 0);
            testCase.verifyEqual(second.PointSet.GenerationId, ...
                first.PointSet.GenerationId);
            testCase.verifyEqual(second.Diagnostics, first.Diagnostics);
        end

        function testFusionRunUsesRegisteredAlgorithmWithoutForcingDem(testCase)
            [runner, catalog, configuration] = ...
                ProjectionSurfaceWorkbenchRunnerTest.fixture();
            state = ProjectionSurfaceWorkbenchRunnerTest.state( ...
                catalog, configuration, struct(DenseMethod="external", ...
                PairSchedule="quality", ProcessingStage="fusionDerived", ...
                FusionAlgorithm="robustMultiRay"));

            outcome = runner.run(state);
            dem = ProjectionSurfaceProductCatalog.find(outcome.Catalog, "dem");

            testCase.verifyEqual(outcome.Status, "succeeded");
            testCase.verifyEqual(outcome.FusionResult.AlgorithmId, ...
                "sightline.fusion.robust-multi-ray");
            testCase.verifyEqual(dem.Status, "unavailable");
            testCase.verifyGreaterThan( ...
                numel(outcome.FusionResult.FusedPoints), 0);
        end

        function testCancellationAndUnsupportedStatesAreExplicit(testCase)
            [runner, catalog, configuration] = ...
                ProjectionSurfaceWorkbenchRunnerTest.fixture();
            state = ProjectionSurfaceWorkbenchRunnerTest.state( ...
                catalog, configuration, struct(DenseMethod="external"));

            cancelled = runner.run(state, ...
                struct(CancellationFcn=@() true));
            state.ExecutionPath = "gpuRequired";
            unsupportedGpu = runner.run(state);

            defaultRunner = ProjectionSurfaceWorkbenchRunner( ...
                ProjectionSurfaceWorkbenchRunnerTest.context());
            state.ExecutionPath = "cpu";
            unsupportedCustom = defaultRunner.preflight(state);

            testCase.verifyEqual(cancelled.Status, "cancelled");
            testCase.verifyTrue(contains( ...
                cancelled.Message, "between pair stages"));
            testCase.verifyEqual(unsupportedGpu.Status, "unsupported");
            testCase.verifyTrue(contains(unsupportedGpu.Message, "GPU"));
            testCase.verifyFalse(unsupportedCustom.Supported);
            testCase.verifyTrue(contains(unsupportedCustom.Reason, ...
                "external matcher"));
        end

        function testIllConditionedPairEvidenceReturnsExplicitEmpty(testCase)
            context = ProjectionSurfaceWorkbenchRunnerTest.context();
            registries = ProjectionSurfaceWorkbenchRunnerTest.registries();
            normalRunner = ProjectionSurfaceWorkbenchRunner( ...
                context, registries);
            catalog = normalRunner.initialCatalog();
            configuration = normalRunner.initialConfiguration(catalog);
            for index = 1:numel(context.PairEntries)
                entry = context.PairEntries(index);
                scene = entry.Request.Context.Scene;
                first = entry.LayerIndices(1);
                second = entry.LayerIndices(2);
                scene.layers(second).SourceGeometry.SampleRayFcn = ...
                    scene.layers(first).SourceGeometry.SampleRayFcn;
                entry.Request.Context.Scene = scene;
                context.PairEntries(index) = entry;
            end
            weakRunner = ProjectionSurfaceWorkbenchRunner(context, registries);
            state = ProjectionSurfaceWorkbenchRunnerTest.state( ...
                catalog, configuration, struct(DenseMethod="external", ...
                PairSchedule="quality"));

            outcome = weakRunner.run(state);

            testCase.verifyEqual(outcome.Status, "empty");
            testCase.verifyTrue(contains(outcome.Message, ...
                "geometrically ill-conditioned"), outcome.Message);
            testCase.verifyTrue(isfield( ...
                outcome.Diagnostics, "Association"));
        end

        function testWorkbenchRunLifecycleReplacesCatalogAndExports(testCase)
            [runner, catalog, configuration] = ...
                ProjectionSurfaceWorkbenchRunnerTest.fixture();
            app = ProjectionSurfaceWorkbenchApp( ...
                catalog, configuration, runner);
            testCase.addTeardown(@() delete(app));
            app.setSelection(struct(DenseMethod="external", ...
                PairSchedule="quality", SelectedViewIds=catalog.ViewIds, ...
                SelectedPassIds=catalog.PassIds, ...
                SelectedPairIds=catalog.PairIds, MaximumObservations=8));

            report = app.preflight();
            outcome = app.runProcessing();
            diagnostics = app.diagnostics();
            path = string(tempname) + ".mat";
            testCase.addTeardown(@() delete(path));
            app.exportRun(path);
            saved = load(path, "surfaceWorkbenchRun");
            jsonPath = string(tempname) + ".json";
            testCase.addTeardown(@() delete(jsonPath));
            app.exportRun(jsonPath);
            metadata = jsondecode(fileread(jsonPath));
            evidenceButton = findall(app.figureHandle(), ...
                "Tag", "ProjectionSurfaceWorkbenchEvidenceButton");
            evidenceButton.ButtonPushedFcn(evidenceButton, struct());
            drawnow

            testCase.verifyNumElements(report.SelectedPairIds, 3);
            testCase.verifyEqual(outcome.Status, "succeeded");
            testCase.verifyFalse(diagnostics.IsRunning);
            testCase.verifyFalse(diagnostics.CancellationRequested);
            testCase.verifyTrue(diagnostics.RunnerBound);
            testCase.verifyEqual(diagnostics.LastRun.Status, "succeeded");
            testCase.verifyEqual( ...
                saved.surfaceWorkbenchRun.Status, "succeeded");
            testCase.verifyEqual(string(metadata.Status), "succeeded");
            testCase.verifyFalse(isfield(metadata.PairRuns, "Evidence"));
            testCase.verifyFalse(ProjectionSurfaceWorkbenchFixture. ...
                hasRuntimeHandle(saved.surfaceWorkbenchRun));
            testCase.verifyEqual(string(findall(app.figureHandle(), ...
                "Tag", "ProjectionSurfaceWorkbenchRunButton").Enable), "on");
            testCase.verifyEqual(string(findall(app.figureHandle(), ...
                "Tag", "ProjectionSurfaceWorkbenchCancelButton").Enable), ...
                "off");
            testCase.verifyEqual(string(findall(app.figureHandle(), ...
                "Tag", "ProjectionSurfaceWorkbenchEvidenceButton").Enable), ...
                "on");
            testCase.verifyNumElements(findall(groot, "Tag", ...
                "ProjectionSurfaceWorkbenchQualityAxes"), 1);
            testCase.verifyNumElements(findall(groot, "Tag", ...
                "ProjectionSurfaceWorkbenchRayResidualAxes"), 1);
            testCase.verifyNumElements(findall(groot, "Tag", ...
                "ProjectionSurfaceWorkbenchHeightAxes"), 1);
        end

        function testExplicitPairScheduleRunsOnlySelectedIdentity(testCase)
            [runner, catalog, configuration] = ...
                ProjectionSurfaceWorkbenchRunnerTest.fixture();
            selectedPair = catalog.PairIds(2);
            state = ProjectionSurfaceWorkbenchRunnerTest.state( ...
                catalog, configuration, struct(DenseMethod="external", ...
                PairSchedule="operator", SelectedPairIds=selectedPair));

            report = runner.preflight(state);
            outcome = runner.run(state);

            testCase.verifyEqual(report.SelectedPairIds, selectedPair);
            testCase.verifyNumElements(outcome.PairRuns, 1);
            testCase.verifyEqual(outcome.PairRuns.PairId, selectedPair);
            testCase.verifyEqual(outcome.Status, "succeeded");
        end

        function testFiveImageScheduleNamesAllReconstructedAndFusedPairs(testCase)
            context = ProjectionSurfaceWorkbenchRunnerTest.context(5);
            runner = ProjectionSurfaceWorkbenchRunner(context, ...
                ProjectionSurfaceWorkbenchRunnerTest.registries());
            catalog = runner.initialCatalog();
            configuration = runner.initialConfiguration(catalog);
            state = ProjectionSurfaceWorkbenchRunnerTest.state( ...
                catalog, configuration, struct(DenseMethod="external", ...
                PairSchedule="quality", ProcessingStage="fusionDerived", ...
                MaximumObservations=8));

            report = runner.preflight(state);
            outcome = runner.run(state);
            valid = outcome.PointSet.Points( ...
                [outcome.PointSet.Points.Valid]);

            testCase.verifyNumElements(report.SelectedViewIds, 5);
            testCase.verifyNumElements(report.SelectedPairIds, 10);
            testCase.verifyEqual(string({outcome.PairRuns.PairId}), ...
                report.SelectedPairIds);
            testCase.verifyEqual(outcome.Provenance.PairIds, ...
                report.SelectedPairIds);
            testCase.verifyEqual(outcome.Status, "succeeded");
            testCase.verifyEqual( ...
                outcome.Diagnostics.AcceptedCorrespondenceCount, 40);
            testCase.verifyTrue(all([valid.IndependentViewCount] == 5));
            testCase.verifyNumElements(outcome.Catalog.PairIds, 10);
            testCase.verifyEqual(outcome.FusionResult.AlgorithmId, ...
                "sightline.fusion.robust-multi-ray");
        end
    end

    methods (Static, Access = private)
        function [runner, catalog, configuration] = fixture()
            context = ProjectionSurfaceWorkbenchRunnerTest.context();
            registries = ProjectionSurfaceWorkbenchRunnerTest.registries();
            runner = ProjectionSurfaceWorkbenchRunner(context, registries);
            catalog = runner.initialCatalog();
            configuration = runner.initialConfiguration(catalog);
        end

        function registries = registries()
            matcherRegistry = ProjectionDenseMatcherRegistry({ ...
                ProjectionDenseSgmMatcher(), ...
                ProjectionDenseTemplateMatcher(), ...
                ProjectionDenseMatcherFixture()});
            fusionRegistry = ProjectionSurfaceFusionRegistry({ ...
                ProjectionRobustMultiRayFusion(), ...
                ProjectionExampleSurfaceFusion()});
            registries = struct( ...
                MatcherRegistry=matcherRegistry, ...
                FusionRegistry=fusionRegistry);
        end

        function context = context(viewCount)
            if nargin < 1
                viewCount = 3;
            end
            sizePixels = 32;
            [columns, rows] = meshgrid(1:sizePixels, 1:sizePixels);
            imageData = uint8(mod(17 * rows .^ 2 + 31 * columns + ...
                7 * rows .* columns, 251));
            imageList = repmat({imageData}, 1, viewCount);
            paths = "view-" + (1:viewCount) + ".tif";
            scene = ProjectionViewerHarness.createSceneFromImages( ...
                imageList, paths, struct( ...
                RowStride=1, ColumnStride=1, GSD=2, ...
                PlatformStepMeters=20, NominalRange=100));
            scene = ProjectionLayerIdentity.ensureScene(scene);
            for index = 1:viewCount
                scene.layers(index).PassId = "pass-" + ceil(index / 3);
            end
            layerCoordinate = (1:viewCount) - (viewCount + 1) / 2;
            rowShift = 0.5 - layerCoordinate;
            columnShift = -0.5 * layerCoordinate;
            pairs = nchoosek(1:viewCount, 2);
            entries = repmat(struct(PairId="", ...
                ViewIds=strings(1, 2), PassIds=strings(1, 2), ...
                LayerIndices=zeros(1, 2), Request=struct()), ...
                1, size(pairs, 1));
            sparse = [12; 16; 20; 24];
            overlap = false(sizePixels);
            overlap(3:end - 2, 3:end - 2) = true;
            for index = 1:size(pairs, 1)
                pair = pairs(index, :);
                layerIds = string({scene.layers(pair).LayerId});
                pairImages(1) = struct(LayerId=layerIds(1), ...
                    Image=double(imageData), ValidMask=true(sizePixels), ...
                    SourceRows=double(rows) + rowShift(pair(1)), ...
                    SourceColumns=double(columns) + columnShift(pair(1)));
                pairImages(2) = struct(LayerId=layerIds(2), ...
                    Image=double(imageData), ValidMask=true(sizePixels), ...
                    SourceRows=double(rows) + rowShift(pair(2)), ...
                    SourceColumns=double(columns) + columnShift(pair(2)));
                pairWorking = struct(Pair=pair, PairLayerIds=layerIds, ...
                    LayerImages=pairImages, OverlapMask=struct(Mask=overlap));
                pairMatch = struct(Count=numel(sparse), Pair=pair, ...
                    MovingSourceRows=sparse + rowShift(pair(1)), ...
                    MovingSourceColumns=sparse + columnShift(pair(1)), ...
                    ReferenceSourceRows=sparse + rowShift(pair(2)), ...
                    ReferenceSourceColumns=sparse + columnShift(pair(2)), ...
                    Scores=ones(numel(sparse), 1));
                request = ProjectionDenseSgmMatcher.requestFromLegacy( ...
                    scene, pairWorking, pairMatch, struct());
                entries(index) = struct(PairId=request.PairId, ...
                    ViewIds=request.ViewIds, ...
                    PassIds=string({scene.layers(pair).PassId}), ...
                    LayerIndices=pair, Request=request);
            end
            context = struct(PairEntries=entries, ...
                ActivePairId=entries(1).PairId);
        end

        function value = state(catalog, configuration, changes)
            configuration.SelectedViewIds = catalog.ViewIds;
            configuration.SelectedPassIds = catalog.PassIds;
            configuration.SelectedPairIds = catalog.PairIds;
            model = ProjectionSurfaceWorkbenchModel(catalog, configuration);
            model.configure(changes);
            value = model.state();
        end
    end
end
