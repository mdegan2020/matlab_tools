# D0 Native C++ Requirements And Candidate Study

## Decision

D0 establishes a portable, dependency-free CPU reference and the reproducible
scaffolding needed for staged C++ parity. It does not select a production
linear-algebra, solver, image-processing, package-management, CUDA, or
deployment stack. MATLAB remains the acceptance oracle.

The platform-independent D0 foundation is complete on the current macOS arm64
host. Native Windows x64/MSVC, WSL 2/GCC, Windows MATLAB/MEX, NVIDIA CUDA, and
Ceres build evidence remain explicitly unclaimed because those environments
are unavailable here. That external gate does not block the independent D2 CPU
geometry/procedural parity work.

## Frozen boundary contract

| Boundary | D0 contract |
| --- | --- |
| Scalar | IEEE-754 binary64 for authoritative geometry |
| World/plane units | Meters |
| Angle units | Radians |
| World values | Explicit three-component column-vector semantics |
| Plane | Origin plus unit `basis_x`, unit `basis_y`, and unit normal; mutually orthogonal and right-handed with `cross(basis_x,basis_y)=normal` |
| Ray | `origin + range * direction`, with a finite unit direction in the project-world frame |
| Domain | Forward only; zero or negative range is `behind_origin` |
| Parallel policy | `abs(dot(normal,direction)) <= 1e-12` is `parallel` |
| Invalid policy | Invalid plane/nonfinite/nonunit data returns `invalid_input`; invalid numeric outputs are quiet NaNs |
| ABI | Plain C structs/enums/functions in `sightline/c_api.h`; no C++ containers or exceptions cross the boundary |

`native/fixtures/geometry_plane_intersections.csv` is the public cross-language
oracle for equations GEO-004/GEO-005. Its JSON manifest freezes frames, units,
precision, tolerances, statuses, and MATLAB exporter provenance. MATLAB verifies
the committed fixture against production `PlanarProjection`; independent C++
and C tests consume the same contract.

## Build and packaging foundation

The project requires CMake 3.25+ and C++17, treats Sightline warnings as errors,
provides opt-in address/undefined sanitizers, and installs headers, the static
library, and a versioned package exporting `Sightline::core`. Presets cover:

| Preset | Status |
| --- | --- |
| `macos-clang` | Configured, built, and tested locally with Apple Clang 21 and CMake 4.4.0 |
| `macos-clang-eigen` | Configured, built, and tested locally with hash-pinned Eigen 5.0.1 |
| `windows-msvc` / `windows-msvc-release` | Authored; target-host validation unclaimed |
| `wsl-gcc` | Authored; WSL validation unclaimed |

An out-of-tree install/consumer smoke configured with
`find_package(SightlineNative 0.1 CONFIG REQUIRED)`, linked
`Sightline::core`, built, and ran successfully on the current host. The
dependency-free preset passes its C++ fixture test and true-C ABI smoke test;
the Eigen preset additionally passes the Eigen parity probe.

## Dependency and licensing study

| Candidate | Evidence and current decision |
| --- | --- |
| CMake 4.4.0 | Official macOS universal archive was checksum-verified and used in isolation. The project minimum remains 3.25 for broader availability. |
| Eigen 5.0.1 / MPL-2.0 | Optional hash-pinned FetchContent probe builds and passes. It is a leading small fixed-size geometry candidate, not yet the production backend. Eigen emits one upstream CMake-policy deprecation warning under CMake 4.4; Sightline sources remain warnings-clean. |
| Ceres 2.2 / BSD-3-Clause primary | An explicit installed-package robust attitude-solve probe is present. It is not locally built because Ceres is not installed. Dense/sparse backend, autodiff/analytic, determinism, and scale measurements remain required. |
| BLAS/LAPACK | No provider selected. Measure only for sufficiently large dynamic dense operations and record implementation/license/runtime coupling. |
| SuiteSparse | Deferred. Ceres' possible SuiteSparse path carries component-specific GPL/LGPL/commercial considerations and cannot be enabled by default without review. |
| OpenCV 4.12.0 / Apache-2.0 | Optional/deferred for later image kernels. Algorithms must be wrapped behind coordinate/mask/precision/provenance contracts. SURF/nonfree remains excluded without explicit legal/deployment approval. |
| vcpkg versus Conan 2 | vcpkg leads the first Windows pilot because Ceres documents it and manifests support pinned baselines. Conan lockfiles remain viable for multi-configuration builds. No final manager is selected before Windows/WSL evidence. |

The default library has no third-party runtime dependency. `native/THIRD_PARTY.md`
is the durable redistribution checklist and candidate-version record.

## Non-gating benchmark evidence

On the Apple M4 Pro host, Release builds reported approximately 9.18 ns per
call for the safe Sightline wrapper and 2.31 ns per iteration for the Eigen
inner-algebra probe over one million iterations. These are smoke measurements,
not an implementation selection: the Sightline call validates the complete
plane and input contract on every iteration, while the Eigen probe times only
prevalidated inner algebra. They are intentionally not apples-to-apples and
carry no acceptance threshold.

Future profiling must separate validation, allocation, algebra, transfers,
kernel execution, synchronization, and I/O; record compiler/flags/hardware;
and compare equivalent contracts and output checksums.

## Remaining D0 target evidence and next stage

- Run the MSVC preset, tests, install consumer, warnings-as-errors, and relevant
  sanitizers/static analysis on native Windows x64.
- Run the GCC preset and equivalent tests under WSL 2 without loading its
  binaries into Windows MATLAB.
- Build and measure the Ceres 2.2 probe with reviewed transitive dependencies.
- Choose and lock a package manager only after Windows and WSL reproduction.
- Keep Windows MATLAB-managed GPU and D1/P3 CUDA/MEX claims unclaimed until the
  target NVIDIA system is available.
- Proceed independently with D2 CPU geometry and two-image procedural parity,
  adding MATLAB/native golden comparisons stage by stage.
