# Real-Data Validation Follow-Up Workpack

Status: complete July 14, 2026. RD-2, RD-3, RD-1, RD-4, RD-5, RD-6, and RD-7
are complete in the recorded execution order. Independent D2 native CPU work
may resume; hardware-gated GPU work remains external. Post-RD-7 real-data
findings involving dense association scaling, ECEF 3-D presentation, saved-run
inspection, tiled anaglyph ownership, and in-place viewport recovery are
recorded separately in `docs/real_data_surface_stereo_recovery_workplan.md`.

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

A subsequent five-view operator pass exposed a second corrective set:

8. Single View, Pair View, and View All can diverge from the stored visibility
   state when tiled surfaces are replaced during zoom or LOD reconciliation;
9. Pair View does not consistently follow Layer Manager order, Loop defaults
   off, and the OPK readout can escape the usable viewport during resize;
10. first-run alignment overlays and active-stage status are unreliable, while
    closing and reopening the Alignment Workbench loses the operator's visible
    session even though the underlying session object survives;
11. Surface Workbench availability is incorrectly tied to one ordered active
    pair, and its viewer-launched default selects only that pair even though the
    runner supports multi-image association and robust multi-ray reconstruction;
12. bounded alignment working images are produced through unnecessarily large
    full-source reads and conversions rather than an analysis-safe source LOD;
13. the 512/768 working-image matches are treated as final measurements even
    though they should be coarse discovery seeds for full-source subpixel
    refinement;
14. coarse feature and filtered-observation counts are excessive for a
    constant-OPK network solve and are selected without a strong spatial-
    diversity or information-content contract; and
15. the 10 percent residual-improvement preference is incorrectly implemented
    as a hard failure, preventing review and application of valid incremental
    corrections near convergence.

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
  never become backend radiometric inputs. Alignment may share immutable,
  source-radiometric pyramid infrastructure with display, but it shall never
  consume normalized, tone-mapped, colorized, composited, or presentation-
  prepared display textures.
- Camera presentation fixes must not mutate the physical projection plane,
  source rays, corrections, output grid, or serialized scientific state.
- Optimization changes must preserve residual definitions, correction signs,
  robust weighting, gauge policy, hard scientific validity gates, provenance,
  and deterministic CPU results within an explicitly tested tolerance.
  Advisory utility thresholds shall not rewrite a converged scientific result
  as failed or masquerade as hard safety gates.
- Graphics handles, optimizers, callbacks, sampled-ray caches, and progress
  state remain runtime-only.
- Use MATLAB MCP for MATLAB execution and issue each logical test group in a
  separate fresh-class call. Do not launch MATLAB from the shell.
- Preserve unrelated work and private real-data values. Commit no private
  imagery, geometry, paths, or measurements that identify a protected source.
- Do not commit operator-specific source-image dimensions or infer them into a
  durable fixture. Use non-private structural scales and source-to-working
  sampling ratios instead.

## Ordered Queue

### RD-0 — July 13 Operator Findings And Execution Order

Status: complete; all six corrective packs are implemented and validated.

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

Those six packs were top-priority corrective work relative to independent D2
native CPU work and hardware-gated GPU work. RD-7 now owns that priority.
Complete, validate, commit, and push each coherent implementation slice while
retaining RD-7 as one integrated release gate. A slice may be split further
when its tests or review surface would otherwise be too broad.

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

Status: implementation complete July 14, 2026; representative real-data
confirmation remains pending.

Completion evidence: the presentation convention is now explicit. Four ground
corners are named `LL, LR, UR, UL` in anticlockwise order, with plane `+X`
from `LL` toward `LR`, plane `+Y` toward `UL`, and `VN = VX x VY`. Image rows
increase downward; monitor `+X` is right and monitor `+Y` is up. The camera
look vector `V` is positive from the camera toward the plane. Away from the
head-on degeneracy, monitor up is
`-sign(VN dot V) * (VN - (VN dot V) * V)`, monitor right is `V x up`, and the
stored positive focal-plane `X` axis is `up x V`. The sign factor makes the
presentation invariant to reversing an equivalent plane normal instead of
embedding a bare sign flip. A head-on view uses projected plane `+Y`, then
plane `+X`, as a deterministic fallback.

Only a frame camera that exactly matches the real-data harness's implicit
camera is reoriented, and only in app presentation state. Distinct
caller-supplied camera poses remain authoritative. Initial framing, Pair View
and Restore, twist, motion entry/exit, and physical-eye workflows share the
same screen-basis convention. Focused tests also prove that the scene struct,
plane, sampling handles and coordinates, OPK state, exported backend scene,
output grid, and backend pixels remain bitwise unchanged. The procedural
anaglyph oracle and all six fresh-class groups remain green. The validated
group counts are 143, 185, 237, 75, 69, and 34, totaling 743/743 with zero
failures or incomplete tests.

The active operator advisory is intentionally retained until representative
private real datasets confirm the repository convention.

#### Observed evidence

After the large multi-image workstream, two-image and five-image real datasets
launched with imagery appearing vertically inverted or projected as though
viewed from the wrong side. In an external disposable copy, negating the
`desiredUp` value in `ProjectionViewerHarness.createRealDataFrameCamera`
produced the expected orientation across several datasets. That experiment is
strong localization evidence, not yet an accepted fix.

