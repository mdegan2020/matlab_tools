# Sightline Native CPU Foundation

This directory is the D0 portable C/C++ foundation for staged MATLAB-to-native
parity work. It is not yet a replacement backend. The authoritative behavior
remains MATLAB, and every native stage must continue to use public golden
fixtures and explicit parity tolerances.

The current library provides:

- a warning-clean C++17 CPU reference for right-handed plane validation,
  plane reconstruction, and forward ray/plane intersection;
- a stable plain-C ABI suitable for later MEX and language bindings;
- public CSV/JSON fixtures generated and verified by MATLAB;
- independent C++ and plain-C tests;
- a non-gating CPU microbenchmark;
- an optional hash-pinned Eigen 5.0.1 parity/performance probe;
- an optional installed-Ceres 2.2 attitude-solve probe; and
- installable CMake package metadata exporting `Sightline::core`.

The scientific contract uses IEEE-754 binary64 geometry, meters for world and
plane coordinates, radians for angles, right-handed orthonormal plane bases,
unit world-frame ray directions, and forward-only intersections. Invalid
input, parallel rays, and intersections behind the origin are distinct status
values. Invalid results carry quiet NaNs instead of plausible coordinates.

## Configure, build, and test

Use CMake 3.25 or newer. The locally validated presets are:

```sh
cmake --preset macos-clang
cmake --build --preset macos-clang --parallel
ctest --preset macos-clang

cmake --preset macos-clang-eigen
cmake --build --preset macos-clang-eigen --parallel
ctest --preset macos-clang-eigen
```

Equivalent `windows-msvc`/`windows-msvc-release` and `wsl-gcc` presets are
provided, but remain unclaimed until run on those target systems. Build output
is ignored under `native/out/`.

To enable the Ceres candidate probe, make Ceres 2.2 discoverable to CMake and
configure with `-DSIGHTLINE_ENABLE_CERES_PROBE=ON`. This target is deliberately
not fetched automatically because its solver backend and transitive license
choices require deployment review.

The complete D0 evidence and dependency decision record is in
`docs/cpp_backend_d0.md`.
