# Sightline Workbench Project Status

This is the concise current-status index for Sightline Workbench. Detailed
design history remains in the linked workplans; historical deliverable lists
should not be mistaken for unfinished implementation.

## Current Baseline

As of July 10, 2026:

- The project directory and main application title are `sightline_workbench`
  and **Sightline Workbench**.
- The public `PlanarProjection` and `Projection*` MATLAB APIs retain their
  existing names for compatibility.
- CPU execution is the required and tested path.
- GPU acceleration remains optional and capability-checked.
- Any MATLAB parallel pool used by the backend is
  `parpool("threads")`; process-based pools are unsupported.
- Graphics handles and runtime caches remain outside serializable
  scene/layer/source structures.
- Backend radiometry defaults to full-source inverse warp. Display pyramids,
  preview tiles, alignment working images, and dense-surface products never
  become backend radiometric inputs.
- The latest fresh-class repository suite passes 386/386 tests with zero
  failures and zero incomplete tests.

## Completed Feature Trees

| Workstream | Current state |
| --- | --- |
| Original viewer milestones 1-6 | Complete |
| Backend Milestones 1-10 | Complete |
| Auto Alignment Milestones 1-13 | Complete |
| Initial Alignment Hardening Feature Packs 1-5 | Complete |
| Alignment Reliability Packs 0-8 | Complete |
| Viewer Performance Packs 0-8 | Complete |
| Backend Performance Packs 0-1 | Complete |
| Dense Surface Pack 1 | Complete |

The alignment system now includes stable match provenance, current-geometry
overlays, a staged Alignment Workbench, deterministic mask-aware matching,
truthful similarity/affine and coplanarity filtering, balanced
common/differential solving, unified GUI/backend safety, Shift+left common
anchor adjustment, synthetic oblique-terrain validation, and CPU SGM
dense-surface exploration.

The viewer performance work includes demand-driven crosshairs, latest-state
camera scheduling, LOD hysteresis and halo retention, cached/vectorized tile
visibility, differential surface reuse, bounded runtime caches/pools, targeted
geometry invalidation, coalesced alpha rendering, lazy UI/pyramid storage,
scalar single-band textures, and the decision to keep raster preview optional.

## Active Implementation Queue

The only ordered, explicitly selected implementation queue remaining in the
committed workplans is Backend Performance Packs 2-5:

1. **Backend Performance Pack 2 — Bounded serial streaming.** Incrementally
   write tiled TIFF/mask products, remove output-sized index temporaries, make
   in-memory return policy explicit, and close partial files safely.
2. **Backend Performance Pack 3 — Bounded thread pipeline.** Submit a limited
   number of tiles through `parpool("threads")`, consume results
   incrementally, and keep deterministic writes and bounded in-flight memory.
3. **Backend Performance Pack 4 — Radiometric and precision policy.** Define
   output class, scale/offset, fill, single-precision tolerances, and
   format-specific writing without repeated full-image normalization.
4. **Backend Performance Pack 5 — File-backed source regions.** Add a backend
   source-region provider with in-memory compatibility and TIFF/`blockedImage`
   adapters so tiled jobs need not hold a complete source array.

Until Pack 2 is complete, the tiled backend should not be described as
bounded-memory end to end for very large outputs.

## External Validation Gates

These require user data or target hardware rather than more synthetic claims:

- Run the alignment workflow on representative difficult real imagery. Record
  all match-stage counts, correction split, observability, bounds,
  forward-ray residuals, interaction behavior, and saved/background
  equivalence.
- Benchmark representative 100-150 MP primarily single-channel images on the
  intended high-end Windows workstation at 1080p/4K, including 512 versus 1024
  display tile sides and one, two, and four visible layers. The provisional
  default remains 1024.
- Exercise optional MATLAB-managed GPU behavior and CPU equivalence on a
  supported Windows GPU system before making any performance recommendation.

No user real-data pair is currently available to the repository, so these
gates remain explicitly unclaimed.

## Deferred Or Decision-Gated Work

The following are documented possibilities, not an approved implementation
queue:

- calibrated or spatially varying stereo rectification, confidence/uncertainty,
  consistency filtering, cleanup, smoothing, and export for dense surfaces;
- a production preview/exact/difference/flicker comparison view;
- sensor-specific geometry ingestion beyond
  `ProjectionSourceGeometry.fromGrid`;
- calibrated pointing covariance and native-displacement defaults;
- a second/multi-anchor common-twist interaction;
- optional DEM-constrained adjustment or an explicitly labeled plane-tie tool;
- explicit anaglyph channel assignment and richer difference/flicker/swipe
  comparison modes;
- a decision on signed-line versus forward-ray semantics for the legacy
  `PlanarProjection.intersectPlane` and
  `PlanarProjection.triangulateRays` APIs; and
- custom GPU kernels, only if profiling shows a bottleneck not addressed by
  CPU tiling, thread execution, and MATLAB-managed GPU operations.

## Sources Of Truth

- `docs/viewer_development_plan.md` — architecture, historical viewer/backend
  milestones, and broader roadmap topics.
- `docs/alignment_workflow_hardening_plan.md` — completed alignment design
  and reliability packs plus deferred alignment scope.
- `docs/performance_optimization_workplan.md` — completed viewer/backend
  performance packs and active Backend Packs 2-5.
- `docs/dense_surface_feature_pack.md` — exploratory dense-surface contract
  and limitations.
- `docs/alignment_operator_guide.md` — current staged operator workflow.
