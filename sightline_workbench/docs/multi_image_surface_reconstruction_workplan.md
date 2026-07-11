# Sightline Workbench Multi-Image And Surface Reconstruction Workplan

Status: planning draft. The dense-surface synthetic expansion and Backend
Performance Packs 2-5 are complete. This document is now backed up in the
repository for safety, while continued planning remains in the `/private/tmp`
working copy. Only explicitly dispatched packs are an active implementation
queue; unresolved decisions remain planning gates.

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

Add a compact active-pair selector to the Alignment Workbench. It should
support:

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

Provide a `Solo pair` action that temporarily shows only the two active layers.
It must:

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
current camera cannot establish a stable left/right ordering.

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
a documented representative origin, normally the center-column origin or a
robust mean over the overlapping acquisition interval. Then:

- place the viewer camera at the midpoint of the two representative origins;
- aim at the centroid of the active pair's mutually visible footprint;
- derive up from the current plane basis and pair geometry;
- fit the pair footprint without changing scene geometry; and
- preserve a one-step `Restore camera` action.

This command changes only presentation. It is useful for intuitive stereo
ordering and baseline inspection but must not redefine the projection plane or
source geometry.

### 5.2 What an “equivalent plane for another image” means

If four supplied image corners all lie on one constant-elevation physical
plane, that plane is already common to every image observing that surface. A
different view does not require rotating the plane normal. Two distinct
operations may nevertheless be useful:

1. **Reparameterize the same plane.** Keep the plane origin and normal on the
   same geometric locus, but rotate its in-plane basis so its horizontal and
   vertical axes align naturally with another image or active pair. This
   changes plane coordinates and presentation orientation, not the physical
   intersection surface.
2. **Replace the master plane.** Fit a new origin/normal from a different
   physical surface, local tangent plane, or curved-Earth approximation. This
   changes intersections, footprints, working grids, overlays, caches, and
   backend products and therefore requires a preview, explicit confirmation,
   recomputation, and rollback.

For reparameterization, project the selected view's ordered corner observations
onto the existing physical plane and solve an orthonormal in-plane basis that
best aligns with the average image-row and image-column directions. A small
two-dimensional Procrustes fit or averaged-edge construction is appropriate.
The lower-left/anticlockwise convention fixes handedness and prevents an
unintended mirror.

### 5.3 Pair-derived plane-basis command

Consider a `Orient plane axes to active pair` command after the mathematical
behavior is tested. It should preview old/new axes and explain that only the
basis is changing. A separate, deliberately stronger `Replace master plane`
workflow belongs in an advanced scene tool, not beside routine pair controls.

## 6. Motion-Imagery Presentation Mode

Add a non-stereo motion-imagery mode that displays one aligned layer at a time
while retaining a fixed viewer camera and projection plane.

### 6.1 Interaction

- Order frames by explicit acquisition time, with manual order as a fallback.
- Left/right arrow keys select previous/next visible frame.
- Optional edge affordances appear only while the pointer is near the left or
  right viewport edge and disappear when it leaves.
- A small transient label shows image name, time, pass, and sequence position.
- Later additions may include play/pause, frame rate, ping-pong, and difference
  modes.

### 6.2 Main-view cleanliness and performance

The arrows should be viewport overlays, not permanent side-panel controls.
They must be inactive outside motion mode and must not trigger tile selection,
mesh rebuilding, layer restacking, or full redraw on every pointer event.

Prototype two implementations and measure them:

1. demand-activated lightweight UI controls near the viewport edges; and
2. axes/figure overlay glyphs with hit regions.

Pointer handling should update only when the hover state changes. If hover
tracking measurably degrades pan/zoom/crosshair interaction, retain keyboard
navigation and use subtle persistent arrows instead.

Motion mode temporarily solos the current frame but preserves/restores the
operator's prior visibility and stereo state.

## 7. Global Multi-Image Alignment Solver

### 7.1 First parameterization

Start with one constant OPK vector per image. For accepted track observations,
minimize a robust sum of pairwise epipolar/coplanarity residuals plus pass-aware
priors. Sparse matrix structure should be preserved: each residual touches only
the observations and image parameters involved in that track/pair.

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

