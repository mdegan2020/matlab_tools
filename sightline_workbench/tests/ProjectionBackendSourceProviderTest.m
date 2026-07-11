classdef ProjectionBackendSourceProviderTest < matlab.unittest.TestCase
    %ProjectionBackendSourceProviderTest Tests file-backed source regions.

    methods (TestClassSetup)
        function addSourceToPath(testCase)
            projectRoot = fileparts(fileparts(mfilename("fullpath")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(projectRoot, "src")));
        end
    end

    methods (Test)
        function testTiffProviderReadsOnlyRequiredBoundingRegion(testCase)
            [folder, imagePath, imageData] = ...
                ProjectionBackendSourceProviderTest.makeTiffFixture();
            testCase.addTeardown(@() ...
                ProjectionBackendSourceProviderTest.removeFolder(folder));
            scene = ProjectionBackendSourceProviderTest.makeScene( ...
                imageData, imagePath);
            scene.layers.BackendSource = struct(Kind="tiff", Path=imagePath);
            provider = ProjectionBackendSourceProvider.fromLayer(scene.layers);
            mapping = struct(RowCoordinates=[5.2 5.8], ...
                ColumnCoordinates=[10.1 10.9], ValidMask=[true true]);

            [regionImage, regionalMapping, region] = ...
                ProjectionBackendSourceProvider.readForMapping( ...
                provider, mapping);

            testCase.verifyEqual(region.RowRange, [5 6]);
            testCase.verifyEqual(region.ColumnRange, [10 11]);
            testCase.verifyEqual(region.PixelCount, 4);
            testCase.verifyEqual(regionImage, imageData(5:6, 10:11));
            testCase.verifyEqual(regionalMapping.RowCoordinates, [1.2 1.8], ...
                AbsTol=1e-12);
            testCase.verifyEqual(regionalMapping.ColumnCoordinates, [1.1 1.9], ...
                AbsTol=1e-12);
        end

        function testFileBackedTiledRenderMatchesInMemory(testCase)
            testCase.addTeardown( ...
                @ProjectionBackendSourceProviderTest.deleteActiveThreadPool);
            [folder, imagePath, imageData] = ...
                ProjectionBackendSourceProviderTest.makeTiffFixture();
            testCase.addTeardown(@() ...
                ProjectionBackendSourceProviderTest.removeFolder(folder));
            memoryScene = ProjectionBackendSourceProviderTest.makeScene( ...
                imageData, imagePath);
            fileScene = memoryScene;
            fileScene.layers.Image = [];
            fileScene.layers.BackendSource = struct( ...
                Kind="tiff", Path=imagePath);
            renderOptions = struct(OutputSize=[17 19], TileSize=[5 7]);

            memoryResult = ProjectionBackendProcessor.run(struct( ...
                Scene=memoryScene, RenderOptions=renderOptions));
            fileResult = ProjectionBackendProcessor.run(struct( ...
                Scene=fileScene, RenderOptions=renderOptions));

            testCase.verifyEqual(fileResult.Readback.Image, ...
                memoryResult.Readback.Image);
            testCase.verifyEqual(fileResult.Readback.ValidMask, ...
                memoryResult.Readback.ValidMask);
            testCase.verifyEqual(fileResult.RenderPlan.Sources.Kind, "tiff");
            testCase.verifyEqual(fileResult.RenderPlan.Sources.Path, imagePath);
            testCase.verifyFalse(isfield(fileResult.RenderPlan.Sources, "Image"));
            testCase.verifyError(@() ProjectionBackendProcessor.run(struct( ...
                Scene=fileScene, RenderOptions=renderOptions, ...
                Execution=struct(Mode="threads", MaximumInFlightTiles=2))), ...
                "ProjectionBackendTiledRenderer:fileBackedThreadsUnsupported");
        end

        function testSerializedFileBackedJobRunsWithoutImagePayload(testCase)
            [folder, imagePath, imageData] = ...
                ProjectionBackendSourceProviderTest.makeTiffFixture();
            testCase.addTeardown(@() ...
                ProjectionBackendSourceProviderTest.removeFolder(folder));
            scene = ProjectionBackendSourceProviderTest.makeScene( ...
                imageData, imagePath);
            scene.layers.Image = [];
            scene.layers.BackendSource = struct(Kind="tiff", Path=imagePath);
            jobPath = fullfile(folder, "file_backed_job.json");
            job = struct(Scene=scene, ...
                RenderOptions=struct(OutputSize=[9 11], TileSize=[4 5]));

            ProjectionBackendJob.write(jobPath, job);
            result = ProjectionBackendProcessor.run(jobPath);

            testCase.verifySize(result.Readback.Image, [9 11]);
            testCase.verifyEqual(result.RenderPlan.Sources.Kind, "tiff");
            testCase.verifyEmpty(result.Scene.layers.Image);
        end
    end

    methods (Static, Access = private)
        function [folder, imagePath, imageData] = makeTiffFixture()
            folder = string(tempname);
            mkdir(folder);
            imagePath = string(fullfile(folder, "source.tif"));
            imageData = uint16(reshape(1:600, 20, 30));
            imwrite(imageData, imagePath, "tif");
        end

        function scene = makeScene(imageData, imagePath)
            scene = ProjectionViewerHarness.createSceneFromImages( ...
                {imageData}, imagePath, struct(RowStride=4, ColumnStride=5));
        end

        function removeFolder(folder)
            if isfolder(folder)
                rmdir(folder, "s");
            end
        end

        function deleteActiveThreadPool()
            pool = gcp("nocreate");
            if ~isempty(pool) && contains(string(class(pool)), "ThreadPool")
                delete(pool);
            end
        end
    end
end
