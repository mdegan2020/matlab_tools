# Dense-Surface Synthetic Expansion Plan

Status: complete. Milestones 1-5 and the separately reviewable numerical-
threshold proposal are complete. Fixture inputs and modeling decisions remain
in the local ignored configuration. Proposed thresholds remain documentation-
only until explicitly adopted as an automated gate.

## Purpose

This workstream replaces the unavailable systematic real-data alignment gate
with a deterministic, physically motivated synthetic acceptance fixture. The
fixture will provide known terrain, trajectory, image-formation, navigation,
and visibility truth while exercising the same viewer, alignment, and dense
surface contracts used for ordinary in-memory imagery.

The fixture is intentionally more demanding than the existing compact oblique
terrain harness. It models a continuous airborne collection, time-varying
platform motion, articulated pointing, line-by-line image formation, relief,
occlusion, cross-band radiometry, and realistic navigation-solution errors.
The result remains a test and evaluation product, not a backend radiometric
input or a production sensor simulator.

## Parameter Privacy And Reproducibility

The actual sensor, platform, geometry, scheduling, noise, source-path, and
output values for this fixture must not be committed or repeated in project
documentation.

The repository commits only
`config/dense_surface_synthetic.template.json`. It defines field names and
units with `null` placeholders. A runnable configuration is copied to
`config/dense_surface_synthetic.local.json`, which is narrowly ignored by Git.
Generated products are also ignored.

Implementation and review output may report whether constraints passed, the
derived relationships, and normalized/error metrics. It must not echo the
private configuration into committed reports, snapshots, test names, or source
constants. Focused unit tests use small public values created inside each test;
they do not load the private full-scale configuration.

## Non-Negotiable Contracts

- CPU execution remains complete and tested.
- Optional GPU use remains capability-checked and is not required by this
  fixture.
- No process-based parallel pool may be created. If later profiling justifies
  parallel work, only `parpool("threads")` is acceptable.
- Truth imagery is rendered from the full in-memory source texture and truth
  geometry. Viewer pyramids, alignment working images, and dense products are
  never radiometric inputs.
- The viewer receives reported/noisy source geometry, while rendering uses
  truth geometry. Truth must not leak into alignment inputs.
- Graphics handles and runtime caches stay outside serializable scene, layer,
  source, truth, and configuration structures.
- Geometry sampling continues to use the
  `SampleFcn(rowIndices, columnIndices)` and continuous observation-sampling
  contracts.
- Full per-pixel XYZ truth is not retained. Truth is compact, parametric, and
  sampled on demand.
- Large image inputs and outputs may remain in memory during this prototype.
  A completed product may be written once in the configured TIFF or PNG form.
  File-throughput optimization is not part of this workstream.

## Image And Sensor Model

Each source-image column is one time sample from an instantaneous cross-track
detector line. Detector rows span the configured cross-track field of view.
Columns advance at the configured line rate, so acquisition time follows from
image width and line rate rather than from an independent duration option.

The platform body frame follows standard aircraft convention: forward, right,
and down. The target-local world frame uses nominal flight direction, right of
flight, and up. The implementation must provide one explicit, tested transform
between them.

The sensor has a roll gimbal mounted to the platform and a pitch gimbal mounted
to the roll stage. Zero-angle boresight is platform down. Active right-hand
rotations are applied in physical mounting order: roll about platform forward,
then pitch about the roll-transformed gimbal lateral axis. Pitch scanning moves
the ground footprint forward and adds to the platform's ground motion.

The required ground advance per image column is one projected cross-track GSD.
The feasibility planner therefore derives the pitch scan rate from

```text
required total ground rate = configured line rate * projected GSD
pitch-scan ground rate = required total ground rate - platform ground rate
```

The implementation must use the complete oblique ray/terrain geometry when
solving this relationship; a nadir small-angle shortcut is not an acceptance
calculation.

## Collection And Feasibility Planner

Before allocating full-size imagery, a pure planner must solve the collection
schedule and return an explainable report containing:

- derived slant range and ground standoff;
- projected GSD along both image axes;
- platform and gimbal contributions to column-to-column ground advance;
- pitch start, center, end, and field-of-regard margin for every collection;
- acquisition duration, retrace, and constant inter-image gap;
- achieved scene-center separation between consecutive images;
- projected terrain/texture bounds for every view;
- required reflected-tile count along each terrain axis; and
- oversampling ratio along each projected image axis.

The planner first targets the configured scene-center separation. It may
increase separation only when required by the acquisition duration, constant
gap, scan rate, or pitch field of regard. It must not silently change image
shape, platform motion, line rate, or field of regard.

Planning stops for user judgment when no schedule satisfies the private range
envelope, pitch limits, footprint containment, texture-grid growth limit, or
per-axis oversampling limit. A failed feasibility report is useful output and
must identify the first violated constraint and the nearest candidate.

