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
src/ProjectionPreviewTileGeometry.m Runtime-only cached tile footprint helper
src/ProjectionReadbackRenderer.m Headless frame-camera readback prototype
src/ProjectionViewerApp.m       Programmatic interactive preview app
src/ProjectionViewerLruCache.m  Byte-bounded runtime prepared-tile cache
src/ProjectionViewerPerformanceMonitor.m Bounded runtime viewer work metrics
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
scripts/viewer_performance_evaluation.m Repeatable viewer interaction benchmark
docs/alignment_workflow_hardening_plan.md Real-data GUI alignment hardening plan
docs/performance_optimization_workplan.md Viewer/backend optimization packs
artifacts/backend_evaluation/ Ignored backend evaluation output directory
artifacts/viewer_performance/ Ignored viewer benchmark output directory
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

## Viewer Performance Evaluation

The viewer exposes bounded, runtime-only work diagnostics without adding
graphics handles or caches to serializable scene/layer/source state:

```matlab
diagnostics = app.performanceDiagnostics();
app.resetPerformanceDiagnostics();
```

To inspect the live graphics surfaces, including retained hidden pool entries,
use the exact singular tags below. `findall` is intentional because pooled
surfaces are hidden:

```matlab
fig = findall(groot, Type="figure", Name="Projection Viewer Prototype");
assert(~isempty(fig), "Projection Viewer figure not found.");
ax = findall(fig(1), Type="axes");
assert(~isempty(ax), "Projection Viewer axes not found.");

surfaces = findall(ax(1), Type="surface");
wantedTags = ["ProjectionViewerPreviewTileSurface", ...
    "ProjectionViewerLayerSurface", ...
    "ProjectionViewerPooledTileSurface"];
surfaceTags = arrayfun(@(h) string(h.Tag), surfaces);
surfaces = surfaces(ismember(surfaceTags, wantedTags));

surfaceCount = numel(surfaces);
Tag = strings(surfaceCount, 1);
Visible = strings(surfaceCount, 1);
CDataClass = strings(surfaceCount, 1);
CDataRows = zeros(surfaceCount, 1);
CDataColumns = zeros(surfaceCount, 1);
CDataBands = zeros(surfaceCount, 1);
CDataMiB = zeros(surfaceCount, 1);
MeshRows = zeros(surfaceCount, 1);
MeshColumns = zeros(surfaceCount, 1);
for k = 1:surfaceCount
    cdata = surfaces(k).CData;
    cdataInfo = whos("cdata");
    Tag(k) = string(surfaces(k).Tag);
    Visible(k) = string(surfaces(k).Visible);
    CDataClass(k) = string(class(cdata));
    CDataRows(k) = size(cdata, 1);
    CDataColumns(k) = size(cdata, 2);
    CDataBands(k) = size(cdata, 3);
    CDataMiB(k) = cdataInfo.bytes / 2^20;
    MeshRows(k) = size(surfaces(k).XData, 1);
    MeshColumns(k) = size(surfaces(k).XData, 2);
end
graphicsTree = table(Tag, Visible, CDataClass, CDataRows, CDataColumns, ...
    CDataBands, CDataMiB, MeshRows, MeshColumns);
disp(graphicsTree)
for tag = wantedTags
    isTag = graphicsTree.Tag == tag;
    fprintf("%s: %d total, %d visible, %.2f MiB CData\n", tag, ...
        nnz(isTag), nnz(isTag & graphicsTree.Visible == "on"), ...
        sum(graphicsTree.CDataMiB(isTag)));
end
```

Run the repeatable alpha, crosshair, twist, pan, LOD-boundary zoom, WASD, and
OPK scenarios with:

```matlab
summary = viewer_performance_evaluation;
```

The evaluation uses local prototype TIFFs when available and otherwise creates
a deterministic single-channel fixture. Pass `UseSynthetic=true` to force the
synthetic path. Slow, fast, and reversing LOD-boundary scenarios default to the
`15.0`/`14.5` degree audit boundary and can be configured with
`LodBoundaryAngles`. `DisplayTileSize`, `SyntheticLayerCount`, and
`SyntheticPattern="constant"` support representative large single-channel
tile-size experiments without large synthetic-pattern work arrays.
Machine-specific MAT/JSON/CSV output is written beneath
the ignored `artifacts/viewer_performance` directory. Timing values are reports,
not pass/fail thresholds; automated tests assert structural work counts.

