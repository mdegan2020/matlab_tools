# RPC00B Plot and Diagnostic Guide

## Purpose and scope

This guide explains every figure produced by `runRpc00bHeightTest`, the
conclusions that each panel can support, and the minimum scalar observations
needed to diagnose a remote real-data run when the MATLAB report cannot be
exported. It applies to both `ExecutionMode="direct"` and
`ExecutionMode="hierarchical"`.

The harness is a smoke test of exact RPC height-plane geometry, raw ZNCC,
guarded sublabel refinement, and physical-height SGM. It is not yet a
production RPC workflow. A visually plausible height map is therefore evidence
to investigate, not proof of absolute height accuracy.

All reported heights are WGS84 HAE metres. Image coordinates use one-based
`[x,y]=[sample,line]=[column,row]` pixel centers. The public
`ReferenceROI=[yStart,yEnd,xStart,xEnd]` is always inclusive and expressed in
native 1x reference-image coordinates. Geometry trajectories, `dw/dz`, and
dense correspondence products are expressed in pixels at the processing level
unless a field explicitly says `NativePixels`. Intensity residuals use images
scaled from `uint16` to `[0,1]` and are not geometric pixel residuals.

The complete MATLAB `report` contains derived raster data and, when feature
adjustment is enabled, feature coordinates. Do not export it from the private
system. `report.Summary` is intentionally redaction-safe, but even its image
identifiers and sizes should be reviewed before release. Screenshots can expose
source imagery and require the same review.

## What the three height products are

- **Raw ZNCC HAE** is the unregularized data-term result. Each valid reference
  pixel independently selects the height label having the smallest ZNCC cost.
  The ZNCC cost is `(1-correlation)/2`: zero is perfect positive correlation,
  `0.5` is zero correlation, one is perfect anticorrelation, and lower is
  better.
- **Guarded refined HAE** fits a local parabola through the winning label and
  its two neighbors. It supplies a continuous sublabel height only where the
  discrete winner is interior and the local curve passes the refinement
  guards. It is not an independent matcher.
- **Frozen SGM HAE** minimizes the ZNCC evidence plus the currently fixed
  physical-height smoothness model along four or eight paths. It can suppress
  isolated noise, but it can also propagate a wrong low-cost solution. A smooth
  SGM map is not sufficient evidence that the raw image evidence or camera
  geometry is correct.

The final dense correspondence is obtained by projecting the selected height
through the exact RPC mapping. In direct mode it is available as
`report.FrozenSgmProjection.CorrespondenceXY`; in hierarchical mode it is
`report.FrozenSgm.CorrespondenceXY`.

## Direct mode: four figures

### 1. RPC00B Inputs

This 2-by-3 figure contains:

1. **Native reference** and **Native moving** show the selected `uint16` band
   before ROI selection, downsampling, and `[0,1]` conversion. Confirm the
   intended image pair, band, orientation, and gross overlap. Unexpected flips,
   offsets, black borders, or saturation are ingest problems, not matcher
   behavior.
2. **Processed reference** shows the selected native reference ROI after the
   requested downsampling. **Processed moving** remains the complete moving
   image after downsampling so that projected support is not clipped to a
   reference-shaped crop.
3. **Processed reference valid** and **Processed moving valid** show the masks
   that actually enter matching. White means valid. Downsampled masks require
   effectively complete valid support; detector centers outside a
   non-divisible native extent are also invalid. A spatial failure that follows
   a mask boundary should first be classified as support loss.

Single takeaway: record the native and processed sizes, native 1x ROI, band,
downsampling factor, and whether the bad result follows an input or mask
boundary.

### 2. RPC00B Geometry and Raw Evidence

This 2-by-3 figure contains:

1. **RPC trajectories** plots, for a sparse grid of reference pixels, the
   moving-image position predicted at the minimum, expected, and maximum HAE.
   Each connected three-point trajectory is one reference location, not a
   feature match. Smooth, similarly directed tracks are expected for a narrow
   field-of-view pair. Abruptly different directions, very long tracks, tracks
   leaving the image, or spatially varying curvature indicate difficult
   geometry, extrapolation, or a possible RPC/raster convention problem. The
   plot alone cannot reveal a global pointing bias because all three points may
   be displaced together.
2. **Label policy** plots median displacement from the minimum HAE versus the
   generated labels. The expected HAE is retained exactly. Adjacent labels are
   chosen so their median projected separation does not exceed
   `TargetProjectedMotionPixels`, apart from numerical tolerance. This is a
   median scene policy: high-observability regions may still be under-sampled,
   which is why the P10, median, and P90 `dw/dz` values must also be reported.
