# Alignment Workflow Hardening Plan

This document anchors the next follow-up work for GUI auto-alignment quality,
operator review, and real-data workflow control.

The current auto-alignment pipeline is fast enough to run on large real imagery
after the matched-ray solver optimization, but the default workflow can still
produce implausible OPK corrections when bad feature matches survive filtering.
This plan focuses on alignment quality and workflow transparency. It should not
change backend rendering semantics: backend output remains full-resolution,
1:1-oriented processing of the source image data.

## Triggering Observation

A real-data GUI alignment run completed quickly and reported roughly:

```text
raw matches: 350
reported inliers: 302
```

Most drawn correspondences were visually close, roughly `50` to `100` native
pixels apart, but two correspondences crossed nearly the full image, roughly
`15000` native pixels. The solve then produced implausible corrections:

```text
L2 OPK approximately [3, 12, 11] degrees
L1 OPK approximately [0.1, 12, 11] degrees
```

For that data, plausible omega and phi should be less than roughly one quarter
of the field of view, about `0.25` degrees when the FOV is about `1` degree.
Kappa can have more freedom, but should still be bounded, with a practical
default cap below `20` degrees. Applying the solution moved the imagery far away
and did not produce a good alignment.

The GUI also lacks an obvious way to clear drawn match overlays, and the single
`Run` action makes it hard to inspect and curate matches before solving.

## Goals

- Reject catastrophic feature correspondences before the OPK solve.
- Make OPK bounds physically plausible by default for real imagery.
- Distinguish raw matches, filtered matches, geometric inliers, solver-used
  observations, and solver residual outliers.
- Split the GUI workflow into inspectable stages: match, filter, solve, preview,
  apply, revert, and clear.
- Keep intermediate alignment state so the operator can solve again without
  recomputing features.
- Provide a path toward manual match curation.
- Make overlays clearable and eventually state-aware.

## Non-Goals

- Do not change backend output-grid or full-resolution rendering behavior.
- Do not make display pyramids or tiled preview data part of backend processing.
- Do not require GPU acceleration.
- Do not introduce process-based parallel pools. If profiling later justifies
  parallel alignment work, only `parpool("threads")` is acceptable.
- Do not redesign the backend alignment contract unless a later milestone
  explicitly requires it.

## Feature Pack 1: Filtering And Plausibility Guardrails

### 1.1 Enable geometric outlier filtering by default

The GUI previously constructed options with `GeometricMethod="none"`. For real
data, this was too permissive. The default GUI path should run a geometric
outlier stage after descriptor matching and before solving.

Candidate behavior:

- Use a robust 2D geometric model in the projection-plane working image.
- Start with a similarity or affine model, then revisit if real sensor geometry
  requires a different model.
- Reject correspondences with displacement or model residuals far outside the
  consensus set.
- Surface the raw and post-filter counts in the pair table and status text.

Acceptance criteria:

- A small number of full-image-crossing matches cannot survive the default
  filter when most correspondences form a compact consensus.
- Existing synthetic alignment tests still pass.
- Tests distinguish raw match counts from geometrically accepted counts.

Implementation note:

- The GUI default now requests `GeometricMethod="similarity"` and reports raw
  versus filtered match counts distinctly.

### 1.2 Add native-pixel displacement sanity filtering

Working-image filtering can miss mistakes if a feature maps back to a large
native source displacement. Add an optional native-pixel displacement sanity
check after feature locations are mapped back to source observations.

Candidate controls:

- Absolute maximum native displacement.
- Robust threshold based on median absolute deviation.
- Per-pair diagnostics for rejected native displacement outliers.

Acceptance criteria:

- A pair with two `15000` native-pixel outliers and hundreds of local matches
  rejects the outliers deterministically.
- The threshold can be disabled or relaxed from advanced options later.

Implementation note:

- The shared filter pipeline now has a `nativeDisplacement` stage. The GUI
  default enables the MAD-based native-pixel displacement filter while the
  engine default keeps the method disabled unless requested.

### 1.3 Rename and report match states precisely

The current GUI wording can imply that all filtered matches are true inliers.
Use precise labels throughout diagnostics and UI:

```text
raw matches
descriptor-kept matches
geometric inliers
ROI-kept matches
solver observations
solver residual outliers
```

Acceptance criteria:

- Pair table and result diagnostics no longer call every filtered match an
  inlier unless it survived a geometric inlier test.
- JSON result diagnostics preserve stage counts.

### 1.4 Add physically plausible OPK bounds

Add conservative solver bounds for GUI alignment. Defaults should be derived
from available source geometry metadata when possible.

