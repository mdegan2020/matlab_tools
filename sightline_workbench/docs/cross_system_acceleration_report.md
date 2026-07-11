# Cross-System Acceleration Report

Status: complete on July 11, 2026.

## Scope and local environment

This pass reviewed viewer interaction, feature alignment, backend rendering,
and dense-surface extraction on MATLAB R2026a Update 2 for macOS with Parallel
Computing Toolbox, Computer Vision Toolbox, and the existing CPU reference
paths. The local system exposes no supported `gpuArray` device, so GPU speedup
claims remain an external Windows/NVIDIA validation gate.

## Decisions

- **Viewer:** retain the optimized main-thread graphics path. Camera scheduling,
  cached geometry, differential surfaces, and display budgets already address
  the measured bottlenecks. MATLAB graphics callbacks and handle mutation are
  not moved to workers.
- **Alignment:** retain CPU feature detection, extraction, matching, and solving.
  The installed detector APIs document GPU code generation but not direct
  `gpuArray` inputs. Pair-level parallel work is not introduced without a
  representative multi-image workload and bounded-memory evidence.
- **Backend:** retain the existing serial reference, optional thread-pool mode,
  and optional GPU compositing. Backend Performance Pack 2 subsequently made
  serial TIFF output genuinely bounded; Pack 3 subsequently added bounded
  `parfeval` submission and incremental `fetchNext` consumption.
- **Dense surface:** add optional capability-checked GPU execution for the SGM
  kernel. MathWorks documents full `gpuArray` support for `disparitySGM` in
  R2026a. Inputs move to the GPU only when `UseGPU=true` and a supported device
  is available; disparity is gathered immediately afterward and all mapping,
  validity, and ray triangulation remain on the tested CPU path.

## Implementation

`ProjectionGpuSupport` is the shared MATLAB-managed GPU capability boundary.
`ProjectionBackendGpuSupport` retains its compatibility API and delegates to
the shared probe. `ProjectionDenseSurfaceExtractor` adds `UseGPU=false` to its
validated options and records requested/effective GPU state, fallback reason,
and actual execution in result diagnostics.

The GPU-request test is portable: it executes the GPU path when available and
otherwise verifies clean CPU fallback, then compares the resulting disparity
and validity products with the explicit CPU reference. The local macOS run used
the fallback path and passed.

## External gate

Run dense SGM CPU/GPU numerical and timing comparisons on the target Windows
GPU workstation with representative working-image sizes and disparity spans.
Do not change the default from CPU or make a performance recommendation until
that matrix is recorded. GPU memory limits must remain explicit for large SGM
inputs.

Primary capability references:

- [MathWorks `disparitySGM` documentation](https://www.mathworks.com/help/vision/ref/disparitysgm.html)
- [MathWorks thread/process environment guidance](https://www.mathworks.com/help/parallel-computing/choose-between-thread-based-and-process-based-environments.html)
