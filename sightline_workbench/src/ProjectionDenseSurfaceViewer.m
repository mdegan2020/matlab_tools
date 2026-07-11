classdef ProjectionDenseSurfaceViewer
    %ProjectionDenseSurfaceViewer Show intensity and 3-D dense surface results.

    methods (Static)
        function handles = show(result)
            %show Open one intensity viewer and one surface figure.
            ProjectionDenseSurfaceViewer.validateResult(result);
            intensityViewer = viewer2d();
            intensityViewer.Title = "Dense Surface Intensity";
            intensityViewer.Tag = "ProjectionViewerDenseSurfaceIntensityViewer";
            intensityImage = imageshow(result.Intensity, ...
                Parent=intensityViewer, DisplayRangeMode="data-range");
            intensityImage.Tag = "ProjectionViewerDenseSurfaceIntensityImage";

            surfaceFigure = figure(Name="Dense Stereo Surface", ...
                NumberTitle="off", ...
                Tag="ProjectionViewerDenseSurfaceFigure");
            layout = tiledlayout(surfaceFigure, 1, 1, ...
                Padding="compact", TileSpacing="compact");
            axesHandle = nexttile(layout);
            surfaceData = result.Surface;
            surfaceObject = surf(axesHandle, surfaceData.X, surfaceData.Y, ...
                surfaceData.HeightMeters, surfaceData.Intensity, ...
                EdgeColor="none");
            surfaceObject.Tag = "ProjectionViewerDenseSurfaceObject";
            xlabel(axesHandle, "Projection X (m)");
            ylabel(axesHandle, "Projection Y (m)");
            zlabel(axesHandle, "Height above projection plane (m)");
            title(axesHandle, sprintf("Dense stereo surface (%d valid points)", ...
                nnz(surfaceData.ValidMask)));
            axis(axesHandle, "tight");
            view(axesHandle, 3);
            grid(axesHandle, "on");
            colormap(axesHandle, gray(256));
            colorbar(axesHandle);

            handles = struct(IntensityViewer=intensityViewer, ...
                IntensityImage=intensityImage, SurfaceFigure=surfaceFigure, ...
                SurfaceAxes=axesHandle, SurfaceObject=surfaceObject);
        end
    end

    methods (Static, Access = private)
        function validateResult(result)
            required = ["Format", "Intensity", "Surface"];
            if ~isstruct(result) || ~isscalar(result) || ...
                    any(~isfield(result, required)) || ...
                    string(result.Format) ~= ProjectionDenseSurfaceExtractor.Format
                error("ProjectionDenseSurfaceViewer:invalidResult", ...
                    "Result must come from ProjectionDenseSurfaceExtractor.extract.");
            end
            surfaceRequired = ["X", "Y", "HeightMeters", ...
                "Intensity", "ValidMask"];
            if ~isstruct(result.Surface) || ...
                    any(~isfield(result.Surface, surfaceRequired)) || ...
                    ~isequal(size(result.Surface.X), ...
                    size(result.Surface.HeightMeters)) || ...
                    ~any(result.Surface.ValidMask, "all")
                error("ProjectionDenseSurfaceViewer:emptySurface", ...
                    "Dense surface result contains no valid triangulated points.");
            end
        end
    end
end
