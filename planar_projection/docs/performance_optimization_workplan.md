# Viewer And Backend Performance Optimization Workplan

This document captures the July 2026 performance and scalability audit of the
MATLAB planar projection viewer and backend. It is a design and implementation
workplan, not a record of completed optimization work.

The immediate motivation was unexpectedly chunky interaction when changing
layer alpha, adjusting camera twist, or enabling and moving the crosshair. The
audit also reviewed whether the current tiled backend is suitable for the
expected `15000 x 10000` through `30000 x 20000` source and output sizes.

## Status

The audit and local measurements are complete. No performance changes described
here have been implemented yet.

The current selected feature tree remains Alignment Workflow Hardening until the
user explicitly reprioritizes work. If performance work is selected first, use
the milestone order in this document and commit each coherent, validated pack
separately.

## Non-Negotiable Contracts

All performance work must preserve these constraints:

- The CPU path remains complete, correct, and tested.
- GPU support remains optional and capability-checked. GPU support cannot be
  required on the current macOS development system.
- If backend parallelism is used, it must use only `parpool("threads")` or
  bounded work submitted to that thread pool. Do not create process-based pools.
- Backend rendering continues to use full source imagery and the configured
  output grid. Display pyramids, preview tiles, and alignment working images are
  never backend radiometric inputs.
- Alignment may use selected single-band analysis images, but solved OPK state
  remains applicable to every registered band during backend rendering.
- Graphics handles stay in the app or another explicitly runtime-only graphics
  owner. They do not enter scene, layer, or source-geometry structs.
- Serializable jobs and viewer state remain human-readable and explainable.
- Runtime caches must be derivable from scene/job state and safe to discard.
- Source geometry continues to use the
  `SampleFcn(rowIndices, columnIndices)` adapter contract.
- WASD translation retains its current semantics: sampled rays and origins are
  unchanged; the projected intersections receive an in-plane
  `ProjectionOffsetMeters` translation.

## Audit Environment And Method

The measurements below were made with:

```text
MATLAB R2026a Update 2
macOS development system
CPU graphics/backend path
test_data/10.tif   approximately 3320 x 3228 RGB
test_data/102.tif  approximately 3378 x 2713 RGB
```

The two fixture images were loaded as viewer layers through
`runProjectionViewerPrototype`. Timings used the existing UI callbacks and a
forced `drawnow` where noted so that the result included an actual rendered
frame rather than only property assignment. MATLAB `profile` was used to
identify repeated app, mesh, tile, interpolation, and UI-component work.

These numbers are local diagnostic baselines, not portable pass/fail thresholds.
Future validation should primarily assert structural performance contracts and
report relative timing changes on the same machine and scene.

## Measured Baseline

| Operation | Local result | Important interpretation |
| --- | ---: | --- |
| First two-layer launch in the audit session | about `4.3 s` | Includes image read, app/UI construction, preview setup, and first draw. |
| Warm/profiled two-layer launch | about `2.1 s` | About `1.1 s` was hidden alignment-control construction. |
| Alpha frame with two coarse surfaces | about `19 ms` | Near 50 rendered frames/second if events are scheduled well. |
| Alpha frame with 11 visible tile surfaces | median about `48 ms` | Renderer/compositing dominates; approximately 21 frames/second maximum for this view. |
| Twist callback with 11 visible tile surfaces | median about `137 ms` | Tile selection, geometry probes, restacking, and rendering run on every change. |
| Camera-only roll of the same view | median about `18 ms` | Demonstrates that camera rotation itself is not the twist bottleneck. |
| Crosshair line update with current restacking | median about `98 ms` | Two `uistack` calls dominate the crosshair path. |
| Crosshair line-data update without restacking | median about `2.4 ms` | The coordinate calculation and line update are inexpensive. |
| Backend `256 x 256`, untiled, two layers | about `0.63 s` render time | Builds each layer's interpolation structures once. |
| Backend `256 x 256`, four `128 x 128` tiles | about `2.19 s` render time | Repeats mesh and interpolant setup per tile; about 3.5 times slower. |

The MATLAB Code Analyzer was run across all `src/*.m` files. It found no
graphics-path warning that explains the measured responsiveness. Two
information-level suggestions in `ProjectionAlignmentMatchFilter` were
unrelated to the viewer/backend bottlenecks. The important issues are runtime
architecture and invalidation scope rather than ordinary static-analysis
warnings.

## Current Viewer Dependency And Invalidation Model

The app currently routes many different interactions through broad refresh
helpers. A more precise dependency model is required:

