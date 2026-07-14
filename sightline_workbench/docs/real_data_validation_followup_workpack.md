# Real-Data Validation Follow-Up Workpack

Status: active planning and operator-feedback intake. No implementation pack in
this document has started. This workpack is the highest-priority implementation
queue once the pending July 13, 2026 operator findings are incorporated. It
temporarily precedes independent D2 native CPU work and all hardware-gated GPU
work.

## Purpose

This workpack converts real-data regressions, scalability findings, and
operator-workflow deficiencies into small, testable implementation packs
without weakening the established scientific contracts. The July 13, 2026
five-image evaluation is now incorporated. It identified:

1. an interactive global-alignment solve whose diagnostic and residual-
   evaluation costs scale poorly for five-image, high-match-count networks;
2. stale or invalid preview LOD state when the active motion frame changes;
3. an initial-camera orientation regression for explicit oblique planes;
4. incomplete viewer-child lifecycle ownership;
5. unnecessary launcher chrome and an underpowered motion/layer workflow;
6. an opaque selected-pair dense-surface action whose result was unusable on
   the evaluated real imagery; and
7. the need for a world-space stereo cursor.

The findings are ordered below. Do not begin a decision-gated behavior until
its explicit open decision is resolved.

## Authority And Constraints

The project-wide SRS and consolidated multi-image workplan remain authoritative.
This workpack adds focused corrective implementation; it does not reopen
completed feature trees except where a regression is demonstrated.

- Keep the existing `PlanarProjection` and `Projection*` public names and
  compatibility behavior.
- Keep the complete, tested CPU path.
- GPU execution remains optional and capability-checked.
- If MATLAB parallelism is used, use only `parpool("threads")`; never create a
  process-based pool.
- Backend radiometry continues to use full source imagery and the configured
  output grid. Viewer previews, alignment working images, and dense products
  never become backend radiometric inputs.
- Camera presentation fixes must not mutate the physical projection plane,
  source rays, corrections, output grid, or serialized scientific state.
- Optimization changes must preserve residual definitions, correction signs,
  robust weighting, gauge policy, safety gates, provenance, and deterministic
  CPU results within an explicitly tested tolerance.
- Graphics handles, optimizers, callbacks, sampled-ray caches, and progress
  state remain runtime-only.
- Use MATLAB MCP for MATLAB execution and issue each logical test group in a
  separate fresh-class call. Do not launch MATLAB from the shell.
- Preserve unrelated work and private real-data values. Commit no private
  imagery, geometry, paths, or measurements that identify a protected source.

## Ordered Queue

### RD-0 — July 13 Operator Findings And Execution Order

Status: intake and presentation decisions complete; implementation ready.

The implementation order is deliberately independent of the historical pack
numbers retained below:

| Order | Pack | Finding | Reason for position |
|---:|---|---|---|
| 1 | RD-2 | Bounded, observable multi-image network solve | The present solve can occupy one core for tens of minutes without useful progress and blocks the main alignment workflow. |
| 2 | RD-3 | Frame-change LOD correctness and child-window lifecycle | These are viewer correctness and recovery defects with bounded ownership. |
| 3 | RD-1 | Explicit-plane initial-camera orientation | The external sign experiment is promising, but the fix must be derived from a declared screen/plane convention. |
| 4 | RD-4 | Layer Manager and main-viewer shell | This depends on the corrected frame-change and child-window lifecycle contracts. |
| 5 | RD-5 | Dense-surface controls, evidence, and quality recovery | The current entry point is too opaque to diagnose scientifically; expose evidence before changing algorithms. |
| 6 | RD-6 | World-space stereo cursor | The confirmed world-space interaction is bounded and follows the viewer-shell work. |

All six packs are top-priority corrective work relative to independent D2 native
CPU work and hardware-gated GPU work. Complete, validate, commit, and push each
coherent pack separately. A later pack may be split further when its tests or
review surface would otherwise be too broad.

#### Resolved presentation decisions

1. The stereo cursor is the physical world-space point defined in RD-6. Only
   while it is enabled, `Shift+mouse-wheel` adjusts cursor Z; Tip remains
   available through `Shift+Up/Down`. When it is disabled, the established
   modifier-wheel behavior is unchanged.
2. Pair navigation changes the active pair; it does not define eye assignment.
   After every transition, the established physical-eye resolver assigns the
   new physical left image to red/left and the new physical right image to
   cyan/right, independent of temporal order, layer order, and
   reference/moving role. There is no temporal eye override.
