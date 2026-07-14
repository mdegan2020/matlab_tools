# Logical MATLAB Test Suite Groups

The repository test suite is divided into six authoritative logical groups so
each fresh-class MATLAB MCP call remains comfortably below the MCP 600-second
limit. `projectionTestGroups.m` is the executable manifest, and
`ProjectionTestGroupingTest` verifies that every `tests/*Test.m` file belongs
to exactly one group.

| Group | Scope | Current tests |
| --- | --- | ---: |
| `coreGeometryState` | Geometry, identities, state, metadata, caches, native golden-fixture parity, and non-UI controllers | 142 |
| `alignment` | Sparse matching/filtering, track and graph logic, global network solving, synthetic acceptance, correction SDK, A7 research, and atomic DEM position apply | 185 |
| `backendSurface` | Backend jobs/rendering, dense matchers/search/audit, pair covariance, procedural anaglyph parity, robust multi-ray, surface-fusion SDK/audit, DEM registration SDK/audit, Surface Workbench model, dense surface, synthetic truth, inverse warp, and raster paths | 237 |
| `viewerAlignmentUi` | Viewer alignment, active-pair, DEM-correction invalidation, and general app interaction | 71 |
| `viewerPresentationWorkflows` | Viewer motion, framing, harness, stereo, and Surface Workbench/3-D/DEM-preview workflows | 55 |
| `viewerPerformancePrecision` | Viewer performance evidence and long-range precision | 33 |

The validated July 14, 2026 baseline is 723/723 with zero failures and zero
incomplete tests.

The viewer suite is intentionally subdivided. A combined viewer/UI/
performance group exceeded 600 seconds after repeated UI execution, while the
same files passed when split by subsystem. The current UI groups contain 71
alignment/app UI tests and 55 motion/framing/stereo/Workbench workflow tests;
the performance/precision group contains 33 tests. No individual test timed
out; the observed failure mode was cumulative group/session behavior.

## MATLAB MCP Validation

Run every group in a separate MCP call. Each call begins from fresh graphics
and class state:

```matlab
close all force;
clear classes;
rehash;
results = runTestGroup("coreGeometryState");
```

Repeat that separate call for `alignment`, `backendSurface`,
`viewerAlignmentUi`, `viewerPresentationWorkflows`, and
`viewerPerformancePrecision`. Do not run
`runtests("tests")`, `runTests`, or
`buildtool test` as one MATLAB MCP call; the aggregate suite can exceed the MCP
timeout even when every test is healthy.

`runTestGroup` uses strict test execution, displays the result table, prints
the exact total/failure/incomplete counts, and calls `assertSuccess`. It runs
one test file at a time and writes the active group/file/state to
`sightline_workbench_test_progress.txt` under MATLAB's `tempdir`. If an MCP call
times out, inspect that file, then run the named test file method-by-method to
isolate a specific slow or hanging test.

## Local And Buildtool Entry Points

`runTests` and `buildtool test` remain aggregate local/CI conveniences. The
build tool also exposes one task per logical group:

```matlab
buildtool testCoreGeometryState
buildtool testAlignment
buildtool testBackendSurface
buildtool testViewerAlignmentUi
buildtool testViewerPresentationWorkflows
buildtool testViewerPerformancePrecision
```

When adding, renaming, or removing a test file, update
`projectionTestGroups.m` in the same change. The manifest-integrity test will
fail on missing or duplicate ownership.