| Interaction | State that truly changes | Required immediate work | Work that can wait until settle |
| --- | --- | --- | --- |
| Alpha | Selected-layer appearance | Set selected-layer opacity and label | Optional higher-quality compositing refresh |
| Crosshair | Diagnostic overlay | Move two overlay lines | None |
| Twist | Camera up vector | Update camera | Tile visibility/LOD reconciliation |
| Camera pan | Camera position and target | Update camera | Tile visibility reconciliation |
| Camera zoom | Camera view angle | Update camera | Tile visibility/LOD reconciliation |
| WASD or Control-drag | Selected-layer plane offset | Apply selected-layer rigid translation | Tile footprint/visibility reconciliation |
| OPK keys or Alt-drag | Selected-layer ray rotation | Reproject selected layer | Higher-quality selected-layer geometry and overlays |
| Tip/tilt | Shared projection plane | Reproject all affected layers | Higher-quality geometry and overlays |
| Visibility | One layer's appearance | Toggle that layer | Blend-channel reassignment if required |
| Blend mode | Visible-layer appearance | Update affected layer textures/alpha | None |
| Layer order | Stack/depth presentation | Update order/depth bias | None |
| Alignment preview/apply/revert | OPK for solved layers | Reproject only affected layers | Overlay refresh |

A future implementation should make these invalidation categories explicit.
The event handler should request a category of work instead of calling one
monolithic projection refresh.

## Detailed Viewer Findings

### 1. Crosshair Restacking And Always-On Motion Handling

`ProjectionViewerApp.pointerMoved` always calls `updateCrosshair`, and the
figure-level `WindowButtonMotionFcn` remains installed over the whole figure.
This means pointer motion over sliders and other controls also enters the
crosshair path.

When disabled or outside the axes, `updateCrosshair` repeatedly assigns
`Visible="off"` to both line objects. When enabled, every update changes six
coordinate properties, makes the lines visible, and calls `uistack` separately
for the horizontal and vertical lines. Tiled surface refresh also restacks the
crosshair even when it is disabled.

The local comparison of approximately `98 ms` with restacking versus `2.4 ms`
without it makes this the highest-confidence quick win.

Candidate solution:

1. Return immediately when neither dragging nor crosshair tracking is active.
2. Install or enable the motion callback only while it is needed.
3. Track whether the crosshair is already hidden and avoid redundant property
   assignments.
4. Keep crosshair geometry in front of projection surfaces using its existing
   camera-relative depth or another explicit overlay depth.
5. Restack only after graphics topology changes if a manual visual test proves
   it is still necessary.
6. Prefer one `uistack` call for a handle vector over two calls if restacking
   remains necessary.
7. Consider a pointer-transparent figure-coordinate annotation or `uihtml`
   overlay if complete isolation from 3-D axes rendering is beneficial.

### 2. Camera Changes Trigger Tile Selection On Every Event

Twist, camera pan, and zoom all call `refreshTiledProjectionSurfaces`
immediately. Camera-only changes do not alter source geometry, OPK, plane
intersection points, or tile world footprints.

The current tile refresh still:

- builds a default sampled layer mesh to select pyramid LOD;
- enumerates candidate tiles for each tiled layer;
- builds a 2-by-2 mesh for every candidate tile to test camera overlap;
- repeatedly queries camera basis, target, and view size inside that tile loop;
- processes hidden tiled layers; and
- raises the crosshair overlay.

Candidate solution:

- Apply the camera property change immediately using the current surfaces.
- Keep a one-tile or configurable screen-space halo around the visible view.
- Defer tile reconciliation to a short settle timer.
- Reconcile immediately only when the viewport leaves the cached halo or the
  selected LOD crosses a material threshold.
- Coalesce repeated wheel and drag events so only the newest request is used.
- Refresh hidden layers only when they become visible.

### 3. `drawnow limitrate` And Event Backlog

Several interaction paths use `drawnow limitrate`. MATLAB documents that this
limits updates to 20 frames per second and skips a draw if fewer than 50 ms have
elapsed or the renderer is busy. The app's `MinPreviewInterval = 1/30` therefore
cannot produce 30 displayed frames per second through those calls.

The correct response is not to replace every call with unrestricted `drawnow`.
Doing so can process more callbacks and make stale-event backlog worse.

Candidate solution:

- Introduce one preview update scheduler owned by the app.
- UI callbacks store desired state and return quickly.
- The scheduler consumes only the newest desired state.
- The scheduler measures its previous frame cost and selects a sustainable
  cadence.
- Intermediate interactive updates use an explicit quality budget.
- `ValueChanged`, mouse release, or a settle timer flushes one exact final state.
- Use `drawnow nocallbacks` or another deliberate draw policy inside the
  scheduler when it prevents callback reentrancy without breaking required
  interaction.

### 4. Tile Visibility Rebuilds Geometry Repeatedly

`previewTileOverlapsCameraView` creates a temporary layer, builds a 2-by-2 mesh,
converts its four points, queries camera state, and then performs a bounding-box
test. This is repeated for every tile at every attempted pyramid level.

Candidate solution:

- Cache each tile's source corner observations.
- Cache projected 3-D tile footprints until plane, OPK, or projection-offset
  state changes.
