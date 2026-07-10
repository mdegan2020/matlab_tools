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
            testCase.verifyEmpty(pyramid.Levels(end).Image);
            storageBefore = ProjectionPreviewPyramid.storageDiagnostics(pyramid);
            [pyramid, wasMaterialized] = ...
                ProjectionPreviewPyramid.materializeLevel( ...
                pyramid, numel(pyramid.Levels));
            storageAfter = ProjectionPreviewPyramid.storageDiagnostics(pyramid);
            testCase.verifyTrue(wasMaterialized);
            testCase.verifySize(pyramid.Levels(end).Image, [3 3]);
            testCase.verifyEqual(pyramid.Levels(end).Downsample, 4);
            testCase.verifyEqual(storageBefore.MaterializedLevelCount, 1);
            testCase.verifyEqual(storageAfter.MaterializedLevelCount, 2);
        end

        function testTileBoundsAndTextureUseLevelCoordinates(testCase)
            imageData = uint8(reshape(1:80, 8, 10));
            pyramid = ProjectionPreviewPyramid.build(imageData, ...
                struct(TileSize=4));

            tiles = ProjectionPreviewPyramid.tileBounds(pyramid, 2, 3);
            [texture, pyramid, wasMaterialized] = ...
                ProjectionPreviewPyramid.tileTexture(pyramid, tiles(1));
            [repeatedTexture, ~, repeatedMaterialization] = ...
                ProjectionPreviewPyramid.tileTexture(pyramid, tiles(1));
            expectedLevel = imresize(imageData, ...
                pyramid.Levels(2).ImageSize, "box", Antialiasing=true);
            expectedTexture = expectedLevel(1:3, 1:3);

            testCase.verifyEqual(tiles(1).LevelRowLimits, [1 3]);
            testCase.verifyEqual(tiles(1).LevelColumnLimits, [1 3]);
            testCase.verifyEqual(tiles(1).SourceRowLimits, [1 7]);
            testCase.verifyEqual(tiles(1).SourceColumnLimits, [1 7]);
            testCase.verifyEqual(tiles(2).SourceColumnLimits(1), ...
                tiles(1).SourceColumnLimits(2));
            testCase.verifyTrue(wasMaterialized);
            testCase.verifyFalse(repeatedMaterialization);
            testCase.verifyEqual(texture, expectedTexture);
            testCase.verifyEqual(repeatedTexture, texture);
            testCase.verifyNotEqual(texture, imageData([1 3 5], [1 3 5]));
        end

        function testFileSourceReadsFineTileWithoutMaterializingLevel(testCase)
            imageData = uint8(reshape(1:80, 8, 10));
            imagePath = string(tempname) + ".tif";
            imwrite(imageData, imagePath);
            testCase.addTeardown(@() delete(imagePath));
            pyramid = ProjectionPreviewPyramid.build(imageData, struct( ...
                TileSize=4, SourcePath=imagePath, UseFileSource=true));
            fineTiles = ProjectionPreviewPyramid.tileBounds(pyramid, 1, 4);

            [texture, pyramid, wasMaterialized] = ...
                ProjectionPreviewPyramid.tileTexture(pyramid, fineTiles(1));
            storage = ProjectionPreviewPyramid.storageDiagnostics(pyramid);

            testCase.verifyEqual(pyramid.Source.Mode, "file");
            testCase.verifyFalse(wasMaterialized);
            testCase.verifyEqual(texture, imageData(1:4, 1:4));
            testCase.verifyEqual(storage.MaterializedLevelCount, 0);
            testCase.verifyEqual(storage.MaterializedBytes, 0);
        end

        function testBoxReductionSuppressesCheckerboardAliasing(testCase)
            checker = repmat(uint8([0 255; 255 0]), 32, 32);
            pyramid = ProjectionPreviewPyramid.build(checker, ...
                struct(TileSize=8));

            [pyramid, wasMaterialized] = ...
                ProjectionPreviewPyramid.materializeLevel(pyramid, 2);
            reduced = double(pyramid.Levels(2).Image);

            testCase.verifyTrue(wasMaterialized);
            testCase.verifyLessThanOrEqual( ...
                max(reduced, [], "all") - min(reduced, [], "all"), 1);
            testCase.verifyEqual(mean(reduced, "all"), 128, AbsTol=1);
        end

        function testTileMeshSamplingUsesFullResolutionLimits(testCase)
            imageData = uint8(reshape(1:80, 8, 10));
            pyramid = ProjectionPreviewPyramid.build(imageData, ...
                struct(TileSize=4));
            tiles = ProjectionPreviewPyramid.tileBounds(pyramid, 2, 3);

            meshSampling = ProjectionPreviewPyramid.tileMeshSampling( ...
                pyramid, tiles(1), 4);

            testCase.verifyEqual(meshSampling.RowIndices, [1 4 7]);
            testCase.verifyEqual(meshSampling.ColumnIndices, [1 4 7]);
            testCase.verifyEqual(meshSampling.RowStride, 3);
            testCase.verifyEqual(meshSampling.ColumnStride, 3);
        end

        function testTileKeyIsStableAndLevelSpecific(testCase)
            pyramid = ProjectionPreviewPyramid.build( ...
                uint8(zeros(16, 16)), struct(TileSize=4));
            levelOneTiles = ProjectionPreviewPyramid.tileBounds(pyramid, 1, 4);
            levelTwoTiles = ProjectionPreviewPyramid.tileBounds(pyramid, 2, 4);

            firstKey = ProjectionPreviewPyramid.tileKey(levelOneTiles(1));
            repeatedKey = ProjectionPreviewPyramid.tileKey(levelOneTiles(1));
            adjacentKey = ProjectionPreviewPyramid.tileKey(levelOneTiles(2));
            coarseKey = ProjectionPreviewPyramid.tileKey(levelTwoTiles(1));

            testCase.verifyEqual(firstKey, repeatedKey);
            testCase.verifyNotEqual(firstKey, adjacentKey);
            testCase.verifyNotEqual(firstKey, coarseKey);
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

        function testHysteresisSuppressesBoundaryOscillation(testCase)
            pyramid = ProjectionPreviewPyramid.build( ...
                uint8(zeros(64, 64)), struct(TileSize=8));

            [heldCoarse, coarseDiagnostics] = ...
                ProjectionPreviewPyramid.selectLevelWithHysteresis( ...
                pyramid, 6.1, 4, 0.75, 1.75);
            promoted = ProjectionPreviewPyramid.selectLevelWithHysteresis( ...
                pyramid, 5.9, 4, 0.75, 1.75);
            heldFine = ProjectionPreviewPyramid.selectLevelWithHysteresis( ...
                pyramid, 6.9, 3, 0.75, 1.75);
            demoted = ProjectionPreviewPyramid.selectLevelWithHysteresis( ...
                pyramid, 7.1, 3, 0.75, 1.75);

            testCase.verifyEqual(heldCoarse, 4);
            testCase.verifyTrue(coarseDiagnostics.WasSuppressed);
            testCase.verifyEqual(promoted, 3);
            testCase.verifyEqual(heldFine, 3);
            testCase.verifyEqual(demoted, 4);
        end

        function testHysteresisRejectsInvalidThresholds(testCase)
            pyramid = ProjectionPreviewPyramid.build( ...
                uint8(zeros(64, 64)), struct(TileSize=8));

            testCase.verifyError(@() ...
                ProjectionPreviewPyramid.selectLevelWithHysteresis( ...
                pyramid, 4, 3, 1, 1.75), ...
                "ProjectionPreviewPyramid:invalidHysteresis");
        end
    end
end
