classdef ProjectionDenseMatchResult
    %ProjectionDenseMatchResult Validate normalized full-source matches.

    properties (Constant)
        Format = "ProjectionDenseMatchResult"
        Version = 1
        States = ["valid" "noMatch" "occluded" ...
            "ambiguousRepetitive" "insufficientTexture" ...
            "outsideOverlap" "geometrySearchFailure" "masked" ...
            "algorithmFailure"]
    end

    methods (Static)
        function result = validate(result, request)
            %validate Normalize one matcher result against its request.
            if ~isstruct(result) || ~isscalar(result)
                error("ProjectionDenseMatchResult:invalidResult", ...
                    "Dense matcher result must be a scalar struct.");
            end
            forbidden = ["Surface" "DisplayPyramid" "PreviewCoordinates"];
            if any(isfield(result, forbidden))
                error("ProjectionDenseMatchResult:forbiddenProduct", ...
                    "Matcher results cannot substitute a surface or preview product for observations.");
            end
            request = ProjectionDenseMatchRequest.validate(request);
            required = ["MovingSourceRows" "MovingSourceColumns" ...
                "ReferenceSourceRows" "ReferenceSourceColumns" "States"];
            if any(~isfield(result, required))
                error("ProjectionDenseMatchResult:invalidResult", ...
                    "Result must contain both full-source observations and states.");
            end
            defaults = struct(Format=ProjectionDenseMatchResult.Format, ...
                Version=ProjectionDenseMatchResult.Version, Status="succeeded", ...
                PairId=request.PairId, ViewIds=request.ViewIds, ...
                MovingSourceRows=[], MovingSourceColumns=[], ...
                ReferenceSourceRows=[], ReferenceSourceColumns=[], ...
                States=strings(0, 1), Score=[], Confidence=[], ...
                CovariancePixelsSquared=[], Diagnostics=struct(), ...
                Timing=struct(TotalSeconds=NaN), Memory=struct(Bytes=NaN), ...
                Execution=struct(), Provenance=struct());
            names = fieldnames(result);
            unknown = setdiff(string(names), string(fieldnames(defaults)));
            if ~isempty(unknown)
                error("ProjectionDenseMatchResult:invalidResult", ...
                    "Unexpected result field: %s.", unknown(1));
            end
            for index = 1:numel(names)
                defaults.(names{index}) = result.(names{index});
            end
            defaults.PairId = string(defaults.PairId);
            defaults.ViewIds = reshape(string(defaults.ViewIds), 1, []);
            if defaults.PairId ~= request.PairId || ...
                    ~isequal(defaults.ViewIds, request.ViewIds)
                error("ProjectionDenseMatchResult:identityMismatch", ...
                    "Result pair and view identities must match the request.");
            end
            observationFields = ["MovingSourceRows" "MovingSourceColumns" ...
                "ReferenceSourceRows" "ReferenceSourceColumns"];
            count = numel(defaults.MovingSourceRows);
            for field = observationFields
                value = defaults.(field);
                if ~isnumeric(value) || numel(value) ~= count
                    error("ProjectionDenseMatchResult:invalidObservations", ...
                        "All source-observation arrays must have the same numeric length.");
                end
                defaults.(field) = double(value(:));
            end
            defaults.States = string(defaults.States(:));
            if numel(defaults.States) ~= count || ...
                    any(~ismember(defaults.States, ...
                    ProjectionDenseMatchResult.States))
                error("ProjectionDenseMatchResult:invalidStates", ...
                    "Every observation must have one supported primary state.");
            end
            valid = defaults.States == "valid";
            for field = observationFields
                if any(~isfinite(defaults.(field)(valid)))
                    error("ProjectionDenseMatchResult:invalidObservations", ...
                        "Valid observations require finite full-source coordinates.");
                end
            end
            defaults.Score = ProjectionDenseMatchResult.metricVector( ...
                defaults.Score, count, "Score", NaN);
            defaults.Confidence = ProjectionDenseMatchResult.metricVector( ...
                defaults.Confidence, count, "Confidence", NaN);
            finiteConfidence = isfinite(defaults.Confidence);
            if any(defaults.Confidence(finiteConfidence) < 0 | ...
                    defaults.Confidence(finiteConfidence) > 1)
                error("ProjectionDenseMatchResult:invalidConfidence", ...
                    "Finite confidence scores must lie in [0,1].");
            end
            covariance = defaults.CovariancePixelsSquared;
            if ~isempty(covariance) && ...
                    (~isnumeric(covariance) || ...
                    size(covariance, 1) ~= 2 || size(covariance, 2) ~= 2 || ...
                    size(covariance, 3) ~= count || ndims(covariance) > 3 || ...
                    any(~isfinite(covariance), "all"))
                error("ProjectionDenseMatchResult:invalidCovariance", ...
                    "Covariance must be empty or finite 2x2xN pixels-squared values.");
            end
            structFields = ["Diagnostics" "Timing" "Memory" ...
                "Execution" "Provenance"];
            for field = structFields
                if ~isstruct(defaults.(field)) || ~isscalar(defaults.(field))
                    error("ProjectionDenseMatchResult:invalidResult", ...
                        "%s must be a scalar struct.", field);
                end
            end
            defaults.Status = string(defaults.Status);
            if ~isscalar(defaults.Status) || ...
                    ~ismember(defaults.Status, ["succeeded" "failed" "cancelled"])
                error("ProjectionDenseMatchResult:invalidStatus", ...
                    "Status must be succeeded, failed, or cancelled.");
            end
            result = defaults;
        end
    end

    methods (Static, Access = private)
        function values = metricVector(values, count, name, fill)
            if isempty(values)
                values = repmat(fill, count, 1);
            elseif ~isnumeric(values) || numel(values) ~= count
                error("ProjectionDenseMatchResult:invalidMetrics", ...
                    "%s must be empty or numeric with one value per observation.", ...
                    name);
            else
                values = double(values(:));
            end
        end
    end
end
