classdef ProjectionBackendRadiometry
    %ProjectionBackendRadiometry Deterministic backend output encoding.

    methods (Static)
        function encoded = prepare(imageData, output)
            %prepare Map physical renderer values to the configured stored class.
            values = double(imageData);
            values(~isfinite(values)) = output.FillValue;
            normalized = (values - output.RadiometricOffset) ./ ...
                output.RadiometricScale;
            if output.OutOfRangePolicy == "error" && ...
                    any(normalized < 0 | normalized > 1, "all")
                error("ProjectionBackendRadiometry:outOfRange", ...
                    "Rendered values fall outside the configured radiometric range [%g,%g].", ...
                    output.RadiometricOffset, output.RadiometricOffset + ...
                    output.RadiometricScale);
            end
            normalized = min(max(normalized, 0), 1);
            switch output.OutputClass
                case "uint8"
                    encoded = uint8(round(normalized * double(intmax("uint8"))));
                case "uint16"
                    encoded = uint16(round(normalized * double(intmax("uint16"))));
                case "single"
                    encoded = single(normalized);
                otherwise
                    error("ProjectionBackendRadiometry:unsupportedClass", ...
                        "Unsupported output class %s.", output.OutputClass);
            end
        end

        function metadata = metadata(output)
            %metadata Return the reversible stored-to-physical value contract.
            metadata = struct();
            metadata.OutputClass = output.OutputClass;
            metadata.Scale = output.RadiometricScale;
            metadata.Offset = output.RadiometricOffset;
            metadata.FillValue = output.FillValue;
            metadata.OutOfRangePolicy = output.OutOfRangePolicy;
            metadata.StoredValueContract = ...
                "physical = storedNormalized * Scale + Offset";
            if output.OutputClass == "uint8"
                metadata.StoredNormalizationDivisor = ...
                    double(intmax("uint8"));
            elseif output.OutputClass == "uint16"
                metadata.StoredNormalizationDivisor = ...
                    double(intmax("uint16"));
            else
                metadata.StoredNormalizationDivisor = 1;
            end
        end
    end
end
