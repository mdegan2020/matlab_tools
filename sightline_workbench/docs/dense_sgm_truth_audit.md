# B0 SGM Truth Audit

Status: complete. The existing `ProjectionDenseSurfaceExtractor` remains a
supported baseline for bounded, textured, well-rectified pairs. The evidence
does not support an automatic `Best` matcher or using SGM alone for general
cross-band, weak-texture, misrectified, or occlusion-heavy imagery.

## Audit Contract

`ProjectionDenseSgmTruthAudit` runs an 11-case public deterministic matrix
through the existing SGM extractor. It covers near/far range, several
intersection angles, constant and two-level relief, explicit occlusion,
same-band and cross-band radiometry, pointing-only and geometry-biased reported
navigation, vertical rectification error, random/repetitive/low texture,
multiple disparity magnitudes, CPU execution, and a capability-checked GPU
request.

Truth disparity, height, and correspondence state are generated separately and
are used only after matching. They are not placed in the scene, working-image,
sparse-match, or dense-extractor inputs. Audit reports contain no image arrays.
Optional evidence persistence writes one compact MAT report and one JSON report.

Every case records:

- mutually supported candidate count and completeness;
- median, p95, and maximum absolute disparity error;
- gross-outlier rate at the documented one-pixel audit threshold;
- height RMS and p95 absolute error;
- forward/backward consistency count, fraction, and p95 error;
- truth-occlusion count and false-valid rate;
- SGM and total runtime, result memory, requested/actual execution, and GPU
  capability/fallback; and
- actual intersection angle, relief, and truth disparity range.

Confidence is not calibrated, thresholds are evidence descriptors rather than
product gates, and `AutomaticBestMatcherSelected` remains false.

## Public Baseline Evidence

The July 13, 2026 CPU baseline produced the following representative values.
Runtime and memory remain in each machine-readable record because they vary by
host.

| Case | Complete | Gross outliers | Disparity p95 (px) | Height p95 (m) | LR consistent | Occlusion false-valid |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| nominal | 0.900 | 0.029 | 0.142 | 0.762 | 1.000 | n/a |
| far/small angle | 0.885 | 0.029 | 0.142 | 3.236 | 1.000 | n/a |
| wider angle | 0.926 | 0.046 | 0.227 | 0.380 | 1.000 | n/a |
| relief plus occlusion | 0.864 | 0.066 | 2.000 | 4.845 | 0.990 | 0.779 |
| cross-band | 0.688 | 1.000 | 10.018 | 50.000 | 0.781 | n/a |
| geometry-biased navigation | 0.900 | 0.029 | 0.142 | 12.233 | 1.000 | n/a |
| two-pixel rectification error | 0.736 | 0.351 | 4.837 | 25.547 | 0.846 | n/a |
| repetitive texture | 0.903 | 0.035 | 0.238 | 1.359 | 0.732 | n/a |
| low texture | 0.903 | 1.000 | 1.969 | 16.321 | 0.005 | n/a |
| larger disparity | 0.962 | 0.029 | 0.147 | 0.197 | 1.000 | n/a |

The current host has no supported MATLAB GPU array device. The GPU-request
case therefore completed on CPU with explicit capability/fallback reporting and
the same numerical result as the nominal CPU case. Target Windows GPU evidence
remains an external gate.

## Interpretation

SGM is a useful baseline when radiometry is comparable, texture is informative,
and rectification is accurate. Range/angle conditioning still changes height
error even when image-space disparity remains accurate. The audit exposes
false-valid occlusion behavior and severe cross-band, weak-texture, and
rectification failure modes. Geometry bias can leave image matching apparently
accurate while substantially degrading reconstructed height.

These findings motivate B1/B2: sparse tracks should constrain local search and
the classical matcher should expose texture, uniqueness, bidirectional
consistency, subpixel fit, geometry residual, and explicit no-match/occlusion
states. SGM remains registered as a named adapter; it is not silently selected
as universally best.

## Usage

```matlab
report = ProjectionDenseSgmTruthAudit.runRepeatable();

report = ProjectionDenseSgmTruthAudit.runRepeatable([], struct( ...
    WriteArtifacts=true, ...
    OutputDirectory="artifacts/dense_sgm_truth_audit"));
```

`ProjectionDenseSgmTruthAuditTest` verifies dimension coverage, nominal
metrics, known degradation modes, occlusion reporting, capability-checked GPU
requests, exact nonvolatile repeatability, and compact image-free artifacts.