Crosshair pointer tracking is demand-activated. When enabled, steady movement
updates stable line handles without restacking projection graphics; when
disabled and no drag is active, the figure motion callback is removed.

Camera-only twist, pan, and zoom use a latest-state settle scheduler. Camera
properties update immediately, while tiled visibility and LOD reconciliation
wait for a `120 ms` quiet period or an explicit final flush. The display-only
LOD policy uses asymmetric promotion/demotion hysteresis and a viewport halo;
it does not change backend inputs or serialized viewer state. The performance
evaluation reports active and settled diagnostics separately.

Tile visibility uses cached tile footprints built from one shared
tile-boundary mesh per pyramid level. The cached numeric coordinates are
render-origin-relative, matching the graphics surfaces and camera even when
the source geometry uses large real-world/ECEF-like coordinates. Camera
reconciliation projects all candidate footprints in one vectorized operation
and skips hidden layers.
Cache keys cover the plane, OPK, projection offset, source identity/image size,
render origin, and tile layout. `configurePreviewTiling` changes runtime display
tile options and rebuilds only viewer data; exported backend imagery and viewer
state remain unchanged.

Visible tile sets update differentially: overlapping stable tile keys retain
their graphics handles, entering tiles use a bounded prepared texture/mesh LRU,
and departing handles move to a bounded hidden pool for reuse. The defaults are
a `256 MiB` prepared-data cache and `64` pooled surfaces. Both are runtime-only
and configurable for evaluation:

```matlab
app.configurePreviewCache(struct( ...
    MaxBytes=256 * 1024^2, SampleMaxBytes=64 * 1024^2, ...
    SurfacePoolMaxCount=64));
```

The local 100 MP single-channel comparison did not justify moving away from the
provisional `1024` display tile side: `512` kept comparable warm interaction
time but required four times as many candidates/surfaces in the measured zoomed
view. Confirm `512` versus `1024` on the intended Windows/1080p/4K workload
before changing the default.

Viewer mesh construction separates immutable source sampling from derived
projection geometry. The app caches exact row/column source origin/ray samples
in the runtime-only sampled-geometry LRU, then reuses them across plane, OPK,
and projection-offset changes. Shared tip/tilt refreshes all layers; selected
OPK edits and alignment operations refresh only affected layers.

WASD and Control-drag preserve the existing explainable state contract while
avoiding mesh reconstruction: they update `ProjectionOffsetMeters` and apply
the corresponding exact in-plane world translation to current surfaces.
Source geometry, sampled ray origins, and sampled view vectors do not change.
Tiled coverage is reconciled after interaction using cached samples. The
performance diagnostics and CSV artifacts report sample-cache hits/misses,
`SampleFcn` calls, affected-layer refreshes, and rigid translations.

Alpha interaction is latest-value coalesced at a configurable render interval
(`50 ms` by default), while slider release and `flushPreviewUpdates` render the
exact final value. Alpha zero hides the graphics surfaces without changing the
layer's serializable visibility flag; a positive alpha restores them. Alpha
updates do not rebuild geometry or select tiles.

Tiled reconciliation observes global display-only budgets (48 visible surfaces
and `256 MiB` of graphics texture by default). A budget-limited view selects a
coarser complete LOD rather than truncating coverage. An optional automatic
policy can additionally target at most 12 tiles per visible layer; it is off by
default pending workload-specific visual validation:

```matlab
app.configurePreviewBudget(struct( ...
    MaxVisibleSurfaces=48, ...
    MaxVisibleTextureBytes=256 * 1024^2, ...
    TargetMaxTilesPerLayer=12, ...
    AutomaticTilePolicy=true, ...
    AlphaPreviewMinIntervalSeconds=0.05));
```

Run `viewer_surface_consolidation_evaluation` to compare equal-texel tiled and
single-atlas transparency cost. Local 512- and 1024-side results showed no
compelling atlas advantage, so the production viewer retains differential tile
surfaces and defers raster/atlas architecture to the later prototype decision.

The hidden alignment panel is built lazily. Initial launch creates neither the
heavy alignment grid nor its pair/match tables; opening the context-menu panel
creates them once and later show/hide operations reuse them.