The graph should retain enough nonsequential redundancy to close loops, detect
bad edges, and improve long-baseline observability without paying the full
quadratic pair cost. Useful policies to compare include minimum-degree graphs,
maximum-spanning overlap/geometry trees augmented with the best loop-closing
edges, and pass-aware chord selection. Diagnostics should show which cycles
support or contradict each pair.

### 7.4 Cycle-aware solver structure

Build the global objective from unique track observations and physical
residuals, with cycle closure primarily serving data association, edge
validation, and optional consistency penalties. Algebraically, a track seen in
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

- an ideal per-column OPK model for analysis and upper-bound experiments;
- a practical set of OPK control posts at configurable column intervals;
- interpolation or spline basis between posts;
- smoothness/IMU priors; and
- observability-driven adaptive post spacing.

Dense correspondence may supply enough observations, but parameter density
must be limited by actual spatial/temporal support. The solver should coarsen
posts automatically when a segment is weakly observed.

## 8. Dense Correspondence Quality Program

The existing MATLAB SGM path is a baseline to measure, not a presumed final
algorithm.

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
only where the evidence supports it.

### 8.2 Sparse-seeded dense search

Use accepted sparse tracks and their triangulated points to predict local
disparity, epipolar direction/curve, depth range, and search uncertainty. The
dense matcher should use these predictions to avoid one oversized global
disparity interval.

Partition the image into regions with coherent predicted geometry, while
allowing uncertainty to widen the search near depth discontinuities and areas
without sparse support.

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

### 8.4 Spatially varying epipolar geometry

General pushbroom pairs may not admit one global rectifying homography. Support
one of:

- direct search along sampled epipolar loci;
- piecewise local rectification with overlap and blending; or
- a common terrain-coordinate working grid with source-coordinate truth maps.

The selected representation must preserve continuous mappings back to both
full source images and must expose rectification residuals.

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

The first spike should use a small bounded ROI and a sparse voxel hash or
multiresolution octree. Compare a hard count, uncertainty-weighted kernel
density, and pass-balanced log-likelihood. Count independent views/passes, not
raw pair multiplicity, so a dataset with many correlated pairs does not appear
artificially certain.

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

Same-pass correlations are essential. Treating every ray independently would
dramatically overstate the information gained from many images sharing one
navigation bias.

### 11.2 Propagation

For well-conditioned local cases, propagate covariance through ray formation
and multi-ray triangulation with analytic or validated numerical Jacobians:

```text
Sigma_point = J * Sigma_inputs * J^T
```

For nonlinear, bounded, or weak geometry, compare linearized covariance with
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
reporting only sample variance.

## 12. DEM Registration Without DEM-Forced Intersection

The DEM is an uncertain external reference, not a hard surface constraint.
Maintain the imagery-only reconstruction and optionally estimate a registration
between it and the DEM.

### 12.1 Registration model

Begin with a low-dimensional transform appropriate to the expected navigation
error:

- horizontal/vertical translation;
- optional small rotation;
- optional pass-level position correction; and
- later low-order spatial/trajectory terms only when observable.

Use robust point-to-DEM or point-to-local-surface-normal residuals weighted by
both reconstructed-point covariance and DEM uncertainty.

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

## 13. Numerical Precision Policy And Validation

Do not apply one blanket precision choice to the entire pipeline. Establish a
documented precision policy for each data product and computation boundary,
with double precision as the scientific reference until evidence supports a
narrower type.

### 13.1 Questions to answer

1. Does the current single-precision interactive geometry retain acceptable
   screen position, layer registration, stereo ordering, and responsiveness at
   a 100 km standoff range?
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

- near, nominal, and maximum intended standoff ranges, explicitly including
  the 100 km case of concern;
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

Provide one stable, serializable result contract for accepted scientific
corrections. The caller must be able to retrieve corrections after preview or
application and use them independently of the viewer. The first result type
reports OPK, but its envelope must allow future correction blocks without
changing the meaning of existing fields.

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

Expose narrow public operations to retrieve the current accepted results,
retrieve a named historical generation, apply compatible results explicitly,
and serialize/deserialize portable result data. Application must validate view
identity, geometry revision, convention, dimensions, and compatibility before
mutation. Reading results must never require that the GUI remain open.

