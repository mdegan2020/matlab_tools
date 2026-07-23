function tre = serializeRpc00bTre(rpc, swapLP, options)
%serializeRpc00bTre Serialize fitted RPC parameters as a tagged RPC00B TRE.
%
%   tre = serializeRpc00bTre(rpc) returns a string scalar containing the
%   11-character "RPC00B01041" tag/length header followed by the 1041-byte
%   RPC00B payload.
%
%   tre = serializeRpc00bTre(rpc, swapLP) applies the complete RPC00B
%   L/P-variable substitution when swapLP is true. This corrects a fitter
%   that used L for normalized latitude and P for normalized longitude.
%
%   tre = serializeRpc00bTre(..., ErrorBias=value, ErrorRandom=value)
%   supplies the fixed ERR_BIAS and ERR_RAND values in metres. Both default
%   to zero.
%
%   rpc must contain these fields:
%       line_num_coeff, line_den_coeff, samp_num_coeff, samp_den_coeff
%           Twenty finite real coefficients in RPC00B term order.
%       offsets, scales
%           Either five-element numeric vectors in the order
%           [line sample latitude longitude height], or scalar structures
%           with corresponding named fields. Common names such as line,
%           samp/sample, lat/latitude, long/lon/longitude, and height/hae
%           are accepted, as are their *_off, *_offset, or *_scale forms.
%
%   RPC00B coefficient order is:
%       1,L,P,H,LP,LH,PH,L^2,P^2,H^2,LPH,L^3,LP^2,LH^2,
%       L^2P,P^3,PH^2,L^2H,P^2H,H^3.

arguments
    rpc (1, 1) struct {mustBeRpc00bFitStruct}
    swapLP (1, 1) logical = false
    options.ErrorBias (1, 1) double ...
        {mustBeReal, mustBeFinite, mustBeRpc00bError} = 0
    options.ErrorRandom (1, 1) double ...
        {mustBeReal, mustBeFinite, mustBeRpc00bError} = 0
end

components = rpc00bComponents(rpc);
if swapLP
    components.LineNumerator = swapRpc00bLandP( ...
        components.LineNumerator);
    components.LineDenominator = swapRpc00bLandP( ...
        components.LineDenominator);
    components.SampleNumerator = swapRpc00bLandP( ...
        components.SampleNumerator);
    components.SampleDenominator = swapRpc00bLandP( ...
        components.SampleDenominator);
end

offsets = components.Offsets;
scales = components.Scales;
header = sprintf([ ...
    '%1d%07.2f%07.2f%06d%05d%+08.4f%+09.4f%+05d' ...
    '%06d%05d%+08.4f%+09.4f%+05d'], ...
    1, options.ErrorBias, options.ErrorRandom, ...
    round(offsets.Line), round(offsets.Sample), ...
    offsets.Latitude, offsets.Longitude, round(offsets.Height), ...
    round(scales.Line), round(scales.Sample), ...
    scales.Latitude, scales.Longitude, round(scales.Height));

coefficients = [ ...
    components.LineNumerator, components.LineDenominator, ...
    components.SampleNumerator, components.SampleDenominator];
coefficientFields = strings(1, numel(coefficients));
for index = 1:numel(coefficients)
    coefficientFields(index) = formatRpc00bCoefficient( ...
        coefficients(index));
end

payload = string(header) + join(coefficientFields, "");
if strlength(payload) ~= 1041 || contains(payload, " ")
    error("serializeRpc00bTre:internalFormatFailure", ...
        "The formatted RPC00B payload is not exactly 1041 bytes.");
end
tre = "RPC00B01041" + payload;
end

function mustBeRpc00bFitStruct(rpc)
components = rpc00bComponents(rpc);

mustBeRpc00bCoefficientVector(components.LineNumerator, ...
    "line_num_coeff");
mustBeRpc00bCoefficientVector(components.LineDenominator, ...
    "line_den_coeff");
mustBeRpc00bCoefficientVector(components.SampleNumerator, ...
    "samp_num_coeff");
mustBeRpc00bCoefficientVector(components.SampleDenominator, ...
    "samp_den_coeff");

offsets = components.Offsets;
mustBeRpc00bInteger(offsets.Line, "LINE_OFF");
mustBeRpc00bInteger(offsets.Sample, "SAMP_OFF");
mustBeRpc00bInteger(offsets.Height, "HEIGHT_OFF");
mustBeInClosedRange(offsets.Line, 0, 999999, "LINE_OFF");
mustBeInClosedRange(offsets.Sample, 0, 99999, "SAMP_OFF");
mustBeInClosedRange(offsets.Latitude, -90, 90, "LAT_OFF");
mustBeInClosedRange(offsets.Longitude, -180, 180, "LONG_OFF");
mustBeInClosedRange(offsets.Height, -9999, 9999, "HEIGHT_OFF");

scales = components.Scales;
mustBeRpc00bInteger(scales.Line, "LINE_SCALE");
mustBeRpc00bInteger(scales.Sample, "SAMP_SCALE");
mustBeRpc00bInteger(scales.Height, "HEIGHT_SCALE");
mustBeInClosedRange(scales.Line, 1, 999999, "LINE_SCALE");
mustBeInClosedRange(scales.Sample, 1, 99999, "SAMP_SCALE");
mustBeInClosedRange(scales.Latitude, 0.0001, 90, "LAT_SCALE");
mustBeInClosedRange(scales.Longitude, 0.0001, 180, "LONG_SCALE");
mustBeInClosedRange(scales.Height, 1, 9999, "HEIGHT_SCALE");
end

function components = rpc00bComponents(rpc)
required = [ ...
    "line_num_coeff", "line_den_coeff", ...
    "samp_num_coeff", "samp_den_coeff", "offsets", "scales"];
