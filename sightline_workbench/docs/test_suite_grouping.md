# Logical MATLAB Test Suite Groups

The repository test suite is divided into four authoritative logical groups so
each fresh-class MATLAB MCP call remains comfortably below the MCP 600-second
limit. `projectionTestGroups.m` is the executable manifest, and
`ProjectionTestGroupingTest` verifies that every `tests/*Test.m` file belongs
to exactly one group.

| Group | Scope | Current tests |
| --- | --- | ---: |
| `coreGeometryState` | Geometry, identities, state, metadata, caches, and non-UI controllers | 136 |
| `alignment` | Sparse matching/filtering, track and graph logic, global network solving, synthetic acceptance, and correction SDK | 165 |
| `backendSurface` | Backend jobs/rendering, dense surface, synthetic truth, inverse warp, and raster paths | 132 |
| `viewerUiPerformance` | Viewer workflows, UI interaction, motion playback, framing, stereo, and performance | 144 |

The validated July 12, 2026 baseline is 577/577 with zero failures and zero
incomplete tests.

## MATLAB MCP Validation

Run every group in a separate MCP call. Each call begins from fresh graphics
and class state:

```matlab
close all force;
clear classes;
rehash;
results = runTestGroup("coreGeometryState");
```

Repeat that separate call for `alignment`, `backendSurface`, and
`viewerUiPerformance`. Do not run `runtests("tests")`, `runTests`, or
`buildtool test` as one MATLAB MCP call; the aggregate suite can exceed the MCP
timeout even when every test is healthy.

`runTestGroup` uses strict test execution, displays the result table, prints
the exact total/failure/incomplete counts, and calls `assertSuccess`.

## Local And Buildtool Entry Points

`runTests` and `buildtool test` remain aggregate local/CI conveniences. The
build tool also exposes one task per logical group:

```matlab
buildtool testCoreGeometryState
buildtool testAlignment
buildtool testBackendSurface
buildtool testViewerUiPerformance
```

When adding, renaming, or removing a test file, update
`projectionTestGroups.m` in the same change. The manifest-integrity test will
fail on missing or duplicate ownership.
