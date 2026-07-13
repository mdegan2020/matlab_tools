classdef ProjectionDenseSearchPlanningTest < matlab.unittest.TestCase
    %ProjectionDenseSearchPlanningTest B1 dense scheduling and seed tests.

    methods (TestClassSetup)
        function addSourcePath(testCase)
            projectRoot = fileparts(fileparts(mfilename("fullpath")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(projectRoot, "src")));
        end
    end

    methods (Test)
        function testRegionalPredictionRetainsSeedProvenance(testCase)
            request = ProjectionDenseSearchPlanningTest.request();
            evidence = ProjectionDenseSearchPlanningTest.sparseEvidence();

            prediction = ProjectionDenseSearchPredictor.build(request, evidence);
            states = string({prediction.Regions.State});
            seeded = prediction.Regions(states == "seeded");

            testCase.verifyEqual(prediction.Format, ...
                ProjectionDenseSearchPredictor.Format);
            testCase.verifyEqual(prediction.GridSize, [2 2]);
            testCase.verifyEqual(states, ...
                ["seeded" "unseeded" "unseeded" "seeded"]);
            testCase.verifyEqual(seeded(1).DisparityVectorPixels, [4 1]);
            testCase.verifyEqual(seeded(2).DisparityVectorPixels, [8 0]);
            testCase.verifyEqual(seeded(1).SupportingTrackIds, ...
                ["track-a"; "track-b"]);
            testCase.verifyEqual(seeded(2).DepthRangeMeters, [80 100]);
            testCase.verifyFalse(prediction.ForcesSurface);
            testCase.verifyFalse(prediction.TruthUsed);
        end

        function testUnsupportedRegionsRemainExplicitOrUseWidePrior(testCase)
            request = ProjectionDenseSearchPlanningTest.request();
            evidence = ProjectionDenseSearchPlanningTest.sparseEvidence();

            supported = ProjectionDenseSearchPredictor.build( ...
                request, evidence);
            unsupported = ProjectionDenseSearchPredictor.build( ...
                request, evidence, struct(AllowUnseededSearch=false));
            supportedStates = string({supported.Regions.State});
            unsupportedStates = string({unsupported.Regions.State});
            wide = supported.Regions(supportedStates == "unseeded");

            testCase.verifyEqual(supportedStates, ...
                ["seeded" "unseeded" "unseeded" "seeded"]);
            testCase.verifyEqual(unsupportedStates, ...
                ["seeded" "noSupport" "noSupport" "seeded"]);
            testCase.verifyGreaterThanOrEqual( ...
                [wide.UncertaintyPixels], 12);
            testCase.verifyTrue(all(cellfun(@isempty, ...
                {wide.SupportingTrackIds})));
        end

        function testEmptySparseEvidenceDoesNotInventSurface(testCase)
            request = ProjectionDenseSearchPlanningTest.request();
            evidence = struct(MovingPoints=zeros(0, 2), ...
                ReferencePoints=zeros(0, 2));

            prediction = ProjectionDenseSearchPredictor.build( ...
                request, evidence);

            testCase.verifyEqual(prediction.SeedCount, 0);
            testCase.verifyTrue(all(string( ...
                {prediction.Regions.State}) == "noSupport"));
            testCase.verifyFalse(prediction.ForcesSurface);
        end

        function testPredictionAttachesToValidatedMatcherRequest(testCase)
            request = ProjectionDenseSearchPlanningTest.request();
            evidence = ProjectionDenseSearchPlanningTest.sparseEvidence();

            attached = ProjectionDenseSearchPredictor.attach(request, evidence);

            testCase.verifyEqual(attached.SearchPrediction.Format, ...
                ProjectionDenseSearchPredictor.Format);
            testCase.verifyEqual(attached.SearchPrediction.PairId, ...
                attached.PairId);
            testCase.verifyEqual(attached.SearchPrediction.ViewIds, ...
                attached.ViewIds);
        end

        function testDenseScheduleIsIndependentAndQualityRanked(testCase)
            [scene, evidence] = ProjectionDenseSearchPlanningTest.scheduleFixture();

            schedule = ProjectionDensePairScheduler.build(scene, evidence);
            selectedScores = [schedule.Selected.SelectionScore];

            testCase.verifyEqual(schedule.Format, ...
                ProjectionDensePairScheduler.Format);
            testCase.verifyFalse(schedule.SparseScheduleConsumed);
            testCase.verifyEqual(schedule.SelectedPairCount, 3);
            testCase.verifyTrue(all(diff(selectedScores) <= 0));
            testCase.verifyTrue(schedule.ValidationViewReserved);
            testCase.verifyEqual(numel(schedule.ValidationCandidates), 1);
            testCase.verifyTrue( ...
                schedule.Diagnostics.EveryDecisionExplained);
            testCase.verifyGreaterThan(schedule.PredictedCost, 0);
            testCase.verifyGreaterThan(schedule.PredictedMemoryBytes, 0);
        end

        function testAllPlausibleAndOperatorOverridesAreExplained(testCase)
            [scene, evidence] = ProjectionDenseSearchPlanningTest.scheduleFixture();
            ids = ProjectionDenseSearchPlanningTest.pairIds(scene, evidence);
            options = struct(AllPlausiblePairs=true, MaximumPairs=1, ...
                ReserveValidationView=false, ...
                ForceIncludePairIds=ids(6), ForceExcludePairIds=ids(1));

            schedule = ProjectionDensePairScheduler.build( ...
                scene, evidence, options);
            included = schedule.Candidates( ...
                string({schedule.Candidates.PairId}) == ids(6));
            excluded = schedule.Candidates( ...
                string({schedule.Candidates.PairId}) == ids(1));

            testCase.verifyGreaterThan(schedule.SelectedPairCount, 1);
            testCase.verifyEqual(included.Decision, "selected");
            testCase.verifyEqual(included.SelectionReason, "operatorIncluded");
            testCase.verifyTrue(included.Forced);
            testCase.verifyEqual(excluded.Decision, "rejected");
            testCase.verifyEqual(excluded.SelectionReason, "operatorExcluded");
            testCase.verifyTrue(excluded.Forced);
        end

        function testValidationReservationAndDeterminismAreExplicit(testCase)
            [scene, evidence] = ProjectionDenseSearchPlanningTest.scheduleFixture();

            first = ProjectionDensePairScheduler.build(scene, evidence);
            second = ProjectionDensePairScheduler.build(scene, evidence);

            testCase.verifyEqual(first, second);
            testCase.verifyEqual(first.ValidationViewReason, ...
                "stableHeldOutView");
            testCase.verifyFalse(ismember(first.ValidationViewId, ...
                first.Diagnostics.SelectedViewIds));
            testCase.verifyEqual(first.ValidationCandidates.ViewIds(2), ...
                first.ValidationViewId);
        end

        function testWeakCandidateHasSpecificRejectionReason(testCase)
            [scene, evidence] = ProjectionDenseSearchPlanningTest.scheduleFixture();
            evidence(2).TextureScore = 0;
            id = ProjectionDenseSearchPlanningTest.pairIds(scene, evidence);

            schedule = ProjectionDensePairScheduler.build(scene, evidence, ...
                struct(ReserveValidationView=false, MaximumPairs=Inf));
            weak = schedule.Candidates( ...
                string({schedule.Candidates.PairId}) == id(2));

            testCase.verifyEqual(weak.Decision, "rejected");
            testCase.verifyEqual(weak.SelectionReason, ...
                "insufficientTexture");
        end
    end

    methods (Static, Access = private)
        function request = request()
            [columns, rows] = meshgrid(1:64, 1:64);
            request = ProjectionDenseMatchRequest.validate(struct( ...
                PairId="pair:dense-search", ViewIds=["view-a" "view-b"], ...
                AnalysisImages={{double(rows), double(columns)}}, ...
                ValidityMasks={{true(64), true(64)}}, ...
                SourceRows={{double(rows), double(rows)}}, ...
                SourceColumns={{double(columns), double(columns)}}));
        end

        function evidence = sparseEvidence()
            evidence = struct( ...
                MovingPoints=[8 8; 24 20; 42 44; 56 58], ...
                ReferencePoints=[4 7; 20 19; 34 44; 48 58], ...
                TrackIds=["track-a" "track-b" "track-c" "track-d"], ...
                DepthMeters=[50 70 80 100], ...
                UncertaintyPixels=[0.5 1 2 3]);
        end

        function [scene, evidence] = scheduleFixture()
            images = repmat({zeros(8)}, 1, 5);
            names = "view-" + string(1:5) + ".tif";
            scene = ProjectionViewerHarness.createSceneFromImages( ...
                images, names, struct(RowStride=1, ColumnStride=1));
            pairs = [1 2; 2 3; 3 4; 4 5; 1 3; 2 4];
            scores = [0.95 0.9 0.85 0.8 0.75 0.7];
            evidence = repmat(struct(Pair=zeros(1, 2), ...
                OverlapFraction=0, ConditioningScore=0, TextureScore=0, ...
                RadiometricCompatibility=0, VisibilityScore=0, ...
                PredictedCost=0, PredictedMemoryBytes=0), 1, size(pairs, 1));
            for index = 1:size(pairs, 1)
                evidence(index) = struct(Pair=pairs(index, :), ...
                    OverlapFraction=scores(index), ...
                    ConditioningScore=scores(index), ...
                    TextureScore=scores(index), ...
                    RadiometricCompatibility=scores(index), ...
                    VisibilityScore=scores(index), ...
                    PredictedCost=10 * index, ...
                    PredictedMemoryBytes=1000 * index);
            end
        end

        function ids = pairIds(scene, evidence)
            viewIds = string({scene.layers.ViewId});
            ids = strings(1, numel(evidence));
            for index = 1:numel(evidence)
                pair = evidence(index).Pair;
                identity = ProjectionViewMetadata.pairIdentity( ...
                    viewIds(pair(1)), viewIds(pair(2)));
                ids(index) = identity.PairId;
            end
        end
    end
end
