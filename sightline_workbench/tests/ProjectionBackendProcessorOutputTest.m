classdef ProjectionBackendProcessorOutputTest < matlab.unittest.TestCase
    %ProjectionBackendProcessorOutputTest Tests for backend rendering and writers.

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
        function testRunProducesCompositeAndLayerReadbacks(testCase)
            scene = ProjectionBackendProcessorOutputTest.makeTwoLayerScene();
            job = struct(Scene=scene, RenderOptions=struct(OutputSize=[3 4]));

            result = ProjectionBackendProcessor.run(job);

            testCase.verifyEqual(result.Status, "validated");
            testCase.verifySize(result.Readback.Image, [3 4]);
            testCase.verifySize(result.Readback.ValidMask, [3 4]);
            testCase.verifyNumElements(result.Readback.LayerReadbacks, 2);
            testCase.verifyEqual(result.Readback.LayerIndices, [1 2]);
            testCase.verifyEmpty(result.OutputFiles);
            testCase.verifyGreaterThanOrEqual(result.Timing.RenderSeconds, 0);
        end

        function testRunWritesCompositeLayersMasksAndMetadata(testCase)
            outputDirectory = string(tempname);
            mkdir(outputDirectory);
            testCase.addTeardown(@() ...
                ProjectionBackendProcessorOutputTest.removeFolder(outputDirectory));
            scene = ProjectionBackendProcessorOutputTest.makeTwoLayerScene();
            output = struct(Directory=outputDirectory, WriteFiles=true, ...
                Formats=["png", "tiff"], IncludeComposite=true, IncludeLayers=true);
            job = struct(Scene=scene, RenderOptions=struct(OutputSize=[3 4]), ...
                Output=output);

            result = ProjectionBackendProcessor.run(job);
            metadata = jsondecode(fileread(fullfile(outputDirectory, "metadata.json")));

            testCase.verifyTrue(isfile(fullfile(outputDirectory, "composite.png")));
            testCase.verifyTrue(isfile(fullfile(outputDirectory, "composite.tif")));
            testCase.verifyTrue(isfile(fullfile(outputDirectory, "composite_mask.png")));
            testCase.verifyTrue(isfile(fullfile(outputDirectory, ...
                "layer_001_layer1_tif.png")));
            testCase.verifyTrue(isfile(fullfile(outputDirectory, ...
                "layer_001_layer1_tif.tif")));
            testCase.verifyTrue(isfile(fullfile(outputDirectory, ...
                "layer_001_layer1_tif_mask.png")));
            testCase.verifyTrue(isfile(fullfile(outputDirectory, ...
                "layer_002_layer2_tif.png")));
            testCase.verifyTrue(isfile(fullfile(outputDirectory, ...
                "layer_002_layer2_tif.tif")));
            testCase.verifyTrue(isfile(fullfile(outputDirectory, ...
                "layer_002_layer2_tif_mask.png")));
            testCase.verifyEqual(string(metadata.Format), ...
                ProjectionBackendOutputWriter.MetadataFormat);
            testCase.verifyEqual(metadata.OutputGrid.OutputSize(:).', [3 4]);
            testCase.verifyEqual(string(metadata.RenderPlan.Format), ...
                ProjectionBackendRenderPlan.Format);
            testCase.verifyEqual(metadata.RenderPlan.OutputSize(:).', [3 4]);
            testCase.verifyEqual(string(metadata.RenderPlan.Interpolation), ...
                "bilinear");
            testCase.verifyEqual(string(metadata.RenderPlan.NumericalMode), ...
                "fullSourceInverseWarp");
            testCase.verifyEqual(metadata.RenderPlan.MeshBuildCount, 2);
            testCase.verifyEqual(metadata.RenderPlan.TopologyBuildCount, 2);
            testCase.verifyEqual(string(metadata.OutputFiles.Metadata), ...
                string(result.OutputFiles.Metadata));
            testCase.verifyEqual(metadata.LayerIndices(:).', [1 2]);
        end

        function testRunRendersAppliedViewerState(testCase)
            scene = ProjectionBackendProcessorOutputTest.makeTwoLayerScene();
            state = ProjectionBackendProcessorOutputTest.makeViewerState(scene);
            job = struct(Scene=scene, ViewerState=state, ...
                RenderOptions=struct(OutputSize=[3 4]));

            result = ProjectionBackendProcessor.run(job);

            testCase.verifyEqual(result.Status, "stateApplied");
            testCase.verifyEqual( ...
                result.Readback.LayerReadbacks(2).Mesh.ProjectionOffsetMeters, ...
                [-0.75; 1.25], AbsTol=ProjectionBackendProcessorOutputTest.Tol);
            testCase.verifyEqual(result.Scene.layers(2).Alpha, 0.45, ...
                AbsTol=ProjectionBackendProcessorOutputTest.Tol);
        end

        function testSerialStreamingTiffMatchesInMemoryReference(testCase)
            outputDirectory = string(tempname);
            mkdir(outputDirectory);
            testCase.addTeardown(@() ...
                ProjectionBackendProcessorOutputTest.removeFolder(outputDirectory));
            scene = ProjectionBackendProcessorOutputTest.makeTwoLayerScene();
            renderOptions = struct(OutputSize=[17 19], TileSize=[16 16]);
            reference = ProjectionBackendProcessor.run( ...
                struct(Scene=scene, RenderOptions=renderOptions));
            output = struct(Directory=outputDirectory, WriteFiles=true, ...
                Formats="tiff", IncludeComposite=true, IncludeLayers=true, ...
                InMemoryPolicy="never");

            streamed = ProjectionBackendProcessor.run( ...
                struct(Scene=scene, RenderOptions=renderOptions, Output=output));
            diskComposite = im2double(imread(fullfile( ...
                outputDirectory, "composite.tif")));
            diskMask = logical(imread(fullfile( ...
                outputDirectory, "composite_mask.tif")));
            expectedComposite = double(uint8(round( ...
                255 * reference.Readback.Image))) / 255;

            testCase.verifyTrue(streamed.Readback.Streaming);
            testCase.verifyFalse(streamed.Readback.ReturnedInMemory);
            testCase.verifyEmpty(streamed.Readback.Image);
            testCase.verifyEmpty(streamed.Readback.ValidMask);
            testCase.verifyEmpty(streamed.Readback.QueryPlaneCoordinates);
            testCase.verifyEqual(streamed.Readback.TileCount, 4);
            testCase.verifyGreaterThanOrEqual( ...
                [streamed.Readback.TileReports.WriteSeconds], zeros(1, 4));
            testCase.verifyEqual(diskComposite, expectedComposite);
            testCase.verifyEqual(diskMask, reference.Readback.ValidMask);
            testCase.verifyTrue(isfile(fullfile( ...
                outputDirectory, "layer_001_layer1_tif.tif")));
            testCase.verifyTrue(isfile(fullfile( ...
                outputDirectory, "layer_001_layer1_tif_mask.tif")));
            testCase.verifyEqual(string(streamed.OutputFiles.Composite.Path), ...
                string(fullfile(outputDirectory, "composite.tif")));
        end

        function testAutoPolicyStreamsAbovePixelLimit(testCase)
            outputDirectory = string(tempname);
            mkdir(outputDirectory);
            testCase.addTeardown(@() ...
                ProjectionBackendProcessorOutputTest.removeFolder(outputDirectory));
            scene = ProjectionBackendProcessorOutputTest.makeTwoLayerScene();
            output = struct(Directory=outputDirectory, WriteFiles=true, ...
                Formats="tiff", IncludeLayers=false, ...
                MaximumInMemoryPixels=1);
            job = struct(Scene=scene, ...
                RenderOptions=struct(OutputSize=[3 4], TileSize=[16 16]), ...
                Output=output);

            result = ProjectionBackendProcessor.run(job);

            testCase.verifyTrue(result.Readback.Streaming);
            testCase.verifyFalse(result.Readback.ReturnedInMemory);
            testCase.verifyEmpty(result.OutputFiles.Layers);
        end

        function testStreamingTiffPreservesArbitraryBandCount(testCase)
            outputDirectory = string(tempname);
            mkdir(outputDirectory);
            testCase.addTeardown(@() ...
                ProjectionBackendProcessorOutputTest.removeFolder(outputDirectory));
            imageData = reshape(linspace(0, 1, 80), 4, 5, 4);
            scene = ProjectionViewerHarness.createSceneFromImages( ...
                {imageData}, "four_band.tif", ...
                struct(RowStride=1, ColumnStride=1));
            output = struct(Directory=outputDirectory, WriteFiles=true, ...
                Formats="tiff", IncludeLayers=false, ...
                InMemoryPolicy="never");
            job = struct(Scene=scene, ...
                RenderOptions=struct(OutputSize=[17 19], TileSize=[16 16]), ...
                Output=output);

            result = ProjectionBackendProcessor.run(job);
            diskImage = imread(fullfile(outputDirectory, "composite.tif"));

            testCase.verifySize(diskImage, [17 19 4]);
            testCase.verifyTrue(result.Readback.Streaming);
        end

        function testStreamingRejectsPng(testCase)
            outputDirectory = string(tempname);
            mkdir(outputDirectory);
            testCase.addTeardown(@() ...
                ProjectionBackendProcessorOutputTest.removeFolder(outputDirectory));
            scene = ProjectionBackendProcessorOutputTest.makeTwoLayerScene();
            output = struct(Directory=outputDirectory, WriteFiles=true, ...
                Formats="png", InMemoryPolicy="never");
            job = struct(Scene=scene, ...
                RenderOptions=struct(OutputSize=[3 4], TileSize=[16 16]), ...
                Output=output);

            testCase.verifyError( ...
                @() ProjectionBackendProcessor.run(job), ...
                "ProjectionBackendProcessor:streamingRequiresTiff");
        end

        function testStreamingFailureRemovesPartialFiles(testCase)
            outputDirectory = string(tempname);
            mkdir(outputDirectory);
            testCase.addTeardown(@() ...
                ProjectionBackendProcessorOutputTest.removeFolder(outputDirectory));
            scene = ProjectionBackendProcessorOutputTest.makeTwoLayerScene();
            scene.layers(1).Image(:) = 2;
            scene.layers(1).Alpha = 0;
            output = struct(Directory=outputDirectory, WriteFiles=true, ...
                Formats="tiff", InMemoryPolicy="never");
            job = struct(Scene=scene, ...
                RenderOptions=struct(OutputSize=[3 4], TileSize=[16 16]), ...
                Output=output);

            testCase.verifyError( ...
                @() ProjectionBackendProcessor.run(job), ...
                "ProjectionBackendTiffTileWriter:radiometryOutOfRange");
            testCase.verifyEmpty(dir(fullfile(outputDirectory, "*.partial")));
            testCase.verifyFalse(isfile(fullfile( ...
                outputDirectory, "composite.tif")));
            testCase.verifyFalse(isfile(fullfile( ...
                outputDirectory, "metadata.json")));
        end
    end

    methods (Static, Access = private)
        function scene = makeTwoLayerScene()
            imageData1 = reshape(linspace(0, 1, 20), 4, 5);
            imageData2 = reshape(linspace(1, 0, 30), 5, 6);
            options = struct(RowStride=1, ColumnStride=1);
            scene = ProjectionViewerHarness.createSceneFromImages( ...
                {imageData1, imageData2}, ["layer1.tif", "layer2.tif"], ...
                options);
        end

        function state = makeViewerState(scene)
            state = struct();
            state.Format = ProjectionViewerState.Format;
            state.Version = ProjectionViewerState.Version;
            state.LayerCount = numel(scene.layers);
            state.SelectedLayerIndex = 2;
            state.Projection = struct(TipDegrees=2.5, TiltDegrees=-1.5);
            state.View = struct(TwistDegrees=0);
            state.Layers = [ ...
                ProjectionBackendProcessorOutputTest.makeLayerState( ...
                scene.layers(1), 1, 1, [0 0]), ...
                ProjectionBackendProcessorOutputTest.makeLayerState( ...
                scene.layers(2), 2, 0.45, [-0.75 1.25])];
        end

        function layerState = makeLayerState(layer, index, alpha, projectionOffsetMeters)
            layerState = struct();
            layerState.Index = index;
            layerState.Name = layer.Name;
            layerState.ImagePath = layer.ImagePath;
            layerState.Alpha = alpha;
            layerState.Visible = layer.Visible;
            layerState.BlendMode = layer.BlendMode;
            layerState.ProjectionOffsetMeters = projectionOffsetMeters;
            layerState.ViewVectorAngularOffsetsDegrees = ...
                layer.ViewVectorAngularOffsetsDegrees.';
        end

        function removeFolder(folder)
            if isfolder(folder)
                rmdir(folder, "s");
            end
        end
    end
end