3. Per-layer `Visible` remains ordinary persistent viewer/scene state. View All
   displays exactly the layers marked visible and provides **All visible** and
   **None visible** bulk actions. Single View and Pair View apply runtime-only
   presentation masks without rewriting those stored flags; returning to View
   All restores the stored visible set. The presentation mode itself is
   runtime-only and opens in View All by default.

### RD-1 — Explicit-Plane Initial Camera Orientation

Status: confirmed real-data regression; implementation not started.

#### Observed evidence

After the large multi-image workstream, two-image and five-image real datasets
launched with imagery appearing vertically inverted or projected as though
viewed from the wrong side. In an external disposable copy, negating the
`desiredUp` value in `ProjectionViewerHarness.createRealDataFrameCamera`
produced the expected orientation across several datasets. That experiment is
strong localization evidence, not yet an accepted fix.

The current implementation projects `projectionPlane.VN` into the camera image
plane and uses the result as `desiredUp`. Existing tests did not distinguish
that sign from a 180-degree display inversion for the user's explicit-plane
convention. This conflicts with SRS requirement `FR-VIEW-022` and with the
documented claim that an explicit oblique plane launches naturally upright.

#### Required implementation

1. Freeze the presentation convention for a caller-supplied plane derived from
   four ground corners supplied anticlockwise from lower left, including image
   row direction, plane basis, plane normal, camera look direction, and screen
   up/right handedness.
2. Reproduce the current sign failure with a deterministic non-private fixture
   before changing the formula.
3. Select the up-vector sign from that convention. Do not accept a bare sign
   flip without corner-orientation and handedness evidence.
4. Keep caller-supplied camera poses authoritative and unchanged.
5. Check the initial viewer camera, pair viewpoint, Restore viewpoint, physical
   left/right eye assignment, camera twist, and motion-imagery entry/exit for a
   shared sign convention.
6. Keep the change presentation-only. Assert that the projection plane,
   `SampleFcn`/`SampleRayFcn`, source coordinates, OPK corrections, backend
   output, and saved scene state are unchanged.
7. Update operator documentation and remove the active-regression notice only
   after the user confirms representative real datasets.

#### Focused acceptance

- Explicit oblique planes at several azimuths and off-nadir angles display the
  known lower-left, upper-left, lower-right, and upper-right markers in the
  declared screen orientation.
- Equivalent valid plane definitions do not change image handedness.
- The camera remains on the intended viewing side and looks toward the plane;
  positive source ranges remain forward-valid where applicable.
- A caller-supplied camera pose is not reoriented.
- Pair viewpoint and Restore preserve the corrected upright convention.
- Eye assignment remains physical and independent of moving/reference role.
- Backend and procedural-anaglyph numerical outputs are bitwise unchanged when
  only the implicit initial presentation camera is corrected.
- The existing viewer, presentation, precision, and procedural parity suites
  remain green.

### RD-2 — Bounded, Observable Multi-Image Network Solve

Status: complete July 14, 2026.

Completion evidence: the deterministic structural proxy retains five views,
ten nonsequential pairs, and 2,000 observations. The default interactive path
performs one global optimization, builds one immutable evidence bundle, samples
the 20 pair sides only during setup, and starts no sensitivity children. It
completed in 13.941 seconds in the fresh-class alignment test run; that elapsed
time is evidence, not a portable acceptance threshold. Compiled/reference
parity is asserted at `1e-9` for solved OPK and after residuals, `1e-12` for
before residuals, and `2e-4` relative for the condition-sensitive covariance
pseudoinverse. Robust weights and gauge decisions also agree.

The solver now reports bounded runtime-only work/timing and progress records,
uses compiled nominal origins/directions plus a supplied stable semi-analytic
Jacobian for the default constant-OPK coplanarity path, and reuses active-family
residuals and accepted linearizations for diagnostics. Direct sampling and
optimizer finite differences remain selectable reference oracles. A bounded
ten-pair/2,000-observation kernel benchmark on a 14-worker thread pool measured
0.029242 seconds serial and 2.852848 seconds with `parfor` (97.559x slower), so
thread batching is truthfully recorded as evaluated and disabled at this
workload. CPU serial remains the default.

#### Observed evidence

One five-image real-data workflow used visible-layer scope, robust coplanarity
prefiltering, and all-plausible pair coverage. It retained approximately 2,100
of 2,200 raw matches. `Solve` then ran for more than 30 minutes without a useful
status update while one CPU core remained saturated.

