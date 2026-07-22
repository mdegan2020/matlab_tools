function report = runPhaseAGeometryMatrix(options)
%RUNPHASEAGEOMETRYMATRIX Validate the contracted Phase A camera matrix.
%
% This diagnostic evaluates the horizontal Z=0 plane without rendering image
% radiometry. Rows span absolute obliquity and center-ray convergence. The
% independent PinholePlaneOracle is compared with HeightSweepGeometry at a
% fixed grid of one-based [x,y] reference pixels.
%
% Traceability: algorithm description Secs. 5.1-5.2, 10.2, 10.5, and 14.1;
% Eqs. (52)-(58) and the Stage 0 geometry/observability roadmap.

arguments
    options.ObliquityDegrees (1, :) double ...
        {mustBeFinite, mustBeNonnegative, ...
        mustBeLessThan(options.ObliquityDegrees, 90)} = [15, 45, 55, 65, 75]
    options.ConvergenceDegrees (1, :) double ...
        {mustBeFinite, mustBePositive, ...
        mustBeLessThan(options.ConvergenceDegrees, 180)} = [0.5, 1, 2, 3, 5, 10]
    options.ImageSize (1, 2) double ...
        {mustBeFinite, mustBeInteger, mustBePositive} = [512, 512]
    options.Display (1, 1) logical = true
end

root = fileparts(fileparts(mfilename("fullpath")));
src = fullfile(root, "src");
oldPath = path;
addpath(src);
cleanup = onCleanup(@() path(oldPath));

[ob, cv] = ndgrid(options.ObliquityDegrees, options.ConvergenceDegrees);
ob = ob(:);
cv = cv(:);
n = numel(ob);
p = phaseAGeometryPixels(options.ImageSize);

meanObliquity = nan(n, 1);
actualConvergence = nan(n, 1);
slantRange = nan(n, 1);
medianGsd = nan(n, 1);
minimumGsd = nan(n, 1);
maximumGsd = nan(n, 1);
minimumKappa = nan(n, 1);
medianKappa = nan(n, 1);
maximumKappa = nan(n, 1);
labelStep = nan(n, 1);
roundTripError = nan(n, 1);
oracleWarpError = nan(n, 1);
jacobianError = nan(n, 1);
heightDerivativeError1 = nan(n, 1);
heightDerivativeErrorHalf = nan(n, 1);
falseValidRate = nan(n, 1);
falseInvalidRate = nan(n, 1);

timer = tic;
for k = 1:n
    id = "geometry_o" + string(ob(k)) + "_c" + string(cv(k));
    renderer = SyntheticPinholeRenderer( ...
        id, options.ImageSize, MeanObliquityDegrees=ob(k), ...
        ConvergenceDegrees=cv(k), Supersample=1, PsfSigmaPixels=0);
    geom = HeightSweepGeometry( ...
        renderer.ReferenceCamera, renderer.MovingCamera);

    dr = -renderer.ReferenceCamera.C ...
        ./ norm(renderer.ReferenceCamera.C);
    dm = -renderer.MovingCamera.C ...
        ./ norm(renderer.MovingCamera.C);
    meanObliquity(k) = 0.5 .* ( ...
        acosd(dot(dr, [0, 0, -1])) + acosd(dot(dm, [0, 0, -1])));
    actualConvergence(k) = acosd(dot(dr, dm));
    slantRange(k) = renderer.SlantRangeMetres;

    [xw, vr] = renderer.ReferenceCamera.imageToWorldAtHeight(p, 0);
    [pr, vp] = renderer.ReferenceCamera.worldToImage(xw);
    roundTripError(k) = max(vecnorm(pr - p, 2, 2), [], "omitmissing");

    [wt, vt, it] = PinholePlaneOracle.correspondence( ...
        renderer.ReferenceCamera, renderer.MovingCamera, p, 0);
    [wg, vg, ig] = geom.warp(p, 0);
    oracleWarpError(k) = max(vecnorm(wg - wt, 2, 2), [], "omitmissing");
    falseValidRate(k) = nnz(ig & ~it) / numel(it);
    falseInvalidRate(k) = nnz(~ig & it) / numel(it);

    [ae, vae] = PinholePlaneOracle.warpJacobian( ...
        renderer.ReferenceCamera, renderer.MovingCamera, p, 0);
    [aa, vaa] = geom.warpJacobian(p, 0, DeltaPixel=0.25);
    jacobianError(k) = max(abs(aa - ae), [], "all", "omitmissing");

    [te, ke, vte] = PinholePlaneOracle.heightDerivative( ...
        renderer.ReferenceCamera, renderer.MovingCamera, p, 0);
    [t1, ~, vt1] = geom.heightDerivative(p, 0, DeltaHeight=1);
    [th, ~, vth] = geom.heightDerivative(p, 0, DeltaHeight=0.5);
    heightDerivativeError1(k) = max( ...
        abs(t1 - te), [], "all", "omitmissing");
    heightDerivativeErrorHalf(k) = max( ...
        abs(th - te), [], "all", "omitmissing");

    [~, ~, gsd, vs] = PinholePlaneOracle.localSampling( ...
        renderer.ReferenceCamera, p, 0);
    gsd = gsd(vs);
    kappa = ke(vte);
    minimumGsd(k) = min(gsd);
    medianGsd(k) = median(gsd);
    maximumGsd(k) = max(gsd);
    minimumKappa(k) = min(kappa);
    medianKappa(k) = median(kappa);
    maximumKappa(k) = max(kappa);
    labelStep(k) = renderer.TargetMotionPerLabelPixels / medianKappa(k);

    finiteGeometry = vr & vp & vt & vg & vae & vaa & vte & vt1 & vth;
    if ~all(finiteGeometry)
        error("runPhaseAGeometryMatrix:InvalidContractedSample", ...
            "A contracted matrix sample was geometrically invalid.");
    end
