# Real-Data Surface And Stereo Recovery Workplan

Status: active July 15, 2026. The documentation baseline and SR-0/SR-1
implementation milestone are complete. SR-2 through SR-6 remain in progress.

## Purpose

Correct the real-data failures observed while running and reviewing Surface
Workbench products and while returning to the main viewer's tiled anaglyph
Pair View. The required outcome is a workflow that:

1. associates multi-pair dense observations in bounded, observable time;
2. presents ECEF-backed products in a meaningful local East/North/Up frame
   without changing their authoritative coordinates;
3. behaves like a normal interactive MATLAB 3-D surface/point viewer;
4. can reopen a saved Surface Workbench MAT run and inspect every available
   point-cloud, voxel, mesh, and grid product;
5. never accumulates stale or duplicate red/cyan image surfaces while stepping
   Pair View; and
6. provides an in-place **Rebuild viewport** recovery that removes renderer
   junk and reconstructs the current presentation without resetting OPK,
   alignment evidence, corrections, layer state, or camera state.

The template-matcher failure from the same operator session remains a required
intake item. Its exact failure identifier and message were not available when
this plan was written, so this document does not invent a cause or combine it
with the independently confirmed association scaling defect.

## Operator Evidence

The reported sequence was:

1. An all-quality-pair classical-template run eventually failed on a clean
   dataset. The final message will be supplied separately.
2. A GPU SGM run reached the fixed 72 percent association marker quickly and
   then spent a long time there with a 5,000-per-pair cap.
3. The run was cancelled and repeated with 250 observations per pair. The
   association stage was still long, although the operator did not continuously
   time it.
4. A completed result opened in the 3-D Surface Viewer. Its coordinates were
   ECEF, so raw world `+Z` was not height. The surface could not be rotated like
   a normal MATLAB plot.
5. The complete Surface Workbench MAT result was exported for later manual
   inspection.
6. After closing the 3-D viewer, Surface Workbench, and Alignment Workbench,
   tiled anaglyph Pair View was exercised over pairs `1/2`, `2/3`, `3/4`, and
   later pairs. Old red/cyan surfaces accumulated, inactive layers remained in
   the viewport, and overlapping copies z-fought.
7. Visibility toggles and returning to View All did not repair the viewport.
   The existing Reset action was unsuitable because it restores scientific
   scene/correction state. Closing the main viewer was the only apparent
   recovery and discarded the active working session.

## Confirmed Structural Causes And Gaps

### Association

`ProjectionSurfaceWorkbenchRunner` publishes one association event at 72
percent, calls `ProjectionDenseObservationAssociator.associate`, and publishes
no further progress until reconstruction completes or fusion begins at 88
percent. Association and multi-ray reconstruction receive no runtime progress
or cancellation control.

The current associator has several multiplicative costs:

- observation collection sorts unique string keys, then scans the complete key
  vector with `find(keys == key)` for every unique observation;
- disjoint-set `join` relabels with `parent(parent == root)`, scanning the full
  parent vector for every accepted pair record;
- component enumeration rescans every observation for every root;
- edge membership rescans eligible records for every component;
- `componentViews` scans every observation during repeated edge reconciliation;
  and
- observations, mode groups, and tracks grow dynamically in critical loops.

The observation cap is per pair. Ten pairs at 250 and 5,000 therefore permit
2,500 and 50,000 pair records respectively. Lowering the cap cannot make the
present repeated global scans an acceptable production algorithm.

### Coordinate-frame presentation

`ProjectionSurfaceWorkbenchRunner` currently labels reconstruction records
with the generic frame `sceneWorld`. `ProjectionSurfaceProductCatalog` retains
only that frame label, not a reversible local display transform.
`ProjectionSurface3DViewer` renders `PointsWorld`, mesh vertices, and grid
coordinates directly, labels its axes `World X/Y/Z`, and the model's
`elevation` color mode uses the third world-coordinate component. For ECEF,
that component is neither local Up nor ellipsoidal height.

The main viewer already uses `scene.renderOrigin` to keep graphics near a local
origin, and the DEM SDK already owns reversible WGS84 ECEF/local-ENU transform
semantics. The Surface Viewer does not yet share an equivalent portable frame
contract.

