# Sightline Workbench Multi-Image And Surface Reconstruction Workplan

Status: approved consolidated workplan. Backend Performance Packs 0-5, the
dense-surface synthetic expansion, Multi-Image Foundation MI-0 through MI-3,
A2 pair viewpoint, A3a-1 focus-aware keyboard mapping, A3a-2 manual motion
imagery, A3b measured motion playback, S1 immutable CorrectionSet, and S2
correction lifecycle/notification are complete. The read-only MATLAB SDK audit
is also complete. Both A4 track/path-consistency and explainable quality
pair-graph packs, A5 global constant-OPK network solve, A6 pass-aware priors,
the multi-image synthetic acceptance matrix, P0/P1 precision validation, S3
dense matcher SDK/current-SGM adapter, B0 truth-aware SGM audit, and B1 dense
pair/search planning, B2 classical template matching, B3 pairwise point
covariance, B5 dense multi-view reconstruction, S6/B4 surface fusion, B6
Surface Workbench, S7/B7 DEM ingestion and registration, and B8 explicit DEM
position application and the bounded A7 time-varying OPK research pack are
complete. C0-C3 notation, manuscript, procedural-reference, and appendix work
is also complete. A7 remains research-only; production application is still gated on
physical local observability and stability. The current grouped fresh-class
repository suite passes 716/716 tests. This
`/private/tmp` file is
the editing master; the synchronized committed copy is the implementation
source of truth. Only explicitly dispatched packs are active implementation
work, and hardware/evidence gates remain explicit.

## 1. Purpose

Sightline Workbench already supports multiple image layers, pair-oriented
alignment operations, stereo presentation, a global alignment foundation, and
an exploratory two-view dense surface. The next product-level step is to make
the multi-image model explicit and coherent across:

- same-pass and independent-pass collections;
- pairwise inspection and correspondence generation;
- simultaneous adjustment of all enabled image models;
- clean motion-imagery presentation;
- dense reconstruction from more than two views;
- uncertainty-aware point and surface products;
- optional registration to an uncertain reference DEM;
- a stable MATLAB SDK for correction results and replaceable dense matchers;
- a code-independent mathematical specification;
- a transparent procedural MATLAB reference; and
- a future high-performance C++ backend through surface extraction.

The central design rule is:

> Measurements may be created and inspected pairwise, but accepted evidence
> belongs to one multi-image network and should be solved consistently as a
> network.

Sequentially applying unrelated pair solves would accumulate drift, depend on
pair order, and conceal conflicts. Pairwise solving remains useful for
diagnostics and initialization, but the durable adjustment should minimize one
objective over all enabled observations and image parameters.

## 2. Product And Interaction Principles

1. Keep the main viewer visually quiet. Pair scheduling, solver configuration,
   dense processing, uncertainty, and DEM comparison belong in workbenches or
   floating tools rather than a permanent wall of controls.
2. Preserve explicit operator control. The active pair, reference/moving role,
   enabled observation set, pass grouping, solve mode, and presentation mode
   must always be visible and inspectable.
3. Separate scientific geometry from presentation. Solo visibility, anaglyph
   eye assignment, camera viewpoint, screen parallax, motion playback, and
   projection-plane basis orientation must not silently mutate source rays.
4. Separate physical-plane replacement from plane reparameterization. Rotating
   axes inside the same physical plane is a modest coordinate/presentation
   change; changing the plane normal or origin is a scene-wide geometry change.
5. Preserve raw evidence. Pair matches, tracks, ray observations, raw
   triangulations, uncertainty, fused points, DEM-registered products, and
   rejected observations should remain distinguishable and traceable.
6. CPU execution remains complete. GPU and parallel acceleration remain
   optional, capability-checked, and justified by profiling.
7. Do not let viewer previews or bounded analysis products become backend
   radiometric inputs.
8. Treat the MATLAB SDK as a first-class product surface. Public results and
   extension contracts must remain independent of graphics handles, runtime
   caches, workbench layout, and private fixture configuration.

## 3. Core Multi-Image Data Model

### 3.1 Views, pairs, passes, and tracks

Use four distinct concepts:

- **View:** one image and its time-dependent source geometry.
- **Pair:** two views selected for matching, inspection, stereo presentation,
  or dense processing.
- **Pass:** views sharing a flight/orbit segment and therefore correlated
  navigation, mounting, timing, and environmental errors.
- **Track:** one inferred physical feature observed in two or more views.

The image network is a graph whose nodes are views and whose edges are enabled
pairs. Sparse feature tracks are hyperedges connecting observations across
multiple views. Pair matches should be promoted into tracks when observation
identity and geometry support it; duplicating the same physical feature as
many independent pair observations would over-weight it.

The pair graph must not be restricted to sequential neighbors. Sequential
edges are inexpensive and useful, but form a chain that is vulnerable to drift
and weak long-baseline observability. Add selected nonsequential edges wherever
overlap, geometry, radiometry, and cost justify them. In particular, preserve
cycles such as view 1 to 2 to 3 to 1. A feature propagated around a valid cycle
should return to the same observation/track identity; disagreement identifies
an inconsistent edge, ambiguous feature, or inadequate geometry.

Cycle constraints do not require a globally dense all-pairs system. Each
multi-view track or short cycle creates a small dense block/clique among its
participating views, while the overall image network remains block sparse.
Use a cycle basis or another independent set of loops rather than adding every
redundant cycle as if it were new evidence.

Every view needs stable identity independent of layer order. Every pair needs
stable identity independent of moving/reference role. Every pass needs an
explicit identifier rather than being inferred only from filenames or list
adjacency.

MI-0 implements this foundation through optional stable `ViewId`, explicit
`PassId`, unordered pair identity, and optional timing metadata while
preserving the legacy lightweight launch signature. Caller IDs are preserved;
missing IDs are generated. Missing `PassId` places views in one pass and is
never inferred from filenames.

The preferred absolute acquisition-time input is strict UTC text in
`DDMMYY_HHmmSS`, with optional fractional seconds. Also accept unambiguous
`DDMMYYYY_HHmmSS` and numeric relative time for fixtures/headless workflows.
Use the fixed two-digit-year pivot `80-99 -> 1980-1999` and
`00-79 -> 2000-2079`, retain the original text for provenance, and normalize
internally to timezone-aware UTC `datetime`. Per-image start time plus line
rate and scan-axis/direction metadata derive per-line time. Missing timing does
not block viewing or manual pair selection; time-dependent tools report an
explicit fallback.

### 3.2 Same-pass and multi-pass error regimes

The first global adjustment uses one constant OPK correction per image while
holding ray origins fixed. Its prior model should distinguish:

- a common attitude component correlated across a pass;
- a differential component for each image;
- independent common components for different passes; and
- optional per-view confidence differences.

This makes the solver appropriate for both repeated observations during one
flyby and independent passes around the same target. It also prevents the
solver from pretending that every image error is statistically independent.

Position error cannot generally be absorbed by OPK without bias. The first
constant-OPK milestone should report residual structure that indicates an
origin/trajectory error rather than hide it. Later parameter blocks may add:

- a shared translation per pass;
- a velocity or low-order trajectory bias per pass;
- lever-arm, timing, or scan-angle terms; and
- smoothly varying attitude corrections.

### 3.3 Gauge and reference policy

A global solve requires a gauge choice. Supported policies should include:

1. Hold one explicitly selected reference view fixed.
2. Apply covariance priors to all views and solve a balanced network.
3. Use a zero-mean common correction within a pass plus differential priors.

The default should not quietly designate the first layer as truth. Diagnostics
must report which gauge/prior policy was used and how much common versus
differential correction was estimated.

## 4. Pair-Centric Alignment Workbench

### 4.1 Active pair control

MI-1 through MI-3 implement the GUI-independent runtime pair controller,
active-pair controls, Solo-pair visibility, and physical stereo-eye
separation. Preserve those completed contracts while extending the workbench.
The compact active-pair selector supports:

- selecting one scheduled pair;
- assigning moving/reference roles independently of stereo eye assignment;
- swapping moving/reference roles;
- enabling/disabling the pair in the global network;
- stepping to previous/next scheduled pair;
- filtering the pair list by pass or image; and
- showing overlap, baseline/intersection angle, match counts, solver use, and
  status without opening detailed diagnostics.

The active pair controls which overlays, pair table row, sparse matches, dense
preview, and pair-specific commands are shown. It does not remove other pairs
from the global solve unless the operator disables them.

### 4.2 Solo-pair visibility

The completed `Solo pair` action temporarily shows only the two active layers.
It must continue to:

- snapshot every layer's visibility state;
- show both active-pair layers;
- hide all others without changing layer order or serialized visibility;
- optionally restore the prior blend mode;
- expose an obvious `Restore visibility` action; and
- restore safely when the selected pair changes, the workbench closes, or the
  operator exits solo mode.

Pair soloing is runtime presentation state, not scene truth. Matching and the
global solver continue to use their explicit pair schedule rather than viewer
visibility unless the operator requests a visibility-based schedule rebuild.

### 4.3 Left/right invariants

Moving/reference, layer order, and stereo left/right are separate concepts.
For the active pair, derive stereo eye assignment from the representative
sensor origins projected onto the current viewer-camera horizontal axis:

- the origin appearing to the camera's left is the left eye;
- the origin appearing to the camera's right is the right eye;
- red remains assigned to the left eye for red/cyan presentation; and
- swapping moving/reference roles does not swap eyes unless the physical
  viewpoint ordering changes.

Near a degenerate head-on baseline, use hysteresis and retain the previous eye
assignment instead of flickering. Show a small diagnostic warning when the
current camera cannot establish a stable left/right ordering. The completed
runtime controller also provides a visible resettable manual override that is
never serialized.

### 4.4 Pairwise operations versus global solve

Pairwise actions should include Match, Filter, inspect/curate, dense preview,
and an optional pair-only diagnostic solve. Accepted pair observations enter
the shared ledger. The primary Solve action should operate over every enabled
pair and track in the selected network.

Never apply pair solves sequentially as the default global workflow. A
pair-only solution may be used as a warm start or preview, but applying it must
be explicit and must invalidate/re-evaluate affected observations in other
pairs.

### 4.5 Default geometric constraint

Audit the current default before changing it. When valid ray geometry is
available, the multi-image workflow should default to a robust epipolar
coplanarity objective because it expresses the physical relationship between
the two viewing rays without assuming terrain lies on the projection plane.

A practical staged pipeline is:

1. detect and describe features with validity masks;
2. establish radiometric candidates;
3. apply a loose image-space consensus model for catastrophic rejection;
4. apply robust epipolar/coplanarity filtering;
5. solve the enabled network with a robust epipolar objective; and
6. optionally re-render/re-match after a material correction.

Projection-plane and ray-to-ray residuals remain diagnostic alternatives and
fallbacks. Pushbroom geometry can create spatially varying epipolar loci, so a
single global image-line approximation must not be labeled exact.

