classdef ProjectionRasterPreviewRendererTest < matlab.unittest.TestCase
    %ProjectionRasterPreviewRendererTest Tests for the optional CPU raster path.

    methods (TestClassSetup)
        function addSourceToPath(testCase)
            projectRoot = fileparts(fileparts(mfilename("fullpath")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(projectRoot, "src")));
        end
    end

    methods (Test)
        function testCompileAndCompositeReturnOneRgbRaster(testCase)
            scene = ProjectionRasterPreviewRendererTest.makeScene();
            camera = ProjectionRasterPreviewRendererTest.cameraForScene( ...
                scene, [72 96]);

            plan = ProjectionRasterPreviewRenderer.compile(scene, camera, ...
                struct(OutputSize=[72 96]));
            result = ProjectionRasterPreviewRenderer.composite( ...
                plan, scene.layers);

            testCase.verifyEqual(plan.Format, ...
                ProjectionRasterPreviewRenderer.Format);
            testCase.verifySize(result.Image, [72 96 3]);
            testCase.verifySize(result.ValidMask, [72 96]);
            testCase.verifyGreaterThan(nnz(result.ValidMask), 0.3 * 72 * 96);
            testCase.verifyClass(result.Image, "single");
            testCase.verifyTrue(plan.CpuComplete);
            testCase.verifyTrue(result.CpuComplete);
        end

        function testCompiledPlanSupportsAlphaAndVisibilityWithoutRecompile(testCase)
            scene = ProjectionRasterPreviewRendererTest.makeTwoLayerScene();
            camera = ProjectionRasterPreviewRendererTest.cameraForScene( ...
                scene, [60 80]);
            plan = ProjectionRasterPreviewRenderer.compile(scene, camera, ...
                struct(OutputSize=[60 80], SourceMode="fullSourceDisplay"));
            validMask = plan.Layers(1).ValidMask & plan.Layers(2).ValidMask;

            scene.layers(1).Alpha = 1;
            scene.layers(2).Alpha = 0.5;
            alphaResult = ProjectionRasterPreviewRenderer.composite( ...
                plan, scene.layers);
            scene.layers(2).Visible = false;
            hiddenResult = ProjectionRasterPreviewRenderer.composite( ...
                plan, scene.layers);

            testCase.verifyEqual(alphaResult.Image(repmat(validMask, 1, 1, 3)), ...
                single(0.5) * ones(3 * nnz(validMask), 1, "single"), ...
                AbsTol=2e-5);
            testCase.verifyEqual(hiddenResult.Image(repmat(validMask, 1, 1, 3)), ...
                single(0.2) * ones(3 * nnz(validMask), 1, "single"), ...
                AbsTol=2e-5);
            testCase.verifyEqual(plan.LayerIndices, [1 2]);
        end

        function testFullSourceRasterAgreesWithExactReadbackOnAffineScene(testCase)
            scene = ProjectionRasterPreviewRendererTest.makeScene();
            outputSize = [64 88];
            camera = ProjectionRasterPreviewRendererTest.cameraForScene( ...
                scene, outputSize);
            raster = ProjectionRasterPreviewRenderer.render(scene, camera, ...
                struct(OutputSize=outputSize, ...
                SourceMode="fullSourceDisplay", Interpolation="bilinear"));
            outputGrid = ProjectionViewportGrid.asOutputGrid( ...
                raster.Plan.ViewportGrid);
            exact = ProjectionReadbackRenderer.renderScene(scene, ...
                struct(OutputGrid=outputGrid, Interpolation="bilinear", ...
                InvalidFillValue=0, IncludeLayerReadbacks=false));
            exactRgb = repmat(single(exact.Image), 1, 1, 3);
            commonMask = raster.ValidMask & exact.ValidMask;
            differences = abs(raster.Image - exactRgb);

            testCase.verifyGreaterThan(nnz(commonMask), 0.3 * prod(outputSize));
            testCase.verifyLessThan(max(differences( ...
                repmat(commonMask, 1, 1, 3)), [], "all"), 2e-4);
        end

        function testDisplayTextureModeDoesNotUseFullImageRadiometry(testCase)
            scene = ProjectionRasterPreviewRendererTest.makeScene();
            scene.layers.Image(:) = 0;
            scene.layers.DisplayTexture(:) = 0.75;
            camera = ProjectionRasterPreviewRendererTest.cameraForScene( ...
                scene, [48 64]);

            displayResult = ProjectionRasterPreviewRenderer.render( ...
                scene, camera, struct(OutputSize=[48 64], ...
                SourceMode="displayTexture"));
            fullResult = ProjectionRasterPreviewRenderer.render( ...
                scene, camera, struct(OutputSize=[48 64], ...
                SourceMode="fullSourceDisplay"));
            validMask = displayResult.ValidMask & fullResult.ValidMask;

            testCase.verifyGreaterThan(mean(displayResult.Image( ...
                repmat(validMask, 1, 1, 3))), 0.7);
            testCase.verifyEqual(fullResult.Image( ...
                repmat(validMask, 1, 1, 3)), ...
                zeros(3 * nnz(validMask), 1, "single"));
        end

        function testInvisibleAtCompileCanBeShownFromRetainedLayerRaster(testCase)
            scene = ProjectionRasterPreviewRendererTest.makeTwoLayerScene();
            scene.layers(2).Visible = false;
            camera = ProjectionRasterPreviewRendererTest.cameraForScene( ...
                scene, [50 70]);
            plan = ProjectionRasterPreviewRenderer.compile(scene, camera, ...
                struct(OutputSize=[50 70], SourceMode="fullSourceDisplay"));
            hidden = ProjectionRasterPreviewRenderer.composite(plan, scene.layers);
            scene.layers(2).Visible = true;
            shown = ProjectionRasterPreviewRenderer.composite(plan, scene.layers);

            commonMask = plan.Layers(1).ValidMask & plan.Layers(2).ValidMask;
            testCase.verifyEqual(hidden.Image(repmat(commonMask, 1, 1, 3)), ...
                single(0.2) * ones(3 * nnz(commonMask), 1, "single"), ...
                AbsTol=2e-5);
            testCase.verifyEqual(shown.Image(repmat(commonMask, 1, 1, 3)), ...
                single(0.8) * ones(3 * nnz(commonMask), 1, "single"), ...
                AbsTol=2e-5);
        end

        function testAnaglyphUsesRedThenBlueChannels(testCase)
            scene = ProjectionRasterPreviewRendererTest.makeTwoLayerScene();
            [scene.layers.BlendMode] = deal("redBlueAnaglyph");
            camera = ProjectionRasterPreviewRendererTest.cameraForScene( ...
                scene, [40 60]);

            result = ProjectionRasterPreviewRenderer.render(scene, camera, ...
                struct(OutputSize=[40 60], SourceMode="fullSourceDisplay"));
            mask = result.Plan.Layers(1).ValidMask & ...
                result.Plan.Layers(2).ValidMask;

            testCase.verifyEqual(result.Image(:, :, 2), ...
                zeros(40, 60, "single"));
            red = result.Image(:, :, 1);
            blue = result.Image(:, :, 3);
            testCase.verifyEqual(double(red(mask)), ...
                0.2 * ones(nnz(mask), 1), AbsTol=2e-5);
            testCase.verifyEqual(double(blue(mask)), ...
                0.8 * ones(nnz(mask), 1), AbsTol=2e-5);
        end

        function testAppExposesDiagnosticRasterWithoutChangingScene(testCase)
            scene = ProjectionRasterPreviewRendererTest.makeScene();
            app = ProjectionViewerApp(scene);
            cleanup = onCleanup(@() delete(app));
            stateBefore = app.exportState();

            result = app.renderRasterPreview(struct(OutputSize=[42 58]));
            stateAfter = app.exportState();

            testCase.verifySize(result.Image, [42 58 3]);
            testCase.verifyEqual(stateAfter, stateBefore);
            clear cleanup
        end
    end

    methods (Static, Access = private)
        function scene = makeScene()
            [x, y] = meshgrid(single(linspace(0, 1, 32)), ...
                single(linspace(0, 1, 24)));
            imageData = 0.65 * x + 0.35 * y;
            options = struct(RowStride=1, ColumnStride=1, ...
                PlatformDirection=[0; 0; 1]);
            scene = ProjectionViewerHarness.createSceneFromImage( ...
                imageData, "raster-preview.tif", options);
        end

        function scene = makeTwoLayerScene()
            options = struct(RowStride=1, ColumnStride=1, ...
                PlatformDirection=[0; 0; 1]);
            scene = ProjectionViewerHarness.createSceneFromImages( ...
                {single(0.2 * ones(24, 32)), ...
                single(0.8 * ones(24, 32))}, ...
                ["layer1.tif", "layer2.tif"], options);
        end

        function camera = cameraForScene(scene, outputSize)
            plane = scene.layers(1).CurrentProjectionPlane;
            position = scene.frameCamera.G0 - scene.renderOrigin;
            target = plane.P0 - scene.renderOrigin;
            upVector = scene.frameCamera.focalPlane.basis(:, 2);
            viewDirection = target - position;
            viewDistance = norm(viewDirection);
            viewDirection = viewDirection / viewDistance;
            upVector = upVector / norm(upVector);
            rightVector = cross(viewDirection, upVector);
            rightVector = rightVector / norm(rightVector);
            mesh = ProjectionMeshBuilder.buildLayerMesh( ...
                scene.layers(1), plane, scene.renderOrigin);
            points = reshape(mesh.RenderPoints, 3, []);
            width = max(rightVector.' * points) - min(rightVector.' * points);
            height = max(upVector.' * points) - min(upVector.' * points);
            aspect = outputSize(2) / outputSize(1);
            viewHeight = max(height / 0.8, width / (0.8 * aspect));
            viewAngle = rad2deg(2 * atan(viewHeight / (2 * viewDistance)));
            camera = struct(Position=position, Target=target, ...
                UpVector=upVector, ViewAngle=viewAngle, ...
                Projection="orthographic");
        end
    end
end
