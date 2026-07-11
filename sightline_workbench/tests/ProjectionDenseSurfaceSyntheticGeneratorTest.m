classdef ProjectionDenseSurfaceSyntheticGeneratorTest < matlab.unittest.TestCase
    %ProjectionDenseSurfaceSyntheticGeneratorTest Tests truth image generation.

    properties (TestParameter)
        imageFormat = struct(png="png", tiff="tiff")
    end

    methods (TestClassSetup)
        function addProjectPaths(testCase)
            projectRoot = fileparts(fileparts(mfilename("fullpath")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(projectRoot, "src")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(projectRoot, "tests")));
        end
    end

    methods (Test)
        function testGenerationRetainsCompleteDeterministicImages(testCase)
            [config, plan, sourceImage] = ...
                ProjectionDenseSurfaceSyntheticTestSupport.generatorFixture();
            options = struct(WriteFiles=false, RowChunkSize=11, ...
                ColumnChunkSize=13);

            first = ProjectionDenseSurfaceSyntheticGenerator.generate( ...
                config, plan, sourceImage, options);
            second = ProjectionDenseSurfaceSyntheticGenerator.generate( ...
                config, plan, sourceImage, options);

            testCase.verifyEqual(numel(first.Images), config.image.view_count);
            testCase.verifyEqual(size(first.Images{1}), ...
                [config.image.rows config.image.columns]);
            testCase.verifyClass(first.Images{1}, class(sourceImage));
            testCase.verifyEqual(first.Images, second.Images);
            testCase.verifyEqual(first.Summary.ConfigurationFingerprint, ...
                second.Summary.ConfigurationFingerprint);
            testCase.verifyGreaterThan(min([first.Summary.Views.ValidFraction]), 0.99);
        end

        function testRadiometryComesFromFullReflectedSource(testCase)
            [config, plan, sourceImage] = ...
                ProjectionDenseSurfaceSyntheticTestSupport.generatorFixture();
            result = ProjectionDenseSurfaceSyntheticGenerator.generate( ...
                config, plan, sourceImage, struct(WriteFiles=false, ...
                RowChunkSize=9, ColumnChunkSize=17));
            viewIndex = 2;
            row = 17;
            column = 25;

            point = ProjectionDenseSurfaceSyntheticTruth.intersectObservations( ...
                result.Truth, viewIndex, row, column);
            textureRow = 0.5 * (size(sourceImage, 1) + 1) + ...
                (point(2) - plan.TargetPoint(2)) / ...
                plan.TextureSampleSpacingMeters(1);
            textureColumn = 0.5 * (size(sourceImage, 2) + 1) + ...
                (point(1) - plan.TargetPoint(1)) / ...
                plan.TextureSampleSpacingMeters(2);
            sourceBand = config.image.source_band_sequence(viewIndex);
            expected = uint8(round(ProjectionReflectedTexture.sample( ...
                sourceImage(:, :, sourceBand), textureRow, textureColumn)));

            testCase.verifyEqual(result.Images{viewIndex}(row, column), expected);
            testCase.verifyEqual([result.Summary.Views.SourceBand], ...
                config.image.source_band_sequence);
        end

        function testChunkSizesDoNotChangeTruthRender(testCase)
            [config, plan, sourceImage] = ...
                ProjectionDenseSurfaceSyntheticTestSupport.generatorFixture();

            smallChunks = ProjectionDenseSurfaceSyntheticGenerator.generate( ...
                config, plan, sourceImage, struct(WriteFiles=false, ...
                RowChunkSize=7, ColumnChunkSize=8));
            largeChunks = ProjectionDenseSurfaceSyntheticGenerator.generate( ...
                config, plan, sourceImage, struct(WriteFiles=false, ...
                RowChunkSize=64, ColumnChunkSize=64));

            testCase.verifyEqual(smallChunks.Images, largeChunks.Images);
            testCase.verifyEqual([smallChunks.Summary.Views.ValidPixelCount], ...
                [largeChunks.Summary.Views.ValidPixelCount]);
        end

        function testWritesFinalImagesAndCompactArtifacts(testCase, imageFormat)
            outputDirectory = ...
                ProjectionDenseSurfaceSyntheticGeneratorTest.temporaryDirectory( ...
                testCase);
            [config, plan, sourceImage] = ...
                ProjectionDenseSurfaceSyntheticTestSupport.generatorFixture();
            options = struct(WriteFiles=true, OutputDirectory=outputDirectory, ...
                ImageFormat=imageFormat, RowChunkSize=12, ColumnChunkSize=15);

            result = ProjectionDenseSurfaceSyntheticGenerator.generate( ...
                config, plan, sourceImage, options);
            loadedImage = imread(result.Artifacts.ImagePaths(1));
            payload = load(result.Artifacts.TruthSceneMatPath);
            summary = jsondecode(fileread(result.Artifacts.RunSummaryJsonPath));

            testCase.verifyTrue(all(isfile(result.Artifacts.ImagePaths)));
            testCase.verifyEqual(loadedImage, result.Images{1});
            testCase.verifyTrue(isfield(payload, "truth"));
            testCase.verifyTrue(isfield(payload, "sceneData"));
            testCase.verifyFalse(isfield(payload.sceneData, "Terrain"));
            testCase.verifyFalse(isfield(payload, "Images"));
            testCase.verifyEqual(string(summary.Status), "complete");
            testCase.verifyEqual(string(summary.ConfigurationFingerprint), ...
                result.Summary.ConfigurationFingerprint);
        end

        function testInfeasiblePlanBlocksBeforeImageValidation(testCase)
            [config, ~, ~] = ...
                ProjectionDenseSurfaceSyntheticTestSupport.generatorFixture();
            config.gimbal.pitch_field_of_regard_degrees = [-1 1];
            config.gimbal.maximum_initial_forward_pitch_degrees = 1;
            infeasiblePlan = ProjectionDenseSurfaceSyntheticPlanner.plan( ...
                config, [32 36 3]);

            testCase.verifyError( ...
                @() ProjectionDenseSurfaceSyntheticGenerator.generate( ...
                config, infeasiblePlan, [], struct(WriteFiles=false)), ...
                "ProjectionDenseSurfaceSyntheticGenerator:infeasiblePlan");
        end

        function testMissingConfiguredBandErrors(testCase)
            [config, plan, sourceImage] = ...
                ProjectionDenseSurfaceSyntheticTestSupport.generatorFixture();
            sourceImage = sourceImage(:, :, 1:2);

            testCase.verifyError( ...
                @() ProjectionDenseSurfaceSyntheticGenerator.generate( ...
                config, plan, sourceImage, struct(WriteFiles=false)), ...
                "ProjectionDenseSurfaceSyntheticGenerator:missingSourceBand");
        end
    end

    methods (Static, Access = private)
        function directory = temporaryDirectory(testCase)
            directory = string(tempname);
            mkdir(directory);
            testCase.addTeardown(@() rmdir(directory, "s"));
        end
    end
end