3. **Representative unregularized curves** shows raw ZNCC cost versus HAE at
   several sampled reference pixels. A useful curve has a distinct interior
   minimum. A flat curve indicates weak texture or radiometric ambiguity;
   several similar minima indicate repeated texture; a minimum at either end
   suggests an insufficient HAE range, residual camera bias, missing overlap,
   or an uninformative cost. These few curves are diagnostic samples and cannot
   establish scene-wide performance.
4. **Moving warped at minimum, expected, and maximum HAE** uses exact RPC
   plane warps at the three caller-supplied HAE anchors. Compare stable edges in
   the three panels with the processed reference. One anchor should normally be
   visibly closer over broad terrain. No single plane is expected to align a
   scene with substantial relief. A common displacement at all three anchors
   suggests pointing bias; content disappearing at all anchors suggests bounds,
   inversion, mask, or extent problems.

Single takeaway: return the entire `report.Geometry.PerHeight` table, adjacent
median and P95 motion, median direction change, generated label count, and one
sentence describing whether the raw curves have clear interior minima.

### 3. RPC00B Normal-Label Results

This 3-by-4 figure contains:

1. **Raw ZNCC HAE (m)** is the discrete independent-pixel baseline. Coherent
   terrain in this panel is the strongest visual evidence that image evidence
   and RPC geometry agree without regularization. Salt-and-pepper values mean
   the local cost is ambiguous or the correct correspondence is absent.
2. **Guarded refined HAE (m)** is the continuous parabolic refinement. Blank
   pixels are expected at boundary labels, invalid pixels, or failed curvature
   guards. Refinement should add sublabel detail without inventing a new large
   structure.
3. **Frozen SGM HAE (m)** is the regularized result. Compare it with raw ZNCC,
   not only with the source imagery. Structure appearing only after SGM may be
   useful, but it remains prior-driven until supported by raw margins,
   alignment, or independent truth.
4. **SGM - raw height (m)** isolates the regularizer's effect. Large coherent
   differences show where the result is dominated by spatial aggregation.
   Broad changes deserve scrutiny near height discontinuities, occlusions, and
   range boundaries.
5. **Raw cost margin** is the second-smallest finite label cost minus the best
   label cost. Larger is stronger separation; values near zero mean two labels
   are nearly tied. There is no calibrated universal acceptance threshold for
   the RPC data yet. Always interpret the margin beside texture, validity, and
   the height map.
6. **Raw valid** marks pixels with sufficient finite support for a raw label.
   Valid means computable, not correct.
7. **Raw range-boundary winner** marks valid pixels selecting the minimum or
   maximum HAE label. A high or spatially coherent fraction is a critical
   warning. It may mean the true surface is outside the supplied interval, but
   it can also mean residual pointing error, RPC extrapolation, lost overlap,
   repeated texture, or weak radiometry. Do not automatically widen the range
   without checking geometry and anchor warps.
8. **Raw selected label index** shows discrete label structure independent of
   irregular physical spacing around the expected anchor. In direct mode the
   index has one scene-wide meaning. Use the HAE map for physical
   interpretation.
9. **Selected `dw/dz` (px/m)** shows local height observability at the raw
   winning height. Larger values mean one metre of HAE produces more image
   motion and therefore permits finer height discrimination, while also
   requiring denser labels. Values are in processed pixels per metre.
10. **SGM-warped moving** samples the moving image at the final SGM
    correspondence. It should resemble the reference geometrically, subject to
    radiometric and view-dependent differences.
11. **Reference - warped moving** is an intensity residual, not an epipolar or
    reprojection error. Thin paired edges suggest geometric misalignment;
    broad brightness differences may be radiometric; blank areas are invalid.
12. **Height-label use** is the fraction of valid pixels selecting each HAE for
    raw ZNCC and SGM. A large U shape or spikes at both endpoints agree with the
    boundary map and signal a range/geometry/evidence failure. A peak at the
    expected HAE can be plausible, but may also indicate a low-texture default
    and is not proof of correct terrain.

All three height panels use the supplied minimum and maximum HAE as common
color limits. Equal colors are therefore comparable across raw, refined, and
SGM panels.

Single takeaway: report raw and SGM valid fractions, raw and SGM boundary
fractions, guarded-refinement availability, median raw best cost, median raw
cost margin, and the approximate native 1x coordinates of every coherent
failure region.

### 4. RPC00B Selected Alignment

