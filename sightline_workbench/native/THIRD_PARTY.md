# Native Dependency Review

The default `sightline_core` target has no third-party runtime dependency. The
following versions are D0 candidates or build tools, not blanket approvals for
production deployment.

| Component | D0 version | License | Current disposition |
| --- | --- | --- | --- |
| CMake | 4.4.0 locally used; project minimum 3.25 | BSD-3-Clause | Build tool; locally validated on macOS. |
| Eigen | 5.0.1, SHA-256 `e9c326dc8c05cd1e044c71f30f1b2e34a6161a3b6ecf445d56b53ff1669e3dec` | MPL-2.0 | Optional, hash-pinned probe; locally built and tested. No production selection yet. |
| Ceres Solver | 2.2.x candidate API | BSD-3-Clause primary license; bundled dependency notices also apply | Optional installed-package probe authored but not built locally. Solver backend selection remains gated. |
| BLAS/LAPACK | Unselected | Implementation-specific | Benchmark only at problem scales where dynamic dense algebra dominates. |
| SuiteSparse | Unselected | Component-dependent; includes GPL/LGPL/commercial considerations | Disabled/deferred pending legal, deployment, and measured-solver review. |
| OpenCV | 4.12.0 candidate | Apache-2.0 | Optional/deferred. Any adopted algorithm must remain behind Sightline contracts; SURF/nonfree modules stay excluded absent explicit review. |

Do not infer approval of transitive dependencies from the primary package
license. A production lockfile, source inventory, notices bundle, export review,
and platform-specific binary audit are required before redistribution.

vcpkg currently leads the future native-Windows pilot because Ceres documents
that path and vcpkg manifests support baseline/version constraints. Conan 2
remains a viable multi-configuration alternative with lockfiles. Source CMake
presets remain authoritative until Windows and WSL evidence supports a final
package-manager decision.