### 3-D interaction and saved-run inspection

The 3-D viewer creates a `UIAxes`, applies `view(...,3)`, and assigns a
`ButtonDownFcn` to every rendered object for point selection. It does not
explicitly configure the standard rotate/pan/zoom interaction set. The object
callback can win the gesture over ordinary axes rotation.

Surface Workbench MAT export correctly retains `surfaceWorkbenchRun`, including
the catalog, point set, association, pair evidence, fusion result, and
provenance. There is no validated public loader or **Open saved run** workflow.
The constructor can inspect an already extracted catalog, but users must know
the internal MAT variable and object-creation sequence.

### Tiled anaglyph ownership and recovery

Pair View computes an effective two-layer presentation mask and tracked
surfaces are updated against it. Tiled replacement, however, is not a
transaction:

- replacement surfaces can be created or acquired before the prior set is
  retired and before the new set is committed to `app.Surfaces`;
- an exception or stale completion during that interval can leave a graphics
  object under the axes but outside the active per-layer arrays and hidden
  surface pool;
- later visibility and anaglyph updates visit tracked arrays, not escaped axes
  children;
- surface `UserData` records a tile key but no app owner, layer/view identity,
  render generation, or active/pool ownership state; and
- diagnostics count tracked surfaces but do not compare them with every tagged
  renderer-owned axes child.

`rebuildSurfaces` deletes tracked per-layer surfaces and recreates them, but the
only operator path that invokes the broad rebuild is the scientific Reset
workflow. Reset also restores `ResetScene`, clears OPK/alignment state, and is
therefore not a safe graphics-recovery command. Even the current rebuild does
not explicitly sweep escaped tagged children.

## Authority And Non-Negotiable Contracts

This plan extends the completed RD-7 contracts; it does not weaken them.

- Authoritative points, covariance, rays, links, meshes, and grids stay in
  their declared world frame and double precision. ENU, origin-relative, HAE,
  vertical exaggeration, and camera state are presentation values.
- Never relabel ECEF `Z` as elevation or height.
- Coordinate-frame conversion must be explicit, reversible where promised,
  and carried in portable provenance. Magnitude-based ECEF guessing may offer
  an advisory but never silently defines a scientific frame.
- The CPU association path remains complete, deterministic, and tested. GPU
  SGM acceleration does not change association semantics.
- Multi-view association continues to count one stable source observation as
  one ray, reject duplicate-view tracks, preserve all raw records and reasons,
  and retain stable identities.
- Association optimization must preserve existing outputs on deterministic
  fixtures. Performance work cannot weaken confidence, visibility, geometry,
  conditioning, or track-conflict gates.
- Display surface ownership, caches, pools, timers, callbacks, and interaction
  modes remain runtime-only.
- **Rebuild viewport** is presentation-only. It must not mutate scene layers,
  OPK corrections, correction lineage, matches, filters, solve state, Surface
  Workbench results, stored visibility, layer order, active-pair identity,
  anaglyph settings, stereo cursor world point, or saved state.
- Reset remains a scientific/session reset and must be labeled distinctly from
  viewport recovery.
- Existing saved MAT runs from the current schema are first-class migration
  fixtures. The correction must not require rerunning private imagery.
- No private imagery, paths, coordinates, collection dimensions, or identifying
  product values enter Git, fixtures, documentation, or commit messages.

## Ordered Queue

| Order | Pack | Outcome |
| ---: | --- | --- |
| 1 | SR-0 | Preserve the current run, capture the template failure, and freeze repeatable structural benchmarks. |
| 2 | SR-1 | Replace repeated global association scans with near-linear indexed grouping and real disjoint-set/component processing. |
| 3 | SR-2 | Add truthful portable world/display-frame metadata and local ENU/height presentation. |
| 4 | SR-3 | Add normal 3-D interactions and a supported loader/inspector for saved MAT runs. |
| 5 | SR-4 | Make tiled/anaglyph surface replacement transactional and enforce exact renderer ownership. |
| 6 | SR-5 | Add an operator-visible presentation-only Rebuild viewport recovery. |
| 7 | SR-6 | Validate the integrated real-data workflow, document it, and complete delivery. |

