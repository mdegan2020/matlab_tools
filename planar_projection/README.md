# PlanarProjection

`PlanarProjection` is a small MATLAB geometry library for 2D/3D projection work, with an emphasis on plane-based stereo vision, positive-focal-plane camera projections, and future high-performance imagery workflows.

The library is implemented as a single static-method class:

```matlab
plane = PlanarProjection.definePlane(G0, V0, V1, R0);
[P, Q] = PlanarProjection.intersectPlane(Vn, G0, plane);
```

## Project Layout

```text
src/PlanarProjection.m          Static class library
src/ProjectionViewerHarness.m   Synthetic scene and source-geometry harness
src/ProjectionSourceGeometry.m  Sparse source-geometry grid adapter
src/ProjectionLayerManager.m    Multi-layer visibility and change-workflow helpers
src/ProjectionMeshBuilder.m     Pure sampled projection mesh builder
src/ProjectionPreviewPyramid.m  Display-only viewer preview pyramid/tile helper
src/ProjectionReadbackRenderer.m Headless frame-camera readback prototype
src/ProjectionViewerApp.m       Programmatic interactive preview app
src/ProjectionViewerState.m     JSON-serializable viewer state and scene-apply helpers
src/ProjectionAlignment*.m      Feature-based alignment models, matching, solving, and runner
src/ProjectionBackendJob.m      Backend job contract and serialization helpers
src/ProjectionBackendGpuSupport.m Backend optional gpuArray capability checks
src/ProjectionBackendCustomGpuKernelPlan.m Backend custom GPU kernel assessment
src/ProjectionBackendOutputGrid.m Backend full-extent output grid planner
src/ProjectionBackendOutputWriter.m Backend image/mask/metadata writers
src/ProjectionBackendTiledRenderer.m Backend serial tiled CPU renderer
src/ProjectionBackendProcessor.m Backend job invocation facade
tests/PlanarProjectionTest.m    Class-based unit tests
tests/ProjectionAlignment*.m    Alignment model, matching, solver, GUI, and backend tests
runProjectionViewer.m           Programmatic launcher for real image/geometry data
runProjectionViewerPrototype.m  Launcher for the local prototype TIFF
runSyntheticAlignmentPrototype.m Launcher for red/blue synthetic alignment scenes
validateProjectionBackendJob.m  Validate backend jobs without rendering
scripts/backend_interactive_evaluation.m Sectioned backend evaluation script
docs/alignment_workflow_hardening_plan.md Real-data GUI alignment hardening plan
artifacts/backend_evaluation/ Ignored backend evaluation output directory
runTests.m                      Simple test runner
buildfile.m                     MATLAB buildtool tasks
```

## Naming And Shape Conventions

The API intentionally uses tight math-oriented names.

| Name | Meaning | Shape |
| --- | --- | --- |
| `P` | Point in the world/system frame | `3x1` |
| `Pn` | Collection of world/system points | `3xN` |
| `G` | View origin or optical center | `3x1` |
| `G0` | Special view origin or optical center | `3x1` |
| `V` | Vector in the world/system frame | `3x1` |
| `Vn` | Collection of vectors | `3xN` |
| `Q` | Plane-local 2D coordinates | `2xN` |
| `R` | Range or distance along a normalized direction | scalar or `1xN` |

All vectors and points are column-oriented. Collections are also column-oriented, so each point or vector occupies one column.

## Plane Convention

A plane is represented as a struct:

```matlab
plane.P0       % 3x1 plane origin
plane.basis    % 3x2 basis matrix [VX VY]
plane.VN       % 3x1 plane normal
```

The basis is right-handed:

```matlab
cross(plane.basis(:,1), plane.basis(:,2)) == plane.VN
```

Coordinate systems are right-handed. In the usual viewing convention, `+Z` points from the view position toward the plane, `+X` points right on the plane when viewed from the origin, and `+Y` completes the right-handed system.

## Camera Convention

Frame cameras are simple structs with a positive focal plane:

```matlab
camera.G0           % 3x1 optical center
camera.V0           % 3x1 unit optical axis, positive forward
camera.F            % positive scalar focal length
camera.focalPlane   % plane struct at G0 + F*V0
```

The focal plane `+X` direction is chosen by projecting a reference plane's `+X` onto the focal plane. This keeps camera readback aligned with the plane-based projection constructs.

## Current Public API

Plane construction:

```matlab
plane = PlanarProjection.definePlane(G0, V0, V1, R0);
plane = PlanarProjection.defineStereoPlane(G1, V1, R1, G2, V2, R2);
plane = PlanarProjection.defineFitPlane(G0, V0, P1, P2, P3, P4);
plane = PlanarProjection.definePlaneFromBasis(P0, VX, VY);
plane = PlanarProjection.definePlaneFromNormal(P0, VN, VXref);
```

Plane operations:

```matlab
[P, Q] = PlanarProjection.intersectPlane(Vn, G, plane);
P = PlanarProjection.reconstruct3d(Q, plane);
Q = PlanarProjection.worldToPlane(P, plane);
Q2 = PlanarProjection.mapPlaneToPlane(Q1, plane1, plane2);
```