This is a zoomable `viewer2d` display of the reference in magenta and the
SGM-warped moving image in green. Locally aligned equal-intensity content tends
toward gray/white. Magenta-only and green-only paired edges expose residual
displacement. Different spectra, shadows, view-dependent building faces, and
occlusions can remain colored even under correct geometry, so inspect stable
ground edges rather than brightness alone.

Single takeaway: capture one broad view, one successful high-detail region,
and one failed high-detail region at the same zoom. Record the corresponding
native 1x reference coordinates and the alignment valid fraction, normalized
intensity MAE, and normalized intensity RMS.

## Hierarchical mode: four figures

Hierarchical mode replaces one full common label grid with an exact overview
grid followed by per-tile local fine grids and one warning-driven expansion
pass. The three HAE anchors still define the allowed range. A tile is a compute
and label-planning unit; final SGM paths continue across tile seams.

### 1. RPC Hierarchy Inputs

The panels are **Native full reference**, **Native full moving**, **Terminal
reference ROI**, **Terminal full moving**, **Reference ROI valid**, and
**Moving valid**. Their interpretation is the same as the direct input figure.
The explicit full-moving panel is important: the ROI restricts reference
output work, not the moving image support available to the RPC projection.

### 2. RPC Hierarchical Height Results

1. **Overview SGM height** is the coarse scene-wide solution used to plan local
   fine bands. It is not merely a 2-D translation pyramid. Large wrong regions
   here can seed wrong fine intervals.
2. **Fine raw ZNCC height** is independent-pixel selection within each tile's
   local label band. Compare it with the overview to see whether fine evidence
   confirms or overturns the inherited estimate.
3. **Fine guarded sublabel height** has the same interpretation as the direct
   refined result, but uses each tile's local nonuniform band.
4. **Fine seam-continuing SGM height** is the final regularized hierarchical
   surface. SGM paths cross tile boundaries; visible seams are therefore more
   likely to arise from local label-band differences or weak evidence than
   from paths being stopped at a tile edge.
5. **Fine raw second-label margin** has the same definition as the direct cost
   margin. Low-margin regions are ambiguous even if the final SGM map is
   smooth.
6. **Expanded tile bands** is one where the warning logic widened a tile's
   initial fine HAE interval and zero elsewhere. Isolated expansions can be a
   healthy recovery action. Many adjacent expanded tiles, especially over a
   failure band, indicate that the overview estimate, provisional confidence,
   local observability, or camera correction was inadequate. Expansion is not
   a correctness certificate.

Because fine labels are local to each tile, a fine label index is not a
scene-wide physical quantity. Use HAE and the tile label-count diagnostics.

Single takeaway: report overview boundary fractions, fine raw/SGM valid and
boundary fractions, expanded tile count, fine minimum/median/maximum labels per
tile, and total evaluated fine pixel-labels.

### 3. RPC Hierarchy Alignment

The panels are **Warped moving**, **Reference - warped moving**, and the
**Magenta/green selected alignment**. They use the final fine SGM
correspondence. Interpretation matches the direct result and alignment figures.
The reported `ResidualMean` is signed normalized intensity bias and can cancel;
`ResidualRms` is the more useful scalar magnitude in hierarchical mode.

### 4. RPC Coarse Adjustment

This figure is meaningful when
`CoarseAdjustment="symmetric-feature"`:

1. **RPC-3 parameters `[dx,dy,theta]`** shows the equal-and-opposite correction
   assigned to the reference and moving RPCs. `dx` and `dy` are native 1x
   pixels; `theta` is radians. Rotation must not be compared numerically with
   translation on the shared axis. Equal and opposite values are required by
   the chosen meet-in-the-middle gauge and are not independent estimates.
2. **Median bidirectional trajectory residual** compares the feature matches'
   best-height RPC trajectory distance before and after correction, in native
   pixels. A material reduction with enough spatially distributed inliers and
   a finite, reasonable normal-matrix condition supports applying the global
   correction. A lower median alone is not sufficient: the fit can be poorly
   conditioned, supported by too few or clustered features, or coupled to
   terrain height along the trajectory.

When coarse adjustment is disabled, zero parameters and unavailable residuals
are expected. A global RPC-3 correction cannot remove spatially varying
pushbroom pointing errors. If it improves one part of the image while another
band still fails, record that spatial pattern rather than repeatedly tuning the
global fit.

Single takeaway: report detected feature counts, matched pairs, candidates,
inliers, before/after median native-pixel residual, both parameter triplets,
iteration count, normal-matrix condition, and `Converged`.