Preview pyramid metadata is eager, but level images are lazy and antialiased.
Coarse levels are independently box-filtered from the full source with
`imresize`, avoiding cumulative blur and direct-stride aliasing. Compatible
file-backed layers read level-1 tiles by `PixelRegion`; display tile geometry is
independent of file storage blocks. Diagnostics report source mode, total and
materialized level counts, and additional materialized bytes.

Single-band tiled layers use normalized scalar `single` `CData` with the axes
grayscale colormap, avoiding the previous three-channel `repmat` allocation.
RGB remains truecolor, and arbitrary-band imagery uses an explicit mean-band
grayscale/RGB fallback. The prepared-tile LRU caches whichever representation
was selected. Backend export remains unchanged and contains the full source
imagery rather than preview data or file-read tiles.

An optional CPU raster-preview diagnostic is available through
`app.compileRasterPreview(options)` and `app.renderRasterPreview(options)`.
It uses a pure orthographic viewport grid, compiles one viewport-sized raster
per layer, and numerically composites those layers into one opaque RGB image.
It does not replace the production surface renderer and is never a backend
input. Local Pack 8 measurements found fast visibility and crosshair behavior
but much slower camera/twist recompilation, so differential tiled surfaces
remain the default. See
`docs/viewer_performance_pack_8_raster_preview_decision.md` and reproduce the
comparison with `viewer_raster_preview_evaluation`.

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
  a stack. Overlay endpoints are reprojected independently through current
  sampled source rays, OPK, and projection offsets; an invalid endpoint cannot
  move a whole pair back to stale working-image coordinates. Correspondence
  lines require two valid endpoints, while valid endpoints of rejected/invalid
  records can still appear as faint diagnostic markers. Pure layer reordering
  preserves overlay world positions and alignment pair identity.

The ROI button creates a central projection-plane starting region and arms
left-drag redraw in the viewport. ROI filtering uses the actual projection-plane
match coordinates, retains rejected records and their `roi` reason in the full
ledger, and re-filters the stored pre-ROI result on redraw or clear without
rerunning feature detection or descriptor matching.

Alignment records use stable serializable layer IDs in addition to current
display indices, so identity survives state save/load and layer-order changes.
The filtering pipeline preserves a complete raw-match ledger with cumulative
stage masks and rejection reasons rather than retaining only survivors. Solver
results expose `SolverObservations` as the precise canonical term; `Inliers`
remains a compatibility alias. Projection-plane residuals are reported in
`planeMeters`, ray residuals in `rayMeters`, and native displacement in pixels.
These alignment records and working products remain analysis-only and never
replace full-source backend radiometry.

Alignment working images use stable, isotropic, projection-plane grids planned
from each scheduled pair's footprint overlap. `OutputSize` is a maximum working
size rather than a demand to stretch every pair into a square; physical
resolution is coarsened on a power-of-two schedule and bounds are quantized so
tiny geometry changes normally keep the same grid. Multi-image matching detects
features on each pair's own grid. Repeating Match with unchanged radiometry and
mapping reuses the app's runtime-only working-image cache; display alpha does
not invalidate it. Working images retain compact mesh summaries, not display
textures or full sampled-mesh payloads.

The incumbent sparse alignment radiometry can be compared with alignment-only
full-source inverse warp without changing backend behavior:

```matlab
addpath("scripts");
[comparison, artifacts] = alignment_working_image_evaluation( ...
    scene, request, struct(OutputDirectory="artifacts/my_alignment_review"));
```

The comparison writes JSON/MAT metrics, normalized layer PNGs, and match-overlay
PNGs. Alignment working images now default to `fullSourceInverseWarp`; the
historical sparse mode remains an explicit comparison oracle. This is an
alignment-only choice and does not couple working images to backend products.

The deterministic oblique-terrain decision fixture uses the red and blue bands
of the local RGB test TIFF as separate rectified textures, drapes them over a
smooth `+/-50 m` DEM, and renders two CPU pushbroom views at `10 km` range,
`65 degrees` off nadir, and `3 degrees` azimuth separation:

```matlab
addpath("scripts");
[scene, truth, comparison, artifacts] = ...
    alignment_oblique_terrain_evaluation();
```

The default `1024 x 1024` run writes sensor views, working images, match
overlays, and truth-aware JSON/MAT diagnostics under the ignored
`artifacts/alignment_oblique_terrain_comparison` directory. On the selected
test TIFF, full-source inverse warp produced `104` raw and `12` filtered
matches; all filtered observations were within `10 m` of known terrain truth
(`3.03 m` median, `3.94 m` p95). Sparse radiometry produced `29` raw matches,
no filter survivors, and a `1.98 km` raw median truth separation. The DEM and
all simulation truth remain fixture-only and never enter backend radiometry.