Candidate defaults:

```text
omega bound: min(0.25 * field of view, configured hard cap)
phi bound:   min(0.25 * field of view, configured hard cap)
kappa bound: configurable default, less than 20 degrees
```

For the current real-data example, omega and phi should default near
`0.25` degrees. Kappa should remain looser but bounded.

Acceptance criteria:

- GUI-selected default solve cannot return omega or phi around `12` degrees for
  a one-degree-FOV image.
- Result diagnostics report the applied bounds and whether any solution hit a
  bound.
- A bound-hit warning appears in the GUI status/result summary.

Implementation note:

- The solver reports `Diagnostics.BoundsDegrees`, `Diagnostics.BoundHits`, and
  `Diagnostics.AnyBoundHit`, and emits a warning when any OPK correction hits a
  configured bound. GUI defaults keep omega/phi FOV-derived and cap kappa at
  `15` degrees.

### 1.5 Add robust solve diagnostics

Extend solver output with practical quality information:

- before/after RMS.
- max residual before/after.
- worst residual match indices.
- per-pair residual summaries.
- bound-hit flags.
- objective evaluation count and iteration count.

Acceptance criteria:

- The operator can identify that one or two matches dominate the solve.
- Tests cover bound-hit reporting and worst-residual diagnostics.

Implementation note:

- Solver results now include `Diagnostics.MaxResidualBefore`,
  `Diagnostics.MaxResidualAfter`, `Diagnostics.WorstResiduals`,
  `Diagnostics.PerPairResidualSummary`, and table-ready
  `Diagnostics.MatchRecords` with per-match source coordinates, working-image
  coordinates, residuals, and accepted/disabled state. `Convergence` also
  reports the optimizer function-evaluation count when MATLAB provides it.

## Feature Pack 2: Staged GUI Alignment Workflow

### 2.1 Split Run into Match and Solve actions

Replace the single all-in-one `Run` action with staged controls:

```text
Match
Filter
Solve
Preview
Apply
Revert
Clear
```

The first implementation can combine Match and Filter if that keeps the UI
compact, but Solve should be separable from feature detection/matching.

Acceptance criteria:

- `Match` computes working images, raw matches, filtered matches, and overlays.
- `Solve` reuses the current filtered or curated matches.
- The operator can inspect pair counts before solving.
- Existing one-click behavior can remain available as a convenience only if it
  runs the same staged state machine.

### 2.2 Preserve intermediate alignment state

The app should retain:

- current request/options.
- working image metadata.
- raw match result.
- filtered match result.
- curated match mask.
- solve result.
- overlay handles.

Acceptance criteria:

- Re-solving after changing match enablement does not rerun feature detection.
- Clearing overlays does not erase match results unless the operator explicitly
  resets the alignment state.

### 2.3 Add Clear Overlays

Add a button and context-menu item to remove drawn feature and match overlays.

Acceptance criteria:

- Clear removes match lines and markers.
- Clear does not change layer OPK, projection offsets, visibility, alpha, or the
  stored solve result.
- Re-running Preview/Draw can restore overlays from stored state.

## Feature Pack 3: Match Review And Manual Curation

This is a future workflow layer after filtering and staged solving are stable.

### 3.1 Draw raw, rejected, accepted, and worst matches differently

Candidate visual states:

```text
raw only: faint gray
accepted/geometric inlier: bright
rejected: dim or hidden by default
worst residual: highlighted
selected: distinct marker and thicker line
```

Acceptance criteria:

- Catastrophic long matches are immediately visible.
- The operator can toggle rejected matches on/off for diagnosis.

Implementation note:

- The alignment panel now has overlay toggles for accepted match lines,
  rejected match lines, worst residual matches, and feature points. Accepted
  match lines and feature points default on; rejected and worst overlays default
  off. Rejected categories are drawn the same faint style for now. Worst
  highlighting uses the post-solve worst ten percent of finite residuals.

### 3.2 Add a match table

The match table should include:

- pair.
- match index.
- score.
- source rows/columns.
- working-image locations.
- residual before and after solve.
- accepted/rejected/disabled state.

Acceptance criteria:

- Sort by residual.
- Select a row to highlight its overlay.
- Disable a row and solve again without re-matching.

Implementation note:

- The GUI now includes a per-match table populated from filtered matches and
  solver residual records. Rows sort by post-solve residual, row selection
  highlights the selected correspondence, and editing the `Enabled` column
  updates session-local curated masks so `Solve` can run again without
  re-matching.

### 3.3 Add interactive match editing

Future interaction model:

- click a match overlay to select it.
- delete or disable selected matches.
- undo last disable.
- solve again with the curated set.

Acceptance criteria:

- Manual deletion updates the match table and solve input.
- Curated match state is preserved until reset or rematch.

Implementation note:

- Overlay clicks select the nearest match-table row. The alignment panel also
  has Delete and Undo controls: Delete marks selected rows as session-local
  `deleted`, excludes them from Solve, and leaves them visible in the table;
  Undo restores curation snapshots from a stack. Curation remains session-only
  and is cleared by rematching or reset.

## Feature Pack 4: Overlay State Correctness

Current overlays are diagnostic drawings tied to the state at draw time. Future
overlays should stay attached to their source observations as the viewer state
changes.

### 4.1 Reproject overlays on viewer state changes

Overlay geometry should update when:

- projection-plane tip changes.
- projection-plane tilt changes.
- selected-layer OPK changes.
- layer WASD/projection offset changes.
- preview/apply/revert changes alignment corrections.

Acceptance criteria:

- Match markers remain registered to their source layers after tip/tilt edits.
- Match lines remain meaningful after previewing or applying OPK corrections.

Implementation note:

- Overlay redraw now prefers source row/column observations and recomputes
  current projection-plane coordinates from the active scene geometry. Finalized
  projection, layer offset, preview, apply, and revert updates refresh visible
  overlays without changing stored match or solve state.

### 4.2 Add overlay visibility controls

Add toggles for:

- raw matches.
- accepted matches.
- rejected matches.
- residual vectors.
- feature points.

Acceptance criteria:

- Operators can reduce clutter without clearing stored alignment state.

Implementation note:

- Accepted, rejected, worst-residual, and feature-point overlays can be toggled
  from the alignment panel without clearing the stored match or solve state.

## Feature Pack 5: Safe Default Solve Policy

Real-data GUI defaults should prefer safe failure over visually destructive
solutions.

Candidate default policy:

- selected pair only.
- fast working image size first.
- geometric outlier filtering enabled.
- native-pixel outlier filtering enabled.
- omega/phi bounded by FOV-derived limits.
- kappa bounded by a practical default.
- warn or fail if too few geometric inliers remain.
- warn or fail if solve hits bounds with poor residual improvement.

Acceptance criteria:

- The GUI does not apply or encourage an implausible OPK solution silently.
- The operator sees whether the solve is match-limited, bound-limited, or
  residual-limited.

Implementation note:

- GUI alignment options now include a safe solve policy with a hard three
  observation solver minimum, a preferred ten solver observations per enabled
  pair, failure on OPK bound hits, and a default ten percent residual
  improvement threshold. Unsafe solves keep result diagnostics and table
  residuals visible, but are marked `failed` and leave Preview, Apply, and
  Revert disabled. Residual policy checks use the active solver loss residuals,
  including ray-3D residuals when `rayToRay3D` is selected.
- The current implementation treats the preferred ten-observation threshold as
  a failure. Reliability Pack 6 must correct that behavior so exactly three
  through nine observations produce a low-confidence warning, not an automatic
  failure. The selected common physical policy will also evaluate forward-ray
  3D diagnostics across all solver loss choices.

## First Hardening Wave Status

Feature Packs 1 through 5 are implemented. They added staged operation,
overlay clearing and visibility controls, match-table curation, delete/undo,
OPK bounds, residual diagnostics, and the GUI safe-solve gate. Those changes
remain useful safeguards, but real-data review exposed correctness and quality
problems below the UI layer. The second workstream below supersedes the old
implementation-order list and is the selected comprehensive alignment plan.

## Real-Data Audit Findings

The following findings motivate a broader alignment rework rather than another
round of threshold tuning:

1. The current `similarity`, `affine`, and `ransac` geometric choices all run
   the same median-translation displacement gate. The implementation does not
   fit the model named by the option.
2. `GeometricMaxDistancePixels` is applied to projection-plane coordinates in
   metres. The option name, threshold, and data units do not agree.
3. A fixed square working-image size is spread over the union of the selected
   layer extents. It can stretch the two projection axes differently, spend
   most samples outside useful pair overlap, and change scale and origin after
   imperceptibly small view-geometry edits.
4. Feature detection zero-fills invalid pixels but does not exclude detector
   support that overlaps the invalid-mask boundary. Features can therefore be
   created from mask edges or synthetic background.
5. Exact repeated working images are deterministic with the available MATLAB
   detectors. The observed instability is primarily geometry-dependent
   working-image regeneration, sampling, masking, and threshold cliffs rather
   than random-number state.