## 5. Pair Viewpoint And Plane Tools

### 5.1 Midpoint pair camera

Add a `View from pair midpoint` command. For time-dependent views, first choose
a representative origin over the pair's shared temporal/spatial overlap,
falling back to the center-column origin used by MI-3. Then:

- place the viewer camera at the midpoint of the two representative origins;
- aim at the centroid of the active pair's mutually visible footprint;
- derive up from the current plane basis and pair geometry;
- fit the pair footprint without changing scene geometry; and
- preserve a one-step `Restore camera` action.

Provide an opt-in runtime `Follow active pair` checkbox. It reapplies the
viewpoint after scheduled or direct pair navigation, defaults off, and leaves
the current camera unchanged when disabled. Manual camera movement suspends
following for the current pair; navigating again resumes it.

This command changes only presentation. It is useful for intuitive stereo
ordering and baseline inspection but must not redefine the projection plane or
source geometry.

### 5.2 What an “equivalent plane for another image” means

If four supplied image corners all lie on one constant-elevation physical
plane, that plane is already common to every image observing that surface. A
different view does not require rotating the plane normal or changing its
serialized basis. Routine pair orientation is presentation-only: orient and
frame the camera to the active pair while leaving plane origin, normal, basis,
output grid, intersections, radiometry, and caches unchanged.

An advanced preview may show candidate in-plane axes and projected bounds for
explanation, but the first implementation does not apply or serialize them.
Actual basis reparameterization is a later scene-wide operation with explicit
new grid/bounds calculation, complete reprojection, invalidation, and rollback.
Physical plane replacement, which changes origin or normal, is a still stronger
separately gated operation.

### 5.3 Pair-derived plane-basis command

Implement `Orient view to active pair`, not `Apply plane basis`, in the routine
pair workflow. Keep any future basis reparameterization and `Replace master
plane` tools in an advanced scene tool, not beside active-pair controls.

## 6. Motion-Imagery Presentation Mode

Add a non-stereo motion-imagery mode that displays one aligned layer at a time
while retaining a fixed viewer camera and projection plane.

### 6.1 Interaction

- Motion sequences are explicit and independent of current visibility. Default
  to all eligible image layers, permit pass filters and per-image inclusion,
  and disable the mode when fewer than two frames remain.
- Caller-supplied order is authoritative. Otherwise order by acquisition time
  within pass, never interleave incomparable relative clocks, and use stable
  pass/`ViewId` fallback ordering with visible diagnostics.
- Previous/next does not wrap by default; a runtime `Loop` option enables it.
- Enter from a viewer context-menu command. Snapshot visibility, active layer,
  blend/anaglyph, stereo, and presentation state; show one currently applied
  geometry at a time; restore exactly on exit/close.
- Plain Left/Right select previous/next frame only in motion mode.
- Outside motion mode, plain Left/Right select previous/next layer without
  changing visibility and plain Up/Down reuse existing W/S vertical layer
  nudges. Shift+Arrows adjust Tip/Tilt in both modes. Shortcuts apply only when
  the viewport, not an editable/list control, has interaction focus.
- Plain Up/Down do not mutate layers in motion mode.
- Optional edge affordances appear only while the pointer is near the left or
  right viewport edge and disappear when it leaves.
- A transient/pinnable label shows layer, sequence position, UTC acquisition
  time, pass, and applied-correction status. Persistent warnings identify
  fallback ordering, stale geometry, or load failure.
- The first pack implements manual stepping. A separate measured playback pack
  adds Play/Pause, 0.5-10 frames/second with 2 fps default, Loop, bounded
  one-frame lookahead, no silent frame skipping, and no crossfade/interpolation.
- In motion mode Space toggles Play/Pause; outside it retains hold-to-hide.
  Escape stops/exits and restores state. Manual stepping pauses playback.

### 6.2 Main-view cleanliness and performance

The arrows should be viewport overlays, not permanent side-panel controls.
They must be inactive outside motion mode and must not trigger tile selection,
mesh rebuilding, layer restacking, or full redraw on every pointer event.

Prototype two implementations and measure them:

1. demand-activated lightweight UI controls near the viewport edges; and
2. axes/figure overlay glyphs with hit regions.

A3a-2 measured both prototypes in MATLAB R2026a. Visibility-state changes for
two lightweight buttons measured 0.035 ms median / 0.045 ms p95 over 1,000
changes; two axes glyphs plus transparent hit regions measured 0.029 ms median /
0.045 ms p95. The committed button overlay provides clearer hit targets and a
persistent-control fallback without a material state-change penalty. In the
integrated pointer path, 100 callbacks measured 0.838 ms median / 2.154 ms p95
(3.402 ms maximum) and triggered zero mesh builds, tile refreshes, or surface
creations. These measurements characterize the development machine and are not
portable acceptance thresholds.

A3b's target-time, single-shot scheduler measured median/p95 delivered cadence
of 1.990/2.016 s at 0.5 fps, 0.498/0.513 s at 2 fps, and 0.100/0.106 s at
10 fps. Median/p95 direct frame-switch work was 24.7/26.9 ms, 21.9/22.4 ms,
and 15.5/19.3 ms respectively, with no silent frame skips. A separate active-
playback interaction sample recorded 30 pointer callbacks: crosshair work was
1.129/3.365 ms median/p95, pan was 39.137/103.634 ms, and zoom was
0.117/807.291 ms (including one observed long-tail callback). It retained one
lookahead identity, 49,152 visible texture bytes, and 8,553 combined bounded
cache bytes while causing zero mesh builds, tile refreshes, or surface
creations. These development-machine observations are evidence, not portable
acceptance thresholds.

Pointer handling should update only when the hover state changes. If hover
tracking measurably degrades pan/zoom/crosshair interaction, retain keyboard
navigation and use subtle persistent arrows instead.

Motion mode temporarily solos the current frame but preserves/restores the
operator's prior visibility and stereo state. Playback pauses on focus loss,
sequence mutation, missing data, or load failure and reports the reason.

## 7. Global Multi-Image Alignment Solver

### 7.1 First parameterization

Start with one constant OPK vector per image. For accepted track observations,
minimize a robust sum of pairwise epipolar/coplanarity residuals plus pass-aware
priors. Sparse matrix structure should be preserved: each residual touches only
the observations and image parameters involved in that track/pair.

Parameterize effective OPK as a pass-common correction plus a per-image
differential correction with a weighted zero-mean differential constraint.
Different passes have independent common components joined by cross-pass
tracks. Hold ray origins fixed in the first solver. Default to balanced
covariance/prior gauge control; offer an explicit fixed-reference mode but never
silently fix the first image.

Use Huber loss initially with a robustly estimated, physically clamped scale
that is frozen or cautiously updated within a solve. Keep priors outside image
residual robustification. Retain final weights/rejection reasons and expose
Cauchy only as an advanced comparison. Robust loss must not conceal gauge,
rank, position-like, or systematic residual failures.

Report:

- common and differential correction by pass;
- per-image OPK and covariance/observability diagnostics;
- residuals before/after by pair, track, pass, and image region;
- connected components and weakly constrained images;
- bound hits and prior dominance;
- leave-one-pair-out sensitivity; and
- whether conflicts are concentrated in a particular pass or time interval.

### 7.2 Track construction

Pairwise descriptor matches must be reconciled into multi-view tracks using
stable source observations, descriptor consistency, geometric compatibility,
and conflict resolution. A view may contribute at most one observation to a
track. Track merging must reject transitive contradictions rather than joining
everything connected by one weak pair edge.

Track construction should explicitly test path and cycle consistency. For a
short cycle, compare the direct match with the observation obtained by composing
matches along the alternate path. Use cycle closure to score or reject edges,
to split inconsistent tracks, and to expose loop diagnostics. Do not count the
same feature multiple times merely because it participates in several cycles.

### 7.3 Pair scheduling

Do not automatically match all possible pairs, but do not limit matching to
adjacent images. Build a connected, cycle-rich, quality-aware pair graph using:

- projected footprint overlap;
- expected intersection angle and depth precision;
- temporal/pass separation;
- radiometric compatibility;
- predicted occlusion;
- existing track support; and
- operator overrides.

Score all plausible pairs cheaply, start with a maximum-quality spanning forest,
then add the best loop-closing chords until observable components have useful
cycles, nonterminal views have two useful connections where feasible,
cross-pass components have redundant bridges, or the selected budget is met.
Penalize repeated near-equivalent baselines and reward complementary geometry.
Expose workbench quality/speed, hard `Max pairs`, and explicit `All plausible
pairs` controls with predicted cost. Preserve forced inclusions/exclusions and
deterministic tie-breaking. Report tree edges, chords, components, degrees,
cycle basis, rejections, and infeasible connectivity.

### 7.4 Cycle-aware solver structure

Build the global objective from unique track observations and physical
residuals, with cycle closure primarily serving data association, edge
validation, and diagnostics in the first implementation—not a duplicated
solver residual. Algebraically, a track seen in
several images produces a compact dense Jacobian/normal block for those views;
different tracks and disconnected neighborhoods preserve global sparsity.

