classdef HeightTileStore < handle
    %HEIGHTTILESTORE Concrete variable-label tile-volume persistence.
    %
    % Each nonoverlapping row-major tile stores one
    % [localRow,localColumn,localLabel] floating array. Height labels remain
    % double vectors in Plan. Memory and MATLAB v7.3 MAT-file modes share the
    % same explicit written-tile state and permit replacement after adaptive
    % interval expansion.
    %
    % Traceability: algo/main.tex Secs. 10.4 and 14.6;
    % implementation plan C1 milestone 5.

    properties (SetAccess = private)
        Plan table
        Precision (1, 1) string
        Mode (1, 1) string
        FilePath (1, 1) string
        Metadata (1, 1) struct
        WrittenTiles (:, 1) logical
        ReadSeconds (1, 1) double = 0
        WriteSeconds (1, 1) double = 0
        ReadCount (1, 1) double = 0
        WriteCount (1, 1) double = 0
        ReadBytes (1, 1) double = 0
        WriteBytes (1, 1) double = 0
    end

    properties (Access = private)
        Data (:, 1) cell = cell(0, 1)
        Backing
    end

    methods
        function obj = HeightTileStore(plan, options)
            arguments
                plan table {mustBeHeightTilePlan}
                options.Precision (1, 1) string ...
                    {mustBeMember(options.Precision, ...
                    ["single", "double"])} = "single"
                options.Mode (1, 1) string ...
                    {mustBeMember(options.Mode, ...
                    ["memory", "matfile"])} = "memory"
                options.FilePath (1, 1) string ...
                    {mustBeHeightTileStorePath} = ""
                options.Metadata (1, 1) struct ...
                    {mustBeHeightTileMetadata}
            end

            if options.Mode == "memory" && options.FilePath ~= ""
                error("HeightTileStore:UnexpectedFilePath", ...
                    "FilePath must be empty for in-memory storage.");
            elseif options.Mode == "matfile" && options.FilePath == ""
                error("HeightTileStore:FilePathRequired", ...
                    "FilePath is required for MAT-file storage.");
            end
            obj.Plan = plan;
            obj.Precision = options.Precision;
            obj.Mode = options.Mode;
            obj.FilePath = options.FilePath;
            obj.Metadata = options.Metadata;
            obj.WrittenTiles = false(height(plan), 1);
            if options.Mode == "memory"
                obj.Data = cell(height(plan), 1);
                obj.Backing = [];
            else
                obj.Data = cell(0, 1);
                obj.Backing = matfile(char(options.FilePath), Writable=true);
                obj.Backing.TilePlan = plan;
                obj.Backing.TilePrecision = options.Precision;
                obj.Backing.TileMetadata = options.Metadata;
                obj.Backing.WrittenTiles = obj.WrittenTiles;
            end
        end

        function writeTiles(obj, indices, values)
            arguments
                obj (1, 1) HeightTileStore
                indices (1, :) double ...
                    {mustBeHeightTileIndices(indices, obj)}
                values (:, 1) cell ...
                    {mustMatchHeightTileValues(values, indices, obj)}
            end

            obj.writeCore(indices, values);
        end

        function replaceTiles(obj, indices, planRows, values)
            arguments
                obj (1, 1) HeightTileStore
                indices (1, :) double ...
                    {mustBeHeightTileIndices(indices, obj)}
                planRows table ...
                    {mustBeReplacementRows(planRows, indices, obj)}
                values (:, 1) cell ...
                    {mustMatchReplacementValues(values, planRows, obj)}
            end

            obj.Plan(indices, :) = planRows;
            obj.writeCore(indices, values);
            if obj.Mode == "matfile"
                obj.Backing.TilePlan = obj.Plan;
            end
        end

        function synchronizePlan(obj, plan)
            %SYNCHRONIZEPLAN Update an empty store to a final adaptive plan.
            % Spatial tile identity is immutable. Only label-dependent and
            % diagnostic plan fields may change before any values are written.
            % Traceability: implementation plan C1 milestone 5c.
            arguments
                obj (1, 1) HeightTileStore
                plan table ...
                    {mustBeSynchronizedHeightTilePlan(plan, obj)}
            end

            obj.Plan = plan;
            if obj.Mode == "matfile"
                obj.Backing.TilePlan = plan;
            end
        end

        function values = readTiles(obj, indices)
            arguments
                obj (1, 1) HeightTileStore
                indices (1, :) double ...
                    {mustBeHeightTileIndices(indices, obj)}
            end

            if ~all(obj.WrittenTiles(indices))
                error("HeightTileStore:TilesNotWritten", ...
                    "Every requested tile must be written before reading.");
            end
            timer = tic;
            values = cell(numel(indices), 1);
            for k = 1:numel(indices)
                index = indices(k);
                if obj.Mode == "memory"
                    values{k} = obj.Data{index};
                else
                    values{k} = obj.Backing.( ...
                        char(HeightTileStore.variableName(index)));
                end
            end
            obj.ReadSeconds = obj.ReadSeconds + toc(timer);
            bytes = HeightTileStore.cellBytes(values);
            obj.ReadBytes = obj.ReadBytes + bytes;
            obj.ReadCount = obj.ReadCount + 1;
        end

        function groups = rowGroups(obj)
            arguments
                obj (1, 1) HeightTileStore
            end

            bounds = [obj.Plan.RowStart, obj.Plan.RowEnd];
            [uniqueBounds, ~, group] = unique(bounds, "rows", "sorted");
            groups = cell(size(uniqueBounds, 1), 1);
            for k = 1:numel(groups)
                ids = find(group == k);
                [~, order] = sort(obj.Plan.ColumnStart(ids));
                groups{k} = reshape(ids(order), 1, []);
            end
        end

        function stats = statistics(obj)
            arguments
                obj (1, 1) HeightTileStore
            end

            written = find(obj.WrittenTiles);
            valueCount = sum(obj.Plan.PixelCount(written) ...
                .* obj.Plan.LabelCount(written));
            precisionBytes = 8;
            if obj.Precision == "single"
                precisionBytes = 4;
            end
            stats = struct( ...
                "Mode", obj.Mode, ...
                "FilePath", obj.FilePath, ...
                "ReadSeconds", obj.ReadSeconds, ...
                "WriteSeconds", obj.WriteSeconds, ...
                "FileIoSeconds", obj.ReadSeconds + obj.WriteSeconds, ...
                "ReadCount", obj.ReadCount, ...
                "WriteCount", obj.WriteCount, ...
                "ReadBytes", obj.ReadBytes, ...
                "WriteBytes", obj.WriteBytes, ...
                "ReadMebibytesPerSecond", ...
                HeightTileStore.rate(obj.ReadBytes, obj.ReadSeconds), ...
                "WriteMebibytesPerSecond", ...
                HeightTileStore.rate(obj.WriteBytes, obj.WriteSeconds), ...
                "WrittenTileCount", nnz(obj.WrittenTiles), ...
                "TileCount", height(obj.Plan), ...
                "RowGroupCount", numel(obj.rowGroups), ...
                "StoredValueCount", valueCount, ...
                "StoredBytes", valueCount .* precisionBytes, ...
                "Complete", all(obj.WrittenTiles));
        end
    end

    methods (Access = private)
        function writeCore(obj, indices, values)
            timer = tic;
            for k = 1:numel(indices)
                index = indices(k);
                if obj.Mode == "memory"
                    obj.Data{index} = values{k};
                else
                    obj.Backing.(char( ...
                        HeightTileStore.variableName(index))) = values{k};
                end
            end
            obj.WriteSeconds = obj.WriteSeconds + toc(timer);
            obj.WrittenTiles(indices) = true;
            if obj.Mode == "matfile"
                obj.Backing.WrittenTiles = obj.WrittenTiles;
            end
            obj.WriteBytes = obj.WriteBytes ...
                + HeightTileStore.cellBytes(values);
            obj.WriteCount = obj.WriteCount + 1;
        end
    end

    methods (Static, Access = private)
        function name = variableName(index)
            name = "Tile" + compose("%08d", index);
        end

        function bytes = cellBytes(values)
            bytes = 0;
            for k = 1:numel(values)
                value = values{k}; %#ok<NASGU>
                info = whos("value");
                bytes = bytes + info.bytes;
            end
        end

        function value = rate(bytes, seconds)
            if seconds <= 0
                value = NaN;
            else
                value = bytes ./ 2 ^ 20 ./ seconds;
            end
        end
    end
