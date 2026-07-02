# Backend Milestone 9: Custom GPU Kernel Assessment

## Decision

Custom GPU kernels are not enabled in this prototype milestone.

The backend now has these reference execution paths:

- CPU readback via `ProjectionReadbackRenderer.renderScene`.
- Serial tiled CPU readback via `ProjectionBackendTiledRenderer`.
- Thread-pool tile execution using only `parpool("threads")`.
- Optional MATLAB-managed `gpuArray` compositing with clean CPU fallback.

No representative profile currently shows a backend bottleneck that remains
after tiled CPU rendering, thread-pool execution, and MATLAB-managed GPU
compositing. Without that evidence, a custom kernel would add maintenance risk
before proving that it solves the right problem.

## Candidate Kernel If Future Profiling Justifies It

Candidate name:

```text
tileProjectionInterpolationKernel
```

Target bottleneck:

```text
Per-output-pixel projection and interpolation inside tiled readback.
```

Inputs:

- tile output grid coordinates.
- projection plane geometry.
- sampled source image bands.
- sampled source mesh plane coordinates.

Outputs:

- tile image bands.
- tile valid mask.

Correctness references:

- CPU readback renderer.
- MATLAB-managed `gpuArray` compositing path.

## Required Evidence Before Implementation

Before adding a custom kernel, collect:

- representative serial tiled CPU timing.
- representative `parpool("threads")` timing.
- representative MATLAB-managed GPU timing on a GPU-capable workstation.
- a profile showing that projection/interpolation, not file writing or scene
  setup, dominates runtime after the existing acceleration paths.

The CPU implementation must remain the reference path for correctness, and any
custom kernel must add numerical equivalence tests against CPU and
MATLAB-managed GPU outputs.
