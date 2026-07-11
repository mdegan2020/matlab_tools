# Sightline Workbench Project Status

This is the concise current-status index for Sightline Workbench. Detailed
design history remains in the linked workplans; historical deliverable lists
should not be mistaken for unfinished implementation.

## Current Baseline

As of July 11, 2026:

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
- The latest fresh-class repository suite passes 416/416 tests with zero
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
| Backend Performance Packs 0-5 | Complete |
| Dense Surface Pack 1 | Complete |
| Viewer Orientation and Anaglyph Presentation Pack | Complete |
| Alignment Workbench Usability and Offset-Semantics Pack | Complete |
| Cross-System Acceleration Pass | Complete |

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
The completed orientation/anaglyph pack extends twist to `+/-85` degrees,
orients explicit oblique real-data planes naturally upright, assigns the
left-eye layer to red from the current-view sensor baseline, brightens the
preview, and provides runtime-only separation/depth controls without rebuilding
projection geometry or changing serialized/backend state.

The completed Alignment Workbench usability pack groups controls into Setup,
Filter/Solve Settings, Staged Workflow/Review, Pair Schedule, Match Ledger, and
full-width Diagnostics regions. It preserves the staged state machine and
records the projection-offset decision: offsets remain post-intersection
projection-plane registration terms, affect plane-coordinate products, and do
not alter source origins, forward-ray metrics, or coplanarity.

## Active Implementation Queue

The cross-system pass retained CPU viewer/alignment paths, preserved the Pack 2
prerequisite for backend threading, and added optional capability-checked GPU
SGM with CPU fallback. See `docs/cross_system_acceleration_report.md`.

Backend Performance Pack 2 adds bounded serial tiled-TIFF output, explicit
in-memory retention policy/limits, optional query-coordinate omission,
output-sized index-temporary removal, and partial-file cleanup.
Backend Performance Pack 3 replaces retain-all `parfor` execution with bounded
`parfeval` submission, immediate `fetchNext` consumption, indexed main-thread
TIFF writes, deterministic tile reports, and explicit in-flight diagnostics.
Backend Performance Pack 4 replaces implicit min/max normalization with one
shared scale/offset/class/fill/clipping contract, records reconstruction
metadata, supports uint8/uint16 PNG/TIFF and single TIFF, and validates optional
single-precision tile products against double.
Backend Performance Pack 5 adds runtime-only in-memory/TIFF source providers,
serializable TIFF descriptors, per-tile source bounding-region reads, source
provenance summaries, and in-memory/file-backed numerical parity. MATLAB TIFF
region reads require serial execution because their internal reader is not
supported on thread workers.

The remaining implementation queue is dense-surface synthetic expansion.

1. **Dense-surface synthetic data expansion.** The user will provide desired
   output dimensions and
   rough sensor geometry such as azimuth, elevation, and range; the tooling
   should derive the remaining synthetic image/geometry details for more
   representative surface-extraction validation fixtures.

The bounded claim applies to serial/thread TIFF output with in-memory sources,
and to serial TIFF output with file-backed sources. PNG remains in-memory.

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
  supported Windows GPU system before making any performance recommendation,
  including dense-surface `disparitySGM` GPU behavior if available.

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
- production export of screen-adjusted anaglyph presentation as a three-band
  TIFF/PNG product after display-only controls are evaluated;
- richer difference/flicker/swipe comparison modes;
- a decision on signed-line versus forward-ray semantics for the legacy
  `PlanarProjection.intersectPlane` and
  `PlanarProjection.triangulateRays` APIs; and
- custom GPU kernels, only if profiling shows a bottleneck not addressed by
  CPU tiling, thread execution, and MATLAB-managed GPU operations.

## Sources Of Truth

- `docs/viewer_development_plan.md` — architecture, historical viewer/backend
  milestones, and broader roadmap topics.
- `docs/alignment_workflow_hardening_plan.md` — completed alignment design and
  reliability/usability packs, offset-semantics decision, and deferred
  alignment scope.
- `docs/performance_optimization_workplan.md` — completed viewer/backend
  performance packs, cross-system acceleration constraints, and Backend Pack
  5.
- `docs/dense_surface_feature_pack.md` — exploratory dense-surface contract
  and limitations.
- `docs/alignment_operator_guide.md` — current staged operator workflow.
