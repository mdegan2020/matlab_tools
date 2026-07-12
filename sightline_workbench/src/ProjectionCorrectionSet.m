classdef ProjectionCorrectionSet
    %ProjectionCorrectionSet Immutable versioned network correction result.

    properties (Constant)
        FormatName = "ProjectionCorrectionSet"
        SchemaVersion = 1
    end

    properties (SetAccess = immutable)
        Format string
        Version double
        GenerationId string
        ParentGenerationId string
        Lifecycle string
        CreatedAt string
        Convention struct
        Views struct
        Passes struct
        Blocks struct
        Geometry struct
        Covariance struct
        Provenance struct
        Diagnostics struct
        Failure struct
    end

    methods
        function data = toStruct(set)
            %toStruct Return portable immutable value data.
            data = struct(Format=set.Format, Version=set.Version, ...
                GenerationId=set.GenerationId, ...
                ParentGenerationId=set.ParentGenerationId, ...
                Lifecycle=set.Lifecycle, CreatedAt=set.CreatedAt, ...
                Convention=set.Convention, Views=set.Views, ...
                Passes=set.Passes, Blocks=set.Blocks, ...
                Geometry=set.Geometry, Covariance=set.Covariance, ...
                Provenance=set.Provenance, Diagnostics=set.Diagnostics, ...
                Failure=set.Failure);
        end

        function text = encode(set)
            %encode Return portable pretty-printed JSON.
            text = jsonencode(ProjectionCorrectionSet.packJson( ...
                set.toStruct()), PrettyPrint=true);
        end

        function write(set, filePath)
            %write Persist the set as portable JSON or MAT value data.
            filePath = ProjectionCorrectionSet.filePath(filePath);
            [~, ~, extension] = fileparts(filePath);
            if strcmpi(extension, ".mat")
                correctionSetData = set.toStruct();
                save(filePath, "correctionSetData");
            elseif strcmpi(extension, ".json")
                fileId = fopen(filePath, "w");
                if fileId < 0
                    error("ProjectionCorrectionSet:fileOpenFailed", ...
                        "Unable to open correction-set file: %s", filePath);
                end
                cleanup = onCleanup(@() fclose(fileId));
                fprintf(fileId, "%s", set.encode());
                clear cleanup
            else
                error("ProjectionCorrectionSet:unsupportedFileType", ...
                    "Correction sets support .mat and .json files.");
            end
        end

        function record = view(set, viewId)
            %view Retrieve one correction record by stable ViewId.
            viewId = ProjectionCorrectionSet.nonemptyString(viewId, "viewId");
            index = find(string({set.Views.ViewId}) == viewId);
            if isempty(index)
                error("ProjectionCorrectionSet:unknownViewId", ...
                    "Correction set does not contain ViewId %s.", viewId);
            end
            record = set.Views(index(1));
        end

        function values = attitudeDegrees(set, semantics)
            %attitudeDegrees Return explicit degree convenience values.
            semantics = lower(ProjectionCorrectionSet.nonemptyString( ...
                semantics, "semantics"));
            fields = struct(parent="ParentAttitudeRadians", ...
                effective="EffectiveAttitudeRadians", ...
                common="CommonAttitudeRadians", ...
                differential="DifferentialAttitudeRadians", ...
                incrementrotationvector="IncrementRotationVectorRadians");
            if ~isfield(fields, semantics)
                error("ProjectionCorrectionSet:invalidSemantics", ...
                    "Unknown attitude semantics %s.", semantics);
            end
            values = rad2deg(reshape([set.Views.(fields.(semantics))], ...
                3, []).');
        end

        function covariance = attitudeCovarianceDegreesSquared(set)
            %attitudeCovarianceDegreesSquared Convert available covariance.
            covariance = set.Covariance.AttitudeRadiansSquared * (180 / pi)^2;
        end

        function status = compatibility(set, scene)
            %compatibility Check stable IDs and exact parent fingerprints.
            scene = ProjectionViewMetadata.ensureScene(scene);
            mismatches = struct("ViewId", {}, "Code", {}, "Explanation", {});
            for index = 1:numel(set.Views)
                record = set.Views(index);
                try
                    layerIndex = ProjectionViewMetadata.indexForId( ...
                        scene, record.ViewId);
                catch
                    mismatches(end + 1) = struct( ...
                        ViewId=record.ViewId, Code="missingView", ...
                        Explanation="ViewId is absent from the scene."); %#ok<AGROW>
                    continue
                end
                layer = scene.layers(layerIndex);
                if string(layer.PassId) ~= record.PassId
                    mismatches(end + 1) = struct( ...
                        ViewId=record.ViewId, Code="passMismatch", ...
                        Explanation="PassId differs from the correction parent."); %#ok<AGROW>
                    continue
                end
                revision = ProjectionGeometryFingerprint.sourceRevisionStatus( ...
                    layer.SourceGeometry);
                if ~revision.Verifiable
                    mismatches(end + 1) = struct( ...
                        ViewId=record.ViewId, Code="unverifiableGeometry", ...
                        Explanation=revision.Explanation); %#ok<AGROW>
                    continue
                end
                current = ProjectionGeometryFingerprint.layer(layer);
                if current ~= record.ParentGeometryFingerprint
                    mismatches(end + 1) = struct( ...
                        ViewId=record.ViewId, Code="staleGeometry", ...
                        Explanation= ...
                        "Scene geometry does not match the correction parent."); %#ok<AGROW>
                end
            end
            if isempty(mismatches)
                status = struct(Compatible=true, ReasonCode="compatible", ...
                    Explanation="Correction parent geometry is compatible.", ...
                    Mismatches=mismatches);
            else
                status = struct(Compatible=false, ...
                    ReasonCode=string(mismatches(1).Code), ...
                    Explanation=string(mismatches(1).Explanation), ...
                    Mismatches=mismatches);
            end
        end

        function assertCompatible(set, scene)
            %assertCompatible Reject stale or identity-incompatible scenes.
            status = set.compatibility(scene);
            if ~status.Compatible
                error("ProjectionCorrectionSet:" + status.ReasonCode, ...
                    "%s", status.Explanation);
            end
        end

        function transitioned = withLifecycle(set, lifecycle)
            %withLifecycle Return a new immutable lifecycle record.
            data = set.toStruct();
            data.Lifecycle = lifecycle;
            transitioned = ProjectionCorrectionSet.create(data);
        end
    end

    methods (Static)
        function set = create(data)
            %create Validate portable data and construct an immutable value.
            if isa(data, "ProjectionCorrectionSet")
                set = data;
                return
            end
            data = ProjectionCorrectionSet.validateData(data);
            set = ProjectionCorrectionSet(data);
        end

        function set = decode(text)
            %decode Construct from portable JSON.
            set = ProjectionCorrectionSet.create( ...
                ProjectionCorrectionSet.unpackJson(jsondecode(text)));
        end

        function set = read(filePath)
            %read Load portable JSON or MAT value data.
            filePath = ProjectionCorrectionSet.filePath(filePath);
            if ~isfile(filePath)
                error("ProjectionCorrectionSet:fileNotFound", ...
                    "Correction-set file does not exist: %s", filePath);
            end
            [~, ~, extension] = fileparts(filePath);
            if strcmpi(extension, ".mat")
                loaded = load(filePath, "correctionSetData");
                if ~isfield(loaded, "correctionSetData")
                    error("ProjectionCorrectionSet:invalidMatFile", ...
                        "MAT file does not contain correctionSetData.");
                end
                set = ProjectionCorrectionSet.create(loaded.correctionSetData);
            elseif strcmpi(extension, ".json")
                set = ProjectionCorrectionSet.decode(fileread(filePath));
            else
                error("ProjectionCorrectionSet:unsupportedFileType", ...
                    "Correction sets support .mat and .json files.");
            end
        end

        function convention = opkConvention()
            %opkConvention Return the explicit legacy view-vector convention.
            convention = struct( ...
                ConventionId="ProjectionMeshBuilder.ViewVectorOPK.v1", ...
                Order=["omega" "phi" "kappa"], Units="radians", ...
                CovarianceUnits="radiansSquared", ...
                ActivePassive="active", ...
                CompositionOrder="R_kappa * R_phi * R_omega", ...
                ApplicationOrder="omegaThenPhiThenKappa", ...
                SourceFrame="worldSourceViewVector", ...
                DestinationFrame="worldCorrectedViewVector", ...
                MultiplicationSide="left", ...
                IncrementSign="positiveRightHandAboutPositiveAxis", ...
                AxisDefinition=struct(Omega="imageYAxis", ...
                Phi="imageXAxis", Kappa="sourceToProjectionPlane"), ...
                EffectiveSemantics="absoluteRelativeToImmutableBase", ...
                IncrementSemantics="rotationRelativeToParent");
        end
    end

    methods (Access = private)
        function set = ProjectionCorrectionSet(data)
            set.Format = data.Format;
            set.Version = data.Version;
            set.GenerationId = data.GenerationId;
            set.ParentGenerationId = data.ParentGenerationId;
            set.Lifecycle = data.Lifecycle;
            set.CreatedAt = data.CreatedAt;
            set.Convention = data.Convention;
            set.Views = data.Views;
            set.Passes = data.Passes;
            set.Blocks = data.Blocks;
            set.Geometry = data.Geometry;
            set.Covariance = data.Covariance;
            set.Provenance = data.Provenance;
            set.Diagnostics = data.Diagnostics;
            set.Failure = data.Failure;
        end
    end

    methods (Static, Access = private)
        function data = validateData(data)
            if ~isstruct(data) || ~isscalar(data)
                error("ProjectionCorrectionSet:invalidData", ...
                    "Correction-set data must be a scalar struct.");
            end
            ProjectionCorrectionSet.validateTopLevelSchema(data);
            data.Format = ProjectionCorrectionSet.validateFormat(data.Format);
            data.Version = ProjectionCorrectionSet.validateVersion(data.Version);
            data.GenerationId = ProjectionCorrectionSet.nonemptyString( ...
                ProjectionCorrectionSet.value(data, "GenerationId", ...
                ProjectionCorrectionSet.newGenerationId()), "GenerationId");
            data.ParentGenerationId = ProjectionCorrectionSet.optionalString( ...
                ProjectionCorrectionSet.value(data, "ParentGenerationId", ""), ...
                "ParentGenerationId");
            lifecycle = lower(ProjectionCorrectionSet.nonemptyString( ...
                ProjectionCorrectionSet.value(data, "Lifecycle", "proposed"), ...
                "Lifecycle"));
            if ~any(lifecycle == ["proposed" "accepted" "applied" ...
                    "reverted" "rejected" "superseded" "historical"])
                error("ProjectionCorrectionSet:invalidLifecycle", ...
                    "Unsupported correction lifecycle %s.", lifecycle);
            end
            data.Lifecycle = lifecycle;
            data.CreatedAt = ProjectionCorrectionSet.nonemptyString( ...
                ProjectionCorrectionSet.value(data, "CreatedAt", ...
                ProjectionCorrectionSet.utcNow()), "CreatedAt");
            data.Convention = ProjectionCorrectionSet.validateConvention( ...
                ProjectionCorrectionSet.value(data, "Convention", ...
                ProjectionCorrectionSet.opkConvention()));
            data.Views = ProjectionCorrectionSet.validateViews( ...
                ProjectionCorrectionSet.value(data, "Views", struct([])));
            data.Passes = ProjectionCorrectionSet.validatePasses( ...
                ProjectionCorrectionSet.value(data, "Passes", struct([])));
            data.Blocks = ProjectionCorrectionSet.validateBlocks( ...
                ProjectionCorrectionSet.value(data, "Blocks", struct([])));
            data.Geometry = ProjectionCorrectionSet.scalarStruct( ...
                ProjectionCorrectionSet.value(data, "Geometry", struct( ...
                FingerprintAlgorithm=ProjectionGeometryFingerprint.Algorithm, ...
                CanonicalizationVersion= ...
                ProjectionGeometryFingerprint.CanonicalizationVersion)), ...
                "Geometry");
            data.Covariance = ProjectionCorrectionSet.validateCovariance( ...
                ProjectionCorrectionSet.value(data, "Covariance", struct()));
            data.Provenance = ProjectionCorrectionSet.scalarStruct( ...
                ProjectionCorrectionSet.value(data, "Provenance", struct()), ...
                "Provenance");
            data.Diagnostics = ProjectionCorrectionSet.scalarStruct( ...
                ProjectionCorrectionSet.value(data, "Diagnostics", struct()), ...
                "Diagnostics");
            data.Failure = ProjectionCorrectionSet.validateFailure( ...
                ProjectionCorrectionSet.value(data, "Failure", struct()));
        end

        function validateTopLevelSchema(data)
            required = ["Format" "Version"];
            for name = required
                if ~isfield(data, name)
                    error("ProjectionCorrectionSet:missingSchemaField", ...
                        "Correction-set data requires %s.", name);
                end
            end
            allowed = [required "GenerationId" "ParentGenerationId" ...
                "Lifecycle" "CreatedAt" "Convention" "Views" "Passes" ...
                "Blocks" "Geometry" "Covariance" "Provenance" ...
                "Diagnostics" "Failure"];
            names = string(fieldnames(data));
            unknown = names(~ismember(names, allowed));
            if ~isempty(unknown)
                error("ProjectionCorrectionSet:unknownField", ...
                    "Unknown correction-set field %s.", unknown(1));
            end
        end

        function format = validateFormat(format)
            format = string(format);
            if ~isscalar(format) || ismissing(format) || ...
                    strlength(strip(format)) == 0 || format ~= strip(format)
                error("ProjectionCorrectionSet:invalidFormat", ...
                    "Correction-set Format must be a nonempty scalar string.");
            end
            if format ~= ProjectionCorrectionSet.FormatName
                error("ProjectionCorrectionSet:unsupportedFormat", ...
                    "Unsupported correction-set Format %s.", format);
            end
        end

        function version = validateVersion(version)
            if ~isnumeric(version) || ~isscalar(version) || ...
                    ~isfinite(version) || fix(version) ~= version
                error("ProjectionCorrectionSet:invalidVersion", ...
                    "Correction-set Version must be a finite integer scalar.");
            end
            version = double(version);
            if version ~= ProjectionCorrectionSet.SchemaVersion
                error("ProjectionCorrectionSet:unsupportedVersion", ...
                    "Unsupported correction-set Version %g.", version);
            end
        end

        function convention = validateConvention(convention)
            convention = ProjectionCorrectionSet.scalarStruct( ...
                convention, "Convention");
            required = ProjectionCorrectionSet.opkConvention();
            names = fieldnames(required);
            for index = 1:numel(names)
                name = names{index};
                compatible = isfield(convention, name);
                if compatible && isstruct(required.(name))
                    actualStruct = convention.(name);
                    expectedStruct = required.(name);
                    nestedNames = fieldnames(expectedStruct);
                    compatible = isstruct(actualStruct) && ...
                        isscalar(actualStruct) && ...
                        all(isfield(actualStruct, nestedNames));
                    for nestedIndex = 1:numel(nestedNames)
                        nestedName = nestedNames{nestedIndex};
                        compatible = compatible && isequal( ...
                            string(actualStruct.(nestedName)), ...
                            string(expectedStruct.(nestedName)));
                    end
                elseif compatible
                    actual = reshape(string(convention.(name)), 1, []);
                    expected = reshape(string(required.(name)), 1, []);
                    compatible = isequal(actual, expected);
                end
                if ~compatible
                    error("ProjectionCorrectionSet:invalidConvention", ...
                        "Convention field %s is missing or incompatible.", name);
                end
            end
            convention = required;
        end

        function views = validateViews(views)
            if ~isstruct(views) || isempty(views)
                error("ProjectionCorrectionSet:invalidViews", ...
                    "CorrectionSet requires at least one view record.");
            end
            defaults = ProjectionCorrectionSet.defaultView();
            validated = repmat(defaults, 1, numel(views));
            for index = 1:numel(views)
                record = ProjectionCorrectionSet.merge(defaults, views(index));
                record.ViewId = ProjectionCorrectionSet.nonemptyString( ...
                    record.ViewId, "Views.ViewId");
                record.PassId = ProjectionCorrectionSet.nonemptyString( ...
                    record.PassId, "Views.PassId");
                record.LayerId = ProjectionCorrectionSet.optionalString( ...
                    record.LayerId, "Views.LayerId");
                vectorFields = ["ParentAttitudeRadians" ...
                    "EffectiveAttitudeRadians" "CommonAttitudeRadians" ...
                    "DifferentialAttitudeRadians" ...
                    "IncrementRotationVectorRadians"];
                for field = vectorFields
                    record.(field) = ProjectionCorrectionSet.numericShape( ...
                        record.(field), [1 3], "Views." + field);
                end
                matrixFields = ["ParentRotationMatrix" ...
                    "IncrementRotationMatrix" "EffectiveRotationMatrix"];
                for field = matrixFields
                    record.(field) = ProjectionCorrectionSet.rotation( ...
                        record.(field), "Views." + field);
                end
                if norm(record.IncrementRotationMatrix * ...
                        record.ParentRotationMatrix - ...
                        record.EffectiveRotationMatrix, "fro") > 1e-9
                    error("ProjectionCorrectionSet:invalidRotationLineage", ...
                        "Increment * parent must equal effective rotation.");
                end
                offsetFields = ["ParentProjectionOffsetMeters" ...
                    "EffectiveProjectionOffsetMeters"];
                for field = offsetFields
                    record.(field) = ProjectionCorrectionSet.numericShape( ...
                        record.(field), [1 2], "Views." + field);
                end
                fingerprintFields = ["BaseGeometryFingerprint" ...
                    "ParentGeometryFingerprint" ...
                    "CorrectedGeometryFingerprint"];
                for field = fingerprintFields
                    record.(field) = ProjectionCorrectionSet.nonemptyString( ...
                        record.(field), "Views." + field);
                end
                validated(index) = record;
            end
            ids = string({validated.ViewId});
            if numel(unique(ids)) ~= numel(ids)
                error("ProjectionCorrectionSet:duplicateViewId", ...
                    "ViewId records must be unique within a generation.");
            end
            views = validated;
        end

        function passes = validatePasses(passes)
            if isempty(passes)
                passes = struct("PassId", {}, "CommonAttitudeRadians", {}, ...
                    "TranslationMeters", {}, "TranslationAvailable", {});
                return
            end
            if ~isstruct(passes)
                error("ProjectionCorrectionSet:invalidPasses", ...
                    "Passes must be a struct array.");
            end
            defaults = struct(PassId="", CommonAttitudeRadians=zeros(1, 3), ...
                TranslationMeters=zeros(1, 3), TranslationAvailable=false);
            validated = repmat(defaults, 1, numel(passes));
            for index = 1:numel(passes)
                record = ProjectionCorrectionSet.merge(defaults, passes(index));
                record.PassId = ProjectionCorrectionSet.nonemptyString( ...
                    record.PassId, "Passes.PassId");
                record.CommonAttitudeRadians = ...
                    ProjectionCorrectionSet.numericShape( ...
                    record.CommonAttitudeRadians, [1 3], ...
                    "Passes.CommonAttitudeRadians");
                record.TranslationMeters = ProjectionCorrectionSet.numericShape( ...
                    record.TranslationMeters, [1 3], ...
                    "Passes.TranslationMeters");
                record.TranslationAvailable = logical(record.TranslationAvailable);
                validated(index) = record;
            end
            passes = validated;
        end

        function blocks = validateBlocks(blocks)
            if isempty(blocks)
                blocks = struct("Name", {}, "Type", {}, "Scope", {}, ...
                    "TargetId", {}, "Values", {}, "Units", {}, ...
                    "Frame", {}, "Semantics", {});
                return
            end
            if ~isstruct(blocks)
                error("ProjectionCorrectionSet:invalidBlocks", ...
                    "Blocks must be a struct array.");
            end
            defaults = struct(Name="", Type="", Scope="", TargetId="", ...
                Values=[], Units="", Frame="", Semantics="");
            validated = repmat(defaults, 1, numel(blocks));
            for index = 1:numel(blocks)
                block = ProjectionCorrectionSet.merge(defaults, blocks(index));
                names = ["Name" "Type" "Scope" "TargetId" "Units" ...
                    "Frame" "Semantics"];
                for name = names
                    block.(name) = ProjectionCorrectionSet.nonemptyString( ...
                        block.(name), "Blocks." + name);
                end
                if ~isnumeric(block.Values) || any(~isfinite(block.Values), "all")
                    error("ProjectionCorrectionSet:invalidBlocks", ...
                        "Block values must be finite numeric arrays.");
                end
                block.Values = double(block.Values);
                if isvector(block.Values)
                    block.Values = reshape(block.Values, 1, []);
                end
                validated(index) = block;
            end
            blocks = validated;
        end

        function covariance = validateCovariance(covariance)
            defaults = struct(Available=false, ...
                AttitudeRadiansSquared=zeros(0, 0), ...
                ConditionNumber=[], Reason="notAvailable");
            covariance = ProjectionCorrectionSet.merge(defaults, covariance);
            covariance.Available = logical(covariance.Available);
            matrix = covariance.AttitudeRadiansSquared;
            if ~isnumeric(matrix) || any(~isfinite(matrix), "all") || ...
                    (~isempty(matrix) && size(matrix, 1) ~= size(matrix, 2))
                error("ProjectionCorrectionSet:invalidCovariance", ...
                    "Attitude covariance must be a finite square matrix.");
            end
            covariance.AttitudeRadiansSquared = double(matrix);
            covariance.ConditionNumber = double(covariance.ConditionNumber);
            covariance.Reason = ProjectionCorrectionSet.nonemptyString( ...
                covariance.Reason, "Covariance.Reason");
        end

        function failure = validateFailure(failure)
            defaults = struct(Valid=true, Code="none", Explanation="none");
            failure = ProjectionCorrectionSet.merge(defaults, failure);
            failure.Valid = logical(failure.Valid);
            failure.Code = ProjectionCorrectionSet.nonemptyString( ...
                failure.Code, "Failure.Code");
            failure.Explanation = ProjectionCorrectionSet.nonemptyString( ...
                failure.Explanation, "Failure.Explanation");
        end

        function record = defaultView()
            record = struct(ViewId="", PassId="", LayerId="", ...
                ParentAttitudeRadians=zeros(1, 3), ...
                EffectiveAttitudeRadians=zeros(1, 3), ...
                CommonAttitudeRadians=zeros(1, 3), ...
                DifferentialAttitudeRadians=zeros(1, 3), ...
                ParentRotationMatrix=eye(3), ...
                IncrementRotationMatrix=eye(3), ...
                EffectiveRotationMatrix=eye(3), ...
                IncrementRotationVectorRadians=zeros(1, 3), ...
                ParentProjectionOffsetMeters=zeros(1, 2), ...
                EffectiveProjectionOffsetMeters=zeros(1, 2), ...
                BaseGeometryFingerprint="", ...
                ParentGeometryFingerprint="", ...
                CorrectedGeometryFingerprint="");
        end

        function output = merge(defaults, value)
            if isempty(value)
                value = struct();
            end
            if ~isstruct(value) || ~isscalar(value)
                error("ProjectionCorrectionSet:invalidData", ...
                    "Correction-set records must be scalar structs.");
            end
            output = defaults;
            names = fieldnames(value);
            for index = 1:numel(names)
                if ~isfield(defaults, names{index})
                    error("ProjectionCorrectionSet:unknownField", ...
                        "Unknown correction-set field %s.", names{index});
                end
                output.(names{index}) = value.(names{index});
            end
        end

        function value = numericShape(value, shape, name)
            vectorShape = any(shape == 1) && numel(shape) == 2;
            validShape = isequal(size(value), shape) || ...
                (vectorShape && isvector(value) && numel(value) == prod(shape));
            if ~isnumeric(value) || ~validShape || any(~isfinite(value), "all")
                error("ProjectionCorrectionSet:invalidNumericValue", ...
                    "%s must be a finite %s numeric array.", ...
                    name, mat2str(shape));
            end
            value = reshape(double(value), shape);
        end

        function value = rotation(value, name)
            value = ProjectionCorrectionSet.numericShape( ...
                value, [3 3], name);
            if norm(value.' * value - eye(3), "fro") > 1e-9 || ...
                    abs(det(value) - 1) > 1e-9
                error("ProjectionCorrectionSet:invalidRotation", ...
                    "%s must be a proper orthonormal rotation.", name);
            end
        end

        function value = scalarStruct(value, name)
            if ~isstruct(value) || ~isscalar(value)
                error("ProjectionCorrectionSet:invalidData", ...
                    "%s must be a scalar struct.", name);
            end
        end

        function value = value(source, name, defaultValue)
            if isfield(source, name)
                value = source.(name);
            else
                value = defaultValue;
            end
        end

        function value = nonemptyString(value, name)
            value = string(value);
            if ~isscalar(value) || ismissing(value) || ...
                    strlength(strip(value)) == 0 || value ~= strip(value)
                error("ProjectionCorrectionSet:invalidString", ...
                    "%s must be a nonempty trimmed scalar string.", name);
            end
        end

        function value = optionalString(value, name)
            value = string(value);
            if ~isscalar(value) || ismissing(value) || value ~= strip(value)
                error("ProjectionCorrectionSet:invalidString", ...
                    "%s must be a trimmed scalar string.", name);
            end
        end

        function id = newGenerationId()
            [~, token] = fileparts(tempname);
            id = "correction-" + string(token);
        end

        function text = utcNow()
            value = datetime("now", TimeZone="UTC", ...
                Format="yyyy-MM-dd'T'HH:mm:ss.SSSXXX");
            text = string(value);
        end

        function filePath = filePath(filePath)
            filePath = string(filePath);
            if ~isscalar(filePath) || ismissing(filePath) || ...
                    strlength(strip(filePath)) == 0
                error("ProjectionCorrectionSet:invalidFilePath", ...
                    "File path must be a nonempty scalar string.");
            end
            filePath = char(filePath);
        end

        function output = packJson(value)
            if isstring(value)
                output = struct(ProjectionStringArray=true, ...
                    Size=double(size(value)), ...
                    Values={cellstr(value(:))});
            elseif isnumeric(value) || islogical(value)
                output = struct(ProjectionArray=true, ...
                    Class=string(class(value)), Size=double(size(value)), ...
                    Values=reshape(value, 1, []));
            elseif isstruct(value) && isempty(value)
                output = struct(ProjectionEmptyStruct=true, ...
                    Size=double(size(value)), ...
                    Fields={fieldnames(value)});
            elseif isstruct(value) && ~isscalar(value)
                elements = cell(1, numel(value));
                for index = 1:numel(value)
                    elements{index} = ProjectionCorrectionSet.packJson(value(index));
                end
                output = struct(ProjectionStructArray=true, ...
                    Size=double(size(value)), Elements={elements});
            elseif isstruct(value)
                output = value;
                names = fieldnames(value);
                for elementIndex = 1:numel(value)
                    for nameIndex = 1:numel(names)
                        name = names{nameIndex};
                        output(elementIndex).(name) = ...
                            ProjectionCorrectionSet.packJson( ...
                            value(elementIndex).(name));
                    end
                end
            elseif iscell(value)
                output = cell(size(value));
                for index = 1:numel(value)
                    output{index} = ProjectionCorrectionSet.packJson(value{index});
                end
            else
                output = value;
            end
        end

        function output = unpackJson(value)
            if isstruct(value) && isscalar(value) && ...
                    isfield(value, "ProjectionStructArray") && ...
                    logical(value.ProjectionStructArray)
                shape = double(value.Size(:).');
                elements = value.Elements;
                if isstruct(elements)
                    elements = num2cell(elements);
                elseif ~iscell(elements)
                    elements = {elements};
                end
                first = ProjectionCorrectionSet.unpackJson(elements{1});
                output = repmat(first, shape);
                for index = 2:numel(elements)
                    output(index) = ProjectionCorrectionSet.unpackJson( ...
                        elements{index});
                end
            elseif isstruct(value) && isscalar(value) && ...
                    isfield(value, "ProjectionEmptyStruct") && ...
                    logical(value.ProjectionEmptyStruct)
                shape = double(value.Size(:).');
                names = cellstr(string(value.Fields));
                if isempty(names)
                    output = repmat(struct(), shape);
                else
                    template = cell2struct( ...
                        repmat({[]}, numel(names), 1), names, 1);
                    output = repmat(template, shape);
                end
            elseif isstruct(value) && isscalar(value) && ...
                    isfield(value, "ProjectionStringArray") && ...
                    logical(value.ProjectionStringArray)
                shape = double(value.Size(:).');
                output = reshape(string(value.Values), shape);
            elseif isstruct(value) && isscalar(value) && ...
                    isfield(value, "ProjectionArray") && ...
                    logical(value.ProjectionArray)
                shape = double(value.Size(:).');
                values = value.Values;
                if isempty(values)
                    values = zeros(1, 0);
                end
                output = reshape(cast(values, char(string(value.Class))), shape);
            elseif isstruct(value)
                output = value;
                names = fieldnames(value);
                for elementIndex = 1:numel(value)
                    for nameIndex = 1:numel(names)
                        name = names{nameIndex};
                        output(elementIndex).(name) = ...
                            ProjectionCorrectionSet.unpackJson( ...
                            value(elementIndex).(name));
                    end
                end
            elseif iscell(value)
                output = cell(size(value));
                for index = 1:numel(value)
                    output{index} = ...
                        ProjectionCorrectionSet.unpackJson(value{index});
                end
            else
                output = value;
            end
        end
    end
end
