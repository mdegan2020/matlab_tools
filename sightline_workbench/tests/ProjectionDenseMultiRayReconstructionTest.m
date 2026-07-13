classdef ProjectionDenseMultiRayReconstructionTest < matlab.unittest.TestCase
    %ProjectionDenseMultiRayReconstructionTest B5 association/fusion tests.

    methods (TestClassSetup)
        function addSourcePath(testCase)
            root = fileparts(fileparts(mfilename("fullpath")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(root, "src")));
        end
    end

    methods (Test)
        function testThreeViewExactSolveReportsCompleteProvenance(testCase)
            request = ProjectionDenseMultiRayReconstructionTest. ...
                threeViewRequest(false);

            association = ProjectionDenseObservationAssociator.associate(request);
            result = ProjectionMultiRayReconstructor.reconstruct(association);
            point = result.Points;

            testCase.verifyEqual(result.Stage, "robustMultiView");
            testCase.verifyEqual(result.AuthoritativeProduct, ...
                "provenanceRichPointSet");
            testCase.verifyEqual(point.PointWorld, [0; 0; 10], AbsTol=1e-10);
            testCase.verifyEqual(point.State, "multiViewSolved");
            testCase.verifyEqual(point.IndependentViewCount, 3);
            testCase.verifyEqual(point.IndependentPassCount, 2);
            testCase.verifyEqual(point.PairRecordCount, 3);
            testCase.verifyNumElements(point.ContributingPairIds, 3);
            testCase.verifyTrue(all([point.RayDiagnostics.ForwardValid]));
            testCase.verifyTrue(all([point.RayDiagnostics.Accepted]));
            testCase.verifyTrue(all(arrayfun(@(ray) ...
                isequal(size(ray.RayOriginWorld), [3 1]) && ...
                isequal(size(ray.RayVectorWorld), [3 1]), ...
                point.RayDiagnostics)));
            testCase.verifyNumElements(point.ObservationKeys, 3);
            testCase.verifyEqual(point.VisibilityState, "consistentVisible");
            testCase.verifyEqual(point.RadiometricStatus, "pairConsistency");
            testCase.verifyEqual(point.PairwiseInitialOracleLabel, ...
                "pairwisePointMedianNotAuthoritative");
            testCase.verifyEqual(result.Provenance.PairwiseStage, "rawPairwise");
            testCase.verifyEqual(result.Provenance.AuthoritativeStage, ...
                "robustMultiView");
        end

        function testRobustSolveRejectsOneCorruptRay(testCase)
            request = ProjectionDenseMultiRayReconstructionTest. ...
                corruptFourViewRequest();

            association = ProjectionDenseObservationAssociator.associate(request);
            result = ProjectionMultiRayReconstructor.reconstruct(association, ...
                struct(HuberScaleMeters=0.1, MaximumResidualMeters=0.5));
            point = result.Points;
            rejected = point.RayDiagnostics(~[point.RayDiagnostics.Accepted]);

            testCase.verifyEqual(point.PointWorld, [0; 0; 10], AbsTol=1e-8);
            testCase.verifyEqual(point.State, "multiViewSolved");
            testCase.verifyEqual(point.IndependentViewCount, 3);
            testCase.verifyEqual(rejected.ViewId, "view-d");
            testCase.verifyEqual(rejected.RejectionReason, "robustResidual");
            testCase.verifyGreaterThan(rejected.ResidualMeters, 0.5);
            testCase.verifyEqual(point.RejectedViewIds, "view-d");
            testCase.verifyEqual(point.RejectedPairIds, "pair:a-d");
        end

        function testDuplicatePairDoesNotIncreaseIndependentEvidence(testCase)
            baselineRequest = ProjectionDenseMultiRayReconstructionTest. ...
                threeViewRequest(false);
            duplicateRequest = ProjectionDenseMultiRayReconstructionTest. ...
                threeViewRequest(true);

            baselineAssociation = ...
                ProjectionDenseObservationAssociator.associate(baselineRequest);
            duplicateAssociation = ...
                ProjectionDenseObservationAssociator.associate(duplicateRequest);
            baseline = ProjectionMultiRayReconstructor.reconstruct( ...
                baselineAssociation);
            duplicate = ProjectionMultiRayReconstructor.reconstruct( ...
                duplicateAssociation);

            testCase.verifyEqual(duplicate.Points.IndependentViewCount, 3);
            testCase.verifyEqual(duplicate.Points.IndependentPassCount, 2);
            testCase.verifyEqual(duplicate.Points.PairRecordCount, 4);
            testCase.verifyNumElements(duplicate.Points.ContributingPairIds, 3);
            testCase.verifyEqual(duplicate.Points.PointWorld, ...
                baseline.Points.PointWorld, AbsTol=1e-12);
            testCase.verifyEqual( ...
                duplicate.Points.CovarianceWorldMetersSquared, ...
                baseline.Points.CovarianceWorldMetersSquared, AbsTol=1e-14);
        end

        function testPassWeightsRepresentIndependentPassEvidence(testCase)
            request = ProjectionDenseMultiRayReconstructionTest. ...
                threeViewRequest(false);

            association = ProjectionDenseObservationAssociator.associate(request);
            result = ProjectionMultiRayReconstructor.reconstruct(association);
            rays = result.Points.RayDiagnostics;
            passIds = string({rays.PassId});
            weights = [rays.BaseEvidenceWeight];

            testCase.verifyEqual(sum(weights(passIds == "pass-1")), ...
                sum(weights(passIds == "pass-2")), AbsTol=1e-14);
            testCase.verifyEqual(result.Provenance.EvidenceWeightPolicy, ...
                "oneRayPerStableObservation;equalTotalWeightPerPass");
        end

        function testValidTwoViewTrackIsRetainedAndLabeled(testCase)
            request = ProjectionDenseMultiRayReconstructionTest.twoViewRequest();

            association = ProjectionDenseObservationAssociator.associate(request);
            result = ProjectionMultiRayReconstructor.reconstruct(association);
            point = result.Points;

            testCase.verifyTrue(point.Valid);
            testCase.verifyEqual(point.State, "twoViewRetained");
            testCase.verifyEqual(point.IndependentViewCount, 2);
            testCase.verifyEqual(point.PointWorld, [0; 0; 10], AbsTol=1e-10);
        end

        function testCompetingDepthModesAreSplitBeforeSolving(testCase)
            request = ProjectionDenseMultiRayReconstructionTest. ...
                competingModeRequest();

            association = ProjectionDenseObservationAssociator.associate( ...
                request, struct(ModeSeparationMeters=2));
            result = ProjectionMultiRayReconstructor.reconstruct(association);
            heights = sort(arrayfun(@(point) point.PointWorld(3), result.Points));

            testCase.verifyEqual(association.Diagnostics.TrackCount, 2);
            testCase.verifyEqual( ...
                association.Diagnostics.CompetingModeTrackCount, 2);
            testCase.verifyTrue(all([association.Tracks.CompetingMode]));
            testCase.verifyTrue(all([result.Points.CompetingMode]));
            testCase.verifyEqual(heights, [10 20], AbsTol=1e-10);
            testCase.verifyEqual(result.Diagnostics.TwoViewRetainedCount, 2);
        end

        function testPairQualityAndForwardGatesReportReasons(testCase)
            request = ProjectionDenseMultiRayReconstructionTest. ...
                gatedRecordsRequest();

            association = ProjectionDenseObservationAssociator.associate(request);
            reasons = sort(string( ...
                {association.RawPairwiseRecords.AssociationReason}));

            testCase.verifyEqual(reasons, sort([ ...
                "insufficientTexture" "nearlyParallel" ...
                "pairForwardInvalid" "radiometricInconsistent" ...
                "visibilityConflict" "weakNavigation"]));
            testCase.verifyEqual(association.Diagnostics.TrackCount, 0);
            testCase.verifyEqual( ...
                association.Diagnostics.RejectedPairRecordCount, 6);
        end

        function testInconsistentStableObservationIdentityFailsClosed(testCase)
            request = ProjectionDenseMultiRayReconstructionTest. ...
                identityConflictRequest();

            association = ProjectionDenseObservationAssociator.associate(request);

            testCase.verifyEqual(association.Diagnostics.TrackCount, 0);
            testCase.verifyTrue(all(string( ...
                {association.RawPairwiseRecords.AssociationReason}) == ...
                "observationIdentityConflict"));
            testCase.verifyEqual( ...
                association.Diagnostics.ConsistentObservationCount, 2);
        end

        function testDuplicateViewConflictRejectsLowerQualityEdge(testCase)
            request = ProjectionDenseMultiRayReconstructionTest. ...
                duplicateViewConflictRequest();

            association = ProjectionDenseObservationAssociator.associate(request);
            reasons = string( ...
                {association.RawPairwiseRecords.AssociationReason});

            testCase.verifyEqual(association.Diagnostics.TrackCount, 1);
            testCase.verifyEqual(association.Diagnostics.AcceptedPairRecordCount, 2);
            testCase.verifyEqual(association.Diagnostics.DuplicateViewConflictCount, 1);
            testCase.verifyEqual(nnz(reasons == "duplicateViewConflict"), 1);
            testCase.verifyEqual(association.Tracks.ViewCount, 3);
            testCase.verifyEqual(numel(unique(association.Tracks.ViewIds)), 3);
        end

        function testAssociationAndPointIdentityAreOrderIndependent(testCase)
            firstRequest = ProjectionDenseMultiRayReconstructionTest. ...
                threeViewRequest(false);
            secondRequest = firstRequest;
            secondRequest.Records = secondRequest.Records([3 1 2]);

            firstAssociation = ...
                ProjectionDenseObservationAssociator.associate(firstRequest);
            secondAssociation = ...
                ProjectionDenseObservationAssociator.associate(secondRequest);
            firstResult = ProjectionMultiRayReconstructor.reconstruct( ...
                firstAssociation);
            secondResult = ProjectionMultiRayReconstructor.reconstruct( ...
                secondAssociation);

            testCase.verifyEqual(secondAssociation.GenerationId, ...
                firstAssociation.GenerationId);
            testCase.verifyEqual(secondAssociation.Tracks.TrackId, ...
                firstAssociation.Tracks.TrackId);
            testCase.verifyEqual(secondResult.GenerationId, ...
                firstResult.GenerationId);
            testCase.verifyEqual(secondResult.Points.PointId, ...
                firstResult.Points.PointId);
        end

        function testCovarianceIsExplicitSymmetricPsdAssumption(testCase)
            request = ProjectionDenseMultiRayReconstructionTest. ...
                threeViewRequest(false);

            association = ProjectionDenseObservationAssociator.associate(request);
            result = ProjectionMultiRayReconstructor.reconstruct(association);
            point = result.Points;

            testCase.verifyEqual(point.CovarianceStatus, "assumed");
            testCase.verifyEqual(point.CovarianceReason, ...
                "independentRayResidualFloorModel");
            testCase.verifyEqual(point.CovarianceFrame, "sceneWorld");
            testCase.verifyEqual(point.CovarianceWorldMetersSquared, ...
                point.CovarianceWorldMetersSquared.', AbsTol=1e-14);
            testCase.verifyGreaterThanOrEqual( ...
                eig(point.CovarianceWorldMetersSquared), -1e-12);
            testCase.verifyGreaterThan(point.PrincipalAxisSigmasMeters, 0);
        end

        function testMatAndCompactJsonPersistence(testCase)
            request = ProjectionDenseMultiRayReconstructionTest. ...
                threeViewRequest(false);
            folder = string(tempname);
            mkdir(folder);
            testCase.addTeardown(@() rmdir(folder, "s"));
            matPath = fullfile(folder, "point-set.mat");
            jsonPath = fullfile(folder, "point-set.json");

            association = ProjectionDenseObservationAssociator.associate(request);
            result = ProjectionMultiRayReconstructor.reconstruct(association);
            paths = ProjectionMultiRayReconstructor.write( ...
                result, matPath, jsonPath);
            payload = load(paths.MatPath, "pointSet");
            metadata = jsondecode(fileread(paths.MetadataPath));

            testCase.verifyEqual(payload.pointSet.GenerationId, ...
                result.GenerationId);
            testCase.verifyEqual(string(metadata.GenerationId), ...
                result.GenerationId);
            testCase.verifyEqual(metadata.Diagnostics.ValidPointCount, 1);
            testCase.verifyTrue(isfield(metadata, "PointSummaries"));
            testCase.verifyFalse(isfield(metadata, "RawPairwiseRecords"));
        end

        function testStrictSchemaAndOptionsFailClosed(testCase)
            request = ProjectionDenseMultiRayReconstructionTest.twoViewRequest();
            futureRequest = request;
            futureRequest.Version = 2;
            association = ProjectionDenseObservationAssociator.associate(request);
            futureAssociation = association;
            futureAssociation.Version = 2;

            testCase.verifyError(@() ...
                ProjectionDenseObservationAssociator.associate(futureRequest), ...
                "ProjectionDenseObservationAssociator:unsupportedSchema");
            testCase.verifyError(@() ...
                ProjectionDenseObservationAssociator.associate( ...
                request, struct(Unknown=true)), ...
                "ProjectionDenseObservationAssociator:invalidOptions");
            testCase.verifyError(@() ...
                ProjectionMultiRayReconstructor.reconstruct(futureAssociation), ...
                "ProjectionMultiRayReconstructor:unsupportedAssociation");
        end
    end

    methods (Static, Access = private)
        function request = threeViewRequest(includeDuplicate)
            point = [0; 0; 10];
            viewIds = ["view-a" "view-b" "view-c"];
            passIds = ["pass-1" "pass-1" "pass-2"];
            observationIds = ["obs-a" "obs-b" "obs-c"];
            source = [10 20; 30 40; 50 60];
            origins = [-2 2 0; 0 0 -2; 0 0 0];
            pairs = [1 2; 1 3; 2 3];
            records = ProjectionDenseMultiRayReconstructionTest.records( ...
                pairs, point, viewIds, passIds, observationIds, source, ...
                origins, repmat(point, 1, 3));
            if includeDuplicate
                duplicate = records(1);
                duplicate.RecordId = "record-duplicate-a-b";
                records(end + 1) = duplicate;
            end
            request = ProjectionDenseMultiRayReconstructionTest.request(records);
        end

        function request = twoViewRequest()
            point = [0; 0; 10];
            viewIds = ["view-a" "view-b"];
            passIds = ["pass-1" "pass-2"];
            observationIds = ["obs-a" "obs-b"];
            source = [10 20; 30 40];
            origins = [-1 1; 0 0; 0 0];
            records = ProjectionDenseMultiRayReconstructionTest.records( ...
                [1 2], point, viewIds, passIds, observationIds, source, ...
                origins, repmat(point, 1, 2));
            request = ProjectionDenseMultiRayReconstructionTest.request(records);
        end

        function request = corruptFourViewRequest()
            point = [0; 0; 10];
            viewIds = ["view-a" "view-b" "view-c" "view-d"];
            passIds = ["pass-1" "pass-1" "pass-2" "pass-3"];
            observationIds = ["obs-a" "obs-b" "obs-c" "obs-d"];
            source = [10 20; 30 40; 50 60; 70 80];
            origins = [-2 2 0 0; 0 0 -2 2; 0 0 0 0];
            targets = repmat(point, 1, 4);
            targets(:, 4) = [2; 0; 20];
            records = ProjectionDenseMultiRayReconstructionTest.records( ...
                [1 2; 1 3; 1 4], point, viewIds, passIds, ...
                observationIds, source, origins, targets);
            records(3).ProvisionalPointWorld = [];
            request = ProjectionDenseMultiRayReconstructionTest.request(records);
        end

        function request = competingModeRequest()
            nearPoint = [0; 0; 10];
            farPoint = [0; 0; 20];
            first = ProjectionDenseMultiRayReconstructionTest.record( ...
                "record-near", "pair:a-b-near", ...
                ["view-a" "view-b"], ["pass-1" "pass-2"], ...
                ["obs-a" "obs-b-near"], [10 20; 30 40], ...
                [0 -1; 0 0; 0 0], [nearPoint nearPoint]);
            second = ProjectionDenseMultiRayReconstructionTest.record( ...
                "record-far", "pair:a-b-far", ...
                ["view-a" "view-b"], ["pass-1" "pass-2"], ...
                ["obs-a" "obs-b-far"], [10 20; 31 41], ...
                [0 -1; 0 0; 0 0], [farPoint farPoint]);
            request = ProjectionDenseMultiRayReconstructionTest.request( ...
                [first second]);
        end

        function request = gatedRecordsRequest()
            point = [0; 0; 10];
            records = repmat(ProjectionDenseMultiRayReconstructionTest.record( ...
                "", "", ["a" "b"], ["p1" "p2"], ["oa" "ob"], ...
                [1 1; 2 2], [-1 1; 0 0; 0 0], [point point]), 1, 6);
            for index = 1:6
                records(index).RecordId = "gate-record-" + index;
                records(index).PairId = "gate-pair-" + index;
                records(index).ViewIds = ["view-" + (2 * index - 1) ...
                    "view-" + (2 * index)];
                records(index).PassIds = ["pass-" + (2 * index - 1) ...
                    "pass-" + (2 * index)];
                records(index).ObservationIds = ["obs-" + (2 * index - 1) ...
                    "obs-" + (2 * index)];
            end
            narrowPoint = [0; 0; 10];
            records(1).RayOriginsWorld = [-0.0005 0.0005; 0 0; 0 0];
            records(1).RayVectorsWorld = ...
                narrowPoint - records(1).RayOriginsWorld;
            records(1).ProvisionalPointWorld = [];
            records(2).TextureScore = 0;
            records(3).NavigationWeights = [0 1];
            records(4).RadiometricConsistency = 0;
            records(5).VisibilityStates = ["visible" "occluded"];
            records(6).RayVectorsWorld = -records(6).RayVectorsWorld;
            records(6).ProvisionalPointWorld = [];
            request = ProjectionDenseMultiRayReconstructionTest.request(records);
        end

        function request = identityConflictRequest()
            point = [0; 0; 10];
            first = ProjectionDenseMultiRayReconstructionTest.record( ...
                "record-a-b", "pair:a-b", ["view-a" "view-b"], ...
                ["pass-1" "pass-2"], ["obs-a" "obs-b"], ...
                [10 20; 30 40], [-1 1; 0 0; 0 0], [point point]);
            second = ProjectionDenseMultiRayReconstructionTest.record( ...
                "record-a-c", "pair:a-c", ["view-a" "view-c"], ...
                ["pass-1" "pass-3"], ["obs-a" "obs-c"], ...
                [20 30; 50 60], [-1 0; 0 -1; 0 0], [point point]);
            request = ProjectionDenseMultiRayReconstructionTest.request( ...
                [first second]);
        end

        function request = duplicateViewConflictRequest()
            point = [0; 0; 10];
            first = ProjectionDenseMultiRayReconstructionTest.record( ...
                "record-1", "pair:a-b", ["view-a" "view-b"], ...
                ["pass-1" "pass-2"], ["obs-a-1" "obs-b"], ...
                [10 20; 30 40], [-1 1; 0 0; 0 0], [point point]);
            second = ProjectionDenseMultiRayReconstructionTest.record( ...
                "record-2", "pair:b-c", ["view-b" "view-c"], ...
                ["pass-2" "pass-3"], ["obs-b" "obs-c"], ...
                [30 40; 50 60], [1 0; 0 -1; 0 0], [point point]);
            third = ProjectionDenseMultiRayReconstructionTest.record( ...
                "record-3", "pair:a-c", ["view-a" "view-c"], ...
                ["pass-1" "pass-3"], ["obs-a-2" "obs-c"], ...
                [11 21; 50 60], [-1 0; 0 -1; 0 0], [point point]);
            third.Confidence = 0.1;
            request = ProjectionDenseMultiRayReconstructionTest.request( ...
                [first second third]);
        end

        function records = records(pairs, provisionalPoint, viewIds, ...
                passIds, observationIds, source, origins, targets)
            records = repmat(ProjectionDenseMultiRayReconstructionTest.record( ...
                "", "", strings(1, 2), strings(1, 2), strings(1, 2), ...
                zeros(2), zeros(3, 2), ones(3, 2)), 1, size(pairs, 1));
            for index = 1:size(pairs, 1)
                pair = pairs(index, :);
                records(index) = ProjectionDenseMultiRayReconstructionTest.record( ...
                    "record-" + viewIds(pair(1)) + "-" + viewIds(pair(2)), ...
                    "pair:" + extractAfter(viewIds(pair(1)), "view-") + ...
                    "-" + extractAfter(viewIds(pair(2)), "view-"), ...
                    viewIds(pair), passIds(pair), observationIds(pair), ...
                    source(pair, :), origins(:, pair), targets(:, pair));
                records(index).ProvisionalPointWorld = provisionalPoint;
            end
        end

        function value = record(recordId, pairId, viewIds, passIds, ...
                observationIds, source, origins, targets)
            value = struct(RecordId=recordId, PairId=pairId, ...
                ViewIds=viewIds, PassIds=passIds, ...
                ObservationIds=observationIds, ...
                SourceObservationsPixels=source, RayOriginsWorld=origins, ...
                RayVectorsWorld=targets - origins, MatchState="valid", ...
                Score=0.9, Confidence=0.9, TextureScore=0.9, ...
                NavigationWeights=[0.9 0.9], ...
                RadiometricValues=[0.4 0.42], ...
                RadiometricConsistency=0.95, ...
                VisibilityStates=["visible" "visible"], ...
                ProvisionalPointWorld=[], ...
                PairwiseCovarianceWorldMetersSquared=1e-4 * eye(3), ...
                ModeId="");
        end

        function value = request(records)
            value = struct( ...
                Format="ProjectionDensePairObservationRecords", Version=1, ...
                WorldFrame="sceneWorld", Records=records);
        end
    end
end