Camera operations:

```matlab
camera = PlanarProjection.defineFrameCamera(G0, V0, F, referencePlane);
[Q, Pp] = PlanarProjection.projectToCamera(P, camera);
[Vn, Pp] = PlanarProjection.projectFromCamera(Q, camera);
[Qcamera, Pp] = PlanarProjection.projectPlaneToCamera(Qplane, plane, camera);
[Qplane, P] = PlanarProjection.projectCameraToPlane(Qcamera, camera, plane);
```

General geometry helpers:

```matlab
Vn = PlanarProjection.pointsToViewVectors(P, G);
VnUnit = PlanarProjection.normalizeVectors(Vn);
[P, residual, Pnear1, Pnear2] = PlanarProjection.triangulateRays(G1, V1, G2, V2);
tf = PlanarProjection.validatePlane(plane);
tf = PlanarProjection.validateCamera(camera);
```

## Error Policy

The first MATLAB implementation throws errors for invalid geometry instead of returning `NaN` or `Inf`. This includes zero-length vectors, malformed array sizes, degenerate plane definitions, rays parallel to planes, and camera points behind the optical center.

This is intentional for early development. A future CUDA-oriented path may choose `NaN`/`Inf` signaling for throughput-friendly kernels.

## Running Tests

From MATLAB:

```matlab
results = runTests;
```

With MATLAB buildtool:

```matlab
buildtool test
buildtool coverage
```

The tests use MATLAB's class-based `matlab.unittest` framework and exercise the public API with deterministic numeric examples.

## Projection Viewer Prototype

The interactive prototype is programmatic MATLAB app code, not an `.mlapp` file. From MATLAB:

```matlab
app = runProjectionViewerPrototype;
```

The default launcher expects the local ignored prototype image at `test_data/10.tif`.
To launch the prototype with two local dummy textures:

```matlab
app = runProjectionViewerPrototype(["test_data/10.tif", "test_data/102.tif"]);
```

The viewer supports one or more image layers. Each layer has independent source
geometry, alpha, visibility, blend mode, projection-plane offset, and omega/phi/
kappa view-vector correction state. Multi-layer previews share one projection
plane, with a small display-only depth bias so layers do not fight in the
renderer. The default selected layer is the topmost layer.

Large layers can use display-only preview pyramids and tiled preview surfaces so
the app stays responsive while panning, zooming, and adjusting projection state.
These pyramids do not change the layer `Image` data used by readback or backend
jobs; backend processing keeps the full source image and renders through the
configured output grid.

Core controls:

- Mouse wheel zooms the view.
- Shift + wheel adjusts Tip, Alt/Option + wheel adjusts Tilt, and Control +
  wheel adjusts Twist camera roll.
- Up/Down arrows adjust Tip by `0.5` degrees; Left/Right arrows adjust Tilt by
  `0.5` degrees.
- Plain left-drag pans the camera.
- Control + left-drag translates the selected layer on the projection plane,
  using the same selected-layer projection offset as W/A/S/D.
- Alt/Option + left-drag adjusts omega and phi for the selected layer so the
  projected image tracks the mouse drag.
- W/A/S/D translates the selected layer up/left/down/right on the projection
  plane.
- I/K adjust phi, J/L adjust omega, and U/O adjust kappa. Omega and phi default
  to one estimated IFOV per key press; kappa defaults to 0.1 degrees.
- Save and Load write/read a human-readable JSON viewer state containing camera,
  layer, alpha, blend, projection offset, OPK, tip, tilt, and twist settings.
- The alignment panel is hidden by default and can be shown from the image
  context menu. It can run auto-alignment for the selected pair or all visible
  layers. Choose a fast or quality preset, detector, loss mode, optional ROI,
  and enabled pair-table rows, then use Match, Solve, Preview, Apply, Revert,
  and Clear. Match reports stage progress, applies geometric and native-pixel
  displacement filtering, updates raw/filtered match counts, and draws match
  overlays; Solve reuses the stored filtered matches and reports residual/OPK
  summaries in the status text, including warnings when corrections hit OPK
  bounds. GUI solves are marked failed, with Preview/Apply/Revert disabled, if
  they are match-limited, bound-limited, or residual-limited by the safe default
  policy. Solver diagnostics also include max residuals, worst residual match
  references, per-pair residual summaries, and table-ready match records for
  follow-up review workflows. The match table can sort residuals, highlight a
  selected correspondence, and disable individual observations before solving
  again without re-matching. Visible match overlays redraw from source
  observations after finalized projection, layer-offset, preview, apply, and
  revert updates. Alignment-panel overlay toggles show accepted lines and
  feature points by default, with optional faint rejected matches and post-solve
  worst-residual highlights.
  Overlay clicks select the nearest match-table row; Delete marks selected
  rows as session-local deleted observations, and Undo restores curation from
  a stack.

Manual auto-alignment validation loop:

```matlab
app = runSyntheticAlignmentPrototype("test_data/10.tif");
```