6. Raw rejected matches can include observations outside the other image's
   current footprint. The main viewer does not distinguish that legitimate
   diagnostic condition from a bad overlay projection.
7. Overlay reprojection falls back an entire pair to stale working-plane
   coordinates if any source observation fails. One bad endpoint can therefore
   move every displayed correspondence away from the current imagery.
8. Layer reordering physically swaps scene-array entries while stored
   alignment pairs retain numeric indices. A pure display-order change can
   consequently attach source observations to the wrong layer and move an
   accepted overlay.
9. ROI filtering refers to field names that are not produced by the current
   matcher/filter records. The GUI ROI is also a fixed central rectangle rather
   than the promised operator-drawn region.
10. The match table is built from filtered matches and cannot explain the full
    raw-to-accepted reduction or the rejection reason for every raw match.
11. Several validated options are not honored, including detector
    thresholds/scales, movable-parameter selections, reference-motion policy,
    projection-offset inclusion, and parts of diagnostics/execution.
12. The reusable/backend runner applies a solve without the GUI safe-solve
    policy. GUI and backend clients therefore do not share the same protection
    against bound-limited or otherwise unsafe corrections.
13. The current ray loss uses a closest-infinite-line helper and does not
    require positive ranges along both viewing rays. Backward intersections can
    look numerically excellent even though they are not physically valid.
14. The compact alignment panel is wider than the viewer at its default size,
    and the short table cannot support setup, complete match provenance, solve
    diagnostics, and manual review without crowding.

These are semantic issues. MATLAB static analysis is not expected to flag most
of them, so each pack needs numerical and interaction-level regression tests.

## Selected Alignment Model

### Scheduling reference is not a fixed truth anchor

The reference layer remains useful for pair scheduling, table direction, and
moving-to-reference diagnostics. It must not be treated as perfect pointing
knowledge. The default solve will allow both images to move.

For a two-image pair, separate the attitude update into differential and common
components. Conceptually, for equal-confidence images:

```text
moving update    = common update + 0.5 * differential update
reference update = common update - 0.5 * differential update
```

The exact implementation should represent the common update as a small
rotation in a shared world/platform frame and map it into each image's local
OPK convention. Applying identical numeric OPK increments is not generally
equivalent when image axes differ. With unequal pointing uncertainties, use a
covariance-weighted split so the less trusted image moves farther. The equal
half split is the minimum-adjustment result only when the two priors have equal
weight.

Dense matches improve the precision of relative alignment, but they do not by
themselves make every common pointing mode observable. The solver must inspect
weighted Jacobian rank and conditioning rather than infer observability from
match count. Varying image origins, pushbroom geometry, multiple baselines, and
heading diversity may constrain additional common modes. Any mode determined
mainly by a pointing prior or manual anchor must be reported as such.

For a multi-image solve, define the common component per connected adjustment
network and impose a covariance-weighted zero-mean constraint on the
image-specific differential components. Do not create the gauge by pinning the
scheduling reference. Report disconnected pair graphs before solving; solve
separate components only when the request explicitly permits it.

### Optimal stereo does not mean zero projection-plane disparity

Terrain relief and oblique viewing create legitimate disparity when source
rays are intersected with one flat projection plane. Forcing every matched
feature to the same plane coordinate can erase depth information and bias OPK.
The quality objective is compatible forward rays and a stable stereo display:
remove inconsistent ray skew and epipolar error while preserving disparity
that is supported by terrain relief.

The plane-based loss remains useful for coarse matching, quick preview, and
scenes that genuinely approximate the chosen plane. It should not be treated
as physical truth for relief-rich scenes.

### MAP/network adjustment and explainability

Implement the solver as an explicit network adjustment with:

- one OPK correction per participating image;
- a shared-frame common component and image-specific differential components;
- configurable covariance/regularization for common and image-specific
  corrections;
- robust data weights whose scale is defined in the units of each loss;
- parameter masks and bounds that are actually honored;
- Jacobian singular values, condition diagnostics, weak-mode labels, prior
  contribution, and data contribution in the result;
- moving-to-reference pair direction in tables and diagnostics;
- a failed result when a required mode is unobservable, a configured bound is
  hit, or the physical residual policy fails.

Do not use a fixed `1 metre` robust scale for losses with different units.
Every loss must publish its units, normalization, robust scale, and safe-solve
evaluation metric.

## Loss And Filter Modes

The planned solver modes are:

```text
projectionPlane2D
rayToRay3D
epipolarCoplanarity
```

`epipolarCoplanarity` is the new additional loss. For a match with per-sample
world-frame origins `Gm`, `Gr` and corrected unit viewing directions `vm`,
`vr`, the unnormalized coplanarity error is:

```text
(Gr - Gm) dot (vm cross vr)
```

Use an angular/Sampson-style normalization based on the baseline and the
derivatives with respect to both ray directions. This makes the residual
approximately dimensionless/angular, avoids giving long baselines arbitrary
weight solely because they are long, and remains meaningful when origins vary
by sample. Define and test explicit degeneracy handling for negligible
baselines, nearly parallel geometry, invalid rays, and nonfinite observations.

The same normalized residual may be used by an optional pre-solve
`epipolarCoplanarity` filtering stage. Because the starting pointing can have a
shared bias, the filter must not apply a tight zero-centered gate directly to
the uncorrected geometry. Use either a robust fitted residual center/scale or a
small bounded differential-attitude hypothesis with deterministic RANSAC. Keep
its stage mask and rejection reason separate from descriptor, overlap,
similarity/affine, native-displacement, manual-disable, and post-solve residual
states.

Retain `rayToRay3D` as a comparison and solve mode, but replace or wrap the
current infinite-line closest-approach behavior with explicit forward-ray
checks. The result should report both closest approach and the two signed ray
ranges. Negative or degenerate ranges are invalid, not zero-residual inliers.

All solve modes must calculate post-solve forward-ray 3D diagnostics. The
percentage-based safe residual policy should use the ray 3D metric, not native
pixel displacement, so it provides one physical evaluation criterion across
loss choices. The optimized loss and its own before/after statistics must also
remain visible.

## Real-Data Reliability Workstream

The packs in this workstream are numbered independently from the completed
historical hardening Feature Packs 1-5. Use `Alignment Reliability Pack N` in
discussion and commit messages so the two sequences cannot be confused.

### Reliability Pack 0: Observable records, units, and layer identity

#### 0.1 Add a complete match ledger

Create one immutable record for every raw descriptor match. Keep source
row/column observations, working-image observations, descriptor score/ratio,
pair direction, stable layer identity, every stage mask, rejection reasons,
manual state, and post-solve residuals. Filtering should update masks/reasons,
not destructively discard records.

Deprecate or precisely redefine legacy aggregate fields such as `Inliers` that
currently conflate solver observations with geometrically validated matches.
Serialized summaries must use the explicit stage names.

Acceptance criteria:

- The table can explain a reduction such as `372 raw -> 9 solver
  observations` match by match.
- Disabled, deleted, overlap-rejected, geometric-rejected,
  coplanarity-rejected, and residual-rejected observations remain
  distinguishable in data even though the first UI renders all
  disabled/rejected classes with the same faint style.
- Manual delete disables/removes the observation from the next solve.
- Curation history and filter provenance remain session-only; solved OPK is
  serialized for viewer load and background processing.

#### 0.2 Make units explicit

Replace ambiguous fields such as `GeometricMaxDistancePixels` when the data is
in metres. Store working-pixel, native-pixel, plane-metre, angular, and ray-metre
residuals in explicitly named fields. Reject incompatible option/data units at
validation boundaries.

#### 0.3 Introduce stable layer IDs

Store alignment pairs by serializable stable layer ID and resolve the current
scene/display index at use time. Layer ordering is a rendering concern and must
not change pair identity, match records, or solve variables. Do not put graphics
handles in layer, source, scene, session, request, or result structs.

Define backward-compatible migration for saved scenes that predate stable IDs.
Newly assigned IDs must persist on the next save and remain distinct when two
layers share a source path or display name.

### Reliability Pack 1: Geometry, ROI, and overlay correctness

#### 1.1 Reproject each observation independently

Project each source observation through its own current layer and exact sampled
ray path when available. A failed observation should mark only that endpoint or
match invalid; it must never trigger a whole-pair fallback to stale working
coordinates. Invalid or off-footprint raw records stay available in the table
and diagnostic views but are not drawn as valid matches on the main image.

#### 1.2 Make overlays invariant to layer order

Resolve every overlay endpoint through stable layer identity after reorder,
preview, apply, revert, OPK edits, projection-plane edits, and projection-offset
edits. Clicking an overlay match selects the corresponding table row. Selected
state is distinct from accepted/rejected/worst state.

#### 1.3 Implement a true ROI

Replace the fixed central rectangle with an operator-drawn projection-plane
ROI. Apply it to the actual match-ledger fields, retain the original records,
and make ROI changes a filter-stage invalidation rather than a full rematch when
possible.

Acceptance criteria:

- A pure layer reorder moves no overlay endpoint in world coordinates.
- One invalid rejected observation cannot move other overlays.
- ROI on/off and redraw are deterministic and do not access nonexistent
  fields.

