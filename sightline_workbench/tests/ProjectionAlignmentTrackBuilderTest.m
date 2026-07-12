classdef ProjectionAlignmentTrackBuilderTest < matlab.unittest.TestCase
    %ProjectionAlignmentTrackBuilderTest Tests conflict-safe feature tracks.

    methods (TestClassSetup)
        function addSourceToPath(testCase)
            projectRoot = fileparts(fileparts(mfilename("fullpath")));
            srcFolder = fullfile(projectRoot, "src");
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(srcFolder));
        end
    end

    methods (Test)
        function testConsistentTriangleBuildsSingleTrackAndCycleEvidence(testCase)
            matchResult = ProjectionAlignmentTrackBuilderTest.triangleResult();

            result = ProjectionAlignmentTrackBuilder.build(matchResult);

            testCase.verifyEqual(result.Format, "ProjectionAlignmentTracks");
            testCase.verifyNumElements(result.Tracks, 1);
            testCase.verifyEqual(result.Tracks.ViewCount, 3);
            testCase.verifyEqual(result.Tracks.ViewIds, ["view-a" "view-b" "view-c"]);
            testCase.verifyEqual(result.Diagnostics.AcceptedEdgeCount, 3);
            testCase.verifyEqual(result.Diagnostics.RejectedEdgeCount, 0);
            testCase.verifyEqual(result.Diagnostics.ConsistentPathCount, 3);
            testCase.verifyTrue(all([result.PathDiagnostics.Consistent]));
        end

        function testAmbiguousTransitiveMergeRejectsDuplicateView(testCase)
            pairs(1) = ProjectionAlignmentTrackBuilderTest.makePair( ...
                "view-a", [10 10], "view-b", [20 20], 0.1, [0 0], [0 0]);
            pairs(2) = ProjectionAlignmentTrackBuilderTest.makePair( ...
                "view-b", [20 20], "view-c", [30 30], 0.2, [0 0], [0 0]);
            pairs(3) = ProjectionAlignmentTrackBuilderTest.makePair( ...
                "view-a", [50 50], "view-c", [30 30], 0.9, [0 0], [0 0]);

            result = ProjectionAlignmentTrackBuilder.build( ...
                struct(Matches=pairs));

            rejectionReasons = string({result.Edges.RejectionReason});
            conflictEdge = result.Edges(rejectionReasons == "duplicateViewConflict");
            testCase.verifyNumElements(conflictEdge, 1);
            testCase.verifyFalse(conflictEdge.Accepted);
            testCase.verifyEqual(result.Diagnostics.ConflictCount, 1);
            testCase.verifyNumElements(result.Tracks, 1);
            testCase.verifyEqual(result.Tracks.ViewCount, 3);
            testCase.verifyEqual(numel(unique(result.Tracks.ViewIds)), 3);
            inconsistent = result.PathDiagnostics( ...
                string({result.PathDiagnostics.State}) == "inconsistent");
            testCase.verifyNumElements(inconsistent, 1);
            testCase.verifyGreaterThan(inconsistent.EndDisagreementPixels, 50);
            testCase.verifyFalse(inconsistent.DirectEdgeAccepted);
        end

        function testDescriptorAndGeometryGatesHaveExplicitReasons(testCase)
            pairs(1) = ProjectionAlignmentTrackBuilderTest.makePair( ...
                "view-a", [10 10], "view-b", [20 20], 0.8, [0 0], [0 0]);
            pairs(2) = ProjectionAlignmentTrackBuilderTest.makePair( ...
                "view-c", [30 30], "view-d", [40 40], 0.1, [0 0], [3 4]);
            options = struct(MaximumDescriptorMetric=0.5, ...
                MaximumPlaneDisagreementMeters=2);

            result = ProjectionAlignmentTrackBuilder.build( ...
                struct(Matches=pairs), options);

            testCase.verifyEqual(sort(string({result.Edges.RejectionReason})), ...
                ["descriptorInconsistent" "geometryInconsistent"]);
            testCase.verifyEqual(result.Diagnostics.AcceptedEdgeCount, 0);
            testCase.verifyEmpty(result.Tracks);
        end

        function testTrackIdentityIsStableAcrossPairOrdering(testCase)
            matchResult = ProjectionAlignmentTrackBuilderTest.triangleResult();
            first = ProjectionAlignmentTrackBuilder.build(matchResult);
            matchResult.Matches = matchResult.Matches([3 1 2]);

            second = ProjectionAlignmentTrackBuilder.build(matchResult);

            testCase.verifyEqual(second.GenerationId, first.GenerationId);
            testCase.verifyEqual(string({second.Tracks.TrackId}), ...
                string({first.Tracks.TrackId}));
            testCase.verifyEqual(string({second.Edges.RecordId}), ...
                string({first.Edges.RecordId}));
        end

        function testFilterPublishesTracksAndTrackDiagnostics(testCase)
            matchResult = ProjectionAlignmentTrackBuilderTest.triangleResult();

            filtered = ProjectionAlignmentMatchFilter.filter(matchResult);

            testCase.verifyTrue(isfield(filtered, "Tracks"));
            testCase.verifyEqual(filtered.Tracks.Diagnostics.TrackCount, 1);
            testCase.verifyEqual(filtered.Diagnostics.Tracks, ...
                filtered.Tracks.Diagnostics);
            testCase.verifyEqual(filtered.Tracks.Diagnostics.InputRecordCount, 3);
        end
    end

    methods (Static, Access = private)
        function matchResult = triangleResult()
            pairs(1) = ProjectionAlignmentTrackBuilderTest.makePair( ...
                "view-a", [10 10], "view-b", [20 20], 0.1, [0 0], [0 0]);
            pairs(2) = ProjectionAlignmentTrackBuilderTest.makePair( ...
                "view-b", [20 20], "view-c", [30 30], 0.2, [0 0], [0 0]);
            pairs(3) = ProjectionAlignmentTrackBuilderTest.makePair( ...
                "view-a", [10 10], "view-c", [30 30], 0.3, [0 0], [0 0]);
            matchResult = struct(Matches=pairs, Diagnostics=struct());
        end

        function pair = makePair(firstViewId, firstCoordinate, ...
                secondViewId, secondCoordinate, metric, firstPlane, secondPlane)
            pair = struct();
            pair.Pair = [1 2];
            pair.PairLayerIds = [firstViewId secondViewId];
            pair.MovingLayerId = firstViewId;
            pair.ReferenceLayerId = secondViewId;
            pair.PairDirection = "movingToReference";
            pair.Detector = "sift";
            pair.Matcher = "nearestNeighborRatio";
            pair.MovingFeatureLocations = fliplr(firstCoordinate);
            pair.ReferenceFeatureLocations = fliplr(secondCoordinate);
            pair.MovingPlaneCoordinates = firstPlane;
            pair.ReferencePlaneCoordinates = secondPlane;
            pair.MovingSourceRows = firstCoordinate(1);
            pair.MovingSourceColumns = firstCoordinate(2);
            pair.ReferenceSourceRows = secondCoordinate(1);
            pair.ReferenceSourceColumns = secondCoordinate(2);
            pair.IndexPairs = [1 1];
            pair.MatchMetric = metric;
            pair.Scores = 1 - min(metric, 1);
            pair.FeatureCounts = [1 1];
            pair.Count = 1;
            pair.OverlapMask = true(64, 64);
        end
    end
end