SR-1 should precede further large matching experiments. SR-2 and SR-3 are one
coherent Surface Viewer release slice. SR-4 establishes the ownership contract
that SR-5 uses for deterministic recovery.

## SR-0 — Evidence Preservation And Reproduction Baselines

Status: implementation complete July 15, 2026; private evidence intake remains
an external gate.

### Required work

1. Preserve the current exported MAT file outside Git. Record its anonymous
   case ID, timestamp, app commit, run status, pair schedule, matcher, cap,
   execution path, processing stage, and file checksum.
2. Confirm it contains `surfaceWorkbenchRun` and inventory, without logging
   private values, which of these are present: `Catalog`, `PointSet`,
   `Association`, `FusionResult`, `PairRuns`, `Preflight`, and `Provenance`.
3. When supplied, record the classical-template failure's exact visible
   message, MATLAB exception identifier, failed pair ID, elapsed stage, and
   whether earlier pairs retained valid evidence.
4. Add a structural failure-capture test proving every pair failure preserves
   matcher identifier, exception identifier/message, last completed pair,
   stage, options, and already completed pair evidence in an exportable run.
5. Create a privacy-safe association benchmark generator with stable
   observations, duplicate cross-pair observations, disconnected two-view
   components, multi-view tracks, duplicate-view conflicts, rejections, and
   deterministic expected output.
6. Benchmark at 1 pair and at a five-view/ten-pair schedule with 64, 250, 500,
   and 5,000 records per pair. Record stage work counts separately from wall
   time.
7. Add an ECEF-valued catalog fixture whose local East/North/Up orientation and
   height truth are known without using private coordinates.
8. Add a five-layer tiled Pair View fixture that can inject a failure after
   acquiring replacement surfaces but before commit. This must reproduce an
   escaped/orphan handle before the ownership fix.

### Exit criteria

- Current MAT evidence is safely recoverable and not committed.
- The template failure is either reproducible or retained as a precise open
  finding; it is not guessed from the association defect.
- Association scaling and orphan-surface reproduction are deterministic.
- Existing output semantics are frozen before optimization.

### Implementation and validation record

- The exported private MAT run was not supplied to this repository session.
  Its anonymous inventory/checksum and the original template-matcher visible
  message therefore remain external validation gates; no cause is inferred.
- Pair failures now retain the matcher ID, wrapper and underlying exception
  identifiers/messages, failed pair, stage, exact options, elapsed time, last
  completed pair, and completed pair evidence in portable MAT/JSON run data.
- `ProjectionDenseAssociationFixture` supplies deterministic five-view
  association, duplicate-observation, disconnected-track, duplicate-view
  conflict, rejection, and scaling cases without private values.

## SR-1 — Bounded, Observable Dense Observation Association

Status: complete July 15, 2026; original private-data reproduction remains part
of the SR-6 external gate.

### Algorithm correction

1. Replace per-key `find(keys == key)` scans with one deterministic sort/group
   pass. Preallocate one observation per group and assign record-side node
   indices through the group mapping.
2. Replace whole-vector relabeling with a proper disjoint-set forest using
   parent, rank/size, and path compression. `union` and `find` must not scan
   unrelated nodes.
3. Compute final component IDs once after union, sort/group nodes and edges by
   component, and construct component spans. Do not scan all observations or
   all records for every root.
4. Reconcile view membership within each component using local indexed sets or
   compact view ordinals. Do not call a global `componentViews` scan for every
   edge.
5. Preallocate mode/track outputs where counts are known. Defer stable hashes
   until final identities are assembled; avoid repeated dynamic struct growth
   and string construction in hot loops.
6. Preserve deterministic quality ordering, tie breaking, track identity,
   duplicate-view rejection, mode handling, raw-record order, and diagnostic
   meanings.
7. Keep the reference implementation available in tests or a private helper
   long enough to assert exact parity on small fixtures, then remove duplicated
   production paths when parity is established.

### Progress, cancellation, and resource policy

1. Extend association and multi-ray reconstruction to accept the common
   graphics-free runtime control with progress and cancellation callbacks.
