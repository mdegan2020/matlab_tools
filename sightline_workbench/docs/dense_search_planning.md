# B1 Dense Pair And Search Planning

Status: complete. Dense reconstruction now has an independent pair scheduler
and a regional sparse-seeded search-prior contract. Neither component invokes a
matcher or forms a surface.

## Dense Pair Scheduling

`ProjectionDensePairScheduler` consumes explicit per-pair evidence for overlap,
conditioning, texture, radiometric compatibility, visibility, predicted cost,
and predicted memory. It returns stable pair/view identity, normalized quality
scores, selected/rejected/validation decisions, and one explanation per
candidate.

The scheduler is independent of `ProjectionAlignmentScheduler` and records
`SparseScheduleConsumed=false`. It supports a maximum pair budget, `All
plausible pairs`, forced inclusion/exclusion, and an optional explicitly named
validation view. With four or more views it reserves a stable held-out view
where operator-forced edges permit one, and reports why reservation is
unavailable otherwise.

## Sparse-Seeded Regional Search

`ProjectionDenseSearchPredictor` accepts validated dense matcher input plus
accepted sparse working-coordinate observations. It partitions the bounded
analysis image into deterministic regions and records:

- moving-minus-reference disparity vector and epipolar direction;
- horizontal and vertical search ranges;
- optional depth range;
- seed/residual uncertainty and configured padding;
- stable supporting track IDs; and
- one state: `seeded`, `unseeded`, or `noSupport`.

Supported sparse seeds constrain search ranges but never force dense points to
their depth. Unsupported regions either receive an explicitly widened global
unseeded prior or remain `noSupport`, according to policy. Empty evidence never
invents a prior. Every prediction records `ForcesSurface=false`,
`TruthUsed=false`, and the working/full-source coordinate convention. `attach`
returns a revalidated `ProjectionDenseMatchRequest` carrying the prediction.

## Example

```matlab
schedule = ProjectionDensePairScheduler.build(scene, pairEvidence, struct( ...
    MaximumPairs=4, ReserveValidationView=true));

prediction = ProjectionDenseSearchPredictor.build(request, sparseEvidence, ...
    struct(RegionSize=[64 64], AllowUnseededSearch=true));
request = ProjectionDenseSearchPredictor.attach(request, sparseEvidence);
```

`ProjectionDenseSearchPlanningTest` verifies provenance, supported/unsupported
regions, widened uncertainty, empty evidence, request attachment, independent
quality scheduling, all-plausible mode, operator overrides, validation-view
reservation, determinism, cost/memory, and rejection explanations.
