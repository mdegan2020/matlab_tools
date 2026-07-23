# RPC00B Phase B0 Manual Validation

## Scope

This checklist is for the first Windows real-data run of
`runRpc00bHeightTest`. The harness is a normal-label smoke test, not a
production RPC workflow. The three supplied HAE values are range/geometry
anchors `[minimum,expected,maximum]`, not the only executed planes. The harness
measures RPC `||dw/dz||`, generates a normal projected-motion label grid, and
retains the expected height exactly. It preserves each RPC00B TRE in its
original full-resolution coordinates. The recovery build optionally estimates
a symmetric global RPC-3 image correction from capped overview features, runs
the RPC-aware height hierarchy, and selects a native reference ROI. It reports
raw ZNCC, guarded sublabel, and physical-height SGM results separately.
Every direct and hierarchical figure, its interpretation, and the minimum
plain-text evidence to bring back from a private system are documented in
`docs/rpc00b_diagnostic_guide.md`.

The two raster files must each contain the complete pixel grid described by its
TRE. `ReferenceROI=[yStart,yEnd,xStart,xEnd]` may restrict dense processing,
but those bounds are always inclusive one-based locations in the original 1x
reference raster. Reuse the exact same four numbers at every downsampling
factor. Phase B0 does not implement NITF segment mosaicking.
It accepts a single-image-segment NITF or another complete `uint16` raster such
as TIFF. It deliberately rejects a multi-segment NITF. Do not crop a raster and
reuse its full-image TRE; that requires the deferred window-coordinate adapter.

Image Processing Toolbox is required for `nitfread`, `nitfinfo`, and
antialiased `imresize`. Parallel Computing Toolbox is required by the current
threaded path. Computer Vision Toolbox is required only when
`CoarseAdjustment="symmetric-feature"`. The implementation opens only
`parpool("threads")`.

## Prepare local-only inputs

1. Pull the current repository on the Windows machine.
2. Keep images, masks, raw TRE payloads, screenshots, reports, and tuning data
   outside the repository or below an ignored local directory such as
   `test_data/`.
3. Provide one raw 1041-character RPC00B payload file (or a tagged
   `RPC00B01041...` record) for each full raster. A decoded MATLAB structure is
   also accepted, but a payload file is easier to audit remotely.
4. Confirm that the selected image band is `uint16`. A multiband input requires
   an explicit one-based band number. A single-channel input accepts the
   default or band `1`.
5. Prepare optional single-channel masks at native raster size. Zero means
   invalid; nonzero means valid. Mask downsampling is conservative: every
   contributing native sample must be valid.
6. Choose three finite, strictly increasing WGS84 ellipsoidal heights
   `[minimum,expected,maximum]` in metres. The minimum and maximum bound the
   sweep. The expected value is a useful central terrain estimate and is
   included exactly in the generated grid; it need not be the arithmetic
   midpoint. The harness does not expand the supplied interval.

## First coarse run

Replace the paths, bands, heights, downsampling factor, and worker count in this
copyable command:

```matlab
cd("C:\work\oblique-dense-correspondence")
addpath("src", "examples")

report = runRpc00bHeightTest( ...
    ReferenceImage="D:\local_rpc_test\reference.ntf", ...
    MovingImage="D:\local_rpc_test\moving.ntf", ...
    ReferenceTre="D:\local_rpc_test\reference_rpc00b.txt", ...
    MovingTre="D:\local_rpc_test\moving_rpc00b.txt", ...
    HeightRangeHAEMetres=[100,150,225], ...
    TargetProjectedMotionPixels=0.5, ...
    ReferenceBand=1, MovingBand=1, ...
    DownsampleFactor=8, ...
    ExecutionMode="hierarchical", ...
    OverviewDownsampleFactor=24, ...
    CoarseAdjustment="symmetric-feature", ...
    FeatureDownsampleFactor=24, MaximumFeatures=250, ...
    NumWorkers=14, Display=true);
```

For external masks, add:

```matlab
ReferenceMask="D:\local_rpc_test\reference_mask.tif", ...
MovingMask="D:\local_rpc_test\moving_mask.tif", ...
```

Omit `NumWorkers` to use every worker in the active thread pool. Set
`UseParallel=false` only for a serial diagnostic. `Display=false` suppresses
figures only; it does not redirect terminal output or mutate workspace display
settings. `TargetProjectedMotionPixels=0.5` is the frozen P1 fine-grid default;
larger values reduce labels and runtime but increase height quantization.
The explicit factor-24 overview is an exact multiple of terminal factor 8. If
`OverviewDownsampleFactor=0` (the default), the harness chooses a value near 24
that is an integer multiple and at least two times the terminal factor.

To isolate causes, rerun with either:

```matlab
CoarseAdjustment="none"          % hierarchy without feature correction
ExecutionMode="direct"           % original global normal-label sweep
```

## Inspect geometry before matching output

Review these fields first:

```matlab
report.Camera
report.Geometry.PerHeight
report.Geometry.AdjacentMotionMedianPixels
report.Geometry.AdjacentMotionP95Pixels
report.Geometry.MedianDirectionChangeDegrees
report.LabelPolicy
report.CoarseAdjustment
report.Diagnostics
```

Before interpreting a height map, confirm:

- RPC inverse convergence is near one at all three supplied HAE anchors;
- maximum inverse and forward/inverse round-trip residuals are small compared
  with one processed pixel;
