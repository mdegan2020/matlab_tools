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
            testCase.verifyEqual(string(metadata.OutputFiles.Metadata), ...
                string(result.OutputFiles.Metadata));
            testCase.verifyEqual(metadata.LayerIndices(:).', [1 2]);
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

        function removeFolder(folder)
            if isfolder(folder)
                rmdir(folder, "s");
            end
        end
    end
end
