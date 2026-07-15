# Sightline Workbench Project Status

This is the concise current-status index for Sightline Workbench. Detailed
design history remains in the linked workplans; historical deliverable lists
should not be mistaken for unfinished implementation.

## Current Baseline

As of July 15, 2026:

- The project directory is `sightline_workbench`; the main application title is
  **Sightline**.
- The public `PlanarProjection` and `Projection*` MATLAB APIs retain their
  existing names for compatibility.
- CPU execution is the required and tested path.
- GPU acceleration remains optional and capability-checked.
- Any MATLAB parallel pool used by the backend is
  `parpool("threads")`; process-based pools are unsupported.
- Graphics handles and runtime caches remain outside serializable
  scene/layer/source structures.
- Backend radiometry defaults to full-source inverse warp. Display pyramids,
  preview tiles, alignment working images, and dense-surface products never
  become backend radiometric inputs.
- The latest grouped fresh-class repository suite passes 797/797 tests with
  zero failures and zero incomplete tests.
- The post-RD-7 Surface Recovery implementation is complete. SR-0/SR-1 replace
  repeated global dense-association scans with bounded indexed work, and
  SR-2/SR-3 add
  explicit portable world/display frames, truthful ENU/HAE/world-Z semantics,
  standard 3-D navigation/inspection, and defensive standalone MAT reopening.
  SR-4/SR-5 add transactional tiled-surface ownership, exact graphics audit,
  and presentation-only viewport rebuild. SR-6 privacy-safe automated
  validation is complete; representative private-data confirmation and the
  exact template-matcher failure remain external release gates.
- The subsequent Interaction Continuity IC-0 through IC-4 correction is
  complete. Surface Viewer presentation refreshes retain standard navigation;
  anaglyph pairs select the physical red layer at 0.50 scene alpha; Track
  camera preserves viewport target and scale across pair changes; and the
  stereo cursor follows the mouse with a crosshair pointer and signed
  above/below-plane height in the OPK readout.
- `docs/real_data_validation_followup_workpack.md` is the completed RD corrective
  queue. RD-2, RD-3, RD-1, and RD-4 are complete: the default network
  path is bounded and observable, active tiled presentations reconcile against the
  current camera before display, playback lookahead rejects stale requests,
  the main viewer owns one idempotent child/timer shutdown path, and implicit
  real-data cameras use the side-invariant explicit-plane presentation
  convention, and the default-open Layer Manager now owns selection,
  visibility, runtime View All/Single/Pair presentation, playback, and pair
  camera tracking. RD-5 now supplies a scene-bound Surface Workbench Run/Cancel,
  retained evidence, exact pair/method provenance, multi-ray/fusion
  orchestration, and MAT/JSON export. RD-6 adds a
  runtime-only world-space stereo cursor with stable-pair projection, signed
  plane-normal height, physical-eye marks, bounded controls, and explicit
  invalid states. RD-7A/B/C/G now correct presentation visibility/order,
  Alignment Workbench persistence/status, multi-image Surface Workbench launch,
  reviewable correction actionability, analysis-safe source levels,
  full-source refinement/diverse evidence selection, and end-to-end work
  accounting. RD-7 is complete; independent D2 native CPU work may resume.
- Multi-image foundation MI-0 adds optional stable `ViewId`, explicit `PassId`,
  unordered pair identity, and per-line timing metadata while preserving the
  existing viewer launch signature and legacy `LayerId` contracts.
- Multi-image foundation MI-2 adds an Alignment Workbench active-pair bar and
  stable-ID runtime Solo-pair visibility without changing serialized scene
  visibility, matching state, corrections, or projection caches during pair
  navigation.
- Multi-image foundation MI-3 separates physical stereo eyes from
  moving/reference roles and layer order, preserves red-left assignment with
  head-on hysteresis, and provides runtime-only manual swap/reset controls.

## Completed Feature Trees

