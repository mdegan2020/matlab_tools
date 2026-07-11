classdef ProjectionStereoEyeController < handle
    %ProjectionStereoEyeController Own runtime stereo-eye assignment state.

    properties (Constant)
        HysteresisRatio = 0.02
    end

    properties (SetAccess = private)
        Records struct = struct( ...
            PairId={}, AutoLeftViewId={}, AutoRightViewId={}, ...
            ManualLeftViewId={}, ManualRightViewId={}, ...
            LastStatus={}, LastProjectionRatio={})
    end

    methods
        function assignment = resolve(controller, pairId, viewIds, ...
                origins, cameraRightVector)
            [pairId, viewIds, origins, cameraRightVector] = ...
                controller.validateInputs( ...
                pairId, viewIds, origins, cameraRightVector);
            recordIndex = controller.ensureRecord(pairId);
            record = controller.Records(recordIndex);

            projectedPositions = cameraRightVector.' * origins;
            baselineNorm = norm(origins(:, 2) - origins(:, 1));
            if baselineNorm <= eps
                projectionRatio = 0;
            else
                projectionRatio = ...
                    (projectedPositions(2) - projectedPositions(1)) / ...
                    baselineNorm;
            end
            isDegenerate = abs(projectionRatio) <= ...
                controller.HysteresisRatio;

            [automaticLeft, automaticRight, status] = ...
                controller.automaticAssignment( ...
                record, viewIds, projectedPositions, baselineNorm, ...
                isDegenerate);
            record.AutoLeftViewId = automaticLeft;
            record.AutoRightViewId = automaticRight;
            if strlength(record.ManualLeftViewId) > 0
                leftViewId = record.ManualLeftViewId;
                rightViewId = record.ManualRightViewId;
                mode = "manual";
                status = "manualOverride";
            else
                leftViewId = automaticLeft;
                rightViewId = automaticRight;
                mode = "automatic";
            end
            record.LastStatus = status;
            record.LastProjectionRatio = projectionRatio;
            controller.Records(recordIndex) = record;

            assignment = struct( ...
                PairId=pairId, LeftViewId=leftViewId, ...
                RightViewId=rightViewId, RedViewId=leftViewId, ...
                CyanViewId=rightViewId, Mode=mode, Status=status, ...
                IsDegenerate=isDegenerate, ...
                ProjectionRatio=projectionRatio, ...
                HysteresisRatio=controller.HysteresisRatio, ...
                ManualOverride=(mode == "manual"));
        end

        function assignment = swapManual(controller, pairId, viewIds, ...
                origins, cameraRightVector)
            assignment = controller.resolve( ...
                pairId, viewIds, origins, cameraRightVector);
            recordIndex = controller.recordIndex(assignment.PairId);
            record = controller.Records(recordIndex);
            record.ManualLeftViewId = assignment.RightViewId;
            record.ManualRightViewId = assignment.LeftViewId;
            controller.Records(recordIndex) = record;
            assignment = controller.resolve( ...
                pairId, viewIds, origins, cameraRightVector);
        end

        function assignment = resetManual(controller, pairId, viewIds, ...
                origins, cameraRightVector)
            pairId = string(pairId);
            recordIndex = controller.recordIndex(pairId);
            record = controller.Records(recordIndex);
            record.ManualLeftViewId = "";
            record.ManualRightViewId = "";
            controller.Records(recordIndex) = record;
            assignment = controller.resolve( ...
                pairId, viewIds, origins, cameraRightVector);
        end

        function diagnostics = diagnostics(controller, pairId)
            pairId = string(pairId);
            recordIndex = controller.recordIndex(pairId);
            diagnostics = controller.Records(recordIndex);
            diagnostics.HysteresisRatio = controller.HysteresisRatio;
        end
    end

    methods (Access = private)
        function [leftViewId, rightViewId, status] = automaticAssignment( ...
                controller, record, viewIds, projectedPositions, ...
                baselineNorm, isDegenerate)
            if strlength(record.AutoLeftViewId) == 0
                if isDegenerate
                    orderedViewIds = sort(viewIds);
                    leftViewId = orderedViewIds(1);
                    rightViewId = orderedViewIds(2);
                    status = "degenerateNoHistory";
                else
                    [leftViewId, rightViewId] = ...
                        controller.physicalAssignment( ...
                        viewIds, projectedPositions);
                    status = "automatic";
                end
                return
            end

            previousLeftIndex = find( ...
                viewIds == record.AutoLeftViewId, 1, "first");
            previousRightIndex = find( ...
                viewIds == record.AutoRightViewId, 1, "first");
            signedSeparation = projectedPositions(previousRightIndex) - ...
                projectedPositions(previousLeftIndex);
            normalizedSeparation = signedSeparation / max(baselineNorm, eps);
            if normalizedSeparation < -controller.HysteresisRatio
                leftViewId = record.AutoRightViewId;
                rightViewId = record.AutoLeftViewId;
                status = "automaticSwitched";
            else
                leftViewId = record.AutoLeftViewId;
                rightViewId = record.AutoRightViewId;
                if isDegenerate || normalizedSeparation < 0
                    status = "retainedHysteresis";
                else
                    status = "automatic";
                end
            end
        end

        function [leftViewId, rightViewId] = physicalAssignment( ...
                ~, viewIds, projectedPositions)
            [~, order] = sort(projectedPositions, "ascend");
            leftViewId = viewIds(order(1));
            rightViewId = viewIds(order(2));
        end

        function recordIndex = ensureRecord(controller, pairId)
            pairIds = string({controller.Records.PairId});
            recordIndex = find(pairIds == pairId, 1, "first");
            if ~isempty(recordIndex)
                return
            end
            record = struct( ...
                PairId=pairId, AutoLeftViewId="", AutoRightViewId="", ...
                ManualLeftViewId="", ManualRightViewId="", ...
                LastStatus="unresolved", LastProjectionRatio=NaN);
            controller.Records(end + 1) = record;
            recordIndex = numel(controller.Records);
        end

        function recordIndex = recordIndex(controller, pairId)
            pairIds = string({controller.Records.PairId});
            recordIndex = find(pairIds == pairId, 1, "first");
            if isempty(recordIndex)
                error("ProjectionStereoEyeController:unknownPair", ...
                    "Resolve the pair before changing its manual eye state.");
            end
        end

        function [pairId, viewIds, origins, cameraRightVector] = ...
                validateInputs(~, pairId, viewIds, origins, cameraRightVector)
            pairId = string(pairId);
            viewIds = reshape(string(viewIds), 1, []);
            if ~isscalar(pairId) || ismissing(pairId) || ...
                    strlength(pairId) == 0 || numel(viewIds) ~= 2 || ...
                    any(ismissing(viewIds)) || any(strlength(viewIds) == 0)
                error("ProjectionStereoEyeController:invalidPair", ...
                    "Pair identity and exactly two view IDs are required.");
            end
            identity = ProjectionViewMetadata.pairIdentity( ...
                viewIds(1), viewIds(2));
            if identity.PairId ~= pairId
                error("ProjectionStereoEyeController:pairIdentityMismatch", ...
                    "PairId must match the unordered view identities.");
            end
            if ~isnumeric(origins) || ~isequal(size(origins), [3 2]) || ...
                    any(~isfinite(origins), "all")
                error("ProjectionStereoEyeController:invalidOrigins", ...
                    "Origins must be a finite 3-by-2 numeric matrix.");
            end
            cameraRightVector = double(cameraRightVector(:));
            if numel(cameraRightVector) ~= 3 || ...
                    any(~isfinite(cameraRightVector)) || ...
                    norm(cameraRightVector) <= eps
                error("ProjectionStereoEyeController:invalidCameraRight", ...
                    "Camera right must be a finite nonzero three-vector.");
            end
            origins = double(origins);
            cameraRightVector = cameraRightVector / norm(cameraRightVector);
        end
    end
end
