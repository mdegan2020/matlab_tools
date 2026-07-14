# Alignment Operator Guide

This guide describes the staged alignment workflow for two-image and small
multi-image planar-projection scenes. Alignment analysis may use bounded
single-band working images, but final viewer state and backend rendering always
retain full source imagery and the ordinary source-ray inverse warp.

## Current corrective advisories

- RD-1 implements the repository correction for implicit cameras on explicit
  oblique planes, but representative private real-data confirmation remains
  pending. Do not modify the plane, source rays, imagery, or OPK to compensate
  for a presentation concern. Distinct caller-supplied cameras remain
  authoritative. Report any dataset that still appears inverted with its
  corner order, camera side, and plane definition; keep the advisory active
  until representative datasets confirm the convention.
- Visible-layer network solving now reports stage, iteration/function count,
  elapsed time, sensitivity-child progress, and cancellation state. Fast runs
  no sensitivity children, Balanced returns the primary result with sensitivity
  deferred, and Quality runs no more than three leave-one-pair-out children
  within 15 seconds. Exhaustive sensitivity remains an explicit SDK choice.
  Cancelling primary optimization leaves the prior scene/correction state
  authoritative; cancelling optional diagnostics preserves the completed
  primary result for separate review and apply.
- Closing the Alignment Workbench hides it without clearing controls, matches,
  ROI, caches, solve state, or action availability. Reopen to resume the same
  session; use **Reset** only when that state should be discarded.
- A converged correction is classified separately as `passed`, `review`, or
  `rejected`. A marginal improvement or preferred-count warning is reviewable,
  not a failed solve. Review results remain previewable and applicable after a
  confirmation summarizing RMS/objective change, OPK, evidence coverage,
  conditioning/uncertainty, and bounds. Hard-invalid results remain rejected.

### Explicit-plane presentation convention

Name ground corners `LL, LR, UR, UL` in anticlockwise order. Plane `+X` points
from `LL` toward `LR`, plane `+Y` points toward `UL`, and
`VN = VX x VY`. Image row indices increase downward. The camera look vector
`V` points from the camera toward the plane; monitor `+X` points right and
monitor `+Y` points up. For a non-head-on view, monitor up is proportional to
`-sign(VN dot V) * (VN - (VN dot V) * V)` and monitor right is `V x up`.
The stored focal-plane `+X` direction is `up x V`. Reversing an equivalent
plane normal therefore cannot introduce a 180-degree display rotation. A
head-on view falls back deterministically to projected plane `+Y`, then `+X`.
This rule changes presentation only; image rows, source coordinates, rays,
plane geometry, OPK, saved scene data, and backend products remain unchanged.

## Recommended workflow

1. Load the scene, set a useful projection plane, and make the layers to align
   visible. Choose **Alignment Workbench...** from the viewport context menu;
   the separate workbench opens directly or receives focus if already open.
2. Choose the moving and reference layers for a pair, or choose visible-layer
   scope for a scheduled network. “Reference” defines pair direction and
   scheduling; it is not assumed to be absolute truth. Keep **Allow reference
   motion** enabled unless deliberately comparing with a fixed-reference solve.
3. Start with the **Quality** preset and the default projection-plane loss.
   Click **Match**, inspect raw matches, then click **Filter**. Match and Filter
   are separate so filter settings, ROI, and curation can be changed without
   rerunning feature extraction.
4. Inspect accepted and faint rejected overlays before solving. A large raw to
   filtered drop is a diagnostic, not evidence that every rejected observation
   is wrong. Compare the geometric and optional coplanarity filter, inspect
   invalid endpoints, and use an ROI only when the scene contains a known
   irrelevant or corrupt region.
   Working-image features are coarse discovery seeds: the solver preparation
   stage refines eligible survivors in original native-band source patches,
   recomputes physical filtering, and chooses a spatially diverse bounded
   subset. The ledger retains unused accepted records with
   `spatialRedundancy`; this is an audit reason, not a claim that the match is
   false.
5. Click **Solve**. Review the correction split, forward-ray RMS, bound status,
   observed rank, and weak modes. Fewer than three matches per enabled pair is
   a hard stop. Three through nine is a visible warning; ten or more is the
   current preferred count. Every parameter-bound hit is a hard failure.
6. Use **Preview** before **Apply**. Preview, Apply, and Revert are independent:
   Revert becomes available only after this result is previewed or applied. If
   residuals or overlays identify a bad correspondence, select its overlay or
   table row, disable/delete it, and
   solve again. The source observations and curation state are retained.
7. If both images appear coherently displaced despite good relative stereo,
   select an accepted correspondence and use **Shift+left drag** in the main
   viewport. Release performs exact bounded refinement; Esc cancels. This
   moves both images through a common omega/phi correction while preserving
   differential OPK, common kappa, projection offsets, source origins/rays,
   and relief-supported disparity. **Undo** restores the latest curation or
   common-anchor edit.
8. Apply the final result and save viewer state. Solved and manually adjusted
   OPK is serialized normally and is therefore available to background jobs.
   Match history, filter provenance, and manual-drag history remain session
   diagnostics and are not serialized.
