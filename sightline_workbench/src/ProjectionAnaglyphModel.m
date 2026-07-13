classdef ProjectionAnaglyphModel
    %ProjectionAnaglyphModel Pure production anaglyph presentation algebra.

    methods (Static)
        function offset = presentationOffset(cameraRightVector, ...
                channelIndex, viewWidthMeters, stereoExaggeration, ...
                screenDepthOffsetMeters, baseSeparationFraction)
            %presentationOffset Return one display-only world translation.
            cameraRightVector = double(cameraRightVector(:));
            if numel(cameraRightVector) ~= 3 || ...
                    any(~isfinite(cameraRightVector)) || ...
                    norm(cameraRightVector) <= eps
                error("ProjectionAnaglyphModel:invalidCameraRight", ...
                    "Camera right must be a finite nonzero three-vector.");
            end
            if ~isnumeric(channelIndex) || ~isscalar(channelIndex) || ...
                    ~ismember(channelIndex, [1 3])
                error("ProjectionAnaglyphModel:invalidChannel", ...
                    "Anaglyph eye channel must be 1 (red) or 3 (cyan/blue).");
            end
            ProjectionAnaglyphModel.positiveScalar( ...
                viewWidthMeters, "ViewWidthMeters");
            ProjectionAnaglyphModel.nonnegativeScalar( ...
                stereoExaggeration, "StereoExaggeration");
            ProjectionAnaglyphModel.finiteScalar( ...
                screenDepthOffsetMeters, "ScreenDepthOffsetMeters");
            ProjectionAnaglyphModel.nonnegativeScalar( ...
                baseSeparationFraction, "BaseSeparationFraction");

            cameraRightVector = cameraRightVector / ...
                norm(cameraRightVector);
            eyeSign = -1 + 2 * double(channelIndex == 3);
            separationShift = (double(stereoExaggeration) - 1) * ...
                double(baseSeparationFraction) * double(viewWidthMeters);
            parallaxShift = eyeSign * (separationShift + ...
                double(screenDepthOffsetMeters));
            offset = parallaxShift * cameraRightVector;
        end

        function texture = channelTexture( ...
                imageData, channelIndex, channelGain, offChannelFloor)
            %channelTexture Form one viewer-compatible colored eye texture.
            gray = ProjectionAnaglyphModel.unitGrayscale(imageData);
            if ~isnumeric(channelIndex) || ~isscalar(channelIndex) || ...
                    ~ismember(channelIndex, [1 3])
                error("ProjectionAnaglyphModel:invalidChannel", ...
                    "Anaglyph eye channel must be 1 or 3.");
            end
            ProjectionAnaglyphModel.nonnegativeScalar( ...
                channelGain, "ChannelGain");
            ProjectionAnaglyphModel.nonnegativeScalar( ...
                offChannelFloor, "OffChannelFloor");
            if offChannelFloor > 1
                error("ProjectionAnaglyphModel:invalidFloor", ...
                    "OffChannelFloor cannot exceed one.");
            end
            texture = single(offChannelFloor) * ...
                ones([size(gray, 1), size(gray, 2), 3], "single");
            texture(:, :, channelIndex) = min(1, ...
                single(offChannelFloor) + single(channelGain) * ...
                single(gray));
        end

        function [anaglyph, validMask] = composeRedCyan( ...
                leftImage, rightImage, leftMask, rightMask, invalidFillValue)
            %composeRedCyan Compose canonical red/cyan double output.
            if nargin < 5
                invalidFillValue = 0;
            end
            left = ProjectionAnaglyphModel.unitGrayscale(leftImage);
            right = ProjectionAnaglyphModel.unitGrayscale(rightImage);
            if ~isequal(size(left), size(right)) || ...
                    ~isequal(size(leftMask), size(left)) || ...
                    ~isequal(size(rightMask), size(right)) || ...
                    ~(islogical(leftMask) || isnumeric(leftMask)) || ...
                    ~(islogical(rightMask) || isnumeric(rightMask))
                error("ProjectionAnaglyphModel:invalidComposition", ...
                    "Eye images and masks must have equal two-dimensional sizes.");
            end
            ProjectionAnaglyphModel.finiteScalar( ...
                invalidFillValue, "InvalidFillValue");
            validMask = logical(leftMask) & logical(rightMask);
            anaglyph = cat(3, left, right, right);
            for channel = 1:3
                band = anaglyph(:, :, channel);
                band(~validMask) = double(invalidFillValue);
                anaglyph(:, :, channel) = band;
            end
        end

        function gray = unitGrayscale(imageData)
            %unitGrayscale Convert numeric/logical radiometry to double [0,1].
            if ~(isnumeric(imageData) || islogical(imageData)) || ...
                    isempty(imageData) || ndims(imageData) > 3 || ...
                    any(~isfinite(double(imageData)), "all")
                error("ProjectionAnaglyphModel:invalidImage", ...
                    "Image data must be a finite nonempty 2-D or 3-D array.");
            end
            integerInput = isinteger(imageData);
            logicalInput = islogical(imageData);
            if ismatrix(imageData)
                gray = double(imageData);
            elseif integerInput
                gray = round(mean(double(imageData), 3));
            elseif logicalInput
                gray = any(imageData, 3);
            else
                gray = mean(imageData, 3);
            end
            if integerInput
                gray = double(gray) / double(intmax(class(imageData)));
            elseif logicalInput
                gray = double(gray);
            else
                gray = min(max(double(gray), 0), 1);
            end
        end
    end

    methods (Static, Access = private)
        function finiteScalar(value, name)
            if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value)
                error("ProjectionAnaglyphModel:invalidScalar", ...
                    "%s must be a finite scalar.", name);
            end
        end

        function positiveScalar(value, name)
            ProjectionAnaglyphModel.finiteScalar(value, name);
            if value <= 0
                error("ProjectionAnaglyphModel:invalidScalar", ...
                    "%s must be positive.", name);
            end
        end

        function nonnegativeScalar(value, name)
            ProjectionAnaglyphModel.finiteScalar(value, name);
            if value < 0
                error("ProjectionAnaglyphModel:invalidScalar", ...
                    "%s must be nonnegative.", name);
            end
        end
    end
end