### Reliability Pack 2: Stable alignment working images

#### 2.1 Use pair-specific, isotropic overlap grids

Build the working grid from useful pair overlap rather than the union bounding
box. Use equal physical resolution on both axes and a quantized/stable origin
and scale so tiny view-geometry changes do not resample the entire analysis
image unnecessarily. Keep a cache key that includes only inputs that actually
change radiometry or the analysis mapping.

#### 2.2 Compare alignment-only rendering modes before changing default

Under this explicitly scoped alignment-quality pack, compare the historical
`sparseIntensityScatteredInterpolant` working images against a full-source
inverse-warp alignment image. If the evidence warrants it, also prototype
detecting in native image coordinates and mapping observations to world rays
afterward. This comparison must not change backend semantics: backend output
continues to use full source radiometry, and alignment images never become
backend inputs.

Measure exact-repeat and small-geometry-perturbation stability, raw and
per-stage match counts, spatial coverage, visual edge/texture fidelity, solve
quality, memory, and runtime. Do not change the renderer default until the
comparison passes synthetic tests and the user reviews representative real-data
working images and match overlays.

Input needed from the user at the Pack 2 decision gate:

- identify or make locally accessible at least one representative difficult
  two-image pair, ideally including the current oblique/relief-rich case;
- identify the preferred analysis band if an input has multiple bands;
- provide any known bad regions or sensor artifacts that should not drive
  matching; and
- visually judge the side-by-side working images and match overlays, because
  repeatability and residual metrics alone cannot establish which radiometric
  representation preserves the scientifically relevant features.

No additional user input is needed before Pack 2. Local test TIFFs and
synthetic fixtures can build the comparison harness, but the renderer default
will remain unchanged if representative real data is unavailable or the result
is ambiguous.

### Reliability Pack 3: Deterministic feature extraction and matching

#### 3.1 Make feature support mask-aware

Erode or distance-gate the valid mask by detector support, reject features whose
support crosses invalid pixels, and avoid zero-fill edges becoming features.
Record mask rejection separately from descriptor and geometry filtering.

#### 3.2 Honor detector and matcher options

Apply detector metric thresholds and analysis scale, select the requested
matcher method explicitly, and keep the default exhaustive/deterministic unless
an approximate path proves repeatable and materially faster. Record the actual
detector, fallback, feature count, matcher, and thresholds used.

#### 3.3 Stabilize preprocessing and repeatability

Make intensity normalization, mask handling, feature ordering, tie-breaking,
and descriptor matching explicit and deterministic. Measure exact-repeat and
small-geometry-perturbation sensitivity for every supported detector. Detector
fallback must not change silently between runs.

Acceptance criteria:

- Exact repeated inputs produce identical feature and raw-match records.
- Every public detector/matcher option is honored and tested or removed.
- Actual detector, fallback, thresholds, feature ordering, matcher, and timing
  are recorded for explainability.

### Reliability Pack 4: Truthful geometric and coplanarity filtering

#### 4.1 Implement the named 2D models

Implement deterministic similarity and affine fits in working-pixel
coordinates with clearly defined thresholds. Treat affine as advanced because
it can absorb effects that should belong to viewing geometry. Remove the
generic `ransac` choice or define precisely which model it fits. Do not map
multiple option names to a translation-only gate.

#### 4.2 Add coplanarity filtering

Add the optional normalized epipolar/coplanarity stage described above. Compare
it with 2D similarity filtering on geometry perturbations and relief-rich
synthetic scenes. It should supplement, not silently replace, descriptor,
overlap, and 2D checks.

Acceptance criteria:

- Exact repeated inputs produce identical filter records.
- Small view-geometry perturbations do not cause large count changes unless a
  documented threshold is crossed.
- Every filter option is either honored and tested or removed from the public
  schema.

### Reliability Pack 5: Alignment Workbench and staged session

Create the approved separate, lazy, nonmodal programmatic `uifigure` Alignment
Workbench using responsive `uigridlayout` containers. Keep the main alignment
panel as a compact launcher/status surface during migration. The workbench
should provide stacked Setup, Matches, Solve, and Diagnostics views rather than
replacing one diagnostic with another.

Move workflow state into a graphics-free alignment session model with explicit
stage invalidation:

```text
setup -> match -> filter/curate -> solve -> preview -> apply/revert
```

The supported operator workflow is staged only; do not add a one-click
`Run All` path. Match and filter settings, curated masks, and solve state should show
what downstream stages are stale. Re-solving after table/manual edits must not
rerun feature detection. Cancellation should be checked within long matching
and solve operations where MATLAB APIs permit it, not only between stages.