2. Publish bounded substages: normalize, group observations, precheck records,
   union components, reconcile tracks, finalize provenance, and reconstruct
   tracks.
3. Check cancellation between chunks of at most a configured record count and
   before hashing/final assembly. A cancel request shall not wait for the entire
   association stage.
4. Map substage progress monotonically through the runner's 72–88 percent
   interval. The UI shall show processed/total records or components and elapsed
   time; 72 percent alone is not progress.
5. Preflight shall report both per-pair and maximum scheduled total records.
   Add an optional total association budget only as a truthful resource guard,
   distributed deterministically across pairs and spatial support. It is not a
   substitute for correcting the algorithm.
6. On cancellation or failure, retain pair runs and completed stage diagnostics
   in an exportable outcome.

### Acceptance

- Exact record states/reasons, observation values, track memberships, stable
  IDs, point results, and diagnostics match the frozen small reference cases.
- Doubling structurally similar record count does not produce quadratic work
  counts; the benchmark should remain within an initially proposed 2.5-times
  elapsed-time envelope after warm-up on the same host.
- The five-view/ten-pair 250-cap fixture completes association in under five
  seconds on the reference development CPU; 500 completes in under ten
  seconds. These are initial operator targets to be recorded with hardware,
  not portable scientific constants.
- A 5,000-per-pair run either completes the association stage within the
  separately recorded target-host one-minute budget or preflight clearly
  advises/rejects the requested total before Run. It must not appear stuck.
- Progress changes at least once per second during work lasting more than one
  second, and cooperative cancellation is accepted within one second between
  configured chunks on the benchmark host.
- Host memory remains bounded by records, observations, tracks, and explicit
  indexes; there is no dense record-by-observation matrix.

### Validation record

On a 14-core Apple development host using MATLAB R2026a Update 2, the
privacy-safe warm benchmark measured:

| Views / pairs | Records per pair | Total records | Association time (s) | Indexed work count |
| --- | ---: | ---: | ---: | ---: |
| 2 / 1 | 64 | 64 | 0.102 | 1,408 |
| 2 / 1 | 250 | 250 | 0.284 | 5,500 |
| 2 / 1 | 500 | 500 | 0.625 | 11,000 |
| 2 / 1 | 5,000 | 5,000 | 4.975 | 110,000 |
| 5 / 10 | 64 | 640 | 0.375 | 15,424 |
| 5 / 10 | 250 | 2,500 | 0.939 | 60,250 |
| 5 / 10 | 500 | 5,000 | 1.867 | 120,500 |
| 5 / 10 | 5,000 | 50,000 | 18.808 | 1,205,000 |

The focused SR-0/SR-1 suite passed 40/40 with zero incomplete tests, and Code
Analyzer reported zero findings for every changed MATLAB source, helper, test,
and benchmark file. Progress is monotonic across named substages, cancellation
is checked at configured chunk boundaries, and the runner maps association and
reconstruction progress through 72--88 percent while retaining partial
evidence on cancellation or failure.

## SR-2 — Truthful World Frame And Local Surface Presentation

Status: blocked by the SR-0 ECEF fixture. May proceed in parallel with SR-1
after fixtures are frozen.

### Portable frame contract

1. Add one validated graphics-free coordinate-frame value shared by the
   Surface Workbench catalog, 3-D viewer, MAT export, and DEM integration. It
   shall contain at least:

   - authoritative world-frame ID;
   - coordinate kind such as `ecef`, `localCartesian`, or `unknown`;
   - units;
   - display-frame ID;
   - local origin in authoritative world coordinates;
   - a proper world-to-local rotation;
   - axis names and units;
   - optional WGS84 origin latitude/longitude/HAE;
   - vertical/height reference and whether absolute height is available; and
   - derivation/provenance and reversibility status.

2. Propagate the actual common source/scene coordinate frame through the runner
   instead of hardcoding only `sceneWorld`. Reject inconsistent pair-side
   world frames before reconstruction.
3. For ECEF input, use a declared scene origin when available. Otherwise allow
   an explicit operator-supplied WGS84 origin or a documented centroid-derived
   display origin. Store the exact origin and ECEF-to-ENU rotation.
