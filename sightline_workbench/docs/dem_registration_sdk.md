# DEM Ingestion And Registration SDK

S7/B7 adds a graphics-independent path from uncertain WGS84 elevation data to
a reviewable global-translation proposal. Registration never mutates the B5
imagery-only point set, never snaps individual reconstructed points to the DEM,
and never treats the registered preview as independent validation evidence.
B8 adds the separate explicit, atomic position-application path described
below; S7 registration itself remains preview-only.

## DEM value and datum policy

`ProjectionDemGrid.create` accepts a latitude/longitude grid or compatible
latitude/longitude axes with heights. `DatasetKind` is `WGS84Grid` or `DTED2`.
The caller must identify generic-grid heights as `HAE` or `MSL`; MSL is
converted with EGM96. An omitted DTED2 height reference is accepted only by
recording `omittedDtedReferenceAssumedMslEgm96`.

Validity combines finite latitude, longitude, and height values with an
optional no-data sentinel and optional validity mask. A separate exclusion
mask removes known buildings, vegetation, water, changed terrain, or other
operator-defined cells from registration while preserving the base DEM.

Accuracy precedence is:

1. caller-supplied CE90/LE90;
2. dataset CE90/LE90 metadata; then
3. documented DTED2 defaults of 23 m CE90 and 18 m LE90.

Generic grids without uncertainty may be ingested but cannot enter a
registration request. The original 90-percent metrics are retained. The
working Gaussian approximation is

```text
horizontal sigma = CE90 / sqrt(-2 log(0.1))
vertical sigma   = LE90 / 1.64485362695147
```

Dataset accuracy is explicitly modeled as shared across cells, not as
independent per-cell evidence. Registration covariance therefore retains a
shared DEM-accuracy floor instead of shrinking it with support count.

All scientific coordinates are double precision. Ingestion normalizes to
scene-local ENU and HAE while retaining reversible WGS84, ECEF, and
project-world transforms. `worldToEnu`, `enuToWorld`, `worldToGeodetic`, and
`geodeticToWorld` expose these transformations. Project-world origin and ENU
rotation are explicit; HAE and MSL are never mixed silently.

## Headless registration

`ProjectionSurfaceRegistrationRequest` binds one B5 multi-ray point set to one
normalized DEM in the same world frame. It carries ROI and point exclusions,
robust-solve limits, conditioning and slope controls, mask-sensitivity policy,
deterministic seed, and explicit `globalTranslation`/double-precision scope.
Truth values, expected translations, callbacks, graphics handles, and runtime
state are rejected from the portable request. Progress and cooperative
cancellation callbacks are passed separately as runtime control.

The direct entry point is:

```matlab
dem = ProjectionDemGrid.create(demInput);
request = ProjectionSurfaceRegistrationRequest.validate(struct( ...
    PointSet=multiRayPointSet, Dem=dem));
result = ProjectionSurfaceRegistrationService.run(request);
```

`ProjectionRobustDemTranslation` is the default CPU adapter. For point `p_i`,
translation `t`, local DEM point `s_i`, and local surface normal `n_i`, it
minimizes robust point-to-normal residuals

```text
r_i = n_i' * (p_i + t - s_i).
```

Iterative weights include projected reconstructed-point covariance, DEM
horizontal and vertical uncertainty, slope, point conditioning, and a Huber
factor. ROI, point masks, DEM exclusions/voids, invalid covariance, and
ill-conditioned points retain explicit rejection reasons. A second solve that
ignores the DEM exclusion mask reports mask sensitivity. Nonconvergence,
weak normal diversity, excessive condition number, or material mask
sensitivity produces a reviewable `ambiguous` status. Insufficient support or
rank produces `degenerate` with an invalid failure classification.

The result reports translation direction/frame in ENU and project-world,
translation covariance with shared DEM floor, support and coverage,
rejections, initial/final residual distributions, mask sensitivity, datum and
geoid assumptions, ambiguity/gauge evidence, precision, execution, timing,
memory, and deterministic provenance. MAT output preserves the complete
result; compact JSON contains portable summary metadata.

## Extension contract

Custom algorithms derive from `ProjectionSurfaceRegistrationAlgorithm` and
implement `metadata`, `defaultOptions`, `validateOptions`, and protected
`registerImpl`. The sealed lifecycle validates request/options/runtime control,
checks cancellation, publishes progress, classifies algorithm failures, and
normalizes result execution and provenance. Algorithms are supplied as trusted
instances through `ProjectionSurfaceRegistrationRegistry`; the SDK performs no
path scanning or dynamic class-name construction.