## Common failure patterns

| Observation | Most useful next checks | Do not conclude yet |
| --- | --- | --- |
| A coherent white-noise band in raw height | Masks; anchor warps; inside-moving and RPC convergence fractions; raw margin; boundary map; whether the feature correction changes the band | That SGM or tile smoothing alone will repair it |
| A U-shaped label histogram or many endpoint winners | Boundary map location; HAE range validity; coarse-adjustment residual; anchor-plane alignment; RPC fit/extrapolation | That the range merely needs to be widened |
| Raw is noisy but SGM is smooth | Raw margin and curves; SGM-minus-raw map; selected alignment | That smoothness establishes a correct height surface |
| Overview looks useful but fine tiles fail | Expanded-band map; fine tile label counts; fine boundary fraction; local `dw/dz`; raw margin | That the overview itself is necessarily wrong |
| All anchor warps share nearly the same offset | Symmetric-feature adjustment and before/after residual; RPC/raster coordinate convention | That adding height labels addresses pointing bias |
| Content leaves the moving image at one or more anchors | `InsideMovingFraction`, raster/TRE full-image extent agreement, masks, ROI mapping | That this is a radiometric matching failure |
| High RPC inverse residual or incomplete convergence | Refit RPCs over a wider HAE interval; verify RPC normalization, datum, raster dimensions, and extrapolation | That a dense result from those pixels is trustworthy |
| Good downsampled result but poor 1x ROI result | Full-resolution radiometry, support window, feature-scale correction, pixel-level RPC error, raw margins | That the coarse result proves building-scale accuracy |
| Strong magenta/green color but low geometric edge offset | View-dependent radiometry, shadows, occlusion, band response | That color alone is a camera error |

## Minimum return record for every remote run

Rich MATLAB artifacts are not required. A useful diagnostic report must still
contain the following written values and screenshots.

### Run identity and configuration

- Sanitized pair ID and image ordering, code commit or distribution build date,
  MATLAB release, CPU model or native-core count, RAM, GPU model/VRAM, and
  actual thread-pool worker count.
- Whether the timing is a cold first run or a warmed repeat and whether the
  thread pool already existed.
- Native reference/moving sizes, selected bands, line-time axis if known,
  native 1x reference ROI, masks/nodata policy, and processing factor.
- `ExecutionMode`, `CoarseAdjustment`, overview and feature factors, maximum
  features, HAE `[minimum,expected,maximum]`, fine and overview projected-motion
  targets, tile size, label block size, support fraction, precision, SGM
  penalty per metre, maximum penalty, and direction count.

### Geometry and adjustment

- The complete `report.Geometry.PerHeight` table.
- `AdjacentMotionMedianPixels`, `AdjacentMotionP95Pixels`,
  `TotalTrajectoryMedianPixels`, and `MedianDirectionChangeDegrees`.
- Every automatic warning or exception identifier and message.
- If feature adjustment is enabled: detected/matched/candidate/inlier counts,
  before/after median residual, both native parameter triplets, iterations,
  condition number, and convergence.

### Label, evidence, and output metrics

- Direct: total labels, target and achieved maximum adjacent median motion,
  estimated cost-volume MiB, raw/SGM valid fractions, raw/SGM boundary
  fractions, and refinement-valid fraction.
- Hierarchical: overview labels; fine tile count and minimum/median/maximum
  labels; overview and fine raw/SGM boundary fractions; fine raw/SGM valid
  fractions; expanded tiles; and evaluated fine pixel-labels.
- Median raw best ZNCC cost and median raw cost margin. These are compact
  comparators, not substitutes for the spatial maps or representative curves.
- Alignment valid fraction and residual scalar(s), remembering that these are
  normalized intensity residuals rather than pixel reprojection errors.
- A one-sentence spatial result: which approximate native 1x ranges look good,
  noisy, invalid, or pinned to a height boundary.

### Runtime and memory

- The complete `report.Timing` table. In direct mode, `RawZncc` is the dense
  unregularized search. In hierarchical mode, keep `Overview`, `FinePlanning`,
  and `AdaptiveFineAndSgm` separate. `Total` includes display time.
- Raw `PixelLabelCount`, `PixelLabelsPerSecond`, tile count, label block size,
  worker count, and, when present, geometry, bilinear sampling, and local-filter
  seconds. Throughput is essential when comparing label policies or machines;
  wall time alone confounds image size and label count.
