classdef ProjectionDenseTemplateMatcher < ProjectionDenseMatcher
    %ProjectionDenseTemplateMatcher Explainable classical local-strip matcher.

    methods
        function metadata = metadata(~)
            metadata = struct(AlgorithmId="sightline.classical-template", ...
                Name="Classical dense template matcher", ...
                SemanticVersion="1.0.0", Capabilities=struct( ...
                InputGeometry="regionalLocalStrip", ...
                CostMethods=["zncc" "gradientCorrelation" ...
                "censusRank" "phaseCorrelation"], ...
                ObservationSpace="continuousFullSource", ...
                SupportsOcclusionState=true, SupportsCovariance=false, ...
                SupportsSpatiallyVaryingPrediction=true), ...
                RequiredProducts=strings(1, 0), Deterministic=true, ...
                Precision="double scores/subpixel/source mapping", ...
                MemoryEstimate="bounded patches and candidate strips", ...
                CpuSupported=true, GpuSupported=false);
        end

        function options = defaultOptions(~)
            options = ProjectionDenseTemplateMatcher.validate(struct());
        end

        function options = validateOptions(~, options)
            options = ProjectionDenseTemplateMatcher.validate(options);
        end
    end

    methods (Access = protected)
        function result = matchImpl(~, request, options, runtimeControl)
            imageSize = size(request.AnalysisImages{1});
            moving = ProjectionDenseTemplateMatcher.normalizeImage( ...
                request.AnalysisImages{1}, request.ValidityMasks{1});
            reference = ProjectionDenseTemplateMatcher.normalizeImage( ...
                request.AnalysisImages{2}, request.ValidityMasks{2});
            rows = (1 + options.PatchRadius):options.SampleStride: ...
                (imageSize(1) - options.PatchRadius);
            columns = (1 + options.PatchRadius):options.SampleStride: ...
                (imageSize(2) - options.PatchRadius);
            [columnGrid, rowGrid] = meshgrid(columns, rows);
            rowGrid = rowGrid(:);
            columnGrid = columnGrid(:);
            count = min(numel(rowGrid), options.MaximumObservations);
            rowGrid = rowGrid(1:count);
            columnGrid = columnGrid(1:count);
            movingRows = nan(count, 1);
            movingColumns = nan(count, 1);
            referenceRows = nan(count, 1);
            referenceColumns = nan(count, 1);
            states = repmat("noMatch", count, 1);
            score = nan(count, 1);
            confidence = zeros(count, 1);
            bestScores = nan(count, 1);
            secondScores = nan(count, 1);
            uniqueness = nan(count, 1);
            texture = nan(count, 1);
            consistency = nan(count, 1);
            geometryResidual = nan(count, 1);
            tieCount = zeros(count, 1);
            candidateCount = zeros(count, 1);
            for index = 1:count
                ProjectionDenseTemplateMatcher.checkCancellation(runtimeControl);
                row = rowGrid(index);
                column = columnGrid(index);
                if ~request.ValidityMasks{1}(row, column)
                    states(index) = "masked";
                    continue
                end
                if ~request.OverlapMask(row, column)
                    states(index) = "outsideOverlap";
                    continue
                end
                prediction = ProjectionDenseTemplateMatcher.prediction( ...
                    request.SearchPrediction, row, column, options);
                if prediction.State == "noSupport"
                    states(index) = "geometrySearchFailure";
                    continue
                end
                movingPatch = ProjectionDenseTemplateMatcher.patch( ...
                    moving, row, column, options.PatchRadius);
                texture(index) = std(movingPatch(:));
                if texture(index) < options.MinimumTextureStd
                    states(index) = "insufficientTexture";
                    continue
                end
                search = ProjectionDenseTemplateMatcher.search( ...
                    movingPatch, reference, row, column, prediction, ...
                    options, request.ValidityMasks{2});
                candidateCount(index) = search.CandidateCount;
                if search.CandidateCount == 0
                    states(index) = "noMatch";
                    continue
                end
                bestScores(index) = search.BestScore;
                secondScores(index) = search.SecondScore;
                uniqueness(index) = search.BestScore - search.SecondScore;
                tieCount(index) = search.TieCount;
                if search.TieCount > 1 || ...
                        uniqueness(index) < options.MinimumUniquenessMargin
                    states(index) = "ambiguousRepetitive";
                    continue
                end
                disparity = ProjectionDenseTemplateMatcher.subpixel( ...
                    search, options);
                referencePoint = [column row] - disparity;
                roundTrip = ProjectionDenseTemplateMatcher.reverseConsistency( ...
                    reference, moving, referencePoint, disparity, options, ...
                    request.ValidityMasks{1});
                consistency(index) = roundTrip;
                if ~isfinite(roundTrip) || ...
                        roundTrip > options.ConsistencyTolerancePixels
                    states(index) = "occluded";
                    continue
                end
                [movingRows(index), movingColumns(index)] = ...
                    ProjectionDenseTemplateMatcher.mapSource( ...
                    request.SourceRows{1}, request.SourceColumns{1}, ...
                    column, row);
                [referenceRows(index), referenceColumns(index)] = ...
                    ProjectionDenseTemplateMatcher.mapSource( ...
                    request.SourceRows{2}, request.SourceColumns{2}, ...
                    referencePoint(1), referencePoint(2));
                if any(~isfinite([movingRows(index) movingColumns(index) ...
                        referenceRows(index) referenceColumns(index)]))
                    states(index) = "outsideOverlap";
                    continue
                end
                geometryResidual(index) = norm( ...
                    disparity - prediction.DisparityVectorPixels);
                states(index) = "valid";
                score(index) = search.BestScore;
                confidence(index) = min(1, max(0, 0.5 * ...
                    uniqueness(index) / max(options.MinimumUniquenessMargin, eps) + ...
                    0.5 * (1 - roundTrip / ...
                    max(options.ConsistencyTolerancePixels, eps))));
            end
            result = struct(MovingSourceRows=movingRows, ...
                MovingSourceColumns=movingColumns, ...
                ReferenceSourceRows=referenceRows, ...
                ReferenceSourceColumns=referenceColumns, States=states, ...
                Score=score, Confidence=confidence, ...
                Diagnostics=struct(CostMethod=options.CostMethod, ...
                PyramidScales=options.PyramidScales, ...
                BestScore=bestScores, SecondScore=secondScores, ...
                UniquenessMargin=uniqueness, TextureStd=texture, ...
                LeftRightConsistencyPixels=consistency, ...
                GeometricPredictionResidualPixels=geometryResidual, ...
                DeterministicTieCount=tieCount, ...
                CandidateCount=candidateCount, ...
                ConfidenceCalibrated=false, ...
                InputObservationCount=count), ...
                Execution=struct(Device="cpu", FallbackReason=""), ...
                Provenance=struct(SearchPredictionFormat= ...
                ProjectionDenseTemplateMatcher.predictionFormat( ...
                request.SearchPrediction)));
        end
    end

    methods (Static, Access = private)
        function options = validate(options)
            if nargin < 1 || isempty(options)
                options = struct();
            end
            defaults = struct(CostMethod="zncc", PatchRadius=3, ...
                SampleStride=4, HorizontalDisparityRange=[-16 16], ...
                VerticalDisparityRange=[-2 2], ...
                MinimumUniquenessMargin=0.05, MinimumTextureStd=0.01, ...
                ConsistencyTolerancePixels=1, EnableSubpixel=true, ...
                PyramidScales=[0.5 1], MaximumObservations=5000);
            if ~isstruct(options) || ~isscalar(options) || ...
                    any(~ismember(string(fieldnames(options)), ...
                    string(fieldnames(defaults))))
                error("ProjectionDenseTemplateMatcher:invalidOptions", ...
                    "Template matcher options contain unsupported fields.");
            end
            names = fieldnames(options);
            for index = 1:numel(names)
                defaults.(names{index}) = options.(names{index});
            end
            defaults.CostMethod = string(defaults.CostMethod);
            methods = ["zncc" "gradientCorrelation" ...
                "censusRank" "phaseCorrelation"];
            if ~isscalar(defaults.CostMethod) || ...
                    ~ismember(defaults.CostMethod, methods)
                error("ProjectionDenseTemplateMatcher:invalidOptions", ...
                    "CostMethod is unsupported.");
            end
            integerNames = ["PatchRadius" "SampleStride" ...
                "MaximumObservations"];
            for name = integerNames
                value = defaults.(name);
                if ~isnumeric(value) || ~isscalar(value) || ...
                        ~isfinite(value) || value < 1 || fix(value) ~= value
                    error("ProjectionDenseTemplateMatcher:invalidOptions", ...
                        "%s must be a positive integer.", name);
                end
                defaults.(name) = double(value);
            end
            rangeNames = ["HorizontalDisparityRange" ...
                "VerticalDisparityRange"];
            for name = rangeNames
                value = defaults.(name);
                if ~isnumeric(value) || ~isequal(size(value), [1 2]) || ...
                        any(~isfinite(value)) || value(1) > value(2)
                    error("ProjectionDenseTemplateMatcher:invalidOptions", ...
                        "%s must be a finite increasing 1x2 range.", name);
                end
                defaults.(name) = double(value);
            end
            scalarNames = ["MinimumUniquenessMargin" "MinimumTextureStd" ...
                "ConsistencyTolerancePixels"];
            for name = scalarNames
                value = defaults.(name);
                if ~isnumeric(value) || ~isscalar(value) || ...
                        ~isfinite(value) || value < 0
                    error("ProjectionDenseTemplateMatcher:invalidOptions", ...
                        "%s must be a finite nonnegative scalar.", name);
                end
                defaults.(name) = double(value);
            end
            if ~islogical(defaults.EnableSubpixel) || ...
                    ~isscalar(defaults.EnableSubpixel) || ...
                    ~isnumeric(defaults.PyramidScales) || ...
                    isempty(defaults.PyramidScales) || ...
                    any(~isfinite(defaults.PyramidScales)) || ...
                    any(defaults.PyramidScales <= 0) || ...
                    any(diff(defaults.PyramidScales) <= 0) || ...
                    defaults.PyramidScales(end) ~= 1
                error("ProjectionDenseTemplateMatcher:invalidOptions", ...
                    "Subpixel and pyramid options are invalid.");
            end
            options = defaults;
        end

        function image = normalizeImage(image, mask)
            image = double(image);
            values = image(mask & isfinite(image));
            if isempty(values) || max(values) <= min(values)
                image(:) = 0;
            else
                image = (image - min(values)) / (max(values) - min(values));
            end
            image(~mask) = NaN;
        end

        function prediction = prediction(container, row, column, options)
            prediction = struct(State="unseeded", ...
                DisparityVectorPixels=[mean(options.HorizontalDisparityRange) ...
                mean(options.VerticalDisparityRange)], ...
                HorizontalSearchRangePixels=options.HorizontalDisparityRange, ...
                VerticalSearchRangePixels=options.VerticalDisparityRange);
            if ~isstruct(container) || ~isfield(container, "Format") || ...
                    string(container.Format) ~= ProjectionDenseSearchPredictor.Format
                return
            end
            regions = container.Regions;
            for index = 1:numel(regions)
                bounds = regions(index).Bounds;
                if column >= bounds(1) && column < bounds(2) && ...
                        row >= bounds(3) && row < bounds(4)
                    prediction = regions(index);
                    return
                end
            end
            prediction.State = "noSupport";
        end

        function value = predictionFormat(container)
            value = "none";
            if isstruct(container) && isfield(container, "Format")
                value = string(container.Format);
            end
        end

        function values = patch(image, row, column, radius)
            values = image((row - radius):(row + radius), ...
                (column - radius):(column + radius));
        end

        function search = search(movingPatch, reference, row, column, ...
                prediction, options, referenceMask)
            horizontal = ceil(prediction.HorizontalSearchRangePixels(1)): ...
                floor(prediction.HorizontalSearchRangePixels(2));
            vertical = ceil(prediction.VerticalSearchRangePixels(1)): ...
                floor(prediction.VerticalSearchRangePixels(2));
            candidates = zeros(0, 3);
            radius = options.PatchRadius;
            for dy = vertical
                for dx = horizontal
                    referenceRow = row - dy;
                    referenceColumn = column - dx;
                    if referenceRow - radius < 1 || ...
                            referenceRow + radius > size(reference, 1) || ...
                            referenceColumn - radius < 1 || ...
                            referenceColumn + radius > size(reference, 2) || ...
                            ~all(referenceMask( ...
                            (referenceRow - radius):(referenceRow + radius), ...
                            (referenceColumn - radius):(referenceColumn + radius)), ...
                            "all")
                        continue
                    end
                    referencePatch = ProjectionDenseTemplateMatcher.patch( ...
                        reference, referenceRow, referenceColumn, radius);
                    candidateScore = ...
                        ProjectionDenseTemplateMatcher.multiScaleCost( ...
                        movingPatch, referencePatch, options.CostMethod, ...
                        options.PyramidScales);
                    candidates(end + 1, :) = ...
                        [dx dy candidateScore]; %#ok<AGROW>
                end
            end
            if isempty(candidates)
                search = struct(CandidateCount=0, BestScore=NaN, ...
                    SecondScore=NaN, TieCount=0, BestDisparity=[NaN NaN], ...
                    Candidates=candidates);
                return
            end
            candidates = sortrows(candidates, [-3 1 2]);
            best = candidates(1, :);
            second = best;
            if size(candidates, 1) > 1
                second = candidates(2, :);
            end
            tolerance = 1e-12;
            search = struct(CandidateCount=size(candidates, 1), ...
                BestScore=best(3), SecondScore=second(3), ...
                TieCount=nnz(abs(candidates(:, 3) - best(3)) <= tolerance), ...
                BestDisparity=best(1:2), Candidates=candidates);
        end

        function value = cost(first, second, method)
            switch method
                case "zncc"
                    first = first - mean(first, "all");
                    second = second - mean(second, "all");
                    value = sum(first .* second, "all") / ...
                        max(norm(first(:)) * norm(second(:)), eps);
                case "gradientCorrelation"
                    [firstX, firstY] = gradient(first);
                    [secondX, secondY] = gradient(second);
                    first = [firstX(:); firstY(:)];
                    second = [secondX(:); secondY(:)];
                    value = dot(first, second) / ...
                        max(norm(first) * norm(second), eps);
                case "censusRank"
                    firstRank = first(:) > median(first, "all");
                    secondRank = second(:) > median(second, "all");
                    value = 1 - nnz(xor(firstRank, secondRank)) / numel(firstRank);
                case "phaseCorrelation"
                    firstFft = fft2(first - mean(first, "all"));
                    secondFft = fft2(second - mean(second, "all"));
                    crossPower = firstFft .* conj(secondFft);
                    crossPower = crossPower ./ max(abs(crossPower), eps);
                    correlation = real(ifft2(crossPower));
                    value = correlation(1, 1);
            end
            if ~isfinite(value)
                value = -Inf;
            end
        end

        function value = multiScaleCost(first, second, method, scales)
            scores = zeros(size(scales));
            for index = 1:numel(scales)
                if scales(index) == 1
                    firstLevel = first;
                    secondLevel = second;
                else
                    firstLevel = imresize(first, scales(index), "bilinear");
                    secondLevel = imresize(second, scales(index), "bilinear");
                end
                scores(index) = ProjectionDenseTemplateMatcher.cost( ...
                    firstLevel, secondLevel, method);
            end
            value = mean(scores);
        end

        function disparity = subpixel(search, options)
            disparity = search.BestDisparity;
            if ~options.EnableSubpixel
                return
            end
            candidates = search.Candidates;
            dx = disparity(1);
            dy = disparity(2);
            left = candidates(candidates(:, 1) == dx - 1 & ...
                candidates(:, 2) == dy, 3);
            right = candidates(candidates(:, 1) == dx + 1 & ...
                candidates(:, 2) == dy, 3);
            if isempty(left) || isempty(right)
                return
            end
            denominator = left(1) - 2 * search.BestScore + right(1);
            if abs(denominator) > eps
                offset = 0.5 * (left(1) - right(1)) / denominator;
                disparity(1) = dx + min(max(offset, -0.5), 0.5);
            end
        end

        function errorPixels = reverseConsistency(reference, moving, ...
                referencePoint, forwardDisparity, options, movingMask)
            radius = options.PatchRadius;
            row = round(referencePoint(2));
            column = round(referencePoint(1));
            if row - radius < 1 || row + radius > size(reference, 1) || ...
                    column - radius < 1 || column + radius > size(reference, 2)
                errorPixels = Inf;
                return
            end
            referencePatch = ProjectionDenseTemplateMatcher.patch( ...
                reference, row, column, radius);
            prediction = struct(HorizontalSearchRangePixels= ...
                -fliplr(options.HorizontalDisparityRange), ...
                VerticalSearchRangePixels= ...
                -fliplr(options.VerticalDisparityRange));
            reverse = ProjectionDenseTemplateMatcher.search(referencePatch, ...
                moving, row, column, prediction, options, movingMask);
            if reverse.CandidateCount == 0
                errorPixels = Inf;
            else
                errorPixels = norm(forwardDisparity + reverse.BestDisparity);
            end
        end

        function [rowValue, columnValue] = mapSource( ...
                rowMap, columnMap, column, row)
            rowValue = interp2(double(rowMap), column, row, "linear", NaN);
            columnValue = interp2(double(columnMap), column, row, "linear", NaN);
        end

        function checkCancellation(runtimeControl)
            if ~isempty(runtimeControl.CancellationFcn) && ...
                    logical(runtimeControl.CancellationFcn())
                error("ProjectionDenseMatcher:cancelled", ...
                    "Dense matching was cancelled cooperatively.");
            end
        end
    end
end
