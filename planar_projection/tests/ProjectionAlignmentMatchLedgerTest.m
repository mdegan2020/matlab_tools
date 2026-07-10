classdef ProjectionAlignmentMatchLedgerTest < matlab.unittest.TestCase
    %ProjectionAlignmentMatchLedgerTest Tests raw match provenance and units.

    properties (Constant)
        Tol = 1e-12
    end

    methods (TestClassSetup)
        function addSourceToPath(testCase)
            projectRoot = fileparts(fileparts(mfilename("fullpath")));
            srcFolder = fullfile(projectRoot, "src");
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(srcFolder));
        end
    end

    methods (Test)
        function testFilteringPreservesEveryRawRecordAndStageReason(testCase)
            matchResult = ProjectionAlignmentMatchLedgerTest.makeMatchResult();
            options = struct(FilterPipeline=struct( ...
                Stages=["overlapMask", "descriptorScore"], ...
                MinMatchScore=0.5));

            filtered = ProjectionAlignmentMatchFilter.filter(matchResult, options);
            records = filtered.Matches.MatchLedger;
            stageMasks = [records.StageMasks];

            testCase.verifyEqual(filtered.Matches.Count, 2);
            testCase.verifyEqual(filtered.Matches.MatchRecordIndices, [1; 4]);
            testCase.verifyNumElements(records, 4);
            testCase.verifyEqual([records.RawMatchIndex], 1:4);
            testCase.verifyEqual([stageMasks.OverlapMask], ...
                [true false true true]);
            testCase.verifyEqual([stageMasks.DescriptorScore], ...
                [true false false true]);
            testCase.verifyEqual(records(2).FirstRejectedStage, "overlapMask");
            testCase.verifyEqual(records(3).FirstRejectedStage, "descriptorScore");
            testCase.verifyEqual(records(2).RejectionReasons, "overlapMask");
            testCase.verifyEqual(records(3).RejectionReasons, "descriptorScore");
            testCase.verifyEqual([records.Accepted], [true false false true]);
            testCase.verifyNumElements(filtered.MatchLedger, 4);
        end

        function testLedgerUsesStableIdentityAndExplicitCoordinateUnits(testCase)
            matchResult = ProjectionAlignmentMatchLedgerTest.makeMatchResult();

            pairMatch = ProjectionAlignmentMatchLedger.ensurePair( ...
                matchResult.Matches);
            record = pairMatch.MatchLedger(1);

            testCase.verifyEqual(record.PairLayerIds, ["moving-id", "reference-id"]);
            testCase.verifyEqual(record.PairDirection, "movingToReference");
            testCase.verifyEqual(record.MovingWorkingPixel, [2 2], ...
                AbsTol=ProjectionAlignmentMatchLedgerTest.Tol);
            testCase.verifyEqual(record.MovingPlaneMeters, [20 20], ...
                AbsTol=ProjectionAlignmentMatchLedgerTest.Tol);
            testCase.verifyEqual(record.MovingSourceRowPixels, 200, ...
                AbsTol=ProjectionAlignmentMatchLedgerTest.Tol);
            testCase.verifyEqual(record.Residuals.NativeDisplacementPixels, ...
                hypot(10, 10), AbsTol=ProjectionAlignmentMatchLedgerTest.Tol);
        end

        function testSolverResidualsUpdateSelectedRawRecordsOnly(testCase)
            matchResult = ProjectionAlignmentMatchLedgerTest.makeMatchResult();
            pairMatch = ProjectionAlignmentMatchLedger.ensurePair( ...
                matchResult.Matches);

            records = ProjectionAlignmentMatchLedger.markSolverResiduals( ...
                pairMatch.MatchLedger, [1 4], [2 3], [0.5 0.75], ...
                "projectionPlane2D", "planeMeters");
            stageMasks = [records.StageMasks];

            testCase.verifyEqual([stageMasks.SolverObservation], ...
                [true false false true]);
            testCase.verifyEqual(records(1).Residuals.ActiveResidualUnit, ...
                "planeMeters");
            testCase.verifyEqual( ...
                records(4).Residuals.ProjectionPlaneBeforeMeters, 3, ...
                AbsTol=ProjectionAlignmentMatchLedgerTest.Tol);
            testCase.verifyEqual( ...
                records(4).Residuals.ProjectionPlaneAfterMeters, 0.75, ...
                AbsTol=ProjectionAlignmentMatchLedgerTest.Tol);
        end

        function testResidualUnitMismatchErrors(testCase)
            matchResult = ProjectionAlignmentMatchLedgerTest.makeMatchResult();
            pairMatch = ProjectionAlignmentMatchLedger.ensurePair( ...
                matchResult.Matches);

            testCase.verifyError(@() ...
                ProjectionAlignmentMatchLedger.markSolverResiduals( ...
                pairMatch.MatchLedger, 1, 2, 1, ...
                "projectionPlane2D", "rayMeters"), ...
                "ProjectionAlignmentMatchLedger:invalidChoice");
        end
    end

    methods (Static, Access = private)
        function matchResult = makeMatchResult()
            movingLocations = [2 2; 7 7; 3 3; 4 4];
            referenceLocations = movingLocations + 0.1;
            pairMatch = struct();
            pairMatch.Pair = [2 1];
            pairMatch.PairLayerIds = ["moving-id", "reference-id"];
            pairMatch.MovingLayerId = "moving-id";
            pairMatch.ReferenceLayerId = "reference-id";
            pairMatch.PairDirection = "movingToReference";
            pairMatch.Detector = "sift";
            pairMatch.Matcher = "exhaustive";
            pairMatch.MovingFeatureLocations = movingLocations;
            pairMatch.ReferenceFeatureLocations = referenceLocations;
            pairMatch.MovingPlaneCoordinates = 10 * movingLocations;
            pairMatch.ReferencePlaneCoordinates = 10 * referenceLocations;
            pairMatch.MovingSourceRows = 100 * movingLocations(:, 2);
            pairMatch.MovingSourceColumns = 100 * movingLocations(:, 1);
            pairMatch.ReferenceSourceRows = pairMatch.MovingSourceRows + 10;
            pairMatch.ReferenceSourceColumns = pairMatch.MovingSourceColumns + 10;
            pairMatch.IndexPairs = [(1:4).' (1:4).'];
            pairMatch.MatchMetric = [0.1; 0.2; 0.3; 0.4];
            pairMatch.Scores = [0.9; 0.9; 0.2; 0.8];
            pairMatch.FeatureCounts = [4 4];
            pairMatch.Count = 4;
            pairMatch.OverlapMask = false(8, 8);
            pairMatch.OverlapMask(1:5, 1:5) = true;
            matchResult = struct(Matches=pairMatch, Diagnostics=struct());
        end
    end
end
