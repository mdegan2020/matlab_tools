# Sightline Workbench Development Plan

This document tracks the Sightline Workbench architecture, completed feature
trees, and broader roadmap. For the concise current implementation queue, see
`docs/project_status.md`. It supersedes the original first-cut milestone plan:
the initial harness, mesh builder, app, responsiveness work, exact readback
prototype, multi-layer support, backend processor, auto-alignment tree, and
display-preview pyramid work have all been implemented.

The project goal remains a backend-capable processor that can read, render, and
write projected imagery without interaction. The interactive MATLAB app is the
current exploration surface for validating geometry, layer alignment, and
operator controls before those workflows are moved into more automated
processing.

## Current Context

The repository now contains:

```text
src/PlanarProjection.m             Core projection geometry helpers
src/ProjectionViewerHarness.m      Synthetic scene/layer/source-geometry builder
src/ProjectionSourceGeometry.m     Sparse grid source-geometry adapter
src/ProjectionMeshBuilder.m        Pure sampled projection mesh builder
src/ProjectionReadbackRenderer.m   Headless frame-camera readback prototype
src/ProjectionLayerManager.m       Multi-layer workflow helpers
src/ProjectionViewerState.m        JSON viewer-state serialization
src/ProjectionViewerApp.m          Programmatic interactive preview app
src/ProjectionPreviewPyramid.m     Display-only preview pyramid/tile helper
src/ProjectionAlignment*.m         Alignment request/options/result, matching, scheduling, solving, and runner
src/ProjectionDenseSurface*.m      Analysis-only dense SGM extraction and result viewers
src/ProjectionBackendJob.m         Backend job contract/serialization helpers
src/ProjectionBackendOutputGrid.m  Backend full-extent output-grid planner
src/ProjectionBackendOutputWriter.m Backend TIFF/PNG/mask/metadata writer
src/ProjectionBackendTiledRenderer.m Backend serial/threaded tiled renderer
src/ProjectionBackendGpuSupport.m  Optional MATLAB-managed GPU checks
src/ProjectionBackendRenderPlan.m  Runtime-only reusable backend render plan
src/ProjectionFullSourceInverseWarp.m Full-source backend mapping and sampling
src/ProjectionBackendProcessor.m   Backend validation/render facade

tests/PlanarProjectionTest.m
tests/ProjectionViewerHarnessTest.m
tests/ProjectionSourceGeometryTest.m
tests/ProjectionMeshBuilderTest.m
tests/ProjectionReadbackRendererTest.m
tests/ProjectionLayerManagerTest.m
tests/ProjectionViewerStateTest.m
tests/ProjectionViewerAppInteractionTest.m
tests/ProjectionAlignment*.m
tests/ProjectionBackend*.m

runProjectionViewerPrototype.m
runProjectionViewer.m
runSyntheticAlignmentPrototype.m
runTests.m
buildfile.m
validateProjectionBackendJob.m
scripts/backend_interactive_evaluation.m
docs/backend_app_workflow.md
docs/alignment_workflow_hardening_plan.md
docs/backend_milestone_9_custom_gpu_kernel_assessment.md
docs/dense_surface_feature_pack.md
docs/performance_optimization_workplan.md
docs/project_status.md
```

Local prototype TIFFs live under `test_data/` and are intentionally ignored by
git. The default test image is `test_data/10.tif`; current two-layer manual
testing commonly uses `test_data/10.tif` and `test_data/102.tif`.

Development is currently on macOS. MATLAB GPU acceleration through Parallel
Computing Toolbox is not available in this macOS configuration, so the CPU path
is required and remains the tested reference path. The backend's optional GPU
path is capability-checked and limited to pure numeric work.

Real data may be RGB or single-band. Typical real image sizes are expected to be
around `15000 x 10000`, with possible growth to roughly `30000 x 20000`. The
design should continue to avoid dense full-resolution per-pixel 3D vector
storage and avoid unnecessary full-size temporary arrays.

## Current High-Level Capability

Sightline Workbench can:

1. Load one or more image layers.
2. Generate synthetic linear-array-style source geometry for each layer.
3. Accept sparse source geometry through a `SampleFcn(rowIndices, columnIndices)`
   adapter contract.
4. Launch real in-memory `uint8` image layers with sparse view-vector geometry
   definitions and a supplied projection plane.
5. Project sampled source rays onto a shared target projection plane.
6. Preview projected textures in a fixed frame-camera-style view, including
   display-only pyramids and visible tile selection for large layers.
7. Manipulate projection plane tip, tilt, camera twist, layer alpha/visibility,
   per-layer projection offsets, and per-layer omega/phi/kappa view-vector
   corrections.
8. Serialize and restore a human-readable JSON viewer state.
9. Run feature-based auto-alignment from the GUI or backend over selected
   single-band analysis inputs, then apply solved corrections to all bands
   during rendering.
10. Export backend jobs directly from the app or write them as JSON plus `.mat`
   scene payloads.
11. Validate backend jobs without rendering.
12. Render deterministic headless composite and per-layer outputs with
   configurable interpolation, tiled CPU execution, optional thread execution,
   optional MATLAB-managed GPU acceleration, masks, metadata, and basic
   multi-layer blending.
13. Run exploratory CPU semi-global matching after selected-pair alignment and
    triangulate dense correspondences from current corrected source rays into a
    runtime-only metric height surface.
14. Instrument and structurally optimize viewer interaction with latest-state
    camera scheduling, LOD hysteresis, cached/vectorized tile visibility,
    differential surface reuse, bounded runtime caches, coalesced alpha
    rendering, lazy preview/UI storage, and scalar single-band textures.

## Core Design Principles

### Responsiveness Is The App Contract

Interactive controls must avoid queued-event lag and judder. The app should
reuse graphics objects, update existing surface vertices and alpha values, avoid
reloading images during interaction, use coarser sampled geometry during drag,
and converge to the latest requested state on mouse release or settled slider
events.

### Explainability Is The Computation Contract

Scene, layer, source geometry, mesh, render, and viewer state should remain
plain structs or value-like data. Graphics handles belong only to the app layer.
The graphics layer visualizes computed state; it does not own the mathematical
model.

### Backend Compatibility Is Required

Preview and exact readback should share scene/layer state and pure geometry
helpers. The headless renderer must remain callable without MATLAB graphics.
Viewer-only display accelerators, including preview pyramids and visible tile
selection, must not replace or downsample the source images exported to backend
jobs.