9. For an exploratory dense or multi-view product after Preview or Apply, open
   **Surface Workbench...**. Any enabled accepted pair with the hard-minimum
   evidence can enable the action. The default selects all eligible views,
   passes, and pairs, **All quality pairs**, and robust multi-view processing;
   **Selected pair** remains an explicit fast diagnostic. Treat products as
   runtime analysis only: they are not serialized or used by backend rendering.

The Workbench is organized from top to bottom as Setup and matching inputs,
Filter and Solve settings, the left-to-right staged workflow, Pair Schedule,
Match Ledger, and Stage status/diagnostics. Overlay visibility and curation
controls share the workflow region; selecting an overlay or ledger row keeps
the other view synchronized.

`ProjectionOffsetMeters` and WASD remain projection-plane registration tools.
They translate intersections after source-ray projection and therefore affect
working-image and overlay plane coordinates. They do not move sensor origins or
change forward-ray or coplanarity metrics. Do not use them as a substitute for
a physical platform-position correction; that requires a separately modeled
source-origin parameter.

## Choosing the loss

- **Projection plane 2D** is the practical default when within-image pointing
  uncertainty or limited stereo support makes a full ray solve noisy. It is
  sensitive to the selected plane, so interpret relief-supported endpoint
  separation rather than expecting every match line to collapse.
- **Forward ray 3D** directly measures closest approach of the two observation
  rays and is physically preferable for oblique terrain. It can expose weak or
  bound-limited modes. A lower residual does not override a bound hit; edit the
  matches or match settings instead.
- **Epipolar coplanarity** uses a baseline-normalized angular residual and is
  useful both as an optional pre-solve filter and as a solve loss. Degenerate
  baselines and invalid rays are reported explicitly.

Every solve reports all three metrics regardless of the optimized loss. The
safe-solve percentage decision always uses post-solve forward-ray 3D RMS, so
changing the optimizer loss does not silently change the physical acceptance
criterion.

## Reading overlays and tables

- Accepted match lines and feature points are on by default.
- Rejected, disabled, deleted, invalid-projection, and other nonaccepted states
  share the same faint diagnostic style for now.
- Worst residuals are the post-solve worst ten percent, rounded up to at least
  one observation.
- Clicking an overlay selects the corresponding table row. Table identity is
  based on stable layer IDs and raw match indices, so layer reorder does not
  move a correspondence to another observation.
- Overlay endpoints are reprojected independently from source row/column
  observations through current geometry. One invalid endpoint cannot push an
  entire pair back to stale working-image coordinates.

## Failure recovery

- **Too few matches:** try Quality, another detector, a less restrictive
  geometric filter, the coplanarity filter by itself, or a focused ROI. Do not
  lower the hard minimum below three.
- **Many visually good rejected matches:** inspect the per-stage counts and
  rejection reason. Independent oblique images do not necessarily share one
  global native-pixel displacement, so that filter is off by default.
- **Bound hit:** treat the solve as failed. Correct false matches, adjust
  feature settings, or—only with physical justification—change the configured
  percentage/FOV-derived bound.
- **Weak or prior-dominated modes:** stereo has not independently determined
  those modes. Compare covariance assumptions, add another useful baseline, or
  use the common-anchor interaction for an explainable absolute-placement edit.
- **Anchor rejected:** reduce the drag, select a better-conditioned match away
  from degenerate geometry, or repair the accepted set. Nonconvergence, weak
  conditioning, bound hits, and material forward-ray degradation all restore
  the exact mouse-down OPK.

## Large-image operation

For 100–150 MP primarily single-channel imagery, the main viewport should use
its display-only tiled pyramid while alignment uses its separate immutable
native-radiometric source-level cache. Analysis LOD follows the measured
source-to-working sampling footprint, not viewport zoom; large reductions are
materialized in bounded aligned regions with normalized validity, and the
full-source coordinate map remains authoritative for refinement and rays.
Keep the provisional 1024-pixel display tile side unless a representative
Windows benchmark supports changing it. Neither display tiles nor alignment
working images enter backend output. CPU execution remains required; GPU is
optional, and any backend parallel pool must be `parpool("threads")`.

## Dense-surface interpretation

Dense Surface Pack 1 uses a common rotation inferred from accepted sparse
parallax, not a fully calibrated rectifier for arbitrary curved pushbroom
epipolar geometry. Inspect sparse vertical RMS, valid point count, ray
separation, disparity support, and the plausibility of height before using the
surface diagnostically. Low texture, occlusion, repetitive content, weak
baseline, or an incomplete sparse disparity range can produce holes or unstable
height. See `docs/dense_surface_feature_pack.md`.

## Reproducible validation report

Run the synthetic Pack 8 matrix from the repository root:

```matlab
addpath("src", "scripts");
[summary, artifacts] = alignment_reliability_validation;
```

The default uses `test_data/10.tif`, a 10 km range, 65-degree off-nadir stereo
pair with 3 degrees of azimuth separation, and a smooth +/-50 m DEM. It writes
JSON, MAT, and CSV reports under the ignored
`artifacts/alignment_reliability_validation` directory. See
`docs/alignment_reliability_validation_report.md` for the committed reference
run and the remaining Windows/manual validation gate.
