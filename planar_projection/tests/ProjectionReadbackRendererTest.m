classdef ProjectionReadbackRendererTest < matlab.unittest.TestCase
    %ProjectionReadbackRendererTest Tests for headless frame-camera readback.

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
        function testRenderSceneReturnsDeterministicBilinearOutput(testCase)
            scene = ProjectionReadbackRendererTest.makeSingleBandScene();
            options = struct(OutputSize=[4 5]);

            firstReadback = ProjectionReadbackRenderer.renderScene(scene, options);
            secondReadback = ProjectionReadbackRenderer.renderScene(scene, options);

            testCase.verifyEqual(firstReadback.Interpolation, "bilinear");
            testCase.verifySize(firstReadback.Image, [4 5]);
            testCase.verifySize(firstReadback.ValidMask, [4 5]);
            testCase.verifySize(firstReadback.CameraGrid.X, [4 5]);
            testCase.verifySize(firstReadback.CameraGrid.Y, [4 5]);
            testCase.verifySize(firstReadback.QueryPlaneCoordinates, [2 20]);
            testCase.verifyTrue(isequaln(firstReadback.Image, secondReadback.Image));
            testCase.verifyTrue(all(firstReadback.ValidMask, "all"));
        end

        function testNearestInterpolationIsConfigurable(testCase)
            scene = ProjectionReadbackRendererTest.makeSingleBandScene();
            options = struct(OutputSize=[3 4], Interpolation="nearest");

            readback = ProjectionReadbackRenderer.renderScene(scene, options);

            testCase.verifyEqual(readback.Interpolation, "nearest");
            testCase.verifySize(readback.Image, [3 4]);
            testCase.verifyTrue(all(readback.ValidMask, "all"));
        end

        function testRgbReadbackPreservesThreeBands(testCase)
            scene = ProjectionReadbackRendererTest.makeRgbScene();
            options = struct(OutputSize=[4 5]);

            readback = ProjectionReadbackRenderer.renderScene(scene, options);

            testCase.verifySize(readback.Image, [4 5 3]);
            testCase.verifySize(readback.ValidMask, [4 5]);
        end

        function testCurrentPlaneStateAffectsReadbackMesh(testCase)
            scene = ProjectionReadbackRendererTest.makeSingleBandScene();
            baseReadback = ProjectionReadbackRenderer.renderScene(scene, struct(OutputSize=[4 5]));
            layer = scene.layers;
            layer.CurrentProjectionPlane = ProjectionMeshBuilder.applyPlaneTipTilt( ...
                layer.BaseProjectionPlane, pi / 50, pi / 70);
            scene.layers = layer;

            tiltedReadback = ProjectionReadbackRenderer.renderScene(scene, struct(OutputSize=[4 5]));
            meshDifference = max(abs(tiltedReadback.Mesh.WorldPoints - ...
                baseReadback.Mesh.WorldPoints), [], "all");

            testCase.verifyGreaterThan(meshDifference, 1e-3);
        end

        function testInvalidInterpolationErrors(testCase)
            scene = ProjectionReadbackRendererTest.makeSingleBandScene();

            testCase.verifyError( ...
                @() ProjectionReadbackRenderer.renderScene(scene, ...
                struct(Interpolation="bicubic")), ...
                "ProjectionReadbackRenderer:invalidOptions");
        end
    end

    methods (Static, Access = private)
        function scene = makeSingleBandScene()
            imageData = reshape(1:30, 5, 6);
            scene = ProjectionViewerHarness.createSceneFromImage( ...
                imageData, "synthetic.tif", ProjectionReadbackRendererTest.makeOptions());
        end

        function scene = makeRgbScene()
            red = reshape(1:30, 5, 6);
            green = red + 100;
            blue = red + 200;
            imageData = cat(3, red, green, blue);
            scene = ProjectionViewerHarness.createSceneFromImage( ...
                imageData, "synthetic.tif", ProjectionReadbackRendererTest.makeOptions());
        end

        function options = makeOptions()
            options = struct();
            options.RowStride = 1;
            options.ColumnStride = 1;
            options.PlatformDirection = [0; 0; 1];
        end
    end
end
