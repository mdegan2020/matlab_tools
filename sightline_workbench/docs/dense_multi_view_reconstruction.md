# Dense Multi-View Association And Reconstruction

Status: complete. B5 introduces `ProjectionDenseObservationAssociator` and
`ProjectionMultiRayReconstructor` as graphics-independent CPU contracts between
pairwise dense correspondence and later surface-fusion products.

## Pair records and association

`ProjectionDenseObservationAssociator.associate` consumes a versioned
`ProjectionDensePairObservationRecords` request. Every record retains stable
record/pair/view/pass/observation identity, both continuous full-source
observations, both corrected world rays, match state and score, texture,
navigation, radiometric and visibility evidence, provisional pair geometry,
optional pair covariance, and an optional mode hint. View-qualified
`ObservationKey` values prevent ambiguity when two views use the same local
observation label.

The associator derives forward ray parameters, separation, intersection angle,
and condition number for every pair. It rejects non-valid states,
forward-invalid or nearly parallel pairs, poor texture, weak navigation,
radiometric incompatibility, inconsistent visibility, conflicting stable
observation geometry, and lower-quality edges that would create two different
observations from one view in a track. Rejection state and reason stay on the
raw pair record.

Eligible edges are reconciled deterministically. Explicit mode IDs are kept
separate; a finite `ModeSeparationMeters` additionally clusters provisional
pair points before track reconciliation. This lets supported competing depth
or occlusion hypotheses remain separate labeled tracks instead of collapsing
into one point. The default infinite separation avoids inventing a physical
scale; callers enable automatic splitting with a justified scene scale.

## Robust multi-ray point set

`ProjectionMultiRayReconstructor.reconstruct` solves one point per associated
track by minimizing weighted perpendicular distance to its unique corrected
rays. Each stable observation contributes once regardless of repeated pair
records. Confidence and navigation quality weight a ray, and total base weight
is normalized equally across independent passes. Huber iteration precedes a
forward-parameter and residual gate; the final solve excludes inconsistent
rays and reports their residuals and reasons.

Every authoritative point records:

- contributing and rejected observations, views, passes, records, and pairs;
- full-source coordinates, corrected ray origins/vectors, forward parameters,
  residuals, base/robust weights, and rejection reasons;
- condition number and accepted-ray intersection-angle range;
- radiometric and visibility consistency;
- a symmetric world-frame covariance, status, reason, and principal axes; and
- the provisional pair-point median explicitly labeled as a non-authoritative
  initialization oracle.

Valid two-view tracks remain as `twoViewRetained`; tracks with three or more
accepted independent views are `multiViewSolved`. Pair record count is reported
separately from independent view/pass count. The current covariance is honestly
labeled `assumed`: it uses the larger of observed ray residual scale and the
configured metric floor with an independent-ray normal-matrix model. Retained
pairwise covariance remains provenance and is not recounted as independent
precision.

The returned `ProjectionMultiRayPointSet` is the authoritative
`robustMultiView` product. Raw pairwise records remain a distinct stage, and
voxel, mesh, and grid fields are empty derived-product placeholders. `write`
persists the complete value to MAT and compact image/ray-free summary metadata
to JSON.

## Verification

`ProjectionDenseMultiRayReconstructionTest` covers exact three-view solving,
corrupt-ray rejection, duplicate-pair independence, pass weighting, retained
two-view tracks, competing-mode splitting, quality/forward/visibility gates,
stable-observation and duplicate-view conflicts, deterministic identity,
explicit covariance, MAT/JSON persistence, and strict schema rejection. The B5
candidate passes all 13 focused tests and the six grouped fresh-class suites,
638/638 total with zero failures or incomplete tests.
