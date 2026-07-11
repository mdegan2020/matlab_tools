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
- The latest fresh-class repository suite passes 477/477 tests with zero
  failures and zero incomplete tests.
- Multi-image foundation MI-0 adds optional stable `ViewId`, explicit `PassId`,
  unordered pair identity, and per-line timing metadata while preserving the
  existing viewer launch signature and legacy `LayerId` contracts.

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
| Dense-Surface Synthetic Expansion Milestones 1-4 | Complete |
| Dense-Surface Synthetic Milestone 5 implementation/evidence | Complete |
| Dense-Surface Synthetic acceptance-threshold proposal | Complete |
| Multi-Image Foundation MI-0 | Complete |
| Multi-Image Foundation MI-1 | Complete |

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

## Current Implementation Queue

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

The approved dense-surface synthetic expansion has no remaining implementation
milestone. Required fixture decisions are captured in an ignored local JSON
configuration. Actual sensor and geometry values remain out of committed
documentation. Proposed evidence thresholds are documented separately and are
not yet enforced by code.

1. **Configuration and feasibility — complete.** Strict schema/path validation,
   explicit body/world and roll-then-pitch gimbal transforms, full-ray projected
   GSD, pitch-scan and constant-gap schedule solves, footprint/tile planning,
   per-axis oversampling, and ordered explainable feasibility checks are in
   place. The ignored configured fixture passes every planner check before
   full-scale allocation.
2. **Terrain, texture, and truth geometry — complete.** Logical shared-edge
   reflected addressing supports continuous arbitrary-band interpolation;
   compact deterministic terrain enforces configured extrema and uses first-hit
   intersections with explicit occlusion; fixture-local Gauss-Markov motion and
   truth rays are sampled on demand. Truth is absent from viewer-safe metadata.
3. **Full-scale image generation — complete.** The generator gates allocation
   on feasibility, loads full source radiometry once, renders complete
   single-band images in bounded internal chunks, retains them in memory, and
   writes final TIFF/PNG plus compact image-free MAT/JSON artifacts. The
   configured run completed with full valid coverage and exact file readback.
4. **Navigation presets and scene variants — complete.** One correlated sortie
   timeline propagates configured inertial bias/random-walk terms with nominal
   GNSS position/velocity aiding. Generic Tactical Grade IMU and Navigation
   Grade IMU presets each provide pointing-only and combined-error reported
   geometry. Variants share an image reference and contain no image payload or
   truth structure; deterministic statistics preserve expected grade ordering.
5. **Alignment and dense-surface acceptance — complete.** Reported-only scenes
   now run through the existing staged
   alignment, fixed-reference differential OPK solve, safe-apply policy, and
   dense extraction. Truth diagnostics are computed afterward on mutually
   visible terrain. The configured evidence contains four completed alignment
   runs, four successful dense products, exact two-pass repeatability, and
   compact ignored MAT/JSON artifacts. Conservative numerical thresholds are
   proposed in a separate reviewable document without changing runtime policy.

See `docs/dense_surface_synthetic_expansion_plan.md` for the complete ordered
contract.

The bounded claim applies to serial/thread TIFF output with in-memory sources,
and to serial TIFF output with file-backed sources. PNG remains in-memory.

## External Validation Gates

The approved truth-aware synthetic expansion is the primary systematic
alignment acceptance fixture. Later air-gapped real-data findings may be
incorporated as isolated metric or threshold updates; a repository-accessible
real-data corpus is not expected.

The remaining external gates require target hardware:

- Benchmark representative 100-150 MP primarily single-channel images on the
  intended high-end Windows workstation at 1080p/4K, including 512 versus 1024
  display tile sides and one, two, and four visible layers. The provisional
  default remains 1024.
- Exercise optional MATLAB-managed GPU behavior and CPU equivalence on a
  supported Windows GPU system before making any performance recommendation,
  including dense-surface `disparitySGM` GPU behavior if available.

The Windows viewer/GPU gates remain explicitly unclaimed on the current macOS
development system.

## Deferred Or Decision-Gated Work

The following are documented possibilities, not an approved implementation
queue:

- calibrated or spatially varying stereo rectification, confidence/uncertainty,
  consistency filtering, cleanup, smoothing, and export for dense surfaces;
- degraded or interrupted GNSS, precision/differential GNSS, explicit
  gimbal/boresight/mounting errors, and independent repeat-pass error draws;
- piecewise-linear and true curved target-orbit collection trajectories;
- per-column or smoothly posted time-varying OPK correction;
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
  CPU tiling, thread execution, and MATLAB-managed GPU operations; and
- a production C++ backend and NITF output; current prototyping may keep all
  inputs/outputs in memory and perform one final TIFF/PNG write.

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
- `docs/dense_surface_synthetic_expansion_plan.md` — truth-aware synthetic
  fixture, navigation presets, acceptance modes, and ordered implementation
  milestones.
- `docs/dense_surface_synthetic_acceptance_report.md` — first full-scale
  privacy-preserving acceptance evidence and interpretation.
- `docs/dense_surface_synthetic_acceptance_thresholds.md` — proposed primary
  fixture gates derived from the first repeatable evidence package.
- `docs/alignment_operator_guide.md` — current staged operator workflow.