4. Never infer ECEF silently from coordinate magnitude. Legacy import may
   suggest ECEF, but requires explicit confirmation or loader options.
5. Preserve world points and covariance unchanged. Transform only the viewer
   payload; rotate covariance/glyphs into the selected display frame.
6. Migrate catalog/run schemas compatibly. Current version-one exports without
   frame metadata must load with `unknown` presentation until an explicit
   override supplies `ecef` or another frame.

### Viewer semantics

1. Default an ECEF product to local ENU display once the frame is confirmed.
   Label axes `East (m)`, `North (m)`, and `Up (m)` and render after subtracting
   the local origin to preserve graphics precision.
2. Offer explicit display choices: local ENU, origin-relative world XYZ, and
   authoritative world/ECEF diagnostic coordinates. Raw ECEF is not the
   default review view.
3. Replace the ambiguous `elevation` color mode:

   - `localUp` is local tangent-plane Up relative to the chosen origin;
   - `HAE` is ellipsoidal height computed through the declared WGS84 transform;
   - `worldZ` is available only as an explicitly named coordinate diagnostic;
     and
   - MSL/orthometric height is unavailable unless a declared geoid/datum
     transform exists.

4. Use equal metric data aspect ratio by default. Add explicit vertical
   exaggeration as a presentation-only setting with visible `1x`, `2x`, etc.
5. Show the active authoritative and display frames, origin, vertical reference,
   and exaggeration in the viewer status and exported metadata.

### Acceptance

- ECEF fixture axes align with known East/North/Up to numerical tolerance.
- Local-to-world round trip is within the declared double-precision tolerance.
- Local origin shifting does not change distances, residuals, links, product
  IDs, world covariance, or exported authoritative values.
- Covariance glyphs rotate consistently with points.
- `localUp`, HAE, and world-Z values remain distinct and correctly labeled.
- Large ECEF offsets do not degrade local camera/selection behavior.
- A version-one saved run loads only with an explicit legacy-frame decision and
  never silently calls world Z height.

## SR-3 — Normal 3-D Interaction And Saved-Run Inspector

Status: depends on the SR-2 display-frame contract.

### Interaction contract

1. Configure normal MATLAB axes interactions explicitly: rotate, pan, zoom,
   restore view, and data tips. Make rotate the default direct-manipulation mode
   for a 3-D product.
2. Do not let product-wide `ButtonDownFcn` handlers consume rotation gestures.
   Move source-observation selection to a visible **Inspect point** mode,
   modifier-click, or data-tip selection that coexists with rotation.
3. Expose toolbar buttons and concise pointer guidance. Mouse drag shall orbit,
   scroll shall zoom, and the standard pan interaction shall work without
   custom camera algebra unless a tested UIAxes limitation requires it.
4. Preserve camera pose while changing color mode, decimation, or compatible
   product representation. Reset camera only for **Reset view** or an
   incompatible display-frame change.
5. Provide standard useful viewpoints: isometric, top/Up, East profile, North
   profile, and fit. Keep metric aspect and optional vertical exaggeration.
6. Ensure mesh, grid, point-cloud, voxel, comparison, and uncertainty graphics
   all remain rotatable and selectable under the same interaction model.

### Saved-run load and inspection

1. Add a validated loader, for example `ProjectionSurfaceRun.load(path,
   options)`, that accepts the current `surfaceWorkbenchRun` MAT variable,
   future versioned runs, a standalone catalog, or a standalone point set where
   a catalog can be constructed without losing evidence.
2. Add **Open saved run...** to a standalone Surface Workbench/3-D viewer entry
   point. It must not require an open main viewer, source imagery, geometry
   callbacks, or Python/GPU dependencies.
3. Inventory available products after load and expose only products whose
   status is `available`; unavailable mesh/grid placeholders remain truthful.
4. Preserve access to raw pairwise points, robust multi-view points, fusion
   products, voxel evidence, mesh vertices/faces, grid arrays/masks, source
   observation links, uncertainty, pair states, diagnostics, and provenance.
5. Allow a legacy coordinate-frame override without modifying the saved file.
   A separately exported upgraded copy may record the operator-confirmed frame.
