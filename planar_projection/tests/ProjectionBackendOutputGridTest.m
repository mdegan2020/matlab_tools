classdef ProjectionBackendOutputGridTest < matlab.unittest.TestCase
    %ProjectionBackendOutputGridTest Tests for backend full-extent grid planning.

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
        function testPlanCoversVisibleLayerUnion(testCase)
            scene = ProjectionBackendOutputGridTest.makeTwoLayerScene();
            scene.layers(2).ProjectionOffsetMeters = [4; -1];

            grid = ProjectionBackendOutputGrid.plan(scene, ...
                struct(ResolutionMetersPerPixel=0.5));
            expectedBounds = ProjectionBackendOutputGridTest.combinedBounds( ...
                scene, grid, [1 2]);

            testCase.verifyEqual(grid.LayerIndices, [1 2]);
            ProjectionBackendOutputGridTest.verifyBoundsContain( ...
                testCase, grid.Bounds, expectedBounds);
        end

        function testPlanIgnoresInvisibleLayers(testCase)
            scene = ProjectionBackendOutputGridTest.makeTwoLayerScene();
            scene.layers(2).Visible = false;
            scene.layers(2).ProjectionOffsetMeters = [50; 50];

            grid = ProjectionBackendOutputGrid.plan(scene, ...
                struct(ResolutionMetersPerPixel=0.5));
            expectedBounds = ProjectionBackendOutputGridTest.combinedBounds( ...
                scene, grid, 1);

            testCase.verifyEqual(grid.LayerIndices, 1);
            testCase.verifyEqual(grid.Bounds.X, expectedBounds.X, ...
                AbsTol=ProjectionBackendOutputGridTest.Tol);
            testCase.verifyEqual(grid.Bounds.Y, expectedBounds.Y, ...
                AbsTol=ProjectionBackendOutputGridTest.Tol);
        end

        function testTwistRotatesOutputAxes(testCase)
            scene = ProjectionBackendOutputGridTest.makeTwoLayerScene();
            state = ProjectionBackendOutputGridTest.makeViewerState(scene, 30);

            grid = ProjectionBackendOutputGrid.plan(scene, state, ...
                struct(ResolutionMetersPerPixel=0.5));
            expectedXAxis = ProjectionBackendOutputGridTest.rotateVectorAboutAxis( ...
                scene.layers(1).BaseProjectionPlane.basis(:, 1), ...
                scene.layers(1).BaseProjectionPlane.VN, deg2rad(30));
            expectedYAxis = ProjectionBackendOutputGridTest.rotateVectorAboutAxis( ...
                scene.layers(1).BaseProjectionPlane.basis(:, 2), ...
                scene.layers(1).BaseProjectionPlane.VN, deg2rad(30));

            testCase.verifyEqual(grid.TwistDegrees, 30, ...
                AbsTol=ProjectionBackendOutputGridTest.Tol);
            testCase.verifyEqual(grid.XAxis, expectedXAxis, ...
                AbsTol=ProjectionBackendOutputGridTest.Tol);
            testCase.verifyEqual(grid.YAxis, expectedYAxis, ...
                AbsTol=ProjectionBackendOutputGridTest.Tol);
        end

        function testResolutionUsesSourceMetadata(testCase)
            scene = ProjectionBackendOutputGridTest.makeSingleLayerScene(0.25, 0.5);

            grid = ProjectionBackendOutputGrid.plan(scene);

            testCase.verifyEqual(grid.ResolutionMetersPerPixel, 0.25, ...
                AbsTol=ProjectionBackendOutputGridTest.Tol);
            testCase.verifyGreaterThanOrEqual(grid.OutputSize(1), 2);
            testCase.verifyGreaterThanOrEqual(grid.OutputSize(2), 2);
        end

        function testGuardrailRejectsHugeOutput(testCase)
            scene = ProjectionBackendOutputGridTest.makeSingleLayerScene(0.5, 0.5);
            options = struct(ResolutionMetersPerPixel=0.01, MaxOutputPixels=10);

            testCase.verifyError( ...
                @() ProjectionBackendOutputGrid.plan(scene, options), ...
                "ProjectionBackendOutputGrid:outputTooLarge");
        end

        function testBackendProcessorReturnsPlannedGrid(testCase)
            scene = ProjectionBackendOutputGridTest.makeTwoLayerScene();
            state = ProjectionBackendOutputGridTest.makeViewerState(scene, -15);
            job = struct(Scene=scene, ViewerState=state, ...
                RenderOptions=struct(ResolutionMetersPerPixel=0.5));

            result = ProjectionBackendProcessor.run(job);

            testCase.verifyEqual(result.OutputGrid.Format, ...
                ProjectionBackendOutputGrid.Format);
            testCase.verifyEqual(result.OutputGrid.TwistDegrees, -15, ...
                AbsTol=ProjectionBackendOutputGridTest.Tol);
            testCase.verifyEqual(result.OutputGrid.LayerIndices, [1 2]);
        end
    end

    methods (Static, Access = private)
        function scene = makeSingleLayerScene(gsd, platformStepMeters)
            imageData = reshape(1:20, 4, 5);
            options = struct();
            options.RowStride = 1;
            options.ColumnStride = 1;
            options.GSD = gsd;
            options.PlatformStepMeters = platformStepMeters;
            scene = ProjectionViewerHarness.createSceneFromImage( ...
                imageData, "layer1.tif", options);
        end

        function scene = makeTwoLayerScene()
            imageData1 = reshape(1:20, 4, 5);
            imageData2 = reshape(1:30, 5, 6);
            options = struct();
            options.RowStride = 1;
            options.ColumnStride = 1;
            options.GSD = 0.5;
            options.PlatformStepMeters = 0.5;
            scene = ProjectionViewerHarness.createSceneFromImages( ...
                {imageData1, imageData2}, ["layer1.tif", "layer2.tif"], options);
        end

        function state = makeViewerState(scene, twistDegrees)
            state = struct();
            state.Format = ProjectionViewerState.Format;
            state.Version = ProjectionViewerState.Version;
            state.LayerCount = numel(scene.layers);
            state.SelectedLayerIndex = 2;
            state.Projection = struct(TipDegrees=0, TiltDegrees=0);
            state.View = struct(TwistDegrees=twistDegrees);
            state.Layers = [ ...
                ProjectionBackendOutputGridTest.makeLayerState(scene.layers(1), 1), ...
                ProjectionBackendOutputGridTest.makeLayerState(scene.layers(2), 2)];
        end

        function layerState = makeLayerState(layer, index)
            layerState = struct();
            layerState.Index = index;
            layerState.Name = layer.Name;
            layerState.ImagePath = layer.ImagePath;
            layerState.Alpha = layer.Alpha;
            layerState.Visible = layer.Visible;
            layerState.BlendMode = layer.BlendMode;
            layerState.ProjectionOffsetMeters = layer.ProjectionOffsetMeters.';
            layerState.ViewVectorAngularOffsetsDegrees = ...
                layer.ViewVectorAngularOffsetsDegrees.';
        end

        function bounds = combinedBounds(scene, grid, layerIndices)
            allX = zeros(0, 1);
            allY = zeros(0, 1);
            for layerIndex = layerIndices
                mesh = ProjectionMeshBuilder.buildLayerMesh( ...
                    scene.layers(layerIndex), ...
                    scene.layers(layerIndex).CurrentProjectionPlane, ...
                    scene.renderOrigin);
                coordinates = ProjectionBackendOutputGridTest.projectPoints( ...
                    mesh.WorldPoints, grid.Origin, grid.XAxis, grid.YAxis);
                allX = [allX; coordinates(1, :).']; %#ok<AGROW>
                allY = [allY; coordinates(2, :).']; %#ok<AGROW>
            end
            bounds = struct();
            bounds.X = [min(allX), max(allX)];
            bounds.Y = [min(allY), max(allY)];
        end

        function coordinates = projectPoints(worldPoints, origin, xAxis, yAxis)
            points = reshape(worldPoints, 3, []);
            relativePoints = points - origin;
            coordinates = [xAxis.' * relativePoints; yAxis.' * relativePoints];
        end

        function verifyBoundsContain(testCase, actualBounds, expectedBounds)
            testCase.verifyLessThanOrEqual(actualBounds.X(1), ...
                expectedBounds.X(1) + ProjectionBackendOutputGridTest.Tol);
            testCase.verifyGreaterThanOrEqual(actualBounds.X(2), ...
                expectedBounds.X(2) - ProjectionBackendOutputGridTest.Tol);
            testCase.verifyLessThanOrEqual(actualBounds.Y(1), ...
                expectedBounds.Y(1) + ProjectionBackendOutputGridTest.Tol);
            testCase.verifyGreaterThanOrEqual(actualBounds.Y(2), ...
                expectedBounds.Y(2) - ProjectionBackendOutputGridTest.Tol);
        end

        function rotatedVector = rotateVectorAboutAxis(vector, axis, angle)
            axis = axis(:) / norm(axis);
            K = [0 -axis(3) axis(2); axis(3) 0 -axis(1); -axis(2) axis(1) 0];
            R = cos(angle) * eye(3) + (1 - cos(angle)) * (axis * axis.') + ...
                sin(angle) * K;
            rotatedVector = R * vector;
        end
    end
end