Static inspection identifies several multiplicative costs:

- `ProjectionAlignmentOptions` enables
  `Network.ComputeLeaveOnePairOut=true` by default.
- After the primary solve, network diagnostics perform one complete child solve
  for every retained pair. An all-plausible five-view graph may therefore run
  the primary solve plus as many as ten leave-one-pair-out solves.
- `lsqnonlin` uses numerical finite differences because the solver supplies no
  Jacobian. Each parameter perturbation reevaluates all retained observations.
- Each residual evaluation resamples observation origins and rays even though
  their nominal samples are parameter-independent and only their corrected
  directions change during the constant-OPK solve.
- Start/solution observability uses another central finite-difference Jacobian,
  and comparison diagnostics reevaluate all three residual families.
- The cancellation callback is connected to optimizer iteration output, but
  the operator receives no sufficiently granular stage, iteration, child-solve,
  elapsed-time, or remaining-work feedback.

Single-core use by `lsqnonlin` is not itself a correctness failure. The first
priority is eliminating unnecessary work and bounding optional diagnostics,
not adding parallelism around an inefficient evaluation path.

The operator has authorized all six optimizations identified during inspection.
RD-2A measurement is a prerequisite and is not counted as one of the six:

1. bound or defer leave-one-pair-out child solves and return the primary result
   first;
2. precompile and cache invariant observation evidence;
3. supply an analytic or stable semi-analytic Jacobian for the constant-OPK
   residual path;
4. reuse accepted Jacobians, normal-equation products, and residual-family
   evaluations instead of repeating equivalent observability, covariance, and
   comparison work;
5. provide bounded-cadence stage/iteration/child progress and responsive
   cancellation; and
6. only after the optimized serial path is measured, add bounded pair/residual
   batching on `parpool("threads")` where it provides a demonstrated benefit.

The sixth item is required as an evaluated pack, not a promise to enable
parallel execution unconditionally. Its green outcome may be a measured serial
default with a documented thread-pool threshold when overhead dominates.

#### RD-2A — Reproduction, timing, and work accounting

1. Add a deterministic five-view proxy with multiple nonsequential pairs and a
   configurable match count near the observed scale without committing private
   data.
2. Time and count primary optimization, residual evaluations, ray/origin
   sampling, observability, comparison diagnostics, covariance, and each
   leave-one-pair-out child.
3. Record view, pair, track, observation, active-parameter, optimizer-iteration,
   function-evaluation, and child-solve counts.
4. Keep performance instrumentation bounded and runtime-only. Do not make a
   development-machine wall-clock value a scientific acceptance threshold.

#### RD-2B — Interactive diagnostic-cost policy

1. Return and present the primary solve before running optional sensitivity
   diagnostics.
2. Disable exhaustive leave-one-pair-out by default for an ordinary interactive
   solve, or move it behind an explicit operator action/Quality policy. Preserve
   an explicit way to request all retained pairs.
3. Add deterministic maximum-child and/or time-budget controls with clear
   `notRequested`, `deferred`, `partial`, `complete`, `cancelled`, and `failed`
   states. Never label omitted sensitivity evidence as complete.
4. Reuse the baseline solution as a child initial estimate when mathematically
   valid and preserve exact child gauge/prior handling.
5. Cancellation must stop the active child and prevent new child solves.

Structural acceptance: the default five-view interactive path performs one
global optimization, not `1 + pairCount`, while an explicit exhaustive request
retains deterministic leave-one-pair-out results.

#### RD-2C — Precompiled constant-OPK observation evidence

1. Compile validated nominal origins, unit directions, stable observation IDs,
   pair/track indices, baseline-normalization terms, and parameter lookup tables
   once before optimization.
2. Apply candidate OPK rotations to cached nominal directions in vectorized
   batches. Do not call `SampleRayFcn`, rebuild meshes, or interpolate sparse
   geometry once per residual evaluation.
3. Preserve function-backed geometry revision/fingerprint checks so a cache can
   never survive a geometry generation change.
4. Reuse compiled evidence for before/after, comparison, observability, and
   covariance work when the residual contract permits it.
5. Keep a direct uncached reference path for parity tests and diagnostics.

Structural acceptance: observation sampling count is bounded by solve setup,
not optimizer iteration or finite-difference evaluation count. Cached and
reference residuals, solutions, safety decisions, and diagnostics agree within
declared double-precision tolerances.

