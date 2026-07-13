# Surface-Fusion SDK And Bounded Voxel Audit

Status: complete. S6/B4 provides a graphics-independent surface-fusion
extension boundary, three deterministic CPU built-ins, a minimal subclass
example, compact persistence, and a held-out bounded comparison against the B5
authoritative robust multi-ray point set.

## Contract and lifecycle

`ProjectionSurfaceFusionRequest.validate` accepts a versioned request containing
the complete `ProjectionMultiRayPointSet`, a finite world-frame ROI, explicit
voxel scales or a GSD/point-uncertainty scale derivation, a deterministic seed,
and an explicit precision policy. Truth, presentation state, graphics handles,
and progress/cancellation callbacks are forbidden in the portable request.
Runtime callbacks are supplied separately.

`ProjectionSurfaceFusionAlgorithm.fuse` is the sealed common lifecycle. It
owns request, metadata, option, and runtime validation; deterministic seed and
precision provenance; cooperative cancellation; progress publication;
algorithm-failure classification; CPU/GPU reporting; timing; result
normalization; and conformance checks. Subclasses implement metadata, defaults,
option validation, and the protected computation only.

`ProjectionSurfaceFusionResult` supports:

- fused points with stable identity, world coordinates, mode identity,
  contributing point/view/pass IDs, covariance, and explicit state;
- sparse multi-scale voxel evidence with allocated indices, world centers,
  evidence weights, contributor counts/IDs, and deterministic peaks;
- competing-mode, uncertainty, rejection, diagnostics, runtime, memory,
  precision, execution, and provenance summaries; and
- optional mesh/grid derived-product fields without making them authoritative.

`ProjectionSurfaceFusionResult.write` persists the complete result to MAT and
compact JSON metadata. The JSON intentionally summarizes points and scales and
omits full fused-point and sparse-voxel arrays.

Algorithms are caller-owned and registered explicitly through
`ProjectionSurfaceFusionRegistry`; there is no path scanning or dynamic class
construction. `ProjectionExampleSurfaceFusion` demonstrates a minimal external
per-mode centroid subclass and is labeled `exampleOnly`.

## Built-in algorithms

`ProjectionRobustMultiRayFusion` adapts the B5 point set without recomputing it.
It remains the `authoritativeReference` and retains the B5 world covariance.

`ProjectionHardVoxelFusion` builds a bounded sparse point-vote hash for every
requested scale and competing mode. Each input track contributes a weight based
on its independent pass count; `PairRecordCount` is never used.

`ProjectionGaussianSplatFusion` adds a normalized covariance-informed Gaussian
kernel to the bounded sparse hash. The kernel combines input point covariance
with an explicit voxel-scale floor and enforces grid-cell and contribution
limits before large allocations. Both voxel implementations emit derived peak
points with contributing point/view/pass identities and a documented voxel
quantization uncertainty assumption.

All geometry, final fused points, covariance, and refinement remain double.
The request may explicitly select single-precision evidence weights; focused
tests verify that boundary while final coordinates and covariance remain
double. The current implementations are deterministic CPU references and
report GPU support as unavailable rather than silently changing execution.

## Headless use

```matlab
request = struct( ...
    PointSet=multiRayPointSet, ...
    RoiWorld=[xmin xmax; ymin ymax; zmin zmax], ...
    GsdMeters=0.5, ...
    VoxelScaleMultipliers=[0.5 1 2], ...
    Seed=7);

registry = ProjectionSurfaceFusionRegistry({ ...
    ProjectionRobustMultiRayFusion(), ...
    ProjectionHardVoxelFusion(), ...
    ProjectionGaussianSplatFusion()});

algorithm = registry.resolve("sightline.fusion.gaussian-splat");
result = algorithm.fuse(request, algorithm.defaultOptions(), ...
    struct(ProgressFcn=@receiveProgress, CancellationFcn=@isCancelled));

ProjectionSurfaceFusionResult.write( ...
    result, "fusion-result.mat", "fusion-result.json");
```

Callbacks are runtime-only. A callback closure is not serialized into the
request, result, MAT payload, or JSON metadata.

## Bounded truth-aware evidence

`ProjectionSurfaceFusionTruthAudit.run` receives operational input and held-out
truth as separate arguments. It evaluates direct robust multi-ray points, hard
occupancy, and Gaussian splats at every derived scale. It reports accuracy,
completeness, vertical error, mode recall, one-sigma coverage, normalized error,
per-surface-type behavior, allocated sparse voxels, full-grid bounds, memory,
runtime, precision, and provenance. A second run changes only raw pair record
counts to prove that the voxel products depend on independent point/pass
evidence rather than pair multiplicity.

The public bounded roof/parapet fixture uses eight points, two competing urban
modes, three scales (`0.25`, `0.5`, and `1.0` meters), and a `0.5` meter
completeness tolerance. The July 13, 2026 evidence is:

| Product | Best scale | Accuracy RMSE | Completeness | Role |
| --- | ---: | ---: | ---: | --- |
| Robust multi-ray | n/a | 0.0935 m | 1.000 | authoritative reference |
| Hard voxel | 0.25 m | 0.2115 m | 1.000 | diagnostic derived |
| Gaussian splat | 0.25 m | 0.2081 m | 1.000 | diagnostic derived |

Both voxel variants preserve the roof/parapet modes and are exactly invariant
to inflated pair counts, but neither improves accuracy or completeness. The
recorded outcome is therefore `abandonAuthoritativePromotion`: robust
multi-ray remains authoritative and hard/Gaussian voxel evidence remains
available only for bounded diagnostic/research inspection. This explicitly
resolves the initial B4 retention gate without claiming that point-vote
occupancy is ray-likelihood occupancy, photoconsistency/space carving, or
signed-distance fusion.

An occupancy-concentration pose objective is not promoted or used by these
algorithms. It remains a future auxiliary research idea unless separate held-out
truth shows that it avoids false collapse, duplicate evidence, and smoothing.

## Conformance and verification

`ProjectionSurfaceFusionSdkTest` covers strict schemas, GSD/uncertainty scale
derivation, lifecycle/progress/cancellation/failure behavior, explicit
registration, the external-style example, authoritative adaptation, mode and
contributor preservation, normalized/deterministic bounded splats, pair-count
invariance, the single-evidence boundary, resource limits, malformed results,
and MAT/compact-JSON persistence.

`ProjectionSurfaceFusionTruthAuditTest` covers all three algorithms and every
scale, urban mode/surface metrics, independent-evidence invariance, the explicit
promotion/abandon decision, and strict held-out truth separation. The S6/B4
focused candidate passes 15/15 tests with zero failures or incomplete tests.