6. Reject malformed/runtime graphics values and give a precise schema/missing-
   field error. Never execute callbacks or class names from a MAT file.
7. Add concise documentation for both the supported app flow and direct MATLAB
   access to the underlying structs.

### Immediate legacy inspection recipe

Until the loader is implemented, a current successful export can be reopened
without rerunning matching:

```matlab
addpath("src")
loaded = load("surface-run.mat", "surfaceWorkbenchRun");
run = loaded.surfaceWorkbenchRun;

surfaceApp = ProjectionSurfaceWorkbenchApp(run.Catalog);
surfaceViewer = surfaceApp.openViewer();

available = run.Catalog.Products( ...
    string({run.Catalog.Products.Status}) == "available");
table(string({available.ProductId}).', ...
    string({available.Representation}).', ...
    [available.FullElementCount].', ...
    VariableNames=["ProductId" "Representation" "ElementCount"])
```

Keep `surfaceApp` in the workspace while using the viewer. This recipe opens
the current raw-world presentation; it does not yet correct ECEF height or
interaction behavior.

### Acceptance

- A user can rotate every representation immediately after opening it and can
  still inspect a selected point and its full-source links.
- Product/color/decimation changes do not unexpectedly reset an intentional
  camera view.
- The exact current exported MAT schema opens headlessly and interactively.
- A loaded run can display every available representation and directly expose
  its mesh/grid/point arrays without source data.
- Close/reopen of the 3-D child preserves the Workbench catalog and selections.

## SR-4 — Transactional Tiled/Anaglyph Surface Ownership

Status: depends on the SR-0 orphan fixture.

### Ownership model

1. Give every renderer-owned image surface immutable runtime metadata:

   - viewer owner token;
   - stable view ID and current layer index;
   - tile key or untiled key;
   - geometry, camera, presentation, and appearance generation IDs;
   - ownership state `preparing`, `active`, or `pooled`; and
   - anaglyph channel assignment generation.

2. Centralize registration and deletion. Every tagged image surface under the
   axes must be present exactly once in one active per-layer set or the hidden
   pool. No surface may be both, and no renderer-owned child may be unregistered.
3. Make tiled replacement transactional:

   - prepare incoming handles hidden;
   - attach complete metadata and populate them;
   - verify request generation and target keys;
   - atomically publish the complete new set;
   - apply the current effective visibility and anaglyph appearance; and
   - only then retire or delete the old set.

4. Use `onCleanup` rollback for every uncommitted acquired/created handle. A
   preparation exception, cancellation, stale request, or app close must return
   or delete all temporary handles.
5. A stale camera/LOD/presentation completion shall fail its generation check
   before publication. It may not replace or append to a newer Pair View.
6. When a pooled handle is acquired, overwrite all owner/layer/key/generation,
   texture, alpha, geometry, channel, context-menu, visibility, hit-test, and
   callback state before it can become visible.
7. Apply one exact presentation commit after each Pair View transition: only
   the current consecutive pair may be visible; each physical view has one
   channel assignment; all inactive active-set handles and every pool handle
   are hidden.

### Invariants and diagnostics

Add a runtime graphics audit that compares the registry with tagged axes
children and reports:

- active, preparing, pooled, and tagged-child counts;
- orphan tagged-child count;
- duplicate owner/view/tile/generation keys;
- visible inactive-layer handles;
- visible pooled/preparing handles;
- missing expected current-pair tiles;
- multiple active channel assignments for one physical view;
- active surfaces whose appearance generation is stale; and
- the exact effective layer mask and current stable pair.

Production transitions should repair safe visibility drift immediately and
fail closed on ownership corruption. Tests shall assert the invariants directly,
not only the logical mask or `app.Surfaces` contents.

### Acceptance

- Five tiled layers can traverse `1/2`, `2/3`, `3/4`, `4/5`, reverse, and loop
  repeatedly with exactly two visible physical views and no tagged orphans.
- Zoom/LOD replacement, camera tracking, rapid stepping, visibility changes,
  View All/Single/Pair changes, alpha, layer reorder, and anaglyph setting
  changes preserve the same invariant.
