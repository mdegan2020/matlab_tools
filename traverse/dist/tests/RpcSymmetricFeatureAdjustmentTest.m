classdef RpcSymmetricFeatureAdjustmentTest < matlab.unittest.TestCase
    %RPCSYMMETRICFEATUREADJUSTMENTTEST Synthetic sparse RPC-3 controls.

    methods (TestClassSetup)
        function addSource(testCase)
            root = fileparts(fileparts(mfilename("fullpath")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(root, "src")));
        end
    end

    methods (Test)
        function testKnownSymmetricCorrectionReducesEpipolarLoss(testCase)
            [r, m] = makeCameraPair;
            truth = [1.2, -1.6, 0.0012];
            rc = RpcImageCorrectionCamera(r, truth);
            mc = RpcImageCorrectionCamera(m, -truth);
            [x, y] = meshgrid(linspace(80, 560, 8), ...
                linspace(70, 410, 6));
            p1 = [x(:), y(:)];
            z = repmat([960; 1000; 1040], 16, 1);
            [world, valid] = rc.imageToWorldAtHeight(p1, z);
            [p2, projected] = mc.worldToImage(world);
            testCase.assertTrue(all(valid & projected));
            p2(1:4, :) = p2(1:4, :) + [20, -15];

            result = RpcSymmetricFeatureAdjustment.estimateFromMatches( ...
                p1, p2, r, m, 940:10:1060, MinimumMatches=12, ...
                InlierThresholdPixels=2.5, HuberThresholdPixels=2, ...
                MaximumIterations=15);

            testCase.verifyLessThan(result.AfterMedianResidualPixels, ...
                0.25 .* result.BeforeMedianResidualPixels);
            testCase.verifyEqual(result.MovingParametersNativePixelsRadians, ...
                -result.ReferenceParametersNativePixelsRadians);
            testCase.verifyLessThan(abs( ...
                result.ReferenceParametersNativePixelsRadians(2) - truth(2)), ...
                0.2);
            testCase.verifyGreaterThan(abs( ...
                result.ReferenceParametersNativePixelsRadians(3)), 2e-4);
            testCase.verifyGreaterThanOrEqual(result.InlierCount, 40);
            testCase.verifyFalse(all(result.InlierMask(1:4)));
            testCase.verifyTrue(result.Converged);
        end

        function testIdentityMatchesRemainNearZero(testCase)
            [r, m] = makeCameraPair;
            [x, y] = meshgrid(linspace(80, 560, 6), ...
                linspace(70, 410, 5));
            p1 = [x(:), y(:)];
            z = repmat([980; 1000; 1020], 10, 1);
            [world, valid] = r.imageToWorldAtHeight(p1, z);
            [p2, projected] = m.worldToImage(world);
            testCase.assertTrue(all(valid & projected));

            result = RpcSymmetricFeatureAdjustment.estimateFromMatches( ...
                p1, p2, r, m, 960:10:1040, MinimumMatches=12);

            testCase.verifyEqual( ...
                result.ReferenceParametersNativePixelsRadians, [0, 0, 0], ...
                AbsTol=1e-8);
            testCase.verifyLessThan(result.AfterMedianResidualPixels, 1e-8);
        end

        function testDegenerateFeatureDistributionFails(testCase)
            [r, m] = makeCameraPair;
            p = [(100:111).', (200:211).'];
            call = @() RpcSymmetricFeatureAdjustment.estimateFromMatches( ...
                p, p, r, m, [900, 1000, 1100]);
            testCase.verifyError(call, ...
                "RpcSymmetricFeatureAdjustment:DegenerateDistribution");
        end

        function testFeatureCapIsEnforcedInArguments(testCase)
            [r, m] = makeCameraPair;
            rw = RpcImageWindowCamera(r, [1, 480, 1, 640]);
            mw = RpcImageWindowCamera(m, [1, 500, 1, 660]);
            a = zeros(rw.ImageSize, "single");
            b = zeros(mw.ImageSize, "single");
            call = @() RpcSymmetricFeatureAdjustment.estimateFromImages( ...
                a, b, rw, mw, [900, 1000, 1100], MaximumFeatures=251);
            testCase.verifyError(call, ...
                "RpcSymmetricFeatureAdjustment:FeatureCapExceeded");
        end

        function testSurfImagePathUsesCappedNaturalImageFeatures(testCase)
            camera = Rpc00bCamera(affineRpc([240, 320], 0.2), [240, 320]);
            window = RpcImageWindowCamera(camera, [1, 240, 1, 320]);
            rng(19, "twister");
            image = imgaussfilt(single(rand(240, 320)), 1.2);
            [y, x] = ndgrid(1:240, 1:320);
            image = image + 0.5 .* single(mod(floor(x ./ 24) ...
                + floor(y ./ 21), 2));

            result = RpcSymmetricFeatureAdjustment.estimateFromImages( ...
                image, image, window, window, 960:10:1040, ...
                MaximumFeatures=100, MinimumMatches=6, ...
                MetricThreshold=10);

            testCase.verifyLessThanOrEqual( ...
                result.ReferenceDetectedCount, 100);
            testCase.verifyLessThanOrEqual( ...
                result.MovingDetectedCount, 100);
            testCase.verifyGreaterThanOrEqual(result.MatchedPairCount, 6);
            testCase.verifyEqual( ...
                result.ReferenceParametersNativePixelsRadians, [0, 0, 0], ...
                AbsTol=1e-7);
        end
    end
end

function [reference, moving] = makeCameraPair
reference = Rpc00bCamera(affineRpc([480, 640], 0.10), [480, 640]);
moving = Rpc00bCamera(affineRpc([500, 660], 0.28), [500, 660]);
end

function m = affineRpc(imageSize, heightCoefficient)
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
m.SAMP_NUM_COEF(4) = heightCoefficient;
end