#### RD-2D — Derivative, reuse, and linear-algebra optimization

Begin only after RD-2A through RD-2C are measured.

1. Derive analytic or stable semi-analytic Jacobians for the default
   epipolar-coplanarity residual and constant-OPK parameterization, including
   robust-weight and pass-common/differential transforms.
2. Reuse the accepted data Jacobian for observability and covariance where its
   weighting semantics match; do not recompute an equivalent central-
   difference matrix at both start and solution without evidence.
3. Reuse residual-family evaluations, normal-equation products, factorizations,
   and comparison evidence wherever the mathematical weighting and gauge
   contracts match. Record why a recomputation is required when they do not.
4. Expose Jacobian method and fallback in provenance. Retain numerical finite
   differences as a comparison oracle.
5. Measure matrix sparsity and problem size before selecting sparse storage,
   BLAS, or another provider.
6. Evaluate bounded pair/residual batching on `parpool("threads")` after the
   optimized serial CPU path is green. Enable it only above a measured workload
   threshold and only when it improves elapsed time without changing results.
   Do not enable nested or process-based parallelism.

#### RD-2E — Progress, cancellation, and operator recovery

1. Report current stage, primary iteration/function count, elapsed time,
   requested/completed diagnostic children, and cancellation state through a
   runtime callback.
2. Update the Alignment Workbench at a bounded cadence without serializing the
   callback or creating queued-event lag.
3. Keep Cancel responsive during primary optimization and optional diagnostics.
4. On cancellation or diagnostic failure, preserve the last authoritative
   session/scene state and distinguish no solution from a valid primary solution
   with incomplete optional diagnostics.
5. Document recommended Fast/Balanced/Quality diagnostic policies after the
   measured proxy and user data are reviewed.

#### RD-2 acceptance

- The approximately five-view/2,000-observation structural proxy completes the
  default primary solve with bounded optional work and visible progress.
- Constant-OPK corrections, residuals, robust weights, gauge classification,
  covariance, and safe-apply outcome match the reference path within explicit
  tolerance.
- Two-image selected-pair compatibility behavior is unchanged.
- Fast/Balanced/Quality and explicit exhaustive diagnostics state exactly what
  was executed and retained.
- Cancellation is deterministic and leaves scene/correction state unchanged
  unless the operator separately accepts and applies a completed primary result.
- CPU-only execution remains complete. Optional GPU availability does not
  affect this workflow.

Acceptance is complete. Fast requests no sensitivity work, Balanced returns
the primary result with sensitivity deferred, and Quality permits at most
three children within a 15-second diagnostic budget. SDK callers may explicitly
request exhaustive deterministic leave-one-pair-out evidence. Partial,
cancelled, failed, deferred, and complete diagnostic states are distinct, and
child solves warm-start from the authoritative primary solution without
changing their gauge or priors.

### RD-3 — Frame-Change LOD Correctness And Child-Window Lifecycle

Status: confirmed correctness defects; implementation not started.

#### RD-3A — Active-frame LOD reconciliation

Observed behavior is intermittent but structurally explained: after zooming,
advancing the motion frame can show a blocky stale LOD. A subsequent zoom can
make the layer disappear until it self-recovers or the operator toggles
visibility. The current frame-change path refreshes a tiled layer only when it
has no valid surface; it does not require its desired LOD to match the current
camera before presenting an already-cached frame.

Required implementation:

1. On every active-frame or active-pair change, recompute desired preview LOD
   from the current camera, viewport, and layer generation before presentation.
2. Reconcile current, desired, and pending tiled surfaces even when a valid but
   stale surface already exists. A visibility toggle must never be a recovery
   mechanism.
3. Key lookahead work by layer generation and camera/LOD request so an old
   completion cannot replace a newer request.
4. Keep the last valid representation visible until its replacement is ready,
   then swap coherently. Never produce a transient empty layer solely because a
   refinement was requested.
5. Bound adjacent-frame lookahead and cache churn during rapid stepping and
   playback. Repeated Left/Right events may coalesce obsolete work.
6. Apply the same contract to Single View, Pair View, playback, loop boundaries,
   visibility transitions, and ordinary layer selection.
7. Keep full-resolution source imagery and backend radiometric paths untouched.

