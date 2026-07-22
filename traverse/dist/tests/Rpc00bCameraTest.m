classdef Rpc00bCameraTest < matlab.unittest.TestCase
    %RPC00BCAMERATEST Deterministic RPC00B projection/inversion controls.

    methods (TestClassSetup)
        function addSourceFolder(testCase)
            root = fileparts(fileparts(mfilename("fullpath")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(root, "src")));
        end
    end

    methods (Test)
        function testProjectOffsetUsesOneBasedPublicPixels(testCase)
            m = affineMetadata;
            camera = Rpc00bCamera(m, [101, 121]);

            [pixel, valid, d] = camera.worldToImage( ...
                [m.LONG_OFF, m.LAT_OFF, m.HEIGHT_OFF]);

            testCase.verifyTrue(valid);
            testCase.verifyEqual(pixel, ...
                [m.SAMP_OFF + 1, m.LINE_OFF + 1], AbsTol=1e-14);
            testCase.verifyEqual(d.RawSampleLine, ...
                [m.SAMP_OFF, m.LINE_OFF], AbsTol=1e-14);
            testCase.verifyEqual(camera.TreSourceKind, "structure");
        end

        function testRpc00bBasisOrderControlsEveryTerm(testCase)
            m = affineMetadata;
            m.LINE_NUM_COEF = 0.001 .* (1:20);
            m.SAMP_NUM_COEF = 0.001 .* (20:-1:1);
            camera = Rpc00bCamera(m, [101, 121]);
            n = [0.2, -0.3, 0.1];
            world = [m.LONG_OFF + m.LONG_SCALE .* n(1), ...
                m.LAT_OFF + m.LAT_SCALE .* n(2), ...
                m.HEIGHT_OFF + m.HEIGHT_SCALE .* n(3)];
            b = explicitRpc00bBasis(n(1), n(2), n(3));
            expected = [m.SAMP_OFF + m.SAMP_SCALE ...
                .* sum(m.SAMP_NUM_COEF .* b) + 1, ...
                m.LINE_OFF + m.LINE_SCALE ...
                .* sum(m.LINE_NUM_COEF .* b) + 1];

            [actual, valid] = camera.worldToImage(world);

            testCase.verifyTrue(valid);
            testCase.verifyEqual(actual, expected, AbsTol=2e-13);
        end

        function testAffineForwardProjectionMatchesHandCalculation(testCase)
            m = affineMetadata;
            camera = Rpc00bCamera(m, [101, 121]);
            n = [0.4, -0.3, 0.2];
            world = denormalizeWorld(m, n);
            sample = n(1) + 0.2 .* n(2) + 0.05 .* n(3);
            line = -0.1 .* n(1) + n(2) + 0.03 .* n(3);
            expected = [m.SAMP_OFF + m.SAMP_SCALE .* sample + 1, ...
                m.LINE_OFF + m.LINE_SCALE .* line + 1];

            [actual, valid] = camera.worldToImage(world);

            testCase.verifyTrue(valid);
            testCase.verifyEqual(actual, expected, AbsTol=1e-12);
        end

        function testWeaklyNonlinearInverseRoundTrip(testCase)
            m = nonlinearMetadata;
            camera = Rpc00bCamera(m, [101, 121]);
            normalized = [-0.7, -0.6, -0.4; 0, 0, 0.2; 0.65, 0.55, 0.5];
            expected = denormalizeWorld(m, normalized);
            [pixel, projected] = camera.worldToImage(expected);

            [actual, valid, d] = camera.imageToWorldAtHeight( ...
                pixel, expected(:, 3));

            testCase.verifyTrue(all(projected));
            testCase.verifyTrue(all(valid));
            testCase.verifyTrue(all(d.Converged));
            testCase.verifyLessThan(max(d.ResidualPixels), 1e-8);
            testCase.verifyEqual(actual, expected, AbsTol=2e-11);
        end

        function testInverseReportsNonconvergence(testCase)
            m = nonlinearMetadata;
            camera = Rpc00bCamera(m, [101, 121]);
            expected = denormalizeWorld(m, [0.8, 0.75, 0.5]);
            [pixel, projected] = camera.worldToImage(expected);

            [world, valid, d] = camera.imageToWorldAtHeight( ...
                pixel, expected(3), MaximumIterations=1, ...
                MaximumNormalizedStep=0.01);

            testCase.verifyTrue(projected);
            testCase.verifyFalse(valid);
            testCase.verifyTrue(d.Nonconverged);
            testCase.verifyTrue(all(isnan(world)));
        end

        function testInvalidDenominatorRemainsExplicit(testCase)
            m = affineMetadata;
            m.LINE_DEN_COEF = zeros(1, 20);
            camera = Rpc00bCamera(m, [101, 121]);

            [pixel, valid, d] = camera.worldToImage( ...
                [m.LONG_OFF, m.LAT_OFF, m.HEIGHT_OFF]);

            testCase.verifyFalse(valid);
            testCase.verifyFalse(d.DenominatorValid);
            testCase.verifyTrue(all(isnan(pixel)));
        end

        function testNormalizedExtrapolationIsRejected(testCase)
            m = affineMetadata;
            camera = Rpc00bCamera(m, [101, 121]);
            world = denormalizeWorld(m, [1.2, 0, 0]);

            [pixel, valid, d] = camera.worldToImage(world);

            testCase.verifyFalse(valid);
            testCase.verifyTrue(d.Extrapolated);
            testCase.verifyTrue(all(isnan(pixel)));
        end

        function testPayloadAndFileParsingAreEquivalent(testCase)
            m = affineMetadata;
            payload = encodeTre(m);
            tagged = "RPC00B01041" + string(payload);
            fixture = matlab.unittest.fixtures.TemporaryFolderFixture;
            testCase.applyFixture(fixture);
            path = fullfile(fixture.Folder, "synthetic_rpc.txt");
            writelines(tagged, path);

            payloadCamera = Rpc00bCamera(tagged, [101, 121]);
            fileCamera = Rpc00bCamera(string(path), [101, 121]);
            world = denormalizeWorld(m, [0.25, -0.4, 0.3]);
            expected = payloadCamera.worldToImage(world);
            actual = fileCamera.worldToImage(world);

            testCase.verifyEqual(strlength(string(payload)), 1041);
            testCase.verifyEqual(actual, expected, AbsTol=eps);
            testCase.verifyEqual(payloadCamera.TreSourceKind, "payload");
            testCase.verifyEqual(fileCamera.TreSourceKind, "file");
            testCase.verifyEqual(fileCamera.LineNumerator, m.LINE_NUM_COEF);
            testCase.verifyEqual(fileCamera.SampleDenominator, ...
                m.SAMP_DEN_COEF);
        end

        function testMissingFieldAndInvalidPayloadFailInformatively(testCase)
            missing = rmfield(affineMetadata, "LONG_SCALE");

            testCase.verifyError(@() Rpc00bCamera(missing, [101, 121]), ...
                "Rpc00bCamera:MissingField");
            testCase.verifyError(@() Rpc00bCamera("RPC00B01041bad", ...
                [101, 121]), "Rpc00bCamera:InvalidTreLength");
        end

        function testUnsuccessfulTreAndInvalidScaleAreRejected(testCase)
            unsuccessful = affineMetadata;
            unsuccessful.SUCCESS = 0;
            invalidScale = affineMetadata;
            invalidScale.HEIGHT_SCALE = 0;

            testCase.verifyError( ...
                @() Rpc00bCamera(unsuccessful, [101, 121]), ...
                "Rpc00bCamera:UnsuccessfulTre");
            testCase.verifyError( ...
                @() Rpc00bCamera(invalidScale, [101, 121]), ...
                "Rpc00bCamera:InvalidScale");
        end

        function testImageBoundsAndHeightShapeAreValidated(testCase)
            camera = Rpc00bCamera(affineMetadata, [101, 121]);

            inside = camera.isInsideImage([1, 1; 121, 101; 0.9, 1]);

            testCase.verifyEqual(inside, [true; true; false]);
            testCase.verifyError(@() camera.imageToWorldAtHeight( ...
                [1, 1; 2, 2], [1000; 1001; 1002]), ...
                "Rpc00bCamera:HeightSizeMismatch");
        end

        function testProcessedFullCoordinateMapsAreExact(testCase)
            camera = Rpc00bCamera(affineMetadata, [101, 121], ...
                DownsampleFactor=2);
            processed = [1, 1; 12.25, 9.75; 60.75, 50.75];
            expectedFull = 2 .* (processed - 0.5) + 0.5;

            actualFull = camera.processedToFull(processed);
            roundTrip = camera.fullToProcessed(actualFull);

            testCase.verifyEqual(camera.FullImageSize, [101, 121]);
            testCase.verifyEqual(camera.ImageSize, [51, 61]);
            testCase.verifyEqual(camera.DownsampleFactor, 2);
            testCase.verifyEqual(actualFull, expectedFull, AbsTol=eps);
            testCase.verifyEqual(roundTrip, processed, AbsTol=eps);
        end

        function testDownsampledProjectionRetainsFullTreCoordinates(testCase)
            m = affineMetadata;
            camera = Rpc00bCamera(m, [101, 121], DownsampleFactor=2);
            world = [m.LONG_OFF, m.LAT_OFF, m.HEIGHT_OFF];
            expectedFull = [m.SAMP_OFF + 1, m.LINE_OFF + 1];
            expectedProcessed = (expectedFull - 0.5) ./ 2 + 0.5;

            [pixel, projected, d] = camera.worldToImage(world);
            [actual, inverted] = camera.imageToWorldAtHeight( ...
                pixel, m.HEIGHT_OFF);

            testCase.verifyTrue(projected);
            testCase.verifyTrue(inverted);
            testCase.verifyEqual(pixel, expectedProcessed, AbsTol=1e-14);
            testCase.verifyEqual(d.FullResolutionPixelXY, ...
                expectedFull, AbsTol=1e-14);
            testCase.verifyEqual(actual, world, AbsTol=1e-12);
        end

        function testNondivisibleResizePaddingIsExplicitlyInvalid(testCase)
            camera = Rpc00bCamera(affineMetadata, [101, 121], ...
                DownsampleFactor=3);
            lastProcessed = [41, 34];
            lastFull = camera.processedToFull(lastProcessed);

            inside = camera.isInsideImage(lastProcessed);
            [world, valid, d] = camera.imageToWorldAtHeight( ...
                lastProcessed, 1000);

            testCase.verifyEqual(camera.ImageSize, [34, 41]);
            testCase.verifyEqual(lastFull, [122, 101], AbsTol=eps);
            testCase.verifyFalse(inside);
            testCase.verifyFalse(valid);
            testCase.verifyFalse(d.FullResolutionInputInsideImage);
            testCase.verifyTrue(all(isnan(world)));
        end
    end