The pre-fix implementation projected `projectionPlane.VN` into the camera image
plane and used the result as `desiredUp`. Existing tests did not distinguish
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

Status: complete.

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

Acceptance is complete. Active-frame reconciliation now runs for manual motion
steps in both directions, loop rollover, measured playback, Solo-pair turnover,
ordinary selection, and visibility restoration even when a valid tiled surface
already exists. It recomputes desired LOD from one current camera context,
retains the last valid representation through a coherent replacement, consumes
pending state, and leaves backend/full-source image paths unchanged. Playback
retains only one next-frame lookahead; its identity includes layer/geometry and
camera-schedule generations, camera/viewport context, desired/current/pending
LOD, and tile keys. A stale lookahead is synchronously replaced before the
frame becomes active, and stale delayed camera completions are dropped.

The main figure close callback and programmatic deletion now share one guarded,
idempotent shutdown. It clears main callbacks, stops and deletes camera,
identity, and playback timers, exits transient presentation modes, clears
runtime preview/alignment/dense state, and closes the currently viewer-owned
Alignment Workbench, Motion Imagery window, help dialog, and dense result
figures. Child close callbacks unregister/delete only that child, permitting a
fresh reopen. Independent caller-owned figures are not touched. Focused RD-3
acceptance passes 8/8 tests and the four complete affected classes pass 92/92,
including parent-first, child-first, repeated, and in-flight cleanup cases.

### RD-4 — Layer Manager And Main-Viewer Shell

Status: complete.

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

Implementation evidence: the redundant launcher was removed; the context menu
opens or focuses one Alignment Workbench directly; the default-open Layer
Manager owns layer order/visibility, sequence filtering, playback, and the
three runtime presentation modes. Single View accepts one eligible frame; Pair
View uses exactly reversible overlapping pairs and owns persistent absolute
pair-camera tracking. Runtime masks preserve serialized visibility, including
manager edits and bulk actions made while a presentation mask is active.
Physical-eye resolution runs after pair selection, and the selected visible
footprint is a clipped yellow runtime overlay raised above all image surfaces.
Layer selection and outline refresh do not rebuild geometry or textures. The
main viewer now has a two-row four-slider strip and a non-interactive
bottom-right OPK overlay. Hover reveal was not adopted because the existing
explicit compact strip is deterministic across desktop platforms.

Fresh-class acceptance passes `coreGeometryState` 143/143, `alignment`
185/185, `backendSurface` 237/237, `viewerAlignmentUi` 75/75,
`viewerPresentationWorkflows` 69/69, and `viewerPerformancePrecision` 34/34,
totaling 743/743 with zero failures or incomplete tests. MATLAB Code Analyzer
reports zero issues for every changed MATLAB source, test, and evaluation
script.

### RD-5 — Dense-Surface Controls, Evidence, And Quality Recovery

Status: implementation complete July 14, 2026; representative-imagery
usefulness review remains external.

Before RD-5, the Alignment Workbench `Dense surface` button invoked only the
selected-pair `ProjectionDenseSurfaceExtractor` SGM path and then showed its
result; it did not silently merge all five images. The repository already
contained the Surface Workbench, matcher SDK, template matcher, pair/search
planning, multi-ray reconstruction, fusion, uncertainty, and 3-D viewing
components. The Workbench was then only a programmatically constructed
inspector for an already-computed `ProjectionSurfaceProductCatalog`: the viewer
had no launch control, no Run action built selected products from the active
scene, and processing controls affected model selection, estimates, and
display only. The operator had not missed a hidden multi-view control. RD-5
connects and diagnoses those existing capabilities without creating a second
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

#### RD-5 implementation evidence

Post-pack shell consolidation retired the direct **Selected-pair SGM** action.
**Surface Workbench...** now opens or focuses the sole scene-bound dense and
3-D extraction workflow with the active stable pair selected. The
`ProjectionSurfaceWorkbenchRunner` binds the existing matcher, association,
multi-ray, fusion, uncertainty, catalog, and viewer components. The Workbench
now owns an explicit Run/Cancel lifecycle; catalog-only construction remains
available and disables Run rather than implying live processing.

Preflight records the exact views and pair IDs, schedule, matcher/options,
rectification/search state, consistency and occlusion policy, CPU/GPU request
and fallback, observation cap, requested reconstruction/fusion stage, and
bounded resource estimate. Completed runs preserve per-pair matcher states,
accepted correspondence counts, association/reconstruction/fusion counts,
conditioning and uncertainty state, execution fallback, and complete
pair/method/options provenance. Empty, weak/partial, ill-conditioned,
cancelled, unsupported GPU/custom-matcher, and CPU-fallback outcomes remain
explicit.

The evidence window displays retained pair inputs, validity/overlap masks,
disparity diagnostics, matcher score/confidence, ray-separation, and height
distributions. MAT export retains complete intermediate evidence; compact JSON
retains metadata, counts, states, policies, and provenance without image-sized
arrays. The initial sparse-bootstrap catalog is intentionally permissive only
so weak scenes remain diagnosable; actual Run uses the selected scientific
gates. The path performs no display smoothing, hole filling, or forced DEM
intersection.