| Workstream | Current state |
| --- | --- |
| Original viewer milestones 1-6 | Complete |
| Backend Milestones 1-10 | Complete |
| Auto Alignment Milestones 1-13 | Complete |
| Initial Alignment Hardening Feature Packs 1-5 | Complete |
| Alignment Reliability Packs 0-8 | Complete |
| Viewer Performance Packs 0-8 | Complete |
| Backend Performance Packs 0-5 | Complete |
| Dense Surface Pack 1 | Complete |
| Viewer Orientation and Anaglyph Presentation Pack | Complete |
| Alignment Workbench Usability and Offset-Semantics Pack | Complete |
| Cross-System Acceleration Pass | Complete |
| Dense-Surface Synthetic Expansion Milestones 1-4 | Complete |
| Dense-Surface Synthetic Milestone 5 implementation/evidence | Complete |
| Dense-Surface Synthetic acceptance-threshold proposal | Complete |
| Multi-Image Foundation MI-0 | Complete |
| Multi-Image Foundation MI-1 | Complete |
| Multi-Image Foundation MI-2 | Complete |
| Multi-Image Foundation MI-3 | Complete |
| Multi-Image A2 pair viewpoint | Complete |
| Multi-Image A3a-1 focus-aware keyboard mapping | Complete |
| Multi-Image A3a-2 manual motion imagery | Complete |
| Multi-Image A3b measured motion playback | Complete |
| MATLAB SDK S1 immutable CorrectionSet | Complete |
| MATLAB SDK S2 correction lifecycle and notification | Complete |
| Multi-Image A4 conflict-safe tracks and path diagnostics | Complete |
| Multi-Image A4 explainable quality pair graph | Complete |
| Multi-Image A5 global constant-OPK network solve | Complete |
| Multi-Image A6 pass-aware priors and reporting | Complete |
| Multi-image synthetic acceptance matrix | Complete |
| Logical MATLAB test-suite grouping | Complete |
| P0 precision inventory | Complete |
| P1 viewer long-range precision validation | Complete |
| MATLAB SDK S3 dense matcher base/current SGM adapter | Complete |
| B0 truth-aware SGM audit | Complete |
| B1 dense pair and sparse-seeded search planning | Complete |
| B2 classical dense template matcher | Complete |
| B3 pairwise point covariance and conditioning | Complete |
| B5 dense multi-view association and robust multi-ray solve | Complete |
| S6 surface-fusion extension and B4 bounded voxel audit | Complete |
| B6 Surface Workbench and runtime-only 3-D viewer | Complete |
| S7 DEM-registration extension and B7 robust DEM registration | Complete |
| B8 explicit DEM-derived position-correction application | Complete |
| A7 bounded time-varying OPK research | Complete; production apply gated |
| C0 notation and equation inventory | Complete |
| C1 IEEE-style mathematical manuscript and compiled PDF | Complete |
| C2 procedural two-image/anaglyph oracle and golden parity | Complete |
| C3 multi-image/dense mathematical appendices | Complete |
| D0 portable native CPU/C ABI/CMake foundation | Complete on macOS; Windows/WSL/Ceres evidence gated |
| Real-data follow-up RD-2 bounded network solve | Complete |
| Real-data follow-up RD-3 LOD/lifecycle correctness | Complete |
| Real-data follow-up RD-1 explicit-plane camera orientation | Complete; representative real-data confirmation pending |
| Real-data follow-up RD-4 Layer Manager/viewer shell | Complete |
| Real-data follow-up RD-5 dense-surface controls/evidence/recovery | Complete; representative-imagery usefulness review pending |
| Real-data follow-up RD-6 world-space stereo cursor | Complete |
| Real-data follow-up RD-7A presentation correctness | Complete |
| Real-data follow-up RD-7B persistent Alignment Workbench | Complete |
| Real-data follow-up RD-7C multi-image Surface Workbench launch | Complete |
| Real-data follow-up RD-7D through RD-7F measurement/performance path | Complete |
| Real-data follow-up RD-7G correction actionability | Complete |
| Post-RD-7 Surface Recovery SR-0 through SR-5 | Complete |
| Post-RD-7 Surface Recovery SR-6 | Automated validation complete; private/template evidence gated |
| Real-data Interaction Continuity IC-0 through IC-4 | Complete; representative private-data confirmation pending |

The alignment system now includes stable match provenance, current-geometry
overlays, a staged Alignment Workbench, deterministic mask-aware matching,
truthful similarity/affine and coplanarity filtering, balanced
common/differential solving, unified GUI/backend safety, Shift+left common
anchor adjustment, synthetic oblique-terrain validation, and CPU SGM
dense-surface exploration.

The viewer performance work includes demand-driven crosshairs, latest-state
camera scheduling, LOD hysteresis and halo retention, cached/vectorized tile
visibility, differential surface reuse, bounded runtime caches/pools, targeted
geometry invalidation, coalesced alpha rendering, lazy UI/pyramid storage,
scalar single-band textures, and the decision to keep raster preview optional.
RD-3 extends that contract to every active motion frame, Solo pair, visibility
transition, and ordinary selection: desired LOD is recomputed from the current
camera/viewport/generation even when a valid stale surface exists, replacement
is coherent with no blank transition, and one bounded next-frame lookahead is
keyed by camera, geometry, desired/applied LOD, and tile identity. The main
viewer close callback now routes through the same idempotent cleanup as
programmatic deletion, stops preview/playback callbacks and timers, closes
viewer-owned children, and leaves independent caller-owned figures untouched.
The completed orientation/anaglyph pack extends twist to `+/-85` degrees,
assigns the left-eye layer to red from the current-view sensor baseline,
brightens the preview, and provides runtime-only separation/depth controls
without rebuilding projection geometry or changing serialized/backend state.
The RD-1 correction now gives verified implicit real-data cameras a
presentation-only, viewing-side-invariant screen basis. It declares the
`LL, LR, UR, UL` ground-corner, image-row, camera-look, monitor-up/right, and
focal-plane handedness convention; equivalent normal reversal cannot rotate
the display by 180 degrees. Distinct caller-supplied cameras remain
authoritative, while plane/source/OPK data, backend pixels, and procedural
anaglyph outputs remain unchanged. Representative private real-data
confirmation is still required before removing the operator advisory; see
`docs/real_data_validation_followup_workpack.md`.

