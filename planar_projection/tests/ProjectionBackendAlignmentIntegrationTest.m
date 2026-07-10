classdef ProjectionBackendAlignmentIntegrationTest < matlab.unittest.TestCase
    %ProjectionBackendAlignmentIntegrationTest Backend alignment workflow tests.

    properties (Constant)
        Tol = 1e-8
    end

    methods (TestClassSetup)
        function addSourceToPath(testCase)
            projectRoot = fileparts(fileparts(mfilename("fullpath")));
            srcFolder = fullfile(projectRoot, "src");
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(srcFolder));
        end
    end

    methods (Test)
        function testLiveBackendJobAlignsBeforeRenderingAllBands(testCase)
            ProjectionBackendAlignmentIntegrationTest.assumeAlignmentAvailable( ...
                testCase);
            scene = ProjectionBackendAlignmentIntegrationTest.makeRgbTexturedScene();
            job = struct(Scene=scene, Alignment= ...
                ProjectionBackendAlignmentIntegrationTest.alignmentOptions(), ...
                RenderOptions=struct(OutputSize=[24 24], Interpolation="nearest"));

            result = ProjectionBackendProcessor.run(job);

            testCase.verifyEqual(result.Status, "aligned");
            testCase.verifyTrue(result.Alignment.Enabled);
            testCase.verifyEqual(result.Alignment.Result.Status, "solved");
            testCase.verifyTrue(result.Alignment.Result.Convergence.Success);
            testCase.verifyLessThanOrEqual( ...
                result.Alignment.Result.Diagnostics.RmsAfter, ...
                result.Alignment.Result.Diagnostics.RmsBefore);
            testCase.verifySize(result.Readback.LayerReadbacks(1).Image, ...
                [24 24 3]);
            testCase.verifySize(result.Readback.LayerReadbacks(2).Image, ...
                [24 24 3]);
            testCase.verifyEqual( ...
                result.Scene.layers(1).ViewVectorAngularOffsetsDegrees.', ...
                result.Alignment.Result.SolvedCorrections(1).ViewVectorAngularOffsetsDegrees, ...
                AbsTol=ProjectionBackendAlignmentIntegrationTest.Tol);
            testCase.verifyEqual( ...
                result.ViewerState.Layers(2).ViewVectorAngularOffsetsDegrees, ...
                result.Scene.layers(2).ViewVectorAngularOffsetsDegrees.', ...
                AbsTol=ProjectionBackendAlignmentIntegrationTest.Tol);
        end

        function testSerializedBackendJobWritesAlignedStateAndDiagnostics(testCase)
            ProjectionBackendAlignmentIntegrationTest.assumeAlignmentAvailable( ...
                testCase);
            tempFolder = string(tempname);
            mkdir(tempFolder);
            testCase.addTeardown(@() ...
                ProjectionBackendAlignmentIntegrationTest.removeFolder(tempFolder));
            outputDirectory = fullfile(tempFolder, "output");
            jobPath = fullfile(tempFolder, "backend_alignment_job.json");
            scene = ProjectionBackendAlignmentIntegrationTest.makeRgbTexturedScene();
            alignment = ProjectionBackendAlignmentIntegrationTest.alignmentOptions();
            output = struct(Directory=outputDirectory, WriteFiles=true, ...
                Formats="png", IncludeComposite=true, IncludeLayers=true);
            job = struct(Scene=scene, Alignment=alignment, Output=output, ...
                RenderOptions=struct(OutputSize=[20 20], Interpolation="nearest"));

            ProjectionBackendJob.write(jobPath, job);
            result = ProjectionBackendProcessor.run(jobPath);
            diagnosticsPath = fullfile(outputDirectory, ...
                alignment.DiagnosticsFileName);
            statePath = fullfile(outputDirectory, alignment.ViewerStateFileName);
            diagnostics = ProjectionAlignmentResult.read(diagnosticsPath);
            alignedState = ProjectionViewerState.read(statePath, 2);
            metadata = jsondecode(fileread(fullfile(outputDirectory, ...
                "metadata.json")));

            testCase.verifyTrue(isfile(diagnosticsPath));
            testCase.verifyTrue(isfile(statePath));
            testCase.verifyTrue(isfile(fullfile(outputDirectory, "composite.png")));
            testCase.verifyEqual(result.Status, "aligned");
            testCase.verifyEqual(diagnostics.Status, "solved");
            testCase.verifyEqual( ...
                alignedState.Layers(1).ViewVectorAngularOffsetsDegrees, ...
                result.ViewerState.Layers(1).ViewVectorAngularOffsetsDegrees, ...
                AbsTol=ProjectionBackendAlignmentIntegrationTest.Tol);
            testCase.verifyEqual(string(metadata.AlignmentSummary.Status), ...
                "solved");
            testCase.verifyEqual(string(metadata.OutputFiles.AlignmentDiagnostics), ...
                string(result.OutputFiles.AlignmentDiagnostics));
            testCase.verifyEqual(string(metadata.OutputFiles.AlignedViewerState), ...
                string(result.OutputFiles.AlignedViewerState));
        end

        function testUnsafeBackendProposalDoesNotMutateScene(testCase)
            ProjectionBackendAlignmentIntegrationTest.assumeAlignmentAvailable( ...
                testCase);
            scene = ProjectionBackendAlignmentIntegrationTest.makeRgbTexturedScene();
            startingOffsets = reshape( ...
                [scene.layers.ViewVectorAngularOffsetsDegrees], 3, []).';
            alignment = ProjectionBackendAlignmentIntegrationTest.alignmentOptions();
            alignment.Request.Options.Bounds = struct( ...
                OmegaDegrees=0, PhiDegrees=0, KappaDegrees=0);
            job = struct(Scene=scene, Alignment=alignment, ...
                RenderOptions=struct(OutputSize=[24 24], ...
                Interpolation="nearest"));

            result = ProjectionBackendProcessor.run(job);
            finalOffsets = reshape( ...
                [result.Scene.layers.ViewVectorAngularOffsetsDegrees], 3, []).';

            testCase.verifyEqual(result.Status, "alignmentRejected");
            testCase.verifyTrue(result.Alignment.Enabled);
            testCase.verifyFalse(result.Alignment.Applied);
            testCase.verifyEqual(result.Alignment.Result.Status, "failed");
            testCase.verifyTrue(result.Alignment.Result.Diagnostics.AnyBoundHit);
            testCase.verifyNotEmpty( ...
                result.Alignment.Result.SolvedCorrections);
            testCase.verifyEqual(finalOffsets, startingOffsets, ...
                AbsTol=ProjectionBackendAlignmentIntegrationTest.Tol);
            testCase.verifyFalse( ...
                result.Alignment.Result.Diagnostics.Applied);
        end
    end

    methods (Static, Access = private)
        function assumeAlignmentAvailable(testCase)
            capabilities = ProjectionAlignmentFeatureMatcher.capabilities();
            testCase.assumeTrue(ismember("sift", capabilities.AvailableDetectors));
            testCase.assumeTrue(exist("lsqnonlin", "file") == 2);
        end

        function alignment = alignmentOptions()
            options = struct();
            options.Detector = struct(Method="sift", MaxFeatures=120);
            options.Matcher = struct(MaxRatio=0.9);
            options.FilterPipeline = struct(GeometricMethod="none");
            options.Scheduling = struct(Strategy="twoImage");
            options.Bounds = struct(OmegaDegrees=0.02, PhiDegrees=0.02, ...
                KappaDegrees=0.02);
            options.Regularization = struct(OverallWeight=1e-6);

            alignment = struct();
            alignment.Enabled = true;
            alignment.Request = struct(LayerIndices=[1 2], ...
                ReferenceLayerIndex=1, AnalysisBands=[1 1], Options=options);
            alignment.RenderOptions = struct(OutputSize=[80 80], ...
                Interpolation="nearest");
            alignment.DiagnosticsFileName = "alignment_diagnostics.json";
            alignment.ViewerStateFileName = "aligned_viewer_state.json";
        end

        function scene = makeRgbTexturedScene()
            imageData = ProjectionBackendAlignmentIntegrationTest.textureImage();
            image1 = cat(3, imageData, 255 - imageData, ...
                uint8(round(double(imageData) / 2)));
            image2 = cat(3, imageData, uint8(round(double(imageData) / 3)), ...
                255 - imageData);
            scene = ProjectionViewerHarness.createSceneFromImages( ...
                {image1, image2}, ["layer1.tif", "layer2.tif"], ...
                struct(RowStride=1, ColumnStride=1));
            scene.layers(1).ViewVectorAngularOffsetsDegrees = [0.004; 0; 0];
            scene.layers(2).ViewVectorAngularOffsetsDegrees = [-0.004; 0; 0];
        end

        function imageData = textureImage()
            [x, y] = meshgrid(1:80, 1:80);
            imageData = uint8(mod(3 * x + 5 * y + ...
                40 * sin(x / 3) + 30 * cos(y / 5), 256));
        end

        function removeFolder(folder)
            if isfolder(folder)
                rmdir(folder, "s");
            end
        end
    end
end