end

function mustBeHeightTilePlan(plan)
required = ["Tile", "RowStart", "RowEnd", "ColumnStart", ...
    "ColumnEnd", "PixelCount", "LabelCount", "HeightLabelsMetres"];
if isempty(plan) || ~all(ismember(required, string(plan.Properties.VariableNames)))
    error("HeightTileStore:InvalidPlan", ...
        "Plan must be nonempty and contain tile bounds, counts, and labels.");
end
values = [plan.Tile; plan.RowStart; plan.RowEnd; ...
    plan.ColumnStart; plan.ColumnEnd; plan.PixelCount; plan.LabelCount];
if any(~isfinite(values)) || any(values < 1) ...
        || any(values ~= fix(values)) ...
        || any(plan.RowEnd < plan.RowStart) ...
        || any(plan.ColumnEnd < plan.ColumnStart) ...
        || numel(unique(plan.Tile)) ~= height(plan)
    error("HeightTileStore:InvalidPlan", ...
        "Tile identifiers, bounds, and counts must be valid integers.");
end
pixelCount = (plan.RowEnd - plan.RowStart + 1) ...
    .* (plan.ColumnEnd - plan.ColumnStart + 1);
if any(pixelCount ~= plan.PixelCount)
    error("HeightTileStore:PixelCountMismatch", ...
        "PixelCount must equal each rectangular tile-core area.");
