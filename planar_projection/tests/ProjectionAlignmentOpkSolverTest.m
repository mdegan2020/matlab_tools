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
            ledgerStageMasks = [result.MatchLedger.StageMasks];

            testCase.verifyTrue(result.Convergence.Success);
            testCase.verifyLessThan(result.Diagnostics.RmsAfter, ...
                result.Diagnostics.RmsBefore);
            testCase.verifyLessThan(result.Diagnostics.RmsAfter, 1e-6);
            testCase.verifyEqual(result.Residuals.Unit, "planeMeters");
            testCase.verifyNumElements(result.MatchLedger, ...
                matchResult.Matches.Count);
            testCase.verifyEqual( ...
                [ledgerStageMasks.SolverObservation], ...
                true(1, matchResult.Matches.Count));
            testCase.verifyTrue(all(strlength( ...
                [result.SolvedCorrections.LayerId]) > 0));
            testCase.verifyLessThan(abs( ...
                result.SolvedCorrections(1).ViewVectorAngularOffsetsDegrees(1)), ...
                abs(scene.layers(1).ViewVectorAngularOffsetsDegrees(1)));
            testCase.verifyLessThan(abs( ...
                result.SolvedCorrections(2).ViewVectorAngularOffsetsDegrees(1)), ...
                abs(scene.layers(2).ViewVectorAngularOffsetsDegrees(1)));
        end

        function testProjectionLossUsesObservationRaySamplerWithoutMesh(testCase)
            scene = ProjectionAlignmentOpkSolverTest.makePerturbedScene();
            scene = ProjectionAlignmentOpkSolverTest.invalidateMeshSampling(scene);
            matchResult = ProjectionAlignmentOpkSolverTest.makeMatchResult();

            result = ProjectionAlignmentOpkSolver.solve( ...
                scene, matchResult, ProjectionAlignmentOpkSolverTest.looseOptions());

            testCase.verifyTrue(result.Convergence.Success);
            testCase.verifyLessThan(result.Diagnostics.RmsAfter, ...
                result.Diagnostics.RmsBefore);
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
            testCase.verifyTrue(result.Diagnostics.AnyBoundHit);
            testCase.verifyTrue(any([result.Diagnostics.BoundHits.Any]));
            testCase.verifyTrue(any(contains(result.Warnings, "bounds")));
        end

        function testFovDerivedBoundsAndKappaCapAreReported(testCase)
            scene = ProjectionAlignmentOpkSolverTest.makeFovMetadataScene();
            matchResult = ProjectionAlignmentOpkSolverTest.makeMatchResult();
            options = struct();
            options.Bounds = struct(KappaDegrees=15);
            options.Regularization = struct(OverallWeight=1e-3, RobustLoss="none");
            expectedFovBound = 0.25 * rad2deg(20 * 0.1 / 1000);

            result = ProjectionAlignmentOpkSolver.solve(scene, matchResult, options);

            testCase.verifyEqual(result.Diagnostics.BoundsDegrees(:, 1), ...
                expectedFovBound * ones(2, 1), AbsTol=1e-10);
            testCase.verifyEqual(result.Diagnostics.BoundsDegrees(:, 2), ...
                expectedFovBound * ones(2, 1), AbsTol=1e-10);
            testCase.verifyEqual(result.Diagnostics.BoundsDegrees(:, 3), ...
                15 * ones(2, 1), AbsTol=ProjectionAlignmentOpkSolverTest.Tol);
            testCase.verifyFalse(result.Diagnostics.AnyBoundHit);
        end

        function testResidualDiagnosticsIdentifyWorstMatch(testCase)
            scene = ProjectionAlignmentOpkSolverTest.makeBaseTwoLayerScene();
            matchResult = ProjectionAlignmentOpkSolverTest.makeOutlierMatchResult();

            result = ProjectionAlignmentOpkSolver.solve( ...
                scene, matchResult, ...
                ProjectionAlignmentOpkSolverTest.frozenOpkOptions(false));

            records = result.Diagnostics.MatchRecords;
            pairSummary = result.Diagnostics.PerPairResidualSummary;
            testCase.verifyGreaterThan(result.Diagnostics.MaxResidualAfter, 0);
            testCase.verifyEqual(result.Diagnostics.MaxResidualAfter, ...
                result.Diagnostics.WorstResiduals.After.Residual, ...
                AbsTol=ProjectionAlignmentOpkSolverTest.Tol);
            testCase.verifyEqual( ...
                result.Diagnostics.WorstResiduals.After.Pair, [1 2]);
            testCase.verifyEqual( ...
                result.Diagnostics.WorstResiduals.After.MatchIndex, 6);
            testCase.verifyEqual(pairSummary.WorstMatchIndexAfter, 6);
            testCase.verifyEqual(pairSummary.MaxResidualAfter, ...
                result.Diagnostics.MaxResidualAfter, ...
                AbsTol=ProjectionAlignmentOpkSolverTest.Tol);
            testCase.verifyNumElements(records, matchResult.Matches.Count);
            testCase.verifyEqual([records.MatchIndex], 1:matchResult.Matches.Count);
            testCase.verifyEqual(records(6).ReferenceSourceColumn, ...
                matchResult.Matches.ReferenceSourceColumns(6), ...
                AbsTol=ProjectionAlignmentOpkSolverTest.Tol);
            testCase.verifyTrue(records(6).Accepted);
            testCase.verifyFalse(records(6).Disabled);
            testCase.verifyGreaterThan(result.Convergence.FunctionEvaluations, 0);
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

        function testRayToRayLossReportsComparisonDiagnostics(testCase)
            scene = ProjectionAlignmentOpkSolverTest.makePerturbedScene();
            matchResult = ProjectionAlignmentOpkSolverTest.makeMatchResult();

            result = ProjectionAlignmentOpkSolver.solve( ...
                scene, matchResult, ProjectionAlignmentOpkSolverTest.rayOptions());

            testCase.verifyTrue(result.Convergence.Success);
            testCase.verifyEqual(result.Residuals.LossMode, "rayToRay3D");
            testCase.verifyEqual(result.RequestSummary.LossMode, "rayToRay3D");
            testCase.verifyNumElements(result.Residuals.Before, ...
                matchResult.Matches.Count);
            testCase.verifyNumElements(result.Residuals.PerPair, 1);
            testCase.verifyLessThanOrEqual(result.Diagnostics.RmsAfter, ...
                result.Diagnostics.RmsBefore + ProjectionAlignmentOpkSolverTest.Tol);
            testCase.verifyTrue(isfield(result.Diagnostics.Comparison, ...
                "ProjectionPlaneRmsBefore"));
            testCase.verifyTrue(isfield(result.Diagnostics.Comparison, ...
                "ProjectionPlaneRmsAfter"));
        end

        function testRayToRayLossHandlesParallelRays(testCase)
            scene = ProjectionAlignmentOpkSolverTest.makeBaseTwoLayerScene();
            scene.layers(2).SourceGeometry = scene.layers(1).SourceGeometry;
            matchResult = ProjectionAlignmentOpkSolverTest.makeMatchResult();

            result = ProjectionAlignmentOpkSolver.solve( ...
                scene, matchResult, ProjectionAlignmentOpkSolverTest.rayOptions());

            testCase.verifyTrue(result.Convergence.Success);
            testCase.verifyTrue(all(isfinite(result.Residuals.Before)));
            testCase.verifyTrue(all(isfinite(result.Residuals.After)));
        end

        function testRayToRayLossUsesObservationRaySamplerWithoutMesh(testCase)
            scene = ProjectionAlignmentOpkSolverTest.makePerturbedScene();
            scene = ProjectionAlignmentOpkSolverTest.invalidateMeshSampling(scene);
            matchResult = ProjectionAlignmentOpkSolverTest.makeMatchResult();

            result = ProjectionAlignmentOpkSolver.solve( ...
                scene, matchResult, ProjectionAlignmentOpkSolverTest.rayOptions());

            testCase.verifyTrue(result.Convergence.Success);
            testCase.verifyTrue(all(isfinite(result.Residuals.After)));
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

        function scene = makeFovMetadataScene()
            scene = ProjectionAlignmentOpkSolverTest.makePerturbedScene();
            for layerIndex = 1:numel(scene.layers)
                scene.layers(layerIndex).SourceGeometry.NominalRange = 1000;
                scene.layers(layerIndex).SourceGeometry.GSD = 0.1;
                scene.layers(layerIndex).SourceGeometry.PlatformStepMeters = 0.2;
            end
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

        function scene = invalidateMeshSampling(scene)
            for layerIndex = 1:numel(scene.layers)
                imageSize = scene.layers(layerIndex).SourceGeometry.ImageSize;
                scene.layers(layerIndex).MeshSampling.RowIndices = imageSize(1) + 1;
                scene.layers(layerIndex).MeshSampling.ColumnIndices = imageSize(2) + 1;
            end
        end

        function matchResult = makeMatchResult()
            matchResult = struct(Matches= ...
                ProjectionAlignmentOpkSolverTest.makePairMatch([1 2]));
        end

        function matchResult = makeOutlierMatchResult()
            pairMatch = ProjectionAlignmentOpkSolverTest.makePairMatch([1 2]);
            pairMatch.ReferenceFeatureLocations(6, :) = [5 5];
            pairMatch.ReferenceSourceRows(6) = 5;
            pairMatch.ReferenceSourceColumns(6) = 5;
            matchResult = struct(Matches=pairMatch);
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

        function options = rayOptions()
            options = ProjectionAlignmentOpkSolverTest.looseOptions();
            options.LossMode = "rayToRay3D";
            options.Regularization.RobustLoss = "none";
        end
    end
end
