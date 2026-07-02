# Projection Viewer Development Plan

This document captures the planned MATLAB viewing and rendering framework for interactive prototyping of 2D/3D image projection workflows. It is intended to be readable by a human developer and specific enough for a coding agent to implement in stages.

The project goal is to develop a backend-capable processor that reads, renders, and writes imagery without interaction. The immediate need is an interactive MATLAB tool that supports responsive exploration of projection geometry using large remote-sensing imagery.

## Current Context

The repository currently contains a compact MATLAB geometry library:

- `src/PlanarProjection.m`
- `tests/PlanarProjectionTest.m`
- `README.md`

The available prototype image is:

- `test_data/10.tif`

The TIFF is local test content and is intentionally ignored by git. Its observed characteristics are:

- truecolor RGB TIFF
- approximately `3320 x 3228`
- approximately `31 MB`
- uncompressed
- rectified, north-up remote-sensing style imagery
- approximate GSD: `0.5 m`
- approximate footprint: `1660 m x 1614 m`

The local MATLAB installation is R2026a and includes Image Processing Toolbox, Mapping Toolbox, Computer Vision Toolbox, and Parallel Computing Toolbox.

Development is currently on macOS. MATLAB does not support GPU acceleration through Parallel Computing Toolbox on this macOS configuration, so every feature must work well on CPU. After the first prototype is working, testing is expected to move to a high-end Windows workstation with MATLAB GPU support. The architecture should therefore allow optional `gpuArray` acceleration where useful, without making GPU support required.

The current test image is RGB truecolor. Real data may be RGB or single-band. Typical real image sizes are expected to be around `15000 x 10000`, with possible growth by roughly `2x` in each dimension. Individual images should remain manageable on modern memory and graphics hardware, but the design should avoid unnecessary full-size intermediate arrays.

## High-Level Goal

Build a responsive MATLAB app and supporting backend-compatible library that can:

1. Load a large image.
2. Generate or accept collection geometry for a linear-array-style sensor.
3. Project the image through its source collection geometry onto a target plane.
4. View the projected image through a fixed frame-camera model.
5. Manipulate the projection plane interactively with controls such as tip, tilt, and transparency.
6. Keep all core computation explainable and exportable to a headless batch renderer.
7. Start with one image/layer, while designing the architecture to support multiple image layers later.

## Non-Goals For The First Cut

The first implementation should not try to solve every final-rendering problem.

Do not initially implement:

- full real sensor model ingestion
- GPU-only code paths
- dense per-pixel vector storage unless required by a test
- multiple image layers in the UI
- exact pixel-identical backend readback
- tiled out-of-core rendering for imagery larger than the current TIFF
- free 3D orbit camera interaction
- App Designer `.mlapp` files

These capabilities should remain natural extensions of the architecture.

## Core Design Principles

### Responsiveness Is The App Contract

Interactive controls must avoid queued-event lag and judder. During mouse or slider manipulation, the app should render the newest requested state using a lightweight preview representation.

Initial app updates should:

- reuse graphics objects
- update existing surface vertices and alpha values
- avoid recreating UI components
- avoid reloading the image during interaction
- use sparse geometry during drag
- coalesce rapid slider events to the latest state when possible

### Explainability Is The Computation Contract

The geometry and rendering state should be represented as plain MATLAB structs or value-like classes. The computation path should be understandable without inspecting MATLAB graphics state.

The graphics layer should visualize computed state, not own the mathematical model.

### Backend Compatibility Is Required

The final renderer must be able to run without MATLAB graphics. The app may use MATLAB graphics for fast preview, but it should call pure computation functions for geometry construction and, later, exact readback.

### CPU Baseline, Optional GPU Acceleration

The CPU path is mandatory and should be the reference path for tests and correctness. Optional GPU acceleration may be added for pure numeric operations such as sampled ray generation, ray-plane intersections, image resampling, or exact readback.

GPU use must be explicit and guarded by capability checks. If a GPU is unavailable or unsupported, code must automatically fall back to CPU. Graphics-preview code should not require `gpuArray`; data used by MATLAB graphics objects should be gathered back to CPU arrays before assignment.

### Single-Layer First, Multi-Layer Ready

The first app will operate on one image and one projection layer. The data model should still use layer terminology so future stereo or change-detection workflows can render multiple projected images in the same view.