end
if ~iscell(plan.HeightLabelsMetres) ...
        || any(cellfun(@(z) ~isa(z, "double") || ~isrow(z) ...
        || numel(z) < 3 || any(~isfinite(z)) ...
        || any(diff(z) <= 0), plan.HeightLabelsMetres)) ...
        || any(cellfun(@numel, plan.HeightLabelsMetres) ~= plan.LabelCount)
    error("HeightTileStore:InvalidPlan", ...
        "Each tile needs a finite, increasing double label row.");
end
mustBeCompleteRowGroups(plan);
end

function mustBeCompleteRowGroups(plan)
nr = max(plan.RowEnd);
nc = max(plan.ColumnEnd);
bounds = unique([plan.RowStart, plan.RowEnd], "rows", "sorted");
if bounds(1, 1) ~= 1 || bounds(end, 2) ~= nr ...
        || any(bounds(2:end, 1) ~= bounds(1:(end - 1), 2) + 1)
    error("HeightTileStore:IncompleteRowGroups", ...
        "Tile row groups must form contiguous, nonoverlapping image rows.");
end
for k = 1:size(bounds, 1)
    ids = find(plan.RowStart == bounds(k, 1) ...
        & plan.RowEnd == bounds(k, 2));
    [starts, order] = sort(plan.ColumnStart(ids));
    ends = plan.ColumnEnd(ids(order));
    if starts(1) ~= 1 || ends(end) ~= nc ...
            || any(starts(2:end) ~= ends(1:(end - 1)) + 1)
        error("HeightTileStore:IncompleteColumnGroups", ...
            "Every tile row must partition all image columns exactly.");
    end
end
end

function mustBeHeightTileStorePath(path)
if path ~= ""
    if isfile(path) || isfolder(path)
        error("HeightTileStore:PathExists", ...
            "HeightTileStore will not overwrite an existing path.");
    end
    parent = fileparts(path);
    if parent ~= "" && ~isfolder(parent)
        error("HeightTileStore:ParentNotFound", ...
            "The MAT-file parent directory must already exist.");
    end
end
end

function mustBeSynchronizedHeightTilePlan(plan, store)
mustBeHeightTilePlan(plan);
if any(store.WrittenTiles)
    error("HeightTileStore:CannotSynchronizeWrittenStore", ...
        "A tile-store plan can change only before any values are written.");
