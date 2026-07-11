classdef ProjectionAlignmentOpkSolver
    %ProjectionAlignmentOpkSolver Solve pairwise OPK alignment corrections.

    methods (Static)
        function result = solve(scene, matchResult, options, runtimeControl)
            %solve Estimate per-layer omega/phi/kappa corrections.
            if nargin < 3
                options = struct();
            end
            if nargin < 4
                runtimeControl = struct();
            end
            scene = ProjectionLayerIdentity.ensureScene(scene);
            ProjectionAlignmentOpkSolver.validateScene(scene);
            ProjectionAlignmentOpkSolver.validateMatchResult(matchResult);
            options = ProjectionAlignmentOptions.validate(options);
            runtimeControl = ...
                ProjectionAlignmentOpkSolver.validateRuntimeControl( ...
                runtimeControl);
            if exist("lsqnonlin", "file") ~= 2
                error("ProjectionAlignmentOpkSolver:missingOptimizer", ...
                    "lsqnonlin is required for OPK alignment solving.");
            end

            timer = tic;
            layerIndices = ProjectionAlignmentOpkSolver.matchLayerIndices(matchResult);
            startCorrections = ProjectionAlignmentOpkSolver.layerCorrections( ...
                scene, layerIndices);
            parameterModel = ProjectionAlignmentParameterModel.create( ...
                scene, matchResult, layerIndices, startCorrections, options);
            x0 = parameterModel.X0;
            lowerBounds = parameterModel.LowerBounds;
            upperBounds = parameterModel.UpperBounds;
            commonPlane = scene.layers(layerIndices(1)).CurrentProjectionPlane;
            residualFcn = @(x) ProjectionAlignmentOpkSolver.residualVector( ...
                x, scene, matchResult, parameterModel, commonPlane, options);
            beforeResiduals = ProjectionAlignmentOpkSolver.dataResiduals( ...
                x0, scene, matchResult, parameterModel, commonPlane, options);

            solverOptions = optimoptions("lsqnonlin", Display="off", ...
                MaxIterations=100, FunctionTolerance=1e-10, StepTolerance=1e-10);
            if ~isempty(runtimeControl.CancellationFcn)
                solverOptions.OutputFcn = @(~, ~, ~) ...
                    ProjectionAlignmentOpkSolver.cancellationRequested( ...
                    runtimeControl);
            end
            [xSolved, residual, ~, exitFlag, output] = lsqnonlin( ...
                residualFcn, x0, lowerBounds, upperBounds, solverOptions);
            if ProjectionAlignmentOpkSolver.cancellationRequested(runtimeControl)
                error("ProjectionAlignmentOpkSolver:cancelled", ...
                    "OPK alignment solving was cancelled.");
            end
            afterResiduals = ProjectionAlignmentOpkSolver.dataResiduals( ...
                xSolved, scene, matchResult, parameterModel, commonPlane, options);
            perPairResiduals = ProjectionAlignmentOpkSolver.residualPairs( ...
                x0, xSolved, scene, matchResult, parameterModel, commonPlane, options);
            comparisonDiagnostics = ProjectionAlignmentOpkSolver.comparisonDiagnostics( ...
                x0, xSolved, scene, matchResult, parameterModel, commonPlane, options);
            observabilityDiagnostics = ...
                ProjectionAlignmentOpkSolver.observabilityDiagnostics( ...
                x0, xSolved, scene, matchResult, parameterModel, ...
                commonPlane, options);

            result = ProjectionAlignmentOpkSolver.resultStruct( ...
                matchResult, parameterModel, xSolved, ...
                beforeResiduals, afterResiduals, perPairResiduals, residual, ...
                exitFlag, output, comparisonDiagnostics, ...
                observabilityDiagnostics, options, toc(timer));
            result = ProjectionAlignmentResult.validate(result);
        end

        function correctionSet = solveCorrectionSet( ...
                scene, matchResult, options, correctionOptions, runtimeControl)
            %solveCorrectionSet Solve headlessly and return immutable SDK data.
            if nargin < 3
                options = struct();
            end
            if nargin < 4
                correctionOptions = struct();
            end
            if nargin < 5
                runtimeControl = struct();
            end
            result = ProjectionAlignmentOpkSolver.solve( ...
                scene, matchResult, options, runtimeControl);
            correctionSet = ...
                ProjectionCorrectionOpkAdapter.fromAlignmentResult( ...
                scene, result, correctionOptions);
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

        function diagnostics = compareScenes(sceneBefore, sceneAfter, ...
                matchResult, options)
            %compareScenes Evaluate all physical metrics between two scenes.
            if nargin < 4
                options = struct();
            end
            sceneBefore = ProjectionLayerIdentity.ensureScene(sceneBefore);
            sceneAfter = ProjectionLayerIdentity.ensureScene(sceneAfter);
            ProjectionAlignmentOpkSolver.validateScene(sceneBefore);
            ProjectionAlignmentOpkSolver.validateScene(sceneAfter);
            ProjectionAlignmentOpkSolver.validateMatchResult(matchResult);
            options = ProjectionAlignmentOptions.validate(options);
            layerIndices = ProjectionAlignmentOpkSolver.matchLayerIndices( ...
                matchResult);
            startCorrections = ProjectionAlignmentOpkSolver.layerCorrections( ...
                sceneBefore, layerIndices);
            parameterModel = ProjectionAlignmentParameterModel.create( ...
                sceneBefore, matchResult, layerIndices, startCorrections, ...
                options);
            xBefore = parameterModel.X0;
            xAfter = ProjectionAlignmentOpkSolver.parametersForScene( ...
                parameterModel, sceneAfter);
            commonPlane = sceneBefore.layers(layerIndices(1)).CurrentProjectionPlane;
            diagnostics = ProjectionAlignmentOpkSolver.comparisonDiagnostics( ...
                xBefore, xAfter, sceneBefore, matchResult, parameterModel, ...
                commonPlane, options);
        end
    end

    methods (Static, Access = private)
        function x = parametersForScene(parameterModel, scene)
            x = parameterModel.X0;
            for k = 1:parameterModel.LayerCount
                layerIndex = ProjectionLayerIdentity.indexForId( ...
                    scene, parameterModel.LayerIds(k));
                correction = ProjectionAlignmentOpkSolver.layerCorrections( ...
                    scene, layerIndex);
                x(parameterModel.OpkIndices(k, :)) = ...
                    correction.ViewVectorAngularOffsetsDegrees;
                if any(parameterModel.OffsetIndices(k, :) > 0)
                    x(parameterModel.OffsetIndices(k, :)) = ...
                        correction.ProjectionOffsetMeters;
                end
            end
        end

        function runtimeControl = validateRuntimeControl(runtimeControl)
            if isempty(runtimeControl)
                runtimeControl = struct();
            end
            if ~isstruct(runtimeControl) || ~isscalar(runtimeControl)
                error("ProjectionAlignmentOpkSolver:invalidRuntimeControl", ...
                    "Runtime control must be a scalar struct.");
            end
            allowedFields = "CancellationFcn";
            unexpectedFields = setdiff(string(fieldnames(runtimeControl)), ...
                allowedFields);
            if ~isempty(unexpectedFields)
                error("ProjectionAlignmentOpkSolver:invalidRuntimeControl", ...
                    "Unexpected runtime control field: %s.", ...
                    unexpectedFields(1));
            end
            if ~isfield(runtimeControl, "CancellationFcn")
                runtimeControl.CancellationFcn = [];
            end
            if ~isempty(runtimeControl.CancellationFcn) && ...
                    ~isa(runtimeControl.CancellationFcn, "function_handle")
                error("ProjectionAlignmentOpkSolver:invalidRuntimeControl", ...
                    "CancellationFcn must be empty or a function handle.");
            end
        end

        function tf = cancellationRequested(runtimeControl)
            tf = false;
            if isempty(runtimeControl.CancellationFcn)
                return
            end
            tf = runtimeControl.CancellationFcn();
            if ~islogical(tf) || ~isscalar(tf)
                error("ProjectionAlignmentOpkSolver:invalidCancellationResult", ...
                    "CancellationFcn must return a logical scalar.");
            end
        end

        function residuals = residualVector(x, scene, matchResult, ...
                parameterModel, commonPlane, options)
            dataResiduals = ProjectionAlignmentOpkSolver.dataResiduals( ...
                x, scene, matchResult, parameterModel, commonPlane, options);
            dataResiduals = ProjectionAlignmentOpkSolver.robustResiduals( ...
                dataResiduals, options.Regularization);
            regularizationResiduals = ...
                ProjectionAlignmentParameterModel.regularizationResiduals( ...
                parameterModel, x);
            residuals = [dataResiduals(:); regularizationResiduals(:)];
        end

        function residuals = dataResiduals(x, scene, matchResult, parameterModel, ...
                commonPlane, options)
            pairResiduals = ProjectionAlignmentOpkSolver.dataResidualsByPair( ...
                x, scene, matchResult, parameterModel, commonPlane, options);
            residualCells = cellfun(@(values) values(:), pairResiduals, ...
                UniformOutput=false);
            residuals = vertcat(residualCells{:});
        end

        function residuals = dataResidualsByPair(x, scene, matchResult, ...
                parameterModel, commonPlane, options)
            [corrections, sharedScale] = ...
                ProjectionAlignmentParameterModel.corrections(parameterModel, x);
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
                elseif options.LossMode == "epipolarCoplanarity"
                    residuals{pairIndex} = ...
                        ProjectionAlignmentOpkSolver.coplanarityResiduals( ...
                        scene, pairMatch, movingCorrection, ...
                        referenceCorrection, commonPlane, sharedScale);
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

        function residuals = coplanarityResiduals(scene, pairMatch, ...
                movingCorrection, referenceCorrection, commonPlane, sharedScale)
            [movingOrigins, movingVectors] = ProjectionAlignmentOpkSolver.sourceRays( ...
                scene.layers(pairMatch.Pair(1)), movingCorrection, ...
                pairMatch.MovingSourceRows, pairMatch.MovingSourceColumns, ...
                scene.renderOrigin, commonPlane, sharedScale);
            [referenceOrigins, referenceVectors] = ...
                ProjectionAlignmentOpkSolver.sourceRays( ...
                scene.layers(pairMatch.Pair(2)), referenceCorrection, ...
                pairMatch.ReferenceSourceRows, ...
                pairMatch.ReferenceSourceColumns, scene.renderOrigin, ...
                commonPlane, sharedScale);
            diagnostics = ProjectionAlignmentCoplanarity.evaluateRays( ...
                movingOrigins, movingVectors, referenceOrigins, ...
                referenceVectors);
            residuals = diagnostics.Residuals;
            residuals(~diagnostics.ValidMask) = 1;
        end

        function [origins, vectors] = sourceRays(layer, correction, rows, ...
                columns, renderOrigin, ~, sharedScale)
            rows = ProjectionAlignmentOpkSolver.scaleSourceRows( ...
                rows, layer, sharedScale);
            if ProjectionAlignmentOpkSolver.hasObservationRaySampler(layer)
                [origins, vectors] = ProjectionAlignmentOpkSolver.sampleObservationRays( ...
                    layer, rows, columns);
                rotation = ProjectionAlignmentOpkSolver.layerViewVectorRotation( ...
                    layer, correction.ViewVectorAngularOffsetsDegrees);
                vectors = ProjectionAlignmentOpkSolver.normalizeVectors( ...
                    rotation * vectors);
                return
            end

            projectedLayer = layer;
            projectedLayer.ViewVectorAngularOffsetsDegrees = ...
                correction.ViewVectorAngularOffsetsDegrees(:);
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
            delta = G1 - G2;
            a = sum(V1 .* V1, 1);
            b = sum(V1 .* V2, 1);
            c = sum(V2 .* V2, 1);
            d = sum(V1 .* delta, 1);
            e = sum(V2 .* delta, 1);
            denominator = a .* c - b.^2;
            parallel = abs(denominator) <= ...
                ProjectionAlignmentOpkSolver.defaultTolerance();
            denominator(parallel) = 1;
            movingRange = (b .* e - c .* d) ./ denominator;
            referenceRange = (a .* e - b .* d) ./ denominator;
            residuals = delta + V1 .* movingRange - V2 .* referenceRange;
            if any(parallel)
                projection = sum(delta(:, parallel) .* V1(:, parallel), 1) ./ ...
                    a(parallel);
                residuals(:, parallel) = delta(:, parallel) - ...
                    V1(:, parallel) .* projection;
            end
        end

        function coordinates = projectObservations(layer, correction, rows, ...
                columns, renderOrigin, commonPlane, sharedScale)
            [origins, vectors] = ProjectionAlignmentOpkSolver.sourceRays( ...
                layer, correction, rows, columns, renderOrigin, ...
                commonPlane, sharedScale);
            worldPoints = ProjectionAlignmentOpkSolver.intersectObservationRays( ...
                origins, vectors, layer.CurrentProjectionPlane);
            offsetWorld = layer.CurrentProjectionPlane.basis * ...
                correction.ProjectionOffsetMeters(:);
            worldPoints = worldPoints + offsetWorld;
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

        function result = resultStruct(matchResult, parameterModel, xSolved, ...
                beforeResiduals, afterResiduals, perPairResiduals, ...
                solverResiduals, exitFlag, output, comparisonDiagnostics, ...
                observabilityDiagnostics, options, totalSeconds)
            [solvedCorrections, sharedScale] = ...
                ProjectionAlignmentParameterModel.corrections( ...
                parameterModel, xSolved);
            boundDiagnostics = ...
                ProjectionAlignmentParameterModel.boundDiagnostics( ...
                parameterModel, solvedCorrections, sharedScale);
            residualDiagnostics = ProjectionAlignmentOpkSolver.residualDiagnostics( ...
                matchResult, perPairResiduals);
            result = struct();
            result.Status = "solved";
            result.RequestSummary = ProjectionAlignmentOpkSolver.requestSummary( ...
                matchResult, parameterModel.LayerIndices, options);
            result.Matches = ProjectionAlignmentOpkSolver.resultMatches(matchResult);
            result.SolverObservations = ...
                ProjectionAlignmentOpkSolver.resultInliers(matchResult);
            result.Inliers = result.SolverObservations;
            result.MatchLedger = ProjectionAlignmentOpkSolver.resultMatchLedger( ...
                matchResult, perPairResiduals, options.LossMode);
            result.Residuals = struct(LossMode=options.LossMode, ...
                Unit=ProjectionAlignmentOpkSolver.residualUnit(options.LossMode), ...
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
            if boundDiagnostics.Any
                result.Warnings = ...
                    "Alignment solve hit one or more configured parameter bounds.";
            else
                result.Warnings = strings(1, 0);
            end
            result.Timing = struct(StartedAt="", FinishedAt="", ...
                TotalSeconds=totalSeconds, StageSeconds=struct(Solver=totalSeconds));
            result.Diagnostics = struct();
            result.Diagnostics.StartingCorrections = ...
                parameterModel.StartCorrections;
            result.Diagnostics.BoundsDegrees = parameterModel.BoundsDegrees;
            result.Diagnostics.BoundHits = boundDiagnostics.Layers;
            result.Diagnostics.SharedScaleBoundHit = ...
                boundDiagnostics.SharedScaleHit;
            result.Diagnostics.AnyBoundHit = boundDiagnostics.Any;
            result.Diagnostics.SharedScale = sharedScale;
            result.Diagnostics.Comparison = comparisonDiagnostics;
            result.Diagnostics.AttitudeModel = ...
                ProjectionAlignmentParameterModel.decomposition( ...
                parameterModel, xSolved);
            result.Diagnostics.Observability = observabilityDiagnostics;
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
            if ~isempty(observabilityDiagnostics.WeakModes)
                result.Warnings(end + 1) = ...
                    "Weak/prior-dominated alignment modes: " + ...
                    strjoin(observabilityDiagnostics.WeakModes, ", ") + ".";
            end
            if observabilityDiagnostics.HardFailure
                result.Status = "failed";
                result.Convergence.Status = "failed";
                result.Convergence.Success = false;
                result.Convergence.Message = result.Convergence.Message + ...
                    " One or more requested modes are unobservable and have no prior support.";
            end
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

        function records = resultMatchLedger(matchResult, perPairResiduals, lossMode)
            matchResultWithResiduals = matchResult;
            residualUnit = ProjectionAlignmentOpkSolver.residualUnit(lossMode);
            for pairIndex = 1:numel(matchResultWithResiduals.Matches)
                pairMatch = ProjectionAlignmentMatchLedger.ensurePair( ...
                    matchResultWithResiduals.Matches(pairIndex));
                rawMatchIndices = ProjectionAlignmentOpkSolver.matchRecordIndices( ...
                    pairMatch);
                pairMatch.MatchLedger = ...
                    ProjectionAlignmentMatchLedger.markSolverResiduals( ...
                    pairMatch.MatchLedger, rawMatchIndices, ...
                    perPairResiduals(pairIndex).Before, ...
                    perPairResiduals(pairIndex).After, lossMode, residualUnit);
                if pairIndex == 1
                    pairMatches = pairMatch;
                else
                    pairMatches(pairIndex) = pairMatch;
                end
            end
            matchResultWithResiduals.Matches = pairMatches;
            records = ProjectionAlignmentMatchLedger.combine( ...
                matchResultWithResiduals);
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

        function recordIndices = matchRecordIndices(pairMatch)
            recordIndices = (1:pairMatch.Count).';
            if isfield(pairMatch, "MatchRecordIndices") && ...
                    numel(pairMatch.MatchRecordIndices) == pairMatch.Count
                recordIndices = pairMatch.MatchRecordIndices(:);
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

        function summary = requestSummary(matchResult, layerIndices, options)
            referenceIndex = layerIndices(ceil(numel(layerIndices) / 2));
            layerIds = arrayfun(@(index) string(sprintf( ...
                "legacy-layer-%06d", index)), layerIndices);
            referenceLayerId = layerIds(layerIndices == referenceIndex);
            schedulingStrategy = "pairwiseJoint";
            if isfield(matchResult, "Schedule")
                schedule = matchResult.Schedule;
                if isfield(schedule, "ReferenceLayerIndex")
                    referenceIndex = schedule.ReferenceLayerIndex;
                end
                if isfield(schedule, "Strategy")
                    schedulingStrategy = schedule.Strategy;
                end
                if isfield(schedule, "LayerIds") && ...
                        numel(schedule.LayerIds) == numel(layerIndices)
                    layerIds = reshape(string(schedule.LayerIds), 1, []);
                end
                if isfield(schedule, "ReferenceLayerId") && ...
                        strlength(string(schedule.ReferenceLayerId)) > 0
                    referenceLayerId = string(schedule.ReferenceLayerId);
                else
                    referenceLayerId = layerIds(layerIndices == referenceIndex);
                end
            end
            summary = struct(LayerIndices=layerIndices, ...
                LayerIds=layerIds, ...
                ReferenceLayerIndex=referenceIndex, ...
                ReferenceLayerId=referenceLayerId, ...
                AnalysisBands=ones(1, numel(layerIndices)), ...
                LossMode=options.LossMode, ...
                SchedulingStrategy=schedulingStrategy, ...
                MovableParameters=options.MovableParameters.Parameters);
        end

        function pairs = residualPairs(xBefore, xAfter, scene, matchResult, ...
                parameterModel, commonPlane, options)
            beforeByPair = ProjectionAlignmentOpkSolver.dataResidualsByPair( ...
                xBefore, scene, matchResult, parameterModel, commonPlane, options);
            afterByPair = ProjectionAlignmentOpkSolver.dataResidualsByPair( ...
                xAfter, scene, matchResult, parameterModel, commonPlane, options);
            pairs = struct("Pair", {}, "Before", {}, "After", {}, "Count", {});
            for k = 1:numel(matchResult.Matches)
                pairs(k).Pair = matchResult.Matches(k).Pair;
                pairs(k).Before = ProjectionAlignmentOpkSolver.residualNorms( ...
                    beforeByPair{k}, ...
                    ProjectionAlignmentOpkSolver.lossComponentCount( ...
                    options.LossMode));
                pairs(k).After = ProjectionAlignmentOpkSolver.residualNorms( ...
                    afterByPair{k}, ...
                    ProjectionAlignmentOpkSolver.lossComponentCount( ...
                    options.LossMode));
                pairs(k).Count = matchResult.Matches(k).Count;
            end
        end

        function diagnostics = comparisonDiagnostics(xBefore, xAfter, scene, ...
                matchResult, parameterModel, commonPlane, options)
            diagnostics = struct();
            modes = ["projectionPlane2D", "rayToRay3D", ...
                "epipolarCoplanarity"];
            fieldNames = ["ProjectionPlane2D", "ForwardRay3D", ...
                "EpipolarCoplanarity"];
            for k = 1:numel(modes)
                metricOptions = options;
                metricOptions.LossMode = modes(k);
                before = ProjectionAlignmentOpkSolver.dataResiduals( ...
                    xBefore, scene, matchResult, parameterModel, commonPlane, ...
                    metricOptions);
                after = ProjectionAlignmentOpkSolver.dataResiduals( ...
                    xAfter, scene, matchResult, parameterModel, commonPlane, ...
                    metricOptions);
                componentCount = ...
                    ProjectionAlignmentOpkSolver.lossComponentCount(modes(k));
                beforeNorms = ProjectionAlignmentOpkSolver.residualNorms( ...
                    before, componentCount);
                afterNorms = ProjectionAlignmentOpkSolver.residualNorms( ...
                    after, componentCount);
                metric = struct(Unit= ...
                    ProjectionAlignmentOpkSolver.residualUnit(modes(k)), ...
                    RmsBefore=ProjectionAlignmentOpkSolver.rmsOrNaN(beforeNorms), ...
                    RmsAfter=ProjectionAlignmentOpkSolver.rmsOrNaN(afterNorms), ...
                    ResidualsBefore=beforeNorms, ResidualsAfter=afterNorms);
                diagnostics.(fieldNames(k)) = metric;
            end
            diagnostics.ProjectionPlaneRmsBefore = ...
                diagnostics.ProjectionPlane2D.RmsBefore;
            diagnostics.ProjectionPlaneRmsAfter = ...
                diagnostics.ProjectionPlane2D.RmsAfter;
            diagnostics.Ray3DRmsBefore = diagnostics.ForwardRay3D.RmsBefore;
            diagnostics.Ray3DRmsAfter = diagnostics.ForwardRay3D.RmsAfter;
            diagnostics.CoplanarityRmsBefore = ...
                diagnostics.EpipolarCoplanarity.RmsBefore;
            diagnostics.CoplanarityRmsAfter = ...
                diagnostics.EpipolarCoplanarity.RmsAfter;
            diagnostics.EpipolarCoplanarity.PerPair = ...
                ProjectionAlignmentOpkSolver.coplanarityDiagnosticsByPair( ...
                xBefore, xAfter, scene, matchResult, parameterModel, ...
                commonPlane, options);
        end

        function diagnostics = coplanarityDiagnosticsByPair( ...
                xBefore, xAfter, scene, matchResult, parameterModel, ...
                commonPlane, options)
            [beforeCorrections, beforeScale] = ...
                ProjectionAlignmentParameterModel.corrections( ...
                parameterModel, xBefore);
            [afterCorrections, afterScale] = ...
                ProjectionAlignmentParameterModel.corrections( ...
                parameterModel, xAfter);
            diagnostics = struct("Pair", {}, "PairLayerIds", {}, ...
                "Unit", {}, "ResidualsBefore", {}, "ResidualsAfter", {}, ...
                "ValidBefore", {}, "ValidAfter", {}, "StatusBefore", {}, ...
                "StatusAfter", {}, "DegenerateAfter", {}, ...
                "RobustWeightsAfter", {});
            for k = 1:numel(matchResult.Matches)
                pairMatch = matchResult.Matches(k);
                before = ProjectionAlignmentOpkSolver. ...
                    correctedCoplanarityEvaluation(scene, pairMatch, ...
                    beforeCorrections, beforeScale, commonPlane);
                after = ProjectionAlignmentOpkSolver. ...
                    correctedCoplanarityEvaluation(scene, pairMatch, ...
                    afterCorrections, afterScale, commonPlane);
                robustValues = ProjectionAlignmentOpkSolver.robustResiduals( ...
                    after.Residuals, options.Regularization);
                robustWeights = zeros(size(after.Residuals));
                finiteNonzero = after.ValidMask & ...
                    abs(after.Residuals) > eps;
                robustWeights(finiteNonzero) = ...
                    (robustValues(finiteNonzero) ./ ...
                    after.Residuals(finiteNonzero)).^2;
                robustWeights(after.ValidMask & ~finiteNonzero) = 1;
                diagnostics(k).Pair = pairMatch.Pair;
                if isfield(pairMatch, "PairLayerIds")
                    diagnostics(k).PairLayerIds = pairMatch.PairLayerIds;
                else
                    diagnostics(k).PairLayerIds = ...
                        ProjectionLayerIdentity.idsForIndices( ...
                        scene, pairMatch.Pair);
                end
                diagnostics(k).Unit = "normalizedAngular";
                diagnostics(k).ResidualsBefore = before.Residuals;
                diagnostics(k).ResidualsAfter = after.Residuals;
                diagnostics(k).ValidBefore = before.ValidMask;
                diagnostics(k).ValidAfter = after.ValidMask;
                diagnostics(k).StatusBefore = before.Status;
                diagnostics(k).StatusAfter = after.Status;
                diagnostics(k).DegenerateAfter = ~after.ValidMask;
                diagnostics(k).RobustWeightsAfter = robustWeights;
            end
        end

        function evaluation = correctedCoplanarityEvaluation(scene, pairMatch, ...
                corrections, sharedScale, commonPlane)
            movingCorrection = ProjectionAlignmentOpkSolver.correctionForLayer( ...
                corrections, pairMatch.Pair(1));
            referenceCorrection = ProjectionAlignmentOpkSolver.correctionForLayer( ...
                corrections, pairMatch.Pair(2));
            [movingOrigins, movingVectors] = ProjectionAlignmentOpkSolver.sourceRays( ...
                scene.layers(pairMatch.Pair(1)), movingCorrection, ...
                pairMatch.MovingSourceRows, pairMatch.MovingSourceColumns, ...
                scene.renderOrigin, commonPlane, sharedScale);
            [referenceOrigins, referenceVectors] = ...
                ProjectionAlignmentOpkSolver.sourceRays( ...
                scene.layers(pairMatch.Pair(2)), referenceCorrection, ...
                pairMatch.ReferenceSourceRows, ...
                pairMatch.ReferenceSourceColumns, scene.renderOrigin, ...
                commonPlane, sharedScale);
            evaluation = ProjectionAlignmentCoplanarity.evaluateRays( ...
                movingOrigins, movingVectors, referenceOrigins, ...
                referenceVectors);
        end

        function diagnostics = observabilityDiagnostics(xStart, xSolved, ...
                scene, matchResult, parameterModel, commonPlane, options)
            diagnostics = struct();
            diagnostics.Method = ...
                "centralFiniteDifferenceRobustDataJacobianCommonDifferential";
            diagnostics.Start = ProjectionAlignmentOpkSolver. ...
                observabilityAt(xStart, scene, matchResult, parameterModel, ...
                commonPlane, options);
            diagnostics.Solution = ProjectionAlignmentOpkSolver. ...
                observabilityAt(xSolved, scene, matchResult, parameterModel, ...
                commonPlane, options);
            diagnostics.HardFailure = ...
                diagnostics.Solution.HasUnsupportedUnobservableMode;
            diagnostics.WeakModes = diagnostics.Solution.WeakModes;
        end

        function diagnostics = observabilityAt(x, scene, matchResult, ...
                parameterModel, commonPlane, options)
            [transform, labels, priorSupported, fixed] = ...
                ProjectionAlignmentParameterModel.modeTransform(parameterModel);
            base = ProjectionAlignmentOpkSolver.dataResiduals( ...
                x, scene, matchResult, parameterModel, commonPlane, options);
            base = ProjectionAlignmentOpkSolver.robustResiduals( ...
                base, options.Regularization);
            jacobian = zeros(numel(base), numel(x));
            steps = ProjectionAlignmentOpkSolver.observabilitySteps( ...
                parameterModel);
            for k = 1:numel(x)
                xPlus = x;
                xMinus = x;
                xPlus(k) = xPlus(k) + steps(k);
                xMinus(k) = xMinus(k) - steps(k);
                plus = ProjectionAlignmentOpkSolver.dataResiduals( ...
                    xPlus, scene, matchResult, parameterModel, commonPlane, ...
                    options);
                minus = ProjectionAlignmentOpkSolver.dataResiduals( ...
                    xMinus, scene, matchResult, parameterModel, commonPlane, ...
                    options);
                plus = ProjectionAlignmentOpkSolver.robustResiduals( ...
                    plus, options.Regularization);
                minus = ProjectionAlignmentOpkSolver.robustResiduals( ...
                    minus, options.Regularization);
                jacobian(:, k) = (plus(:) - minus(:)) / (2 * steps(k));
            end
            modeJacobian = jacobian * transform;
            [~, singularMatrix, rightVectors] = svd(modeJacobian);
            singularValues = diag(singularMatrix).';
            if isempty(singularValues)
                tolerance = 0;
                rankValue = 0;
            else
                tolerance = max(size(modeJacobian)) * eps( ...
                    max(singularValues)) * 100;
                rankValue = nnz(singularValues > tolerance);
            end
            modeCount = size(modeJacobian, 2);
            if rankValue < modeCount
                nullVectors = rightVectors(:, rankValue + 1:end);
                observedFraction = 1 - sum(nullVectors.^2, 2).';
            else
                observedFraction = ones(1, modeCount);
            end
            observedFraction = min(max(observedFraction, 0), 1);
            sensitivity = vecnorm(modeJacobian, 2, 1);
            if isempty(sensitivity)
                sensitivityTolerance = 1e-12;
            else
                sensitivityTolerance = max(1e-12, ...
                    max(sensitivity) * 1e-7);
            end
            modes = struct("Name", {}, "Status", {}, ...
                "SensitivityNorm", {}, "ObservedFraction", {}, ...
                "PriorSupported", {}, "Fixed", {});
            for k = 1:modeCount
                if fixed(k)
                    status = "fixed";
                elseif sensitivity(k) <= sensitivityTolerance || ...
                        observedFraction(k) < 0.05
                    if priorSupported(k)
                        status = "priorDominated";
                    else
                        status = "unobservable";
                    end
                elseif observedFraction(k) < 0.95
                    status = "partiallyObserved";
                else
                    status = "dataObserved";
                end
                modes(k) = struct(Name=labels(k), Status=status, ...
                    SensitivityNorm=sensitivity(k), ...
                    ObservedFraction=observedFraction(k), ...
                    PriorSupported=priorSupported(k), Fixed=fixed(k));
            end
            if rankValue > 0
                conditionNumber = singularValues(1) / ...
                    singularValues(rankValue);
            else
                conditionNumber = Inf;
            end
            statuses = string({modes.Status});
            diagnostics = struct(JacobianSize=size(modeJacobian), ...
                SingularValues=singularValues, Rank=rankValue, ...
                RankTolerance=tolerance, ConditionNumber=conditionNumber, ...
                Modes=modes, WeakModes=labels(~ismember(statuses, ...
                ["dataObserved", "fixed"])), ...
                HasUnsupportedUnobservableMode=any(statuses == "unobservable"));
        end

        function steps = observabilitySteps(parameterModel)
            steps = 1e-5 * ones(numel(parameterModel.X0), 1);
            if any(parameterModel.OffsetIndices(:) > 0)
                steps(parameterModel.OffsetIndices(:)) = 1e-3;
            end
            if parameterModel.SharedScaleIndex > 0
                steps(parameterModel.SharedScaleIndex) = 1e-6;
            end
        end

        function matches = resultMatches(matchResult)
            for k = 1:numel(matchResult.Matches)
                pairMatch = ProjectionAlignmentMatchLedger.ensurePair( ...
                    matchResult.Matches(k));
                match = struct();
                match.Pair = pairMatch.Pair;
                match.PairLayerIds = pairMatch.PairLayerIds;
                match.MovingLayerId = pairMatch.MovingLayerId;
                match.ReferenceLayerId = pairMatch.ReferenceLayerId;
                match.PairDirection = pairMatch.PairDirection;
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
                pairMatch = ProjectionAlignmentMatchLedger.ensurePair( ...
                    matchResult.Matches(k));
                inlier = struct();
                inlier.Pair = pairMatch.Pair;
                inlier.PairLayerIds = pairMatch.PairLayerIds;
                inlier.Mask = true(pairMatch.Count, 1);
                inlier.Count = pairMatch.Count;
                inlier.Method = "solverObservations";
                inlier.Meaning = "solverObservations";
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
            elseif lossMode == "epipolarCoplanarity"
                count = 1;
            else
                count = 2;
            end
        end

        function unit = residualUnit(lossMode)
            if lossMode == "rayToRay3D"
                unit = "rayMeters";
            elseif lossMode == "epipolarCoplanarity"
                unit = "normalizedAngular";
            else
                unit = "planeMeters";
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
                correction.LayerId = string(layer.LayerId);
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

        function correction = correctionForLayer(corrections, layerIndex)
            correction = corrections([corrections.LayerIndex] == layerIndex);
            correction = correction(1);
        end

        function scene = setCorrections(scene, corrections)
            scene = ProjectionLayerIdentity.ensureScene(scene);
            for k = 1:numel(corrections)
                if isfield(corrections(k), "LayerId") && ...
                        strlength(string(corrections(k).LayerId)) > 0
                    layerIndex = ProjectionLayerIdentity.indexForId( ...
                        scene, corrections(k).LayerId);
                else
                    layerIndex = corrections(k).LayerIndex;
                end
                scene.layers(layerIndex).ViewVectorAngularOffsetsDegrees = ...
                    corrections(k).ViewVectorAngularOffsetsDegrees(:);
                scene.layers(layerIndex).ProjectionOffsetMeters = ...
                    corrections(k).ProjectionOffsetMeters(:);
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