RD-4 removes the redundant hidden alignment launcher, makes
`Alignment Workbench...` a direct one-instance context command, and opens the
nonmodal Layer Manager with every viewer. The manager owns stable-ID layer
selection/order, stored individual and bulk visibility, sequence filtering,
playback, and runtime-only View All, Single View, and overlapping Pair View
masks. Pair View fits the initial tracked camera and then preserves the
operator's viewport target and world-space zoom while adopting each new pair's
direction. It re-runs physical-eye red/cyan assignment after pair turnover and
sets/selects the physical red layer at 0.50 scene alpha with a synchronized
Alpha slider. View All draws a clipped yellow
selected-footprint outline above the image stack without radiometric rerender;
the checked viewport command can hide it, and Single/Pair modes suppress it
automatically. Both Single and Pair modes retain hover or persistent edge
navigation controls. The main figure title is now `Sightline`.
The main viewer retains only a compact Tip/Tilt/Twist/Alpha strip and a disabled
bottom-right OPK overlay so ordinary viewport input passes through.

The Alignment Workbench now exposes only the one-instance **Surface
Workbench...** launch for dense and 3-D extraction; the former direct
Selected-pair SGM action has been retired. The scene-bound runner uses the
existing dense-matcher SDK, stable observation association, multi-ray
reconstruction, fusion SDK, uncertainty, catalog, and 3-D viewer. Its explicit
Run/Cancel lifecycle preflights exact stable pairs, matcher/search policies,
rectification, execution/fallback, bounds, and requested products; completed
runs retain pair images/masks, disparity/score/confidence, ray and height
diagnostics, exact counts/states, and generation provenance. MAT export retains
the complete evidence and compact JSON omits only image-sized arrays. The
deterministic five-image fixture names and processes all ten pairs before
multi-ray/fusion. No smoothing, hole filling, or forced DEM is used, and
representative private imagery remains an external usefulness gate.

The viewport context menu also provides a runtime-only **Invert desired up and
reset camera** safeguard. `ProjectionViewerApp.addImage` appends compatible
image/source-geometry inputs to an open viewer, regenerates view/pair and Layer
Manager state, preserves existing scientific layer state and camera pose, and
extends Reset. Addition is rejected while a correction lifecycle is active.

RD-6 adds checked **Stereo cursor** and **Reposition stereo cursor here**
viewport commands. A plane anchor and signed `z` define exactly one world point
`Pplane + z*VN`, which is inverted independently through both stable-ID source
models and displayed with physical-eye colors. While enabled, its plane anchor
follows the mouse and its signed height remains independently adjustable. Pair
turnover, role swap, layer reorder, OPK refresh, pan, zoom, and twist preserve
that physical definition. The detailed overlay reports signed metres and
explicit invalid, behind-source, and outside-footprint states; the bottom-right
OPK readout says how far above or below the projection plane the cursor lies.
MATLAB's built-in crosshair replaces the arrow until disable restores the prior
pointer. Shift+wheel changes Z only while enabled, with fine/coarse modifiers
and configurable bounds; Shift+Up/Down still controls Tip. Cursor state is
omitted from Save/Load/backend products and is cleared by disable, import,
Reset, and viewer deletion. Its acceptance work also replaced
the unreliable UIAxes `InnerPosition` listener with a guarded one-shot
post-layout graphics event so initial framing uses the resolved viewport.

The completed Alignment Workbench usability pack groups controls into Setup,
Filter/Solve Settings, Staged Workflow/Review, Pair Schedule, Match Ledger, and
full-width Diagnostics regions. It preserves the staged state machine and
records the projection-offset decision: offsets remain post-intersection
projection-plane registration terms, affect plane-coordinate products, and do
not alter source origins, forward-ray metrics, or coplanarity.

Multi-image MI-2 extends that workbench with compact active-pair selectors,
Swap and deterministic schedule navigation, pair status/enablement, and Solo
pair presentation. The Solo snapshot is runtime-only, follows the selected
pair, retains overlays, and restores surviving layers by stable `ViewId` on
explicit exit or workbench/viewer close.

Multi-image MI-3 reuses the existing center-column `ReferenceOrigin` rule for
representative sensor locations. Eye assignment projects those origins onto
camera horizontal, keeps red on the physical left, retains prior identity near
head-on degeneracy, and stores pair-specific manual overrides only in a
graphics-free runtime controller.

Multi-image A2 adds one-shot Pair viewpoint and Restore viewpoint commands. The
camera uses representative origins over
shared overlap when continuous source mapping is available, otherwise the MI-3
center-column `ReferenceOrigin`; it aims from their midpoint to the common
footprint centroid, uses plane-derived up, and fits the overlap with padding.
RD-4 moves persistent tracking ownership to Pair View in the Layer Manager and
applies that absolute geometry after accepted pair transitions. The feature
changes only camera presentation and reports unavailable overlap/geometry
without mutating scene or scientific state.

Multi-image A3a-1 makes arrows viewport-focus-aware. Shift+Arrows retain
Tip/Tilt adjustment, plain Left/Right select layers without visibility changes,
and plain Up/Down reuse W/S vertical nudge semantics. Focused dropdowns,
tables, sliders, and editable controls keep their native arrow behavior. A
runtime keyboard-mode boundary is reserved for the subsequent motion-imagery
pack without implementing motion mode here.

