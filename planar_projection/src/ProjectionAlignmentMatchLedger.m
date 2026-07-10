classdef ProjectionAlignmentMatchLedger
    %ProjectionAlignmentMatchLedger Preserve raw match identity and stage state.

    properties (Constant)
        Format = "ProjectionAlignmentMatchLedgerRecord"
        Version = 2
    end

    methods (Static)
        function pairMatch = ensurePair(pairMatch)
            %ensurePair Add stable pair identity and a complete raw-match ledger.
            ProjectionAlignmentMatchLedger.validatePairShape(pairMatch);
            layerIds = ProjectionAlignmentMatchLedger.pairLayerIds(pairMatch);
            pairMatch.PairLayerIds = layerIds;
            pairMatch.MovingLayerId = layerIds(1);
            pairMatch.ReferenceLayerId = layerIds(2);
            pairMatch.PairDirection = "movingToReference";

            if ~ProjectionAlignmentMatchLedger.hasCompatibleLedger(pairMatch)
                pairMatch.MatchLedger = ...
                    ProjectionAlignmentMatchLedger.create(pairMatch);
            else
                pairMatch.MatchLedger = ...
                    ProjectionAlignmentMatchLedger.validate(pairMatch.MatchLedger);
            end
        end

        function records = create(pairMatch)
            %create Build one ledger record for every raw descriptor match.
            ProjectionAlignmentMatchLedger.validatePairShape(pairMatch);
            layerIds = ProjectionAlignmentMatchLedger.pairLayerIds(pairMatch);
            count = double(pairMatch.Count);
            if count == 0
                records = ProjectionAlignmentMatchLedger.emptyRecords();
                return
            end

            records = repmat(ProjectionAlignmentMatchLedger.defaultRecord(), ...
                1, count);
            for matchIndex = 1:count
                record = ProjectionAlignmentMatchLedger.defaultRecord();
                record.RecordId = sprintf("%s->%s:%06d", ...
                    layerIds(1), layerIds(2), matchIndex);
                record.Pair = double(pairMatch.Pair(:).');
                record.PairLayerIds = layerIds;
                record.RawMatchIndex = matchIndex;
                record.MovingFeatureIndex = ...
                    ProjectionAlignmentMatchLedger.matrixValue( ...
                    pairMatch, "IndexPairs", matchIndex, 1, matchIndex);
                record.ReferenceFeatureIndex = ...
                    ProjectionAlignmentMatchLedger.matrixValue( ...
                    pairMatch, "IndexPairs", matchIndex, 2, matchIndex);
                record.DescriptorMetric = ...
                    ProjectionAlignmentMatchLedger.vectorValue( ...
                    pairMatch, "MatchMetric", matchIndex, NaN);
                record.MatchScore = ProjectionAlignmentMatchLedger.vectorValue( ...
                    pairMatch, "Scores", matchIndex, NaN);
                record.MovingWorkingPixel = ...
                    ProjectionAlignmentMatchLedger.rowValue( ...
                    pairMatch, "MovingFeatureLocations", matchIndex);
                record.ReferenceWorkingPixel = ...
                    ProjectionAlignmentMatchLedger.rowValue( ...
                    pairMatch, "ReferenceFeatureLocations", matchIndex);
                record.MovingPlaneMeters = ...
                    ProjectionAlignmentMatchLedger.rowValue( ...
                    pairMatch, "MovingPlaneCoordinates", matchIndex);
                record.ReferencePlaneMeters = ...
                    ProjectionAlignmentMatchLedger.rowValue( ...
                    pairMatch, "ReferencePlaneCoordinates", matchIndex);
                record.MovingSourceRowPixels = ...
                    ProjectionAlignmentMatchLedger.vectorValue( ...
                    pairMatch, "MovingSourceRows", matchIndex, NaN);
                record.MovingSourceColumnPixels = ...
                    ProjectionAlignmentMatchLedger.vectorValue( ...
                    pairMatch, "MovingSourceColumns", matchIndex, NaN);
                record.ReferenceSourceRowPixels = ...
                    ProjectionAlignmentMatchLedger.vectorValue( ...
                    pairMatch, "ReferenceSourceRows", matchIndex, NaN);
                record.ReferenceSourceColumnPixels = ...
                    ProjectionAlignmentMatchLedger.vectorValue( ...
                    pairMatch, "ReferenceSourceColumns", matchIndex, NaN);
                record.Residuals.NativeDisplacementPixels = ...
                    ProjectionAlignmentMatchLedger.nativeDisplacement(record);
                records(matchIndex) = record;
            end
        end

        function records = applyStage(records, stageName, acceptedMask)
            %applyStage Record one cumulative filter-stage acceptance mask.
            records = ProjectionAlignmentMatchLedger.validate(records);
            [fieldName, reasonName] = ...
                ProjectionAlignmentMatchLedger.stageField(stageName);
            acceptedMask = ProjectionAlignmentMatchLedger.validateMask( ...
                acceptedMask, numel(records));

            for matchIndex = 1:numel(records)
                wasAccepted = records(matchIndex).Accepted;
                isAccepted = acceptedMask(matchIndex);
                records(matchIndex).StageMasks.(fieldName) = isAccepted;
                if wasAccepted && ~isAccepted
                    if strlength(records(matchIndex).FirstRejectedStage) == 0
                        records(matchIndex).FirstRejectedStage = reasonName;
                    end
                    records(matchIndex).RejectionReasons = unique([ ...
                        records(matchIndex).RejectionReasons, reasonName], ...
                        "stable");
                end
                if fieldName ~= "SolverObservation" && ...
                        fieldName ~= "ResidualAccepted"
                    records(matchIndex).Accepted = isAccepted;
                    if isAccepted
                        records(matchIndex).State = "accepted";
                    else
                        records(matchIndex).State = "rejected";
                    end
                end
            end
        end

        function records = markSolverResiduals(records, rawMatchIndices, ...
                beforeResiduals, afterResiduals, lossMode, residualUnit)
            %markSolverResiduals Attach explicit-unit residuals to solver records.
            records = ProjectionAlignmentMatchLedger.validate(records);
            rawMatchIndices = ProjectionAlignmentMatchLedger.validateRecordIndices( ...
                rawMatchIndices, numel(records));
            beforeResiduals = ProjectionAlignmentMatchLedger.validateResidualVector( ...
                beforeResiduals, numel(rawMatchIndices), "beforeResiduals");
            afterResiduals = ProjectionAlignmentMatchLedger.validateResidualVector( ...
                afterResiduals, numel(rawMatchIndices), "afterResiduals");
            lossMode = ProjectionAlignmentMatchLedger.validateLossMode(lossMode);
            residualUnit = ProjectionAlignmentMatchLedger.validateResidualUnit( ...
                lossMode, residualUnit);

            solverMask = false(numel(records), 1);
            solverMask(rawMatchIndices) = true;
            records = ProjectionAlignmentMatchLedger.applyStage( ...
                records, "solverObservation", solverMask);
            for solverIndex = 1:numel(rawMatchIndices)
                recordIndex = rawMatchIndices(solverIndex);
                records(recordIndex).StageMasks.SolverObservation = true;
                records(recordIndex).State = "solverObservation";
                residuals = records(recordIndex).Residuals;
                residuals.ActiveLossMode = lossMode;
                residuals.ActiveResidualUnit = residualUnit;
                residuals.ActiveResidualBefore = beforeResiduals(solverIndex);
                residuals.ActiveResidualAfter = afterResiduals(solverIndex);
                residuals = ProjectionAlignmentMatchLedger.setNamedResiduals( ...
                    residuals, lossMode, beforeResiduals(solverIndex), ...
                    afterResiduals(solverIndex));
                records(recordIndex).Residuals = residuals;
            end
        end

        function records = combine(matchResult)
            %combine Return all pair ledgers as one record array.
            if ~isstruct(matchResult) || ~isscalar(matchResult) || ...
                    ~isfield(matchResult, "Matches")
                error("ProjectionAlignmentMatchLedger:invalidMatchResult", ...
                    "Match result must contain a Matches struct array.");
            end
            records = ProjectionAlignmentMatchLedger.emptyRecords();
            for pairIndex = 1:numel(matchResult.Matches)
                pairMatch = ProjectionAlignmentMatchLedger.ensurePair( ...
                    matchResult.Matches(pairIndex));
                records = [records, pairMatch.MatchLedger]; %#ok<AGROW>
            end
        end

        function records = validate(records)
            %validate Normalize and validate a match-ledger struct array.
            if isempty(records)
                records = ProjectionAlignmentMatchLedger.emptyRecords();
                return
            end
            if ~isstruct(records)
                error("ProjectionAlignmentMatchLedger:invalidRecords", ...
                    "Match ledger must be a struct array.");
            end

            validated = repmat(ProjectionAlignmentMatchLedger.defaultRecord(), ...
                1, numel(records));
            for recordIndex = 1:numel(records)
                record = ProjectionAlignmentMatchLedger.mergeRecord( ...
                    records(recordIndex));
                record.Format = ProjectionAlignmentMatchLedger.Format;
                record.Version = ProjectionAlignmentMatchLedger.Version;
                record.RecordId = ProjectionAlignmentMatchLedger.validateString( ...
                    record.RecordId, "RecordId", false);
                record.Pair = ProjectionAlignmentMatchLedger.validatePair(record.Pair);
                record.PairLayerIds = ...
                    ProjectionAlignmentMatchLedger.validateLayerIds( ...
                    record.PairLayerIds);
                record.PairDirection = ...
                    ProjectionAlignmentMatchLedger.validateDirection( ...
                    record.PairDirection);
                record.RawMatchIndex = ...
                    ProjectionAlignmentMatchLedger.validatePositiveInteger( ...
                    record.RawMatchIndex, "RawMatchIndex");
                record.MovingFeatureIndex = ...
                    ProjectionAlignmentMatchLedger.validatePositiveInteger( ...
                    record.MovingFeatureIndex, "MovingFeatureIndex");
                record.ReferenceFeatureIndex = ...
                    ProjectionAlignmentMatchLedger.validatePositiveInteger( ...
                    record.ReferenceFeatureIndex, "ReferenceFeatureIndex");
                record.DescriptorMetric = ...
                    ProjectionAlignmentMatchLedger.validateNumericScalar( ...
                    record.DescriptorMetric, "DescriptorMetric");
                record.MatchScore = ...
                    ProjectionAlignmentMatchLedger.validateNumericScalar( ...
                    record.MatchScore, "MatchScore");
                record.MovingWorkingPixel = ...
                    ProjectionAlignmentMatchLedger.validatePoint( ...
                    record.MovingWorkingPixel, "MovingWorkingPixel");
                record.ReferenceWorkingPixel = ...
                    ProjectionAlignmentMatchLedger.validatePoint( ...
                    record.ReferenceWorkingPixel, "ReferenceWorkingPixel");
                record.MovingPlaneMeters = ...
                    ProjectionAlignmentMatchLedger.validatePoint( ...
                    record.MovingPlaneMeters, "MovingPlaneMeters");
                record.ReferencePlaneMeters = ...
                    ProjectionAlignmentMatchLedger.validatePoint( ...
                    record.ReferencePlaneMeters, "ReferencePlaneMeters");
                record.MovingSourceRowPixels = ...
                    ProjectionAlignmentMatchLedger.validateNumericScalar( ...
                    record.MovingSourceRowPixels, "MovingSourceRowPixels");
                record.MovingSourceColumnPixels = ...
                    ProjectionAlignmentMatchLedger.validateNumericScalar( ...
                    record.MovingSourceColumnPixels, "MovingSourceColumnPixels");
                record.ReferenceSourceRowPixels = ...
                    ProjectionAlignmentMatchLedger.validateNumericScalar( ...
                    record.ReferenceSourceRowPixels, "ReferenceSourceRowPixels");
                record.ReferenceSourceColumnPixels = ...
                    ProjectionAlignmentMatchLedger.validateNumericScalar( ...
                    record.ReferenceSourceColumnPixels, ...
                    "ReferenceSourceColumnPixels");
                record.StageMasks = ProjectionAlignmentMatchLedger.validateStageMasks( ...
                    record.StageMasks);
                record.FirstRejectedStage = ...
                    ProjectionAlignmentMatchLedger.validateString( ...
                    record.FirstRejectedStage, "FirstRejectedStage", true);
                record.RejectionReasons = reshape(string(record.RejectionReasons), ...
                    1, []);
                record.ManualState = ProjectionAlignmentMatchLedger.validateChoice( ...
                    record.ManualState, ["enabled", "disabled", "deleted"], ...
                    "ManualState");
                record.State = ProjectionAlignmentMatchLedger.validateChoice( ...
                    record.State, ["raw", "accepted", "rejected", ...
                    "solverObservation", "residualRejected"], "State");
                record.Accepted = ProjectionAlignmentMatchLedger.validateLogical( ...
                    record.Accepted, "Accepted");
                record.Disabled = ProjectionAlignmentMatchLedger.validateLogical( ...
                    record.Disabled, "Disabled");
                record.Residuals = ProjectionAlignmentMatchLedger.validateResiduals( ...
                    record.Residuals);
                validated(recordIndex) = record;
            end
            records = validated;
        end

        function records = emptyRecords()
            %emptyRecords Return an empty ledger with the canonical schema.
            records = repmat(ProjectionAlignmentMatchLedger.defaultRecord(), 1, 0);
        end
    end

    methods (Static, Access = private)
        function record = defaultRecord()
            record = struct( ...
                Format=ProjectionAlignmentMatchLedger.Format, ...
                Version=ProjectionAlignmentMatchLedger.Version, ...
                RecordId="", ...
                Pair=[1 2], ...
                PairLayerIds=["legacy-layer-000001", "legacy-layer-000002"], ...
                PairDirection="movingToReference", ...
                RawMatchIndex=1, ...
                MovingFeatureIndex=1, ...
                ReferenceFeatureIndex=1, ...
                DescriptorMetric=NaN, ...
                MatchScore=NaN, ...
                MovingWorkingPixel=[NaN NaN], ...
                ReferenceWorkingPixel=[NaN NaN], ...
                MovingPlaneMeters=[NaN NaN], ...
                ReferencePlaneMeters=[NaN NaN], ...
                MovingSourceRowPixels=NaN, ...
                MovingSourceColumnPixels=NaN, ...
                ReferenceSourceRowPixels=NaN, ...
                ReferenceSourceColumnPixels=NaN, ...
                StageMasks=ProjectionAlignmentMatchLedger.defaultStageMasks(), ...
                FirstRejectedStage="", ...
                RejectionReasons=strings(1, 0), ...
                ManualState="enabled", ...
                State="raw", ...
                Accepted=true, ...
                Disabled=false, ...
                Residuals=ProjectionAlignmentMatchLedger.defaultResiduals());
        end

        function masks = defaultStageMasks()
            masks = struct( ...
                Raw=true, ...
                OverlapMask=true, ...
                DescriptorScore=true, ...
                RatioUniqueness=true, ...
                GeometricOutlier=true, ...
                EpipolarCoplanarity=true, ...
                NativeDisplacement=true, ...
                Radial=true, ...
                Roi=true, ...
                Manual=true, ...
                SolverObservation=false, ...
                ResidualAccepted=true);
        end

        function residuals = defaultResiduals()
            residuals = struct( ...
                ProjectionPlaneBeforeMeters=NaN, ...
                ProjectionPlaneAfterMeters=NaN, ...
                NativeDisplacementPixels=NaN, ...
                RayClosestApproachBeforeMeters=NaN, ...
                RayClosestApproachAfterMeters=NaN, ...
                EpipolarCoplanarityBeforeRadians=NaN, ...
                EpipolarCoplanarityAfterRadians=NaN, ...
                ActiveLossMode="", ...
                ActiveResidualUnit="", ...
                ActiveResidualBefore=NaN, ...
                ActiveResidualAfter=NaN);
        end

        function record = mergeRecord(record)
            defaults = ProjectionAlignmentMatchLedger.defaultRecord();
            names = fieldnames(record);
            for nameIndex = 1:numel(names)
                defaults.(names{nameIndex}) = record.(names{nameIndex});
            end
            record = defaults;
        end

        function validatePairShape(pairMatch)
            required = ["Pair", "Count"];
            if ~isstruct(pairMatch) || ~isscalar(pairMatch) || ...
                    any(~isfield(pairMatch, required))
                error("ProjectionAlignmentMatchLedger:invalidPair", ...
                    "Pair match must contain Pair and Count fields.");
            end
            ProjectionAlignmentMatchLedger.validatePair(pairMatch.Pair);
            count = pairMatch.Count;
            if ~isnumeric(count) || ~isscalar(count) || ~isfinite(count) || ...
                    count < 0 || fix(count) ~= count
                error("ProjectionAlignmentMatchLedger:invalidPair", ...
                    "Pair match Count must be a nonnegative integer.");
            end
        end

        function tf = hasCompatibleLedger(pairMatch)
            tf = isfield(pairMatch, "MatchLedger") && ...
                isstruct(pairMatch.MatchLedger);
            if ~tf
                return
            end
            ledgerCount = numel(pairMatch.MatchLedger);
            if ledgerCount == pairMatch.Count
                return
            end
            tf = isfield(pairMatch, "MatchRecordIndices") && ...
                numel(pairMatch.MatchRecordIndices) == pairMatch.Count;
            if ~tf
                return
            end
            indices = pairMatch.MatchRecordIndices(:);
            tf = isempty(indices) || (all(isfinite(indices)) && ...
                all(indices >= 1) && all(indices <= ledgerCount) && ...
                all(fix(indices) == indices));
        end

        function layerIds = pairLayerIds(pairMatch)
            if isfield(pairMatch, "PairLayerIds") && ...
                    numel(pairMatch.PairLayerIds) == 2
                layerIds = pairMatch.PairLayerIds;
            elseif isfield(pairMatch, "MovingLayerId") && ...
                    isfield(pairMatch, "ReferenceLayerId")
                layerIds = [string(pairMatch.MovingLayerId), ...
                    string(pairMatch.ReferenceLayerId)];
            else
                pair = ProjectionAlignmentMatchLedger.validatePair(pairMatch.Pair);
                layerIds = [ ...
                    string(sprintf("legacy-layer-%06d", pair(1))), ...
                    string(sprintf("legacy-layer-%06d", pair(2)))];
            end
            layerIds = ProjectionAlignmentMatchLedger.validateLayerIds(layerIds);
        end

        function value = matrixValue(source, fieldName, rowIndex, ...
                columnIndex, defaultValue)
            value = defaultValue;
            if isfield(source, fieldName) && ...
                    size(source.(fieldName), 1) >= rowIndex && ...
                    size(source.(fieldName), 2) >= columnIndex
                value = double(source.(fieldName)(rowIndex, columnIndex));
            end
        end

        function value = vectorValue(source, fieldName, index, defaultValue)
            value = defaultValue;
            if isfield(source, fieldName) && numel(source.(fieldName)) >= index
                value = double(source.(fieldName)(index));
            end
        end

        function value = rowValue(source, fieldName, rowIndex)
            value = [NaN NaN];
            if isfield(source, fieldName) && ...
                    size(source.(fieldName), 1) >= rowIndex && ...
                    size(source.(fieldName), 2) == 2
                value = double(source.(fieldName)(rowIndex, :));
            end
        end

        function value = nativeDisplacement(record)
            values = [record.MovingSourceColumnPixels, ...
                record.MovingSourceRowPixels, ...
                record.ReferenceSourceColumnPixels, ...
                record.ReferenceSourceRowPixels];
            if any(~isfinite(values))
                value = NaN;
                return
            end
            value = hypot( ...
                record.ReferenceSourceColumnPixels - ...
                record.MovingSourceColumnPixels, ...
                record.ReferenceSourceRowPixels - record.MovingSourceRowPixels);
        end

        function [fieldName, reasonName] = stageField(stageName)
            stageName = lower(ProjectionAlignmentMatchLedger.validateString( ...
                stageName, "stageName", false));
            switch stageName
                case "overlapmask"
                    fieldName = "OverlapMask";
                    reasonName = "overlapMask";
                case "descriptorscore"
                    fieldName = "DescriptorScore";
                    reasonName = "descriptorScore";
                case {"ratio", "ratiouniqueness"}
                    fieldName = "RatioUniqueness";
                    reasonName = "ratioUniqueness";
                case "geometricoutlier"
                    fieldName = "GeometricOutlier";
                    reasonName = "geometricOutlier";
                case "epipolarcoplanarity"
                    fieldName = "EpipolarCoplanarity";
                    reasonName = "epipolarCoplanarity";
                case "nativedisplacement"
                    fieldName = "NativeDisplacement";
                    reasonName = "nativeDisplacement";
                case "radial"
                    fieldName = "Radial";
                    reasonName = "radial";
                case "roi"
                    fieldName = "Roi";
                    reasonName = "roi";
                case "manual"
                    fieldName = "Manual";
                    reasonName = "manual";
                case "solverobservation"
                    fieldName = "SolverObservation";
                    reasonName = "solverObservation";
                case "residualaccepted"
                    fieldName = "ResidualAccepted";
                    reasonName = "residualAccepted";
                otherwise
                    error("ProjectionAlignmentMatchLedger:invalidStage", ...
                        "Unsupported match-ledger stage %s.", stageName);
            end
        end

        function residuals = setNamedResiduals(residuals, lossMode, before, after)
            switch lossMode
                case "projectionPlane2D"
                    residuals.ProjectionPlaneBeforeMeters = before;
                    residuals.ProjectionPlaneAfterMeters = after;
                case "rayToRay3D"
                    residuals.RayClosestApproachBeforeMeters = before;
                    residuals.RayClosestApproachAfterMeters = after;
                case "epipolarCoplanarity"
                    residuals.EpipolarCoplanarityBeforeRadians = before;
                    residuals.EpipolarCoplanarityAfterRadians = after;
            end
        end

        function masks = validateStageMasks(masks)
            defaults = ProjectionAlignmentMatchLedger.defaultStageMasks();
            if ~isstruct(masks) || ~isscalar(masks)
                error("ProjectionAlignmentMatchLedger:invalidStageMasks", ...
                    "StageMasks must be a scalar struct.");
            end
            names = fieldnames(defaults);
            for nameIndex = 1:numel(names)
                name = names{nameIndex};
                if isfield(masks, name)
                    defaults.(name) = ProjectionAlignmentMatchLedger.validateLogical( ...
                        masks.(name), "StageMasks." + string(name));
                end
            end
            masks = defaults;
        end

        function residuals = validateResiduals(residuals)
            defaults = ProjectionAlignmentMatchLedger.defaultResiduals();
            if ~isstruct(residuals) || ~isscalar(residuals)
                error("ProjectionAlignmentMatchLedger:invalidResiduals", ...
                    "Residuals must be a scalar struct.");
            end
            names = fieldnames(defaults);
            for nameIndex = 1:numel(names)
                name = names{nameIndex};
                if isfield(residuals, name)
                    defaults.(name) = residuals.(name);
                end
            end
            numericNames = names(1:7);
            numericNames = [numericNames; names(10:11)];
            for nameIndex = 1:numel(numericNames)
                name = numericNames{nameIndex};
                defaults.(name) = ...
                    ProjectionAlignmentMatchLedger.validateNumericScalar( ...
                    defaults.(name), "Residuals." + string(name));
            end
            defaults.ActiveLossMode = ProjectionAlignmentMatchLedger.validateString( ...
                defaults.ActiveLossMode, "Residuals.ActiveLossMode", true);
            defaults.ActiveResidualUnit = ...
                ProjectionAlignmentMatchLedger.validateString( ...
                defaults.ActiveResidualUnit, "Residuals.ActiveResidualUnit", true);
            residuals = defaults;
        end

        function mask = validateMask(mask, count)
            if count == 0 && isempty(mask)
                mask = false(0, 1);
                return
            end
            if ~(islogical(mask) || isnumeric(mask)) || ~isvector(mask) || ...
                    numel(mask) ~= count || any(~isfinite(double(mask)))
                error("ProjectionAlignmentMatchLedger:invalidMask", ...
                    "Stage mask must contain one logical value per ledger record.");
            end
            mask = logical(mask(:));
        end

        function indices = validateRecordIndices(indices, recordCount)
            if isempty(indices)
                indices = zeros(0, 1);
                return
            end
            if ~isnumeric(indices) || ~isvector(indices) || ...
                    any(~isfinite(indices)) || any(indices < 1) || ...
                    any(indices > recordCount) || any(fix(indices) ~= indices) || ...
                    numel(unique(indices)) ~= numel(indices)
                error("ProjectionAlignmentMatchLedger:invalidRecordIndices", ...
                    "Raw match indices must uniquely select ledger records.");
            end
            indices = double(indices(:));
        end

        function values = validateResidualVector(values, count, name)
            if ~isnumeric(values) || ~isvector(values) || numel(values) ~= count || ...
                    any(~isfinite(values))
                error("ProjectionAlignmentMatchLedger:invalidResiduals", ...
                    "%s must contain one finite value per solver observation.", name);
            end
            values = double(values(:));
        end

        function lossMode = validateLossMode(lossMode)
            lossMode = ProjectionAlignmentMatchLedger.validateChoice( ...
                lossMode, ["projectionPlane2D", "rayToRay3D", ...
                "epipolarCoplanarity"], "lossMode");
        end

        function residualUnit = validateResidualUnit(lossMode, residualUnit)
            expected = "planeMeters";
            if lossMode == "rayToRay3D"
                expected = "rayMeters";
            elseif lossMode == "epipolarCoplanarity"
                expected = "normalizedAngular";
            end
            residualUnit = ProjectionAlignmentMatchLedger.validateChoice( ...
                residualUnit, expected, "residualUnit");
        end

        function pair = validatePair(pair)
            if ~isnumeric(pair) || numel(pair) ~= 2 || any(~isfinite(pair)) || ...
                    any(pair < 1) || any(fix(pair) ~= pair)
                error("ProjectionAlignmentMatchLedger:invalidPair", ...
                    "Pair must contain two positive integer layer indices.");
            end
            pair = double(pair(:).');
        end

        function layerIds = validateLayerIds(layerIds)
            layerIds = string(layerIds);
            if numel(layerIds) ~= 2 || any(ismissing(layerIds)) || ...
                    any(strlength(strip(layerIds)) == 0) || ...
                    layerIds(1) == layerIds(2)
                error("ProjectionAlignmentMatchLedger:invalidLayerIds", ...
                    "PairLayerIds must contain two distinct nonempty layer IDs.");
            end
            layerIds = reshape(strip(layerIds), 1, []);
        end

        function direction = validateDirection(direction)
            direction = ProjectionAlignmentMatchLedger.validateChoice( ...
                direction, "movingToReference", "PairDirection");
        end

        function value = validatePoint(value, name)
            if ~isnumeric(value) || numel(value) ~= 2 || ...
                    any(~(isfinite(value) | isnan(value)))
                error("ProjectionAlignmentMatchLedger:invalidPoint", ...
                    "%s must be a numeric two-vector with finite or NaN values.", name);
            end
            value = double(value(:).');
        end

        function value = validateNumericScalar(value, name)
            if isempty(value)
                value = NaN;
                return
            end
            if ~isnumeric(value) || ~isscalar(value) || ...
                    ~(isfinite(value) || isnan(value))
                error("ProjectionAlignmentMatchLedger:invalidScalar", ...
                    "%s must be a finite numeric scalar or NaN.", name);
            end
            value = double(value);
        end

        function value = validatePositiveInteger(value, name)
            if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value) || ...
                    value < 1 || fix(value) ~= value
                error("ProjectionAlignmentMatchLedger:invalidInteger", ...
                    "%s must be a positive integer.", name);
            end
            value = double(value);
        end

        function value = validateLogical(value, name)
            if ~(islogical(value) || isnumeric(value)) || ~isscalar(value)
                error("ProjectionAlignmentMatchLedger:invalidLogical", ...
                    "%s must be a scalar logical value.", name);
            end
            value = logical(value);
        end

        function value = validateString(value, name, allowEmpty)
            value = string(value);
            if ~isscalar(value) || ismissing(value) || ...
                    (~allowEmpty && strlength(value) == 0)
                error("ProjectionAlignmentMatchLedger:invalidString", ...
                    "%s must be a scalar string.", name);
            end
        end

        function value = validateChoice(value, allowed, name)
            value = ProjectionAlignmentMatchLedger.validateString( ...
                value, name, false);
            matches = lower(value) == lower(string(allowed));
            if ~any(matches)
                error("ProjectionAlignmentMatchLedger:invalidChoice", ...
                    "%s must be one of: %s.", name, strjoin(string(allowed), ", "));
            end
            allowed = string(allowed);
            value = allowed(find(matches, 1, "first"));
        end
    end
end