### CPU Baseline, Optional GPU Acceleration

CPU execution is mandatory and tested. GPU execution, if added later, should be
opt-in or automatically enabled only after capability checks. Data assigned to
MATLAB graphics objects must be gathered back to CPU arrays.

## Data And Geometry Contracts

### Image Coordinates

Use MATLAB image indexing:

```matlab
Image(y, x, :)
```

where `y` is row and `x` is column. For the linear-array model, each image
column is one acquisition instant.

### Source Geometry Contract

All synthetic and real geometry adapters should expose:

```matlab
[G, V] = sourceGeometry.SampleFcn(rowIndices, columnIndices);
```

where:

- `rowIndices` are MATLAB image row indices.
- `columnIndices` are MATLAB image column indices.
- `G` is `3 x numel(columnIndices)`.
- `V` is `3 x numel(rowIndices) x numel(columnIndices)`.
- `G(:, ix)` applies to all requested rows for `columnIndices(ix)`.
- `V(:, iy, ix)` corresponds to `Image(rowIndices(iy), columnIndices(ix), :)`.
- coordinates may be any arbitrary Cartesian world frame, including future ECEF.
- vectors should be finite and nonzero.

Downstream code should prefer `SampleFcn` over synthetic-only fields. Synthetic
fields can exist for diagnostics, but the mesh builder and renderer should not
depend on them except for explicitly supported correction axes.

### Sparse Geometry Adapter

`ProjectionSourceGeometry.fromGrid` adapts sparse, uniformly spaced row/column
geometry posts into the same `SampleFcn` contract. This is the current bridge
for future sensor-specific camera models that cannot provide dense full-image
view vectors.

For a linear-array sensor:

```matlab
G(:, n)          % one perspective center per geometry column post
V(:, m, n)       % one view vector per row/column geometry post
```

The adapter interpolates requested image row/column indices from those posts and
can carry optional IFOV metadata for OPK step sizing.

### Scene Structure

The scene model is:

```matlab
scene = struct();
scene.frameCamera = camera;
scene.renderOrigin = renderOrigin;
scene.preview = previewOptions;
scene.renderOptions = renderOptions;
scene.layers = layers;
```

`scene.layers` supports one or more layers. The app defaults the selected layer
to the topmost layer.

### Layer Structure

Current layer fields include:

```matlab
layer = struct();
layer.Name = "Layer name";
layer.Image = imageData;
layer.ImagePath = imagePath;
layer.DisplayTexture = textureData;
layer.SourceGeometry = sourceGeometry;
layer.BaseProjectionPlane = plane0;
layer.CurrentProjectionPlane = plane;
layer.MeshSampling = meshSampling;
layer.Alpha = 1.0;
layer.BlendMode = "alpha";
layer.Visible = true;
layer.ProjectionOffsetMeters = [0; 0];
layer.ViewVectorAngularOffsetsDegrees = [0; 0; 0]; % omega, phi, kappa
```

`Image` remains the full source image used by readback and backend jobs.
`DisplayTexture` may be decimated for interactive display, and the app may also
create display-only preview pyramid levels outside the layer struct.

`ProjectionOffsetMeters` shifts where the image is projected on the current
projection plane. It does not move the projection plane and does not move the
source sensor origin.

`ViewVectorAngularOffsetsDegrees` rotates source view vectors before planar
intersection. Omega acts about the source image Y axis, phi about the source
image X axis, and kappa about the axis from the source reference origin to the
projection-plane origin.

### Mesh Sampling Structure

Independent row and column sampling is required:

```matlab
meshSampling = struct();
meshSampling.RowStride = 16;
meshSampling.ColumnStride = 8;
meshSampling.RowIndices = rowIndices;
meshSampling.ColumnIndices = columnIndices;
```

The app maintains default mesh sampling and coarser drag-preview sampling. On
mouse release, the selected operation refreshes back to default sampling.

## Projection And View Model

The conceptual pipeline is:

```text
source image and source collection geometry
    -> sample source origins and view vectors
    -> apply per-layer OPK view-vector corrections
    -> intersect rays with a shared projection plane
    -> apply per-layer projection-plane offsets
    -> preview projected textures in a fixed frame-camera-style view
    -> optionally render exact headless frame-camera readback
```

The shared projection plane can be created from:

```matlab
plane = PlanarProjection.definePlane(G0, V0, V1, R0);
plane = PlanarProjection.defineStereoPlane(G1, V1, R1, G2, V2, R2);
plane = PlanarProjection.defineFitPlane(G0, V0, P1, P2, P3, P4);
plane = PlanarProjection.definePlaneFromBasis(P0, VX, VY);
```

The harness supports `ProjectionPlaneMode` values `"current"`, `"fit"`, and
`"stereo"`, and it also accepts an explicit projection plane.

Tip and tilt rotate the current projection plane about its local axes while
keeping `P0` fixed:

```matlab
Rtip = rotationAboutAxis(plane0.basis(:, 1), tipRadians);
Rtilt = rotationAboutAxis(plane0.basis(:, 2), tiltRadians);
R = Rtilt * Rtip;

VX = R * plane0.basis(:, 1);
VY = R * plane0.basis(:, 2);
plane = PlanarProjection.definePlaneFromBasis(plane0.P0, VX, VY);
```

The frame camera is defined with:

```matlab
camera = PlanarProjection.defineFrameCamera(G0, V0, F, referencePlane);
```

The camera/view geometry remains fixed while projection plane and layer
corrections are manipulated. Twist rolls the viewer camera up vector about the
camera view direction; it does not rotate the projection plane.

Initial framing centers the visible projected footprint by translating the
camera position and target together in the camera screen plane. The translation
preserves the configured view direction and camera-to-target distance. The
camera view angle is then fitted to the footprint and viewport rather than
being clamped to the historical `0.05`-degree floor, which could make a small,
long-range real-data footprint nearly invisible.

## Interactive Viewer Controls

The app is programmatic MATLAB UI code using `uifigure` and `uigridlayout`, not
an App Designer `.mlapp` file.

Current controls:

- mouse wheel zooms the view.
- plain left-drag pans the camera.
- Shift + wheel adjusts projection-plane tip.
- Alt/Option + wheel adjusts projection-plane tilt.
- Control + wheel adjusts camera twist.
- Up/Down arrows adjust projection-plane tip by `0.5` degrees.
- Left/Right arrows adjust projection-plane tilt by `0.5` degrees.
- W/A/S/D translates the selected layer up/left/down/right on the projection
  plane.
