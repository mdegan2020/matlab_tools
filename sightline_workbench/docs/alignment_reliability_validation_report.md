# Alignment Reliability Validation Report

## Scope

Reliability Pack 8 consolidates the deterministic oblique-terrain image audit,
solver comparisons, common-anchor checks, and named GUI/backend regressions.
The local environment has no user real-data pair, so this report does not claim
real-data acceptance. It uses the user-approved synthetic construction based on
the red and blue bands of `test_data/10.tif`.

The committed reference run used:

- 1024 x 1024 single-band sensor views;
- 768 x 768 maximum alignment working images;
- 10 km target range and 65 degrees off nadir;
- 3 degrees of azimuth separation and equal elevation;
- a smooth +/-50 m terrain surface;
- full-source inverse-warp alignment radiometry;
- injected OPK `[0.006 -0.003 0.001]` and
  `[-0.004 0.002 -0.001]` degrees;
- exhaustive matching, similarity filtering, and the CPU path.

The run completed in about 19.4 seconds on MATLAB R2026a/macOS before two
additional fast contract cases were added. Machine-specific artifacts remain
ignored; reproduce them with `alignment_reliability_validation`.

## Image-driven results

All installed detectors repeated exactly on unchanged inputs.

| Detector | Raw | Filtered | Terrain p95 (m) |
|---|---:|---:|---:|
| SIFT | 3 | 3 | 3.14 |
| SURF | 4 | 4 | 8.66 |
| ORB | 7 | 7 | 6.38 |
| BRISK | 0 | 0 | n/a |
| KAZE | 64 | 55 | 11.7 |

KAZE supplied the largest filtered set and was selected for the loss matrix.
A 0.01-degree moving-image omega perturbation retained 45/64 raw and 40/55
filtered observations. The stable working-grid key did not change. A central
interquartile ROI retained 13 observations; manually disabling one observation
left 54, safely above both the hard and preferred count thresholds.

The terrain-error table should not be read as a universal detector ranking.
SIFT had the smallest truth p95 but only three observations; KAZE supplied much
more spatial support with a still small error relative to the kilometer-scale
failure seen when the validation fixture was incorrectly undersampled at
384 x 384. The durable runner therefore uses the previously truth-validated
1024/768 schedule, not the quick unit-test schedule.

## Loss and safety results

| Variant | Safety | Bound | Forward-ray RMS before -> after (m) | Observed rank |
|---|---|---:|---:|---:|
| Plane, equal priors | passed | no | 3.30 -> 2.81 | 6/6 |
| Ray 3D, equal priors | failed | yes | 3.30 -> 2.20 | 6/6 |
| Coplanarity, equal priors | passed | no | 3.30 -> 2.85 | 6/6 |
| Plane, unequal priors | passed | no | 3.30 -> 2.81 | 6/6 |
| Plane, fixed reference | passed | no | 3.30 -> 2.87 | 3/3 |

The ray loss found the lowest forward-ray residual but hit a configured bound,
so the unified policy correctly rejected it. This is the intended behavior:
numerical improvement does not override physical bounds. Plane and coplanarity
were actionable on this fixture. The fixed-reference row is retained only as a
comparison control; the default remains to move both images.

## Common-anchor and contract results

The selected accepted anchor converged with approximately
`[0.00099995 0.00099994]` degrees of common omega/phi change and 8.7 micrometers
of plane-target error. Differential OPK and both kappa values were preserved,
forward-ray RMS changed from 3.2965 m to 3.2947 m, and the deliberately
out-of-bounds anchor request was rejected.

The reference run passed all 13 original named contract regressions with no
failures or incomplete tests. The durable matrix now contains 15 cases after
adding explicit pure-differential and shared-bias/weak-common-mode rows. It
covers ROI, layer reorder, curation/undo, common-anchor apply/undo/cancel,
multi-image solving, equal and unequal priors, fixed reference, parallel rays,
degenerate baseline, behind-origin and invalid endpoints, oblique relief, and
serialized backend alignment.

After the durable matrix and documentation were finalized, all 15 named
regressions passed, the alignment-focused suite passed 141/141, and the Pack 8
fresh repository suite passed 383/383 with no failures or incomplete tests.
Dense Surface Pack 1 subsequently raised the repository baseline to 386/386 at
that historical checkpoint without changing the alignment results
or acceptance policy. The maintained repository total is recorded in
`docs/project_status.md`.

## Conclusions And Remaining External Gate

- The staged workflow, balanced solver, epipolar option, safe policy, overlay
  identity, common-anchor interaction, and backend application contracts are
  covered and deterministic on the synthetic suite.
- Full-source inverse warp remains the alignment working-image default and the
  backend radiometry contract. Display pyramids, tiles, and alignment products
  remain analysis/display only.
- The matrix intentionally records failed variants rather than treating every
  solver configuration as expected to pass. Bound-limited ray loss is an
  explainable failure, not a validation-suite failure.
- A representative 100–150 MP primarily single-channel run on the intended
  high-end Windows workstation remains a manual external validation gate. That
  run should record detector/loss settings, every stage count, correction
  split, observed rank, weak modes, bounds, forward-ray residuals, interaction
  responsiveness, and saved/background equivalence. No code default should be
  changed solely from the synthetic detector ranking.
