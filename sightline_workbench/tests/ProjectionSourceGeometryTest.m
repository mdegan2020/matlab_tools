classdef ProjectionSourceGeometryTest < matlab.unittest.TestCase
    %ProjectionSourceGeometryTest Tests for source geometry adapters.

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
        function testFromGridInterpolatesOriginsAndViewVectors(testCase)
            [imageSize, rowPosts, columnPosts, origins, viewVectors] = ...
                ProjectionSourceGeometryTest.makeGridInputs();

            sourceGeometry = ProjectionSourceGeometry.fromGrid( ...
                imageSize, rowPosts, columnPosts, origins, viewVectors);
            rowIndices = [1 3 9];
            columnIndices = [1 4 13];

            [G, V] = sourceGeometry.SampleFcn(rowIndices, columnIndices);
            expectedOrigins = interp1(columnPosts, origins.', columnIndices, "linear").';
            expectedVectors = ProjectionSourceGeometryTest.expectedGridVectors( ...
                rowPosts, columnPosts, viewVectors, rowIndices, columnIndices);

            testCase.verifyEqual(sourceGeometry.ImageSize, imageSize);
            testCase.verifyEqual(sourceGeometry.RowPostIndices, rowPosts);
            testCase.verifyEqual(sourceGeometry.ColumnPostIndices, columnPosts);
            testCase.verifySize(G, [3 numel(columnIndices)]);
            testCase.verifySize(V, [3 numel(rowIndices) numel(columnIndices)]);
            testCase.verifyEqual(G, expectedOrigins, ...
                AbsTol=ProjectionSourceGeometryTest.Tol);
            testCase.verifyEqual(V, expectedVectors, ...
                AbsTol=ProjectionSourceGeometryTest.Tol);
        end

        function testSampleRayFcnInterpolatesFractionalObservations(testCase)
            [imageSize, rowPosts, columnPosts, origins, viewVectors] = ...
                ProjectionSourceGeometryTest.makeGridInputs();
            sourceGeometry = ProjectionSourceGeometry.fromGrid( ...
                imageSize, rowPosts, columnPosts, origins, viewVectors);
            rowPositions = [1.5 4 8.25];
            columnPositions = [2 7.5 12];

            [G, V] = sourceGeometry.SampleRayFcn(rowPositions, columnPositions);
            expectedOrigins = interp1(columnPosts, origins.', ...
                columnPositions, "linear").';
            expectedVectors = ProjectionSourceGeometryTest.expectedObservationVectors( ...
                rowPosts, columnPosts, viewVectors, rowPositions, columnPositions);

            testCase.verifySize(G, [3 numel(rowPositions)]);
            testCase.verifySize(V, [3 numel(rowPositions)]);
            testCase.verifyEqual(G, expectedOrigins, ...
                AbsTol=ProjectionSourceGeometryTest.Tol);
            testCase.verifyEqual(V, expectedVectors, ...
                AbsTol=ProjectionSourceGeometryTest.Tol);
        end

        function testFromGridEstimatesPerPixelIfovFromPostSpacing(testCase)
            imageSize = [9 13];
            rowPosts = [1 5 9];
            columnPosts = [1 13];
            thetaPerPixel = 1e-3;
            origins = [zeros(1, numel(columnPosts)); ...
                columnPosts; zeros(1, numel(columnPosts))];
            viewVectors = ProjectionSourceGeometryTest.rowAngleGridVectors( ...
                rowPosts, columnPosts, thetaPerPixel);

            sourceGeometry = ProjectionSourceGeometry.fromGrid( ...
                imageSize, rowPosts, columnPosts, origins, viewVectors);

            testCase.verifyEqual(sourceGeometry.IFOVRadians, thetaPerPixel, ...
                AbsTol=ProjectionSourceGeometryTest.Tol);
            testCase.verifyEqual(sourceGeometry.IFOVDegrees, rad2deg(thetaPerPixel), ...
                AbsTol=ProjectionSourceGeometryTest.Tol);
        end

        function testFromGridAcceptsExplicitIfovAndOptionalScalars(testCase)
            [imageSize, rowPosts, columnPosts, origins, viewVectors] = ...
                ProjectionSourceGeometryTest.makeGridInputs();
            options = struct();
            options.IFOVDegrees = 0.0125;
            options.GSD = 0.3;
            options.PlatformStepMeters = 0.7;
            options.NominalRange = 12000;

            sourceGeometry = ProjectionSourceGeometry.fromGrid( ...
                imageSize, rowPosts, columnPosts, origins, viewVectors, options);

            testCase.verifyEqual(sourceGeometry.IFOVDegrees, options.IFOVDegrees, ...
                AbsTol=ProjectionSourceGeometryTest.Tol);
            testCase.verifyEqual(sourceGeometry.GSD, options.GSD, ...
                AbsTol=ProjectionSourceGeometryTest.Tol);
            testCase.verifyEqual(sourceGeometry.PlatformStepMeters, ...
                options.PlatformStepMeters, AbsTol=ProjectionSourceGeometryTest.Tol);
            testCase.verifyEqual(sourceGeometry.NominalRange, ...
                options.NominalRange, AbsTol=ProjectionSourceGeometryTest.Tol);
        end

        function testGridSourceGeometryBuildsProjectionMesh(testCase)
            [imageSize, rowPosts, columnPosts, origins, viewVectors] = ...
                ProjectionSourceGeometryTest.makeGridInputs();
            sourceGeometry = ProjectionSourceGeometry.fromGrid( ...
                imageSize, rowPosts, columnPosts, origins, viewVectors);
            layer = ProjectionSourceGeometryTest.makeLayer(sourceGeometry);
            plane = PlanarProjection.definePlaneFromBasis( ...
                [100; 0; 0], [0; 1; 0], [0; 0; 1]);

            mesh = ProjectionMeshBuilder.buildLayerMesh(layer, plane, plane.P0);

            testCase.verifyTrue(all(isfinite(mesh.X), "all"));
            testCase.verifyTrue(all(isfinite(mesh.Y), "all"));
            testCase.verifyTrue(all(isfinite(mesh.Z), "all"));
            testCase.verifySize(mesh.SampledOrigins, [3 3]);
            testCase.verifySize(mesh.SampledVectors, [3 3 3]);
            testCase.verifyEqual(squeeze(sqrt(sum(mesh.SampledVectors.^2, 1))), ...
                ones(3, 3), AbsTol=ProjectionSourceGeometryTest.Tol);
        end

        function testFromGridRequiresPostCoverage(testCase)
            [imageSize, rowPosts, columnPosts, origins, viewVectors] = ...
                ProjectionSourceGeometryTest.makeGridInputs();
            rowPostsWithoutImageEnd = rowPosts(1:end-1);
            viewVectorsWithoutImageEnd = viewVectors(:, 1:end-1, :);

            testCase.verifyError( ...
                @() ProjectionSourceGeometry.fromGrid( ...
                imageSize, rowPostsWithoutImageEnd, columnPosts, origins, ...
                viewVectorsWithoutImageEnd), ...
                "ProjectionSourceGeometry:invalidPostIndices");
        end

        function testSampleFcnRejectsOutOfBoundsImageIndices(testCase)
            [imageSize, rowPosts, columnPosts, origins, viewVectors] = ...
                ProjectionSourceGeometryTest.makeGridInputs();
            sourceGeometry = ProjectionSourceGeometry.fromGrid( ...
                imageSize, rowPosts, columnPosts, origins, viewVectors);

            testCase.verifyError( ...
                @() sourceGeometry.SampleFcn([1 imageSize(1) + 1], 1), ...
                "ProjectionSourceGeometry:invalidSampleIndices");
        end
    end

    methods (Static, Access = private)
        function [imageSize, rowPosts, columnPosts, origins, viewVectors] = makeGridInputs()
            imageSize = [9 13];
            rowPosts = [1 4 9];
            columnPosts = [1 6 13];
            origins = [zeros(1, numel(columnPosts)); ...
                0.25 * columnPosts; 0.1 * columnPosts];
            viewVectors = zeros(3, numel(rowPosts), numel(columnPosts));
            centerRow = (imageSize(1) + 1) / 2;
            centerColumn = (imageSize(2) + 1) / 2;
            for rowIndex = 1:numel(rowPosts)
                for columnIndex = 1:numel(columnPosts)
                    viewVectors(:, rowIndex, columnIndex) = [1; ...
                        0.01 * (rowPosts(rowIndex) - centerRow); ...
                        0.005 * (columnPosts(columnIndex) - centerColumn)];
                end
            end
            viewVectors = ProjectionSourceGeometryTest.normalizeVectors(viewVectors);
        end

        function viewVectors = rowAngleGridVectors(rowPosts, columnPosts, thetaPerPixel)
            viewVectors = zeros(3, numel(rowPosts), numel(columnPosts));
            for rowIndex = 1:numel(rowPosts)
                theta = thetaPerPixel * (rowPosts(rowIndex) - 1);
                for columnIndex = 1:numel(columnPosts)
                    viewVectors(:, rowIndex, columnIndex) = [cos(theta); sin(theta); 0];
                end
            end
        end

        function expectedVectors = expectedGridVectors( ...
                rowPosts, columnPosts, viewVectors, rowIndices, columnIndices)
            numRows = numel(rowIndices);
            numColumns = numel(columnIndices);
            expectedVectors = zeros(3, numRows, numColumns);
            [rowGrid, columnGrid] = ndgrid(rowIndices, columnIndices);
            for componentIndex = 1:3
                componentGrid = squeeze(viewVectors(componentIndex, :, :));
                values = interp2(columnPosts, rowPosts, componentGrid, ...
                    columnGrid, rowGrid, "linear");
                expectedVectors(componentIndex, :, :) = reshape( ...
                    values, 1, numRows, numColumns);
            end
            expectedVectors = ProjectionSourceGeometryTest.normalizeVectors(expectedVectors);
        end

        function expectedVectors = expectedObservationVectors( ...
                rowPosts, columnPosts, viewVectors, rowPositions, columnPositions)
            expectedVectors = zeros(3, numel(rowPositions));
            for componentIndex = 1:3
                componentGrid = squeeze(viewVectors(componentIndex, :, :));
                expectedVectors(componentIndex, :) = interp2( ...
                    columnPosts, rowPosts, componentGrid, ...
                    columnPositions, rowPositions, "linear");
            end
            expectedVectors = ProjectionSourceGeometryTest.normalizeVectors(expectedVectors);
        end

        function layer = makeLayer(sourceGeometry)
            layer = struct();
            layer.DisplayTexture = zeros(9, 13, 3, "uint8");
            layer.SourceGeometry = sourceGeometry;
            layer.MeshSampling = struct();
            layer.MeshSampling.RowStride = 4;
            layer.MeshSampling.ColumnStride = 6;
            layer.MeshSampling.RowIndices = [1 5 9];
            layer.MeshSampling.ColumnIndices = [1 7 13];
            layer.Alpha = 1;
            layer.BlendMode = "alpha";
            layer.Visible = true;
        end

        function vectors = normalizeVectors(vectors)
            vectors = vectors ./ sqrt(sum(vectors.^2, 1));
        end
    end
end