- Control + left-drag translates the selected layer on the projection plane.
- Alt/Option + left-drag adjusts omega and phi so the selected layer tracks the
  mouse drag.
- I/K adjust phi.
- J/L adjust omega.
- U/O adjust kappa.
- double left-click shows the next layer and hides the other layers.
- spacebar down temporarily hides the selected layer; spacebar up shows it.
- layer dropdown selects the active layer.
- `+` and `-` buttons beside the layer label swap the selected layer with the
  next or previous layer in the stack.
- alpha slider changes selected-layer alpha.
- Visible checkbox in the layer header changes selected-layer visibility.
- right-click context menu on the image contains Save, Load, Cycle, Reset, Help,
  Crosshair, Alignment Panel, and Blend mode controls.
- alignment controls are hidden by default and open a separate lazy nonmodal
  Alignment Workbench. It supports selected-pair or visible-layer scope,
  fast/quality presets, detector/loss choices, optional coplanarity filtering,
  a projection-plane ROI, pair and observation curation, and explicit Match,
  Filter, Solve, Preview, Apply, Revert, and Clear stages.
- after Preview or Apply, Dense surface runs CPU SGM on fresh pair-specific
  alignment working images and opens runtime intensity and metric surface
  views.
- Blend mode context menu supports `"alpha"` and `"redBlueAnaglyph"`.
- Crosshair toggles cyan screen-space guide lines across the image viewport.
- Cycle shows the next layer and hides the others without changing layer alpha.
- Save/Load write and read JSON viewer state.
- Reset restores neutral tip, tilt, twist, layer order, visibility, alpha, blend
  mode, WASD projection offsets, OPK corrections, and the frame camera view.

Omega and phi keyboard steps default to one estimated IFOV for the selected
layer. Kappa defaults to `0.1` degrees.

The Viewer Orientation and Anaglyph Presentation Pack is complete:

- extend twist slider/control range to `+/-85` degrees;
- for real-data launches with an explicit oblique projection plane and no
  caller-specified camera pose, orient the default camera so the plane normal's
  projection onto the monitor/glass points toward the top of the screen;
- infer two-image anaglyph left/right roles from the sensor baseline projected
  into the current view, with left eye rendered red;
- add display-only stereo separation/exaggeration and screen-depth offset
  controls for anaglyph review; and
- brighten anaglyph mode through lightweight presentation controls such as
  channel gain/floor/alpha policy, without replacing the production surface
  render path.

The two-image assignment uses the sensor-reference baseline projected onto the
current camera-right direction. The screen-left eye is red, the assignment
refreshes when twist changes its ordering, and an unobservable baseline falls
back deterministically to layer order. Presentation strength is bounded in
viewport-relative units, while screen depth is stored in runtime metres. Both
controls translate existing graphics surfaces and do not rebuild meshes, call
`SampleFcn`, alter viewer-state serialization, or affect backend radiometry.

## Preview Versus Exact Rendering

### Interactive Preview

The app uses MATLAB graphics surfaces:

```matlab
h = surface(ax, X, Y, Z, textureData, ...
    FaceColor="texturemap", ...
    EdgeColor="none");
```

Callbacks update existing surface `XData`, `YData`, `ZData`, `CData`,
`FaceAlpha`, and `Visible` values. Multi-layer preview surfaces share the same
projection plane and use a display-only depth bias along the frame-camera view
direction to avoid renderer depth fighting. Stabilized axes limits cover the
supported tip/tilt range so preview surfaces do not clip at large
projection-plane angles or change apparent scale on the first edit.

Large layers may use `ProjectionPreviewPyramid` to create display-only pyramid
levels and tiled preview surfaces. Tile selection uses the current camera view
and chooses an appropriate decimation level for the visible footprint. Cached
tile footprints and camera bounds use render-origin-relative coordinates;
absolute world coordinates must not be compared directly with the graphics
camera. This is strictly an app responsiveness feature: backend jobs keep the
original layer `Image` data and do not consume preview pyramid levels.

### Headless Readback

`ProjectionReadbackRenderer.renderScene(scene, options)` renders visible layers
without MATLAB graphics. It currently supports:

- deterministic output images.
- configurable `OutputSize`.
- interpolation values `"bilinear"` and `"nearest"`.
- full-source inverse mapping from output points to source row/column positions.
- single-band, RGB, and arbitrary-band outputs using one shared band warp.
- visible-layer filtering.
- alpha compositing.
- red/blue anaglyph compositing.

Backend/readback radiometry defaults to `fullSourceInverseWarp`; the historical
`sparseIntensityScatteredInterpolant` mode is retained only as an explicit
comparison oracle. Display pyramids and tiled preview data are never inputs to
either mode.

Alignment working images default to `fullSourceInverseWarp` after the
Reliability Pack 2 oblique-terrain comparison. The historical sparse renderer
remains an explicit alignment-only comparison oracle. This default samples the
selected analysis band from full source radiometry onto a bounded working grid;
the resulting working images still never enter backend products, and the
backend numerical-mode contract remains independent.

The readback helper is suitable for qualitative and unit-test validation. Large
backend jobs use `ProjectionBackendTiledRenderer` through
`ProjectionBackendProcessor`, with serial or opt-in thread-pool tile execution.

### Preview/Exact Comparison

A production app mode that shows preview, exact readback, and
difference/flicker views is not implemented. The Pack 8 CPU raster path provides
an optional diagnostic comparison API, but the production viewer remains on
differential tiled surfaces. A richer operator comparison view is deferred and
is not the active implementation queue.

## Viewer State

`ProjectionViewerState` validates, encodes, decodes, writes, and reads a
JSON-serializable state:

```matlab
state.Format
state.Version
state.LayerCount
state.SelectedLayerIndex
state.Projection.TipDegrees
state.Projection.TiltDegrees
state.View.TwistDegrees
state.Camera.Position
state.Camera.Target
state.Camera.UpVector
state.Camera.ViewAngle
state.Camera.Projection
state.Layers(k).Alpha
state.Layers(k).Visible
state.Layers(k).BlendMode
state.Layers(k).ProjectionOffsetMeters
state.Layers(k).ViewVectorAngularOffsetsDegrees
```