## Texture And Terrain Truth

The source TIFF is loaded into memory once. Views select source bands in the
configured cyclic order. Texture coverage uses logical reflected addressing:
adjacent virtual tiles mirror at the shared edge, and diagonal tiles mirror
along both required axes. The implementation does not need to allocate the
complete reflected RGB mosaic.

Reflection must be continuous at every virtual tile boundary. Tests cover
horizontal, vertical, and corner transitions, odd and even source dimensions,
continuous interpolation coordinates, and equivalence with a small explicitly
materialized reflection oracle.

Terrain is a deterministic, smoothly varying, asymmetric composite derived
from a windowed radial-sinc-like surface and secondary smooth components. Its
configured extrema are enforced after composition. Terrain design must produce
some true view-dependent occlusion without introducing discontinuities or
unrealistic single-cell spikes.

Rendering uses the first forward intersection with the terrain, not a
height-only texture warp. Truth records distinguish visible terrain, terrain
occlusion, texture-coverage failure, and invalid geometry. Acceptance metrics
exclude genuine occlusion from false correspondence penalties while reporting
its extent explicitly.

## Truth Motion And Reported Navigation

The truth platform trajectory is a continuous level flyby with a small,
smooth, deterministic turbulence process. It is sampled at every image-column
time and drives image rendering. The random seed and all process parameters
live only in the private configuration.

Reported geometry is produced by a navigation error-state model rather than by
independent position and angle perturbations. The first implementation models:

- one sortie-wide bias draw;
- gyro and accelerometer bias processes;
- gyro angle random walk and accelerometer velocity random walk;
- correlated nominal GNSS position and velocity aiding;
- consistent propagation of position, velocity, and attitude error through
  the complete single-sortie timeline; and
- deterministic repeatability from the private seed.

Two generic presets are required: **Tactical Grade IMU** and
**Navigation Grade IMU**. They are category presets, not claims about a named
product. Exact values remain private. The model is based on public
manufacturer guidance for inertial grades and official GPS performance
material, including:

- [VectorNav inertial error terms and representative sensor grades](https://www.vectornav.com/resources/detail/what-is-an-ins)
- [Honeywell tactical-grade HG4930 characteristics](https://aerospace.honeywell.com/content/dam/aerobt/en/documents/learn/products/sensors/brochures/N61-1523-000-010-HG4930-MEMS-Inertial-Measurement-Unit-bro.pdf?download=true)
- [Honeywell navigation-grade ring-laser gyro characteristics](https://prod-edam.honeywell.com/content/dam/honeywell-edam/aero/en-us/products/navigation-and-sensors/accelerometers-and-gyroscopes/gg1320an-digital-ring-laser-gyroscope/documents/hon-aero-gg1320andigitallasergyro-brochure-en.pdf)
- [Current GPS performance standards](https://www.gps.gov/performance-standards-specifications)

This is an error-state trajectory simulator, not a raw IMU waveform generator
or a complete strapdown INS/GNSS Kalman-filter implementation. Gimbal encoders,
boresight calibration, and mounting are ideal in the first fixture so their
errors are not hidden inside an IMU grade.

## Acceptance Variants And Metrics

One truth render is reused for both navigation presets. Each preset exposes two
reported-geometry variants:

1. **Pointing-only acceptance** isolates the constant pointing component that
   the current per-layer OPK solver can reasonably recover.
2. **Combined navigation-error acceptance** includes correlated position,
   velocity, attitude, and within-image drift. It is a robustness test; current
   constant-OPK alignment is not expected to remove every residual.

The first full-scale run establishes evidence before numerical thresholds are
committed. Every run records at least:

- deterministic repeatability and configuration fingerprint;
- visibility, texture coverage, and occlusion fractions;
- range, pitch-margin, scene-separation, and per-axis sampling compliance;
- match/filter/solver stage counts and spatial coverage;
- injected versus recovered constant OPK component;
- truth correspondence separation and forward-ray separation;
- residual structure versus image column/time;
- dense height error on mutually visible terrain;
- runtime and peak memory; and
- differences between IMU grades and acceptance modes.

After the first evidence package is reviewed, a separate documentation update
will set defensible thresholds. Later air-gapped real-data observations may
adjust individual metrics, but systematic real-data ingestion is not required
for this fixture to become the primary alignment acceptance gate.

## Ordered Implementation Milestones

Each milestone is a small, validated commit and is pushed after completion.

### Milestone 1: Configuration And Feasibility — Complete

- Add strict private-config loading and validation.
- Implement frame transforms, gimbal composition, projected-GSD calculation,
  scan-rate solution, constant-gap schedule solution, and feasibility report.
- Add small public tests for feasible and infeasible schedules.
- Do not render full-size imagery yet.

Implemented by `ProjectionDenseSurfaceSyntheticConfig` and
`ProjectionDenseSurfaceSyntheticPlanner`. The planner returns an ordered
constraint ledger and first violation without changing private inputs. The
configured fixture passes range, per-axis sampling, scan, constant-gap
schedule, pitch field-of-regard, footprint, and reflected-texture growth checks.
No full-size image allocation occurs in this milestone.

### Milestone 2: Terrain, Texture, And Truth Geometry — Complete

- Implement logical reflected texture addressing and continuity tests.
- Implement deterministic asymmetric terrain with first-hit occlusion.
- Implement continuous truth trajectory and compact on-demand truth sampling.
- Validate source-band cycling and ensure truth is excluded from viewer input.

Implemented by `ProjectionReflectedTexture`,
`ProjectionDenseSurfaceSyntheticTerrain`, and
`ProjectionDenseSurfaceSyntheticTruth`. Reflected coordinates share source
edges continuously without allocating a mosaic. Terrain is a normalized smooth
asymmetric composite with first-forward-hit intersections and verified
view-dependent occlusion. Continuous deterministic sortie motion, image rays,
terrain intersections, and cyclic source bands are sampled from compact truth
parameters. The viewer-safe scene metadata contract explicitly excludes the
terrain, trajectory, and truth-view payloads.

### Milestone 3: Full-Scale Image Generation — Complete

- Render each configured single-band image from truth geometry and full source
  texture.
- Retain the complete image in memory; bounded internal row/column chunks are
  allowed as computation details.
- Write the configured final image format only after an image completes.
- Emit compact MAT truth/scene data and a JSON run summary under the ignored
  artifact directory.

Implemented by `ProjectionDenseSurfaceSyntheticGenerator`. Feasibility is
confirmed from source metadata before source-image loading or full-size output
allocation. Full source radiometry is loaded once; complete truth images are
rendered with bounded internal chunks and retained in memory. Final TIFF/PNG
files are written only after image completion. The configured full-scale run
completed with full valid coverage and exact readback; its ignored MAT/JSON
artifacts are compact and contain no full image arrays.

### Milestone 4: Navigation Presets And Scene Variants — Complete

- Add the generic tactical- and navigation-grade error-state presets.
- Add nominal non-RTK GNSS aiding and one-sortie error correlation.
- Produce pointing-only and combined-error source-geometry variants without
  duplicating truth imagery.
- Add deterministic statistics and grade-ordering tests.

Implemented by `ProjectionDenseSurfaceSyntheticNavigation`. A compact
single-sortie error state propagates configured inertial biases and random walks
between correlated nominal GNSS position/velocity updates. Both generic IMU
grades expose pointing-only and combined-navigation-error source geometry with
grid and continuous observation samplers. The configured run preserves expected
grade ordering. Variants contain only a shared image reference and reported
trajectory closures; they neither duplicate imagery nor capture truth payloads.

### Milestone 5: Alignment And Dense-Surface Acceptance — Evidence Complete

- Launch the generated variants through the existing in-memory viewer scene
  contract.
- Run the staged alignment workflow with complete truth diagnostics.
- Exercise dense extraction on selected mutually visible pairs.
- Write the first full-scale evidence package and propose numerical thresholds
  in a separate reviewable documentation change.

Implemented by `ProjectionDenseSurfaceSyntheticAcceptance`. It constructs
ordinary in-memory viewer scenes from shared truth images and reported geometry
without exposing truth to the viewer, then runs the existing render, match,
filter, fixed-reference OPK solve, safe-apply, and dense extraction stages.
Post-run diagnostics compare sparse observations and retained dense source
coordinates with compact truth, explicitly excluding genuine occlusion from
error statistics. The ignored configured evidence contains four completed
alignment runs, four successful dense products, and exact two-pass
repeatability. The compact MAT/JSON package records runtime and memory evidence
without embedding image arrays. See
`docs/dense_surface_synthetic_acceptance_report.md`. Conservative numerical
thresholds are proposed separately in
`docs/dense_surface_synthetic_acceptance_thresholds.md`.

## Deferred Expansion

The schema and pure trajectory interface should allow, but this workstream does
not yet implement:

- a maximum-image-count mode within the pitch field of regard;
- degraded, interrupted, differential, or precision GNSS aiding;
- gimbal encoder, boresight, mounting, timing, or lever-arm errors;
- independent repeat passes with separately drawn biases;
- piecewise-linear orbit legs around the target;
- true curved/orbiting trajectories;
- per-column OPK correction; and
- a more practical smoothly varying OPK model defined at configurable image
  posts and interpolated between them.

Production file throughput, a C++ backend port, and NITF output remain a much
later deployment concern. TIFF and PNG are sufficient for the MATLAB prototype.
