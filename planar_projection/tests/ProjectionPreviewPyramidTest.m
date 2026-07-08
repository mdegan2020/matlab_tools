classdef ProjectionPreviewPyramidTest < matlab.unittest.TestCase
    %ProjectionPreviewPyramidTest Tests for display-only preview tiling.

    methods (TestClassSetup)
        function addSourceToPath(testCase)
            projectRoot = fileparts(fileparts(mfilename("fullpath")));
            srcFolder = fullfile(projectRoot, "src");
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(srcFolder));
        end
    end

    methods (Test)
        function testBuildCreatesDecimatedSingleBandLevels(testCase)
            imageData = uint8(reshape(1:120, 10, 12));
            options = ProjectionPreviewPyramid.defaultOptions( ...
                struct(TileSize=4));

            pyramid = ProjectionPreviewPyramid.build(imageData, options);

            testCase.verifyEqual(pyramid.ImageSize, [10 12]);
            testCase.verifyEqual(pyramid.BandCount, 1);
            testCase.verifyEqual(pyramid.ImageClass, "uint8");
            testCase.verifySize(pyramid.Levels(1).Image, [10 12]);
            testCase.verifySize(pyramid.Levels(end).Image, [4 4]);
            testCase.verifyEqual(pyramid.Levels(end).Downsample, 4);
        end

        function testTileBoundsAndTextureUseLevelCoordinates(testCase)
            imageData = uint8(reshape(1:80, 8, 10));
            pyramid = ProjectionPreviewPyramid.build(imageData, ...
                struct(TileSize=4));

            tiles = ProjectionPreviewPyramid.tileBounds(pyramid, 2, 3);
            texture = ProjectionPreviewPyramid.tileTexture(pyramid, tiles(1));

            testCase.verifyEqual(tiles(1).LevelRowLimits, [1 3]);
            testCase.verifyEqual(tiles(1).LevelColumnLimits, [1 3]);
            testCase.verifyEqual(tiles(1).SourceRowLimits, [1 5]);
            testCase.verifyEqual(tiles(1).SourceColumnLimits, [1 5]);
            testCase.verifyEqual(texture, imageData([1 3 5], [1 3 5]));
        end

        function testTileMeshSamplingUsesFullResolutionLimits(testCase)
            imageData = uint8(reshape(1:80, 8, 10));
            pyramid = ProjectionPreviewPyramid.build(imageData, ...
                struct(TileSize=4));
            tiles = ProjectionPreviewPyramid.tileBounds(pyramid, 2, 3);

            meshSampling = ProjectionPreviewPyramid.tileMeshSampling( ...
                pyramid, tiles(1), 4);

            testCase.verifyEqual(meshSampling.RowIndices, [1 3 5]);
            testCase.verifyEqual(meshSampling.ColumnIndices, [1 3 5]);
            testCase.verifyEqual(meshSampling.RowStride, 2);
            testCase.verifyEqual(meshSampling.ColumnStride, 2);
        end

        function testSelectLevelUsesRequestedDownsample(testCase)
            imageData = uint8(zeros(64, 64));
            pyramid = ProjectionPreviewPyramid.build(imageData, ...
                struct(TileSize=8));

            fineLevel = ProjectionPreviewPyramid.selectLevel(pyramid, 1);
            middleLevel = ProjectionPreviewPyramid.selectLevel(pyramid, 3);
            coarsestLevel = ProjectionPreviewPyramid.selectLevel(pyramid, 64);

            testCase.verifyEqual(fineLevel, 1);
            testCase.verifyEqual(middleLevel, 2);
            testCase.verifyEqual(coarsestLevel, numel(pyramid.Levels));
        end
    end
end
