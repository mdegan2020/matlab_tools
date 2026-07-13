# Sightline Workbench Software Requirements Specification

Document status: Draft 1

Document date: July 11, 2026

Product: Sightline Workbench

## 1. Introduction

### 1.1 Purpose

This Software Requirements Specification (SRS) defines the product requirements
for Sightline Workbench. It covers the MATLAB geometry library, interactive
viewer, alignment workbench, headless backend, multi-image network adjustment,
dense correspondence and surface reconstruction, uncertainty and DEM
registration, MATLAB extension SDK, synthetic validation system, mathematical
reference, procedural reference implementation, and the planned production C++
backend.

This document states required externally observable behavior, scientific
invariants, interfaces, data contracts, quality attributes, and acceptance
criteria. It does not prescribe a project-management or software-development
method.

### 1.2 Standards basis

The organization and requirement style are informed by
[ISO/IEC/IEEE 29148:2018](https://www.iso.org/standard/72089.html), Systems and
software engineering — Life cycle processes — Requirements engineering. That
edition was reviewed and confirmed in 2024 and remains the published current
edition at the date of this draft. This SRS uses uniquely identified,
verifiable shall statements and separates product requirements from planning
history. It does not claim a formal third-party conformance assessment.

### 1.3 Product scope

Sightline Workbench is an explainable environment for projecting and comparing
sensor imagery with known viewing geometry. It shall support:

- plane, camera, ray, and reconstruction geometry;
- interactive multi-layer projection and stereo presentation;
- sparse feature matching and image-model correction;
- pair-centric inspection and global multi-image adjustment;
- headless full-source rendering at a configured output grid;
- dense correspondence, multi-ray reconstruction, and surface exploration;
- uncertainty propagation and optional registration to an uncertain DEM;
- programmatic access to corrections and replaceable scientific algorithms;
- deterministic synthetic truth generation and acceptance evidence; and
- parity references for a later high-performance C++ implementation.

The MATLAB system is both a usable prototype and the scientific reference for
future implementations. Public PlanarProjection and Projection-prefixed names
are retained for compatibility.

### 1.4 Intended audience

This SRS is intended for:

- operators using the viewer, Alignment Workbench, and Surface Workbench;
- MATLAB application and algorithm developers;
- developers integrating Sightline Workbench through its MATLAB SDK;
- photogrammetry, estimation, image-processing, and uncertainty reviewers;
- verification and acceptance personnel; and
- engineers implementing or validating the future C++ and CUDA backend.

### 1.5 Requirement applicability

Each requirement has one applicability class:

| Class | Meaning |
| --- | --- |
| Core | Required behavior of the MATLAB product or a compatibility invariant that shall remain true. |
| Approved | Approved product behavior to be delivered in the ordered roadmap. |
| Gated | Required only after the named evidence, hardware, or contract gate is satisfied. |

Applicability is not implementation status. Current completion state is
maintained in project_status.md.

### 1.6 Verification methods

| Code | Method |
| --- | --- |
| T | Automated or controlled test |
| A | Numerical analysis, benchmark, or truth comparison |
| I | Inspection of interface, schema, source, artifact, or documentation |
| D | Operator or integration demonstration |

Where more than one code appears, all listed methods apply.

### 1.7 Normative terminology

Shall denotes a mandatory requirement within its applicability class. Should
denotes a recommendation. May denotes a permitted behavior. Informative
examples and rationale do not create additional requirements.

### 1.8 References

1. ISO/IEC/IEEE 29148:2018, Requirements engineering.
2. README.md, current public interfaces and operator entry points.
3. docs/project_status.md, current implementation and external validation
   status.
4. docs/viewer_development_plan.md, geometry, viewer, backend, and alignment
   architecture.
5. docs/alignment_workflow_hardening_plan.md, alignment reliability and
   operator workflow.
6. docs/performance_optimization_workplan.md, viewer and backend performance
   contracts.
7. docs/dense_surface_feature_pack.md, current dense-surface baseline.
8. docs/dense_surface_synthetic_expansion_plan.md, synthetic truth and
   acceptance contract.
9. docs/multi_image_surface_reconstruction_workplan.md, approved multi-image,
   SDK, surface, precision, mathematical-reference, CUDA, and C++ requirements.
10. docs/matlab_sdk_audit.md, current public-interface inventory and
    compatibility risks.
11. docs/alignment_operator_guide.md, current alignment operation.
12. tracked_issues.md, local unresolved ray-versus-line semantic decisions when
    present.

## 2. Product context

### 2.1 Product perspective

Sightline Workbench consists of a stable mathematical geometry API, a
programmatic MATLAB viewer, graphics-independent processing components, a
serializable scene/state/job layer, and optional runtime accelerators. The main
viewer is a presentation and interaction surface. Scientific computation shall
remain callable without manipulating GUI widgets.

The system accepts image arrays and source geometry, projects imagery onto a
physical plane for inspection, estimates pointing corrections from image
evidence, and renders backend products from full source imagery. Dense and
surface products are analysis results derived from source observations and
corrected geometry; they are not radiometric inputs to the backend renderer.

### 2.2 User classes and characteristics

| User class | Expected knowledge and access |
| --- | --- |
| Viewer operator | Understands imagery, layers, basic camera navigation, and visual comparison. |
| Alignment operator | Understands image matching, pair selection, residuals, OPK corrections, and acceptance diagnostics. |
| Surface analyst | Understands stereo/multi-view geometry, point clouds, uncertainty, DEMs, and occlusion. |
| MATLAB integrator | Can create MATLAB arrays and structs, call public APIs, consume versioned results, and implement documented subclasses. |
| Algorithm developer | Understands the mathematical inputs, output states, coordinate mappings, numerical precision, and conformance tests for an extension point. |
| C++/CUDA developer | Can reproduce published equations and contracts and compare implementations against MATLAB golden fixtures. |

The GUI shall not require users to understand internal caches, tile pools,
preview planes, or object ownership.

### 2.3 Operating environment

- The reference implementation executes in supported desktop MATLAB
  environments.
- Image Processing Toolbox and Computer Vision Toolbox are required for the
  current dense SGM path and applicable image-processing functions.
- Parallel Computing Toolbox and compatible GPU hardware are optional.
- CPU execution is mandatory and shall remain complete.
- The active development environment may be macOS without gpuArray support.
- Windows with a supported NVIDIA GPU is the target environment for
  MATLAB-managed GPU and CUDA/MEX validation.
- A future C++ implementation shall target native 64-bit Windows first, with a
  portable CPU core and secondary WSL 2/Linux command-line validation.

### 2.4 Constraints

| ID | Requirement | Class | Verify |
| --- | --- | --- | --- |
| CON-001 | The system shall preserve the existing public PlanarProjection and Projection-prefixed MATLAB names unless a separately approved compatibility change is provided. | Core | T, I |
| CON-002 | The system shall provide a complete CPU execution path for every required scientific operation. | Core | T |
| CON-003 | GPU execution shall be optional, explicitly capability-checked, and accompanied by a CPU fallback or an explicit unavailable result. | Core | T, I |
| CON-004 | MATLAB parallel execution, when used by the product, shall use only parpool("threads"); process-based pools shall be unsupported. | Core | T, I |
| CON-005 | Backend radiometry shall use full source imagery and the configured output grid. | Core | T, A |
| CON-006 | Display pyramids, preview tiles, alignment working images, and dense/surface products shall never become backend radiometric inputs. | Core | T, I |
| CON-007 | Graphics handles, timers, GPU contexts, interpolants, file handles, and runtime caches shall remain outside serializable scene, layer, source, job, correction, and scientific-result structures. | Core | T, I |
| CON-008 | Presentation-only state shall not silently mutate source origins, source rays, physical planes, output grids, or accepted scientific corrections. | Core | T, I |
| CON-009 | Committed code, tests, documentation, and example configuration shall not disclose private synthetic-fixture sensor or geometry values. | Core | I |
| CON-010 | The main viewer shall remain programmatic MATLAB UI code and shall not require a .mlapp artifact. | Core | I |
| CON-011 | Near-term scientific workflows shall support in-memory inputs and in-memory results with final TIFF, PNG, MAT, or JSON output as applicable. | Core | T |
| CON-012 | Production NITF, LAS/LAZ, PLY, and GeoTIFF output shall not block the MATLAB scientific pipeline or its near-term acceptance. | Core | I |
| CON-013 | Invalid geometry shall produce an explicit error or invalid-state result according to the applicable API contract and shall not silently produce authoritative NaN/Inf output. | Core | T |
| CON-014 | Every accelerated or mixed-precision result shall identify the actual execution and precision path. | Approved | T, I |

### 2.5 Assumptions and dependencies

| ID | Requirement or assumption | Class | Verify |
| --- | --- | --- | --- |
| DEP-001 | Basic viewer launch shall require only layer names, in-memory image arrays, source-geometry definitions, and a physical plane. | Core | T, D |
| DEP-002 | Optional view, pass, acquisition-time, and scan metadata shall enrich but shall not prevent the basic launch contract. | Core | T |
| DEP-003 | Source geometry shall provide enough sampled origins and view vectors to evaluate requested image coordinates through the documented geometry adapter contract. | Core | T, I |
| DEP-004 | Tools that require unavailable timing, overlap, covariance, DEM metadata, or hardware shall report the missing dependency and shall preserve unrelated functionality. | Core | T, D |
| DEP-005 | The truth-aware synthetic fixture shall be the primary repository-accessible systematic alignment and dense-surface acceptance source. | Core | A, I |
| DEP-006 | Air-gapped real-data findings may refine individual metrics but shall not be assumed to provide a systematic repository dataset. | Core | I |
| DEP-007 | The initial DEM workflow shall accept DTED Level 2 or an equivalent WGS84 latitude/longitude elevation grid. | Approved | T |

## 3. External interface requirements

### 3.1 MATLAB geometry and launch interfaces

| ID | Requirement | Class | Verify |
| --- | --- | --- | --- |
| IF-MAT-001 | PlanarProjection shall expose plane construction, plane intersection/reconstruction, plane mapping, frame-camera construction, camera projection, vector normalization, triangulation, and geometry validation through compatible callable methods. | Core | T, I |
| IF-MAT-002 | Geometry inputs shall use column-oriented 3-D points/vectors and 2-D plane coordinates as documented. | Core | T, I |
| IF-MAT-003 | A plane value shall expose origin, two-vector right-handed basis, and unit normal with validated dimensions and nondegeneracy. | Core | T |
| IF-MAT-004 | A frame-camera value shall expose optical center, unit forward axis, positive focal length, and focal plane. | Core | T |
| IF-MAT-005 | runProjectionViewer shall accept the lightweight launch contract without requiring construction of GUI-internal objects. | Core | T, D |
| IF-MAT-006 | Each geometry definition may provide stable ViewId, PassId, AcquisitionStartTime, LineRateHz, ScanAxis, and ScanDirection metadata. | Core | T |
| IF-MAT-007 | Missing ViewId values shall be generated independently of filename, path, display name, and layer order. | Core | T |
| IF-MAT-008 | Missing PassId values shall place views in a documented default pass and shall not be inferred from filenames. | Core | T |
| IF-MAT-009 | Public headless functions shall return numeric or value-like scientific results without requiring an open viewer. | Core | T |

### 3.2 Time interface

| ID | Requirement | Class | Verify |
| --- | --- | --- | --- |
| IF-TIME-001 | Absolute acquisition text shall accept strict UTC DDMMYY_HHmmSS with optional fractional seconds. | Core | T |
| IF-TIME-002 | The system shall also accept an unambiguous four-digit-year UTC form and numeric relative time where the calling contract permits it. | Core | T |
| IF-TIME-003 | Two-digit years 80 through 99 shall map to 1980 through 1999, and 00 through 79 shall map to 2000 through 2079. | Core | T |
| IF-TIME-004 | The system shall retain original timestamp text for provenance and normalize absolute time to timezone-aware UTC datetime values. | Core | T, I |
| IF-TIME-005 | Per-line time shall be derived from acquisition start, line rate, scan axis, and scan direction when all required fields are available. | Core | T |
| IF-TIME-006 | Missing or incomparable timing shall produce an explicit unavailable or fallback-order status rather than a fabricated time relationship. | Core | T, D |

### 3.3 Viewer interface

| ID | Requirement | Class | Verify |
| --- | --- | --- | --- |
| IF-UI-001 | The main viewer shall present imagery, camera navigation, layer selection, blend/stereo state, and contextual workbench launch without permanently displaying all advanced controls. | Core | D, I |
| IF-UI-002 | Alignment-specific scheduling, matching, solver, curation, and diagnostics controls shall reside in the Alignment Workbench or contextual dialogs. | Core | D |
| IF-UI-003 | Surface selection, processing, uncertainty, fusion, and DEM controls shall reside in a separate Surface Workbench. | Approved | D |
| IF-UI-004 | GUI controls shall expose disabled or failed states with an operator-readable reason. | Core | T, D |
| IF-UI-005 | Keyboard shortcuts shall be captured only when their applicable interaction surface has focus and shall not interfere with editable fields, tables, dropdowns, or sliders. | Approved | T, D |
| IF-UI-006 | Long-running interactive operations shall expose bounded progress and cooperative cancellation where the underlying operation permits interruption. | Core | T, D |
| IF-UI-007 | Cancellation or algorithm failure shall leave previously accepted scientific and presentation state recoverable and internally consistent. | Core | T |

### 3.4 Backend job and file interfaces

| ID | Requirement | Class | Verify |
| --- | --- | --- | --- |
| IF-BE-001 | The backend shall accept an in-memory job or a validated serialized JSON/MAT job. | Core | T |
| IF-BE-002 | A backend job shall identify scene/state input, render options, execution mode, output policy, and optional alignment request. | Core | T, I |
| IF-BE-003 | The backend shall support in-memory output and final PNG/TIFF output with image, validity mask, and explainable metadata as configured. | Core | T |
| IF-BE-004 | TIFF output shall support bounded tiled writing; PNG output may require in-memory assembly. | Core | T, A |
| IF-BE-005 | Output radiometry shall use explicit class, scale, offset, fill value, and out-of-range policy without data-dependent normalization. | Core | T, A |
| IF-BE-006 | File-backed source descriptors shall be serializable while runtime readers and caches remain nonserializable. | Core | T, I |
| IF-BE-007 | File-backed TIFF region input shall reject unsupported threaded execution or select a documented serial path. | Core | T |
| IF-BE-008 | Partial output files shall be removed or clearly marked incomplete after a failed write. | Core | T |

### 3.5 SDK extension interfaces

| ID | Requirement | Class | Verify |
| --- | --- | --- | --- |
| IF-SDK-001 | Public SDK schemas shall be versioned independently of viewer scene serialization. | Approved | T, I |
| IF-SDK-002 | Extension algorithms shall be registered explicitly by the embedding application. | Approved | T, I |
| IF-SDK-003 | The system shall not scan arbitrary paths or instantiate classes named by untrusted serialized data. | Approved | T, I |
| IF-SDK-004 | Extension requests shall use graphics-independent values and shall provide progress and cancellation hooks independent of UI components. | Approved | T |
| IF-SDK-005 | Extension results shall report algorithm identity, semantic version, options, execution capability/fallback, precision, timing, memory, and provenance. | Approved | T, I |

## 4. Data and scientific model requirements

### 4.1 Coordinate frames and geometry

| ID | Requirement | Class | Verify |
| --- | --- | --- | --- |
| DATA-GEO-001 | All public geometry values shall declare or document their coordinate frame, handedness, axes, dimensions, and units. | Core | T, I |
| DATA-GEO-002 | Plane bases shall be right-handed such that the first basis vector crossed with the second equals the plane normal within tolerance. | Core | T |
| DATA-GEO-003 | View vectors used as directions shall be normalized before algorithms that require unit rays. | Core | T |
| DATA-GEO-004 | Source observations shall use continuous full-source column and row coordinates unless an interface explicitly states another coordinate space. | Core | T, I |
| DATA-GEO-005 | Mappings created in preview, pyramid, working-image, or rectified coordinates shall retain a continuous mapping back to full-source coordinates. | Core | T |
| DATA-GEO-006 | Source geometry shall support a sampled origin per applicable scan coordinate and a sampled view vector per image observation. | Core | T |
| DATA-GEO-007 | Projection offsets shall remain post-intersection in-plane registration terms and shall not mutate physical source origins or ray directions. | Core | T |
| DATA-GEO-008 | The system shall distinguish presentation camera orientation, in-plane basis reparameterization, and replacement of the physical plane. | Approved | T, I |
| DATA-GEO-009 | Routine pair-view commands shall not change plane origin, normal, basis, bounds, output grid, or source geometry. | Approved | T |
| DATA-GEO-010 | Any future physical-plane replacement shall require explicit preview, full dependency invalidation, recomputation, and rollback. | Gated | T, D |
| DATA-GEO-011 | The public ray-versus-line semantics of intersectPlane and triangulateRays shall remain compatible until a separately approved resolution defines forward-ray rejection or renamed signed-line behavior. | Core | T, I |

### 4.2 Identity, network, and lifecycle

| ID | Requirement | Class | Verify |
| --- | --- | --- | --- |
| DATA-ID-001 | A view shall have stable identity independent of layer order. | Core | T |
| DATA-ID-002 | An unordered pair shall have stable identity independent of moving/reference roles and stereo-eye roles. | Core | T |
| DATA-ID-003 | A pass shall have an explicit identifier and shall represent a collection segment with potentially correlated errors. | Core | T, I |
| DATA-ID-004 | A sparse or dense track shall identify one inferred physical feature and shall contain at most one observation from any view. | Approved | T |
| DATA-ID-005 | Scientific records shall retain stable view, pair, pass, track, observation, and generation identifiers applicable to their provenance. | Approved | T |
| DATA-ID-006 | Corrections, match ledgers, tracks, dense results, fusion results, and registrations shall identify the geometry revision or fingerprint from which they were derived. | Approved | T |
| DATA-ID-007 | Stale scientific results shall be rejected for application or explicitly marked stale; they shall not be silently applied to a different parent geometry. | Approved | T |
| DATA-ID-008 | Reversion shall restore an exact prior generation and shall not be implemented as an unverified negative correction. | Approved | T |

### 4.3 State separation and provenance

| ID | Requirement | Class | Verify |
| --- | --- | --- | --- |
| DATA-STATE-001 | Serializable scene state shall contain only durable scene, layer, source, and presentation values defined by its schema. | Core | T, I |
| DATA-STATE-002 | Runtime visibility snapshots, pair schedules, manual stereo-eye overrides, hover controls, timers, caches, and open workbench state shall not be serialized as scientific state. | Core | T, I |
| DATA-STATE-003 | Raw observations and rejection reasons shall remain available after filtering and solving. | Core | T |
| DATA-STATE-004 | Raw pairwise points, robust multi-view points, filtered points, voxel evidence, meshes, grids, and DEM-registered products shall remain distinguishable. | Approved | T, I |
| DATA-STATE-005 | Every derived scientific product shall identify its contributing source observations and relevant algorithm/configuration generation. | Approved | T |
| DATA-STATE-006 | Missing covariance, time, datum, confidence calibration, or truth shall be represented as unavailable or assumed and shall not be represented as zero error. | Approved | T, I |
| DATA-STATE-007 | Private synthetic configuration shall be loaded from an ignored local file, while a public schema-complete template shall permit independent reruns without revealing local values. | Core | T, I |

## 5. Functional requirements

### 5.1 Core planar projection

| ID | Requirement | Class | Verify |
| --- | --- | --- | --- |
| FR-GEO-001 | The system shall construct a plane from a view origin, forward direction, orientation reference, and range. | Core | T |
| FR-GEO-002 | The system shall construct stereo, fitted, basis-defined, and normal-defined planes and reject degenerate definitions. | Core | T |
| FR-GEO-003 | The system shall map world points to plane coordinates and reconstruct world points from plane coordinates. | Core | T |
| FR-GEO-004 | The system shall map coordinates between valid planes. | Core | T |
| FR-GEO-005 | The system shall intersect valid view directions with a plane according to the maintained public semantic contract. | Core | T |
| FR-GEO-006 | The system shall construct a positive-focal-length frame camera and project points to and from its focal plane. | Core | T |
| FR-GEO-007 | The system shall triangulate two viewing lines/rays and report the reconstructed point, closest points, and residual under the maintained public semantic contract. | Core | T |
| FR-GEO-008 | Geometry functions shall reject malformed sizes, zero-length vectors, degenerate bases, parallel intersections, and invalid camera-side points as defined by their contracts. | Core | T |

### 5.2 Interactive viewer and presentation

| ID | Requirement | Class | Verify |
| --- | --- | --- | --- |
| FR-VIEW-001 | The viewer shall project multiple image layers onto the supplied physical plane using each layer's source geometry. | Core | T, D |
| FR-VIEW-002 | The viewer shall support visibility, alpha, active-layer selection, blend/change viewing, camera pan/zoom/twist, crosshair, and documented layer-registration controls. | Core | T, D |
| FR-VIEW-003 | Interactive imagery may use display-only pyramids and tiles, while exact/headless products shall remain separately identifiable. | Core | T, I |
| FR-VIEW-004 | The viewer shall support stereo/anaglyph presentation without rebuilding projection geometry for display-only separation, depth, or exaggeration changes. | Core | T, D |
| FR-VIEW-005 | Red/cyan presentation shall assign red to the physical left eye derived from representative sensor origins in the current camera view. | Core | T |
| FR-VIEW-006 | Eye assignment shall be independent of layer order and moving/reference role. | Core | T |
| FR-VIEW-007 | Eye assignment shall use hysteresis near a head-on baseline and shall expose a runtime manual swap/reset override. | Core | T, D |
| FR-VIEW-008 | Manual eye overrides shall be pair-specific, runtime-only, and excluded from saved state and backend jobs. | Core | T |
| FR-VIEW-009 | The viewer shall retain responsive camera and pointer interaction by coalescing or deferring expensive display-only reconciliation where exact final state is subsequently flushed. | Core | A, D |
| FR-VIEW-010 | Tiled visibility and LOD selection shall use bounded runtime caches/pools and shall not cause unbounded graphics-object growth. | Core | T, A |
| FR-VIEW-011 | Geometry invalidation shall be limited to layers and derived products affected by the changed input. | Core | T, A |
| FR-VIEW-012 | Alpha changes shall not rebuild source geometry or select tiles solely because alpha changed. | Core | T |
| FR-VIEW-013 | A camera-only interaction shall not alter serializable scientific geometry. | Core | T |
| FR-VIEW-014 | The viewer shall expose bounded runtime performance diagnostics without adding those diagnostics to serializable scene state. | Core | T, I |
| FR-VIEW-015 | Mouse-wheel and drag interactions shall provide zoom and pan; documented modifier-wheel interactions shall provide plane Tip, plane Tilt, and camera Twist. | Core | T, D |
| FR-VIEW-016 | The viewer shall support projection-plane layer translation through W/A/S/D and the documented modifier-drag interaction. | Core | T, D |
| FR-VIEW-017 | The viewer shall support selected-layer omega, phi, and kappa adjustment through the documented keyboard and modifier-drag interactions. | Core | T, D |
| FR-VIEW-018 | The viewer shall support active-layer selection, stack reordering, visibility, alpha, single-layer cycling, temporary hold-to-hide, and complete Reset behavior. | Core | T, D |
| FR-VIEW-019 | The viewport context menu shall provide state Save/Load, Reset, Help, Crosshair, workbench visibility, layer cycling, and supported blend-mode commands. | Core | T, D |
| FR-VIEW-020 | Save and Load shall round-trip the documented viewer state, including selection/order, plane Tip/Tilt, camera Twist/pose, visibility, alpha, blend, projection offsets, and applied angular offsets. | Core | T |
| FR-VIEW-021 | Camera Twist shall support the approved orientation range through at least plus or minus 85 degrees. | Core | T, D |
| FR-VIEW-022 | When an oblique explicit plane is supplied without a caller camera pose, the initial camera shall orient the plane naturally upright and fit the projected footprint. | Core | T, D |
| FR-VIEW-023 | The initial camera shall support narrow long-range view angles below the historical 0.05-degree floor when required to frame a small footprint. | Core | T, D |

### 5.3 Pair controls and Alignment Workbench

| ID | Requirement | Class | Verify |
| --- | --- | --- | --- |
| FR-PAIR-001 | The Alignment Workbench shall expose an active pair with independently selectable reference and moving roles. | Core | T, D |
| FR-PAIR-002 | The operator shall be able to swap reference/moving roles without changing stable pair identity or forcing a stereo-eye swap. | Core | T |
| FR-PAIR-003 | The operator shall be able to step through a deterministic pair schedule, enable or disable a pair for network use, and review disabled pairs explicitly. | Core | T, D |
| FR-PAIR-004 | Pair navigation shall update inspection state without automatically matching, solving, applying corrections, or rebuilding source geometry. | Core | T |
| FR-PAIR-005 | Solo-pair mode shall temporarily show the two active views, snapshot prior runtime visibility, follow pair changes, and restore surviving views by stable identity. | Core | T, D |
| FR-PAIR-006 | Solo-pair mode shall not change serialized visibility, matching state, accepted corrections, or backend state. | Core | T |
| FR-PAIR-007 | The active-pair display shall identify pair status, network enablement, stereo-eye assignment, and available diagnostics. | Core | T, D |
| FR-PAIR-008 | The workbench shall provide staged Match, Filter, Solve, Preview, Apply, Revert, overlay, ROI, curation, and diagnostics behavior. | Core | T, D |
| FR-PAIR-009 | Changes to setup shall invalidate Match and downstream stages; filter changes shall retain raw matches; solve-setting or curation changes shall retain match/filter evidence and invalidate only dependent stages. | Core | T |
| FR-PAIR-010 | The operator shall be able to curate pair use and match evidence without losing the immutable raw-match ledger. | Core | T, D |
| FR-PAIR-011 | ROI changes shall refilter stored observations using projection-plane match coordinates without rerunning detection when the source evidence is unchanged. | Core | T |
| FR-PAIR-012 | Overlays shall reproject each endpoint through current geometry and shall remain invariant to layer reordering. | Core | T |
| FR-PAIR-013 | A pair-only solve shall be labeled diagnostic, preview, or warm-start behavior and shall not be the default durable global adjustment. | Approved | T, I |

### 5.4 Pair viewpoint

| ID | Requirement | Class | Verify |
| --- | --- | --- | --- |
| FR-PVIEW-001 | The workbench shall provide a pair-viewpoint command and a one-step restore-camera command. | Approved | T, D |
| FR-PVIEW-002 | Pair viewpoint shall use representative origins over shared overlap where available and shall fall back to the documented representative-origin rule. | Approved | T |
| FR-PVIEW-003 | Pair viewpoint shall place the camera at the origin midpoint, aim at the common-footprint centroid, derive stable up from the current plane, and fit the footprint with padding. | Approved | T, D |
| FR-PVIEW-004 | Follow active pair shall be optional, runtime-only, and disabled by default. | Approved | T |
| FR-PVIEW-005 | Manual camera movement shall suspend following for the current pair; subsequent pair navigation shall resume following when enabled. | Approved | T, D |
| FR-PVIEW-006 | Pair viewpoint shall disable with an explanation when required overlap or geometry is unavailable. | Approved | T, D |

### 5.5 Keyboard and motion-imagery presentation

| ID | Requirement | Class | Verify |
| --- | --- | --- | --- |
| FR-MOTION-001 | Shift+Up/Down shall adjust Tip and Shift+Left/Right shall adjust Tilt by the configured existing increment. | Approved | T, D |
| FR-MOTION-002 | In normal mode, Left/Right shall select the previous/next layer without changing visibility. | Approved | T, D |
| FR-MOTION-003 | In normal mode, Up/Down shall perform the documented vertical layer nudge while existing W/A/S/D controls remain available. | Approved | T, D |
| FR-MOTION-004 | Motion-imagery mode shall be launched contextually and shall not add permanent controls to the main viewer. | Approved | D, I |
| FR-MOTION-005 | Motion-imagery mode shall present one aligned, currently applied image geometry at a time with a fixed viewer camera and physical plane. | Approved | T, D |
| FR-MOTION-006 | Motion sequence membership shall be explicit and independent of current visibility, shall default to all eligible views, and shall permit pass and per-view filtering. | Approved | T |
| FR-MOTION-007 | Motion mode shall require at least two eligible frames and shall explain why it is unavailable otherwise. | Approved | T, D |
| FR-MOTION-008 | Caller-supplied order shall be authoritative; otherwise the sequence shall use comparable acquisition time within pass followed by a stable documented fallback. | Approved | T |
| FR-MOTION-009 | The sequence shall not interleave incomparable absolute and relative clocks as if they shared one time basis. | Approved | T |
| FR-MOTION-010 | Left/Right shall step frames in motion mode; Up/Down shall not mutate layers in motion mode; Shift+Arrows shall retain Tip/Tilt behavior. | Approved | T, D |
| FR-MOTION-011 | Motion stepping shall not wrap by default; a runtime Loop option shall enable wrapping. | Approved | T |
| FR-MOTION-012 | Entry shall snapshot visibility, active layer, blend/anaglyph, stereo, and presentation state, and exit/close shall restore that state exactly for surviving layers. | Approved | T |
| FR-MOTION-013 | A transient or pinnable identity display shall show layer, sequence position, acquisition time when available, pass, and applied-correction status. | Approved | T, D |
| FR-MOTION-014 | Persistent status shall identify fallback ordering, stale geometry, missing data, or load failure. | Approved | T, D |
| FR-MOTION-015 | Edge navigation affordances shall update only on hover-state transition and shall fall back to low-cost persistent controls if hover handling degrades interaction. | Approved | A, D |
| FR-MOTION-016 | Playback shall support Play/Pause, 0.5 through 10 frames per second, and a default of 2 frames per second. | Approved | T, D |
| FR-MOTION-017 | Playback shall not interpolate, crossfade, or silently skip frames and shall use at most one-frame bounded lookahead. | Approved | T, A |
| FR-MOTION-018 | Space shall toggle playback only in motion mode; outside motion mode it shall retain its existing hold-to-hide behavior. | Approved | T, D |
| FR-MOTION-019 | Escape shall stop and exit motion mode, and manual stepping shall pause playback before moving once. | Approved | T |
| FR-MOTION-020 | Playback shall pause with an explicit reason on focus loss, sequence/layer mutation, missing data, or load failure. | Approved | T, D |

### 5.6 Sparse alignment and filtering

| ID | Requirement | Class | Verify |
| --- | --- | --- | --- |
| FR-ALIGN-001 | The system shall render pair-specific bounded alignment working images from full source imagery and current source geometry. | Core | T, A |
| FR-ALIGN-002 | Working-image grids shall be isotropic in projection-plane units, derived from pair overlap, bounded by configured size, and stable under insignificant geometry changes. | Core | T |
| FR-ALIGN-003 | Working images shall retain validity masks and continuous mappings between their pixels, projection-plane coordinates, and both full source images. | Core | T |
| FR-ALIGN-004 | Feature preparation shall be deterministic, mask-aware, and explicit about detector support rejected at invalid regions or borders. | Core | T |
| FR-ALIGN-005 | Detector, preprocessing, analysis scale, feature count, matcher ratio, match threshold, uniqueness, and seed/options shall be applied and reported explicitly. | Core | T, I |
| FR-ALIGN-006 | The default matcher selection shall be deterministic; an approximate nondeterministic method shall not be silently selected. | Core | T |
| FR-ALIGN-007 | The match ledger shall preserve every raw candidate, cumulative stage masks, rejection reasons, source observations, and solver-use state. | Core | T |
| FR-ALIGN-008 | Geometric filtering labeled similarity shall fit rotation, uniform scale, and translation; filtering labeled affine shall permit the additional affine degrees of freedom. | Core | T |
| FR-ALIGN-009 | Native-coordinate plausibility filters shall use explicit pixels and shall not assume independent oblique images share one constant displacement. | Core | T, I |
| FR-ALIGN-010 | When valid ray geometry exists, the staged workflow shall support robust epipolar/coplanarity filtering after loose catastrophic image-space rejection. | Core | T |
| FR-ALIGN-011 | Coplanarity filtering shall use normalized angular or Sampson-style ray residuals and shall retain degeneracy and weight diagnostics per observation. | Core | T, A |
| FR-ALIGN-012 | Projection-plane, forward-ray, and coplanarity residuals shall use explicit distinct units and names. | Core | T, I |
| FR-ALIGN-013 | The safe-solve acceptance policy shall use a stable physical diagnostic independent of the selected optimizer display loss. | Core | T |
| FR-ALIGN-014 | The system shall expose raw, filtered, curated, solver-used, rejected, and invalid counts and reasons without requiring access to private GUI state. | Core | T, D |
| FR-ALIGN-015 | Repeating an unchanged match request may reuse runtime working imagery, but display alpha changes shall not invalidate scientific match inputs. | Core | T, A |
| FR-ALIGN-016 | Shift+left common-anchor adjustment shall move both selected images through a shared two-degree-of-freedom boresight correction while preserving their differential correction. | Core | T, D |
| FR-ALIGN-017 | One common anchor shall not claim to solve common kappa, and manual-drag history shall remain session-only while resulting accepted OPK remains serializable. | Core | T, I |
| FR-ALIGN-018 | An optional shared image-Y or focal-scale correction shall use explicit bounds and regularization distinct from OPK and shall remain disabled unless selected. | Core | T |

### 5.7 Pair graph, tracks, and global alignment

| ID | Requirement | Class | Verify |
| --- | --- | --- | --- |
| FR-NET-001 | The multi-image network shall represent views as nodes, enabled pairs as edges, and reconciled feature tracks as multi-view evidence. | Approved | T, I |
| FR-NET-002 | Pair scheduling shall consider sequential, nonsequential, and cross-pass pairs and shall not be restricted to adjacent images. | Approved | T |
| FR-NET-003 | The scheduler shall cheaply score plausible pairs using overlap, geometry, time/pass separation, radiometric compatibility, predicted occlusion, existing support, and operator overrides as available. | Approved | T |
| FR-NET-004 | The default selected graph shall begin with a deterministic quality spanning forest and add useful loop-closing chords subject to quality and budget controls. | Approved | T, A |
| FR-NET-005 | The operator shall be able to select quality/speed, a hard maximum pair count, forced inclusion/exclusion, and all plausible pairs with predicted cost. | Approved | T, D |
| FR-NET-006 | The scheduler shall report selected tree edges, chords, connected components, node degree, cycle basis, rejections, and infeasible connectivity. | Approved | T |
| FR-NET-007 | Track construction shall merge pair matches only when stable observation identity, descriptor consistency, geometry, and conflict checks agree. | Approved | T |
| FR-NET-008 | Track construction shall reject ambiguous transitive merges and shall not admit multiple observations from one view into one track. | Approved | T |
| FR-NET-009 | Track and edge diagnostics shall evaluate path and cycle closure, including direct-versus-composed observation disagreement. | Approved | T, A |
| FR-NET-010 | Cycle evidence shall initially validate association and diagnose edges rather than duplicate the same physical observation as an additional solver residual. | Approved | T, I |
| FR-NET-011 | The global objective shall remain block sparse, with residuals coupling only participating views/tracks and with small dense local blocks permitted. | Approved | A, I |
| FR-NET-012 | The primary multi-image solve shall optimize all enabled valid network evidence simultaneously rather than sequentially applying unrelated pair solves. | Approved | T, A |
| FR-NET-013 | With valid ray geometry, the default network residual shall be robust epipolar coplanarity; ray-to-ray and plane-space modes shall remain diagnostic or fallback alternatives. | Approved | T, A |
| FR-NET-014 | The first network solver shall estimate one constant OPK correction per image while holding source-ray origins fixed. | Approved | T |
| FR-NET-015 | Effective OPK shall be parameterized as a pass-common component plus a per-image differential component with a weighted zero-mean differential constraint per pass. | Approved | T, A |
| FR-NET-016 | Different passes shall have independent common components connected by cross-pass observations. | Approved | T, A |
| FR-NET-017 | The default gauge shall use balanced covariance/prior control; an explicit fixed-reference policy shall be available and the first layer shall not be silently fixed. | Approved | T |
| FR-NET-018 | The solver shall initially use interpretable Huber robustification with a physically bounded scale and shall keep parameter priors outside observation robustification. | Approved | T, A |
| FR-NET-019 | Final robust weights and rejection reasons shall remain inspectable; an advanced Cauchy comparison may be provided without changing the default. | Approved | T |
| FR-NET-020 | The solver shall diagnose gauge deficiency, rank weakness, disconnected components, bound hits, prior dominance, position-like residual structure, and systematic regional/time/pass residuals. | Approved | T, A |
| FR-NET-021 | The solver shall report common/differential/effective corrections, before/after residuals by pair/track/pass/region, weak images, components, and leave-one-pair-out sensitivity. | Approved | T, A |
| FR-NET-022 | A disconnected component shall be solved only when it has a valid gauge; otherwise the operation shall stop for that component and explain the deficiency. | Approved | T |
| FR-NET-023 | Re-match shall create a new ledger generation from current geometry, preserve the prior generation, and invalidate dependent filter/solve state. | Approved | T |
| FR-NET-024 | Global preview and Apply shall operate atomically across all solved images and shall provide one network-level exact revert. | Approved | T |
| FR-NET-025 | Editing evidence, gauge, priors, or parameter scope after a solve shall require a new solve and shall not relabel edited numbers as solver output. | Approved | T, I |
| FR-NET-026 | The system shall provide Single pass, Multiple passes, and Independent views/custom-priors configurations over one solver model. | Approved | T, D |

### 5.8 Time-varying correction

| ID | Requirement | Class | Verify |
| --- | --- | --- | --- |
| FR-TVC-001 | Time-varying attitude correction shall be introduced only after constant network alignment and dense observation support demonstrate local observability. | Gated | A, I |
| FR-TVC-002 | Time-varying attitude shall use small rotation vectors in a local tangent space composed with nominal attitude rather than interpolation of Euler angles. | Gated | T, A |
| FR-TVC-003 | The initial model shall use cubic B-spline control posts nominally every 128 image columns with second-difference or IMU-informed smoothness. | Gated | T |
| FR-TVC-004 | The model shall support pass-common low-frequency and per-image components and shall automatically coarsen post spacing where support is weak. | Gated | T, A |
| FR-TVC-005 | A per-column correction shall be available only as an analysis or upper-bound experiment unless its observability and stability are demonstrated. | Gated | A |
| FR-TVC-006 | Time-varying correction results shall use the same generation, frame, unit, covariance, application, and provenance contracts as constant corrections. | Gated | T, I |

### 5.9 Backend rendering and output

| ID | Requirement | Class | Verify |
| --- | --- | --- | --- |
| FR-BE-001 | The backend shall apply a validated viewer state to an input scene without requiring graphics. | Core | T |
| FR-BE-002 | The backend shall plan the configured full-extent output grid in physical plane coordinates. | Core | T, A |
| FR-BE-003 | The default numerical rendering mode shall inverse-map output samples through source geometry into continuous full-source image coordinates. | Core | T, A |
| FR-BE-004 | Nearest and bilinear radiometric sampling shall honor source validity and configured fill behavior. | Core | T |
| FR-BE-005 | The historical sparse-intensity renderer may remain only as an explicitly selected compatibility/reference mode. | Core | T, I |
| FR-BE-006 | The backend shall compile reusable runtime geometry/interpolation state once per job where valid and reuse it across output tiles. | Core | T, A |
| FR-BE-007 | The serial tiled path shall bound retained tile work and shall support indexed final TIFF assembly. | Core | T, A |
| FR-BE-008 | Thread mode shall use bounded parfeval submission on parpool("threads"), consume completed tiles promptly, and report configured and observed in-flight counts. | Core | T, A |
| FR-BE-009 | Tile reports and output ordering shall be deterministic even when thread completion order differs. | Core | T |
| FR-BE-010 | Output.InMemoryPolicy shall support automatic, always, and never retention with an explicit maximum in-memory pixel ceiling. | Core | T |
| FR-BE-011 | Streaming output may return summaries in place of complete image arrays and shall report what was retained. | Core | T |
| FR-BE-012 | WorkingPrecision may select single tile products only when geometry/radiometry parity remains within an approved double-reference tolerance. | Core | T, A |
| FR-BE-013 | Backend geometry, mapping, and authoritative output metadata shall preserve their declared precision independently of display precision. | Core | T, I |
| FR-BE-014 | The backend shall support in-memory sources and serial file-backed TIFF region sources with numerical parity within the approved tolerance. | Core | T, A |
| FR-BE-015 | A file-backed tile read shall request only the required source bounding region plus interpolation support rather than the entire source image. | Core | T, A |
| FR-BE-016 | Optional headless alignment shall use the same safety policy as interactive alignment and shall render the unchanged scene when a proposal is rejected. | Core | T |
| FR-BE-017 | Backend results shall report alignment acceptance/rejection, GPU request/availability/fallback, render-plan summary, execution mode, precision, radiometry, and output provenance. | Core | T, I |
| FR-BE-018 | GPU requests shall never make CPU-only hardware unable to complete an otherwise valid backend job. | Core | T |
| FR-BE-019 | Backend output-grid planning shall ignore transient viewer pan/zoom, cover the full rendered-layer extent, honor output-axis Twist, preserve an appropriate source-derived resolution, and warn on unexpectedly large dimensions. | Core | T, A |
| FR-BE-020 | The backend shall support composite and unblended per-layer products for single-band, RGB, and arbitrary-band sources, assuming each image's bands are internally registered. | Core | T |
| FR-BE-021 | Backend anaglyph output shall follow its documented headless channel contract; interactive display-only separation, depth, and exaggeration shall not affect backend output without a separately approved export contract. | Core | T, I |

### 5.10 Dense correspondence

| ID | Requirement | Class | Verify |
| --- | --- | --- | --- |
| FR-DENSE-001 | The system shall retain the existing CPU-complete SGM dense extractor as a supported baseline. | Core | T |
| FR-DENSE-002 | Optional SGM GPU execution shall capability-check gpuArray support, gather the result, report fallback, and leave CPU output available. | Core | T, A |
| FR-DENSE-003 | Dense processing shall operate on bounded analysis imagery with validity and full-source coordinate mappings and shall not use viewer preview textures as source radiometry. | Core | T, I |
| FR-DENSE-004 | The SGM baseline shall be audited with synthetic truth across range, intersection angle, relief, occlusion, radiometric bands, navigation errors, rectification error, texture, disparity, and execution path. | Approved | A |
| FR-DENSE-005 | Dense audit metrics shall include completeness, gross-outlier rate, subpixel error, height error, consistency, occlusion behavior, runtime, and memory. | Approved | A |
| FR-DENSE-006 | The product shall not expose an automatic Best matcher until deterministic truth-supported selection rules exist. | Approved | T, I |
| FR-DENSE-007 | Sparse accepted tracks may predict local disparity, epipolar direction or locus, depth range, and search uncertainty for dense matching. | Approved | T, A |
| FR-DENSE-008 | Sparse seeds shall constrain search but shall not force dense points onto a sparse surface; unsupported areas shall retain an explicit no-support state. | Approved | T, A |
| FR-DENSE-009 | A classical matcher shall support explainable multi-scale template search along local epipolar loci or locally rectified strips. | Approved | T, A |
| FR-DENSE-010 | Candidate template costs shall include documented implementations or selections from normalized correlation, gradient correlation, census/rank, and selected phase-correlation methods. | Approved | T, A |
| FR-DENSE-011 | Dense matching shall provide best-versus-second uniqueness, forward/backward consistency, subpixel refinement, texture/conditioning, geometric residual, and deterministic tie diagnostics. | Approved | T, A |
| FR-DENSE-012 | Every dense observation shall report exactly one primary state among valid, occluded, ambiguous/repetitive, insufficient texture, outside overlap, geometry/search failure, masked, and algorithm failure. | Approved | T |
| FR-DENSE-013 | Confidence shall remain an uncalibrated score until truth evidence supports probabilistic calibration; raw scores and competing hypotheses shall remain available. | Approved | T, A |
| FR-DENSE-014 | General pushbroom matching shall support spatially varying epipolar geometry through sampled-locus search, local rectification, or a terrain-coordinate grid with full-source mappings. | Approved | T, A |
| FR-DENSE-015 | Rectification or local search shall report residual geometric error and shall not label a single global line approximation exact when geometry varies spatially. | Approved | T, A |
| FR-DENSE-016 | Dense-pair scheduling shall be independent of sparse-pair scheduling and shall favor overlap, conditioning, complementary geometry, texture, radiometry, and visibility. | Approved | T |
| FR-DENSE-017 | When four or more useful views exist, dense evaluation should reserve an independent validation view where practical and shall report when it cannot. | Approved | A, I |

### 5.11 Point reconstruction and surface fusion

| ID | Requirement | Class | Verify |
| --- | --- | --- | --- |
| FR-SURF-001 | Each dense pair match shall retain both full-source observations, corrected rays, scores, geometric diagnostics, and provisional triangulation. | Approved | T |
| FR-SURF-002 | Ray triangulation used for surface products shall require forward-valid ray parameters and shall report ray separation and conditioning. | Core | T |
| FR-SURF-003 | The preferred multi-view reconstruction shall associate dense observations into tracks and robustly solve one point against all contributing rays. | Approved | T, A |
| FR-SURF-004 | Pairwise point averaging may be retained only as a labeled initial oracle and shall not count correlated duplicate pairs as independent precision. | Approved | T, I |
| FR-SURF-005 | Multi-view reconstruction shall weight independent views and passes, reject inconsistent rays, preserve valid two-view tracks, and split competing depth or occlusion modes where supported. | Approved | T, A |
| FR-SURF-006 | Every authoritative point shall report contributing views/pairs, ray parameters, residuals/rejections, conditioning, radiometric consistency, visibility, and covariance or its unavailable reason. | Approved | T |
| FR-SURF-007 | The authoritative surface result shall be a provenance-rich 3-D point set; meshes, voxel products, and grids shall be derived products retaining contributing point IDs. | Approved | T, I |
| FR-SURF-008 | Surface stages shall distinguish raw pairwise, robust multi-view, filtered/classified, optional mesh/TIN, optional grid, and registered variants. | Approved | T, I |
| FR-SURF-009 | The product shall not force urban vertical surfaces, overhangs, or competing heights into a single-valued DEM representation. | Approved | A, I |
| FR-SURF-010 | The initial volumetric study shall compare direct robust multi-ray reconstruction, hard voxel occupancy, and uncertainty-weighted Gaussian splats on bounded truth-aware ROIs. | Gated | A |
| FR-SURF-011 | Voxel scale shall be derived from GSD or predicted 3-D uncertainty, swept across representative values, and recorded with the result. | Gated | A |
| FR-SURF-012 | Voxel evidence shall count independent views or passes rather than raw pair multiplicity and shall preserve competing modes. | Gated | T, A |
| FR-SURF-013 | An occupancy-concentration pose objective shall remain auxiliary until truth demonstrates that it avoids false collapse, duplicate evidence, and excessive smoothing. | Gated | A |
| FR-SURF-014 | The volumetric path shall be abandoned or retained only as diagnostic output if it adds no reliable accuracy, completeness, uncertainty, or interpretability value over multi-ray reconstruction. | Gated | A, I |
| FR-SURF-015 | Scientific surface results shall be returnable directly to MATLAB and persistable as MAT plus compact JSON metadata. | Approved | T |

### 5.12 Surface Workbench

| ID | Requirement | Class | Verify |
| --- | --- | --- | --- |
| FR-SWB-001 | The Surface Workbench shall select views/passes, pair schedule, dense method, geometry search, processing stage, uncertainty filters, fusion product, DEM registration, and output product. | Approved | T, D |
| FR-SWB-002 | The Surface Workbench shall expose progress, cancellation, processing diagnostics, pair/multi-view statistics, and estimated cost/memory. | Approved | T, D |
| FR-SWB-003 | The 3-D viewer shall display point, mesh, and gridded products and compare raw, fused, uncertainty-filtered, voxel, DEM, and registered variants. | Approved | T, D |
| FR-SWB-004 | The 3-D viewer shall color by source intensity, elevation, view/pass count, residual, uncertainty, conditioning, fusion method, pair/pass, or DEM difference as applicable. | Approved | T, D |
| FR-SWB-005 | Selecting a 3-D point shall link to its contributing full-source image observations. | Approved | T, D |
| FR-SWB-006 | Uncertainty ellipsoids or principal-axis glyphs shall be limited to selected or bounded subsets to preserve responsiveness. | Approved | T, A |
| FR-SWB-007 | Interactive decimation shall not discard or overwrite the complete authoritative result. | Approved | T |
| FR-SWB-008 | Graphics state for surface visualization shall remain runtime-only. | Approved | T, I |

### 5.13 Uncertainty

| ID | Requirement | Class | Verify |
| --- | --- | --- | --- |
| FR-UNC-001 | The initial uncertainty input shall support one full 6x6 common pose covariance per pass and one full 6x6 differential pose covariance per image, including position/attitude cross terms. | Approved | T |
| FR-UNC-002 | A source-localization covariance shall be 2x2 in continuous full-source [column,row] coordinates with units of pixels squared. | Approved | T, I |
| FR-UNC-003 | Covariance originating in a working, pyramid, or rectified coordinate space shall map to full-source observation space through the applicable coordinate Jacobian. | Approved | T, A |
| FR-UNC-004 | Pushbroom scan-coordinate uncertainty shall map to timing uncertainty through line rate when timing is available. | Approved | T, A |
| FR-UNC-005 | Every covariance block shall declare units, frame, ordering, and whether it is prior, posterior, calibrated, or assumed. | Approved | T, I |
| FR-UNC-006 | Same-pass correlations shall be represented and shall not be replaced by an assumption that all rays are independent. | Approved | T, A |
| FR-UNC-007 | Initial covariance propagation shall use carefully scaled central numerical Jacobians in double precision. | Approved | T, A |
| FR-UNC-008 | Numerical propagation shall be validated against synthetic truth and Monte Carlo before a higher-throughput derivative path is accepted. | Approved | A |
| FR-UNC-009 | Nonlinear, bounded, multimodal, or weak cases shall be compared with sigma-point or Monte Carlo behavior and shall be labeled unreliable when a local Gaussian result is misleading. | Approved | A |
| FR-UNC-010 | The global solver shall expose an approximate posterior covariance or selected marginal covariances with conditioning and observability status. | Approved | T, A |
| FR-UNC-011 | Dense confidence shall not be converted to observation variance until calibrated against truth. | Approved | A, I |
| FR-UNC-012 | Each reconstructed point shall support a 3x3 covariance in the authoritative world frame with units of meters squared. | Approved | T |
| FR-UNC-013 | Point covariance shall be checked for symmetry and positive-semidefinite behavior; unreliable nonlinear results shall be marked rather than silently repaired. | Approved | T, A |
| FR-UNC-014 | Outputs shall provide principal axes, horizontal/vertical uncertainty, view/pass contribution count, and dominant uncertainty source when available. | Approved | T |
| FR-UNC-015 | Surface gridding shall propagate or summarize input uncertainty and shall not substitute unqualified sample variance for measurement uncertainty. | Approved | T, A |

### 5.14 DEM ingestion and registration

| ID | Requirement | Class | Verify |
| --- | --- | --- | --- |
| FR-DEM-001 | DEM ingestion shall accept WGS84 latitude/longitude grids with HAE or MSL heights. | Approved | T |
| FR-DEM-002 | MSL heights shall use EGM96 by default; an omitted DTED height reference shall be recorded as an MSL/EGM96 assumption. | Approved | T, I |
| FR-DEM-003 | DEM validity shall use NaN/Inf and an optional no-data sentinel; a separate validity mask shall not be mandatory. | Approved | T |
| FR-DEM-004 | Caller-supplied CE90/LE90 shall take precedence over valid dataset metadata, which shall take precedence over documented DTED2 defaults of CE90 23 m and LE90 18 m. | Approved | T |
| FR-DEM-005 | The system shall preserve CE90/LE90 values and state any distribution assumption used to convert them to covariance-like measures. | Approved | T, I |
| FR-DEM-006 | DEM work shall normalize to double-precision scene-local ENU and HAE while preserving reversible WGS84, ECEF, and project-world transforms. | Approved | T, A |
| FR-DEM-007 | HAE and orthometric height shall never be mixed without an explicit conversion and recorded geoid model. | Approved | T |
| FR-DEM-008 | Initial registration shall estimate one robust global 3-D translation in scene-local ENU. | Approved | T, A |
| FR-DEM-009 | Registration shall use point-to-local-surface-normal or equivalent local-surface residuals weighted by reconstructed-point covariance, DEM uncertainty, slope, and conditioning. | Approved | T, A |
| FR-DEM-010 | Buildings, vegetation, water, changed areas, and voids shall be excluded or robustly down-weighted when identified. | Approved | T, A |
| FR-DEM-011 | Registration shall preserve the imagery-only point product and shall not snap individual reconstructed points to the DEM. | Approved | T, A |
| FR-DEM-012 | Registration shall not reuse DEM-constrained points as independent validation evidence. | Approved | A, I |
| FR-DEM-013 | Registration shall report transform direction/frame, covariance, coverage, support/rejections, residual distribution, mask sensitivity, datum assumptions, and ambiguity. | Approved | T, A |
| FR-DEM-014 | Registration shall return a proposed correction and preview product and shall never automatically apply it to source geometry. | Approved | T |
| FR-DEM-015 | A later explicit DEM-derived correction Apply shall be atomic and revertible, validate frame/scope, update compatible origins, invalidate dependent evidence/products, and require recomputation. | Gated | T |
| FR-DEM-016 | Rotation, per-pass translation, and trajectory terms shall remain gated until truth demonstrates that they are distinguishable from gauge and datum errors. | Gated | A |

### 5.15 MATLAB correction SDK

| ID | Requirement | Class | Verify |
| --- | --- | --- | --- |
| FR-SDK-COR-001 | The SDK shall provide one immutable network-level CorrectionSet for each solver or registration generation. | Approved | T, I |
| FR-SDK-COR-002 | CorrectionSet records shall be keyed by stable ViewId and PassId and shall support typed pass-common, differential, effective, translation, and future correction blocks. | Approved | T |
| FR-SDK-COR-003 | Each correction generation shall distinguish proposed, accepted, applied, rejected, superseded, and historical state as applicable. | Approved | T |
| FR-SDK-COR-004 | Authoritative attitude corrections shall use radians and attitude covariance shall use radians squared; degree convenience accessors shall be explicit. | Approved | T |
| FR-SDK-COR-005 | Every attitude block shall declare omega/phi/kappa order, active/passive meaning, source and destination frames, composition order, multiplication side, increment sign, and incremental/absolute/common/differential/effective semantics. | Approved | T, I |
| FR-SDK-COR-006 | Existing public APIs that require degrees shall retain their unit behavior through validated adapters. | Approved | T |
| FR-SDK-COR-007 | Attitude changes shall compose as rotations and shall not use unqualified vector addition of OPK values. | Approved | T, A |
| FR-SDK-COR-008 | A result shall distinguish its increment relative to parent geometry from its effective correction relative to immutable base geometry. | Approved | T |
| FR-SDK-COR-009 | CorrectionSet shall retain geometry fingerprints, solver/match/track/gauge/precision/configuration provenance, covariance or marginals, bounds, conditioning, prior contribution, observability, and machine-readable failure reasons. | Approved | T, I |
| FR-SDK-COR-010 | The SDK shall expose graphics-independent operations to retrieve current and historical results, accept or reject a proposal, apply a compatible result, revert an exact generation, and round-trip portable data. | Approved | T |
| FR-SDK-COR-011 | Applying a result shall validate view identity, parent geometry revision, convention, frame, units, dimensions, and lifecycle compatibility before mutation. | Approved | T |
| FR-SDK-COR-012 | Reapplying an already applied generation shall be idempotent or explicitly rejected and shall not double-apply a rotation. | Approved | T |
| FR-SDK-COR-013 | Headless alignment shall return CorrectionSet directly without requiring an open application. | Approved | T |
| FR-SDK-COR-014 | Interactive launch may accept accepted, applied, and reverted callbacks; each callback shall receive an immutable result and fire only for its named transition. | Approved | T |
| FR-SDK-COR-015 | Callback failure shall be reported but shall not roll back or corrupt a successful scientific transition. | Approved | T |
| FR-SDK-COR-016 | Callbacks shall be supplementary to queryable correction history and shall not be the authoritative result store. | Approved | T, I |
| FR-SDK-COR-017 | CorrectionSet shall support MAT persistence and compact JSON metadata or a portable JSON representation according to the selected schema. | Approved | T |
| FR-SDK-COR-018 | Reading or constructing a portable CorrectionSet shall reject malformed or unsupported Format and Version values and shall never coerce an incompatible schema to the current version. | Approved | T |
| FR-SDK-COR-019 | Function-backed source geometry shall provide a stable serializable geometry revision or fingerprint token before a portable correction may be applied; an unverifiable closure shall fail compatibility. | Approved | T, I |
| FR-SDK-COR-020 | Geometry identity shall not serialize function workspaces, runtime closures, or private fixture values in order to establish compatibility. | Approved | T, I |
| FR-SDK-COR-021 | Proposal, acceptance, rejection, application, supersession, and historical or reverted state shall be represented by immutable lifecycle records; an earlier record shall never be mutated in place. | Approved | T |
| FR-SDK-COR-022 | A graphics-independent authoritative store shall expose current proposed, accepted, and applied generations and named history without requiring an open GUI. | Approved | T |
| FR-SDK-COR-023 | Apply shall validate the entire declared view scope before mutation, operate on a scene copy, verify every corrected geometry fingerprint, and publish the new scene and current generation atomically. | Approved | T |
| FR-SDK-COR-024 | Apply shall reject failed, rejected, superseded, historical, wrong-parent, stale, identity/pass/convention-mismatched, or dimension-incompatible results before any authoritative mutation. | Approved | T |
| FR-SDK-COR-025 | Revert shall restore and verify the exact parent generation; reapply shall be idempotent or rejected and shall never double-compose a correction. | Approved | T |
| FR-SDK-COR-026 | Accepted, applied, and reverted callbacks shall execute after transition commit on the MATLAB client/UI thread with deterministic ordering and reentrancy protection. | Approved | T |
| FR-SDK-COR-027 | Callback exceptions shall be retained in diagnostics without rolling back scientific state, and queryable history shall remain authoritative. | Approved | T |

### 5.16 Dense-matcher SDK

| ID | Requirement | Class | Verify |
| --- | --- | --- | --- |
| FR-SDK-DM-001 | The SDK shall provide a documented abstract dense-correspondence base class consumed by the workbench and headless pipeline. | Approved | T, I |
| FR-SDK-DM-002 | A matcher shall declare identity, semantic version, capabilities, supported imagery/geometry/radiometry, options schema/defaults, determinism, cancellation, precision, memory estimate, and CPU/GPU support. | Approved | T |
| FR-SDK-DM-003 | A matcher request shall contain stable view IDs, bounded read-only analysis arrays or readers, masks, full-source coordinate maps, corrected geometry, overlap ROI, search predictions, precision policy, and deterministic seed. | Approved | T |
| FR-SDK-DM-004 | A matcher result shall contain continuous observations in both full source images, explicit validity/no-match states, score/confidence, optional subpixel covariance, diagnostics, timing, memory, and provenance. | Approved | T |
| FR-SDK-DM-005 | The base class shall own contract validation, coordinate/mask checks, cancellation plumbing, result normalization, provenance, error classification, and execution capability reporting. | Approved | T |
| FR-SDK-DM-006 | A derived matcher shall implement algorithm-specific preparation and matching without mutating or retaining caller-owned arrays beyond the documented call lifetime. | Approved | T, I |
| FR-SDK-DM-007 | A matcher shall not return preview coordinates, a display pyramid, or a triangulated surface as a substitute for full-source observations. | Approved | T |
| FR-SDK-DM-008 | The SDK shall provide an adapter for the existing SGM implementation and for the planned classical matcher. | Approved | T |
| FR-SDK-DM-009 | The SDK shall provide a deliberately simple documented example matcher and a headless subclass-conformance suite. | Approved | T, I |
| FR-SDK-DM-010 | Registration of matcher implementations shall be explicit through a caller-supplied registry. | Approved | T |

### 5.17 Fusion, registration, and screening SDK

| ID | Requirement | Class | Verify |
| --- | --- | --- | --- |
| FR-SDK-EXT-001 | The SDK shall provide a documented abstract surface-fusion algorithm contract with stable identities, rays, observations, points, covariance, visibility, ROI, precision, seed, progress, and cancellation. | Approved | T, I |
| FR-SDK-EXT-002 | Fusion results shall support fused points, sparse voxel/octree evidence, competing modes, derived mesh/grid, uncertainty, contributors, rejections, timing, memory, precision, and provenance as applicable. | Approved | T |
| FR-SDK-EXT-003 | Built-in fusion implementations shall include robust multi-ray fusion and, if retained after evidence, hard occupancy and Gaussian splatting. | Gated | T, A |
| FR-SDK-EXT-004 | The SDK shall provide a headless DEM-registration service and a documented derivable registration algorithm contract. | Approved | T, I |
| FR-SDK-EXT-005 | Registration extensions shall receive imagery-only surfaces and explicit DEM datum/uncertainty/ROI/transform constraints and shall return a proposed transform without auto-application. | Approved | T |
| FR-SDK-EXT-006 | The first registration implementation shall perform robust global translation. | Approved | T, A |
| FR-SDK-EXT-007 | The SDK shall provide a documented derivable scene-suitability screener returning full-source masks or quality maps for supported invalidity, obscuration, water, texture, saturation, repetition, and radiometric compatibility states. | Approved | T, I |
| FR-SDK-EXT-008 | Initial screening shall include deterministic invalid-geometry, low-texture, and saturation checks; cloud and water detection shall remain data-gated. | Approved | T, A |
| FR-SDK-EXT-009 | Screening shall retain confidence, provenance, generation, usable coverage, and operator override and shall distinguish unobservable input from algorithm failure. | Approved | T |
| FR-SDK-EXT-010 | Every derivable SDK class shall document lifecycle, mathematical fields, frames, units, covariance, examples, headless use, determinism, cancellation, memory, acceleration, compatibility, and conformance testing. | Approved | I |

### 5.18 Synthetic truth and acceptance fixture

| ID | Requirement | Class | Verify |
| --- | --- | --- | --- |
| FR-SYN-001 | The synthetic fixture shall validate a strict local configuration schema and shall complete collection feasibility checks before allocating full-size output imagery. | Core | T |
| FR-SYN-002 | Collection planning shall derive coordinate transforms, roll-then-pitch gimbal composition, per-axis projected GSD, platform and scan contributions, timing, scene spacing, field-of-regard use, texture coverage, and oversampling. | Core | T, A |
| FR-SYN-003 | An infeasible configured collection shall report ordered checks, the first violated constraint, and the nearest computed schedule without silently modifying configured inputs. | Core | T |
| FR-SYN-004 | The fixture shall use a private ignored local configuration and a committed schema-complete template containing no private sensor or geometry values. | Core | T, I |
| FR-SYN-005 | Terrain truth shall be deterministic, smooth, asymmetric, nonperfectly radial, and capable of producing occlusion and first-hit visibility. | Core | T, A |
| FR-SYN-006 | Texture expansion shall use continuous reflected tiling or equivalent seamless addressing and shall support cycling selected source bands across generated views. | Core | T, A |
| FR-SYN-007 | Truth trajectory and reported navigation shall be separate; generated imagery shall use truth geometry and viewer/alignment input shall use reported geometry. | Core | T |
| FR-SYN-008 | Navigation shall provide generic Tactical Grade IMU and Navigation Grade IMU presets with physically plausible correlated sortie errors and deterministic grade ordering. | Core | T, A |
| FR-SYN-009 | A sortie error realization shall remain continuous across its views and shall distinguish pointing-only from combined navigation-error variants. | Core | T |
| FR-SYN-010 | Truth terrain, trajectory, and ray payloads shall not enter viewer-safe scene metadata or reported source geometry closures. | Core | T, I |
| FR-SYN-011 | Full-scale generation shall load source radiometry once, render in bounded internal chunks, retain complete requested outputs in memory when configured, and perform final TIFF/PNG writes. | Core | T, A |
| FR-SYN-012 | Acceptance shall run the ordinary alignment and dense pipeline on reported-only scene inputs and shall compare with compact truth only after producing the result. | Core | T, A |
| FR-SYN-013 | Acceptance shall support pointing-only and combined-error modes and shall produce exact repeatability evidence under the same deterministic configuration. | Core | T, A |
| FR-SYN-014 | Acceptance evidence shall distinguish mutually visible terrain, occluded terrain, invalid geometry, and texture-coverage failures. | Core | T, A |
| FR-SYN-015 | Multi-image truth validation shall expand across 2, 3, 4, and 6 views; graph variants; same-pass and multi-pass errors; corrupted edges; texture, occlusion, and masks; and uncertainty calibration. | Approved | T, A |
| FR-SYN-016 | Future simulation shall support a trajectory/pass provider for polygonal stop-sign passes, then true curved orbits, independent pass errors, and optional shared calibration after their parameters are approved. | Gated | T, A |

### 5.19 Mathematical and procedural references

| ID | Requirement | Class | Verify |
| --- | --- | --- | --- |
| FR-REF-001 | The project shall provide one self-contained code-independent mathematical manuscript in LaTeX using the IEEEtran two-column journal format and a compiled PDF. | Approved | I, D |
| FR-REF-002 | The manuscript shall define coordinate frames, transforms, gimbal/scanner formation, planes, rays, full-source projection, sparse matching, tracks, constraints, global OPK solve, priors, gauge, uncertainty, dense matching, triangulation, fusion, DEM registration, precision, and degeneracies. | Approved | I |
| FR-REF-003 | The manuscript shall describe pair viewpoint, stereo-eye assignment, anaglyph formation, and display-only stereo exaggeration while distinguishing presentation from physical geometry. | Approved | I |
| FR-REF-004 | The manuscript shall define symbols once, use plain language around equations, include appropriate diagrams, cite primary literature, and place detailed derivations and Jacobians in appendices. | Approved | I |
| FR-REF-005 | The mathematical manuscript shall avoid code-level classes, caches, tile pools, and UI implementation details. | Approved | I |
| FR-REF-006 | The project shall provide a direct procedural MATLAB two-image/anaglyph reference accepting two image arrays, a plane, camera/presentation values, two source geometries, and explicit output/stereo options. | Approved | T, I |
| FR-REF-007 | The procedural reference shall visibly perform output-grid definition, plane reconstruction, source inverse mapping, full-source interpolation/masking, physical eye assignment, display-only stereo transforms, and red/cyan composition. | Approved | T, A |
| FR-REF-008 | The procedural reference shall use double geometry by default and shall avoid GUI dependencies, hidden state, runtime caches, and application object hierarchies. | Approved | T, I |
| FR-REF-009 | Golden tests shall compare procedural and production MATLAB outputs for values, masks, eye assignment, plane coordinates, and stereo controls. | Approved | T, A |
| FR-REF-010 | The procedural reference shall serve as an executable companion to the mathematical manuscript and as the first C++ translation oracle. | Approved | I |

### 5.20 Future C++ and CUDA backend

| ID | Requirement | Class | Verify |
| --- | --- | --- | --- |
| FR-CPP-001 | The production backend shall be based on frozen code-independent equations, data contracts, public golden fixtures, and parity tolerances rather than treating MATLAB Coder output as the primary architecture. | Gated | I, A |
| FR-CPP-002 | The C++ core shall use explicit ownership, array views, units, frames, scalar types, precision boundaries, and a narrow stable C or language-neutral integration boundary. | Gated | T, I |
| FR-CPP-003 | The C++ project shall provide reproducible CMake builds and reviewed dependency/version/license records. | Gated | T, I |
| FR-CPP-004 | The first native target shall be Windows x64 with MSVC and MATLAB-compatible MEX/CUDA MEX integration; WSL 2 Linux command-line builds shall remain separate validation targets. | Gated | T, D |
| FR-CPP-005 | The C++ backend shall retain a complete explainable CPU reference path. | Gated | T |
| FR-CPP-006 | Eigen and Ceres shall receive explicit parity and performance prototypes; BLAS/LAPACK, SuiteSparse, and applicable accelerator backends shall be selected by measured problem structure. | Gated | A, I |
| FR-CPP-007 | OpenCV may provide reviewed image-processing or feature algorithms only behind Sightline coordinate, mask, precision, and provenance contracts. | Gated | T, I |
| FR-CPP-008 | Nonfree or deployment-restricted algorithms and dependencies shall require explicit legal and deployment review before inclusion. | Gated | I |
| FR-CPP-009 | The first custom CUDA/MEX experiment shall evaluate bounded dense template/correlation cost on the target Windows GPU before viewer integration. | Gated | T, A |
| FR-CPP-010 | Every CUDA kernel shall retain a CPU MATLAB oracle, capability check, clean fallback, value/mask/error parity test, and separate allocation/transfer/kernel/synchronization measurements. | Gated | T, A |
| FR-CPP-011 | GPU buffers and contexts shall remain runtime-only and shall not enter portable scientific or scene serialization. | Gated | T, I |
| FR-CPP-012 | The port shall progress through geometry and procedural rendering, source adapters and sparse alignment, dense matching and CUDA, uncertainty/fusion/DEM, then production I/O. | Gated | T, I |
| FR-CPP-013 | Each C++ stage shall pass independent unit tests, adversarial geometry tests, MATLAB parity, determinism checks, memory/error-policy review, and profiling before becoming authoritative. | Gated | T, A, I |
| FR-CPP-014 | Production NITF output shall remain gated until the scientific pipeline and production data contract are stable. | Gated | I |

## 6. Quality requirements

### 6.1 Correctness and scientific integrity

| ID | Requirement | Class | Verify |
| --- | --- | --- | --- |
| QR-COR-001 | Authoritative scientific outputs shall be traceable to full-source observations, current accepted geometry, configuration, algorithm version, and precision path. | Core | T, I |
| QR-COR-002 | Presentation operations shall not change backend output or scientific geometry unless an explicit scientific Apply operation is invoked. | Core | T |
| QR-COR-003 | Every filter, solver, dense, fusion, uncertainty, and registration failure shall preserve enough status and provenance to distinguish invalid input, unavailable capability, degeneracy, rejection, cancellation, and internal algorithm failure. | Core | T |
| QR-COR-004 | Accepted corrections shall satisfy configured bounds, safety criteria, gauge/observability requirements, and parent-generation compatibility. | Core | T, A |
| QR-COR-005 | Numerical comparisons shall use physically meaningful units and shall not mix plane meters, ray meters, pixels, angles, or height datums without explicit conversion. | Core | T, I |

### 6.2 Numerical precision

| ID | Requirement | Class | Verify |
| --- | --- | --- | --- |
| QR-PREC-001 | Double precision shall remain the authoritative scientific reference until evidence approves a narrower boundary. | Core | T, A |
| QR-PREC-002 | Serializable source geometry, physical planes/cameras, scientific corrections, backend coordinate mapping, solver state, Jacobian accumulation, factorization, and covariance shall use double precision by default. | Approved | T, I |
| QR-PREC-003 | Single precision may be used for discardable viewer-relative geometry, radiometry, dense costs, or voxel intermediates only at explicit tested boundaries. | Approved | T, A |
| QR-PREC-004 | Final triangulation, fusion refinement, and uncertainty shall be recomputed or refined in double when an intermediate uses reduced precision. | Approved | T, A |
| QR-PREC-005 | Precision validation shall compare local and large translated origins, shallow incidence, nearly parallel rays, small/wide baselines, multiple passes, weak networks, covariance dynamic range, dense subpixel recovery, and voxel accumulation. | Approved | A |
| QR-PREC-006 | Required range validation shall extend through 100 km; stretch validation shall extend to the closer of 200 km or the unrefracted geometric horizon. | Approved | A |
| QR-PREC-007 | Provisional well-conditioned limits shall target less than 0.1 screen pixel for display geometry and less than 0.01 full-source pixel for backend mapping, subject to final evidence-based adoption. | Approved | A |
| QR-PREC-008 | Precision changes shall not cause NaN/Inf, eye/sign reversal, material accepted-observation changes, or loss of covariance symmetry and positive-semidefinite behavior. | Approved | T, A |
| QR-PREC-009 | Mixed or GPU precision shall demonstrate a meaningful measured runtime or memory benefit before adoption. | Approved | A |
| QR-PREC-010 | Results and diagnostics shall record geometry, radiometric, solver, covariance, dense, and GPU precision as applicable. | Approved | T, I |

### 6.3 Performance and capacity

| ID | Requirement | Class | Verify |
| --- | --- | --- | --- |
| QR-PERF-001 | Pointer tracking, pan, zoom, camera movement, layer selection, and alpha interaction shall remain responsive under the intended interactive workload. | Core | A, D |
| QR-PERF-002 | Runtime caches, tile pools, prepared imagery, playback lookahead, in-flight backend tiles, and surface glyphs shall have explicit finite bounds. | Core | T, A |
| QR-PERF-003 | Viewer interaction shall avoid rebuilding immutable source samples or unaffected layer geometry. | Core | T, A |
| QR-PERF-004 | Backend serial and threaded TIFF output shall bound retained working memory according to configured policies. | Core | T, A |
| QR-PERF-005 | Performance reports shall distinguish active interaction from settled/final work and shall report timing, work counts, memory, and hardware/software context. | Core | A, I |
| QR-PERF-006 | Representative Windows validation shall cover primarily single-channel 100-150 MP imagery, 1080p and 4K displays, 512 versus 1024 display tiles, and one, two, and four visible layers. | Gated | A |
| QR-PERF-007 | The provisional display tile side shall remain 1024 until the target Windows evidence supports another default. | Core | A, I |
| QR-PERF-008 | GPU or CUDA recommendations shall be based on target-hardware measurements including transfer and synchronization cost, not kernel time alone. | Gated | A |

### 6.4 Reliability and recovery

| ID | Requirement | Class | Verify |
| --- | --- | --- | --- |
| QR-REL-001 | Repeating a deterministic request with identical inputs and seed shall reproduce the same accepted records and scientific outputs within declared numerical tolerance. | Core | T, A |
| QR-REL-002 | Preview, Apply, Revert, Solo, motion mode, cancellation, state load, and workbench close shall have explicit recoverable transitions. | Core | T |
| QR-REL-003 | Invalid, stale, incompatible, or partially available inputs shall not partially mutate authoritative scientific state. | Core | T |
| QR-REL-004 | A failed callback, output write, plugin operation, or optional accelerator shall not corrupt a previously valid scene or accepted result. | Approved | T |
| QR-REL-005 | Temporary files and incomplete products shall be cleaned up or identified after failure. | Core | T |
| QR-REL-006 | Atomic multi-image correction and registration application shall either complete for the full declared scope or leave the prior generation authoritative. | Approved | T |

### 6.5 Usability and explainability

| ID | Requirement | Class | Verify |
| --- | --- | --- | --- |
| QR-USE-001 | The main viewer shall remain visually quiet and shall place advanced workflows in contextual or floating workbenches. | Core | D, I |
| QR-USE-002 | The active pair, roles, eye assignment, pair enablement, sequence frame, correction state, solve gauge, and product generation shall be visible where relevant. | Approved | D |
| QR-USE-003 | Every disabled command, fallback, rejected solve, paused playback, disconnected network, and unavailable capability shall provide a concise reason. | Core | T, D |
| QR-USE-004 | Diagnostics shall use domain units and descriptions rather than requiring knowledge of private implementation fields. | Core | D, I |
| QR-USE-005 | Destructive or globally invalidating scientific changes shall require an explicit action and shall offer preview or rollback where defined. | Approved | T, D |

### 6.6 Compatibility, portability, and extensibility

| ID | Requirement | Class | Verify |
| --- | --- | --- | --- |
| QR-COMP-001 | Existing PlanarProjection and Projection-prefixed behavior shall remain covered by regression tests. | Core | T |
| QR-COMP-002 | Existing scene, viewer-state, backend-job, and alignment-result schemas shall retain their documented compatibility or fail with a version-specific explanation. | Core | T |
| QR-COMP-003 | New SDK request/result schemas shall be independently versioned, shall reject unsupported formats and versions without coercion, and shall provide round-trip, malformed-schema, and stale-version tests. | Approved | T |
| QR-COMP-004 | Basic headless scientific workflows shall not require desktop UI state. | Core | T |
| QR-COMP-005 | Optional GPU, file-backed source, plugin, DEM, and timing capabilities shall not make unrelated CPU/in-memory workflows unavailable. | Core | T |
| QR-COMP-006 | Third-party algorithms shall be replaceable through documented contracts rather than workbench-specific branching. | Approved | T, I |
| QR-COMP-007 | Public scientific data contracts shall be suitable for translation to C++ without depending on MATLAB graphics objects. | Approved | I |

### 6.7 Data protection and controlled extensibility

| ID | Requirement | Class | Verify |
| --- | --- | --- | --- |
| QR-SEC-001 | Private local fixture paths and parameter values shall remain ignored and shall not be copied into logs intended for commit. | Core | I |
| QR-SEC-002 | Serialized data shall not cause arbitrary class loading, path scanning, or code execution. | Approved | T, I |
| QR-SEC-003 | Plugin registries shall be supplied by trusted embedding code and shall validate declared identity and capabilities before execution. | Approved | T |
| QR-SEC-004 | Portable results shall omit graphics handles, live closures, reader objects, device buffers, and runtime caches. | Core | T, I |

## 7. Verification and acceptance requirements

### 7.1 Verification levels

| ID | Requirement | Class | Verify |
| --- | --- | --- | --- |
| VER-001 | Every feature pack shall add focused tests for its pure state, public interface, invalid inputs, failure recovery, and GUI behavior where applicable. | Core | T, I |
| VER-002 | Changed MATLAB files shall pass checkcode or shall document reviewed unavoidable diagnostics. | Core | I |
| VER-003 | A feature pack shall run every authoritative logical fresh-class repository test group before its acceptance; MATLAB MCP execution shall use a separate call per group. | Core | T |
| VER-004 | GUI requirements shall be tested through programmatic UI interaction where feasible and supplemented by a defined manual demonstration when visual behavior cannot be fully automated. | Core | T, D |
| VER-005 | Numerical algorithms shall be compared against analytic examples, deterministic synthetic truth, Monte Carlo, or an established double CPU oracle as appropriate. | Core | T, A |
| VER-006 | Performance claims shall include repeatable scripts, bounded artifacts, hardware/software context, and measured rather than assumed thresholds. | Core | A, I |
| VER-007 | Serialization shall be tested for version, round trip, omission of runtime state, malformed input, and stale/incompatible application. | Core | T |
| VER-008 | CPU/GPU, MATLAB/C++, and double/mixed comparisons shall include values, masks, source coordinates, corrections, covariance, error behavior, determinism, runtime, and memory as applicable. | Gated | T, A |

### 7.2 Acceptance evidence

| ID | Requirement | Class | Verify |
| --- | --- | --- | --- |
| ACC-001 | The committed automated suite shall pass with zero failures and zero incomplete tests on the acceptance baseline. | Core | T |
| ACC-002 | Alignment acceptance shall use the truth-aware synthetic fixture as the primary systematic dataset and shall keep truth out of the operational input path. | Core | T, A |
| ACC-003 | Multi-image alignment acceptance shall cover same-pass and multi-pass priors, nonsequential edges, cycles, corrupted matches, disconnected or weak graphs, and deterministic reruns. | Approved | T, A |
| ACC-004 | Dense acceptance shall measure correspondence state, source-coordinate accuracy, height/ray error, occlusion, completeness, and repeatability rather than judging only a displayed surface. | Approved | T, A |
| ACC-005 | Uncertainty acceptance shall compare predicted distributions with truth or Monte Carlo and shall evaluate calibration and coverage, not covariance shape alone. | Approved | A |
| ACC-006 | DEM registration acceptance shall preserve imagery-only truth, quantify transform recovery and sensitivity, and include urban/void/outlier cases. | Approved | T, A |
| ACC-007 | Air-gapped real-data observations shall be incorporated as isolated evidence updates with provenance and shall not silently redefine repository-wide thresholds. | Core | I |
| ACC-008 | Windows viewer and MATLAB-managed GPU claims shall remain explicitly unclaimed until target-hardware gates pass. | Core | I |

### 7.3 Current external acceptance gates

The following gates do not block unrelated CPU/MATLAB requirements:

1. Representative 100-150 MP Windows viewer testing at 1080p and 4K.
2. MATLAB-managed GPU and CPU-equivalence testing on a supported Windows NVIDIA
   system.
3. Required 100 km and stretch min(200 km, geometric horizon) precision tests.
4. Dense-matcher selection after truth-aware comparison.
5. Volumetric-fusion retention or abandonment after bounded truth studies.
6. Time-varying correction density and additional trajectory parameters after
   observability evidence.
7. Curved-orbit and independent-pass fixture details after their parameter
   space is approved.
8. C++ dependency, toolchain, CUDA, and production-output selection after
   parity, performance, license, and deployment review.

## 8. Requirements traceability

### 8.1 Requirement families to source documents

| Requirement family | Primary source |
| --- | --- |
| CON, DEP, DATA-STATE | project_status.md; viewer_development_plan.md |
| IF-MAT, FR-GEO, DATA-GEO | README.md; viewer_development_plan.md |
| FR-VIEW, QR-PERF | viewer_development_plan.md; performance_optimization_workplan.md |
| FR-PAIR, FR-ALIGN | alignment_workflow_hardening_plan.md |
| FR-PVIEW, FR-MOTION, FR-NET, FR-TVC | multi_image_surface_reconstruction_workplan.md, Tree A |
| FR-BE, IF-BE | viewer_development_plan.md; performance_optimization_workplan.md |
| FR-DENSE, FR-SURF, FR-SWB | dense_surface_feature_pack.md; multi_image_surface_reconstruction_workplan.md, Tree B |
| FR-UNC, FR-DEM | multi_image_surface_reconstruction_workplan.md, sections 11-13 and Tree B |
| FR-SDK-COR, FR-SDK-DM, FR-SDK-EXT | matlab_sdk_audit.md; multi_image_surface_reconstruction_workplan.md, Tree S |
| FR-SYN | dense_surface_synthetic_expansion_plan.md |
| FR-REF | multi_image_surface_reconstruction_workplan.md, Tree C |
| FR-CPP | multi_image_surface_reconstruction_workplan.md, Tree D |
| QR-PREC | multi_image_surface_reconstruction_workplan.md, Tree P |
| VER, ACC | all workplans and project_status.md |

### 8.2 Approved workplan tree to requirement families

| Workplan tree | SRS coverage |
| --- | --- |
| Tree A — Multi-Image Alignment and Viewer | DATA-ID, FR-PAIR, FR-PVIEW, FR-MOTION, FR-NET, FR-TVC |
| Tree B — Multi-View Dense Surface | FR-DENSE, FR-SURF, FR-SWB, FR-UNC, FR-DEM |
| Tree C — Mathematical and Procedural References | FR-REF |
| Tree S — MATLAB SDK | IF-SDK, FR-SDK-COR, FR-SDK-DM, FR-SDK-EXT |
| Tree D — C++ Production Backend | FR-CPP |
| Tree P — Precision and Numerical Integrity | QR-PREC |

Implementation status and ordered pack dependencies shall remain in
project_status.md and multi_image_surface_reconstruction_workplan.md rather than
being duplicated as requirement status in this SRS.

## 9. Deferred and excluded near-term scope

The following items are intentionally outside near-term acceptance, although
some have gated requirements above:

- production NITF and production GIS/point-cloud export formats;
- production mesh editing and GIS cartography;
- cloud and water classification without suitable development data;
- independent repeated-pass and curved-orbit simulation details not yet
  parameterized;
- time-varying OPK until dense support and observability are demonstrated;
- additional position, trajectory, gimbal, lever-arm, boresight, and timing
  correction blocks until separately evidenced;
- automatic Best dense-algorithm selection without truth-supported rules;
- automatic DEM-derived geometry mutation;
- custom CUDA kernels without target-hardware parity and benefit;
- authoritative C++ replacement before each corresponding MATLAB contract and
  golden fixture is frozen; and
- a change to legacy ray-versus-line semantics without an explicit
  compatibility decision.

## Appendix A. Glossary

| Term | Definition |
| --- | --- |
| Alignment working image | Bounded analysis-only image resampled onto a pair-specific grid with validity and full-source coordinate maps. |
| Backend | Graphics-independent renderer that applies validated scene/state and produces configured full-source-derived output. |
| CorrectionSet | Planned immutable, versioned network-level collection of correction blocks and lifecycle/provenance data. |
| Dense correspondence | A set of image observations covering many pixels or regions, with explicit source coordinates and match states. |
| DEM | Digital elevation model used as an uncertain reference, not a mandatory intersection surface. |
| Differential correction | Per-view correction relative to a pass-common component. |
| Effective correction | Total correction relative to immutable base geometry after exact composition. |
| Full source | Original caller-provided image radiometry at native sample locations. |
| GSD | Ground sample distance projected according to local viewing geometry. |
| HAE | Height above ellipsoid. |
| MSL | Mean-sea-level or orthometric height relative to a declared geoid. |
| OPK | Omega, phi, kappa attitude-angle convention whose order, frame, sign, and composition shall be explicit. |
| Pair | Two stable views selected for inspection, matching, stereo, or dense processing. |
| Pass | Views sharing a collection segment and potentially correlated errors. |
| Physical plane | World-space plane used by projection and output geometry. |
| Presentation state | Camera, visibility, blend, eye assignment, stereo, and motion display state that does not alter scientific geometry. |
| Source observation | Continuous [column,row] coordinate in a full source image. |
| Track | One inferred physical feature observed in two or more views, at most once per view. |
| View | One image and its associated possibly time-dependent source geometry. |

## Appendix B. Informative realization snapshot

At the date of this draft, the repository reports 618 of 618 grouped
fresh-class tests passing. Original viewer milestones, Backend Milestones 1-10, Auto Alignment
Milestones 1-13, Alignment Hardening and Reliability Packs, Viewer Performance
Packs 0-8, Backend Performance Packs 0-5, Dense Surface Pack 1, the
cross-system pass, dense-surface synthetic milestones, and multi-image
foundation MI-0 through MI-3, pair viewpoint, focus-aware keyboard controls,
manual and measured motion imagery, MATLAB SDK S1 and S2, and both A4
conflict-safe track/path-consistency and explainable quality pair-graph packs,
and A5 global constant-OPK network solving, A6 pass-aware priors/reporting, and
the multi-image synthetic acceptance matrix, P0/P1 precision validation, S3
dense matcher SDK/current-SGM adapter, B0 truth-aware SGM audit, and B1 dense
pair/sparse-seeded search planning, and B2 classical template matching are
complete. The SDK audit and logical
test-suite grouping refactor are complete.

This snapshot is informative and may become stale. project_status.md is the
authoritative implementation-status record.
