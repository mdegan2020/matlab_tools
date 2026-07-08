classdef ProjectionViewerHarnessTest < matlab.unittest.TestCase
    %ProjectionViewerHarnessTest Tests for the Milestone 1 scene harness.

    properties (Constant)
        Tol = 1e-10
    end

    methods (TestClassSetup)
        function addSourceToPath(testCase)
            projectRoot = fileparts(fileparts(mfilename("fullpath")));
            srcFolder = fullfile(projectRoot, "src");
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(projectRoot));
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

        function testRealDataOptionsExposeDefaultsAndOverrides(testCase)
            options = ProjectionViewerHarness.realDataOptions( ...
                struct(RowStride=4, ColumnStride=5, FrameFocalLength=2, ...
                CoordinateFrame="ecef", InterpolationMethod="nearest"));

            testCase.verifyEqual(options.RowStride, 4);
            testCase.verifyEqual(options.ColumnStride, 5);
            testCase.verifyEqual(options.FrameFocalLength, 2, ...
                AbsTol=ProjectionViewerHarnessTest.Tol);
            testCase.verifyEqual(options.CoordinateFrame, "ecef");
            testCase.verifyEqual(options.InterpolationMethod, "nearest");
            testCase.verifyEqual(options.DisplayTextureMaxPixels, 2e6);
            testCase.verifyTrue(isstruct(options.Metadata));
        end

        function testRealDataSceneCapsDisplayTextureWithoutChangingImage(testCase)
            layerNames = "Large layer";
            imageData = uint8(reshape(mod(0:119, 256), 10, 12));
            imageDataList = {imageData};
            geometryDefinitions = { ...
                ProjectionViewerHarnessTest.makeRealGeometryDefinition( ...
                [10 12], [10; 0; 0], 0)};
            projectionPlane = PlanarProjection.definePlaneFromBasis( ...
                [100; 0; 0], [0; 1; 0], [0; 0; 1]);
            options = ProjectionViewerHarness.realDataOptions( ...
                struct(RowStride=3, ColumnStride=4, ...
                DisplayTextureMaxPixels=25));

            scene = ProjectionViewerHarness.createRealDataScene( ...
                layerNames, imageDataList, geometryDefinitions, ...
                projectionPlane, options);

            testCase.verifyEqual(scene.layers.Image, imageData);
            testCase.verifySize(scene.layers.DisplayTexture, [4 5 3]);
            testCase.verifyEqual(scene.layers.ImageMetadata.ImageSize, [10 12]);
        end

        function testCreateRealDataSceneBuildsGridBackedLayersAndCamera(testCase)
            [layerNames, imageDataList, geometryDefinitions, projectionPlane, ...
                options] = ProjectionViewerHarnessTest.makeRealDataInputs();
            expectedCameraOrigin = mean([ ...
                geometryDefinitions{1}.NominalSceneCenter, ...
                geometryDefinitions{2}.NominalSceneCenter], 2);
            expectedCameraAxis = projectionPlane.P0 - expectedCameraOrigin;
            expectedCameraAxis = expectedCameraAxis / norm(expectedCameraAxis);

            scene = ProjectionViewerHarness.createRealDataScene( ...
                layerNames, imageDataList, geometryDefinitions, ...
                projectionPlane, options);
            [G, V] = scene.layers(2).SourceGeometry.SampleFcn([1 3 5], [1 4 7]);

            testCase.verifyNumElements(scene.layers, 2);
            testCase.verifyEqual([scene.layers.Name], layerNames);
            testCase.verifyEqual(scene.layers(1).Image, imageDataList{1});
            testCase.verifyEqual(scene.layers(2).Image, imageDataList{2});
            testCase.verifyEqual(scene.layers(1).BaseProjectionPlane, projectionPlane);
            testCase.verifyEqual(scene.layers(2).CurrentProjectionPlane, projectionPlane);
            testCase.verifyEqual(scene.renderOrigin, projectionPlane.P0);
            testCase.verifyEqual(scene.frameCamera.G0, expectedCameraOrigin, ...
                AbsTol=ProjectionViewerHarnessTest.Tol);
            testCase.verifyEqual(scene.frameCamera.V0, expectedCameraAxis, ...
                AbsTol=ProjectionViewerHarnessTest.Tol);
            testCase.verifyEqual(scene.layers(1).SourceGeometry.NominalSceneCenter, ...
                geometryDefinitions{1}.NominalSceneCenter);
            testCase.verifySize(G, [3 3]);
            testCase.verifySize(V, [3 3 3]);
            testCase.verifyEqual(squeeze(sqrt(sum(V.^2, 1))), ones(3, 3), ...
                AbsTol=ProjectionViewerHarnessTest.Tol);
        end

        function testCreateRealSourceGeometryAcceptsPublicGeometryAliases(testCase)
            [~, imageDataList, geometryDefinitions] = ...
                ProjectionViewerHarnessTest.makeRealDataInputs();
            geometryDefinition = geometryDefinitions{1};
            geometryDefinition.RowIndices = geometryDefinition.RowPostIndices;
            geometryDefinition.ColumnIndices = geometryDefinition.ColumnPostIndices;
            geometryDefinition.Origins = geometryDefinition.ViewVectorOrigins;
            geometryDefinition = rmfield(geometryDefinition, ...
                {'RowPostIndices', 'ColumnPostIndices', 'ViewVectorOrigins'});
            imageSize = [size(imageDataList{1}, 1), size(imageDataList{1}, 2)];

            sourceGeometry = ProjectionViewerHarness.createRealSourceGeometry( ...
                imageSize, geometryDefinition);

            testCase.verifyEqual(sourceGeometry.RowPostIndices, ...
                geometryDefinitions{1}.RowPostIndices);
            testCase.verifyEqual(sourceGeometry.ColumnPostIndices, ...
                geometryDefinitions{1}.ColumnPostIndices);
            testCase.verifyEqual(sourceGeometry.ViewVectorOrigins, ...
                geometryDefinitions{1}.ViewVectorOrigins);
            testCase.verifyEqual(sourceGeometry.NominalSceneCenter, ...
                geometryDefinitions{1}.NominalSceneCenter);
        end

        function testCreateRealDataSceneRequiresNominalSceneCenter(testCase)
            [layerNames, imageDataList, geometryDefinitions, projectionPlane, ...
                options] = ProjectionViewerHarnessTest.makeRealDataInputs();
            geometryDefinitions{1} = rmfield(geometryDefinitions{1}, ...
                "NominalSceneCenter");

            testCase.verifyError( ...
                @() ProjectionViewerHarness.createRealDataScene( ...
                layerNames, imageDataList, geometryDefinitions, ...
                projectionPlane, options), ...
                "ProjectionViewerHarness:invalidGeometryDefinition");
        end

        function testCreateRealDataSceneRequiresUint8Imagery(testCase)
            [layerNames, imageDataList, geometryDefinitions, projectionPlane, ...
                options] = ProjectionViewerHarnessTest.makeRealDataInputs();
            imageDataList{1} = double(imageDataList{1});

            testCase.verifyError( ...
                @() ProjectionViewerHarness.createRealDataScene( ...
                layerNames, imageDataList, geometryDefinitions, ...
                projectionPlane, options), ...
                "ProjectionViewerHarness:invalidRealImage");
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

        function [layerNames, imageDataList, geometryDefinitions, ...
                projectionPlane, options] = makeRealDataInputs()
            layerNames = ["Forward look", "Aft look"];
            imageDataList = { ...
                uint8(reshape(1:35, 5, 7)), ...
                uint8(reshape(1:105, 5, 7, 3))};
            geometryDefinitions = { ...
                ProjectionViewerHarnessTest.makeRealGeometryDefinition( ...
                [5 7], [10; -2; 1], 0), ...
                ProjectionViewerHarnessTest.makeRealGeometryDefinition( ...
                [5 7], [14; 2; 3], 0.02)};
            projectionPlane = PlanarProjection.definePlaneFromBasis( ...
                [100; 0; 0], [0; 1; 0], [0; 0; 1]);
            options = ProjectionViewerHarness.realDataOptions( ...
                struct(RowStride=2, ColumnStride=3, FrameFocalLength=2));
        end

        function geometryDefinition = makeRealGeometryDefinition( ...
                imageSize, nominalSceneCenter, columnTilt)
            rowPosts = [1 ceil(imageSize(1) / 2) imageSize(1)];
            columnPosts = [1 ceil(imageSize(2) / 2) imageSize(2)];
            origins = [ ...
                nominalSceneCenter(1) + zeros(1, numel(columnPosts)); ...
                nominalSceneCenter(2) + 0.5 * (columnPosts - columnPosts(2)); ...
                nominalSceneCenter(3) + 0.25 * (columnPosts - columnPosts(2))];
            viewVectors = zeros(3, numel(rowPosts), numel(columnPosts));
            centerRow = (imageSize(1) + 1) / 2;
            centerColumn = (imageSize(2) + 1) / 2;
            for rowIndex = 1:numel(rowPosts)
                for columnIndex = 1:numel(columnPosts)
                    viewVectors(:, rowIndex, columnIndex) = [1; ...
                        0.01 * (rowPosts(rowIndex) - centerRow); ...
                        columnTilt + 0.005 * ...
                        (columnPosts(columnIndex) - centerColumn)];
                end
            end
            viewVectors = viewVectors ./ sqrt(sum(viewVectors.^2, 1));

            geometryDefinition = struct();
            geometryDefinition.RowPostIndices = rowPosts;
            geometryDefinition.ColumnPostIndices = columnPosts;
            geometryDefinition.ViewVectorOrigins = origins;
            geometryDefinition.ViewVectors = viewVectors;
            geometryDefinition.NominalSceneCenter = nominalSceneCenter;
            geometryDefinition.Metadata = struct(Source="unit-test");
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
