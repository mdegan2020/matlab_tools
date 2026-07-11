classdef ProjectionAlignmentCommonAnchor
    %ProjectionAlignmentCommonAnchor Two-DOF shared stereo anchor adjustment.

    properties (Constant)
        Format = "ProjectionAlignmentCommonAnchorState"
        Version = 1
        JacobianStepDegrees = 1e-3
        MinimumJacobianReciprocalCondition = 1e-8
        DisparityPenaltyWeight = 0.1
        MaximumForwardRayDegradationFraction = 0.1
    end

    methods (Static)
        function state = prepare(scene, matchResult, pair, matchIndex, ...
                plane, options)
            %prepare Capture an immutable, graphics-free anchor drag state.
            scene = ProjectionLayerIdentity.ensureScene(scene);
            PlanarProjection.validatePlane(plane);
            options = ProjectionAlignmentOptions.validate(options);
            pair = ProjectionAlignmentCommonAnchor.validatePair(scene, pair);
            pairMatch = ProjectionAlignmentCommonAnchor.findPairMatch( ...
                matchResult, pair);
            observationIndex = ...
                ProjectionAlignmentCommonAnchor.observationIndex( ...
                pairMatch, matchIndex);
            selectedMatch = ProjectionAlignmentCommonAnchor.selectObservation( ...
                pairMatch, observationIndex);

            startCorrections = ...
                ProjectionAlignmentCommonAnchor.layerCorrections(scene, pair);
            anchorOptions = ...
                ProjectionAlignmentCommonAnchor.anchorOptions(options);
            parameterModel = ProjectionAlignmentParameterModel.create( ...
                scene, struct(Matches=pairMatch), pair, startCorrections, ...
                anchorOptions);
            commonBounds = min(parameterModel.BoundsDegrees(:, 1:2), [], 1);
            if any(~isfinite(commonBounds)) || any(commonBounds <= 0)
                error("ProjectionAlignmentCommonAnchor:invalidBounds", ...
                    "Common-anchor omega/phi bounds must be finite and positive.");
            end

            state = struct();
            state.Format = ProjectionAlignmentCommonAnchor.Format;
            state.Version = ProjectionAlignmentCommonAnchor.Version;
            state.StartScene = scene;
            state.MatchResult = matchResult;
            state.SelectedMatch = selectedMatch;
            state.Pair = pair;
            state.LayerIds = ProjectionLayerIdentity.idsForIndices(scene, pair);
            state.MatchIndex = double(matchIndex);
            state.Plane = plane;
            state.Options = anchorOptions;
            state.StartingCorrections = startCorrections;
            state.CommonBoundsDegrees = commonBounds;
            state.AdjustedCommonModes = ["omega", "phi"];
            endpointPrecision = 1 ./ mean( ...
                parameterModel.PointingSigmaDegrees(:, 1:2).^2, 2);
            state.EndpointWeights = reshape( ...
                endpointPrecision / sum(endpointPrecision), 1, []);

            startEvaluation = ...
                ProjectionAlignmentCommonAnchor.evaluateDelta(state, [0 0]);
            state.StartingProjectionPoints = startEvaluation.ProjectionPoints;
            state.StartingCentroid = startEvaluation.Centroid;
            state.StartingDisparity = startEvaluation.Disparity;
            state.Jacobian = ProjectionAlignmentCommonAnchor.numericJacobian( ...
                state, [0 0]);
            [state.JacobianReciprocalCondition, state.JacobianSingularValues] = ...
                ProjectionAlignmentCommonAnchor.jacobianCondition(state.Jacobian);
            state.CanDrag = state.JacobianReciprocalCondition >= ...
                ProjectionAlignmentCommonAnchor. ...
                MinimumJacobianReciprocalCondition;
            if ~state.CanDrag
                error("ProjectionAlignmentCommonAnchor:illConditioned", ...
                    "The selected anchor cannot constrain common omega/phi at this geometry.");
            end
        end

        function preview = preview(state, targetPlanePoint)
            %preview Apply the cached local Jacobian without iterative solving.
            ProjectionAlignmentCommonAnchor.validateState(state);
            target = ProjectionAlignmentCommonAnchor.validateTarget( ...
                targetPlanePoint);
            delta = state.Jacobian \ (target - state.StartingCentroid).';
            delta = reshape(delta, 1, []);
            delta = min(max(delta, -state.CommonBoundsDegrees), ...
                state.CommonBoundsDegrees);
            evaluation = ProjectionAlignmentCommonAnchor.evaluateDelta( ...
                state, delta);
            preview = evaluation;
            preview.TargetPlanePoint = target;
            preview.TargetErrorMeters = norm(evaluation.Centroid - target);
            preview.BoundLimited = any(abs(delta) >= ...
                state.CommonBoundsDegrees - 1e-10);
            preview.Status = "preview";
        end

        function result = refine(state, targetPlanePoint)
            %refine Run the exact bounded release solve and safety checks.
            ProjectionAlignmentCommonAnchor.validateState(state);
            target = ProjectionAlignmentCommonAnchor.validateTarget( ...
                targetPlanePoint);
            preview = ProjectionAlignmentCommonAnchor.preview(state, target);
            solverOptions = optimoptions("lsqnonlin", Display="off", ...
                MaxIterations=30, FunctionTolerance=1e-10, ...
                StepTolerance=1e-10);
            objective = @(delta) ...
                ProjectionAlignmentCommonAnchor.anchorResiduals( ...
                state, delta, target);
            [delta, residual, ~, exitFlag, output] = lsqnonlin( ...
                objective, preview.CommonDeltaDegrees, ...
                -state.CommonBoundsDegrees, state.CommonBoundsDegrees, ...
                solverOptions);
            delta = reshape(delta, 1, []);
            evaluation = ProjectionAlignmentCommonAnchor.evaluateDelta( ...
                state, delta);
            finalJacobian = ProjectionAlignmentCommonAnchor.numericJacobian( ...
                state, delta);
            [reciprocalCondition, singularValues] = ...
                ProjectionAlignmentCommonAnchor.jacobianCondition(finalJacobian);
            tolerance = max(1e-8, 1e-6 * state.CommonBoundsDegrees);
            boundHitMask = abs(abs(delta) - state.CommonBoundsDegrees) <= ...
                tolerance;
            comparison = ProjectionAlignmentOpkSolver.compareScenes( ...
                state.StartScene, evaluation.Scene, state.MatchResult, ...
                state.Options);
            rayBefore = comparison.ForwardRay3D.RmsBefore;
            rayAfter = comparison.ForwardRay3D.RmsAfter;
            rayTolerance = max(1e-6, 1e-6 * max(abs(rayBefore), 1));
            rayDegraded = isfinite(rayBefore) && isfinite(rayAfter) && ...
                rayAfter > rayBefore * (1 + ...
                ProjectionAlignmentCommonAnchor. ...
                MaximumForwardRayDegradationFraction) + rayTolerance;

            success = exitFlag > 0 && ...
                reciprocalCondition >= ProjectionAlignmentCommonAnchor. ...
                MinimumJacobianReciprocalCondition && ...
                ~any(boundHitMask) && ~rayDegraded;
            failureReason = "";
            if exitFlag <= 0
                failureReason = "Exact anchor refinement did not converge.";
            elseif reciprocalCondition < ProjectionAlignmentCommonAnchor. ...
                    MinimumJacobianReciprocalCondition
                failureReason = "Anchor refinement became ill-conditioned.";
            elseif any(boundHitMask)
                failureReason = "Anchor refinement hit an omega/phi bound.";
            elseif rayDegraded
                failureReason = ...
                    "Anchor refinement materially degraded forward-ray residuals.";
            end

            result = evaluation;
            result.Status = "failed";
            if success
                result.Status = "succeeded";
            end
            result.Success = success;
            result.FailureReason = failureReason;
            result.TargetPlanePoint = target;
            result.TargetErrorMeters = norm(evaluation.Centroid - target);
            result.Jacobian = finalJacobian;
            result.JacobianReciprocalCondition = reciprocalCondition;
            result.JacobianSingularValues = singularValues;
            result.BoundHitMask = boundHitMask;
            result.AnyBoundHit = any(boundHitMask);
            result.ForwardRayRmsBefore = rayBefore;
            result.ForwardRayRmsAfter = rayAfter;
            result.Comparison = comparison;
            result.Objective = sum(residual.^2);
            result.ExitFlag = exitFlag;
            result.Iterations = output.iterations;
            result.AdjustedCommonModes = state.AdjustedCommonModes;
            result.CommonBoundsDegrees = state.CommonBoundsDegrees;
            result.MatchIndex = state.MatchIndex;
            result.Pair = state.Pair;
            result.LayerIds = state.LayerIds;
            result.StartingProjectionPoints = state.StartingProjectionPoints;
            result.StartingCentroid = state.StartingCentroid;
            result.StartingDisparity = state.StartingDisparity;
            result.EndpointWeights = state.EndpointWeights;
            result.StartingCorrections = state.StartingCorrections;
        end

        function scene = applyCorrections(scene, corrections)
            %applyCorrections Apply stable-ID corrections without other mutation.
            scene = ProjectionLayerIdentity.ensureScene(scene);
            for k = 1:numel(corrections)
                layerIndex = ProjectionLayerIdentity.indexForId( ...
                    scene, corrections(k).LayerId);
                scene.layers(layerIndex).ViewVectorAngularOffsetsDegrees = ...
                    reshape(corrections(k).ViewVectorAngularOffsetsDegrees, 3, 1);
            end
        end
    end

    methods (Static, Access = private)
        function options = anchorOptions(options)
            options.MovableParameters.Parameters = ["omega", "phi"];
            options.MovableParameters.AllowReferenceMotion = true;
            options.MovableParameters.IncludeProjectionOffsets = false;
            options.MovableParameters.IncludeSharedScale = false;
            options = ProjectionAlignmentOptions.validate(options);
        end

        function evaluation = evaluateDelta(state, delta)
            delta = reshape(double(delta), 1, []);
            if numel(delta) ~= 2 || any(~isfinite(delta))
                error("ProjectionAlignmentCommonAnchor:invalidDelta", ...
                    "Common omega/phi delta must be a finite two-vector.");
            end
            corrections = state.StartingCorrections;
            for k = 1:numel(corrections)
                opk = reshape( ...
                    corrections(k).ViewVectorAngularOffsetsDegrees, 1, 3);
                opk(1:2) = opk(1:2) + delta;
                corrections(k).ViewVectorAngularOffsetsDegrees = opk;
            end
            scene = ProjectionAlignmentCommonAnchor.applyCorrections( ...
                state.StartScene, corrections);
            points = ProjectionAlignmentCommonAnchor.projectSelected( ...
                scene, state.SelectedMatch, state.Pair, state.Plane);
            centroid = state.EndpointWeights * points;
            evaluation = struct(Scene=scene, Corrections=corrections, ...
                CommonDeltaDegrees=delta, ProjectionPoints=points, ...
                Centroid=centroid, Disparity=points(1, :) - points(2, :));
        end

        function residuals = anchorResiduals(state, delta, target)
            evaluation = ProjectionAlignmentCommonAnchor.evaluateDelta( ...
                state, delta);
            centroidResidual = evaluation.Centroid - target;
            disparityResidual = ProjectionAlignmentCommonAnchor. ...
                DisparityPenaltyWeight * ...
                (evaluation.Disparity - state.StartingDisparity);
            residuals = [centroidResidual(:); disparityResidual(:)];
        end

        function jacobian = numericJacobian(state, delta)
            step = ProjectionAlignmentCommonAnchor.JacobianStepDegrees;
            jacobian = zeros(2, 2);
            for parameterIndex = 1:2
                positive = delta;
                negative = delta;
                positive(parameterIndex) = positive(parameterIndex) + step;
                negative(parameterIndex) = negative(parameterIndex) - step;
                positiveEvaluation = ...
                    ProjectionAlignmentCommonAnchor.evaluateDelta( ...
                    state, positive);
                negativeEvaluation = ...
                    ProjectionAlignmentCommonAnchor.evaluateDelta( ...
                    state, negative);
                jacobian(:, parameterIndex) = ...
                    (positiveEvaluation.Centroid - ...
                    negativeEvaluation.Centroid).' / (2 * step);
            end
        end

        function [reciprocalCondition, singularValues] = ...
                jacobianCondition(jacobian)
            singularValues = svd(jacobian);
            if numel(singularValues) < 2 || singularValues(1) <= eps
                reciprocalCondition = 0;
            else
                reciprocalCondition = singularValues(end) / singularValues(1);
            end
        end

        function points = projectSelected(scene, selectedMatch, pair, plane)
            moving = ProjectionAlignmentObservationProjector.project( ...
                scene, pair(1), selectedMatch.MovingSourceRows, ...
                selectedMatch.MovingSourceColumns, plane);
            reference = ProjectionAlignmentObservationProjector.project( ...
                scene, pair(2), selectedMatch.ReferenceSourceRows, ...
                selectedMatch.ReferenceSourceColumns, plane);
            if ~all(moving.ValidMask) || ~all(reference.ValidMask)
                error("ProjectionAlignmentCommonAnchor:invalidProjection", ...
                    "The selected anchor must project in front of both sources.");
            end
            points = [moving.PlaneCoordinates; reference.PlaneCoordinates];
        end

        function corrections = layerCorrections(scene, pair)
            for k = 1:2
                layer = scene.layers(pair(k));
                correction = struct();
                correction.LayerIndex = pair(k);
                correction.LayerId = string(layer.LayerId);
                if isfield(layer, "ViewVectorAngularOffsetsDegrees")
                    correction.ViewVectorAngularOffsetsDegrees = reshape( ...
                        double(layer.ViewVectorAngularOffsetsDegrees), 1, 3);
                else
                    correction.ViewVectorAngularOffsetsDegrees = [0 0 0];
                end
                if isfield(layer, "ProjectionOffsetMeters")
                    correction.ProjectionOffsetMeters = reshape( ...
                        double(layer.ProjectionOffsetMeters), 1, 2);
                else
                    correction.ProjectionOffsetMeters = [0 0];
                end
                correction.SharedScale = 1;
                corrections(k) = correction; %#ok<AGROW>
            end
        end

        function pair = validatePair(scene, pair)
            pair = reshape(double(pair), 1, []);
            if numel(pair) ~= 2 || any(~isfinite(pair)) || ...
                    any(pair ~= round(pair)) || any(pair < 1) || ...
                    any(pair > numel(scene.layers)) || pair(1) == pair(2)
                error("ProjectionAlignmentCommonAnchor:invalidPair", ...
                    "Anchor pair must contain two distinct current layer indices.");
            end
        end

        function pairMatch = findPairMatch(matchResult, pair)
            if ~isstruct(matchResult) || ~isfield(matchResult, "Matches")
                error("ProjectionAlignmentCommonAnchor:invalidMatches", ...
                    "Anchor adjustment requires a filtered match result.");
            end
            matches = matchResult.Matches;
            position = find(arrayfun(@(value) ...
                isequal(double(value.Pair), pair), matches), 1, "first");
            if isempty(position)
                error("ProjectionAlignmentCommonAnchor:unknownPair", ...
                    "The selected anchor pair is not enabled and filtered.");
            end
            pairMatch = matches(position);
        end

        function index = observationIndex(pairMatch, matchIndex)
            indices = (1:pairMatch.Count).';
            if isfield(pairMatch, "MatchRecordIndices") && ...
                    numel(pairMatch.MatchRecordIndices) == pairMatch.Count
                indices = pairMatch.MatchRecordIndices(:);
            end
            index = find(indices == matchIndex, 1, "first");
            if isempty(index)
                error("ProjectionAlignmentCommonAnchor:unknownMatch", ...
                    "The selected match is not an accepted filtered observation.");
            end
        end

        function selected = selectObservation(pairMatch, index)
            fields = ["MovingSourceRows", "MovingSourceColumns", ...
                "ReferenceSourceRows", "ReferenceSourceColumns"];
            selected = struct();
            for field = fields
                selected.(field) = pairMatch.(field)(index);
            end
        end

        function target = validateTarget(target)
            target = reshape(double(target), 1, []);
            if numel(target) ~= 2 || any(~isfinite(target))
                error("ProjectionAlignmentCommonAnchor:invalidTarget", ...
                    "Anchor target must be a finite two-vector in plane coordinates.");
            end
        end

        function validateState(state)
            if ~isstruct(state) || ~isscalar(state) || ...
                    ~isfield(state, "Format") || ...
                    string(state.Format) ~= ProjectionAlignmentCommonAnchor.Format
                error("ProjectionAlignmentCommonAnchor:invalidState", ...
                    "Common-anchor state was not produced by prepare.");
            end
        end
    end
end