## Coordinate And Image Conventions

### MATLAB Image Coordinates

Use MATLAB image indexing:

```matlab
Image(y, x, :)
```

where:

- `y` is the row coordinate.
- `x` is the column coordinate.
- all pixels in `Image(:, 1)` are collected at time 1.
- all pixels in `Image(:, 2)` are collected at time 2.

### Supported Image Band Shapes

The first implementation should support both:

```matlab
Image(y, x)       % single-band image
Image(y, x, :)    % multiband image, initially RGB
```

Core geometry code should not depend on band count. Display code should convert image data into a texture representation suitable for MATLAB graphics:

- RGB input can be used directly when its type and range are display-ready.
- single-band input can be displayed with a default grayscale mapping.
- future exact readback should preserve source band semantics where possible.

### Linear-Array Collection Geometry

Each image column is one acquisition instant.

For a source image:

```matlab
G(:, x)          % sensor origin for image column x
V(:, y, x)       % world-frame view vector for pixel Image(y, x, :)
```

Interpretation:

- all pixels in a given column share one origin `G(:, x)`.
- row variation at fixed column is due to camera or scanner geometry.
- column variation at fixed row is due to platform motion.
- the model should be agnostic to whether row variation came from active telescope scanning, push-broom scanning, or another sensor-specific mechanism.

### Real Geometry Adapter Contract

The transition from synthetic geometry to real linear-array geometry should be clean and obvious. Synthetic geometry and real geometry should use the same source-geometry interface.

At minimum, a source geometry provider must answer this query:

```matlab
[G, V] = provider.sample(rowIndices, columnIndices);
```

where:

- `rowIndices` are MATLAB image row indices.
- `columnIndices` are MATLAB image column indices.
- `G` is `3 x numel(columnIndices)` and contains one sensor origin per requested column.
- `V` is `3 x numel(rowIndices) x numel(columnIndices)` and contains one world-frame view vector per requested pixel sample.
- `G(:, ix)` applies to all requested rows for `columnIndices(ix)`.
- `V(:, iy, ix)` corresponds to `Image(rowIndices(iy), columnIndices(ix), :)`.
- coordinates may be ECEF or any arbitrary world Cartesian frame.
- vectors should be finite and nonzero; the mesh builder may normalize them before use.

The synthetic harness should implement this same contract. The real sensor adapter can later be as simple as a wrapper around generated camera-model code that exposes the same `sample(rowIndices, columnIndices)` method or function-handle signature.

Suggested struct form:

```matlab
sourceGeometry = struct();
sourceGeometry.ImageSize = [height width];
sourceGeometry.CoordinateFrame = "world";
sourceGeometry.SampleFcn = @sampleGeometry;
sourceGeometry.Metadata = metadata;
```

Suggested function-handle signature:

```matlab
[G, V] = sourceGeometry.SampleFcn(rowIndices, columnIndices);
```

All downstream code should prefer `SampleFcn` over inspecting synthetic-only fields. Synthetic-specific fields can exist for debugging, but they should not be required by the mesh builder.

### World Coordinates

The framework should treat world coordinates as arbitrary 3D Cartesian coordinates. They may later be ECEF coordinates, but app and core code should not assume ECEF, ENU, NED, or any other Earth-fixed convention.

For synthetic test geometry:

- platform motion may be locally linear.
- a default path can move in `+Z` of the chosen world frame to approximate a "north-ish" trajectory.
- a nominal platform height or slant range of `10000 m` is acceptable for first synthetic tests.

### Local Render Frame

When world coordinates are ECEF-like, absolute position values can be large. Rendering should therefore use an origin-shifted local frame:

```matlab
Prender = Pworld - renderOrigin
Grender = Gworld - renderOrigin
```

The backend model should preserve world-frame values. The graphics preview should render local shifted values.

## Projection And View Model

The desired conceptual pipeline is:

```text
source image and source collection geometry
    -> project sampled source rays onto target projection plane
    -> render projected texture as seen by a fixed frame camera
    -> display the frame-camera output with 2D-style pan/zoom
```

### Source Image Geometry

The source image starts in a positive-focal-plane-style collection geometry. For the synthetic harness, derive normalized camera parameters from:

- image size
- approximate `0.5 m` GSD
- nominal range `10000 m`
- optical axis pointing toward the projection center

