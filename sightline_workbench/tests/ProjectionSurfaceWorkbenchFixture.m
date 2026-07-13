classdef ProjectionSurfaceWorkbenchFixture
    %ProjectionSurfaceWorkbenchFixture Compact B6 catalog and UI fixtures.

    methods (Static)
        function catalog = catalog()
            request = ProjectionSurfaceWorkbenchFixture.request();
            hard = ProjectionHardVoxelFusion().fuse(request);
            catalog = ProjectionSurfaceProductCatalog.create( ...
                request.PointSet, {hard}, ...
                ProjectionSurfaceWorkbenchFixture.optionalProducts(request));
        end

        function catalog = catalogWithGaussian()
            request = ProjectionSurfaceWorkbenchFixture.request();
            hard = ProjectionHardVoxelFusion().fuse(request);
            gaussian = ProjectionGaussianSplatFusion().fuse(request);
            catalog = ProjectionSurfaceProductCatalog.create( ...
                request.PointSet, {hard, gaussian}, ...
                ProjectionSurfaceWorkbenchFixture.optionalProducts(request));
        end

        function request = request()
            request = ProjectionSurfaceFusionFixture.request();
            for index = 1:4
                request.PointSet.Points(index). ...
                    CovarianceWorldMetersSquared = 0.01 * eye(3);
                request.PointSet.Points(index). ...
                    PrincipalAxisSigmasMeters = sqrt(0.01) * ones(1, 3);
            end
        end

        function ids = availableIds(catalog)
            available = string({catalog.Products.Status}) == "available";
            ids = string({catalog.Products(available).ProductId});
        end

        function payloads = colorPayloads(model)
            modes = ProjectionSurfaceWorkbenchModel.colorModes();
            payloads = cell(1, numel(modes));
            for index = 1:numel(modes)
                payloads{index} = model.payload("robust-multi-view", modes(index));
            end
        end

        function tf = hasRuntimeHandle(value)
            if isa(value, "function_handle") || ...
                    (isobject(value) && isa(value, "handle")) || isjava(value)
                tf = true;
            elseif isstruct(value)
                tf = false;
                fields = fieldnames(value);
                for element = 1:numel(value)
                    for index = 1:numel(fields)
                        if ProjectionSurfaceWorkbenchFixture.hasRuntimeHandle( ...
                                value(element).(fields{index}))
                            tf = true;
                            return
                        end
                    end
                end
            elseif iscell(value)
                tf = false;
                for index = 1:numel(value)
                    if ProjectionSurfaceWorkbenchFixture. ...
                            hasRuntimeHandle(value{index})
                        tf = true;
                        return
                    end
                end
            else
                tf = false;
            end
        end
    end

    methods (Static, Access = private)
        function products = optionalProducts(request)
            base = request.PointSet.Points(1).PointWorld;
            vertices = base + [0 1 1 0; 0 0 1 1; 0 0 0 0];
            mesh = ProjectionSurfaceProductCatalog.meshProduct( ...
                "mesh-demo", "Fixture triangle mesh", "mesh", ...
                "diagnosticDerived", vertices, [1 2 3; 1 3 4], ...
                ["mesh-1" "mesh-2" "mesh-3" "mesh-4"]);
            [x, y] = meshgrid([base(1) base(1) + 1], ...
                [base(2) base(2) + 1]);
            z = base(3) + [0 0.1; 0.2 0.3];
            grid = ProjectionSurfaceProductCatalog.gridProduct( ...
                "grid-demo", "Fixture elevation grid", "grid", ...
                "diagnosticDerived", x, y, z, true(2));
            products = [mesh grid];
        end
    end
end
