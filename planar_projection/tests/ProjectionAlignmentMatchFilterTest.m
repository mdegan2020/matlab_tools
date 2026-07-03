classdef ProjectionAlignmentMatchFilterTest < matlab.unittest.TestCase
    %ProjectionAlignmentMatchFilterTest Tests match-filter pipeline stages.

    methods (TestClassSetup)
        function addSourceToPath(testCase)
            projectRoot = fileparts(fileparts(mfilename("fullpath")));
            srcFolder = fullfile(projectRoot, "src");
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(srcFolder));
        end
    end

    methods (Test)
        function testFilterOrderingAndDiagnostics(testCase)
            matchResult = ProjectionAlignmentMatchFilterTest.makeMatchResult();
            options = struct();
            options.FilterPipeline = struct( ...
                Stages=["overlapMask", "descriptorScore", "geometricOutlier"], ...
                MinMatchScore=0.5, ...
                GeometricMethod="ransac", ...
                GeometricMaxDistancePixels=1);

            filtered = ProjectionAlignmentMatchFilter.filter(matchResult, options);
            diagnostics = filtered.Diagnostics.FilterPipeline;

            testCase.verifyEqual(filtered.Format, ProjectionAlignmentMatchFilter.Format);
            testCase.verifyEqual(diagnostics.StageCounts.Initial, 5);
            testCase.verifyEqual(diagnostics.StageCounts.OverlapMask, 4);
            testCase.verifyEqual(diagnostics.StageCounts.DescriptorScore, 3);
            testCase.verifyEqual(diagnostics.StageCounts.GeometricOutlier, 2);
            testCase.verifyEqual(diagnostics.FinalCount, 2);
            testCase.verifyEqual(filtered.Matches.Count, 2);
            testCase.verifyEqual(filtered.Matches.IndexPairs, [1 1; 2 2]);
        end

        function testRatioUniquenessStageRemovesMetricAndDuplicateMatches(testCase)
            matchResult = ProjectionAlignmentMatchFilterTest.makeDuplicateMatchResult();
            options = struct();
            options.FilterPipeline = struct( ...
                Stages="ratio", ...
                MaxDescriptorRatio=0.5);

            filtered = ProjectionAlignmentMatchFilter.filter(matchResult, options);

            testCase.verifyEqual( ...
                filtered.Diagnostics.FilterPipeline.StageCounts.Initial, 4);
            testCase.verifyEqual( ...
                filtered.Diagnostics.FilterPipeline.StageCounts.RatioUniqueness, 2);
            testCase.verifyEqual(filtered.Matches.IndexPairs, [1 1; 2 2]);
            testCase.verifyEqual(filtered.Matches.MatchMetric, [0.1; 0.2]);
        end

        function testOverlapMaskRejectsEitherFeatureLocation(testCase)
            matchResult = ProjectionAlignmentMatchFilterTest.makeOverlapMatchResult();
            options = struct();
            options.FilterPipeline = struct(Stages="overlapMask");

            filtered = ProjectionAlignmentMatchFilter.filter(matchResult, options);

            testCase.verifyEqual(filtered.Matches.Count, 1);
            testCase.verifyEqual(filtered.Matches.IndexPairs, [1 1]);
            testCase.verifyEqual( ...
                filtered.Diagnostics.FilterPipeline.StageCounts.OverlapMask, 1);
        end

        function testRadialFilterCallbackControlsSurvivingMatches(testCase)
            matchResult = ProjectionAlignmentMatchFilterTest.makeDuplicateMatchResult();
            options = struct();
            options.FilterPipeline = struct( ...
                Stages="radial", ...
                RadialFilterFcn=@ProjectionAlignmentMatchFilterTest.keepFirstTwo, ...
                RadialFilterName="unit-test");

            filtered = ProjectionAlignmentMatchFilter.filter(matchResult, options);

            testCase.verifyEqual(filtered.Matches.Count, 2);
            testCase.verifyEqual(filtered.Matches.IndexPairs, [1 1; 2 2]);
            testCase.verifyEqual( ...
                filtered.Diagnostics.FilterPipeline.StageCounts.Radial, 2);
            testCase.verifyEqual(filtered.FilterOptions.RadialFilterName, "unit-test");
        end
    end

    methods (Static, Access = private)
        function matchResult = makeMatchResult()
            matchResult = struct();
            matchResult.Matches = ProjectionAlignmentMatchFilterTest.makePairMatch( ...
                [2 2; 3 3; 7 7; 4 4; 5 5], ...
                [3 2; 4 3; 8 7; 5 4; 5 5], ...
                [1 1; 2 2; 3 3; 4 4; 5 5], ...
                [0.1; 0.2; 0.3; 0.4; 0.5], ...
                [0.9; 0.8; 0.95; 0.1; 0.9]);
            matchResult.Matches.ReferencePlaneCoordinates(5, :) = [30 30];
        end

        function matchResult = makeDuplicateMatchResult()
            matchResult = struct();
            matchResult.Matches = ProjectionAlignmentMatchFilterTest.makePairMatch( ...
                [2 2; 3 3; 4 4; 5 5], ...
                [3 2; 4 3; 5 4; 6 5], ...
                [1 1; 2 2; 2 3; 4 2], ...
                [0.1; 0.2; 0.3; 0.9], ...
                [0.9; 0.8; 0.7; 0.6]);
        end

        function matchResult = makeOverlapMatchResult()
            matchResult = struct();
            matchResult.Matches = ProjectionAlignmentMatchFilterTest.makePairMatch( ...
                [2 2; 7 7; 4 4], ...
                [3 3; 4 4; 8 8], ...
                [1 1; 2 2; 3 3], ...
                [0.1; 0.2; 0.3], ...
                [0.9; 0.8; 0.7]);
        end

        function pairMatch = makePairMatch(movingLocations, referenceLocations, ...
                indexPairs, matchMetric, scores)
            pairMatch = struct();
            pairMatch.Pair = [1 2];
            pairMatch.Detector = "sift";
            pairMatch.Matcher = "nearestNeighborRatio";
            pairMatch.MovingFeatureLocations = movingLocations;
            pairMatch.ReferenceFeatureLocations = referenceLocations;
            pairMatch.MovingPlaneCoordinates = movingLocations;
            pairMatch.ReferencePlaneCoordinates = referenceLocations;
            pairMatch.MovingSourceRows = movingLocations(:, 2);
            pairMatch.MovingSourceColumns = movingLocations(:, 1);
            pairMatch.ReferenceSourceRows = referenceLocations(:, 2);
            pairMatch.ReferenceSourceColumns = referenceLocations(:, 1);
            pairMatch.IndexPairs = indexPairs;
            pairMatch.MatchMetric = matchMetric;
            pairMatch.Scores = scores;
            pairMatch.FeatureCounts = [10 10];
            pairMatch.Count = size(indexPairs, 1);
            pairMatch.OverlapMask = ProjectionAlignmentMatchFilterTest.makeOverlapMask();
        end

        function mask = makeOverlapMask()
            mask = false(8, 8);
            mask(1:5, 1:5) = true;
        end

        function mask = keepFirstTwo(pairMatch, currentMask, pipeline) %#ok<INUSD>
            mask = false(pairMatch.Count, 1);
            mask(1:2) = true;
            mask = mask & currentMask(:);
        end
    end
end
