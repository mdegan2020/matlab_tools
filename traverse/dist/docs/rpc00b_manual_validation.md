# RPC00B Phase B0 Manual Validation

## Scope

This checklist is for the first Windows real-data run of
`runRpc00bHeightTest`. The harness is a normal-label smoke test, not a
production RPC workflow. The three supplied HAE values are range/geometry
anchors `[minimum,expected,maximum]`, not the only executed planes. The harness
measures RPC `||dw/dz||`, generates a normal projected-motion label grid, and
retains the expected height exactly. It preserves each RPC00B TRE in its
original full-resolution coordinates, optionally antialiases and downsamples
both images by the same scalar integer factor, and reports raw ZNCC, guarded
sublabel, and frozen physical-height SGM results separately.

The two raster files must each contain the complete pixel grid described by its
TRE. Phase B0 does not implement crop/ROI origins or NITF segment mosaicking.
It accepts a single-image-segment NITF or another complete `uint16` raster such
as TIFF. It deliberately rejects a multi-segment NITF. Do not crop a raster and
reuse its full-image TRE; that requires the deferred window-coordinate adapter.

Image Processing Toolbox is required for `nitfread`, `nitfinfo`, and
antialiased `imresize`. Parallel Computing Toolbox is required by the current
threaded path. The implementation opens only `parpool("threads")`.

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

## Inspect geometry before matching output

Review these fields first:

```matlab
report.Camera
report.Geometry.PerHeight
report.Geometry.AdjacentMotionMedianPixels
report.Geometry.AdjacentMotionP95Pixels
report.Geometry.MedianDirectionChangeDegrees
report.LabelPolicy
report.Warnings
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

An RPC convention, datum, raster/TRE extent, or inversion problem invalidates
the matching result regardless of its visual smoothness.

## Inspect the three separate results

```matlab
report.CostCurves
report.RawZncc
report.Sublabel
report.FrozenSgm
report.LabelDiagnostics.SelectionFractions
report.Alignment
report.Timing
report.Memory
```

Interpretation:

- `RawZncc` is the unregularized algorithm output on the complete generated
  height grid. It is the first matching evidence to inspect.
- `Sublabel` is a guarded local parabola and is valid only for suitable
  interior-label winners with finite neighbors and positive curvature.
- `FrozenSgm` is the unchanged regularized control. It is not raw matching
  evidence and its penalty may saturate across widely spaced heights.
- A large boundary-winner fraction suggests an inadequate height range, a
  radiometric/occlusion failure, or camera bias; it is not evidence that the
  boundary height is correct.
- Representative `CostCurves.Zncc` should be inspected before trusting SGM.
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
writetable(summary.SelectionFractions, ...
    "D:\local_rpc_test\rpc00b_labels.csv")
writetable(summary.Timing, ...
    "D:\local_rpc_test\rpc00b_timing.csv", WriteRowNames=true)
exportgraphics(report.Figures.Inputs, ...
    "D:\local_rpc_test\rpc00b_inputs.png", Resolution=150)
exportgraphics(report.Figures.Geometry, ...
    "D:\local_rpc_test\rpc00b_geometry_evidence.png", Resolution=150)
exportgraphics(report.Figures.Results, ...
    "D:\local_rpc_test\rpc00b_results.png", Resolution=150)
exportgraphics(report.Figures.Alignment, ...
    "D:\local_rpc_test\rpc00b_alignment.png", Resolution=150)
```

Review filenames and screenshots for sensitive content before moving them from
the Windows system. Do not commit the full report, imagery, masks, raw TREs, or
geographic metadata.

## Escalation sequence

If the coarse geometry is plausible, decrease `DownsampleFactor` in steps and
repeat. Factor `1` processes the entire full-resolution raster; Phase B0 has no
safe ROI/crop transform. Do not attempt a cropped factor-1 shortcut. If the
full scene is too expensive, record that as an R1 computational result and use
it to prioritize the planned hierarchical/tiled production solver.

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