Multi-image A3a-2 adds a lazy context-launched manual motion-imagery window.
Sequences default to all image layers independently of visibility, support pass
and per-view filtering, preserve explicit caller order, otherwise order time
within pass, and expose stable fallback warnings. The non-stereo runtime shows
one currently applied geometry at a time, supplies no-wrap/Loop stepping,
hover-edge or persistent buttons, and transient/pinnable identity. Exit restores
camera and presentation state exactly without changing scene geometry,
visibility, blend, stereo identity, radiometry, or corrections. Strict UTC text
parsing now preserves provenance and implements the locked two-digit-year pivot.
The integrated hover path measured 0.838 ms median and 2.154 ms p95 over 100
callbacks on the development machine, with zero mesh, tile-refresh, or surface-
creation work; lightweight buttons and axes glyphs had equivalent p95
visibility-toggle cost, so buttons were retained for clearer hit targets and a
persistent fallback.

Multi-image A3b adds direct Play/Pause at 0.5-10 fps with a 2 fps default,
Space/Escape integration, sequential no-skip display, and a single-frame
lookahead bound. Manual steps pause first; focus loss, layer/sequence mutation,
missing/stale data, load failure, and the no-wrap boundary pause with a visible
reason. Development-machine cadence medians were 1.990 s at 0.5 fps, 0.498 s at
2 fps, and 0.100 s at 10 fps; corresponding frame-switch medians were 24.7,
21.9, and 15.5 ms. Pointer/crosshair, pan, zoom, frame switching, cache bytes,
and visible texture memory are exposed through bounded performance diagnostics.
An interaction sample retained one lookahead, built no meshes/tiles/surfaces,
and held caches to 8,553 bytes while recording 30 pointer callbacks.

MATLAB SDK S1 adds immutable `ProjectionCorrectionSet` generation values keyed
by stable view/pass identity, complete legacy OPK convention metadata,
authoritative radian/radian-squared fields with degree accessors, exact rotation
composition lineage, typed extension blocks, provenance/diagnostics/failure
data, and SHA-256 parent/corrected geometry fingerprints. Compatibility queries
reject missing views, pass changes, and stale parent geometry before any future
mutation. `ProjectionCorrectionOpkAdapter` bridges existing degree solver
results in both directions; `solveCorrectionSet` is the new graphics-independent
headless entry point. MAT and shape-preserving portable JSON round-trip exactly.
MATLAB SDK S2 hardens that boundary with strict format/version rejection and
stable revision tokens for function-backed geometry. The graphics-independent
`ProjectionCorrectionStore` owns immutable proposal, acceptance, rejection,
application, supersession, historical, and reverted records. It validates a
complete correction scope against the exact parent generation, applies on a
scene copy, verifies every corrected fingerprint before publication, and
restores verified parent snapshots for exact revert. Ordered post-commit
callbacks are reentrancy-protected and failure-isolated; queryable history
remains authoritative. Viewer launch and public app methods expose the same
contract while the legacy runner retains automatic safe apply compatibility.

## Current Implementation Queue

The completed read-only MATLAB SDK entry-point inventory, proposed reuse points,
and compatibility risks are recorded in `docs/matlab_sdk_audit.md`. The
consolidated product roadmap remains
`docs/multi_image_surface_reconstruction_workplan.md`; its completed and gated
items are preserved there. The corrective queue in
`docs/real_data_validation_followup_workpack.md` is complete; independent D2
work is next. Its July 13 operator findings were completed in the order RD-2
network-solve,
RD-3 LOD/lifecycle correctness, RD-1 camera-up orientation, RD-4 Layer
Manager/viewer shell, RD-5 dense-surface recovery, and RD-6 stereo cursor.
RD-2, RD-3, RD-1, RD-4, RD-5, and RD-6 are complete. MI-0 through MI-3, A2
pair viewpoint, A3a-1 focus-aware keyboard mapping, A3a-2 manual motion imagery,
A3b motion playback, S1 immutable CorrectionSet, S2 correction lifecycle, the
SDK audit, and both A4 track/path and explainable pair-graph packs are
complete. A5/A6 global constant-OPK network solving and the multi-image
synthetic acceptance matrix and P0/P1 precision validation are also complete.
Target-hardware Windows MATLAB-managed GPU validation and the D1/P3 CUDA/MEX
dense-cost spike remain external and unclaimed. The independent portable D0
native foundation is complete on macOS; D2 geometry and two-image procedural
parity is the next independent CPU stage in the explicit dependency order.
C0-C3 are complete. A7 research is complete; production time-varying
application remains gated on physical local observability and stability.

The post-RD-7 real-data Surface Workbench and tiled-anaglyph corrective queue is
implemented in `docs/real_data_surface_stereo_recovery_workplan.md`. SR-0/SR-1
are implemented: dense association now uses deterministic indexed grouping,
path-compressed disjoint sets, component spans, and local view ordinals; it
publishes bounded substage progress, accepts cooperative cancellation, exposes
linear work counts, and retains exportable pair failure/partial-run evidence.
The five-view/ten-pair privacy-safe benchmark measured 0.939 seconds at 250
records per pair, 1.867 seconds at 500, and 18.808 seconds at 5,000 on the
14-core MATLAB R2026a development host. The private saved-run inventory and
original template-matcher message remain external gates. SR-2/SR-3 provide
truthful portable coordinate frames, standard 3-D interactions, and defensive
saved-run inspection. SR-4/SR-5 provide transactional renderer ownership,
direct audit, deterministic failure rollback, and presentation-only viewport
rebuild. SR-6 privacy-safe grouped validation passes 795/795; the representative
private scenario remains unclaimed.