- Compute camera basis and view bounds once per refresh.
- Project all tile footprints into screen coordinates with batched matrix
  operations.
- Perform vectorized bounding-box intersection for all tiles.
- Cache each layer's projected extent for LOD selection instead of rebuilding
  the default mesh for camera-only changes.
- Avoid enumerating and scanning progressively coarser complete tile sets when
  the visible source region and required level can be estimated directly.

### 5. Tile Surface Replacement Is All-Or-Nothing

The current reuse test requires the complete tile struct vector to be equal. If
one tile enters or leaves the view, every surface in that layer is deleted and
recreated. This causes graphics-object churn, texture preparation/upload, and
crosshair-order maintenance.

Candidate solution:

- Assign a stable key to every tile, such as level plus source row/column limits.
- Retain surface handles for keys that remain visible.
- Hide or recycle handles for departing tiles.
- Assign recycled handles only to entering tiles.
- Cache prepared display texture and sampled geometry by tile key in an LRU
  cache with a configurable memory budget.
- Keep surface handle order independent of tile enumeration order.
- Test that one-tile viewport changes preserve all overlapping graphics handles.

### 6. Projection Refresh Scope Is Too Broad

Selected-layer translation and selected-layer OPK changes currently route
through `updateProjection`, which loops across all layers. This repeats work for
layers whose mathematical state did not change.

Candidate solution:

- Split shared-plane refresh from selected-layer projection refresh.
- Add an affected-layer list for alignment preview/apply/revert.
- Cache `SampleFcn` outputs keyed by layer and row/column sampling.
- Split pure mesh work into sampling and projection stages:

```text
SampleFcn rows/columns -> immutable sampled G/V
sampled G/V + OPK + plane -> intersections
intersections + projection offset -> displayed points
```

- Reuse sampled `G/V` through plane, OPK, and projection-offset changes.
- Implement WASD/Control-drag as an exact selected-layer translation, using
  `hgtransform` if it behaves reliably under `uiaxes`, or a direct delta applied
  to current surface coordinates.
- Reconcile tile visibility and full-quality geometry after the drag settles.

### 7. Alpha Is Primarily Renderer/Transparency Limited

At the 11-surface test view, MATLAB-side alpha callback work was only a small
fraction of the approximately `48 ms` forced frame. Transparency compositing and
graphics-object rendering dominate.

Low- and medium-risk improvements:

- Throttle/coalesce alpha preview updates through the shared scheduler.
- Update only the alpha label rather than all tip/tilt/twist/OPK labels.
- Avoid assigning the slider's current value back during `ValueChanging` when
  the UI component already owns that value.
- Set surfaces invisible at exact alpha zero and restore visibility when alpha
  becomes positive.
- Use a coarser interaction LOD while alpha is moving and restore the selected
  view on release.
- Use a global visible-texture and graphics-object budget across layers rather
  than a separate maximum for every layer.
- Consolidate a contiguous visible source region into fewer texture surfaces or
  a per-layer texture atlas.

Disabling `GraphicsSmoothing` did not improve the local alpha benchmark and is
not recommended as a work item.

### 8. Hidden Alignment Controls Add Startup Cost

The profiled warm launch spent about `1.1 s` constructing the hidden alignment
grid, controls, and two web-backed tables. The panel is hidden by default.

Candidate solution:

- Create only a lightweight alignment-panel placeholder and context-menu state
  at app startup.
- Instantiate the full alignment controls on first open.
- Retain them after first creation so subsequent show/hide operations are cheap.
- Preserve current alignment-panel location and behavior.

### 9. Preview Pyramid And Large-Image Memory

`ProjectionPreviewPyramid.build` stores the original image as level 1 and
eagerly materializes every coarser power-of-two level. Copy-on-write avoids an
immediate second copy of level 1, but the coarser levels approach one-third of
the original image storage. A `30000 x 20000` RGB `uint8` source is about
`1.8 GB`, so its additional decimated levels approach `0.6 GB` per layer before
graphics textures and caches.

Candidate solution:

- Keep preview image access behind a runtime-only region provider.
- Build only the levels currently useful for the initial view, then populate
  finer/coarser levels lazily.
- Use `blockedImage` or an equivalent `ReadRegionFcn` for file-backed imagery.
- Maintain a bounded LRU cache of decoded/prepared preview tiles.
- Keep the full source image or source descriptor available to the backend.
- Never export preview pyramid levels as backend inputs.

### 10. Source Geometry Sampling Can Be Cached

Real source geometry uses repeated `interp1`/`interp2` calls inside `SampleFcn`.
The same row/column sets recur for default meshes, drag meshes, tile geometry,
and tile-corner visibility probes.

Candidate solution:

- Cache sampled `G/V` in a viewer runtime cache keyed by a stable layer identity
  and exact row/column vectors.
- Consider prepared `griddedInterpolant` objects inside the source adapter if
  profiling real sensor geometry shows the shared CPU/backend sampler benefits.
