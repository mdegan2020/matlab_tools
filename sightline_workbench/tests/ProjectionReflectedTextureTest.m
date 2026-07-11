classdef ProjectionReflectedTextureTest < matlab.unittest.TestCase
    %ProjectionReflectedTextureTest Tests continuous logical mirror addressing.

    properties (TestParameter)
        textureSize = struct(odd=[5 7], even=[4 6])
    end

    methods (TestClassSetup)
        function addSourceToPath(testCase)
            projectRoot = fileparts(fileparts(mfilename("fullpath")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(projectRoot, "src")));
        end
    end

    methods (Test)
        function testHorizontalVerticalAndCornerBoundariesAreContinuous(testCase)
            image = reshape(1:24, 4, 6);
            epsilon = 1e-7;
            rows = [2 2 4-epsilon 4+epsilon 4-epsilon 4+epsilon];
            columns = [6-epsilon 6+epsilon 3 3 6-epsilon 6+epsilon];

            values = ProjectionReflectedTexture.sample( ...
                image, rows, columns, "linear");

            testCase.verifyEqual(values(1), values(2), AbsTol=1e-5);
            testCase.verifyEqual(values(3), values(4), AbsTol=1e-5);
            testCase.verifyEqual(values(5), values(6), AbsTol=1e-5);
        end

        function testContinuousSamplingMatchesMaterializedOracle( ...
                testCase, textureSize)
            image = reshape(1:prod(textureSize), textureSize);
            rows = reshape(linspace(-6.25, 2 * textureSize(1) + 5.5, 63), 7, 9);
            columns = reshape(linspace(-8.5, 2 * textureSize(2) + 7.25, 63), 7, 9);

            actual = ProjectionReflectedTexture.sample( ...
                image, rows, columns, "linear");
            expected = ProjectionReflectedTextureTest.materializedOracle( ...
                image, rows, columns);

            testCase.verifyEqual(actual, expected, AbsTol=1e-10);
        end

        function testArbitraryBandsShareOneReflectedMapping(testCase)
            first = reshape(1:30, 5, 6);
            image = cat(3, first, 2 * first + 3, 5 * first - 7);
            rows = [0.25 3.5 7.75];
            columns = [8.25 -1.5 5.25];

            values = ProjectionReflectedTexture.sample(image, rows, columns);

            testCase.verifySize(values, [1 3 3]);
            testCase.verifyEqual(values(:, :, 2), 2 * values(:, :, 1) + 3, ...
                AbsTol=1e-10);
            testCase.verifyEqual(values(:, :, 3), 5 * values(:, :, 1) - 7, ...
                AbsTol=1e-10);
        end

        function testNearestSamplingUsesReflectedCoordinates(testCase)
            image = reshape(1:20, 4, 5);

            values = ProjectionReflectedTexture.sample( ...
                image, [1 4 5 0], [1 5 6 0], "nearest");

            testCase.verifyEqual(values, image(sub2ind(size(image), ...
                [1 4 3 2], [1 5 4 2])));
        end

        function testInvalidCoordinateShapeErrors(testCase)
            image = ones(4, 5);

            testCase.verifyError( ...
                @() ProjectionReflectedTexture.sample(image, ones(2), ones(3)), ...
                "ProjectionReflectedTexture:invalidCoordinates");
        end
    end

    methods (Static, Access = private)
        function values = materializedOracle(image, rows, columns)
            rowCoordinates = (floor(min(rows, [], "all")) - 1): ...
                (ceil(max(rows, [], "all")) + 1);
            columnCoordinates = (floor(min(columns, [], "all")) - 1): ...
                (ceil(max(columns, [], "all")) + 1);
            rowIndices = arrayfun(@(value) ...
                ProjectionReflectedTextureTest.reflectIndex( ...
                value, size(image, 1)), rowCoordinates);
            columnIndices = arrayfun(@(value) ...
                ProjectionReflectedTextureTest.reflectIndex( ...
                value, size(image, 2)), columnCoordinates);
            materialized = double(image(rowIndices, columnIndices));
            values = interp2(columnCoordinates, rowCoordinates, ...
                materialized, columns, rows, "linear");
        end

        function index = reflectIndex(index, lengthValue)
            while index < 1 || index > lengthValue
                if index < 1
                    index = 2 - index;
                end
                if index > lengthValue
                    index = 2 * lengthValue - index;
                end
            end
        end
    end
end
