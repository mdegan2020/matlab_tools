function report = runPhaseAOrientationMatrix(options)
%RUNPHASEAORIENTATIONMATRIX Validate look azimuth and relative camera roll.
%
% The horizontal Z=0 plane is evaluated at multiple ENU look azimuths and
% moving-camera rolls. Roll is an image-plane rotation about the forward axis;
% it does not change center-ray obliquity or convergence.
%
% Traceability: algorithm description Secs. 2.1, 5.1-5.2, and 14.1;
% coordinate invariants and the Stage 0 synthetic-geometry roadmap.

arguments
    options.LookAzimuthDegrees (1, :) double {mustBeFinite} = [0, 45, 90, 135]
    options.MovingRollDegrees (1, :) double {mustBeFinite} = [-2, 0, 2]
    options.ImageSize (1, 2) double ...
        {mustBeFinite, mustBeInteger, mustBePositive} = [512, 512]
    options.Display (1, 1) logical = true
end

root = fileparts(fileparts(mfilename("fullpath")));
src = fullfile(root, "src");
oldPath = path;
addpath(src);
cleanup = onCleanup(@() path(oldPath));

[az, roll] = ndgrid( ...
    options.LookAzimuthDegrees, options.MovingRollDegrees);
az = az(:);
roll = roll(:);
n = numel(az);
p = phaseAOrientationPixels(options.ImageSize);

measuredObliquity = nan(n, 1);
measuredConvergence = nan(n, 1);
medianGsd = nan(n, 1);
medianKappa = nan(n, 1);
insideFraction = nan(n, 1);
maximumWarpError = nan(n, 1);
maximumJacobianError = nan(n, 1);
maximumHeightDerivativeError = nan(n, 1);

timer = tic;
for k = 1:n
    id = "orientation_a" + string(az(k)) + "_r" + string(roll(k));
    renderer = SyntheticPinholeRenderer( ...
        id, options.ImageSize, LookAzimuthDegrees=az(k), ...
        ReferenceRollDegrees=0, MovingRollDegrees=roll(k), ...
        Supersample=1, PsfSigmaPixels=0);
    geom = HeightSweepGeometry( ...
        renderer.ReferenceCamera, renderer.MovingCamera);

    dr = -renderer.ReferenceCamera.C ...
        ./ norm(renderer.ReferenceCamera.C);
    dm = -renderer.MovingCamera.C ...
        ./ norm(renderer.MovingCamera.C);
    measuredObliquity(k) = 0.5 .* ( ...
        acosd(dot(dr, [0, 0, -1])) + acosd(dot(dm, [0, 0, -1])));
    measuredConvergence(k) = acosd(dot(dr, dm));

    [wt, vt, inside] = PinholePlaneOracle.correspondence( ...
        renderer.ReferenceCamera, renderer.MovingCamera, p, 0);
    [wg, vg] = geom.warp(p, 0);
    maximumWarpError(k) = max( ...
        vecnorm(wg - wt, 2, 2), [], "omitmissing");
    insideFraction(k) = nnz(inside) / numel(inside);

    [ae, vae] = PinholePlaneOracle.warpJacobian( ...
        renderer.ReferenceCamera, renderer.MovingCamera, p, 0);
    [aa, vaa] = geom.warpJacobian(p, 0, DeltaPixel=0.25);
    maximumJacobianError(k) = max( ...
        abs(aa - ae), [], "all", "omitmissing");

    [te, ke, vte] = PinholePlaneOracle.heightDerivative( ...
        renderer.ReferenceCamera, renderer.MovingCamera, p, 0);
    [ta, ~, vta] = geom.heightDerivative(p, 0, DeltaHeight=0.5);
    maximumHeightDerivativeError(k) = max( ...
        abs(ta - te), [], "all", "omitmissing");
    medianKappa(k) = median(ke(vte));

    [~, ~, sg, vs] = PinholePlaneOracle.localSampling( ...
        renderer.ReferenceCamera, p, 0);
    medianGsd(k) = median(sg(vs));
    if ~all(vt & vg & vae & vaa & vte & vta)
        error("runPhaseAOrientationMatrix:InvalidContractedSample", ...
            "A contracted azimuth/roll sample was geometrically invalid.");
    end
end
seconds = toc(timer);

results = table(az, roll, measuredObliquity, measuredConvergence, ...
    medianGsd, medianKappa, insideFraction, maximumWarpError, ...
    maximumJacobianError, maximumHeightDerivativeError, ...
    VariableNames=["LookAzimuthDegrees", "MovingRollDegrees", ...
    "MeasuredMeanObliquityDegrees", "MeasuredConvergenceDegrees", ...
    "MedianGsdMetresPerPixel", "MedianObservabilityPixelsPerMetre", ...
    "InsideMovingImageFraction", "MaximumOracleWarpErrorPixels", ...
    "MaximumJacobianError", "MaximumDwDzErrorDeltaHalf"]);
summary = struct( ...
    "Cases", height(results), ...
    "MinimumInsideMovingImageFraction", min(insideFraction), ...
    "MaximumOracleWarpErrorPixels", max(maximumWarpError), ...
    "MaximumJacobianError", max(maximumJacobianError), ...
    "MaximumDwDzErrorDeltaHalf", max(maximumHeightDerivativeError), ...
    "Seconds", seconds);
report = struct("Results", results, "Summary", summary, ...
    "ImageSize", options.ImageSize, "SamplePixels", p);

fprintf("Phase A orientation matrix: %d cases\n", height(results));
fprintf("  Minimum moving-image sample fraction: %.6f\n", ...
    summary.MinimumInsideMovingImageFraction);
fprintf("  Max oracle/geometry EPE: %.3e pixels\n", ...
    summary.MaximumOracleWarpErrorPixels);
fprintf("  Max dw/dp error: %.3e\n", summary.MaximumJacobianError);
fprintf("  Max dw/dZ error at 0.5 m: %.3e\n", ...
    summary.MaximumDwDzErrorDeltaHalf);
fprintf("  Runtime: %.3f s\n", seconds);
if options.Display
    disp(results);
end

clear cleanup
end

function p = phaseAOrientationPixels(imageSize)
x = linspace(0.15 * imageSize(2), 0.85 * imageSize(2), 5);
y = linspace(0.15 * imageSize(1), 0.85 * imageSize(1), 5);
[xx, yy] = meshgrid(x, y);
p = [xx(:), yy(:)];
end
