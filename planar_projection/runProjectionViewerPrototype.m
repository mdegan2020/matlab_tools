function app = runProjectionViewerPrototype(imagePath, options)
%runProjectionViewerPrototype Launch the projection viewer app for one or more images.

projectRoot = fileparts(mfilename("fullpath"));
addpath(fullfile(projectRoot, "src"));

if nargin < 2
    options = struct();
end
if nargin < 1 || isempty(imagePath) || ...
        ((ischar(imagePath) || isstring(imagePath)) && ...
        isscalar(string(imagePath)) && strlength(string(imagePath)) == 0)
    scene = ProjectionViewerHarness.createDefaultScene("", options);
else
    scene = ProjectionViewerHarness.createDefaultScene(imagePath, options);
end

app = ProjectionViewerApp(scene);
if nargout == 0
    clear app
end
end