Given a `1660 m` image width at `10000 m` range, the initial synthetic horizontal angular footprint is modest, roughly 9 to 10 degrees.

### Projection Plane

The target projection plane should be defined with the existing `PlanarProjection` API, using functions such as:

```matlab
plane = PlanarProjection.definePlane(G0, V0, V1, R0);
plane = PlanarProjection.defineStereoPlane(G1, V1, R1, G2, V2, R2);
plane = PlanarProjection.defineFitPlane(G0, V0, P1, P2, P3, P4);
plane = PlanarProjection.definePlaneFromBasis(P0, VX, VY);
```

For the first synthetic case:

- `G0` is the initial or central camera/sensor location.
- `V0` is the camera optical axis.
- `V1` is a ray corresponding to a pixel around `+10` pixels in image `+X` from the optical center.
- `R0` is the nominal camera range.

Implementation note: verify whether `definePlane(G0, V0, V1, R0)` maps the `V1` offset to the intended app plane axis. If the app needs explicit image-axis orientation, add a small helper that constructs the projection plane from basis vectors in an unambiguous way.

### Frame Camera

The fixed frame camera is the view model used by both preview alignment and eventual backend readback.

Use:

```matlab
camera = PlanarProjection.defineFrameCamera(G0, V0, F, referencePlane);
```

Initial behavior:

- camera looks at the projection plane center.
- camera/view geometry remains fixed while tip/tilt sliders are manipulated.
- mouse interaction behaves like pan/zoom on the resulting 2D camera output, not free 3D orbit.

### Interactive Plane Manipulation

The initial sliders should manipulate the projection plane only.

Controls:

- `Tip`: rotate the projection plane about its local `X` axis.
- `Tilt`: rotate the projection plane about its local `Y` axis.
- `Transparency`: modulate layer alpha from `0` to `1`.

Sensor geometry and frame camera remain fixed in the first prototype.

## Preview Versus Exact Rendering

The project should explicitly separate interactive preview from exact readback.

### Stage A: Geometry-Equivalent Interactive Preview

This is the first app target.

Use MATLAB graphics to render a texture-mapped surface:

- sparse sampled geometry mesh
- source image as texture
- fixed app camera aligned to the frame-camera model as closely as practical
- 2D-style pan/zoom interaction
- fast tip/tilt/alpha updates

This stage should prioritize responsiveness and geometric interpretability. It does not need pixel-identical backend output.

### Stage B: Exact Frame-Camera Readback

This is a later backend-compatible renderer.

It should:

- use the same scene/layer state as the app
- avoid reliance on MATLAB graphics objects
- sample projected imagery according to the frame-camera model
- default to bilinear interpolation for the first exact readback implementation
- expose interpolation as an option so nearest, bicubic, or other methods can be evaluated later
- produce deterministic output images
- be callable from scripts and batch workflows

### Stage C: Preview Versus Exact Comparison

Eventually the app should support a comparison mode:

- interactive preview display
- exact readback display
- difference or flicker views if useful

This mode will help quantify where MATLAB graphics interpolation and camera behavior diverge from the backend renderer.

## Proposed Architecture

The first implementation can use structs and static/helper functions. Classes may be introduced when state ownership becomes clearer.

### Scene Structure

Use a scene-level model:

```matlab
scene = struct();
scene.frameCamera = camera;
scene.renderOrigin = renderOrigin;
scene.preview = previewOptions;
scene.layers = layer;
```

The first app will use exactly one layer:

```matlab
numel(scene.layers) == 1
```

The renderer should still loop over `scene.layers` internally where this does not add complexity.

### Layer Structure

Suggested first-layer fields:

```matlab
layer = struct();
layer.Name = "Test image";
layer.Image = imageData;
layer.ImagePath = imagePath;
layer.SourceGeometry = sourceGeometry;
layer.BaseProjectionPlane = plane0;
layer.CurrentProjectionPlane = plane;
layer.MeshSampling = meshSampling;
layer.Alpha = 1.0;
layer.BlendMode = "alpha";
layer.Visible = true;
```

### Source Geometry Structure

Use a compact representation where possible:

```matlab
sourceGeometry = struct();
sourceGeometry.ImageSize = [height width];
sourceGeometry.GSD = 0.5;
sourceGeometry.NominalRange = 10000;
sourceGeometry.Origins = G;              % 3 x Nx, sampled or full-column
sourceGeometry.CameraRays = Vcamera;     % 3 x Ny, row scan geometry
sourceGeometry.Attitudes = R;            % 3 x 3 x Nx, optional
sourceGeometry.WorldVectors = [];        % optional dense or sampled cache
sourceGeometry.SampleFcn = @sampleGeometry;
```

For the first cut, avoid dense full-resolution `V(:, y, x)` unless needed. Compute sampled world vectors on demand:

```matlab
Vworld(:, iy, ix) = R(:, :, ix) * Vcamera(:, iy);
```

The first synthetic case may use identity attitudes or a simple smooth variation.

Real geometry should be introduced by supplying a different `SampleFcn`, not by changing app or mesh-builder logic.

### Mesh Sampling Structure

Independent row and column strides are required:

```matlab
meshSampling = struct();
meshSampling.RowStride = 16;
meshSampling.ColumnStride = 8;
meshSampling.RowIndices = rowIndices;
meshSampling.ColumnIndices = columnIndices;
```

The initial defaults can be:

```matlab
RowStride = 16;
ColumnStride = 8;
```

These are only defaults. The app can expose them later.

## Proposed File Layout

The names below are suggestions. Keep code small and focused.

```text
src/
    PlanarProjection.m
    ProjectionViewerHarness.m
    ProjectionSceneBuilder.m
    ProjectionMeshBuilder.m
    ProjectionViewerApp.m

tests/
    PlanarProjectionTest.m
    ProjectionViewerHarnessTest.m
    ProjectionMeshBuilderTest.m

docs/
    viewer_development_plan.md

runProjectionViewerPrototype.m
```

### `ProjectionViewerHarness`

Purpose:

- load the local TIFF
- create the first synthetic source geometry
- create the base projection plane
- create the fixed frame camera
- return a complete single-layer scene

Likely public entry point:

```matlab
scene = ProjectionViewerHarness.createDefaultScene(imagePath, options);
```

Suggested options:

```matlab
options.GSD = 0.5;
options.NominalRange = 10000;
options.RowStride = 16;
options.ColumnStride = 8;
options.PlatformDirection = [0; 0; 1];
```

### `ProjectionSceneBuilder`

Purpose:

- create validated scene/layer/source geometry structs
- centralize defaults
- avoid app callbacks assembling ad hoc state

Likely functions:

```matlab
scene = ProjectionSceneBuilder.makeSingleLayerScene(imageData, sourceGeometry, plane, camera, options);
layer = ProjectionSceneBuilder.makeLayer(imageData, sourceGeometry, plane, options);
```

### `ProjectionMeshBuilder`

Purpose:

- build sampled ray-plane intersection mesh
- apply local render-origin shifting
- produce arrays suitable for MATLAB texture-mapped surfaces
- remain independent of graphics handles

Likely function:

```matlab
mesh = ProjectionMeshBuilder.buildLayerMesh(layer, plane, renderOrigin);
```

Suggested mesh fields:

```matlab
mesh = struct();
mesh.X = X;
mesh.Y = Y;
mesh.Z = Z;
mesh.RowIndices = rowIndices;
mesh.ColumnIndices = columnIndices;
mesh.Texture = textureData;
mesh.Alpha = alpha;
```

### Render Options Structure

Exact readback and preview generation should accept explicit options rather than relying on hardcoded choices.

Suggested first fields:

```matlab
renderOptions = struct();
renderOptions.Interpolation = "bilinear";
renderOptions.UseGPU = false;
renderOptions.InvalidIntersectionPolicy = "error";
```

Interpolation should default to `"bilinear"`. Other values can be added later, but the option should exist from the beginning so algorithm comparisons do not require API changes.

`InvalidIntersectionPolicy` controls what happens when a sampled source ray intersects the projection plane behind the source origin. In a properly defined geometric setup this is not expected. The first safe behavior should be to detect it and report it clearly rather than silently rendering misleading geometry.

### `ProjectionViewerApp`

Purpose:

- programmatic MATLAB app, not `.mlapp`
- show one projected image layer
- provide controls for tip, tilt, transparency
- provide 2D-style pan/zoom over the fixed frame-camera output

Expected construction:

```matlab
app = ProjectionViewerApp(scene);
```