- Keep any such prepared objects runtime-only or reconstructable from the sparse
  grid payload so serialized geometry remains explainable.

## Strategic Viewer Option: Raster Preview Mode

The highest-ceiling viewer option is to stop using many transparent textured
surfaces for the normal operator view.

The final presentation is a projection-plane image viewed through an
orthographic frame camera. A pure preview renderer could:

1. Build a viewport-sized output grid.
2. Map that grid to source row/column coordinates for each visible layer.
3. Sample the selected preview LOD or source region.
4. Blend visible layers numerically.
5. Display one opaque image or texture surface.
6. Draw crosshair and alignment diagnostics in a separate 2-D overlay.

Expected advantages:

- Alpha, visibility, and blend changes become numeric compositing rather than
  MATLAB transparent-surface sorting.
- The graphics layer repaints one opaque object.
- Preview and backend can share a pure inverse-warp implementation.
- Preview/exact difference testing becomes straightforward.
- The existing surface renderer can remain as a geometry-debug mode.

Risks and decision points:

- The inverse-warp implementation must be numerically validated against current
  projection geometry.
- Viewport resampling must remain responsive at the selected resolution.
- A raster preview changes interpolation appearance and should be compared
  visually against the surface path before becoming default.
- It is a larger architectural change than crosshair, scheduling, and tile-cache
  improvements.

Recommendation: implement and benchmark the low-risk viewer packs first. Then
prototype raster preview behind an option and compare frame time, memory,
visual quality, and code complexity before deciding whether it becomes the
default path.

## Detailed Backend Findings

### 1. Meshes And Interpolants Are Rebuilt Per Tile

Every output tile calls the complete `ProjectionReadbackRenderer.renderScene`
path. That path builds a first-layer mesh to create a sampling grid, builds the
first layer again inside the layer loop, builds every other layer, and creates
one `scatteredInterpolant` per band and layer.

For four tiles, two RGB layers create 24 band interpolants over the same source
mesh nodes. The local four-tile render was about 3.5 times slower than the
untiled render even though the final output pixel count was identical.

Candidate solution:

- Compile a render plan once before tile execution.
- Build each layer mesh once.
- Build reusable topology/inverse-mapping structures once.
- Resolve and validate render options once.
- Resolve GPU capability once per job.
- Evaluate only tile-specific query coordinates and image samples inside the
  tile loop.

### 2. The Current Tiled Renderer Is Not Bounded-Memory End To End

The renderer computes tiles independently but then allocates complete
double-precision composite and per-layer outputs in memory. It also allocates a
full `2 x PixelCount` query-plane coordinate array for every layer.

`tileLinearIndices` constructs:

```matlab
reshape(1:prod(outputSize), outputSize)
```

for every assigned tile. At `30000 x 20000`, that temporary double vector alone
is about `4.8 GB`.

Approximate persistent array cost for a `30000 x 20000` RGB output:

| Array | Approximate memory |
| --- | ---: |
| One RGB double image | `14.4 GB` |
| One logical valid mask | `0.6 GB` |
| One layer's `2 x PixelCount` double query coordinates | `9.6 GB` |
| Composite image plus mask | `15.0 GB` |
| One per-layer image, mask, and coordinate array | `24.6 GB` |
| Composite plus two layer readbacks | about `64.2 GB` |

This excludes source imagery, pyramid memory, interpolants, tile results, and
temporary arrays.

Threaded execution also stores every completed tile result in a cell array
before assembly, which increases peak memory and defeats bounded streaming.

Candidate solution:

- Make tile consumption incremental.
- Write large TIFF products with tiled/striped `Tiff` APIs as tiles finish.
- Make returned in-memory images opt-in and subject to an explicit pixel/memory
  limit.
- Do not store output-wide query-plane coordinates unless a small diagnostic job
  explicitly asks for them.
- Compute any needed tile indices analytically without an output-sized index
  image.
- In thread mode, use bounded `parfeval` work on `parpool("threads")` and consume
  results with `fetchNext`, keeping only a limited number of tiles in flight.
- Keep deterministic output placement and tile-level diagnostics.

### 3. Full-Source Radiometric Semantics Need A Design Checkpoint

The current readback renderer samples image intensities only at:

```matlab
layer.Image(mesh.RowIndices, mesh.ColumnIndices, :)
```

and interpolates those sparse intensity values across the output. With default
row/column strides, this does not appear to consume full source radiometry in the
intended 1:1-oriented sense, even though the backend correctly avoids preview
pyramids and uses `layer.Image` rather than `DisplayTexture`.

A more direct full-source design is:

1. Use sparse geometry samples to define a piecewise mapping between source
   row/column coordinates and the projection/output plane.
2. Invert that mapping for each output tile.
3. Obtain floating-point source row/column coordinates for each valid output
   pixel.
