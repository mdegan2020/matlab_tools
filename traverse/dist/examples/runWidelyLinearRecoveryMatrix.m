function report = runWidelyLinearRecoveryMatrix(options)
%RUNWIDELYLINEARRECOVERYMATRIX Controlled affine patch recovery experiment.
%
% Known real Jacobians are converted to the exact complex coefficients in
% gR=a*gM+b*conj(gM). Orientation separation and noise are swept independently.
% Traceability: algo/main.tex Sec. 7.5 and Eqs. (86)-(95).

arguments
    options.Display (1, 1) logical = true
end

root = fileparts(fileparts(mfilename("fullpath")));
oldPath = path;
addpath(fullfile(root, "src"));
cleanup = onCleanup(@() path(oldPath));

transformNames = ["identity", "rotation-scale", "anisotropic", "shear"];
jacobian = zeros(4, 2, 2);
jacobian(1, :, :) = eye(2);
r15 = [cosd(15), -sind(15); sind(15), cosd(15)];
r25 = [cosd(25), -sind(25); sind(25), cosd(25)];
jacobian(2, :, :) = 1.2 .* r15;
jacobian(3, :, :) = r25 * diag([1.3, 0.8]) * r25.';
jacobian(4, :, :) = [1, 0.25; 0.10, 1.1];
separation = [0, 1, 5, 15, 45, 90];
noise = [0, 0.01];
gain = 1.3;
n = numel(transformNames) * numel(separation) * numel(noise);

name = strings(n, 1);
orientationSeparationDegrees = nan(n, 1);
noiseFraction = nan(n, 1);
trueA = complex(nan(n, 1));
trueB = complex(nan(n, 1));
trueMu = complex(nan(n, 1));
estimatedA = complex(nan(n, 1));
estimatedB = complex(nan(n, 1));
estimatedMu = complex(nan(n, 1));
aError = nan(n, 1);
bError = nan(n, 1);
muError = nan(n, 1);
conditionNumber = nan(n, 1);
designRank = nan(n, 1);
fullResidualCost = nan(n, 1);
deltaCost = nan(n, 1);
fitValid = false(n, 1);
physicalValid = false(n, 1);
stream = RandStream("mt19937ar", Seed=20260718);

row = 0;
for i = 1:numel(transformNames)
    aij = reshape(jacobian(i, :, :), 1, 2, 2);
    [fz, fb] = HeightSweepGeometry.toWirtinger(aij);
    at = gain .* conj(fz);
    bt = gain .* fb;
    mut = bt ./ conj(at);
    for j = 1:numel(separation)
        x = recoveryGradients(separation(j));
        y0 = at .* x + bt .* conj(x);
        for k = 1:numel(noise)
            row = row + 1;
            sigma = noise(k) .* sqrt(mean(abs(y0) .^ 2));
            e = sigma ./ sqrt(2) .* complex( ...
                randn(stream, size(y0)), randn(stream, size(y0)));
            fit = WidelyLinearPatchModel.fit( ...
                y0 + e, x, LambdaA=0, LambdaB=0);
            name(row) = transformNames(i);
            orientationSeparationDegrees(row) = separation(j);
            noiseFraction(row) = noise(k);
            trueA(row) = at;
            trueB(row) = bt;
            trueMu(row) = mut;
            estimatedA(row) = fit.A;
            estimatedB(row) = fit.B;
            estimatedMu(row) = fit.Mu;
            aError(row) = abs(fit.A - at);
            bError(row) = abs(fit.B - bt);
            muError(row) = abs(fit.Mu - mut);
            conditionNumber(row) = fit.ConditionNumber;
            designRank(row) = fit.DesignRank;
            fullResidualCost(row) = fit.FullResidualCost;
            deltaCost(row) = fit.DeltaCost;
            fitValid(row) = fit.FitValid;
            physicalValid(row) = fit.PhysicalValid;
        end
    end
end

results = table(name, orientationSeparationDegrees, noiseFraction, ...
    trueA, trueB, trueMu, estimatedA, estimatedB, estimatedMu, ...
    aError, bError, muError, conditionNumber, designRank, ...
    fullResidualCost, deltaCost, fitValid, physicalValid);
cleanDiverse = noiseFraction == 0 & orientationSeparationDegrees >= 15;
noisyDiverse = noiseFraction > 0 & orientationSeparationDegrees >= 15;
summary = struct( ...
    "Cases", height(results), ...
    "SingleOrientationInvalidFraction", mean( ...
    ~fitValid(orientationSeparationDegrees == 0)), ...
    "MaximumCleanAError", max(aError(cleanDiverse), [], "omitmissing"), ...
    "MaximumCleanBError", max(bError(cleanDiverse), [], "omitmissing"), ...
    "MaximumCleanMuError", max(muError(cleanDiverse), [], "omitmissing"), ...
    "MaximumNoisyMuError", max(muError(noisyDiverse), [], "omitmissing"), ...
    "MaximumCleanConditionNumber", max( ...
    conditionNumber(cleanDiverse), [], "omitmissing"), ...
    "MinimumNoisyDeltaCost", min(deltaCost(noisyDiverse), [], "omitmissing"));
report = struct("Results", results, "Summary", summary);

fprintf("Widely linear affine recovery matrix: %d cases\n", height(results));
fprintf("  Single-orientation invalid fraction: %.3f\n", ...
    summary.SingleOrientationInvalidFraction);
fprintf("  Max clean diverse errors [a b mu]: [%.3e %.3e %.3e]\n", ...
    summary.MaximumCleanAError, summary.MaximumCleanBError, ...
    summary.MaximumCleanMuError);
fprintf("  Max noisy diverse mu error: %.3e\n", ...
    summary.MaximumNoisyMuError);
fprintf("  Max clean diverse condition number: %.3e\n", ...
    summary.MaximumCleanConditionNumber);
fprintf("  Min noisy diverse Delta C: %.3e\n", ...
    summary.MinimumNoisyDeltaCost);

if options.Display
    showRecoveryConditioning(report);
end

clear cleanup
end

function x = recoveryGradients(separation)
n = 80;
amplitude = linspace(0.5, 1.5, n).';
theta = deg2rad(23 + separation ./ 2 .* (-1) .^ (1:n).');
x = amplitude .* exp(1i .* theta);
end

function showRecoveryConditioning(report)
figure(Name="Widely linear affine recovery");
tiledlayout(1, 2);
nexttile;
hold on;
names = unique(report.Results.name, "stable");
for k = 1:numel(names)
    q = report.Results.name == names(k) & report.Results.noiseFraction == 0;
    semilogy(report.Results.orientationSeparationDegrees(q), ...
        report.Results.conditionNumber(q), "-o", LineWidth=1.1);
end
grid on;
xlabel("Gradient-orientation separation (degrees)");
ylabel("Condition number");
legend(names, Location="best");

nexttile;
hold on;
for k = 1:numel(names)
    q = report.Results.name == names(k) & report.Results.noiseFraction > 0;
    semilogy(report.Results.orientationSeparationDegrees(q), ...
        report.Results.muError(q), "-o", LineWidth=1.1);
end
grid on;
xlabel("Gradient-orientation separation (degrees)");
ylabel("Absolute mu error");
legend(names, Location="best");
end