An optional callback/event may notify an embedding application that a new
accepted correction generation exists, but event delivery is supplementary;
the authoritative result remains queryable. The SDK must distinguish solver
output from operator acceptance and actual application.

### 14.2 Dense-correspondence extension API

Provide an abstract MATLAB base class or similarly strict interface from which
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

Begin with adapters for the existing SGM path and the planned classical dense
template matcher. Provide a small documented example matcher and conformance
tests so an external developer can validate a subclass without launching the
viewer. Registration should be explicit through a factory/registry supplied by
the embedding application; do not scan arbitrary paths or instantiate classes
from untrusted serialized names.

### 14.3 SDK compatibility and documentation

- Version public request/result schemas independently from scene serialization.
- Preserve existing `PlanarProjection` and `Projection*` API names.
- Prefer immutable value-like results and pure conversion/validation helpers.
- Keep authoritative numeric results usable in headless MATLAB workflows.
- Include concise examples for launching, retrieving corrections, applying a
  reviewed result, registering a matcher, running it headlessly, and consuming
  its source-coordinate result.
- Add contract, round-trip, stale-result, convention, subclass-conformance,
  cancellation, and failure-path tests.

## 15. Code-Independent Mathematical Specification

Produce a standalone LaTeX document compiled to PDF using an IEEE journal-style
template. It should read as a clear mathematical and algorithmic description,
not as software documentation.

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
10. Pair-camera midpoint and plane-basis reorientation.
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
- **Ceres Solver** for robust nonlinear least squares, automatic/analytic
  differentiation comparisons, parameter bounds/manifolds, and bundle-style
  sparse solves;
- Ceres linear-solver alternatives including Eigen, LAPACK/BLAS, SuiteSparse,
  and its supported CUDA/cuDSS paths, selected by measured problem structure;
- established image-processing primitives for interpolation, pyramids,
  descriptors, template costs, and morphology;
- TIFF/PNG libraries for prototype parity;
- GDAL/PROJ or an equivalent reviewed stack for geospatial and eventual NITF
  needs;
- standard threads, a task runtime, or OpenMP for bounded CPU parallelism;
- CUDA or another explicitly selected GPU backend only after profiling; and
- established unit-test and benchmark frameworks.

Selection criteria are performance, numerical control, determinism, supported
platforms, licensing/export constraints, maintenance health, API stability,
and suitability for the eventual deployment environment.

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

Candidate first kernels are those with high arithmetic intensity and simple,
explicit contracts:

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

1. Coordinate frames, planes, cameras, gimbals, and ray kernels.
2. Output grids, inverse mapping, interpolation, masks, and two-view anaglyph.
3. Source-geometry adapters and time-dependent scan models.
4. Sparse feature observation contracts and pair/track graph.
5. Global constant-OPK solver and pass-aware priors.
6. Dense pair matcher and occlusion/confidence logic.
7. Voxel/multi-ray reconstruction, uncertainty, and fusion.
8. DEM registration and surface products.
9. Production I/O, including NITF decision and metadata mapping.
10. Optional GPU acceleration and system-level performance hardening.

Each stage requires MATLAB/C++ parity, independent C++ tests, adversarial
geometry tests, memory/error-policy review, and performance profiling.

## 18. Ordered Feature Trees

These trees are coordinated but should remain separately reviewable.

### Tree A: Multi-Image Alignment And Viewer

1. **A0 — Contract audit and network model.** Formalize views, pairs, passes,
   tracks, stable identities, active-pair state, and pass-aware priors.
2. **A1 — Active pair and solo visibility.** Add selection, swap, pair stepping,
   solo/restore, and left/right invariants.
3. **A2 — Pair viewpoint and plane basis.** Add midpoint camera, fit/restore,
   and same-plane basis reorientation preview.
4. **A3 — Motion-imagery mode.** Add time ordering, keyboard stepping, measured
   edge-hover controls, and transient frame identity.
5. **A4 — Multi-view tracks and pair graph.** Reconcile pair matches into
   tracks; build an explainable nonsequential, cycle-rich schedule; and add
   cycle/path-consistency diagnostics without requiring all-pairs matching.
6. **A5 — Global constant-OPK solve.** Make robust epipolar network adjustment
   the primary solve when ray geometry is available.
