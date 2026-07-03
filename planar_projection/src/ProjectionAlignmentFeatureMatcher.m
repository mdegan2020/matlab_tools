classdef ProjectionAlignmentFeatureMatcher
    %ProjectionAlignmentFeatureMatcher Detect and match working-image features.

    properties (Constant)
        Format = "ProjectionAlignmentFeatureMatches"
        Version = 1
    end

    methods (Static)
        function info = capabilities()
            %capabilities Return available detector/matcher feature methods.
            detectors = ["sift", "surf", "orb", "brisk", "kaze"];
            functions = ["detectSIFTFeatures", "detectSURFFeatures", ...
                "detectORBFeatures", "detectBRISKFeatures", "detectKAZEFeatures"];
            available = false(size(detectors));
            for k = 1:numel(detectors)
                available(k) = exist(functions(k), "file") == 2;
            end

            info = struct();
            info.Detectors = detectors;
            info.DetectorFunctions = functions;
            info.AvailableDetectors = detectors(available);
            info.UnavailableDetectors = detectors(~available);
            info.HasExtractFeatures = exist("extractFeatures", "file") == 2;
            info.HasMatchFeatures = exist("matchFeatures", "file") == 2;
            info.HasShowMatchedFeatures = exist("showMatchedFeatures", "file") == 2;
            info.DefaultDetector = ProjectionAlignmentFeatureMatcher.defaultDetector(info);
        end

        function matchResult = match(workingImages, options)
            %match Detect and match features for all working-image pairs.
            if nargin < 2
                options = struct();
            end
            ProjectionAlignmentFeatureMatcher.validateWorkingImages(workingImages);
            options = ProjectionAlignmentOptions.validate(options);
            capabilities = ProjectionAlignmentFeatureMatcher.capabilities();
            detector = ProjectionAlignmentFeatureMatcher.resolveDetector( ...
                options.Detector.Method, capabilities);
            features = ProjectionAlignmentFeatureMatcher.detectLayerFeatures( ...
                workingImages, detector, options.Detector);
            matches = ProjectionAlignmentFeatureMatcher.matchPairs( ...
                workingImages, features, options.Matcher, detector);

            matchResult = struct();
            matchResult.Format = ProjectionAlignmentFeatureMatcher.Format;
            matchResult.Version = ProjectionAlignmentFeatureMatcher.Version;
            matchResult.Detector = detector;
            matchResult.Matcher = options.Matcher;
            matchResult.Features = features;
            matchResult.Matches = matches;
            matchResult.Capabilities = capabilities;
            matchResult.Diagnostics = ProjectionAlignmentFeatureMatcher.diagnostics( ...
                features, matches);
        end

        function fig = showMatchedPair(workingImages, matchResult, pairIndex, options)
            %showMatchedPair Show a diagnostic matched-feature figure.
            if nargin < 4
                options = struct();
            end
            options = ProjectionAlignmentFeatureMatcher.mergeDisplayOptions(options);
            if ~matchResult.Capabilities.HasShowMatchedFeatures
                error("ProjectionAlignmentFeatureMatcher:unavailableDiagnosticView", ...
                    "showMatchedFeatures is unavailable in this MATLAB installation.");
            end
            if pairIndex < 1 || pairIndex > numel(matchResult.Matches)
                error("ProjectionAlignmentFeatureMatcher:invalidPairIndex", ...
                    "pairIndex must select an existing match pair.");
            end

            pairMatch = matchResult.Matches(pairIndex);
            movingLayer = ProjectionAlignmentFeatureMatcher.layerImageByIndex( ...
                workingImages, pairMatch.Pair(1));
            referenceLayer = ProjectionAlignmentFeatureMatcher.layerImageByIndex( ...
                workingImages, pairMatch.Pair(2));
            fig = figure(Name="Projection Alignment Matched Features", ...
                Visible=options.Visible);
            ax = axes(fig);
            showMatchedFeatures(movingLayer.Image, referenceLayer.Image, ...
                pairMatch.MovingFeatureLocations, ...
                pairMatch.ReferenceFeatureLocations, ...
                Parent=ax, PlotOptions={"ro", "go", "y-"});
            title(ax, sprintf("Layer %d to layer %d: %d matches", ...
                pairMatch.Pair(1), pairMatch.Pair(2), pairMatch.Count));
        end
    end

    methods (Static, Access = private)
        function detector = resolveDetector(requestedMethod, capabilities)
            method = lower(string(requestedMethod));
            if method == "auto"
                method = capabilities.DefaultDetector;
            end
            if strlength(method) == 0 || ~ismember(method, capabilities.AvailableDetectors)
                error("ProjectionAlignmentFeatureMatcher:unavailableDetector", ...
                    "Requested detector %s is unavailable.", requestedMethod);
            end

            detector = struct();
            detector.Method = method;
            detector.Function = ProjectionAlignmentFeatureMatcher.detectorFunction(method);
        end

        function detector = defaultDetector(capabilities)
            preferences = ["sift", "surf", "orb", "brisk", "kaze"];
            detector = "";
            for k = 1:numel(preferences)
                if ismember(preferences(k), capabilities.AvailableDetectors)
                    detector = preferences(k);
                    return
                end
            end
        end

        function functionName = detectorFunction(method)
            switch method
                case "sift"
                    functionName = "detectSIFTFeatures";
                case "surf"
                    functionName = "detectSURFFeatures";
                case "orb"
                    functionName = "detectORBFeatures";
                case "brisk"
                    functionName = "detectBRISKFeatures";
                case "kaze"
                    functionName = "detectKAZEFeatures";
                otherwise
                    error("ProjectionAlignmentFeatureMatcher:unavailableDetector", ...
                        "Unsupported detector %s.", method);
            end
        end

        function features = detectLayerFeatures(workingImages, detector, detectorOptions)
            for k = 1:numel(workingImages.LayerImages)
                layerImage = workingImages.LayerImages(k);
                imageData = ProjectionAlignmentFeatureMatcher.prepareFeatureImage( ...
                    layerImage.Image, layerImage.ValidMask);
                points = ProjectionAlignmentFeatureMatcher.detectPoints( ...
                    imageData, detector.Method);
                points = ProjectionAlignmentFeatureMatcher.selectStrongest( ...
                    points, detectorOptions.MaxFeatures);
                [descriptors, validPoints] = ...
                    ProjectionAlignmentFeatureMatcher.extractDescriptors( ...
                    imageData, points);
                feature = struct();
                feature.LayerIndex = layerImage.LayerIndex;
                feature.Detector = detector.Method;
                feature.Count = ProjectionAlignmentFeatureMatcher.pointCount(validPoints);
                feature.Points = validPoints;
                feature.Locations = ProjectionAlignmentFeatureMatcher.pointLocations( ...
                    validPoints);
                feature.Metrics = ProjectionAlignmentFeatureMatcher.pointMetrics( ...
                    validPoints);
                feature.Descriptors = descriptors;
                feature.DescriptorClass = string(class(descriptors));
                feature.DescriptorSize = size(descriptors);
                if k == 1
                    features = feature;
                else
                    features(k) = feature;
                end
            end
        end

        function points = detectPoints(imageData, method)
            switch method
                case "sift"
                    points = detectSIFTFeatures(imageData);
                case "surf"
                    points = detectSURFFeatures(imageData);
                case "orb"
                    points = detectORBFeatures(imageData);
                case "brisk"
                    points = detectBRISKFeatures(imageData);
                case "kaze"
                    points = detectKAZEFeatures(imageData);
            end
        end

        function imageData = prepareFeatureImage(imageData, validMask)
            if ~ismatrix(imageData)
                imageData = mean(imageData, 3);
            end
            imageData = gather(imageData);
            if isfloat(imageData)
                imageData = single(imageData);
                finiteValues = imageData(isfinite(imageData));
                if isempty(finiteValues)
                    imageData = zeros(size(imageData), "single");
                elseif min(finiteValues) < 0 || max(finiteValues) > 1
                    imageData = single(mat2gray(imageData));
                end
            end
            imageData(~validMask | ~isfinite(imageData)) = 0;
        end

        function points = selectStrongest(points, maxFeatures)
            count = ProjectionAlignmentFeatureMatcher.pointCount(points);
            if count > maxFeatures
                points = points.selectStrongest(maxFeatures);
            end
        end

        function [descriptors, validPoints] = extractDescriptors(imageData, points)
            if ProjectionAlignmentFeatureMatcher.pointCount(points) == 0
                descriptors = zeros(0, 0, "single");
                validPoints = points;
                return
            end
            [descriptors, validPoints] = extractFeatures(imageData, points);
        end

        function matches = matchPairs(workingImages, features, matcher, detector)
            pairMasks = workingImages.PairOverlapMasks;
            matches = struct("Pair", {}, "Detector", {}, "Matcher", {}, ...
                "MovingFeatureLocations", {}, "ReferenceFeatureLocations", {}, ...
                "MovingPlaneCoordinates", {}, "ReferencePlaneCoordinates", {}, ...
                "MovingSourceRows", {}, "MovingSourceColumns", {}, ...
                "ReferenceSourceRows", {}, "ReferenceSourceColumns", {}, ...
                "IndexPairs", {}, "MatchMetric", {}, "Scores", {}, ...
                "FeatureCounts", {}, "Count", {}, "OverlapMask", {});
            for k = 1:numel(pairMasks)
                pair = pairMasks(k).Pair;
                movingFeatures = ProjectionAlignmentFeatureMatcher.featuresByLayer( ...
                    features, pair(1));
                referenceFeatures = ProjectionAlignmentFeatureMatcher.featuresByLayer( ...
                    features, pair(2));
                pairMatch = ProjectionAlignmentFeatureMatcher.matchFeaturePair( ...
                    workingImages, movingFeatures, referenceFeatures, matcher, ...
                    detector, pairMasks(k));
                if k == 1
                    matches = pairMatch;
                else
                    matches(k) = pairMatch;
                end
            end
        end

        function pairMatch = matchFeaturePair(workingImages, movingFeatures, ...
                referenceFeatures, matcher, detector, pairMask)
            [indexPairs, matchMetric] = ProjectionAlignmentFeatureMatcher.matchDescriptors( ...
                movingFeatures.Descriptors, referenceFeatures.Descriptors, matcher);
            movingLocations = movingFeatures.Locations(indexPairs(:, 1), :);
            referenceLocations = referenceFeatures.Locations(indexPairs(:, 2), :);
            movingLayer = ProjectionAlignmentFeatureMatcher.layerImageByIndex( ...
                workingImages, movingFeatures.LayerIndex);
            referenceLayer = ProjectionAlignmentFeatureMatcher.layerImageByIndex( ...
                workingImages, referenceFeatures.LayerIndex);

            pairMatch = struct();
            pairMatch.Pair = pairMask.Pair;
            pairMatch.Detector = detector.Method;
            pairMatch.Matcher = matcher.Method;
            pairMatch.MovingFeatureLocations = movingLocations;
            pairMatch.ReferenceFeatureLocations = referenceLocations;
            pairMatch.MovingPlaneCoordinates = ...
                ProjectionAlignmentFeatureMatcher.samplePlaneCoordinates( ...
                workingImages, movingLocations);
            pairMatch.ReferencePlaneCoordinates = ...
                ProjectionAlignmentFeatureMatcher.samplePlaneCoordinates( ...
                workingImages, referenceLocations);
            [pairMatch.MovingSourceRows, pairMatch.MovingSourceColumns] = ...
                ProjectionAlignmentFeatureMatcher.sampleSourceObservations( ...
                movingLayer, movingLocations);
            [pairMatch.ReferenceSourceRows, pairMatch.ReferenceSourceColumns] = ...
                ProjectionAlignmentFeatureMatcher.sampleSourceObservations( ...
                referenceLayer, referenceLocations);
            pairMatch.IndexPairs = indexPairs;
            pairMatch.MatchMetric = matchMetric(:);
            pairMatch.Scores = 1 ./ (1 + double(matchMetric(:)));
            pairMatch.FeatureCounts = [movingFeatures.Count referenceFeatures.Count];
            pairMatch.Count = size(indexPairs, 1);
            pairMatch.OverlapMask = pairMask.Mask;
        end

        function [indexPairs, matchMetric] = matchDescriptors( ...
                movingDescriptors, referenceDescriptors, matcher)
            if isempty(movingDescriptors) || isempty(referenceDescriptors)
                indexPairs = zeros(0, 2);
                matchMetric = zeros(0, 1);
                return
            end
            args = {"Unique", matcher.Unique, "MaxRatio", matcher.MaxRatio};
            if matcher.Method == "exhaustive"
                args = [args, {"Method", "Exhaustive"}];
            elseif matcher.Method == "approximate"
                args = [args, {"Method", "Approximate"}];
            end
            if ~isempty(matcher.MatchThreshold)
                args = [args, {"MatchThreshold", matcher.MatchThreshold}];
            end
            [indexPairs, matchMetric] = matchFeatures( ...
                movingDescriptors, referenceDescriptors, args{:});
        end

        function coordinates = samplePlaneCoordinates(workingImages, locations)
            if isempty(locations)
                coordinates = zeros(0, 2);
                return
            end
            x = ProjectionAlignmentFeatureMatcher.sampleMap( ...
                workingImages.PixelToPlane.X, locations);
            y = ProjectionAlignmentFeatureMatcher.sampleMap( ...
                workingImages.PixelToPlane.Y, locations);
            coordinates = [x(:), y(:)];
        end

        function [rows, columns] = sampleSourceObservations(layerImage, locations)
            if isempty(locations)
                rows = zeros(0, 1);
                columns = zeros(0, 1);
                return
            end
            rows = ProjectionAlignmentFeatureMatcher.sampleMap( ...
                layerImage.SourceRows, locations);
            columns = ProjectionAlignmentFeatureMatcher.sampleMap( ...
                layerImage.SourceColumns, locations);
            rows = rows(:);
            columns = columns(:);
        end

        function values = sampleMap(map, locations)
            values = interp2(map, locations(:, 1), locations(:, 2), "linear", NaN);
        end

        function count = pointCount(points)
            if isempty(points)
                count = 0;
                return
            end
            if isprop(points, "Count")
                count = double(points.Count);
            else
                count = size(points.Location, 1);
            end
        end

        function locations = pointLocations(points)
            if ProjectionAlignmentFeatureMatcher.pointCount(points) == 0
                locations = zeros(0, 2);
            else
                locations = double(points.Location);
            end
        end

        function metrics = pointMetrics(points)
            if ProjectionAlignmentFeatureMatcher.pointCount(points) == 0 || ...
                    ~isprop(points, "Metric")
                metrics = zeros(0, 1);
            else
                metrics = double(points.Metric(:));
            end
        end

        function feature = featuresByLayer(features, layerIndex)
            matches = [features.LayerIndex] == layerIndex;
            if ~any(matches)
                error("ProjectionAlignmentFeatureMatcher:missingFeatures", ...
                    "Missing feature records for layer %d.", layerIndex);
            end
            feature = features(find(matches, 1, "first"));
        end

        function layerImage = layerImageByIndex(workingImages, layerIndex)
            matches = [workingImages.LayerImages.LayerIndex] == layerIndex;
            if ~any(matches)
                error("ProjectionAlignmentFeatureMatcher:missingLayerImage", ...
                    "Missing working image for layer %d.", layerIndex);
            end
            layerImage = workingImages.LayerImages(find(matches, 1, "first"));
        end

        function diagnostics = diagnostics(features, matches)
            diagnostics = struct();
            diagnostics.FeatureCounts = [features.Count];
            diagnostics.MatchCounts = [matches.Count];
            diagnostics.TotalMatches = sum(diagnostics.MatchCounts);
        end

        function validateWorkingImages(workingImages)
            requiredFields = ["LayerImages", "PairOverlapMasks", "PixelToPlane"];
            if ~isstruct(workingImages) || ~isscalar(workingImages) || ...
                    any(~isfield(workingImages, requiredFields))
                error("ProjectionAlignmentFeatureMatcher:invalidWorkingImages", ...
                    "Working images must come from ProjectionAlignmentWorkingImageRenderer.");
            end
        end

        function options = mergeDisplayOptions(options)
            if isempty(options)
                options = struct();
            end
            if ~isstruct(options) || ~isscalar(options)
                error("ProjectionAlignmentFeatureMatcher:invalidOptions", ...
                    "Display options must be a scalar struct.");
            end
            defaults = struct(Visible="on");
            names = fieldnames(options);
            for k = 1:numel(names)
                defaults.(names{k}) = options.(names{k});
            end
            defaults.Visible = lower(string(defaults.Visible));
            if ~isscalar(defaults.Visible) || ~ismember(defaults.Visible, ["on", "off"])
                error("ProjectionAlignmentFeatureMatcher:invalidOptions", ...
                    "Visible must be on or off.");
            end
            options = defaults;
        end
    end
end