end
seconds = toc(timer);

results = table(ob, cv, meanObliquity, actualConvergence, slantRange, ...
    minimumGsd, medianGsd, maximumGsd, minimumKappa, medianKappa, ...
    maximumKappa, labelStep, roundTripError, oracleWarpError, ...
    jacobianError, heightDerivativeError1, heightDerivativeErrorHalf, ...
    falseValidRate, falseInvalidRate, VariableNames=[ ...
    "RequestedObliquityDegrees", "RequestedConvergenceDegrees", ...
    "MeasuredMeanObliquityDegrees", "MeasuredConvergenceDegrees", ...
    "SlantRangeMetres", "MinimumGsdMetresPerPixel", ...
    "MedianGsdMetresPerPixel", "MaximumGsdMetresPerPixel", ...
    "MinimumObservabilityPixelsPerMetre", ...
    "MedianObservabilityPixelsPerMetre", ...
    "MaximumObservabilityPixelsPerMetre", "HeightLabelStepMetres", ...
    "MaximumRoundTripErrorPixels", "MaximumOracleWarpErrorPixels", ...
    "MaximumJacobianError", "MaximumDwDzErrorDelta1", ...
    "MaximumDwDzErrorDeltaHalf", "FalseValidRate", "FalseInvalidRate"]);
summary = struct( ...
    "Cases", height(results), ...
    "MaximumRoundTripErrorPixels", max(roundTripError), ...
    "MaximumOracleWarpErrorPixels", max(oracleWarpError), ...
    "MaximumJacobianError", max(jacobianError), ...
    "MaximumDwDzErrorDelta1", max(heightDerivativeError1), ...
    "MaximumDwDzErrorDeltaHalf", max(heightDerivativeErrorHalf), ...
    "MaximumFalseValidRate", max(falseValidRate), ...
    "MaximumFalseInvalidRate", max(falseInvalidRate), ...
    "Seconds", seconds);
report = struct("Results", results, "Summary", summary, ...
    "ImageSize", options.ImageSize, "SamplePixels", p);

fprintf("Phase A geometry matrix: %d cases, %d sample pixels/case\n", ...
    height(results), size(p, 1));
fprintf("  Max round-trip error: %.3e pixels\n", ...
    summary.MaximumRoundTripErrorPixels);
fprintf("  Max oracle/geometry EPE: %.3e pixels\n", ...
    summary.MaximumOracleWarpErrorPixels);
fprintf("  Max dw/dp error: %.3e\n", summary.MaximumJacobianError);
fprintf("  Max dw/dZ error: %.3e (1 m), %.3e (0.5 m)\n", ...
    summary.MaximumDwDzErrorDelta1, summary.MaximumDwDzErrorDeltaHalf);
fprintf("  False-valid %.3e; false-invalid %.3e\n", ...
    summary.MaximumFalseValidRate, summary.MaximumFalseInvalidRate);
fprintf("  Runtime: %.3f s\n", seconds);
if options.Display
    disp(results(:, ["RequestedObliquityDegrees", ...
        "RequestedConvergenceDegrees", "MedianGsdMetresPerPixel", ...
        "MedianObservabilityPixelsPerMetre", "HeightLabelStepMetres"]));
end

clear cleanup
end

function p = phaseAGeometryPixels(imageSize)
x = linspace(0.1 * imageSize(2), 0.9 * imageSize(2), 5);
y = linspace(0.1 * imageSize(1), 0.9 * imageSize(1), 5);
[xx, yy] = meshgrid(x, y);
p = [xx(:), yy(:)];
end
