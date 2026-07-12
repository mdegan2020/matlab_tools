classdef ProjectionGeometryFingerprint
    %ProjectionGeometryFingerprint Deterministic scientific-geometry identity.

    properties (Constant)
        Algorithm = "SHA-256"
        CanonicalizationVersion = 1
    end

    methods (Static)
        function fingerprint = layer(layer)
            %layer Hash one layer's identity and authoritative geometry.
            layer = ProjectionViewMetadata.ensureLayers(layer);
            status = ProjectionGeometryFingerprint.sourceRevisionStatus( ...
                layer.SourceGeometry);
            if ~status.Verifiable
                error("ProjectionGeometryFingerprint:unverifiableGeometry", ...
                    "%s", status.Explanation);
            end
            payload = struct( ...
                CanonicalizationVersion= ...
                ProjectionGeometryFingerprint.CanonicalizationVersion, ...
                ViewId=string(layer.ViewId), PassId=string(layer.PassId), ...
                LayerId=string(layer.LayerId), ...
                SourceGeometry=ProjectionGeometryFingerprint.canonical( ...
                layer.SourceGeometry), ...
                BaseProjectionPlane=ProjectionGeometryFingerprint.field( ...
                layer, "BaseProjectionPlane", struct()), ...
                CurrentProjectionPlane=ProjectionGeometryFingerprint.field( ...
                layer, "CurrentProjectionPlane", struct()), ...
                ProjectionOffsetMeters=double( ...
                ProjectionGeometryFingerprint.field( ...
                layer, "ProjectionOffsetMeters", zeros(2, 1))), ...
                ViewVectorAngularOffsetsDegrees=double( ...
                ProjectionGeometryFingerprint.field( ...
                layer, "ViewVectorAngularOffsetsDegrees", zeros(3, 1))));
            fingerprint = ProjectionGeometryFingerprint.hash(payload);
        end

        function token = deriveSourceRevision(authoritativeGeometry)
            %deriveSourceRevision Hash serializable authoritative geometry.
            if ~isstruct(authoritativeGeometry) || ...
                    ~isscalar(authoritativeGeometry)
                error("ProjectionGeometryFingerprint:invalidSourceGeometry", ...
                    "Authoritative source geometry must be a scalar struct.");
            end
            if isfield(authoritativeGeometry, "GeometryRevisionToken")
                authoritativeGeometry = rmfield( ...
                    authoritativeGeometry, "GeometryRevisionToken");
            end
            token = ProjectionGeometryFingerprint.hash(authoritativeGeometry);
        end

        function status = sourceRevisionStatus(sourceGeometry)
            %sourceRevisionStatus Verify function-backed geometry identity.
            if ~isstruct(sourceGeometry) || ~isscalar(sourceGeometry)
                status = struct(Verifiable=false, FunctionBacked=false, ...
                    Token="", ReasonCode="invalidGeometry", ...
                    Explanation="Source geometry must be a scalar struct.");
                return
            end
            functionBacked = ProjectionGeometryFingerprint.hasFunctionHandle( ...
                sourceGeometry);
            token = "";
            if isfield(sourceGeometry, "GeometryRevisionToken")
                token = string(sourceGeometry.GeometryRevisionToken);
            end
            validToken = isscalar(token) && ~ismissing(token) && ...
                token == strip(token) && strlength(token) > 0;
            if functionBacked && ~validToken
                status = struct(Verifiable=false, FunctionBacked=true, ...
                    Token="", ReasonCode="unverifiableGeometry", ...
                    Explanation="Function-backed source geometry requires " + ...
                    "a stable serializable GeometryRevisionToken.");
            else
                if ~validToken
                    token = "";
                end
                status = struct(Verifiable=true, ...
                    FunctionBacked=functionBacked, Token=token, ...
                    ReasonCode="verifiable", ...
                    Explanation="Source geometry identity is verifiable.");
            end
        end

        function records = scene(scene)
            %scene Return stable-ID fingerprint records in scene order.
            scene = ProjectionViewMetadata.ensureScene(scene);
            records = repmat(struct(ViewId="", PassId="", LayerId="", ...
                Fingerprint=""), 1, numel(scene.layers));
            for index = 1:numel(scene.layers)
                layer = scene.layers(index);
                records(index) = struct(ViewId=string(layer.ViewId), ...
                    PassId=string(layer.PassId), ...
                    LayerId=string(layer.LayerId), ...
                    Fingerprint=ProjectionGeometryFingerprint.layer(layer));
            end
        end

        function fingerprint = hash(value)
            %hash Hash a canonical JSON representation with SHA-256.
            value = ProjectionGeometryFingerprint.canonical(value);
            json = jsonencode(value);
            digest = java.security.MessageDigest.getInstance('SHA-256');
            digest.update(unicode2native(json, 'UTF-8'));
            bytes = typecast(digest.digest(), 'uint8');
            fingerprint = string(lower(reshape(dec2hex(bytes, 2).', 1, [])));
        end
    end

    methods (Static, Access = private)
        function tf = hasFunctionHandle(value)
            if isa(value, "function_handle")
                tf = true;
            elseif isstruct(value)
                tf = false;
                names = fieldnames(value);
                for elementIndex = 1:numel(value)
                    for nameIndex = 1:numel(names)
                        if ProjectionGeometryFingerprint.hasFunctionHandle( ...
                                value(elementIndex).(names{nameIndex}))
                            tf = true;
                            return
                        end
                    end
                end
            elseif iscell(value)
                tf = false;
                for index = 1:numel(value)
                    if ProjectionGeometryFingerprint.hasFunctionHandle(value{index})
                        tf = true;
                        return
                    end
                end
            else
                tf = false;
            end
        end

        function value = field(source, name, defaultValue)
            if isfield(source, name)
                value = source.(name);
            else
                value = defaultValue;
            end
            value = ProjectionGeometryFingerprint.canonical(value);
        end

        function output = canonical(value)
            if isstruct(value)
                names = sort(fieldnames(value));
                output = struct([]);
                for elementIndex = 1:numel(value)
                    element = struct();
                    for nameIndex = 1:numel(names)
                        name = names{nameIndex};
                        fieldValue = value(elementIndex).(name);
                        if isa(fieldValue, "function_handle")
                            continue
                        end
                        element.(name) = ...
                            ProjectionGeometryFingerprint.canonical(fieldValue);
                    end
                    if elementIndex == 1
                        output = orderfields(element);
                    else
                        output(elementIndex) = orderfields(element);
                    end
                end
                output = reshape(output, size(value));
            elseif iscell(value)
                output = cell(size(value));
                for index = 1:numel(value)
                    output{index} = ...
                        ProjectionGeometryFingerprint.canonical(value{index});
                end
            elseif isdatetime(value)
                output = string(value, "yyyy-MM-dd'T'HH:mm:ss.SSSXXX");
            elseif isduration(value)
                output = seconds(value);
            elseif isstring(value) || ischar(value) || islogical(value) || ...
                    isnumeric(value)
                output = value;
            elseif isempty(value)
                output = [];
            else
                error("ProjectionGeometryFingerprint:unsupportedValue", ...
                    "Geometry fingerprint does not support values of class %s.", ...
                    class(value));
            end
        end
    end
end