Measure whether added loop edges improve rank, covariance, leave-one-edge-out
sensitivity, and recovery of deliberately corrupted matches. A loop is useful
only when it adds independent geometry or validates a path; redundant edges
sharing the same pass-wide errors must not be treated as independent precision.
Use global multi-image matching literature such as
[Multi-Image Matching via Fast Alternating Minimization](https://arxiv.org/abs/1505.04845)
as a starting point for cycle-consistent association, while retaining the
project's physical ray and pass-correlation model.

### 7.5 Later time-varying correction

After constant OPK is stable, add a smooth correction field over image time:

- an ideal per-column model only for analysis/upper-bound experiments;
- small rotation vectors in the local attitude tangent space, composed with
  nominal attitude rather than interpolated Euler angles;
- cubic B-spline control posts initially every 128 image columns;
- second-difference smoothness/IMU priors;
- a pass-common low-frequency component plus per-image variation; and
- observability-driven automatic coarsening, with finer spacing allowed only
  when dense support demonstrates local observability.

Dense correspondence may supply enough observations, but parameter density
must be limited by actual spatial/temporal support. The solver should coarsen
posts automatically when a segment is weakly observed.

Provide a discrete active-pair/full-network `Re-match` control after material
correction. It creates a new ledger generation from fresh current geometry,
preserves the prior generation, and invalidates downstream filter/solve state.
Preview and apply global corrections atomically across all solved images with
one network-level revert. Review common/differential/effective OPK, covariance,
bounds, prior dominance, predicted displacement, rank, components, and
sensitivity before Apply; changing evidence or gauge requires a re-solve.

## 8. Dense Correspondence Quality Program

The existing MATLAB SGM path is a baseline to measure, not a presumed final
algorithm. Keep it as a supported built-in SDK adapter. The completed
`ProjectionDenseSurfaceExtractor` remains compatible while a new abstract
dense-correspondence class normalizes requests/results and allows SGM,
classical template matching, and caller plugins.

### 8.1 Baseline audit

Use the truth-aware synthetic fixture to characterize SGM across:

- intersection angle and range;
- terrain relief and occlusion;
- same-band and cross-band pairs;
- pointing-only and combined navigation errors;
- rectification error;
- repetitive and low-texture regions;
- disparity span;
- uniqueness thresholds; and
- CPU/GPU execution where supported.

Record completeness, gross-outlier rate, subpixel error, height error,
left/right consistency, occlusion behavior, runtime, and memory. Retain SGM
only where the evidence supports it. Do not add an automatic `Best` method
until deterministic selection rules are supported by truth.

### 8.2 Sparse-seeded dense search

Use accepted sparse tracks and their triangulated points to predict local
disparity, epipolar direction/curve, depth range, and search uncertainty. The
dense matcher should use these predictions to avoid one oversized global
disparity interval.

Partition the image into regions with coherent predicted geometry, while
allowing uncertainty to widen the search near depth discontinuities and areas
without sparse support. Seeds constrain search rather than force matches onto a
sparse surface; allow evidence-supported unseeded regions and retain explicit
`no support` where extrapolation would be arbitrary. Compare seeded/unseeded
truth to detect bias and record which sparse tracks shaped each search range.

### 8.3 Classical dense template matcher

Develop an explainable multi-scale matcher that can search along local
epipolar curves or locally rectified strips. Candidate costs include:

- zero-mean normalized cross correlation;
- gradient correlation;
- census/rank transforms for cross-band robustness; and
- phase correlation for selected translation-dominant patches.

Required quality controls include:

- best-versus-second-best uniqueness;
- forward/backward consistency;
- subpixel refinement;
- texture/conditioning score;
- explicit occlusion/no-match state;
- local geometric prediction residual; and
- deterministic tie handling.

Compare the matcher with SGM rather than replacing SGM by assertion. A hybrid
may use SGM in well-rectified textured regions and template search elsewhere.

Every result reports one explicit state: valid, occluded, ambiguous/repetitive,
insufficient texture, outside overlap, geometry/search failure, masked, or
algorithm failure. Normalize confidence from uniqueness, forward/backward
consistency, texture/conditioning, geometric residual, and subpixel fit, but do
not call it probability until calibrated against truth. Preserve raw scores,
competing multimodal hypotheses, deterministic ties, and rejection reasons.

### 8.4 Spatially varying epipolar geometry

General pushbroom pairs may not admit one global rectifying homography. Support
one of:

- direct search along sampled epipolar loci;
- piecewise local rectification with overlap and blending; or
- a common terrain-coordinate working grid with source-coordinate truth maps.

The selected representation must preserve continuous mappings back to both
full source images and must expose rectification residuals.

Sparse-alignment and dense-reconstruction pair schedules are separate. Dense
selection favors overlap, conditioning, complementary baselines, texture,
radiometric compatibility, and visibility; it need not use every sparse edge.
When four or more useful views exist, reserve an independent validation view
where practical. Provide operator inclusion/exclusion and `All plausible
pairs`, predicted cost/memory/geometry, and an explanation for every selection.

## 9. Multi-View Point Reconstruction And Fusion

### 9.1 Preserve pair provenance

Every dense pair match produces two source observations, two corrected rays,
a match score, geometric diagnostics, and a provisional triangulation. Keep
these records even when points are later fused.

### 9.2 Prefer multi-ray reconstruction over point averaging

Simple spatial clustering and averaging of pairwise points is an acceptable
initial oracle, but the preferred model associates consistent pair matches into
dense multi-view tracks and solves one point against all contributing rays with
a robust loss.

The provenance-rich 3-D point set is authoritative. Raw pairwise points remain
distinct from robust multi-view points; meshes, voxel products, and grids are
derived and retain contributing point IDs. Weight independent views/passes,
not repeated pair multiplicity. Split competing depth/occlusion modes rather
than forcing one point, and retain valid two-view tracks with explicit labels.

For each reconstructed point, record:

- contributing views and pairs;
- ray parameters and forward-validity;
- robust residuals and rejected rays;
- intersection geometry/condition number;
- radiometric consistency;
- visibility/occlusion state; and
- covariance or an explicit reason it is unavailable.

### 9.3 Pair and point selection

More views are not automatically better. Reject or down-weight observations
with nearly parallel geometry, poor texture, inconsistent visibility, weak
navigation state, or conflicts with the multi-view solution. Preserve at least
one independent validation view when practical.

### 9.4 Volumetric occupancy and evidence-fusion research spike

Evaluate a bounded volumetric representation as an alternative or complement
to direct multi-ray point fusion. This is a legitimate multi-view research
direction, but several distinct ideas must not be conflated:

1. **Point-vote occupancy.** Each pairwise or multi-ray reconstruction deposits
   a weighted vote or uncertainty kernel into nearby voxels.
2. **Ray-likelihood occupancy.** Ray pairs or bundles contribute an intersection
   likelihood volume rather than one hard point.
3. **Photoconsistency/space carving.** Voxels are retained or removed using
   visibility and radiometric agreement across source images.
4. **Signed-distance fusion.** Pair-derived depth maps contribute weighted
   signed-distance observations to a common volume.

The first spike uses small truth-aware ROIs and a sparse voxel hash or
multiresolution octree. Compare direct robust multi-ray reconstruction, hard
voxel occupancy, and uncertainty-weighted Gaussian splats. Derive and sweep
voxel scale from GSD/3-D uncertainty, preserve competing modes, and count
independent views/passes rather than raw pair multiplicity.

Potential uses include:

- coalescing noisy pairwise points into consensus modes;
- retaining vertical/urban structure that a DEM cannot represent;
- identifying competing depth hypotheses;
- visualizing weak or contradictory geometry; and
- providing a coarse initialization or diagnostic objective for pose/OPK
  refinement.

An occupancy-concentration objective could attempt to sharpen voxel evidence by
adjusting image corrections. Test smooth alternatives such as Gaussian voxel
splats, kernel-density concentration, entropy, or likelihood rather than a
discontinuous maximum-bin count. Treat this as a coarse auxiliary objective,
not the primary alignment solver, until synthetic truth demonstrates that it
does not reward false collapse, duplicate correlated evidence, or excessive
smoothing.

Compare the volume against direct robust multi-ray least squares on point
accuracy, completeness, uncertainty calibration, memory, scale sensitivity,
urban surfaces, and runtime. Abandon it if it adds no reliable information.

The literature review should begin with the classic distinctions among
[voxel coloring](https://publications.ri.cmu.edu/photorealistic-scene-reconstruction-by-voxel-coloring),
[space carving](https://doi.org/10.1023/A:1008191222954), and
[weighted signed-distance fusion](https://doi.org/10.1145/237170.237269), then
identify methods appropriate to sparse, uncertain airborne ray geometry.

### 9.5 Surface products

Keep these stages distinct:

1. raw pairwise points;
2. robust multi-view points;
3. filtered/classified point cloud;
4. optional local mesh/TIN;
5. optional gridded elevation product; and
6. optional DEM-registered variants.

Do not smooth or grid away provenance. Urban vertical surfaces and overhangs
cannot be represented faithfully by a single-valued DEM.

Return results directly to MATLAB through a versioned SDK value. Near-term
persistence is MAT (`-v7.3` when required) plus compact JSON metadata. LAS/LAZ,
PLY, GeoTIFF, NITF, and other production exports are deferred and must not
block reconstruction, fusion, visualization, or SDK delivery.

## 10. Surface Reconstruction Workbench

Create a separate floating **Surface Workbench** rather than overloading the
main viewer or Alignment Workbench.

Candidate regions:

- input image network and selected passes;
- pair scheduler and pair-quality table;
- dense method and geometry-search settings;
- processing stages and progress/cancel controls;
- pairwise/multi-view point statistics;
- uncertainty and conditioning filters;
- DEM registration/comparison controls;
- output-product selector; and
- full diagnostics/export region.

The workbench should launch or control a 3-D surface/point viewer supporting:

- point cloud, mesh, and gridded modes;
- coloring by source intensity, height, view count, residual, uncertainty,
  pair/pass, or DEM difference;
- camera-linked selection back to source observations;
- uncertainty ellipsoids or compact principal-axis glyphs on demand;
- raw versus fused versus registered comparison; and
- bounded decimation for interaction without discarding the full result.

The first release explicitly supports raw pairwise, robust multi-view,
uncertainty-filtered, voxel/fusion, DEM, and DEM-difference products. Color by
intensity, elevation, view/pass count, residual, uncertainty, conditioning,
fusion method, or DEM difference. Link selected 3-D points back to contributing
source observations; render uncertainty glyphs only for selected/bounded
subsets. Defer production mesh editing and GIS cartography.

Graphics handles remain runtime-only. Dense results should gain an explicit
serializable product contract only after the data model and size policy are
reviewed.

## 11. Rigorous Uncertainty Model

### 11.1 Inputs

Eventually support covariance and correlation for:

- platform position and velocity;
- platform attitude and OPK correction;
- pass-common and view-differential errors;
- gimbal angles, boresight, lever arm, timing, and scan rate;
- source pixel localization and dense-match subpixel error;
- projection/master-plane parameters where used; and
- reference DEM height and horizontal registration.

The initial contract uses one full 6x6 common pose covariance per pass and one
6x6 differential pose covariance per image, including position/attitude cross
terms, plus a 2x2 source-observation covariance. The observation vector is
continuous full-source `[column,row]` in pixels and covariance units are
pixels-squared. Working/pyramid/rectified covariance maps back through the same
coordinate Jacobian. For pushbroom imagery column uncertainty maps to timing
through line rate. Missing uncertainty is unavailable, not zero; every block
records units, frame, ordering, and prior/posterior/calibrated/assumed status.

Same-pass correlations are essential. Treating every ray independently would
dramatically overstate the information gained from many images sharing one
navigation bias.

### 11.2 Propagation

For well-conditioned local cases, begin with carefully scaled central numerical
Jacobians and propagate covariance through ray formation and multi-ray
triangulation:

```text
Sigma_point = J * Sigma_inputs * J^T
```

Validate against synthetic truth and Monte Carlo, then replace high-volume
derivatives with analytic/automatic versions only after parity. For nonlinear,
bounded, multimodal, or weak geometry, compare linearized covariance with
sigma-point or Monte Carlo propagation. Report conditioning and non-Gaussian
behavior rather than publishing a misleading ellipse.

The global alignment solver should expose an approximate posterior covariance
or selected marginal covariances using its sparse normal equations. Dense-match
cost margins are confidence indicators, not calibrated probabilities; use
synthetic truth to calibrate them before converting them into observation
variance.

### 11.3 Outputs

Provide per-point 3-D covariance, principal axes, horizontal/vertical
uncertainty, view/pass contribution count, and dominant uncertainty source.
Surface gridding must propagate or summarize point uncertainty rather than
reporting only sample variance. Store the 3x3 covariance in the authoritative
world frame in meters-squared, validate symmetry/positive semidefiniteness, and
mark unreliable nonlinear results instead of silently repairing them.

## 12. DEM Registration Without DEM-Forced Intersection

The DEM is an uncertain external reference, not a hard surface constraint.
Maintain the imagery-only reconstruction and optionally estimate a registration
between it and the DEM.

### 12.1 Registration model

Begin with one global 3-D translation in a scene-local ENU frame. Estimate it
with robust point-to-local-DEM-surface-normal residuals weighted by
reconstruction covariance, DEM uncertainty, slope, and conditioning. Defer
small rotation, pass translation, and low-order trajectory terms until truth
shows they are distinguishable.

Use robust point-to-DEM or point-to-local-surface-normal residuals weighted by
both reconstructed-point covariance and DEM uncertainty.

The non-blocking initial DEM input is DTED Level 2 or an equivalent WGS84
latitude/longitude elevation grid. Heights may be HAE or MSL; MSL defaults to
EGM96. If DTED height reference is omitted, assume MSL/EGM96 and record the
assumption. An optional no-data sentinel plus NaN/Inf defines validity; no
separate mask is required. Caller CE90/LE90 wins, then valid dataset metadata,
then DTED2 defaults CE90=23 m and LE90=18 m. Preserve those 90% metrics and
state any Gaussian conversion assumptions; do not treat cells as independent.

Normalize working heights to HAE, convert geodetic data to double-precision
scene-local ENU, and preserve exact transforms to WGS84/ECEF and the project
world frame. Never mix HAE and orthometric height silently. Richer per-cell
uncertainty/classification masks remain optional enhancements.

### 12.2 Bias avoidance

- Exclude or robustly down-weight buildings, vegetation, water, changed areas,
  and DEM voids.
- Do not snap each reconstructed point to the DEM.
- Do not use the same DEM-constrained points as independent validation.
- Preserve raw and registered products side by side.
- Report the estimated transform, uncertainty, coverage, residual distribution,
  and sensitivity to masks/regions.

Urban mismatch is expected and scientifically useful; it must not be erased by
forcing intersections onto the terrain model.

Registration returns a proposed correction through the SDK and preview-only
registered product; it never auto-applies. A later explicit atomic position-
correction operation validates scope/frame, preserves rollback, updates
compatible source origins, invalidates geometry-dependent matches/solves/dense
products/registration, and requires rerunning alignment/reconstruction. Report
gauge or datum confounding rather than claiming unique position knowledge.

## 13. Numerical Precision Policy And Validation

Do not apply one blanket precision choice to the entire pipeline. Establish a
documented precision policy for each data product and computation boundary,
with double precision as the scientific reference until evidence supports a
narrower type.

### 13.1 Questions to answer

1. Does the current single-precision interactive geometry retain acceptable
   screen position, layer registration, stereo ordering, and responsiveness at
   the 100 km required range and the `min(200 km, geometric horizon)` stretch
   range?
2. Is single precision acceptable only because viewer coordinates are shifted
   to a local render origin, and what happens when large absolute coordinates
   enter before that shift?
3. Which source-ray, plane-intersection, inverse-mapping, and triangulation
   operations are sensitive to cancellation or nearly parallel geometry?
4. Can backend radiometric interpolation use single-valued images while its
   coordinate and intersection calculations remain double?
5. Must OPK optimization, Jacobian formation, normal-equation accumulation,
   factorization, and convergence tests remain double, or is a mixed-precision
   solve reliable after scaling/preconditioning?
6. What precision is required to keep propagated covariance symmetric,
   positive semidefinite, and meaningful when small eigenvalues coexist with
   large world-coordinate magnitudes?
7. Can dense cost volumes, correlation scores, disparity fields, voxel
   accumulators, and GPU kernels use single or reduced precision while subpixel
   refinement, triangulation, fusion, and uncertainty remain double?
8. Which values may be converted at boundaries without allowing display
   precision to contaminate scientific/backend state?

### 13.2 Candidate policy to test, not assume

- Source imagery and display textures retain their natural/integer or selected
  working radiometric type.
- Viewer surfaces and camera-relative display coordinates may use single when
  local origin/scale and visual-error tests pass.
- Serializable source geometry, platform origins, ray directions, plane/camera
  definitions, and scientific corrections remain double by default.
- Backend coordinate generation, ray intersection, output-grid mapping, and
  truth products use double reference geometry; interpolated radiometry may use
  a separately selected working precision.
- Solver state, Jacobian accumulation, normal equations, factorization, and
  posterior covariance remain double initially.
- Dense matching and voxel evidence may use mixed precision if final
  reconstruction is recomputed or refined in double and confidence calibration
  is unchanged.
- GPU implementations may use single/mixed kernels, but must compare against a
  double CPU oracle and report the actual precision path.

### 13.3 Validation matrix

Test double, single, and proposed mixed paths across:

- near and nominal ranges, the required 100 km threshold, and the stretch
  `min(200 km, geometric horizon)` using local WGS84 curvature and observer
  HAE; primary tests use an unrefracted geometric horizon;
- small local coordinates and large translated world coordinates representing
  the same relative geometry;
- shallow plane incidence and nearly parallel ray intersections;
- small baselines, wide baselines, and multi-pass position biases;
- repeated transform composition and plane-basis changes;
- well-conditioned and weakly conditioned OPK networks;
- covariance matrices spanning several orders of magnitude;
- dense subpixel matching, height recovery, and voxel accumulation; and
- CPU versus future CUDA execution.

Measure world-point error, range error, reprojection/pixel error, OPK recovery,
ray separation, height error, covariance eigenvalues, solver convergence,
visual registration, memory, and runtime. Include catastrophic thresholds for
NaN/Inf, sign/eye reversal, loss of positive semidefiniteness, and changes in
accepted/rejected observations.

Provisional scale-aware gates are under 0.1 screen pixel for display geometry
and under 0.01 full-source pixel for well-conditioned backend mapping, with no
material validity/eye/acceptance changes. Solver differences must be small
relative to posterior uncertainty; point/fusion differences must be small
relative to GSD and predicted uncertainty; covariance must preserve symmetry,
PSD behavior, and principal structure. Mixed/CUDA paths must also demonstrate
meaningful measured runtime or memory benefit before adoption.

### 13.4 Precision boundaries and provenance

Every cast should occur at an explicit boundary and be testable. Runtime
diagnostics and scientific outputs should record geometry precision,
radiometric working precision, solver precision, covariance precision, and GPU
precision. Display-only single arrays must be derived/discardable and must not
replace authoritative double geometry.

The existing viewer/backend single-versus-double tolerance evidence is useful
but is not sufficient by itself for long-range triangulation, global solving,
or covariance. Re-run the precision matrix whenever coordinate scale, source
geometry, solver parameterization, or hardware backend changes.

## 14. MATLAB SDK And Extension Surface

The MATLAB implementation needs a documented SDK that supports automation and
third-party algorithm development without requiring callers to manipulate app
widgets or internal scene state. The current lightweight viewer launch remains
valid: image arrays, layer names, geometry structures, and a plane structure
are sufficient. Optional identifiers, pass metadata, start times, and line
rates enrich the SDK but do not make basic launch onerous.

### 14.1 Correction-result API

Provide one immutable network-level `CorrectionSet` for a solver/registration
generation. Per-view records are keyed by stable `ViewId`/`PassId`; typed blocks
cover pass-common, differential, and effective OPK, global/pass translation,
and later timing, boresight, gimbal, or posted time-varying OPK.

Each result should contain at least:

- stable view and pass identifiers;
- correction generation and whether the result is proposed, accepted, applied,
  superseded, or rejected;
- explicit angle order, units, sign convention, reference frame, and whether
  values are increments or absolute quantities;
- pass-common, per-image differential, and effective total OPK corrections;
- the original and corrected geometry revisions or fingerprints;
- covariance/selected marginals, conditioning, prior contribution, bounds,
  and observability status when available;
- solver, match-ledger, track, gauge, precision, and configuration provenance;
- diagnostics and a machine-readable reason when no valid correction exists;
  and
- a versioned collection of named future correction blocks, such as position,
  timing, boresight, or smoothly posted OPK, each with its own units and frame.

Authoritative angles/covariance are radians/radians-squared, with explicit
degree/degree-squared convenience accessors. Never expose unitless `OPK`.
Record `[omega,phi,kappa]` order, active/passive meaning, composition order,
source/destination frames, multiplication side, increment sign, and
incremental/absolute/common/differential/effective semantics. Existing public
APIs retain their required units through adapters.

Preserve immutable base geometry and exact generation lineage. Compose attitude
through rotations, not OPK vector addition. Every result distinguishes an
increment relative to its parent geometry from the effective correction
relative to base. Reapply is idempotent or rejected; wrong-parent application
fails; revert restores an exact generation rather than applying a negative.

Expose narrow public operations to retrieve the current accepted results,
retrieve a named historical generation, apply compatible results explicitly,
and serialize/deserialize portable result data. Application must validate view
identity, geometry revision, convention, dimensions, and compatibility before
mutation. Reading results must never require that the GUI remain open.

An optional callback/event may notify an embedding application that a new
accepted correction generation exists, but event delivery is supplementary;
the authoritative result remains queryable. The SDK must distinguish solver
output from operator acceptance and actual application.

Headless functions return `CorrectionSet` directly. Interactive launch may
accept `CorrectionAcceptedFcn`, `CorrectionAppliedFcn`, and
`CorrectionRevertedFcn`; callbacks receive immutable results, fire only on the
named transition, run on the MATLAB client/UI thread, and cannot roll back a
successful scientific operation when callback code fails. Expose queryable
current/history APIs because callbacks are never authoritative storage.

S2 hardens the S1 value boundary before enabling mutation:

- reject an incoming correction-set `Format` or schema `Version` that is
  missing where required, malformed, or unsupported; never overwrite an
  incompatible portable schema and interpret it as the current version;
- require every function-backed source geometry to expose a stable
  serializable geometry revision/fingerprint token, or classify compatibility
  as unverifiable and reject Apply. Do not serialize function workspaces or
  private fixture values merely to identify a closure;
- allow only explicit valid lifecycle transitions. Proposal, acceptance,
  rejection, application, supersession, and historical/reverted state are
  immutable records; no transition mutates an earlier result in place;
- reject failed, rejected, superseded, historical, wrong-parent, stale,
  identity-mismatched, pass-mismatched, convention-mismatched, or
  dimension-mismatched results before any scene mutation;
- validate the complete declared view scope first, apply to a scene copy,
  recompute and compare every corrected geometry fingerprint, and publish the
  new scene/current generation only after all checks pass;
- revert by restoring and verifying the exact parent generation/fingerprints,
  never by negating a correction. Reapply is idempotent or explicitly
  rejected and can never double-compose a rotation;
- keep a graphics-independent authoritative generation store with queries for
  current proposed/accepted/applied state and named history. GUI state and
  callbacks are clients, not the history owner;
- deliver accepted/applied/reverted callbacks only after the corresponding
  transition commits, on the MATLAB client/UI thread, with deterministic
  ordering and reentrancy protection. Callback exceptions are reported and
  retained in diagnostics but never roll back scientific state; and
- preserve the existing legacy runner/degree APIs through explicit adapters.
  Their historical automatic-safe-apply behavior may remain for compatibility,
  but it must not become the new SDK lifecycle contract.

S2 focused tests cover unsupported schema rejection, explicit geometry
revision handling for function-backed sources, every valid and invalid
lifecycle transition, all-scope atomicity, corrected-fingerprint verification,
exact revert, stale/wrong-parent/reapply protection, history queries, callback
ordering/reentrancy/failure isolation, headless use, GUI integration, and
legacy behavior.

### 14.2 Dense-correspondence extension API

Provide an abstract MATLAB base class from which
callers can implement custom dense correspondence algorithms. The workbench
and backend should consume the interface, not branch on concrete algorithms.

The base contract should define:

- algorithm identity, semantic version, capabilities, required products, and
  supported image/radiometric/geometry forms;
- option schema, defaults, validation, and an explainable capability check;
- a pair request containing stable view IDs, analysis images or bounded
  readers, validity masks, continuous source-coordinate maps, corrected source
  geometry, overlap ROI, epipolar/search predictions, precision policy, and
  deterministic seed;
- a result containing continuous observations in both full source images,
  validity/no-match/occlusion states, score and confidence measures, optional
  subpixel covariance, diagnostics, timing, memory, and algorithm provenance;
- progress and cooperative cancellation hooks that are independent of UI
  components; and
- deterministic behavior and explicit CPU/GPU capability/fallback reporting.

The base implementation should own common contract validation, coordinate and
mask checks, cancellation plumbing, result normalization, provenance, and
error classification. Derived implementations should supply only their
algorithm-specific preparation and matching logic. No extension may return a
display pyramid, preview coordinate, or dense surface as if it were a full
source observation.

Requests provide bounded read-only in-memory analysis arrays, masks, and
continuous mappings to full source coordinates. File I/O/tiling is not required
of plugins; an optional region-reader capability may come later. Plugins declare
CPU/GPU, size/memory estimate, bands/types, rectification/epipolar support,
determinism, and cancellation. They neither mutate nor retain caller arrays,
and return continuous full-source observations even when working in pyramids or
rectified/local grids.

Begin with adapters for the existing SGM path and the planned classical dense
template matcher. Provide a small documented example matcher and conformance
tests so an external developer can validate a subclass without launching the
viewer. Registration should be explicit through a factory/registry supplied by
the embedding application; do not scan arbitrary paths or instantiate classes
from untrusted serialized names.

### 14.3 Surface-fusion extension API

Provide a documented abstract `ProjectionSurfaceFusionAlgorithm`-style class.
Its request carries stable view/pair/pass/track IDs, corrected rays/source
observations, provisional pair/multi-ray points, covariance, visibility,
bounded ROI/frame, scale/precision/seed, progress, and cancellation. Results may
contain fused points, sparse voxel/octree evidence, competing modes, optional
derived mesh/grid, uncertainty, contributor counts, rejection reasons, runtime,
memory, precision, and provenance.

The base class owns validation, units/frames/covariance, deterministic seed,
cancellation, error classification, provenance, result conformance, and
CPU/GPU reporting. Initial subclasses implement robust multi-ray fusion, hard
voxel occupancy, and Gaussian splatting. Registration is explicit through a
caller registry; serialized class names are never instantiated automatically.

### 14.4 DEM-registration extension API

Provide direct headless registration plus a derivable
`ProjectionSurfaceRegistrationAlgorithm`-style class. Requests contain the
imagery-only result, DEM/geodetic/datum/uncertainty/masks, ROI, allowed
transform, robust/convergence/precision/seed/progress/cancellation. Results
contain the proposed transform/covariance/direction/frame, support/rejections,
residual/sensitivity/provenance, preview descriptor, correction block, and
explicit success/ambiguity/degeneracy/failure. The first built-in implements
robust global 3-D translation. The base class enforces datum/frame validation,
uncertainty normalization, result validation, and no automatic application.

### 14.5 Scene-suitability extension API

Add an optional upstream screener that returns full-source masks/quality maps
for invalid geometry, cloud/obscuration, water, low texture, saturation,
repetition, and severe radiometric incompatibility. Begin with deterministic
invalid/texture/saturation checks; cloud/water await suitable data. Preserve
confidence/provenance/generation, report usable coverage, allow operator
override, and distinguish unobservable input from matcher/solver failure.
Expose a documented derivable class for domain-specific screeners.

### 14.6 SDK compatibility and documentation

- Version public request/result schemas independently from scene serialization.
- Preserve existing `PlanarProjection` and `Projection*` API names.
- Prefer immutable value-like results and pure conversion/validation helpers.
- Keep authoritative numeric results usable in headless MATLAB workflows.
- Include concise examples for launching, retrieving corrections, applying a
  reviewed result, registering a matcher, running it headlessly, and consuming
  its source-coordinate result.
- Add contract, round-trip, stale-result, convention, subclass-conformance,
  cancellation, and failure-path tests.
- For every derivable class, document lifecycle, mathematical field meaning,
  frames/axes/units/covariance, minimal and advanced examples, headless use,
  determinism/cancellation/memory/tiling/GPU guidance, version compatibility,
  and a third-party conformance suite plus deliberately simple example plugin.
- Near-term scientific persistence is MAT plus compact JSON metadata. Rich
  production export formats remain deferred and non-blocking.

## 15. Code-Independent Mathematical Specification

Produce one self-contained LaTeX paper/PDF using the `IEEEtran` two-column
journal format. Target technical stakeholders, photogrammetry/estimation
reviewers, and MATLAB/C++ implementers. Keep the main narrative readable and
put detailed derivations, Jacobians, degeneracies, and covariance expansions in
appendices within the same PDF. It is a living technical specification, not
software documentation.

### 15.1 Required content

1. Coordinate frames, handedness, notation, and homogeneous transforms.
2. Platform, roll-gimbal, pitch-gimbal, and line-scanner image formation.
3. Plane construction, plane-basis parameterization, and ordered-corner
   conventions.
4. Ray formation and ray/plane/terrain intersection.
5. Image projection and full-source inverse resampling.
6. Sparse feature detection, description, matching, masking, and track
   construction.
7. Image-space consensus and epipolar/coplanarity constraints.
8. Pairwise and global OPK objectives, robust losses, priors, gauge freedoms,
   bounds, and observability.
9. Same-pass and multi-pass covariance structure.
10. Pair-camera midpoint, presentation-only pair orientation, and the
    distinction between view orientation, plane-basis reparameterization, and
    physical plane replacement.
11. Stereo eye assignment, anaglyph formation, depth/separation controls, and
    the exact display-only stereo-exaggeration transform used by the viewer.
12. Dense epipolar search, local rectification, template costs, subpixel
    refinement, and occlusion checks.
13. Pairwise triangulation and robust multi-ray reconstruction.
14. Uncertainty propagation and conditioning.
15. Multi-view fusion, surface formation, and DEM registration.
16. Numerical precision, coordinate scaling, cancellation, mixed-precision
    boundaries, and validation metrics.
17. Limitations and degeneracies.

### 15.2 Style

- Define symbols once in a nomenclature table.
- Use diagrams for frames, gimbal order, rays, plane bases, stereo parallax,
  image network, and uncertainty geometry.
- Use plain language around each equation.
- Avoid class names, cache/tile terminology, UI implementation details, and
  repository-specific abstractions.
- Distinguish physical transforms from presentation transforms throughout.
- Cite primary photogrammetry, multiple-view geometry, estimation, and image
  matching literature.
- Describe SDK algorithm boundaries by mathematical inputs, outputs, and
  invariants without discussing code-level classes.

Build and visually inspect the PDF. Keep LaTeX source, bibliography, figures,
and a reproducible build command together when this work is eventually added to
the repository.

## 16. Pure Procedural Two-Image Reference

Before the C++ port, implement a deliberately direct MATLAB reference for the
two-image anaglyph path. It should accept only:

- two in-memory image arrays;
- the physical plane;
- viewer camera/presentation parameters;
- two source-geometry structs/functions; and
- explicit output/grid/stereo options.

It should perform, in visible procedural order:

1. output-grid or viewport definition;
2. output sample reconstruction on the physical plane;
3. inverse mapping into each source geometry;
4. full-source radiometric interpolation and validity masking;
5. physically correct left/right assignment;
6. the exact display-only separation/depth/exaggeration transform;
7. red/cyan composition; and
8. output plus explainable metadata.

Avoid object hierarchies, runtime caches, tile pools, GUI dependencies, and
hidden state. Small helper functions are acceptable when they make the matrix
algebra legible.

Golden tests must compare this reference against the production MATLAB pipeline
for image values, masks, eye assignment, plane coordinates, and stereo controls.
This becomes both an executable appendix to the math document and the first
translation oracle for the C++ team.

Use double geometry as the default procedural oracle. Add explicit, separately
named single/mixed experiments rather than allowing MATLAB's implicit casting
to define the reference behavior.

## 17. High-Performance C++ Backend Strategy

### 17.1 Approach

Do not make MATLAB Coder output the primary production architecture. Instead:

1. freeze code-independent equations and data contracts;
2. maintain the procedural MATLAB oracle;
3. create small public golden fixtures and tolerances;
4. transcode one kernel/workstream at a time;
5. compare C++ results against MATLAB after every stage;
6. profile before selecting parallel/GPU implementations; and
7. retain an explainable CPU reference path.

Codex-assisted translation can reduce hand-porting effort, but generated code
must be reviewed as ordinary production C++ and validated numerically. No
translation is accepted solely because it compiles.

### 17.2 Candidate architecture

- Modern C++ core with explicit array views, ownership, units, and coordinate
  frames.
- Explicit scalar/precision policy: authoritative double geometry and solver
  paths, with selected float/mixed kernels behind typed boundaries and parity
  tests.
- Stable C ABI or narrow language-neutral boundary for integration.
- CMake build and reproducible dependency management.
- MATLAB MEX/CUDA MEX and command-line harnesses during parity development.
- Native 64-bit Windows/MSVC is the first MATLAB/CUDA target. WSL 2 supplies a
  secondary GCC/Clang Linux CPU/CUDA command-line build; Linux binaries are not
  loaded into Windows MATLAB. Keep a portable CPU core for later macOS/Linux.
- CPU geometry/resampling/alignment/dense kernels first.
- Optional GPU kernels behind capability and equivalence checks.
- Streaming and in-memory execution policies selected by product context.
- NITF output only after the scientific pipeline is stable.

### 17.3 Library evaluation gates

Benchmark and review licenses rather than committing prematurely. Eigen and
Ceres are leading candidates and should receive explicit prototypes rather
than remaining generic placeholders:

- **Eigen** for fixed/small dense geometry, transformations, Jacobian blocks,
  and selected sparse structures, with BLAS/LAPACK backends benchmarked for
  larger dense work;
- **BLAS/LAPACK** as optional measured backends for sufficiently large dynamic
  dense operations; Eigen remains the small fixed-size geometry layer and may
  delegate supported large operations to MKL, OpenBLAS, Accelerate, or another
  reviewed implementation;
- **Ceres Solver** for robust nonlinear least squares, automatic/analytic
  differentiation comparisons, parameter bounds/manifolds, and bundle-style
  sparse solves;
- Ceres linear-solver alternatives including Eigen, LAPACK/BLAS, SuiteSparse,
  and its supported CUDA/cuDSS paths, selected by measured problem structure;
- **OpenCV** as an optional provider for interpolation, pyramids, filters,
  transforms, features/descriptors/matching, consensus geometry, morphology,
  connected components, and selected CPU/CUDA primitives, always wrapped behind
  Sightline coordinate/mask/provenance contracts;
- TIFF/PNG libraries for prototype parity;
- GDAL/PROJ or an equivalent reviewed stack for geospatial and eventual NITF
  needs;
- standard threads, a task runtime, or OpenMP for bounded CPU parallelism;
- CUDA or another explicitly selected GPU backend only after profiling; and
- established unit-test and benchmark frameworks.

Selection criteria are performance, numerical control, determinism, supported
platforms, licensing/export constraints, maintenance health, API stability,
and suitability for the eventual deployment environment.

OpenCV 4.5+ is Apache-2.0; SIFT is a normal candidate, while SURF/nonfree
modules remain disabled by default and require explicit legal/deployment
review. Prefer permissive production-compatible dependencies, pin versions and
CMake flags, and do not introduce GPL/copyleft constraints without approval.
Evaluate vcpkg or Conan rather than choosing a dependency manager by assertion.

Do not assume that one backend wins at every scale. Small cycle/track blocks may
favor Eigen, while large global normal equations may favor SuiteSparse or a
GPU-enabled Ceres backend. Measure factorization time, Jacobian construction,
transfer cost, memory, convergence, and deterministic repeatability separately.

### 17.4 MATLAB-hosted CUDA stepping stone

Before a standalone C++ application, use the MATLAB pipeline as an oracle and
test harness for selected CUDA kernels on the future Windows/NVIDIA system.
MathWorks supports CUDA MEX through `mexcuda` and direct `gpuArray` exchange
through the GPU MEX API, so kernels can be invoked without first replacing the
viewer or scene orchestration.

The first custom CUDA/MEX experiment is the dense template/correlation cost
kernel (ZNCC and/or census/gradient cost over bounded epipolar strips). It has
high arithmetic intensity, an isolated contract, and direct dense-matcher SDK
value. Candidate later kernels are:

- dense matching cost-volume or template-correlation evaluation;
- epipolar-strip resampling;
- batched ray/terrain or ray/ray calculations;
- full-source inverse interpolation; and
- voxel vote/splat accumulation.

For every kernel:

- retain a complete CPU MATLAB reference;
- capability-check CUDA and fall back cleanly;
- compare values, masks, edge cases, and error policy;
- measure allocation, host/device transfer, kernel, and synchronization time
  separately;
- keep GPU buffers/contexts runtime-only and out of serializable scene state;
- reuse buffers only behind an explicitly discardable cache; and
- verify that viewer integration does not make graphics/UI callbacks wait on
  unnecessary transfers.

Start with a standalone functional/MEX harness, then add an optional call from
the MATLAB viewer or Surface Workbench only after parity and responsiveness are
demonstrated. This work can mature CUDA kernels and data layouts before the
larger C++ port while keeping MATLAB as the acceptance oracle. Relevant primary
references are the [MathWorks CUDA/MEX interface](https://www.mathworks.com/help/parallel-computing/gpu-cuda-and-mex-programming.html),
the [Ceres installation and accelerator options](https://ceres-solver.readthedocs.io/latest/installation.html),
and the [NVIDIA CUDA Programming Guide](https://docs.nvidia.com/cuda/cuda-programming-guide/index.html).

### 17.5 Staged C++ port

1. Freeze frames, units, scalar types, array layouts, masks, and error policy.
2. Coordinate frames, planes, cameras, gimbals, and ray kernels.
3. Procedural two-image inverse renderer/anaglyph plus MEX and CLI parity.
4. Full-source interpolation, output grids, and prototype TIFF/PNG.
5. Source-geometry adapters and time-dependent scan models.
6. Sparse observations, pair/track graph, and constant-OPK global solver.
7. Dense matcher contracts and selected CPU/OpenCV algorithms.
8. CUDA dense costs after the MATLAB-hosted spike succeeds.
9. Multi-ray reconstruction, uncertainty, and plugin-compatible fusion.
10. DEM ingestion/registration and correction results.
11. Surface Workbench acceleration hooks only after standalone parity.
12. Production I/O/NITF, packaging, deployment, and broader GPU hardening.

Each stage requires MATLAB/C++ parity, independent C++ tests, adversarial
geometry tests, memory/error-policy review, and performance profiling.

The validation matrix compares MATLAB double CPU; native Windows C++ CPU,
CUDA, MEX, and CUDA MEX; WSL 2 Linux C++ CPU/CUDA; and later native Linux. Use
identical public fixtures and record compiler/flags/dependencies, hardware,
driver/runtime, precision, values/masks/source coordinates/corrections/
covariance/error policy/determinism, and transfer/runtime breakdown. WSL is
informative but never substitutes for native Windows MATLAB integration.

## 18. Ordered Feature Trees

These trees are coordinated but should remain separately reviewable.

### Tree A: Multi-Image Alignment And Viewer

1. **A0 — Multi-image foundation — complete as MI-0/MI-1.** Stable view/pass/
   pair identity, optional timing, deterministic runtime pair schedule.
2. **A1 — Active pair and stereo presentation — complete as MI-2/MI-3.**
   Selection, swap, stepping, Solo/restore, physical eye invariants/override.
3. **A2 — Pair viewpoint — complete.** Midpoint camera, fit/restore, optional
   follow, manual-motion suspension, explicit unavailable reasons, and
   presentation-only active-pair orientation without plane mutation.
4. **A3a — Keyboard and manual motion imagery — complete.** Focus-aware
   remapping shipped as A3a-1. A3a-2 adds explicit sequence/order, strict UTC
   parsing, manual stepping, measured edge controls with persistent fallback,
   identity labels, Loop, visible warnings, and exact runtime restore.
5. **A3b — Motion playback — complete.** Measured 0.5-10 fps playback adds
   Space/Escape, sequential no-skip display, one-frame lookahead, explicit
   pause reasons, bounded cache/memory diagnostics, and interaction evidence.
6. **A4 — Multi-view tracks and pair graph — complete.** Conflict-safe stable
   tracks and direct-versus-composed path diagnostics feed an explainable
   nonsequential quality graph. The default graph is a deterministic quality
   spanning forest plus complementary loop chords, with forced overrides,
   quality/speed, hard maximum, all-plausible, predicted-cost, component,
   degree, cycle-basis, rejection, and connectivity diagnostics.
7. **A5 — Global constant-OPK solve — complete.** Robust epipolar network
   adjustment is the primary visible-layer solve when ray geometry is
   available. Unique track evidence, fixed ray origins, explicit gauge
   preflight, bounded robustification, covariance, component/weak-view, and
   track/pass/region residual diagnostics are retained.
8. **A6 — Same-pass/multi-pass priors — complete.** Explicit pass-common and
   prior-weighted zero-mean per-image differentials support single pass,
   multiple passes, and independent/custom-prior configurations. Independent
   pass components, prior dominance, systematic pass/time/region/position
   conflicts, and leave-one-pair-out sensitivity are reported.
9. **A7 — Time-varying correction research — complete.** The truth-free
   linearized study uses local tangent rotation vectors, cubic spline posts
   nominally every 128 columns, second-difference priors, pass-common plus
   per-image terms, support/rank/condition-driven coarsening, and a held-out
   truth audit. Per-column fitting is an analysis upper bound. Portable
   research CorrectionSet blocks are reviewable but explicitly cannot Apply;
   production promotion remains gated on physical observability and stability.

### Tree B: Multi-View Dense Surface

1. **B0 — SGM truth audit — complete.** The held-out public matrix quantifies
   range/angle, relief/occlusion, radiometry, navigation/rectification, texture,
   disparity, execution, accuracy, consistency, runtime, and memory behavior.
2. **B1 — Sparse-seeded pair scheduler — complete.** Independent explainable
   dense pair scheduling and regional seeded/unseeded/no-support search priors
   retain cost, memory, validation-view, uncertainty, and track provenance.
3. **B2 — Dense template matcher — complete.** Deterministic multi-scale local
   strip search provides four classical costs, uniqueness/tie/texture,
   subpixel, bidirectional consistency, prediction residual, confidence, and
   explicit state evidence with continuous full-source output.
4. **B3 — Pairwise point covariance — complete.** Forward-valid pair
   triangulation exposes separation/conditioning and propagates full-source
   observation plus correlated ray-state geometry covariance into explicit
   world-frame point covariance and reliability status.
5. **B4 — Volumetric fusion research spike — complete.** The bounded held-out
   roof/parapet audit compares sparse hard occupancy, uncertainty-weighted
   Gaussian splats, and direct multi-ray reconstruction over GSD-derived scale
   sweeps. All preserve competing modes and ignore pair multiplicity, but the
   voxel variants do not improve the authoritative point accuracy/completeness;
   they remain diagnostic only and authoritative promotion is abandoned.
6. **B5 — Dense multi-view association and multi-ray solve — complete.** Stable
   full-source observations form deterministic conflict-safe tracks; unique
   view/pass evidence drives robust multi-ray points with rejected-ray,
   conditioning, radiometry, visibility, covariance, two-view, competing-mode,
   raw-pair provenance, and MAT/compact-JSON records.
7. **B6 — Surface Workbench and 3-D viewer — complete.** A strict portable
   product catalog and headless selection model drive a separate responsive
   Workbench and runtime-only point/voxel/mesh/grid viewer with comparison,
   full-source links, selected uncertainty glyphs, diagnostics, cost/memory
   estimates, and non-destructive decimation.
8. **B7 — DEM registration — complete.** Strict WGS84/DTED2 ingestion,
   HAE/MSL-EGM96 normalization, shared DEM uncertainty, robust global ENU
   point-to-normal translation, mask/ambiguity evidence, complete preview, and
   Workbench products preserve the imagery-only points.
9. **B8 — Explicit DEM position-correction apply — complete.** Live-scene
   binding validates generation/frame/view/pass scope and position-only terms;
   S2 applies compatible source origins atomically with fingerprint proof and
   exact revert, then invalidates dependent evidence and requires recomputation.

### Tree C: Mathematical And Procedural References

1. **C0 — Notation and equation inventory — complete.** Frozen frames,
   transforms, objectives, degeneracy states, precision boundaries, stable
   equation identifiers, and presentation/scientific distinctions are recorded
   in `docs/mathematical_reference/notation_and_equation_inventory.md`.
2. **C1 — IEEE-style LaTeX manuscript — complete.** The self-contained,
   code-independent IEEEtran source, bibliography, reproducible build script,
   and six-page compiled PDF are committed under `docs/mathematical_reference/`
   and `output/pdf/`.
3. **C2 — Procedural two-image/anaglyph oracle — complete.** The direct
   `proceduralTwoImageAnaglyph` path visibly implements double-precision grid,
   inverse-map, full-source sampling, eye, display-offset, mask, and red/cyan
   algebra; eight golden tests compare it with production components.
4. **C3 — Multi-image/dense appendices — complete.** The manuscript appendices
   cover Jacobians, observability, dense costs, multi-image association,
   fusion/registration, the procedural companion, and cross-language
   conformance.

### Tree S: MATLAB SDK

1. **S0 — SDK inventory and public boundary — complete.** Existing callable
   launch, solve, apply, export, and dense entry points were inventoried with
   versioning, headless behavior, conventions, and compatibility risks while
   preserving existing public API names.
2. **S1 — Correction-result contract — complete.** Stable per-view/pass
   generation values include exact rotation lineage, complete OPK convention
   metadata, geometry fingerprints/stale checks, provenance, covariance status,
   diagnostics, MAT/portable JSON, legacy adapters, and a headless solve API.
3. **S2 — Correction application and notification — complete.** Strict schema
   and function-backed-geometry revision checks precede mutation. Compatible
   generations apply/revert atomically through immutable authoritative history;
   proposal/acceptance/application remain distinct and post-transition callbacks
   are ordered, reentrancy-protected, and failure-isolated.
4. **S3 — Dense matcher base contract — complete.** Validated request/result
   types, abstract matcher lifecycle, cancellation/progress, provenance,
   explicit registry, current-SGM adapter, and subclass conformance are present.
5. **S4 — Built-in adapters and example extension.** Wrap the existing SGM
   implementation, integrate the future template matcher, and ship a minimal
   documented external-style matcher example.
6. **S5 — SDK guide and compatibility suite.** Document end-to-end automation
   and extension examples and establish schema/API compatibility tests.
7. **S6 — Surface-fusion extension — complete.** Strict request/result values,
   a sealed base lifecycle, explicit registry, built-in multi-ray/hard-voxel/
   Gaussian adapters, external-style example, persistence, and conformance
   tests are present.
8. **S7 — DEM-registration extension — complete.** A sealed derivable
   lifecycle, strict request/result values, explicit registry, direct headless
   service, robust and external-style adapters, persistence, proposed
   CorrectionSet output, and held-out conformance/audit tests are present.
9. **S8 — Scene-suitability extension.** Add masks/quality results, deterministic
   baseline screener, documented plugin interface, and operator override.

### Tree D: C++ Production Backend

1. **D0 — Requirements, Eigen/Ceres/BLAS/OpenCV/dependency, licensing,
   Windows/WSL build, and benchmark study.**
2. **D1 — MATLAB-hosted CUDA/MEX kernel spike on the target Windows GPU.**
3. **D2 — Geometry and two-image procedural parity spike.**
4. **D3 — Full inverse renderer and prototype TIFF/PNG output.**
5. **D4 — Multi-image sparse alignment and global solve.**
6. **D5 — Dense matching, voxel/multi-ray reconstruction, and fusion.**
7. **D6 — Uncertainty, DEM registration, and surface products.**
8. **D7 — Production I/O/NITF, GPU, and deployment hardening.**

### Tree P: Precision And Numerical Integrity

1. **P0 — Precision inventory — complete.** The executable inventory classifies
   authoritative, derived, display, backend, solver, covariance, dense, truth,
   fusion, and GPU boundaries by role and current/required type.
2. **P1 — Viewer long-range validation — complete.** Double reference and
   single display candidates are compared with local and large origins through
   required 100 km and stretch `min(200 km, geometric horizon)`; single is safe
   only after double render-origin subtraction.
3. **P2 — Scientific mixed-precision matrix.** Test backend mapping,
   triangulation, global OPK, covariance, dense refinement, and voxel fusion;
   select explicit boundaries.
4. **P3 — CUDA precision study.** Compare float, double, and selected mixed
   kernels on target hardware, including transfer and refinement costs.

## 19. Dependency And Recommended Order

The synthetic, backend-performance, MI-0 through MI-3, and S0 audit queues are
complete. The ordered implementation queue is:

1. Preserve the current grouped fresh-class baseline, now 716/716 after C0-C3.
2. A2 pair viewpoint/follow and presentation-only orientation — complete.
3. A3a focus-aware keyboard remapping — complete.
4. A3a manual motion imagery — complete.
5. A3b motion playback and performance evidence — complete.
6. S1 immutable `CorrectionSet`, MAT/JSON, stale protection, OPK adapter — complete.
7. S2 callbacks and explicit apply/revert/generation lineage — complete.
8. A4 multi-view tracks and cycle diagnostics — complete.
9. A4 explainable pair graph and quality/max/all-pair controls — complete.
10. A5/A6 global constant-OPK network solve and pass-aware priors — complete.
11. Multi-image synthetic acceptance matrix — complete.
12. P0/P1 precision inventory and required/stretch range validation — complete.
13. S3 dense-matcher base and current SGM adapter — complete.
14. B0 truth-aware SGM audit — complete.
15. B1 sparse-seeded dense pair/search planning and B2 classical template
    matcher — complete.
16. B3/B5 multi-ray reconstruction and initial uncertainty — complete.
17. S6/B4 surface-fusion SDK and bounded voxel spike — complete; voxel evidence
    remains diagnostic and robust multi-ray remains authoritative.
18. B6 Surface Workbench — complete.
19. S7/B7 DEM ingestion, uncertainty, registration, preview translation — complete.
20. B8 explicit DEM-derived position-correction application — complete.
21. A7 time-varying OPK research — complete; production application remains
    gated on physical local observability and stability.
22. C0-C3 manuscript/procedural oracle at stable checkpoints — complete.
23. Windows MATLAB-managed GPU validation, then D1/P3 CUDA/MEX dense-cost spike.
24. D0 and staged C++ port after corresponding MATLAB contracts/fixtures freeze.

The bounded A7 research study is complete because constant global alignment and
dense observation contracts are available. Its synthetic audit is not physical
observability evidence, so production time-varying application remains gated.
The C0-C3 reference pack freezes the implementation-independent equations and
adds a direct, tested two-image translation oracle. The next ordered item is
the external Windows MATLAB-managed GPU gate, followed by D1/P3 only when the
required target hardware is available.
The full C++ dense backend begins only after the MATLAB dense/fusion product
contract is selected.

### Continuous execution authorization

Beginning with S2, a worker is authorized to continue through this ordered
queue without requesting permission after each green pack. For every coherent
pack, it shall inspect current state, implement only the ordered scope, run
focused tests and checkcode, run every logical fresh-class suite group through
separate MATLAB MCP calls, update directly relevant documentation, commit,
push, confirm a
clean worktree, and proceed to the next item.

Pack completion, a clean validation result, or a choice already resolved by
this workplan/SRS is not a reason to wait. Stop and request direction only for
a genuine design ambiguity that would materially change the product, overlapping
user/concurrent changes that cannot be preserved, a repeated required MATLAB
MCP failure, a validation failure requiring user judgment, unavailable
external data/hardware that is essential to the next dependency, invalid
repository authentication, or another unsafe/irreversible action outside the
approved scope. Hardware-gated GPU work shall not block independent ordered CPU
work, but the worker shall not silently skip an unresolved dependency.

MATLAB execution remains MCP-only for unattended work. Never launch MATLAB
through a shell, request an out-of-sandbox MATLAB process, or use GUI-launch
workarounds. Git add, commit, and push shall be separate direct noninteractive
commands with explicit paths/messages; use the already approved narrow
escalation for parent Git metadata or sandboxed network access rather than
waiting for the user to run Git.

## 20. Remaining Evidence, Hardware, And Later-Parameter Gates

No unresolved design question blocks the ordered CPU/MATLAB queue. Remaining
gates are deliberately resolved by implementation evidence or later user input:

1. Final numerical thresholds after the recorded precision and truth studies.
2. Which dense matcher(s) and pair policies survive truth-aware audit.
3. Voxel fusion retention — resolved for the initial bounded spike. It preserves
   modes and provides diagnostic evidence but adds no accuracy/completeness
   value over robust multi-ray, so authoritative promotion is abandoned.
4. Cloud/water screening methods after suitable data exists.
5. Per-pass position/rotation and time-varying OPK density after observability.
6. Stop-sign/curved-orbit radii, leg counts, turns, and independent-pass
   parameters in a separately approved fixture pack.
7. MATLAB-managed GPU and CUDA behavior on the Windows RTX workstation.
8. Eigen/Ceres/SuiteSparse/BLAS/OpenCV backend choices from measured problem
   scale, license, and deployment evidence.
9. vcpkg versus Conan and final production platforms/toolchains.
10. Production LAS/LAZ/PLY/GeoTIFF/NITF mappings; MAT/JSON suffice meanwhile.

## 21. Acceptance Themes

Every pack should be judged on:

- correctness against known truth and adversarial geometry;
- same-pass and multi-pass behavior;
- deterministic repeatability;
- explicit provenance and failure reasons;
- preservation of CPU and public API behavior;
- headless MATLAB SDK usability and explicit schema/convention compatibility;
- separation of presentation and scientific state;
- explicit precision boundaries and parity against a double scientific oracle;
- no private fixture values in committed code/docs/tests;
- bounded interaction and computation cost;
- clean GUI presentation; and
- focused commit/push boundaries with full validation where appropriate.

## 22. Locked Planning Decisions 1-75

The following decisions are approved implementation requirements. They preserve
the discussion state for handoff; the normative sections above consolidate the
same requirements by subsystem.

1. Every image has a stable `ViewId`; preserve caller IDs and generate missing
   IDs independently of filename, path, layer order, or display name.
2. The caller supplies `PassId` for multi-pass work. If absent, place all views
   in one pass; never infer passes from filenames.
3. Preserve the lightweight launch contract. Optionally accept one start time
   and line rate per image, derive line times from image size and scan metadata,
   permit absolute or relative time, and degrade time-dependent tools
   explicitly when timing is absent.
4. Score all possible pairs cheaply when affordable, but run expensive matching
   on a selected subset by default. Put quality/speed and maximum-pair controls,
   an `All plausible pairs` override, and estimated cost in the workbench.
5. The initial graph combines sequential neighbors, nonsequential chords, and
   useful cross-pass edges to remain connected and cycle-rich.
6. Small image sets use every plausible overlapping pair when affordable.
7. Cycle consistency initially validates tracks/edges and diagnoses
   contradictions; it is not an additional solver residual unless evidence
   later justifies it.
8. A track has at most one observation per image and rejects ambiguous
   transitive merges.
9. Begin with automatic tracks, track diagnostics and enable/disable, plus
   pair-level curation. Defer observation-level editing until needed.
10. Preserve a globally block-sparse solve with small dense track/cycle blocks;
    do not intentionally form a globally dense matrix.
11. Effective OPK equals a pass-common component plus a per-image differential
    component, with a weighted zero-mean differential constraint per pass and
    separate reporting of both components.
12. Passes have independent common OPK components and are joined by cross-pass
    tracks; per-image differential corrections remain nested within each pass.
13. Default to balanced covariance/prior gauge control. Do not silently fix the
    first image; offer an explicit fixed-reference mode and record the policy.
14. The first network solver holds ray origins fixed and estimates constant OPK
    only. Diagnose position-like residuals and defer translation/trajectory
    parameters to a separate observability-driven pack.
15. Use robust epipolar coplanarity by default with valid ray geometry, after a
    loose catastrophic image-space filter. Retain ray-to-ray and plane-based
    diagnostics/fallbacks and do not call a global straight-line approximation
    exact for pushbroom data.
16. Pair-only solve is diagnostic, preview, or warm-start functionality. The
    global network Apply is durable; explicit pair-only application invalidates
    or reassesses affected observations.
17. Provide a discrete re-match control after material correction, with active-
    pair and enabled-network scopes. Preserve old/new ledger generations and
    invalidate downstream filter/solve state until rerun.
18. Treat disconnected components as input/observability problems. Solve a
    component only with a valid gauge, otherwise stop and explain. Later add an
    upstream cloud/water/low-texture/invalid-geometry screener that reports and
    masks rather than silently discarding.
19. Preview and apply a global result atomically across all solved images, with
    one network-level revert and consistent match/track/overlay generations.
20. Expose `Single pass`, `Multiple passes`, and `Independent views / custom
    priors` presets that configure grouping and priors over one solver.
21. Put the active-pair bar at the top of the Alignment Workbench: reference and
    moving selectors, swap, previous/next scheduled pair, status, enable state,
    and `Solo pair`. Pair changes update inspection state but do not auto-match
    or mutate corrections. The main viewer gains no permanent pair controls.
22. Keep reference/moving roles separate from left/right stereo eyes. Derive eye
    assignment geometrically with hysteresis near degeneracy, keep red on the
    left eye, and provide a visible resettable manual override.
23. `Solo pair` snapshots all runtime visibility, follows active-pair changes,
    restores exactly on exit/close, handles added/deleted layers safely, and is
    never serialized into scene/layer data.
24. Pair navigation uses a deterministic explicit schedule: same-pass temporal
    neighbors, same-pass chords, cross-pass pairs, then remaining custom/all-
    pair candidates. Skip disabled pairs normally, allow review inclusion, and
    replace the stored runtime schedule only on explicit regeneration.
25. `Pair viewpoint` uses representative origins over shared overlap, their
    midpoint, the common-footprint centroid, plane-derived stable up, footprint
    fitting, and restore. It is one-shot by default. An opt-in runtime `Follow
    active pair` checkbox reapplies it during pair navigation; manual camera
    motion suspends following for the current pair and navigation resumes it.
26. Routine pair orientation is presentation-only. Do not mutate/serialize the
    plane basis; advanced basis/physical-plane changes require separate full
    reprojection, invalidation, preview, and rollback.
27. Motion order uses caller order, otherwise time within pass and stable
    fallback; do not interleave incomparable clocks; no-wrap default plus Loop.
28. Preferred UTC text is `DDMMYY_HHmmSS[.fraction]`, with four-digit-year and
    numeric-relative alternatives, `80-99 -> 1980-1999` and
    `00-79 -> 2000-2079`, strict parsing, and original-text provenance.
29. Motion mode is context-launched, non-stereo, single-frame, uses applied
    geometry only, snapshots/restores presentation exactly, and remains runtime.
30. Shift+Arrows adjust Tip/Tilt. Normal plain Left/Right select layers without
    visibility mutation; Up/Down reuse vertical nudges. Motion Left/Right step
    frames and Up/Down do not mutate. Only viewport focus captures shortcuts.
31. Manual motion ships first; measured playback follows at 0.5-10 fps (2 fps
    default), no interpolation/skips, one-frame lookahead, and runtime Loop.
32. Motion Space toggles play; outside it preserves hold-to-hide. Escape exits,
    manual step pauses, focus/data/sequence changes pause with reason.
33. Transient/pinnable frame identity reports layer, position, UTC time, pass,
    applied-correction state, and persistent fallback/stale/load warnings.
34. Motion membership is explicit and visibility-independent, defaults to all
    eligible images, supports pass/include filters, and requires two frames.
35. Provenance-rich 3-D points are authoritative; pairwise/multi-view stages
    remain distinct and mesh/voxel/grid/registered products are derived.
36. Associate dense observations into tracks and robustly solve all rays;
    never average duplicated pair points as independent evidence.
37. Sparse and dense pair schedules are separate; dense selection favors
    complementary useful geometry and may reserve an independent validation view.
38. SGM remains a supported baseline adapter; template/custom matchers share one
    contract, no hidden automatic method/fallback before truth evidence.
39. Sparse seeds create uncertainty-aware dense search priors, not forced
    surfaces; allow supported unseeded matching and report no-support/bias.
40. Dense results carry explicit valid/occluded/ambiguous/texture/overlap/
    geometry/masked/algorithm states; confidence is not probability until calibrated.
41. Initial uncertainty is pass-common 6x6 plus image-differential 6x6 pose
    covariance and full-source `[column,row]` 2x2 pixels-squared observation covariance.
42. Start covariance propagation with scaled central Jacobians, validate by
    truth/Monte Carlo, use double, and label nonlinear/unreliable results.
43. Initial DEM registration is robust global ENU 3-D translation using
    surface-normal residuals; preserve raw and preview registered products.
44. DEM input is non-blocking WGS84/DTED2 oriented: HAE or MSL/EGM96, optional
    sentinel/masks/CE90/LE90, DTED2 defaults 23 m CE90/18 m LE90.
45. Normalize DEM work to double scene-local ENU/HAE with reversible WGS84/ECEF/
    project transforms and never silently mix height datums.
46. First voxel spike compares multi-ray, hard occupancy, and Gaussian splats
    on bounded truth ROIs/resolution sweeps with an explicit abandon criterion.
47. Surface fusion is a fully documented derivable MATLAB SDK class with common
    validation, provenance, cancellation, capability, examples, and conformance.
48. The separate Surface Workbench inspects raw/fused/uncertain/voxel/DEM
    products, links points to sources, and uses runtime decimation/glyph bounds.
49. Dense ROIs live in world/plane space, map to full sources, support bounded
    previews/chunk overlap, deterministic boundaries, and explicit uncovered area.
50. Return surface results in memory; MAT plus compact JSON is sufficient.
    LAS/LAZ/PLY/GeoTIFF/NITF cannot block near-term implementation.
51. DEM registration returns a proposed SDK correction; explicit later apply is
    atomic/revertible, updates origins, invalidates dependencies, and reruns.
52. DEM registration has headless service plus a documented derivable SDK class;
    the first built-in is robust translation and never auto-applies.
53. One immutable network `CorrectionSet` holds typed per-view/pass correction
    blocks, lifecycle, covariance, provenance, geometry fingerprints, and status.
54. Authoritative OPK uses radians/radians-squared with explicit degree accessors
    and complete order/frame/composition/sign/multiplication semantics.
55. Headless calls return `CorrectionSet`; optional accepted/applied/reverted
    callbacks supplement queryable history and cannot corrupt successful state.
56. Matcher inputs are bounded read-only arrays/mappings; plugins declare
    capabilities and return normalized full-source observations without retention.
57. The math specification is one self-contained IEEEtran two-column living
    paper with appendices for engineers, reviewers, and technical stakeholders.
58. Authoritative geometry/solvers/covariance/backend mapping remain double;
    single/mixed is limited to explicit discardable/intermediate boundaries.
59. Precision acceptance uses scale-aware gates: 100 km required and
    `min(200 km, geometric horizon)` stretch, with unrefracted primary horizon.
60. First custom CUDA/MEX spike is bounded dense template/correlation cost;
    standalone parity/performance precedes any viewer integration.
61. C++ uses modern core plus stable C ABI, Eigen/Ceres prototypes, optional
    CUDA, MATLAB/CLI harnesses, CPU reference, and no MATLAB-Coder architecture.
62. OpenCV is optional behind Sightline contracts; Eigen covers small geometry,
    optional BLAS/LAPACK large dense work, and nonfree SURF requires review.
63. The procedural MATLAB two-image/anaglyph reference is direct double matrix
    algebra, production-parity tested, SDK example, paper companion, C++ oracle.
64. First accelerated target is Windows x64/MSVC/MATLAB-compatible CUDA; CMake
    portable CPU core and WSL2 GCC/Clang/CUDA CLI are secondary build paths.
65. One golden-fixture matrix covers MATLAB, Windows CPU/CUDA/MEX, WSL CPU/CUDA,
    and later Linux, recording full toolchain/hardware/precision/runtime provenance.
66. C++ port order freezes contracts, then geometry/procedural renderer,
    adapters/alignment, dense/CUDA, uncertainty/fusion/DEM, and production I/O.
67. Time-varying OPK uses tangent-space cubic splines, initial 128-column posts,
    smoothness/pass-common priors, observability coarsening, and SDK output.
68. Optional scene suitability produces full-source masks/quality/provenance and
    a derivable SDK screener; it never silently deletes images/evidence.
69. Future simulation uses a trajectory/pass provider: polygon stop-sign legs,
    then curved paths, independent pass errors and optional shared calibration.
70. Multi-image truth validation covers 2/3/4/6 views, graph variants, errors,
    corruption, texture/occlusion/masks, baselines, repeatability, and uncertainty.
71. Implement in the ordered queue in section 19; small validated commits/pushes
    remain required and CPU work is not blocked by hardware-gated GPU work.
72. Default pair graph is a quality spanning forest plus deterministic useful
    loop chords under quality/max/all controls and explicit connectivity reports.
73. Global solve defaults to interpretable Huber robustification with bounded
    scale, separate priors, retained weights/rejections, and optional Cauchy study.
74. Review the complete global generation and re-solve after evidence/gauge
    edits; never edit numbers and label them solver output or partially apply.
75. Preserve immutable base/parent geometry; compose rotations exactly, expose
    incremental/effective corrections, reject stale/reapply, and revert exactly.

This consolidated workplan is active as the ordered source of truth. A feature
tree enters implementation only when explicitly dispatched; evidence/hardware
gates remain non-blocking for unrelated CPU work.