UI contracts:

- Accepted matches and feature points default on.
- All rejected/disabled classes are initially drawn with one faint style.
- Worst residuals are post-solve and default to the worst ten percent.
- Table/manual state supports re-solve.
- Overlay selection and table-row selection are bidirectional.
- Delete disables the selected match; Undo restores session state.
- Match/filter history is not serialized yet; applied/solved OPK is.

### Reliability Pack 6: Balanced network solve and physical safety

#### 6.1 Implement common and differential attitude variables

Replace the implicit all-image least-adjustment behavior with the selected
shared-frame common plus image-specific differential model. Both images move by
default. Equal priors reproduce a half split; unequal priors reproduce the
covariance-weighted split. The scheduling reference remains free unless the
caller explicitly supplies a near-zero covariance as an intentional control
case.

#### 6.2 Add the epipolar/coplanarity loss

Expose `epipolarCoplanarity` in the validated options, reusable solver, GUI,
result model, and backend request path. Include normalized per-match residuals,
degeneracy flags, robust weights, and comparison diagnostics against plane 2D
and forward-ray 3D metrics.

#### 6.3 Enforce observability and parameter contracts

Honor `MovableParameters`, `AllowReferenceMotion`, shared scale, and configured
bounds. Calculate a weighted numerical/analytic Jacobian at the start and
solution, inspect singular values, and report which common or differential
modes are data-observed, prior-dominated, or unobservable. Do not silently solve
an unconstrained parameter through regularization alone.

#### 6.4 Unify GUI and backend safety

The reusable runner must return a proposed solution and apply the same safe
policy before any GUI or backend caller mutates a scene. Fewer than three
observations is a hard failure. The preferred minimum is ten per enabled pair;
exactly three through nine is explicitly low-confidence and warned, but is not
an automatic failure. Any OPK bound hit fails the solve. Keep the
residual-improvement threshold configurable and percentage-based, evaluated
with post-solve forward-ray 3D diagnostics.

Acceptance criteria:

- A shared pointing-bias synthetic case does not arbitrarily assign the entire
  correction to the moving image.
- Equal-confidence data produces the expected half split; unequal covariance
  moves the less trusted image farther.
- Weak common modes are reported rather than hidden by a nominal convergence
  flag.
- The backend cannot apply a solution that the GUI would mark unsafe.

### Reliability Pack 7: Shift+left common anchor drag

Add an explainable manual common-mode correction to the main viewer:

```text
Shift + left drag: move the selected stereo correspondence/anchor together
```

Initial interaction contract:

1. The interaction is active only when the alignment session has an enabled
   pair and a selected accepted correspondence. A Shift+left press may snap to
   the nearest accepted overlay inside a documented hit radius; otherwise the
   status tells the operator to select a match rather than silently panning.
2. On mouse down, capture stable layer IDs, the two source observations, the
   current projection plane, current OPK corrections, common/differential
   decomposition, and the correspondence's two current plane endpoints.
3. Define the grabbed location as the confidence-weighted stereo centroid. As
   the cursor moves on the projection plane, solve only a shared-frame common
   boresight update so the centroid follows the cursor. Keep the differential
   OPK component fixed and penalize changes in displayed disparity; do not
   force relief-supported endpoint separation to zero.
4. A single anchor provides two independent screen/plane constraints. The first
   implementation therefore adjusts a two-degree-of-freedom common boresight
   correction and holds common twist/kappa fixed. A future second separated
   anchor could make common twist observable.
5. Use a cached local Jacobian and lightweight preview updates during motion,
   then run an exact bounded refinement on mouse release. If the refinement is
   ill-conditioned, hits a bound, or materially degrades the forward-ray 3D
   residual, restore the mouse-down state and explain why. A common anchor is
   an absolute-placement constraint, so it is not required to improve the
   relative ray residual by the automatic solve's configured percentage.
6. Commit one undoable manual adjustment on release. Update both images' OPK
   correction state without mutating base source origins/rays or
   `ProjectionOffsetMeters`. Mark prior solve diagnostics stale, preserve source
   match observations and curation, reproject overlays, and allow staged
   filter/re-solve without rematching.

The result/session diagnostics should report the anchor match ID, target and
achieved plane coordinates, OPK changes for both images, which common modes
were adjusted, conditioning, bounds, and before/after forward-ray residuals.
Only final OPK corrections participate in normal viewer-state serialization;
manual drag provenance/history remains session-only for now.

Acceptance criteria:

- Shift+left does not conflict with plain pan, Control+left layer translation,
  or Alt/Option+left selected-layer OPK drag.
- Both images move in the common direction while their differential correction
  remains fixed within tolerance.
- The grabbed stereo centroid follows the cursor without collapsing legitimate
  disparity.
- Common kappa is unchanged for the one-anchor implementation.
- Cancel, invalid geometry, and failed release refinement restore the exact
  starting corrections.
- The gesture uses the existing differential viewer refresh path and remains
  responsive on large tiled imagery.

### Reliability Pack 8: Real-data validation and documentation

Build a repeatable validation matrix covering detector choice, loss choice,
small geometry perturbations, ROI, layer reorder, manual curation, common-anchor
drag, pair and multi-image schedules, and saved/background application. Record
raw and per-stage counts, correction split, observability, residuals, bounds,
runtime, and failure reason.

Include synthetic cases for:

- pure differential attitude error;
- shared/correlated pointing bias plus differential error;
- equal and unequal pointing covariance;
- fixed-reference comparison as a non-default control;
- varying pushbroom origins and multiple baseline directions;
- near-zero baseline, near-parallel rays, and behind-origin intersections;
- oblique relief where valid plane disparity must remain;
- exact-repeat and tiny-geometry-perturbation matching;
- layer-order invariance and one-invalid-endpoint overlays;
- common-anchor success, rollback, bound hit, and weak common twist.

Manual validation should use representative 100-150 MP primarily
single-channel imagery on the intended high-end Windows workstation. Alignment
working images remain bounded analysis products; no validation or optimization
may route them into backend output.

## Required Implementation Order

Implement and validate one small coherent sub-pack at a time:

1. Reliability Pack 0: records, units, and stable layer identity.
2. Reliability Pack 1: overlay, reorder, and ROI correctness.
3. Reliability Pack 2: stable working images and the sparse-versus-full-source
   decision gate.
4. Reliability Pack 3: deterministic mask-aware feature extraction and
   matching.
5. Reliability Pack 4: truthful 2D models and coplanarity filtering.
6. Reliability Pack 5: separate staged Alignment Workbench/session.
7. Reliability Pack 6: balanced network solver, epipolar loss, observability,
   and unified safety.
8. Reliability Pack 7: Shift+left common anchor drag.
9. Reliability Pack 8: full real-data validation and operator documentation.

For each sub-pack: inspect the relevant source/tests, implement only that scope,
add focused tests, run targeted tests, run `runTests`, update documentation,
commit with a clear `Alignment Reliability Pack N: ...` message, and push only
after validation. Stop for user judgment if real data contradicts the selected
model or a new design choice materially changes these contracts.

## Decisions And Deferred Scope

Decided:

- Both images move by default; the scheduling reference is not fixed truth.
- Equal-confidence differential correction is split halfway; covariance priors
  generalize the split.
- Direction is moving-to-reference.
- `epipolarCoplanarity` will be an additional loss and optional filter stage.
- The common-anchor gesture is Shift+left drag and adjusts both images' OPK.
- The one-anchor gesture preserves differential correction/disparity and does
  not solve common kappa.
- Fewer than three observations is a hard failure; three through nine is a
  warning; ten is the preferred minimum.
- Bound hits fail; residual thresholds remain configurable percentages and use
  forward-ray 3D diagnostics.
- The workflow is staged only.
- Rejected/disabled classes share one faint initial style; accepted matches and
  feature points default visible; worst means post-solve worst ten percent.
- Diagnostics stack, overlay/table selection is synchronized, and manual delete
  disables the match for re-solve.
- Solved/applied OPK is serialized. Match history, curation history, anchor-drag
  history, and filter provenance are session-only for now.
- A separate Alignment Workbench is approved, with the compact main panel
  retained as launcher/status during migration.
- Sparse versus full-source inverse-warp working images will be evaluated in
  Reliability Pack 2 before the alignment renderer default changes.

Deferred:

- DEM/terrain-constrained adjustment is out of scope for Reliability Packs
  0-8. It may be reconsidered later as an optional absolute constraint and
  must not be assumed available by the solver.
- A second manual anchor or multi-anchor interaction that observes common twist
  is future work.
- A `planeTie` drag that intentionally collapses both endpoints onto one plane
  point is not the common-anchor gesture. It may be considered later as a
  separately labeled opt-in constraint because it asserts that the selected
  feature lies on the projection plane and can erase valid terrain disparity.
- Sensor-specific native-displacement thresholds and calibrated pointing
  covariance defaults require representative real-data measurements. Until
  then, expose their source and units and use conservative documented defaults.