`ProjectionExampleSurfaceRegistration` is the minimal external-style adapter.
It delegates the trusted robust implementation while demonstrating independent
identity and provenance. `ProjectionSurfaceRegistrationTestAlgorithm` and the
SDK tests exercise subclass conformance, registry behavior, cancellation,
progress, failure isolation, and strict portable schemas.

## Preview, correction, and Workbench products

A successful or ambiguous result contains the complete original and translated
point matrices, stable point IDs, accepted mask, and point-to-DEM differences.
It also carries one immutable `ProjectionCorrectionSet` in `proposed`
lifecycle with a typed `globalPositionTranslation` block. Diagnostics state
`AutoApply=false` and `RequiresExplicitB8Apply=true`; the S7 service cannot
apply it.

## Explicit B8 position application

`ProjectionDemCorrectionAdapter.bind` is the mandatory boundary between an S7
point-set proposal and live source geometry. Binding requires the current
scene generation, verifies successful registration (or a separate explicit
`AllowAmbiguous=true` override), matches the declared view/pass scope, and
checks the DEM correction frame against the scoped source-coordinate frame.
It rejects rotation, per-pass, trajectory, or any block other than one global
translation plus its covariance.

The binder translates a scene copy using
`ProjectionSourceGeometry.translateOrigins`, recomputes every parent and
corrected geometry fingerprint, and returns a new `proposed` CorrectionSet
whose typed translation semantics are
`imageryToDemExplicitPositionCorrection`. Function-backed `SampleFcn` and
`SampleRayFcn` values are wrapped so sampled origins move by the same world
translation while ray directions remain unchanged. Compatible explicit sensor
origin aliases and revision tokens are updated together; geometry without a
verifiable revision or compatible origin contract fails closed.

Headless application uses the existing S2 lifecycle and remains deliberately
multi-step:

```matlab
bound = ProjectionDemCorrectionAdapter.bind(scene, registrationResult, ...
    struct(ParentGenerationId=store.currentGenerationId()));
store.propose(bound);
store.accept(bound.GenerationId);       % explicit operator/application policy
[scene, applied, effects] = store.apply(bound.GenerationId);
```

`ProjectionCorrectionStore` applies the position block to a scene copy,
verifies every corrected fingerprint, and publishes only after all scoped
views succeed. Revert restores the exact stored parent scene rather than
negating the translation. Apply and revert return a portable effect record
that invalidates raw/filtered matches, alignment solves, dense observations,
multi-ray points, fusion/surface products, and DEM registration. It requires
alignment, dense reconstruction, fusion, and registration to be rerun; a
registered preview is never reused as independent validation.

`ProjectionViewerApp.proposeDemCorrection` exposes the same binding without
accepting or applying automatically. Its ordinary `acceptCorrection`,
`applyCorrection`, and `revertCorrection` methods retain the S2 history. On a
DEM position apply or revert, the viewer clears alignment evidence and solve
state, closes dense products, records explicit invalidation diagnostics,
refreshes every source-geometry-dependent layer, and requires recomputation.

`ProjectionSurfaceProductCatalog.registrationProducts` adapts the DEM grid,
registered point preview, and DEM-difference point product for the B6 Surface
Workbench. Registered covariance includes the estimated translation
covariance, full-source observation links remain attached, and the original
robust multi-view product remains separately available and unchanged.

## Validation evidence

The focused S7 suite contains 23 tests: seven DEM-ingestion tests, ten SDK and
robust-solve tests, four held-out truth-audit tests, and two Workbench/viewer
workflow tests. The clean deterministic fixture recovers the held-out
`[1.2, -0.8, 2.0]` m ENU translation to better than 1 mm. The masked
urban/void/outlier fixture remains below 0.2 m translation error, preserves
rejection and sensitivity evidence, and reduces residual RMS. Deterministic
Monte Carlo includes independent point noise plus one shared DEM error draw;
the automated gate requires at least 0.8 empirical coverage at the nominal
three-dimensional 90-percent covariance threshold.

B8 adds eight headless atomicity/frame/scope/origin/invalidation tests and one
viewer lifecycle test. They cover preview/accept/apply separation, an explicit
ambiguity override, sampled and explicit origin translation, unchanged ray
directions, unsupported source failure, corrected-fingerprint rollback, exact
revert, dependency clearing, and mandatory recomputation.

The authoritative repository validation runs the six logical groups in
separate fresh-class MATLAB MCP calls as documented in
`test_suite_grouping.md`.
