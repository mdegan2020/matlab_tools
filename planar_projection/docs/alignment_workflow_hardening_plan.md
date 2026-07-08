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
- Do not introduce process-based parallel pools.
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

### 3.3 Add interactive match editing

Future interaction model:

- click a match overlay to select it.
- delete or disable selected matches.
- undo last disable.
- solve again with the curated set.

Acceptance criteria:

- Manual deletion updates the match table and solve input.
- Curated match state is preserved until reset or rematch.

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

### 4.2 Add overlay visibility controls

Add toggles for:

- raw matches.
- accepted matches.
- rejected matches.
- residual vectors.
- feature points.

Acceptance criteria:

- Operators can reduce clutter without clearing stored alignment state.

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

## Suggested Implementation Order

1. Add Clear Overlays.
2. Add staged Match and Solve state in the GUI while preserving the current
   all-in-one helper internally if useful.
3. Enable geometric outlier filtering by default and fix "inlier" terminology.
4. Add native-pixel displacement outlier filtering.
5. Add FOV-derived OPK bounds and bound-hit diagnostics.
6. Add worst-residual diagnostics and table-ready match records.
7. Add match table and manual disable/re-solve.
8. Make overlays update when projection or layer state changes.

## Validation Strategy

Unit tests should cover:

- match-filter stage counts.
- catastrophic outlier rejection.
- native displacement filtering.
- OPK bound construction from source geometry metadata.
- bound-hit diagnostics.
- solve reusing filtered or curated matches.
- clear-overlays behavior.

Manual validation should include:

- synthetic red/blue harness.
- real two-layer data with known large outlier matches.
- selected-pair flow.
- visible-layer flow.
- ROI-on and ROI-off runs.
- preview, apply, revert, and clear overlay interactions.

## Open Questions

- Should the first geometric filter use similarity, affine, or a custom
  projection-plane residual model by default?
- What should the default native-pixel displacement cap be for each sensor or
  FOV regime?
- Should FOV-derived OPK bounds be editable from the compact GUI, or only from
  an advanced options dialog later?
- Should a one-click "Run All" remain after the staged workflow is added?
- Should curated match state be serializable in viewer state, or kept as
  session-only diagnostic state?