end
spatial = ["Tile", "RowStart", "RowEnd", "ColumnStart", ...
    "ColumnEnd", "PixelCount"];
if ~isequal(string(plan.Properties.VariableNames), ...
        string(store.Plan.Properties.VariableNames)) ...
        || ~isequal(plan(:, spatial), store.Plan(:, spatial))
    error("HeightTileStore:SynchronizedPlanSpatialMismatch", ...
        "A synchronized plan must preserve variables and spatial tile identity.");
end
end

function mustBeHeightTileMetadata(metadata)
required = ["PixelConvention", "WorldFrame", "ElevationDatum", ...
    "ArrayLayout", "InvalidCost"];
if any(~isfield(metadata, required))
    error("HeightTileStore:IncompleteMetadata", ...
        "Metadata must define coordinate, layout, datum, and invalidity conventions.");
end
end

function mustBeHeightTileIndices(indices, store)
if isempty(indices) || any(indices < 1) ...
        || any(indices > height(store.Plan)) ...
        || any(diff(indices) <= 0)
    error("HeightTileStore:InvalidIndices", ...
        "Tile row indices must be unique, increasing, and inside Plan.");
end
end

function mustMatchHeightTileValues(values, indices, store)
if numel(values) ~= numel(indices)
    error("HeightTileStore:ValueCountMismatch", ...
        "There must be one value for every tile index.");
end
for k = 1:numel(indices)
    index = indices(k);
    expected = [store.Plan.RowEnd(index) - store.Plan.RowStart(index) + 1, ...
        store.Plan.ColumnEnd(index) - store.Plan.ColumnStart(index) + 1, ...
        store.Plan.LabelCount(index)];
    value = values{k};
    if ~isnumeric(value) || ~isreal(value) || ~isfloat(value) ...
            || string(class(value)) ~= store.Precision ...
            || ~isequal(size(value), expected)
        error("HeightTileStore:ValueSizeOrPrecisionMismatch", ...
            "Each value must match its tile core, labels, and store precision.");
    end
end
end

function mustMatchReplacementValues(values, plan, store)
if numel(values) ~= height(plan)
    error("HeightTileStore:ValueCountMismatch", ...
        "There must be one value for every replacement plan row.");
end
for k = 1:height(plan)
    expected = [plan.RowEnd(k) - plan.RowStart(k) + 1, ...
        plan.ColumnEnd(k) - plan.ColumnStart(k) + 1, ...
        plan.LabelCount(k)];
    value = values{k};
    if ~isnumeric(value) || ~isreal(value) || ~isfloat(value) ...
            || string(class(value)) ~= store.Precision ...
            || ~isequal(size(value), expected)
        error("HeightTileStore:ValueSizeOrPrecisionMismatch", ...
            "Each replacement must match its tile core, labels, and precision.");
    end
end
end

function mustBeReplacementRows(rows, indices, store)
if height(rows) ~= numel(indices) ...
        || ~isequal(string(rows.Properties.VariableNames), ...
        string(store.Plan.Properties.VariableNames))
    error("HeightTileStore:ReplacementPlanMismatch", ...
        "Replacement rows must match the selected store-plan rows.");
end
expected = store.Plan(indices, :);
if any(rows.Tile ~= expected.Tile) ...
        || any(rows.RowStart ~= expected.RowStart) ...
        || any(rows.RowEnd ~= expected.RowEnd) ...
        || any(rows.ColumnStart ~= expected.ColumnStart) ...
        || any(rows.ColumnEnd ~= expected.ColumnEnd) ...
        || any(rows.PixelCount ~= expected.PixelCount)
    error("HeightTileStore:ReplacementBoundsChanged", ...
        "Adaptive replacement may change labels but not tile identity or bounds.");
end
mustBeHeightTilePlan(replaceSelectedRows(store.Plan, indices, rows));
end

function plan = replaceSelectedRows(plan, indices, rows)
plan(indices, :) = rows;
end
