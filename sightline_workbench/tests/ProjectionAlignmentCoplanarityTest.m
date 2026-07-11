classdef ProjectionAlignmentCoplanarityTest < matlab.unittest.TestCase
    %ProjectionAlignmentCoplanarityTest Normalized epipolar residual tests.

    properties (Constant)
        Tol = 1e-12
    end

    methods (TestClassSetup)
        function addSourceToPath(testCase)
            projectRoot = fileparts(fileparts(mfilename("fullpath")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(projectRoot, "src")));
        end
    end

    methods (Test)
        function testCoplanarRaysHaveZeroNormalizedResidual(testCase)
            movingOrigin = [0; 0; 0];
            referenceOrigin = [1; 0; 0];
            target = [0; 10; 2];

            result = ProjectionAlignmentCoplanarity.evaluateRays( ...
                movingOrigin, target - movingOrigin, referenceOrigin, ...
                target - referenceOrigin);

            testCase.verifyTrue(result.ValidMask);
            testCase.verifyEqual(result.Status, "valid");
            testCase.verifyEqual(result.Unit, "normalizedAngular");
            testCase.verifyEqual(result.Residuals, 0, ...
                AbsTol=ProjectionAlignmentCoplanarityTest.Tol);
        end

        function testResidualIsInvariantToUniformBaselineScale(testCase)
            movingOrigin = [0; 0; 0];
            referenceOrigin = [1; 0; 0];
            movingVector = [0; 10; 2];
            referenceVector = [-1; 10; 3];
            first = ProjectionAlignmentCoplanarity.evaluateRays( ...
                movingOrigin, movingVector, referenceOrigin, referenceVector);
            scale = 100;
            second = ProjectionAlignmentCoplanarity.evaluateRays( ...
                scale * movingOrigin, movingVector, ...
                scale * referenceOrigin, referenceVector);

            testCase.verifyTrue(first.ValidMask);
            testCase.verifyTrue(second.ValidMask);
            testCase.verifyEqual(first.Residuals, second.Residuals, ...
                AbsTol=ProjectionAlignmentCoplanarityTest.Tol);
            testCase.verifyEqual(second.BaselineMeters, ...
                scale * first.BaselineMeters, ...
                AbsTol=ProjectionAlignmentCoplanarityTest.Tol);
        end

        function testDegenerateGeometryIsFlagged(testCase)
            negligible = ProjectionAlignmentCoplanarity.evaluateRays( ...
                zeros(3, 1), [0; 1; 0], zeros(3, 1), [1; 1; 0]);
            parallel = ProjectionAlignmentCoplanarity.evaluateRays( ...
                zeros(3, 1), [0; 1; 0], [1; 0; 0], [0; 1; 0]);

            testCase.verifyFalse(negligible.ValidMask);
            testCase.verifyEqual(negligible.Status, "negligibleBaseline");
            testCase.verifyFalse(parallel.ValidMask);
            testCase.verifyEqual(parallel.Status, "nearlyParallelRays");
        end

        function testSceneSamplingUsesStablePairIdentity(testCase)
            scene = ProjectionAlignmentCoplanarityTest.makeScene();
            pairMatch = struct(Pair=[1 2], ...
                PairLayerIds=["moving-id" "reference-id"], Count=3, ...
                MovingSourceRows=[2; 4; 6], ...
                MovingSourceColumns=[3; 5; 7], ...
                ReferenceSourceRows=[2; 4; 6], ...
                ReferenceSourceColumns=[3; 5; 7]);

            result = ProjectionAlignmentCoplanarity.evaluate( ...
                scene, pairMatch);

            testCase.verifyEqual(result.Pair, [1 2]);
            testCase.verifyEqual(result.PairLayerIds, ...
                ["moving-id" "reference-id"]);
            testCase.verifyEqual(result.MovingSampler, "exactSampledRay");
            testCase.verifyEqual(result.ReferenceSampler, "exactSampledRay");
            testCase.verifyTrue(all(result.ValidMask));
            testCase.verifyEqual(result.Residuals, zeros(3, 1), ...
                AbsTol=ProjectionAlignmentCoplanarityTest.Tol);
        end

        function testProjectionOffsetsDoNotChangePhysicalCoplanarity(testCase)
            scene = ProjectionAlignmentCoplanarityTest.makeScene();
            pairMatch = struct(Pair=[1 2], ...
                PairLayerIds=["moving-id" "reference-id"], Count=3, ...
                MovingSourceRows=[2; 4; 6], ...
                MovingSourceColumns=[3; 5; 7], ...
                ReferenceSourceRows=[2; 4; 6], ...
                ReferenceSourceColumns=[3; 5; 7]);
            baseline = ProjectionAlignmentCoplanarity.evaluate( ...
                scene, pairMatch);
            scene.layers(1).ProjectionOffsetMeters = [120; -45];
            scene.layers(2).ProjectionOffsetMeters = [-80; 30];

            shifted = ProjectionAlignmentCoplanarity.evaluate( ...
                scene, pairMatch);

            testCase.verifyEqual(shifted.Residuals, baseline.Residuals, ...
                AbsTol=ProjectionAlignmentCoplanarityTest.Tol);
            testCase.verifyEqual(shifted.BaselineMeters, ...
                baseline.BaselineMeters, ...
                AbsTol=ProjectionAlignmentCoplanarityTest.Tol);
            testCase.verifyEqual(shifted.Status, baseline.Status);
        end
    end

    methods (Static, Access = private)
        function scene = makeScene()
            plane = PlanarProjection.definePlaneFromBasis( ...
                zeros(3, 1), [1; 0; 0], [0; 1; 0]);
            movingGeometry = struct(ImageSize=[10 10], ...
                SampleRayFcn=@(rows, columns) ...
                ProjectionAlignmentCoplanarityTest.raysToTargets( ...
                [0; 0; 0], rows, columns));
            referenceGeometry = struct(ImageSize=[10 10], ...
                SampleRayFcn=@(rows, columns) ...
                ProjectionAlignmentCoplanarityTest.raysToTargets( ...
                [1; 0; 0], rows, columns));
            layer = struct(LayerId="moving-id", ...
                SourceGeometry=movingGeometry, CurrentProjectionPlane=plane, ...
                ViewVectorAngularOffsetsDegrees=zeros(3, 1));
            layers = repmat(layer, 1, 2);
            layers(2).LayerId = "reference-id";
            layers(2).SourceGeometry = referenceGeometry;
            scene = struct(layers=layers, renderOrigin=zeros(3, 1));
        end

        function [origins, vectors] = raysToTargets(origin, rows, columns)
            count = numel(rows);
            origins = repmat(origin, 1, count);
            targets = [columns(:).'; 10 * ones(1, count); rows(:).'];
            vectors = targets - origins;
        end
    end
end
