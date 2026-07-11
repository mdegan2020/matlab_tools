classdef ProjectionDenseSurfaceSyntheticGenerator
    %ProjectionDenseSurfaceSyntheticGenerator Render and write truth imagery.

    properties (Constant)
        Format = "ProjectionDenseSurfaceSyntheticRun"
        Version = 1
    end

    methods (Static)
        function result = runFile(configPath, options)
            %runFile Plan first, load the full source once, then render all views.
            if nargin < 2
                options = struct();
            end
            [config, context] = ProjectionDenseSurfaceSyntheticConfig.load(configPath);
            imageInfo = imfinfo(context.SourceImagePath);
            sourceImageSize = [imageInfo.Height imageInfo.Width ...
                imageInfo.SamplesPerPixel];
            plan = ProjectionDenseSurfaceSyntheticPlanner.plan( ...
                config, sourceImageSize);
            ProjectionDenseSurfaceSyntheticGenerator.requireFeasible(plan);
            options = ProjectionDenseSurfaceSyntheticGenerator.mergeOptions( ...
                options, config, context.OutputDirectory);
            sourceImage = imread(context.SourceImagePath);
            result = ProjectionDenseSurfaceSyntheticGenerator.generate( ...
                config, plan, sourceImage, options);
        end

        function result = generate(config, plan, sourceImage, options)
            %generate Render configured views from full source radiometry and truth.
            if nargin < 4
                options = struct();
            end
            config = ProjectionDenseSurfaceSyntheticConfig.validate(config);
            ProjectionDenseSurfaceSyntheticGenerator.requireFeasible(plan);
            ProjectionDenseSurfaceSyntheticGenerator.validateSourceImage( ...
                sourceImage, config);
            options = ProjectionDenseSurfaceSyntheticGenerator.mergeOptions( ...
                options, config, config.output.directory);
            if options.WriteFiles && ~isfolder(options.OutputDirectory)
                mkdir(options.OutputDirectory);
            end

            runTimer = tic;
            truth = ProjectionDenseSurfaceSyntheticTruth.create(config, plan);
            viewCount = config.image.view_count;
            images = cell(1, viewCount);
            imagePaths = strings(1, viewCount);
            viewReports = repmat( ...
                ProjectionDenseSurfaceSyntheticGenerator.emptyViewReport(), ...
                1, viewCount);
            for viewIndex = 1:viewCount
                viewTimer = tic;
                [image, counts] = ...
                    ProjectionDenseSurfaceSyntheticGenerator.renderView( ...
                    truth, plan, sourceImage, viewIndex, options);
                images{viewIndex} = image;
                if options.WriteFiles
                    imagePaths(viewIndex) = ...
                        ProjectionDenseSurfaceSyntheticGenerator.writeViewImage( ...
                        image, viewIndex, options);
                end
                imageInfo = whos("image");
                viewReports(viewIndex) = struct(Index=viewIndex, ...
                    SourceBand=truth.Views(viewIndex).SourceBand, ...
                    ValidPixelCount=counts.VisibleTerrain, ...
                    InvalidGeometryCount=counts.InvalidGeometry, ...
                    TextureCoverageFailureCount=counts.TextureCoverageFailure, ...
                    ValidFraction=counts.VisibleTerrain / numel(image), ...
                    RuntimeSeconds=toc(viewTimer), ImageBytes=imageInfo.bytes, ...
                    OutputPath=imagePaths(viewIndex));
            end

            sceneData = ProjectionDenseSurfaceSyntheticTruth.sceneMetadata(truth);
            sceneData.ImagePaths = imagePaths;
            sceneData.ImageClass = string(class(sourceImage));
            sceneData.SourceGeometryRole = "reported-navigation-required";
            sceneData.TruthIncluded = false;
            fingerprint = ...
                ProjectionDenseSurfaceSyntheticGenerator.configFingerprint(config);
            imageBytes = sum([viewReports.ImageBytes]);
            sourceInfo = whos("sourceImage");
            elapsed = toc(runTimer);
            summary = struct( ...
                Format=ProjectionDenseSurfaceSyntheticGenerator.Format, ...
                Version=ProjectionDenseSurfaceSyntheticGenerator.Version, ...
                Status="complete", ConfigurationFingerprint=fingerprint, ...
                ViewCount=viewCount, ImageSize=truth.ImageSize, ...
                ImageClass=string(class(sourceImage)), ...
                Feasibility=struct(Status=plan.Status, ...
                CheckNames=string({plan.Checks.Name}), ...
                ChecksPassed=[plan.Checks.Passed]), ...
                VisibilityStatuses=truth.VisibilityStatuses, ...
                OcclusionAudit=truth.OcclusionAudit, Views=viewReports, ...
                RuntimeSeconds=elapsed, RetainedImageBytes=imageBytes, ...
                EstimatedPeakBytes=imageBytes + sourceInfo.bytes + ...
                max([viewReports.ImageBytes]));
            artifacts = ProjectionDenseSurfaceSyntheticGenerator.writeArtifacts( ...
                config, plan, truth, sceneData, summary, options, imagePaths);
            result = struct(Format=ProjectionDenseSurfaceSyntheticGenerator.Format, ...
                Version=ProjectionDenseSurfaceSyntheticGenerator.Version, ...
                Images={images}, Truth=truth, Plan=plan, SceneData=sceneData, ...
                Summary=summary, Artifacts=artifacts);
        end
    end

    methods (Static, Access = private)
        function [image, counts] = renderView( ...
                truth, plan, sourceImage, viewIndex, options)
            imageSize = truth.ImageSize;
            image = zeros(imageSize, "like", sourceImage(:, :, 1));
            sourceBand = truth.Views(viewIndex).SourceBand;
            sourceTexture = sourceImage(:, :, sourceBand);
            visibleCount = 0;
            invalidCount = 0;
            textureFailureCount = 0;
            for columnStart = 1:options.ColumnChunkSize:imageSize(2)
                columnEnd = min(columnStart + options.ColumnChunkSize - 1, ...
                    imageSize(2));
                columnIndices = columnStart:columnEnd;
                for rowStart = 1:options.RowChunkSize:imageSize(1)
                    rowEnd = min(rowStart + options.RowChunkSize - 1, imageSize(1));
                    rowIndices = rowStart:rowEnd;
                    [origins, vectors] = ...
                        ProjectionDenseSurfaceSyntheticTruth.sampleGridRays( ...
                        truth, viewIndex, rowIndices, columnIndices);
                    expandedOrigins = repelem(origins, 1, numel(rowIndices));
                    [points, status] = ...
                        ProjectionDenseSurfaceSyntheticTerrain.intersectRays( ...
                        truth.Terrain, expandedOrigins, reshape(vectors, 3, []));
                    terrainX = reshape(points(1, :), ...
                        numel(rowIndices), numel(columnIndices));
                    terrainY = reshape(points(2, :), ...
                        numel(rowIndices), numel(columnIndices));
                    [textureRows, textureColumns] = ...
                        ProjectionDenseSurfaceSyntheticGenerator.textureCoordinates( ...
                        terrainX, terrainY, plan, size(sourceTexture));
                    values = ProjectionReflectedTexture.sample( ...
                        sourceTexture, textureRows, textureColumns, "linear");
                    chunkStatus = reshape(status, ...
                        numel(rowIndices), numel(columnIndices));
                    textureFailure = chunkStatus == "visibleTerrain" & ...
                        ~isfinite(values);
                    valid = chunkStatus == "visibleTerrain" & ~textureFailure;
                    values(~valid) = 0;
                    image(rowIndices, columnIndices) = ...
                        ProjectionDenseSurfaceSyntheticGenerator.castValues( ...
                        values, class(sourceTexture));
                    visibleCount = visibleCount + nnz(valid);
                    invalidCount = invalidCount + ...
                        nnz(chunkStatus == "invalidGeometry");
                    textureFailureCount = textureFailureCount + nnz(textureFailure);
                end
            end
            counts = struct(VisibleTerrain=visibleCount, ...
                InvalidGeometry=invalidCount, ...
                TextureCoverageFailure=textureFailureCount);
        end

        function [rows, columns] = textureCoordinates(x, y, plan, textureSize)
            spacing = plan.TextureSampleSpacingMeters;
            target = plan.TargetPoint;
            rows = 0.5 * (textureSize(1) + 1) + (y - target(2)) / spacing(1);
            columns = 0.5 * (textureSize(2) + 1) + ...
                (x - target(1)) / spacing(2);
        end

        function values = castValues(values, className)
            switch className
                case "uint8"
                    values = uint8(min(max(round(values), 0), ...
                        double(intmax("uint8"))));
                case "uint16"
                    values = uint16(min(max(round(values), 0), ...
                        double(intmax("uint16"))));
                case "int16"
                    values = int16(min(max(round(values), ...
                        double(intmin("int16"))), double(intmax("int16"))));
                case "logical"
                    values = values >= 0.5;
                otherwise
                    values = cast(values, className);
            end
        end

        function path = writeViewImage(image, viewIndex, options)
            if options.ImageFormat == "tiff"
                extension = "tif";
            else
                extension = "png";
            end
            path = string(fullfile(options.OutputDirectory, ...
                sprintf("view_%03d.%s", viewIndex, extension)));
            imwrite(image, path);
        end

        function artifacts = writeArtifacts( ...
                config, plan, truth, sceneData, summary, options, imagePaths)
            truthPath = "";
            summaryPath = "";
            if options.WriteFiles && config.output.write_compact_mat_truth
                truthPath = string(fullfile(options.OutputDirectory, ...
                    "synthetic_truth_scene.mat"));
                save(truthPath, "truth", "sceneData", "plan", "-v7");
            end
            if options.WriteFiles && config.output.write_json_run_summary
                summaryPath = string(fullfile(options.OutputDirectory, ...
                    "run_summary.json"));
                ProjectionDenseSurfaceSyntheticGenerator.writeJson( ...
                    summaryPath, summary);
            end
            artifacts = struct(OutputDirectory=options.OutputDirectory, ...
                ImagePaths=imagePaths, TruthSceneMatPath=truthPath, ...
                RunSummaryJsonPath=summaryPath);
        end

        function writeJson(path, value)
            fileId = fopen(path, "w");
            if fileId < 0
                error("ProjectionDenseSurfaceSyntheticGenerator:outputOpenFailed", ...
                    "Could not open JSON output for writing.");
            end
            cleanup = onCleanup(@() fclose(fileId));
            fprintf(fileId, "%s", jsonencode(value, PrettyPrint=true));
            clear cleanup
        end

        function fingerprint = configFingerprint(config)
            bytes = unicode2native(jsonencode(config), "UTF-8");
            digest = java.security.MessageDigest.getInstance("SHA-256");
            digest.update(uint8(bytes));
            raw = typecast(digest.digest(), "uint8");
            fingerprint = lower(string(reshape(dec2hex(raw, 2).', 1, [])));
        end

        function options = mergeOptions(options, config, defaultOutputDirectory)
            if isempty(options)
                options = struct();
            end
            if ~isstruct(options) || ~isscalar(options)
                error("ProjectionDenseSurfaceSyntheticGenerator:invalidOptions", ...
                    "Generator options must be a scalar struct.");
            end
            defaults = struct(RowChunkSize=256, ColumnChunkSize=512, ...
                WriteFiles=true, OutputDirectory=string(defaultOutputDirectory), ...
                ImageFormat=config.output.default_image_format);
            names = fieldnames(options);
            allowed = string(fieldnames(defaults));
            if any(~ismember(string(names), allowed))
                error("ProjectionDenseSurfaceSyntheticGenerator:invalidOptions", ...
                    "Generator options contain an unsupported field.");
            end
            for fieldIndex = 1:numel(names)
                defaults.(names{fieldIndex}) = options.(names{fieldIndex});
            end
            defaults.RowChunkSize = ...
                ProjectionDenseSurfaceSyntheticGenerator.positiveInteger( ...
                defaults.RowChunkSize, "RowChunkSize");
            defaults.ColumnChunkSize = ...
                ProjectionDenseSurfaceSyntheticGenerator.positiveInteger( ...
                defaults.ColumnChunkSize, "ColumnChunkSize");
            if ~islogical(defaults.WriteFiles) || ~isscalar(defaults.WriteFiles)
                error("ProjectionDenseSurfaceSyntheticGenerator:invalidOptions", ...
                    "WriteFiles must be a logical scalar.");
            end
            defaults.OutputDirectory = string(defaults.OutputDirectory);
            if ~isscalar(defaults.OutputDirectory) || ...
                    (defaults.WriteFiles && strlength(defaults.OutputDirectory) == 0)
                error("ProjectionDenseSurfaceSyntheticGenerator:invalidOptions", ...
                    "OutputDirectory must be a nonempty scalar path when writing.");
            end
            defaults.ImageFormat = lower(string(defaults.ImageFormat));
            if ~isscalar(defaults.ImageFormat) || ...
                    ~ismember(defaults.ImageFormat, config.output.supported_image_formats)
                error("ProjectionDenseSurfaceSyntheticGenerator:invalidOptions", ...
                    "ImageFormat must be one of the configured supported formats.");
            end
            options = defaults;
        end

        function validateSourceImage(image, config)
            if ~(isnumeric(image) || islogical(image)) || isempty(image) || ...
                    ndims(image) > 3 || any(~isfinite(double(image)), "all") || ...
                    size(image, 1) < 2 || size(image, 2) < 2
                error("ProjectionDenseSurfaceSyntheticGenerator:invalidSourceImage", ...
                    "Source image must be a finite in-memory 2-D or 3-D image.");
            end
            if max(config.image.source_band_sequence) > size(image, 3)
                error("ProjectionDenseSurfaceSyntheticGenerator:missingSourceBand", ...
                    "Source image does not contain every configured band.");
            end
            if config.output.preserve_source_integer_class && ~isinteger(image)
                error("ProjectionDenseSurfaceSyntheticGenerator:invalidSourceClass", ...
                    "The configured source-class policy requires integer imagery.");
            end
        end

        function requireFeasible(plan)
            if ~isstruct(plan) || ~isscalar(plan) || ...
                    ~isfield(plan, "Format") || ...
                    string(plan.Format) ~= ProjectionDenseSurfaceSyntheticPlanner.Format
                error("ProjectionDenseSurfaceSyntheticGenerator:invalidPlan", ...
                    "A synthetic collection plan is required before rendering.");
            end
            if ~isfield(plan, "Feasible") || ~plan.Feasible
                firstViolation = "unknown";
                if isfield(plan, "FirstViolation")
                    firstViolation = string(plan.FirstViolation);
                end
                error("ProjectionDenseSurfaceSyntheticGenerator:infeasiblePlan", ...
                    "Full-size allocation is blocked by feasibility constraint %s.", ...
                    firstViolation);
            end
        end

        function value = positiveInteger(value, name)
            if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value) || ...
                    value < 1 || fix(value) ~= value
                error("ProjectionDenseSurfaceSyntheticGenerator:invalidOptions", ...
                    "%s must be a positive integer.", name);
            end
            value = double(value);
        end

        function report = emptyViewReport()
            report = struct(Index=0, SourceBand=0, ValidPixelCount=0, ...
                InvalidGeometryCount=0, TextureCoverageFailureCount=0, ...
                ValidFraction=0, RuntimeSeconds=0, ImageBytes=0, OutputPath="");
        end
    end
end
