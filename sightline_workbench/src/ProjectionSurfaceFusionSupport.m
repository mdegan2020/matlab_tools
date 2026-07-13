classdef ProjectionSurfaceFusionSupport
    %ProjectionSurfaceFusionSupport Shared bounded CPU voxel operations.

    methods (Static)
        function [points, rejections] = selectPoints(request)
            %selectPoints Retain valid points inside the bounded world ROI.
            inputPoints = request.PointSet.Points;
            selected = false(1, numel(inputPoints));
            rejections = ProjectionSurfaceFusionResult.emptyRejections();
            for index = 1:numel(inputPoints)
                point = inputPoints(index);
                reason = "";
                if ~point.Valid
                    reason = "invalidMultiRayPoint";
                elseif any(point.PointWorld < request.RoiWorld(:, 1)) || ...
                        any(point.PointWorld > request.RoiWorld(:, 2))
                    reason = "outsideRoi";
                else
                    selected(index) = true;
                end
                if strlength(reason) > 0
                    rejections(end + 1) = struct( ...
                        PointId=string(point.PointId), Reason=reason); %#ok<AGROW>
                end
            end
            points = inputPoints(selected);
        end

        function labels = modeLabels(points)
            %modeLabels Return normalized mode identity for every point.
            labels = strings(1, numel(points));
            for index = 1:numel(points)
                labels(index) = string(points(index).ModeId);
                if strlength(labels(index)) == 0
                    labels(index) = "primary";
                end
            end
        end

        function output = standardPoints(points, worldFrame)
            %standardPoints Map authoritative inputs to fusion-point values.
            output = ProjectionSurfaceFusionResult.emptyPoints();
            for index = 1:numel(points)
                point = points(index);
                output(end + 1) = struct( ...
                    PointId=string(point.PointId), ...
                    PointWorld=double(point.PointWorld), ...
                    ModeId=ProjectionSurfaceFusionSupport.modeId(point), ...
                    CompetingMode=logical(point.CompetingMode), ...
                    State="robustMultiViewReference", ...
                    ContributingPointIds=string(point.PointId), ...
                    ContributingViewIds=reshape( ...
                    string(point.ContributingViewIds), 1, []), ...
                    ContributingPassIds=reshape( ...
                    string(point.ContributingPassIds), 1, []), ...
                    IndependentViewCount=double(point.IndependentViewCount), ...
                    IndependentPassCount=double(point.IndependentPassCount), ...
                    CovarianceWorldMetersSquared=double( ...
                    point.CovarianceWorldMetersSquared), ...
                    CovarianceStatus=string(point.CovarianceStatus), ...
                    CovarianceReason=string(point.CovarianceReason), ...
                    CovarianceFrame=string(worldFrame)); %#ok<AGROW>
            end
        end

        function evidence = hardEvidence(points, request, options, runtimeControl)
            %hardEvidence Accumulate one sparse point-vote voxel hash per mode.
            evidence = struct(Method="hardOccupancy", ...
                ScaleSource=request.VoxelScaleSource, ...
                ScaleResults=ProjectionSurfaceFusionSupport.emptyScaleResults());
            for scaleIndex = 1:numel(request.VoxelScalesMeters)
                ProjectionSurfaceFusionSupport.throwIfCancelled(runtimeControl);
                scale = request.VoxelScalesMeters(scaleIndex);
                gridSize = ProjectionSurfaceFusionSupport.gridSize( ...
                    request.RoiWorld, scale, options.MaximumGridCells);
                modes = ProjectionSurfaceFusionSupport.modes(points);
                labels = ProjectionSurfaceFusionSupport.modeLabels(points);
                modeResults = ProjectionSurfaceFusionSupport.emptyModes();
                for modeIndex = 1:numel(modes)
                    modePoints = points(labels == modes(modeIndex));
                    modeResult = ProjectionSurfaceFusionSupport.accumulateHard( ...
                        modePoints, modes(modeIndex), request, scale, gridSize);
                    modeResults(end + 1) = ProjectionSurfaceFusionSupport. ...
                        castEvidence(modeResult, request.PrecisionPolicy.Evidence); %#ok<AGROW>
                end
                allocated = sum([modeResults.AllocatedVoxelCount]);
                evidence.ScaleResults(end + 1) = struct( ...
                    VoxelScaleMeters=scale, GridSize=gridSize, ...
                    Modes=modeResults, AllocatedVoxelCount=allocated, ...
                    GridCellCount=prod(gridSize));
                ProjectionSurfaceFusionSupport.notifyProgress( ...
                    runtimeControl, scaleIndex / numel(request.VoxelScalesMeters), ...
                    "hardScaleComplete");
            end
        end

        function evidence = gaussianEvidence( ...
                points, request, options, runtimeControl)
            %gaussianEvidence Accumulate normalized uncertainty-weighted splats.
            evidence = struct(Method="gaussianSplat", ...
                ScaleSource=request.VoxelScaleSource, ...
                ScaleResults=ProjectionSurfaceFusionSupport.emptyScaleResults());
            contributionCount = 0;
            for scaleIndex = 1:numel(request.VoxelScalesMeters)
                ProjectionSurfaceFusionSupport.throwIfCancelled(runtimeControl);
                scale = request.VoxelScalesMeters(scaleIndex);
                gridSize = ProjectionSurfaceFusionSupport.gridSize( ...
                    request.RoiWorld, scale, options.MaximumGridCells);
                modes = ProjectionSurfaceFusionSupport.modes(points);
                labels = ProjectionSurfaceFusionSupport.modeLabels(points);
                modeResults = ProjectionSurfaceFusionSupport.emptyModes();
                for modeIndex = 1:numel(modes)
                    modeMask = labels == modes(modeIndex);
                    modePoints = points(modeMask);
                    [modeResult, added] = ...
                        ProjectionSurfaceFusionSupport.accumulateGaussian( ...
                        modePoints, modes(modeIndex), request, scale, ...
                        gridSize, options, ...
                        options.MaximumContributions - contributionCount);
                    contributionCount = contributionCount + added;
                    if contributionCount > options.MaximumContributions
                        error("ProjectionSurfaceFusionSupport:contributionLimit", ...
                            "Gaussian splat contribution limit was exceeded.");
                    end
                    modeResults(end + 1) = ProjectionSurfaceFusionSupport. ...
                        castEvidence(modeResult, request.PrecisionPolicy.Evidence); %#ok<AGROW>
                end
                allocated = sum([modeResults.AllocatedVoxelCount]);
                evidence.ScaleResults(end + 1) = struct( ...
                    VoxelScaleMeters=scale, GridSize=gridSize, ...
                    Modes=modeResults, AllocatedVoxelCount=allocated, ...
                    GridCellCount=prod(gridSize));
                ProjectionSurfaceFusionSupport.notifyProgress( ...
                    runtimeControl, scaleIndex / numel(request.VoxelScalesMeters), ...
                    "gaussianScaleComplete");
            end
        end

        function points = pointsFromEvidence(evidence, inputPoints, request)
            %pointsFromEvidence Convert base-scale peaks into derived points.
            points = ProjectionSurfaceFusionResult.emptyPoints();
            if isempty(evidence.ScaleResults)
                return
            end
            scales = [evidence.ScaleResults.VoxelScaleMeters];
            [~, scaleIndex] = min(abs(scales - request.BaseVoxelScaleMeters));
            scaleResult = evidence.ScaleResults(scaleIndex);
            for modeIndex = 1:numel(scaleResult.Modes)
                mode = scaleResult.Modes(modeIndex);
                peakIndices = find(mode.PeakMask);
                for peakIndex = reshape(peakIndices, 1, [])
                    contributorIds = mode.ContributingPointIds{peakIndex};
                    contributorMask = ismember( ...
                        string({inputPoints.PointId}), contributorIds);
                    contributors = inputPoints(contributorMask);
                    views = ProjectionSurfaceFusionSupport.unionField( ...
                        contributors, "ContributingViewIds");
                    passes = ProjectionSurfaceFusionSupport.unionField( ...
                        contributors, "ContributingPassIds");
                    pointPayload = struct(Method=evidence.Method, ...
                        Scale=scaleResult.VoxelScaleMeters, ...
                        ModeId=mode.ModeId, Index=mode.Indices(peakIndex, :), ...
                        Contributors=contributorIds);
                    pointId = "fusion-point-" + extractBefore( ...
                        ProjectionGeometryFingerprint.hash(pointPayload), 17);
                    variance = scaleResult.VoxelScaleMeters ^ 2 / 12;
                    reason = "voxelQuantizationModel";
                    if evidence.Method == "gaussianSplat"
                        reason = "splatKernelAndVoxelQuantizationModel";
                    end
                    points(end + 1) = struct( ...
                        PointId=pointId, ...
                        PointWorld=mode.CentersWorld(:, peakIndex), ...
                        ModeId=mode.ModeId, ...
                        CompetingMode=numel(scaleResult.Modes) > 1 || ...
                        any([contributors.CompetingMode]), ...
                        State=evidence.Method + "Peak", ...
                        ContributingPointIds=contributorIds, ...
                        ContributingViewIds=views, ...
                        ContributingPassIds=passes, ...
                        IndependentViewCount=numel(views), ...
                        IndependentPassCount=numel(passes), ...
                        CovarianceWorldMetersSquared=variance * eye(3), ...
                        CovarianceStatus="assumed", ...
                        CovarianceReason=reason, ...
                        CovarianceFrame=request.PointSet.WorldFrame); %#ok<AGROW>
                end
            end
        end

        function summary = modeSummary(points)
            %modeSummary Report preserved mode identities and point counts.
            modes = ProjectionSurfaceFusionSupport.modes(points);
            labels = ProjectionSurfaceFusionSupport.modeLabels(points);
            counts = zeros(size(modes));
            for index = 1:numel(modes)
                counts(index) = nnz(labels == modes(index));
            end
            summary = struct(ModeIds=modes, PointCounts=counts, ...
                ModeCount=numel(modes), ...
                CompetingModeCount=nnz([points.CompetingMode]));
        end

        function summary = contributorSummary(inputPoints, fusedPoints)
            %contributorSummary Report independent evidence, never pair count.
            summary = struct(InputPointCount=numel(inputPoints), ...
                OutputPointCount=numel(fusedPoints), ...
                IndependentViewIds=ProjectionSurfaceFusionSupport.unionField( ...
                inputPoints, "ContributingViewIds"), ...
                IndependentPassIds=ProjectionSurfaceFusionSupport.unionField( ...
                inputPoints, "ContributingPassIds"), ...
                EvidencePolicy="uniquePointTracksAndPasses;pairMultiplicityIgnored");
        end

        function bytes = bytes(value)
            %bytes Return serialized value-array memory estimate.
            if isempty(value)
                bytes = 0;
                return
            end
            info = whos("value");
            bytes = double(info.bytes);
        end
    end

    methods (Static, Access = private)
        function modeResult = accumulateHard(points, modeId, request, scale, gridSize)
            accumulator = ProjectionSurfaceFusionSupport.emptyAccumulator();
            for pointIndex = 1:numel(points)
                index = ProjectionSurfaceFusionSupport.pointIndex( ...
                    points(pointIndex).PointWorld, request.RoiWorld, ...
                    scale, gridSize);
                accumulator = ProjectionSurfaceFusionSupport.add( ...
                    accumulator, index, ...
                    ProjectionSurfaceFusionSupport.pointWeight(points(pointIndex)), ...
                    points(pointIndex));
            end
            modeResult = ProjectionSurfaceFusionSupport.finalize( ...
                accumulator, modeId, request.RoiWorld, scale);
        end

        function [modeResult, contributionCount] = accumulateGaussian( ...
                points, modeId, request, scale, gridSize, options, maximumRemaining)
            accumulator = ProjectionSurfaceFusionSupport.emptyAccumulator();
            contributionCount = 0;
            for pointIndex = 1:numel(points)
                point = points(pointIndex);
                covariance = ProjectionSurfaceFusionSupport.kernelCovariance( ...
                    point, scale, options.KernelSigmaFloorVoxels);
                radius = ceil(options.TruncationSigma * ...
                    sqrt(max(diag(covariance))) / scale);
                centerIndex = ProjectionSurfaceFusionSupport.pointIndex( ...
                    point.PointWorld, request.RoiWorld, scale, gridSize);
                lower = max(ones(1, 3), centerIndex - radius);
                upper = min(gridSize, centerIndex + radius);
                maximumSupport = prod(upper - lower + 1);
                if contributionCount + maximumSupport > maximumRemaining
                    error("ProjectionSurfaceFusionSupport:contributionLimit", ...
                        "Gaussian splat contribution limit was exceeded.");
                end
                [first, second, third] = ndgrid( ...
                    lower(1):upper(1), lower(2):upper(2), ...
                    lower(3):upper(3));
                indices = [first(:) second(:) third(:)];
                centers = ProjectionSurfaceFusionSupport.centers( ...
                    indices, request.RoiWorld, scale);
                delta = centers - point.PointWorld;
                inverseCovariance = pinv(covariance);
                exponent = sum(delta .* (inverseCovariance * delta), 1);
                kernel = exp(-0.5 * exponent);
                keep = kernel >= options.MinimumKernelWeight;
                indices = indices(keep, :);
                kernel = kernel(keep);
                kernel = kernel / max(sum(kernel), eps);
                contributions = ProjectionSurfaceFusionSupport.pointWeight(point) * ...
                    kernel;
                if request.PrecisionPolicy.Evidence == "single"
                    contributions = double(single(contributions));
                end
                for contributionIndex = 1:size(indices, 1)
                    accumulator = ProjectionSurfaceFusionSupport.add( ...
                        accumulator, indices(contributionIndex, :), ...
                        contributions(contributionIndex), point);
                end
                contributionCount = contributionCount + size(indices, 1);
            end
            modeResult = ProjectionSurfaceFusionSupport.finalize( ...
                accumulator, modeId, request.RoiWorld, scale);
        end

        function accumulator = emptyAccumulator()
            accumulator = struct(Map=containers.Map( ...
                "KeyType", "char", "ValueType", "double"), ...
                Indices=zeros(0, 3), EvidenceWeights=zeros(0, 1), ...
                PointIds={cell(0, 1)}, ViewIds={cell(0, 1)}, ...
                PassIds={cell(0, 1)});
        end

        function accumulator = add(accumulator, index, weight, point)
            key = ProjectionSurfaceFusionSupport.indexKey(index);
            if isKey(accumulator.Map, key)
                row = accumulator.Map(key);
            else
                row = size(accumulator.Indices, 1) + 1;
                accumulator.Map(key) = row;
                accumulator.Indices(row, :) = index;
                accumulator.EvidenceWeights(row, 1) = 0;
                accumulator.PointIds{row, 1} = strings(1, 0);
                accumulator.ViewIds{row, 1} = strings(1, 0);
                accumulator.PassIds{row, 1} = strings(1, 0);
            end
            accumulator.EvidenceWeights(row) = ...
                accumulator.EvidenceWeights(row) + double(weight);
            accumulator.PointIds{row} = unique([ ...
                accumulator.PointIds{row} string(point.PointId)], "stable");
            accumulator.ViewIds{row} = unique([ ...
                accumulator.ViewIds{row} reshape( ...
                string(point.ContributingViewIds), 1, [])], "stable");
            accumulator.PassIds{row} = unique([ ...
                accumulator.PassIds{row} reshape( ...
                string(point.ContributingPassIds), 1, [])], "stable");
        end

        function mode = finalize(accumulator, modeId, roi, scale)
            [indices, order] = sortrows(accumulator.Indices, [1 2 3]);
            weights = accumulator.EvidenceWeights(order);
            pointIds = accumulator.PointIds(order);
            viewIds = accumulator.ViewIds(order);
            passIds = accumulator.PassIds(order);
            peakMask = ProjectionSurfaceFusionSupport.peakMask(indices, weights);
            mode = struct(ModeId=modeId, Indices=indices, ...
                CentersWorld=ProjectionSurfaceFusionSupport.centers( ...
                indices, roi, scale), EvidenceWeights=weights, ...
                PointCounts=cellfun(@numel, pointIds), ...
                IndependentViewCounts=cellfun(@numel, viewIds), ...
                IndependentPassCounts=cellfun(@numel, passIds), ...
                ContributingPointIds={pointIds}, ...
                ContributingViewIds={viewIds}, ...
                ContributingPassIds={passIds}, PeakMask=peakMask, ...
                AllocatedVoxelCount=size(indices, 1));
        end

        function mask = peakMask(indices, weights)
            count = size(indices, 1);
            mask = true(count, 1);
            lookup = containers.Map("KeyType", "char", "ValueType", "double");
            for index = 1:count
                lookup(ProjectionSurfaceFusionSupport. ...
                    indexKey(indices(index, :))) = index;
            end
            offsets = dec2base(0:26, 3, 3) - '1';
            offsets(all(offsets == 0, 2), :) = [];
            for index = 1:count
                for offsetIndex = 1:size(offsets, 1)
                    neighbor = indices(index, :) + offsets(offsetIndex, :);
                    key = ProjectionSurfaceFusionSupport.indexKey(neighbor);
                    if ~isKey(lookup, key)
                        continue
                    end
                    neighborIndex = lookup(key);
                    tolerance = eps(max([weights(index) ...
                        weights(neighborIndex) 1]));
                    if weights(neighborIndex) > weights(index) + tolerance || ...
                            (abs(weights(neighborIndex) - weights(index)) <= ...
                            tolerance && neighborIndex < index)
                        mask(index) = false;
                        break
                    end
                end
            end
        end

        function covariance = kernelCovariance(point, scale, floorVoxels)
            covariance = double(point.CovarianceWorldMetersSquared);
            if any(~isfinite(covariance), "all") || ...
                    any(eig(0.5 * (covariance + covariance.')) < -1e-10)
                covariance = zeros(3);
            end
            covariance = 0.5 * (covariance + covariance.') + ...
                (floorVoxels * scale) ^ 2 * eye(3);
        end

        function mode = castEvidence(mode, precision)
            if precision == "single"
                mode.EvidenceWeights = single(mode.EvidenceWeights);
            else
                mode.EvidenceWeights = double(mode.EvidenceWeights);
            end
        end

        function weight = pointWeight(point)
            weight = max(1, double(point.IndependentPassCount));
        end

        function value = modeId(point)
            value = string(point.ModeId);
            if strlength(value) == 0
                value = "primary";
            end
        end

        function modes = modes(points)
            if isempty(points)
                modes = strings(1, 0);
                return
            end
            modes = sort(unique( ...
                ProjectionSurfaceFusionSupport.modeLabels(points)));
        end

        function gridSize = gridSize(roi, scale, maximumCells)
            gridSize = max(1, ceil((roi(:, 2) - roi(:, 1)).' / scale));
            if prod(gridSize) > maximumCells
                error("ProjectionSurfaceFusionSupport:gridLimit", ...
                    "Bounded ROI grid exceeds MaximumGridCells.");
            end
        end

        function index = pointIndex(point, roi, scale, gridSize)
            index = floor((point - roi(:, 1)) / scale).' + 1;
            index = min(max(index, ones(1, 3)), gridSize);
        end

        function values = centers(indices, roi, scale)
            if isempty(indices)
                values = zeros(3, 0);
                return
            end
            offsets = (double(indices).' - 0.5) * scale;
            span = roi(:, 2) - roi(:, 1);
            values = roi(:, 1) + min(offsets, span);
        end

        function key = indexKey(index)
            key = sprintf("%d,%d,%d", index(1), index(2), index(3));
        end

        function values = unionField(points, field)
            values = strings(1, 0);
            for index = 1:numel(points)
                values = unique([values reshape( ...
                    string(points(index).(field)), 1, [])], "stable");
            end
            values = sort(values);
        end

        function throwIfCancelled(runtimeControl)
            if ~isempty(runtimeControl.CancellationFcn) && ...
                    logical(runtimeControl.CancellationFcn())
                error("ProjectionSurfaceFusionAlgorithm:cancelled", ...
                    "Surface fusion was cancelled cooperatively.");
            end
        end

        function notifyProgress(runtimeControl, fraction, stage)
            if ~isempty(runtimeControl.ProgressFcn)
                runtimeControl.ProgressFcn(struct( ...
                    Fraction=double(fraction), Stage=string(stage)));
            end
        end

        function scales = emptyScaleResults()
            scales = struct("VoxelScaleMeters", {}, "GridSize", {}, ...
                "Modes", {}, "AllocatedVoxelCount", {}, ...
                "GridCellCount", {});
        end

        function modes = emptyModes()
            modes = struct("ModeId", {}, "Indices", {}, ...
                "CentersWorld", {}, "EvidenceWeights", {}, ...
                "PointCounts", {}, "IndependentViewCounts", {}, ...
                "IndependentPassCounts", {}, "ContributingPointIds", {}, ...
                "ContributingViewIds", {}, "ContributingPassIds", {}, ...
                "PeakMask", {}, "AllocatedVoxelCount", {});
        end
    end
end
