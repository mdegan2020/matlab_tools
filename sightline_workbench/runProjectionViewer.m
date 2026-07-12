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
correctionOptions = correctionRuntimeOptions(options);
app = ProjectionViewerApp(scene, [], [], correctionOptions);

if nargout == 0
    clear app
end

function correctionOptions = correctionRuntimeOptions(options)
correctionOptions = struct();
callbackNames = ["CorrectionAcceptedFcn" "CorrectionAppliedFcn" ...
    "CorrectionRevertedFcn"];
for name = callbackNames
    if isfield(options, name)
        correctionOptions.(name) = options.(name);
    end
end
if isfield(options, "CorrectionInitialGenerationId")
    correctionOptions.InitialGenerationId = ...
        options.CorrectionInitialGenerationId;
end
end
end
