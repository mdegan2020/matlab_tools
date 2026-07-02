# Projection Viewer Development Plan

This document tracks the current MATLAB projection viewer prototype and the
remaining roadmap. It supersedes the original first-cut milestone plan: the
initial harness, mesh builder, app, responsiveness work, exact readback
prototype, and multi-layer support have all been implemented.

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

tests/PlanarProjectionTest.m
tests/ProjectionViewerHarnessTest.m
tests/ProjectionSourceGeometryTest.m
tests/ProjectionMeshBuilderTest.m
tests/ProjectionReadbackRendererTest.m
tests/ProjectionLayerManagerTest.m
tests/ProjectionViewerStateTest.m
tests/ProjectionViewerAppInteractionTest.m

runProjectionViewerPrototype.m
runTests.m
buildfile.m
```

Local prototype TIFFs live under `test_data/` and are intentionally ignored by
git. The default test image is `test_data/10.tif`; current two-layer manual
testing commonly uses `test_data/10.tif` and `test_data/102.tif`.

Development is currently on macOS. MATLAB GPU acceleration through Parallel
Computing Toolbox is not available in this macOS configuration, so the CPU path
is required and remains the tested reference path. Future GPU support should be
optional, guarded by capability checks, and limited to pure numeric work.

Real data may be RGB or single-band. Typical real image sizes are expected to be
around `15000 x 10000`, with possible growth to roughly `30000 x 20000`. The
design should continue to avoid dense full-resolution per-pixel 3D vector
storage and avoid unnecessary full-size temporary arrays.

## Current High-Level Capability

The current prototype can:

1. Load one or more image layers.
2. Generate synthetic linear-array-style source geometry for each layer.
3. Accept sparse source geometry through a `SampleFcn(rowIndices, columnIndices)`
   adapter contract.
4. Project sampled source rays onto a shared target projection plane.
5. Preview projected textures in a fixed frame-camera-style view.
6. Manipulate projection plane tip, tilt, camera twist, layer alpha/visibility,
   per-layer projection offsets, and per-layer omega/phi/kappa view-vector
   corrections.
7. Serialize and restore a human-readable JSON viewer state.
8. Render deterministic headless frame-camera readback images with configurable
   interpolation and basic multi-layer blending.

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

## Interactive Viewer Controls

The app is programmatic MATLAB UI code using `uifigure` and `uigridlayout`, not
an App Designer `.mlapp` file.

Current controls:

- mouse wheel zooms the view.
- plain left-drag pans the camera.
- Shift + wheel adjusts projection-plane tip.
- Alt/Option + wheel adjusts projection-plane tilt.
- Control + wheel adjusts camera twist.
- W/A/S/D translates the selected layer up/left/down/right on the projection
  plane.
- Control + left-drag translates the selected layer on the projection plane.
- I/K adjust phi.
- J/L adjust omega.
- U/O adjust kappa.
- Control + right-drag adjusts omega and phi so the selected layer tracks the
  mouse drag.
- layer dropdown selects the active layer.
- alpha slider changes selected-layer alpha.
- Visible checkbox changes selected-layer visibility.
- blend dropdown supports `"alpha"` and `"redBlueAnaglyph"`.
- Cycle advances the single-active-layer change workflow.
- Save/Load write and read JSON viewer state.
- Reset returns tip, tilt, twist, and alpha to defaults and restores the frame
  camera view.

Omega and phi keyboard steps default to one estimated IFOV for the selected
layer. Kappa defaults to `0.1` degrees.

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
direction to avoid renderer depth fighting.

### Headless Readback

`ProjectionReadbackRenderer.renderScene(scene, options)` renders visible layers
without MATLAB graphics. It currently supports:

- deterministic output images.
- configurable `OutputSize`.
- interpolation values `"bilinear"` and `"nearest"`.
- single-band and RGB outputs.
- visible-layer filtering.
- alpha compositing.
- red/blue anaglyph compositing.

The readback prototype is suitable for qualitative and unit-test validation. It
is not yet a production tiled renderer for very large images.

### Preview/Exact Comparison

An app mode that shows preview, exact readback, and difference/flicker views is
not yet implemented. This remains a likely next milestone.

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
- compact UI control layout.
- Control + left-drag layer translation.
- Control + right-drag omega/phi correction.

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
interactions.

## Active Roadmap For Discussion

The items below are intentionally not resolved in this cleanup. They should be
prioritized and specified with user guidance before implementation.

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

### Preview/Exact Comparison Mode

A comparison view could show interactive preview, exact readback, and
difference/flicker output. This would help quantify where MATLAB graphics
interpolation and camera behavior differ from the headless renderer.

### Large-Image Tiling And Pyramids

For `15000 x 10000` to `30000 x 20000` imagery, likely future work includes
`blockedImage`, image pyramids, zoom-dependent tile selection, lower-resolution
textures during interaction, and full-resolution exact readback outside the UI
loop.

### Optional GPU Path

GPU support should remain optional and CPU-equivalent. Candidate acceleration
targets are sampled ray generation, ray-plane intersections, interpolation, and
readback resampling.

### Geometry API Ray/Line Semantics

`tracked_issues.md` records a ray-versus-line ambiguity:

- `PlanarProjection.intersectPlane` currently allows signed line-plane
  intersections.
- `PlanarProjection.triangulateRays` currently solves closest points for
  infinite lines.

Before exact backend readback becomes authoritative, decide whether these APIs
should enforce forward-ray semantics or be documented/renamed as signed-line
operations.

### Blend And Change-Detection Workflows

Current blend support is alpha and red/blue anaglyph, plus layer cycling. Future
work may add difference, flicker, swipe, false-color, checkerboard, or other
change/stereo workflows.

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
7. Support RGB and single-band imagery.
8. Do not commit local prototype TIFFs or local agent notes.
9. Preserve the existing `PlanarProjection` API unless a deliberate geometry
   semantics decision changes it.