Non-private acceptance combines the existing dense truth/uncertainty/fusion
audits with a deterministic five-image runner fixture. The fixture schedules
and names all ten physical pairs, reconstructs stable observations with five
independent views, and records the exact fusion inputs/output. Separate tests
identify SGM, classical template matching, and a registered SDK matcher and
cover explicit schedules, cancellation, fallback, unsupported execution,
ill-conditioning, UI catalog replacement, retained evidence, and export.

Fresh-class acceptance passes `coreGeometryState` 143/143, `alignment`
185/185, `backendSurface` 246/246, `viewerAlignmentUi` 75/75,
`viewerPresentationWorkflows` 69/69, and `viewerPerformancePrecision` 34/34,
totaling 752/752 with zero failures or incomplete tests. MATLAB Code Analyzer
reports zero issues for every changed MATLAB source, test, and manifest file.
Representative private imagery remains the deliberate external gate for
practical-usefulness claims.

### RD-6 — World-Space Stereo Cursor

Status: implementation complete July 14, 2026.

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

Implementation evidence: the pre-change reproduction found no stereo-cursor
context command despite a valid active pair. `ProjectionStereoCursorModel`
now owns graphics-independent world-point construction and deterministic
bounded source-model inversion. `ProjectionViewerApp` owns the checked menu,
reposition action, two physical-eye markers, connector, compact status overlay,
active-pair refresh, cleanup, and the public `placeStereoCursor`,
`stereoCursorDiagnostics`, and `stereoCursorOptions` entry points. Default Z
steps are `1 m`, `0.1x` fine, and `10x` coarse within configurable finite
bounds. Explicit statuses cover missing views, unsupported geometry,
outside-source footprint, behind source, sampling failure, ray-model mismatch,
and projection-plane failures.

Focused acceptance covers zero and signed height, oblique planes, signed
disparity reversal, stable IDs through role/order changes, physical-eye color,
pair turnover from Alignment and Pair View, pan/zoom/twist, invalid states,
runtime-only import/reset/delete cleanup, and unchanged Shift-arrow behavior.
The UI run also exposed and corrected a deterministic initial-framing race:
framing now waits for the resolved UIAxes viewport through a guarded one-shot
post-layout graphics event and refreshes tiles only for tiled layers.

Fresh-class acceptance passes `coreGeometryState` 147/147, `alignment`
185/185, `backendSurface` 246/246, `viewerAlignmentUi` 77/77,
`viewerPresentationWorkflows` 73/73, and `viewerPerformancePrecision` 34/34,
totaling 762/762 with zero failures or incomplete tests. MATLAB Code Analyzer
reports zero issues for every changed MATLAB source, test, and manifest file.

### RD-7 — Real-Data Regression, Alignment Measurement, And Multi-View Surface Corrections

Status: complete July 14, 2026. RD-7A/B/C/G were delivered as the first
coherent slice; RD-7D/E/F complete the integrated measurement/performance
release gate.

RD-7 incorporates the complete operator report beginning with the July 14
five-view presentation/alignment regression report and all subsequent design
decisions. It is one operator-visible corrective release gate. The subpacks
below are dependency-ordered engineering slices, not independently releasable
claims of completion. Do not mark RD-7 complete until the integrated workflow
passes its focused tests, all affected fresh-class groups, Code Analyzer, and
operator documentation review.

The approved direction is:

1. make runtime presentation masks and tiled graphics agree immediately;
2. preserve the Alignment Workbench session and make every blocking stage
   visibly active;
3. enable Surface Workbench from any valid accepted pair and launch it as a
   genuine multi-image workflow by default;
4. replace repeated full-source working-image materialization with an
   analysis-safe, antialiased source-pyramid path;
5. use 512/768 working images for coarse discovery only, then refine retained
   correspondences in full-source patches;
6. reduce evidence through spatially diverse and information-aware selection
   rather than globally strongest-score truncation; and
7. separate solver validity from residual-improvement preference so a valid
   small second correction remains reviewable and applicable.

#### Observed operator evidence and confirmed structural causes

- Single View can lose its active image after zoom/LOD replacement. Changing
  frame or zoom can make it reappear. The tile preview path currently derives
  a new surface's visibility from stored `layer.Visible` instead of the
  effective runtime presentation mask.
- Returning to View All can leave stored visibility checkboxes checked while
  the corresponding tiled surfaces remain hidden. Toggling each stored flag
  forces the missing graphics to reappear.
- Pair View is expected to traverse consecutive Layer Manager entries
  `(1,2)`, `(2,3)`, and so on. The runtime schedule may instead use acquisition
  metadata or stable-ID fallback ordering, while stale tiled graphics make one
  apparent eye remain fixed.
- Loop is currently initialized off in both the Layer Manager control and the
  motion runtime. The approved default is on.
- The OPK display is currently an absolute figure overlay. It can rise above
  the control base or leave the usable viewport during resize. The approved
  correction is to return it to the bottom control base.
- A first Match can produce a healthy raw count without visible viewport
  overlays. Alignment overlays are reconstructed on the image plane and can
  be occluded or z-fight with image surfaces; they require an explicit
  top-of-stack presentation offset and immediate refresh.
- Filter sets a status string before its blocking work, but the UI may continue
  showing the preceding Match summary. Every blocking stage needs a forced,
  bounded event flush and an unambiguous active-stage message.
- Closing the Alignment Workbench destroys its controls. `AlignmentSession`
  survives, but recreated controls and tables begin empty or disabled, making
  retained matches and solve state appear deleted.