UI components:

- main display area
- slider for tip
- slider for tilt
- slider for transparency
- optional labels showing current values
- optional reset button

Implementation guidance:

- use `uifigure` and `uigridlayout`
- store component handles as private properties
- keep layout construction separate from computation
- keep callbacks short
- update existing graphics objects in callbacks

### `runProjectionViewerPrototype.m`

Purpose:

- add `src` to the MATLAB path
- locate `test_data/10.tif`
- create the default scene
- launch the app

The launcher should be convenient for manual testing.

## Rendering Implementation Notes

### Texture-Mapped Surface Preview

The first preview can use a MATLAB graphics surface:

```matlab
h = surface(ax, X, Y, Z, textureData, ...
    FaceColor="texturemap", ...
    EdgeColor="none");
```

Then update only existing properties:

```matlab
h.XData = Xnew;
h.YData = Ynew;
h.ZData = Znew;
h.FaceAlpha = alpha;
```

If full-resolution texture updates are too slow, the first preview may use a downsampled texture while preserving the same mesh geometry. This should be an app/display choice, not part of the backend geometry model.

### 2D-Style Mouse Interaction

The user should feel like they are viewing a static output image in a normal 2D viewer.

Initial behavior:

- pan and zoom are allowed
- free 3D orbit is not part of the first target
- camera orientation remains tied to the fixed frame camera

Implementation trade space:

- A high-level `viewer2d` plus `imageshow` path is useful for later exact readback display.
- The projected texture preview likely needs `uiaxes` or axes-based graphics to display a texture-mapped surface.
- If a strict 2D viewer experience conflicts with 3D surface rendering, prefer a two-stage display:
  - render preview from fixed camera into an image-like view, then show it in `viewer2d`
  - keep the lower-level surface preview available for diagnostics

This choice should be revisited after the first performance experiment.

### Event Coalescing

Slider updates should avoid processing every intermediate event when the user drags quickly.

Possible first implementation:

- use `ValueChangingFcn` for lightweight preview updates
- use `ValueChangedFcn` for final settled update
- keep a timestamp or dirty flag if needed
- call `drawnow limitrate`

The app should always converge to the latest slider state.

## Plane Tip/Tilt Update

Given a base plane:

```matlab
plane0.P0
plane0.basis(:, 1)   % local X
plane0.basis(:, 2)   % local Y
plane0.VN
```

Tip and tilt should rotate the projection plane around its local axes. Keep `P0` fixed in the first implementation.

Conceptual update:

```matlab
Rtip = rotationAboutAxis(plane0.basis(:, 1), tipRadians);
Rtilt = rotationAboutAxis(plane0.basis(:, 2), tiltRadians);
R = Rtilt * Rtip;

VX = R * plane0.basis(:, 1);
VY = R * plane0.basis(:, 2);
plane = PlanarProjection.definePlaneFromBasis(plane0.P0, VX, VY);
```

Implementation note: if the order of rotations becomes visually important, make it explicit in docs and tests. Start with `R = Rtilt * Rtip`.

## Future Sensor Geometry Manipulation

The first app should manipulate only the projection plane. Sensor geometry and frame camera remain fixed.

The architecture should still allow future controls that modify source geometry, such as:

- platform origin offsets
- attitude perturbations
- scan-angle bias
- range or altitude perturbations
- synthetic geometry parameters

These future controls should update the same source geometry provider contract:

```matlab
[G, V] = sourceGeometry.SampleFcn(rowIndices, columnIndices);
```

They should not require the mesh builder or renderer to know whether geometry came from a synthetic model, a real camera model, or an interactive perturbation layer.

## Synthetic Geometry Details

The first synthetic geometry does not need to be physically exact. It should be clear, stable, and representative enough to exercise the pipeline.

Inputs:

- image height `H`
- image width `W`
- GSD `0.5 m`
- nominal range `10000 m`
- center pixel approximately `[H/2, W/2]`

Approximate focal-plane dimensions:

```matlab
widthMeters = W * GSD;
heightMeters = H * GSD;
```

Build camera-frame detector rays from focal-plane offsets:

```matlab
xMeters = (x - centerX) * GSD;
yMeters = (y - centerY) * GSD;
Vcamera = normalize([xMeters; yMeters; nominalRange]);
```

