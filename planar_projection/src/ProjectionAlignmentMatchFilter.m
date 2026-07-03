classdef ProjectionAlignmentMatchFilter
    %ProjectionAlignmentMatchFilter Filter pairwise alignment matches.

    properties (Constant)
        Format = "ProjectionAlignmentFilteredMatches"
        Version = 1
    end

    methods (Static)
        function filtered = filter(matchResult, options)
            %filter Apply the configured match-filter pipeline.
            if nargin < 2
                options = struct();
            end
            ProjectionAlignmentMatchFilter.validateMatchResult(matchResult);
            options = ProjectionAlignmentOptions.validate(options);

            filtered = matchResult;
            filtered.Format = ProjectionAlignmentMatchFilter.Format;
            filtered.Version = ProjectionAlignmentMatchFilter.Version;
            for k = 1:numel(matchResult.Matches)
                [filtered.Matches(k), pairDiagnostics(k)] = ... %#ok<AGROW>
                    ProjectionAlignmentMatchFilter.filterPair( ...
                    matchResult.Matches(k), options);
            end
            filtered.FilterOptions = options.FilterPipeline;
            filtered.Diagnostics.FilterPipeline = pairDiagnostics;
        end
    end

    methods (Static, Access = private)
        function [pairMatch, diagnostics] = filterPair(pairMatch, options)
            pipeline = options.FilterPipeline;
            keepMask = true(pairMatch.Count, 1);
            diagnostics = ProjectionAlignmentMatchFilter.initialDiagnostics(pairMatch);

            for stage = pipeline.Stages
                switch stage
                    case "overlapMask"
                        keepMask = keepMask & ...
                            ProjectionAlignmentMatchFilter.overlapMask(pairMatch);
                        diagnostics.StageCounts.OverlapMask = nnz(keepMask);
                    case "descriptorScore"
                        keepMask = keepMask & ...
                            ProjectionAlignmentMatchFilter.descriptorScoreMask( ...
                            pairMatch, pipeline);
                        diagnostics.StageCounts.DescriptorScore = nnz(keepMask);
                    case "ratio"
                        keepMask = keepMask & ...
                            ProjectionAlignmentMatchFilter.ratioUniquenessMask( ...
                            pairMatch, pipeline);
                        diagnostics.StageCounts.RatioUniqueness = nnz(keepMask);
                    case "geometricOutlier"
                        keepMask = keepMask & ...
                            ProjectionAlignmentMatchFilter.geometricMask( ...
                            pairMatch, pipeline, keepMask);
                        diagnostics.StageCounts.GeometricOutlier = nnz(keepMask);
                    case "radial"
                        keepMask = keepMask & ...
                            ProjectionAlignmentMatchFilter.radialMask( ...
                            pairMatch, pipeline, keepMask);
                        diagnostics.StageCounts.Radial = nnz(keepMask);
                end
            end

            pairMatch = ProjectionAlignmentMatchFilter.subsetPair(pairMatch, keepMask);
            diagnostics.FinalCount = pairMatch.Count;
            diagnostics.RejectedCount = diagnostics.InitialCount - diagnostics.FinalCount;
        end

        function diagnostics = initialDiagnostics(pairMatch)
            diagnostics = struct();
            diagnostics.Pair = pairMatch.Pair;
            diagnostics.InitialCount = pairMatch.Count;
            diagnostics.FinalCount = pairMatch.Count;
            diagnostics.RejectedCount = 0;
            diagnostics.StageCounts = struct();
            diagnostics.StageCounts.Initial = pairMatch.Count;
            diagnostics.StageCounts.OverlapMask = pairMatch.Count;
            diagnostics.StageCounts.DescriptorScore = pairMatch.Count;
            diagnostics.StageCounts.RatioUniqueness = pairMatch.Count;
            diagnostics.StageCounts.GeometricOutlier = pairMatch.Count;
            diagnostics.StageCounts.Radial = pairMatch.Count;
        end

        function mask = overlapMask(pairMatch)
            if pairMatch.Count == 0
                mask = false(0, 1);
                return
            end
            movingMask = ProjectionAlignmentMatchFilter.sampleMask( ...
                pairMatch.OverlapMask, pairMatch.MovingFeatureLocations);
            referenceMask = ProjectionAlignmentMatchFilter.sampleMask( ...
                pairMatch.OverlapMask, pairMatch.ReferenceFeatureLocations);
            mask = movingMask & referenceMask;
        end

        function mask = descriptorScoreMask(pairMatch, pipeline)
            mask = true(pairMatch.Count, 1);
            if ~isempty(pipeline.MinMatchScore)
                mask = pairMatch.Scores(:) >= pipeline.MinMatchScore;
            end
        end

        function mask = ratioUniquenessMask(pairMatch, pipeline)
            mask = true(pairMatch.Count, 1);
            if ~isempty(pipeline.MaxDescriptorRatio)
                mask = mask & pairMatch.MatchMetric(:) <= pipeline.MaxDescriptorRatio;
            end
            mask = mask & ProjectionAlignmentMatchFilter.uniqueIndexMask( ...
                pairMatch.IndexPairs);
        end

        function mask = geometricMask(pairMatch, pipeline, currentMask)
            mask = true(pairMatch.Count, 1);
            if pipeline.GeometricMethod == "none" || nnz(currentMask) < 3
                return
            end

            moving = pairMatch.MovingPlaneCoordinates(currentMask, :);
            reference = pairMatch.ReferencePlaneCoordinates(currentMask, :);
            displacement = reference - moving;
            medianDisplacement = median(displacement, 1);
            residuals = sqrt(sum((displacement - medianDisplacement).^2, 2));
            currentIndices = find(currentMask);
            mask(currentIndices) = residuals <= pipeline.GeometricMaxDistancePixels;
        end

        function mask = radialMask(pairMatch, pipeline, currentMask)
            mask = true(pairMatch.Count, 1);
            if isempty(pipeline.RadialFilterFcn)
                return
            end

            candidateMask = pipeline.RadialFilterFcn(pairMatch, currentMask, pipeline);
            if ~(islogical(candidateMask) || isnumeric(candidateMask)) || ...
                    ~isvector(candidateMask) || numel(candidateMask) ~= pairMatch.Count
                error("ProjectionAlignmentMatchFilter:invalidRadialFilter", ...
                    "RadialFilterFcn must return a logical vector with one value per match.");
            end
            mask = logical(candidateMask(:));
        end

        function pairMatch = subsetPair(pairMatch, keepMask)
            pairMatch.MovingFeatureLocations = ...
                pairMatch.MovingFeatureLocations(keepMask, :);
            pairMatch.ReferenceFeatureLocations = ...
                pairMatch.ReferenceFeatureLocations(keepMask, :);
            pairMatch.MovingPlaneCoordinates = ...
                pairMatch.MovingPlaneCoordinates(keepMask, :);
            pairMatch.ReferencePlaneCoordinates = ...
                pairMatch.ReferencePlaneCoordinates(keepMask, :);
            pairMatch.MovingSourceRows = pairMatch.MovingSourceRows(keepMask, :);
            pairMatch.MovingSourceColumns = pairMatch.MovingSourceColumns(keepMask, :);
            pairMatch.ReferenceSourceRows = pairMatch.ReferenceSourceRows(keepMask, :);
            pairMatch.ReferenceSourceColumns = ...
                pairMatch.ReferenceSourceColumns(keepMask, :);
            pairMatch.IndexPairs = pairMatch.IndexPairs(keepMask, :);
            pairMatch.MatchMetric = pairMatch.MatchMetric(keepMask, :);
            pairMatch.Scores = pairMatch.Scores(keepMask, :);
            pairMatch.Count = nnz(keepMask);
        end

        function mask = sampleMask(maskImage, locations)
            if isempty(locations)
                mask = false(0, 1);
                return
            end
            values = interp2(double(maskImage), locations(:, 1), locations(:, 2), ...
                "nearest", 0);
            mask = values(:) > 0;
        end

        function mask = uniqueIndexMask(indexPairs)
            mask = false(size(indexPairs, 1), 1);
            usedMoving = zeros(0, 1);
            usedReference = zeros(0, 1);
            for k = 1:size(indexPairs, 1)
                movingIndex = indexPairs(k, 1);
                referenceIndex = indexPairs(k, 2);
                if ~ismember(movingIndex, usedMoving) && ...
                        ~ismember(referenceIndex, usedReference)
                    mask(k) = true;
                    usedMoving(end + 1, 1) = movingIndex; %#ok<AGROW>
                    usedReference(end + 1, 1) = referenceIndex; %#ok<AGROW>
                end
            end
        end

        function validateMatchResult(matchResult)
            if ~isstruct(matchResult) || ~isscalar(matchResult) || ...
                    ~isfield(matchResult, "Matches") || isempty(matchResult.Matches)
                error("ProjectionAlignmentMatchFilter:invalidMatchResult", ...
                    "Match result must contain a nonempty Matches struct array.");
            end
        end
    end
end
