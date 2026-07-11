# Alignment Operator Guide

This guide describes the staged alignment workflow for two-image and small
multi-image planar-projection scenes. Alignment analysis may use bounded
single-band working images, but final viewer state and backend rendering always
retain full source imagery and the ordinary source-ray inverse warp.

## Recommended workflow

1. Load the scene, set a useful projection plane, and make the layers to align
   visible. Open **Alignment panel** from the viewport context menu, then open
   the separate **Alignment Workbench**.
2. Choose the moving and reference layers for a pair, or choose visible-layer
   scope for a scheduled network. “Reference” defines pair direction and
   scheduling; it is not assumed to be absolute truth. Keep **Move reference**
   enabled unless deliberately comparing with a fixed-reference solve.
3. Start with the **Quality** preset and the default projection-plane loss.
   Click **Match**, inspect raw matches, then click **Filter**. Match and Filter
   are separate so filter settings, ROI, and curation can be changed without
   rerunning feature extraction.
4. Inspect accepted and faint rejected overlays before solving. A large raw to
   filtered drop is a diagnostic, not evidence that every rejected observation
   is wrong. Compare the geometric and optional coplanarity filter, inspect
   invalid endpoints, and use an ROI only when the scene contains a known
   irrelevant or corrupt region.
5. Click **Solve**. Review the correction split, forward-ray RMS, bound status,
   observed rank, and weak modes. Fewer than three matches per enabled pair is
   a hard stop. Three through nine is a visible warning; ten or more is the
   current preferred count. Every parameter-bound hit is a hard failure.
6. Use **Preview** before **Apply**. If residuals or overlays identify a bad
   correspondence, select its overlay or table row, disable/delete it, and
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
its display-only tiled pyramid while alignment uses bounded working images.
Keep the provisional 1024-pixel display tile side unless a representative
Windows benchmark supports changing it. Neither display tiles nor alignment
working images enter backend output. CPU execution remains required; GPU is
optional, and any backend parallel pool must be `parpool("threads")`.

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

