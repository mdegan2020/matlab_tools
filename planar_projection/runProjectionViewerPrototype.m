function app = runProjectionViewerPrototype(imagePath)
%runProjectionViewerPrototype Launch the programmatic projection viewer app.

projectRoot = fileparts(mfilename("fullpath"));
addpath(fullfile(projectRoot, "src"));

if nargin < 1 || strlength(string(imagePath)) == 0
    scene = ProjectionViewerHarness.createDefaultScene();
else
    scene = ProjectionViewerHarness.createDefaultScene(imagePath);
end

app = ProjectionViewerApp(scene);
if nargout == 0
    clear app
end
end