- Surface Workbench enablement currently depends on an Alignment Workbench
  table handle and on the exact ordered active moving/reference pair. This can
  keep the button disabled even when another enabled physical pair has ample
  accepted evidence.
- The Surface Workbench context already contains one request per accepted
  physical pair, and the runner already associates stable observations into
  multi-view tracks before robust multi-ray reconstruction. However,
  viewer-launched initial configuration selects the active pair's two views
  and the `Selected pair`/`fast` schedule, so the default Run is pairwise.
- Fast and Quality alignment working grids are bounded by 512 and 768 pixels
  per axis respectively, but the full-source inverse warp reads or copies the
  enclosing full-source rectangle for each pair side and converts the selected
  band to double before resampling. Broad overlap can therefore repeat large
  source-region work across every pair even though the output is bounded.
- Feature locations are continuously mapped back into full-source row/column
  coordinates and the solver samples rays at those coordinates. This avoids
  hard integer quantization, but it cannot restore spatial information lost in
  the coarse render. The current path has no full-source local correspondence
  refinement stage.
- The working-image inverse warp uses direct bilinear sampling without an
  explicit reduction prefilter. Large scale changes can therefore expose
  feature detection to aliasing or systematic localization bias.
- Fast and Quality currently retain up to 1,000 and 2,000 features per pair
  image, ordered globally by detector metric. Exhaustive descriptor matching
  and the later solve can receive many locally redundant observations.
- The network solver already reduces cyclic edges within a multi-view feature
  track, but it does not yet select independent tracks for spatial coverage or
  OPK information gain.
- A converged second solve near the current solution can produce a small RMS
  improvement and small finite OPK increments. The present 10 percent policy
  rewrites that result as failed and disables Preview, Apply, and Revert
  together. Near convergence, small improvement is expected and is not by
  itself a scientific-safety failure.

#### RD-7A — Presentation-state and bottom-control correctness

Implementation status: complete July 14, 2026. Effective visibility now gates
all surface visibility updates, explicit Layer Manager order drives Single and
Pair presentation, reverse stepping is exact, Loop defaults on while preserving
an operator-off session choice, and the OPK readout is layout-managed in the
bottom control base. Five-layer tiled/LOD tests inspect actual surface
visibility, stored View All visibility, outline state, rollover, and pair
identity.

1. Make `effectiveLayerVisibilityMask` the single runtime authority for every
   image-surface creation, replacement, reuse, LOD transition, lookahead
   completion, and visibility reconciliation path. Stored `layer.Visible`
   remains the View All preference, not the presentation-mode graphics state.
2. Entering or stepping Single View and Pair View shall synchronously reconcile
   every newly active tiled layer. The old valid LOD may remain visible until a
   coherent replacement is ready; an active image shall never disappear only
   because refinement was requested.
3. Returning to View All shall immediately apply the complete stored visibility
   vector to both tiled and untiled surfaces. It shall not require individual
   checkbox toggles or another camera event.
4. Derive Single/Pair navigation from the current Layer Manager stack order and
   the same eligible-layer filter shown to the operator. Pair View shall present
   consecutive overlapping pairs in that order, with reverse stepping the
   exact inverse. Acquisition time, pass metadata, and stable IDs may break a
   true tie only when no explicit manager order exists.
5. Initialize Loop on in the Layer Manager control and in the runtime default.
   Preserve an explicit operator off state for the remainder of that viewer
   session.
6. Keep active-layer-outline state runtime-only and ensure its existing on/off
   control remains respected through presentation changes and LOD replacement.
7. Move the OPK/view-vector readout back into the bottom control base as a
   layout-managed element. It shall remain in the bottom corner, inside the
   figure, at minimum supported window size and through repeated resize. Remove
   absolute viewport positioning for that readout.

Focused acceptance shall exercise five tiled layers, zoom-driven LOD changes,
Single and Pair forward/reverse stepping, loop rollover, View All restoration,
stored visibility edits made in every mode, active-outline off/on, layer
reorder, and minimum/large window resize. Assertions shall inspect actual
surface visibility and pair identities, not only the calculated logical mask.

#### RD-7B — Persistent Alignment Workbench and truthful stage feedback

Implementation status: complete July 14, 2026. Close hides the viewer-owned
Workbench without destroying session controls or computation state, Reset is
the intentional clearing boundary, and viewer deletion owns final cleanup.
First-match overlays use a deterministic depth offset, while active and last-
completed stage status are retained separately and blocking stages visibly
flush their active message.

1. Treat the Alignment Workbench as a persistent viewer-owned tool window.
   Its close button shall hide the window and preserve its controls, tables,
   settings, ROI, working-image cache, raw/filtered matches, solution,
   correction actions, and diagnostics. Reopening shall focus/show the same
   session.
2. Viewer deletion remains the hard ownership boundary and shall delete the
   hidden workbench and its callbacks. Add or retain an explicit Reset action
   for intentional state clearing; closing is never Reset.
3. If controls must be recreated after an exceptional graphics deletion,
   restore them from `AlignmentSession` rather than initializing an empty
   operator presentation.
4. Preserve the exact enabled/disabled state of Match, Filter, Solve, Preview,
   Apply, Revert, and Surface Workbench actions across hide/show. Recompute only
   when a real input-generation change invalidates the corresponding stage.
