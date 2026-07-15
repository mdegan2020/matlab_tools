# Real-Data Interaction Continuity Workplan

Status: implementation in progress July 15, 2026.

## Purpose

Correct the presentation and interaction defects found during the next
five-image real-data workflow after the post-RD-7 Surface Recovery release.
The required outcome is continuous 3-D navigation after presentation changes,
predictable anaglyph defaults for every pair, stable camera framing while
following a pair sequence, and a mouse-following stereo cursor whose signed
height is visible without obscuring the imagery.

## Operator Evidence

The reported sequence was:

1. The Surface 3-D Viewer initially rotated normally.
2. After presentation changes, including switching color from world `Z` to
   HAE, the viewer eventually stopped responding to rotation.
3. The 3-D viewer, Surface Workbench, Alignment Workbench, and dataset all
   closed or saved normally, so the observed failure was limited to viewport
   interaction rather than application shutdown or scientific-state storage.
4. Pair View anaglyph presentation worked, but the red-eye surface did not
   start at the desired 50 percent alpha for each new pair.
5. Camera-follow pair changes recomputed the viewport center and zoom, making
   scene changes difficult to track.
6. The stereo cursor remained at a placed anchor instead of following the
   pointer, its signed plane height was not in the persistent bottom-right
   readout, and the standard white arrow competed visually with the cursor.

No private imagery, coordinates, or collection metadata are reproduced in
this workplan or its automated fixtures.

## Structural Diagnosis

### Surface 3-D Viewer interaction lifetime

Every presentation control refresh deletes the viewer-owned data objects and
then calls `cla` on the `UIAxes`. The axes owns the configured rotate/data-tip
interactions and toolbar; clearing the complete axes unnecessarily resets
interaction-owned state while the viewer immediately reuses the same axes.
The viewer already tracks every primary, comparison, and glyph handle, so it
can refresh those owned objects without clearing the axes. The reported HAE
switch is therefore treated as a trigger for the broad refresh path, not as a
problem with HAE coordinate conversion.

### Anaglyph alpha

The current preview applies a presentation-only 0.70 alpha cap to every
visible anaglyph surface. It does not establish a red-eye layer alpha or
synchronize the Alpha slider. Pair turnover can therefore inherit arbitrary
stored alpha values. The correction must resolve physical eye assignment by
stable `ViewId`, set the red-eye layer to 0.50, select that layer so the slider
truthfully represents it, and leave the cyan layer's alpha unchanged.

### Camera-follow continuity

Pair-follow currently applies each pair's complete fitted camera plan,
including a newly fitted target and view angle. Pair direction should follow
the active sensor geometry, but an operator-adjusted viewport target and
world-space view height should carry across pair changes. Preserving only the
numeric view angle is insufficient when pair camera distance changes.

### Stereo cursor interaction

Pointer motion callbacks are installed only for crosshair, drag, and motion
edge-hover modes. Stereo-cursor enablement does not request motion callbacks,
so its plane anchor cannot follow the mouse. The existing cursor model already
owns the authoritative signed height and stable-pair projection; the required
change is runtime interaction wiring and presentation. MATLAB `uifigure`
supports a built-in `crosshair` pointer, which is less intrusive than the
standard arrow and avoids an unsupported platform-specific custom cursor.

## Authority And Non-Negotiable Contracts

- HAE, ENU, world `Z`, vertical exaggeration, camera state, pointer shape, and
  cursor graphics remain presentation concerns. Authoritative surface
  coordinates and covariance are unchanged.
- The stereo cursor height remains signed metres along projection-plane `VN`.
  The readout may say above/below, but it must retain the sign and plane-normal
  meaning.
- Physical red/cyan assignment continues to come from stable view identity and
  sensor geometry, independent of layer order and moving/reference roles.
- The red-eye 0.50 alpha is applied to the active pair's scene layer and shown
  by the Alpha slider; no hidden second alpha contract is introduced.
- Camera-follow continuity is runtime-only. It must not mutate OPK, projection
  planes, pair evidence, corrections, or backend geometry.
- Stereo cursor anchor, height, projections, pointer shape, and overlays remain
  runtime-only and absent from serialized scientific state.
- All refresh paths retain deterministic cleanup and one-instance lifecycle
  behavior.

## Ordered Milestones

### IC-0 — Workplan and regression matrix

1. Record the operator sequence and structural diagnosis without claiming an
   exact private-data reproduction.
2. Freeze focused automated tests before implementation:
   - repeated Surface Viewer color/display/decimation/comparison refreshes keep
     rotate and data-tip interactions installed and preserve the camera;
   - pair entry and turnover set the physical red-eye layer and Alpha slider
     to 0.50;
   - tracked pair turnover preserves viewport target and world-space view
     height while changing pair orientation;
   - an enabled stereo cursor follows pointer-plane motion, exposes signed
     height in the bottom-right OPK readout, uses `crosshair`, and restores the
     prior pointer on disable.

Exit criterion: this committed plan is the implementation and acceptance
source of truth.

### IC-1 — Surface Viewer interaction continuity

1. Replace broad axes clearing with deletion of viewer-owned render handles.
2. Centralize and reassert standard rotate/data-tip interactions and toolbar
   availability after component creation and presentation refresh.
3. Preserve camera state for color, comparison, decimation, inspect, and
   vertical-exaggeration changes within one display frame.
4. Keep display-frame changes free to refit because their coordinates and
   labels change.

Exit criterion: repeated presentation changes retain live standard
interactions and camera persistence in a focused UI test.

### IC-2 — Pair presentation defaults and camera continuity

1. Resolve the active physical red-eye layer after Pair View reconciliation.
2. Set its scene alpha to exactly 0.50 for initial Pair View and every pair
   turnover, select it, synchronize the Alpha slider/label, and render that
   alpha without an additional global anaglyph cap.
3. Before applying a followed pair plan, capture the current target and
   world-space view height. Apply the new pair direction/up vector around the
   preserved target and derive the new view angle needed to preserve scale.
4. Retain explicit Apply/Restore behavior and the current follow-suspension
   rules for manual navigation within a pair.

Exit criterion: focused motion-workflow tests prove stable red alpha, slider,
target, and scale across pair changes, with no camera drift on return.

### IC-3 — Mouse-follow stereo cursor and unobtrusive pointer

1. Make stereo-cursor enablement install the pointer-motion callback.
2. While the pointer is over the viewport, update only the cursor's plane
   anchor; retain its bounded signed height and refresh both-eye projections.
3. Append a signed `above`/`below` plane-height line to the bottom-right OPK
   readout while the cursor is enabled, while retaining the detailed
   projection-status overlay.
4. Use MATLAB's built-in `crosshair` figure pointer while enabled and restore
   the previous pointer when disabled, reset, imported, or closed.

Exit criterion: focused UI tests prove pointer-follow, readout content,
crosshair use/restoration, stable height, and runtime-only serialization.

### IC-4 — Integrated validation and delivery

1. Run MATLAB Code Analyzer on modified source and tests.
2. Run focused Surface Workbench, motion workflow, and stereo-cursor workflow
   tests in fresh MATLAB processes/classes.
3. Run all six authoritative repository groups separately:
   `coreGeometryState`, `alignment`, `backendSurface`, `viewerAlignmentUi`,
   `viewerPresentationWorkflows`, and `viewerPerformancePrecision`.
4. Update operator documentation, requirements, and project status with the
   delivered behavior and any remaining private-data/manual confirmation gate.
5. Commit by milestone, push `main`, and verify the local branch is clean and
   synchronized with `origin/main`.

Exit criterion: all automated gates pass and the pushed main branch contains
the implementation and documentation.