The follow-on interaction-continuity queue is implemented in
`docs/real_data_interaction_continuity_workplan.md`. IC-1 removes broad axes
clearing from compatible Surface Viewer refreshes and retains the standard
interaction/tooling state. IC-2 replaces the old global anaglyph alpha cap with
a physical-red 0.50 scene alpha/slider contract and preserves target plus
world-space view height during tracked pair turnover. IC-3 adds demand-driven
mouse-follow cursor updates, signed OPK height wording, and built-in crosshair
pointer restoration. IC-4 grouped validation passes 797/797 and is recorded in
that workplan;
representative private-data confirmation remains external.

S2 is complete. Its mandatory entry hardening, atomic application/reversion,
immutable history, viewer integration, callback safeguards, and legacy
compatibility are covered by focused and full fresh-class validation.

The first A4 pack is complete. Accepted pair-ledger records now reconcile into
stable multi-view tracks with at most one observation per view. Descriptor and
geometry gates retain explicit rejection reasons, ambiguous transitive merges
are rejected, and direct-versus-composed observation disagreement is exposed as
cycle/path diagnostic evidence without becoming a duplicate solver residual.

The second A4 pack is complete. Multi-image scheduling now scores plausible
stable-view pairs, builds a deterministic maximum-quality spanning forest, and
adds complementary loop chords with low-degree and cross-pass redundancy
rewards. Headless and workbench callers have Fast/Balanced/Quality, hard pair
budget, all-plausible, and forced include/exclude controls. Diagnostics expose
tree/chord roles, components, degrees, cycle basis, rejections, signal
availability, predicted cost, and infeasible connectivity while preserving
legacy explicit strategies and two-image role direction.

A5 is complete. `ProjectionAlignmentNetworkSolver` rebuilds current track
evidence, removes cycle-duplicate residuals, defaults to epipolar coplanarity,
holds ray origins fixed, and jointly optimizes all retained views. It provides
bounded frozen robust scale, Huber/Cauchy weighting evidence, balanced-prior or
named fixed-reference gauge preflight, components and weak views,
weighted-normal OPK covariance, and residual summaries by track, pass, and
image region. Visible-layer workbench solves use this path; selected-pair
solves preserve the established compatibility path. Network covariance and
track/gauge provenance flow into the immutable CorrectionSet and existing
atomic apply/revert lifecycle.

A6 is complete. Balanced network coordinates now contain one explicit common
OPK vector per pass plus per-image differentials with an algebraically exact,
prior-precision-weighted zero mean. Single-pass, multiple-pass, and independent
views/custom-prior configurations share the model and are exposed in the
workbench. Independent pass commons are connected only by cross-pass evidence.
Diagnostics retain pass common/differential/effective corrections, prior/data
objective contribution and prior dominance, residual concentration by pass,
time interval, region, and position correlation, and leave-one-pair-out
sensitivity with missing/failed child state. Effective covariance and pass
decomposition remain authoritative through CorrectionSet serialization.

The multi-image synthetic acceptance matrix is complete. Its deterministic
reported-only scenarios cover 2, 3, 4, and 6 views; balanced, fast, quality,
and all-plausible pair graphs; single- and multi-pass errors; corrupted-edge
association rejection; explicit visible/occluded/texture/masked/invalid
evidence classes; held-out OPK truth comparison; uncertainty summaries; and
exact repeatability. No numerical acceptance threshold is implied by the
recorded evidence.

Repository validation is now partitioned by the authoritative
`projectionTestGroups` manifest. Every feature pack runs all six logical
groups in separate fresh-class MATLAB MCP calls, as documented in
`docs/test_suite_grouping.md`; an integrity test rejects missing or duplicate
test-file ownership.

P0/P1 are complete. The executable inventory classifies 16 current precision
boundaries and retains double as the scientific reference. The long-range
viewer matrix covers local and large translated coordinates at 1 km, 25 km,
the required 100 km, and the 200 km stretch range under an unrefracted WGS84
horizon model. Casting only after double render-origin subtraction stayed at
`4.005e-5` pixel maximum error with preserved eye ordering; casting absolute
world values first reached `0.786` pixel and collapsed the 0.02 m stereo
baseline. See `docs/precision_inventory_and_long_range_validation.md`.

S3 is complete. The dense matcher SDK now provides validated graphics-free
request/result values, an abstract common lifecycle with progress,
cancellation, error classification, execution and provenance reporting, and a
caller-owned explicit registry. The current SGM extractor is available through
`ProjectionDenseSgmMatcher`, which converts legacy output to full-source
observations and explicit states without returning a surface as correspondence
output. See `docs/dense_matcher_sdk.md`.

B0 is complete. An 11-case deterministic held-out matrix now audits the current
SGM extractor across range/angle, relief/occlusion, radiometry, reported
navigation/rectification error, texture, disparity, and execution request. It
records completeness, gross outliers, subpixel disparity and height errors,
left/right consistency, occlusion behavior, runtime, memory, and GPU fallback.
The evidence retains SGM for bounded textured well-rectified use but does not
authorize an automatic `Best` matcher. See `docs/dense_sgm_truth_audit.md`.