4. Bilinearly or nearest-neighbor sample the full source image at those
   positions.
5. Reuse the same mapping for every registered band.

This separates geometric interpolation from radiometric interpolation. It also
builds only two source-coordinate mapping fields per layer instead of building a
new spatial interpolant for every image band and output tile.

This change can alter numerical output relative to the current sparse-intensity
prototype, so it is a user-visible design checkpoint. Before implementation:

- confirm that full-source inverse sampling is the intended backend contract;
- construct small deterministic parity examples;
- document boundary and invalid-region behavior;
- define bilinear/nearest semantics precisely; and
- retain the old path temporarily as a comparison oracle if useful.

### 4. Output Writing Copies And Normalizes Full Images

The output writer converts each complete image to double, replaces invalid
values, scans global minimum/maximum, conditionally rescales, clamps, and then
calls `imwrite`. The process is repeated for each requested output format.

This has two problems:

- It requires full-image materialization and additional full-size copies.
- Data-dependent min/max scaling is not an ideal explainable radiometric policy
  unless its parameters are recorded explicitly.

Candidate solution:

- Add an explicit output pixel class and radiometric scaling policy to the job.
- Preserve `uint8`/`uint16` ranges when appropriate.
- Use single-precision working tiles if numerical tests show they are adequate.
- Record scale/offset, fill value, and output class in metadata.
- Prepare a tile once and write it to the requested large-output format.
- Treat PNG as a small-output or overview format when streaming limitations make
  full-size PNG impractical.

### 5. Validation And Capability Checks Rescan Large State

Backend profiling showed repeated full-image validation and repeated GPU
capability checks:

- integer and logical images are scanned with `isfinite` even though their types
  cannot contain `NaN` or `Inf`;
- job resolution and validation revisit the same scene data; and
- GPU capability resolution invokes `gpuDeviceCount` repeatedly per tiled job.

Candidate solution:

- Run finite-value scans only for floating-point images.
- Validate the resolved scene once and pass a validated render plan downstream.
- Cache GPU capability for the duration of one job or MATLAB session with a
  safe invalidation mechanism.
- Avoid copying large scene structs when a read-only reference/value flow is
  sufficient.

### 6. File-Backed Source Access

Live in-memory jobs must remain supported, but very large sources should not be
required to occupy one contiguous MATLAB array if the caller has file-backed
imagery.

Candidate extension:

```text
Source image contract
    InMemory array
    or ReadRegionFcn(rowRange, columnRange, bandIndices)
    or supported blockedImage/file descriptor
```

The render plan would describe source size, class, band count, and provenance.
The runtime renderer would request only the regions needed by each output tile.
This continues to process the full source product and does not introduce preview
imagery into the backend.

## Explainability-Preserving Runtime Architecture

Performance does not require hiding the mathematical model. Separate the
explainable plan from replaceable runtime acceleration:

### Serializable `ProjectionRenderPlan`

Candidate fields:

```text
Format and version
Output grid and pixel spacing
Visible layer order
Per-layer projection plane, offset, OPK, alpha, and blend mode
Source image descriptor and band policy
Geometry sampling/topology description
Interpolation and invalid-fill policy
Radiometric scaling/output-class policy
Tile size and execution policy
Optional state/source hashes
```

The plan remains a plain struct suitable for metadata and validation.

### Runtime-Only `ProjectionRenderCache`

Candidate contents:

```text
Sampled G/V arrays
Layer mesh coordinates
Triangulation or inverse-warp structures
Tile footprints and screen bounds
Prepared preview textures
LRU cache state
Thread-local reusable work buffers
Graphics surface pools in the app only
```

The cache is never required to reproduce a job, is not serialized, and can be
discarded at any time. Graphics handles remain confined to the app-facing cache.

### Cache Invalidation Keys

Use explicit versions or stable keys for:

```text
Camera state
Shared projection-plane state
Per-layer source geometry
Per-layer OPK
Per-layer projection offset
Per-layer appearance
Preview viewport and LOD
Output-grid and interpolation policy
```

Avoid hashing full source images during interaction. Prefer state counters or
identifiers established when the source is loaded.

## Proposed Viewer Performance Packs

### Viewer Performance Pack 0: Measurement Harness

Deliverables:

- A repeatable script such as `scripts/viewer_performance_evaluation.m`.
- Local ignored output under `artifacts/viewer_performance/`.
- Counters/timings for frame requests, rendered frames, dropped/coalesced
  requests, tile candidates, tile cache hits/misses, mesh builds, surface
  creations/deletions, and visible texture pixels.
- Scenarios for alpha, crosshair, twist, pan, zoom, WASD, and OPK interaction.
- A compact diagnostic struct suitable for tests and manual comparison.

Acceptance criteria:

- The harness can reproduce the baseline scenarios without modifying backend
  output or viewer state beyond the test session.
- Performance tests assert structural work counts and handle reuse rather than
  brittle machine-specific elapsed-time limits.
