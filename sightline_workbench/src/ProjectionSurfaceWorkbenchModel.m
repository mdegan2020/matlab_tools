classdef ProjectionSurfaceWorkbenchModel < handle
    %ProjectionSurfaceWorkbenchModel Graphics-free B6 selection and display model.

    properties (Constant)
        Format = "ProjectionSurfaceWorkbenchState"
        Version = 1
    end

    properties (Access = private)
        Catalog struct
        Configuration struct
    end

    methods
        function model = ProjectionSurfaceWorkbenchModel(catalog, configuration)
            %ProjectionSurfaceWorkbenchModel Create a portable workbench model.
            if nargin < 2
                configuration = struct();
            end
            model.Catalog = ProjectionSurfaceProductCatalog.validate(catalog);
            model.Configuration = model.defaults();
            model.configure(configuration);
        end

        function configure(model, changes)
            %configure Apply strict graphics-free workbench selections.
            if isempty(changes)
                changes = struct();
            end
            if ~isstruct(changes) || ~isscalar(changes)
                error("ProjectionSurfaceWorkbenchModel:invalidConfiguration", ...
                    "Configuration changes must be a scalar struct.");
            end
            names = string(fieldnames(changes));
            unknown = setdiff(names, string(fieldnames(model.Configuration)));
            if ~isempty(unknown)
                error("ProjectionSurfaceWorkbenchModel:invalidConfiguration", ...
                    "Unexpected workbench field: %s.", unknown(1));
            end
            candidate = model.Configuration;
            for name = names.'
                candidate.(name) = changes.(name);
            end
            model.Configuration = model.validateConfiguration(candidate);
        end

        function state = state(model)
            %state Return serializable scientific/control state without graphics.
            state = model.Configuration;
            state.Format = ProjectionSurfaceWorkbenchModel.Format;
            state.Version = ProjectionSurfaceWorkbenchModel.Version;
            state.CatalogGenerationId = model.Catalog.GenerationId;
            state.WorldFrame = model.Catalog.WorldFrame;
            state.EstimatedCatalogMemoryBytes = ...
                model.Catalog.Diagnostics.EstimatedMemoryBytes;
            state.EstimatedSelectedProductMemoryBytes = ...
                model.selectedProduct().EstimatedMemoryBytes;
            state.GraphicsStateIncluded = false;
        end

        function catalog = catalogValue(model)
            %catalogValue Return the complete immutable-by-convention catalog.
            catalog = model.Catalog;
        end

        function summaries = productSummaries(model)
            %productSummaries Return compact product/status/count rows.
            products = model.Catalog.Products;
            summaries = repmat(struct(ProductId="", Label="", Stage="", ...
                Representation="", ProductRole="", Status="", ...
                FullElementCount=0, EstimatedMemoryBytes=0), ...
                1, numel(products));
            for index = 1:numel(products)
                product = products(index);
                summaries(index) = struct(ProductId=product.ProductId, ...
                    Label=product.Label, Stage=product.Stage, ...
                    Representation=product.Representation, ...
                    ProductRole=product.ProductRole, Status=product.Status, ...
                    FullElementCount=product.FullElementCount, ...
                    EstimatedMemoryBytes=product.EstimatedMemoryBytes);
            end
        end

        function payload = payload(model, productId, colorMode)
            %payload Prepare bounded display data without changing full results.
            if nargin < 2 || strlength(string(productId)) == 0
                productId = model.Configuration.OutputProductId;
            end
            if nargin < 3 || strlength(string(colorMode)) == 0
                colorMode = model.Configuration.ColorMode;
            end
            [product, points] = model.resolvedProduct(productId);
            colorMode = model.validateColorMode(colorMode);
            fullPointCount = product.FullElementCount;
            filteredPointCount = numel(points);
            displayIndices = ProjectionSurfaceWorkbenchModel.decimatedIndices( ...
                filteredPointCount, model.Configuration.DecimationLimit);
            displayPoints = points(displayIndices);
            pointWorld = zeros(3, numel(displayPoints));
            if ~isempty(displayPoints)
                pointWorld = horzcat(displayPoints.PointWorld);
            end
            [colorValues, colorLabels, colorAvailable] = ...
                ProjectionSurfaceWorkbenchModel.colors(displayPoints, colorMode);
            representation = product.Representation;
            decimated = filteredPointCount > numel(displayIndices);
            if decimated && ismember(representation, ["mesh" "grid"])
                representation = "pointCloud";
            end
            payload = struct(ProductId=product.ProductId, Label=product.Label, ...
                Stage=product.Stage, ProductRole=product.ProductRole, ...
                SourceRepresentation=product.Representation, ...
                Representation=representation, ...
                FullPointCount=fullPointCount, ...
                FilteredPointCount=filteredPointCount, ...
                DisplayPointCount=numel(displayPoints), Decimated=decimated, ...
                DisplayIndices=displayIndices, Points=displayPoints, ...
                PointIds=reshape(string({displayPoints.PointId}), 1, []), ...
                PointsWorld=pointWorld, ColorMode=colorMode, ...
                ColorValues=colorValues, ColorLabels=colorLabels, ...
                ColorAvailable=colorAvailable, Mesh=product.Mesh, ...
                Grid=product.Grid, Diagnostics=product.Diagnostics, ...
                Provenance=product.Provenance, ...
                EstimatedMemoryBytes=product.EstimatedMemoryBytes, ...
                CompleteProductRetained=true);
        end

        function links = observationLinks(model, productId, pointId)
            %observationLinks Resolve selected 3-D identity to source pixels.
            payload = model.payload(productId, model.Configuration.ColorMode);
            match = string({payload.Points.PointId}) == string(pointId);
            if nnz(match) ~= 1
                error("ProjectionSurfaceWorkbenchModel:unknownPoint", ...
                    "Point '%s' is not in the selected display payload.", pointId);
            end
            links = payload.Points(match).ObservationLinks;
        end

        function stats = statistics(model, productId)
            %statistics Summarize full, filtered, and interactive products.
            payload = model.payload(productId, model.Configuration.ColorMode);
            uncertainty = double([payload.Points.UncertaintyMeters]);
            residual = double([payload.Points.ResidualMeters]);
            stats = struct(ProductId=payload.ProductId, Stage=payload.Stage, ...
                FullPointCount=payload.FullPointCount, ...
                FilteredPointCount=payload.FilteredPointCount, ...
                DisplayPointCount=payload.DisplayPointCount, ...
                Decimated=payload.Decimated, ...
                FiniteUncertaintyCount=nnz(isfinite(uncertainty)), ...
                MedianUncertaintyMeters= ...
                ProjectionSurfaceWorkbenchModel.medianFinite(uncertainty), ...
                MedianResidualMeters= ...
                ProjectionSurfaceWorkbenchModel.medianFinite(residual), ...
                EstimatedMemoryBytes=payload.EstimatedMemoryBytes);
        end

        function stats = networkStatistics(model)
            %networkStatistics Summarize pair and multi-view evidence.
            raw = model.productsAtStage("rawPairwise");
            robust = model.productsAtStage("robustMultiView");
            robustPoints = ProjectionSurfaceProductCatalog.emptyPoints();
            if ~isempty(robust)
                robustPoints = robust(1).Points;
            end
            views = double([robustPoints.IndependentViewCount]);
            passes = double([robustPoints.IndependentPassCount]);
            stats = struct(SelectedViewCount= ...
                numel(model.Configuration.SelectedViewIds), ...
                SelectedPassCount=numel(model.Configuration.SelectedPassIds), ...
                CatalogPairCount=numel(model.Catalog.PairIds), ...
                RawPairwisePointCount=sum([raw.FullElementCount]), ...
                RobustMultiViewPointCount=sum([robust.FullElementCount]), ...
                MedianIndependentViewCount= ...
                ProjectionSurfaceWorkbenchModel.medianFinite(views), ...
                MedianIndependentPassCount= ...
                ProjectionSurfaceWorkbenchModel.medianFinite(passes));
        end

        function estimate = processingEstimate(model)
            %processingEstimate Expose bounded relative work and memory cost.
            selectedViewCount = numel(model.Configuration.SelectedViewIds);
            potentialPairCount = selectedViewCount * ...
                max(0, selectedViewCount - 1) / 2;
            catalogPairCount = numel(model.Catalog.PairIds);
            eligiblePairCount = min(catalogPairCount, potentialPairCount);
            switch model.Configuration.PairSchedule
                case "fast"
                    scheduledPairCount = min(1, eligiblePairCount);
                case "balanced"
                    scheduledPairCount = ceil(eligiblePairCount / 2);
                case {"quality", "operator"}
                    scheduledPairCount = eligiblePairCount;
                otherwise
                    scheduledPairCount = potentialPairCount;
            end
            selected = model.selectedProduct();
            estimate = struct(PairSchedule=model.Configuration.PairSchedule, ...
                PotentialPairCount=potentialPairCount, ...
                ScheduledPairCount=scheduledPairCount, ...
                RelativeWorkUnits=scheduledPairCount * ...
                max(1, selected.FullElementCount), ...
                EstimatedCatalogMemoryBytes= ...
                model.Catalog.Diagnostics.EstimatedMemoryBytes, ...
                EstimatedSelectedProductMemoryBytes= ...
                selected.EstimatedMemoryBytes, ...
                IsWallClockPrediction=false);
        end

        function ids = availableProductIds(model)
            %availableProductIds Return selectable products only.
            available = string({model.Catalog.Products.Status}) == "available";
            ids = string({model.Catalog.Products(available).ProductId});
        end
    end

    methods (Static)
        function modes = colorModes()
            %colorModes Return the stable B6 color vocabulary.
            modes = ["sourceIntensity" "elevation" "viewCount" ...
                "passCount" "residual" "uncertainty" "conditioning" ...
                "fusionMethod" "pairPass" "demDifference" "evidenceWeight"];
        end
    end

    methods (Access = private)
        function configuration = defaults(model)
            available = model.availableProductIdsFromCatalog();
            outputId = "robust-multi-view";
            if ~ismember(outputId, available)
                outputId = available(1);
            end
            fusionProducts = model.Catalog.Products( ...
                string({model.Catalog.Products.Stage}) == "fusionDerived" & ...
                string({model.Catalog.Products.Status}) == "available");
            fusionId = outputId;
            if ~isempty(fusionProducts)
                fusionId = fusionProducts(1).ProductId;
            end
            configuration = struct( ...
                SelectedViewIds=model.Catalog.ViewIds, ...
                SelectedPassIds=model.Catalog.PassIds, ...
                PairSchedule="quality", DenseMethod="currentSgm", ...
                GeometrySearch="sparseSeeded", ...
                ProcessingStage="robustMultiView", ...
                MaximumUncertaintyMeters=Inf, FusionProductId=fusionId, ...
                DemRegistrationMode="none", OutputProductId=outputId, ...
                ComparisonProductId="", ColorMode="elevation", ...
                DecimationLimit=50000, MaximumUncertaintyGlyphs=1);
        end

        function configuration = validateConfiguration(model, configuration)
            configuration.SelectedViewIds = ProjectionSurfaceWorkbenchModel. ...
                selectedIds(configuration.SelectedViewIds, ...
                model.Catalog.ViewIds, "SelectedViewIds");
            configuration.SelectedPassIds = ProjectionSurfaceWorkbenchModel. ...
                selectedIds(configuration.SelectedPassIds, ...
                model.Catalog.PassIds, "SelectedPassIds");
            configuration.PairSchedule = ProjectionSurfaceWorkbenchModel. ...
                enumValue(configuration.PairSchedule, ...
                ["fast" "balanced" "quality" "allPlausible" "operator"], ...
                "PairSchedule");
            configuration.DenseMethod = ProjectionSurfaceWorkbenchModel. ...
                enumValue(configuration.DenseMethod, ...
                ["currentSgm" "classicalTemplate" "external"], "DenseMethod");
            configuration.GeometrySearch = ProjectionSurfaceWorkbenchModel. ...
                enumValue(configuration.GeometrySearch, ...
                ["sparseSeeded" "widePrior" "localStrip" "terrainGrid"], ...
                "GeometrySearch");
            configuration.ProcessingStage = ProjectionSurfaceWorkbenchModel. ...
                enumValue(configuration.ProcessingStage, ...
                ["rawPairwise" "robustMultiView" "uncertaintyFiltered" ...
                "fusionDerived" "voxelEvidence" "mesh" "grid" ...
                "dem" "registered" "demDifference"], "ProcessingStage");
            configuration.DemRegistrationMode = ProjectionSurfaceWorkbenchModel. ...
                enumValue(configuration.DemRegistrationMode, ...
                ["none" "preview" "registered" "difference"], ...
                "DemRegistrationMode");
            configuration.ColorMode = model.validateColorMode( ...
                configuration.ColorMode);
            configuration.MaximumUncertaintyMeters = ...
                ProjectionSurfaceWorkbenchModel.positiveOrInf( ...
                configuration.MaximumUncertaintyMeters, ...
                "MaximumUncertaintyMeters");
            configuration.DecimationLimit = ...
                ProjectionSurfaceWorkbenchModel.positiveInteger( ...
                configuration.DecimationLimit, "DecimationLimit");
            configuration.MaximumUncertaintyGlyphs = ...
                ProjectionSurfaceWorkbenchModel.nonnegativeInteger( ...
                configuration.MaximumUncertaintyGlyphs, ...
                "MaximumUncertaintyGlyphs");
            available = model.availableProductIdsFromCatalog();
            productFields = ["FusionProductId" "OutputProductId"];
            for field = productFields
                configuration.(field) = string(configuration.(field));
                if ~isscalar(configuration.(field)) || ...
                        ~ismember(configuration.(field), available)
                    error("ProjectionSurfaceWorkbenchModel:unknownProduct", ...
                        "%s must name an available catalog product.", field);
                end
            end
            configuration.ComparisonProductId = ...
                string(configuration.ComparisonProductId);
            if ~isscalar(configuration.ComparisonProductId) || ...
                    (strlength(configuration.ComparisonProductId) > 0 && ...
                    ~ismember(configuration.ComparisonProductId, available))
                error("ProjectionSurfaceWorkbenchModel:unknownProduct", ...
                    "ComparisonProductId must be empty or available.");
            end
        end

        function [product, points] = resolvedProduct(model, productId)
            product = ProjectionSurfaceProductCatalog.find( ...
                model.Catalog, productId);
            if product.Status ~= "available"
                error("ProjectionSurfaceWorkbenchModel:unavailableProduct", ...
                    "Surface product '%s' is unavailable.", product.ProductId);
            end
            points = product.Points;
            if strlength(product.SourceProductId) > 0
                source = ProjectionSurfaceProductCatalog.find( ...
                    model.Catalog, product.SourceProductId);
                points = source.Points;
            end
            if product.Stage == "uncertaintyFiltered"
                uncertainty = double([points.UncertaintyMeters]);
                keep = isfinite(uncertainty) & ...
                    uncertainty <= model.Configuration.MaximumUncertaintyMeters;
                points = points(keep);
            end
        end

        function product = selectedProduct(model)
            product = ProjectionSurfaceProductCatalog.find( ...
                model.Catalog, model.Configuration.OutputProductId);
        end

        function products = productsAtStage(model, stage)
            products = model.Catalog.Products( ...
                string({model.Catalog.Products.Stage}) == string(stage) & ...
                string({model.Catalog.Products.Status}) == "available");
        end

        function value = validateColorMode(~, value)
            value = ProjectionSurfaceWorkbenchModel.enumValue( ...
                value, ProjectionSurfaceWorkbenchModel.colorModes(), "ColorMode");
        end

        function ids = availableProductIdsFromCatalog(model)
            available = string({model.Catalog.Products.Status}) == "available";
            ids = string({model.Catalog.Products(available).ProductId});
            if isempty(ids)
                error("ProjectionSurfaceWorkbenchModel:noProducts", ...
                    "At least one available surface product is required.");
            end
        end
    end

    methods (Static, Access = private)
        function [values, labels, available] = colors(points, mode)
            count = numel(points);
            labels = strings(1, 0);
            if count == 0
                values = zeros(1, 0);
                available = false;
                return
            end
            switch mode
                case "sourceIntensity"
                    values = double([points.SourceIntensity]);
                case "elevation"
                    coordinates = horzcat(points.PointWorld);
                    values = coordinates(3, :);
                case "viewCount"
                    values = double([points.IndependentViewCount]);
                case "passCount"
                    values = double([points.IndependentPassCount]);
                case "residual"
                    values = double([points.ResidualMeters]);
                case "uncertainty"
                    values = double([points.UncertaintyMeters]);
                case "conditioning"
                    values = double([points.ConditionNumber]);
                case "demDifference"
                    values = double([points.DemDifferenceMeters]);
                case "evidenceWeight"
                    values = double([points.EvidenceWeight]);
                case "fusionMethod"
                    [values, labels] = ProjectionSurfaceWorkbenchModel. ...
                        categoricalColors(string({points.FusionMethod}));
                otherwise
                    pairPass = strings(1, count);
                    for index = 1:count
                        pair = ProjectionSurfaceWorkbenchModel.joinOrNone( ...
                            points(index).PairIds);
                        pass = ProjectionSurfaceWorkbenchModel.joinOrNone( ...
                            points(index).PassIds);
                        pairPass(index) = pair + " | " + pass;
                    end
                    [values, labels] = ProjectionSurfaceWorkbenchModel. ...
                        categoricalColors(pairPass);
            end
            available = any(isfinite(values));
            if ~available
                values = zeros(1, count);
            else
                values(~isfinite(values)) = min(values(isfinite(values)));
            end
        end

        function [values, labels] = categoricalColors(categories)
            labels = sort(unique(categories));
            values = zeros(1, numel(categories));
            for index = 1:numel(labels)
                values(categories == labels(index)) = index;
            end
        end

        function value = joinOrNone(values)
            values = reshape(string(values), 1, []);
            if isempty(values)
                value = "none";
            else
                value = strjoin(sort(unique(values)), "+");
            end
        end

        function indices = decimatedIndices(count, limit)
            if count == 0
                indices = zeros(1, 0);
            elseif count <= limit
                indices = 1:count;
            else
                indices = unique(round(linspace(1, count, limit)), "stable");
            end
        end

        function values = selectedIds(values, available, name)
            values = reshape(string(values), 1, []);
            if isempty(values) || any(~ismember(values, available)) || ...
                    numel(unique(values)) ~= numel(values)
                error("ProjectionSurfaceWorkbenchModel:invalidConfiguration", ...
                    "%s must select unique available identities.", name);
            end
        end

        function value = enumValue(value, supported, name)
            value = string(value);
            if ~isscalar(value) || ismissing(value) || ...
                    ~ismember(value, supported)
                error("ProjectionSurfaceWorkbenchModel:invalidConfiguration", ...
                    "%s is unsupported.", name);
            end
        end

        function value = positiveOrInf(value, name)
            if ~isnumeric(value) || ~isscalar(value) || ...
                    ~(isfinite(value) || isinf(value)) || value <= 0
                error("ProjectionSurfaceWorkbenchModel:invalidConfiguration", ...
                    "%s must be positive or Inf.", name);
            end
            value = double(value);
        end

        function value = positiveInteger(value, name)
            if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value) || ...
                    value < 1 || fix(value) ~= value
                error("ProjectionSurfaceWorkbenchModel:invalidConfiguration", ...
                    "%s must be a positive integer.", name);
            end
            value = double(value);
        end

        function value = nonnegativeInteger(value, name)
            if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value) || ...
                    value < 0 || fix(value) ~= value
                error("ProjectionSurfaceWorkbenchModel:invalidConfiguration", ...
                    "%s must be a nonnegative integer.", name);
            end
            value = double(value);
        end

        function value = medianFinite(values)
            values = values(isfinite(values));
            if isempty(values)
                value = NaN;
            else
                value = median(values);
            end
        end
    end
end
