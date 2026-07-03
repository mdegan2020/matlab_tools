classdef ProjectionAlignmentOpkSolver
    %ProjectionAlignmentOpkSolver Solve pairwise OPK alignment corrections.

    methods (Static)
        function result = solve(scene, matchResult, options)
            %solve Estimate per-layer omega/phi/kappa corrections.
            if nargin < 3
                options = struct();
            end
            ProjectionAlignmentOpkSolver.validateScene(scene);
            ProjectionAlignmentOpkSolver.validateMatchResult(matchResult);
            options = ProjectionAlignmentOptions.validate(options);
            if exist("lsqnonlin", "file") ~= 2
                error("ProjectionAlignmentOpkSolver:missingOptimizer", ...
                    "lsqnonlin is required for OPK alignment solving.");
            end

            timer = tic;
            layerIndices = ProjectionAlignmentOpkSolver.matchLayerIndices(matchResult);
            startCorrections = ProjectionAlignmentOpkSolver.layerCorrections( ...
                scene, layerIndices);
            [x0, lowerBounds, upperBounds, boundsDegrees] = ...
                ProjectionAlignmentOpkSolver.variableBounds( ...
                scene, layerIndices, startCorrections, options);
            commonPlane = scene.layers(layerIndices(1)).CurrentProjectionPlane;
            residualFcn = @(x) ProjectionAlignmentOpkSolver.residualVector( ...
                x, scene, matchResult, layerIndices, startCorrections, ...
                commonPlane, options);
            beforeResiduals = ProjectionAlignmentOpkSolver.dataResiduals( ...
                x0, scene, matchResult, layerIndices, commonPlane);

            solverOptions = optimoptions("lsqnonlin", Display="off", ...
                MaxIterations=100, FunctionTolerance=1e-10, StepTolerance=1e-10);
            [xSolved, residual, ~, exitFlag, output] = lsqnonlin( ...
                residualFcn, x0, lowerBounds, upperBounds, solverOptions);
            afterResiduals = ProjectionAlignmentOpkSolver.dataResiduals( ...
                xSolved, scene, matchResult, layerIndices, commonPlane);
            perPairResiduals = ProjectionAlignmentOpkSolver.residualPairs( ...
                x0, xSolved, scene, matchResult, layerIndices, commonPlane);

            result = ProjectionAlignmentOpkSolver.resultStruct( ...
                matchResult, layerIndices, startCorrections, xSolved, ...
                beforeResiduals, afterResiduals, perPairResiduals, residual, ...
                exitFlag, output, boundsDegrees, toc(timer));
            result = ProjectionAlignmentResult.validate(result);
        end

        function alignedScene = applyCorrections(scene, result)
            %applyCorrections Return a scene with solved corrections applied.
            alignedScene = ProjectionAlignmentOpkSolver.setCorrections( ...
                scene, result.SolvedCorrections);
        end

        function previewScene = previewCorrections(scene, result)
            %previewCorrections Return a preview scene with solved corrections.
            previewScene = ProjectionAlignmentOpkSolver.applyCorrections(scene, result);
        end

        function revertedScene = revertCorrections(scene, result)
            %revertCorrections Return a scene restored to starting corrections.
            revertedScene = ProjectionAlignmentOpkSolver.setCorrections( ...
                scene, result.Diagnostics.StartingCorrections);
        end
    end

    methods (Static, Access = private)
        function residuals = residualVector(x, scene, matchResult, layerIndices, ...
                startCorrections, commonPlane, options)
            dataResiduals = ProjectionAlignmentOpkSolver.dataResiduals( ...
                x, scene, matchResult, layerIndices, commonPlane);
            dataResiduals = ProjectionAlignmentOpkSolver.robustResiduals( ...
                dataResiduals, options.Regularization);
            regularizationResiduals = ...
                ProjectionAlignmentOpkSolver.regularizationResiduals( ...
                x, startCorrections, options.Regularization);
            residuals = [dataResiduals(:); regularizationResiduals(:)];
        end

        function residuals = dataResiduals(x, scene, matchResult, layerIndices, ...
                commonPlane)
            pairResiduals = ProjectionAlignmentOpkSolver.dataResidualsByPair( ...
                x, scene, matchResult, layerIndices, commonPlane);
            residualCells = cellfun(@(values) values(:), pairResiduals, ...
                UniformOutput=false);
            residuals = vertcat(residualCells{:});
        end

        function residuals = dataResidualsByPair(x, scene, matchResult, ...
                layerIndices, commonPlane)
            [corrections, sharedScale] = ProjectionAlignmentOpkSolver.vectorToCorrections( ...
                x, layerIndices);
            residuals = cell(1, numel(matchResult.Matches));
            for pairIndex = 1:numel(matchResult.Matches)
                pairMatch = matchResult.Matches(pairIndex);
                movingCorrection = ProjectionAlignmentOpkSolver.correctionForLayer( ...
                    corrections, pairMatch.Pair(1));
                referenceCorrection = ProjectionAlignmentOpkSolver.correctionForLayer( ...
                    corrections, pairMatch.Pair(2));
                movingCoordinates = ProjectionAlignmentOpkSolver.projectObservations( ...
                    scene.layers(pairMatch.Pair(1)), movingCorrection, ...
                    pairMatch.MovingSourceRows, pairMatch.MovingSourceColumns, ...
                    scene.renderOrigin, commonPlane, sharedScale);
                referenceCoordinates = ProjectionAlignmentOpkSolver.projectObservations( ...
                    scene.layers(pairMatch.Pair(2)), referenceCorrection, ...
                    pairMatch.ReferenceSourceRows, pairMatch.ReferenceSourceColumns, ...
                    scene.renderOrigin, commonPlane, sharedScale);
                residuals{pairIndex} = movingCoordinates - referenceCoordinates;
            end
        end

        function coordinates = projectObservations(layer, correctionDegrees, rows, ...
                columns, renderOrigin, commonPlane, sharedScale)
            projectedLayer = layer;
            projectedLayer.ViewVectorAngularOffsetsDegrees = correctionDegrees(:);
            rows = ProjectionAlignmentOpkSolver.scaleSourceRows( ...
                rows, layer, sharedScale);
            mesh = ProjectionMeshBuilder.buildLayerMesh( ...
                projectedLayer, projectedLayer.CurrentProjectionPlane, renderOrigin);
            worldPoints = reshape(mesh.WorldPoints, 3, []);
            planeCoordinates = PlanarProjection.worldToPlane(worldPoints, commonPlane);
            [rowGrid, columnGrid] = ndgrid(mesh.RowIndices, mesh.ColumnIndices);
            xInterpolant = scatteredInterpolant(columnGrid(:), rowGrid(:), ...
                planeCoordinates(1, :).', "linear", "none");
            yInterpolant = scatteredInterpolant(columnGrid(:), rowGrid(:), ...
                planeCoordinates(2, :).', "linear", "none");
            x = xInterpolant(columns(:), rows(:));
            y = yInterpolant(columns(:), rows(:));
            coordinates = [x, y];
            if any(~isfinite(coordinates), "all")
                error("ProjectionAlignmentOpkSolver:observationOutsideMesh", ...
                    "Matched source observations must lie inside the layer mesh.");
            end
        end

        function rows = scaleSourceRows(rows, layer, sharedScale)
            if sharedScale == 1
                return
            end
            imageSize = layer.SourceGeometry.ImageSize;
            centerRow = (double(imageSize(1)) + 1) / 2;
            rows = centerRow + (rows - centerRow) * sharedScale;
        end

        function residuals = robustResiduals(residuals, regularization)
            if regularization.RobustLoss == "none"
                return
            end
            scale = regularization.RobustScale;
            absResiduals = abs(residuals);
            large = absResiduals > scale;
            if regularization.RobustLoss == "huber"
                residuals(large) = sign(residuals(large)) .* ...
                    sqrt(2 * scale * absResiduals(large) - scale^2);
            elseif regularization.RobustLoss == "bisquare"
                residuals(large) = sign(residuals(large)) * scale;
            end
        end

        function residuals = regularizationResiduals(x, startCorrections, regularization)
            weights = [regularization.OmegaWeight; regularization.PhiWeight; ...
                regularization.KappaWeight];
            weights = repmat(sqrt(regularization.OverallWeight) * sqrt(weights), ...
                numel(startCorrections), 1);
            opkValueCount = 3 * numel(startCorrections);
            opkValues = x(1:opkValueCount);
            residuals = (opkValues(:) - ...
                reshape([startCorrections.ViewVectorAngularOffsetsDegrees], ...
                [], 1)) .* weights;
            if numel(x) > opkValueCount
                scaleWeight = sqrt(regularization.OverallWeight) * ...
                    sqrt(regularization.SharedScaleWeight);
                residuals = [residuals; (x(end) - 1) * scaleWeight];
            end
        end

        function [x0, lowerBounds, upperBounds, boundsDegrees] = variableBounds( ...
                scene, layerIndices, startCorrections, options)
            x0 = reshape([startCorrections.ViewVectorAngularOffsetsDegrees], [], 1);
            boundsDegrees = zeros(numel(layerIndices), 3);
            for k = 1:numel(layerIndices)
                boundsDegrees(k, :) = ProjectionAlignmentOpkSolver.layerBounds( ...
                    scene.layers(layerIndices(k)), options.Bounds);
            end
            boundsVector = reshape(boundsDegrees.', [], 1);
            lowerBounds = x0 - boundsVector;
            upperBounds = x0 + boundsVector;
            if options.MovableParameters.IncludeSharedScale
                x0(end + 1, 1) = 1;
                lowerBounds(end + 1, 1) = options.Bounds.SharedScale(1);
                upperBounds(end + 1, 1) = options.Bounds.SharedScale(2);
            end
        end

        function bounds = layerBounds(layer, options)
            fovBound = ProjectionAlignmentOpkSolver.fovBoundDegrees(layer, options);
            bounds = [ ...
                ProjectionAlignmentOpkSolver.fieldOrDefaultBound( ...
                options.OmegaDegrees, fovBound), ...
                ProjectionAlignmentOpkSolver.fieldOrDefaultBound( ...
                options.PhiDegrees, fovBound), ...
                ProjectionAlignmentOpkSolver.fieldOrDefaultBound( ...
                options.KappaDegrees, fovBound)];
        end

        function bound = fovBoundDegrees(layer, options)
            geometry = layer.SourceGeometry;
            imageSize = geometry.ImageSize;
            nominalRange = ProjectionAlignmentOpkSolver.positiveScalarOrDefault( ...
                geometry, "NominalRange", 1);
            gsd = ProjectionAlignmentOpkSolver.positiveScalarOrDefault( ...
                geometry, "GSD", 1);
            platformStep = ProjectionAlignmentOpkSolver.positiveScalarOrDefault( ...
                geometry, "PlatformStepMeters", gsd);
            verticalFov = rad2deg(imageSize(1) * gsd / nominalRange);
            horizontalFov = rad2deg(imageSize(2) * platformStep / nominalRange);
            bound = max(options.FieldOfViewFraction * ...
                min(verticalFov, horizontalFov), 1e-6);
        end

        function value = positiveScalarOrDefault(source, fieldName, defaultValue)
            value = defaultValue;
            if isfield(source, fieldName) && isnumeric(source.(fieldName)) && ...
                    isscalar(source.(fieldName)) && isfinite(source.(fieldName)) && ...
                    source.(fieldName) > 0
                value = double(source.(fieldName));
            end
        end

        function bound = fieldOrDefaultBound(value, defaultValue)
            if isempty(value)
                bound = defaultValue;
            else
                bound = value;
            end
        end

        function result = resultStruct(matchResult, layerIndices, startCorrections, ...
                xSolved, beforeResiduals, afterResiduals, perPairResiduals, ...
                solverResiduals, exitFlag, output, boundsDegrees, totalSeconds)
            [solvedCorrections, sharedScale] = ProjectionAlignmentOpkSolver.vectorToCorrections( ...
                xSolved, layerIndices);
            result = struct();
            result.Status = "solved";
            result.RequestSummary = ProjectionAlignmentOpkSolver.requestSummary( ...
                matchResult, layerIndices);
            result.Matches = ProjectionAlignmentOpkSolver.resultMatches(matchResult);
            result.Inliers = ProjectionAlignmentOpkSolver.resultInliers(matchResult);
            result.Residuals = struct(LossMode="projectionPlane2D", Unit="meters", ...
                Before=ProjectionAlignmentOpkSolver.residualNorms(beforeResiduals), ...
                After=ProjectionAlignmentOpkSolver.residualNorms(afterResiduals), ...
                PerPair=perPairResiduals);
            result.SolvedCorrections = solvedCorrections;
            result.Convergence = struct(Status= ...
                ProjectionAlignmentOpkSolver.convergenceStatus(exitFlag), ...
                Success=exitFlag > 0, Iterations=output.iterations, ...
                ExitFlag=exitFlag, Objective=sum(solverResiduals.^2), ...
                FirstOrderOptimality=[], Message=string(output.message));
            result.Warnings = strings(1, 0);
            result.Timing = struct(StartedAt="", FinishedAt="", ...
                TotalSeconds=totalSeconds, StageSeconds=struct(Solver=totalSeconds));
            result.Diagnostics = struct();
            result.Diagnostics.StartingCorrections = startCorrections;
            result.Diagnostics.BoundsDegrees = boundsDegrees;
            result.Diagnostics.SharedScale = sharedScale;
            result.Diagnostics.RmsBefore = rms(result.Residuals.Before);
            result.Diagnostics.RmsAfter = rms(result.Residuals.After);
        end

        function summary = requestSummary(matchResult, layerIndices)
            referenceIndex = layerIndices(ceil(numel(layerIndices) / 2));
            schedulingStrategy = "pairwiseJoint";
            if isfield(matchResult, "Schedule")
                schedule = matchResult.Schedule;
                if isfield(schedule, "ReferenceLayerIndex")
                    referenceIndex = schedule.ReferenceLayerIndex;
                end
                if isfield(schedule, "Strategy")
                    schedulingStrategy = schedule.Strategy;
                end
            end
            summary = struct(LayerIndices=layerIndices, ...
                ReferenceLayerIndex=referenceIndex, ...
                AnalysisBands=ones(1, numel(layerIndices)), ...
                LossMode="projectionPlane2D", ...
                SchedulingStrategy=schedulingStrategy, ...
                MovableParameters=["omega", "phi", "kappa"]);
        end

        function pairs = residualPairs(xBefore, xAfter, scene, matchResult, ...
                layerIndices, commonPlane)
            beforeByPair = ProjectionAlignmentOpkSolver.dataResidualsByPair( ...
                xBefore, scene, matchResult, layerIndices, commonPlane);
            afterByPair = ProjectionAlignmentOpkSolver.dataResidualsByPair( ...
                xAfter, scene, matchResult, layerIndices, commonPlane);
            pairs = struct("Pair", {}, "Before", {}, "After", {}, "Count", {});
            for k = 1:numel(matchResult.Matches)
                pairs(k).Pair = matchResult.Matches(k).Pair;
                pairs(k).Before = ProjectionAlignmentOpkSolver.residualNorms( ...
                    beforeByPair{k});
                pairs(k).After = ProjectionAlignmentOpkSolver.residualNorms( ...
                    afterByPair{k});
                pairs(k).Count = matchResult.Matches(k).Count;
            end
        end

        function matches = resultMatches(matchResult)
            for k = 1:numel(matchResult.Matches)
                pairMatch = matchResult.Matches(k);
                match = struct();
                match.Pair = pairMatch.Pair;
                match.MovingPoints = pairMatch.MovingFeatureLocations;
                match.ReferencePoints = pairMatch.ReferenceFeatureLocations;
                match.MovingProjectionPoints = pairMatch.MovingPlaneCoordinates;
                match.ReferenceProjectionPoints = pairMatch.ReferencePlaneCoordinates;
                match.Scores = pairMatch.Scores;
                match.DescriptorIndices = pairMatch.IndexPairs;
                match.Count = pairMatch.Count;
                if k == 1
                    matches = match;
                else
                    matches(k) = match;
                end
            end
        end

        function inliers = resultInliers(matchResult)
            for k = 1:numel(matchResult.Matches)
                pairMatch = matchResult.Matches(k);
                inlier = struct();
                inlier.Pair = pairMatch.Pair;
                inlier.Mask = true(pairMatch.Count, 1);
                inlier.Count = pairMatch.Count;
                inlier.Method = "filteredMatches";
                if k == 1
                    inliers = inlier;
                else
                    inliers(k) = inlier;
                end
            end
        end

        function norms = residualNorms(residuals)
            if isempty(residuals)
                norms = [];
                return
            end
            if ismatrix(residuals) && size(residuals, 2) == 2
                pairs = residuals;
            else
                pairs = reshape(residuals, [], 2);
            end
            norms = sqrt(sum(pairs.^2, 2)).';
        end

        function status = convergenceStatus(exitFlag)
            if exitFlag > 0
                status = "converged";
            elseif exitFlag == 0
                status = "maxIterations";
            else
                status = "failed";
            end
        end

        function corrections = layerCorrections(scene, layerIndices)
            for k = 1:numel(layerIndices)
                layer = scene.layers(layerIndices(k));
                correction = struct();
                correction.LayerIndex = layerIndices(k);
                correction.ViewVectorAngularOffsetsDegrees = ...
                    ProjectionAlignmentOpkSolver.layerViewVectorCorrections(layer);
                correction.ProjectionOffsetMeters = ...
                    ProjectionAlignmentOpkSolver.layerProjectionOffset(layer);
                correction.SharedScale = 1;
                if k == 1
                    corrections = correction;
                else
                    corrections(k) = correction;
                end
            end
        end

        function offsets = layerViewVectorCorrections(layer)
            if isfield(layer, "ViewVectorAngularOffsetsDegrees")
                offsets = double(layer.ViewVectorAngularOffsetsDegrees(:).');
            else
                offsets = [0 0 0];
            end
        end

        function offset = layerProjectionOffset(layer)
            if isfield(layer, "ProjectionOffsetMeters")
                offset = double(layer.ProjectionOffsetMeters(:).');
            else
                offset = [0 0];
            end
        end

        function [corrections, sharedScale] = vectorToCorrections(x, layerIndices)
            opkValueCount = 3 * numel(layerIndices);
            sharedScale = 1;
            if numel(x) > opkValueCount
                sharedScale = x(opkValueCount + 1);
            end
            x = reshape(x(1:opkValueCount), 3, []).';
            for k = 1:numel(layerIndices)
                correction = struct();
                correction.LayerIndex = layerIndices(k);
                correction.ViewVectorAngularOffsetsDegrees = x(k, :);
                correction.ProjectionOffsetMeters = [0 0];
                correction.SharedScale = sharedScale;
                if k == 1
                    corrections = correction;
                else
                    corrections(k) = correction;
                end
            end
        end

        function correction = correctionForLayer(corrections, layerIndex)
            correction = corrections([corrections.LayerIndex] == layerIndex);
            correction = correction(1).ViewVectorAngularOffsetsDegrees;
        end

        function scene = setCorrections(scene, corrections)
            for k = 1:numel(corrections)
                layerIndex = corrections(k).LayerIndex;
                scene.layers(layerIndex).ViewVectorAngularOffsetsDegrees = ...
                    corrections(k).ViewVectorAngularOffsetsDegrees(:);
            end
        end

        function layerIndices = matchLayerIndices(matchResult)
            if isfield(matchResult, "Schedule") && ...
                    isfield(matchResult.Schedule, "LayerIndices") && ...
                    ~isempty(matchResult.Schedule.LayerIndices)
                layerIndices = double(matchResult.Schedule.LayerIndices);
            else
                pairs = reshape([matchResult.Matches.Pair], 2, []).';
                layerIndices = unique(pairs(:).', "stable");
            end
            if numel(layerIndices) < 2
                error("ProjectionAlignmentOpkSolver:invalidMatchPairs", ...
                    "OPK alignment solving requires at least two matched layers.");
            end
        end

        function validateScene(scene)
            if ~isstruct(scene) || ~isscalar(scene) || ~isfield(scene, "layers") || ...
                    ~isfield(scene, "renderOrigin") || isempty(scene.layers)
                error("ProjectionAlignmentOpkSolver:invalidScene", ...
                    "Scene must contain renderOrigin and layers.");
            end
        end

        function validateMatchResult(matchResult)
            if ~isstruct(matchResult) || ~isscalar(matchResult) || ...
                    ~isfield(matchResult, "Matches") || isempty(matchResult.Matches)
                error("ProjectionAlignmentOpkSolver:invalidMatchResult", ...
                    "Match result must contain a nonempty Matches struct array.");
            end
            pairs = reshape([matchResult.Matches.Pair], 2, []).';
            if numel(unique(pairs(:))) < 2
                error("ProjectionAlignmentOpkSolver:invalidMatchPairs", ...
                    "OPK alignment solving requires at least two matched layers.");
            end
            if any([matchResult.Matches.Count] < 3)
                error("ProjectionAlignmentOpkSolver:insufficientMatches", ...
                    "At least three matches are required for OPK solving.");
            end
        end
    end
end