- Injected failure at every prepare/commit boundary leaves the previous complete
  frame visible or a clean recoverable empty state; it never leaves a partial
  new frame or escaped handle.
- Red/cyan assignment follows physical-eye identity with no duplicate copy of a
  view carrying the opposite channel.
- Surface-pool count stays within its bound and every pooled object is hidden.

## SR-5 — Presentation-Only Rebuild Viewport Recovery

Status: depends on SR-4 ownership metadata and audit.

### Operator contract

1. Add **Rebuild viewport** to the image context menu and Layer Manager. It is
   available whenever the main viewer is open and is distinct from Reset.
2. Add a tooltip/status explanation: “Clear and recreate display graphics;
   preserve scene, corrections, alignment, layers, pair, and camera.”
3. Rename or clarify the existing Reset action as **Reset scene and
   corrections...** so it cannot be mistaken for graphics repair. Preserve its
   established scientific behavior and add confirmation if none exists.
4. Rebuild requires no confirmation because it is presentation-only. It shall
   publish start/completion status and an audit summary.

### Rebuild transaction

1. Snapshot presentation-only values needed to restore the same view: camera,
   selected layer, stored visibility/order, active View All/Single/Pair mode,
   sequence position and current pair, playback preference, anaglyph settings
   and eye overrides, active-outline setting, and stereo cursor definition.
2. Pause playback, cancel camera reconciliation and pending tile requests, and
   advance a renderer generation so late completions cannot publish.
3. Delete all registered active/preparing/pool image surfaces.
4. Sweep every renderer image-surface tag owned by this axes, including legacy
   tagged surfaces without new metadata. Do not use broad `cla` and do not
   delete alignment overlays, stereo cursor, crosshair, selected outline, or
   unrelated caller-owned graphics.
5. Clear active handle arrays, pool, applied tile keys/levels, pending LOD, and
   appearance generations. Retain immutable pyramids/prepared data caches only
   if their generation keys are still valid; otherwise clear them explicitly.
6. Recreate one coherent surface set from current scene/layer state, apply the
   exact effective presentation mask and physical-eye channel assignment, then
   restore camera and overlays.
7. Run the graphics ownership audit. On failure, keep all image surfaces hidden,
   report a precise recovery error, and leave scientific state untouched.
8. Leave playback paused with a visible reason; the operator may resume after
   confirming the repaired frame.

### Preservation acceptance

Compare before/after bitwise or exact value equality where applicable for:

- scene layers, source geometry, projection planes, images, and backend state;
- OPK/projection offsets and immutable correction history/lineage;
- raw/filtered/selected matches, solve result, actionability, previews, and
  Alignment Workbench control state;
- Surface Workbench run/catalog and saved export values;
- stable IDs, layer order, stored visibility, active pair/mode/position;
- camera pose, anaglyph parameters/eye overrides, outline preference, and
  stereo cursor world definition; and
- serialized viewer state.

The only permitted changes are runtime graphics handles, render generations,
cache/pool state, performance/recovery diagnostics, and playback changing from
playing to paused.

### Recovery acceptance

- A fixture containing visible orphan, duplicate, pooled-visible, stale-channel,
  and missing-active surfaces is repaired to the exact current pair with zero
  audit violations.
- Rebuild works from View All, Single View, and every Pair View position and
  survives immediate zoom/LOD replacement.
- Rebuild is idempotent; a second invocation produces the same registered
  topology and no scientific changes.
- The operator never needs to close the main viewer to recover from graphics
  corruption.

## SR-6 — Integrated Validation And Delivery

Status: blocked by SR-1 through SR-5.

### Integrated scenario

Run one privacy-safe five-view scenario and one representative private manual
scenario in this order:

1. open the main viewer and Alignment Workbench;
2. produce accepted pair evidence;
3. open Surface Workbench with all quality pairs;
4. run GPU SGM where available with 250 observations per pair;
5. observe association substage progress and cancellation once, then complete;
6. export the complete MAT result;
7. inspect point-cloud, voxel, mesh, and grid products that are actually
   available in local ENU with normal rotation;
8. close and reopen the 3-D viewer without losing the catalog;
9. close the Surface and Alignment Workbenches as the operator did;
10. enter tiled red/cyan Pair View and traverse all adjacent pairs forward,
    backward, with zoom/LOD changes and loop;