In the viewer, start with the fast preset and `projectionPlane2D`, inspect the
pair table, match overlays, and RMS summary, then switch to the quality preset
or `rayToRay3D` when the fast solve looks plausible. Use the ROI button when
background features dominate the overlap, uncheck weak pair rows before rerun,
preview the solved OPK corrections, apply or revert them, and save the viewer
state from the context menu. Common failure modes are too few filtered or
solver-used matches, disabled or hidden layers leaving no enabled pairs, a solve
that hits OPK bounds, weak residual improvement, an ROI that clips all features,
or a detector that is unavailable in the current MATLAB installation.
Real-data alignment quality follow-up work, including staged match/solve
controls, outlier filtering, OPK bounds, overlay clearing, and future manual
match curation, is tracked in `docs/alignment_workflow_hardening_plan.md`.

Projection scenes can choose how the initial projection plane is built:

```matlab
options = struct(ProjectionPlaneMode="fit");      % "current", "fit", or "stereo"
scene = ProjectionViewerHarness.createDefaultScene("test_data/10.tif", options);
app = ProjectionViewerApp(scene);
```

You can also pass an explicit plane, either while creating the scene or when
constructing the app from an existing scene:

```matlab
plane = PlanarProjection.defineFitPlane(G0, V0, P1, P2, P3, P4);
scene = ProjectionViewerHarness.createDefaultScene("test_data/10.tif", ...
    struct(ProjectionPlane=plane));
app = ProjectionViewerApp(scene, plane);
```

Sensor-specific geometry can be supplied through the `SampleFcn(rowIndices,
columnIndices)` contract. For sparse camera-model posts, use
`ProjectionSourceGeometry.fromGrid` to adapt uniformly spaced row/column geometry
posts into the same sampled-origin and sampled-view-vector interface used by the
mesh builder.

For programmatic real-data launch, pass layer names, in-memory `uint8` images,
one sparse geometry definition per image, and the projection plane:

```matlab
options = ProjectionViewerHarness.realDataOptions();
geometryDefinitions{1} = struct( ...
    RowPostIndices=rowPostIndices, ...
    ColumnPostIndices=columnPostIndices, ...
    ViewVectorOrigins=viewVectorOrigins, ...  % 3 x numColumnPosts
    ViewVectors=viewVectors, ...              % 3 x numRowPosts x numColumnPosts
    NominalSceneCenter=nominalSceneCenter);

app = runProjectionViewer(layerNames, imageDataList, ...
    geometryDefinitions, projectionPlane, options);
```

The viewer frame camera is placed at the arithmetic mean of the per-layer
`NominalSceneCenter` vectors and looks toward the supplied projection plane.
The initial view frames the projected surface conservatively in the viewport,
and stabilized axes limits keep large tip/tilt adjustments from changing the
apparent scale on the first edit.

## Backend Processor Workflow

The backend processor milestones are implemented and committed. The backend can
run live in-memory jobs or serialized JSON/MAT jobs, apply viewer state
headlessly, plan full-extent output grids, render composite and per-layer
outputs, write PNG/TIFF products with metadata, process tiles serially or with
`parpool("threads")`, run optional alignment before rendering, and accept
optional GPU requests with CPU fallback.

From an interactive app session:

```matlab
app = runProjectionViewerPrototype("test_data/10.tif");
job = app.exportBackendJob(struct( ...
    RenderOptions=struct(OutputSize=[512 512], TileSize=[128 128]), ...
    Execution=struct(Mode="serial"), ...
    Output=struct(Directory="backend_output", WriteFiles=true)));
ProjectionBackendJob.write("backend_job.json", job);
validation = validateProjectionBackendJob("backend_job.json");
result = ProjectionBackendProcessor.run("backend_job.json");
```

Alignment can also run headlessly before rendering. The alignment request selects
analysis layers and bands; solved pointing corrections are applied to the scene
and therefore to all bands during backend rendering:

```matlab
job.Alignment = struct( ...
    Enabled=true, ...
    Request=struct( ...
        LayerIndices=[1 2], ...
        ReferenceLayerIndex=1, ...
        AnalysisBands=[1 1]), ...
    RenderOptions=struct(OutputSize=[512 512]));
```

When `Output.WriteFiles` is true, alignment-enabled jobs can write
`aligned_viewer_state.json` and `alignment_diagnostics.json` beside the rendered
products.

Threaded backend execution is opt-in and uses only MATLAB's thread pool:

```matlab
job.Execution = struct(Mode="threads");
```

GPU requests are optional. If compatible `gpuArray` support is unavailable, the
backend records the fallback reason in `GpuInfo` and continues on CPU.

See `docs/backend_app_workflow.md` for the complete app-to-backend workflow,
`docs/alignment_workflow_hardening_plan.md` for the current GUI alignment
hardening plan, and
`docs/backend_milestone_9_custom_gpu_kernel_assessment.md` for the current
custom GPU kernel decision record.

For interactive timing and output-size experiments, run
`scripts/backend_interactive_evaluation.m` section-by-section. It writes jobs,
rendered products, logs, and summary tables under `artifacts/backend_evaluation/`.
