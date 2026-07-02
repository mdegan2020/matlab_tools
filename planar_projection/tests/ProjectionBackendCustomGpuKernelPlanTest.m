classdef ProjectionBackendCustomGpuKernelPlanTest < matlab.unittest.TestCase
    %ProjectionBackendCustomGpuKernelPlanTest Tests custom-kernel guardrails.

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
        function testAssessmentKeepsCustomKernelsDisabled(testCase)
            plan = ProjectionBackendCustomGpuKernelPlan.assessment();

            testCase.verifyEqual(plan.Format, ...
                ProjectionBackendCustomGpuKernelPlan.Format);
            testCase.verifyFalse(plan.CustomKernelsEnabled);
            testCase.verifyEqual(plan.Decision, ...
                "notJustifiedWithoutProfileEvidence");
            testCase.verifyEqual(plan.CpuReference, ...
                "ProjectionReadbackRenderer.renderScene");
        end

        function testAssessmentIncludesCandidateKernelDesign(testCase)
            plan = ProjectionBackendCustomGpuKernelPlan.assessment();

            testCase.verifyEqual(plan.CandidateKernel.Name, ...
                "tileProjectionInterpolationKernel");
            testCase.verifyTrue(contains( ...
                plan.CandidateKernel.TargetBottleneck, "interpolation"));
            testCase.verifyTrue(any(contains( ...
                plan.CandidateKernel.EquivalenceReferences, "CPU")));
            testCase.verifyTrue(any(contains( ...
                plan.CandidateKernel.EquivalenceReferences, "gpuArray")));
        end

        function testJobDefaultsDisableCustomGpuKernels(testCase)
            scene = ProjectionBackendCustomGpuKernelPlanTest.makeTwoLayerScene();

            job = ProjectionBackendJob.validate(struct(Scene=scene));

            testCase.verifyFalse(job.Execution.UseCustomGpuKernels);
        end

        function testJobRejectsCustomGpuKernelRequest(testCase)
            scene = ProjectionBackendCustomGpuKernelPlanTest.makeTwoLayerScene();
            job = struct(Scene=scene, ...
                Execution=struct(UseCustomGpuKernels=true));

            testCase.verifyError(@() ProjectionBackendJob.validate(job), ...
                "ProjectionBackendCustomGpuKernelPlan:notEnabled");
        end

        function testMatlabManagedGpuRequestMatchesCpuReference(testCase)
            scene = ProjectionBackendCustomGpuKernelPlanTest.makeTwoLayerScene();
            cpuJob = struct(Scene=scene, ...
                RenderOptions=struct(OutputSize=[5 7], UseGPU=false));
            gpuJob = struct(Scene=scene, ...
                RenderOptions=struct(OutputSize=[5 7], UseGPU=true));

            cpuResult = ProjectionBackendProcessor.run(cpuJob);
            gpuResult = ProjectionBackendProcessor.run(gpuJob);

            testCase.verifyEqual(gpuResult.Readback.Image, cpuResult.Readback.Image, ...
                AbsTol=ProjectionBackendCustomGpuKernelPlanTest.Tol);
            testCase.verifyEqual(gpuResult.Readback.ValidMask, ...
                cpuResult.Readback.ValidMask);
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
