classdef Rpc00bCamera
    %RPC00BCAMERA Vectorized WGS84/HAE RPC00B camera model.
    %
    % Public image coordinates are one-based [x,y]=[sample,line] pixel
    % centers. RPC00B line/sample coordinates are zero-based from the first
    % row/column of the full image, so the adapter adds or subtracts one
    % exactly once at this boundary. Public world rows are
    % [longitudeDegrees,latitudeDegrees,haeMetres].
    %
    % Traceability: STDI-0002 v2.1 Sec. 8.2.4, RPC00B 20-term order;
    % NCDRD STDI-0006 Sec. 2.5.15, zero-based full-subimage coordinates;
    % algo/main.tex Sec. 2.1, Eqs. (1)-(2).

    properties (SetAccess = private)
        Success (1, 1) logical
        ErrorBiasMetres (1, 1) double
        ErrorRandomMetres (1, 1) double
        LineOffset (1, 1) double
        SampleOffset (1, 1) double
        LatitudeOffsetDegrees (1, 1) double
        LongitudeOffsetDegrees (1, 1) double
        HeightOffsetMetres (1, 1) double
        LineScale (1, 1) double
        SampleScale (1, 1) double
        LatitudeScaleDegrees (1, 1) double
        LongitudeScaleDegrees (1, 1) double
        HeightScaleMetres (1, 1) double
        LineNumerator (1, 20) double
        LineDenominator (1, 20) double
        SampleNumerator (1, 20) double
        SampleDenominator (1, 20) double
        FullImageSize (1, 2) double
        ImageSize (1, 2) double
        DownsampleFactor (1, 1) double
        TreSourceKind (1, 1) string
        WorldFrame (1, 1) string = ...
            "WGS84 longitude/latitude degrees and HAE metres"
        ElevationDatum (1, 1) string = "WGS84 ellipsoid HAE metres"
    end

    properties (Constant, Access = private)
        DenominatorTolerance (1, 1) double = 1e-12
        NormalizedLimit (1, 1) double = 1 + 1e-9
    end

    methods
        function obj = Rpc00bCamera(metadata, fullImageSize, options)
            arguments
                metadata {mustBeRpc00bInput}
                fullImageSize (1, 2) double ...
                    {mustBeFinite, mustBeInteger, mustBePositive}
                options.DownsampleFactor (1, 1) double ...
                    {mustBeFinite, mustBeInteger, mustBePositive} = 1
            end

            [m, kind] = Rpc00bCamera.parseTre(metadata);
            if ~m.SUCCESS
                error("Rpc00bCamera:UnsuccessfulTre", ...
                    "RPC00B SUCCESS must be one before the model is used.");
            end

            obj.Success = m.SUCCESS;
            obj.ErrorBiasMetres = m.ERR_BIAS;
            obj.ErrorRandomMetres = m.ERR_RAND;
            obj.LineOffset = m.LINE_OFF;
            obj.SampleOffset = m.SAMP_OFF;
            obj.LatitudeOffsetDegrees = m.LAT_OFF;
            obj.LongitudeOffsetDegrees = m.LONG_OFF;
            obj.HeightOffsetMetres = m.HEIGHT_OFF;
            obj.LineScale = m.LINE_SCALE;
            obj.SampleScale = m.SAMP_SCALE;
            obj.LatitudeScaleDegrees = m.LAT_SCALE;
            obj.LongitudeScaleDegrees = m.LONG_SCALE;
            obj.HeightScaleMetres = m.HEIGHT_SCALE;
            obj.LineNumerator = m.LINE_NUM_COEF;
            obj.LineDenominator = m.LINE_DEN_COEF;
            obj.SampleNumerator = m.SAMP_NUM_COEF;
            obj.SampleDenominator = m.SAMP_DEN_COEF;
            obj.FullImageSize = fullImageSize;
            obj.DownsampleFactor = options.DownsampleFactor;
            obj.ImageSize = ceil(fullImageSize ./ obj.DownsampleFactor);
            obj.TreSourceKind = kind;
        end

        function [pixelXY, valid, diagnostic] = worldToImage(obj, world)
            %WORLDTOIMAGE Project WGS84 longitude/latitude/HAE to pixels.
            % Traceability: STDI-0002 v2.1 Sec. 8.2.4; Eq. (2).

            arguments
                obj (1, 1) Rpc00bCamera
                world (:, 3) double {mustBeReal}
            end

            lon = (world(:, 1) - obj.LongitudeOffsetDegrees) ...
                ./ obj.LongitudeScaleDegrees;
            lat = (world(:, 2) - obj.LatitudeOffsetDegrees) ...
                ./ obj.LatitudeScaleDegrees;
            hae = (world(:, 3) - obj.HeightOffsetMetres) ...
                ./ obj.HeightScaleMetres;
            inputFinite = all(isfinite(world), 2);
            normalizedInside = max(abs([lon, lat, hae]), [], 2) ...
                <= obj.NormalizedLimit;

            [line, sample, ~, ~, ~, ~, denominatorValid] = ...
                obj.evaluateNormalized(lon, lat, hae);
            fullPixelXY = [ ...
                obj.SampleOffset + obj.SampleScale .* sample, ...
                obj.LineOffset + obj.LineScale .* line] + 1;
            pixelXY = obj.fullToProcessed(fullPixelXY);
            valid = inputFinite & normalizedInside & denominatorValid ...
                & all(isfinite(pixelXY), 2);
            pixelXY(~valid, :) = NaN;
            fullPixelXY(~valid, :) = NaN;

            diagnostic = struct( ...
                "InputFinite", inputFinite, ...
                "NormalizationInside", normalizedInside, ...
                "Extrapolated", inputFinite & ~normalizedInside, ...
                "DenominatorValid", denominatorValid, ...
                "RawSampleLine", fullPixelXY - 1, ...
                "FullResolutionPixelXY", fullPixelXY, ...
                "DownsampleFactor", obj.DownsampleFactor, ...
                "NormalizedLongitudeLatitudeHeight", [lon, lat, hae], ...
                "PixelConvention", ...
                "one-based [x,y]=[sample,line] pixel centers", ...
                "RpcPixelConvention", ...
                "zero-based [sample,line] full-image pixel centers", ...
                "WorldConvention", ...
                "[longitudeDegrees,latitudeDegrees,haeMetres] WGS84");
        end

        function [world, valid, diagnostic] = ...
                imageToWorldAtHeight(obj, pixelXY, height, options)
            %IMAGETOWORLDATHEIGHT Invert RPC00B at fixed WGS84 HAE.
            %
            % A bounded vectorized Newton solve operates in normalized
            % longitude/latitude. Iteration is sequential; every active point
            % within one iteration is evaluated together.
            % Traceability: algo/main.tex Sec. 2.1, Eq. (1).

            arguments
                obj (1, 1) Rpc00bCamera
                pixelXY (:, 2) double {mustBeReal}
                height (:, 1) double ...
                    {mustBeReal, mustHaveOneOrNRows(height, pixelXY)}
                options.MaximumIterations (1, 1) double ...
                    {mustBeFinite, mustBeInteger, mustBePositive} = 20
                options.PixelTolerance (1, 1) double ...
                    {mustBeFinite, mustBePositive} = 1e-8
                options.MaximumNormalizedStep (1, 1) double ...
                    {mustBeFinite, mustBePositive, ...
                    mustBeLessThanOrEqual( ...
                    options.MaximumNormalizedStep, 1)} = 0.5
            end

            n = size(pixelXY, 1);
            z = Rpc00bCamera.expandHeight(height, n);
            fullPixelXY = obj.processedToFull(pixelXY);
            raw = fullPixelXY - 1;
            targetSample = (raw(:, 1) - obj.SampleOffset) ...
                ./ obj.SampleScale;
            targetLine = (raw(:, 2) - obj.LineOffset) ./ obj.LineScale;
            hn = (z - obj.HeightOffsetMetres) ./ obj.HeightScaleMetres;
            inputFinite = all(isfinite(pixelXY), 2) & isfinite(z);
            inputInside = obj.isInsideImage(pixelXY);
            fullInputInside = obj.isInsideFullImage(fullPixelXY);
            targetInside = max(abs([targetSample, targetLine, hn]), [], 2) ...
                <= obj.NormalizedLimit;
            inputValid = inputFinite & inputInside & fullInputInside ...
                & targetInside;

            lon = zeros(n, 1);
            lat = zeros(n, 1);
            iterations = zeros(n, 1);
            solverJacobianValid = inputValid;
            for k = 1:options.MaximumIterations
                [line, sample, lineLon, lineLat, sampleLon, sampleLat, ...
                    denominatorValid] = obj.evaluateNormalized(lon, lat, hn);
                sampleResidual = sample - targetSample;
                lineResidual = line - targetLine;
                residualPixels = hypot( ...
                    obj.SampleScale .* sampleResidual, ...
                    obj.LineScale .* lineResidual);
                converged = inputValid & denominatorValid ...
                    & residualPixels <= options.PixelTolerance;
                active = inputValid & ~converged & solverJacobianValid;
                if ~any(active)
                    break
                end

                a = sampleLon;
                b = sampleLat;
                c = lineLon;
                d = lineLat;
                detJ = a .* d - b .* c;
                detScale = max(1, abs(a .* d) + abs(b .* c));
                jacobianValid = denominatorValid & isfinite(detJ) ...
                    & abs(detJ) > 1e-14 .* detScale;
                solverJacobianValid(active & ~jacobianValid) = false;
                active = active & jacobianValid;
                if ~any(active)
                    break
                end

                dLon = (-sampleResidual .* d + b .* lineResidual) ./ detJ;
                dLat = (c .* sampleResidual - a .* lineResidual) ./ detJ;
                step = hypot(dLon, dLat);
                scale = min(1, options.MaximumNormalizedStep ...
                    ./ max(step, realmin));
                lon(active) = lon(active) + dLon(active) .* scale(active);
                lat(active) = lat(active) + dLat(active) .* scale(active);
                iterations(active) = k;
            end

            [line, sample, ~, ~, ~, ~, denominatorValid] = ...
                obj.evaluateNormalized(lon, lat, hn);
            residualPixels = hypot( ...
                obj.SampleScale .* (sample - targetSample), ...
                obj.LineScale .* (line - targetLine));
            converged = inputValid & denominatorValid ...
                & residualPixels <= options.PixelTolerance;
            normalizationInside = max(abs([lon, lat, hn]), [], 2) ...
                <= obj.NormalizedLimit;
            valid = converged & normalizationInside;
            world = [ ...
                obj.LongitudeOffsetDegrees ...
                + obj.LongitudeScaleDegrees .* lon, ...
                obj.LatitudeOffsetDegrees ...
                + obj.LatitudeScaleDegrees .* lat, z];
            world(~valid, :) = NaN;
            residualPixels(~inputValid | ~denominatorValid) = NaN;

            diagnostic = struct( ...
                "Iterations", iterations, ...
                "ResidualPixels", residualPixels, ...
                "Converged", converged, ...
                "InputFinite", inputFinite, ...
                "InputInsideImage", inputInside, ...
                "FullResolutionInputInsideImage", fullInputInside, ...
                "FullResolutionPixelXY", fullPixelXY, ...
                "DownsampleFactor", obj.DownsampleFactor, ...
                "TargetNormalizationInside", targetInside, ...
                "GroundNormalizationInside", normalizationInside, ...
                "DenominatorValid", denominatorValid, ...
                "SolverJacobianValid", solverJacobianValid, ...
                "Nonconverged", inputValid & denominatorValid ...
                & ~converged, ...
                "PixelTolerance", options.PixelTolerance, ...
                "MaximumIterations", options.MaximumIterations, ...
                "WorldConvention", ...
                "[longitudeDegrees,latitudeDegrees,haeMetres] WGS84");
        end

        function valid = isInsideImage(obj, pixelXY, margin)
            %ISINSIDEIMAGE Test support inside the processed image array.

            arguments
                obj (1, 1) Rpc00bCamera
                pixelXY (:, 2) double {mustBeReal}
                margin (1, 1) double ...
                    {mustBeFinite, mustBeNonnegative} = 0
            end

            valid = all(isfinite(pixelXY), 2) ...
                & pixelXY(:, 1) >= 1 + margin ...
                & pixelXY(:, 1) <= obj.ImageSize(2) - margin ...
                & pixelXY(:, 2) >= 1 + margin ...
                & pixelXY(:, 2) <= obj.ImageSize(1) - margin;
            valid = valid & obj.isInsideFullImage( ...
                obj.processedToFull(pixelXY));
        end

        function fullPixelXY = processedToFull(obj, pixelXY)
            %PROCESSEDTOFULL Map processed centers to full-image centers.
            % Traceability: docs/data_contract.md Phase B0 downsampling.

            arguments
                obj (1, 1) Rpc00bCamera
                pixelXY (:, 2) double {mustBeReal}
            end

            fullPixelXY = obj.DownsampleFactor .* (pixelXY - 0.5) + 0.5;
        end

        function pixelXY = fullToProcessed(obj, fullPixelXY)
            %FULLTOPROCESSED Map full-image centers to processed centers.
            % Traceability: docs/data_contract.md Phase B0 downsampling.

            arguments
                obj (1, 1) Rpc00bCamera
                fullPixelXY (:, 2) double {mustBeReal}
            end

            pixelXY = (fullPixelXY - 0.5) ./ obj.DownsampleFactor + 0.5;
        end

        function valid = isInsideFullImage(obj, fullPixelXY, margin)
            %ISINSIDEFULLIMAGE Test support in native TRE coordinates.

            arguments
                obj (1, 1) Rpc00bCamera
                fullPixelXY (:, 2) double {mustBeReal}
                margin (1, 1) double ...
                    {mustBeFinite, mustBeNonnegative} = 0
            end

            valid = all(isfinite(fullPixelXY), 2) ...
                & fullPixelXY(:, 1) >= 1 + margin ...
                & fullPixelXY(:, 1) <= obj.FullImageSize(2) - margin ...
                & fullPixelXY(:, 2) >= 1 + margin ...
                & fullPixelXY(:, 2) <= obj.FullImageSize(1) - margin;
        end
    end

    methods (Static)
        function [metadata, sourceKind] = parseTre(source)
            %PARSETRE Decode a structure, 1041-byte payload, or TRE file.

            arguments
                source {mustBeRpc00bInput}
            end

            if isstruct(source)
                metadata = Rpc00bCamera.normalizeMetadata(source);
                sourceKind = "structure";
                return
            end

            s = string(source);
            if strlength(s) < 512 && isfile(s)
                s = string(fileread(s));
                sourceKind = "file";
            else
                sourceKind = "payload";
            end
            payload = char(erase(erase(s, newline), char(13)));
            if startsWith(payload, "RPC00B")
                if numel(payload) < 11
                    error("Rpc00bCamera:InvalidTreLength", ...
                        "RPC00B TRE header is incomplete.");
                end
                declared = str2double(payload(7:11));
                if declared ~= 1041
                    error("Rpc00bCamera:InvalidTreLength", ...
                        "RPC00B declared payload length must be 1041 bytes.");
                end
                payload = payload(12:end);
            end
            if numel(payload) ~= 1041
                error("Rpc00bCamera:InvalidTreLength", ...
                    "RPC00B payload must contain exactly 1041 ASCII bytes.");
            end

            m = struct( ...
                "SUCCESS", str2double(payload(1)), ...
                "ERR_BIAS", str2double(payload(2:8)), ...
                "ERR_RAND", str2double(payload(9:15)), ...
                "LINE_OFF", str2double(payload(16:21)), ...
                "SAMP_OFF", str2double(payload(22:26)), ...
                "LAT_OFF", str2double(payload(27:34)), ...
                "LONG_OFF", str2double(payload(35:43)), ...
                "HEIGHT_OFF", str2double(payload(44:48)), ...
                "LINE_SCALE", str2double(payload(49:54)), ...
                "SAMP_SCALE", str2double(payload(55:59)), ...
                "LAT_SCALE", str2double(payload(60:67)), ...
                "LONG_SCALE", str2double(payload(68:76)), ...
                "HEIGHT_SCALE", str2double(payload(77:81)));
            coef = reshape(payload(82:end), 12, 80).';
            coef = str2double(string(coef));
            m.LINE_NUM_COEF = coef(1:20).';
            m.LINE_DEN_COEF = coef(21:40).';
            m.SAMP_NUM_COEF = coef(41:60).';
            m.SAMP_DEN_COEF = coef(61:80).';
            metadata = Rpc00bCamera.normalizeMetadata(m);
        end
    end

    methods (Access = private)
        function [line, sample, lineLon, lineLat, sampleLon, sampleLat, ...
                valid] = evaluateNormalized(obj, lon, lat, hae)
            [b, bLon, bLat] = Rpc00bCamera.basis(lon, lat, hae);
            [line, lineLon, lineLat, lineValid] = ...
                Rpc00bCamera.ratio(b, bLon, bLat, ...
                obj.LineNumerator, obj.LineDenominator);
            [sample, sampleLon, sampleLat, sampleValid] = ...
                Rpc00bCamera.ratio(b, bLon, bLat, ...
                obj.SampleNumerator, obj.SampleDenominator);
            valid = lineValid & sampleValid;
        end
    end

    methods (Static, Access = private)
        function [b, bLon, bLat] = basis(lon, lat, hae)
            % RPC00B order: 1,L,P,H,LP,LH,PH,L2,P2,H2,PLH,L3,
            % LP2,LH2,L2P,P3,PH2,L2H,P2H,H3 (STDI-0002 Sec. 8.2.4).
            b = [ones(size(lon)), lon, lat, hae, lon .* lat, ...
                lon .* hae, lat .* hae, lon .^ 2, lat .^ 2, hae .^ 2, ...
                lat .* lon .* hae, lon .^ 3, lon .* lat .^ 2, ...
                lon .* hae .^ 2, lon .^ 2 .* lat, lat .^ 3, ...
                lat .* hae .^ 2, lon .^ 2 .* hae, ...
                lat .^ 2 .* hae, hae .^ 3];
            bLon = [zeros(size(lon)), ones(size(lon)), ...
                zeros(size(lon)), zeros(size(lon)), lat, hae, ...
                zeros(size(lon)), 2 .* lon, zeros(size(lon)), ...
                zeros(size(lon)), lat .* hae, 3 .* lon .^ 2, ...
                lat .^ 2, hae .^ 2, 2 .* lon .* lat, ...
                zeros(size(lon)), zeros(size(lon)), ...
                2 .* lon .* hae, zeros(size(lon)), zeros(size(lon))];
            bLat = [zeros(size(lat)), zeros(size(lat)), ones(size(lat)), ...
                zeros(size(lat)), lon, zeros(size(lat)), hae, ...
                zeros(size(lat)), 2 .* lat, zeros(size(lat)), ...
                lon .* hae, zeros(size(lat)), 2 .* lon .* lat, ...
                zeros(size(lat)), lon .^ 2, 3 .* lat .^ 2, ...
                hae .^ 2, zeros(size(lat)), 2 .* lat .* hae, ...
                zeros(size(lat))];
        end

        function [value, dLon, dLat, valid] = ...
                ratio(b, bLon, bLat, numerator, denominator)
            num = b * numerator.';
            den = b * denominator.';
            valid = all(isfinite(b), 2) & isfinite(num) & isfinite(den) ...
                & abs(den) > Rpc00bCamera.DenominatorTolerance;
            value = num ./ den;
            dLon = ((bLon * numerator.') .* den ...
                - num .* (bLon * denominator.')) ./ (den .^ 2);
            dLat = ((bLat * numerator.') .* den ...
                - num .* (bLat * denominator.')) ./ (den .^ 2);
            value(~valid) = NaN;
            dLon(~valid) = NaN;
            dLat(~valid) = NaN;
        end

        function metadata = normalizeMetadata(metadata)
            names = ["SUCCESS", "ERR_BIAS", "ERR_RAND", "LINE_OFF", ...
                "SAMP_OFF", "LAT_OFF", "LONG_OFF", "HEIGHT_OFF", ...
                "LINE_SCALE", "SAMP_SCALE", "LAT_SCALE", ...
                "LONG_SCALE", "HEIGHT_SCALE", "LINE_NUM_COEF", ...
                "LINE_DEN_COEF", "SAMP_NUM_COEF", "SAMP_DEN_COEF"];
            for k = 1:numel(names)
                name = names(k);
                if ~isfield(metadata, name)
                    error("Rpc00bCamera:MissingField", ...
                        "RPC00B metadata is missing field %s.", name);
                end
            end

            scalarNames = names(1:13);
            for k = 1:numel(scalarNames)
                name = scalarNames(k);
                value = Rpc00bCamera.numericScalar(metadata.(name), name);
                metadata.(name) = value;
            end
            if ~ismember(metadata.SUCCESS, [0, 1])
                error("Rpc00bCamera:InvalidField", ...
                    "RPC00B SUCCESS must be zero or one.");
            end
            metadata.SUCCESS = logical(metadata.SUCCESS);

            coefNames = names(14:17);
            for k = 1:numel(coefNames)
                name = coefNames(k);
                value = double(metadata.(name));
                if numel(value) ~= 20 || ~isreal(value) ...
                        || any(~isfinite(value), "all")
                    error("Rpc00bCamera:InvalidCoefficientVector", ...
                        "%s must contain 20 finite real coefficients.", name);
                end
                metadata.(name) = reshape(value, 1, 20);
            end

            scales = [metadata.LINE_SCALE, metadata.SAMP_SCALE, ...
                metadata.LAT_SCALE, metadata.LONG_SCALE, ...
                metadata.HEIGHT_SCALE];
            if any(scales <= 0)
                error("Rpc00bCamera:InvalidScale", ...
                    "All RPC00B normalization scales must be positive.");
            end
            if abs(metadata.LAT_OFF) > 90 ...
                    || abs(metadata.LONG_OFF) > 180 ...
                    || metadata.LAT_SCALE > 90 ...
                    || metadata.LONG_SCALE > 180
                error("Rpc00bCamera:InvalidGeodeticNormalization", ...
                    "RPC00B latitude/longitude offsets or scales are invalid.");
            end
        end

        function value = numericScalar(value, name)
            if ischar(value) || isstring(value)
                value = str2double(string(value));
            end
            if ~(isnumeric(value) || islogical(value)) ...
                    || ~isscalar(value) || ~isreal(value) || ~isfinite(value)
                error("Rpc00bCamera:InvalidField", ...
                    "RPC00B field %s must be one finite real scalar.", name);
            end
            value = double(value);
        end

        function z = expandHeight(z, n)
            if isscalar(z)
                z = repmat(z, n, 1);
            end
        end
    end
end

function mustBeRpc00bInput(value)
valid = (isstruct(value) && isscalar(value)) ...
    || (isstring(value) && isscalar(value)) ...
    || (ischar(value) && isrow(value));
if ~valid
    error("Rpc00bCamera:InvalidInput", ...
        "RPC00B metadata must be a scalar structure, path, or ASCII payload.");
end
end

function mustHaveOneOrNRows(z, p)
if ~(isscalar(z) || size(z, 1) == size(p, 1))
    error("Rpc00bCamera:HeightSizeMismatch", ...
        "Height must be scalar or have one row per pixel.");
end
end
