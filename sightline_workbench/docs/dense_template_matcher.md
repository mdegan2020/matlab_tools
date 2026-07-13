# B2 Classical Dense Template Matcher

Status: complete. `ProjectionDenseTemplateMatcher` is a CPU-complete,
deterministic `ProjectionDenseMatcher` implementation for bounded local-strip
search with continuous full-source observations.

The matcher consumes optional B1 regional predictions and otherwise uses an
explicit bounded disparity range. It evaluates every retained working-grid
sample with a multi-scale patch score and deterministic candidate ordering.
Supported score families are zero-mean normalized cross correlation, gradient
correlation, census/rank similarity, and phase-only correlation.

Quality evidence includes best and second score, uniqueness margin,
deterministic tie count, texture standard deviation, forward/backward
consistency, local prediction residual, candidate count, subpixel parabolic
refinement, and uncalibrated composite confidence. Results use the shared state
vocabulary for valid, masked, outside-overlap, insufficient-texture,
ambiguous/repetitive, occluded, no-match, and geometry/search failure.

The implementation is graphics-independent, cancellation-aware, bounded by
sample stride and maximum observations, and maps fractional working
coordinates through the request's continuous full-source row/column maps. It
reports CPU execution; no unsupported GPU claim or automatic `Best` selection
is made.

```matlab
matcher = ProjectionDenseTemplateMatcher();
options = matcher.defaultOptions();
options.CostMethod = "censusRank";
options.PyramidScales = [0.5 1];
result = matcher.match(request, options);
```

`ProjectionDenseTemplateMatcherTest` verifies all four cost families, known
integer and subpixel translations, continuous source mapping, quality
diagnostics, low texture, mask/overlap states, regional no-support behavior,
vertical inconsistency/occlusion, provenance, repeatability, and cancellation.