The app can export/import state programmatically, construct from an initial
state, and save/load state from GUI file dialogs.

## Historical Milestone Status

The original milestone plan is complete unless otherwise noted.

| Milestone | Status | Notes |
| --- | --- | --- |
| 1. Data model and harness | Complete | `ProjectionViewerHarness`, scene/layer/source structs, synthetic `SampleFcn`, RGB/single-band display prep, tests. |
| 2. Pure mesh builder | Complete | `ProjectionMeshBuilder`, sampled intersections, render-origin shift, projection offsets, OPK correction support, tests. |
| 3. Interactive app | Complete | Programmatic app, launcher, fixed camera-style preview, tip/tilt/alpha, pan/zoom, tests. |
| 4. Responsiveness refinement | Complete | `drawnow limitrate`, drag-preview sampling, settled refresh, stable axes, reusable surfaces. |
| 5. Exact backend readback prototype | Complete | Headless renderer with bilinear default, nearest option, RGB/single-band, alpha/anaglyph blending, tests. |
| 6. Multi-layer extension | Complete | 1-N layers, independent alpha/visibility/blend/geometry, top-layer default, depth bias, layer cycling, tests. |

Post-milestone features already added:

- projection plane mode selection and explicit plane injection.
- camera twist control.
- modifier-wheel controls for tip, tilt, and twist.
- image-axis decoration removal.
- selected-layer WASD projection offsets.
- selected-layer OPK view-vector corrections.
- IFOV-derived omega/phi key steps.
- sparse source-geometry grid adapter.
- JSON state save/load.
- compact UI control layout with image context menu, layer-order buttons, and
  header-row visibility control.
- Control + left-drag layer translation.
- Alt/Option + left-drag omega/phi correction.
- image-space crosshair overlay.
- visibility-preserving layer cycling and reset-all viewer state restoration.
- real-data launcher support for in-memory images and sparse sensor geometry.
- hidden-by-default alignment panel with selected-pair and visible-layer
  workflows, fast/quality presets, ROI filtering, pair enablement, staged
  match/solve state, raw/filtered match counts, clear-overlays controls,
  preview/apply/revert, and backend integration.
- expanded `-85` to `85` degree tip/tilt controls, stabilized preview axes,
  footprint-centered initial viewport framing (including sub-`0.05`-degree
  views), and arrow-key tip/tilt nudges.
- display-only preview pyramids and visible preview tiling for large layers,
  while preserving full-resolution image data for readback and backend jobs.

## Validation

Default validation remains:

```matlab
results = runTests;
```

or:

```matlab
buildtool test
```

The current suite exercises pure geometry, scene construction, sparse geometry,
mesh building, readback, layer workflows, state serialization, and app
interactions. The current fresh-class baseline is 416/416 passing tests with no
failures or incomplete tests.

## Backend Processor Work Plan

The backend processor should turn an interactively aligned viewer configuration
into a repeatable noninteractive render. The app's save/load state is the natural
operator-state bridge, but it should not be the only job description. A complete
backend job also needs scene inputs, geometry references, output policy, and
execution policy.

### Backend Job Contract Decisions

- Jobs must be invokable directly from MATLAB with live in-memory structs.
- Jobs must also be serializable for repeatable runs.
- Lightweight job parameters and viewer state should be JSON-serializable.
- Heavy scene data, sparse geometry grids, and view-vector arrays should be
  stored in `.mat` files rather than JSON.
- A caller should not be forced to write JSON just to run a job.
- The backend should accept either live values or paths to serialized JSON/MAT
  files.

Target API shape:

```matlab
result = ProjectionBackendProcessor.run(job);
result = ProjectionBackendProcessor.run("job.json");
result = ProjectionBackendProcessor.run("job.mat");
```

where a live job can contain:

```matlab
job.Scene = scene;
job.ViewerState = state;
job.RenderOptions = renderOptions;
job.Output = outputOptions;
job.Execution = executionOptions;
```

and a serialized JSON job can refer to heavier files:

```matlab
job.SceneMatPath = "scene_geometry.mat";
job.ViewerStatePath = "viewer_state.json";
job.Output.Directory = "outputs";
job.Output.Formats = ["tiff", "png"];
```

### Backend Output Decisions

- Produce a composite output.
- Produce per-layer outputs.
- If the selected blend mode is `redBlueAnaglyph`, the composite output should
  be an anaglyph image.
- Preserve per-layer unblended readbacks so downstream analysis is not limited
  to the composite.
- Initial image output formats are TIFF and PNG.
- Backend image processing should support an arbitrary number of bands per
  image. It may assume bands within each image are already spectrally
  registered and that the same solved warp applies to every band in that image.
- Include sidecar metadata describing inputs, output grid, render options,
  execution mode, timing, and state summary.

Interactive two-image anaglyph assignment is geometry-derived and uses
left-eye-red mapping. The headless backend retains its existing layer-order
channel contract. Interactive separation/exaggeration and in/out screen-depth
controls are display-only until a later explicit backend/export product
contract is designed.

### Backend Output Grid Decisions

Backend output should not reproduce transient app pan/zoom. It should:

- apply viewer state to the scene.
- honor tip, tilt, twist, layer visibility, alpha, blend mode, projection
  offsets, and OPK corrections.
- ignore app pan/zoom when choosing backend output bounds.
- cover the complete projected extent of all rendered layers.
- use twist to orient the backend output axes.
- attempt to preserve the effective input scene resolution without inflating
  output dimensions unnecessarily.
- warn or require confirmation if the native-ish output grid would become
  unexpectedly huge.

There is no hard runtime target yet. Correct, clean, measurable CPU behavior
comes first; optimization follows profiling.

### Backend Milestones

Implementation status:

- Backend Milestones 1-10 are complete, validated, and committed.
- The backend now supports live and serialized jobs, `.mat` scene payloads,
  headless viewer-state application, output-grid planning, composite/per-layer
  image writers, hardened readback masks and band handling, serial tiled CPU
  rendering, opt-in `parpool("threads")` tile execution, optional
  MATLAB-managed `gpuArray` compositing with CPU fallback, a documented custom
  GPU-kernel assessment, app job export, validate-only job checks, and optional
  pre-render alignment with aligned-state and diagnostics outputs.
- See `docs/backend_app_workflow.md` for the operator workflow from app
  alignment to backend validation and rendering.