Then introduce collection geometry:

- column index controls platform origin.
- row index controls camera ray.
- first implementation may hold attitude constant.

For sampled rows and columns:

```matlab
Gsample(:, ix) = G0 + platformStepMeters * (xSample(ix) - centerX) * platformDirection;
Vsample(:, iy, ix) = R(:, :, ix) * Vcamera(:, iy);
```

The exact initial `platformStepMeters` can be derived from GSD or set to a simple value that keeps the projected mesh well-conditioned. Because the source image is rectified north-up and the first goal is framework performance, do not overfit these parameters.

## Testing Plan

### Unit Tests

Add tests for pure functions first.

Suggested tests:

- default harness creates a scene with one layer
- scene has valid frame camera and projection plane
- source geometry exposes the `SampleFcn(rowIndices, columnIndices)` contract
- synthetic and stub real-geometry providers can be consumed through the same interface
- row and column strides produce expected index vectors
- sampled origins have one origin per sampled column
- sampled vectors have one vector per sampled row/column
- single-band and RGB images can both be prepared for display
- mesh builder returns `X`, `Y`, and `Z` arrays with size `[numRows numColumns]`
- mesh vertices are finite
- alpha is clamped or validated in `[0, 1]`
- tip/tilt update preserves a valid plane
- local render-origin shifting is applied consistently

### App Smoke Tests

The app can initially be verified manually. Later, add a smoke test that launches and closes the app if reliable in the local MATLAB environment.

Manual checks:

- app launches from `runProjectionViewerPrototype`
- image appears
- pan/zoom feels responsive
- tip slider changes projected geometry
- tilt slider changes projected geometry
- transparency slider changes alpha
- reset returns to the initial plane

### Existing Tests

Continue running:

```matlab
results = runTests;
```

or:

```matlab
buildtool test
```

## Performance Plan

### First Performance Target

For the current TIFF, the app should feel responsive with preview geometry around:

```matlab
RowStride = 16;
ColumnStride = 8;
```

For a `3228 x 3320` image, this yields roughly:

- `203` sampled rows
- `415` sampled columns
- about `84k` mesh vertices

If that is too slow, increase the strides or use a coarser drag-preview mesh.

### Progressive Quality

Use two quality levels:

- drag preview: coarse mesh and optional downsampled texture
- settled preview: denser mesh and full or higher-resolution texture

The first implementation can start with only one quality level. The code should not prevent adding progressive quality later.

### Large-Image Future

Real imagery is expected to be commonly around `15000 x 10000`, with possible growth to roughly `30000 x 20000`. These are large but still within the range of modern workstation memory and graphics hardware when handled carefully.

For larger remote-sensing imagery, consider:

- `blockedImage`
- image pyramids
- tile selection based on zoom
- lower-resolution textures during interaction
- full-resolution exact readback outside the UI loop

The first implementation does not need full out-of-core tiling, but it should avoid architectural choices that require dense full-resolution 3D vectors or multiple full-size temporary images.

### Optional GPU Path

GPU acceleration should be planned as an optional optimization for Windows or other MATLAB GPU-supported systems.

Guidelines:

- CPU implementation must remain complete and tested.
- GPU execution should be opt-in or automatically enabled only after capability checks.
- Use `gpuArray` only inside pure numeric compute functions.
- Gather arrays before assigning to MATLAB graphics objects.
- Keep CPU and GPU results numerically comparable in tests where practical.
- Do not introduce APIs that require callers to know whether data is currently CPU or GPU unless a future performance review proves that necessary.

## Milestone Implementation Plan

### Milestone 1: Documented Data Model And Harness

Deliverables:

- `ProjectionViewerHarness`
- scene/layer/source geometry structs
- tests for default scene creation

Acceptance criteria:

- default scene loads `test_data/10.tif`
- scene contains one layer
- image metadata and synthetic geometry are internally consistent
- tests pass

### Milestone 2: Pure Mesh Builder

Deliverables:

- `ProjectionMeshBuilder`
- sampled ray-plane intersections
- local render-origin shifting
- tests for mesh shape and finite vertices

Acceptance criteria:

- mesh builds without graphics
- mesh dimensions match sampled rows/columns
- changing tip/tilt changes mesh vertices
- tests pass

### Milestone 3: First Interactive App

Deliverables:

- `ProjectionViewerApp`
- `runProjectionViewerPrototype.m`
- tip, tilt, and alpha sliders
- fixed frame-camera-style view

Acceptance criteria:

- app launches
- projected image is visible
- sliders update without object recreation
- mouse pan/zoom is usable and 2D-like
- no obvious queued-event lag on the provided TIFF

### Milestone 4: Responsiveness Refinement

Deliverables:

- event coalescing or `drawnow limitrate`
- optional separate drag and settled quality
- optional texture downsampling for preview

Acceptance criteria:

- rapid slider movement stays responsive
- final display converges to the last slider state
- UI remains explainable and deterministic from scene state

### Milestone 5: Exact Backend Readback Prototype

Deliverables:

- pure renderer entry point
- frame-camera readback using scene/layer state
- configurable interpolation with initial default `"bilinear"`
- initial output image generation without MATLAB graphics

Acceptance criteria:

- renderer runs headless
- output image is deterministic
- bilinear interpolation is the default and can be changed through an option
- app state can be passed to renderer
- preview and exact output can be compared qualitatively

### Milestone 6: Multi-Layer Extension

Deliverables:

- multiple `scene.layers`
- layer visibility and alpha controls
- per-layer blend settings
- initial red/blue anaglyph blend mode for stereo viewing
- image cycling control for change workflows
- support for stereo/change exploration

Acceptance criteria:

- two layers can render in one frame-camera view
- each layer has independent geometry and alpha
- stereo layers can be rendered as a red/blue anaglyph without preserving full true color
- change workflows can toggle or cycle one image to `100%` alpha while other layers are `0%`
- the first single-layer workflow remains simple

## Agent Implementation Notes

When coding from this plan:

1. Keep the first code changes small and testable.
2. Prefer pure functions for geometry and state construction.
3. Keep MATLAB graphics handles out of scene/layer structs.
4. Use `uifigure` and `uigridlayout` for app construction.
5. Do not use App Designer `.mlapp` files.
6. Avoid `imshow` for app image display. Use `imageshow`/`viewer2d` where displaying final image-like output is appropriate.
7. For texture-mapped geometry, use existing surface/axes objects and update their data properties.
8. Do not commit prototype TIFF data.
9. Preserve compatibility with the existing `PlanarProjection` API.
10. Add tests for core computation before tuning the UI.
11. Keep CPU as the required execution path; add `gpuArray` only behind optional capability checks.
12. Keep real sensor geometry integration focused on the `SampleFcn(rowIndices, columnIndices)` contract.
13. Support single-band and RGB images in display preparation and tests.

## Resolved Design Decisions

These decisions should guide the first implementation:

1. Exact frame-camera readback should start with bilinear interpolation.
2. Interpolation should be configurable through an option.
3. Ray-plane intersections behind the source origin are not expected in a properly defined geometric setup.
4. The first implementation should detect invalid behind-origin intersections and report them clearly rather than silently rendering misleading output.
5. Future app versions should allow source sensor geometry manipulation in addition to projection-plane manipulation.
6. Each layer should have its own alpha value.
7. Stereo viewing should eventually support red/blue anaglyph rendering, without requiring full true color preservation.
8. Multi-image change workflows should eventually support cycling one layer to `100%` alpha while setting other layers to `0%`.

## Open Questions

These do not block the first implementation, but should be revisited:

1. Should `PlanarProjection.definePlane` be wrapped for clearer image-axis semantics?
2. Should the preview path render directly as a texture-mapped surface, or should it produce an intermediate image shown with `viewer2d`?
3. Which invalid-intersection policy options are ultimately needed beyond the first `"error"` behavior?
4. What exact UI should be used for future source geometry manipulation?
5. What blend modes beyond alpha, red/blue anaglyph, and layer cycling are useful for stereo or image-to-image change workflows?

## Known Geometry Caveat

Previous review identified a ray-versus-line ambiguity in the current geometry helpers:

- `PlanarProjection.intersectPlane` currently allows signed line-plane intersections.
- `PlanarProjection.triangulateRays` currently solves closest points for infinite lines.

The first viewer prototype can proceed with this behavior if synthetic geometry keeps intersections in front of the source origins. Before exact backend readback becomes authoritative, decide whether these APIs should enforce forward-ray semantics or be documented as signed-line operations.