- The full existing test suite remains green.

Suggested commit:

```text
Viewer Performance Pack 0: Add interaction benchmark harness
```

### Viewer Performance Pack 1: Crosshair Event Path

Deliverables:

- Remove per-motion restacking.
- Avoid redundant hidden-state assignments.
- Activate pointer motion work only when needed.
- Preserve crosshair screen registration across pan, zoom, twist, and resize.
- Add focused interaction tests for stable handles and visibility transitions.

Acceptance criteria:

- Crosshair movement does not rebuild meshes, refresh tiles, or create/delete
  surfaces.
- Crosshair movement performs no `uistack` operation in the steady state.
- Slider dragging outside the axes does not repeatedly update crosshair graphics.
- Manual visual validation confirms the crosshair remains visible above imagery.

Suggested commit:

```text
Viewer Performance Pack 1: Streamline crosshair updates
```

### Viewer Performance Pack 2: Latest-State Camera Scheduler

Deliverables:

- A single latest-state-wins preview scheduler.
- Immediate camera-only updates for twist, pan, and zoom.
- Deferred tile/LOD reconciliation after interaction settles.
- A prefetched viewport halo and clear settle/finalize behavior.
- No stale event queue after fast slider or mouse input.

Acceptance criteria:

- Twist `ValueChanging` does not build layer or tile-probe meshes.
- Camera pan does not create/delete surfaces while the current halo covers the
  viewport.
- The final settled view selects the correct tiles and LOD.
- The final viewer state exactly reflects the last requested value.
- Crosshair and alignment overlays remain correctly registered.

Suggested commit:

```text
Viewer Performance Pack 2: Coalesce camera preview updates
```

### Viewer Performance Pack 3: Cached Vectorized Tile Visibility

Deliverables:

- Cached layer extents and tile footprints.
- Batched camera projection and visibility tests.
- Hidden-layer exclusion.
- Direct LOD estimation without repeated default-mesh builds.
- Cache invalidation for plane, OPK, offset, image size, and tile layout changes.

Acceptance criteria:

- Camera-only refresh performs no `SampleFcn` calls.
- Camera basis/view state is queried once per refresh rather than once per tile.
- Visibility results match the current implementation on deterministic scenes.
- Cache invalidation tests prevent stale footprints after geometry changes.

Suggested commit:

```text
Viewer Performance Pack 3: Cache tile visibility geometry
```

### Viewer Performance Pack 4: Differential Tile Reuse

Deliverables:

- Stable tile keys.
- Surface-handle reuse for overlapping tile sets.
- Bounded prepared-texture and mesh LRU cache.
- Surface-pool cleanup on app deletion and scene reset.

Acceptance criteria:

- A one-tile viewport shift preserves every overlapping surface handle.
- Only entering tiles prepare/upload new texture data.
- Cache memory remains below its configured budget.
- Reset and layer replacement cannot reuse stale tile data.

Suggested commit:

```text
Viewer Performance Pack 4: Reuse preview tile surfaces
```

### Viewer Performance Pack 5: Targeted Geometry Invalidation

Deliverables:

- Separate shared-plane and per-layer refresh paths.
- Cached sampled source geometry.
- Selected-layer OPK refresh.
- Exact rigid projection-offset transform during WASD/Control-drag.
- Affected-layer refresh for alignment preview/apply/revert.

Acceptance criteria:

- WASD does not call `SampleFcn` or change stored source rays/origins.
- WASD preserves the existing `ProjectionOffsetMeters` state contract.
- Selected-layer OPK edits do not rebuild unchanged layers.
- Tip/tilt still refreshes every layer sharing the projection plane.
- Backend and viewer state serialization remain unchanged.

Suggested commit:

```text
Viewer Performance Pack 5: Target projection geometry updates
```

### Viewer Performance Pack 6: Transparency And Object Budget

Deliverables:

- Coalesced alpha updates.
- Exact-alpha-zero visibility behavior.
- Interaction LOD and global object/texture budget.
- Benchmark of per-layer surface consolidation or a texture atlas.

Acceptance criteria:

- Alpha does not rebuild geometry or recompute tile selection.
- Intermediate alpha interaction stays within the configured render budget.
- Release/final alpha is exact.
- Visual blending and layer order match existing behavior.

Suggested commit:

```text
Viewer Performance Pack 6: Budget transparent preview rendering
```

### Viewer Performance Pack 7: Lazy UI And Preview Storage

Deliverables:

- Lazy alignment-control creation.
- Lazy or file-backed preview pyramid levels.
- Bounded preview tile cache.
- Startup and memory diagnostics.

Acceptance criteria:

- The alignment panel remains hidden by default and is functionally identical
  after first open.
- Initial app launch does not create the large match/pair tables.
- Backend export continues to contain full source image data or source
  descriptors, never preview levels.

Suggested commit:

```text
Viewer Performance Pack 7: Load heavy preview UI lazily
```

### Viewer Performance Pack 8: Raster Preview Prototype And Decision

Deliverables:

- Optional single-raster preview path.
- Shared pure viewport-grid/inverse-warp helper where practical.
- Side-by-side timing, memory, and visual comparison with surface preview.
- A decision record: adopt, retain as optional, or reject.

Acceptance criteria:

- The prototype does not replace the surface path before comparison is complete.
- Alpha, visibility, crosshair, and camera interactions are exercised.
- Preview image differences are quantified against current preview and exact
  readback on small deterministic scenes.
- The CPU path is complete.

Suggested commit:

```text
Viewer Performance Pack 8: Evaluate raster preview architecture
```

## Proposed Backend Performance Packs

Backend performance packs should begin only after confirming the full-source
inverse-warp contract. They are follow-up backend work, not new historical
Backend Milestones 11+.

### Backend Performance Pack 0: Compile Render Plan

Deliverables:

- Pure, validated render-plan model.
- Per-layer mesh/topology preparation once per job.
- GPU capability resolution once per job.
- Existing renderer adapted to consume the plan without changing numerical
  output.

Acceptance criteria:

- Tiled and untiled small-scene results remain numerically equivalent.
- Mesh build count is independent of output tile count.
- Result metadata records the plan's output and interpolation policy.

Suggested commit:

```text
Backend Performance Pack 0: Compile reusable render plans
```

### Backend Performance Pack 1: Full-Source Inverse Warp

Deliverables:

- Pure mapping from output points to source row/column positions.
- Full source image sampling for every band.
- Precise nearest/bilinear and invalid-region policy.
- Compatibility comparison against the current sparse-intensity renderer.

Acceptance criteria:

- Geometry sampling and radiometric sampling are separate.
- Preview imagery is never used as backend input.
- All registered bands use the same source-coordinate warp.
- Tests cover identity, translation, OPK, oblique geometry, invalid borders,
  single-band, RGB, and arbitrary-band images.

Suggested commit:

```text
Backend Performance Pack 1: Render full-source inverse warps
```

### Backend Performance Pack 2: Bounded Serial Streaming

Deliverables:

- Incremental tiled TIFF/mask writer.
- Optional in-memory result policy with explicit limits.
- Removal of output-sized linear-index temporaries.
- Optional omission of full query-coordinate diagnostics.
- Tile-level timing and memory reporting retained.

Acceptance criteria:

- Peak working memory is bounded by configured tile/cache sizes plus small fixed
  job state when files are written.
- A synthetic large-output planning test does not allocate an output-sized index
  array.
- Streamed TIFF pixels agree with the in-memory reference on small scenes.
- Partial files are closed cleanly on failure.

Suggested commit:

```text
Backend Performance Pack 2: Stream serial tiled outputs
```

### Backend Performance Pack 3: Bounded Thread Pipeline

Deliverables:

- Bounded `parfeval` submission on `parpool("threads")`.
- Ordered or indexed tile writes using `fetchNext` results.
- Deterministic output and bounded in-flight memory.
- Clear handling of an incompatible active pool.

Acceptance criteria:

- No process-based pool is created or required.
- Threaded and serial products agree numerically.
- Peak retained tile results stay within the configured in-flight limit.
- Worker failures identify the tile and close output resources.

Suggested commit:

```text
Backend Performance Pack 3: Bound threaded tile execution
```

### Backend Performance Pack 4: Radiometric And Precision Policy

Deliverables:

- Explicit output class and scale/offset contract.
- Single-precision working-tile option if validated.
- Metadata for output radiometry.
- Format-aware writing without repeated full-image normalization.

Acceptance criteria:

- Integer-source identity cases preserve expected values.
- Scaling is deterministic and recorded.
- TIFF/PNG behavior is explicit for supported band counts and sizes.
- Numerical tolerances are documented for single precision.

Suggested commit:

```text
Backend Performance Pack 4: Define output radiometric policy
```

### Backend Performance Pack 5: File-Backed Source Regions

Deliverables:

- Optional source-region provider contract.
- In-memory compatibility adapter.
- `blockedImage` or supported TIFF-region adapter.
- Source provenance and size/class metadata.

Acceptance criteria:

- In-memory jobs continue to work unchanged.
- File-backed and in-memory rendering agree on the same source data.
- Only required source regions are resident for a tiled write.
- Viewer preview providers remain separate from backend source providers.

Suggested commit:

```text
Backend Performance Pack 5: Read source imagery by region
```

## Validation Strategy

### Structural Performance Tests

Prefer deterministic counts and invariants:

- camera-only operations do not call `SampleFcn`;
- crosshair updates do not call `uistack` or touch surfaces;
- alpha changes do not build meshes or change tile selection;
- a one-tile viewport change creates only entering tile surfaces;
- selected-layer changes do not rebuild other layers;
- backend mesh/interpolant preparation count is independent of tile count;
- streaming mode does not allocate output-sized coordinate/index arrays; and
- thread mode never creates a process-based pool.

