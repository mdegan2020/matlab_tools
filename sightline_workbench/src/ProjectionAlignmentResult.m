classdef ProjectionAlignmentResult
    %ProjectionAlignmentResult Validate reusable alignment result structs.

    properties (Constant)
        Format = "ProjectionAlignmentResult"
        Version = 2
    end

    methods (Static)
        function result = empty(request)
            %empty Return a normalized result with no alignment work recorded.
            if nargin < 1
                request = struct();
            end
            result = struct();
            if ~isempty(request)
                result.RequestSummary = ProjectionAlignmentResult.summarizeRequest(request);
            end
            result = ProjectionAlignmentResult.validate(result);
        end

        function result = validate(result)
            %validate Normalize and validate an alignment result.
            if nargin < 1 || isempty(result)
                result = struct();
            end
            if ProjectionAlignmentResult.isPath(result)
                result = ProjectionAlignmentResult.read(result);
                return
            end
            if ~isstruct(result) || ~isscalar(result)
                error("ProjectionAlignmentResult:invalidResult", ...
                    "Alignment result must be a scalar struct or JSON file path.");
            end

            result.Format = ProjectionAlignmentResult.Format;
            result.Version = ProjectionAlignmentResult.Version;
            result.Status = ProjectionAlignmentResult.validateStatus( ...
                ProjectionAlignmentResult.fieldOrDefault(result, "Status", "notRun"));
            result.RequestSummary = ProjectionAlignmentResult.validateRequestSummary( ...
                ProjectionAlignmentResult.fieldOrDefault(result, ...
                "RequestSummary", struct()));
            result.Matches = ProjectionAlignmentResult.validateMatches( ...
                ProjectionAlignmentResult.fieldOrDefault(result, "Matches", []));
            rawInliers = ProjectionAlignmentResult.fieldOrDefault( ...
                result, "Inliers", []);
            rawSolverObservations = ProjectionAlignmentResult.fieldOrDefault( ...
                result, "SolverObservations", []);
            if isempty(rawSolverObservations)
                rawSolverObservations = rawInliers;
            end
            result.SolverObservations = ProjectionAlignmentResult.validateInliers( ...
                rawSolverObservations);
            result.Inliers = result.SolverObservations;
            result.MatchLedger = ProjectionAlignmentMatchLedger.validate( ...
                ProjectionAlignmentResult.fieldOrDefault(result, ...
                "MatchLedger", ProjectionAlignmentMatchLedger.emptyRecords()));
            result.Residuals = ProjectionAlignmentResult.validateResiduals( ...
                ProjectionAlignmentResult.fieldOrDefault(result, "Residuals", struct()));
            result.SolvedCorrections = ProjectionAlignmentResult.validateCorrections( ...
                ProjectionAlignmentResult.fieldOrDefault(result, ...
                "SolvedCorrections", []));
            result.Convergence = ProjectionAlignmentResult.validateConvergence( ...
                ProjectionAlignmentResult.fieldOrDefault(result, "Convergence", struct()));
            result.Warnings = ProjectionAlignmentResult.validateStringList( ...
                ProjectionAlignmentResult.fieldOrDefault(result, "Warnings", ...
                strings(1, 0)), "Warnings");
            result.Timing = ProjectionAlignmentResult.validateTiming( ...
                ProjectionAlignmentResult.fieldOrDefault(result, "Timing", struct()));
            result.Diagnostics = ProjectionAlignmentResult.validateDiagnostics( ...
                ProjectionAlignmentResult.fieldOrDefault(result, "Diagnostics", struct()));
        end

        function jsonText = encode(result)
            %encode Convert an alignment result to pretty JSON text.
            jsonText = jsonencode(ProjectionAlignmentResult.validate(result), ...
                PrettyPrint=true);
        end

        function result = decode(jsonText)
            %decode Decode alignment result JSON.
            result = ProjectionAlignmentResult.validate(jsondecode(jsonText));
        end

        function write(filePath, result)
            %write Save an alignment result as JSON.
            ProjectionAlignmentResult.writeTextFile(filePath, ...
                ProjectionAlignmentResult.encode(result));
        end

        function result = read(filePath)
            %read Load an alignment result from JSON.
            filePath = ProjectionAlignmentResult.validateFilePath(filePath);
            if ~isfile(filePath)
                error("ProjectionAlignmentResult:fileNotFound", ...
                    "Alignment result file does not exist: %s", filePath);
            end
            result = ProjectionAlignmentResult.decode(fileread(filePath));
        end
    end

    methods (Static, Access = private)
        function summary = summarizeRequest(request)
            request = ProjectionAlignmentRequest.validate(request);
            summary = struct();
            summary.LayerIndices = request.LayerIndices;
            summary.LayerIds = request.LayerIds;
            summary.ReferenceLayerIndex = request.ReferenceLayerIndex;
            summary.ReferenceLayerId = request.ReferenceLayerId;
            summary.AnalysisBands = request.AnalysisBands;
            summary.LossMode = request.Options.LossMode;
            summary.SchedulingStrategy = request.Options.Scheduling.Strategy;
            summary.MovableParameters = request.Options.MovableParameters.Parameters;
        end

        function status = validateStatus(status)
            status = ProjectionAlignmentResult.validateChoice(status, ...
                ["notRun", "matched", "solved", "failed", "cancelled"], "Status");
        end

        function summary = validateRequestSummary(summary)
            if isempty(summary)
                summary = struct();
            end
            if ~isstruct(summary) || ~isscalar(summary)
                error("ProjectionAlignmentResult:invalidRequestSummary", ...
                    "RequestSummary must be a scalar struct.");
            end
        end

        function matches = validateMatches(matches)
            if isempty(matches)
                matches = ProjectionAlignmentResult.emptyMatches();
                return
            end
            if ~isstruct(matches)
                error("ProjectionAlignmentResult:invalidMatches", ...
                    "Matches must be a struct array.");
            end
            validatedMatches = ProjectionAlignmentResult.emptyMatches();
            for k = 1:numel(matches)
                hasPairLayerIds = isfield(matches(k), "PairLayerIds") && ...
                    ~isempty(matches(k).PairLayerIds);
                match = ProjectionAlignmentResult.mergeStruct( ...
                    ProjectionAlignmentResult.defaultMatch(), matches(k), "Matches");
                match.Pair = ProjectionAlignmentResult.validateIntegerVector( ...
                    match.Pair, 2, "Matches.Pair");
                if ~hasPairLayerIds
                    match.PairLayerIds = strings(1, 0);
                end
                match.PairLayerIds = ProjectionAlignmentResult.validatePairLayerIds( ...
                    match.PairLayerIds, match.Pair, "Matches.PairLayerIds");
                match.MovingLayerId = match.PairLayerIds(1);
                match.ReferenceLayerId = match.PairLayerIds(2);
                match.PairDirection = ProjectionAlignmentResult.validateChoice( ...
                    match.PairDirection, "movingToReference", ...
                    "Matches.PairDirection");
                match.MovingPoints = ProjectionAlignmentResult.validatePointMatrix( ...
                    match.MovingPoints, "Matches.MovingPoints");
                match.ReferencePoints = ProjectionAlignmentResult.validatePointMatrix( ...
                    match.ReferencePoints, "Matches.ReferencePoints");
                match.MovingProjectionPoints = ...
                    ProjectionAlignmentResult.validatePointMatrix( ...
                    match.MovingProjectionPoints, ...
                    "Matches.MovingProjectionPoints");
                match.ReferenceProjectionPoints = ...
                    ProjectionAlignmentResult.validatePointMatrix( ...
                    match.ReferenceProjectionPoints, ...
                    "Matches.ReferenceProjectionPoints");
                match.Scores = ProjectionAlignmentResult.validateNumericVector( ...
                    match.Scores, "Matches.Scores");
                match.DescriptorIndices = ...
                    ProjectionAlignmentResult.validateDescriptorIndices( ...
                    match.DescriptorIndices);
                match.Count = ProjectionAlignmentResult.validateNonnegativeInteger( ...
                    match.Count, "Matches.Count");
                if k == 1
                    validatedMatches = match;
                else
                    validatedMatches(k) = match;
                end
            end
            matches = validatedMatches;
        end

        function inliers = validateInliers(inliers)
            if isempty(inliers)
                inliers = ProjectionAlignmentResult.emptyInliers();
                return
            end
            if ~isstruct(inliers)
                error("ProjectionAlignmentResult:invalidInliers", ...
                    "Inliers must be a struct array.");
            end
            validatedInliers = ProjectionAlignmentResult.emptyInliers();
            for k = 1:numel(inliers)
                hasPairLayerIds = isfield(inliers(k), "PairLayerIds") && ...
                    ~isempty(inliers(k).PairLayerIds);
                inlier = ProjectionAlignmentResult.mergeStruct( ...
                    ProjectionAlignmentResult.defaultInlier(), inliers(k), "Inliers");
                inlier.Pair = ProjectionAlignmentResult.validateIntegerVector( ...
                    inlier.Pair, 2, "Inliers.Pair");
                if ~hasPairLayerIds
                    inlier.PairLayerIds = strings(1, 0);
                end
                inlier.PairLayerIds = ...
                    ProjectionAlignmentResult.validatePairLayerIds( ...
                    inlier.PairLayerIds, inlier.Pair, "Inliers.PairLayerIds");
                inlier.Mask = ProjectionAlignmentResult.validateLogicalVector( ...
                    inlier.Mask, "Inliers.Mask");
                inlier.Count = ProjectionAlignmentResult.validateNonnegativeInteger( ...
                    inlier.Count, "Inliers.Count");
                inlier.Method = ProjectionAlignmentResult.validateScalarString( ...
                    inlier.Method, "Inliers.Method");
                inlier.Meaning = ProjectionAlignmentResult.validateChoice( ...
                    inlier.Meaning, "solverObservations", "Inliers.Meaning");
                if k == 1
                    validatedInliers = inlier;
                else
                    validatedInliers(k) = inlier;
                end
            end
            inliers = validatedInliers;
        end

        function residuals = validateResiduals(residuals)
            hasUnit = isstruct(residuals) && isscalar(residuals) && ...
                isfield(residuals, "Unit") && ~isempty(residuals.Unit);
            defaults = struct();
            defaults.LossMode = "projectionPlane2D";
            defaults.Unit = "planeMeters";
            defaults.Before = [];
            defaults.After = [];
            defaults.PerPair = ProjectionAlignmentResult.emptyResidualPairs();
            residuals = ProjectionAlignmentResult.mergeStruct(defaults, residuals, ...
                "Residuals");
            residuals.LossMode = ProjectionAlignmentResult.validateChoice( ...
                residuals.LossMode, ["projectionPlane2D", "rayToRay3D", ...
                "epipolarCoplanarity"], ...
                "Residuals.LossMode");
            if ~hasUnit
                residuals.Unit = ProjectionAlignmentResult.defaultResidualUnit( ...
                    residuals.LossMode);
            end
            residuals.Unit = ProjectionAlignmentResult.validateScalarString( ...
                residuals.Unit, "Residuals.Unit");
            residuals.Unit = ProjectionAlignmentResult.validateResidualUnit( ...
                residuals.LossMode, residuals.Unit);
            residuals.Before = ProjectionAlignmentResult.validateNumericVector( ...
                residuals.Before, "Residuals.Before");
            residuals.After = ProjectionAlignmentResult.validateNumericVector( ...
                residuals.After, "Residuals.After");
            residuals.PerPair = ProjectionAlignmentResult.validateResidualPairs( ...
                residuals.PerPair);
        end

        function pairs = validateResidualPairs(pairs)
            if isempty(pairs)
                pairs = ProjectionAlignmentResult.emptyResidualPairs();
                return
            end
            if ~isstruct(pairs)
                error("ProjectionAlignmentResult:invalidResiduals", ...
                    "Residuals.PerPair must be a struct array.");
            end
            validatedPairs = ProjectionAlignmentResult.emptyResidualPairs();
            for k = 1:numel(pairs)
                pair = ProjectionAlignmentResult.mergeStruct( ...
                    ProjectionAlignmentResult.defaultResidualPair(), pairs(k), ...
                    "Residuals.PerPair");
                pair.Pair = ProjectionAlignmentResult.validateIntegerVector( ...
                    pair.Pair, 2, "Residuals.PerPair.Pair");
                pair.Before = ProjectionAlignmentResult.validateNumericVector( ...
                    pair.Before, "Residuals.PerPair.Before");
                pair.After = ProjectionAlignmentResult.validateNumericVector( ...
                    pair.After, "Residuals.PerPair.After");
                pair.Count = ProjectionAlignmentResult.validateNonnegativeInteger( ...
                    pair.Count, "Residuals.PerPair.Count");
                if k == 1
                    validatedPairs = pair;
                else
                    validatedPairs(k) = pair;
                end
            end
            pairs = validatedPairs;
        end

        function corrections = validateCorrections(corrections)
            if isempty(corrections)
                corrections = ProjectionAlignmentResult.emptyCorrections();
                return
            end
            if ~isstruct(corrections)
                error("ProjectionAlignmentResult:invalidCorrections", ...
                    "SolvedCorrections must be a struct array.");
            end
            validatedCorrections = ProjectionAlignmentResult.emptyCorrections();
            for k = 1:numel(corrections)
                correction = ProjectionAlignmentResult.mergeStruct( ...
                    ProjectionAlignmentResult.defaultCorrection(), corrections(k), ...
                    "SolvedCorrections");
                correction.LayerIndex = ProjectionAlignmentResult.validatePositiveInteger( ...
                    correction.LayerIndex, "SolvedCorrections.LayerIndex");
                correction.LayerId = ProjectionAlignmentResult.validateScalarString( ...
                    correction.LayerId, "SolvedCorrections.LayerId");
                correction.ViewVectorAngularOffsetsDegrees = ...
                    ProjectionAlignmentResult.validateFiniteVector( ...
                    correction.ViewVectorAngularOffsetsDegrees, 3, ...
                    "SolvedCorrections.ViewVectorAngularOffsetsDegrees");
                correction.ProjectionOffsetMeters = ...
                    ProjectionAlignmentResult.validateFiniteVector( ...
                    correction.ProjectionOffsetMeters, 2, ...
                    "SolvedCorrections.ProjectionOffsetMeters");
                correction.SharedScale = ProjectionAlignmentResult.validatePositiveScalar( ...
                    correction.SharedScale, "SolvedCorrections.SharedScale");
                if k == 1
                    validatedCorrections = correction;
                else
                    validatedCorrections(k) = correction;
                end
            end
            corrections = validatedCorrections;
        end

        function convergence = validateConvergence(convergence)
            defaults = struct();
            defaults.Status = "notRun";
            defaults.Success = false;
            defaults.Iterations = 0;
            defaults.FunctionEvaluations = [];
            defaults.ExitFlag = [];
            defaults.Objective = [];
            defaults.FirstOrderOptimality = [];
            defaults.Message = "";
            convergence = ProjectionAlignmentResult.mergeStruct(defaults, convergence, ...
                "Convergence");
            convergence.Status = ProjectionAlignmentResult.validateChoice( ...
                convergence.Status, ["notRun", "converged", "maxIterations", ...
                "failed", "cancelled"], "Convergence.Status");
            convergence.Success = ProjectionAlignmentResult.validateLogicalScalar( ...
                convergence.Success, "Convergence.Success");
            convergence.Iterations = ...
                ProjectionAlignmentResult.validateNonnegativeInteger( ...
                convergence.Iterations, "Convergence.Iterations");
            convergence.FunctionEvaluations = ...
                ProjectionAlignmentResult.validateOptionalNonnegativeInteger( ...
                convergence.FunctionEvaluations, ...
                "Convergence.FunctionEvaluations");
            convergence.ExitFlag = ProjectionAlignmentResult.validateOptionalFiniteScalar( ...
                convergence.ExitFlag, "Convergence.ExitFlag");
            convergence.Objective = ProjectionAlignmentResult.validateOptionalFiniteScalar( ...
                convergence.Objective, "Convergence.Objective");
            convergence.FirstOrderOptimality = ...
                ProjectionAlignmentResult.validateOptionalFiniteScalar( ...
                convergence.FirstOrderOptimality, ...
                "Convergence.FirstOrderOptimality");
            convergence.Message = ProjectionAlignmentResult.validateScalarString( ...
                convergence.Message, "Convergence.Message");
        end

        function timing = validateTiming(timing)
            defaults = struct();
            defaults.StartedAt = "";
            defaults.FinishedAt = "";
            defaults.TotalSeconds = [];
            defaults.StageSeconds = struct();
            timing = ProjectionAlignmentResult.mergeStruct(defaults, timing, "Timing");
            timing.StartedAt = ProjectionAlignmentResult.validateScalarString( ...
                timing.StartedAt, "Timing.StartedAt");
            timing.FinishedAt = ProjectionAlignmentResult.validateScalarString( ...
                timing.FinishedAt, "Timing.FinishedAt");
            timing.TotalSeconds = ProjectionAlignmentResult.validateOptionalFiniteScalar( ...
                timing.TotalSeconds, "Timing.TotalSeconds");
            if ~isstruct(timing.StageSeconds) || ~isscalar(timing.StageSeconds)
                error("ProjectionAlignmentResult:invalidTiming", ...
                    "Timing.StageSeconds must be a scalar struct.");
            end
        end

        function diagnostics = validateDiagnostics(diagnostics)
            if isempty(diagnostics)
                diagnostics = struct();
            end
            if ~isstruct(diagnostics) || ~isscalar(diagnostics)
                error("ProjectionAlignmentResult:invalidDiagnostics", ...
                    "Diagnostics must be a scalar struct.");
            end
        end

        function matches = emptyMatches()
            matches = struct("Pair", {}, "PairLayerIds", {}, ...
                "MovingLayerId", {}, "ReferenceLayerId", {}, ...
                "PairDirection", {}, "MovingPoints", {}, ...
                "ReferencePoints", {}, "MovingProjectionPoints", {}, ...
                "ReferenceProjectionPoints", {}, "Scores", {}, ...
                "DescriptorIndices", {}, "Count", {});
        end

        function match = defaultMatch()
            match = struct();
            match.Pair = [1 2];
            match.PairLayerIds = ["legacy-layer-000001", ...
                "legacy-layer-000002"];
            match.MovingLayerId = match.PairLayerIds(1);
            match.ReferenceLayerId = match.PairLayerIds(2);
            match.PairDirection = "movingToReference";
            match.MovingPoints = zeros(0, 2);
            match.ReferencePoints = zeros(0, 2);
            match.MovingProjectionPoints = zeros(0, 2);
            match.ReferenceProjectionPoints = zeros(0, 2);
            match.Scores = zeros(0, 1);
            match.DescriptorIndices = zeros(0, 2);
            match.Count = 0;
        end

        function inliers = emptyInliers()
            inliers = struct("Pair", {}, "PairLayerIds", {}, "Mask", {}, ...
                "Count", {}, "Method", {}, "Meaning", {});
        end

        function inlier = defaultInlier()
            inlier = struct();
            inlier.Pair = [1 2];
            inlier.PairLayerIds = ["legacy-layer-000001", ...
                "legacy-layer-000002"];
            inlier.Mask = false(1, 0);
            inlier.Count = 0;
            inlier.Method = "none";
            inlier.Meaning = "solverObservations";
        end

        function pairs = emptyResidualPairs()
            pairs = struct("Pair", {}, "Before", {}, "After", {}, "Count", {});
        end

        function pair = defaultResidualPair()
            pair = struct();
            pair.Pair = [1 2];
            pair.Before = [];
            pair.After = [];
            pair.Count = 0;
        end

        function corrections = emptyCorrections()
            corrections = struct("LayerIndex", {}, "LayerId", {}, ...
                "ViewVectorAngularOffsetsDegrees", {}, ...
                "ProjectionOffsetMeters", {}, "SharedScale", {});
        end

        function correction = defaultCorrection()
            correction = struct();
            correction.LayerIndex = 1;
            correction.LayerId = "";
            correction.ViewVectorAngularOffsetsDegrees = [0 0 0];
            correction.ProjectionOffsetMeters = [0 0];
            correction.SharedScale = 1;
        end

        function value = validateChoice(value, allowed, name)
            value = ProjectionAlignmentResult.validateScalarString(value, name);
            matches = lower(value) == lower(allowed);
            if ~any(matches)
                error("ProjectionAlignmentResult:invalidChoice", ...
                    "%s must be one of: %s.", name, strjoin(allowed, ", "));
            end
            value = allowed(find(matches, 1, "first"));
        end

        function unit = validateResidualUnit(lossMode, unit)
            expected = ProjectionAlignmentResult.defaultResidualUnit(lossMode);
            unit = ProjectionAlignmentResult.validateChoice( ...
                unit, expected, "Residuals.Unit");
        end

        function unit = defaultResidualUnit(lossMode)
            if lossMode == "rayToRay3D"
                unit = "rayMeters";
            elseif lossMode == "epipolarCoplanarity"
                unit = "normalizedAngular";
            else
                unit = "planeMeters";
            end
        end

        function layerIds = validatePairLayerIds(layerIds, pair, name)
            if isempty(layerIds)
                layerIds = [ ...
                    string(sprintf("legacy-layer-%06d", pair(1))), ...
                    string(sprintf("legacy-layer-%06d", pair(2)))];
            else
                layerIds = string(layerIds);
            end
            if numel(layerIds) ~= 2 || any(ismissing(layerIds)) || ...
                    any(strlength(strip(layerIds)) == 0) || ...
                    layerIds(1) == layerIds(2)
                error("ProjectionAlignmentResult:invalidLayerIds", ...
                    "%s must contain two distinct nonempty layer IDs.", name);
            end
            layerIds = reshape(strip(layerIds), 1, []);
        end

        function value = validateScalarString(value, name)
            if ~(ischar(value) || isstring(value)) || ~isscalar(string(value))
                error("ProjectionAlignmentResult:invalidString", ...
                    "%s must be a scalar string.", name);
            end
            value = string(value);
        end

        function values = validateStringList(values, name)
            if isempty(values)
                values = strings(1, 0);
                return
            end
            values = string(values);
            if ~isvector(values)
                error("ProjectionAlignmentResult:invalidString", ...
                    "%s must be a string vector.", name);
            end
            values = reshape(values, 1, []);
        end

        function value = validatePointMatrix(value, name)
            if isempty(value)
                value = zeros(0, 2);
                return
            end
            if ~isnumeric(value) || ~ismatrix(value) || size(value, 2) ~= 2 || ...
                    any(~isfinite(value), "all")
                error("ProjectionAlignmentResult:invalidPoints", ...
                    "%s must be a finite numeric Nx2 array.", name);
            end
            value = double(value);
        end

        function value = validateDescriptorIndices(value)
            if isempty(value)
                value = zeros(0, 2);
                return
            end
            if ~isnumeric(value) || ~ismatrix(value) || size(value, 2) ~= 2 || ...
                    any(~isfinite(value), "all") || any(value < 1, "all") || ...
                    any(fix(value) ~= value, "all")
                error("ProjectionAlignmentResult:invalidDescriptorIndices", ...
                    "Matches.DescriptorIndices must be a positive integer Nx2 array.");
            end
            value = double(value);
        end

        function value = validateNumericVector(value, name)
            if isempty(value)
                value = [];
                return
            end
            if ~isnumeric(value) || ~isvector(value) || any(~isfinite(value))
                error("ProjectionAlignmentResult:invalidVector", ...
                    "%s must be a finite numeric vector.", name);
            end
            value = double(reshape(value, 1, []));
        end

        function value = validateLogicalVector(value, name)
            if isempty(value)
                value = false(1, 0);
                return
            end
            if ~(islogical(value) || isnumeric(value)) || ~isvector(value)
                error("ProjectionAlignmentResult:invalidLogical", ...
                    "%s must be a logical vector.", name);
            end
            value = logical(reshape(value, 1, []));
        end

        function value = validateIntegerVector(value, count, name)
            if ~isnumeric(value) || numel(value) ~= count || any(~isfinite(value), "all") || ...
                    any(value < 1, "all") || any(fix(value) ~= value, "all")
                error("ProjectionAlignmentResult:invalidInteger", ...
                    "%s must be a positive integer %d-vector.", name, count);
            end
            value = double(value(:).');
        end

        function value = validateFiniteVector(value, count, name)
            if ~isnumeric(value) || numel(value) ~= count || ...
                    any(~isfinite(value), "all")
                error("ProjectionAlignmentResult:invalidVector", ...
                    "%s must be a finite numeric %d-vector.", name, count);
            end
            value = double(value(:).');
        end

        function value = validatePositiveInteger(value, name)
            if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value) || ...
                    value < 1 || fix(value) ~= value
                error("ProjectionAlignmentResult:invalidInteger", ...
                    "%s must be a positive integer.", name);
            end
            value = double(value);
        end

        function value = validateNonnegativeInteger(value, name)
            if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value) || ...
                    value < 0 || fix(value) ~= value
                error("ProjectionAlignmentResult:invalidInteger", ...
                    "%s must be a nonnegative integer.", name);
            end
            value = double(value);
        end

        function value = validatePositiveScalar(value, name)
            if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value) || value <= 0
                error("ProjectionAlignmentResult:invalidScalar", ...
                    "%s must be a positive finite scalar.", name);
            end
            value = double(value);
        end

        function value = validateOptionalFiniteScalar(value, name)
            if isempty(value)
                value = [];
                return
            end
            if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value)
                error("ProjectionAlignmentResult:invalidScalar", ...
                    "%s must be a finite scalar.", name);
            end
            value = double(value);
        end

        function value = validateOptionalNonnegativeInteger(value, name)
            if isempty(value)
                value = [];
                return
            end
            value = ProjectionAlignmentResult.validateNonnegativeInteger( ...
                value, name);
        end

        function value = validateLogicalScalar(value, name)
            if ~(islogical(value) || isnumeric(value)) || ~isscalar(value)
                error("ProjectionAlignmentResult:invalidLogical", ...
                    "%s must be a scalar logical value.", name);
            end
            value = logical(value);
        end

        function output = mergeStruct(defaults, overrides, name)
            if isempty(overrides)
                output = defaults;
                return
            end
            if ~isstruct(overrides) || ~isscalar(overrides)
                error("ProjectionAlignmentResult:invalidStruct", ...
                    "%s must be a scalar struct.", name);
            end

            output = defaults;
            names = fieldnames(overrides);
            for k = 1:numel(names)
                output.(names{k}) = overrides.(names{k});
            end
        end

        function value = fieldOrDefault(value, fieldName, defaultValue)
            if isfield(value, fieldName)
                value = value.(fieldName);
            else
                value = defaultValue;
            end
        end

        function tf = isPath(value)
            tf = ischar(value) || (isstring(value) && isscalar(value));
        end

        function filePath = validateFilePath(filePath)
            if ~(ischar(filePath) || (isstring(filePath) && isscalar(filePath))) || ...
                    strlength(string(filePath)) == 0
                error("ProjectionAlignmentResult:invalidPath", ...
                    "File path must be a nonempty character vector or scalar string.");
            end
            filePath = char(filePath);
        end

        function writeTextFile(filePath, text)
            filePath = ProjectionAlignmentResult.validateFilePath(filePath);
            fid = fopen(filePath, "w");
            if fid < 0
                error("ProjectionAlignmentResult:fileOpenFailed", ...
                    "Unable to open alignment result file for writing: %s", filePath);
            end
            cleaner = onCleanup(@() fclose(fid));
            fprintf(fid, "%s\n", text);
            clear cleaner
        end
    end
end
