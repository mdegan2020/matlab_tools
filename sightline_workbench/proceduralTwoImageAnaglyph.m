function result = proceduralTwoImageAnaglyph( ...
        images, plane, camera, sourceGeometries, options)
%proceduralTwoImageAnaglyph Direct double two-image/anaglyph oracle.
%
% RESULT = proceduralTwoImageAnaglyph(IMAGES, PLANE, CAMERA, SOURCES, OPTIONS)
% performs explicit output-grid construction, plane reconstruction, source-ray
% intersection, inverse mapping, full-source sampling, physical eye assignment,
% display-only parallax, and canonical red/cyan composition. It is deliberately
% procedural and graphics-free so the same algebra can seed an independent port.

if nargin < 5
    options = struct();
end
[images, plane, camera, sourceGeometries, options] = validateInputs( ...
    images, plane, camera, sourceGeometries, options);

% 1. Define an output grid in the physical plane coordinate frame.
xCoordinates = linspace(options.Bounds.X(1), options.Bounds.X(2), ...
    options.OutputSize(2));
yCoordinates = linspace(options.Bounds.Y(2), options.Bounds.Y(1), ...
    options.OutputSize(1));
[gridX, gridY] = meshgrid(xCoordinates, yCoordinates);
planeCoordinates = [gridX(:).'; gridY(:).'];

% 2. Reconstruct physical output samples from the plane basis.
worldPoints = plane.P0 + plane.basis * planeCoordinates;

% 3. Derive the camera right vector and assign physical left/right eyes.
viewDirection = camera.Target - camera.Position;
viewDirection = viewDirection / norm(viewDirection);
cameraUp = camera.UpVector / norm(camera.UpVector);
cameraRight = cross(viewDirection, cameraUp);
cameraRight = cameraRight / norm(cameraRight);
viewIds = string({sourceGeometries.ViewId});
viewOrigins = horzcat(sourceGeometries.ViewOrigin);
eyeAssignment = assignEyes(viewIds, viewOrigins, cameraRight, options);

% 4. Form display-only eye translations. Physical plane/world points do not move.
displayOffsetsWorld = zeros(3, 2);
for sourceIndex = 1:2
    if sourceGeometries(sourceIndex).ViewId == eyeAssignment.LeftViewId
        eyeSign = -1;
    else
        eyeSign = 1;
    end
    separationShift = (options.StereoExaggeration - 1) * ...
        options.BaseSeparationFraction * camera.ViewWidthMeters;
    displayOffsetsWorld(:, sourceIndex) = eyeSign * ...
        (separationShift + options.ScreenDepthOffsetMeters) * cameraRight;
end
displayOffsetsPlane = plane.basis.' * displayOffsetsWorld;

% 5. Build each direct source-plane topology and inverse map the output grid.
layerImages = cell(1, 2);
layerMasks = cell(1, 2);
coordinateMaps = repmat(struct(RowCoordinates=zeros(0), ...
    ColumnCoordinates=zeros(0), ValidMask=false(0), ...
    SourcePlaneCoordinates=zeros(2, 0), ...
    DisplayQueryPlaneCoordinates=zeros(2, 0)), 1, 2);
support = repmat(struct(ViewId="", RayCount=0, ...
    ForwardIntersectionCount=0), 1, 2);
for sourceIndex = 1:2
    source = sourceGeometries(sourceIndex);
    [origins, rays] = source.SampleFcn( ...
        source.RowIndices, source.ColumnIndices);
    [sourcePlane, forwardMask] = intersectSourceGrid( ...
        origins, rays, plane, source.ProjectionOffsetMeters);
    query = planeCoordinates - displayOffsetsPlane(:, sourceIndex);
    mapping = inverseMap(sourcePlane, forwardMask, source, ...
        size(images{sourceIndex}), query, options.OutputSize);
    [layerImages{sourceIndex}, layerMasks{sourceIndex}] = sampleFullSource( ...
        images{sourceIndex}, mapping, options.Interpolation, ...
        options.InvalidFillValue);
    coordinateMaps(sourceIndex) = struct( ...
        RowCoordinates=mapping.RowCoordinates, ...
        ColumnCoordinates=mapping.ColumnCoordinates, ...
        ValidMask=mapping.ValidMask, ...
        SourcePlaneCoordinates=sourcePlane, ...
        DisplayQueryPlaneCoordinates=query);
    support(sourceIndex) = struct(ViewId=source.ViewId, ...
        RayCount=numel(forwardMask), ...
        ForwardIntersectionCount=nnz(forwardMask));
