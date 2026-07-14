# Architecture Concept Recommendations

Status: concept record, July 2026. Not an implementation workplan or accepted
scientific specification.

## Purpose And Authority

This document preserves the architecture recommendations discussed after the
D0 native C++ work-package summary. It records candidate directions for the
native dependency stack, CPU scheduling and image kernels, a future non-MATLAB
frontend, compact sensor geometry, atmospheric refraction, terrain-aware path
linearization, and progressive geometry evaluation.

These recommendations are intentionally forward-looking. They do not supersede
`software_requirements_specification.md`,
`multi_image_surface_reconstruction_workplan.md`, or the accepted D0 boundary
in `cpp_backend_d0.md`. A recommendation becomes an implementation requirement
only when it is promoted through the authoritative SRS and ordered workplan
with an explicit acceptance and validation gate.

MATLAB remains the current acceptance oracle. A native implementation may
become the scientific authority only after a separately approved milestone
defines the authority transition and demonstrates contract, numerical,
provenance, platform, and independent-truth parity. Completing D0 or adding an
optimized provider does not perform that transition.

## Consolidated Recommendation

The preferred long-term architecture is:

1. Keep a portable, dependency-light, double-precision native CPU reference as
   the candidate long-term scientific authority, subject to the explicit
   MATLAB-to-native authority gate above.
2. Add optimized libraries as optional capabilities behind narrow Sightline
   contracts rather than letting their types or lifecycle cross public
   boundaries.
3. Use oneTBB as the leading optional native CPU task scheduler when D3-or-later
   profiling demonstrates enough coarse-grained work.
4. Evaluate Intel IPP as an optional x86 image-kernel provider, not as the
   portable core, a geometry library, or a replacement for future GPU work.
5. Adopt Boost only by component when a specific library removes meaningful
   implementation risk; do not adopt Boost as a blanket foundation.
6. Keep Babylon.js as the leading web-rendering candidate for a future
   frontend, using ordinary DOM UI around the canvas and a separately deployed
   native scientific backend.
7. Preserve sensor independence through a compact, differentiable
   `ObservationGeometry` interface that evaluates physical sensor origins and
   exterior tangents. Treat dense ray grids as one encoding, not the public
   model.
8. Separate sensor geometry, propagation through the atmosphere, and surface
   intersection. Curved paths are a property of the propagation medium, not a
   reason to import a large sensor-specific API into every algorithm.
9. Use progressive, error-bounded geometry evaluation. Ordinary observations
   take a very fast straight or compiled-surrogate path; difficult observations
   escalate through terrain-anchored local linearization to exact path tracing
   only when their requested accuracy requires it.

## 1. Native C++ Dependency Strategy

### 1.1 Role Separation

No single candidate library should own the native backend. The intended roles
are complementary:

| Capability | Leading candidate or policy |
| --- | --- |
| Small fixed-size geometry | Eigen candidate, behind Sightline value contracts |
| Large dense algebra | Measured BLAS/LAPACK provider when operation sizes justify it |
| Nonlinear least squares | Ceres candidate after target-host dependency and determinism evidence |
| CPU task scheduling | Optional oneTBB outer scheduler |
| CPU image kernels | Portable Sightline reference plus optional Intel IPP provider |
| Spatial indexing and selected utilities | Individual Boost libraries where justified |
| GPU compute | Later capability-checked CUDA or other approved path, never required for correctness |

The CPU reference remains complete even when all optional providers are
disabled. Provider selection, actual execution, precision, fallback reason,
timing, and relevant version information should remain explainable in result
provenance.

Before promoting any dependency, record the following disposition in the
authoritative work package:

| Decision field | Required evidence |
| --- | --- |
| Component and version | Pinned version, supported update policy, and reproducible build source |
| License and redistribution | License review, notices, binary/source redistribution, and air-gapped deployment consequences |
| Supported hosts | Windows and Linux versions, compiler/ABI support, CPU architecture and vendor, and optional GPU requirements |
| Scientific role | Reference, optional accelerator, optimizer, scheduler, or presentation-only role |
| Numerical contract | Precision, determinism, border/mask/rounding behavior, failure behavior, and parity tolerance |
| Runtime behavior | Thread ownership, memory bounds, cancellation, capability detection, and fallback |
| Measured value | Representative target-host speed, memory, startup, and deployment results |

The eventual Windows CPU vendor is not yet fixed. Intel IPP should therefore
remain a measured x86 candidate rather than an assumed default; compare it with
the portable path on the actual target CPU before promotion.

### 1.2 Boost

Boost does not supply a missing equivalent of Eigen, BLAS, Ceres, oneTBB, IPP,
or CUDA. It should therefore not be adopted wholesale as a performance stack.
Its value is component-specific.

Candidate components include:

- **Boost.Geometry spatial indexes:** an R-tree may be useful for view
  footprints, tile bounds, feature neighborhoods, surface chunks, and
  candidate overlap queries. It should be measured against the simpler custom
  or domain-specific hierarchy needed by the actual workload.
- **Boost.Math:** selected special functions, distributions, quadrature, and
  root-finding utilities may reduce numerical implementation risk when the
  equivalent standard-library or existing solver functionality is inadequate.
- **Boost.Graph:** useful only if later multi-view scheduling or dependency
  analysis requires algorithms materially more complex than the current
  explicit graph data structures.