7. **A6 — Same-pass/multi-pass priors.** Add pass-common/differential reporting,
   independent pass components, and conflict diagnostics.
8. **A7 — Time-varying correction research.** Add configurable smooth OPK posts
   only after dense support and observability are demonstrated.

### Tree B: Multi-View Dense Surface

1. **B0 — SGM truth audit.** Quantify where the current method succeeds/fails.
2. **B1 — Sparse-seeded pair scheduler.** Select useful pairs and predict local
   search geometry from sparse tracks.
3. **B2 — Dense template matcher.** Implement multi-scale epipolar/local-strip
   search with explicit confidence and occlusion.
4. **B3 — Pairwise point covariance.** Propagate geometry and match uncertainty
   and expose conditioning.
5. **B4 — Volumetric fusion research spike.** Compare sparse voxel occupancy,
   uncertainty-weighted splats, and direct multi-ray reconstruction on bounded
   truth-aware ROIs.
6. **B5 — Dense multi-view association and multi-ray solve.** Fuse observations
   before surface formation, retaining any useful volumetric representation as
   an optional product or auxiliary objective.
7. **B6 — Surface Workbench and 3-D viewer.** Inspect raw, fused, uncertain, and
   derived products without cluttering the main viewer.
8. **B7 — DEM registration.** Add uncertainty-weighted robust alignment while
   preserving unconstrained points.

### Tree C: Mathematical And Procedural References

1. **C0 — Notation and equation inventory.** Freeze frames, transforms,
   objectives, and presentation/scientific distinctions.
2. **C1 — IEEE-style LaTeX manuscript.** Write and compile the code-independent
   mathematical document.
3. **C2 — Procedural two-image/anaglyph oracle.** Implement the transparent
   MATLAB path and golden parity tests.
4. **C3 — Multi-image/dense appendices.** Extend equations as Trees A/B stabilize.

### Tree S: MATLAB SDK

1. **S0 — SDK inventory and public boundary.** Identify existing callable
   launch, solve, apply, export, and dense entry points; define versioning,
   headless behavior, conventions, and compatibility rules without changing
   existing public API names.
2. **S1 — Correction-result contract.** Add stable per-view/pass result values,
   correction generations, OPK convention metadata, provenance, covariance and
   diagnostics, plus query and portable round-trip APIs.
3. **S2 — Correction application and notification.** Validate and explicitly
   apply compatible result generations; distinguish proposed, accepted, and
   applied state; add optional embedding callbacks/events.
4. **S3 — Dense matcher base contract.** Add the request/result types, abstract
   matcher interface, common validation, cancellation, provenance, registry,
   and subclass conformance suite.
5. **S4 — Built-in adapters and example extension.** Wrap the existing SGM
   implementation, integrate the future template matcher, and ship a minimal
   documented external-style matcher example.
6. **S5 — SDK guide and compatibility suite.** Document end-to-end automation
   and extension examples and establish schema/API compatibility tests.

### Tree D: C++ Production Backend

1. **D0 — Requirements, Eigen/Ceres/dependency, licensing, and benchmark
   study.**
2. **D1 — MATLAB-hosted CUDA/MEX kernel spike on the target Windows GPU.**
3. **D2 — Geometry and two-image procedural parity spike.**
4. **D3 — Full inverse renderer and prototype TIFF/PNG output.**
5. **D4 — Multi-image sparse alignment and global solve.**
6. **D5 — Dense matching, voxel/multi-ray reconstruction, and fusion.**
7. **D6 — Uncertainty, DEM registration, and surface products.**
8. **D7 — Production I/O/NITF, GPU, and deployment hardening.**

### Tree P: Precision And Numerical Integrity

1. **P0 — Precision inventory.** Classify every authoritative, derived,
   display, backend, solver, covariance, dense, and GPU array by role and
   current type.
2. **P1 — Viewer long-range validation.** Compare double/single display
   geometry with local and large world origins across the intended range.
3. **P2 — Scientific mixed-precision matrix.** Test backend mapping,
   triangulation, global OPK, covariance, dense refinement, and voxel fusion;
   select explicit boundaries.
4. **P3 — CUDA precision study.** Compare float, double, and selected mixed
   kernels on target hardware, including transfer and refinement costs.

