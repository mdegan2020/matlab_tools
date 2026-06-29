function results = runTests(varargin)
%runTests Run the PlanarProjection MATLAB unit test suite.

projectRoot = fileparts(mfilename("fullpath"));
addpath(fullfile(projectRoot, "src"));

results = runtests(fullfile(projectRoot, "tests"), ...
    "IncludeSubfolders", true, "Strict", true, varargin{:});

disp(table(results));
assertSuccess(results);
end
