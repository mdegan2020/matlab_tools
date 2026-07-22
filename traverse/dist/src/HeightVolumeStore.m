classdef HeightVolumeStore < handle
    %HEIGHTVOLUMESTORE Concrete row-slab numeric volume storage.
    %
    % Modes are in-memory or MATLAB v7.3 MAT-file partial access. Arrays use
    % [row,column,label]. Rows must be written before they can be read; this
    % prevents unwritten file initialization values from becoming valid costs.
    %
    % Traceability: algo/main.tex Secs. 10.4 and 14.6;
    % implementation plan Stage C5.

    properties (SetAccess = private)
        Shape (1, 3) double
        Precision (1, 1) string
        Mode (1, 1) string
        FilePath (1, 1) string
        VariableName (1, 1) string
        Metadata (1, 1) struct
        WrittenRows (:, 1) logical
        ReadSeconds (1, 1) double = 0
        WriteSeconds (1, 1) double = 0
        ReadCount (1, 1) double = 0
        WriteCount (1, 1) double = 0
        ReadBytes (1, 1) double = 0
        WriteBytes (1, 1) double = 0
    end

    properties (Access = private)
        Data
        Backing
    end

    methods
        function obj = HeightVolumeStore(shape, options)
            arguments
                shape (1, 3) double ...
                    {mustBeFinite, mustBeInteger, mustBePositive}
                options.Precision (1, 1) string ...
                    {mustBeMember(options.Precision, ...
                    ["single", "double"])} = "single"
                options.Mode (1, 1) string ...
                    {mustBeMember(options.Mode, ...
                    ["memory", "matfile"])} = "memory"
                options.FilePath (1, 1) string ...
                    {mustBeStorePath} = ""
                options.VariableName (1, 1) string ...
                    {mustBeVariableName} = "Volume"
                options.Metadata (1, 1) struct ...
                    {mustBeVolumeMetadata}
            end

            obj.Shape = shape;
            obj.Precision = options.Precision;
            obj.Mode = options.Mode;
            obj.FilePath = options.FilePath;
            obj.VariableName = options.VariableName;
            obj.Metadata = options.Metadata;
            obj.WrittenRows = false(shape(1), 1);
            if numel(options.Metadata.HeightLabelsMetres) ~= shape(3)
                error("HeightVolumeStore:LabelCountMismatch", ...
                    "Metadata height labels must match the third dimension.");
            end
            if options.Mode == "memory" && options.FilePath ~= ""
                error("HeightVolumeStore:UnexpectedFilePath", ...
                    "FilePath must be empty for in-memory storage.");
            elseif options.Mode == "matfile" && options.FilePath == ""
                error("HeightVolumeStore:FilePathRequired", ...
                    "FilePath is required for MAT-file storage.");
            end
            if options.Mode == "memory"
                obj.Data = zeros(shape, options.Precision);
                obj.Backing = [];
            else
                obj.Data = zeros(0, options.Precision);
                obj.Backing = matfile(char(options.FilePath), ...
                    Writable=true);
                obj.Backing.(char(options.VariableName))( ...
                    shape(1), shape(2), shape(3)) = ...
                    cast(0, options.Precision);
                obj.Backing.VolumeShape = shape;
                obj.Backing.VolumePrecision = options.Precision;
                obj.Backing.VolumeMetadata = options.Metadata;
                obj.Backing.WrittenRows = obj.WrittenRows;
            end
        end

        function writeRows(obj, rows, value)
            arguments
                obj (1, 1) HeightVolumeStore
                rows (1, :) double ...
                    {mustBeFinite, mustBeInteger, mustBeContiguousRows( ...
                    rows, obj)}
                value (:, :, :) ...
                    {mustBeNumeric, mustBeReal, mustBeFloating, ...
                    mustMatchSlab(value, rows, obj), ...
                    mustMatchPrecision(value, obj)}
            end

            timer = tic;
            if obj.Mode == "memory"
                obj.Data(rows, :, :) = value;
            else
                obj.Backing.(char(obj.VariableName))(rows, :, :) = value;
            end
            obj.WriteSeconds = obj.WriteSeconds + toc(timer);
            obj.WrittenRows(rows) = true;
            if obj.Mode == "matfile"
                obj.Backing.WrittenRows = obj.WrittenRows;
            end
            info = whos("value");
            obj.WriteBytes = obj.WriteBytes + info.bytes;
            obj.WriteCount = obj.WriteCount + 1;
        end

        function value = readRows(obj, rows)
            arguments
                obj (1, 1) HeightVolumeStore
                rows (1, :) double ...
                    {mustBeFinite, mustBeInteger, mustBeContiguousRows( ...
                    rows, obj)}
            end

            if ~all(obj.WrittenRows(rows))
                error("HeightVolumeStore:RowsNotWritten", ...
                    "Every requested row must be written before reading.");
            end
            timer = tic;
            if obj.Mode == "memory"
                value = obj.Data(rows, :, :);
            else
                value = obj.Backing.(char(obj.VariableName))(rows, :, :);
            end
            obj.ReadSeconds = obj.ReadSeconds + toc(timer);
            info = whos("value");
            obj.ReadBytes = obj.ReadBytes + info.bytes;
            obj.ReadCount = obj.ReadCount + 1;
        end

        function stats = statistics(obj)
            arguments
                obj (1, 1) HeightVolumeStore
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
                "ReadMebibytesPerSecond", rate(obj.ReadBytes, ...
                obj.ReadSeconds), ...
                "WriteMebibytesPerSecond", rate(obj.WriteBytes, ...
                obj.WriteSeconds), ...
                "WrittenRowCount", nnz(obj.WrittenRows), ...
                "Complete", all(obj.WrittenRows));
        end
    end
