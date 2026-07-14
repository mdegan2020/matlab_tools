# Real-Data Validation Follow-Up Workpack

Status: active planning and operator-feedback intake. No implementation pack in
this document has started. This workpack is the highest-priority implementation
queue once the pending July 13, 2026 operator findings are incorporated. It
temporarily precedes independent D2 native CPU work and all hardware-gated GPU
work.

## Purpose

This workpack converts real-data regressions and scalability findings into
small, testable implementation packs without weakening the established
scientific contracts. It currently contains two repository-inspection findings:

1. an initial-camera orientation regression for explicit oblique planes; and
2. an interactive global-alignment solve whose diagnostic and residual-
   evaluation costs scale poorly for five-image, high-match-count networks.

The user's additional extensive test findings will be recorded at the top of
the ordered queue before implementation begins. Do not infer those findings or
begin source changes until they have been incorporated here.

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

### RD-0 — Operator Test Findings — Priority Reserved

Status: awaiting the user's July 13, 2026 testing report.

Record each finding with:

- a concise symptom and affected workflow stage;
- whether it is deterministic or intermittent;
- the smallest non-private reproduction or structural proxy;
- expected versus observed behavior;
- severity, data-loss/scientific-risk assessment, and workaround;
- likely owning component and dependencies;
- focused acceptance tests; and
- an explicit order relative to other RD-0 findings.

RD-0 findings take priority over RD-1 and RD-2 unless the user assigns another
order. Split unrelated findings into independently reviewable packs. A report
that changes a public/scientific contract requires a documented decision before
implementation; a clear regression against an existing requirement does not.

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

Status: confirmed scalability defect; implementation not started.

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

#### RD-2D — Derivative and linear-algebra optimization

Begin only after RD-2A through RD-2C are measured.

1. Derive analytic or stable semi-analytic Jacobians for the default
   epipolar-coplanarity residual and constant-OPK parameterization, including
   robust-weight and pass-common/differential transforms.
2. Reuse the accepted data Jacobian for observability and covariance where its
   weighting semantics match; do not recompute an equivalent central-
   difference matrix at both start and solution without evidence.
3. Expose Jacobian method and fallback in provenance. Retain numerical finite
   differences as a comparison oracle.
4. Measure matrix sparsity and problem size before selecting sparse storage,
   BLAS, or another provider.
5. Consider bounded pair/residual batching on `parpool("threads")` only if the
   optimized serial CPU path remains a demonstrated bottleneck. Do not enable
   nested or process-based parallelism.

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
tests/ProjectionViewerHarnessTest.m
tests/ProjectionPairViewpointTest.m
tests/ProjectionAlignmentNetworkSolverTest.m
tests/ProjectionAlignmentOpkSolverTest.m
tests/ProjectionViewerAlignmentWorkflowTest.m
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
