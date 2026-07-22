function report = runAlgorithmVerticalSlice(options)
%RUNALGORITHMVERTICALSLICE Execute the synthetic geometry/cost diagnostic.
%
% Traceability: algorithm description Secs. 5.1-5.5 and 14.1-14.2;
% Algorithm 1 through unregularized cost-curve inspection.

arguments
    options.Display (1, 1) logical = true
end

root = fileparts(fileparts(mfilename("fullpath")));
src = fullfile(root, "src");
addpath(src);
cleanup = onCleanup(@() rmpath(src));

imageSize = [96, 112];
f = 80;
k = [f, 0, 56.5; 0, f, 48.5; 0, 0, 1];
r = diag([1, -1, -1]);
refCam = PinholeCamera(k, r, [0, 0, 100], imageSize);
movCam = PinholeCamera(k, r, [5, 0, 100], imageSize);
geom = HeightSweepGeometry(refCam, movCam);

[x, y] = meshgrid(1:imageSize(2), 1:imageSize(1));
texture = sin(0.17 .* x + 0.04 .* y) ...
    + 0.65 .* cos(0.07 .* x - 0.13 .* y) ...
    + 0.35 .* sin(0.011 .* x .* y);
texture = (texture - min(texture, [], "all")) ...
    ./ (max(texture, [], "all") - min(texture, [], "all"));
refImage = uint8(round(255 .* texture));
movImage = zeros(imageSize, "uint8");
movImage(:, 1:end-4) = refImage(:, 5:end);

p = [52, 44; 70, 58];
z = -20:2:20;
curve = HeightCostCurve(geom, refImage, movImage, ...
    DerivativeSigma=1, IntegrationSigma=2);
timer = tic;
cost = curve.evaluate(p, z, MinimumSupportFraction=0.95);
seconds = toc(timer);

% Sec. 5.1, Eqs. (52)-(55): report step sensitivity in pixels/metre.
[t1, ~, v1] = geom.heightDerivative(p, 0, DeltaHeight=1);
[t2, kappa, v2] = geom.heightDerivative(p, 0, DeltaHeight=0.5);
tExpected = repmat([-f * 5 / 100 ^ 2, 0], size(p, 1), 1);
e1 = max(abs(t1 - tExpected), [], "all");
e2 = max(abs(t2 - tExpected), [], "all");

report = struct( ...
    "KnownHeight", 0, ...
    "ReferencePixels", p, ...
    "HeightDerivative", t2, ...
    "HeightDerivativeValid", v1 & v2, ...
    "ObservabilityPixelsPerMetre", kappa, ...
    "DerivativeErrorDelta1", e1, ...
    "DerivativeErrorDeltaHalf", e2, ...
    "SelectedHeight", cost.SelectedHeight, ...
    "CostCurve", cost, ...
    "CostSeconds", seconds);

fprintf("Synthetic vertical slice\n");
fprintf("  Known height: %.1f m\n", report.KnownHeight);
fprintf("  Selected [ZNCC point-spin2 T0 T3], first point: " + ...
    "[%.1f %.1f %.1f %.1f] m\n", ...
    report.SelectedHeight.Zncc(1), ...
    report.SelectedHeight.PointSpin2(1), ...
    report.SelectedHeight.Spin2T0(1), ...
    report.SelectedHeight.Spin2T3(1));
fprintf("  Observability: %.6f pixels/m\n", kappa(1));
fprintf("  dw/dZ max error: %.3e (delta 1 m), %.3e (delta 0.5 m)\n", ...
    e1, e2);
fprintf("  Sparse cost runtime: %.3f s\n", seconds);

if options.Display
    figure(Name="Algorithm vertical-slice cost curves");
    plot(z, cost.Costs.Zncc(1, :), "-o", ...
        z, cost.Costs.PointSpin2(1, :), "-s", ...
        z, cost.Costs.Spin2T0(1, :), "-^", ...
        z, cost.Costs.Spin2T3(1, :), "-d", LineWidth=1.2);
    grid on;
    xlabel("Elevation Z (m)");
    ylabel("Unregularized cost");
    title("Synthetic height cost curves at the first reference point");
    legend("ZNCC", "Point spin-2", "T0 scalar q_2", ...
        "T3 transported q_2", Location="best");
end

clear cleanup
end
