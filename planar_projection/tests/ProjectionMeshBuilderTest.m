classdef ProjectionMeshBuilderTest < matlab.unittest.TestCase
    %ProjectionMeshBuilderTest Tests for pure sampled mesh construction.

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
        function testBuildLayerMeshReturnsFiniteSampledArrays(testCase)
            scene = ProjectionMeshBuilderTest.makeScene();
            layer = scene.layers;

            mesh = ProjectionMeshBuilder.buildLayerMesh( ...
                layer, layer.CurrentProjectionPlane, scene.renderOrigin);
            numRows = numel(layer.MeshSampling.RowIndices);
            numColumns = numel(layer.MeshSampling.ColumnIndices);

            testCase.verifySize(mesh.X, [numRows numColumns]);
            testCase.verifySize(mesh.Y, [numRows numColumns]);
            testCase.verifySize(mesh.Z, [numRows numColumns]);
            testCase.verifyEqual(mesh.RowIndices, layer.MeshSampling.RowIndices);
            testCase.verifyEqual(mesh.ColumnIndices, layer.MeshSampling.ColumnIndices);
            testCase.verifyEqual(mesh.Texture, layer.DisplayTexture);
            testCase.verifyEqual(mesh.Alpha, layer.Alpha, AbsTol=ProjectionMeshBuilderTest.Tol);
            testCase.verifyTrue(all(isfinite(mesh.X), "all"));
            testCase.verifyTrue(all(isfinite(mesh.Y), "all"));
            testCase.verifyTrue(all(isfinite(mesh.Z), "all"));
            testCase.verifySize(mesh.WorldPoints, [3 numRows numColumns]);
            testCase.verifySize(mesh.SampledVectors, [3 numRows numColumns]);
            testCase.verifyEqual(mesh.ViewVectorAngularOffsetsDegrees, [0; 0; 0], ...
                AbsTol=ProjectionMeshBuilderTest.Tol);
            testCase.verifyEqual(mesh.ViewVectorRotationMatrix, eye(3), ...
                AbsTol=ProjectionMeshBuilderTest.Tol);
        end

        function testBuildLayerMeshUsesSampleFunctionContract(testCase)
            layer = ProjectionMeshBuilderTest.makeStubLayer();
            plane = PlanarProjection.definePlaneFromBasis([10; 0; 0], [0; 1; 0], [0; 0; 1]);
            renderOrigin = [10; 0; 0];

            mesh = ProjectionMeshBuilder.buildLayerMesh(layer, plane, renderOrigin);

            testCase.verifyEqual(mesh.X, zeros(3, 2), AbsTol=ProjectionMeshBuilderTest.Tol);
            testCase.verifyEqual(mesh.Y, [-10 -10; 0 0; 20 20], ...
                AbsTol=ProjectionMeshBuilderTest.Tol);
            testCase.verifyEqual(mesh.Z, [2 5; 2 5; 2 5], ...
                AbsTol=ProjectionMeshBuilderTest.Tol);
            testCase.verifyEqual(mesh.Alpha, 0.25, AbsTol=ProjectionMeshBuilderTest.Tol);
        end

        function testRenderOriginShiftMatchesWorldPoints(testCase)
            scene = ProjectionMeshBuilderTest.makeScene();
            layer = scene.layers;
            renderOrigin = [3; -2; 7];

            mesh = ProjectionMeshBuilder.buildLayerMesh( ...
                layer, layer.CurrentProjectionPlane, renderOrigin);
            expectedX = reshape(mesh.WorldPoints(1, :, :), size(mesh.X)) - renderOrigin(1);
            expectedY = reshape(mesh.WorldPoints(2, :, :), size(mesh.Y)) - renderOrigin(2);
            expectedZ = reshape(mesh.WorldPoints(3, :, :), size(mesh.Z)) - renderOrigin(3);

            testCase.verifyEqual(mesh.X, expectedX, AbsTol=ProjectionMeshBuilderTest.Tol);
            testCase.verifyEqual(mesh.Y, expectedY, AbsTol=ProjectionMeshBuilderTest.Tol);
            testCase.verifyEqual(mesh.Z, expectedZ, AbsTol=ProjectionMeshBuilderTest.Tol);
        end

        function testTipTiltPlaneChangesMeshVertices(testCase)
            scene = ProjectionMeshBuilderTest.makeScene();
            layer = scene.layers;
            baseMesh = ProjectionMeshBuilder.buildLayerMesh( ...
                layer, layer.BaseProjectionPlane, scene.renderOrigin);
            tiltedPlane = ProjectionMeshBuilder.applyPlaneTipTilt( ...
                layer.BaseProjectionPlane, pi / 48, -pi / 60);

            tiltedMesh = ProjectionMeshBuilder.buildLayerMesh( ...
                layer, tiltedPlane, scene.renderOrigin);
            vertexDifference = max(abs(tiltedMesh.WorldPoints - baseMesh.WorldPoints), [], "all");

            testCase.verifyTrue(PlanarProjection.validatePlane(tiltedPlane));
            testCase.verifyGreaterThan(vertexDifference, 1e-3);
        end

        function testProjectionOffsetShiftsMeshWithoutMovingSamples(testCase)
            scene = ProjectionMeshBuilderTest.makeScene();
            layer = scene.layers;
            plane = layer.CurrentProjectionPlane;
            baseMesh = ProjectionMeshBuilder.buildLayerMesh( ...
                layer, plane, scene.renderOrigin);
            layer.ProjectionOffsetMeters = [2; -3];

            shiftedMesh = ProjectionMeshBuilder.buildLayerMesh( ...
                layer, plane, scene.renderOrigin);
            expectedWorldOffset = plane.basis * layer.ProjectionOffsetMeters;
            expectedWorldOffset = reshape(expectedWorldOffset, 3, 1, 1);

            testCase.verifyEqual(shiftedMesh.WorldPoints - baseMesh.WorldPoints, ...
                repmat(expectedWorldOffset, 1, size(baseMesh.WorldPoints, 2), ...
                size(baseMesh.WorldPoints, 3)), AbsTol=ProjectionMeshBuilderTest.Tol);
            testCase.verifyEqual(shiftedMesh.SampledOrigins, baseMesh.SampledOrigins, ...
                AbsTol=ProjectionMeshBuilderTest.Tol);
            testCase.verifyEqual(shiftedMesh.SampledVectors, baseMesh.SampledVectors, ...
                AbsTol=ProjectionMeshBuilderTest.Tol);
            testCase.verifyEqual(shiftedMesh.Ranges, baseMesh.Ranges, ...
                AbsTol=ProjectionMeshBuilderTest.Tol);
        end

        function testViewVectorAngularOffsetsRotateSamplesWithoutMovingOrigins(testCase)
            scene = ProjectionMeshBuilderTest.makeScene();
            layer = scene.layers;
            plane = layer.CurrentProjectionPlane;
            baseMesh = ProjectionMeshBuilder.buildLayerMesh( ...
                layer, plane, scene.renderOrigin);
            layer.ViewVectorAngularOffsetsDegrees = [0.25; -0.15; 0.1];

            correctedMesh = ProjectionMeshBuilder.buildLayerMesh( ...
                layer, plane, scene.renderOrigin);
            expectedVectors = reshape( ...
                correctedMesh.ViewVectorRotationMatrix * ...
                reshape(baseMesh.SampledVectors, 3, []), ...
                size(baseMesh.SampledVectors));
            vertexDifference = max(abs( ...
                correctedMesh.WorldPoints - baseMesh.WorldPoints), [], "all");

            testCase.verifyEqual(correctedMesh.ViewVectorAngularOffsetsDegrees, ...
                layer.ViewVectorAngularOffsetsDegrees, AbsTol=ProjectionMeshBuilderTest.Tol);
            testCase.verifyEqual(correctedMesh.SampledOrigins, baseMesh.SampledOrigins, ...
                AbsTol=ProjectionMeshBuilderTest.Tol);
            testCase.verifyEqual(correctedMesh.SampledVectors, expectedVectors, ...
                AbsTol=ProjectionMeshBuilderTest.Tol);
            testCase.verifyGreaterThan(vertexDifference, 1e-3);
        end

        function testBehindSourceIntersectionsError(testCase)
            scene = ProjectionMeshBuilderTest.makeScene();
            layer = scene.layers;
            behindPlane = PlanarProjection.definePlaneFromBasis([-10; 0; 0], [0; 1; 0], [0; 0; 1]);

            testCase.verifyError( ...
                @() ProjectionMeshBuilder.buildLayerMesh(layer, behindPlane, scene.renderOrigin), ...
                "ProjectionMeshBuilder:behindSource");
        end

        function testInvalidAlphaErrors(testCase)
            scene = ProjectionMeshBuilderTest.makeScene();
            layer = scene.layers;
            layer.Alpha = 1.25;

            testCase.verifyError( ...
                @() ProjectionMeshBuilder.buildLayerMesh( ...
                layer, layer.CurrentProjectionPlane, scene.renderOrigin), ...
                "ProjectionMeshBuilder:invalidAlpha");
        end

        function testInvalidViewVectorAngularOffsetsError(testCase)
            scene = ProjectionMeshBuilderTest.makeScene();
            layer = scene.layers;
            layer.ViewVectorAngularOffsetsDegrees = [0; NaN; 0];

            testCase.verifyError( ...
                @() ProjectionMeshBuilder.buildLayerMesh( ...
                layer, layer.CurrentProjectionPlane, scene.renderOrigin), ...
                "ProjectionMeshBuilder:invalidViewVectorCorrection");
        end
    end

    methods (Static, Access = private)
        function scene = makeScene()
            imageData = uint8(reshape(1:180, 6, 10, 3));
            options = struct();
            options.RowStride = 2;
            options.ColumnStride = 4;
            options.PlatformDirection = [0; 0; 1];
            scene = ProjectionViewerHarness.createSceneFromImage( ...
                imageData, "synthetic.tif", options);
        end

        function layer = makeStubLayer()
            sourceGeometry = struct();
            sourceGeometry.ImageSize = [4 5];
            sourceGeometry.CoordinateFrame = "stub-world";
            sourceGeometry.SampleFcn = @ProjectionMeshBuilderTest.sampleStubGeometry;

            meshSampling = struct();
            meshSampling.RowStride = 1;
            meshSampling.ColumnStride = 3;
            meshSampling.RowIndices = [1 2 4];
            meshSampling.ColumnIndices = [2 5];

            layer = struct();
            layer.DisplayTexture = zeros(4, 5, 3, "uint8");
            layer.SourceGeometry = sourceGeometry;
            layer.MeshSampling = meshSampling;
            layer.Alpha = 0.25;
            layer.BlendMode = "alpha";
            layer.Visible = true;
        end

        function [G, V] = sampleStubGeometry(rowIndices, columnIndices)
            rowIndices = double(rowIndices(:).');
            columnIndices = double(columnIndices(:).');
            numRows = numel(rowIndices);
            numColumns = numel(columnIndices);

            G = [zeros(1, numColumns); zeros(1, numColumns); columnIndices];
            rowOffsets = rowIndices - 2;
            rowVectors = [ones(1, numRows); rowOffsets; zeros(1, numRows)];
            V = repmat(reshape(rowVectors, 3, numRows, 1), 1, 1, numColumns);
        end
    end
end
