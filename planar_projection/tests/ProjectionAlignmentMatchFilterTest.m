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
                GeometricMethod="similarity", ...
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
            testCase.verifyEqual(diagnostics.GeometricModel.Method, "similarity");
            testCase.verifyEqual( ...
                diagnostics.GeometricModel.CoordinateSpace, "workingPixels");
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

        function testGeometricFilterRejectsCatastrophicDisplacements(testCase)
            matchResult = ...
                ProjectionAlignmentMatchFilterTest.makeCatastrophicOutlierMatchResult();
            options = struct();
            options.FilterPipeline = struct( ...
                Stages="geometricOutlier", ...
                GeometricMethod="similarity", ...
                GeometricMaxDistancePixels=20);

            filtered = ProjectionAlignmentMatchFilter.filter(matchResult, options);

            testCase.verifyEqual(filtered.Matches.Count, 20);
            testCase.verifyEqual( ...
                filtered.Diagnostics.FilterPipeline.StageCounts.GeometricOutlier, ...
                20);
            testCase.verifyTrue(all(filtered.Matches.IndexPairs(:, 1) <= 20));
            model = filtered.Diagnostics.FilterPipeline.GeometricModel;
            testCase.verifyEqual(model.Status, "fitted");
            testCase.verifyEqual(model.AcceptedCount, 20);
            testCase.verifyLessThan(model.RmsAcceptedPixels, 1e-10);
        end

        function testNativeDisplacementFilterRejectsNativePixelOutliers(testCase)
            matchResult = ...
                ProjectionAlignmentMatchFilterTest.makeCatastrophicOutlierMatchResult();
            options = struct();
            options.FilterPipeline = struct( ...
                Stages="nativeDisplacement", ...
                NativeDisplacementMethod="mad", ...
                NativeMadScale=6, ...
                NativeMinResidualPixels=5);

            filtered = ProjectionAlignmentMatchFilter.filter(matchResult, options);

            testCase.verifyEqual(filtered.Matches.Count, 20);
            testCase.verifyEqual( ...
                filtered.Diagnostics.FilterPipeline.StageCounts.NativeDisplacement, ...
                20);
            testCase.verifyTrue(all(filtered.Matches.IndexPairs(:, 1) <= 20));
        end

        function testCoplanarityFilterUsesRobustCenteredNormalizedResidual( ...
                testCase)
            [matchResult, scene] = ...
                ProjectionAlignmentMatchFilterTest.makeCoplanarityInputs();
            options = struct(FilterPipeline=struct( ...
                Stages="epipolarCoplanarity", ...
                CoplanarityMethod="robustMad", ...
                CoplanarityMadScale=4, CoplanarityMinResidual=1e-5));

            first = ProjectionAlignmentMatchFilter.filter( ...
                matchResult, options, scene);
            second = ProjectionAlignmentMatchFilter.filter( ...
                matchResult, options, scene);
            diagnostics = first.Diagnostics.FilterPipeline.Coplanarity;
            records = first.Matches.MatchLedger;
            stageMasks = [records.StageMasks];

            testCase.verifyEqual(first.Matches.Count, 10);
            testCase.verifyEqual(first.Matches.IndexPairs, [(1:10).' (1:10).']);
            testCase.verifyEqual(diagnostics.Status, "filtered");
            testCase.verifyEqual(diagnostics.Unit, "normalizedAngular");
            testCase.verifyEqual(diagnostics.Center, 0, AbsTol=1e-12);
            testCase.verifyEqual([stageMasks.EpipolarCoplanarity], ...
                [true(1, 10) false false]);
            testCase.verifyEqual(records(11).FirstRejectedStage, ...
                "epipolarCoplanarity");
            testCase.verifyTrue(isfinite( ...
                records(11).Residuals.EpipolarCoplanarityBeforeRadians));
            testCase.verifyEqual(first.Matches.MatchRecordIndices, ...
                second.Matches.MatchRecordIndices);
            testCase.verifyEqual( ...
                first.Diagnostics.FilterPipeline.Coplanarity.AcceptedMask, ...
                second.Diagnostics.FilterPipeline.Coplanarity.AcceptedMask);
        end

        function testCoplanarityFilterRequiresScene(testCase)
            [matchResult, ~] = ...
                ProjectionAlignmentMatchFilterTest.makeCoplanarityInputs();
            options = struct(FilterPipeline=struct( ...
                Stages="epipolarCoplanarity", ...
                CoplanarityMethod="robustMad"));

            testCase.verifyError(@() ProjectionAlignmentMatchFilter.filter( ...
                matchResult, options), ...
                "ProjectionAlignmentMatchFilter:sceneRequired");
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
            matchResult.Matches.ReferenceFeatureLocations(5, :) = [30 30];
            overlapMask = false(30, 30);
            overlapMask(1:5, 1:5) = true;
            overlapMask(30, 30) = true;
            matchResult.Matches.OverlapMask = overlapMask;
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

        function matchResult = makeCatastrophicOutlierMatchResult()
            moving = [(1:20).' (1:20).'];
            reference = moving + [5 * ones(20, 1), 3 * ones(20, 1)];
            moving = [moving; 10 10; 15 15];
            reference = [reference; 15000 15000; -15000 14000];
            indexPairs = [(1:22).' (1:22).'];
            matchResult = struct();
            matchResult.Matches = ProjectionAlignmentMatchFilterTest.makePairMatch( ...
                moving, reference, indexPairs, 0.1 * ones(22, 1), ...
                ones(22, 1));
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

        function [matchResult, scene] = makeCoplanarityInputs()
            count = 12;
            rows = (1:count).';
            columns = (1:count).';
            movingLocations = [columns rows];
            referenceLocations = movingLocations;
            pairMatch = ProjectionAlignmentMatchFilterTest.makePairMatch( ...
                movingLocations, referenceLocations, ...
                [(1:count).' (1:count).'], 0.1 * ones(count, 1), ...
                ones(count, 1));
            pairMatch.PairLayerIds = ["moving-id" "reference-id"];
            pairMatch.MovingLayerId = "moving-id";
            pairMatch.ReferenceLayerId = "reference-id";
            pairMatch.MovingSourceRows = rows;
            pairMatch.MovingSourceColumns = columns;
            pairMatch.ReferenceSourceRows = rows;
            pairMatch.ReferenceSourceColumns = columns;
            pairMatch.ReferenceSourceRows(end - 1:end) = [1; 2];
            matchResult = struct(Matches=pairMatch);

            plane = PlanarProjection.definePlaneFromBasis( ...
                zeros(3, 1), [1; 0; 0], [0; 1; 0]);
            movingGeometry = struct(ImageSize=[count count], ...
                SampleRayFcn=@(sampleRows, sampleColumns) ...
                ProjectionAlignmentMatchFilterTest.raysToTargets( ...
                [0; 0; 0], sampleRows, sampleColumns));
            referenceGeometry = struct(ImageSize=[count count], ...
                SampleRayFcn=@(sampleRows, sampleColumns) ...
                ProjectionAlignmentMatchFilterTest.raysToTargets( ...
                [1; 0; 0], sampleRows, sampleColumns));
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
            targets = [columns(:).'; 20 * ones(1, count); rows(:).'];
            vectors = targets - origins;
        end
    end
end
