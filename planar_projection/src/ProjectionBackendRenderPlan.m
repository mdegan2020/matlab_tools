classdef ProjectionBackendRenderPlan
    %ProjectionBackendRenderPlan Compile reusable runtime backend geometry.
    %
    % Plans are runtime-only. They may contain MATLAB interpolation objects
    % and must never be serialized into jobs or scene/layer/source structs.

    properties (Constant)
        Format = "ProjectionBackendRenderPlan"
        Version = 1
    end

    methods (Static)
        function plan = compile(scene, options, preparedLayers)
            %compile Prepare visible meshes and interpolation topology once.
            if nargin < 2
                options = struct();
            end
            if nargin < 3
                preparedLayers = struct([]);
            end
            ProjectionBackendRenderPlan.validateScene(scene);
            layerIndices = ProjectionBackendRenderPlan.visibleLayerIndices( ...
                scene.layers);
            firstLayer = scene.layers(layerIndices(1));
            options = ProjectionBackendRenderPlan.mergeOptions(options, firstLayer);
            preparedLayers = ProjectionBackendRenderPlan.validatePreparedLayers( ...
                preparedLayers, layerIndices);
            gpuInfo = ProjectionBackendGpuSupport.resolve(options.UseGPU);

            layers = struct([]);
            compileMeshBuildCount = 0;
            compileTimer = tic;
            for outputIndex = 1:numel(layerIndices)
                layerIndex = layerIndices(outputIndex);
                layer = scene.layers(layerIndex);
                plane = layer.CurrentProjectionPlane;
                [mesh, reusedMesh] = ProjectionBackendRenderPlan.layerMesh( ...
                    layer, plane, scene.renderOrigin, preparedLayers, layerIndex);
                compileMeshBuildCount = compileMeshBuildCount + ~reusedMesh;
                worldPoints = reshape(mesh.WorldPoints, 3, []);
                meshPlaneCoordinates = PlanarProjection.worldToPlane( ...
                    worldPoints, plane);
                if options.NumericalMode == "fullSourceInverseWarp"
                    inverseWarp = ProjectionFullSourceInverseWarp.prepare( ...
                        mesh, plane, layer.SourceGeometry.ImageSize);
                    interpolant = inverseWarp.InterpolantTemplate;
                    sampledImage = [];
                    sourceImage = layer.Image;
                    bandCount = size(sourceImage, 3);
                else
                    inverseWarp = [];
                    sampledImage = layer.Image( ...
                        mesh.RowIndices, mesh.ColumnIndices, :);
                    sourceImage = [];
                    bandCount = size(sampledImage, 3);
                    interpolant = scatteredInterpolant( ...
                        meshPlaneCoordinates(1, :).', ...
                        meshPlaneCoordinates(2, :).', ...
                        zeros(size(meshPlaneCoordinates, 2), 1), ...
                        ProjectionBackendRenderPlan.scatteredMethod( ...
                        options.Interpolation), "none");
                end

                layerPlan = struct();
                layerPlan.LayerIndex = layerIndex;
                layerPlan.Plane = plane;
                layerPlan.Mesh = mesh;
                layerPlan.MeshPlaneCoordinates = meshPlaneCoordinates;
                layerPlan.SampledImage = sampledImage;
                layerPlan.SourceImage = sourceImage;
                layerPlan.BandCount = bandCount;
                layerPlan.InterpolantTemplate = interpolant;
                layerPlan.InverseWarp = inverseWarp;
                layerPlan.Alpha = double(layer.Alpha);
                layerPlan.Visible = logical(layer.Visible);
                layerPlan.BlendMode = string(layer.BlendMode);
                layerPlan.MeshReused = reusedMesh;
                if isempty(layers)
                    layers = layerPlan;
                else
                    layers(outputIndex) = layerPlan;
                end
            end

            plan = struct();
            plan.Format = ProjectionBackendRenderPlan.Format;
            plan.Version = ProjectionBackendRenderPlan.Version;
            plan.RuntimeOnly = true;
            plan.FrameCamera = scene.frameCamera;
            plan.RenderOrigin = scene.renderOrigin;
            plan.OutputGrid = options.OutputGrid;
            plan.OutputSize = options.OutputSize;
            plan.Interpolation = options.Interpolation;
            plan.InvalidFillValue = options.InvalidFillValue;
            plan.IncludeLayerReadbacks = options.IncludeLayerReadbacks;
            plan.UseGPU = gpuInfo.Enabled;
            plan.GpuInfo = gpuInfo;
            plan.LayerIndices = layerIndices;
            plan.Layers = layers;
            plan.Preparation = struct( ...
                MeshBuildCount=numel(layerIndices), ...
                CompileMeshBuildCount=compileMeshBuildCount, ...
                ReusedMeshCount=numel(layerIndices) - compileMeshBuildCount, ...
                TopologyBuildCount=numel(layerIndices), ...
                GpuResolutionCount=1, ...
                CompileSeconds=toc(compileTimer));
            plan.NumericalMode = options.NumericalMode;
            ProjectionBackendRenderPlan.validate(plan);
        end

        function plan = validate(plan)
            %validate Validate a compiled runtime render plan.
            requiredFields = ["Format", "Version", "RuntimeOnly", ...
                "FrameCamera", "RenderOrigin", "OutputGrid", "OutputSize", ...
                "Interpolation", "InvalidFillValue", ...
                "IncludeLayerReadbacks", "UseGPU", "GpuInfo", ...
                "LayerIndices", "Layers", "Preparation", "NumericalMode"];
            if ~isstruct(plan) || ~isscalar(plan) || ...
                    any(~isfield(plan, requiredFields)) || ...
                    string(plan.Format) ~= ProjectionBackendRenderPlan.Format || ...
                    double(plan.Version) ~= ProjectionBackendRenderPlan.Version
                error("ProjectionBackendRenderPlan:invalidPlan", ...
                    "Render plan has an invalid format or is missing required fields.");
            end
            if ~isscalar(plan.RuntimeOnly) || ~logical(plan.RuntimeOnly)
                error("ProjectionBackendRenderPlan:invalidPlan", ...
                    "Render plans must be marked runtime-only.");
            end
            PlanarProjection.validateCamera(plan.FrameCamera);
            if ~isnumeric(plan.RenderOrigin) || ...
                    ~isequal(size(plan.RenderOrigin), [3 1]) || ...
                    any(~isfinite(plan.RenderOrigin))
                error("ProjectionBackendRenderPlan:invalidPlan", ...
                    "RenderOrigin must be a finite numeric 3x1 vector.");
            end
            plan.OutputSize = ProjectionBackendRenderPlan.validateOutputSize( ...
                plan.OutputSize, "OutputSize");
            plan.Interpolation = ...
                ProjectionBackendRenderPlan.validateInterpolation( ...
                plan.Interpolation);
            plan.IncludeLayerReadbacks = ...
                ProjectionBackendRenderPlan.validateLogicalScalar( ...
                plan.IncludeLayerReadbacks, "IncludeLayerReadbacks");
            plan.UseGPU = ProjectionBackendRenderPlan.validateLogicalScalar( ...
                plan.UseGPU, "UseGPU");
            if isempty(plan.Layers) || ~isstruct(plan.Layers) || ...
                    numel(plan.Layers) ~= numel(plan.LayerIndices)
                error("ProjectionBackendRenderPlan:invalidPlan", ...
                    "Plan layers must match LayerIndices.");
            end
            requiredLayerFields = ["LayerIndex", "Plane", "Mesh", ...
                "SampledImage", "SourceImage", "BandCount", ...
                "InterpolantTemplate", "InverseWarp", ...
                "Alpha", "Visible", "BlendMode"];
            if any(~isfield(plan.Layers, requiredLayerFields)) || ...
                    ~all(arrayfun(@(value) isa( ...
                    value.InterpolantTemplate, "scatteredInterpolant"), ...
                    plan.Layers))
                error("ProjectionBackendRenderPlan:invalidPlan", ...
                    "Each plan layer must contain prepared mesh and interpolation data.");
            end
            if ~isequal(double([plan.Layers.LayerIndex]), ...
                    double(plan.LayerIndices))
                error("ProjectionBackendRenderPlan:invalidPlan", ...
                    "Plan layer indices are inconsistent.");
            end
            numericalMode = ProjectionBackendRenderPlan.validateNumericalMode( ...
                plan.NumericalMode);
            for layerIndex = 1:numel(plan.Layers)
                if numericalMode == "fullSourceInverseWarp"
                    ProjectionFullSourceInverseWarp.validate( ...
                        plan.Layers(layerIndex).InverseWarp);
                    if isempty(plan.Layers(layerIndex).SourceImage)
                        error("ProjectionBackendRenderPlan:invalidPlan", ...
                            "Full-source plan layers must retain source imagery.");
                    end
                elseif isempty(plan.Layers(layerIndex).SampledImage)
                    error("ProjectionBackendRenderPlan:invalidPlan", ...
                        "Sparse-reference plan layers must retain sampled imagery.");
                end
            end
            requiredPreparationFields = ["MeshBuildCount", ...
                "CompileMeshBuildCount", "ReusedMeshCount", ...
                "TopologyBuildCount", "GpuResolutionCount", "CompileSeconds"];
            if ~isstruct(plan.Preparation) || ~isscalar(plan.Preparation) || ...
                    any(~isfield(plan.Preparation, requiredPreparationFields))
                error("ProjectionBackendRenderPlan:invalidPlan", ...
                    "Plan preparation diagnostics are incomplete.");
            end
        end

        function summary = summary(plan)
            %summary Return JSON-safe render-plan metadata.
            plan = ProjectionBackendRenderPlan.validate(plan);
            summary = struct();
            summary.Format = plan.Format;
            summary.Version = plan.Version;
            summary.RuntimeOnly = plan.RuntimeOnly;
            summary.NumericalMode = plan.NumericalMode;
            summary.LayerIndices = plan.LayerIndices;
            summary.LayerCount = numel(plan.LayerIndices);
            summary.OutputSize = plan.OutputSize;
            summary.Interpolation = plan.Interpolation;
            summary.IncludeLayerReadbacks = plan.IncludeLayerReadbacks;
            summary.UseGPU = plan.UseGPU;
            summary.GpuInfo = plan.GpuInfo;
            summary.MeshBuildCount = plan.Preparation.MeshBuildCount;
            summary.CompileMeshBuildCount = ...
                plan.Preparation.CompileMeshBuildCount;
            summary.ReusedMeshCount = plan.Preparation.ReusedMeshCount;
            summary.TopologyBuildCount = plan.Preparation.TopologyBuildCount;
            summary.GpuResolutionCount = plan.Preparation.GpuResolutionCount;
            summary.CompileSeconds = plan.Preparation.CompileSeconds;
        end
    end

    methods (Static, Access = private)
        function validateScene(scene)
            requiredFields = ["frameCamera", "renderOrigin", "layers"];
            if ~isstruct(scene) || ~isscalar(scene) || ...
                    any(~isfield(scene, requiredFields)) || ...
                    isempty(scene.layers) || ~isstruct(scene.layers)
                error("ProjectionBackendRenderPlan:invalidScene", ...
                    "Scene must contain frameCamera, renderOrigin, and layers.");
            end
            PlanarProjection.validateCamera(scene.frameCamera);
        end

        function indices = visibleLayerIndices(layers)
            if ~all(isfield(layers, "Visible"))
                error("ProjectionBackendRenderPlan:invalidScene", ...
                    "Scene layers must contain Visible flags.");
            end
            indices = find([layers.Visible]);
            if isempty(indices)
                error("ProjectionBackendRenderPlan:noVisibleLayer", ...
                    "At least one scene layer must be visible.");
            end
        end

        function options = mergeOptions(options, firstLayer)
            if isempty(options)
                options = struct();
            end
            if ~isstruct(options) || ~isscalar(options)
                error("ProjectionBackendRenderPlan:invalidOptions", ...
                    "Options must be a scalar struct.");
            end
            defaults = struct();
            defaults.OutputSize = [numel(firstLayer.MeshSampling.RowIndices), ...
                numel(firstLayer.MeshSampling.ColumnIndices)];
            defaults.OutputGrid = [];
            defaults.Interpolation = "bilinear";
            defaults.InvalidFillValue = NaN;
            defaults.IncludeLayerReadbacks = true;
            defaults.UseGPU = false;
            defaults.NumericalMode = "fullSourceInverseWarp";
            names = fieldnames(defaults);
            for k = 1:numel(names)
                if isfield(options, names{k})
                    defaults.(names{k}) = options.(names{k});
                end
            end
            defaults.OutputGrid = ProjectionBackendRenderPlan.validateOutputGrid( ...
                defaults.OutputGrid);
            if ~isempty(defaults.OutputGrid)
                defaults.OutputSize = defaults.OutputGrid.OutputSize;
            end
            defaults.OutputSize = ProjectionBackendRenderPlan.validateOutputSize( ...
                defaults.OutputSize, "OutputSize");
            defaults.Interpolation = ...
                ProjectionBackendRenderPlan.validateInterpolation( ...
                defaults.Interpolation);
            if ~isnumeric(defaults.InvalidFillValue) || ...
                    ~isscalar(defaults.InvalidFillValue)
                error("ProjectionBackendRenderPlan:invalidOptions", ...
                    "InvalidFillValue must be a numeric scalar.");
            end
            defaults.InvalidFillValue = double(defaults.InvalidFillValue);
            defaults.IncludeLayerReadbacks = ...
                ProjectionBackendRenderPlan.validateLogicalScalar( ...
                defaults.IncludeLayerReadbacks, "IncludeLayerReadbacks");
            defaults.UseGPU = ProjectionBackendRenderPlan.validateLogicalScalar( ...
                defaults.UseGPU, "UseGPU");
            defaults.NumericalMode = ...
                ProjectionBackendRenderPlan.validateNumericalMode( ...
                defaults.NumericalMode);
            options = defaults;
        end

        function outputGrid = validateOutputGrid(outputGrid)
            if isempty(outputGrid)
                return
            end
            requiredFields = ["OutputSize", "Bounds", "Origin", "XAxis", "YAxis"];
            if ~isstruct(outputGrid) || ~isscalar(outputGrid) || ...
                    any(~isfield(outputGrid, requiredFields))
                error("ProjectionBackendRenderPlan:invalidOptions", ...
                    "OutputGrid must be a scalar output-grid struct.");
            end
            outputGrid.OutputSize = ProjectionBackendRenderPlan.validateOutputSize( ...
                outputGrid.OutputSize, "OutputGrid.OutputSize");
        end

        function interpolation = validateInterpolation(interpolation)
            interpolation = lower(string(interpolation));
            if ~isscalar(interpolation) || ...
                    ~ismember(interpolation, ["bilinear", "nearest"])
                error("ProjectionBackendRenderPlan:invalidOptions", ...
                    "Interpolation must be bilinear or nearest.");
            end
        end

        function outputSize = validateOutputSize(outputSize, name)
            if ~isnumeric(outputSize) || ~isvector(outputSize) || ...
                    numel(outputSize) ~= 2 || any(~isfinite(outputSize)) || ...
                    any(outputSize < 1) || any(fix(outputSize) ~= outputSize)
                error("ProjectionBackendRenderPlan:invalidOptions", ...
                    "%s must be a finite positive integer 2-vector.", name);
            end
            outputSize = double(outputSize(:).');
        end

        function value = validateLogicalScalar(value, name)
            if ~(islogical(value) || isnumeric(value)) || ~isscalar(value)
                error("ProjectionBackendRenderPlan:invalidOptions", ...
                    "%s must be a scalar logical value.", name);
            end
            value = logical(value);
        end

        function preparedLayers = validatePreparedLayers( ...
                preparedLayers, layerIndices)
            if isempty(preparedLayers)
                preparedLayers = struct([]);
                return
            end
            requiredFields = ["LayerIndex", "Mesh"];
            if ~isstruct(preparedLayers) || ...
                    any(~isfield(preparedLayers, requiredFields)) || ...
                    ~all(ismember(layerIndices, [preparedLayers.LayerIndex]))
                error("ProjectionBackendRenderPlan:invalidPreparedLayers", ...
                    "Prepared layers must contain a mesh for every visible layer.");
            end
        end

        function [mesh, reused] = layerMesh(layer, plane, renderOrigin, ...
                preparedLayers, layerIndex)
            reused = false;
            if ~isempty(preparedLayers)
                match = find([preparedLayers.LayerIndex] == layerIndex, 1, "first");
                if ~isempty(match)
                    mesh = preparedLayers(match).Mesh;
                    reused = true;
                    return
                end
            end
            mesh = ProjectionMeshBuilder.buildLayerMesh( ...
                layer, plane, renderOrigin);
        end

        function method = scatteredMethod(interpolation)
            if interpolation == "bilinear"
                method = "linear";
            else
                method = "nearest";
            end
        end

        function mode = validateNumericalMode(mode)
            mode = lower(string(mode));
            if ~isscalar(mode)
                error("ProjectionBackendRenderPlan:invalidOptions", ...
                    "NumericalMode must be a scalar string.");
            end
            switch mode
                case "fullsourceinversewarp"
                    mode = "fullSourceInverseWarp";
                case "sparseintensityscatteredinterpolant"
                    mode = "sparseIntensityScatteredInterpolant";
                otherwise
                    error("ProjectionBackendRenderPlan:invalidOptions", ...
                        "NumericalMode must be fullSourceInverseWarp or sparseIntensityScatteredInterpolant.");
            end
        end
    end
end