end

function mustBeStorePath(path)
if path ~= ""
    if isfile(path) || isfolder(path)
        error("HeightVolumeStore:PathExists", ...
            "HeightVolumeStore will not overwrite an existing path.");
    end
    parent = fileparts(path);
    if parent ~= "" && ~isfolder(parent)
        error("HeightVolumeStore:ParentNotFound", ...
            "The MAT-file parent directory must already exist.");
    end
end
end

function mustBeVariableName(name)
if ~isvarname(name)
    error("HeightVolumeStore:InvalidVariableName", ...
        "VariableName must be a valid MATLAB variable name.");
end
end

function mustBeVolumeMetadata(metadata)
required = ["HeightLabelsMetres", "PixelConvention", "WorldFrame", ...
    "ElevationDatum", "ArrayLayout", "InvalidCost"];
if any(~isfield(metadata, required))
    error("HeightVolumeStore:IncompleteMetadata", ...
        "Metadata must define height labels and all coordinate conventions.");
end
end

function mustBeContiguousRows(rows, store)
if isempty(rows) || rows(1) < 1 || rows(end) > store.Shape(1) ...
        || any(diff(rows) ~= 1)
    error("HeightVolumeStore:InvalidRows", ...
        "Rows must be a nonempty contiguous range inside the volume.");
end
end

function mustMatchSlab(value, rows, store)
if size(value, 1) ~= numel(rows) || size(value, 2) ~= store.Shape(2) ...
        || size(value, 3) ~= store.Shape(3) || ndims(value) > 3
    error("HeightVolumeStore:SlabSizeMismatch", ...
        "The slab must have size [numel(rows),columns,labels].");
end
end

function mustMatchPrecision(value, store)
if string(class(value)) ~= store.Precision
    error("HeightVolumeStore:PrecisionMismatch", ...
        "The slab precision must match the store precision.");
end
end

function mustBeFloating(value)
if ~isfloat(value)
    error("HeightVolumeStore:FloatingPointRequired", ...
        "Stored values must use single or double precision.");
end
end

function value = rate(bytes, seconds)
if seconds <= 0
    value = NaN;
else
    value = bytes ./ 2 ^ 20 ./ seconds;
end
end
