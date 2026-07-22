classdef Rpc00bGeometryTest < matlab.unittest.TestCase
    %RPC00BGEOMETRYTEST Shared height geometry with processed RPC cameras.

    methods (TestClassSetup)
        function addSourceFolder(testCase)
            root = fileparts(fileparts(mfilename("fullpath")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(root, "src")));
        end
    end

    methods (Test)
        function testWarpMatchesIndependentAffineRpcCalculation(testCase)
            [geometry, r, m, factor] = rpcGeometry;
            p = [30.75, 25.75; 24.5, 20.25; 38.25, 31.5];
            z = [900; 1000; 1125];
            expected = expectedWarp(r, m, p, z, factor);

            [actual, valid, inside] = geometry.warp(p, z);

            testCase.verifyTrue(all(valid));
            testCase.verifyTrue(all(inside));
            testCase.verifyEqual(actual, expected, AbsTol=2e-11);
        end

        function testHeightDerivativeIsInProcessedPixelsPerMetre(testCase)
            [geometry, r, m, factor] = rpcGeometry;
            p = [30.75, 25.75; 24.5, 20.25; 38.25, 31.5];
            z = [900; 1000; 1125];
            wp = expectedWarp(r, m, p, z + 0.5, factor);
            wm = expectedWarp(r, m, p, z - 0.5, factor);
            expected = wp - wm;

            [actual, kappa, valid] = geometry.heightDerivative( ...
                p, z, DeltaHeight=0.5);

            testCase.verifyTrue(all(valid));
            testCase.verifyEqual(actual, expected, AbsTol=2e-11);
            testCase.verifyEqual(kappa, vecnorm(expected, 2, 2), ...
                AbsTol=2e-11);
            testCase.verifyGreaterThan(min(kappa), 0);
        end

        function testWarpJacobianAndDifferentImageSizesRemainValid(testCase)
            [geometry, ~, ~, ~] = rpcGeometry;
            p = [30.75, 25.75; 24.5, 20.25];
            z = [1000; 1100];

            [a, valid] = geometry.warpJacobian( ...
                p, z, DeltaPixel=0.25);

            testCase.verifyTrue(all(valid));
            testCase.verifySize(a, [2, 2, 2]);
            testCase.verifyTrue(all(isfinite(a), "all"));
            testCase.verifyEqual(geometry.ReferenceCamera.ImageSize, [51, 61]);
            testCase.verifyEqual(geometry.MovingCamera.ImageSize, [41, 46]);
        end

        function testUnsupportedCameraFailsAtGeometryBoundary(testCase)
            testCase.verifyError( ...
                @() HeightSweepGeometry(struct, struct), ...
                "HeightSweepGeometry:UnsupportedCamera");
        end

        function testMixedWorldConventionsAreRejected(testCase)
            [geometry, ~, ~, ~] = rpcGeometry;
            pinhole = PinholeCamera(eye(3), eye(3), ...
                [0, 0, -1], [10, 10]);

            testCase.verifyError(@() HeightSweepGeometry( ...
                pinhole, geometry.MovingCamera), ...
                "HeightSweepGeometry:IncompatibleCamera");
        end
    end
end

function [geometry, reference, moving, factor] = rpcGeometry
factor = 2;
reference = affineMetadata([101, 121], 50, 60, 50, 60);
moving = affineMetadata([81, 91], 40, 45, 40, 45);
moving.LINE_NUM_COEF([2, 3, 4]) = [-0.05, 1.1, -0.02];
moving.SAMP_NUM_COEF([2, 3, 4]) = [0.9, 0.1, 0.1];
referenceCamera = Rpc00bCamera(reference, reference.IMAGE_SIZE, ...
    DownsampleFactor=factor);
movingCamera = Rpc00bCamera(moving, moving.IMAGE_SIZE, ...
    DownsampleFactor=factor);
geometry = HeightSweepGeometry(referenceCamera, movingCamera);
end

function m = affineMetadata(imageSize, lineOffset, sampleOffset, ...
        lineScale, sampleScale)
m = struct( ...
    "SUCCESS", 1, "ERR_BIAS", 1.25, "ERR_RAND", 0.75, ...
    "LINE_OFF", lineOffset, "SAMP_OFF", sampleOffset, ...
    "LAT_OFF", 40, "LONG_OFF", -105, "HEIGHT_OFF", 1000, ...
    "LINE_SCALE", lineScale, "SAMP_SCALE", sampleScale, ...
    "LAT_SCALE", 0.1, "LONG_SCALE", 0.2, "HEIGHT_SCALE", 500, ...
    "LINE_NUM_COEF", zeros(1, 20), ...
    "LINE_DEN_COEF", [1, zeros(1, 19)], ...
    "SAMP_NUM_COEF", zeros(1, 20), ...
    "SAMP_DEN_COEF", [1, zeros(1, 19)], ...
    "IMAGE_SIZE", imageSize);
m.LINE_NUM_COEF([2, 3, 4]) = [-0.1, 1, 0.03];
m.SAMP_NUM_COEF([2, 3, 4]) = [1, 0.2, 0.05];
end

function pixel = expectedWarp(reference, moving, processedPixel, z, factor)
fullPixel = factor .* (processedPixel - 0.5) + 0.5;
target = [(fullPixel(:, 1) - 1 - reference.SAMP_OFF) ...
    ./ reference.SAMP_SCALE, ...
    (fullPixel(:, 2) - 1 - reference.LINE_OFF) ...
    ./ reference.LINE_SCALE];
hn = (z - reference.HEIGHT_OFF) ./ reference.HEIGHT_SCALE;
referenceMatrix = [reference.SAMP_NUM_COEF(2:3); ...
    reference.LINE_NUM_COEF(2:3)];
referenceHeight = [reference.SAMP_NUM_COEF(4), ...
    reference.LINE_NUM_COEF(4)];
lonLat = (referenceMatrix \ (target - hn .* referenceHeight).').';
movingMatrix = [moving.SAMP_NUM_COEF(2:3); ...
    moving.LINE_NUM_COEF(2:3)];
movingHeight = [moving.SAMP_NUM_COEF(4), moving.LINE_NUM_COEF(4)];
normalized = lonLat * movingMatrix.' + hn .* movingHeight;
movingFull = [moving.SAMP_OFF + moving.SAMP_SCALE .* normalized(:, 1) + 1, ...
    moving.LINE_OFF + moving.LINE_SCALE .* normalized(:, 2) + 1];
pixel = (movingFull - 0.5) ./ factor + 0.5;
end
