classdef ProjectionCoordinateFrame
    %ProjectionCoordinateFrame Portable authoritative-world/display transform.

    properties (Constant)
        Format = "ProjectionCoordinateFrame"
        Version = 1
    end

    methods (Static)
        function frame = unknown(worldFrameId, worldOriginMeters, derivation)
            %unknown Preserve an unclassified legacy world frame without guessing.
            if nargin < 2 || isempty(worldOriginMeters)
                worldOriginMeters = zeros(3, 1);
            end
            if nargin < 3
                derivation = "legacyFrameUnclassified";
            end
            frame = ProjectionCoordinateFrame.value(worldFrameId, "unknown", ...
                worldOriginMeters, eye(3), "authoritativeWorld", ...
                ["World X" "World Y" "World Z"], ...
                [NaN NaN NaN], "unknown", false, derivation);
        end

        function frame = localCartesian(worldFrameId, worldOriginMeters, ...
                worldToLocalRotation, derivation)
            %localCartesian Declare a metric local Cartesian world frame.
            if nargin < 3 || isempty(worldToLocalRotation)
                worldToLocalRotation = eye(3);
            end
            if nargin < 4
                derivation = "explicitLocalCartesian";
            end
            frame = ProjectionCoordinateFrame.value(worldFrameId, ...
                "localCartesian", worldOriginMeters, worldToLocalRotation, ...
                "localENU", ["Local X" "Local Y" "Local Z"], ...
                [NaN NaN NaN], "relative", false, derivation);
        end

        function frame = ecef(worldFrameId, worldOriginMeters, derivation)
            %ecef Declare WGS84 ECEF and derive an exact local ENU frame.
            if nargin < 3
                derivation = "explicitWgs84Ecef";
            end
            origin = ProjectionCoordinateFrame.coordinates( ...
                worldOriginMeters, "world origin");
            if size(origin, 2) ~= 1
                error("ProjectionCoordinateFrame:invalidOrigin", ...
                    "World origin must be one finite 3x1 point.");
            end
            ellipsoid = wgs84Ellipsoid("meter");
            [latitude, longitude, hae] = ecef2geodetic(ellipsoid, ...
                origin(1), origin(2), origin(3));
            latitudeRadians = deg2rad(latitude);
            longitudeRadians = deg2rad(longitude);
            rotation = [-sin(longitudeRadians) cos(longitudeRadians) 0; ...
                -sin(latitudeRadians) * cos(longitudeRadians) ...
                -sin(latitudeRadians) * sin(longitudeRadians) ...
                cos(latitudeRadians); ...
                cos(latitudeRadians) * cos(longitudeRadians) ...
                cos(latitudeRadians) * sin(longitudeRadians) ...
                sin(latitudeRadians)];
            frame = ProjectionCoordinateFrame.value(worldFrameId, "ecef", ...
                origin, rotation, "localENU", ["East" "North" "Up"], ...
                [latitude longitude hae], "WGS84-HAE", true, derivation);
        end

        function frame = fromDeclaration(worldFrameId, worldOriginMeters)
            %fromDeclaration Classify only recognized explicit frame identifiers.
            worldFrameId = string(worldFrameId);
            normalized = lower(regexprep(worldFrameId, "[^a-zA-Z0-9]", ""));
            if ismember(normalized, ["ecef" "wgs84ecef" "epsg4978"])
                frame = ProjectionCoordinateFrame.ecef(worldFrameId, ...
                    worldOriginMeters, "recognizedDeclaredWgs84Ecef");
            else
                frame = ProjectionCoordinateFrame.unknown(worldFrameId, ...
                    worldOriginMeters, "unrecognizedDeclaredFrame");
            end
        end

        function frame = validate(frame)
            %validate Normalize one portable frame value.
            required = ["Format" "Version" "WorldFrameId" ...
                "CoordinateKind" "WorldUnits" "DisplayFrameId" ...
                "WorldOriginMeters" "WorldToLocalRotation" "AxisNames" ...
                "AxisUnits" "OriginGeodeticDegreesMeters" ...
                "VerticalReference" "AbsoluteHeightAvailable" ...
                "Derivation" "Reversible"];
            if ~isstruct(frame) || ~isscalar(frame) || ...
                    any(~isfield(frame, required)) || ...
                    ProjectionCoordinateFrame.hasRuntimeValue(frame)
                error("ProjectionCoordinateFrame:invalidFrame", ...
                    "Coordinate frame must be one portable value struct.");
            end
            frame.Format = string(frame.Format);
            if ~isscalar(frame.Format) || ...
                    frame.Format ~= ProjectionCoordinateFrame.Format || ...
                    ~isequal(frame.Version, ProjectionCoordinateFrame.Version)
                error("ProjectionCoordinateFrame:unsupportedSchema", ...
                    "Coordinate-frame format and version are unsupported.");
            end
            stringsToCheck = ["WorldFrameId" "CoordinateKind" ...
                "WorldUnits" "DisplayFrameId" "VerticalReference" "Derivation"];
            for field = stringsToCheck
                frame.(field) = string(frame.(field));
                if ~isscalar(frame.(field)) || ismissing(frame.(field)) || ...
                        strlength(frame.(field)) == 0
                    error("ProjectionCoordinateFrame:invalidFrame", ...
                        "%s must be one nonempty string.", field);
                end
            end
            if ~ismember(frame.CoordinateKind, ...
                    ["ecef" "localCartesian" "unknown"]) || ...
                    frame.WorldUnits ~= "meters"
                error("ProjectionCoordinateFrame:invalidFrame", ...
                    "Coordinate kind and metric world units must be explicit.");
            end
            frame.WorldOriginMeters = ProjectionCoordinateFrame.coordinates( ...
                frame.WorldOriginMeters, "world origin");
            if size(frame.WorldOriginMeters, 2) ~= 1
                error("ProjectionCoordinateFrame:invalidOrigin", ...
                    "World origin must be one finite 3x1 point.");
            end
            rotation = double(frame.WorldToLocalRotation);
            if ~isequal(size(rotation), [3 3]) || ...
                    any(~isfinite(rotation), "all") || ...
                    norm(rotation * rotation.' - eye(3), "fro") > 1e-10 || ...
                    abs(det(rotation) - 1) > 1e-10
                error("ProjectionCoordinateFrame:invalidRotation", ...
                    "World-to-local rotation must be finite, orthonormal, and proper.");
            end
            frame.WorldToLocalRotation = rotation;
            frame.AxisNames = reshape(string(frame.AxisNames), 1, []);
            frame.AxisUnits = reshape(string(frame.AxisUnits), 1, []);
            if numel(frame.AxisNames) ~= 3 || ...
                    any(ismissing(frame.AxisNames)) || ...
                    any(strlength(frame.AxisNames) == 0) || ...
                    ~isequal(frame.AxisUnits, ["m" "m" "m"])
                error("ProjectionCoordinateFrame:invalidAxes", ...
                    "Three named metric display axes are required.");
            end
            geodetic = reshape(double( ...
                frame.OriginGeodeticDegreesMeters), 1, []);
            if numel(geodetic) ~= 3 || ...
                    ~(all(isfinite(geodetic)) || all(isnan(geodetic)))
                error("ProjectionCoordinateFrame:invalidOrigin", ...
                    "Geodetic origin must be finite latitude/longitude/HAE or unknown.");
            end
            frame.OriginGeodeticDegreesMeters = geodetic;
            if ~isscalar(frame.AbsoluteHeightAvailable) || ...
                    ~islogical(frame.AbsoluteHeightAvailable) || ...
                    ~isscalar(frame.Reversible) || ~islogical(frame.Reversible) || ...
                    ~frame.Reversible
                error("ProjectionCoordinateFrame:invalidFrame", ...
                    "Availability and reversible-transform state must be explicit.");
            end
            if frame.CoordinateKind == "ecef"
                if ~all(isfinite(geodetic)) || ...
                        ~frame.AbsoluteHeightAvailable || ...
                        frame.VerticalReference ~= "WGS84-HAE" || ...
                        frame.DisplayFrameId ~= "localENU"
                    error("ProjectionCoordinateFrame:invalidEcefFrame", ...
                        "ECEF frames require WGS84 HAE and local ENU metadata.");
                end
            elseif frame.AbsoluteHeightAvailable || ~all(isnan(geodetic))
                error("ProjectionCoordinateFrame:invalidHeightMetadata", ...
                    "Non-ECEF frames cannot claim absolute WGS84 height.");
            end
            supported = ProjectionCoordinateFrame.displayModes(frame);
            if ~ismember(frame.DisplayFrameId, supported)
                error("ProjectionCoordinateFrame:invalidDisplayFrame", ...
                    "Default display frame is unsupported for this coordinate kind.");
            end
        end

        function modes = displayModes(frame)
            %displayModes Return scientifically available display transforms.
            if isstruct(frame) && isfield(frame, "CoordinateKind")
                kind = string(frame.CoordinateKind);
            else
                kind = string(frame);
            end
            if ismember(kind, ["ecef" "localCartesian"])
                modes = ["localENU" "originRelativeWorld" ...
                    "authoritativeWorld"];
            elseif kind == "unknown"
                modes = ["originRelativeWorld" "authoritativeWorld"];
            else
                error("ProjectionCoordinateFrame:invalidFrame", ...
                    "Coordinate kind is unsupported.");
            end
        end

        function display = worldToDisplay(frame, world, displayFrameId)
            %worldToDisplay Derive display coordinates without changing world data.
            frame = ProjectionCoordinateFrame.validate(frame);
            world = ProjectionCoordinateFrame.coordinates(world, "world points");
            displayFrameId = ProjectionCoordinateFrame.displayFrame( ...
                frame, displayFrameId);
            centered = world - frame.WorldOriginMeters;
            if displayFrameId == "localENU"
                display = frame.WorldToLocalRotation * centered;
            elseif displayFrameId == "originRelativeWorld"
                display = centered;
            else
                display = world;
            end
        end

        function world = displayToWorld(frame, display, displayFrameId)
            %displayToWorld Reverse one declared display transform.
            frame = ProjectionCoordinateFrame.validate(frame);
            display = ProjectionCoordinateFrame.coordinates( ...
                display, "display points");
            displayFrameId = ProjectionCoordinateFrame.displayFrame( ...
                frame, displayFrameId);
            if displayFrameId == "localENU"
                world = frame.WorldOriginMeters + ...
                    frame.WorldToLocalRotation.' * display;
            elseif displayFrameId == "originRelativeWorld"
                world = frame.WorldOriginMeters + display;
            else
                world = display;
            end
        end

        function covariance = covarianceToDisplay(frame, covarianceWorld, ...
                displayFrameId)
            %covarianceToDisplay Rotate covariance while preserving world truth.
            frame = ProjectionCoordinateFrame.validate(frame);
            displayFrameId = ProjectionCoordinateFrame.displayFrame( ...
                frame, displayFrameId);
            covarianceWorld = double(covarianceWorld);
            if ~isequal(size(covarianceWorld), [3 3])
                error("ProjectionCoordinateFrame:invalidCovariance", ...
                    "World covariance must be a 3x3 matrix.");
            end
            rotation = eye(3);
            if displayFrameId == "localENU"
                rotation = frame.WorldToLocalRotation;
            end
            covariance = rotation * covarianceWorld * rotation.';
        end

        function height = haeHeight(frame, world)
            %haeHeight Return WGS84 ellipsoid height for explicit ECEF points.
            frame = ProjectionCoordinateFrame.validate(frame);
            if frame.CoordinateKind ~= "ecef" || ...
                    ~frame.AbsoluteHeightAvailable
                error("ProjectionCoordinateFrame:absoluteHeightUnavailable", ...
                    "HAE is unavailable because the world frame is not explicit ECEF.");
            end
            world = ProjectionCoordinateFrame.coordinates(world, "world points");
            ellipsoid = wgs84Ellipsoid("meter");
            [~, ~, height] = ecef2geodetic(ellipsoid, ...
                world(1, :), world(2, :), world(3, :));
        end

        function names = axisNames(frame, displayFrameId)
            %axisNames Return unambiguous labels for the selected display frame.
            frame = ProjectionCoordinateFrame.validate(frame);
            displayFrameId = ProjectionCoordinateFrame.displayFrame( ...
                frame, displayFrameId);
            if displayFrameId == "localENU" && frame.CoordinateKind == "ecef"
                names = ["East (m)" "North (m)" "Up (m)"];
            elseif displayFrameId == "localENU"
                names = frame.AxisNames + " (m)";
            elseif displayFrameId == "originRelativeWorld"
                names = ["World X - origin (m)" "World Y - origin (m)" ...
                    "World Z - origin (m)"];
            else
                names = ["Authoritative world X (m)" ...
                    "Authoritative world Y (m)" "Authoritative world Z (m)"];
            end
        end
    end

    methods (Static, Access = private)
        function frame = value(worldFrameId, kind, origin, rotation, ...
                displayFrameId, axisNames, geodetic, verticalReference, ...
                absoluteHeightAvailable, derivation)
            frame = struct(Format=ProjectionCoordinateFrame.Format, ...
                Version=ProjectionCoordinateFrame.Version, ...
                WorldFrameId=string(worldFrameId), CoordinateKind=string(kind), ...
                WorldUnits="meters", DisplayFrameId=string(displayFrameId), ...
                WorldOriginMeters=reshape(double(origin), 3, 1), ...
                WorldToLocalRotation=double(rotation), ...
                AxisNames=reshape(string(axisNames), 1, []), ...
                AxisUnits=["m" "m" "m"], ...
                OriginGeodeticDegreesMeters=reshape(double(geodetic), 1, []), ...
                VerticalReference=string(verticalReference), ...
                AbsoluteHeightAvailable=logical(absoluteHeightAvailable), ...
                Derivation=string(derivation), Reversible=true);
            frame = ProjectionCoordinateFrame.validate(frame);
        end

        function id = displayFrame(frame, id)
            if nargin < 2 || strlength(string(id)) == 0
                id = frame.DisplayFrameId;
            end
            id = string(id);
            if ~isscalar(id) || ismissing(id) || ...
                    ~ismember(id, ProjectionCoordinateFrame.displayModes(frame))
                error("ProjectionCoordinateFrame:unsupportedDisplayFrame", ...
                    "Display frame is unavailable for this coordinate kind.");
            end
        end

        function coordinates = coordinates(value, name)
            if ~isnumeric(value) || ~isreal(value) || ...
                    size(value, 1) ~= 3 || any(~isfinite(value), "all")
                error("ProjectionCoordinateFrame:invalidCoordinates", ...
                    "%s must be finite real 3xN coordinates.", name);
            end
            coordinates = double(value);
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
                        if ProjectionCoordinateFrame.hasRuntimeValue( ...
                                value(element).(names{index}))
                            tf = true;
                            return
                        end
                    end
                end
            elseif iscell(value)
                tf = false;
                for index = 1:numel(value)
                    if ProjectionCoordinateFrame.hasRuntimeValue(value{index})
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