- The complete `report.Memory` structure. Its current values are tracked MATLAB
  payload lower bounds, not process peak resident memory. Also record observed
  peak MATLAB RAM and GPU memory from the operating system or MATLAB tools if
  available. State explicitly when either value was not measured.

### Screenshots

- All four figures for the selected execution mode with readable titles and
  colorbars.
- A zoom of one successful and one failed region in the selected-alignment
  view, with approximate native 1x coordinates.
- If a spatial failure band exists, include the same extent in raw HAE, cost
  margin, boundary/expansion, and residual views.

## Compact MATLAB transcription commands

The harness already prints several metrics. The following commands expose the
remaining scalar and tabular evidence without saving the full report:

```matlab
disp(report.Input)
disp(report.Settings)
disp(report.Geometry.PerHeight)
disp(report.Geometry.AdjacentMotionMedianPixels)
disp(report.Geometry.AdjacentMotionP95Pixels)
disp(report.Geometry.TotalTrajectoryMedianPixels)
disp(report.Geometry.MedianDirectionChangeDegrees)
disp(report.Summary.CoarseAdjustment)
disp(report.LabelPolicy)
disp(report.Timing)
disp(report.Memory)

v = report.RawZncc.Valid & isfinite(report.RawZncc.BestCost);
fprintf("raw valid fraction: %.6g\n", mean(report.RawZncc.Valid, "all"));
fprintf("raw median best ZNCC cost: %.6g\n", ...
    median(double(report.RawZncc.BestCost(v)), "omitnan"));
fprintf("raw median second-label margin: %.6g\n", ...
    median(double(report.RawZncc.CostMargin(v)), "omitnan"));
fprintf("raw evaluated pixel-labels: %.0f\n", ...
    report.RawZncc.Runtime.PixelLabelCount);
fprintf("raw throughput (pixel-labels/s): %.6g\n", ...
    report.RawZncc.Runtime.PixelLabelsPerSecond);
```

For direct mode also run:

```matlab
disp(report.LabelDiagnostics.MethodSummary)
disp(report.LabelDiagnostics.SelectionFractions)
disp(report.Warnings)
disp(report.WarningKinds)
disp(report.Alignment.ValidFraction)
disp(report.Alignment.MeanAbsoluteResidual)
disp(report.Alignment.RootMeanSquareResidual)
```

For hierarchical mode also run:

```matlab
disp(report.Diagnostics)
disp(report.Overview.Warnings.RawBoundaryWinnerFraction)
disp(report.Overview.Warnings.SgmBoundaryWinnerFraction)
disp(report.Fine.Runtime)
disp(report.Alignment.ValidFraction)
disp(report.Alignment.ResidualMean)
disp(report.Alignment.ResidualRms)
```

Do not print or export the complete `report.CoarseAdjustment` structure when
feature coordinates are sensitive. Instead transcribe only the scalar fields
listed above or use `report.Summary.CoarseAdjustment`. Likewise, do not export
`report.Figures`, processed images, masks, correspondence arrays, height maps,
cost volumes, or raw feature locations unless they have been explicitly
sanitized.

## Copyable written result template

```text
Run ID / pair order:
Commit or distribution date:
MATLAB / CPU / RAM / GPU / workers:
Cold or warm run; pool already open:
Native sizes / bands / time axis:
Native 1x reference ROI:
Mode / coarse adjustment:
Downsample / overview / feature factors:
HAE min / expected / max:
Fine / overview projected-motion targets:
Tile / label block / precision / support:
SGM penalty-per-m / maximum / directions:

Feature detected ref/moving / matched / candidates / inliers:
Feature residual before -> after (native px):
Reference and moving [dx dy theta] (native px, native px, rad):
Adjustment iterations / condition / converged:

RPC inverse convergence by height:
Inside-moving fraction by height:
Maximum inverse / round-trip residual by height:
Median and P95 dw/dz by height (processed px/m):
Adjacent median / P95 motion; median direction change:

Direct labels, achieved motion, cost-volume estimate:
or overview labels and fine min/median/max labels:
Evaluated pixel-labels / pixel-labels per second:
Median raw best ZNCC cost / median raw margin:
Raw and SGM valid fractions:
Raw and SGM boundary fractions:
Expanded tile count if hierarchical:
Alignment valid fraction / residual scalar(s):

Timing table:
Tracked memory lower bounds / observed peak RAM / observed peak VRAM:
Warnings or exception:
Good native 1x region(s):
Failed native 1x region(s) and appearance:
Raw curves: interior / flat / multimodal / endpoint:
Anchor warps and selected alignment observation:
Screenshots supplied and sanitization performed:
```