end

function m = affineMetadata
m = struct( ...
    "SUCCESS", 1, "ERR_BIAS", 1.25, "ERR_RAND", 0.75, ...
    "LINE_OFF", 50, "SAMP_OFF", 60, ...
    "LAT_OFF", 40, "LONG_OFF", -105, "HEIGHT_OFF", 1000, ...
    "LINE_SCALE", 50, "SAMP_SCALE", 60, ...
    "LAT_SCALE", 0.1, "LONG_SCALE", 0.2, "HEIGHT_SCALE", 500, ...
    "LINE_NUM_COEF", zeros(1, 20), ...
    "LINE_DEN_COEF", [1, zeros(1, 19)], ...
    "SAMP_NUM_COEF", zeros(1, 20), ...
    "SAMP_DEN_COEF", [1, zeros(1, 19)]);
m.LINE_NUM_COEF([2, 3, 4]) = [-0.1, 1, 0.03];
m.SAMP_NUM_COEF([2, 3, 4]) = [1, 0.2, 0.05];
end

function m = nonlinearMetadata
m = affineMetadata;
m.LINE_NUM_COEF([5, 8, 11, 14]) = [0.08, -0.03, 0.02, 0.01];
m.SAMP_NUM_COEF([5, 9, 13, 17]) = [-0.06, 0.04, 0.015, -0.01];
m.LINE_DEN_COEF([2, 4]) = [0.02, -0.01];
m.SAMP_DEN_COEF([3, 4]) = [-0.015, 0.01];
end

