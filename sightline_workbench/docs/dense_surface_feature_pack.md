# Dense Surface Feature Pack

Status: Pack 1 is complete. The representative synthetic image/geometry
expansion is approved and is the active implementation queue. Its ordered,
privacy-preserving milestones are defined in
`docs/dense_surface_synthetic_expansion_plan.md`. Other follow-up candidates
below remain decision-gated; see `docs/project_status.md`.

## Purpose

Dense Surface Pack 1 adds a deliberately small first-pass dense stereo product
after two images have been aligned. It is an analysis and visualization tool,
not a new backend product contract. The operator selects the moving and
reference layers in the Alignment Workbench, completes the staged alignment
through Preview or Apply, and presses `Dense surface`.

The pack opens two runtime windows:

1. A masked intensity view of moving-image pixels for which SGM produced a
   usable dense correspondence.
2. A surface plot colored by moving-image intensity. X and Y are current
   projection-plane metres; Z is signed height in metres along the current
   projection-plane normal.

## Processing Contract

`ProjectionDenseSurfaceExtractor` is the graphics-free computation boundary.
`ProjectionDenseSurfaceViewer` owns the result windows. Graphics handles stay
in the app/runtime viewer helper and never enter scene, layer, source, result,
or serialized state structures.

For the currently selected moving-to-reference pair, extraction performs these
steps:

1. Require at least three currently accepted correspondences and an alignment
   that is previewed, applied, or manually adjusted.
2. Render fresh pair-specific alignment working images from the current scene.
   This prevents a solved pointing change from being paired with stale image or
   source-coordinate maps.
3. Reproject accepted source observations onto the current working grid.
4. Estimate the dominant sparse displacement direction and rotate both working
   images by one common angle so the median parallax is horizontal. This common
   resampling preserves disparity rather than warping either image onto the
   other.
5. Derive a bounded disparity search interval from accepted sparse disparities
   unless the caller supplies one, normalize each valid analysis image, and run
   MATLAB `disparitySGM` on the CPU.
6. Carry the rectified working-image source-row/source-column maps through the
   same resampling. Every retained dense correspondence therefore maps back to
   continuous observations in both full source images.
7. Sample each layer's current corrected source ray, find the closest forward
   points on the two rays, and use their midpoint as the reconstructed point.
   Report ray separation as a per-point consistency diagnostic.
8. Convert the reconstructed midpoint to projection-plane X/Y and signed
   height above the plane. Subsample only the triangulated display surface when
   the dense field exceeds the configured surface-point budget; retain the
   full disparity/intensity result.

The default options are intentionally conservative and caller-overridable:

| Option | Default | Meaning |
| --- | ---: | --- |
| `DisparityPaddingPixels` | 16 | Margin around sparse disparity support |
| `MaximumDisparitySpanPixels` | 128 | Maximum automatic SGM search span |
| `UniquenessThreshold` | 15 | `disparitySGM` uniqueness threshold |
| `MinimumSparseMatches` | 3 | Hard minimum accepted sparse support |
| `MinimumSparseParallaxPixels` | 0.1 | Minimum usable dominant displacement |
| `MaximumSurfacePoints` | 250000 | Approximate triangulation/display budget |
| `MaximumRaySeparationMeters` | `Inf` | Optional physical rejection gate |
| `UseGPU` | `false` | Request capability-checked GPU SGM with CPU fallback |

The result records the sparse and dense counts, common rectification angle,
requested and actual disparity ranges, sparse vertical RMS, sampling stride,
height range/median, ray-separation median/95th percentile, corrections used,
and total elapsed time. Projection offsets are reported but intentionally not
applied to physical source rays: viewer projection offsets translate a layer's
plane display and do not mutate its source ray origins or directions.

## Required Products and Execution

The feature requires MATLAB, Image Processing Toolbox, and Computer Vision
Toolbox. `disparitySGM` is the first implementation. The required and default
path is CPU. `UseGPU=true` optionally sends only the SGM inputs to a supported
`gpuArray` device, gathers disparity immediately, and otherwise records a clean
CPU fallback. The feature creates no parallel pool.

The button remains disabled when `disparitySGM` is unavailable, before a
preview/apply/manual aligned state exists, or when the selected pair has fewer
than three accepted observations. Failures remain non-destructive and are
reported in Alignment Workbench status/diagnostics.

## Invariants

- Full source imagery and current source geometry remain authoritative.
- Display pyramids, preview tiles, and cached viewer textures are never dense
  stereo radiometry.
- Alignment working images are bounded, single-band analysis products only.
- Dense results are runtime-only. They are not serialized into viewer state or
  backend jobs and cannot affect backend output.
- Backend processing remains full-source inverse warp at its configured output
  resolution.
- CPU support is mandatory. Optional GPU SGM is capability-checked and retains
  CPU equivalence/fallback; target-Windows performance validation remains
  external.
- No process-based pool is created. If later profiling justifies parallelism,
  only `parpool("threads")` is permitted.

## Known Limitations and Follow-up Candidates

This is a starting point, not calibrated general stereo rectification.

- A single common in-plane rotation is appropriate when accepted disparities
  define a dominant direction and residual vertical disparity is modest. It
  does not model curved or spatially varying epipolar loci from arbitrary
  pushbroom/line-scanner geometry.
- SGM quality depends strongly on texture, radiometric similarity, occlusion,
  repetitive structure, disparity-range support, and the validity masks.
- The sparse matches seed orientation and range. Sparse support that omits a
  large terrain disparity can still truncate the automatic search interval.
- Ray midpoints provide an explainable reconstruction and ray separation, but
  Pack 1 does not yet expose uncertainty, confidence maps, speckle removal,
  left/right consistency, connected-component filtering, or surface smoothing.
- Results are not geospatial files, DEMs, point clouds, or persisted products.
  Export and serialization need a separately reviewed contract.
- A future quality pack should compare SGM with alternative dense matchers and
  add rectification-quality diagnostics and adjustable options. The approved
  synthetic expansion supplies the primary truth-aware acceptance fixture;
  later air-gapped real-data metrics may refine individual criteria.
- The approved representative synthetic expansion adds a physically motivated
  multi-view collection, occluding terrain, navigation-error variants, and
  known truth. Actual fixture parameters remain in an ignored local JSON file
  and must not be copied into committed documentation.

## Validation

Focused tests cover a deterministic textured stereo pair with known disparity
and height, hard sparse-match validation, intensity/surface window creation,
and Alignment Workbench button state through Match, Filter, Solve, Preview,
Apply, and Revert. Final repository validation uses a fresh MATLAB class state:

```matlab
close all force;
clear all;
clear classes;
rehash;
results = runTests;
```

The completed Pack 1 fresh-class run passed all 386 repository tests at that
milestone. The current fresh-class repository baseline is 436/436 after
synthetic-expansion Milestone 2.
