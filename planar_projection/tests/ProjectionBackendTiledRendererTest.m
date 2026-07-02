classdef ProjectionBackendTiledRendererTest < matlab.unittest.TestCase
    %ProjectionBackendTiledRendererTest Tests for serial tiled CPU rendering.

    properties (Constant)
        Tol = 1e-10
    end

    methods (TestClassSetup)
        function addSourceToPath(testCase)
            projectRoot = fileparts(fileparts(mfilename("fullpath")));
            srcFolder = fullfile(projectRoot, "src");
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(srcFolder));
        end
    end

    methods (Test)
        function testTiledMatchesUntiledComposite(testCase)
            scene = ProjectionBackendTiledRendererTest.makeTwoLayerScene();
            [untiled, tiled] = ...
                ProjectionBackendTiledRendererTest.renderUntiledAndTiled(scene);

            testCase.verifyTrue(tiled.Tiled);
            testCase.verifyEqual(tiled.OutputSize, [5 7]);
            testCase.verifyEqual(tiled.Image, untiled.Image, ...
                AbsTol=ProjectionBackendTiledRendererTest.Tol);
            testCase.verifyEqual(tiled.ValidMask, untiled.ValidMask);
        end

        function testTiledMatchesUntiledLayerReadbacks(testCase)
            scene = ProjectionBackendTiledRendererTest.makeTwoLayerScene();
            [untiled, tiled] = ...
                ProjectionBackendTiledRendererTest.renderUntiledAndTiled(scene);

            testCase.verifyNumElements(tiled.LayerReadbacks, 2);
            testCase.verifyEqual(tiled.LayerReadbacks(1).Image, ...
                untiled.LayerReadbacks(1).Image, ...
                AbsTol=ProjectionBackendTiledRendererTest.Tol);
            testCase.verifyEqual(tiled.LayerReadbacks(2).Image, ...
                untiled.LayerReadbacks(2).Image, ...
                AbsTol=ProjectionBackendTiledRendererTest.Tol);
            testCase.verifyEqual(tiled.LayerReadbacks(1).ValidMask, ...
                untiled.LayerReadbacks(1).ValidMask);
            testCase.verifyEqual(tiled.LayerReadbacks(2).ValidMask, ...
                untiled.LayerReadbacks(2).ValidMask);
        end

        function testTiledRendererReportsTileTimingAndMemory(testCase)
            scene = ProjectionBackendTiledRendererTest.makeTwoLayerScene();
            outputGrid = ProjectionBackendTiledRendererTest.makeOutputGrid(scene);
            options = struct(OutputGrid=outputGrid, TileSize=[2 3]);

            readback = ProjectionBackendTiledRenderer.renderScene(scene, options);

            testCase.verifyEqual(readback.TileCount, 9);
            testCase.verifyNumElements(readback.TileReports, 9);
            testCase.verifyEqual(readback.TileReports(1).RowRange, [1 2]);
            testCase.verifyEqual(readback.TileReports(1).ColumnRange, [1 3]);
            testCase.verifyGreaterThanOrEqual([readback.TileReports.RenderSeconds], ...
                zeros(1, 9));
            testCase.verifyGreaterThan([readback.TileReports.EstimatedMemoryBytes], ...
                zeros(1, 9));
        end

        function testProcessorUsesTiledRendererWhenTileSizeSet(testCase)
            scene = ProjectionBackendTiledRendererTest.makeTwoLayerScene();
            job = struct(Scene=scene, ...
                RenderOptions=struct(OutputSize=[5 7], TileSize=[2 3]));

            result = ProjectionBackendProcessor.run(job);

            testCase.verifyTrue(result.Readback.Tiled);
            testCase.verifyEqual(result.RenderOptions.TileSize, [2 3]);
            testCase.verifyEqual(result.Readback.TileCount, 9);
            testCase.verifySize(result.Readback.Image, [5 7]);
        end

        function testLayerReadbacksCanBeDisabledForTiledRendering(testCase)
            scene = ProjectionBackendTiledRendererTest.makeTwoLayerScene();
            outputGrid = ProjectionBackendTiledRendererTest.makeOutputGrid(scene);
            options = struct(OutputGrid=outputGrid, TileSize=[2 3], ...
                IncludeLayerReadbacks=false);

            readback = ProjectionBackendTiledRenderer.renderScene(scene, options);

            testCase.verifyTrue(readback.Tiled);
            testCase.verifyEqual(readback.LayerIndices, [1 2]);
            testCase.verifyEmpty(readback.LayerReadbacks);
            testCase.verifyEmpty(readback.QueryPlaneCoordinates);
            testCase.verifyEmpty(readback.Mesh);
        end

        function testInvalidTileSizeErrors(testCase)
            scene = ProjectionBackendTiledRendererTest.makeTwoLayerScene();

            testCase.verifyError( ...
                @() ProjectionBackendTiledRenderer.renderScene(scene, ...
                struct(TileSize=[0 3])), ...
                "ProjectionBackendTiledRenderer:invalidOptions");
        end
    end

    methods (Static, Access = private)
        function [untiled, tiled] = renderUntiledAndTiled(scene)
            outputGrid = ProjectionBackendTiledRendererTest.makeOutputGrid(scene);
            untiledOptions = struct(OutputGrid=outputGrid);
            tiledOptions = struct(OutputGrid=outputGrid, TileSize=[2 3]);

            untiled = ProjectionReadbackRenderer.renderScene(scene, untiledOptions);
            tiled = ProjectionBackendTiledRenderer.renderScene(scene, tiledOptions);
        end

        function outputGrid = makeOutputGrid(scene)
            outputGrid = ProjectionBackendOutputGrid.plan(scene, ...
                struct(OutputSize=[5 7]));
        end

        function scene = makeTwoLayerScene()
            imageData1 = reshape(linspace(0, 1, 20), 4, 5);
            imageData2 = reshape(linspace(1, 0, 20), 4, 5);
            options = struct(RowStride=1, ColumnStride=1, ...
                PlatformDirection=[0; 0; 1]);
            scene = ProjectionViewerHarness.createSceneFromImages( ...
                {imageData1, imageData2}, ["layer1.tif", "layer2.tif"], ...
                options);
            scene.layers(2).Alpha = 0.5;
        end
    end
end
