classdef ProjectionViewMetadata
    %ProjectionViewMetadata Normalize stable view identity and image timing.

    properties (Constant)
        DefaultPassId = "pass-default"
        GeneratedViewIdPrefix = "view-"
    end

    methods (Static)
        function scene = ensureScene(scene)
            %ensureScene Return a scene with normalized per-layer view metadata.
            scene = ProjectionLayerIdentity.ensureScene(scene);
            scene.layers = ProjectionViewMetadata.ensureLayers(scene.layers);
        end

        function layers = ensureLayers(layers)
            %ensureLayers Add optional view fields and validate supplied values.
            layers = ProjectionLayerIdentity.ensureLayers(layers);
            layers = ProjectionViewMetadata.addMissingField(layers, "ViewId", "");
            layers = ProjectionViewMetadata.addMissingField( ...
                layers, "PassId", ProjectionViewMetadata.DefaultPassId);
            layers = ProjectionViewMetadata.addMissingField( ...
                layers, "AcquisitionStartTime", []);
            layers = ProjectionViewMetadata.addMissingField( ...
                layers, "AcquisitionStartTimeOriginalText", "");
            layers = ProjectionViewMetadata.addMissingField(layers, "LineRateHz", []);
            layers = ProjectionViewMetadata.addMissingField( ...
                layers, "ScanAxis", "column");
            layers = ProjectionViewMetadata.addMissingField( ...
                layers, "ScanDirection", "increasing");

            viewIds = strings(1, numel(layers));
            for layerIndex = 1:numel(layers)
                viewIds(layerIndex) = ProjectionViewMetadata.optionalId( ...
                    layers(layerIndex).ViewId, "ViewId", layerIndex);
            end
            suppliedIds = viewIds(strlength(viewIds) > 0);
            if numel(unique(suppliedIds)) ~= numel(suppliedIds)
                error("ProjectionViewMetadata:duplicateViewId", ...
                    "Nonempty ViewId values must be unique within a scene.");
            end

            for layerIndex = 1:numel(layers)
                if strlength(viewIds(layerIndex)) == 0
                    viewIds(layerIndex) = ProjectionViewMetadata.generateViewId( ...
                        viewIds);
                end
                layers(layerIndex).ViewId = viewIds(layerIndex);
                layers(layerIndex).PassId = ProjectionViewMetadata.passId( ...
                    layers(layerIndex).PassId, layerIndex);
                originalText = string( ...
                    layers(layerIndex).AcquisitionStartTimeOriginalText);
                [startTime, parsedOriginalText] = ...
                    ProjectionViewMetadata.acquisitionStart( ...
                    layers(layerIndex).AcquisitionStartTime, layerIndex);
                layers(layerIndex).AcquisitionStartTime = startTime;
                if strlength(parsedOriginalText) > 0
                    originalText = parsedOriginalText;
                end
                layers(layerIndex).AcquisitionStartTimeOriginalText = ...
                    originalText;
                layers(layerIndex).LineRateHz = ProjectionViewMetadata.lineRate( ...
                    layers(layerIndex).LineRateHz, layerIndex);
                layers(layerIndex).ScanAxis = ProjectionViewMetadata.scanAxis( ...
                    layers(layerIndex).ScanAxis, layerIndex);
                layers(layerIndex).ScanDirection = ...
                    ProjectionViewMetadata.scanDirection( ...
                    layers(layerIndex).ScanDirection, layerIndex);
            end
        end

        function layer = applyOverrides(layer, metadata)
            %applyOverrides Copy optional public metadata fields onto one layer.
            if isempty(metadata)
                return
            end
            if ~isstruct(metadata) || ~isscalar(metadata)
                error("ProjectionViewMetadata:invalidOverrides", ...
                    "View metadata overrides must be a scalar struct.");
            end
            fieldNames = ["ViewId", "PassId", "AcquisitionStartTime", ...
                "AcquisitionStartTimeOriginalText", "LineRateHz", ...
                "ScanAxis", "ScanDirection"];
            for fieldName = fieldNames
                if isfield(metadata, fieldName)
                    layer.(fieldName) = metadata.(fieldName);
                end
            end
        end

        function viewIds = ids(scene)
            %ids Return view IDs in current layer storage order.
            scene = ProjectionViewMetadata.ensureScene(scene);
            viewIds = reshape(string({scene.layers.ViewId}), 1, []);
        end

        function layerIndex = indexForId(scene, viewId)
            %indexForId Resolve a stable view ID to the current layer index.
            scene = ProjectionViewMetadata.ensureScene(scene);
            viewId = ProjectionViewMetadata.requiredId(viewId, "viewId");
            matches = find(ProjectionViewMetadata.ids(scene) == viewId);
            if isempty(matches)
                error("ProjectionViewMetadata:unknownViewId", ...
                    "ViewId %s is not present in the scene.", viewId);
            end
            if numel(matches) ~= 1
                error("ProjectionViewMetadata:duplicateViewId", ...
                    "ViewId %s is not unique within the scene.", viewId);
            end
            layerIndex = matches(1);
        end

        function identity = pairIdentity(firstViewId, secondViewId)
            %pairIdentity Return stable unordered identity for two distinct views.
            firstViewId = ProjectionViewMetadata.requiredId( ...
                firstViewId, "firstViewId");
            secondViewId = ProjectionViewMetadata.requiredId( ...
                secondViewId, "secondViewId");
            if firstViewId == secondViewId
                error("ProjectionViewMetadata:duplicatePairView", ...
                    "A pair must contain two distinct ViewId values.");
            end
            viewIds = sort([firstViewId secondViewId]);
            identity = struct();
            identity.ViewIds = viewIds;
            identity.PairId = "pair:" + string(jsonencode(cellstr(viewIds)));
        end

        function status = timingStatus(layer)
            %timingStatus Report whether per-line acquisition time is available.
            layer = ProjectionViewMetadata.ensureLayers(layer);
            status = struct(Available=false, Code="", Explanation="", ...
                TimeMode="unavailable", ScanAxis=string(layer.ScanAxis), ...
                ScanDirection=string(layer.ScanDirection), LineCount=0, ...
                StartTime=layer.AcquisitionStartTime, EndTime=[]);
            status.LineCount = ProjectionViewMetadata.lineCount(layer);

            hasStart = ~isempty(layer.AcquisitionStartTime);
            hasRate = ~isempty(layer.LineRateHz);
            if ~hasStart && ~hasRate
                status.Code = "missingStartAndLineRate";
                status.Explanation = ...
                    "Acquisition start time and line rate were not supplied.";
                return
            end
            if ~hasStart
                status.Code = "missingStartTime";
                status.Explanation = "Acquisition start time was not supplied.";
                return
            end
            if ~hasRate
                status.Code = "missingLineRate";
                status.Explanation = "Line rate was not supplied.";
                return
            end

            status.Available = true;
            status.Code = "available";
            status.Explanation = "Per-line acquisition time is available.";
            if isdatetime(layer.AcquisitionStartTime)
                status.TimeMode = "absolute";
            else
                status.TimeMode = "relative";
            end
            if string(layer.ScanDirection) == "increasing"
                endLinePosition = status.LineCount;
            else
                endLinePosition = 1;
            end
            status.EndTime = ProjectionViewMetadata.sampleLineTimes( ...
                layer, endLinePosition);
        end

        function lineTimes = sampleLineTimes(layer, linePositions)
            %sampleLineTimes Derive acquisition time at continuous line positions.
            layer = ProjectionViewMetadata.ensureLayers(layer);
            status = ProjectionViewMetadata.timingStatusWithoutSampling(layer);
            if ~status.Available
                error("ProjectionViewMetadata:timingUnavailable", ...
                    "%s", status.Explanation);
            end
            if ~isnumeric(linePositions) || isempty(linePositions) || ...
                    ~isvector(linePositions) || any(~isfinite(linePositions)) || ...
                    any(linePositions < 1) || any(linePositions > status.LineCount)
                error("ProjectionViewMetadata:invalidLinePositions", ...
                    "Line positions must be finite values inside the scan axis.");
            end
            linePositions = double(reshape(linePositions, size(linePositions)));
            if string(layer.ScanDirection) == "increasing"
                offsets = (linePositions - 1) / layer.LineRateHz;
            else
                offsets = (status.LineCount - linePositions) / layer.LineRateHz;
            end
            if isnumeric(layer.AcquisitionStartTime)
                lineTimes = double(layer.AcquisitionStartTime) + offsets;
            else
                lineTimes = layer.AcquisitionStartTime + seconds(offsets);
            end
        end
    end

    methods (Static, Access = private)
        function layers = addMissingField(layers, fieldName, defaultValue)
            if ~isfield(layers, fieldName)
                [layers.(fieldName)] = deal(defaultValue);
            end
        end

        function value = optionalId(value, fieldName, layerIndex)
            if isempty(value)
                value = "";
                return
            end
            if ~(ischar(value) || isstring(value))
                error("ProjectionViewMetadata:invalidViewId", ...
                    "Scene layer %d %s must be a scalar string.", ...
                    layerIndex, fieldName);
            end
            value = string(value);
            if ~isscalar(value) || ismissing(value)
                error("ProjectionViewMetadata:invalidViewId", ...
                    "Scene layer %d %s must be a trimmed nonempty scalar string.", ...
                    layerIndex, fieldName);
            end
            if strlength(value) == 0
                return
            end
            if value ~= strip(value)
                error("ProjectionViewMetadata:invalidViewId", ...
                    "Scene layer %d %s must be a trimmed nonempty scalar string.", ...
                    layerIndex, fieldName);
            end
        end

        function value = requiredId(value, fieldName)
            if ~(ischar(value) || isstring(value))
                error("ProjectionViewMetadata:invalidViewId", ...
                    "%s must be a trimmed nonempty scalar string.", fieldName);
            end
            value = string(value);
            if ~isscalar(value) || ismissing(value) || ...
                    strlength(strip(value)) == 0 || value ~= strip(value)
                error("ProjectionViewMetadata:invalidViewId", ...
                    "%s must be a trimmed nonempty scalar string.", fieldName);
            end
        end

        function value = generateViewId(existingIds)
            while true
                [~, token] = fileparts(tempname);
                value = ProjectionViewMetadata.GeneratedViewIdPrefix + ...
                    string(token);
                if ~any(existingIds == value)
                    return
                end
            end
        end

        function value = passId(value, layerIndex)
            if isempty(value)
                value = ProjectionViewMetadata.DefaultPassId;
                return
            end
            if ~(ischar(value) || isstring(value))
                error("ProjectionViewMetadata:invalidPassId", ...
                    "Scene layer %d PassId must be a scalar string.", layerIndex);
            end
            value = string(value);
            if ~isscalar(value) || ismissing(value)
                error("ProjectionViewMetadata:invalidPassId", ...
                    "Scene layer %d PassId must be a trimmed nonempty scalar string.", ...
                    layerIndex);
            end
            if strlength(value) == 0
                value = ProjectionViewMetadata.DefaultPassId;
                return
            end
            if value ~= strip(value)
                error("ProjectionViewMetadata:invalidPassId", ...
                    "Scene layer %d PassId must be a trimmed nonempty scalar string.", ...
                    layerIndex);
            end
        end

        function [value, originalText] = acquisitionStart(value, layerIndex)
            originalText = "";
            if isempty(value)
                value = [];
                return
            end
            if ischar(value) || isstring(value)
                value = string(value);
                if ~isscalar(value) || ismissing(value) || ...
                        value ~= strip(value) || strlength(value) == 0
                    error("ProjectionViewMetadata:invalidAcquisitionStartTime", ...
                        "Scene layer %d acquisition time text is invalid.", ...
                        layerIndex);
                end
                originalText = value;
                value = ProjectionViewMetadata.parseUtcAcquisitionText( ...
                    value, layerIndex);
                return
            end
            validNumeric = isnumeric(value) && isscalar(value) && isfinite(value);
            validDuration = isduration(value) && isscalar(value) && ...
                isfinite(seconds(value));
            validDatetime = isdatetime(value) && isscalar(value) && ~isnat(value);
            if ~(validNumeric || validDuration || validDatetime)
                error("ProjectionViewMetadata:invalidAcquisitionStartTime", ...
                    ["Scene layer %d AcquisitionStartTime must be a finite " ...
                    "numeric scalar, duration, datetime, or empty."], layerIndex);
            end
        end

        function value = parseUtcAcquisitionText(text, layerIndex)
            expression = ['^(?<day>\d{2})(?<month>\d{2})' ...
                '(?<year>\d{2}|\d{4})_(?<hour>\d{2})' ...
                '(?<minute>\d{2})(?<second>\d{2})' ...
                '(?<fraction>\.\d+)?$'];
            tokens = regexp(char(text), expression, "names", "once");
            if isempty(tokens)
                error("ProjectionViewMetadata:invalidAcquisitionStartTime", ...
                    "Scene layer %d acquisition time must use strict UTC " + ...
                    "DDMMYY_HHmmSS[.fraction] or DDMMYYYY_HHmmSS[.fraction].", ...
                    layerIndex);
            end
            parsedYear = str2double(tokens.year);
            if strlength(string(tokens.year)) == 2
                if parsedYear >= 80
                    parsedYear = 1900 + parsedYear;
                else
                    parsedYear = 2000 + parsedYear;
                end
            end
            fraction = 0;
            if ~isempty(tokens.fraction)
                fraction = str2double(tokens.fraction);
            end
            components = [parsedYear, str2double(tokens.month), ...
                str2double(tokens.day), str2double(tokens.hour), ...
                str2double(tokens.minute), ...
                str2double(tokens.second) + fraction];
            try
                value = datetime(components, TimeZone="UTC");
            catch exception
                error("ProjectionViewMetadata:invalidAcquisitionStartTime", ...
                    "Scene layer %d acquisition time is invalid: %s", ...
                    layerIndex, exception.message);
            end
            actual = [year(value), month(value), day(value), hour(value), ...
                minute(value), second(value)];
            if any(abs(actual - components) > 1e-9)
                error("ProjectionViewMetadata:invalidAcquisitionStartTime", ...
                    "Scene layer %d acquisition time is not a valid UTC date.", ...
                    layerIndex);
            end
        end

        function value = lineRate(value, layerIndex)
            if isempty(value)
                value = [];
                return
            end
            if ~isnumeric(value) || ~isscalar(value) || ...
                    ~isfinite(value) || value <= 0
                error("ProjectionViewMetadata:invalidLineRate", ...
                    "Scene layer %d LineRateHz must be a positive finite scalar.", ...
                    layerIndex);
            end
            value = double(value);
        end

        function value = scanAxis(value, layerIndex)
            value = lower(string(value));
            if ~isscalar(value) || ismissing(value) || ...
                    ~any(value == ["row" "column"])
                error("ProjectionViewMetadata:invalidScanAxis", ...
                    "Scene layer %d ScanAxis must be row or column.", layerIndex);
            end
        end

        function value = scanDirection(value, layerIndex)
            value = lower(string(value));
            if ~isscalar(value) || ismissing(value) || ...
                    ~any(value == ["increasing" "decreasing"])
                error("ProjectionViewMetadata:invalidScanDirection", ...
                    ["Scene layer %d ScanDirection must be increasing or " ...
                    "decreasing."], layerIndex);
            end
        end

        function count = lineCount(layer)
            imageSize = [];
            if isfield(layer, "ImageMetadata") && ...
                    isfield(layer.ImageMetadata, "ImageSize")
                imageSize = layer.ImageMetadata.ImageSize;
            elseif isfield(layer, "SourceGeometry") && ...
                    isfield(layer.SourceGeometry, "ImageSize")
                imageSize = layer.SourceGeometry.ImageSize;
            elseif isfield(layer, "Image") && ~isempty(layer.Image)
                imageSize = [size(layer.Image, 1), size(layer.Image, 2)];
            end
            if ~isnumeric(imageSize) || numel(imageSize) < 2 || ...
                    any(~isfinite(imageSize(1:2))) || any(imageSize(1:2) < 1)
                error("ProjectionViewMetadata:missingImageSize", ...
                    "Image size is required to derive per-line acquisition time.");
            end
            if string(layer.ScanAxis) == "row"
                count = double(imageSize(1));
            else
                count = double(imageSize(2));
            end
        end

        function status = timingStatusWithoutSampling(layer)
            status = struct(Available=false, Code="", Explanation="", ...
                LineCount=ProjectionViewMetadata.lineCount(layer));
            hasStart = ~isempty(layer.AcquisitionStartTime);
            hasRate = ~isempty(layer.LineRateHz);
            if ~hasStart && ~hasRate
                status.Code = "missingStartAndLineRate";
                status.Explanation = ...
                    "Acquisition start time and line rate were not supplied.";
            elseif ~hasStart
                status.Code = "missingStartTime";
                status.Explanation = "Acquisition start time was not supplied.";
            elseif ~hasRate
                status.Code = "missingLineRate";
                status.Explanation = "Line rate was not supplied.";
            else
                status.Available = true;
                status.Code = "available";
                status.Explanation = "Per-line acquisition time is available.";
            end
        end
    end
end