Focused acceptance includes zoomed-in and zoomed-out frame changes, repeated
forward/reverse stepping, pair turnover, playback, loop boundaries, visibility
changes, and a deliberately delayed stale preview completion. The displayed
layer may briefly retain its prior valid LOD but shall converge without another
camera event and shall not disappear.

#### RD-3B — Main-viewer close ownership

Closing the main viewer shall route through one idempotent close path that stops
timers/callbacks and closes every viewer-owned child base: Alignment Workbench,
Layer Manager, help, dense-surface result windows, and any Surface Workbench or
3-D viewer opened as its child. Closing a child independently shall unregister
it without closing the parent. Deleting an already-closed figure or app shall
be harmless. The viewer shall not close independent caller-owned figures.

Acceptance shall cover window close-button use, programmatic app deletion,
child-first closure, parent-first closure, in-flight playback/preview work, and
repeated cleanup. No timer, callback, graphics handle, or runtime cache may
survive the owning viewer.

### RD-4 — Layer Manager And Main-Viewer Shell

Status: approved direction and behavior; implementation not started.

#### RD-4A — Remove the redundant alignment launcher bar

Remove the hidden main-viewer Alignment bar and its enable/disable interaction.
The viewport context-menu item shall be named `Alignment Workbench...` and
shall directly open or focus the one existing workbench. Status and progress
belong in that workbench, with only concise transient viewer notification when
needed. This changes launcher chrome, not alignment state or solver behavior.

#### RD-4B — Replace Motion Imagery with a default-open Layer Manager

Rename and expand the Motion Imagery child to `Layer Manager`. It opens by
default as a nonmodal viewer-owned child and becomes the primary home for layer
selection, ordering, per-layer visibility, playback, loop/rate controls, and
pair tracking. Moving controls shall preserve stable layer IDs and shall not
turn graphics handles or transient presentation state into scientific scene
data.

Expose three mutually exclusive presentation modes:

- **View All:** display every image layer whose stored `Visible` state is true.
  Provide **All visible** and **None visible** bulk actions in addition to each
  layer's visibility control. Draw a yellow outline around the actively selected
  visible layer's projected valid footprint above the complete image stack so
  selection remains obvious when that layer is not top-most. The outline is a
  runtime overlay, follows projection/offset/LOD/selection changes without
  forcing a radiometric rerender, clips cleanly at the viewport, and does not
  enter saved scientific state.
- **Single View:** temporarily show only the current sequence layer, regardless
  of its stored `Visible` flag; Left/Right selects the previous/next layer
  according to the deterministic motion schedule.
- **Pair View:** temporarily show the current scheduled pair only, regardless
  of stored `Visible` flags; Left/Right steps the overlapping pair so forward
  motion is `(i,i+1)` to `(i+1,i+2)` and reverse is the exact inverse.

Single/Pair masks never rewrite stored layer visibility. Returning to View All
restores the exact current stored visible set, including changes made with the
individual and bulk controls. The mode is runtime-only, is not part of saved
scientific state, and defaults to View All when the Layer Manager opens.

Pair View shall support a persistent `Track camera` control. It uses the
established pair-viewpoint geometry when enabled and updates once per accepted
pair transition, without accumulation or drift. Pair tracking moves out of the
Alignment Workbench; the workbench may reflect the active pair but shall not be
the owner of this presentation behavior.

When red/blue anaglyph presentation is enabled, pair stepping first changes the
active pair and then runs the established physical-eye resolver. The new
physical left image is red/left and the new physical right image is cyan/right.
There is no guarantee that the old right frame becomes the new left frame;
temporal order, layer order, and reference/moving roles never override physical
eye assignment.

Mode transitions, layer reorder, deleted/disabled layers, end-of-sequence
behavior, loop behavior, and scenes with fewer than two eligible layers must be
deterministic and explained in the UI. Keyboard ownership shall remain:

- normal/View All: Left/Right selects previous/next layer and Up/Down performs
  the existing layer nudge;
- Single View: Left/Right selects previous/next frame;
- Pair View: Left/Right selects previous/next overlapping pair;
- `Shift+arrows` retain Tip/Tilt adjustment in every presentation mode.

#### RD-4C — Compact main-viewer controls

Move layer dropdown/order/visibility controls off the main control bar and into
the Layer Manager. Reduce the remaining Tip/Tilt/Twist/Alpha slider bar to the
smallest usable vertical extent. Move the current OPK/view-vector readout into
a legible bottom-right viewport overlay that does not intercept ordinary image
interaction.

