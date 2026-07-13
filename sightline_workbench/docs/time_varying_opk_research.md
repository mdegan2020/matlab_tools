# A7 Time-Varying OPK Research

A7 implements a bounded, graphics-independent observability study for smooth
within-image attitude correction. It does not authorize production application.
The durable decision is `retainResearchOnly` until physical dense-network data
demonstrate local observability, stability, and useful held-out improvement.

## Model

`ProjectionTimeVaryingOpkResearch.analyze` accepts portable, truth-free
linearized observations. Each view record supplies stable `ViewId`/`PassId`,
the full-source image width and columns, an `N`-by-3 local rotation Jacobian,
residuals, positive weights, and an explicit sparse/dense/mixed evidence label.
Runtime handles, callbacks, embedded truth, inconsistent shapes, nonfinite
values, and out-of-image columns are rejected.

The attitude increment is represented by a small rotation vector in the local
attitude tangent space. It is applied mathematically as

```text
R_effective(c) = Exp([delta_theta(c)]_x) R_nominal
delta_theta_v(c) = delta_theta_pass(v) + B_v(c) q_v
```

where `B_v` is an open-uniform cubic B-spline evaluated in full-source image
columns. Nominal post spacing is 128 pixels. Per-view second differences provide
the smoothness prior, and a prior-weighted zero-mean differential gauge
separates each pass-common term from its per-image terms. The model never
interpolates omega/phi/kappa Euler angles.

The solver reports data-only rank, the rank required after accounting for the
pass/differential gauge, condition number, minimum local control support,
prior-augmented rank, prior dominance, covariance availability, residuals,
selected post spacing, pass-common terms, and per-view control vectors. When
support, rank, or condition is inadequate, post spacing doubles up to the
configured bound. A one-column spacing mode exists only as
`perColumnAnalysis`; its result is always labeled `analysisUpperBound`. A
configurable parameter-count limit (2000 by default) rejects oversized studies
before allocating the design matrix or covariance.

## Held-Out Audit

`ProjectionTimeVaryingOpkTruthAudit` keeps truth outside the operational
request. Its deterministic study covers:

- a dense four-view/two-pass case at the nominal 128-column spacing;
- held-out image columns not used by the fit;
- sparse support that forces repeated coarsening and remains explicitly
  insufficient; and
- a bounded per-column parameter-density experiment.

The July 13, 2026 focused audit selected 128 pixels for the dense case and
reported a maximum held-out tangent-rotation error of `2.34e-14` radians. The
sparse case coarsened to the configured 2048-pixel maximum and remained
`insufficientLocalObservability`. These synthetic results verify algebra,
support accounting, and truth separation; they are not evidence that physical
time-varying attitude is observable.

## Correction SDK Boundary

`toCorrectionSet` packages pass-common rotation vectors and per-view spline
controls as typed, radian-valued, local-tangent `CorrectionSet` blocks with
generation, geometry fingerprint, covariance-status, provenance, and explicit
research diagnostics. Parent and corrected fingerprints remain equal because
this pack does not define a production source-geometry application model.

Research sets may enter proposal and acceptance for inspection. Their
`Diagnostics.ApplicationSupported` flag is false, and
`ProjectionCorrectionStore.apply` rejects them with
`ProjectionCorrectionStore:unsupportedApplication` before geometry validation
or mutation. They are never auto-applied.

## Promotion Gate

Production promotion remains gated on physical dense observations that retain
local rank and conditioning under held-out validation, improve an accepted
constant-attitude baseline, remain stable under support/spacing perturbation,
and justify an explicit source-geometry application and invalidation contract.
Until those conditions are met, the constant global alignment remains
authoritative and the A7 implementation is analysis-only.