end

% 6. Select the physically assigned eye images and compose red/cyan output.
leftIndex = find(viewIds == eyeAssignment.LeftViewId, 1);
rightIndex = find(viewIds == eyeAssignment.RightViewId, 1);
leftGray = unitGrayscale(layerImages{leftIndex}, images{leftIndex});
rightGray = unitGrayscale(layerImages{rightIndex}, images{rightIndex});
compositeMask = layerMasks{leftIndex} & layerMasks{rightIndex};
anaglyph = cat(3, leftGray, rightGray, rightGray);
for channel = 1:3
    band = anaglyph(:, :, channel);
    band(~compositeMask) = options.InvalidFillValue;
    anaglyph(:, :, channel) = band;
end

% 7. Return double scientific values plus portable explanatory metadata.
result = struct(Format="ProceduralTwoImageAnaglyph", Version=1, ...
    Precision="double", Images={layerImages}, Masks={layerMasks}, ...
    Anaglyph=anaglyph, ValidMask=compositeMask, ...
    OutputGrid=struct(OutputSize=options.OutputSize, ...
    Bounds=options.Bounds, X=gridX, Y=gridY, ...
    PlaneCoordinates=planeCoordinates, WorldPoints=worldPoints), ...
    EyeAssignment=eyeAssignment, ...
    Presentation=struct(CameraRightVector=cameraRight, ...
    StereoExaggeration=options.StereoExaggeration, ...
    ScreenDepthOffsetMeters=options.ScreenDepthOffsetMeters, ...
    BaseSeparationFraction=options.BaseSeparationFraction, ...
    DisplayOffsetsWorld=displayOffsetsWorld, ...
    DisplayOffsetsPlane=displayOffsetsPlane, ...
    PhysicalGeometryChanged=false), ...
    CoordinateMaps=coordinateMaps, Support=support, ...
    Provenance=struct(Method="directProceduralMatrixOracle", ...
    Interpolation=options.Interpolation, RuntimeStateRetained=false, ...
    GuiUsed=false, CacheUsed=false));
end

function [images, plane, camera, sources, options] = validateInputs( ...
        images, plane, camera, sources, options)
if ~iscell(images) || numel(images) ~= 2
    error("proceduralTwoImageAnaglyph:invalidImages", ...
        "Images must be a two-element cell array.");
end
images = reshape(images, 1, 2);
for index = 1:2
    image = images{index};
    if ~(isnumeric(image) || islogical(image)) || isempty(image) || ...
            ndims(image) > 3 || any(~isfinite(double(image)), "all")
        error("proceduralTwoImageAnaglyph:invalidImages", ...
            "Each image must be a finite nonempty 2-D or 3-D array.");
    end
end

requiredPlane = ["P0" "VN" "basis"];
if ~isstruct(plane) || ~isscalar(plane) || ...
        any(~isfield(plane, requiredPlane)) || ...
        ~isequal(size(plane.P0), [3 1]) || ...
        ~isequal(size(plane.VN), [3 1]) || ...
        ~isequal(size(plane.basis), [3 2]) || ...
        any(~isfinite([plane.P0 plane.VN plane.basis]), "all")
    error("proceduralTwoImageAnaglyph:invalidPlane", ...
        "Plane requires finite P0, VN, and 3-by-2 basis fields.");
