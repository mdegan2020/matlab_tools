classdef RpcImageCoordinateCameraTest < matlab.unittest.TestCase
    %RPCIMAGECOORDINATECAMERATEST Native correction and ROI contracts.

    methods (TestClassSetup)
        function addSource(testCase)
            root = fileparts(fileparts(mfilename("fullpath")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(root, "src")));
        end
    end

    methods (Test)
        function testCorrectionForwardInverseRoundTrip(testCase)
            base = makeCamera([240, 320]);
            camera = RpcImageCorrectionCamera(base, [3.25, -1.75, 0.004]);
            p = [40, 50; 160, 120; 270, 190];
            z = [970; 1000; 1030];

            [world, valid] = camera.imageToWorldAtHeight(p, z);
            [roundTrip, projected] = camera.worldToImage(world);

            testCase.verifyTrue(all(valid & projected));
            testCase.verifyEqual(roundTrip, p, AbsTol=2e-8);
            testCase.verifyEqual(camera.invert(camera.apply(p)), p, ...
                AbsTol=2e-12);
        end

        function testIdentityCorrectionEqualsBase(testCase)
            base = makeCamera([120, 180]);
            camera = RpcImageCorrectionCamera(base, [0, 0, 0]);
            world = [-105.004, 39.997, 980; -104.997, 40.003, 1020];

            [actual, av] = camera.worldToImage(world);
            [expected, ev] = base.worldToImage(world);

            testCase.verifyEqual(actual, expected);
            testCase.verifyEqual(av, ev);
        end

        function testNativeRoiMapsSameFootprintAtEveryFactor(testCase)
            base = makeCamera([240, 320]);
            roi = [41, 200, 61, 260];
            factors = [1, 2, 4, 8];
            firstNative = nan(numel(factors), 2);
            lastNative = nan(numel(factors), 2);
            for k = 1:numel(factors)
                camera = RpcImageWindowCamera(base, roi, ...
                    DownsampleFactor=factors(k));
                firstNative(k, :) = camera.workingToNative([1, 1]);
                lastNative(k, :) = camera.workingToNative( ...
                    [camera.ImageSize(2), camera.ImageSize(1)]);
                testCase.verifyEqual(camera.NativeROI, roi);
                testCase.verifyEqual(camera.ImageSize, ...
                    ceil([160, 200] ./ factors(k)));
                p = [1, 1; camera.ImageSize(2), camera.ImageSize(1)];
                testCase.verifyEqual( ...
                    camera.nativeToWorking(camera.workingToNative(p)), p, ...
                    AbsTol=2e-14);
            end

            testCase.verifyEqual(firstNative, ...
                [61,41; 61.5,41.5; 62.5,42.5; 64.5,44.5]);
            testCase.verifyLessThanOrEqual(lastNative(:, 1), roi(4));
            testCase.verifyLessThanOrEqual(lastNative(:, 2), roi(2));
        end

        function testWindowPreservesNativeWorldMapping(testCase)
            base = makeCamera([240, 320]);
            corrected = RpcImageCorrectionCamera(base, [2, -3, 0.002]);
            camera = RpcImageWindowCamera(corrected, [31, 210, 51, 280], ...
                DownsampleFactor=4);
            p = [5, 6; 30, 20; 50, 40];
            z = [980; 1000; 1020];

            [world, valid] = camera.imageToWorldAtHeight(p, z);
            [roundTrip, projected] = camera.worldToImage(world);

            testCase.verifyTrue(all(valid & projected));
            testCase.verifyEqual(roundTrip, p, AbsTol=2e-8);
        end

        function testInvalidNativeRoiFails(testCase)
            base = makeCamera([100, 120]);
            call = @() RpcImageWindowCamera(base, [1, 101, 1, 20]);
            testCase.verifyError(call, ...
                "RpcImageWindowCamera:InvalidNativeROI");
        end
    end
end

function camera = makeCamera(imageSize)
m = struct( ...
    "SUCCESS", true, "ERR_BIAS", -1, "ERR_RAND", -1, ...
    "LINE_OFF", (imageSize(1) - 1) ./ 2, ...
    "SAMP_OFF", (imageSize(2) - 1) ./ 2, ...
    "LAT_OFF", 40, "LONG_OFF", -105, "HEIGHT_OFF", 1000, ...
    "LINE_SCALE", (imageSize(1) - 1) ./ 2, ...
    "SAMP_SCALE", (imageSize(2) - 1) ./ 2, ...
    "LAT_SCALE", 0.01, "LONG_SCALE", 0.01, "HEIGHT_SCALE", 200, ...
    "LINE_NUM_COEF", zeros(1, 20), ...
    "LINE_DEN_COEF", [1, zeros(1, 19)], ...
    "SAMP_NUM_COEF", zeros(1, 20), ...
    "SAMP_DEN_COEF", [1, zeros(1, 19)]);
m.LINE_NUM_COEF(3) = 1;
m.LINE_NUM_COEF(4) = -0.04;
m.SAMP_NUM_COEF(2) = 1;
m.SAMP_NUM_COEF(4) = 0.18;
camera = Rpc00bCamera(m, imageSize);
end