Evaluate hover reveal for the slider bar. It may ship only if pointer entry and
exit are reliable across supported MATLAB desktop platforms, keyboard access
and a discoverable pinned/always-visible fallback remain available, and rapid
pointer motion does not trigger rendering or layout churn. Otherwise retain a
compact explicit show/hide affordance rather than a fragile hover effect.

Acceptance covers default Layer Manager launch, one-instance focus behavior,
all three modes, keyboard and button parity, forward/reverse pair turnover,
track-camera stability, anaglyph assignment, layer reorder/removal, saved scene
compatibility, the top-most yellow selected-footprint overlay in View All, and
main-viewer rendering/interaction performance.

### RD-5 — Dense-Surface Controls, Evidence, And Quality Recovery

Status: confirmed unusable real-data result and deficient operator feedback;
implementation not started.

The Alignment Workbench `Dense surface` button currently invokes the selected-
pair `ProjectionDenseSurfaceExtractor` SGM path and then shows its result. It
does not silently merge all five images. The repository also contains the
newer Surface Workbench, matcher SDK, template matcher, pair/search planning,
multi-ray reconstruction, fusion, uncertainty, and 3-D viewing components.
However, the Surface Workbench is currently a programmatically constructed
inspector for an already-computed `ProjectionSurfaceProductCatalog`; the viewer
has no launch control for it and the workbench has no Run action that builds
the selected products from the active scene. Its apparent processing controls
currently configure model selection, estimates, and display only. The operator
did not miss a hidden multi-view execution control. This pack shall connect and
diagnose those existing capabilities rather than create a second competing
surface architecture.

#### RD-5A — Make the current operation explicit and inspectable

1. Relabel the one-click action so its selected-pair SGM scope is unambiguous,
   and add a distinct `Surface Workbench...` launch action that builds a
   scene-bound request/catalog with the active pair preselected. The Workbench
   shall expose an explicit Run/Cancel lifecycle for requested pairwise,
   multi-ray, and fusion stages rather than presenting inert processing choices.
2. Before execution, show selected views/pairs, matcher, rectification state,
   disparity/search bounds, resource estimate, CPU/GPU selection and fallback,
   and output stage.
3. During and after execution, show stage progress and counts for candidates,
   accepted disparities/correspondences, consistency and occlusion rejection,
   valid rays, reconstructed points, conditioning/ray-separation rejection,
   fusion input/output, and uncertainty availability.
4. Provide diagnostic views for rectified inputs, disparity/score/confidence,
   validity/occlusion masks, residuals, ray geometry, height distribution, and
   per-pair/method provenance. Distinguish empty, failed, rejected, and low-
   confidence outcomes.

#### RD-5B — Reproduce and localize the quality failure

Build a non-private structural reproduction using the synthetic truth fixture
and representative single-pair and five-view schedules. Audit, in order:

1. left/right and row/column conventions;
2. epipolar rectification and inverse mapping;
3. expected disparity direction and search interval;
4. scale, texture, radiometric/channel, and normalization assumptions;
5. consistency, uniqueness, occlusion, and invalid-region behavior;
6. image-to-ray coordinate mapping and intersection conditioning; and
7. multi-pair association, reconstruction, fusion, and outlier rejection.

Compare every stage to known truth and to a sparse-match/bootstrap prior. Do
not use display smoothing, aggressive hole filling, or forced DEM intersection
to disguise scientifically invalid geometry.

#### RD-5C — Expose method and multi-view policy

The Surface Workbench shall let the operator choose and configure:

- selected pair, planned subset, all plausible pairs, or an explicit schedule;
- SGM, dense template matching, or a registered custom matcher derived from the
  documented SDK base class;
- sparse/bootstrap priors, search-quality/speed policy, consistency and
  occlusion policy, and resource limits;
- pairwise-only inspection, multi-ray reconstruction, and supported fusion
  algorithms; and
- 2-D diagnostics, 3-D surface/point visualization, uncertainty, DEM comparison,
  and `.mat`/JSON export where implemented.

Defaults shall remain runnable without expert parameter entry, but no result
may omit method, pair, parameter, rejection, fallback, and generation
provenance. A poor result must be explainable from retained intermediate
evidence.

#### RD-5 acceptance

- The synthetic truth fixture reports disparity/correspondence, height/point,
  completeness, outlier, and uncertainty-calibration metrics per pair and after
  fusion.
- Selected-pair SGM, template matching, and one SDK test matcher are separately
  identifiable and reproducible.
