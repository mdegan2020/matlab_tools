function [app, loaded] = openSurfaceWorkbenchRun(path, options)
%openSurfaceWorkbenchRun Validate and reopen a saved Surface Workbench MAT file.
if nargin < 1 || strlength(string(path)) == 0
    [file, folder] = uigetfile("*.mat", "Open saved Surface Workbench run");
    if isequal(file, 0)
        app = [];
        loaded = struct();
        return
    end
    path = fullfile(folder, file);
end
if nargin < 2
    options = struct();
end
loaded = ProjectionSurfaceRun.read(path, options);
app = ProjectionSurfaceWorkbenchApp(loaded.Catalog);
if nargout == 0
    clear app loaded
end
end