- See `docs/backend_milestone_9_custom_gpu_kernel_assessment.md` for the
  current decision that custom GPU kernels are not enabled without profiling
  evidence.
- The Auto Alignment Feature Tree milestones 1-13 are complete, validated, and
  committed; the milestone list below is retained as implementation history and
  design reference.
- Backend Performance Packs 0-5 subsequently added one reusable runtime render
  plan per job, selected full-source inverse-warp radiometry, and bounded serial
  and threaded tiled-TIFF output with explicit in-memory/in-flight limits.
  explicit radiometric/precision policy, and serial TIFF source-region reads.

#### Backend Milestone 1: Job Contract And Serialization

Deliverables:

- `ProjectionBackendJob` or equivalent helper for validating job structs.
- live in-memory job invocation.
- JSON serialization for lightweight job parameters.
- `.mat` serialization for scene/geometry payloads.
- tests for live jobs and path-based jobs.

Feedback checkpoint:

- Review job JSON and MAT payloads for readability, portability, and whether
  they match the desired workflow from app alignment to backend run.

#### Backend Milestone 2: Pure State-To-Scene Application

Deliverables:

- pure helper that applies `ProjectionViewerState` to a scene without creating
  `ProjectionViewerApp`.
- layer-count, layer-order, image-path, and state compatibility validation.
- tests proving app-exported state and backend-applied state produce equivalent
  scene/render state.

Feedback checkpoint:

- Save a state from an interactively aligned viewer session, apply it headlessly,
  and confirm the backend scene represents the intended alignment.

#### Backend Milestone 3: Full-Extent Output Grid Planner

Deliverables:

- output-grid planner independent of app pan/zoom.
- twist-aware output axes.
- union extent over all rendered layers.
- resolution policy based on source GSD/IFOV/mesh spacing.
- guardrails for unexpectedly large output sizes.
- tests for output extent, twist orientation, and resolution policy.

Feedback checkpoint:

- Inspect planned output sizes and extents for representative one-layer and
  two-layer states before committing to the render cost.

#### Backend Milestone 4: Processor Entry Point And Writers

Deliverables:

- `ProjectionBackendProcessor.run(job)` entry point.
- composite and per-layer render outputs.
- TIFF and PNG writers.
- sidecar metadata writer.
- deterministic naming policy for composite, per-layer, masks, and metadata.
- tests for output files and metadata.

Feedback checkpoint:

- Run a saved viewer state through the backend and inspect the generated TIFF/PNG
  outputs against the app preview.

#### Backend Milestone 5: Readback Kernel Hardening

Deliverables:

- explicit render options for output size/grid, invalid fill value, masks,
  interpolation, and per-layer output policy.
- clearer separation between output-grid construction, layer sampling,
  interpolation, and compositing.
- baseline timing instrumentation.
- tests for masks, invalid regions, single-band/RGB/arbitrary-band preservation,
  multi-layer compositing, anaglyph compositing, and state-driven rendering.

Feedback checkpoint:

- Decide whether the prototype sampled-mesh interpolation is sufficiently exact
  for current use, or whether a stricter readback kernel is needed.

#### Backend Milestone 6: Tiled CPU Renderer

This historical milestone established tiled computation and numerical
equivalence, but it did not make the complete output/write lifecycle
bounded-memory. That follow-up is Backend Performance Pack 2.

Backend Performance Pack 2 completed that historical follow-up with serial
tiled-TIFF streaming, explicit in-memory limits, and partial-file cleanup.

Deliverables:

- output tiling by rows/columns.
- bounded-memory tile processing.
- optional incremental file writing where practical.
- tile-level timing and memory reporting.
- serial tiled rendering before parallel execution.
- tests that tiled and untiled output agree numerically on small scenes.

Feedback checkpoint:

- Benchmark serial tiled rendering on available representative images and choose
  practical default tile sizes.

#### Backend Milestone 7: Thread-Pool Acceleration

Deliverables:

- `Execution.Mode = "serial"` and `Execution.Mode = "threads"`.
- use `parpool("threads")` only for parallel pool acceleration.
- do not create or use heavyweight process-based pools.
- clear behavior if a process-based pool is already active.
- tile-level parallel execution with deterministic output.
- serial-vs-threads numerical equivalence tests.

Feedback checkpoint:

- Benchmark serial versus threads on the same backend job and decide whether
  threading should be opt-in or automatic for large jobs.

#### Backend Milestone 8: MATLAB-Managed GPU Acceleration

Deliverables:

- optional Windows-targeted GPU execution path using `gpuArray` and
  GPU-supported MATLAB functions where practical.
- capability checks so macOS development and CI remain CPU-only.
- clean fallback to CPU when GPU support is unavailable.
- `gather` boundaries before file writing or graphics use.
- CPU-vs-GPU numerical comparison tests on GPU-capable systems.

Feedback checkpoint:

- Profile on the Windows GPU workstation and decide which backend kernels
  benefit from MATLAB-managed GPU acceleration.

#### Backend Milestone 9: Custom GPU Kernels If Needed

Deliverables:

- profiling report identifying bottlenecks not solved by tiled CPU, threads, or
  MATLAB-managed GPU acceleration.
- candidate custom kernel design for the specific bottleneck.
- CPU reference implementation retained for correctness.
- numerical equivalence tests against CPU and MATLAB-managed GPU paths.

Feedback checkpoint:

- Decide whether the performance gain justifies the additional maintenance cost
  of custom kernels.

#### Backend Milestone 10: Viewer/Backend Integration Polish

Deliverables:

- app helper to export a backend job from the current scene and viewer state.
- optional UI for anaglyph red/blue assignment or swap.
- documentation and runnable examples for app-to-backend workflow.
- quick validation command that checks job resolvability without rendering.

Feedback checkpoint:

- Exercise the complete operator workflow: align in app, export job, run backend,
  inspect composite and per-layer products.

## Auto Alignment Feature Tree

Auto alignment began as an interactive viewer workflow and now also runs as a
backend-capable processing step. The core implementation is a reusable
feature-based alignment engine, with the GUI and backend acting as clients of
the same pure alignment helpers.

Implementation status:

- Auto Alignment Milestones 1-13 are complete, validated, and committed.
- The implementation includes request/options/result models, synthetic
  red/blue-channel harness, projection-plane working images, detector/matcher
  capability checks, match filtering with a radial-filter hook, OPK solving,
  joint multi-image scheduling/solving, optional shared scale, ray-to-ray loss,
  GUI workflow controls, and backend alignment integration.