- **Boost.Units or related dimensional utilities:** potentially useful inside
  implementation code, but compile cost, diagnostics, ABI exposure, and
  interaction with MATLAB/C boundaries must be evaluated before adoption.
- **Boost.Endian, UUID, and JSON:** potentially useful narrow utilities when
  they improve portable binary interchange, stable identity, or native
  metadata handling.

Avoid introducing Boost threading, asynchronous I/O, containers, or smart
pointer types merely for uniformity. Every component requires an explicit
use case, version/license review, compile-time measurement, and a wrapper that
prevents Boost types from becoming part of the C ABI or durable scientific
schema. The official catalog is available at
[Boost Libraries](https://www.boost.org/libraries/latest/).

### 1.3 Intel Integrated Performance Primitives

Intel IPP remains a modern, relevant candidate for optimized Windows and Linux
x86 deployments. Its most plausible Sightline role is a selectable provider
for measured image-processing hotspots such as:

- image resize, interpolation, and geometric resampling;
- convolution, filtering, gradients, and pyramid construction;
- thresholding, morphology, statistics, reductions, and pixel transforms;
- selected color or type conversions when their exact semantics match the
  Sightline contract.

IPP should not become:

- the portable reference implementation;
- an authoritative geometry or optimization layer;
- a replacement for Eigen, BLAS, Ceres, oneTBB, or CUDA;
- a source of implicit internal threading that oversubscribes an outer
  scheduler; or
- a reason to change masks, borders, coordinates, interpolation, rounding, or
  radiometric semantics.

Wrap each adopted kernel behind a Sightline operation with a scalar/reference
path, capability selection, parity tests, bounded memory, and execution
provenance. Benchmark on representative target x86 systems, including the
actual CPU vendor selected for deployment, before enabling it by default, and
review redistribution and runtime-dispatch requirements.
Use single-threaded or explicitly bounded IPP kernels beneath an outer task
scheduler unless measurements prove a different nesting policy. See
[Intel oneAPI IPP](https://www.intel.com/content/www/us/en/developer/tools/oneapi/ipp.html).

### 1.4 oneTBB

oneTBB is the leading optional native CPU scheduler for D3 and later. D2 should
remain serial and deterministic while geometry/procedural parity is being
established.

Use oneTBB for coarse outer work such as:

- independent output tiles;
- independent image pairs or bounded view groups;
- terrain or surface chunks;
- batches of ray/path evaluations;
- bounded image-kernel jobs; and
- deterministic partitions of large reductions.

Important policies are:

- Sightline owns concurrency limits and task granularity.
- Use bounded arenas or equivalent controls rather than unbounded nested
  parallelism.
- Prevent Eigen, BLAS, IPP, Ceres, and future GPU submission from each creating
  competing thread teams under the same task.
- Make reductions deterministic where results affect authoritative scientific
  output. Fixed partitions and merge order are preferable to opportunistic
  floating-point accumulation.
- Keep cancellation, progress, failure propagation, and memory budgets explicit.
- Do not move GUI handle mutation or presentation callbacks into worker tasks.

oneTBB is a scheduler, not a numerical or image-processing implementation. Its
adoption is justified only after serial profiling identifies enough
coarse-grained independent work. See
[oneTBB documentation](https://uxlfoundation.github.io/oneTBB/).

This recommendation applies to a future native backend. It does not authorize
the current MATLAB backend to create process-based pools or bypass the existing
requirement that any MATLAB parallelism use only `parpool("threads")`.

## 2. Future Frontend Direction

### 2.1 Babylon.js Recommendation

Babylon.js is a strong frontrunner for a future frontend after the native
backend becomes complete. The recommended commitment would be:

> Babylon.js renderer plus conventional DOM workbench UI plus a versioned
> native scientific service.

Babylon.js is attractive because it provides WebGPU and WebGL rendering, a
complete scene graph, picking, render-graph facilities, height maps, LOD,
instancing, large-world rendering, geospatial camera support, 3D Tiles, and
anaglyph presentation. It is TypeScript-oriented, Apache-2.0 licensed, and
actively maintained. See the
[Babylon.js repository](https://github.com/BabylonJS/Babylon.js) and
[engine specifications](https://www.babylonjs.com/specifications/).

### 2.2 Frontend Boundaries

Babylon.js should own presentation and interaction, not scientific authority.
The native backend should continue to own:

- full-resolution source imagery and bounded image-tile access;
- authoritative double-precision coordinates and transformations;
- surfaces, optimizers, uncertainty, correction state, and provenance;
- scientific persistence and export; and
- backend verification of picks, measurements, and accepted corrections.

The frontend should receive bounded image tiles, surface chunks, identifiers,
view-local coordinates, and summaries. It must not copy 100-150 MP imagery or
complete authoritative surfaces into the JavaScript heap. Camera-relative
`float32` values are appropriate for rendering, but they must be derived from
native `double` values at an explicit boundary.

Use an ordinary DOM framework such as React, Vue, or Svelte for dense tables,
trees, inspectors, forms, keyboard navigation, and accessibility. Babylon GUI
is appropriate for viewport overlays and heads-up controls, not the entire
engineering workbench.

Use a versioned binary protocol and bounded streaming. Large numeric arrays
should not cross the process boundary as JSON. Candidate transports may use
shared memory, memory-mapped tile caches, framed binary IPC, or another
measured mechanism. A separate backend process is preferable to an in-process
native addon when isolation, crash containment, and upgrade independence are
more valuable than the final copy.

The desktop shell remains a separate decision. Chromium/Electron or CEF is a
reasonable first controlled prototype because the rendering runtime can be
pinned. Tauri is attractive for package size but requires explicit Windows and
Linux WebGPU/webview qualification. The final choice must include offline
deployment, security-update cadence, package size, file access, and air-gapped
operation.

### 2.3 Babylon Native

Babylon Native should not be the initial production choice. Its project
currently describes itself as a source-only public preview without a stable
backward-compatible consumption contract; GUI and input support remain partial
and HTML-dependent controls are outside its scope. It is worth reassessing
later if a browser/webview becomes the measured bottleneck, but today it would
remove DOM UI while introducing native embedding and JavaScript-runtime work.
See [Babylon Native project status](https://github.com/BabylonJS/BabylonNative#project-status).

### 2.4 Required Prototype

Before selection, build a bounded vertical slice that:

1. streams a 100-150 MP image through a native pyramid/tile protocol;
2. provides linked 2-D, anaglyph, and 3-D views;
3. streams a DEM or mesh plus uncertainty overlays;
4. exercises picking, measurement, layer editing, and native verification;
5. validates camera-relative rendering at the largest anticipated coordinates;
6. measures frame latency, startup, RAM, GPU memory, tile churn, and IPC cost;
7. validates offline Windows/NVIDIA and Linux deployment; and
8. compares the result with a serious native control, preferably Qt/QML plus
   VTK or an equivalent native viewport.

The prototype must also demonstrate scientific display parity rather than rely
on nominal engine feature support. Acceptance should cover:

- native-to-display and display-to-native pixel-coordinate round trips;
- validity masks, NaN handling, and invalid-region presentation;
- 8-bit, 16-bit, and floating-point radiometry, including explicit LUT, gamma,
  clipping, and color-space behavior;
- physical left/right eye assignment, parallax sign, stereo exaggeration, and
  anaglyph composition parity with the accepted Sightline pipeline;
- pick and selection precision at representative and maximum coordinates; and
- deterministic screenshots or image-difference fixtures for stable views.

Babylon.js built-in anaglyph support is only a rendering capability. It must
not be treated as evidence that Sightline's eye assignment, radiometry, or
display-only stereo semantics are preserved.

The native API must remain frontend-neutral even if Babylon.js wins this
prototype.

## 3. Compact Sensor Geometry

### 3.1 Canonical Observation Contract

The current exposure-station and view-vector concept is a strong generalized
camera abstraction for straight-line optical imaging. The future native
contract should formalize it as a batch-oriented `ObservationGeometry`
evaluator rather than define a dense grid as the model:

```text
evaluate(observation coordinates, requested fields) -> ObservationBatch

ObservationBatch fields:
    observation coordinate convention and band
    physical sensor origin
    physical exterior unit tangent
    trace direction sense
    coordinate reference frame and linear/angular units
    acquisition time, when available
    time scale, epoch, and timing convention, when available
    wavelength, effective wavelength, or spectral response, when applicable
    exterior optical-boundary definition
    validity and domain status
    derivatives with respect to image coordinates, when available
    deterministic approximation bounds
    stochastic uncertainty description, when available
    geometry fingerprint and correction generation
```

The canonical direction must be the forward scene-tracing tangent from the
exterior sensor boundary toward the observed scene. Photon travel is normally
opposite that direction. Adapters must reverse vendor conventions explicitly
rather than rely on a consumer to infer direction sense. Reciprocity may be
assumed only when the selected propagation model states that the medium is
stationary, isotropic, and reciprocal over the evaluated path. Optical windows
or ports belong inside the physical sensor model unless the exterior boundary
is explicitly defined beyond them.

Paired per-observation evaluation must be the fundamental operation. The
current rectangular convention in which one origin applies to every requested
row of a column is an efficient linear-array specialization, not a universal
sensor property. Rolling shutter, push-frame, whiskbroom, staggered detector,
and band-dependent geometries may require origins or timing that depend on
both image coordinates and band.

`SampleFcn` and `SampleRayFcn` remain compatibility adapters. CSM, RPC, vendor,
analytic, and navigation-derived models can evaluate directly or be compiled
into a Sightline representation at ingestion. CSM remains useful for external
interoperability, but its type system and plugin lifecycle need not enter the
scientific core.

The backend also requires an inverse geometry contract. Its semantic operation
is independent of any particular numerical method:

```text
project(world or surface points, band, options) -> ProjectionBatch

ProjectionBatch fields:
    zero, one, or multiple observation-coordinate candidates
    candidate validity and source-domain status
    forward scene-trace range and surface/path branch identity
    convergence, initialization, iteration, and residual diagnostics
    derivatives or Jacobians, when available
    deterministic approximation bound and stochastic uncertainty metadata
```

The contract must define how initial guesses are supplied or generated, how
multiple solutions and detector seams are ordered, and how failure differs
from a valid point outside the source footprint. D3 full-source inverse
rendering cannot consume a forward-only observation interface.

### 3.2 Adaptive Spline Ray Atlas

The public observation interface is intended to be universal. An adaptive,
piecewise cubic spline ray atlas is a candidate generic fallback encoding, not
yet a universal or authoritative representation:

- represent origin control points in local Cartesian coordinates;
- represent directions with two-dimensional angular coordinates in a local
  tangent plane on the unit sphere;
- map interpolated angular coordinates back to the sphere and normalize;
- partition the image into patches with explicit seams and invalid regions;
- adaptively subdivide until origin and angular error bounds pass; and
- prohibit extrapolation outside the validated domain.

Raw XYZ direction splines followed by normalization are an acceptable simpler
first implementation. Tangent-plane coordinates are attractive for a promoted
format because fitted residuals have a direct angular meaning.
Generic central and non-central camera research has demonstrated cubic
B-spline interpolation of both directions and points on observation lines:
[Schops et al., CVPR 2020](https://openaccess.thecvf.com/content_CVPR_2020/papers/Schops_Why_Having_10000_Parameters_in_Your_Camera_Model_Is_Better_CVPR_2020_paper.pdf).

Choose knots from a downstream position-error budget rather than an arbitrary
pixel interval. For small angular error,

```text
ground error <= origin error + maximum range * angular error.
```

Each atlas should record its domain, source fingerprint, coordinate frame,
units, coefficient precision, maximum measured/validated origin and angular
residuals, validation strategy, seam/mask information, and generation
provenance.

Promotion requires held-out evidence across the actual sensor families in
scope, including frame, rolling-shutter, pushbroom, push-frame, whiskbroom,
staggered-detector, band-dependent, and vendor-supplied geometries. Where an
exact physical factorization exists, prefer it over compiling immediately to a
generic atlas. Required sensor/vendor fixtures and their permissible error
budgets remain an open evidence item.

### 3.3 Factorized Scanning-Sensor Representation

When the geometry supports it, use a more compact factorization:

```text
time = timingMap(row, column, band)
origin = positionSpline(time)
direction = attitudeSpline(time) * detectorDirection(row, band)
            plus a small residual ray field
```

Use ordinary splines for position and continuous Lie-group splines for
orientation rather than interpolating OPK Euler angles. A linear-array sensor
may then require only a one-dimensional position curve, a one-dimensional
orientation curve, a detector look-direction curve, and a small residual
atlas. Continuous-time Lie-group B-splines provide efficient derivatives and
avoid representation singularities; see
[Sommer et al.](https://arxiv.org/abs/1911.08860).

This factorization is an optional encoding, not a semantic requirement placed
on consumers. It must evaluate through the same observation contract as an
arbitrary spline atlas or dense grid.

### 3.4 Derivatives, Inverse Acceleration, And Uncertainty

Analytic or stable spline derivatives with respect to row and column are often
more valuable than storage compression. They can accelerate inverse
projection, terrain intersection, epipolar-locus evaluation, bundle
adjustment, and uncertainty propagation while avoiding repeated finite
differences.

Build a hierarchy over image patches containing origin bounds, directional
cones, time bounds, validity, and approximation error. This supports rapid
overlap pruning, inverse-projection initialization, surface candidate queries,
and progressive evaluation.

Represent correlated geometry error through low-dimensional modes rather than
independent per-ray covariance:

```text
origin(q, xi) = origin0(q) + A_origin(q) * xi
direction(q, xi) = Exp([A_angle(q) * xi]_x) * direction0(q)
```

The latent variables can represent position/attitude bias, drift, timing bias,
periodic jitter, detector curvature, scan nonlinearity, or band registration.
Their covariance preserves image-wide correlation, and the same modes can
serve as compact correction parameters in later estimation.

### 3.5 Correction Ordering, Lineage, And Identifiability

The conceptual order of operations is:

1. evaluate the nominal physical sensor origin, exterior tangent, timing, and
   band state;
2. apply accepted position, attitude/OPK, timing, detector, and trajectory
   corrections to that physical state;
3. propagate the corrected exterior state through the selected atmosphere;
4. intersect the resulting path with the requested ellipsoid, DEM, DSM, or
   mesh; and
5. apply projection-only or display-only offsets after physical intersection,
   without presenting them as sensor corrections.

An atmosphere, terrain, datum, sensor-model, or accepted-correction revision
must invalidate every derived path, inverse map, match geometry, surface, and
render product whose fingerprint includes that revision. A propagation or
terrain revision does not by itself erase independently estimated sensor-only
corrections, but it makes products and estimates that depended on the earlier
model stale until their lineage is re-evaluated.

Atmospheric bending, position, OPK, timing drift, detector calibration, and DEM
registration can explain overlapping image residuals. A future joint solver
must define gauge constraints, priors, observability tests, and reported
cross-covariances before estimating more than one such family. It must not
silently absorb an unmodeled atmosphere into pointing or treat a DEM-derived
translation as independent validation evidence.

### 3.6 Non-Primary Encodings

- **RPCs:** useful for ingestion or export, but not the universal internal
  model because they approximate ground-to-image behavior over a bounded volume
  and do not preserve physical origin, time, or correlated error cleanly.
- **Plucker coordinates:** useful inside generalized epipolar and line
  algorithms, but not a major storage reduction and not a substitute for the
  physical exposure station.
- **Global high-order polynomials:** compact for very smooth models but poorly
  localized around detector seams and local irregularities. Piecewise
  Chebyshev patches remain a viable compiled surrogate.
- **Neural ray fields:** potentially compact and differentiable, but presently
  unsuitable as authoritative geometry because worst-case certification,
  extrapolation, reproducibility, and deterministic deployment are weaker.

## 4. Atmospheric Propagation And Curved Paths

### 4.1 Semantic Separation

A straight origin-plus-direction ray is sensor-agnostic only for single-valued
straight-line imaging. Refractive atmospheric paths require three explicit
layers:

```text
ObservationGeometry
    physical sensor origin, exterior tangent, time, band

PropagationModel
    atmospheric/environment model -> path

SurfaceIntersection
    first valid path intersection with ellipsoid, DEM, or mesh
```

The exterior tangent is the physical direction immediately outside the sensor
or aircraft optical boundary. It must be distinguished from an effective chord
chosen to intersect a reference height after refraction.

Legacy or precomputed effective rays remain useful, but their metadata should
state:

```text
representation = EffectiveStraightRay
reference surface or height
atmosphere model and revision
validated height/path interval
maximum position error
```

This prevents double correction and prevents a reference-height approximation
from being mistaken for physical sensor geometry.

### 4.2 Propagation Models

For a general refractive-index field, geometric optics gives

```text
d/ds (n * dx/ds) = gradient(n).
```

Here `s` is path arc length, `x(s)` is position in a declared Earth-fixed or
local frame, `dx/ds` is a unit scene-tracing tangent, and `n` is the
wavelength-dependent refractive index evaluated in a consistent spatial and
time coordinate system. An implementation must state whether profile height is
geometric, geopotential, ellipsoidal height (HAE), or orthometric height (MSL),
and must record the geoid transformation when MSL data such as EGM96-referenced
weather or terrain products are combined with WGS84/ECEF geometry.

For a horizontally stratified spherical atmosphere, azimuth is conserved and
the path admits the invariant

```text
n(r) * r * sin(zenith angle) = constant.
```

That common production case reduces to inexpensive one-dimensional quadrature
in the observation's vertical plane. A general three-dimensional ODE solver is
needed only for horizontal refractivity structure or another environment that
violates the stratified approximation.

The spherical invariant is an approximation and validation path, not an
implicit replacement for the project's WGS84 ellipsoidal coordinates. Any
production approximation must declare its reference radius/model, conversion
to and from WGS84, acquisition location and time, atmosphere validity interval,
and the ground-position error assigned to that approximation. The applicable
wavelength and composition range of the selected refractivity law must be
capability-checked for each sensor band.

Recommended atmosphere levels are:

1. a named standard stratified atmosphere;
2. a measured or weather-model vertical profile of pressure, temperature, and
   humidity, compiled into refractive index by height; and
3. an optional three-dimensional NWP-derived refractivity field for extreme or
   accuracy-critical work.

Use a wavelength-aware refractive-index model. NIST documents Ciddor and
modified Edlen calculations for air as functions of wavelength, temperature,
pressure, humidity, and composition:
[NIST refractive-index documentation](https://emtoolbox.nist.gov/Wavelength/Documentation.asp).

Published guidance recommends more rigorous numerical treatment at zenith
angles above roughly 75 degrees or when high positional accuracy is required:
[Mangum and Wallace](https://arxiv.org/abs/1411.1617). Airborne photogrammetry
studies also show meaningful dependence on height and atmospheric profile:
[Beisl and Tempelmann, ISPRS 2016](https://isprs-archives.copernicus.org/articles/XLI-B1/281/2016/isprs-archives-XLI-B1-281-2016.pdf).

The path solver must detect and report unsupported or ambiguous propagation,
including a turning path, ducting, a non-monotonic profile, multiple candidate
surface intersections, departure from the atmosphere domain, or no forward
surface intersection. It must not force these cases into a single straight or
single-valued path result.

### 4.3 Qualitative Mean-Height Sensitivity

The architecture discussion included uncommitted scoping calculations for a
spherical Earth, a dry standard-troposphere profile, visible light, and a
straight effective ray fitted at one mean terrain elevation. They indicated
the expected qualitative behavior: refraction and the residual error of a
mean-height straight-ray approximation grow rapidly with off-nadir angle,
range, and relief, and near-tangent geometry can amplify small changes in
bending into large horizontal intersection changes.

The earlier numerical table is intentionally not retained as design evidence.
Before numerical values are restored or used for a threshold, commit a
reproducible public script and configuration that identify:

- atmosphere profile, refractivity law, wavelength/band, humidity and gas
  composition;
- Earth shape/radius, gravity assumptions, coordinate frame, and vertical
  datums;
- sensor and target heights, off-nadir and zenith definitions, surface model,
  relief direction, and path direction;
- quadrature/ODE algorithm, tolerances, convergence criteria, and software
  version; and
- the exact definitions and signs of reported shift, residual, range, and
  horizontal error.

The resulting values require an independent implementation or trusted external
cross-check before promotion. The definitive atmosphere profiles, spectral
bands, surface cases, and acceptance tolerances are not yet supplied and remain
open evidence items rather than blockers to this concept record.

## 5. Terrain-Anchored Local Path Approximation

### 5.1 Recommended Approximation

Intersect the refracted path with a low-resolution or hierarchical terrain
surface, then linearize the path locally near that provisional intersection.
Retain:

```text
physical sensor origin
path anchor x_a
local path tangent t_a
optional local curvature k_a
path parameter or accumulated distance at the anchor
validated linearization interval and deterministic approximation bound
```

The notation avoids `P0`, which is already used elsewhere in Sightline for a
projection-plane origin.

The first-order approximation is

```text
x(s) ~= x_a + t_a * delta_s.
```

An optional local quadratic is

```text
x(s) ~= x_a + t_a * delta_s + 0.5 * k_a * delta_s^2.
```

Use the local path tangent, not the chord from the exposure station to the
coarse intersection. The tangent makes path-departure error second-order in
the remaining distance. The chord retains a first-order direction error from
all curvature accumulated above the anchor.

Uncommitted scoping calculations indicated that local-tangent error grows more
slowly than exposure-station-to-anchor chord error as the true surface departs
from the coarse anchor, with the largest difference in near-grazing geometry.
That qualitative result motivates the candidate method but does not establish
an error bound. Numerical comparisons require the reproducibility evidence in
Section 4.3 plus an explicit constant-elevation spherical/ellipsoidal surface,
surface slope and crossing-angle definition, anchor construction, and
first-intersection policy.

The relevant independent variable is remaining path length, not vertical
height difference alone. If `gamma` is the local path-versus-surface crossing
angle,

```text
remaining path length ~= abs(height residual) / abs(sin(gamma)).
```

For local curvature `kappa`, tangent departure is approximately bounded by

```text
cross-path departure <= 0.5 * kappa * remaining_path_length^2.
```

Near-grazing surface intersection can further amplify that departure. The
runtime acceptance test must therefore include path length, crossing angle,
curvature, terrain uncertainty, and requested ground-position tolerance rather
than only a fixed vertical threshold.

### 5.2 Terrain Hierarchy And First-Hit Correctness

DTED Level 0 is valuable as a globally available initial guess and scheduling
surface, but its nominal post spacing is 30 arc-seconds, approximately one
kilometer. See
[NGA elevation products](https://earth-info.nga.mil/index.php?action=elevation&dir=elevation).
It is not a conservative bound in rugged terrain: narrow ridges can disappear,
valleys can be filled, and a missed ridge can be the true first intersection.

Build or consume a conservative hierarchy from the best available terrain.
Each coarse cell should carry:

```text
minimum elevation
maximum elevation
deterministic geometric envelope provenance, when available
unresolved roughness or stochastic source uncertainty
validity and vertical datum
surface class or DTM/DSM semantics
children or fine-source reference
```

Trace through coarse cells, reject elevation envelopes that cannot intersect
the path, and refine only ambiguous cells. DTED Level 0 can seed this process
when nothing better is available, but it should not certify first-hit
correctness by itself. Convert vertical datums explicitly before comparing
terrain with ECEF or ellipsoidal geometry.

A digital terrain model (DTM) and a digital surface model (DSM) answer
different first-hit questions. A DTM normally omits buildings and vegetation;
it cannot certify optical first-hit correctness in an urban or forested scene.
A DSM or mesh may represent those structures, but its acquisition time,
occlusion, void, and change limitations must remain explicit. The requested
surface semantics must therefore be part of the query and provenance.

Keep deterministic envelopes separate from stochastic error. A cell min/max
constructed conservatively from complete source samples may be used for hard
pruning within its stated assumptions. CE90, LE90, covariance, nominal source
accuracy, or interpolated roughness are probabilistic evidence and must not be
promoted to a guaranteed min/max bound without a separately justified
confidence and composition policy. The required confidence policy and source
metadata for a production hierarchy remain open design inputs.

### 5.3 Stereo And Reconstruction

Curved paths do not require every downstream algorithm to become a general
curve solver. For stereo or multi-view reconstruction:

1. anchor each observation path near a coarse terrain estimate;
2. solve closest approach on the local tangent lines with a helper whose
   infinite-line semantics are explicit, then require positive forward path
   parameters before accepting a physical reconstruction;
3. measure how far the solution moved from each validated anchor;
4. retrace or relinearize only paths that exceeded their interval; and
5. iterate to convergence or report an explicit accuracy/observability failure.

This does not change the public compatibility behavior of
`PlanarProjection.triangulateRays`, which currently solves infinite lines. New
scientific code must perform the forward-validity check explicitly rather than
infer ray validity from that legacy function name.

This is analogous to a geometry-specific Gauss-Newton iteration. It preserves
fast line algebra for the common inner solve while retaining an authoritative
curved-path outer model.

## 6. Progressive, Error-Bounded Geometry Evaluation

### 6.1 Escalation Ladder

The production evaluator should choose the cheapest method whose predicted
error satisfies the caller's requested tolerance:

| Level | Method | Intended use |
| --- | --- | --- |
| 0 | Straight physical ray | Refraction and terrain bounds are already below tolerance |
| 1 | Cached refractive transfer spline or equivalent validated surrogate | Smooth terrain and ordinary viewing geometry |
| 2 | Refracted coarse-terrain anchor plus local tangent | Normal difficult-geometry path |
| 3 | Local curvature or iterative relinearization | Grazing crossing or larger anchor residual |
| 4 | Direct path integration plus hierarchical terrain refinement | Extreme, ambiguous, or strict-authority cases |

Do not use off-nadir angle alone as the dispatch rule. Selection should account
for requested tolerance, atmospheric bending and uncertainty, local crossing
angle, sensor/terrain distance, terrain min/max bounds, path curvature, and
distance from an existing anchor.

### 6.2 Accuracy Policies And Result Status

Callers request an outcome rather than a particular algorithm:

```text
display tolerance
interactive-analysis tolerance
authoritative scientific tolerance
```

These tolerances may derive from screen scale, source GSD, output GSD, or an
explicit project value. A single `maximum predicted geometry error` must not
conflate numerical approximation with uncertain knowledge of the physical
scene. Every result reports separate dimensions:

```text
computational status: validated, provisional, degraded, or unavailable
domain status: in-domain, extrapolated, ambiguous, or outside-domain
deterministic numerical/surrogate truncation bound and its evidence
stochastic sensor, atmosphere, and terrain uncertainty with confidence model
combined policy outcome and the rule/confidence used to combine components
method and precision actually used
sensor, atmosphere, terrain, and correction revisions
fallback or escalation reason
timing and relevant memory/capability diagnostics
```

`Validated` means that the selected method's deterministic error bound and
domain checks satisfy the declared policy. It does not mean that the unknown
physical position lies inside a hard interval. Stochastic covariance, CE90,
LE90, atmosphere uncertainty, and DEM uncertainty remain confidence-qualified
estimates. A policy may combine them for a requested confidence level only when
the assumptions, correlations, conversions, and composition rule are stated.
Otherwise the result must report the components separately and avoid the word
`certified`.

The UI may display a rapid provisional result and refine difficult tiles or
observations asynchronously. Final scientific export must wait until the
requested deterministic, stochastic, domain, and authority policy is
satisfied, or explicitly record that the caller accepted a degraded product. A
small extreme-angle region must not block ordinary interaction with the rest of
a scene.

### 6.3 Compiled Propagation And Caching

For a fixed acquisition, band, and stratified atmosphere, compile the
propagation mapping into an adaptive spline or piecewise Chebyshev table over
the relevant sensor altitude, look angle, and target-height domain. Direct
quadrature remains the oracle and out-of-domain fallback.

The native implementation should be batch-oriented and structure-of-arrays:

- evaluate many observations together;
- cache sensor spline basis weights by image tile;
- cache atmospheric transfer tables by profile/acquisition/band revision;
- cache coarse anchors by sensor geometry, atmosphere, and terrain revision;
- vectorize terrain traversal and local intersection;
- use bounded oneTBB tasks only after the serial reference is stable; and
- keep authoritative geometry and path evaluation in native double precision.

All caches remain runtime-only. Serializable records contain stable values,
source identifiers, revisions, tolerances, and compact coefficients, not
function pointers, task objects, file readers, graphics handles, or runtime
contexts.

## 7. Candidate Native Interfaces

The exact names remain a later API decision, but the boundary should preserve
the following separation:

```text
ObservationState
    observation coordinate and band
    physical sensor origin
    exterior tangent
    acquisition time
    validity, derivatives, and sensor-geometry error

PropagationContext
    propagation model and revision
    atmospheric profile or compiled surrogate
    wavelength/band policy
    precision and requested tolerance

PathLinearization
    physical sensor origin
    path anchor and local tangent
    optional curvature and path coordinate
    validated interval and deterministic position-error bound

InverseProjectionRequest
    world/surface points, band, and coordinate frame
    optional initial candidates and search/domain policy
    propagation, surface, precision, tolerance, and solution-count policy

InverseProjectionResult
    zero, one, or multiple observation-coordinate candidates
    forward range, branch/surface identity, and validity
    convergence, initialization, residual, derivative, and domain diagnostics
    deterministic approximation bound and stochastic uncertainty metadata

GeometryEvaluation
    result status and method
    path/surface intersection or local line
    sensor/atmosphere/terrain/correction revisions
    separate deterministic bound and stochastic uncertainty
    domain, combined-policy, precision, timing, and fallback diagnostics
```

Compatibility adapters can continue to provide the existing MATLAB
`SampleFcn` and `SampleRayFcn` forms. New native algorithms should consume the
paired observation contract and request propagation or terrain intersection
only when they need it.

## 8. Validation And Promotion Gates

No concept in this document should become authoritative without focused
scientific and performance evidence.

### Native libraries

- Benchmark identical contracts and output checksums on target Windows and
  Linux systems.
- Separate validation, allocation, scheduling, algebra, kernel, transfer,
  synchronization, and I/O time.
- Verify bounded memory, cancellation, deterministic reductions, fallback, and
  redistribution requirements.
- Prevent oversubscription across oneTBB, IPP, BLAS, Eigen, Ceres, and GPU
  providers.
- Complete the component/version/license/host/role/contract/runtime/value
  disposition before promotion, including the actual target CPU vendor.

### Frontend

- Complete the bounded native-service/Babylon.js vertical slice.
- Measure Windows and Linux rendering/IPC behavior on representative imagery
  and surfaces.
- Verify offline installation, security update policy, accessibility, large
  coordinates, pick round trips, and preservation of the scientific-authority
  boundary selected by the applicable transition gate.
- Verify masks/NaNs, supported radiometric types, LUT/gamma/color behavior,
  left/right and parallax conventions, selection precision, and deterministic
  image-difference fixtures against the accepted Sightline pipeline.

### Sensor geometry

- Compare compact encodings with exact/vendor evaluators and held-out samples.
- Test patch seams, invalid regions, band-dependent geometry, discontinuities,
  rolling/pushbroom timing, derivatives, inverse initialization, and correction
  modes.
- Express acceptance in downstream ground-position terms over the validated
  range, not only coefficient or angular residuals.
- Exercise both forward observation evaluation and inverse world-to-source
  projection, including zero/multiple solutions, seams, poor initial guesses,
  out-of-domain results, convergence failure, and Jacobian checks.
- Verify direction sense, coordinate/time conventions, spectral metadata,
  exterior-boundary definition, geometry fingerprints, correction ordering,
  lineage invalidation, and projection-only offset separation.
- Retain the generic spline atlas as a candidate until held-out frame,
  rolling-shutter, pushbroom, push-frame, whiskbroom, staggered-detector,
  band-dependent, and vendor-model evidence supports promotion.

### Atmospheric propagation and terrain

- Verify zero-gradient/constant-index cases reduce to straight lines.
- Verify spherical stratified cases preserve the Snell invariant and
  reciprocity.
- Compare compiled surrogates with independent direct numerical integration.
- Cover standard, measured-profile, inversion, horizontal-gradient, and
  uncertainty cases as available.
- Test turning, ducted, non-monotonic, multiple-intersection, out-of-domain,
  and no-forward-intersection cases without forcing a single valid path.
- Exercise off-nadir angles through 85 degrees, terrain relief through at least
  +/-1000 m, multiple absolute elevations, wavelengths/bands, and sensor
  altitudes.
- Test terrain first-hit behavior with narrow ridges, valleys, voids, datum
  transformations, DTM/DSM differences, urban/vegetation structure, and min/max
  hierarchy refinement.
- Test hard geometric envelopes separately from confidence-qualified terrain,
  atmosphere, and sensor uncertainty.
- Validate tangent and quadratic error bounds as functions of remaining path
  length and crossing angle.
- For stereo, verify iterative local relinearization against direct curved-path
  closest-approach or equivalent independent truth.

Before accepting numerical refraction or tangent-approximation thresholds,
provide the reproducible configuration, public calculation, independent
cross-check, bands, profiles, datums, surfaces, tolerances, and sign conventions
listed in Sections 4.2, 4.3, and 5.1. Those inputs are intentionally recorded as
open evidence items and do not authorize inferred defaults.

### Open inputs before promotion

The following information is deliberately unresolved. It is not required to
retain this concept record, but the affected recommendation must not be
promoted without it:

- the held-out sensor families, vendor evaluators, detector discontinuities,
  timing conventions, spectral responses, and downstream position-error
  budgets used to qualify a compact geometry encoding;
- the operational atmosphere profiles, acquisition locations/times, sensor
  bands, Earth/datum conventions, terrain/surface cases, and deterministic and
  stochastic acceptance tolerances;
- the confidence and correlation policy for composing sensor, atmosphere, DEM,
  DSM, and numerical approximation evidence;
- the target Windows/Linux CPU vendors and models, compiler/runtime matrix,
  NVIDIA capability, redistribution constraints, and representative workload
  measurements used to select native providers;
- the frontend shell and deployment/update model, including air-gapped security
  maintenance and scientific-display parity fixtures; and
- the separately approved milestone and evidence that would transfer
  scientific authority from the MATLAB oracle to a native implementation.

## 9. Glossary

| Term | Meaning in this document |
| --- | --- |
| ABI | Application binary interface. |
| BLAS | Basic Linear Algebra Subprograms. |
| CE90 | Horizontal circular error threshold associated with 90-percent confidence under a stated model. |
| CEF | Chromium Embedded Framework. |
| CSM | Community Sensor Model interoperability family. |
| DEM | Digital elevation model; the generic term does not by itself distinguish terrain from top-of-surface height. |
| DOM | Document Object Model used for conventional web UI. |
| DSM | Digital surface model, potentially including buildings and vegetation. |
| DTM | Digital terrain model representing bare-earth terrain. |
| ECEF | Earth-centered, Earth-fixed Cartesian coordinates. |
| EGM96 | Earth Gravitational Model 1996, used here when an MSL/geoid conversion is explicitly selected. |
| GSD | Ground sample distance. |
| HAE | Height above the reference ellipsoid. |
| IPC | Inter-process communication. |
| IPP | Intel Integrated Performance Primitives. |
| LE90 | Vertical linear error threshold associated with 90-percent confidence under a stated model. |
| MSL | Mean sea level or orthometric height; a geoid model must be identified. |
| NWP | Numerical weather prediction. |
| ODE | Ordinary differential equation. |
| OPK | Omega, phi, and kappa attitude correction convention used by Sightline. |
| RPC | Rational polynomial coefficient camera-model representation. |
| SDK | Software development kit. |
| WGS84 | World Geodetic System 1984. |

The final system should spend additional computation on difficult physics only
where it is needed, never silently exceed a requested deterministic bound or
misstate a stochastic confidence, and never require worst-case 85-degree
processing cost for ordinary interactive views.
