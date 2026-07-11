function app = runSyntheticAlignmentPrototype(imagePath, options)
%runSyntheticAlignmentPrototype Launch a red/blue synthetic alignment scene.

projectRoot = fileparts(mfilename("fullpath"));
addpath(fullfile(projectRoot, "src"));

if nargin < 2
    options = struct();
end
if nargin < 1
    imagePath = "";
end

scene = ProjectionAlignmentSyntheticHarness.createSceneFromRgbTiff( ...
    imagePath, options);
app = ProjectionViewerApp(scene);

if nargout == 0
    clear app
end
end
