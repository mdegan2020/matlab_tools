classdef ProjectionAlignmentEvidenceSelector
    %ProjectionAlignmentEvidenceSelector Select diverse bounded solve evidence.

    properties (Constant)
        Format = "ProjectionAlignmentEvidenceSelection"
        Version = 1
    end

    methods (Static)
        function selection = select(matchResult, options)
            %select Retain a spatially diverse, informative subset per pair.
            options = ProjectionAlignmentOptions.validate(options);
            selected = matchResult;
            pairDiagnostics = repmat( ...
                ProjectionAlignmentEvidenceSelector.emptyPairDiagnostics(), ...
                1, numel(matchResult.Matches));
            for pairIndex = 1:numel(matchResult.Matches)
                pair = ProjectionAlignmentMatchLedger.ensurePair( ...
                    matchResult.Matches(pairIndex));
                [keep, pairDiagnostics(pairIndex)] = ...
                    ProjectionAlignmentEvidenceSelector.pairSelection( ...
                    pair, options.EvidenceSelection);
                pair = ProjectionAlignmentEvidenceSelector.markLedger(pair, keep);
                pair = ProjectionAlignmentEvidenceSelector.subsetPair(pair, keep);
                selected.Matches(pairIndex) = pair;
            end
            selected.MatchLedger = ProjectionAlignmentMatchLedger.combine(selected);
            diagnostics = ProjectionAlignmentEvidenceSelector.combineDiagnostics( ...
                pairDiagnostics, options.EvidenceSelection);
            selection = struct(Format=ProjectionAlignmentEvidenceSelector.Format, ...
                Version=ProjectionAlignmentEvidenceSelector.Version, ...
                MatchResult=selected, PairDiagnostics=pairDiagnostics, ...
                Diagnostics=diagnostics);
        end
    end

    methods (Static, Access = private)
        function [keep, diagnostics] = pairSelection(pair, options)
            count = pair.Count;
            diagnostics = ProjectionAlignmentEvidenceSelector. ...
                emptyPairDiagnostics();
            diagnostics.Pair = pair.Pair;
            diagnostics.InputCount = count;
            keep = true(count, 1);
            if ~options.Enabled || count <= options.MaximumPerPair
                diagnostics.SelectedCount = count;
                diagnostics.CoverageBefore = ...
                    ProjectionAlignmentEvidenceSelector.coverage(pair, keep);
                diagnostics.CoverageAfter = diagnostics.CoverageBefore;
                diagnostics = ProjectionAlignmentEvidenceSelector. ...
                    informationDiagnostics(diagnostics, pair, keep);
                return
            end

            [movingNormalized, movingCell] = ...
                ProjectionAlignmentEvidenceSelector.normalizeAndBin( ...
                pair.MovingSourceColumns, pair.MovingSourceRows, ...
                options.SpatialGridSize);
            [referenceNormalized, referenceCell] = ...
                ProjectionAlignmentEvidenceSelector.normalizeAndBin( ...
                pair.ReferenceSourceColumns, pair.ReferenceSourceRows, ...
                options.SpatialGridSize);
            quality = ProjectionAlignmentEvidenceSelector.quality(pair);
            radial = sum((movingNormalized - 0.5).^2, 2) + ...
                sum((referenceNormalized - 0.5).^2, 2);
            informationScore = quality + options.InformationWeight * radial;
            recordIds = ProjectionAlignmentEvidenceSelector.recordIds(pair);
            values = table(-informationScore, recordIds, (1:count).', ...
                VariableNames=["NegativeScore" "RecordId" "Index"]);
            values = sortrows(values, ["NegativeScore" "RecordId"]);
            order = values.Index;

            keep = false(count, 1);
            movingUsed = false(prod(options.SpatialGridSize), 1);
            referenceUsed = false(prod(options.SpatialGridSize), 1);
            for index = reshape(order, 1, [])
                addsCoverage = ~movingUsed(movingCell(index)) || ...
                    ~referenceUsed(referenceCell(index));
                if addsCoverage
                    keep(index) = true;
                    movingUsed(movingCell(index)) = true;
                    referenceUsed(referenceCell(index)) = true;
                    if nnz(keep) == options.MaximumPerPair
                        break
                    end
                end
            end
            for index = reshape(order, 1, [])
                if nnz(keep) == options.MaximumPerPair
                    break
                end
                keep(index) = true;
            end
            keep = ProjectionAlignmentEvidenceSelector.ensureExtent( ...
                pair, keep, order, options.MinimumCoverageFraction);

            diagnostics.SelectedCount = nnz(keep);
            diagnostics.SpatialRedundancyCount = count - nnz(keep);
            diagnostics.CoverageBefore = ...
                ProjectionAlignmentEvidenceSelector.coverage( ...
                pair, true(count, 1));
            diagnostics.CoverageAfter = ...
                ProjectionAlignmentEvidenceSelector.coverage(pair, keep);
            diagnostics = ProjectionAlignmentEvidenceSelector. ...
                informationDiagnostics(diagnostics, pair, keep);
        end

        function [normalized, cells] = normalizeAndBin( ...
                columns, rows, gridSize)
            coordinates = [double(columns(:)) double(rows(:))];
            minimum = min(coordinates, [], 1);
            span = max(coordinates, [], 1) - minimum;
            span(span <= eps) = 1;
            normalized = (coordinates - minimum) ./ span;
            columnBins = min(gridSize(2), max(1, ...
                floor(normalized(:, 1) * gridSize(2)) + 1));
            rowBins = min(gridSize(1), max(1, ...
                floor(normalized(:, 2) * gridSize(1)) + 1));
            cells = sub2ind(gridSize, rowBins, columnBins);
        end

        function quality = quality(pair)
            if isfield(pair, "Scores") && numel(pair.Scores) == pair.Count
                quality = double(pair.Scores(:));
                quality(~isfinite(quality)) = 0;
            else
                quality = ones(pair.Count, 1);
            end
            maximum = max(quality);
            minimum = min(quality);
            if maximum > minimum
                quality = (quality - minimum) / (maximum - minimum);
            else
                quality(:) = 1;
            end
            if isfield(pair, "SourceUncertaintyPixels") && ...
                    size(pair.SourceUncertaintyPixels, 1) == pair.Count
                uncertainty = mean(pair.SourceUncertaintyPixels, 2, "omitnan");
                uncertainty(~isfinite(uncertainty)) = 1;
                quality = quality ./ max(1, uncertainty);
            end
        end

        function ids = recordIds(pair)
            rawIndices = ProjectionAlignmentEvidenceSelector.rawIndices(pair);
            ids = string({pair.MatchLedger(rawIndices).RecordId}).';
        end

        function keep = ensureExtent(pair, keep, order, minimumFraction)
            targetCount = nnz(keep);
            fields = {pair.MovingSourceColumns, pair.MovingSourceRows, ...
                pair.ReferenceSourceColumns, pair.ReferenceSourceRows};
            forced = zeros(0, 1);
            for fieldIndex = 1:numel(fields)
                values = double(fields{fieldIndex}(:));
                [~, minimumIndex] = min(values);
                [~, maximumIndex] = max(values);
                forced = unique([forced; minimumIndex; maximumIndex], "stable");
            end
            candidate = keep;
            candidate(forced) = true;
            before = ProjectionAlignmentEvidenceSelector.coverage( ...
                pair, true(pair.Count, 1));
            after = ProjectionAlignmentEvidenceSelector.coverage(pair, candidate);
            ratios = after ./ max(before, eps);
            if all(ratios >= minimumFraction)
                keep = candidate;
            else
                return
            end
            if nnz(keep) > numel(order)
                return
            end
            maximumCount = max(targetCount, numel(forced));
            removable = reshape(flipud(order), 1, []);
            for index = removable
                if nnz(keep) <= maximumCount
                    break
                end
                if keep(index) && ~ismember(index, forced)
                    keep(index) = false;
                end
            end
        end

        function coverage = coverage(pair, keep)
            moving = ProjectionAlignmentEvidenceSelector.extentCoverage( ...
                pair.MovingSourceColumns(keep), pair.MovingSourceRows(keep));
            reference = ProjectionAlignmentEvidenceSelector.extentCoverage( ...
                pair.ReferenceSourceColumns(keep), ...
                pair.ReferenceSourceRows(keep));
            coverage = [moving reference];
        end

        function value = extentCoverage(columns, rows)
            if isempty(columns)
                value = 0;
                return
            end
            value = max(1, max(columns) - min(columns)) * ...
                max(1, max(rows) - min(rows));
        end

        function diagnostics = informationDiagnostics(diagnostics, pair, keep)
            coordinates = [pair.MovingSourceColumns(keep) ...
                pair.MovingSourceRows(keep) pair.ReferenceSourceColumns(keep) ...
                pair.ReferenceSourceRows(keep)];
            if isempty(coordinates)
                diagnostics.InformationLogDeterminant = -Inf;
                diagnostics.InformationConditionNumber = Inf;
                return
            end
            coordinates = double(coordinates);
            scale = max(max(coordinates, [], 1) - min(coordinates, [], 1), 1);
            design = [ones(size(coordinates, 1), 1) ...
                (coordinates - mean(coordinates, 1)) ./ scale];
            normal = design.' * design + 1e-12 * eye(size(design, 2));
            diagnostics.InformationLogDeterminant = ...
                2 * sum(log(abs(diag(chol(normal)))));
            diagnostics.InformationConditionNumber = cond(normal);
        end

        function pair = markLedger(pair, keep)
            rawIndices = ProjectionAlignmentEvidenceSelector.rawIndices(pair);
            ledgerMask = false(numel(pair.MatchLedger), 1);
            ledgerMask(rawIndices(keep)) = true;
            pair.MatchLedger = ProjectionAlignmentMatchLedger.applyStage( ...
                pair.MatchLedger, "spatialSelection", ledgerMask);
        end

        function pair = subsetPair(pair, keep)
            fields = ["MovingFeatureLocations" "ReferenceFeatureLocations" ...
                "MovingPlaneCoordinates" "ReferencePlaneCoordinates" ...
                "MovingSourceRows" "MovingSourceColumns" ...
                "ReferenceSourceRows" "ReferenceSourceColumns" ...
                "IndexPairs" "MatchMetric" "Scores" "MatchRecordIndices" ...
                "RefinementStatus" "RefinementQuality" ...
                "RefinementPeakMargin" "SourceUncertaintyPixels" ...
                "RefinementAcceptedMask" "MovingSourceJacobians" ...
                "ReferenceSourceJacobians"];
            for field = fields
                if isfield(pair, field) && size(pair.(field), 1) == pair.Count
                    pair.(field) = pair.(field)(keep, :);
                end
            end
            pair.Count = nnz(keep);
        end

        function indices = rawIndices(pair)
            if isfield(pair, "MatchRecordIndices") && ...
                    numel(pair.MatchRecordIndices) == pair.Count
                indices = pair.MatchRecordIndices(:);
            else
                indices = (1:pair.Count).';
            end
        end

        function diagnostics = emptyPairDiagnostics()
            diagnostics = struct(Pair=[0 0], InputCount=0, ...
                SelectedCount=0, SpatialRedundancyCount=0, ...
                CoverageBefore=[0 0], CoverageAfter=[0 0], ...
                InformationLogDeterminant=-Inf, ...
                InformationConditionNumber=Inf);
        end

        function diagnostics = combineDiagnostics(pairs, options)
            diagnostics = struct(Enabled=options.Enabled, ...
                MaximumPerPair=options.MaximumPerPair, ...
                InputRecordCount=sum([pairs.InputCount]), ...
                SelectedRecordCount=sum([pairs.SelectedCount]), ...
                SpatialRedundancyCount=sum([pairs.SpatialRedundancyCount]), ...
                PairDiagnostics=pairs);
        end
    end
end