function world = denormalizeWorld(m, normalized)
world = [m.LONG_OFF + m.LONG_SCALE .* normalized(:, 1), ...
    m.LAT_OFF + m.LAT_SCALE .* normalized(:, 2), ...
    m.HEIGHT_OFF + m.HEIGHT_SCALE .* normalized(:, 3)];
end

function b = explicitRpc00bBasis(lon, lat, hae)
b = [1, lon, lat, hae, lon .* lat, lon .* hae, lat .* hae, ...
    lon .^ 2, lat .^ 2, hae .^ 2, lat .* lon .* hae, lon .^ 3, ...
    lon .* lat .^ 2, lon .* hae .^ 2, lon .^ 2 .* lat, lat .^ 3, ...
    lat .* hae .^ 2, lon .^ 2 .* hae, lat .^ 2 .* hae, hae .^ 3];
end

function payload = encodeTre(m)
head = char(sprintf("%1d%07.2f%07.2f%06d%05d%+08.4f%+09.4f%+05d" ...
    + "%06d%05d%+08.4f%+09.4f%+05d", ...
    m.SUCCESS, m.ERR_BIAS, m.ERR_RAND, m.LINE_OFF, m.SAMP_OFF, ...
    m.LAT_OFF, m.LONG_OFF, m.HEIGHT_OFF, m.LINE_SCALE, ...
    m.SAMP_SCALE, m.LAT_SCALE, m.LONG_SCALE, m.HEIGHT_SCALE));
coef = [m.LINE_NUM_COEF, m.LINE_DEN_COEF, ...
    m.SAMP_NUM_COEF, m.SAMP_DEN_COEF];
payload = [head, char(join(compose("%+12.5E", coef), ""))];
end