### Numerical Tests

- Existing mesh, readback, backend, viewer-state, and alignment tests.
- Tiled versus untiled equivalence.
- Serial versus thread-pool equivalence.
- Current renderer versus compiled-plan equivalence before inverse-warp changes.
- Full-source inverse-warp tests on analytically predictable scenes.
- Multi-band warp consistency.
- Preview pyramid/provider data never entering backend render input.

### Interaction Tests

- Alpha fast drag and exact release.
- Twist fast drag without stale updates.
- Pan and zoom within/across the tile halo.
- Crosshair across imagery and controls.
- WASD and Control-drag translation.
- OPK keyboard and Alt-drag.
- Alignment preview/apply/revert with overlay registration.
- Visibility, layer cycle, layer order, and reset.

### Manual Performance Evaluation

Use:

```matlab
close all force;
clear classes;
rehash;
app = runProjectionViewerPrototype(["test_data/10.tif", "test_data/102.tif"]);
```

Exercise initial and zoomed views, record tile/surface counts, and compare the
same interaction sequence before and after each pack.

Run full validation after every completed pack:

```matlab
close all force;
clear classes;
rehash;
results = runTests;
```

### Performance Reporting

Record at least:

```text
MATLAB version
OS and hardware summary
fixture dimensions and band counts
visible layer count
camera view angle
visible tile/surface count
visible texture pixels
median and high-percentile frame time
mesh and SampleFcn call counts
surface create/delete counts
cache hit/miss counts
backend tile count and peak estimated memory
```

Do not commit local TIFFs or machine-specific artifact output.

## Risks And Mitigations

### Timer Reentrancy And Stale State

Risk: a new scheduler could apply stale state or fire after app deletion.

Mitigation: one owner, one latest request, explicit generation counters,
`BusyMode`/timer cleanup, and final-state tests.

### Cache Invalidation Errors

Risk: stale geometry or textures after plane, OPK, offset, layer order, or reset.

Mitigation: explicit invalidation keys and deterministic tests for every state
category.

### Crosshair Or Overlay Occlusion

Risk: removing steady-state `uistack` could allow new surfaces to cover an
overlay.

Mitigation: explicit overlay depth or separate overlay owner, restack only after
topology changes, and manual validation.

### Temporary Low-Quality Interaction

Risk: delayed tile reconciliation or coarser LOD exposes blank edges or visible
quality changes.

Mitigation: viewport halo, minimum interaction quality, and immediate exact
settle refresh.

### Inverse-Warp Numerical Change

Risk: full-source radiometric sampling changes output relative to the current
sparse-intensity prototype.

Mitigation: explicit user decision, comparison oracle, deterministic fixtures,
and documented interpolation semantics.

### Thread Safety And Memory

Risk: prepared MATLAB interpolation objects might not be safe or efficient when
shared among thread workers.

Mitigation: measure thread support, use immutable shared arrays where safe,
create bounded thread-local runtime objects if necessary, and retain the serial
reference path.

### Streaming Output Failure

Risk: partial TIFFs or inconsistent metadata after errors.

Mitigation: `onCleanup`, temporary output names, atomic final rename where
practical, and explicit failure metadata/logging.

## Work That Is Not Recommended Yet

- Do not pursue viewer GPU acceleration before fixing event, invalidation,
  object-count, and transparency architecture.
- Do not introduce process-based pools.
- Do not write custom GPU kernels for these bottlenecks.
- Do not expect `GraphicsSmoothing="off"` to solve alpha responsiveness.
- Do not tune tile size blindly without measuring object count, texture
  overfetch, selection cost, and renderer cost together.
- Do not serialize graphics handles, interpolants, or caches into scene/job
  contracts.
- Do not let display pyramids become backend inputs.

## Recommended Decision And Execution Order

If performance work is prioritized before the remaining alignment terminology
work, the recommended first sequence is:

1. Viewer Performance Pack 0: measurement harness.
2. Viewer Performance Pack 1: crosshair event path.
3. Viewer Performance Pack 2: latest-state camera scheduler.
4. Viewer Performance Pack 3: cached/vectorized tile visibility.
5. Viewer Performance Pack 4: differential tile reuse.
6. Viewer Performance Pack 5: targeted geometry invalidation.
7. Viewer Performance Pack 6: transparency/object budget.
8. Viewer Performance Pack 7: lazy UI and preview storage.
9. Viewer Performance Pack 8: raster preview prototype and decision.

In parallel only at the planning/design level, confirm the backend full-source
inverse-warp semantics. Then execute Backend Performance Packs 0-5 in order.

Do not mix the viewer quick wins and backend renderer rewrite into one commit.
Each pack should remain independently reviewable, validated, and reversible.
