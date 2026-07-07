function app = runProjectionViewer(layerNames, imageDataList, geometryDefinitions, ...
        projectionPlane, options)
%runProjectionViewer Launch the projection viewer for programmatic real data.

projectRoot = fileparts(mfilename("fullpath"));
addpath(fullfile(projectRoot, "src"));

if nargin < 5
    options = ProjectionViewerHarness.realDataOptions();
end

scene = ProjectionViewerHarness.createRealDataScene( ...
    layerNames, imageDataList, geometryDefinitions, projectionPlane, options);
app = ProjectionViewerApp(scene);

if nargout == 0
    clear app
end
end