5. Raise raw, filtered, and solved alignment overlays above the complete image
   stack with a deterministic camera-depth offset. Refresh them on the first
   Match, after every filter/solve, after presentation or active-pair changes,
   and after relevant layer projection changes without modifying scientific
   coordinates.
6. Before blocking work, publish and visibly flush bounded messages for working
   image planning/rendering, pair progress, feature detection/matching,
   filtering, evidence refinement/selection, network preparation, primary
   optimization, and optional diagnostics. Filter shall never leave the prior
   Match result looking like the active status.
7. Retain completed counts and timings after each stage, but distinguish them
   from the active-stage message. Cancellation or failure shall leave the last
   authoritative completed state inspectable.

Focused acceptance shall close/reopen after Match, Filter, Solve, Preview, and
Apply; verify table rows, settings, cached generations, overlays, status, and
action controls; confirm explicit Reset clears state; and confirm viewer
deletion owns hidden-window cleanup.

#### RD-7C — Surface Workbench gate and multi-image launch default

Implementation status: complete July 14, 2026. Eligibility is derived from any
enabled accepted physical pair independent of direction or table graphics.
Viewer launch supplies every eligible pair and initially selects all catalog
views, passes, and pairs with the Quality schedule and `robustMultiView` stage.
Fast, planned, quality, plausible, and explicit schedules are distinct;
selected passes filter real execution; preflight explains exact pair inclusion,
stages, caps, and evidence gates.

1. Enable Surface Workbench when any enabled, curated, accepted physical pair
   has at least the hard solver minimum of usable evidence and the alignment
   stage is previewed, applied, or explicitly accepted for manual correction.
   Do not depend on an Alignment Workbench table graphics handle.
2. Pair identity checks shall be orientation-independent. Moving/reference
   direction may choose display roles but shall not make the same physical pair
   ineligible.
3. Refresh availability when matches are filtered/curated, pair enablement
   changes, active roles change, a solve is previewed/applied/reverted, the
   workbench is shown, or scene/correction generation changes.
4. Build the launch context from every eligible accepted physical pair. The
   active pair remains highlighted and available as an explicit anchor or
   selected-pair schedule; it does not limit the context.
5. Viewer-launched initial configuration shall select all eligible catalog
   views, passes, and pairs and shall default to `All quality pairs` with the
   `robustMultiView` processing stage. Selecting five views must no longer open
   in a silent two-view execution state.
6. `Selected pair` remains an explicit fast diagnostic schedule. `Planned
   subset`, `All quality pairs`, `All plausible pairs`, and `Explicit pairs`
   shall have distinct, documented scheduling semantics.
7. Apply selected pass IDs as a real scheduling filter, not presentation-only
   table state. Quality and plausibility gates shall report why a context pair
   is included or omitted.
8. Preflight shall list the exact scheduled view, pass, and pair IDs, pair
   count, per-pair observation cap, matcher, and reconstruction/fusion stages.
   It shall explain that all eligible pair evidence is offered to association,
   while validity, confidence, occlusion, consistency, track connectivity,
   residual, and conditioning gates decide which rays contribute to each
   reconstructed point.
9. Multi-view association shall continue to count one stable source
   observation as one ray even when it participates in multiple pair records.
   A five-view run may use all accepted pair evidence without claiming that all
   five views observe every reconstructed point.

Focused acceptance shall cover activation from a valid non-active pair,
reversed pair roles, a disabled active pair with another eligible pair,
hide/show of Alignment Workbench, selected-pass filtering, explicit single-pair
execution, and a deterministic five-view/all-eligible-pair preflight and
multi-ray result.

#### RD-7D — Analysis-safe source pyramid and bounded working-image rendering

Implementation status: complete July 14, 2026. The alignment-only
`ProjectionAnalysisSourceCache` selects the power-of-two source level
immediately finer than the measured source-to-working footprint, reads only
the configured native band, reduces invalid-aware radiometry by normalized
antialiased convolution, and materializes large regions in bounded aligned
chunks. Its identity covers geometry/source revision, path or memory
generation, size/class, band, validity and radiometric policy, level, region,
and reduction version. Pair outputs retain the original continuous source
maps and report plan/read/reduction/inverse-map/resample/validity/cache work.
Repeated pair sides reuse immutable entries; display textures and camera LOD
are absent from the path.

1. Factor the raw antialiased source-level generator out of the display-only
   contract into an immutable source-radiometric pyramid/cache service. Display
   may convert those values into presentation textures; alignment consumes the
   configured source band and validity only.
2. An analysis-cache identity shall include source/geometry revision, source
   path or memory generation, image size/class, band, nodata/validity policy,
   pyramid level, reduction-filter version, region/tile identity, and any
   radiometric option that changes scientific analysis pixels.
3. Never reuse normalized scalar display textures, RGB display conversions,
   alpha/composite results, contrast stretches, or camera-selected display LOD
   as alignment input.
4. Build power-of-two levels with a declared antialiasing reduction filter.
   Filter validity through normalized convolution or an equivalent explicit
   policy so invalid pixels do not bleed into valid texture. Use filter-support
   halos and deterministic edge handling so tile seams cannot create features.
5. Choose analysis LOD from the local source-to-working-grid sampling Jacobian,
   independently of viewport zoom. Prefer the cached level immediately finer
   than the output demand; never use a coarser level merely because it is
   already on screen.
