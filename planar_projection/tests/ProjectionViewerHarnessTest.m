classdef ProjectionViewerHarnessTest < matlab.unittest.TestCase
    %ProjectionViewerHarnessTest Tests for the Milestone 1 scene harness.

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
        function testCreateSceneFromImageBuildsSingleLayerScene(testCase)
            imageData = uint8(reshape(1:60, 4, 5, 3));
            options = ProjectionViewerHarnessTest.makeOptions();

            scene = ProjectionViewerHarness.createSceneFromImage( ...
                imageData, "synthetic.tif", options);
            layer = scene.layers;

            testCase.verifyEqual(numel(scene.layers), 1);
            testCase.verifyTrue(PlanarProjection.validateCamera(scene.frameCamera));
            testCase.verifyEqual(scene.renderOptions.Interpolation, "bilinear");
            testCase.verifyFalse(scene.renderOptions.UseGPU);
            testCase.verifyEqual(scene.renderOptions.InvalidIntersectionPolicy, "error");
            testCase.verifyTrue(PlanarProjection.validatePlane(layer.BaseProjectionPlane));
            testCase.verifyEqual(layer.CurrentProjectionPlane, layer.BaseProjectionPlane);
            testCase.verifyEqual(layer.ImageMetadata.ImageSize, [4 5]);
            testCase.verifyEqual(layer.ImageMetadata.BandCount, 3);
            testCase.verifyEqual(layer.SourceGeometry.ImageSize, [4 5]);
            testCase.verifyEqual(layer.Alpha, 1, AbsTol=ProjectionViewerHarnessTest.Tol);
            testCase.verifyTrue(layer.Visible);
        end

        function testCreateDefaultSceneLoadsExplicitImagePath(testCase)
            imagePath = string(tempname) + ".tif";
            imageData = uint8(reshape(1:75, 5, 5, 3));
            imwrite(imageData, imagePath);
            testCase.addTeardown(@() delete(imagePath));

            scene = ProjectionViewerHarness.createDefaultScene( ...
                imagePath, ProjectionViewerHarnessTest.makeOptions());

            testCase.verifyEqual(scene.layers.ImagePath, imagePath);
            testCase.verifyEqual(scene.layers.Image, imageData);
            testCase.verifyEqual(scene.layers.ImageMetadata.ImageSize, [5 5]);
        end

        function testSourceGeometrySampleFunctionUsesRowColumnContract(testCase)
            imageData = zeros(6, 7, "uint8");
            scene = ProjectionViewerHarness.createSceneFromImage( ...
                imageData, "synthetic.tif", ProjectionViewerHarnessTest.makeOptions());
            sourceGeometry = scene.layers.SourceGeometry;

            [G, V] = sourceGeometry.SampleFcn([1 3 6], [2 5]);
            vectorNorms = squeeze(sqrt(sum(V.^2, 1)));

            testCase.verifySize(G, [3 2]);
            testCase.verifyEqual(size(V, 1), 3);
            testCase.verifyEqual(size(V, 2), 3);
            testCase.verifyEqual(size(V, 3), 2);
            testCase.verifyEqual(G, sourceGeometry.Origins(:, [2 5]), ...
                AbsTol=ProjectionViewerHarnessTest.Tol);
            testCase.verifyEqual(V(:, 2, 1), sourceGeometry.CameraRays(:, 3), ...
                AbsTol=ProjectionViewerHarnessTest.Tol);
            testCase.verifyEqual(V(:, 2, 2), sourceGeometry.CameraRays(:, 3), ...
                AbsTol=ProjectionViewerHarnessTest.Tol);
            testCase.verifyEqual(vectorNorms, ones(3, 2), ...
                AbsTol=ProjectionViewerHarnessTest.Tol);
            testCase.verifyTrue(all(isfinite(G), "all"));
            testCase.verifyTrue(all(isfinite(V), "all"));
        end

        function testMeshSamplingIncludesImageEnds(testCase)
            meshSampling = ProjectionViewerHarness.createMeshSampling([17 19], 5, 7);

            testCase.verifyEqual(meshSampling.RowStride, 5);
            testCase.verifyEqual(meshSampling.ColumnStride, 7);
            testCase.verifyEqual(meshSampling.RowIndices, [1 6 11 16 17]);
            testCase.verifyEqual(meshSampling.ColumnIndices, [1 8 15 19]);
        end

        function testPrepareDisplayTexturePreservesRgbTexture(testCase)
            imageData = uint8(reshape(1:36, 3, 4, 3));

            textureData = ProjectionViewerHarness.prepareDisplayTexture(imageData);

            testCase.verifyClass(textureData, "uint8");
            testCase.verifySize(textureData, [3 4 3]);
            testCase.verifyEqual(textureData, imageData);
        end

        function testPrepareDisplayTextureMapsSingleBandToGrayRgb(testCase)
            imageData = uint8([0 128; 255 64]);
            expectedGray = single(imageData) / single(intmax("uint8"));
            expectedTexture = repmat(expectedGray, 1, 1, 3);

            textureData = ProjectionViewerHarness.prepareDisplayTexture(imageData);

            testCase.verifyClass(textureData, "single");
            testCase.verifySize(textureData, [2 2 3]);
            testCase.verifyEqual(textureData, expectedTexture, AbsTol=single(1e-7));
        end
    end

    methods (Static, Access = private)
        function options = makeOptions()
            options = struct();
            options.GSD = 0.5;
            options.NominalRange = 10000;
            options.RowStride = 2;
            options.ColumnStride = 3;
            options.PlatformDirection = [0; 0; 1];
            options.PlatformStepMeters = 0.5;
            options.FrameFocalLength = 1;
        end
    end
end
