classdef ProjectionBackendRenderPlanTest < matlab.unittest.TestCase
    %ProjectionBackendRenderPlanTest Tests reusable backend plan preparation.

    properties (Constant)
        Tol = 1e-10
    end

    methods (TestClassSetup)
        function addSourceToPath(testCase)
            projectRoot = fileparts(fileparts(mfilename("fullpath")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(projectRoot, "src")));
        end
    end

    methods (Test)
        function testCompileReusesMeshesPreparedByOutputPlanner(testCase)
            scene = ProjectionBackendRenderPlanTest.makeScene();
            [outputGrid, preparedLayers] = ProjectionBackendOutputGrid.plan( ...
                scene, struct(OutputSize=[6 8]));

            plan = ProjectionBackendRenderPlan.compile(scene, ...
                struct(OutputGrid=outputGrid, Interpolation="bilinear"), ...
                preparedLayers);
            summary = ProjectionBackendRenderPlan.summary(plan);

            testCase.verifyEqual(summary.Format, ...
                ProjectionBackendRenderPlan.Format);
            testCase.verifyEqual(summary.LayerIndices, [1 2]);
            testCase.verifyEqual(summary.OutputSize, [6 8]);
            testCase.verifyEqual(summary.Interpolation, "bilinear");
            testCase.verifyEqual(summary.MeshBuildCount, 2);
            testCase.verifyEqual(summary.CompileMeshBuildCount, 0);
            testCase.verifyEqual(summary.ReusedMeshCount, 2);
            testCase.verifyEqual(summary.TopologyBuildCount, 2);
            testCase.verifyEqual(summary.GpuResolutionCount, 1);
            testCase.verifyTrue(summary.RuntimeOnly);
            testCase.verifyTrue(all(arrayfun(@(layer) isa( ...
                layer.InterpolantTemplate, "scatteredInterpolant"), ...
                plan.Layers)));
        end

        function testCompiledReadbackMatchesSceneEntryPoint(testCase)
            scene = ProjectionBackendRenderPlanTest.makeScene();
            outputGrid = ProjectionBackendOutputGrid.plan( ...
                scene, struct(OutputSize=[5 7]));
            options = struct(OutputGrid=outputGrid, Interpolation="nearest");
            plan = ProjectionBackendRenderPlan.compile(scene, options);

            planned = ProjectionReadbackRenderer.renderPlan(plan);
            direct = ProjectionReadbackRenderer.renderScene(scene, options);

            testCase.verifyEqual(planned.Image, direct.Image, ...
                AbsTol=ProjectionBackendRenderPlanTest.Tol);
            testCase.verifyEqual(planned.ValidMask, direct.ValidMask);
            testCase.verifyEqual(planned.RenderPlan.Interpolation, "nearest");
            testCase.verifyEqual(planned.RenderPlan.OutputSize, [5 7]);
        end

        function testTileCountDoesNotChangePlanPreparation(testCase)
            scene = ProjectionBackendRenderPlanTest.makeScene();
            [outputGrid, preparedLayers] = ProjectionBackendOutputGrid.plan( ...
                scene, struct(OutputSize=[7 9]));
            baseOptions = struct(OutputGrid=outputGrid, ...
                Interpolation="bilinear", IncludeLayerReadbacks=false);
            plan = ProjectionBackendRenderPlan.compile( ...
                scene, baseOptions, preparedLayers);

            fine = ProjectionBackendTiledRenderer.renderScene(scene, ...
                ProjectionBackendRenderPlanTest.withTileSize( ...
                baseOptions, [2 3]), struct(), plan);
            coarse = ProjectionBackendTiledRenderer.renderScene(scene, ...
                ProjectionBackendRenderPlanTest.withTileSize( ...
                baseOptions, [7 9]), struct(), plan);

            testCase.verifyGreaterThan(fine.TileCount, coarse.TileCount);
            testCase.verifyEqual(fine.Image, coarse.Image, ...
                AbsTol=ProjectionBackendRenderPlanTest.Tol);
            testCase.verifyEqual(fine.ValidMask, coarse.ValidMask);
            testCase.verifyEqual(fine.RenderPlan.MeshBuildCount, 2);
            testCase.verifyEqual(coarse.RenderPlan.MeshBuildCount, 2);
            testCase.verifyEqual(fine.RenderPlan.TopologyBuildCount, 2);
            testCase.verifyEqual(coarse.RenderPlan.TopologyBuildCount, 2);
            testCase.verifyEqual(fine.RenderPlan.GpuResolutionCount, 1);
            testCase.verifyEqual(coarse.RenderPlan.GpuResolutionCount, 1);
        end

        function testProcessorPublishesPlanSummaryForRunAndValidation(testCase)
            scene = ProjectionBackendRenderPlanTest.makeScene();
            job = struct(Scene=scene, ...
                RenderOptions=struct(OutputSize=[5 7], ...
                Interpolation="nearest", TileSize=[2 3]));

            validation = ProjectionBackendProcessor.validate(job);
            result = ProjectionBackendProcessor.run(job);

            testCase.verifyEqual(validation.RenderPlan.OutputSize, [5 7]);
            testCase.verifyEqual(validation.RenderPlan.Interpolation, "nearest");
            testCase.verifyEqual(validation.RenderPlan.MeshBuildCount, 2);
            testCase.verifyEqual(result.RenderPlan, result.Readback.RenderPlan);
            testCase.verifyEqual(result.RenderPlan.TopologyBuildCount, 2);
            testCase.verifyEqual(result.RenderPlan.GpuResolutionCount, 1);
        end

        function testSummaryContainsNoRuntimeInterpolationObjects(testCase)
            scene = ProjectionBackendRenderPlanTest.makeScene();
            outputGrid = ProjectionBackendOutputGrid.plan( ...
                scene, struct(OutputSize=[4 6]));
            plan = ProjectionBackendRenderPlan.compile( ...
                scene, struct(OutputGrid=outputGrid));

            summary = ProjectionBackendRenderPlan.summary(plan);
            encoded = jsonencode(summary);

            testCase.verifyFalse(isfield(summary, "Layers"));
            testCase.verifyFalse(contains(encoded, "InterpolantTemplate"));
            testCase.verifyTrue(contains(encoded, ...
                "sparseIntensityScatteredInterpolant"));
        end

        function testInvalidPlanIsRejected(testCase)
            testCase.verifyError( ...
                @() ProjectionBackendRenderPlan.validate(struct()), ...
                "ProjectionBackendRenderPlan:invalidPlan");
        end
    end

    methods (Static, Access = private)
        function scene = makeScene()
            image1 = reshape(linspace(0, 1, 30), 5, 6);
            image2 = reshape(linspace(1, 0, 30), 5, 6);
            options = struct(RowStride=1, ColumnStride=1, ...
                PlatformDirection=[0; 0; 1]);
            scene = ProjectionViewerHarness.createSceneFromImages( ...
                {image1, image2}, ["plan-1.tif", "plan-2.tif"], options);
            scene.layers(2).Alpha = 0.5;
        end

        function options = withTileSize(options, tileSize)
            options.TileSize = tileSize;
        end
    end
end
