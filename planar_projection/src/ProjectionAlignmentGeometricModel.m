classdef ProjectionAlignmentGeometricModel
    %ProjectionAlignmentGeometricModel Deterministic robust 2-D model fit.

    methods (Static)
        function result = fit(movingPoints, referencePoints, method, options)
            %fit Map moving to reference working-pixel coordinates.
            if nargin < 4
                options = struct();
            end
            [movingPoints, referencePoints, method, options] = ...
                ProjectionAlignmentGeometricModel.validateInputs( ...
                movingPoints, referencePoints, method, options);
            count = size(movingPoints, 1);
            result = ProjectionAlignmentGeometricModel.empty(method, count);
            finiteMask = all(isfinite(movingPoints), 2) & ...
                all(isfinite(referencePoints), 2);
            result.FiniteMask = finiteMask;
            result.AcceptedMask = finiteMask;
            if method == "none"
                result.Status = "disabled";
                return
            end

            minimumCount = ProjectionAlignmentGeometricModel.minimumCount(method);
            finiteIndices = find(finiteMask);
            if numel(finiteIndices) < minimumCount
                result.Status = "insufficientPoints";
                result.AcceptedMask = finiteMask;
                return
            end

            moving = movingPoints(finiteMask, :);
            reference = referencePoints(finiteMask, :);
            sampleSets = ProjectionAlignmentGeometricModel.hypothesisSamples( ...
                size(moving, 1), minimumCount, options.MaxHypotheses);
            bestMatrix = [];
            bestScore = [Inf Inf Inf Inf];
            validHypothesisCount = 0;
            for k = 1:size(sampleSets, 1)
                [candidate, isValid] = ...
                    ProjectionAlignmentGeometricModel.leastSquaresModel( ...
                    moving(sampleSets(k, :), :), ...
                    reference(sampleSets(k, :), :), method);
                if ~isValid
                    continue
                end
                validHypothesisCount = validHypothesisCount + 1;
                residuals = ProjectionAlignmentGeometricModel.residuals( ...
                    moving, reference, candidate);
                hypothesisInliers = residuals <= options.MaxDistancePixels;
                if any(hypothesisInliers)
                    inlierMedian = median(residuals(hypothesisInliers));
                else
                    inlierMedian = Inf;
                end
                modelPenalty = norm(candidate(1:2, 1:2) - eye(2), "fro");
                score = [-nnz(hypothesisInliers), inlierMedian, ...
                    median(residuals), modelPenalty];
                if ProjectionAlignmentGeometricModel.scoreIsBetter( ...
                        score, bestScore)
                    bestScore = score;
                    bestMatrix = candidate;
                end
            end
            result.HypothesisCount = validHypothesisCount;
            result.InitialRobustScore = bestScore;
            if isempty(bestMatrix)
                result.Status = "degenerateGeometry";
                result.AcceptedMask(:) = false;
                return
            end

            matrix = bestMatrix;
            for iteration = 1:options.RefinementIterations
                residuals = ProjectionAlignmentGeometricModel.residuals( ...
                    moving, reference, matrix);
                inlierMask = residuals <= options.MaxDistancePixels;
                if nnz(inlierMask) < minimumCount
                    break
                end
                [refined, isValid] = ...
                    ProjectionAlignmentGeometricModel.leastSquaresModel( ...
                    moving(inlierMask, :), reference(inlierMask, :), method);
                if ~isValid
                    break
                end
                matrix = refined;
            end

            finiteResiduals = ProjectionAlignmentGeometricModel.residuals( ...
                moving, reference, matrix);
            acceptedFinite = finiteResiduals <= options.MaxDistancePixels;
            result.Status = "fitted";
            result.ModelMatrix = matrix;
            result.Residuals(finiteMask) = finiteResiduals;
            result.AcceptedMask(:) = false;
            result.AcceptedMask(finiteIndices(acceptedFinite)) = true;
            result.ThresholdPixels = options.MaxDistancePixels;
            result.AcceptedCount = nnz(result.AcceptedMask);
            result.RejectedCount = count - result.AcceptedCount;
            if any(acceptedFinite)
                acceptedResiduals = finiteResiduals(acceptedFinite);
                result.RmsAcceptedPixels = sqrt(mean(acceptedResiduals.^2));
                result.MaxAcceptedResidualPixels = max(acceptedResiduals);
            end
        end

        function result = empty(method, count)
            %empty Return a stable diagnostic result shape.
            if nargin < 1
                method = "none";
            end
            if nargin < 2
                count = 0;
            end
            result = struct(Method=string(method), ...
                CoordinateSpace="workingPixels", ...
                Direction="movingToReference", Deterministic=true, ...
                Status="notRun", ModelMatrix=nan(3), ...
                Residuals=nan(count, 1), FiniteMask=false(count, 1), ...
                AcceptedMask=false(count, 1), ThresholdPixels=NaN, ...
                AcceptedCount=0, RejectedCount=0, HypothesisCount=0, ...
                InitialRobustScore=[NaN NaN NaN NaN], ...
                RmsAcceptedPixels=NaN, MaxAcceptedResidualPixels=NaN);
        end
    end

    methods (Static, Access = private)
        function [moving, reference, method, options] = validateInputs( ...
                moving, reference, method, options)
            if ~isnumeric(moving) || ~ismatrix(moving) || ...
                    size(moving, 2) ~= 2 || ~isnumeric(reference) || ...
                    ~isequal(size(reference), size(moving))
                error("ProjectionAlignmentGeometricModel:invalidPoints", ...
                    "Moving and reference points must be equal-size numeric Nx2 arrays.");
            end
            moving = double(moving);
            reference = double(reference);
            method = lower(string(method));
            if ~isscalar(method) || ...
                    ~ismember(method, ["none", "similarity", "affine"])
                error("ProjectionAlignmentGeometricModel:invalidMethod", ...
                    "Method must be none, similarity, or affine.");
            end
            if isempty(options)
                options = struct();
            end
            if ~isstruct(options) || ~isscalar(options)
                error("ProjectionAlignmentGeometricModel:invalidOptions", ...
                    "Options must be a scalar struct.");
            end
            defaults = struct(MaxDistancePixels=3, MaxHypotheses=512, ...
                RefinementIterations=3);
            names = fieldnames(options);
            for k = 1:numel(names)
                defaults.(names{k}) = options.(names{k});
            end
            if ~isnumeric(defaults.MaxDistancePixels) || ...
                    ~isscalar(defaults.MaxDistancePixels) || ...
                    ~isfinite(defaults.MaxDistancePixels) || ...
                    defaults.MaxDistancePixels <= 0 || ...
                    ~isnumeric(defaults.MaxHypotheses) || ...
                    ~isscalar(defaults.MaxHypotheses) || ...
                    fix(defaults.MaxHypotheses) ~= defaults.MaxHypotheses || ...
                    defaults.MaxHypotheses < 1 || ...
                    ~isnumeric(defaults.RefinementIterations) || ...
                    ~isscalar(defaults.RefinementIterations) || ...
                    fix(defaults.RefinementIterations) ~= ...
                    defaults.RefinementIterations || ...
                    defaults.RefinementIterations < 0
                error("ProjectionAlignmentGeometricModel:invalidOptions", ...
                    "Threshold, hypothesis count, or refinement count is invalid.");
            end
            options = defaults;
        end

        function count = minimumCount(method)
            if method == "affine"
                count = 3;
            else
                count = 2;
            end
        end

        function samples = hypothesisSamples(count, sampleSize, maximumCount)
            baseCount = min(count, max(1, floor(maximumCount / 4)));
            bases = unique(round(linspace(1, count, baseCount)), "stable");
            if sampleSize == 2
                fractions = [0.17 0.31 0.47 0.63];
                samples = zeros(numel(bases) * numel(fractions), 2);
                cursor = 0;
                for base = reshape(bases, 1, [])
                    for fraction = fractions
                        cursor = cursor + 1;
                        offset = max(1, round(fraction * count));
                        samples(cursor, :) = [base, ...
                            mod(base - 1 + offset, count) + 1];
                    end
                end
            else
                fractions = [0.17 0.47; 0.31 0.67; ...
                    0.13 0.73; 0.41 0.83];
                samples = zeros(numel(bases) * size(fractions, 1), 3);
                cursor = 0;
                for base = reshape(bases, 1, [])
                    for k = 1:size(fractions, 1)
                        cursor = cursor + 1;
                        offsets = max(1, round(fractions(k, :) * count));
                        samples(cursor, :) = [base, ...
                            mod(base - 1 + offsets, count) + 1];
                    end
                end
            end
            samples = sort(samples(1:cursor, :), 2);
            samples = unique(samples, "rows", "stable");
            samples = samples(all(diff(samples, 1, 2) > 0, 2), :);
            if size(samples, 1) > maximumCount
                samples = samples(1:maximumCount, :);
            end
        end

        function [matrix, isValid] = leastSquaresModel( ...
                moving, reference, method)
            count = size(moving, 1);
            if method == "similarity"
                x = moving(:, 1);
                y = moving(:, 2);
                design = zeros(2 * count, 4);
                design(1:2:end, :) = [x -y ones(count, 1) zeros(count, 1)];
                design(2:2:end, :) = [y x zeros(count, 1) ones(count, 1)];
                values = reshape(reference.', [], 1);
                isValid = rank(design) == 4;
                if isValid
                    parameters = design \ values;
                    matrix = [parameters(1) -parameters(2) parameters(3); ...
                        parameters(2) parameters(1) parameters(4); 0 0 1];
                else
                    matrix = [];
                end
            else
                design = [moving ones(count, 1)];
                isValid = rank(design) == 3;
                if isValid
                    parameters = design \ reference;
                    matrix = [parameters(:, 1).'; parameters(:, 2).'; 0 0 1];
                else
                    matrix = [];
                end
            end
        end

        function residuals = residuals(moving, reference, matrix)
            predicted = (matrix(1:2, 1:2) * moving.' + ...
                matrix(1:2, 3)).';
            residuals = sqrt(sum((predicted - reference).^2, 2));
        end

        function tf = scoreIsBetter(score, bestScore)
            difference = score - bestScore;
            firstDifference = find(abs(difference) > 1e-12, 1, "first");
            tf = ~isempty(firstDifference) && difference(firstDifference) < 0;
        end
    end
end
