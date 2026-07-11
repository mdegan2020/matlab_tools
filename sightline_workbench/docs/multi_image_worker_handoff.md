# Sightline Workbench Worker Handoff: Multi-Image Foundation

Status: completed. MI-0 through MI-3 and the optional SDK audit were committed
and pushed through `5a45b75`. Do not rerun this historical handoff; continue
from `docs/multi_image_surface_reconstruction_workplan.md`.

## Mission

Implement only the currently approved, unblocked foundation for the future
multi-image workflow. Work in small packs, validate each pack, commit it, and
push it before beginning the next pack. Do not implement plane replacement or
reorientation, motion-imagery behavior, global multi-image solving, dense
fusion, or the not-yet-finalized SDK correction/matcher APIs in this task.

The primary planning source for this task is:

```text
docs/multi_image_surface_reconstruction_workplan.md
```

The locked decisions are collected in section 22. The working planner may
continue refining `/private/tmp/sightline_multi_image_surface_workplan.md`, so
do not edit that temporary file.

## Mandatory Start

Work only inside:

```text
/Users/matt/projects/matlab_tools/sightline_workbench
```

Before editing, run and inspect:

```text
pwd
git rev-parse --show-toplevel
git status --short
git log -10 --oneline --decorate
```

Read completely:

```text
Agents.md
README.md
docs/project_status.md
docs/viewer_development_plan.md
docs/alignment_workflow_hardening_plan.md
docs/performance_optimization_workplan.md
docs/dense_surface_feature_pack.md
docs/dense_surface_synthetic_expansion_plan.md
docs/multi_image_surface_reconstruction_workplan.md
tracked_issues.md, if present
```

At handoff creation, `main` and `origin/main` were at `7ab40ff`, the worktree
was clean, Backend Performance Packs 0-5 and Dense-Surface Synthetic Milestones
1-5 were complete, and the documented fresh-class suite passed 457/457. Verify
rather than assuming this remains current.

## Non-Negotiable Constraints

- Preserve current lightweight viewer launch compatibility.
- Preserve existing public `PlanarProjection` and `Projection*` names.
- CPU behavior remains complete and tested.
- GPU support remains optional and capability-checked.
- Only `parpool("threads")` may be used; do not introduce process pools.
- Full source imagery and configured output grids remain backend radiometric
  inputs. Never substitute previews, pyramids, alignment working images, or
  dense products.
- Keep graphics handles and runtime caches out of serializable structures.
- Do not expose or commit private synthetic-fixture values.
- Preserve unrelated user changes. Stop if the worktree contains overlapping
  uncommitted edits.
- Use focused tests first, then the full fresh-class validation appropriate to
  the pack.
- Commit and push after every completed pack. Stop on validation failure or a
  design ambiguity that would change a public contract.

## Pack MI-0: Stable Multi-Image Identity And Optional Timing

Audit existing scene/layer/source/alignment models and add the smallest
compatible contract needed for:

- stable `ViewId`, preserving a supplied value and generating one when absent;
- explicit optional `PassId`, defaulting all unspecified views to one pass;
- a stable unordered pair identity independent of moving/reference role;
- optional acquisition start time and line rate per image;
- derived per-line time using image dimensions and scan-axis/direction metadata;
- relative or absolute time without requiring UTC; and
- explicit capability/status reporting when timing is unavailable.

Do not require these optional fields for the existing array/name/geometry/plane
launch path. Do not infer pass identity from filenames. Prefer pure
normalization/validation/time-sampling helpers and reuse existing value models
instead of creating a parallel scene representation.

Focused tests must cover supplied/generated identity stability, layer reorder,
duplicate/malformed IDs, default and explicit pass grouping, relative/absolute
time, scan direction, missing timing, serialization if applicable, and legacy
launch compatibility.

Commit and push this pack before continuing.

## Pack MI-1: Pair Schedule And Runtime Controller

Add a GUI-independent runtime pair/schedule model using the MI-0 identities.
It must support:

- reference and moving roles separate from unordered pair identity;
- pair enabled/disabled and status fields;
- direct selection and swap without running Match, Solve, Apply, or Re-match;
- deterministic previous/next stepping;
- default grouping order: same-pass temporal neighbors, same-pass chords,
  cross-pass pairs, then remaining custom/all-pair candidates;
- normal skipping of disabled pairs plus an explicit review mode that includes
  them; and
- schedule replacement only on explicit regeneration.

Keep the schedule runtime-only in this first pack unless an existing alignment
session model already has a safe serializable home. Do not build the expensive
pair-candidate scorer or global solver here.

Focused tests must cover determinism across layer reorder, role swap identity,
disabled stepping, end behavior, explicit selection, schedule regeneration,
and absent timing fallback to stable view order.

Commit and push this pack before continuing.

## Pack MI-2: Alignment Workbench Active Pair And Solo Pair

Integrate the runtime controller into a compact bar at the top of the Alignment
Workbench with reference/moving selectors, Swap, previous/next, pair status,
enabled state, and `Solo pair`. Do not add permanent pair controls to the main
viewer.

Changing pairs updates pair inspection state and overlays only; it must not run
matching or mutate correction state. Reject selection of the same view in both
roles.

`Solo pair` must:

- capture the complete runtime layer-visibility state;
- show the active pair and retain required non-image alignment overlays;
- follow active-pair changes while soloed;
- restore surviving layers exactly on exit or workbench/viewer close;
- handle layers added/deleted during solo mode safely; and
- remain outside serialized scene/layer/source state.

Add focused pure-state tests and GUI workflow tests. Confirm existing workbench
layout remains clean at representative window sizes and that no matching,
render-cache rebuild, or correction application is triggered merely by pair
navigation.

Commit and push this pack before continuing.

## Pack MI-3: Stereo Eye Assignment Separation

Only begin after MI-2 is complete. Reuse the existing baseline-aware anaglyph
implementation and separate:

- reference/moving alignment roles;
- layer order; and
- left/right stereo eyes.

Derive left/right from representative sensor origins projected onto current
camera horizontal, keep red assigned to the left eye, retain the prior result
with hysteresis near head-on degeneracy, and add a clearly marked resettable
manual override in the Alignment Workbench. Swapping reference/moving must not
swap eyes unless the physical ordering changes.

If representative-origin behavior cannot reuse the existing center-sample
rule without prematurely fixing the still-open plane/pair-viewpoint contract,
stop after MI-2 and report the exact ambiguity rather than guessing.

Commit and push this pack if completed.

## Optional Read-Only SDK Audit

If MI-0 through MI-3 finish without blockers, inspect the current public and
headless MATLAB entry points for viewer launch, matching, solving, correction
application/export, dense matching, and dense extraction. Report proposed
reuse points and compatibility risks to the user. Do not implement the new
correction-result or dense-matcher SDK contracts yet; their detailed lifecycle
will be decided in the ongoing planning thread.

## Final Report

For each pack, report commit hash, pushed branch, focused/full validation,
files changed, and any deferred ambiguity. Include final `git status --short`.
