classdef ProjectionBackendJobTest < matlab.unittest.TestCase
    %ProjectionBackendJobTest Tests for backend job contract serialization.

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
        function testValidateAppliesBackendDefaults(testCase)
            scene = ProjectionBackendJobTest.makeScene();

            job = ProjectionBackendJob.validate(struct(Scene=scene));

            testCase.verifyEqual(job.Format, ProjectionBackendJob.Format);
            testCase.verifyEqual(job.Version, ProjectionBackendJob.Version);
            testCase.verifyEmpty(job.RenderOptions.OutputSize);
            testCase.verifyEmpty(job.RenderOptions.TileSize);
            testCase.verifyEqual(job.RenderOptions.Interpolation, "bilinear");
            testCase.verifyEqual(job.RenderOptions.NumericalMode, ...
                "fullSourceInverseWarp");
            testCase.verifyFalse(job.RenderOptions.UseGPU);
            testCase.verifyTrue(job.RenderOptions.IncludeLayerReadbacks);
            testCase.verifyTrue(job.RenderOptions.IncludeQueryCoordinates);
            testCase.verifyEqual(job.RenderOptions.WorkingPrecision, "double");
            testCase.verifyEqual(job.RenderOptions.InvalidIntersectionPolicy, "error");
            testCase.verifyEqual(job.Output.Formats, ["tiff", "png"]);
            testCase.verifyFalse(job.Output.WriteFiles);
            testCase.verifyEqual(job.Output.InMemoryPolicy, "auto");
            testCase.verifyEqual(job.Output.MaximumInMemoryPixels, 16000000);
            testCase.verifyEqual(job.Output.OutputClass, "uint8");
            testCase.verifyEqual(job.Output.RadiometricScale, 1);
            testCase.verifyEqual(job.Output.RadiometricOffset, 0);
            testCase.verifyEqual(job.Output.FillValue, 0);
            testCase.verifyEqual(job.Output.OutOfRangePolicy, "clip");
            testCase.verifyEqual(job.Execution.Mode, "serial");
            testCase.verifyFalse(job.Execution.UseGPU);
            testCase.verifyFalse(job.Execution.UseCustomGpuKernels);
            testCase.verifyEqual(job.Execution.MaximumInFlightTiles, 4);
            testCase.verifyFalse(job.Alignment.Enabled);
            testCase.verifyTrue(job.Alignment.WriteUpdatedViewerState);
            testCase.verifyTrue(job.Alignment.WriteDiagnostics);
            testCase.verifyEqual(job.Alignment.ViewerStateFileName, ...
                "aligned_viewer_state.json");
            testCase.verifyEqual(job.Alignment.DiagnosticsFileName, ...
                "alignment_diagnostics.json");
        end

        function testValidationRejectsMissingScene(testCase)
            testCase.verifyError( ...
                @() ProjectionBackendJob.validate(struct(RenderOptions=struct())), ...
                "ProjectionBackendJob:missingScene");
        end

        function testValidationRejectsProcessPoolExecution(testCase)
            scene = ProjectionBackendJobTest.makeScene();
            job = struct(Scene=scene, Execution=struct(Mode="processes"));

            testCase.verifyError( ...
                @() ProjectionBackendJob.validate(job), ...
                "ProjectionBackendJob:invalidExecution");
        end

        function testValidationAcceptsThreadPoolExecution(testCase)
            scene = ProjectionBackendJobTest.makeScene();
            job = struct(Scene=scene, ...
                Execution=struct(Mode="threads", MaximumInFlightTiles=2));

            job = ProjectionBackendJob.validate(job);

            testCase.verifyEqual(job.Execution.Mode, "threads");
            testCase.verifyFalse(job.Execution.UseGPU);
            testCase.verifyEqual(job.Execution.MaximumInFlightTiles, 2);
        end

        function testValidationRejectsInvalidInFlightLimit(testCase)
            scene = ProjectionBackendJobTest.makeScene();
            job = struct(Scene=scene, ...
                Execution=struct(MaximumInFlightTiles=0));

            testCase.verifyError( ...
                @() ProjectionBackendJob.validate(job), ...
                "ProjectionBackendJob:invalidExecution");
        end

        function testValidationAcceptsGpuRequests(testCase)
            scene = ProjectionBackendJobTest.makeScene();
            job = struct(Scene=scene, ...
                RenderOptions=struct(UseGPU=true), ...
                Execution=struct(UseGPU=true));

            job = ProjectionBackendJob.validate(job);

            testCase.verifyTrue(job.RenderOptions.UseGPU);
            testCase.verifyTrue(job.Execution.UseGPU);
        end

        function testValidationAcceptsSparseCompatibilityMode(testCase)
            scene = ProjectionBackendJobTest.makeScene();
            job = struct(Scene=scene, RenderOptions=struct( ...
                NumericalMode="sparseIntensityScatteredInterpolant"));

            job = ProjectionBackendJob.validate(job);

            testCase.verifyEqual(job.RenderOptions.NumericalMode, ...
                "sparseIntensityScatteredInterpolant");
        end

        function testValidationRejectsNeverPolicyWithoutFiles(testCase)
            scene = ProjectionBackendJobTest.makeScene();
            job = struct(Scene=scene, ...
                Output=struct(InMemoryPolicy="never"));

            testCase.verifyError( ...
                @() ProjectionBackendJob.validate(job), ...
                "ProjectionBackendJob:invalidOutput");
        end

        function testValidationRejectsSinglePrecisionPngOutput(testCase)
            scene = ProjectionBackendJobTest.makeScene();
            output = struct(Directory=tempname, WriteFiles=true, ...
                Formats="png", OutputClass="single");

            testCase.verifyError(@() ...
                ProjectionBackendJob.validate(struct(Scene=scene, Output=output)), ...
                "ProjectionBackendJob:invalidOutput");
        end

        function testLiveJobInvocationReturnsValidatedContract(testCase)
            scene = ProjectionBackendJobTest.makeScene();
            job = struct();
            job.Scene = scene;
            job.RenderOptions = struct(OutputSize=[3 4], Interpolation="nearest");
            job.Output = struct(Formats="png");

            result = ProjectionBackendProcessor.run(job);

            testCase.verifyEqual(result.Status, "validated");
            testCase.verifyEqual(result.RenderOptions.OutputSize, [3 4]);
            testCase.verifyEqual(result.RenderOptions.Interpolation, "nearest");
            testCase.verifyEqual(result.Output.Formats, "png");
            testCase.verifyEqual(result.Scene.layers.Image, scene.layers.Image);
            testCase.verifySize(result.Readback.Image, [3 4]);
            testCase.verifyEqual(result.Readback.OutputSize, [3 4]);
        end

        function testJsonJobWritesScenePayloadAndLoadsPathJob(testCase)
            tempFolder = string(tempname);
            mkdir(tempFolder);
            testCase.addTeardown(@() ProjectionBackendJobTest.removeFolder(tempFolder));
            scene = ProjectionBackendJobTest.makeScene();
            state = ProjectionBackendJobTest.makeViewerState();
            jobPath = fullfile(tempFolder, "backend_job.json");
            scenePayloadPath = fullfile(tempFolder, "backend_job_scene.mat");
            job = struct(Scene=scene, ViewerState=state, Output=struct(Formats="tiff"));

            ProjectionBackendJob.write(jobPath, job);
            result = ProjectionBackendProcessor.run(jobPath);
            jsonText = fileread(jobPath);

            testCase.verifyTrue(isfile(jobPath));
            testCase.verifyTrue(isfile(scenePayloadPath));
            testCase.verifyTrue(contains(jsonText, '"SceneMatPath"'));
            testCase.verifyFalse(contains(jsonText, '"Scene":'));
            testCase.verifyEqual(result.Scene.layers.Image, scene.layers.Image);
            testCase.verifyEqual(result.ViewerState.Projection.TipDegrees, ...
                state.Projection.TipDegrees, AbsTol=ProjectionBackendJobTest.Tol);
            testCase.verifyEqual(result.Output.Formats, "tiff");
        end

        function testJsonJobLoadsExplicitMatPayloadAndViewerStatePath(testCase)
            tempFolder = string(tempname);
            mkdir(tempFolder);
            testCase.addTeardown(@() ProjectionBackendJobTest.removeFolder(tempFolder));
            scene = ProjectionBackendJobTest.makeScene();
            state = ProjectionBackendJobTest.makeViewerState();
            scenePath = fullfile(tempFolder, "scene_geometry.mat");
            statePath = fullfile(tempFolder, "viewer_state.json");
            jobPath = fullfile(tempFolder, "backend_job.json");
            job = struct(SceneMatPath="scene_geometry.mat", ...
                ViewerStatePath="viewer_state.json", ...
                RenderOptions=struct(OutputSize=[2 3]));

            ProjectionBackendJob.writeScenePayload(scenePath, scene);
            ProjectionViewerState.write(statePath, state);
            ProjectionBackendJob.write(jobPath, job);
            result = ProjectionBackendProcessor.run(jobPath);

            testCase.verifyEqual(result.Job.SceneMatPath, string(scenePath));
            testCase.verifyEqual(result.Job.ViewerStatePath, string(statePath));
            testCase.verifyEqual(result.RenderOptions.OutputSize, [2 3]);
            testCase.verifyEqual(result.Scene.layers.Image, scene.layers.Image);
            testCase.verifyEqual(result.ViewerState.Layers.Alpha, state.Layers.Alpha, ...
                AbsTol=ProjectionBackendJobTest.Tol);
        end

        function testMatJobPathLoadsLiveJob(testCase)
            tempFolder = string(tempname);
            mkdir(tempFolder);
            testCase.addTeardown(@() ProjectionBackendJobTest.removeFolder(tempFolder));
            scene = ProjectionBackendJobTest.makeScene();
            jobPath = fullfile(tempFolder, "backend_job.mat");
            job = struct(Scene=scene, RenderOptions=struct(Interpolation="nearest"));

            ProjectionBackendJob.write(jobPath, job);
            result = ProjectionBackendProcessor.run(jobPath);

            testCase.verifyEqual(result.RenderOptions.Interpolation, "nearest");
            testCase.verifyEqual(result.Scene.renderOrigin, scene.renderOrigin, ...
                AbsTol=ProjectionBackendJobTest.Tol);
            testCase.verifyEqual(result.Scene.layers.Image, scene.layers.Image);
        end
    end

    methods (Static, Access = private)
        function scene = makeScene()
            imageData = reshape(1:30, 5, 6);
            options = struct(RowStride=1, ColumnStride=1, ...
                PlatformDirection=[0; 0; 1]);
            scene = ProjectionViewerHarness.createSceneFromImage( ...
                imageData, "synthetic.tif", options);
        end

        function state = makeViewerState()
            state = struct();
            state.Format = ProjectionViewerState.Format;
            state.Version = ProjectionViewerState.Version;
            state.LayerCount = 1;
            state.SelectedLayerIndex = 1;
            state.Projection = struct(TipDegrees=1.25, TiltDegrees=-0.5);
            state.View = struct(TwistDegrees=0.75);
            state.Layers = ProjectionBackendJobTest.makeLayerState();
        end

        function layer = makeLayerState()
            layer = struct();
            layer.Index = 1;
            layer.Name = "Test image";
            layer.ImagePath = "synthetic.tif";
            layer.Alpha = 0.8;
            layer.Visible = true;
            layer.BlendMode = "alpha";
            layer.ProjectionOffsetMeters = [1 -2];
            layer.ViewVectorAngularOffsetsDegrees = [0.1 0.2 -0.3];
        end

        function removeFolder(folder)
            if isfolder(folder)
                rmdir(folder, "s");
            end
        end
    end
end
