classdef ProjectionBackendGpuSupportTest < matlab.unittest.TestCase
    %ProjectionBackendGpuSupportTest Tests optional GPU capability handling.

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
        function testResolveReportsCpuWhenGpuNotRequested(testCase)
            info = ProjectionBackendGpuSupport.resolve(false);

            testCase.verifyFalse(info.Requested);
            testCase.verifyFalse(info.Enabled);
            testCase.verifyEqual(info.FallbackReason, "");
        end

        function testGpuRequestMatchesCapability(testCase)
            capability = ProjectionBackendGpuSupport.capability();

            info = ProjectionBackendGpuSupport.resolve(true);

            testCase.verifyTrue(info.Requested);
            testCase.verifyEqual(info.Available, capability.Available);
            testCase.verifyEqual(info.Enabled, capability.Available);
        end

        function testGpuRequestedOutputMatchesCpuOutput(testCase)
            scene = ProjectionBackendGpuSupportTest.makeTwoLayerScene();
            cpuJob = struct(Scene=scene, ...
                RenderOptions=struct(OutputSize=[5 7], UseGPU=false));
            gpuJob = struct(Scene=scene, ...
                RenderOptions=struct(OutputSize=[5 7], UseGPU=true));
            expectedGpuInfo = ProjectionBackendGpuSupport.resolve(true);

            cpuResult = ProjectionBackendProcessor.run(cpuJob);
            gpuResult = ProjectionBackendProcessor.run(gpuJob);

            testCase.verifyTrue(gpuResult.Readback.GpuInfo.Requested);
            testCase.verifyEqual(gpuResult.Readback.UseGPU, expectedGpuInfo.Enabled);
            testCase.verifyEqual(gpuResult.GpuInfo.Enabled, expectedGpuInfo.Enabled);
            testCase.verifyEqual(gpuResult.Readback.Image, cpuResult.Readback.Image, ...
                AbsTol=ProjectionBackendGpuSupportTest.Tol);
            testCase.verifyEqual(gpuResult.Readback.ValidMask, ...
                cpuResult.Readback.ValidMask);
        end

        function testExecutionGpuRequestIsAppliedToRenderOptions(testCase)
            scene = ProjectionBackendGpuSupportTest.makeTwoLayerScene();
            job = struct(Scene=scene, RenderOptions=struct(OutputSize=[5 7]), ...
                Execution=struct(UseGPU=true));
            expectedGpuInfo = ProjectionBackendGpuSupport.resolve(true);

            result = ProjectionBackendProcessor.run(job);

            testCase.verifyTrue(result.RenderOptions.UseGPU);
            testCase.verifyTrue(result.GpuInfo.Requested);
            testCase.verifyEqual(result.GpuInfo.Enabled, expectedGpuInfo.Enabled);
        end

        function testTiledGpuRequestCarriesEffectiveGpuInfo(testCase)
            scene = ProjectionBackendGpuSupportTest.makeTwoLayerScene();
            job = struct(Scene=scene, ...
                RenderOptions=struct(OutputSize=[5 7], TileSize=[2 3], ...
                UseGPU=true));
            expectedGpuInfo = ProjectionBackendGpuSupport.resolve(true);

            result = ProjectionBackendProcessor.run(job);

            testCase.verifyTrue(result.Readback.Tiled);
            testCase.verifyTrue(result.Readback.GpuInfo.Requested);
            testCase.verifyEqual(result.Readback.UseGPU, expectedGpuInfo.Enabled);
        end
    end

    methods (Static, Access = private)
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
