classdef ProjectionSurfaceRun
    %ProjectionSurfaceRun Defensive graphics-free saved-run ingestion.

    properties (Constant)
        Format = "ProjectionSurfaceLoadedRun"
        Version = 1
    end

    methods (Static)
        function loaded = read(path, options)
            %read Load a validated run, catalog, or point set from one MAT file.
            if nargin < 2
                options = struct();
            end
            options = ProjectionSurfaceRun.validateOptions(options);
            path = string(path);
            if ~isscalar(path) || ismissing(path) || strlength(path) == 0 || ...
                    ~isfile(path)
                error("ProjectionSurfaceRun:invalidPath", ...
                    "Saved-run path must identify an existing MAT file.");
            end
            [~, ~, extension] = fileparts(path);
            if lower(string(extension)) ~= ".mat"
                error("ProjectionSurfaceRun:invalidPath", ...
                    "Saved surface runs must use a .mat file.");
            end
            inventory = whos("-file", path);
            supported = ["surfaceWorkbenchRun" "catalog" "pointSet"];
            names = string({inventory.name});
            selected = supported(ismember(supported, names));
            if isempty(selected)
                error("ProjectionSurfaceRun:unsupportedContents", ...
                    "MAT file contains no supported surface run, catalog, or point set.");
            end
            variable = selected(1);
            info = inventory(names == variable);
            if numel(info) ~= 1 || string(info.class) ~= "struct"
                error("ProjectionSurfaceRun:unsafeVariable", ...
                    "Selected MAT variable must be a plain struct value.");
            end
            values = load(path, variable);
            value = values.(variable);
            if ~isstruct(value) || ~isscalar(value) || ...
                    ProjectionSurfaceRun.hasRuntimeValue(value)
                error("ProjectionSurfaceRun:runtimeState", ...
                    "Saved surface values cannot contain callbacks, handles, or Java state.");
            end
            run = struct();
            pointSet = struct();
            if variable == "surfaceWorkbenchRun"
                run = ProjectionSurfaceRun.validateRun(value);
                if isfield(run, "PointSet") && isstruct(run.PointSet) && ...
                        ~isempty(fieldnames(run.PointSet))
                    pointSet = run.PointSet;
                end
                if isfield(run, "Catalog") && isstruct(run.Catalog) && ...
                        ~isempty(fieldnames(run.Catalog))
                    rawCatalog = run.Catalog;
                elseif ~isempty(fieldnames(pointSet))
                    rawCatalog = ProjectionSurfaceProductCatalog.create( ...
                        pointSet, {});
                else
                    error("ProjectionSurfaceRun:missingSurface", ...
                        "Saved run contains no completed catalog or point set.");
                end
            elseif variable == "catalog"
                rawCatalog = value;
            else
                pointSet = value;
                rawCatalog = ProjectionSurfaceProductCatalog.create(pointSet, {});
            end
            legacy = ~isfield(rawCatalog, "CoordinateFrame") || ...
                (isfield(rawCatalog, "Version") && isequal(rawCatalog.Version, 1));
            if ~isempty(fieldnames(pointSet))
                legacy = legacy || ~isfield(pointSet, "CoordinateFrame");
            end
            rawCatalog = ProjectionSurfaceRun.applyFrameDecision( ...
                rawCatalog, options, legacy);
            catalog = ProjectionSurfaceProductCatalog.validate(rawCatalog);
            if ~isempty(fieldnames(run))
                run.Catalog = catalog;
                if ~isempty(fieldnames(pointSet))
                    pointSet.CoordinateFrame = catalog.CoordinateFrame;
                    run.PointSet = pointSet;
                end
            end
            loaded = struct(Format=ProjectionSurfaceRun.Format, ...
                Version=ProjectionSurfaceRun.Version, Path=path, ...
                SourceVariable=variable, Run=run, Catalog=catalog, ...
                PointSet=pointSet, CoordinateFrame=catalog.CoordinateFrame, ...
                GraphicsStateIncluded=false);
        end
    end

    methods (Static, Access = private)
        function options = validateOptions(value)
            defaults = struct(LegacyFrameDecision="", ...
                CoordinateFrameOverride=struct());
            if isempty(value)
                value = struct();
            end
            if ~isstruct(value) || ~isscalar(value)
                error("ProjectionSurfaceRun:invalidOptions", ...
                    "Loader options must be one scalar struct.");
            end
            names = string(fieldnames(value));
            unknown = setdiff(names, string(fieldnames(defaults)));
            if ~isempty(unknown)
                error("ProjectionSurfaceRun:invalidOptions", ...
                    "Unexpected loader option: %s.", unknown(1));
            end
            for name = names.'
                defaults.(name) = value.(name);
            end
            defaults.LegacyFrameDecision = string( ...
                defaults.LegacyFrameDecision);
            if ~isscalar(defaults.LegacyFrameDecision) || ...
                    ~ismember(defaults.LegacyFrameDecision, ["" "unknown"])
                error("ProjectionSurfaceRun:invalidOptions", ...
                    "LegacyFrameDecision must be empty or explicit 'unknown'.");
            end
            if ~isstruct(defaults.CoordinateFrameOverride) || ...
                    ~isscalar(defaults.CoordinateFrameOverride)
                error("ProjectionSurfaceRun:invalidOptions", ...
                    "CoordinateFrameOverride must be one scalar struct.");
            end
            if ~isempty(fieldnames(defaults.CoordinateFrameOverride))
                defaults.CoordinateFrameOverride = ...
                    ProjectionCoordinateFrame.validate( ...
                    defaults.CoordinateFrameOverride);
            end
            options = defaults;
        end

        function run = validateRun(run)
            required = ["Format" "Version" "Status" ...
                "GraphicsStateIncluded"];
            if any(~isfield(run, required))
                error("ProjectionSurfaceRun:invalidRun", ...
                    "Saved workbench run schema is incomplete.");
            end
            format = string(run.Format);
            if ~isscalar(format) || ~isnumeric(run.Version) || ...
                    ~isscalar(run.Version) || ~isfinite(run.Version) || ...
                    run.Version < 1 || fix(run.Version) ~= run.Version || ...
                    format ~= ProjectionSurfaceWorkbenchRunner.Format
                error("ProjectionSurfaceRun:unsupportedRun", ...
                    "Saved workbench run format or version is malformed.");
            end
            status = string(run.Status);
            if ~isscalar(status) || ismissing(status) || ...
                    ~ismember(status, ["succeeded" "partial" "empty" ...
                    "failed" "cancelled" "unsupported" "notRun"])
                error("ProjectionSurfaceRun:invalidRun", ...
                    "Saved workbench run status is malformed.");
            end
            if ~isscalar(run.GraphicsStateIncluded) || ...
                    ~islogical(run.GraphicsStateIncluded) || ...
                    run.GraphicsStateIncluded
                error("ProjectionSurfaceRun:runtimeState", ...
                    "Saved workbench runs must explicitly exclude graphics state.");
            end
        end

        function catalog = applyFrameDecision(catalog, options, legacy)
            if ~isstruct(catalog) || ~isscalar(catalog)
                error("ProjectionSurfaceRun:invalidCatalog", ...
                    "Saved catalog must be one scalar struct.");
            end
            override = options.CoordinateFrameOverride;
            if legacy && isempty(fieldnames(override)) && ...
                    options.LegacyFrameDecision ~= "unknown"
                error("ProjectionSurfaceRun:legacyFrameDecisionRequired", ...
                    "Version-1 surface data requires explicit LegacyFrameDecision='unknown' or a CoordinateFrameOverride.");
            end
            if ~isempty(fieldnames(override))
                if ~isfield(catalog, "WorldFrame") || ...
                        override.WorldFrameId ~= string(catalog.WorldFrame)
                    error("ProjectionSurfaceRun:frameMismatch", ...
                        "Coordinate-frame override must retain catalog world identity.");
                end
                catalog.CoordinateFrame = override;
                catalog.Version = ProjectionSurfaceProductCatalog.Version;
            end
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
                        if ProjectionSurfaceRun.hasRuntimeValue( ...
                                value(element).(names{index}))
                            tf = true;
                            return
                        end
                    end
                end
            elseif iscell(value)
                tf = false;
                for index = 1:numel(value)
                    if ProjectionSurfaceRun.hasRuntimeValue(value{index})
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