for name = required
    if ~isfield(rpc, name)
        error("serializeRpc00bTre:missingField", ...
            "RPC input is missing required field '%s'.", name);
    end
end

components = struct( ...
    LineNumerator=reshape(double(rpc.line_num_coeff), 1, []), ...
    LineDenominator=reshape(double(rpc.line_den_coeff), 1, []), ...
    SampleNumerator=reshape(double(rpc.samp_num_coeff), 1, []), ...
    SampleDenominator=reshape(double(rpc.samp_den_coeff), 1, []), ...
    Offsets=rpc00bNormalizer(rpc.offsets, "offsets"), ...
    Scales=rpc00bNormalizer(rpc.scales, "scales"));
end

function values = rpc00bNormalizer(input, kind)
if isnumeric(input)
    if ~isreal(input) || numel(input) ~= 5 || any(~isfinite(input), "all")
        error("serializeRpc00bTre:invalidNormalizer", ...
            "%s must contain five finite real values.", kind);
    end
    input = reshape(double(input), 1, []);
    values = struct( ...
        Line=input(1), Sample=input(2), Latitude=input(3), ...
        Longitude=input(4), Height=input(5));
    return
end

if ~isstruct(input) || ~isscalar(input)
    error("serializeRpc00bTre:invalidNormalizer", ...
        "%s must be a five-element numeric vector or scalar structure.", ...
        kind);
end

if kind == "offsets"
    suffixes = ["", "_off", "_offset"];
else
    suffixes = ["", "_scale"];
end
values = struct( ...
    Line=namedNormalizerValue(input, "line", suffixes, kind), ...
    Sample=namedNormalizerValue(input, ["samp" "sample"], suffixes, kind), ...
    Latitude=namedNormalizerValue(input, ["lat" "latitude"], suffixes, kind), ...
    Longitude=namedNormalizerValue(input, ...
        ["long" "lon" "longitude"], suffixes, kind), ...
    Height=namedNormalizerValue(input, ["height" "hae"], suffixes, kind));
end

function value = namedNormalizerValue(input, roots, suffixes, kind)
aliases = strings(1, 0);
for root = roots
    aliases = [aliases, root + suffixes]; %#ok<AGROW>
end

names = string(fieldnames(input));
matches = ismember(lower(names), lower(aliases));
if nnz(matches) ~= 1
    error("serializeRpc00bTre:invalidNormalizer", ...
        "%s must contain exactly one field matching {%s}.", ...
        kind, strjoin(aliases, ", "));
end
value = input.(char(names(matches)));
if ~isnumeric(value) || ~isreal(value) || ~isscalar(value) || ...
        ~isfinite(value)
    error("serializeRpc00bTre:invalidNormalizer", ...
        "%s.%s must be one finite real numeric scalar.", ...
        kind, names(matches));
end
value = double(value);
end

function mustBeRpc00bCoefficientVector(value, name)
if ~isnumeric(value) || ~isreal(value) || numel(value) ~= 20 || ...
        any(~isfinite(value), "all")
    error("serializeRpc00bTre:invalidCoefficients", ...
        "%s must contain exactly 20 finite real coefficients.", name);
end
if any(abs(value) > 1, "all")
    error("serializeRpc00bTre:coefficientOutOfRange", ...
        "%s coefficients must be in the RPC00B range [-1, 1].", name);
end
end

function mustBeRpc00bError(value)
if value < 0 || value > 9999.99
    error("serializeRpc00bTre:errorOutOfRange", ...
        "RPC00B error values must be between 0 and 9999.99 metres.");
end
end

function mustBeRpc00bInteger(value, name)
tolerance = 8 * eps(max(1, abs(value)));
if abs(value - round(value)) > tolerance
    error("serializeRpc00bTre:nonintegerField", ...
        "%s must be integer-valued for lossless RPC00B serialization.", ...
        name);
end
end

function mustBeInClosedRange(value, lowerBound, upperBound, name)
if value < lowerBound || value > upperBound
    error("serializeRpc00bTre:fieldOutOfRange", ...
        "%s must be in the range [%g, %g].", ...
        name, lowerBound, upperBound);
end
end

function coefficients = swapRpc00bLandP(coefficients)
% Complete monomial substitution L <-> P. This permutation is self-inverse.
permutation = [ ...
    1, 3, 2, 4, 5, 7, 6, 9, 8, 10, 11, 16, 15, 17, 13, 12, ...
    14, 19, 18, 20];
coefficients = coefficients(permutation);
end

function field = formatRpc00bCoefficient(value)
% Use all available mantissa digits while retaining the complete exponent.
if value == 0
    field = "+0.000000E+0";
    return
end

unrounded = regexp(sprintf('%+.16E', value), ...
    '^([+-]\d\.\d+)E([+-]\d+)$', "tokens", "once");
mantissa = str2double(unrounded{1});
exponent = str2double(unrounded{2});

while true
    if exponent == 0
        exponentDigits = 1;
    else
        exponentDigits = floor(log10(abs(exponent))) + 1;
    end
    decimalDigits = 7 - exponentDigits;
    if decimalDigits < 0
        error("serializeRpc00bTre:coefficientExponentOutOfRange", ...
            "Coefficient exponent cannot fit in a 12-byte RPC00B field.");
    end

    roundedMantissa = round(mantissa, decimalDigits);
    if abs(roundedMantissa) < 10
        break
    end
    mantissa = sign(mantissa);
    exponent = exponent + 1;
end

field = string(sprintf('%+.*fE%+d', ...
    decimalDigits, roundedMantissa, exponent));
if strlength(field) ~= 12
    error("serializeRpc00bTre:internalCoefficientFormatFailure", ...
        "Coefficient did not format to exactly 12 bytes.");
end
end