Feature extraction is deterministic and valid-mask aware. Detector inputs use
finite valid-mask min/max normalization; optional analysis scaling is
mask-weighted and antialiased; features whose configured detector support
crosses an invalid region or image border are rejected before descriptors are
formed. Metric threshold, analysis scale, maximum feature count, matcher ratio,
match threshold, and uniqueness options are all applied explicitly. The
matcher default is exhaustive; the nondeterministic approximate choice is not
part of the public options schema.

The app exposes the actual detector, matcher, preprocessing counts, timing, and
every filter stage without requiring access to private GUI state:

```matlab
diagnostics = app.alignmentDiagnostics();
diagnostics.Stage.FeatureDiagnostics
diagnostics.Stage.FilterDiagnostics
```

To audit exact repeats and a small OPK perturbation for every installed
detector on the oblique-terrain fixture:

```matlab
addpath("scripts");
[summary, artifacts] = alignment_feature_repeatability_evaluation();
```

The JSON/MAT report is written under the ignored
`artifacts/alignment_feature_repeatability` directory.

Geometric filtering now uses the model named by the option in
moving-to-reference working-pixel coordinates. `similarity` fits rotation,
uniform scale, and translation; `affine` is an advanced shear/nonuniform-scale
model. The former translation-only projection-metre gate and undefined generic
`ransac` label are gone. GUI presets use similarity and leave native-coordinate
MAD disabled because independent oblique images need not share a global native
pixel displacement.

An optional `epipolarCoplanarity` filter evaluates normalized angular/Sampson
ray coplanarity, robustly centers the current residual distribution, and keeps
its stage state separate in the match ledger. Configure it programmatically
with `FilterPipeline.CoplanarityMethod="robustMad"`; the separate Workbench will
expose it as a staged filter control. Compare all filter models against terrain
truth with:

```matlab
addpath("scripts");
[summary, artifacts] = alignment_filter_model_evaluation();
```

The selected fixture retained `48/58` similarity-filtered matches at `3.57 m`
median and `11.34 m` p95 terrain separation. A `0.01 degree` OPK perturbation
changed the survivor count from `48` to `49`. Reports are written under the
ignored `artifacts/alignment_filter_model_evaluation` directory.

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
The initial view translates the camera position and target together to center
the visible projected footprint, preserves the configured view direction and
camera distance, and fits that footprint to half the viewport. This also
supports narrow view angles below `0.05` degrees for small footprints at long
range. Stabilized axes limits keep large tip/tilt adjustments from changing the
apparent scale on the first edit.

## Backend Processor Workflow

The backend processor milestones are implemented and committed. The backend can
run live in-memory jobs or serialized JSON/MAT jobs, apply viewer state
headlessly, plan full-extent output grids, render composite and per-layer
outputs, write PNG/TIFF products with metadata, process tiles serially or with
`parpool("threads")`, run optional alignment before rendering, and accept
optional GPU requests with CPU fallback.

Backend rendering first compiles a runtime-only `ProjectionBackendRenderPlan`.
Output-grid meshes are reused, interpolation topology is prepared once per
visible layer, and GPU capability is resolved once per job; every output tile
then consumes the same plan. `result.RenderPlan`, validation output, readback,
and JSON metadata contain only the serializable plan summary. The runtime plan's
interpolation objects never enter scene/job serialization.

Backend radiometry defaults to `RenderOptions.NumericalMode =
"fullSourceInverseWarp"`. Sparse geometry defines a piecewise-linear mapping
from output points to continuous source row/column coordinates; nearest or
bilinear sampling then reads every registered band from full `layer.Image`.
`DisplayTexture`, preview pyramids, display tiles, and alignment working images
are never backend inputs. The former
`"sparseIntensityScatteredInterpolant"` mode remains available only as an
explicit backend compatibility reference. The alignment working-image renderer
also requests its historical sparse mode explicitly so backend Pack 1 does not
change GUI match/solve behavior; alignment working images remain alignment-only
and never enter backend rendering. Run `backend_inverse_warp_evaluation` to
quantify the backend modes on a deterministic fixture.

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