6. Support local/tiled LOD choice where projective scale varies materially
   across a pair. Record the chosen source-pixel footprint and oversampling
   margin in runtime diagnostics.
7. Warp the selected analysis level into the pair-specific working grid while
   retaining authoritative continuous full-source row/column maps and ray
   sampling. Account explicitly for pyramid level indices and pixel-center
   conventions.
8. Avoid reading/copying and converting a broad full-resolution bounding
   rectangle when a cached antialiased regional level can supply the bounded
   output. Reuse source regions/levels across pairs and pair directions.
9. Keep the present 512/768 per-axis working-grid bounds initially as coarse
   discovery policies. Pair aspect and overlap may produce a smaller dimension;
   the bounds are not a promise of square output.
10. Instrument planning, source read, pyramid materialization, inverse-map,
    resample, validity, and cache time/bytes/hits per source and pair. Runtime
    evidence may be inspected during private validation, but private source
    dimensions and identifying values shall not enter repository documents.

Acceptance shall compare the analysis-LOD render against a direct full-source
oracle for coordinate mapping, valid masks, radiometric error, feature
repeatability, match/inlier stability, and absence of tile seams or jagged
reduction artifacts. It shall prove that repeated pairs hit the analysis cache
and that output work is bounded by selected LOD/region rather than repeated
full-source materialization.

#### RD-7E — Coarse discovery, full-source refinement, and diverse evidence

Implementation status: complete July 14, 2026. Fast and Quality start at 256
and 512 detector candidates per pair side. Overlap-aware aspect quotas spread
strong candidates before descriptors. After cheap filtering, bounded native
patch ZNCC refinement returns continuous source coordinates, explicit weak/
ambiguous/border/geometry states, subpixel curvature uncertainty, and
reprojected plane coordinates; physical filters are recomputed from those
values. Final selection balances both source frames, margins/interior, stable
record identity, and an information-normal proxy, caps ordinary evidence at
64 records per pair, preserves component edges, and marks unused full-ledger
records `spatialRedundancy`.

1. Declare 512/768 feature matching a coarse correspondence-discovery stage,
   not the final measurement supplied to the precision OPK solve.
2. Before descriptor extraction, apply overlap-aware adaptive nonmaximum
   suppression and aspect-aware spatial quotas. Select several strong,
   separated candidates per occupied cell rather than the globally strongest
   detector responses from one textured region.
3. Use initial engineering caps near 256 candidates per Fast pair image and
   512 per Quality pair image, subject to synthetic and representative
   validation. These are performance starting points, not universal scientific
   thresholds; sparse scenes may return fewer, and an explicit diagnostic mode
   may request more.
4. Enforce candidate and post-match coverage in both images. A distribution
   that is broad in the moving image but collapsed in the reference image is
   not spatially diverse.
5. Run cheap overlap, descriptor-ratio/uniqueness, and provisional geometric
   rejection before expensive source refinement. With bounded candidates,
   deterministic exhaustive matching may remain the reference path; any
   approximate search requires explicit parity and reproducibility evidence.
6. Refine surviving matches in small original-source patches using a declared
   photometric normalization and subpixel local estimator. Handle masks,
   borders, scale/orientation, weak texture, ambiguity, and convergence
   explicitly. Do not refine against display or coarse-pyramid pixels.
7. Return refined continuous source row/column values plus localization
   covariance or an equivalent uncertainty/quality record. Recompute plane
   coordinates, exact sampled rays, coplanarity residuals, and subsequent
   filters from refined values.
8. Permit one bounded refinement iteration after the initial OPK estimate when
   reprojection materially changes the local search center. Prevent drift with
   source-patch bounds and an explicit acceptance test against the coarse seed.
9. After physical/geometric filtering, create a spatial-diversity stage that
   balances occupied cells, image margins/interior, source rows/columns, pair
   coverage, and multi-view track uniqueness. Keep every raw and accepted
   record in the ledger; mark unused records with a reason such as
   `spatialRedundancy` rather than silently deleting them.
10. Select the final solve subset by network connectivity and incremental OPK
    information gain, using the solver Jacobian/normal matrix where valid.
    Prefer observations that improve rank, conditioning, and covariance over
    additional nearby observations with similar sensitivity.
11. Initial evaluation targets are roughly 32–64 solve-selected records per
    useful pair and a few hundred for an ordinary five-view network. Stop
    adding evidence when marginal information/covariance improvement plateaus,
    subject to per-pair and per-component hard minima. Do not turn these
    engineering targets into fixed public acceptance thresholds without
    measured evidence.
12. Report raw, descriptor-accepted, geometrically accepted, source-refined,
    spatially eligible, track-unique, and solve-selected counts separately.
    Report occupied-cell fraction, normalized convex-hull/extent coverage,
    conditioning contribution, and rejection reasons per view and pair.
13. Report the source-pixels-per-working-pixel map and the refined localization
    uncertainty/angular measurement floor. Evaluate small physical-model
    approximations, including refraction approximations, against the refined
    measurement floor rather than the coarse working-image localization floor.

Acceptance shall prove that the refined source observations improve or retain
known-truth OPK accuracy, that spatial selection cannot collapse into one
region, that all required network components remain observable, and that a
smaller solve subset reproduces the full eligible solution within a declared
uncertainty-based tolerance while materially reducing work.

