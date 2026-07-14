# Dense Matcher MATLAB SDK

Status: S3 complete. The graphics-independent base contract, request/result
schemas, common lifecycle, explicit registry, conformance fixture, current SGM
adapter, and B2 classical template matcher are implemented.

## Core Types

- `ProjectionDenseMatchRequest` validates stable pair/view identity, two
  bounded analysis images, masks, continuous full-source row/column maps,
  corrected geometry, overlap ROI, search prediction, precision policy,
  deterministic seed, and a graphics-independent runtime context.
- `ProjectionDenseMatchResult` validates continuous observations in both full
  source images, one primary state per observation, score, uncalibrated
  confidence, optional 2x2 pixels-squared covariance, diagnostics, timing,
  memory, execution, and provenance.
- `ProjectionDenseMatcher` is the abstract handle base. Its sealed `match`
  lifecycle owns request validation, metadata/options validation, cooperative
  cancellation, progress callbacks, algorithm-error classification, result
  normalization, timing, execution reporting, and deterministic provenance.
- `ProjectionDenseMatcherRegistry` stores only explicitly supplied matcher
  instances. It never scans paths or instantiates a class name from serialized
  data.
- `ProjectionDenseSgmMatcher` adapts the existing
  `ProjectionDenseSurfaceExtractor`. It builds requests from the current
  scene/pair-working/match contract and converts the legacy surface result into
  full-source observation arrays and explicit states without returning a
  surface as matcher output.

Requests and results reject `DisplayPyramid`, `PreviewCoordinates`, and
`Surface` substitution. Invalid observations may retain nonfinite coordinates
with an explicit failure state; observations marked `valid` must have finite
full-source coordinates.

## Implementing A Matcher

A subclass implements four methods:

```matlab
classdef MyDenseMatcher < ProjectionDenseMatcher
    methods
        function value = metadata(obj)
            % Return identity/version/capability/product/precision metadata.
        end

        function options = defaultOptions(obj)
        end

        function options = validateOptions(obj, options)
        end
    end

    methods (Access = protected)
        function result = matchImpl(obj, request, options, runtimeControl)
            % Return raw full-source observations; the base normalizes them.
        end
    end
end
```

Register instances explicitly:

```matlab
registry = ProjectionDenseMatcherRegistry();
registry.register(MyDenseMatcher());
matcher = registry.resolve("example.my-matcher");
result = matcher.match(request, options, runtimeControl);
```

The base class reports callbacks at `starting` and `completed`. Derived
implementations may inspect the validated cancellation hook during bounded
algorithm stages. They must not retain or mutate caller-owned arrays beyond the
documented call lifetime.

## Current SGM Bridge

```matlab
matcher = ProjectionDenseSgmMatcher();
request = ProjectionDenseSgmMatcher.requestFromLegacy( ...
    scene, pairWorking, pairMatch, struct(Seed=7, DisparityRange=[0 64]));
result = matcher.match(request, request.Context.ExtractorOptions);
```

The adapter reports CPU/GPU capability and fallback from the established
extractor, labels current invalid samples `geometrySearchFailure`, and keeps
confidence explicitly uncalibrated. The existing viewer surface workflow still
uses `ProjectionDenseSurfaceExtractor` as its compatibility orchestration
boundary; later dense work can consume the matcher result before triangulation
without changing this SDK schema.

## Conformance

`ProjectionDenseMatcherSdkTest` and its deliberately simple fixture matcher
exercise request/result validation, progress/provenance, cancellation,
algorithm-failure wrapping, forbidden surface output, explicit registry
behavior, SGM conversion, and the legacy request bridge. External subclasses
can follow the same headless test pattern without launching the viewer.

## Planned Learned-Matcher Evaluation

`docs/ufm_evaluation_workplan.md` defines the gated evaluation of UFM-Base as a
possible optional external matcher. No UFM adapter or dependency is currently
implemented. License/use approval, a pinned Python/CUDA environment,
standalone pair evidence, full-source mapping, and a controlled SGM/template
comparison must pass before any MATLAB adapter or Surface Workbench UI work.
