classdef ProjectionBackendProcessorValidationTest < matlab.unittest.TestCase
    %ProjectionBackendProcessorValidationTest Tests validate-only backend flow.

    properties (Constant)
        Tol = 1e-10
    end

    methods (TestClassSetup)
        function addProjectToPath(testCase)
            projectRoot = fileparts(fileparts(mfilename("fullpath")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(projectRoot));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(projectRoot, "src")));
        end
    end

    methods (Test)
        function testValidateLiveJobPlansWithoutReadback(testCase)
            scene = ProjectionBackendProcessorValidationTest.makeTwoLayerScene();
            job = struct(Scene=scene, RenderOptions=struct(OutputSize=[5 7]));

            validation = ProjectionBackendProcessor.validate(job);

            testCase.verifyEqual(validation.Status, "valid");
            testCase.verifyFalse(validation.StateApplied);
            testCase.verifyEqual(validation.OutputGrid.OutputSize, [5 7]);
            testCase.verifyEqual(validation.RenderPlan.OutputSize, [5 7]);
            testCase.verifyEqual(validation.RenderPlan.Interpolation, "bilinear");
            testCase.verifyEqual(validation.RenderPlan.NumericalMode, ...
                "fullSourceInverseWarp");
            testCase.verifyEqual(validation.RenderPlan.MeshBuildCount, 2);
            testCase.verifyEqual(validation.RenderPlan.TopologyBuildCount, 2);
            testCase.verifyEqual(validation.RenderPlan.GpuResolutionCount, 1);
            testCase.verifyFalse(isfield(validation, "Readback"));
            testCase.verifyFalse(validation.GpuInfo.Requested);
        end

        function testValidateJsonPathResolvesMatPayload(testCase)
            tempFolder = string(tempname);
            mkdir(tempFolder);
            testCase.addTeardown(@() ...
                ProjectionBackendProcessorValidationTest.removeFolder(tempFolder));
            scene = ProjectionBackendProcessorValidationTest.makeTwoLayerScene();
            jobPath = fullfile(tempFolder, "backend_job.json");
            scenePayloadPath = fullfile(tempFolder, "backend_job_scene.mat");
            job = struct(Scene=scene, RenderOptions=struct(OutputSize=[5 7]));

            ProjectionBackendJob.write(jobPath, job);
            validation = ProjectionBackendProcessor.validate(jobPath);

            testCase.verifyTrue(isfile(scenePayloadPath));
            testCase.verifyEqual(validation.Status, "valid");
            testCase.verifyEqual(validation.Job.SceneMatPath, string(scenePayloadPath));
            testCase.verifyEqual(validation.OutputGrid.OutputSize, [5 7]);
        end

        function testValidateCommandReturnsValidation(testCase)
            scene = ProjectionBackendProcessorValidationTest.makeTwoLayerScene();
            job = struct(Scene=scene, RenderOptions=struct(OutputSize=[5 7]));

            validation = validateProjectionBackendJob(job);

            testCase.verifyEqual(validation.Format, "ProjectionBackendValidation");
            testCase.verifyEqual(validation.Status, "valid");
            testCase.verifyGreaterThanOrEqual( ...
                validation.Timing.ValidationSeconds, 0);
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
        end

        function removeFolder(folder)
            if isfolder(folder)
                rmdir(folder, "s");
            end
        end
    end
end