- Further alignment ideas are decision-gated quality and sensor-workflow
  topics, not unstarted milestone gates.
- Real-data GUI alignment hardening is tracked in
  `docs/alignment_workflow_hardening_plan.md`. Its completed first wave covers
  staged controls, guardrails, overlays, and manual curation. The selected
  Real-Data Reliability Packs 0-8 cover complete match provenance, stable layer
  identity and overlays, deterministic working images/matching, truthful 2D and
  coplanarity filtering, an implemented separate Alignment Workbench, balanced
  common/differential network solving, an `epipolarCoplanarity` loss,
  Shift+left common-anchor drag, and a consolidated synthetic validation
  matrix. The approved full-scale truth-aware synthetic expansion is the
  primary systematic alignment gate; representative Windows large-image
  performance remains external.
- Dense Surface Pack 1 is complete. From a previewed or applied selected-pair
  alignment, the Workbench can run CPU semi-global matching on fresh bounded
  alignment working images, map dense correspondences back to full-source
  observations, and triangulate corrected ray pairs into an analysis-only
  metric height surface. The first-pass contract and limitations are recorded
  in `docs/dense_surface_feature_pack.md`.
- Reliability Packs 0-4 established the data, geometry, working-image,
  deterministic matching, and truthful filtering foundations. Stable layer IDs
  now flow through viewer state, alignment requests/schedules/working images,
  match pairs, solver corrections, and backend payloads. A non-destructive
  raw-match ledger
  records explicit stage masks/reasons and coordinate/residual units;
  `SolverObservations` is canonical while `Inliers` is a compatibility alias.
  Current overlay reprojection uses exact sampled rays when available, reports
  endpoint validity independently, and remains invariant to layer reorder.
  Projection-plane ROI redraw/clear re-filters the stored pre-ROI match result
  without rerunning feature matching. Reliability Pack 2 is also complete:
  working images use stable isotropic pair-overlap grids, multi-image matching
  uses one grid per scheduled pair, repeated Match actions can reuse a
  runtime-only working-image cache, and the truth-aware oblique-terrain fixture
  selected full-source inverse warp as the alignment default. The sparse mode
  remains an explicit comparison oracle. Reliability Pack 3 adds deterministic
  valid-mask-aware preprocessing, detector support gating, explicit option and
  exhaustive-matcher dispatch, stable feature/match ordering, and public
  feature/filter-stage diagnostics. The nondeterministic approximate matcher
  is no longer a public option. The final fresh-class Pack 3 suite passes 348
  tests. Reliability Pack 4 replaces the mislabeled translation gate with
  deterministic working-pixel similarity/affine fits, makes native-coordinate
  MAD opt-in, and adds a normalized robust-centered coplanarity filter with
  explicit ray-degeneracy diagnostics. The final fresh-class Pack 4 suite
  passes 360 tests.

### Auto Alignment Design Decisions

- Matching is feature based on projection-plane working images.
- Alignment should operate on selected single-band analysis images. For
  multispectral source data, the user or caller chooses one band from each image
  for alignment.
- The solved alignment warp should then be applicable to every band in that
  image, assuming the image's bands are internally registered.
- A synthetic alignment harness supports smoke tests from the local TIFF
  dataset by taking one RGB image, using its red channel as synthetic image 1
  and its blue channel as synthetic image 2.
- The synthetic harness generates two independent geometries with enough
  disagreement to exercise alignment while preserving credible correspondence
  between the channel-derived single-band images.
- Candidate detectors/descriptors include SIFT, SURF, ORB, or MATLAB-supported
  equivalents, with capability checks and clear fallback behavior.
- Matching can run over full visible overlap or a GUI-selected rectangular ROI.
- The solver adjusts per-image `omega`, `phi`, and `kappa` corrections, with an
  optional shared image-Y scale parameter for fixed-camera linear-array
  workflows.
- WASD projection offsets are intentionally not part of the first solver path
  because small translations and small angular corrections can become difficult
  to separate.
- The default matching reference is the middle image by input order.
- The project plane is assumed to be closest to the center perspective when the
  user sets up the scene.
- The reference image is a scheduling/reference image, not a fixed truth anchor.
  All images, including the reference, may move within correction bounds.
- The selected real-data hardening design makes this explicit as a balanced
  network adjustment: a shared-frame common attitude component plus
  image-specific differential components. Equal-confidence pair corrections
  split the differential update halfway; covariance priors generalize that
  split. Weak or prior-dominated common modes must be reported from Jacobian
  observability diagnostics rather than hidden by regularization.
- Correction bounds should be tied to image angular scale. The default hard cap
  should be less than one quarter of the full field of view, for example
  `0.25 * min(horizontalFOV, verticalFOV)`.
- Solvers include least-adjustment regularization so the solution stays
  close to the original pointing knowledge and does not drift or run away.
- The default loss mode minimizes two-dimensional feature residuals on the
  projection plane.
- A second loss mode evaluates ray-to-ray closest approach between matched
  feature observations.
- The implemented third `epipolarCoplanarity` loss uses normalized
  per-observation baseline/ray coplanarity and may also serve as an optional
  pre-solve filter.
  It must use forward-ray validity diagnostics and handle varying pushbroom
  origins and degenerate baselines explicitly.
- Optimal relief-rich stereo means compatible forward rays and reduced
  epipolar/skew error, not necessarily zero projection-plane disparity.
- DEM/terrain-constrained losses are explicitly out of scope for the selected
  hardening packs. They may be reconsidered later as optional absolute
  constraints.
- The match filtering pipeline includes a pluggable `RadialFilterFcn`.
- Shift+left common-anchor drag moves both images through a two-degree-of-freedom
  shared boresight correction while preserving differential correction and
  relief-supported disparity. One anchor does not adjust common kappa; final
  OPK corrections are serialized while manual-drag history remains
  session-only.

### Auto Alignment Milestones

Each milestone in this section is complete. The deliverable lists are preserved
as a historical checklist for future reviews and regressions.

#### Auto Alignment Milestone 1: Alignment Request And Result Model

Deliverables:

- `ProjectionAlignmentRequest`, `ProjectionAlignmentOptions`, and
  `ProjectionAlignmentResult` structs or equivalent helpers.
