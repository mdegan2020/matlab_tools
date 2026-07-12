classdef ProjectionAlignmentParameterModel
    %ProjectionAlignmentParameterModel Explicit bounded alignment parameters.

    methods (Static)
        function model = create(scene, matchResult, layerIndices, ...
                startCorrections, options)
            options = ProjectionAlignmentOptions.validate(options);
            layerIndices = reshape(double(layerIndices), 1, []);
            layerCount = numel(layerIndices);
            model = struct();
            model.LayerIndices = layerIndices;
            model.LayerIds = string([startCorrections.LayerId]);
            model.LayerCount = layerCount;
            model.ReferenceLayerIndex = ...
                ProjectionAlignmentParameterModel.referenceLayerIndex( ...
                scene, matchResult, layerIndices, options);
            model.StartCorrections = startCorrections;
            model.Options = options;

            model.OpkIndices = reshape(1:(3 * layerCount), 3, []).';
            startOpk = reshape( ...
                [startCorrections.ViewVectorAngularOffsetsDegrees], 3, []).';
            model.PointingSigmaDegrees = ...
                ProjectionAlignmentParameterModel.pointingSigmas( ...
                model.LayerIds, options.PointingPriors);
            parameterNames = ["omega", "phi", "kappa"];
            activeOpk = ismember(parameterNames, ...
                options.MovableParameters.Parameters);
            model.ActiveOpkMask = repmat(activeOpk, layerCount, 1);
            if ~options.MovableParameters.AllowReferenceMotion
                referencePosition = find(layerIndices == ...
                    model.ReferenceLayerIndex, 1, "first");
                model.ActiveOpkMask(referencePosition, :) = false;
            end
            model.BoundsDegrees = zeros(layerCount, 3);
            for k = 1:layerCount
                model.BoundsDegrees(k, :) = ...
                    ProjectionAlignmentParameterModel.layerOpkBounds( ...
                    scene.layers(layerIndices(k)), options.Bounds);
            end
            model.BoundsDegrees(~model.ActiveOpkMask) = 0;

            x0 = startOpk.';
            x0 = x0(:);
            bounds = model.BoundsDegrees.';
            bounds = bounds(:);
            labels = strings(numel(x0), 1);
            for k = 1:layerCount
                for p = 1:3
                    labels(model.OpkIndices(k, p)) = ...
                        "layer:" + model.LayerIds(k) + ":" + ...
                        parameterNames(p);
                end
            end

            model.OffsetIndices = zeros(layerCount, 2);
            model.OffsetBoundsMeters = zeros(layerCount, 2);
            model.ActiveOffsetMask = false(layerCount, 2);
            includeOffsets = options.MovableParameters.IncludeProjectionOffsets;
            if includeOffsets
                offsetStartIndex = numel(x0) + 1;
                model.OffsetIndices = reshape( ...
                    offsetStartIndex:(offsetStartIndex + 2 * layerCount - 1), ...
                    2, []).';
                startOffsets = reshape( ...
                    [startCorrections.ProjectionOffsetMeters], 2, []).';
                x0 = [x0; reshape(startOffsets.', [], 1)];
                activeOffsets = ismember(["projectionOffsetX", ...
                    "projectionOffsetY"], ...
                    options.MovableParameters.Parameters);
                model.ActiveOffsetMask = repmat(activeOffsets, layerCount, 1);
                if ~options.MovableParameters.AllowReferenceMotion
                    referencePosition = find(layerIndices == ...
                        model.ReferenceLayerIndex, 1, "first");
                    model.ActiveOffsetMask(referencePosition, :) = false;
                end
                for k = 1:layerCount
                    model.OffsetBoundsMeters(k, :) = ...
                        ProjectionAlignmentParameterModel.layerOffsetBounds( ...
                        scene.layers(layerIndices(k)), options.Bounds);
                end
                model.OffsetBoundsMeters(~model.ActiveOffsetMask) = 0;
                bounds = [bounds; reshape(model.OffsetBoundsMeters.', [], 1)];
                offsetNames = ["projectionOffsetX", "projectionOffsetY"];
                for k = 1:layerCount
                    for p = 1:2
                        labels(model.OffsetIndices(k, p)) = ...
                            "layer:" + model.LayerIds(k) + ":" + ...
                            offsetNames(p);
                    end
                end
            end

            model.SharedScaleIndex = 0;
            if options.MovableParameters.IncludeSharedScale
                model.SharedScaleIndex = numel(x0) + 1;
                x0(end + 1, 1) = 1;
                bounds(end + 1, 1) = NaN;
                labels(end + 1, 1) = "sharedScale";
            end
            model.X0 = x0;
            model.LowerBounds = x0 - bounds;
            model.UpperBounds = x0 + bounds;
            if model.SharedScaleIndex > 0
                model.LowerBounds(model.SharedScaleIndex) = ...
                    options.Bounds.SharedScale(1);
                model.UpperBounds(model.SharedScaleIndex) = ...
                    options.Bounds.SharedScale(2);
            end
            model.ParameterLabels = labels;
        end

        function [corrections, sharedScale] = corrections(model, x)
            opk = reshape(x(model.OpkIndices.'), 3, []).';
            sharedScale = 1;
            if model.SharedScaleIndex > 0
                sharedScale = x(model.SharedScaleIndex);
            end
            for k = 1:model.LayerCount
                correction = model.StartCorrections(k);
                correction.ViewVectorAngularOffsetsDegrees = opk(k, :);
                if any(model.OffsetIndices(k, :) > 0)
                    correction.ProjectionOffsetMeters = ...
                        reshape(x(model.OffsetIndices(k, :)), 1, []);
                end
                correction.SharedScale = sharedScale;
                if k == 1
                    corrections = correction;
                else
                    corrections(k) = correction;
                end
            end
        end

        function residuals = regularizationResiduals(model, x)
            options = model.Options;
            regularization = options.Regularization;
            startOpk = reshape( ...
                [model.StartCorrections.ViewVectorAngularOffsetsDegrees], ...
                3, []).';
            opk = reshape(x(model.OpkIndices.'), 3, []).';
            parameterWeights = [regularization.OmegaWeight, ...
                regularization.PhiWeight, regularization.KappaWeight];
            weights = sqrt(regularization.OverallWeight) .* ...
                sqrt(parameterWeights) ./ model.PointingSigmaDegrees;
            residuals = (opk - startOpk) .* weights;
            residuals = residuals(:);
            if any(model.OffsetIndices(:) > 0)
                startOffsets = reshape( ...
                    [model.StartCorrections.ProjectionOffsetMeters], 2, []).';
                offsets = reshape(x(model.OffsetIndices.'), 2, []).';
                offsetWeight = sqrt(regularization.OverallWeight) * ...
                    sqrt(regularization.ProjectionOffsetWeight);
                residuals = [residuals; ...
                    reshape((offsets - startOffsets) * offsetWeight, [], 1)];
            end
            if model.SharedScaleIndex > 0
                scaleWeight = sqrt(regularization.OverallWeight) * ...
                    sqrt(regularization.SharedScaleWeight);
                residuals = [residuals; ...
                    (x(model.SharedScaleIndex) - 1) * scaleWeight];
            end
        end

        function diagnostics = decomposition(model, x)
            [corrections, ~] = ...
                ProjectionAlignmentParameterModel.corrections(model, x);
            startOpk = reshape( ...
                [model.StartCorrections.ViewVectorAngularOffsetsDegrees], ...
                3, []).';
            solvedOpk = reshape( ...
                [corrections.ViewVectorAngularOffsetsDegrees], 3, []).';
            delta = solvedOpk - startOpk;
            precision = 1 ./ model.PointingSigmaDegrees.^2;
            common = sum(precision .* delta, 1) ./ sum(precision, 1);
            diagnostics = struct();
            diagnostics.Model = "commonPlusDifferential";
            diagnostics.LayerIndices = model.LayerIndices;
            diagnostics.LayerIds = model.LayerIds;
            diagnostics.ReferenceLayerIndex = model.ReferenceLayerIndex;
            diagnostics.AllowReferenceMotion = ...
                model.Options.MovableParameters.AllowReferenceMotion;
            diagnostics.PointingSigmaDegrees = model.PointingSigmaDegrees;
            diagnostics.PriorPrecision = precision;
            diagnostics.LayerDeltaDegrees = delta;
            diagnostics.CommonDeltaDegrees = common;
            diagnostics.DifferentialDeltaDegrees = delta - common;
        end

        function [transform, labels, priorSupported, fixed] = ...
                modeTransform(model)
            transform = zeros(numel(model.X0), 0);
            labels = strings(1, 0);
            priorSupported = false(1, 0);
            fixed = false(1, 0);
            names = ["omega", "phi", "kappa"];
            regularization = model.Options.Regularization;
            parameterWeights = [regularization.OmegaWeight, ...
                regularization.PhiWeight, regularization.KappaWeight];
            for p = 1:3
                active = model.ActiveOpkMask(:, p);
                activePositions = find(active);
                hasPrior = regularization.OverallWeight > 0 && ...
                    parameterWeights(p) > 0;
                if isempty(activePositions)
                    [transform, labels, priorSupported, fixed] = ...
                        ProjectionAlignmentParameterModel.appendMode( ...
                        transform, labels, priorSupported, fixed, ...
                        zeros(numel(model.X0), 1), "common." + names(p), ...
                        hasPrior, true);
                    continue
                end
                if model.Options.MovableParameters.AllowReferenceMotion && ...
                        numel(activePositions) == model.LayerCount
                    column = zeros(numel(model.X0), 1);
                    column(model.OpkIndices(:, p)) = 1;
                    [transform, labels, priorSupported, fixed] = ...
                        ProjectionAlignmentParameterModel.appendMode( ...
                        transform, labels, priorSupported, fixed, column, ...
                        "common." + names(p), hasPrior, false);
                    precision = 1 ./ model.PointingSigmaDegrees(:, p).^2;
                    anchor = activePositions(end);
                    for q = reshape(activePositions(1:end-1), 1, [])
                        column = zeros(numel(model.X0), 1);
                        column(model.OpkIndices(q, p)) = 1;
                        column(model.OpkIndices(anchor, p)) = ...
                            -precision(q) / precision(anchor);
                        label = "differential." + names(p) + "." + ...
                            model.LayerIds(q) + "_vs_" + model.LayerIds(anchor);
                        [transform, labels, priorSupported, fixed] = ...
                            ProjectionAlignmentParameterModel.appendMode( ...
                            transform, labels, priorSupported, fixed, column, ...
                            label, hasPrior, false);
                    end
                else
                    for q = reshape(activePositions, 1, [])
                        column = zeros(numel(model.X0), 1);
                        column(model.OpkIndices(q, p)) = 1;
                        label = "differential." + names(p) + "." + ...
                            model.LayerIds(q);
                        [transform, labels, priorSupported, fixed] = ...
                            ProjectionAlignmentParameterModel.appendMode( ...
                            transform, labels, priorSupported, fixed, column, ...
                            label, hasPrior, false);
                    end
                end
            end
            if any(model.OffsetIndices(:) > 0)
                for k = 1:model.LayerCount
                    for p = 1:2
                        if ~model.ActiveOffsetMask(k, p)
                            continue
                        end
                        column = zeros(numel(model.X0), 1);
                        column(model.OffsetIndices(k, p)) = 1;
                        label = "layerOffset." + string(p) + "." + ...
                            model.LayerIds(k);
                        [transform, labels, priorSupported, fixed] = ...
                            ProjectionAlignmentParameterModel.appendMode( ...
                            transform, labels, priorSupported, fixed, column, ...
                            label, regularization.OverallWeight > 0 && ...
                            regularization.ProjectionOffsetWeight > 0, false);
                    end
                end
            end
            if model.SharedScaleIndex > 0
                column = zeros(numel(model.X0), 1);
                column(model.SharedScaleIndex) = 1;
                [transform, labels, priorSupported, fixed] = ...
                    ProjectionAlignmentParameterModel.appendMode( ...
                    transform, labels, priorSupported, fixed, column, ...
                    "sharedScale", regularization.OverallWeight > 0 && ...
                    regularization.SharedScaleWeight > 0, false);
            end
        end

        function diagnostics = boundDiagnostics(model, corrections, sharedScale)
            parameterNames = ["omega", "phi", "kappa"];
            layers = struct("LayerIndex", {}, "LayerId", {}, ...
                "Parameters", {}, "DeltaDegrees", {}, "BoundsDegrees", {}, ...
                "HitMask", {}, "HitParameters", {}, ...
                "ProjectionOffsetDeltaMeters", {}, ...
                "ProjectionOffsetBoundsMeters", {}, ...
                "ProjectionOffsetHitMask", {}, "Any", {});
            for k = 1:model.LayerCount
                startOpk = model.StartCorrections(k). ...
                    ViewVectorAngularOffsetsDegrees(:).';
                solvedOpk = corrections(k). ...
                    ViewVectorAngularOffsetsDegrees(:).';
                delta = solvedOpk - startOpk;
                opkHit = ProjectionAlignmentParameterModel.hitMask( ...
                    delta, model.BoundsDegrees(k, :), model.ActiveOpkMask(k, :));
                offsetDelta = corrections(k).ProjectionOffsetMeters - ...
                    model.StartCorrections(k).ProjectionOffsetMeters;
                offsetHit = ProjectionAlignmentParameterModel.hitMask( ...
                    offsetDelta, model.OffsetBoundsMeters(k, :), ...
                    model.ActiveOffsetMask(k, :));
                layers(k).LayerIndex = model.LayerIndices(k);
                layers(k).LayerId = model.LayerIds(k);
                layers(k).Parameters = parameterNames;
                layers(k).DeltaDegrees = delta;
                layers(k).BoundsDegrees = model.BoundsDegrees(k, :);
                layers(k).HitMask = opkHit;
                layers(k).HitParameters = parameterNames(opkHit);
                layers(k).ProjectionOffsetDeltaMeters = offsetDelta;
                layers(k).ProjectionOffsetBoundsMeters = ...
                    model.OffsetBoundsMeters(k, :);
                layers(k).ProjectionOffsetHitMask = offsetHit;
                layers(k).Any = any(opkHit) || any(offsetHit);
            end
            sharedHit = false;
            if model.SharedScaleIndex > 0
                tolerance = max(1e-10, 1e-6 * max(abs( ...
                    model.Options.Bounds.SharedScale)));
                sharedHit = abs(sharedScale - ...
                    model.Options.Bounds.SharedScale(1)) <= tolerance || ...
                    abs(sharedScale - ...
                    model.Options.Bounds.SharedScale(2)) <= tolerance;
            end
            diagnostics = struct(Layers=layers, SharedScaleHit=sharedHit, ...
                Any=any([layers.Any]) || sharedHit);
        end
    end

    methods (Static, Access = private)
        function index = referenceLayerIndex( ...
                scene, matchResult, layerIndices, options)
            if options.Network.Enabled && ...
                    options.Network.GaugePolicy == "fixedReference"
                viewIds = strings(1, numel(scene.layers));
                for layerIndex = 1:numel(scene.layers)
                    if isfield(scene.layers(layerIndex), "ViewId")
                        viewIds(layerIndex) = ...
                            string(scene.layers(layerIndex).ViewId);
                    end
                end
                index = find(viewIds == ...
                    options.Network.FixedReferenceViewId, 1, "first");
                if isempty(index) || ~ismember(index, layerIndices)
                    error("ProjectionAlignmentParameterModel:unknownFixedReference", ...
                        "FixedReferenceViewId is not part of the network solve.");
                end
                return
            end
            index = layerIndices(ceil(numel(layerIndices) / 2));
            if isfield(matchResult, "Schedule") && ...
                    isfield(matchResult.Schedule, "ReferenceLayerIndex") && ...
                    ismember(matchResult.Schedule.ReferenceLayerIndex, layerIndices)
                index = double(matchResult.Schedule.ReferenceLayerIndex);
            end
        end

        function sigma = pointingSigmas(layerIds, priors)
            sigma = repmat(priors.DefaultSigmaDegrees, numel(layerIds), 1);
            for k = 1:numel(priors.LayerIds)
                position = find(layerIds == priors.LayerIds(k), 1, "first");
                if isempty(position)
                    error("ProjectionAlignmentParameterModel:unknownPriorLayer", ...
                        "Pointing prior LayerId %s is not part of the solve.", ...
                        priors.LayerIds(k));
                end
                sigma(position, :) = priors.SigmaDegrees(k, :);
            end
        end

        function bounds = layerOpkBounds(layer, options)
            fovBound = ProjectionAlignmentParameterModel.fovBoundDegrees( ...
                layer, options);
            values = {options.OmegaDegrees, options.PhiDegrees, ...
                options.KappaDegrees};
            bounds = zeros(1, 3);
            for k = 1:3
                if isempty(values{k})
                    bounds(k) = fovBound;
                else
                    bounds(k) = values{k};
                end
            end
        end

        function bound = fovBoundDegrees(layer, options)
            geometry = layer.SourceGeometry;
            imageSize = double(geometry.ImageSize);
            nominalRange = ProjectionAlignmentParameterModel. ...
                positiveScalarOrDefault(geometry, "NominalRange", 1);
            gsd = ProjectionAlignmentParameterModel.positiveScalarOrDefault( ...
                geometry, "GSD", 1);
            platformStep = ProjectionAlignmentParameterModel. ...
                positiveScalarOrDefault(geometry, "PlatformStepMeters", gsd);
            verticalFov = rad2deg(imageSize(1) * gsd / nominalRange);
            horizontalFov = rad2deg(imageSize(2) * platformStep / nominalRange);
            bound = max(options.FieldOfViewFraction * ...
                min(verticalFov, horizontalFov), 1e-6);
        end

        function bounds = layerOffsetBounds(layer, options)
            if ~isempty(options.ProjectionOffsetMeters)
                bounds = options.ProjectionOffsetMeters;
                return
            end
            geometry = layer.SourceGeometry;
            imageSize = double(geometry.ImageSize);
            gsd = ProjectionAlignmentParameterModel.positiveScalarOrDefault( ...
                geometry, "GSD", 1);
            platformStep = ProjectionAlignmentParameterModel. ...
                positiveScalarOrDefault(geometry, "PlatformStepMeters", gsd);
            bounds = options.FieldOfViewFraction * ...
                [imageSize(2) * platformStep, imageSize(1) * gsd];
        end

        function value = positiveScalarOrDefault(source, fieldName, defaultValue)
            value = defaultValue;
            if isfield(source, fieldName) && isnumeric(source.(fieldName)) && ...
                    isscalar(source.(fieldName)) && ...
                    isfinite(source.(fieldName)) && source.(fieldName) > 0
                value = double(source.(fieldName));
            end
        end

        function [transform, labels, priorSupported, fixed] = appendMode( ...
                transform, labels, priorSupported, fixed, column, label, ...
                hasPrior, isFixed)
            transform(:, end + 1) = column;
            labels(end + 1) = label;
            priorSupported(end + 1) = hasPrior;
            fixed(end + 1) = isFixed;
        end

        function mask = hitMask(delta, bounds, active)
            tolerance = max(1e-8, 1e-6 * max(bounds, 1));
            mask = active & abs(abs(delta) - bounds) <= tolerance;
        end
    end
end