#### RD-7F — End-to-end alignment performance and work accounting

Implementation status: complete July 14, 2026. The non-private five-view
structural fixture now begins with 2,000 eligible pair observations and proves
that only 640 reach the ten-pair optimizer while all 2,000 remain auditable.
The selected compiled-evidence/semi-analytic path preserves reference-path
correction, residual, robust-weight, gauge, and covariance parity. Runtime
diagnostics count pair/pair-side renders, source reads/pixels/bytes, pyramid
and cache work, detected/described/matched/filtered/refined/selected/track-
unique observations, ray sampling, residual/Jacobian evaluations, iterations,
and bounded sensitivity children. Progress and cancellation cover source
refinement as well as optimization; correctness has no wall-clock threshold.

1. Add an instrumented non-private five-view workflow that covers working-image
   planning/rendering, feature preparation/detection/description, matching,
   filtering, source refinement, track construction, solve selection, evidence
   compilation, optimization, comparison, covariance, and optional sensitivity
   diagnostics.
2. Count source reads/pixels/bytes, pyramid/cache work, pair-side renders,
   detected/described/matched/refined/selected observations, ray sampling,
   residual/Jacobian evaluations, iterations, and optional child solves.
3. Verify that the RD-2 compiled evidence and semi-analytic Jacobian path is
   actually selected for the representative constant-OPK network. A custom
   real-data ray sampler shall not reintroduce per-iteration source sampling.
4. Supply only the diverse solve-selected evidence to optimization while
   retaining the complete ledger, refined observations, and diagnostics for
   audit and alternate selection.
5. Keep Fast sensitivity work `notRequested`, Balanced `deferred`, and Quality
   explicitly bounded unless the operator requests exhaustive diagnostics.
6. Present active stage and elapsed/work counts at bounded cadence before and
   during every blocking stage. Do not use a machine-specific wall-clock value
   as a correctness threshold.
7. Profile first; do not reduce numerical precision, weaken physical residuals,
   or change robust weighting merely to meet a timing target. Optimize repeated
   source work, redundant evidence, allocation, and equivalent diagnostic
   evaluations first.

Acceptance shall demonstrate bounded work scaling with scheduled pairs,
selected LOD regions, refined candidates, and solve-selected observations. It
shall retain reference-path correction/residual/weight/gauge/covariance parity
within declared tolerances and keep Cancel responsive throughout.

#### RD-7G — Passed, review, and rejected correction actionability

Implementation status: complete July 14, 2026. The compatibility migration now
maps the old minimum-improvement option to an advisory preferred-improvement
setting. Solver convergence remains scientific truth while a separate
`passed`/`review`/`rejected` decision controls Preview, Apply, confirmation, and
Revert independently. Review confirmation reports physical RMS, active
objective change, maximum OPK, observation/track/coverage evidence,
conditioning/uncertainty, and bounds. Correction-store generation parenting
retains exact second-generation apply/revert lineage, and applied review
results enable Surface Workbench.

First-slice validation evidence: MATLAB Code Analyzer reports zero issues in
all 17 changed MATLAB source/test files. Fresh-class groups pass
`coreGeometryState` 147/147, `alignment` 186/186, `backendSurface` 248/248,
`viewerAlignmentUi` 77/77, `viewerPresentationWorkflows` 73/73, and
`viewerPerformancePrecision` 34/34, totaling 765/765 with zero failures or
incomplete tests.

1. Replace `MinResidualImprovementFraction` with a compatibility-migrated
   `PreferredResidualImprovementFraction`. Retain 10 percent as the default
   advisory preference unless later measured evidence supports another value.
2. Classify a completed result independently of solver convergence:
   `passed`, `review`, or `rejected`. Expose at least `PreviewAllowed`,
   `ApplyAllowed`, `ConfirmationRequired`, `Warnings`, and
   `HardRejectionReasons`.
3. A result is `passed` when it satisfies the hard gates and the preferred
   improvement/significance checks without advisory findings.
4. A result is `review` when it satisfies all hard gates but has a marginal
   residual improvement, fewer than the preferred (but not hard-minimum)
   observations, a correction small relative to estimated uncertainty, or
   another declared quality warning. `review` results remain previewable and
   applicable.
5. A result is `rejected` only for a hard reason such as nonconvergence,
   nonfinite correction/residual state, deficient gauge/observability,
   fewer than the hard-minimum usable observations, material degradation of
   the authoritative objective or validation metric beyond numerical/model
   tolerance, an unacceptable condition/covariance state, or a configured
   parameter-bound hit.
6. Do not rewrite a converged solver result or `Convergence.Success` as failed
   merely because actionability is `review` or `rejected`. Preserve the
   scientific result and attach the separate policy decision.
7. Decouple Preview, Apply, and Revert enablement. Preview is available for a
   finite solved correction; Apply is available for `passed` and `review`;
   Revert is available only after this result has been previewed or applied.
8. Applying a `review` result shall show one concise confirmation containing
   before/after RMS and percentage, active-objective change, maximum incremental
   omega/phi/kappa, observation/track and spatial-coverage summaries,
   condition/covariance/significance, and bound state.
9. A finite nonzero incremental correction near convergence shall not be
   disabled merely because its relative RMS improvement is small. An exactly
   state-equivalent correction may be reported as a no-op.