- sampled trajectories are geometrically valid and mostly inside the moving
  image;
- `dw/dz` is finite and nonzero over useful parts of the scene;
- `LabelPolicy.MaximumAdjacentMedianProjectedMotionPixels` is no larger than
  the requested target and the label count/cost-volume estimate are practical;
- trajectory direction change is plausible for the pushbroom geometry; and
- the image masks and band selections match the intended data.
- feature residual falls materially without a very small/ill-conditioned
  inlier set; an along-trajectory parameter may remain coupled to height.

An RPC convention, datum, raster/TRE extent, or inversion problem invalidates
the matching result regardless of its visual smoothness.

## Inspect the three separate results

```matlab
report.RawZncc
report.Sublabel
report.FrozenSgm
report.Overview
report.FinePlan
report.Fine.Warnings
report.Alignment
report.Timing
report.Memory
```

Interpretation:

- In hierarchical mode, `Overview` is the scene-wide exact common-grid sweep,
  while `RawZncc`, `Sublabel`, and `FrozenSgm` alias the final adaptive products
  at the requested terminal factor. `FinePlan.FinalTilePlan` records every
  local height vector.
- `RawZncc` is unregularized and remains the first matching evidence to inspect.
- `Sublabel` is a guarded local parabola and is valid only for suitable
  interior-label winners with finite neighbors and positive curvature.
- `FrozenSgm` is the unchanged regularized control. It is not raw matching
  evidence and its penalty may saturate across widely spaced heights.
- A large boundary-winner fraction suggests an inadequate height range, a
  radiometric/occlusion failure, or camera bias; it is not evidence that the
  boundary height is correct.
- Direct mode retains representative `CostCurves.Zncc`; hierarchical mode
  instead retains overview evidence, local raw margins, boundary warnings, and
  expansion maps before SGM.
- The geometry figure shows only the three anchor-plane warps; the cost curves,
  label-use plot, and height products use every generated label.
- In the alignment viewer, agreement is gray; reference-only structure is
  magenta and warped-moving-only structure is green.

The full report intentionally contains processed and derived raster arrays.
`report.Summary` omits TRE coefficients, geographic coordinates, and raster
pixels and is the only object intended for sanitized export.

## Save only sanitized artifacts

```matlab
summary = report.Summary;
save("D:\local_rpc_test\rpc00b_summary.mat", "summary")
writelines(jsonencode(summary), ...
    "D:\local_rpc_test\rpc00b_summary.json")
writetable(summary.GeometryPerHeight, ...
    "D:\local_rpc_test\rpc00b_geometry.csv")
writetable(summary.Timing, ...
    "D:\local_rpc_test\rpc00b_timing.csv", WriteRowNames=true)
exportgraphics(report.Figures.Inputs, ...
    "D:\local_rpc_test\rpc00b_inputs.png", Resolution=150)
exportgraphics(report.Figures.Results, ...
    "D:\local_rpc_test\rpc00b_results.png", Resolution=150)
exportgraphics(report.Figures.Alignment, ...
    "D:\local_rpc_test\rpc00b_alignment.png", Resolution=150)
exportgraphics(report.Figures.Adjustment, ...
    "D:\local_rpc_test\rpc00b_adjustment.png", Resolution=150)
```

Review filenames and screenshots for sensitive content before moving them from
the Windows system. Do not commit the full report, imagery, masks, raw TREs, or
geographic metadata.

## Escalation sequence

If the 8x adjusted hierarchy is plausible, choose one native 1x ROI around
buildings and repeat the identical detector footprint at 8x, 4x, 2x, and 1x:

```matlab
roi = [yStart,yEnd,xStart,xEnd];  % measure once in the native reference
report = runRpc00bHeightTest( ...
    ReferenceImage="D:\local_rpc_test\reference.ntf", ...
    MovingImage="D:\local_rpc_test\moving.ntf", ...
    ReferenceTre="D:\local_rpc_test\reference_rpc00b.txt", ...
    MovingTre="D:\local_rpc_test\moving_rpc00b.txt", ...
    HeightRangeHAEMetres=[100,150,225], ...
    ReferenceBand=1, MovingBand=1, ReferenceROI=roi, ...
    DownsampleFactor=1, ExecutionMode="hierarchical", ...
    OverviewDownsampleFactor=24, ...
    CoarseAdjustment="symmetric-feature", ...
    FeatureDownsampleFactor=24, MaximumFeatures=250, ...
    NumWorkers=14, Display=true);
```

For a 1k-by-1k or 2k-by-2k native ROI, factor 1 evaluates only that reference
footprint while retaining the full moving raster for projected support. Compare
the same building roof and wall edges in raw, refined, and SGM maps to judge
block-like versus melted geometry. The feature correction still uses full-image
overviews, so it remains global and identical across ROI resolution runs.

Classify a failure as one or more of:

- RPC parsing/convention/datum;
- RPC inverse convergence or extrapolation;
- raster/TRE extent mismatch;
- height-label spacing/range;
- radiometry or selected band;
- mask, nodata, occlusion, or out-of-bounds support;
- residual camera pointing/registration bias; or
- time/memory scalability.

Bring only `report.Summary`, sanitized screenshots, and written observations
back to the repository. A clearly classified failure satisfies the scientific
purpose of the first R1 run even when the height surface is inaccurate.
