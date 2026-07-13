classdef ProjectionPairwisePointCovarianceTest < matlab.unittest.TestCase
    %ProjectionPairwisePointCovarianceTest B3 triangulation uncertainty tests.

    methods (TestClassSetup)
        function addSourcePath(testCase)
            root = fileparts(fileparts(mfilename("fullpath")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(root, "src")));
        end
    end

    methods (Test)
        function testExactForwardIntersectionReportsGeometry(testCase)
            request = ProjectionPairwisePointCovarianceTest.request(2, true);

            result = ProjectionPairwisePointCovariance.reconstruct(request);
            record = result.Records;

            testCase.verifyEqual(record.PointWorld, [0; 0; 10], AbsTol=1e-10);
            testCase.verifyLessThan(record.RaySeparationMeters, 1e-10);
            testCase.verifyTrue(all(record.RayParameters > 0));
            testCase.verifyGreaterThan(record.IntersectionAngleDegrees, 0);
            testCase.verifyGreaterThan(record.ConditionNumber, 1);
            testCase.verifyTrue(record.Valid);
        end

        function testCovarianceIsSymmetricPsdAndFrameExplicit(testCase)
            request = ProjectionPairwisePointCovarianceTest.request(2, true);

            result = ProjectionPairwisePointCovariance.reconstruct(request);
            record = result.Records;

            testCase.verifyEqual(record.CovarianceStatus, "available");
            testCase.verifyEqual(record.CovarianceFrame, "sceneWorld");
            testCase.verifyEqual(result.CovarianceUnits, "metersSquared");
            testCase.verifyEqual(record.CovarianceWorldMetersSquared, ...
                record.CovarianceWorldMetersSquared.', AbsTol=1e-14);
            testCase.verifyGreaterThanOrEqual( ...
                eig(record.CovarianceWorldMetersSquared), -1e-10);
            testCase.verifyGreaterThanOrEqual( ...
                record.PrincipalAxisSigmasMeters, 0);
        end

        function testObservationCovarianceScalingPropagates(testCase)
            firstRequest = ProjectionPairwisePointCovarianceTest.request(2, true);
            secondRequest = ProjectionPairwisePointCovarianceTest.request(2, true);
            secondRequest.ObservationCovariancePixelsSquared = 4 * eye(4);

            first = ProjectionPairwisePointCovariance.reconstruct(firstRequest);
            second = ProjectionPairwisePointCovariance.reconstruct(secondRequest);

            testCase.verifyEqual( ...
                second.Records.CovarianceWorldMetersSquared, ...
                4 * first.Records.CovarianceWorldMetersSquared, ...
                RelTol=1e-10, AbsTol=1e-14);
        end

        function testMissingUncertaintyIsUnavailableNotZero(testCase)
            request = ProjectionPairwisePointCovarianceTest.request(2, false);

            result = ProjectionPairwisePointCovariance.reconstruct(request);
            record = result.Records;

            testCase.verifyEqual(record.CovarianceStatus, "unavailable");
            testCase.verifyEqual(record.CovarianceReason, ...
                "observationAndGeometryCovarianceMissing");
            testCase.verifyTrue(all(isnan( ...
                record.CovarianceWorldMetersSquared), "all"));
            testCase.verifyEqual(result.CovarianceAvailableCount, 0);
        end

        function testCorrelatedRayStateCovarianceAlsoPropagates(testCase)
            firstRequest = ProjectionPairwisePointCovarianceTest.request(2, false);
            secondRequest = ProjectionPairwisePointCovarianceTest.request(2, false);
            firstRequest.RayStateCovarianceWorld = 1e-6 * eye(12);
            secondRequest.RayStateCovarianceWorld = 9e-6 * eye(12);

            first = ProjectionPairwisePointCovariance.reconstruct(firstRequest);
            second = ProjectionPairwisePointCovariance.reconstruct(secondRequest);

            testCase.verifyEqual(first.Records.CovarianceStatus, "available");
            testCase.verifyEqual( ...
                second.Records.CovarianceWorldMetersSquared, ...
                9 * first.Records.CovarianceWorldMetersSquared, ...
                RelTol=1e-8, AbsTol=1e-12);
        end

        function testWeakGeometryIsLabeledUnreliable(testCase)
            request = ProjectionPairwisePointCovarianceTest.request(0.001, true);
            request.MaximumConditionNumber = 100;

            result = ProjectionPairwisePointCovariance.reconstruct(request);
            record = result.Records;

            testCase.verifyEqual(record.CovarianceStatus, "unreliable");
            testCase.verifyEqual(record.CovarianceReason, ...
                "weakGeometryOrNonPsdLinearization");
            testCase.verifyFalse(record.ReliableLinearization);
            testCase.verifyGreaterThan(record.ConditionNumber, 100);
        end

        function testBehindRayIntersectionIsInvalid(testCase)
            request = ProjectionPairwisePointCovarianceTest.request(2, true);
            request.FirstVectors = -request.FirstVectors;
            request.SecondVectors = -request.SecondVectors;

            result = ProjectionPairwisePointCovariance.reconstruct(request);

            testCase.verifyFalse(result.Records.Valid);
            testCase.verifyTrue(all(isnan(result.Records.PointWorld)));
            testCase.verifyEqual(result.ValidCount, 0);
        end
    end

    methods (Static, Access = private)
        function request = request(baseline, includeCovariance)
            point = [0; 0; 10];
            firstOrigin = [-baseline / 2; 0; 0];
            secondOrigin = [baseline / 2; 0; 0];
            jacobian = [0.001 0; 0 0.001; 0 0];
            request = struct(PairIds="pair:test", ...
                ViewIds=["view-a" "view-b"], ...
                FirstOrigins=firstOrigin, FirstVectors=point - firstOrigin, ...
                SecondOrigins=secondOrigin, SecondVectors=point - secondOrigin, ...
                FirstDirectionJacobian=jacobian, ...
                SecondDirectionJacobian=jacobian, ...
                WorldFrame="sceneWorld", CovarianceStatus="assumed");
            if includeCovariance
                request.ObservationCovariancePixelsSquared = eye(4);
            end
        end
    end
end