10. A second accepted correction shall use the current applied correction
    generation as its parent, apply exactly once, remain reversible, and not
    confuse Revert with the prior generation.
11. Surface Workbench eligibility shall recognize an applied `review`
    correction exactly as it recognizes an applied `passed` correction.

Focused acceptance shall cover preferred improvement exceeded, small positive
improvement, zero/no-op, statistically insignificant finite correction,
material degradation, hard-minimum evidence failure, preferred-count warning,
bound hit, observability failure, confirmation accept/cancel, Preview without
Apply, second-generation Apply, and exact Revert lineage.

#### RD-7 integrated acceptance and delivery

- Five tiled layers remain visible as required through zoom, LOD replacement,
  Single/Pair stepping, loop rollover, and View All restoration. Pair identity
  follows Layer Manager order and actual graphics agree with stored/effective
  state.
- Alignment Match overlays are visible on the first run; Filter and Solve show
  the active stage before blocking; closing/reopening preserves the complete
  operator session; explicit Reset alone clears it.
- The OPK readout remains in the bottom control base at every supported size.
- Surface Workbench enables from any valid accepted pair and opens with all
  eligible views/passes/pairs selected, `All quality pairs`, and robust
  multi-view reconstruction. Preflight exactly names the work. Explicit
  selected-pair execution remains available.
- Working-image generation uses an analysis-safe antialiased LOD and reusable
  source cache, retains authoritative full-source coordinate maps, and avoids
  repeated broad full-source materialization for bounded outputs.
- Coarse matching uses fewer spatially distributed candidates. Full-source
  patch refinement supplies continuous source observations and uncertainty.
  Filtering and final solve selection remain spatially diverse, connected,
  track-aware, and information-bearing.
- The constant-OPK solve receives a bounded evidence subset, reports complete
  work accounting, and matches the full/reference solution within declared
  scientific tolerances.
- A valid marginal second solve is classified `review`, can be previewed, and
  can be applied after explicit confirmation. Hard-invalid results remain
  non-applicable with exact reasons.
- No display-normalized pixels enter alignment or backend scientific products;
  no private imagery, geometry, paths, source dimensions, or identifying
  measurements enter the repository.
- Run Code Analyzer on every changed MATLAB file and run each affected logical
  test group in a separate fresh-class MATLAB MCP call. Complete all six groups
  before the final RD-7 completion claim, then update operator/reference docs,
  commit, push, and confirm a clean worktree.

Final integrated validation evidence: MATLAB Code Analyzer reports zero issues
in all 18 changed MATLAB source/test files. Fresh-class groups pass
`coreGeometryState` 147/147, `alignment` 188/188, `backendSurface` 248/248,
`viewerAlignmentUi` 77/77, `viewerPresentationWorkflows` 73/73, and
`viewerPerformancePrecision` 34/34, totaling 767/767 with zero failures or
incomplete tests.

## Likely Code And Test Touchpoints

Inspect rather than assume the final edit set:

```text
src/ProjectionViewerHarness.m
src/ProjectionPairViewpoint.m
src/ProjectionStereoCursorModel.m
src/ProjectionViewerApp.m
src/ProjectionAlignmentSession.m
src/ProjectionAlignmentOptions.m
src/ProjectionAlignmentWorkingGrid.m
src/ProjectionAlignmentWorkingImageRenderer.m
src/ProjectionAlignmentFeatureMatcher.m
src/ProjectionAlignmentMatchFilter.m
src/ProjectionAlignmentTrackBuilder.m
src/ProjectionAlignmentNetworkEvidence.m
src/ProjectionAlignmentNetworkSolver.m
src/ProjectionAlignmentOpkSolver.m
src/ProjectionAlignmentParameterModel.m
src/ProjectionAlignmentSafeSolvePolicy.m
src/ProjectionPreviewPyramid.m
src/ProjectionBackendSourceProvider.m
src/ProjectionFullSourceInverseWarp.m
src/ProjectionViewerLruCache.m
src/ProjectionDenseSurfaceExtractor.m
src/ProjectionSurfaceWorkbenchApp.m
src/ProjectionSurfaceWorkbenchModel.m
src/ProjectionSurfaceWorkbenchRunner.m
src/ProjectionSurface3DViewer.m
tests/ProjectionViewerHarnessTest.m
tests/ProjectionPairViewpointTest.m
tests/ProjectionAlignmentSessionTest.m
tests/ProjectionAlignmentWorkingImageRendererTest.m
tests/ProjectionAlignmentFeatureMatcherTest.m
tests/ProjectionAlignmentMatchFilterTest.m
tests/ProjectionAlignmentTrackBuilderTest.m
tests/ProjectionAlignmentNetworkSolverTest.m
tests/ProjectionAlignmentOpkSolverTest.m
tests/ProjectionAlignmentSafeSolvePolicyTest.m
tests/ProjectionViewerAlignmentWorkflowTest.m
tests/ProjectionViewerMotionWorkflowTest.m
tests/ProjectionViewerMotionPlaybackWorkflowTest.m
tests/ProjectionViewerAppInteractionTest.m
tests/ProjectionStereoCursorModelTest.m
tests/ProjectionViewerStereoCursorWorkflowTest.m
tests/ProjectionPreviewPyramidTest.m
tests/ProjectionDenseSurfaceExtractorTest.m
tests/ProjectionSurfaceWorkbenchRunnerTest.m
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