## 19. Dependency And Recommended Order

The synthetic-expansion and backend-performance queues are complete. The
recommended order for explicitly dispatched work is:

1. A0, S0, C0, and P0: freeze multi-image/SDK contracts, notation, and
   precision boundaries/inventory.
2. S1 alongside A0-A1 so solver results and active-view identities have one
   stable programmatic representation.
3. P1 alongside A1-A3: verify that viewer single precision remains safe at the
   intended scale while pair and motion controls are developed.
4. A1: active-pair/solo/left-right usability.
5. S2 after the first global result generation is stable.
6. A2: pair viewpoint and plane-basis behavior.
7. A3: motion-imagery presentation.
8. A4-A6: tracks, nonsequential cycle-rich pair graph, and global pass-aware
   OPK solve.
9. P2 before accepting A5/B3 numerical contracts: validate double and proposed
   mixed scientific paths.
10. B0 and S3: audit SGM while establishing the algorithm-neutral dense
    correspondence extension boundary.
11. S4 and B1-B3: built-in adapters, pair scheduling, improved dense matching,
    and point uncertainty.
12. B4: bounded voxel/volume fusion research spike with an explicit abandon
   criterion.
13. B5-B7: true multi-view fusion, Surface Workbench, and DEM registration.
14. C1-C3 and S5 throughout stable checkpoints, with the first compiled manuscript
   after A6 and a dense extension after B6.
15. D0 may begin as a library/architecture study, and D1/P3 may use the MATLAB
   harness for CUDA experiments once target hardware is available.
16. C2 before D2 so the systematic C++ port has a transparent executable
   oracle.
17. Production transcoding should not begin until the relevant MATLAB
   equations/contracts and golden fixtures are stable.

Time-varying OPK A7 begins only after constant global alignment and dense
observation support have measurable evidence. The full C++ dense backend begins
only after the MATLAB dense/fusion product contract is selected.

## 20. Decision Gates

Before activating this workplan in the repository, resolve or validate:

1. Whether acquisition timestamps and pass identifiers are always available or
   require explicit user metadata.
2. Default gauge policy for the global solver.
3. Exact representative-origin rule for time-dependent pair viewpoint and eye
   assignment.
4. Whether plane-axis reorientation should alter serialized plane coordinates
   or remain a presentation-only camera operation.
5. Motion-mode order, wrap behavior, and whether playback belongs in the first
   pack.
6. Pair-graph scoring weights, minimum nonsequential redundancy, and cycle-basis
   selection.
7. Whether cycle closure is used only for track/edge validation or also as an
   explicit solver penalty.
8. Which dense matcher(s) survive the truth audit.
9. Whether voxel occupancy/splatting adds value beyond multi-ray fusion and,
   if so, whether it is a product, diagnostic, initializer, or solver objective.
10. Primary surface product: provenance-rich point cloud, mesh/TIN, gridded
   elevation, or a staged combination.
11. Initial uncertainty input contract and which correlations are mandatory.
12. DEM registration transform family and stable-terrain masking strategy.
13. Scope and publication audience of the IEEE-style mathematical manuscript.
14. Precision selected for viewer display geometry, authoritative geometry,
    backend mapping, solvers, covariance, dense matching/fusion, and output;
    plus the range/conditioning evidence required for each choice.
15. Eigen/Ceres solver/backend choices for each problem scale.
16. First MATLAB-hosted CUDA kernel and the required Windows/MATLAB/CUDA
    compatibility matrix.
17. C++ target platforms, licensing constraints, NITF profile, and GPU/runtime
    requirements.
18. Exact MATLAB correction-result type, callback policy, accepted-versus-
    applied lifecycle, and portable serialization format.
19. Dense-matcher base-class lifecycle, request ownership, tiling/streaming
    boundary, registry policy, and minimum third-party conformance suite.

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

## 22. Locked Planning Decisions Through Pair-UX Item 25

The following decisions are approved and may be treated as implementation
requirements. They are recorded here so the discussion state survives thread
handoff. Item 26, physical-plane versus basis behavior, remains open.

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

This plan remains a planning draft. Repository backup does not activate every
feature tree; only explicitly dispatched packs enter implementation.