- A five-image run states exactly which pair results were reconstructed and
  fused; selecting five visible images cannot be mistaken for a five-image
  algorithm when only one pair was processed.
- Empty, weak, ill-conditioned, cancelled, CPU fallback, and unsupported GPU
  cases are explicit and recoverable.
- User review of representative imagery remains the acceptance gate for calling
  the result practically useful.

### RD-6 — World-Space Stereo Cursor

Status: geometry and binding approved; implementation not started.

Add `Stereo cursor` to the viewport context menu with an explicit checked state.
The cursor represents one confirmed physical 3-D point, not an arbitrary screen
disparity:

1. At activation or repositioning, intersect the pointer's view ray with the
   projection plane to define a plane-local anchor `Pplane`.
2. Define the cursor point as `Pcursor = Pplane + z * VN`, where `VN` is the
   declared unit projection-plane normal and `z` is signed meters relative to
   the plane.
3. Project that same 3-D point independently through the two active source
   models and display the corresponding left/right cursor marks. Do not mutate
   camera geometry, OPK corrections, matches, or the plane.
4. Display `Z = ... m relative to plane` and the positive-normal convention in
   a compact overlay. Show invalid/behind-camera/out-of-footprint states instead
   of fabricating a correspondence.
5. While enabled, the proposed `Shift+mouse-wheel` binding adjusts Z with a
   bounded configurable step and fine/coarse modifiers; ordinary wheel zoom and
   `Shift+Up/Down` Tip remain available. When disabled, existing wheel bindings
   are unchanged.
6. Require an active valid pair, whether supplied by Pair View or the current
   Alignment Workbench selection. Stable layer IDs, not display indices, own the
   pair association.

Acceptance covers plane-zero coincidence, known positive/negative heights,
oblique planes, swapped temporal order, physical eye assignment, out-of-bounds
projection, active-pair turnover, zoom/pan/rotate, and enable/disable cleanup.
The cursor and overlay are runtime-only and never enter saved scientific state.

## Likely Code And Test Touchpoints

Inspect rather than assume the final edit set:

```text
src/ProjectionViewerHarness.m
src/ProjectionPairViewpoint.m
src/ProjectionViewerApp.m
src/ProjectionAlignmentOptions.m
src/ProjectionAlignmentNetworkSolver.m
src/ProjectionAlignmentOpkSolver.m
src/ProjectionAlignmentParameterModel.m
src/ProjectionDenseSurfaceExtractor.m
src/ProjectionSurfaceWorkbenchApp.m
src/ProjectionSurface3DViewer.m
tests/ProjectionViewerHarnessTest.m
tests/ProjectionPairViewpointTest.m
tests/ProjectionAlignmentNetworkSolverTest.m
tests/ProjectionAlignmentOpkSolverTest.m
tests/ProjectionViewerAlignmentWorkflowTest.m
tests/ProjectionViewerMotionWorkflowTest.m
tests/ProjectionViewerMotionPlaybackWorkflowTest.m
tests/ProjectionViewerAppInteractionTest.m
tests/ProjectionDenseSurfaceExtractorTest.m
tests/ProjectionSurfaceWorkbenchWorkflowTest.m
scripts/alignment_reliability_validation.m
```

Add a dedicated non-private network-solve performance/structure fixture if that
keeps timing evidence out of correctness tests.

## Validation And Delivery

For each independently coherent pack:

1. reproduce the failure or structural cost first;
2. add focused contract and regression tests;
3. run `checkcode` on changed MATLAB files;
4. run each of the six logical groups in a separate fresh-class MATLAB MCP
   call as documented in `docs/test_suite_grouping.md`;
5. update this workpack, `docs/project_status.md`, and directly affected
   operator/reference documentation;
6. commit and push the green pack with separate noninteractive Git commands;
7. confirm a clean worktree; and
8. continue in the recorded order until blocked.

Stop for user direction only when a finding requires a new scientific/public
contract, representative behavior contradicts the chosen orientation or solve
policy, required private reproduction information is unavailable, validation
fails in a way that needs judgment, or MATLAB MCP remains unavailable after
reasonable retry.

## Documentation-Only Reconciliation

The documentation audit that created this workpack also corrected stale test
totals, completed queues still described as active, resolved SRS gates, and an
obsolete statement that a `/private/tmp` planning copy was the editing master.
Those were state-record defects and do not require MATLAB source changes.