- option fields for detector, matcher, filter pipeline, loss mode, scheduling
  strategy, movable parameters, bounds, regularization weights, and diagnostics.
- result fields for matched pairs, inliers, residuals, solved corrections,
  convergence state, warnings, and timing.
- tests for option defaults, validation, and serialization compatibility.

Feedback checkpoint:

- Review request/result structs before wiring them into the viewer so the model
  remains usable from both GUI and backend code.

#### Auto Alignment Milestone 2: Synthetic Single-Band Alignment Harness

Deliverables:

- harness that accepts a local RGB TIFF fixture and constructs two synthetic
  single-band alignment layers from the red and blue channels.
- independent synthetic geometries and OPK perturbations for the two layers,
  with approximately overlapping projection-plane footprints.
- known-perturbation metadata for smoke tests and solver diagnostics.
- one-line launcher or example for the two-layer synthetic alignment scene,
  without committing local TIFF data.
- tests for channel extraction, single-band scene construction, geometry
  disagreement, overlap sanity, and `SampleFcn` compatibility.

Feedback checkpoint:

- Launch the synthetic red/blue-channel scene and confirm that it gives a
  useful visual and numerical smoke test before building the full solver.

#### Auto Alignment Milestone 3: Projection-Plane Working Images

Deliverables:

- pure helper that renders selected layers into common projection-plane analysis
  images at a controlled resolution.
- overlap-mask generation for each layer and layer pair.
- mappings from working-image pixels back to projection-plane coordinates and
  source observations.
- explicit separation from the display z-stagger used by the GUI renderer.
- tests for overlap extent, mask generation, coordinate mapping, and
  single-band handling.

Feedback checkpoint:

- Inspect working images and masks from representative two-layer and multi-layer
  scenes before depending on them for feature matching.

#### Auto Alignment Milestone 4: Feature Detection And Matching

Deliverables:

- detector/matcher abstraction with capability checks for available MATLAB
  feature methods.
- feature extraction on projection-plane working images.
- pairwise match table containing feature locations, scores, descriptors or
  descriptor references, and coordinate mappings.
- GUI diagnostic view for matched features without applying corrections.
- focused tests using synthetic or small fixture images where matches are known
  or at least structurally valid.

Feedback checkpoint:

- Compare detector choices on actual representative imagery and pick the first
  default for prototype alignment.

#### Auto Alignment Milestone 5: Match Filtering Pipeline

Deliverables:

- descriptor-score and ratio/uniqueness filtering.
- overlap-mask filtering.
- geometric outlier rejection for projection-plane matches.
- pluggable `RadialFilterFcn` hook for the external direction/magnitude filter.
- diagnostics that record how many matches survive each stage.
- tests for filter ordering, mask rejection, radial-filter callback behavior,
  and deterministic diagnostics.

Feedback checkpoint:

- Import and evaluate the existing radial filter on difficult oblique data, then
  decide whether it becomes default, optional, or data-condition dependent.

#### Auto Alignment Milestone 6: Two-Image 2D OPK Solver

Deliverables:

- two-image solver that minimizes projection-plane feature residuals.
- per-image `omega`, `phi`, and `kappa` corrections for both images.
- scale-aware bounds derived from approximate image field of view.
- least-adjustment regularization toward the starting pointing knowledge.
- robust residual weighting to reduce sensitivity to remaining outliers.
- preview/apply/revert support for solved corrections.
- tests for known synthetic perturbations, bounds enforcement,
  regularization behavior, and solver diagnostics.

Feedback checkpoint:

- Run on a few real two-image examples and compare visual alignment, residual
  statistics, and correction magnitudes before expanding to N images.

#### Auto Alignment Milestone 7: GUI Auto Alignment Workflow

Deliverables:

- compact viewer controls for reference layer, moving layer, detector, loss mode,
  run/cancel, preview/apply, and revert.
- live solver progress reporting.
- match and inlier overlays on the projection viewer.
- residual summary, correction summary, and warning display.
- nonblocking or interruption-friendly execution where practical.
- manual validation workflow in the README.

Feedback checkpoint:

- Exercise the full operator loop in the GUI: find matches, inspect matches,
  solve, preview, apply, revert, and save state.

#### Auto Alignment Milestone 8: Multi-Image Matching Scheduler

Deliverables:

- default reference index computed as the middle image by input order.
- center-out pair scheduling for ordered image sets, such as image 4 against
  images 3 and 5 before expanding toward images 1 and 7.
- pluggable scheduling strategies for center-star, adjacent-chain, and hybrid
  matching.
- pairwise match diagnostics and confidence scoring.
- tests for odd/even layer counts, schedule construction, and disabled/hidden
  layers.

Feedback checkpoint:

- Compare center-star, adjacent-chain, and hybrid schedules on representative
  multi-perspective data before picking the default beyond the center-out
  prototype.

#### Auto Alignment Milestone 9: Joint Multi-Image Solver

Deliverables:

- joint solver over all selected images using pairwise match residuals.
- per-image `omega`, `phi`, and `kappa` corrections, including the middle
  reference image.
- least-adjustment regularization to remove gauge freedom and avoid global
  drift.
- pairwise residual reporting before and after solve.
- tests for synthetic multi-image perturbations and solver stability.

Feedback checkpoint:

- Validate that allowing every image to move improves alignment without
  producing unintuitive global rotations or runaway corrections.

#### Auto Alignment Milestone 10: Optional Shared Focal/Y-Scale Correction

Deliverables:

- optional single shared focal-length or image-Y scale parameter for all images.
- scale bounds and regularization separate from OPK bounds.
- solver tests showing when the shared scale parameter helps versus when OPK
  corrections alone are sufficient.

Feedback checkpoint:

- Decide whether the shared scale correction is necessary for the first real
  sensor workflow or should remain an advanced option.

#### Auto Alignment Milestone 11: Ray-To-Ray 3D Loss Mode

Deliverables:

- optional loss based on closest approach between matched feature rays.
- coordinate mapping from matched projection-plane features back to source rays.
- robust handling of near-parallel rays and noisy matches.
- comparison diagnostics between 2D projection-plane loss and ray-to-ray loss.
- tests for synthetic ray geometry and numerical stability.

Feedback checkpoint:

- Compare 2D and 3D losses on oblique terrain scenes and decide whether
  ray-to-ray closest approach is useful before adding terrain-constrained losses.

#### Auto Alignment Milestone 12: Backend Alignment Integration