11. inject or synthesize graphics corruption and invoke Rebuild viewport; and
12. prove corrections, matches, camera, layer state, active pair, and saved
    values remain unchanged.

### Required automated coverage

- association parity, scaling work counts, progress, cancellation, partial
  evidence, and deterministic identities;
- ECEF/local-ENU round trip, HAE versus local-Up versus world-Z labeling,
  covariance rotation, and large-origin precision;
- current and future MAT schema loading plus malformed/untrusted-value
  rejection;
- rotate/pan/zoom/inspect interactions for point, voxel, mesh, grid, and
  comparison products;
- transactional surface prepare/commit/rollback and stale-generation rejection;
- five-layer Pair View forward/reverse/loop/zoom/reorder/visibility/anaglyph
  ownership invariants; and
- Rebuild viewport corruption recovery, idempotence, and complete scientific
  state preservation.

### Validation discipline

1. Run pure association/frame/catalog tests before UI tests.
2. Use deterministic fault injection for renderer transaction boundaries.
3. Run the smallest named UI methods while debugging and one grouped UI pass
   after stabilization.
4. Run Code Analyzer on every changed MATLAB source and test file.
5. Run all six authoritative groups in separate fresh MATLAB sessions in the
   order defined by `docs/test_suite_grouping.md`:

   1. `coreGeometryState`
   2. `alignment`
   3. `backendSurface`
   4. `viewerAlignmentUi`
   5. `viewerPresentationWorkflows`
   6. `viewerPerformancePrecision`

6. Record exact totals, failures, incomplete counts, association benchmark
   hardware/times, and representative-real-data outcomes.
7. Commit no private MAT file, screenshot, coordinates, dimensions, or path.

### Release gate

Do not mark this workstream complete until:

- 250-per-pair all-quality association is comfortably interactive and 5,000
  has a truthful bounded policy;
- the template failure is resolved or retained as a separately explained open
  blocker;
- ECEF products default to a correctly labeled local review frame;
- standard rotation and saved-run reopening work for every available product;
- Pair View cannot accumulate stale/duplicate red/cyan surfaces under the
  transition matrix; and
- Rebuild viewport recovers injected corruption without changing scientific or
  session state.

## Likely Code And Test Touchpoints

```text
src/ProjectionDenseObservationAssociator.m
src/ProjectionMultiRayReconstructor.m
src/ProjectionSurfaceWorkbenchRunner.m
src/ProjectionSurfaceWorkbenchApp.m
src/ProjectionSurfaceWorkbenchModel.m
src/ProjectionSurfaceProductCatalog.m
src/ProjectionSurface3DViewer.m
src/ProjectionViewerApp.m
src/ProjectionDemGrid.m
src/ProjectionViewerState.m
tests/ProjectionDenseMultiRayReconstructionTest.m
tests/ProjectionSurfaceWorkbenchRunnerTest.m
tests/ProjectionSurfaceWorkbenchModelTest.m
tests/ProjectionSurfaceWorkbenchWorkflowTest.m
tests/ProjectionViewerMotionWorkflowTest.m
tests/ProjectionViewerAppInteractionTest.m
tests/ProjectionViewerPerformanceTest.m
```

Prefer adding small graphics-free helpers for disjoint-set association,
coordinate-frame transformation, saved-run loading, and renderer ownership
auditing rather than expanding already large app classes with untestable nested
logic.

## Delivery Boundaries

Use three coherent implementation milestones if this plan is approved:

1. **SR-0/SR-1:** failure evidence, association rewrite, progress,
   cancellation, scaling benchmarks, and partial-run retention.
2. **SR-2/SR-3:** portable coordinate/display frame, ECEF/local-ENU/height
   semantics, saved-run loader, and normal 3-D interaction.
3. **SR-4/SR-5/SR-6:** transactional renderer ownership, Pair View/anaglyph
   correction, Rebuild viewport, operator docs, and integrated validation.

Each milestone must be independently reviewable, pass all affected focused
tests, and pass the complete six-group suite on its exact pre-commit tree.
