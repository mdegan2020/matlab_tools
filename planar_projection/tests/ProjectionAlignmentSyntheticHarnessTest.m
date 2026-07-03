classdef ProjectionAlignmentSyntheticHarnessTest < matlab.unittest.TestCase
    %ProjectionAlignmentSyntheticHarnessTest Tests for red/blue alignment scenes.

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
        function testCreateSceneFromRgbImageExtractsSingleBandLayers(testCase)
            rgbImage = ProjectionAlignmentSyntheticHarnessTest.makeRgbImage();

            scene = ProjectionAlignmentSyntheticHarness.createSceneFromRgbImage( ...
                rgbImage, "memory_rgb.tif");

            testCase.verifyNumElements(scene.layers, 2);
            testCase.verifyEqual(scene.layers(1).Image, rgbImage(:, :, 1));
            testCase.verifyEqual(scene.layers(2).Image, rgbImage(:, :, 3));
            testCase.verifyEqual(scene.layers(1).ImageMetadata.BandCount, 1);
            testCase.verifyEqual(scene.layers(2).ImageMetadata.BandCount, 1);
            testCase.verifySize(scene.layers(1).DisplayTexture, [6 7 3]);
            testCase.verifyEqual(scene.AlignmentMetadata.LayerChannels, ["red", "blue"]);
            testCase.verifyEqual(scene.AlignmentMetadata.ChannelIndices, [1 3]);
        end

        function testCreateSceneFromRgbTiffLoadsLocalFixturePath(testCase)
            imagePath = string(tempname) + ".tif";
            rgbImage = ProjectionAlignmentSyntheticHarnessTest.makeRgbImage();
            imwrite(rgbImage, imagePath);
            testCase.addTeardown(@() delete(imagePath));

            scene = ProjectionAlignmentSyntheticHarness.createSceneFromRgbTiff(imagePath);

            testCase.verifyEqual(scene.AlignmentMetadata.SourceImagePath, imagePath);
            testCase.verifyEqual(scene.layers(1).ImagePath, imagePath + "#red");
            testCase.verifyEqual(scene.layers(2).ImagePath, imagePath + "#blue");
            testCase.verifyEqual(scene.layers(1).Image, rgbImage(:, :, 1));
            testCase.verifyEqual(scene.layers(2).Image, rgbImage(:, :, 3));
        end

        function testSyntheticSceneRecordsIndependentGeometryAndPerturbations(testCase)
            rgbImage = ProjectionAlignmentSyntheticHarnessTest.makeRgbImage();

            scene = ProjectionAlignmentSyntheticHarness.createSceneFromRgbImage( ...
                rgbImage, "memory_rgb.tif");

            testCase.verifyGreaterThan(norm( ...
                scene.layers(1).SourceGeometry.ReferenceOrigin - ...
                scene.layers(2).SourceGeometry.ReferenceOrigin), 0);
            testCase.verifyGreaterThan(norm( ...
                scene.layers(1).SourceGeometry.OpticalAxis - ...
                scene.layers(2).SourceGeometry.OpticalAxis), 0);
            testCase.verifyGreaterThan(norm( ...
                scene.layers(1).ViewVectorAngularOffsetsDegrees), 0);
            testCase.verifyGreaterThan(norm( ...
                scene.layers(2).ViewVectorAngularOffsetsDegrees), 0);
            testCase.verifyEqual( ...
                scene.AlignmentMetadata.ExpectedCorrectionDeltaDegrees, ...
                -scene.AlignmentMetadata.ViewVectorAngularOffsetsDegrees, ...
                AbsTol=ProjectionAlignmentSyntheticHarnessTest.Tol);
        end

        function testSyntheticProjectionFootprintsOverlap(testCase)
            rgbImage = uint8(randi([0 255], 12, 14, 3));
            options = struct(RowStride=1, ColumnStride=1);

            scene = ProjectionAlignmentSyntheticHarness.createSceneFromRgbImage( ...
                rgbImage, "memory_rgb.tif", options);
            mesh1 = ProjectionMeshBuilder.buildLayerMesh( ...
                scene.layers(1), scene.layers(1).CurrentProjectionPlane, ...
                scene.renderOrigin);
            mesh2 = ProjectionMeshBuilder.buildLayerMesh( ...
                scene.layers(2), scene.layers(2).CurrentProjectionPlane, ...
                scene.renderOrigin);
            overlapArea = ProjectionAlignmentSyntheticHarnessTest.meshOverlapArea( ...
                mesh1, mesh2, scene.layers(1).CurrentProjectionPlane);

            testCase.verifyGreaterThan(overlapArea, 0);
        end

        function testSyntheticSourceGeometryUsesSampleFcnContract(testCase)
            rgbImage = ProjectionAlignmentSyntheticHarnessTest.makeRgbImage();
            scene = ProjectionAlignmentSyntheticHarness.createSceneFromRgbImage( ...
                rgbImage, "memory_rgb.tif");
            sourceGeometry = scene.layers(2).SourceGeometry;

            [G, V] = sourceGeometry.SampleFcn([1 3 6], [2 5]);

            testCase.verifySize(G, [3 2]);
            testCase.verifySize(V, [3 3 2]);
            testCase.verifyTrue(all(isfinite(G), "all"));
            testCase.verifyTrue(all(isfinite(V), "all"));
            testCase.verifyEqual( ...
                squeeze(sqrt(sum(V.^2, 1))), ones(3, 2), ...
                AbsTol=ProjectionAlignmentSyntheticHarnessTest.Tol);
        end

        function testInvalidNonRgbImageErrors(testCase)
            grayImage = zeros(4, 5, "uint8");

            testCase.verifyError( ...
                @() ProjectionAlignmentSyntheticHarness.createSceneFromRgbImage( ...
                grayImage, "gray.tif"), ...
                "ProjectionAlignmentSyntheticHarness:invalidRgbImage");
        end

        function testInvalidPerturbationShapeErrors(testCase)
            rgbImage = ProjectionAlignmentSyntheticHarnessTest.makeRgbImage();
            options = struct(ViewVectorAngularOffsetsDegrees=[0 0 0]);

            testCase.verifyError( ...
                @() ProjectionAlignmentSyntheticHarness.createSceneFromRgbImage( ...
                rgbImage, "memory_rgb.tif", options), ...
                "ProjectionAlignmentSyntheticHarness:invalidOptions");
        end
    end

    methods (Static, Access = private)
        function rgbImage = makeRgbImage()
            red = uint8(reshape(1:42, 6, 7));
            green = uint8(zeros(6, 7));
            blue = uint8(reshape(101:142, 6, 7));
            rgbImage = cat(3, red, green, blue);
        end

        function area = meshOverlapArea(mesh1, mesh2, plane)
            bounds1 = ProjectionAlignmentSyntheticHarnessTest.meshBounds(mesh1, plane);
            bounds2 = ProjectionAlignmentSyntheticHarnessTest.meshBounds(mesh2, plane);
            overlapWidth = max(0, min(bounds1(2), bounds2(2)) - ...
                max(bounds1(1), bounds2(1)));
            overlapHeight = max(0, min(bounds1(4), bounds2(4)) - ...
                max(bounds1(3), bounds2(3)));
            area = overlapWidth * overlapHeight;
        end

        function bounds = meshBounds(mesh, plane)
            points = reshape(mesh.WorldPoints, 3, []);
            planePoints = PlanarProjection.worldToPlane(points, plane);
            bounds = [min(planePoints(1, :)), max(planePoints(1, :)), ...
                min(planePoints(2, :)), max(planePoints(2, :))];
        end
    end
end
