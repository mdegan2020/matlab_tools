classdef ProjectionAlignmentNetworkSolverTest < matlab.unittest.TestCase
    %ProjectionAlignmentNetworkSolverTest Tests global constant-OPK solving.

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
        function testUniqueTrackEvidenceRemovesCycleDuplicates(testCase)
            [scene, filtered] = ...
                ProjectionAlignmentNetworkSolverTest.triangleInputs();
            options = ProjectionAlignmentNetworkSolverTest.options();
            options.Network = struct(Enabled=true);

            evidence = ProjectionAlignmentNetworkEvidence.prepare( ...
                filtered, options);

            testCase.verifyEqual(evidence.Diagnostics.TrackCount, 6);
            testCase.verifyEqual(evidence.Diagnostics.AcceptedTrackEdgeCount, 18);
            testCase.verifyEqual(evidence.Diagnostics.SelectedRecordCount, 12);
            testCase.verifyEqual(evidence.Diagnostics.RemovedCycleEdgeCount, 6);
            testCase.verifyEqual(numel(evidence.MatchResult.Matches), 2);
            testCase.verifyEqual(sum([evidence.MatchResult.Matches.Count]), 12);
            testCase.verifyEqual(numel(unique(string( ...
                {evidence.RecordMap.RecordId}))), 12);
            testCase.verifyEqual(numel(unique(string( ...
                {evidence.RecordMap.TrackId}))), 6);
            testCase.verifyEqual(numel(scene.layers), 3);
        end

        function testGlobalNetworkSolveDefaultsToEpipolarAndReportsDiagnostics( ...
                testCase)
            testCase.assumeTrue(exist("lsqnonlin", "file") == 2);
            [scene, filtered] = ...
                ProjectionAlignmentNetworkSolverTest.triangleInputs();

            result = ProjectionAlignmentNetworkSolver.solve( ...
                scene, filtered, ProjectionAlignmentNetworkSolverTest.options());

            network = result.Diagnostics.Network;
            testCase.verifyTrue(result.Convergence.Success);
            testCase.verifyEqual(result.RequestSummary.SolverMode, ...
                "globalConstantOpkNetwork");
            testCase.verifyEqual(result.Residuals.LossMode, ...
                "epipolarCoplanarity");
            testCase.verifyEqual(network.ActiveResidual, ...
                "epipolarCoplanarity");
            testCase.verifyTrue(network.RayOriginsFixed);
            testCase.verifyEqual(network.Evidence.SelectedRecordCount, 12);
            testCase.verifyNumElements(network.Components, 1);
            testCase.verifyTrue(network.Gauge.Valid);
            testCase.verifyNumElements(network.ViewCovariance, 3);
            testCase.verifyTrue(all(isfinite(reshape( ...
                [network.ViewCovariance.StandardDeviationDegrees], 3, [])), ...
                "all"));
            testCase.verifyNumElements(network.ResidualsByTrack, 6);
            testCase.verifyTrue(all([network.ResidualsByTrack.Count] == 2));
            testCase.verifyNumElements(network.ResidualsByPass, 1);
            testCase.verifyNotEmpty(network.ResidualsByImageRegion);
            testCase.verifyGreaterThanOrEqual( ...
                network.Robustification.Scale, 1e-6);
            testCase.verifyLessThanOrEqual( ...
                network.Robustification.Scale, 0.05);
            testCase.verifyNumElements(network.Robustification.Weights, 12);
        end

        function testFixedReferenceGaugeUsesNamedView(testCase)
            testCase.assumeTrue(exist("lsqnonlin", "file") == 2);
            [scene, filtered] = ...
                ProjectionAlignmentNetworkSolverTest.triangleInputs();
            fixedViewId = scene.layers(2).ViewId;
            options = ProjectionAlignmentNetworkSolverTest.options();
            options.Network = struct(GaugePolicy="fixedReference", ...
                FixedReferenceViewId=fixedViewId);
            starting = scene.layers(2).ViewVectorAngularOffsetsDegrees(:).';

            result = ProjectionAlignmentNetworkSolver.solve( ...
                scene, filtered, options);
            fixedCorrection = result.SolvedCorrections( ...
                [result.SolvedCorrections.LayerIndex] == 2);

            testCase.verifyEqual(result.RequestSummary.ReferenceLayerIndex, 2);
            testCase.verifyEqual(result.RequestSummary.GaugePolicy, ...
                "fixedReference");
            testCase.verifyEqual( ...
                fixedCorrection.ViewVectorAngularOffsetsDegrees, starting, ...
                AbsTol=ProjectionAlignmentNetworkSolverTest.Tol);
            testCase.verifyEqual( ...
                result.Diagnostics.Network.Gauge.FixedReferenceViewId, ...
                fixedViewId);
        end

        function testGaugeDeficientDisconnectedComponentStopsBeforeSolve(testCase)
            [scene, filtered] = ...
                ProjectionAlignmentNetworkSolverTest.disconnectedInputs();
            options = ProjectionAlignmentNetworkSolverTest.options();
            options.Regularization.OverallWeight = 0;

            testCase.verifyError(@() ProjectionAlignmentNetworkSolver.solve( ...
                scene, filtered, options), ...
                "ProjectionAlignmentNetworkSolver:gaugeDeficientComponent");
        end

        function testNetworkCorrectionSetUsesExistingImmutableSdkContract(testCase)
            testCase.assumeTrue(exist("lsqnonlin", "file") == 2);
            [scene, filtered] = ...
                ProjectionAlignmentNetworkSolverTest.triangleInputs();

            correctionSet = ProjectionAlignmentNetworkSolver.solveCorrectionSet( ...
                scene, filtered, ProjectionAlignmentNetworkSolverTest.options(), ...
                struct(GenerationId="network-generation", ...
                CreatedAt="2026-07-12T00:00:00.000Z"));

            testCase.verifyClass(correctionSet, "ProjectionCorrectionSet");
            testCase.verifyEqual(correctionSet.GenerationId, ...
                "network-generation");
            testCase.verifyTrue(correctionSet.compatibility(scene).Compatible);
            testCase.verifyEqual(string({correctionSet.Views.ViewId}), ...
                ProjectionViewMetadata.ids(scene));
            testCase.verifyTrue(correctionSet.Covariance.Available);
            testCase.verifySize( ...
                correctionSet.Covariance.AttitudeRadiansSquared, [9 9]);
            testCase.verifyTrue(correctionSet.Provenance.Track.Available);
        end

        function testAdvancedCauchyComparisonRetainsInspectableWeights(testCase)
            testCase.assumeTrue(exist("lsqnonlin", "file") == 2);
            [scene, filtered] = ...
                ProjectionAlignmentNetworkSolverTest.triangleInputs();
            options = ProjectionAlignmentNetworkSolverTest.options();
            options.Regularization.RobustLoss = "cauchy";

            result = ProjectionAlignmentNetworkSolver.solve( ...
                scene, filtered, options);
            robust = result.Diagnostics.Network.Robustification;

            testCase.verifyEqual(robust.Loss, "cauchy");
            testCase.verifyTrue(all(isfinite(robust.Weights)));
            testCase.verifyTrue(all(robust.Weights >= 0 & robust.Weights <= 1));
            testCase.verifyNumElements( ...
                robust.RejectionReasons, numel(result.Residuals.After));
        end

        function testMultiplePassParameterizationHasExactWeightedZeroMean( ...
                testCase)
            testCase.assumeTrue(exist("lsqnonlin", "file") == 2);
            [scene, filtered] = ...
                ProjectionAlignmentNetworkSolverTest.multiPassInputs();
            options = ProjectionAlignmentNetworkSolverTest.options();
            layerIds = string({scene.layers.LayerId});
            options.PointingPriors = struct(LayerIds=layerIds, ...
                SigmaDegrees=[10 1 1; 1 1 1; 2 1 1]);

            result = ProjectionAlignmentNetworkSolver.solve( ...
                scene, filtered, options);
            model = result.Diagnostics.AttitudeModel;
            network = result.Diagnostics.Network;

            testCase.verifyEqual(model.Parameterization, ...
                "passCommonPlusWeightedZeroMeanDifferential");
            testCase.verifyNumElements(model.Passes, 2);
            testCase.verifyEqual(string({model.Passes.PassId}), ...
                ["pass-a" "pass-b"]);
            for pass = model.Passes
                testCase.verifyEqual( ...
                    pass.WeightedDifferentialMeanDegrees, zeros(1, 3), ...
                    AbsTol=1e-12);
            end
            testCase.verifyEqual(network.Configuration, "multiplePasses");
            testCase.verifyNumElements(network.PassCorrections, 2);
            testCase.verifyNumElements(network.PriorDominanceByPass, 2);
            testCase.verifyNumElements(network.LeaveOnePairOut, 2);
            testCase.verifyTrue(all(isfinite( ...
                [network.LeaveOnePairOut.MaxAttitudeChangeDegrees])));
            testCase.verifyNotEmpty(network.ResidualsByTimeInterval);
            testCase.verifyTrue(isfinite(network.PriorContribution.Fraction));
            testCase.verifyEqual(network.Components.PassIds, ...
                ["pass-a" "pass-b"]);
        end

        function testSinglePassAndIndependentViewConfigurationsShareModel( ...
                testCase)
            testCase.assumeTrue(exist("lsqnonlin", "file") == 2);
            [scene, filtered] = ...
                ProjectionAlignmentNetworkSolverTest.multiPassInputs();
            singleOptions = ProjectionAlignmentNetworkSolverTest.options();
            singleOptions.Network = struct(Configuration="singlePass", ...
                ComputeLeaveOnePairOut=false);
            independentOptions = ProjectionAlignmentNetworkSolverTest.options();
            independentOptions.Network = struct( ...
                Configuration="independentViewsCustomPriors", ...
                ComputeLeaveOnePairOut=false);

            single = ProjectionAlignmentNetworkSolver.solve( ...
                scene, filtered, singleOptions);
            independent = ProjectionAlignmentNetworkSolver.solve( ...
                scene, filtered, independentOptions);

            testCase.verifyNumElements( ...
                single.Diagnostics.Network.PassCorrections, 1);
            testCase.verifyNumElements( ...
                independent.Diagnostics.Network.PassCorrections, 3);
            testCase.verifyEqual( ...
                independent.Diagnostics.Network.Configuration, ...
                "independentViewsCustomPriors");
            testCase.verifyTrue(all(arrayfun(@(pass) ...
                size(pass.DifferentialDeltaDegrees, 1) == 1, ...
                independent.Diagnostics.Network.PassCorrections)));
        end

        function testCorrectionSetReportsIndependentPassCommonValues(testCase)
            testCase.assumeTrue(exist("lsqnonlin", "file") == 2);
            [scene, filtered] = ...
                ProjectionAlignmentNetworkSolverTest.multiPassInputs();
            options = ProjectionAlignmentNetworkSolverTest.options();
            options.Network = struct(ComputeLeaveOnePairOut=false);

            correctionSet = ProjectionAlignmentNetworkSolver.solveCorrectionSet( ...
                scene, filtered, options, ...
                struct(GenerationId="multipass-generation", ...
                CreatedAt="2026-07-12T01:00:00.000Z"));

            testCase.verifyNumElements(correctionSet.Passes, 2);
            testCase.verifyEqual(string({correctionSet.Passes.PassId}), ...
                ["pass-a" "pass-b"]);
            for pass = correctionSet.Passes
                passViews = correctionSet.Views( ...
                    string({correctionSet.Views.PassId}) == pass.PassId);
                common = reshape([passViews.CommonAttitudeRadians], 3, []);
                testCase.verifyEqual(pass.CommonAttitudeRadians, ...
                    mean(common, 2).', AbsTol=1e-12);
            end
        end
    end

    methods (Static, Access = private)
        function [scene, filtered] = triangleInputs()
            scene = ProjectionAlignmentNetworkSolverTest.makeScene(3);
            pairs = [1 2; 2 3; 1 3];
            metrics = [0.1 0.2 0.3];
            matches = ProjectionAlignmentNetworkSolverTest.makeMatches( ...
                scene, pairs, metrics);
            filtered = ProjectionAlignmentMatchFilter.filter( ...
                struct(Matches=matches, Diagnostics=struct()), ...
                struct(FilterPipeline=struct(Stages="overlapMask")));
        end

        function [scene, filtered] = disconnectedInputs()
            scene = ProjectionAlignmentNetworkSolverTest.makeScene(4);
            pairs = [1 2; 3 4];
            matches = ProjectionAlignmentNetworkSolverTest.makeMatches( ...
                scene, pairs, [0.1 0.2]);
            filtered = ProjectionAlignmentMatchFilter.filter( ...
                struct(Matches=matches, Diagnostics=struct()), ...
                struct(FilterPipeline=struct(Stages="overlapMask")));
        end

        function [scene, filtered] = multiPassInputs()
            [scene, filtered] = ...
                ProjectionAlignmentNetworkSolverTest.triangleInputs();
            scene.layers(1).PassId = "pass-a";
            scene.layers(2).PassId = "pass-a";
            scene.layers(3).PassId = "pass-b";
            scene = ProjectionViewMetadata.ensureScene(scene);
        end

        function scene = makeScene(layerCount)
            imageData = reshape(1:400, 20, 20);
            scene = ProjectionViewerHarness.createSceneFromImages( ...
                repmat({imageData}, 1, layerCount), ...
                "network-layer-" + string(1:layerCount) + ".tif", ...
                struct(RowStride=1, ColumnStride=1, GSD=0.5, ...
                PlatformStepMeters=0.5));
            perturbations = linspace(0.004, -0.004, layerCount);
            for layerIndex = 1:layerCount
                scene.layers(layerIndex).ViewVectorAngularOffsetsDegrees = ...
                    [perturbations(layerIndex); 0; 0];
            end
            scene = ProjectionViewMetadata.ensureScene(scene);
        end

        function matches = makeMatches(scene, pairs, metrics)
            for pairIndex = 1:size(pairs, 1)
                pair = ProjectionAlignmentNetworkSolverTest.makePair( ...
                    scene, pairs(pairIndex, :), metrics(pairIndex));
                if pairIndex == 1
                    matches = pair;
                else
                    matches(pairIndex) = pair;
                end
            end
        end

        function pair = makePair(scene, layerPair, metric)
            rows = [5; 5; 10; 15; 15; 10];
            columns = [5; 15; 10; 5; 15; 15];
            layerIds = string({scene.layers(layerPair).LayerId});
            pair = struct(Pair=layerPair, PairLayerIds=layerIds, ...
                MovingLayerId=layerIds(1), ReferenceLayerId=layerIds(2), ...
                PairDirection="movingToReference", Detector="sift", ...
                Matcher="exhaustive", ...
                MovingFeatureLocations=[columns rows], ...
                ReferenceFeatureLocations=[columns rows], ...
                MovingPlaneCoordinates=zeros(numel(rows), 2), ...
                ReferencePlaneCoordinates=zeros(numel(rows), 2), ...
                MovingSourceRows=rows, MovingSourceColumns=columns, ...
                ReferenceSourceRows=rows, ReferenceSourceColumns=columns, ...
                IndexPairs=[(1:numel(rows)).' (1:numel(rows)).'], ...
                MatchMetric=metric * ones(numel(rows), 1), ...
                Scores=ones(numel(rows), 1), ...
                FeatureCounts=[numel(rows) numel(rows)], ...
                Count=numel(rows), OverlapMask=true(20, 20));
        end

        function options = options()
            options = struct( ...
                Bounds=struct(OmegaDegrees=0.02, PhiDegrees=0.02, ...
                KappaDegrees=0.02), ...
                Regularization=struct(OverallWeight=1e-3, ...
                RobustLoss="huber"));
        end
    end
end