Deliverables:

- backend job option to run alignment before rendering.
- saved updated viewer state and alignment diagnostics.
- composite and per-layer backend output using the aligned state.
- use selected single-band inputs for alignment while applying solved image
  warps to all bands during backend rendering.
- CPU-complete execution path with later profiling for threads/GPU work if
  alignment becomes a bottleneck.
- tests for live and serialized backend jobs that include alignment options.

Feedback checkpoint:

- Run the complete headless workflow: load job, align, save diagnostics, render,
  and compare output with the GUI-aligned result.

#### Auto Alignment Milestone 13: Later GUI And Workflow Enhancements

Deliverables:

- manual rectangular ROI/rubber-band selection.
- match table or inspection tool for accepting/rejecting pairs.
- per-pair enable/disable controls for multi-image alignment.
- alignment presets for fast preview versus high-quality solve.
- documentation for recommended workflows and failure modes.
- see `docs/alignment_workflow_hardening_plan.md` for the completed follow-up
  feature tree and current synthetic-primary acceptance policy.

Feedback checkpoint:

- Decide which operator controls are genuinely useful after the automatic path
  has been exercised on real data.

## Active Roadmap For Discussion

The backend and auto-alignment feature trees, Viewer Orientation and Anaglyph
Presentation Pack, and Alignment Workbench Usability and Offset-Semantics Pack
are implemented. The Cross-System Acceleration Pass is also complete. The
Multi-Image Foundation MI-0 through MI-2 are complete, including stable view
metadata, the runtime pair controller, and active/Solo pair Workbench controls.
The remaining queue is:

1. The approved dense-surface synthetic expansion milestones in
   `docs/dense_surface_synthetic_expansion_plan.md`. Required fixture decisions
   are captured privately; implementation begins with configuration validation
   and geometry feasibility.

The items below remain broader design topics to prioritize with user guidance.

### Real Sensor Geometry Ingestion

The current bridge is `ProjectionSourceGeometry.fromGrid`. The next step is to
define how sensor-specific camera-model output should be packaged into sparse
geometry grids, metadata, correction axes, and optional IFOV values.

### Source Geometry Manipulation Model

The app now supports per-layer projection offsets and OPK view-vector
corrections. Broader sensor-geometry controls may include platform origin
offsets, attitude perturbations, scan-angle bias, range/altitude corrections, or
synthetic-geometry parameter edits. These should keep using the `SampleFcn`
contract and should not require mesh-builder special cases.

### Alignment Acceptance And Dense Stereo Follow-Up

Alignment Reliability Packs 0-8 and Dense Surface Pack 1 are complete. The
approved truth-aware synthetic expansion is the primary systematic alignment
acceptance fixture. Later air-gapped real-data findings may refine individual
metrics. Dense-surface improvements such as
calibrated/spatially varying rectification, confidence and consistency
filtering, cleanup, uncertainty, and export are decision-gated follow-up rather
than an approved pack queue. See
`docs/alignment_workflow_hardening_plan.md`,
`docs/alignment_reliability_validation_report.md`, and
`docs/dense_surface_feature_pack.md`.

### Preview/Exact Comparison Mode

A comparison view could show interactive preview, exact readback, and
difference/flicker output. This would help quantify where MATLAB graphics
interpolation and camera behavior differ from the headless renderer.

### Large-Image Tiling And Pyramids

For `15000 x 10000` to `30000 x 20000` imagery, the viewer now has an
app-facing display pyramid and visible tile selection path. Follow-up work may
still consider `blockedImage` and profiling on representative 100-150 MP
Windows scenes. The current viewer already has lazy/file-backed preview levels,
settle-aware LOD hysteresis, cached visibility, and differential tile reuse.
Backend Performance Packs 2-5 now provide bounded serial/thread TIFF output,
explicit radiometric policy, and serial file-backed source regions. Preview
pyramids remain outside backend input.

### Optional GPU Path

The backend already accepts optional MATLAB-managed `gpuArray` acceleration
with capability checks, explicit CPU fallback, and `gather` boundaries. GPU
support remains optional; viewer GPU work and custom kernels are not
recommended without target-Windows profiling that shows a bottleneck not met by
CPU tiling, `parpool("threads")`, and MATLAB-managed operations.

macOS development remains CPU-only because `gpuArray` is unsupported in the
current local environment. Windows GPU testing should add numerical-equivalence
and performance checks for GPU-capable systems.

### Geometry API Ray/Line Semantics

`tracked_issues.md` records a ray-versus-line ambiguity:

- `PlanarProjection.intersectPlane` currently allows signed line-plane
  intersections.
- `PlanarProjection.triangulateRays` currently solves closest points for
  infinite lines.

Before changing geometry semantics or tightening backend assumptions around
forward-only rays, decide whether these APIs should enforce forward-ray
semantics or be documented/renamed as signed-line operations.

### Blend And Change-Detection Workflows

Current blend support is alpha and red/blue anaglyph from the image context
menu, plus visibility-based layer cycling and simple adjacent layer-order
swapping. Future work may add difference, flicker, swipe, false-color,
checkerboard, or other change/stereo workflows.

### Scene Builder Boundary

The original plan proposed `ProjectionSceneBuilder`, but current responsibilities
are covered by `ProjectionViewerHarness`, `ProjectionSourceGeometry`, and
validation in downstream helpers. Either keep this implicit boundary or add a
small scene builder only if it removes real duplication as real sensor ingestion
becomes clearer.

## Standing Implementation Rules

1. Keep CPU complete and tested.
2. Do not require GPU support.
3. Keep MATLAB app code programmatic; do not use `.mlapp` files.
4. Keep graphics handles out of scene/layer/source structs.
5. Prefer pure functions for geometry, mesh construction, readback, and state
   serialization.
6. Keep source geometry integration centered on
   `SampleFcn(rowIndices, columnIndices)`.
7. Support single-band, RGB, and arbitrary-band imagery where backend processing
   requires it. Alignment may operate on selected single-band analysis inputs.
8. Do not commit local prototype TIFFs or local agent notes.
9. Preserve the existing `PlanarProjection` API unless a deliberate geometry
   semantics decision changes it.
10. Use only `parpool("threads")` for backend parallel-pool acceleration; do not
    create heavyweight process-based pools.
11. Treat MATLAB-managed GPU acceleration as the first GPU step; use custom GPU
    kernels only after profiling justifies them.
