classdef ProjectionAlignmentFeatureMatcher
    %ProjectionAlignmentFeatureMatcher Detect and match working-image features.

    properties (Constant)
        Format = "ProjectionAlignmentFeatureMatches"
        Version = 3
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
            matcher = ProjectionAlignmentFeatureMatcher.resolveMatcher( ...
                options.Matcher);
            features = ProjectionAlignmentFeatureMatcher.detectLayerFeatures( ...
                workingImages, detector, options.Detector);
            matches = ProjectionAlignmentFeatureMatcher.matchPairs( ...
                workingImages, features, matcher, detector);

            matchResult = struct();
            matchResult.Format = ProjectionAlignmentFeatureMatcher.Format;
            matchResult.Version = ProjectionAlignmentFeatureMatcher.Version;
            matchResult.Detector = detector;
            matchResult.Matcher = matcher;
            matchResult.Features = features;
            matchResult.Matches = matches;
            matchResult.MatchLedger = ...
                ProjectionAlignmentMatchLedger.combine(matchResult);
            if isfield(workingImages, "Schedule")
                matchResult.Schedule = workingImages.Schedule;
            end
            matchResult.Capabilities = capabilities;
            matchResult.Diagnostics = ProjectionAlignmentFeatureMatcher.diagnostics( ...
                features, matches, detector, matcher);
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
            pairWorking = ProjectionAlignmentFeatureMatcher.pairWorkingImage( ...
                workingImages, pairIndex);
            movingLayer = ProjectionAlignmentFeatureMatcher.layerImageByIndex( ...
                pairWorking, pairMatch.Pair(1));
            referenceLayer = ProjectionAlignmentFeatureMatcher.layerImageByIndex( ...
                pairWorking, pairMatch.Pair(2));
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
            requestedMethod = lower(string(requestedMethod));
            method = requestedMethod;
            if method == "auto"
                method = capabilities.DefaultDetector;
            end
            if strlength(method) == 0 || ~ismember(method, capabilities.AvailableDetectors)
                error("ProjectionAlignmentFeatureMatcher:unavailableDetector", ...
                    "Requested detector %s is unavailable.", requestedMethod);
            end

            detector = struct();
            detector.RequestedMethod = requestedMethod;
            detector.Method = method;
            detector.Function = ProjectionAlignmentFeatureMatcher.detectorFunction(method);
            detector.AutoSelected = requestedMethod == "auto";
            detector.FallbackUsed = false;
            detector.FallbackReason = "";
        end

        function matcher = resolveMatcher(options)
            matcher = options;
            matcher.RequestedMethod = options.Method;
            matcher.SearchMethod = "Exhaustive";
            matcher.Deterministic = true;
            matcher.RatioTestEnabled = true;
        end

        function detector = defaultDetector(capabilities)
            preferences = ["kaze", "sift", "surf", "orb", "brisk"];
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
            if ProjectionAlignmentFeatureMatcher.hasPairWorkingImages(workingImages)
                features = ProjectionAlignmentFeatureMatcher.detectPairFeatures( ...
                    workingImages, detector, detectorOptions);
                return
            end
            for k = 1:numel(workingImages.LayerImages)
                layerImage = workingImages.LayerImages(k);
                feature = ProjectionAlignmentFeatureMatcher.detectLayerImage( ...
                    layerImage, detector, detectorOptions, []);
                feature.PairIndex = 0;
                feature.PairLayerIds = strings(1, 0);
                feature.Role = "layer";
                if k == 1
                    features = feature;
                else
                    features(k) = feature;
                end
            end
        end

        function features = detectPairFeatures(workingImages, detector, detectorOptions)
            pairWorkingImages = workingImages.PairWorkingImages;
            featureCount = 2 * numel(pairWorkingImages);
            features = repmat( ...
                ProjectionAlignmentFeatureMatcher.emptyFeature(), ...
                1, featureCount);
            cursor = 0;
            for pairIndex = 1:numel(pairWorkingImages)
                pairWorking = pairWorkingImages(pairIndex);
                for pairPosition = 1:2
                    cursor = cursor + 1;
                    layerIndex = pairWorking.Pair(pairPosition);
                    layerImage = ProjectionAlignmentFeatureMatcher.layerImageByIndex( ...
                        pairWorking, layerIndex);
                    overlapMask = pairWorking.OverlapMask.Mask;
                    feature = ProjectionAlignmentFeatureMatcher.detectLayerImage( ...
                        layerImage, detector, detectorOptions, overlapMask);
                    feature.PairIndex = pairIndex;
                    feature.PairLayerIds = pairWorking.PairLayerIds;
                    if pairPosition == 1
                        feature.Role = "moving";
                    else
                        feature.Role = "reference";
                    end
                    features(cursor) = feature;
                end
            end
        end

        function feature = detectLayerImage( ...
                layerImage, detector, detectorOptions, overlapMask)
            preparationTimer = tic;
            analysisMask = layerImage.ValidMask;
            if ~isempty(overlapMask)
                analysisMask = analysisMask & logical(overlapMask);
            end
            [imageData, validMask, mapping, normalization] = ...
                ProjectionAlignmentFeatureMatcher.prepareFeatureImage( ...
                layerImage.Image, analysisMask, ...
                detectorOptions.AnalysisScale);
            preparationSeconds = toc(preparationTimer);
            detectionTimer = tic;
            [points, detectorParameters] = ...
                ProjectionAlignmentFeatureMatcher.detectPoints( ...
                imageData, detector.Method);
            detectionSeconds = toc(detectionTimer);
            detectedCount = ProjectionAlignmentFeatureMatcher.pointCount(points);
            points = ProjectionAlignmentFeatureMatcher.applyMetricThreshold( ...
                points, detectorOptions.MetricThreshold);
            metricKeptCount = ProjectionAlignmentFeatureMatcher.pointCount(points);
            supportRadius = ...
                ProjectionAlignmentFeatureMatcher.resolveSupportRadius( ...
                detector.Method, detectorOptions.MaskSupportRadiusPixels);
            points = ProjectionAlignmentFeatureMatcher.applySupportMask( ...
                points, validMask, supportRadius, mapping);
            supportKeptCount = ProjectionAlignmentFeatureMatcher.pointCount(points);
            points = ProjectionAlignmentFeatureMatcher.orderPoints(points);
            [points, spatialSelection] = ...
                ProjectionAlignmentFeatureMatcher.selectSpatially( ...
                points, detectorOptions.MaxFeatures, validMask);
            selectedCount = ProjectionAlignmentFeatureMatcher.pointCount(points);
            descriptorTimer = tic;
            [descriptors, validPoints] = ...
                ProjectionAlignmentFeatureMatcher.extractDescriptors( ...
                imageData, points);
            [validPoints, descriptors] = ...
                ProjectionAlignmentFeatureMatcher.orderPointsAndDescriptors( ...
                validPoints, descriptors);
            descriptorSeconds = toc(descriptorTimer);
            locations = ProjectionAlignmentFeatureMatcher.pointLocations( ...
                validPoints);
            locations = ProjectionAlignmentFeatureMatcher.analysisToWorkingLocations( ...
                locations, mapping);
            feature = ProjectionAlignmentFeatureMatcher.emptyFeature();
            feature.LayerIndex = layerImage.LayerIndex;
            feature.LayerId = string(layerImage.LayerId);
            feature.Detector = detector.Method;
            feature.DetectorParameters = detectorParameters;
            feature.Count = ProjectionAlignmentFeatureMatcher.pointCount(validPoints);
            feature.Points = validPoints;
            feature.Locations = locations;
            feature.Metrics = ProjectionAlignmentFeatureMatcher.pointMetrics( ...
                validPoints);
            feature.Descriptors = descriptors;
            feature.DescriptorClass = string(class(descriptors));
            feature.DescriptorSize = ...
                ProjectionAlignmentFeatureMatcher.descriptorSize(descriptors);
            feature.DetectedCount = detectedCount;
            feature.MetricKeptCount = metricKeptCount;
            feature.SupportKeptCount = supportKeptCount;
            feature.SpatialKeptCount = selectedCount;
            feature.SelectedCount = selectedCount;
            feature.MetricRejectedCount = detectedCount - metricKeptCount;
            feature.MaskRejectedCount = metricKeptCount - supportKeptCount;
            feature.SpatialRejectedCount = supportKeptCount - selectedCount;
            feature.DescriptorRejectedCount = selectedCount - feature.Count;
            feature.MetricThreshold = detectorOptions.MetricThreshold;
            feature.AnalysisScaleRequested = detectorOptions.AnalysisScale;
            feature.AnalysisScaleActual = mapping.Scale;
            feature.PreparedImageSize = mapping.AnalysisSize;
            feature.MaskSupportRadiusPixels = supportRadius;
            feature.PointCoordinateSpace = "analysisPixels";
            feature.LocationCoordinateSpace = "workingPixels";
            feature.Normalization = normalization;
            feature.SpatialSelection = spatialSelection;
            feature.TimingSeconds = struct(Preparation=preparationSeconds, ...
                Detection=detectionSeconds, DescriptorExtraction=descriptorSeconds);
        end

        function feature = emptyFeature()
            feature = struct(LayerIndex=0, LayerId="", PairIndex=0, ...
                PairLayerIds=strings(1, 0), Role="", Detector="", ...
                DetectorParameters=struct(), ...
                Count=0, Points=[], Locations=zeros(0, 2), ...
                Metrics=zeros(0, 1), Descriptors=zeros(0, 0), ...
                DescriptorClass="", DescriptorSize=[0 0], DetectedCount=0, ...
                MetricKeptCount=0, SupportKeptCount=0, ...
                SpatialKeptCount=0, SelectedCount=0, ...
                MetricRejectedCount=0, MaskRejectedCount=0, ...
                SpatialRejectedCount=0, DescriptorRejectedCount=0, ...
                MetricThreshold=[], ...
                AnalysisScaleRequested=1, AnalysisScaleActual=[1 1], ...
                PreparedImageSize=[0 0], MaskSupportRadiusPixels=0, ...
                PointCoordinateSpace="analysisPixels", ...
                LocationCoordinateSpace="workingPixels", Normalization=struct(), ...
                SpatialSelection=struct(), ...
                TimingSeconds=struct(Preparation=0, Detection=0, ...
                DescriptorExtraction=0));
        end

        function [points, parameters] = detectPoints(imageData, method)
            parameters = struct();
            switch method
                case "sift"
                    points = detectSIFTFeatures(imageData);
                case "surf"
                    points = detectSURFFeatures(imageData);
                case "orb"
                    minimumSize = min(size(imageData, [1 2]));
                    parameters.ScaleFactor = 1.2;
                    parameters.MinimumLevelImageSize = 63;
                    if minimumSize < parameters.MinimumLevelImageSize
                        parameters.NumLevels = 0;
                        parameters.SkippedReason = "analysisImageTooSmall";
                        points = ORBPoints;
                    else
                        maximumLevels = floor(log(minimumSize / ...
                            parameters.MinimumLevelImageSize) / ...
                            log(parameters.ScaleFactor)) + 1;
                        parameters.NumLevels = min(8, max(1, maximumLevels));
                        parameters.SkippedReason = "";
                        points = detectORBFeatures(imageData, ...
                            NumLevels=parameters.NumLevels, ...
                            ScaleFactor=parameters.ScaleFactor);
                    end
                case "brisk"
                    points = detectBRISKFeatures(imageData);
                case "kaze"
                    points = detectKAZEFeatures(imageData);
            end
        end

        function [imageData, validMask, mapping, normalization] = ...
                prepareFeatureImage(imageData, validMask, analysisScale)
            if ~ismatrix(imageData)
                imageData = mean(single(imageData), 3);
            end
            imageData = single(gather(imageData));
            validMask = logical(gather(validMask));
            if ~isequal(size(validMask), size(imageData))
                error("ProjectionAlignmentFeatureMatcher:invalidWorkingImages", ...
                    "Each layer valid mask must match its analysis image.");
            end
            finiteMask = validMask & isfinite(imageData);
            finiteValues = imageData(finiteMask);
            if isempty(finiteValues)
                lowerLimit = NaN;
                upperLimit = NaN;
                imageData = zeros(size(imageData), "single");
                validMask(:) = false;
            else
                lowerLimit = double(min(finiteValues));
                upperLimit = double(max(finiteValues));
                imageData(~finiteMask) = 0;
                if upperLimit > lowerLimit
                    imageData = (imageData - single(lowerLimit)) / ...
                        single(upperLimit - lowerLimit);
                else
                    imageData(:) = 0;
                end
                imageData(~finiteMask) = 0;
                validMask = finiteMask;
            end

            workingSize = size(imageData, [1 2]);
            analysisSize = max(2, round(workingSize * analysisScale));
            if ~isequal(analysisSize, workingSize)
                weights = imresize(single(validMask), analysisSize, "box", ...
                    Antialiasing=true);
                weightedImage = imresize(imageData .* single(validMask), ...
                    analysisSize, "box", Antialiasing=true);
                imageData = zeros(analysisSize, "single");
                positiveMask = weights > eps("single");
                imageData(positiveMask) = weightedImage(positiveMask) ./ ...
                    weights(positiveMask);
                validMask = weights >= single(1 - 1e-5);
                imageData(~validMask) = 0;
            end
            actualScale = analysisSize ./ workingSize;
            mapping = struct(WorkingSize=workingSize, ...
                AnalysisSize=analysisSize, Scale=actualScale);
            normalization = struct(Method="validMinMax", ...
                InputMinimum=lowerLimit, InputMaximum=upperLimit, ...
                ValidFraction=nnz(validMask) / numel(validMask));
        end

        function points = applyMetricThreshold(points, threshold)
            if isempty(threshold) || ...
                    ProjectionAlignmentFeatureMatcher.pointCount(points) == 0
                return
            end
            metrics = ProjectionAlignmentFeatureMatcher.pointMetrics(points);
            points = points(metrics >= threshold);
        end

        function points = applySupportMask(points, validMask, ...
                supportRadiusPixels, mapping)
            if ProjectionAlignmentFeatureMatcher.pointCount(points) == 0
                return
            end
            locations = ProjectionAlignmentFeatureMatcher.pointLocations(points);
            if all(validMask, "all")
                maskDistance = inf(size(locations, 1), 1);
            else
                distanceImage = bwdist(~validMask);
                maskDistance = interp2(distanceImage, locations(:, 1), ...
                    locations(:, 2), "linear", 0);
            end
            imageSize = mapping.AnalysisSize;
            borderDistance = min([locations(:, 1) - 0.5, ...
                imageSize(2) + 0.5 - locations(:, 1), ...
                locations(:, 2) - 0.5, ...
                imageSize(1) + 0.5 - locations(:, 2)], [], 2);
            scaledRadius = supportRadiusPixels * mean(mapping.Scale);
            keepMask = min(maskDistance(:), borderDistance) >= scaledRadius;
            points = points(keepMask);
        end

        function radius = resolveSupportRadius(method, configuredRadius)
            if ~isempty(configuredRadius)
                radius = configuredRadius;
                return
            end
            switch method
                case "orb"
                    radius = 16;
                case {"sift", "brisk"}
                    radius = 12;
                case {"surf", "kaze"}
                    radius = 10;
            end
        end

        function points = orderPoints(points)
            order = ProjectionAlignmentFeatureMatcher.pointOrder(points);
            if ~isempty(order)
                points = points(order);
            end
        end

        function [points, diagnostics] = selectSpatially( ...
                points, maxFeatures, validMask)
            count = ProjectionAlignmentFeatureMatcher.pointCount(points);
            imageSize = size(validMask, [1 2]);
            aspect = imageSize(2) / max(imageSize(1), 1);
            columnCount = max(1, ceil(sqrt(maxFeatures * aspect)));
            rowCount = max(1, ceil(maxFeatures / columnCount));
            diagnostics = struct(Method="overlapAwareAspectQuotaAnms", ...
                CandidateCount=count, MaximumCount=maxFeatures, ...
                GridSize=[rowCount columnCount], SelectedCount=count);
            if count <= maxFeatures
                return
            end
            locations = ProjectionAlignmentFeatureMatcher.pointLocations(points);
            columnBins = min(columnCount, max(1, floor( ...
                (locations(:, 1) - 0.5) / max(imageSize(2), 1) * ...
                columnCount) + 1));
            rowBins = min(rowCount, max(1, floor( ...
                (locations(:, 2) - 0.5) / max(imageSize(1), 1) * ...
                rowCount) + 1));
            cellIndices = sub2ind([rowCount columnCount], rowBins, columnBins);
            keep = false(count, 1);
            selectedPerCell = zeros(rowCount * columnCount, 1);
            quota = 1;
            while nnz(keep) < maxFeatures
                previousCount = nnz(keep);
                for pointIndex = 1:count
                    cellIndex = cellIndices(pointIndex);
                    if ~keep(pointIndex) && selectedPerCell(cellIndex) < quota
                        keep(pointIndex) = true;
                        selectedPerCell(cellIndex) = ...
                            selectedPerCell(cellIndex) + 1;
                        if nnz(keep) == maxFeatures
                            break
                        end
                    end
                end
                if nnz(keep) == previousCount
                    break
                end
                quota = quota + 1;
            end
            points = points(keep);
            diagnostics.SelectedCount = ProjectionAlignmentFeatureMatcher. ...
                pointCount(points);
        end

        function order = pointOrder(points)
            count = ProjectionAlignmentFeatureMatcher.pointCount(points);
            if count == 0
                order = zeros(0, 1);
                return
            end
            locations = ProjectionAlignmentFeatureMatcher.pointLocations(points);
            metrics = ProjectionAlignmentFeatureMatcher.pointMetrics(points);
            scales = ProjectionAlignmentFeatureMatcher.pointProperty( ...
                points, "Scale", count);
            orientations = ProjectionAlignmentFeatureMatcher.pointProperty( ...
                points, "Orientation", count);
            keys = [-metrics(:), locations(:, 2), locations(:, 1), ...
                scales(:), orientations(:), (1:count).'];
            [~, order] = sortrows(keys, 1:size(keys, 2));
        end

        function values = pointProperty(points, propertyName, count)
            if isprop(points, propertyName)
                values = double(points.(propertyName));
                values = values(:);
            else
                values = zeros(count, 1);
            end
        end

        function [points, descriptors] = orderPointsAndDescriptors( ...
                points, descriptors)
            order = ProjectionAlignmentFeatureMatcher.pointOrder(points);
            if isempty(order)
                return
            end
            points = points(order);
            if isa(descriptors, "binaryFeatures")
                descriptors = binaryFeatures(descriptors.Features(order, :));
            else
                descriptors = descriptors(order, :);
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

        function locations = analysisToWorkingLocations(locations, mapping)
            if isempty(locations)
                return
            end
            locations(:, 1) = (locations(:, 1) - 0.5) / ...
                mapping.Scale(2) + 0.5;
            locations(:, 2) = (locations(:, 2) - 0.5) / ...
                mapping.Scale(1) + 0.5;
        end

        function descriptorSize = descriptorSize(descriptors)
            if isa(descriptors, "binaryFeatures")
                descriptorSize = [descriptors.NumFeatures descriptors.NumBits];
            else
                descriptorSize = size(descriptors);
            end
        end

        function count = descriptorCount(descriptors)
            if isa(descriptors, "binaryFeatures")
                count = descriptors.NumFeatures;
            else
                count = size(descriptors, 1);
            end
        end

        function matches = matchPairs(workingImages, features, matcher, detector)
            pairMasks = workingImages.PairOverlapMasks;
            matches = struct("Pair", {}, "Detector", {}, "Matcher", {}, ...
                "MatcherRequestedMethod", {}, "MatcherSearchMethod", {}, ...
                "PairLayerIds", {}, "MovingLayerId", {}, ...
                "ReferenceLayerId", {}, "PairDirection", {}, ...
                "MovingFeatureLocations", {}, "ReferenceFeatureLocations", {}, ...
                "MovingPlaneCoordinates", {}, "ReferencePlaneCoordinates", {}, ...
                "MovingSourceRows", {}, "MovingSourceColumns", {}, ...
                "ReferenceSourceRows", {}, "ReferenceSourceColumns", {}, ...
                "IndexPairs", {}, "MatchMetric", {}, "Scores", {}, ...
                "FeatureCounts", {}, "Count", {}, "OverlapMask", {}, ...
                "MatchSeconds", {}, "MatchLedger", {});
            for k = 1:numel(pairMasks)
                pair = pairMasks(k).Pair;
                pairWorking = ProjectionAlignmentFeatureMatcher.pairWorkingImage( ...
                    workingImages, k);
                if ProjectionAlignmentFeatureMatcher.hasPairWorkingImages(workingImages)
                    movingFeatures = ...
                        ProjectionAlignmentFeatureMatcher.featuresByPairRole( ...
                        features, k, "moving");
                    referenceFeatures = ...
                        ProjectionAlignmentFeatureMatcher.featuresByPairRole( ...
                        features, k, "reference");
                else
                    movingFeatures = ProjectionAlignmentFeatureMatcher.featuresByLayer( ...
                        features, pair(1));
                    referenceFeatures = ProjectionAlignmentFeatureMatcher.featuresByLayer( ...
                        features, pair(2));
                end
                pairMatch = ProjectionAlignmentFeatureMatcher.matchFeaturePair( ...
                    pairWorking, movingFeatures, referenceFeatures, matcher, ...
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
            matchTimer = tic;
            [indexPairs, matchMetric] = ProjectionAlignmentFeatureMatcher.matchDescriptors( ...
                movingFeatures.Descriptors, referenceFeatures.Descriptors, matcher);
            matchSeconds = toc(matchTimer);
            movingLocations = movingFeatures.Locations(indexPairs(:, 1), :);
            referenceLocations = referenceFeatures.Locations(indexPairs(:, 2), :);
            movingLayer = ProjectionAlignmentFeatureMatcher.layerImageByIndex( ...
                workingImages, movingFeatures.LayerIndex);
            referenceLayer = ProjectionAlignmentFeatureMatcher.layerImageByIndex( ...
                workingImages, referenceFeatures.LayerIndex);

            pairMatch = struct();
            pairMatch.Pair = pairMask.Pair;
            pairMatch.PairLayerIds = pairMask.PairLayerIds;
            pairMatch.MovingLayerId = pairMask.MovingLayerId;
            pairMatch.ReferenceLayerId = pairMask.ReferenceLayerId;
            pairMatch.PairDirection = pairMask.PairDirection;
            pairMatch.Detector = detector.Method;
            pairMatch.Matcher = lower(matcher.SearchMethod);
            pairMatch.MatcherRequestedMethod = matcher.RequestedMethod;
            pairMatch.MatcherSearchMethod = matcher.SearchMethod;
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
            pairMatch.MovingSourceJacobians = ...
                ProjectionAlignmentFeatureMatcher.sampleSourceJacobians( ...
                movingLayer, movingLocations);
            pairMatch.ReferenceSourceJacobians = ...
                ProjectionAlignmentFeatureMatcher.sampleSourceJacobians( ...
                referenceLayer, referenceLocations);
            pairMatch.AnalysisBands = [movingLayer.AnalysisBand ...
                referenceLayer.AnalysisBand];
            pairMatch.SourcePixelsPerWorkingPixel = [ ...
                ProjectionAlignmentFeatureMatcher.sourceDiagnostic( ...
                movingLayer, "SourcePixelsPerWorkingPixel", NaN), ...
                ProjectionAlignmentFeatureMatcher.sourceDiagnostic( ...
                referenceLayer, "SourcePixelsPerWorkingPixel", NaN)];
            pairMatch.IndexPairs = indexPairs;
            pairMatch.MatchMetric = matchMetric(:);
            pairMatch.Scores = 1 ./ (1 + double(matchMetric(:)));
            pairMatch.FeatureCounts = [movingFeatures.Count referenceFeatures.Count];
            pairMatch.Count = size(indexPairs, 1);
            pairMatch.OverlapMask = pairMask.Mask;
            pairMatch.MatchSeconds = matchSeconds;
            pairMatch = ProjectionAlignmentMatchLedger.ensurePair(pairMatch);
        end

        function [indexPairs, matchMetric] = matchDescriptors( ...
                movingDescriptors, referenceDescriptors, matcher)
            if ProjectionAlignmentFeatureMatcher.descriptorCount( ...
                    movingDescriptors) == 0 || ...
                    ProjectionAlignmentFeatureMatcher.descriptorCount( ...
                    referenceDescriptors) == 0
                indexPairs = zeros(0, 2);
                matchMetric = zeros(0, 1);
                return
            end
            args = {"Unique", matcher.Unique, "MaxRatio", matcher.MaxRatio, ...
                "Method", matcher.SearchMethod};
            if ~isempty(matcher.MatchThreshold)
                args = [args, {"MatchThreshold", matcher.MatchThreshold}];
            end
            [indexPairs, matchMetric] = matchFeatures( ...
                movingDescriptors, referenceDescriptors, args{:});
            if ~isempty(indexPairs)
                keys = [double(indexPairs(:, 1)), double(matchMetric(:)), ...
                    double(indexPairs(:, 2))];
                [~, order] = sortrows(keys, [1 2 3]);
                indexPairs = indexPairs(order, :);
                matchMetric = matchMetric(order, :);
            end
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

        function value = sourceDiagnostic(layerImage, fieldName, defaultValue)
            value = defaultValue;
            if isfield(layerImage, "SourceDiagnostics") && ...
                    isstruct(layerImage.SourceDiagnostics) && ...
                    isfield(layerImage.SourceDiagnostics, fieldName)
                value = double(layerImage.SourceDiagnostics.(fieldName));
            end
        end

        function jacobians = sampleSourceJacobians(layerImage, locations)
            [rowDx, rowDy] = gradient(layerImage.SourceRows);
            [columnDx, columnDy] = gradient(layerImage.SourceColumns);
            jacobians = [ ...
                ProjectionAlignmentFeatureMatcher.sampleMap(rowDx, locations), ...
                ProjectionAlignmentFeatureMatcher.sampleMap(rowDy, locations), ...
                ProjectionAlignmentFeatureMatcher.sampleMap(columnDx, locations), ...
                ProjectionAlignmentFeatureMatcher.sampleMap(columnDy, locations)];
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

        function feature = featuresByPairRole(features, pairIndex, role)
            matches = [features.PairIndex] == pairIndex & ...
                string({features.Role}) == role;
            if ~any(matches)
                error("ProjectionAlignmentFeatureMatcher:missingFeatures", ...
                    "Missing %s feature record for pair %d.", role, pairIndex);
            end
            feature = features(find(matches, 1, "first"));
        end

        function tf = hasPairWorkingImages(workingImages)
            tf = isfield(workingImages, "PairWorkingImages") && ...
                ~isempty(workingImages.PairWorkingImages);
        end

        function pairWorking = pairWorkingImage(workingImages, pairIndex)
            if ProjectionAlignmentFeatureMatcher.hasPairWorkingImages(workingImages)
                pairWorking = workingImages.PairWorkingImages(pairIndex);
            else
                pairWorking = workingImages;
            end
        end

        function layerImage = layerImageByIndex(workingImages, layerIndex)
            matches = [workingImages.LayerImages.LayerIndex] == layerIndex;
            if ~any(matches)
                error("ProjectionAlignmentFeatureMatcher:missingLayerImage", ...
                    "Missing working image for layer %d.", layerIndex);
            end
            layerImage = workingImages.LayerImages(find(matches, 1, "first"));
        end

        function diagnostics = diagnostics(features, matches, detector, matcher)
            scored = ProjectionAlignmentScheduler.scoreMatches(struct(Matches=matches));
            diagnostics = struct();
            diagnostics.Detector = detector;
            diagnostics.Matcher = matcher;
            diagnostics.FeatureCounts = [features.Count];
            diagnostics.DetectedFeatureCounts = [features.DetectedCount];
            diagnostics.MetricRejectedFeatureCounts = ...
                [features.MetricRejectedCount];
            diagnostics.MaskRejectedFeatureCounts = ...
                [features.MaskRejectedCount];
            diagnostics.SpatialRejectedFeatureCounts = ...
                [features.SpatialRejectedCount];
            diagnostics.DescriptorRejectedFeatureCounts = ...
                [features.DescriptorRejectedCount];
            diagnostics.MatchCounts = [matches.Count];
            diagnostics.TotalMatches = sum(diagnostics.MatchCounts);
            diagnostics.PairDiagnostics = scored.PairDiagnostics;
            diagnostics.MeanConfidence = scored.MeanConfidence;
            diagnostics.FeatureRecords = ...
                ProjectionAlignmentFeatureMatcher.featureDiagnosticRecords( ...
                features);
            featureTimings = [features.TimingSeconds];
            diagnostics.TimingSeconds = struct( ...
                Preparation=sum([featureTimings.Preparation]), ...
                Detection=sum([featureTimings.Detection]), ...
                DescriptorExtraction= ...
                sum([featureTimings.DescriptorExtraction]), ...
                Matching=sum([matches.MatchSeconds]));
        end

        function records = featureDiagnosticRecords(features)
            records = repmat(struct(LayerIndex=0, LayerId="", PairIndex=0, ...
                PairLayerIds=strings(1, 0), Role="", Detector="", ...
                DetectorParameters=struct(), ...
                DetectedCount=0, MetricRejectedCount=0, ...
                MaskRejectedCount=0, SpatialRejectedCount=0, ...
                SelectedCount=0, ...
                DescriptorRejectedCount=0, FinalCount=0, ...
                MetricThreshold=[], AnalysisScaleRequested=1, ...
                AnalysisScaleActual=[1 1], PreparedImageSize=[0 0], ...
                MaskSupportRadiusPixels=0, Normalization=struct(), ...
                SpatialSelection=struct(), ...
                TimingSeconds=struct()), 1, numel(features));
            for k = 1:numel(features)
                feature = features(k);
                records(k) = struct(LayerIndex=feature.LayerIndex, ...
                    LayerId=feature.LayerId, PairIndex=feature.PairIndex, ...
                    PairLayerIds=feature.PairLayerIds, Role=feature.Role, ...
                    Detector=feature.Detector, ...
                    DetectorParameters=feature.DetectorParameters, ...
                    DetectedCount=feature.DetectedCount, ...
                    MetricRejectedCount=feature.MetricRejectedCount, ...
                    MaskRejectedCount=feature.MaskRejectedCount, ...
                    SpatialRejectedCount=feature.SpatialRejectedCount, ...
                    SelectedCount=feature.SelectedCount, ...
                    DescriptorRejectedCount=feature.DescriptorRejectedCount, ...
                    FinalCount=feature.Count, ...
                    MetricThreshold=feature.MetricThreshold, ...
                    AnalysisScaleRequested=feature.AnalysisScaleRequested, ...
                    AnalysisScaleActual=feature.AnalysisScaleActual, ...
                    PreparedImageSize=feature.PreparedImageSize, ...
                    MaskSupportRadiusPixels= ...
                    feature.MaskSupportRadiusPixels, ...
                    Normalization=feature.Normalization, ...
                    SpatialSelection=feature.SpatialSelection, ...
                    TimingSeconds=feature.TimingSeconds);
            end
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
