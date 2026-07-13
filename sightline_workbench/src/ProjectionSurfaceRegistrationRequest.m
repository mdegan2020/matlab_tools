classdef ProjectionSurfaceRegistrationRequest
    %ProjectionSurfaceRegistrationRequest Strict graphics-free S7 request.

    properties (Constant)
        Format = "ProjectionSurfaceRegistrationRequest"
        Version = 1
    end

    methods (Static)
        function request = validate(request)
            %validate Normalize one imagery-only surface/DEM request.
            if ~isstruct(request) || ~isscalar(request)
                error("ProjectionSurfaceRegistrationRequest:invalidRequest", ...
                    "Surface-registration request must be a scalar struct.");
            end
            forbidden = ["Truth" "ExpectedTranslation" "ProgressFcn" ...
                "CancellationFcn" "Graphics" "RuntimeCache"];
            if any(isfield(request, forbidden))
                error("ProjectionSurfaceRegistrationRequest:forbiddenData", ...
                    "Truth, callbacks, and runtime state are forbidden in requests.");
            end
            defaults = struct(Format= ...
                ProjectionSurfaceRegistrationRequest.Format, ...
                Version=ProjectionSurfaceRegistrationRequest.Version, ...
                PointSet=struct(), Dem=struct(), RoiWorld=[], ...
                AllowedTransform="globalTranslation", RobustLoss="huber", ...
                MaximumIterations=30, ConvergenceToleranceMeters=1e-6, ...
                HuberScaleMeters=[], MinimumSupport=6, ...
                MaximumConditionNumber=1e12, SlopeWeightScale=1, ...
                EvaluateMaskSensitivity=true, ...
                PointExclusions=ProjectionSurfaceRegistrationRequest. ...
                emptyExclusions(), Seed=0, ...
                PrecisionPolicy=struct(Geometry="double", ...
                Accumulation="double", Final="double"), Context=struct());
            names = string(fieldnames(request));
            unknown = setdiff(names, string(fieldnames(defaults)));
            if ~isempty(unknown)
                error("ProjectionSurfaceRegistrationRequest:invalidRequest", ...
                    "Unexpected registration-request field: %s.", unknown(1));
            end
            for name = names.'
                defaults.(name) = request.(name);
            end
            request = defaults;
            request.Format = string(request.Format);
            if ~isscalar(request.Format) || request.Format ~= ...
                    ProjectionSurfaceRegistrationRequest.Format || ...
                    ~isequal(request.Version, ...
                    ProjectionSurfaceRegistrationRequest.Version)
                error("ProjectionSurfaceRegistrationRequest:unsupportedSchema", ...
                    "Registration request format/version is unsupported.");
            end
            request.PointSet = ProjectionSurfaceRegistrationRequest. ...
                validatePointSet(request.PointSet);
            request.Dem = ProjectionDemGrid.validate(request.Dem);
            if string(request.PointSet.WorldFrame) ~= string(request.Dem.WorldFrame)
                error("ProjectionSurfaceRegistrationRequest:frameMismatch", ...
                    "Imagery points and DEM must use the same project world frame.");
            end
            if ~request.Dem.Accuracy.Available
                error("ProjectionSurfaceRegistrationRequest:missingDemUncertainty", ...
                    "DEM CE90/LE90 uncertainty is required for registration.");
            end
            coordinates = horzcat(request.PointSet.Points( ...
                [request.PointSet.Points.Valid]).PointWorld);
            request.RoiWorld = ProjectionSurfaceRegistrationRequest.roi( ...
                request.RoiWorld, coordinates);
            request.AllowedTransform = ...
                ProjectionSurfaceRegistrationRequest.enumValue( ...
                request.AllowedTransform, "globalTranslation", ...
                "AllowedTransform");
            request.RobustLoss = ProjectionSurfaceRegistrationRequest. ...
                enumValue(request.RobustLoss, "huber", "RobustLoss");
            request.MaximumIterations = ProjectionSurfaceRegistrationRequest. ...
                positiveInteger(request.MaximumIterations, "MaximumIterations");
            request.ConvergenceToleranceMeters = ...
                ProjectionSurfaceRegistrationRequest.positiveScalar( ...
                request.ConvergenceToleranceMeters, ...
                "ConvergenceToleranceMeters");
            if ~isempty(request.HuberScaleMeters)
                request.HuberScaleMeters = ...
                    ProjectionSurfaceRegistrationRequest.positiveScalar( ...
                    request.HuberScaleMeters, "HuberScaleMeters");
            end
            request.MinimumSupport = ProjectionSurfaceRegistrationRequest. ...
                positiveInteger(request.MinimumSupport, "MinimumSupport");
            request.MaximumConditionNumber = ...
                ProjectionSurfaceRegistrationRequest.positiveScalar( ...
                request.MaximumConditionNumber, "MaximumConditionNumber");
            request.SlopeWeightScale = ProjectionSurfaceRegistrationRequest. ...
                positiveScalar(request.SlopeWeightScale, "SlopeWeightScale");
            if ~islogical(request.EvaluateMaskSensitivity) || ...
                    ~isscalar(request.EvaluateMaskSensitivity)
                error("ProjectionSurfaceRegistrationRequest:invalidRequest", ...
                    "EvaluateMaskSensitivity must be a logical scalar.");
            end
            request.PointExclusions = ProjectionSurfaceRegistrationRequest. ...
                exclusions(request.PointExclusions, request.PointSet.Points);
            request.Seed = ProjectionSurfaceRegistrationRequest. ...
                nonnegativeInteger(request.Seed, "Seed");
            request.PrecisionPolicy = ProjectionSurfaceRegistrationRequest. ...
                precision(request.PrecisionPolicy);
            if ~isstruct(request.Context) || ~isscalar(request.Context) || ...
                    ProjectionSurfaceRegistrationRequest.hasRuntimeValue( ...
                    request.Context)
                error("ProjectionSurfaceRegistrationRequest:invalidContext", ...
                    "Context must be a portable scalar value struct.");
            end
            if ProjectionSurfaceRegistrationRequest.hasRuntimeValue(request)
                error("ProjectionSurfaceRegistrationRequest:runtimeState", ...
                    "Registration requests cannot contain runtime values.");
            end
        end

        function exclusions = emptyExclusions()
            %emptyExclusions Return the normalized point-mask schema.
            exclusions = struct("PointId", {}, "Reason", {});
        end
    end

    methods (Static, Access = private)
        function pointSet = validatePointSet(pointSet)
            if ~isstruct(pointSet) || ~isscalar(pointSet) || ...
                    ~isfield(pointSet, "Points") || isempty(pointSet.Points)
                error("ProjectionSurfaceRegistrationRequest:invalidPointSet", ...
                    "A nonempty B5 imagery-only point set is required.");
            end
            valid = [pointSet.Points.Valid];
            coordinates = horzcat(pointSet.Points(valid).PointWorld);
            if isempty(coordinates) || any(~isfinite(coordinates), "all")
                error("ProjectionSurfaceRegistrationRequest:invalidPointSet", ...
                    "At least one finite valid imagery-only point is required.");
            end
            lower = min(coordinates, [], 2);
            upper = max(coordinates, [], 2);
            padding = max(1, 0.01 * max(upper - lower));
            validation = ProjectionSurfaceFusionRequest.validate(struct( ...
                PointSet=pointSet, RoiWorld=[lower - padding upper + padding], ...
                VoxelScalesMeters=padding));
            pointSet = validation.PointSet;
        end

        function value = roi(value, coordinates)
            if isempty(value)
                lower = min(coordinates, [], 2);
                upper = max(coordinates, [], 2);
                padding = max(1, 0.01 * max(upper - lower));
                value = [lower - padding upper + padding];
            end
            if ~isnumeric(value) || ~isequal(size(value), [3 2]) || ...
                    any(~isfinite(value), "all") || any(value(:, 2) <= value(:, 1))
                error("ProjectionSurfaceRegistrationRequest:invalidRoi", ...
                    "RoiWorld must be finite increasing 3x2 world bounds.");
            end
            value = double(value);
        end

        function exclusions = exclusions(exclusions, points)
            if isempty(exclusions)
                exclusions = ProjectionSurfaceRegistrationRequest. ...
                    emptyExclusions();
                return
            end
            if ~isstruct(exclusions)
                error("ProjectionSurfaceRegistrationRequest:invalidExclusions", ...
                    "PointExclusions must be a struct array.");
            end
            pointIds = string({points.PointId});
            normalized = ProjectionSurfaceRegistrationRequest.emptyExclusions();
            for index = 1:numel(exclusions)
                if any(~isfield(exclusions(index), ["PointId" "Reason"]))
                    error("ProjectionSurfaceRegistrationRequest:invalidExclusions", ...
                        "Each point exclusion requires PointId and Reason.");
                end
                pointId = string(exclusions(index).PointId);
                reason = string(exclusions(index).Reason);
                if ~isscalar(pointId) || ~ismember(pointId, pointIds) || ...
                        ~isscalar(reason) || ismissing(reason) || ...
                        strlength(reason) == 0
                    error("ProjectionSurfaceRegistrationRequest:invalidExclusions", ...
                        "Point exclusions require known IDs and explicit reasons.");
                end
                normalized(end + 1) = struct( ...
                    PointId=pointId, Reason=reason); %#ok<AGROW>
            end
            if numel(unique(string({normalized.PointId}))) ~= numel(normalized)
                error("ProjectionSurfaceRegistrationRequest:invalidExclusions", ...
                    "A point may be excluded only once.");
            end
            exclusions = normalized;
        end

        function value = precision(value)
            required = ["Geometry" "Accumulation" "Final"];
            if ~isstruct(value) || ~isscalar(value) || ...
                    any(~isfield(value, required)) || ...
                    any(structfun(@(entry) string(entry) ~= "double", value))
                error("ProjectionSurfaceRegistrationRequest:invalidPrecision", ...
                    "Initial DEM registration requires double precision throughout.");
            end
            value = struct(Geometry="double", Accumulation="double", ...
                Final="double");
        end

        function value = enumValue(value, choices, name)
            value = string(value);
            if ~isscalar(value) || ismissing(value) || ~ismember(value, choices)
                error("ProjectionSurfaceRegistrationRequest:invalidRequest", ...
                    "%s is unsupported.", name);
            end
        end

        function value = positiveInteger(value, name)
            value = ProjectionSurfaceRegistrationRequest. ...
                nonnegativeInteger(value, name);
            if value < 1
                error("ProjectionSurfaceRegistrationRequest:invalidRequest", ...
                    "%s must be positive.", name);
            end
        end

        function value = nonnegativeInteger(value, name)
            if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value) || ...
                    value < 0 || fix(value) ~= value
                error("ProjectionSurfaceRegistrationRequest:invalidRequest", ...
                    "%s must be a nonnegative integer.", name);
            end
            value = double(value);
        end

        function value = positiveScalar(value, name)
            if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value) || ...
                    value <= 0
                error("ProjectionSurfaceRegistrationRequest:invalidRequest", ...
                    "%s must be a positive scalar.", name);
            end
            value = double(value);
        end

        function tf = hasRuntimeValue(value)
            if isa(value, "function_handle") || ...
                    (isobject(value) && isa(value, "handle")) || isjava(value)
                tf = true;
            elseif isstruct(value)
                tf = false;
                names = fieldnames(value);
                for element = 1:numel(value)
                    for index = 1:numel(names)
                        if ProjectionSurfaceRegistrationRequest.hasRuntimeValue( ...
                                value(element).(names{index}))
                            tf = true;
                            return
                        end
                    end
                end
            elseif iscell(value)
                tf = false;
                for index = 1:numel(value)
                    if ProjectionSurfaceRegistrationRequest. ...
                            hasRuntimeValue(value{index})
                        tf = true;
                        return
                    end
                end
            else
                tf = false;
            end
        end
    end
end