B1 is complete. Dense pair scheduling is independent of the alignment graph and
scores overlap, conditioning, texture, radiometry, visibility, cost, and memory
with operator overrides and held-out validation-view reporting. Sparse accepted
observations now produce deterministic regional disparity/direction/depth
search priors with track provenance, uncertainty widening, explicit unseeded or
no-support states, and no forced surface. See `docs/dense_search_planning.md`.

B2 is complete. `ProjectionDenseTemplateMatcher` adds bounded deterministic
multi-scale local-strip matching with ZNCC, gradient, census/rank, and
phase-only costs. It retains uniqueness/ties, texture, subpixel fit,
forward/backward consistency, prediction residual, uncalibrated confidence,
explicit states, cancellation, provenance, and continuous full-source
coordinates. See `docs/dense_template_matcher.md`.

B3 is complete. Pairwise reconstruction now reports forward ray parameters,
separation, angle/conditioning, and provisional points while central numerical
Jacobians propagate full-source localization and correlated ray-state geometry
uncertainty into symmetric world-frame covariance. Missing or weak covariance
is explicitly unavailable/unreliable. See `docs/pairwise_point_covariance.md`.

B5 is complete. Stable view-qualified observations are associated before
surface formation with explicit quality, forward-geometry, visibility, and
duplicate-view conflict reasons. The robust multi-ray point set counts unique
views and equalized pass evidence rather than pair multiplicity, rejects
inconsistent rays, retains labeled two-view tracks, splits supported competing
depth modes, and reports complete contributor, residual, conditioning,
radiometry, visibility, and assumed/unavailable covariance provenance. Full MAT
plus compact JSON persistence is available. See
`docs/dense_multi_view_reconstruction.md`.

S6/B4 is complete. The graphics-independent surface-fusion SDK provides strict
request/result values, a sealed lifecycle, an explicit trusted registry,
progress/cancellation/failure classification, robust multi-ray, sparse hard
occupancy and covariance-informed Gaussian adapters, a minimal external-style
example, resource limits, explicit precision, and MAT plus compact-JSON
persistence. A bounded held-out roof/parapet audit sweeps GSD-derived scales,
preserves competing urban modes, and proves that pair multiplicity cannot
inflate evidence. Robust multi-ray achieved `0.0935` m RMSE versus `0.2115` m
hard voxel and `0.2081` m Gaussian at their best scale, all with full fixture
completeness. The explicit decision abandons authoritative voxel promotion;
voxel results remain diagnostic/research products. See
`docs/surface_fusion_sdk.md`.

B6 is complete. `ProjectionSurfaceProductCatalog` strictly adapts B5 raw and
authoritative points, S6 fused/voxel outputs, optional mesh/grid products, and
DEM/registered placeholders without runtime handles. A headless model
owns portable selection state, product statistics, relative work/memory
estimates, deterministic color/decimation payloads, and full-source links. The
separate responsive Workbench provides selection, processing, diagnostics,
progress, and cancel controls; its lazy 3-D viewer renders and compares
point/voxel/mesh/grid products, shows selected-only covariance axes, and never
overwrites the complete result. See `docs/surface_workbench.md`.

S7/B7 is complete. `ProjectionDemGrid` strictly ingests WGS84 grids and DTED2-
oriented values, makes HAE versus MSL/EGM96 explicit, applies caller/dataset/
DTED2 accuracy precedence, records Gaussian conversion and shared-cell
correlation assumptions, and preserves reversible WGS84/ECEF/scene-ENU/project
transforms. The sealed derivable registration lifecycle, explicit registry,
direct headless service, robust point-to-normal translation adapter, and
external-style example produce covariance, coverage, support/rejections,
residuals, mask sensitivity, datum, ambiguity, persistence, a complete preview,
and a proposed non-auto-applied `CorrectionSet`. Workbench adapters expose DEM,
registered, and difference products without changing imagery-only points. The
23 focused tests include held-out deterministic and Monte Carlo truth audits;
the full grouped baseline is 691/691. See `docs/dem_registration_sdk.md`.

B8 is complete. `ProjectionDemCorrectionAdapter` binds the preview-only S7
proposal to the current scene generation, validates the world frame and exact
view/pass scope, requires a separate override for ambiguous registration, and
rejects rotation, per-pass, trajectory, or unbound terms. Compatible explicit
and function-backed source origins translate together while ray directions
remain unchanged. The S2 store applies a scene copy, verifies every corrected
fingerprint before publication, restores the exact parent on revert, and emits
a durable invalidation/recompute manifest. Viewer integration clears matches,
filters, solves, and dense products after both apply and revert. The nine B8
tests bring the grouped baseline to 700/700. See
`docs/dem_registration_sdk.md`.

A7 research is complete. `ProjectionTimeVaryingOpkResearch` fits truth-free
linearized residuals with local tangent rotation vectors, open-uniform cubic
splines nominally spaced every 128 full-source columns, second-difference
priors, and explicit pass-common plus per-image terms. It automatically
coarsens when data support, rank, or conditioning is inadequate and labels a
per-column model as an analysis upper bound. The held-out audit recovers the
dense synthetic case while a sparse case fails closed after coarsening.
Research CorrectionSet blocks retain generation/frame/unit/provenance contracts
but are rejected before Apply. The eight A7 tests bring the grouped baseline to
708/708. See `docs/time_varying_opk_research.md`.