end
plane.P0 = double(plane.P0);
plane.VN = double(plane.VN);
plane.basis = double(plane.basis);
if abs(norm(plane.VN) - 1) > 1e-10 || ...
        norm(plane.basis.' * plane.basis - eye(2), "fro") > 1e-10 || ...
        norm(plane.VN.' * plane.basis) > 1e-10
    error("proceduralTwoImageAnaglyph:invalidPlane", ...
        "Plane normal and basis must be orthonormal.");
end

requiredCamera = ["Position" "Target" "UpVector" "ViewWidthMeters"];
if ~isstruct(camera) || ~isscalar(camera) || ...
        any(~isfield(camera, requiredCamera))
    error("proceduralTwoImageAnaglyph:invalidCamera", ...
        "Camera requires Position, Target, UpVector, and ViewWidthMeters.");
end
vectors = [camera.Position camera.Target camera.UpVector];
if ~isnumeric(vectors) || ~isequal(size(vectors), [3 3]) || ...
        any(~isfinite(vectors), "all") || ...
        norm(camera.Target - camera.Position) <= eps || ...
        norm(camera.UpVector) <= eps
    error("proceduralTwoImageAnaglyph:invalidCamera", ...
        "Camera vectors must be finite and nondegenerate.");
end
camera.Position = double(camera.Position);
camera.Target = double(camera.Target);
camera.UpVector = double(camera.UpVector);
camera.ViewWidthMeters = positiveScalar( ...
    camera.ViewWidthMeters, "ViewWidthMeters");
right = cross(camera.Target - camera.Position, camera.UpVector);
if norm(right) <= 1e-12
    error("proceduralTwoImageAnaglyph:invalidCamera", ...
        "Camera up cannot be parallel to the view direction.");
end

requiredSource = ["ViewId" "ViewOrigin" "RowIndices" ...
    "ColumnIndices" "SampleFcn"];
if ~isstruct(sources) || numel(sources) ~= 2 || ...
        any(~isfield(sources, requiredSource))
    error("proceduralTwoImageAnaglyph:invalidSources", ...
        "Exactly two complete source-geometry records are required.");
end
sources = reshape(sources, 1, 2);
for index = 1:2
    sources(index).ViewId = requiredString( ...
        sources(index).ViewId, "ViewId");
    origin = double(sources(index).ViewOrigin(:));
    rows = reshape(double(sources(index).RowIndices), 1, []);
    columns = reshape(double(sources(index).ColumnIndices), 1, []);
    imageSize = size(images{index});
    if numel(origin) ~= 3 || any(~isfinite(origin)) || ...
            ~isnumeric(sources(index).RowIndices) || numel(rows) < 2 || ...
            any(~isfinite(rows)) || any(diff(rows) <= 0) || ...
            rows(1) < 1 || rows(end) > imageSize(1) || ...
            ~isnumeric(sources(index).ColumnIndices) || numel(columns) < 2 || ...
            any(~isfinite(columns)) || any(diff(columns) <= 0) || ...
            columns(1) < 1 || columns(end) > imageSize(2) || ...
            ~isa(sources(index).SampleFcn, "function_handle")
        error("proceduralTwoImageAnaglyph:invalidSources", ...
            "Source origins, indices, and SampleFcn are invalid.");
    end
    sources(index).ViewOrigin = origin;
    sources(index).RowIndices = rows;
    sources(index).ColumnIndices = columns;
    if ~isfield(sources, "ProjectionOffsetMeters") || ...
            isempty(sources(index).ProjectionOffsetMeters)
        sources(index).ProjectionOffsetMeters = zeros(2, 1);
    end
    offset = double(sources(index).ProjectionOffsetMeters(:));
    if numel(offset) ~= 2 || any(~isfinite(offset))
        error("proceduralTwoImageAnaglyph:invalidSources", ...
            "ProjectionOffsetMeters must be a finite two-vector.");
    end
    sources(index).ProjectionOffsetMeters = offset;
end
if sources(1).ViewId == sources(2).ViewId
    error("proceduralTwoImageAnaglyph:invalidSources", ...
        "Source ViewId values must be unique.");
end

defaults = struct(OutputSize=[256 256], ...
    Bounds=struct(X=[-1 1], Y=[-1 1]), Interpolation="bilinear", ...
    InvalidFillValue=0, StereoExaggeration=1, ...
    ScreenDepthOffsetMeters=0, BaseSeparationFraction=0.01, ...
    HysteresisRatio=0.02, PreviousLeftViewId="", ManualSwap=false, ...
    MaxOutputPixels=4000000);
if isempty(options)
    options = struct();
end
if ~isstruct(options) || ~isscalar(options)
    error("proceduralTwoImageAnaglyph:invalidOptions", ...
        "Options must be a scalar struct.");
end
names = string(fieldnames(options));
unknown = setdiff(names, string(fieldnames(defaults)));
if ~isempty(unknown)
    error("proceduralTwoImageAnaglyph:invalidOptions", ...
        "Unexpected option %s.", unknown(1));
end
for name = names.'
    defaults.(name) = options.(name);
end
defaults.OutputSize = positiveIntegerPair(defaults.OutputSize, "OutputSize");
defaults.MaxOutputPixels = positiveInteger( ...
    defaults.MaxOutputPixels, "MaxOutputPixels");
if prod(defaults.OutputSize) > defaults.MaxOutputPixels
    error("proceduralTwoImageAnaglyph:resourceLimit", ...
        "Output grid exceeds MaxOutputPixels.");
end
if ~isstruct(defaults.Bounds) || ~isscalar(defaults.Bounds) || ...
        any(~isfield(defaults.Bounds, ["X" "Y"]))
    error("proceduralTwoImageAnaglyph:invalidBounds", ...
        "Bounds requires X and Y two-vectors.");
end
defaults.Bounds.X = finiteIncreasingPair(defaults.Bounds.X, "Bounds.X");
defaults.Bounds.Y = finiteIncreasingPair(defaults.Bounds.Y, "Bounds.Y");
defaults.Interpolation = lower(string(defaults.Interpolation));
if ~isscalar(defaults.Interpolation) || ...
        ~ismember(defaults.Interpolation, ["bilinear" "nearest"])
    error("proceduralTwoImageAnaglyph:invalidInterpolation", ...
        "Interpolation must be bilinear or nearest.");
end
defaults.InvalidFillValue = finiteScalar( ...
    defaults.InvalidFillValue, "InvalidFillValue");
defaults.StereoExaggeration = nonnegativeScalar( ...
    defaults.StereoExaggeration, "StereoExaggeration");
defaults.ScreenDepthOffsetMeters = finiteScalar( ...
    defaults.ScreenDepthOffsetMeters, "ScreenDepthOffsetMeters");
defaults.BaseSeparationFraction = nonnegativeScalar( ...
    defaults.BaseSeparationFraction, "BaseSeparationFraction");
defaults.HysteresisRatio = nonnegativeScalar( ...
    defaults.HysteresisRatio, "HysteresisRatio");
defaults.PreviousLeftViewId = string(defaults.PreviousLeftViewId);
if ~isscalar(defaults.PreviousLeftViewId) || ...
        (~ismember(defaults.PreviousLeftViewId, ["" string({sources.ViewId})]))
    error("proceduralTwoImageAnaglyph:invalidPreviousEye", ...
        "PreviousLeftViewId must be empty or one of the two views.");
end
if ~(islogical(defaults.ManualSwap) || isnumeric(defaults.ManualSwap)) || ...
        ~isscalar(defaults.ManualSwap) || ...
        ~isfinite(double(defaults.ManualSwap))
    error("proceduralTwoImageAnaglyph:invalidManualSwap", ...
        "ManualSwap must be a logical scalar.");
end
defaults.ManualSwap = logical(defaults.ManualSwap);
options = defaults;
end

function assignment = assignEyes(viewIds, origins, cameraRight, options)
positions = cameraRight.' * origins;
baseline = norm(origins(:, 2) - origins(:, 1));
if baseline <= eps
    ratio = 0;
else
    ratio = (positions(2) - positions(1)) / baseline;
end
isDegenerate = abs(ratio) <= options.HysteresisRatio;
if strlength(options.PreviousLeftViewId) == 0
    if isDegenerate
        ordered = sort(viewIds);
        left = ordered(1);
        right = ordered(2);
        status = "degenerateNoHistory";
    else
        [~, order] = sort(positions, "ascend");
        left = viewIds(order(1));
        right = viewIds(order(2));
        status = "automatic";
    end
else
    left = options.PreviousLeftViewId;
    right = viewIds(viewIds ~= left);
    leftIndex = find(viewIds == left, 1);
    rightIndex = find(viewIds == right, 1);
    signedRatio = (positions(rightIndex) - positions(leftIndex)) / ...
        max(baseline, eps);
    if signedRatio < -options.HysteresisRatio
        [left, right] = deal(right, left);
        status = "automaticSwitched";
    elseif isDegenerate || signedRatio < 0
        status = "retainedHysteresis";
    else
        status = "automatic";
    end
end
if options.ManualSwap
    [left, right] = deal(right, left);
    mode = "manual";
    status = "manualOverride";
else
    mode = "automatic";
end
assignment = struct(LeftViewId=left, RightViewId=right, RedViewId=left, ...
    CyanViewId=right, Mode=mode, Status=status, ...
    IsDegenerate=isDegenerate, ProjectionRatio=ratio, ...
    HysteresisRatio=options.HysteresisRatio, ...
    PreviousLeftViewId=options.PreviousLeftViewId, ...
    ManualSwap=options.ManualSwap);
end

function [planeCoordinates, forwardMask] = intersectSourceGrid( ...
        origins, rays, plane, projectionOffsetMeters)
if ~isnumeric(origins) || ~isnumeric(rays) || size(rays, 1) ~= 3 || ...
        ndims(rays) ~= 3 || any(~isfinite(origins), "all") || ...
        any(~isfinite(rays), "all")
    error("proceduralTwoImageAnaglyph:invalidSourceSamples", ...
        "SampleFcn must return finite origin and 3-by-row-by-column ray arrays.");
end
rowCount = size(rays, 2);
columnCount = size(rays, 3);
if isequal(size(origins), size(rays))
    expandedOrigins = origins;
elseif isequal(size(origins), [3 columnCount])
    expandedOrigins = repmat(reshape(origins, 3, 1, columnCount), ...
        1, rowCount, 1);
elseif isequal(size(origins), [3 1])
    expandedOrigins = repmat(reshape(origins, 3, 1, 1), ...
        1, rowCount, columnCount);
else
    error("proceduralTwoImageAnaglyph:invalidSourceSamples", ...
        "Origins must be 3-by-1, 3-by-column, or match the ray array.");
end
flatOrigins = reshape(double(expandedOrigins), 3, []);
flatRays = reshape(double(rays), 3, []);
denominator = plane.VN.' * flatRays;
numerator = plane.VN.' * (plane.P0 - flatOrigins);
range = numerator ./ denominator;
forwardMask = isfinite(range) & abs(denominator) > 1e-12 & range > 0;
points = flatOrigins + flatRays .* range;
points = points + plane.basis * projectionOffsetMeters;
planeCoordinates = plane.basis.' * (points - plane.P0);
planeCoordinates(:, ~forwardMask) = NaN;
end

function mapping = inverseMap(sourcePlane, forwardMask, source, ...
        imageSize, query, outputSize)
rows = repmat(source.RowIndices(:), 1, numel(source.ColumnIndices));
columns = repmat(source.ColumnIndices(:).', numel(source.RowIndices), 1);
valid = forwardMask(:) & all(isfinite(sourcePlane), 1).';
if nnz(valid) < 4
    error("proceduralTwoImageAnaglyph:insufficientSourceSupport", ...
        "At least four forward source samples are required.");
end
try
    interpolant = scatteredInterpolant(sourcePlane(1, valid).', ...
        sourcePlane(2, valid).', double(rows(valid)), "linear", "none");
    rowCoordinates = reshape(interpolant(query(1, :).', query(2, :).'), ...
        outputSize);
    interpolant.Values = double(columns(valid));
    columnCoordinates = reshape( ...
        interpolant(query(1, :).', query(2, :).'), outputSize);
catch exception
    error("proceduralTwoImageAnaglyph:invalidSourceTopology", ...
        "Source samples do not define a usable inverse map: %s", ...
        exception.message);
end
tolerance = 1e-9 * max([1 imageSize(1:2)]);
validMask = isfinite(rowCoordinates) & isfinite(columnCoordinates) & ...
    rowCoordinates >= 1 - tolerance & rowCoordinates <= imageSize(1) + tolerance & ...
    columnCoordinates >= 1 - tolerance & ...
    columnCoordinates <= imageSize(2) + tolerance;
rowCoordinates(validMask) = min(max(rowCoordinates(validMask), 1), imageSize(1));
columnCoordinates(validMask) = min(max( ...
    columnCoordinates(validMask), 1), imageSize(2));
mapping = struct(RowCoordinates=rowCoordinates, ...
    ColumnCoordinates=columnCoordinates, ValidMask=validMask);
end

function [output, validMask] = sampleFullSource( ...
        image, mapping, interpolation, fillValue)
bandCount = size(image, 3);
output = zeros([size(mapping.ValidMask) bandCount]);
validMask = mapping.ValidMask;
if interpolation == "bilinear"
    method = "linear";
else
    method = "nearest";
end
for bandIndex = 1:bandCount
    band = double(image(:, :, bandIndex));
    sampled = interp2(band, mapping.ColumnCoordinates, ...
        mapping.RowCoordinates, method, NaN);
    bandMask = mapping.ValidMask & isfinite(sampled);
    validMask = validMask & bandMask;
    sampled(~bandMask) = fillValue;
    output(:, :, bandIndex) = sampled;
end
if ~all(validMask, "all")
    for bandIndex = 1:bandCount
        band = output(:, :, bandIndex);
        band(~validMask) = fillValue;
        output(:, :, bandIndex) = band;
    end
end
if bandCount == 1
    output = output(:, :, 1);
end
end

function gray = unitGrayscale(image, sourceImage)
if ismatrix(image)
    gray = image;
else
    gray = mean(double(image), 3);
end
if isinteger(sourceImage)
    gray = double(gray) / double(intmax(class(sourceImage)));
elseif islogical(sourceImage)
    gray = double(gray);
else
    gray = min(max(double(gray), 0), 1);
end
end

function value = requiredString(value, name)
value = string(value);
if ~isscalar(value) || ismissing(value) || strlength(value) == 0 || ...
        value ~= strip(value)
    error("proceduralTwoImageAnaglyph:invalidString", ...
        "%s must be a nonempty trimmed string.", name);
end
end

function value = finiteScalar(value, name)
if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value)
    error("proceduralTwoImageAnaglyph:invalidScalar", ...
        "%s must be a finite scalar.", name);
end
value = double(value);
end

function value = positiveScalar(value, name)
value = finiteScalar(value, name);
if value <= 0
    error("proceduralTwoImageAnaglyph:invalidScalar", ...
        "%s must be positive.", name);
end
end

function value = nonnegativeScalar(value, name)
value = finiteScalar(value, name);
if value < 0
    error("proceduralTwoImageAnaglyph:invalidScalar", ...
        "%s must be nonnegative.", name);
end
end

function value = positiveInteger(value, name)
value = positiveScalar(value, name);
if fix(value) ~= value
    error("proceduralTwoImageAnaglyph:invalidInteger", ...
        "%s must be an integer.", name);
end
end

function value = positiveIntegerPair(value, name)
if ~isnumeric(value) || numel(value) ~= 2 || any(~isfinite(value)) || ...
        any(value < 1) || any(fix(value) ~= value)
    error("proceduralTwoImageAnaglyph:invalidInteger", ...
        "%s must be a positive integer pair.", name);
end
value = reshape(double(value), 1, 2);
end

function value = finiteIncreasingPair(value, name)
if ~isnumeric(value) || numel(value) ~= 2 || any(~isfinite(value)) || ...
        value(2) <= value(1)
    error("proceduralTwoImageAnaglyph:invalidBounds", ...
        "%s must be a finite increasing pair.", name);
end
value = reshape(double(value), 1, 2);
end
