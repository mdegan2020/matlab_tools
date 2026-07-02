function validation = validateProjectionBackendJob(jobInput)
%validateProjectionBackendJob Validate a backend job without rendering.

projectRoot = fileparts(mfilename("fullpath"));
addpath(fullfile(projectRoot, "src"));

if nargin < 1
    error("validateProjectionBackendJob:missingInput", ...
        "A backend job struct, JSON path, or MAT path is required.");
end

validation = ProjectionBackendProcessor.validate(jobInput);

if nargout == 0
    fprintf("%s\n", validation.Message);
    fprintf("OutputSize: %d x %d\n", validation.OutputGrid.OutputSize);
    fprintf("Execution.Mode: %s\n", validation.Execution.Mode);
    clear validation
end
end