C0-C3 are complete. The frozen notation inventory and code-independent
IEEEtran manuscript cover frames, source formation, planes/rays, sparse and
dense correspondence, global/pass-aware and time-varying research models,
stereo presentation, multi-ray uncertainty, fusion, DEM registration,
precision, degeneracies, Jacobians, and cross-language conformance. The direct
`proceduralTwoImageAnaglyph` companion performs the two-image inverse-map and
red/cyan path without GUI state or production object hierarchies. Eight golden
tests compare plane coordinates, source maps, values, masks, physical-eye
identity, and display offsets with production components, bringing the grouped
baseline to 716/716. See `docs/mathematical_reference/README.md` and
`output/pdf/sightline_mathematical_specification.pdf`.

The platform-independent D0 foundation adds a C++17 dependency-free CPU
geometry reference, stable plain-C ABI, warning-as-error CMake presets,
installable `Sightline::core` package, public MATLAB-generated CSV/JSON golden
fixture, independent C++ and true-C tests, and an optional hash-pinned Eigen
5.0.1 probe. Three MATLAB fixture/manifest tests bring the grouped baseline to
719/719. The macOS base and Eigen presets and an out-of-tree install consumer
pass; native Windows/WSL, Ceres 2.2, MATLAB/MEX, and CUDA evidence remain
explicitly unclaimed. See `docs/cpp_backend_d0.md`.

The worker is also authorized to continue through subsequent ordered green
packs without waiting after each commit. Each pack still requires focused
validation, checkcode, every grouped fresh-class MATLAB-MCP suite,
documentation,
commit, push, and clean status. The explicit stop conditions and unattended
MATLAB/Git rules are recorded under `Continuous execution authorization` in
the consolidated workplan.

The cross-system pass retained CPU viewer/alignment paths, preserved the Pack 2
prerequisite for backend threading, and added optional capability-checked GPU
SGM with CPU fallback. See `docs/cross_system_acceleration_report.md`.

Backend Performance Pack 2 adds bounded serial tiled-TIFF output, explicit
in-memory retention policy/limits, optional query-coordinate omission,
output-sized index-temporary removal, and partial-file cleanup.
Backend Performance Pack 3 replaces retain-all `parfor` execution with bounded
`parfeval` submission, immediate `fetchNext` consumption, indexed main-thread
TIFF writes, deterministic tile reports, and explicit in-flight diagnostics.
Backend Performance Pack 4 replaces implicit min/max normalization with one
shared scale/offset/class/fill/clipping contract, records reconstruction
metadata, supports uint8/uint16 PNG/TIFF and single TIFF, and validates optional
single-precision tile products against double.
Backend Performance Pack 5 adds runtime-only in-memory/TIFF source providers,
serializable TIFF descriptors, per-tile source bounding-region reads, source
provenance summaries, and in-memory/file-backed numerical parity. MATLAB TIFF
region reads require serial execution because their internal reader is not
supported on thread workers.

The approved dense-surface synthetic expansion has no remaining implementation
milestone. Required fixture decisions are captured in an ignored local JSON
configuration. Actual sensor and geometry values remain out of committed
documentation. Proposed evidence thresholds are documented separately and are
not yet enforced by code.

1. **Configuration and feasibility — complete.** Strict schema/path validation,
   explicit body/world and roll-then-pitch gimbal transforms, full-ray projected
   GSD, pitch-scan and constant-gap schedule solves, footprint/tile planning,
   per-axis oversampling, and ordered explainable feasibility checks are in
   place. The ignored configured fixture passes every planner check before
   full-scale allocation.
2. **Terrain, texture, and truth geometry — complete.** Logical shared-edge
   reflected addressing supports continuous arbitrary-band interpolation;
   compact deterministic terrain enforces configured extrema and uses first-hit
   intersections with explicit occlusion; fixture-local Gauss-Markov motion and
   truth rays are sampled on demand. Truth is absent from viewer-safe metadata.
3. **Full-scale image generation — complete.** The generator gates allocation
   on feasibility, loads full source radiometry once, renders complete
   single-band images in bounded internal chunks, retains them in memory, and
   writes final TIFF/PNG plus compact image-free MAT/JSON artifacts. The
   configured run completed with full valid coverage and exact file readback.
4. **Navigation presets and scene variants — complete.** One correlated sortie
   timeline propagates configured inertial bias/random-walk terms with nominal
   GNSS position/velocity aiding. Generic Tactical Grade IMU and Navigation
   Grade IMU presets each provide pointing-only and combined-error reported
   geometry. Variants share an image reference and contain no image payload or
   truth structure; deterministic statistics preserve expected grade ordering.
5. **Alignment and dense-surface acceptance — complete.** Reported-only scenes
   now run through the existing staged
   alignment, fixed-reference differential OPK solve, safe-apply policy, and
   dense extraction. Truth diagnostics are computed afterward on mutually
   visible terrain. The configured evidence contains four completed alignment
   runs, four successful dense products, exact two-pass repeatability, and
   compact ignored MAT/JSON artifacts. Conservative numerical thresholds are
   proposed in a separate reviewable document without changing runtime policy.

