classdef ProjectionAlignmentOpkSolverTest < matlab.unittest.TestCase
    %ProjectionAlignmentOpkSolverTest Tests two-image OPK solving.

    properties (Constant)
        Tol = 1e-8
    end

    methods (TestClassSetup)
        function addSourceToPath(testCase)
            projectRoot = fileparts(fileparts(mfilename("fullpath")));
            srcFolder = fullfile(projectRoot, "src");
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(srcFolder));
        end
    end

    methods (Test)
        function testKnownPerturbationReducesProjectionResiduals(testCase)
            scene = ProjectionAlignmentOpkSolverTest.makePerturbedScene();
            matchResult = ProjectionAlignmentOpkSolverTest.makeMatchResult();
            options = ProjectionAlignmentOpkSolverTest.looseOptions();

            result = ProjectionAlignmentOpkSolver.solve(scene, matchResult, options);

            testCase.verifyTrue(result.Convergence.Success);
            testCase.verifyLessThan(result.Diagnostics.RmsAfter, ...
                result.Diagnostics.RmsBefore);
            testCase.verifyLessThan(result.Diagnostics.RmsAfter, 1e-6);
            testCase.verifyLessThan(abs( ...
                result.SolvedCorrections(1).ViewVectorAngularOffsetsDegrees(1)), ...
                abs(scene.layers(1).ViewVectorAngularOffsetsDegrees(1)));
            testCase.verifyLessThan(abs( ...
                result.SolvedCorrections(2).ViewVectorAngularOffsetsDegrees(1)), ...
                abs(scene.layers(2).ViewVectorAngularOffsetsDegrees(1)));
        end

        function testBoundsConstrainSolvedCorrections(testCase)
            scene = ProjectionAlignmentOpkSolverTest.makePerturbedScene();
            matchResult = ProjectionAlignmentOpkSolverTest.makeMatchResult();
            options = ProjectionAlignmentOpkSolverTest.tightOptions();

            result = ProjectionAlignmentOpkSolver.solve(scene, matchResult, options);

            testCase.verifyGreaterThanOrEqual( ...
                result.SolvedCorrections(1).ViewVectorAngularOffsetsDegrees(1), ...
                scene.layers(1).ViewVectorAngularOffsetsDegrees(1) - 0.001 - ...
                ProjectionAlignmentOpkSolverTest.Tol);
            testCase.verifyLessThanOrEqual( ...
                result.SolvedCorrections(2).ViewVectorAngularOffsetsDegrees(1), ...
                scene.layers(2).ViewVectorAngularOffsetsDegrees(1) + 0.001 + ...
                ProjectionAlignmentOpkSolverTest.Tol);
            testCase.verifyGreaterThan(result.Diagnostics.RmsAfter, 1e-3);
        end

        function testRegularizationKeepsPerfectInitialState(testCase)
            scene = ProjectionAlignmentOpkSolverTest.makeRegularizedScene();
            matchResult = ProjectionAlignmentOpkSolverTest.makeMatchResult();
            options = ProjectionAlignmentOpkSolverTest.looseOptions();

            result = ProjectionAlignmentOpkSolver.solve(scene, matchResult, options);

            testCase.verifyEqual( ...
                result.SolvedCorrections(1).ViewVectorAngularOffsetsDegrees, ...
                scene.layers(1).ViewVectorAngularOffsetsDegrees.', AbsTol=1e-7);
            testCase.verifyEqual( ...
                result.SolvedCorrections(2).ViewVectorAngularOffsetsDegrees, ...
                scene.layers(2).ViewVectorAngularOffsetsDegrees.', AbsTol=1e-7);
            testCase.verifyLessThan(result.Diagnostics.RmsAfter, 1e-8);
        end

        function testApplyPreviewAndRevertCorrections(testCase)
            scene = ProjectionAlignmentOpkSolverTest.makePerturbedScene();
            matchResult = ProjectionAlignmentOpkSolverTest.makeMatchResult();
            result = ProjectionAlignmentOpkSolver.solve( ...
                scene, matchResult, ProjectionAlignmentOpkSolverTest.looseOptions());

            previewScene = ProjectionAlignmentOpkSolver.previewCorrections(scene, result);
            alignedScene = ProjectionAlignmentOpkSolver.applyCorrections(scene, result);
            revertedScene = ProjectionAlignmentOpkSolver.revertCorrections( ...
                alignedScene, result);

            testCase.verifyEqual( ...
                previewScene.layers(1).ViewVectorAngularOffsetsDegrees.', ...
                result.SolvedCorrections(1).ViewVectorAngularOffsetsDegrees, ...
                AbsTol=ProjectionAlignmentOpkSolverTest.Tol);
            testCase.verifyEqual( ...
                alignedScene.layers(2).ViewVectorAngularOffsetsDegrees.', ...
                result.SolvedCorrections(2).ViewVectorAngularOffsetsDegrees, ...
                AbsTol=ProjectionAlignmentOpkSolverTest.Tol);
            testCase.verifyEqual( ...
                revertedScene.layers(1).ViewVectorAngularOffsetsDegrees.', ...
                result.Diagnostics.StartingCorrections(1).ViewVectorAngularOffsetsDegrees, ...
                AbsTol=ProjectionAlignmentOpkSolverTest.Tol);
        end

        function testJointMultiImageSolverReportsPairwiseResiduals(testCase)
            scene = ProjectionAlignmentOpkSolverTest.makeMultiLayerPerturbedScene();
            matchResult = ProjectionAlignmentOpkSolverTest.makeMultiLayerMatchResult(scene);

            result = ProjectionAlignmentOpkSolver.solve( ...
                scene, matchResult, ProjectionAlignmentOpkSolverTest.looseOptions());

            solvedLayerIndices = [result.SolvedCorrections.LayerIndex];
            testCase.verifyTrue(result.Convergence.Success);
            testCase.verifyEqual(solvedLayerIndices, 1:5);
            testCase.verifyEqual(result.RequestSummary.ReferenceLayerIndex, 3);
            testCase.verifyLessThan(result.Diagnostics.RmsAfter, ...
                result.Diagnostics.RmsBefore);
            testCase.verifyNumElements(result.Residuals.PerPair, ...
                numel(matchResult.Matches));
            for k = 1:numel(result.Residuals.PerPair)
                testCase.verifyEqual(result.Residuals.PerPair(k).Pair, ...
                    matchResult.Matches(k).Pair);
                testCase.verifyEqual(result.Residuals.PerPair(k).Count, ...
                    matchResult.Matches(k).Count);
                testCase.verifyLessThanOrEqual( ...
                    mean(result.Residuals.PerPair(k).After), ...
                    mean(result.Residuals.PerPair(k).Before));
            end
            solvedOffsets = reshape( ...
                [result.SolvedCorrections.ViewVectorAngularOffsetsDegrees], ...
                3, []).';
            testCase.verifyTrue(all(isfinite(solvedOffsets), "all"));
            testCase.verifyLessThan(max(abs(solvedOffsets), [], "all"), 0.02);
        end

        function testSharedScaleImprovesRowScaleMismatch(testCase)
            scene = ProjectionAlignmentOpkSolverTest.makeBaseTwoLayerScene();
            matchResult = ProjectionAlignmentOpkSolverTest.makeRowScaleMatchResult();
            opkOnly = ProjectionAlignmentOpkSolver.solve( ...
                scene, matchResult, ...
                ProjectionAlignmentOpkSolverTest.frozenOpkOptions(false));
            withScale = ProjectionAlignmentOpkSolver.solve( ...
                scene, matchResult, ...
                ProjectionAlignmentOpkSolverTest.frozenOpkOptions(true));

            sharedScales = [withScale.SolvedCorrections.SharedScale];
            testCase.verifyLessThan(withScale.Diagnostics.RmsAfter, ...
                opkOnly.Diagnostics.RmsAfter);
            testCase.verifyLessThan(withScale.Diagnostics.SharedScale, 0.99);
            testCase.verifyEqual(sharedScales, ...
                withScale.Diagnostics.SharedScale * ones(size(sharedScales)), ...
                AbsTol=ProjectionAlignmentOpkSolverTest.Tol);
            testCase.verifyEqual(opkOnly.Diagnostics.SharedScale, 1, ...
                AbsTol=ProjectionAlignmentOpkSolverTest.Tol);
        end

        function testInsufficientMatchesError(testCase)
            scene = ProjectionAlignmentOpkSolverTest.makePerturbedScene();
            matchResult = ProjectionAlignmentOpkSolverTest.makeMatchResult();
            matchResult.Matches.Count = 2;

            testCase.verifyError( ...
                @() ProjectionAlignmentOpkSolver.solve(scene, matchResult, ...
                ProjectionAlignmentOpkSolverTest.looseOptions()), ...
                "ProjectionAlignmentOpkSolver:insufficientMatches");
        end
    end

    methods (Static, Access = private)
        function scene = makePerturbedScene()
            scene = ProjectionAlignmentOpkSolverTest.makeBaseTwoLayerScene();
            scene.layers(1).ViewVectorAngularOffsetsDegrees = [0.006; 0; 0];
            scene.layers(2).ViewVectorAngularOffsetsDegrees = [-0.006; 0; 0];
        end

        function scene = makeRegularizedScene()
            scene = ProjectionAlignmentOpkSolverTest.makeBaseTwoLayerScene();
            scene.layers(1).ViewVectorAngularOffsetsDegrees = [0.004; 0.003; 0];
            scene.layers(2).ViewVectorAngularOffsetsDegrees = [0.004; 0.003; 0];
        end

        function scene = makeMultiLayerPerturbedScene()
            imageData = reshape(1:400, 20, 20);
            images = repmat({imageData}, 1, 5);
            scene = ProjectionViewerHarness.createSceneFromImages( ...
                images, "layer" + string(1:5) + ".tif", ...
                struct(RowStride=1, ColumnStride=1, GSD=0.5, ...
                PlatformStepMeters=0.5));
            perturbations = [ ...
                0.006, 0.002, 0.001; ...
                0.003, -0.001, 0; ...
                0, 0, 0; ...
                -0.002, 0.001, 0; ...
                -0.005, -0.002, -0.001];
            for layerIndex = 1:5
                scene.layers(layerIndex).ViewVectorAngularOffsetsDegrees = ...
                    perturbations(layerIndex, :).';
            end
        end

        function scene = makeBaseTwoLayerScene()
            imageData = reshape(1:400, 20, 20);
            scene = ProjectionViewerHarness.createSceneFromImage( ...
                imageData, "layer1.tif", struct(RowStride=1, ColumnStride=1, ...
                GSD=0.5, PlatformStepMeters=0.5));
            layer2 = scene.layers(1);
            layer2.Name = "Layer 2";
            layer2.ImagePath = "layer2.tif";
            scene.layers = [scene.layers layer2];
        end

        function matchResult = makeMatchResult()
            matchResult = struct(Matches= ...
                ProjectionAlignmentOpkSolverTest.makePairMatch([1 2]));
        end

        function matchResult = makeRowScaleMatchResult()
            pairMatch = ProjectionAlignmentOpkSolverTest.makePairMatch([1 2]);
            centerRow = 10.5;
            pairMatch.ReferenceSourceRows = centerRow + ...
                1.2 * (pairMatch.ReferenceSourceRows - centerRow);
            matchResult = struct(Matches=pairMatch);
        end

        function matchResult = makeMultiLayerMatchResult(scene)
            schedule = ProjectionAlignmentScheduler.build(scene, struct( ...
                Options=struct(Scheduling=struct(Strategy="centerOut"))));
            for k = 1:numel(schedule.Pairs)
                pairMatch = ProjectionAlignmentOpkSolverTest.makePairMatch( ...
                    schedule.Pairs(k).Pair);
                if k == 1
                    matches = pairMatch;
                else
                    matches(k) = pairMatch;
                end
            end
            matchResult = struct(Matches=matches, Schedule=schedule);
        end

        function pairMatch = makePairMatch(pair)
            rows = [5; 5; 10; 15; 15; 10];
            columns = [5; 15; 10; 5; 15; 15];
            pairMatch = struct();
            pairMatch.Pair = pair;
            pairMatch.MovingFeatureLocations = [columns rows];
            pairMatch.ReferenceFeatureLocations = [columns rows];
            pairMatch.MovingPlaneCoordinates = zeros(numel(rows), 2);
            pairMatch.ReferencePlaneCoordinates = zeros(numel(rows), 2);
            pairMatch.MovingSourceRows = rows;
            pairMatch.MovingSourceColumns = columns;
            pairMatch.ReferenceSourceRows = rows;
            pairMatch.ReferenceSourceColumns = columns;
            pairMatch.IndexPairs = [(1:numel(rows)).' (1:numel(rows)).'];
            pairMatch.MatchMetric = zeros(numel(rows), 1);
            pairMatch.Scores = ones(numel(rows), 1);
            pairMatch.FeatureCounts = [numel(rows) numel(rows)];
            pairMatch.Count = numel(rows);
            pairMatch.OverlapMask = true(20, 20);
        end

        function options = looseOptions()
            options = struct();
            options.Bounds = struct(OmegaDegrees=0.02, PhiDegrees=0.02, ...
                KappaDegrees=0.02);
            options.Regularization = struct(OverallWeight=1e-3, RobustLoss="none");
        end

        function options = tightOptions()
            options = struct();
            options.Bounds = struct(OmegaDegrees=0.001, PhiDegrees=0.001, ...
                KappaDegrees=0.001);
            options.Regularization = struct(OverallWeight=1e-6, RobustLoss="none");
        end

        function options = frozenOpkOptions(includeSharedScale)
            options = struct();
            options.MovableParameters = struct( ...
                IncludeSharedScale=includeSharedScale);
            options.Bounds = struct(OmegaDegrees=0, PhiDegrees=0, ...
                KappaDegrees=0, SharedScale=[0.8 1.2]);
            options.Regularization = struct(OverallWeight=1e-8, ...
                SharedScaleWeight=1e-6, RobustLoss="none");
        end
    end
end
