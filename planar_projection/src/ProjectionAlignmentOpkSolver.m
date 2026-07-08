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
                x0, scene, matchResult, layerIndices, commonPlane, options);

            solverOptions = optimoptions("lsqnonlin", Display="off", ...
                MaxIterations=100, FunctionTolerance=1e-10, StepTolerance=1e-10);
            [xSolved, residual, ~, exitFlag, output] = lsqnonlin( ...
                residualFcn, x0, lowerBounds, upperBounds, solverOptions);
            afterResiduals = ProjectionAlignmentOpkSolver.dataResiduals( ...
                xSolved, scene, matchResult, layerIndices, commonPlane, options);
            perPairResiduals = ProjectionAlignmentOpkSolver.residualPairs( ...
                x0, xSolved, scene, matchResult, layerIndices, commonPlane, options);
            comparisonDiagnostics = ProjectionAlignmentOpkSolver.comparisonDiagnostics( ...
                x0, xSolved, scene, matchResult, layerIndices, commonPlane, options);

            result = ProjectionAlignmentOpkSolver.resultStruct( ...
                matchResult, layerIndices, startCorrections, xSolved, ...
                beforeResiduals, afterResiduals, perPairResiduals, residual, ...
                exitFlag, output, boundsDegrees, comparisonDiagnostics, options, ...
                toc(timer));
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
                x, scene, matchResult, layerIndices, commonPlane, options);
            dataResiduals = ProjectionAlignmentOpkSolver.robustResiduals( ...
                dataResiduals, options.Regularization);
            regularizationResiduals = ...
                ProjectionAlignmentOpkSolver.regularizationResiduals( ...
                x, startCorrections, options.Regularization);
            residuals = [dataResiduals(:); regularizationResiduals(:)];
        end

        function residuals = dataResiduals(x, scene, matchResult, layerIndices, ...
                commonPlane, options)
            pairResiduals = ProjectionAlignmentOpkSolver.dataResidualsByPair( ...
                x, scene, matchResult, layerIndices, commonPlane, options);
            residualCells = cellfun(@(values) values(:), pairResiduals, ...
                UniformOutput=false);
            residuals = vertcat(residualCells{:});
        end

        function residuals = dataResidualsByPair(x, scene, matchResult, ...
                layerIndices, commonPlane, options)
            [corrections, sharedScale] = ProjectionAlignmentOpkSolver.vectorToCorrections( ...
                x, layerIndices);
            residuals = cell(1, numel(matchResult.Matches));
            for pairIndex = 1:numel(matchResult.Matches)
                pairMatch = matchResult.Matches(pairIndex);
                movingCorrection = ProjectionAlignmentOpkSolver.correctionForLayer( ...
                    corrections, pairMatch.Pair(1));
                referenceCorrection = ProjectionAlignmentOpkSolver.correctionForLayer( ...
                    corrections, pairMatch.Pair(2));
                if options.LossMode == "rayToRay3D"
                    residuals{pairIndex} = ProjectionAlignmentOpkSolver.rayResiduals( ...
                        scene, pairMatch, movingCorrection, referenceCorrection, ...
                        commonPlane, sharedScale);
                else
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
        end

        function residuals = rayResiduals(scene, pairMatch, movingCorrection, ...
                referenceCorrection, commonPlane, sharedScale)
            [movingOrigins, movingVectors] = ProjectionAlignmentOpkSolver.sourceRays( ...
                scene.layers(pairMatch.Pair(1)), movingCorrection, ...
                pairMatch.MovingSourceRows, pairMatch.MovingSourceColumns, ...
                scene.renderOrigin, commonPlane, sharedScale);
            [referenceOrigins, referenceVectors] = ...
                ProjectionAlignmentOpkSolver.sourceRays( ...
                scene.layers(pairMatch.Pair(2)), referenceCorrection, ...
                pairMatch.ReferenceSourceRows, pairMatch.ReferenceSourceColumns, ...
                scene.renderOrigin, commonPlane, sharedScale);
            residuals = ProjectionAlignmentOpkSolver.closestApproachResiduals( ...
                movingOrigins, movingVectors, referenceOrigins, referenceVectors).';
        end

        function [origins, vectors] = sourceRays(layer, correctionDegrees, rows, ...
                columns, renderOrigin, ~, sharedScale)
            rows = ProjectionAlignmentOpkSolver.scaleSourceRows( ...
                rows, layer, sharedScale);
            if ProjectionAlignmentOpkSolver.hasObservationRaySampler(layer)
                [origins, vectors] = ProjectionAlignmentOpkSolver.sampleObservationRays( ...
                    layer, rows, columns);
                rotation = ProjectionAlignmentOpkSolver.layerViewVectorRotation( ...
                    layer, correctionDegrees);
                vectors = ProjectionAlignmentOpkSolver.normalizeVectors( ...
                    rotation * vectors);
                return
            end

            projectedLayer = layer;
            projectedLayer.ViewVectorAngularOffsetsDegrees = correctionDegrees(:);
            mesh = ProjectionMeshBuilder.buildLayerMesh( ...
                projectedLayer, projectedLayer.CurrentProjectionPlane, renderOrigin);
            origins = ProjectionAlignmentOpkSolver.interpolateOrigins(mesh, columns);
            vectors = ProjectionAlignmentOpkSolver.interpolateVectors(mesh, rows, ...
                columns);
            if any(~isfinite(origins), "all") || any(~isfinite(vectors), "all")
                error("ProjectionAlignmentOpkSolver:observationOutsideMesh", ...
                    "Matched source observations must lie inside the layer mesh.");
            end
            vectors = PlanarProjection.normalizeVectors(vectors);
        end

        function origins = interpolateOrigins(mesh, columns)
            origins = zeros(3, numel(columns));
            for componentIndex = 1:3
                origins(componentIndex, :) = interp1(mesh.ColumnIndices, ...
                    mesh.SampledOrigins(componentIndex, :), columns(:).', ...
                    "linear");
            end
        end

        function vectors = interpolateVectors(mesh, rows, columns)
            [rowGrid, columnGrid] = ndgrid(mesh.RowIndices, mesh.ColumnIndices);
            vectors = zeros(3, numel(rows));
            for componentIndex = 1:3
                componentGrid = squeeze(mesh.SampledVectors(componentIndex, :, :));
                vectors(componentIndex, :) = interp2(columnGrid, rowGrid, ...
                    componentGrid, columns(:).', rows(:).', "linear");
            end
        end

        function residuals = closestApproachResiduals(G1, V1, G2, V2)
            residuals = zeros(3, size(V1, 2));
            for k = 1:size(V1, 2)
                try
                    [~, ~, Pnear1, Pnear2] = PlanarProjection.triangulateRays( ...
                        G1(:, k), V1(:, k), G2(:, k), V2(:, k));
                    residuals(:, k) = Pnear1 - Pnear2;
                catch ME
                    if ME.identifier ~= "PlanarProjection:parallelRay"
                        rethrow(ME)
                    end
                    delta = G1(:, k) - G2(:, k);
                    residuals(:, k) = delta - V1(:, k) * dot(delta, V1(:, k));
                end
            end
        end

        function coordinates = projectObservations(layer, correctionDegrees, rows, ...
                columns, renderOrigin, commonPlane, sharedScale)
            [origins, vectors] = ProjectionAlignmentOpkSolver.sourceRays( ...
                layer, correctionDegrees, rows, columns, renderOrigin, ...
                commonPlane, sharedScale);
            worldPoints = ProjectionAlignmentOpkSolver.intersectObservationRays( ...
                origins, vectors, layer.CurrentProjectionPlane);
            planeCoordinates = PlanarProjection.worldToPlane(worldPoints, commonPlane);
            coordinates = planeCoordinates.';
            if any(~isfinite(coordinates), "all")
                error("ProjectionAlignmentOpkSolver:observationOutsideMesh", ...
                    "Matched source observations must lie inside the layer mesh.");
            end
        end

        function worldPoints = intersectObservationRays(origins, vectors, plane)
            normal = plane.VN;
            denom = normal.' * vectors;
            if any(abs(denom) <= ProjectionAlignmentOpkSolver.defaultTolerance())
                error("ProjectionAlignmentOpkSolver:parallelRay", ...
                    "One or more matched source rays are parallel to the projection plane.");
            end

            ranges = (normal.' * (plane.P0 - origins)) ./ denom;
            if any(ranges <= ProjectionAlignmentOpkSolver.defaultTolerance())
                error("ProjectionAlignmentOpkSolver:behindSource", ...
                    "One or more matched intersections are behind the source origin.");
            end

            worldPoints = origins + vectors .* ranges;
        end

        function tf = hasObservationRaySampler(layer)
            sourceGeometry = layer.SourceGeometry;
            tf = isfield(sourceGeometry, "SampleRayFcn") && ...
                isa(sourceGeometry.SampleRayFcn, "function_handle");
        end

        function [origins, vectors] = sampleObservationRays(layer, rows, columns)
            [origins, vectors] = layer.SourceGeometry.SampleRayFcn(rows, columns);
            ProjectionAlignmentOpkSolver.validateObservationRays( ...
                origins, vectors, numel(rows));
        end

        function validateObservationRays(origins, vectors, observationCount)
            if ~isnumeric(origins) || ~isequal(size(origins), [3 observationCount]) || ...
                    any(~isfinite(origins), "all")
                error("ProjectionAlignmentOpkSolver:invalidObservationRays", ...
                    "SampleRayFcn must return origins as a finite 3 x N array.");
            end

            if ~isnumeric(vectors) || ~isequal(size(vectors), [3 observationCount]) || ...
                    any(~isfinite(vectors), "all")
                error("ProjectionAlignmentOpkSolver:invalidObservationRays", ...
                    "SampleRayFcn must return view vectors as a finite 3 x N array.");
            end
        end

        function R = layerViewVectorRotation(layer, correctionDegrees)
            offsetsDegrees = double(correctionDegrees(:));
            if all(abs(offsetsDegrees) <= ProjectionAlignmentOpkSolver.defaultTolerance())
                R = eye(3);
                return
            end

            sourceGeometry = layer.SourceGeometry;
            imageYAxis = ProjectionAlignmentOpkSolver.sourceGeometryUnitVector( ...
                sourceGeometry, ["ImageYAxis", "RowAxis"], "image y axis");
            imageXAxis = ProjectionAlignmentOpkSolver.sourceGeometryUnitVector( ...
                sourceGeometry, ["ImageXAxis", "PlatformDirection"], "image x axis");
            referenceOrigin = ProjectionAlignmentOpkSolver.sourceGeometryPoint( ...
                sourceGeometry, ["G0", "ReferenceOrigin"], "G0");
            kappaAxis = ProjectionAlignmentOpkSolver.unitVector( ...
                layer.CurrentProjectionPlane.P0 - referenceOrigin, "kappa axis");

            omegaRadians = deg2rad(offsetsDegrees(1));
            phiRadians = deg2rad(offsetsDegrees(2));
            kappaRadians = deg2rad(offsetsDegrees(3));
            Romega = ProjectionAlignmentOpkSolver.rotationAboutAxis( ...
                imageYAxis, omegaRadians);
            Rphi = ProjectionAlignmentOpkSolver.rotationAboutAxis( ...
                imageXAxis, phiRadians);
            Rkappa = ProjectionAlignmentOpkSolver.rotationAboutAxis( ...
                kappaAxis, kappaRadians);
            R = Rkappa * Rphi * Romega;
        end

        function vector = sourceGeometryUnitVector(sourceGeometry, fieldNames, name)
            vector = ProjectionAlignmentOpkSolver.sourceGeometryVector( ...
                sourceGeometry, fieldNames, name);
            vector = ProjectionAlignmentOpkSolver.unitVector(vector, name);
        end

        function vector = sourceGeometryVector(sourceGeometry, fieldNames, name)
            for fieldName = string(fieldNames)
                if isfield(sourceGeometry, fieldName)
                    vector = sourceGeometry.(fieldName);
                    if ~isnumeric(vector) || ~isequal(size(vector), [3 1]) || ...
                            any(~isfinite(vector))
                        error("ProjectionAlignmentOpkSolver:invalidViewVectorCorrection", ...
                            "Source geometry %s must be a finite numeric 3x1 vector.", name);
                    end
                    vector = double(vector);
                    return
                end
            end

            error("ProjectionAlignmentOpkSolver:invalidViewVectorCorrection", ...
                "Source geometry must contain %s for view-vector correction.", name);
        end

        function point = sourceGeometryPoint(sourceGeometry, fieldNames, name)
            point = ProjectionAlignmentOpkSolver.sourceGeometryVector( ...
                sourceGeometry, fieldNames, name);
        end

        function R = rotationAboutAxis(axis, angle)
            axis = ProjectionAlignmentOpkSolver.unitVector(axis, "rotation axis");
            K = [0 -axis(3) axis(2); axis(3) 0 -axis(1); -axis(2) axis(1) 0];
            R = cos(angle) * eye(3) + ...
                (1 - cos(angle)) * (axis * axis.') + sin(angle) * K;
        end

        function vector = unitVector(vector, name)
            if ~isnumeric(vector) || ~isequal(size(vector), [3 1]) || ...
                    any(~isfinite(vector))
                error("ProjectionAlignmentOpkSolver:invalidVector", ...
                    "%s must be a finite numeric 3x1 vector.", name);
            end

            magnitude = norm(vector);
            if magnitude <= ProjectionAlignmentOpkSolver.defaultTolerance()
                error("ProjectionAlignmentOpkSolver:invalidVector", ...
                    "%s must have nonzero length.", name);
            end
            vector = double(vector) / magnitude;
        end

        function vectors = normalizeVectors(vectors)
            vectorNorms = sqrt(sum(vectors.^2, 1));
            if any(vectorNorms <= ProjectionAlignmentOpkSolver.defaultTolerance(), ...
                    "all")
                error("ProjectionAlignmentOpkSolver:invalidObservationRays", ...
                    "Sampled view vectors must have nonzero length.");
            end
            vectors = vectors ./ vectorNorms;
        end

        function tol = defaultTolerance()
            tol = 1e-10;
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
                solverResiduals, exitFlag, output, boundsDegrees, ...
                comparisonDiagnostics, options, totalSeconds)
            [solvedCorrections, sharedScale] = ProjectionAlignmentOpkSolver.vectorToCorrections( ...
                xSolved, layerIndices);
            boundHits = ProjectionAlignmentOpkSolver.boundHitDiagnostics( ...
                layerIndices, startCorrections, solvedCorrections, boundsDegrees);
            residualDiagnostics = ProjectionAlignmentOpkSolver.residualDiagnostics( ...
                matchResult, perPairResiduals);
            result = struct();
            result.Status = "solved";
            result.RequestSummary = ProjectionAlignmentOpkSolver.requestSummary( ...
                matchResult, layerIndices, options);
            result.Matches = ProjectionAlignmentOpkSolver.resultMatches(matchResult);
            result.Inliers = ProjectionAlignmentOpkSolver.resultInliers(matchResult);
            result.Residuals = struct(LossMode=options.LossMode, Unit="meters", ...
                Before=ProjectionAlignmentOpkSolver.residualNorms( ...
                beforeResiduals, ProjectionAlignmentOpkSolver.lossComponentCount( ...
                options.LossMode)), ...
                After=ProjectionAlignmentOpkSolver.residualNorms( ...
                afterResiduals, ProjectionAlignmentOpkSolver.lossComponentCount( ...
                options.LossMode)), ...
                PerPair=perPairResiduals);
            result.SolvedCorrections = solvedCorrections;
            result.Convergence = struct(Status= ...
                ProjectionAlignmentOpkSolver.convergenceStatus(exitFlag), ...
                Success=exitFlag > 0, Iterations=output.iterations, ...
                FunctionEvaluations=ProjectionAlignmentOpkSolver.outputFieldOrDefault( ...
                output, "funcCount", []), ExitFlag=exitFlag, ...
                Objective=sum(solverResiduals.^2), ...
                FirstOrderOptimality=ProjectionAlignmentOpkSolver.outputFieldOrDefault( ...
                output, "firstorderopt", []), Message=string(output.message));
            if any([boundHits.Any])
                result.Warnings = "OPK solve hit one or more configured correction bounds.";
            else
                result.Warnings = strings(1, 0);
            end
            result.Timing = struct(StartedAt="", FinishedAt="", ...
                TotalSeconds=totalSeconds, StageSeconds=struct(Solver=totalSeconds));
            result.Diagnostics = struct();
            result.Diagnostics.StartingCorrections = startCorrections;
            result.Diagnostics.BoundsDegrees = boundsDegrees;
            result.Diagnostics.BoundHits = boundHits;
            result.Diagnostics.AnyBoundHit = any([boundHits.Any]);
            result.Diagnostics.SharedScale = sharedScale;
            result.Diagnostics.Comparison = comparisonDiagnostics;
            result.Diagnostics.RmsBefore = rms(result.Residuals.Before);
            result.Diagnostics.RmsAfter = rms(result.Residuals.After);
            result.Diagnostics.MaxResidualBefore = ...
                residualDiagnostics.Summary.MaxResidualBefore;
            result.Diagnostics.MaxResidualAfter = ...
                residualDiagnostics.Summary.MaxResidualAfter;
            result.Diagnostics.WorstResiduals = ...
                residualDiagnostics.WorstResiduals;
            result.Diagnostics.PerPairResidualSummary = ...
                residualDiagnostics.PerPair;
            result.Diagnostics.MatchRecords = residualDiagnostics.MatchRecords;
        end

        function diagnostics = residualDiagnostics(matchResult, perPairResiduals)
            records = ProjectionAlignmentOpkSolver.matchRecords( ...
                matchResult, perPairResiduals);
            before = [records.ResidualBefore];
            after = [records.ResidualAfter];

            diagnostics = struct();
            diagnostics.Summary = struct( ...
                Count=numel(after), ...
                RmsBefore=ProjectionAlignmentOpkSolver.rmsOrNaN(before), ...
                RmsAfter=ProjectionAlignmentOpkSolver.rmsOrNaN(after), ...
                MaxResidualBefore=ProjectionAlignmentOpkSolver.maxOrNaN(before), ...
                MaxResidualAfter=ProjectionAlignmentOpkSolver.maxOrNaN(after));
            diagnostics.PerPair = ...
                ProjectionAlignmentOpkSolver.perPairResidualSummary( ...
                perPairResiduals);
            diagnostics.WorstResiduals = struct( ...
                Before=ProjectionAlignmentOpkSolver.worstResidualRecord( ...
                records, "ResidualBefore"), ...
                After=ProjectionAlignmentOpkSolver.worstResidualRecord( ...
                records, "ResidualAfter"));
            diagnostics.MatchRecords = records;
        end

        function records = matchRecords(matchResult, perPairResiduals)
            totalCount = sum([matchResult.Matches.Count]);
            if totalCount == 0
                records = ProjectionAlignmentOpkSolver.emptyMatchRecords();
                return
            end

            records = repmat( ...
                ProjectionAlignmentOpkSolver.defaultMatchRecord(), ...
                1, totalCount);
            recordIndex = 0;
            for pairIndex = 1:numel(matchResult.Matches)
                pairMatch = matchResult.Matches(pairIndex);
                before = perPairResiduals(pairIndex).Before(:);
                after = perPairResiduals(pairIndex).After(:);
                for matchIndex = 1:pairMatch.Count
                    recordIndex = recordIndex + 1;
                    record = ProjectionAlignmentOpkSolver.defaultMatchRecord();
                    record.Pair = pairMatch.Pair;
                    record.PairIndex = pairIndex;
                    record.PairKey = sprintf("%d -> %d", ...
                        pairMatch.Pair(1), pairMatch.Pair(2));
                    record.MatchIndex = ...
                        ProjectionAlignmentOpkSolver.matchRecordIndex( ...
                        pairMatch, matchIndex);
                    record.Score = pairMatch.Scores(matchIndex);
                    record.MovingSourceRow = ...
                        pairMatch.MovingSourceRows(matchIndex);
                    record.MovingSourceColumn = ...
                        pairMatch.MovingSourceColumns(matchIndex);
                    record.ReferenceSourceRow = ...
                        pairMatch.ReferenceSourceRows(matchIndex);
                    record.ReferenceSourceColumn = ...
                        pairMatch.ReferenceSourceColumns(matchIndex);
                    record.MovingWorkingX = ...
                        pairMatch.MovingFeatureLocations(matchIndex, 1);
                    record.MovingWorkingY = ...
                        pairMatch.MovingFeatureLocations(matchIndex, 2);
                    record.ReferenceWorkingX = ...
                        pairMatch.ReferenceFeatureLocations(matchIndex, 1);
                    record.ReferenceWorkingY = ...
                        pairMatch.ReferenceFeatureLocations(matchIndex, 2);
                    record.MovingProjectionX = ...
                        pairMatch.MovingPlaneCoordinates(matchIndex, 1);
                    record.MovingProjectionY = ...
                        pairMatch.MovingPlaneCoordinates(matchIndex, 2);
                    record.ReferenceProjectionX = ...
                        pairMatch.ReferencePlaneCoordinates(matchIndex, 1);
                    record.ReferenceProjectionY = ...
                        pairMatch.ReferencePlaneCoordinates(matchIndex, 2);
                    record.ResidualBefore = before(matchIndex);
                    record.ResidualAfter = after(matchIndex);
                    records(recordIndex) = record;
                end
            end
        end

        function records = emptyMatchRecords()
            records = repmat( ...
                ProjectionAlignmentOpkSolver.defaultMatchRecord(), 1, 0);
        end

        function record = defaultMatchRecord()
            record = struct( ...
                Pair=[0 0], ...
                PairIndex=0, ...
                PairKey="", ...
                MatchIndex=0, ...
                Score=NaN, ...
                MovingSourceRow=NaN, ...
                MovingSourceColumn=NaN, ...
                ReferenceSourceRow=NaN, ...
                ReferenceSourceColumn=NaN, ...
                MovingWorkingX=NaN, ...
                MovingWorkingY=NaN, ...
                ReferenceWorkingX=NaN, ...
                ReferenceWorkingY=NaN, ...
                MovingProjectionX=NaN, ...
                MovingProjectionY=NaN, ...
                ReferenceProjectionX=NaN, ...
                ReferenceProjectionY=NaN, ...
                ResidualBefore=NaN, ...
                ResidualAfter=NaN, ...
                State="solverObservation", ...
                Accepted=true, ...
                Disabled=false);
        end

        function recordIndex = matchRecordIndex(pairMatch, matchIndex)
            recordIndex = matchIndex;
            if isfield(pairMatch, "MatchRecordIndices") && ...
                    numel(pairMatch.MatchRecordIndices) >= matchIndex
                recordIndex = pairMatch.MatchRecordIndices(matchIndex);
            end
        end

        function summaries = perPairResidualSummary(perPairResiduals)
            if isempty(perPairResiduals)
                summaries = struct("Pair", {}, "PairIndex", {}, "Count", {}, ...
                    "RmsBefore", {}, "RmsAfter", {}, "MaxResidualBefore", {}, ...
                    "MaxResidualAfter", {}, "WorstMatchIndexBefore", {}, ...
                    "WorstMatchIndexAfter", {});
                return
            end

            for k = 1:numel(perPairResiduals)
                before = perPairResiduals(k).Before(:).';
                after = perPairResiduals(k).After(:).';
                [~, worstBefore] = ProjectionAlignmentOpkSolver.maxAndIndex( ...
                    before);
                [~, worstAfter] = ProjectionAlignmentOpkSolver.maxAndIndex( ...
                    after);
                summary = struct();
                summary.Pair = perPairResiduals(k).Pair;
                summary.PairIndex = k;
                summary.Count = perPairResiduals(k).Count;
                summary.RmsBefore = ProjectionAlignmentOpkSolver.rmsOrNaN( ...
                    before);
                summary.RmsAfter = ProjectionAlignmentOpkSolver.rmsOrNaN( ...
                    after);
                summary.MaxResidualBefore = ...
                    ProjectionAlignmentOpkSolver.maxOrNaN(before);
                summary.MaxResidualAfter = ...
                    ProjectionAlignmentOpkSolver.maxOrNaN(after);
                summary.WorstMatchIndexBefore = worstBefore;
                summary.WorstMatchIndexAfter = worstAfter;
                if k == 1
                    summaries = summary;
                else
                    summaries(k) = summary;
                end
            end
        end

        function record = worstResidualRecord(records, fieldName)
            record = struct(Pair=[0 0], PairIndex=0, PairKey="", ...
                MatchIndex=0, Residual=NaN, Score=NaN, ...
                MovingSourceRow=NaN, MovingSourceColumn=NaN, ...
                ReferenceSourceRow=NaN, ReferenceSourceColumn=NaN);
            if isempty(records)
                return
            end

            [residual, recordIndex] = ProjectionAlignmentOpkSolver.maxAndIndex( ...
                [records.(fieldName)]);
            if isnan(recordIndex)
                return
            end

            source = records(recordIndex);
            record.Pair = source.Pair;
            record.PairIndex = source.PairIndex;
            record.PairKey = source.PairKey;
            record.MatchIndex = source.MatchIndex;
            record.Residual = residual;
            record.Score = source.Score;
            record.MovingSourceRow = source.MovingSourceRow;
            record.MovingSourceColumn = source.MovingSourceColumn;
            record.ReferenceSourceRow = source.ReferenceSourceRow;
            record.ReferenceSourceColumn = source.ReferenceSourceColumn;
        end

        function value = rmsOrNaN(values)
            if isempty(values)
                value = NaN;
            else
                value = rms(values);
            end
        end

        function value = maxOrNaN(values)
            value = ProjectionAlignmentOpkSolver.maxAndIndex(values);
        end

        function [value, index] = maxAndIndex(values)
            if isempty(values)
                value = NaN;
                index = NaN;
            else
                [value, index] = max(values);
            end
        end

        function value = outputFieldOrDefault(output, fieldName, defaultValue)
            value = defaultValue;
            if isfield(output, fieldName)
                value = output.(fieldName);
            end
        end

        function diagnostics = boundHitDiagnostics(layerIndices, startCorrections, ...
                solvedCorrections, boundsDegrees)
            parameterNames = ["omega", "phi", "kappa"];
            diagnostics = struct("LayerIndex", {}, "Parameters", {}, ...
                "DeltaDegrees", {}, "BoundsDegrees", {}, "HitMask", {}, ...
                "HitParameters", {}, "Any", {});
            for k = 1:numel(layerIndices)
                startOpk = startCorrections(k).ViewVectorAngularOffsetsDegrees(:).';
                solvedOpk = solvedCorrections(k).ViewVectorAngularOffsetsDegrees(:).';
                delta = solvedOpk - startOpk;
                bounds = boundsDegrees(k, :);
                tolerance = max(1e-8, 1e-6 * max(bounds, 1));
                hitMask = abs(abs(delta) - bounds) <= tolerance;
                diagnostics(k).LayerIndex = layerIndices(k);
                diagnostics(k).Parameters = parameterNames;
                diagnostics(k).DeltaDegrees = delta;
                diagnostics(k).BoundsDegrees = bounds;
                diagnostics(k).HitMask = hitMask;
                diagnostics(k).HitParameters = parameterNames(hitMask);
                diagnostics(k).Any = any(hitMask);
            end
        end

        function summary = requestSummary(matchResult, layerIndices, options)
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
                LossMode=options.LossMode, ...
                SchedulingStrategy=schedulingStrategy, ...
                MovableParameters=["omega", "phi", "kappa"]);
        end

        function pairs = residualPairs(xBefore, xAfter, scene, matchResult, ...
                layerIndices, commonPlane, options)
            beforeByPair = ProjectionAlignmentOpkSolver.dataResidualsByPair( ...
                xBefore, scene, matchResult, layerIndices, commonPlane, options);
            afterByPair = ProjectionAlignmentOpkSolver.dataResidualsByPair( ...
                xAfter, scene, matchResult, layerIndices, commonPlane, options);
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

        function diagnostics = comparisonDiagnostics(xBefore, xAfter, scene, ...
                matchResult, layerIndices, commonPlane, options)
            diagnostics = struct();
            if options.LossMode ~= "rayToRay3D"
                return
            end
            projectionOptions = options;
            projectionOptions.LossMode = "projectionPlane2D";
            before = ProjectionAlignmentOpkSolver.dataResiduals( ...
                xBefore, scene, matchResult, layerIndices, commonPlane, ...
                projectionOptions);
            after = ProjectionAlignmentOpkSolver.dataResiduals( ...
                xAfter, scene, matchResult, layerIndices, commonPlane, ...
                projectionOptions);
            diagnostics.ProjectionPlaneRmsBefore = rms( ...
                ProjectionAlignmentOpkSolver.residualNorms(before, 2));
            diagnostics.ProjectionPlaneRmsAfter = rms( ...
                ProjectionAlignmentOpkSolver.residualNorms(after, 2));
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
                inlier.Method = "solverObservations";
                if k == 1
                    inliers = inlier;
                else
                    inliers(k) = inlier;
                end
            end
        end

        function norms = residualNorms(residuals, componentCount)
            if isempty(residuals)
                norms = [];
                return
            end
            if nargin < 2
                componentCount = 2;
            end
            if ismatrix(residuals) && ...
                    (size(residuals, 2) == 2 || size(residuals, 2) == 3)
                pairs = residuals;
            else
                pairs = reshape(residuals, [], componentCount);
            end
            norms = sqrt(sum(pairs.^2, 2)).';
        end

        function count = lossComponentCount(lossMode)
            if lossMode == "rayToRay3D"
                count = 3;
            else
                count = 2;
            end
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