See `docs/dense_surface_synthetic_expansion_plan.md` for the complete ordered
contract.

The bounded claim applies to serial/thread TIFF output with in-memory sources,
and to serial TIFF output with file-backed sources. PNG remains in-memory.

## External Validation Gates

The approved truth-aware synthetic expansion is the primary systematic
alignment acceptance fixture. Later air-gapped real-data findings may be
incorporated as isolated metric or threshold updates; a repository-accessible
real-data corpus is not expected.

The remaining external gates require target hardware:

- Benchmark representative 100-150 MP primarily single-channel images on the
  intended high-end Windows workstation at 1080p/4K, including 512 versus 1024
  display tile sides and one, two, and four visible layers. The provisional
  default remains 1024.
- Exercise optional MATLAB-managed GPU behavior and CPU equivalence on a
  supported Windows GPU system before making any performance recommendation,
  including dense-surface `disparitySGM` GPU behavior if available.

The Windows viewer/GPU gates remain explicitly unclaimed on the current macOS
development system.

## Later, Evidence-Gated, Or Hardware-Gated Work

The consolidated multi-image workplan approves the architecture and order for
many of these items, while their execution remains later, evidence-gated, or
hardware-gated:

- calibrated or spatially varying stereo rectification, confidence/uncertainty,
  consistency filtering, cleanup, smoothing, and export for dense surfaces;
- degraded or interrupted GNSS, precision/differential GNSS, explicit
  gimbal/boresight/mounting errors, and independent repeat-pass error draws;
- piecewise-linear and true curved target-orbit collection trajectories;
- production application of per-column or smoothly posted time-varying OPK
  correction after the completed A7 research passes physical observability and
  stability gates;
- a production preview/exact/difference/flicker comparison view;
- sensor-specific geometry ingestion beyond
  `ProjectionSourceGeometry.fromGrid`;
- calibrated pointing covariance and native-displacement defaults;
- a second/multi-anchor common-twist interaction;
- optional DEM-constrained adjustment or an explicitly labeled plane-tie tool;
- production export of screen-adjusted anaglyph presentation as a three-band
  TIFF/PNG product after display-only controls are evaluated;
- richer difference/flicker/swipe comparison modes;
- a decision on signed-line versus forward-ray semantics for the legacy
  `PlanarProjection.intersectPlane` and
  `PlanarProjection.triangulateRays` APIs; and
- custom GPU kernels, only if profiling shows a bottleneck not addressed by
  CPU tiling, thread execution, and MATLAB-managed GPU operations;
- later C++ stages beyond the completed portable D0 foundation and eventual
  NITF output; current prototyping may keep all inputs/outputs in memory and
  perform one final TIFF/PNG write.

## Sources Of Truth

- `docs/software_requirements_specification.md` — project-wide normative
  product, interface, scientific-integrity, quality, and verification
  requirements. It does not replace the ordered workplan or this status index.
- `docs/multi_image_surface_reconstruction_workplan.md` — consolidated
  multi-image viewer/alignment, MATLAB SDK, dense reconstruction, uncertainty,
  DEM registration, precision, mathematical-specification, CUDA, and C++
  roadmap; most MATLAB trees and D0 are complete.
- `docs/real_data_validation_followup_workpack.md` — completed RD corrective
  queue and historical intake point for the July 13 real-data findings.
- `docs/real_data_surface_stereo_recovery_workplan.md` — implemented post-RD-7
  corrective queue for dense association, ECEF/local 3-D review, saved-run
  inspection, tiled anaglyph ownership, and viewport recovery.
- `docs/real_data_interaction_continuity_workplan.md` — implemented follow-up
  for Surface Viewer navigation lifetime, anaglyph alpha/camera continuity,
  and mouse-follow stereo cursor presentation.
- `docs/matlab_sdk_audit.md` — completed inventory of current public/headless
  entry points, reuse candidates, and compatibility risks feeding the SDK plan.
- `docs/viewer_development_plan.md` — architecture, historical viewer/backend
  milestones, and broader roadmap topics.
- `docs/alignment_workflow_hardening_plan.md` — completed alignment design and
  reliability/usability packs, offset-semantics decision, and deferred
  alignment scope.
- `docs/performance_optimization_workplan.md` — completed viewer/backend
  performance packs, cross-system acceleration constraints, and Backend Pack
  5.
- `docs/dense_surface_feature_pack.md` — exploratory dense-surface contract
  and limitations.
- `docs/dense_surface_synthetic_expansion_plan.md` — truth-aware synthetic
  fixture, navigation presets, acceptance modes, and ordered implementation
  milestones.
- `docs/dense_surface_synthetic_acceptance_report.md` — first full-scale
  privacy-preserving acceptance evidence and interpretation.
- `docs/dense_surface_synthetic_acceptance_thresholds.md` — proposed primary
  fixture gates derived from the first repeatable evidence package.
- `docs/alignment_operator_guide.md` — current staged operator workflow.
- `docs/architecture_concept_recommendations.md` — non-authoritative future
  architecture concept record; promotion requires an SRS/workplan gate.
- `docs/cpp_backend_d0.md` — completed portable native-foundation boundary,
  dependency evidence, and explicitly unclaimed target-host validation.
