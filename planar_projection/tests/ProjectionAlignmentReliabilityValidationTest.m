classdef ProjectionAlignmentReliabilityValidationTest < matlab.unittest.TestCase
    %ProjectionAlignmentReliabilityValidationTest Pack 8 report contracts.

    properties
        TemporaryFolder string
    end

    methods (TestClassSetup)
        function addProjectPaths(testCase)
            projectRoot = fileparts(fileparts(mfilename("fullpath")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(projectRoot, "src")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(projectRoot, "scripts")));
        end
    end

    methods (TestMethodSetup)
        function createTemporaryFolder(testCase)
            fixture = testCase.applyFixture( ...
                matlab.unittest.fixtures.TemporaryFolderFixture);
            testCase.TemporaryFolder = string(fixture.Folder);
        end
    end

    methods (Test)
        function testQuickMatrixWritesDurableArtifacts(testCase)
            imagePath = fullfile(testCase.TemporaryFolder, "fixture.tif");
            imwrite(ProjectionAlignmentReliabilityValidationTest.rgbFixture(), ...
                imagePath);
            outputDirectory = fullfile(testCase.TemporaryFolder, "artifacts");
            options = struct(OutputDirectory=outputDirectory, ...
                SimulationOptions=struct(SensorImageSize=[64 64], ...
                DemGridSize=33, MeshStride=4, RenderChunkRows=16), ...
                RenderOptions=struct(OutputSize=[64 64]), ...
                Detectors="auto", RunRegressionTests=false, ...
                MaxFeatures=100);

            [summary, artifacts] = alignment_reliability_validation( ...
                imagePath, options);

            testCase.verifyEqual(summary.Format, ...
                "ProjectionAlignmentReliabilityValidation");
            testCase.verifyEqual(summary.WorkingImageMode, ...
                "fullSourceInverseWarp");
            testCase.verifyEqual(summary.BackendRadiometryContract, ...
                "fullSourceInverseWarp");
            testCase.verifyEqual(summary.SelectedDetector, "auto");
            testCase.verifyTrue(summary.Detectors.ExactRepeat);
            testCase.verifyNumElements(summary.Losses, 5);
            testCase.verifyGreaterThanOrEqual( ...
                numel(summary.ContractRegressions), 10);
            testCase.verifyTrue(all(string( ...
                {summary.ContractRegressions.Status}) == "notRun"));
            testCase.verifyTrue(isfile(artifacts.SummaryPath));
            testCase.verifyTrue(isfile(artifacts.MatPath));
            testCase.verifyTrue(isfile(artifacts.DetectorMatrixPath));
            testCase.verifyTrue(isfile(artifacts.LossMatrixPath));
            testCase.verifyTrue(isfile(artifacts.RegressionMatrixPath));

            jsonText = string(fileread(artifacts.SummaryPath));
            testCase.verifyTrue(contains(jsonText, ...
                '"BackendRadiometryContract": "fullSourceInverseWarp"'));
            testCase.verifyFalse(contains(jsonText, "DisplayTexture"));
        end
    end

    methods (Static, Access = private)
        function image = rgbFixture()
            [x, y] = meshgrid(1:96, 1:96);
            red = uint8(mod(7 * x + 11 * y + ...
                40 * sin(x / 4), 256));
            green = uint8(mod(5 * x + 3 * y, 256));
            blue = uint8(mod(13 * x + 2 * y + ...
                35 * cos(y / 5), 256));
            image = cat(3, red, green, blue);
        end
    end
end
