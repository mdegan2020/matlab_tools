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

        function testCreateDefaultSceneLoadsMultipleImagePaths(testCase)
            imagePath1 = string(tempname) + ".tif";
            imagePath2 = string(tempname) + ".tif";
            imageData1 = uint8(reshape(1:60, 4, 5, 3));
            imageData2 = uint8(reshape(1:72, 6, 4, 3));
            imwrite(imageData1, imagePath1);
            imwrite(imageData2, imagePath2);
            testCase.addTeardown(@() delete(imagePath1));
            testCase.addTeardown(@() delete(imagePath2));

            scene = ProjectionViewerHarness.createDefaultScene( ...
                [imagePath1 imagePath2], ProjectionViewerHarnessTest.makeOptions());

            testCase.verifyNumElements(scene.layers, 2);
            testCase.verifyEqual(scene.layers(1).Image, imageData1);
            testCase.verifyEqual(scene.layers(2).Image, imageData2);
            testCase.verifyEqual(scene.layers(1).ImageMetadata.ImageSize, [4 5]);
            testCase.verifyEqual(scene.layers(2).ImageMetadata.ImageSize, [6 4]);
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

        function testCreateSceneFromImagesBuildsIndependentOverlappingLayers(testCase)
            imageData1 = zeros(5, 6, "uint8");
            imageData2 = ones(7, 4, "uint8");
            options = ProjectionViewerHarnessTest.makeOptions();
            options.RowStride = 1;
            options.ColumnStride = 1;

            scene = ProjectionViewerHarness.createSceneFromImages( ...
                {imageData1, imageData2}, ["layer1.tif", "layer2.tif"], options);
            mesh1 = ProjectionMeshBuilder.buildLayerMesh( ...
                scene.layers(1), scene.layers(1).CurrentProjectionPlane, scene.renderOrigin);
            mesh2 = ProjectionMeshBuilder.buildLayerMesh( ...
                scene.layers(2), scene.layers(2).CurrentProjectionPlane, scene.renderOrigin);
            centerDistance = norm(ProjectionViewerHarnessTest.meshCenter(mesh1) - ...
                ProjectionViewerHarnessTest.meshCenter(mesh2));

            testCase.verifyNumElements(scene.layers, 2);
            testCase.verifyEqual(scene.layers(1).SourceGeometry.ImageSize, [5 6]);
            testCase.verifyEqual(scene.layers(2).SourceGeometry.ImageSize, [7 4]);
            testCase.verifyEqual(scene.layers(1).BaseProjectionPlane, ...
                scene.layers(2).BaseProjectionPlane);
            testCase.verifyGreaterThan(norm( ...
                scene.layers(1).SourceGeometry.ReferenceOrigin - ...
                scene.layers(2).SourceGeometry.ReferenceOrigin), 0);
            testCase.verifyGreaterThan(norm( ...
                scene.layers(1).SourceGeometry.OpticalAxis - ...
                scene.layers(2).SourceGeometry.OpticalAxis), 0);
            testCase.verifyLessThan(centerDistance, ...
                min(ProjectionViewerHarnessTest.meshSpan(mesh1), ...
                ProjectionViewerHarnessTest.meshSpan(mesh2)));
        end

        function testProjectionPlaneModeStereoUsesStereoPlane(testCase)
            imageData = zeros(4, 5, "uint8");
            options = ProjectionViewerHarnessTest.makeOptions();
            options.ProjectionPlaneMode = "stereo";
            expectedPlane = PlanarProjection.defineStereoPlane( ...
                [0; 0; -1], [1; 0; 0], options.NominalRange, ...
                [0; 0; 1], [1; 0; 0], options.NominalRange);

            scene = ProjectionViewerHarness.createSceneFromImage( ...
                imageData, "synthetic.tif", options);

            testCase.verifyEqual(scene.layers.BaseProjectionPlane.P0, ...
                expectedPlane.P0, AbsTol=ProjectionViewerHarnessTest.Tol);
            testCase.verifyEqual(scene.layers.BaseProjectionPlane.basis, ...
                expectedPlane.basis, AbsTol=ProjectionViewerHarnessTest.Tol);
            testCase.verifyEqual(scene.layers.BaseProjectionPlane.VN, ...
                expectedPlane.VN, AbsTol=ProjectionViewerHarnessTest.Tol);
            testCase.verifyEqual(scene.layers.CurrentProjectionPlane, ...
                scene.layers.BaseProjectionPlane);
        end

        function testProjectionPlaneModeFitBuildsValidPlane(testCase)
            imageData = zeros(4, 5, "uint8");
            options = ProjectionViewerHarnessTest.makeOptions();
            options.ProjectionPlaneMode = "fit";

            scene = ProjectionViewerHarness.createSceneFromImage( ...
                imageData, "synthetic.tif", options);

            testCase.verifyTrue(PlanarProjection.validatePlane( ...
                scene.layers.BaseProjectionPlane));
            testCase.verifyEqual(scene.layers.BaseProjectionPlane.P0, ...
                [options.NominalRange; 0; 0], AbsTol=ProjectionViewerHarnessTest.Tol);
            testCase.verifyEqual(scene.renderOrigin, scene.layers.BaseProjectionPlane.P0);
        end

        function testExplicitProjectionPlaneOverridesMode(testCase)
            imageData = zeros(4, 5, "uint8");
            customPlane = ProjectionViewerHarnessTest.makeCustomPlane();
            options = ProjectionViewerHarnessTest.makeOptions();
            options.ProjectionPlaneMode = "stereo";
            options.ProjectionPlane = customPlane;

            scene = ProjectionViewerHarness.createSceneFromImage( ...
                imageData, "synthetic.tif", options);

            testCase.verifyEqual(scene.layers.BaseProjectionPlane, customPlane);
            testCase.verifyEqual(scene.layers.CurrentProjectionPlane, customPlane);
            testCase.verifyEqual(scene.renderOrigin, customPlane.P0);
        end

        function testApplyProjectionPlaneUpdatesLayersAndFrameCamera(testCase)
            imageData = ones(4, 5);
            scene = ProjectionViewerHarness.createSceneFromImage( ...
                imageData, "layer1.tif", ProjectionViewerHarnessTest.makeOptions());
            secondLayer = scene.layers;
            secondLayer.Name = "Layer 2";
            scene.layers = [scene.layers secondLayer];
            customPlane = ProjectionViewerHarnessTest.makeCustomPlane();

            scene = ProjectionViewerHarness.applyProjectionPlane(scene, customPlane);

            testCase.verifyEqual(scene.layers(1).BaseProjectionPlane, customPlane);
            testCase.verifyEqual(scene.layers(2).BaseProjectionPlane, customPlane);
            testCase.verifyEqual(scene.layers(1).CurrentProjectionPlane, customPlane);
            testCase.verifyEqual(scene.layers(2).CurrentProjectionPlane, customPlane);
            testCase.verifyEqual(scene.renderOrigin, customPlane.P0);
            testCase.verifyTrue(PlanarProjection.validateCamera(scene.frameCamera));
            testCase.verifyEqual(scene.frameCamera.focalPlane.basis(:, 1), ...
                customPlane.basis(:, 1), AbsTol=ProjectionViewerHarnessTest.Tol);
        end

        function testInvalidProjectionPlaneModeErrors(testCase)
            imageData = zeros(4, 5, "uint8");
            options = ProjectionViewerHarnessTest.makeOptions();
            options.ProjectionPlaneMode = "banana";

            testCase.verifyError( ...
                @() ProjectionViewerHarness.createSceneFromImage( ...
                imageData, "synthetic.tif", options), ...
                "ProjectionViewerHarness:invalidProjectionPlaneMode");
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

        function plane = makeCustomPlane()
            plane = PlanarProjection.definePlaneFromBasis( ...
                [9000; 10; 20], [0; 1; 0], [0; 0; 1]);
        end

        function center = meshCenter(mesh)
            points = reshape(mesh.WorldPoints, 3, []);
            center = mean(points, 2);
        end

        function span = meshSpan(mesh)
            points = reshape(mesh.WorldPoints, 3, []);
            span = norm(max(points, [], 2) - min(points, [], 2));
        end
    end
end
