# PlanarProjection

`PlanarProjection` is a small MATLAB geometry library for 2D/3D projection work, with an emphasis on plane-based stereo vision, positive-focal-plane camera projections, and future high-performance imagery workflows.

The library is implemented as a single static-method class:

```matlab
plane = PlanarProjection.definePlane(G0, V0, V1, R0);
[P, Q] = PlanarProjection.intersectPlane(Vn, G0, plane);
```

## Project Layout

```text
src/PlanarProjection.m          Static class library
src/ProjectionViewerHarness.m   Synthetic scene and source-geometry harness
src/ProjectionSourceGeometry.m  Sparse source-geometry grid adapter
src/ProjectionLayerManager.m    Multi-layer visibility and change-workflow helpers
src/ProjectionMeshBuilder.m     Pure sampled projection mesh builder
src/ProjectionReadbackRenderer.m Headless frame-camera readback prototype
src/ProjectionViewerApp.m       Programmatic interactive preview app
src/ProjectionViewerState.m     JSON-serializable viewer state and scene-apply helpers
src/ProjectionBackendJob.m      Backend job contract and serialization helpers
src/ProjectionBackendOutputGrid.m Backend full-extent output grid planner
src/ProjectionBackendProcessor.m Backend job invocation facade
tests/PlanarProjectionTest.m    Class-based unit tests
runProjectionViewerPrototype.m  Launcher for the local prototype TIFF
runTests.m                      Simple test runner
buildfile.m                     MATLAB buildtool tasks
```

## Naming And Shape Conventions

The API intentionally uses tight math-oriented names.

| Name | Meaning | Shape |
| --- | --- | --- |
| `P` | Point in the world/system frame | `3x1` |
| `Pn` | Collection of world/system points | `3xN` |
| `G` | View origin or optical center | `3x1` |
| `G0` | Special view origin or optical center | `3x1` |
| `V` | Vector in the world/system frame | `3x1` |
| `Vn` | Collection of vectors | `3xN` |
| `Q` | Plane-local 2D coordinates | `2xN` |
| `R` | Range or distance along a normalized direction | scalar or `1xN` |

All vectors and points are column-oriented. Collections are also column-oriented, so each point or vector occupies one column.

## Plane Convention

A plane is represented as a struct:

```matlab
plane.P0       % 3x1 plane origin
plane.basis    % 3x2 basis matrix [VX VY]
plane.VN       % 3x1 plane normal
```

The basis is right-handed:

```matlab
cross(plane.basis(:,1), plane.basis(:,2)) == plane.VN
```

Coordinate systems are right-handed. In the usual viewing convention, `+Z` points from the view position toward the plane, `+X` points right on the plane when viewed from the origin, and `+Y` completes the right-handed system.

## Camera Convention

Frame cameras are simple structs with a positive focal plane:

```matlab
camera.G0           % 3x1 optical center
camera.V0           % 3x1 unit optical axis, positive forward
camera.F            % positive scalar focal length
camera.focalPlane   % plane struct at G0 + F*V0
```

The focal plane `+X` direction is chosen by projecting a reference plane's `+X` onto the focal plane. This keeps camera readback aligned with the plane-based projection constructs.

## Current Public API

Plane construction:

```matlab
plane = PlanarProjection.definePlane(G0, V0, V1, R0);
plane = PlanarProjection.defineStereoPlane(G1, V1, R1, G2, V2, R2);
plane = PlanarProjection.defineFitPlane(G0, V0, P1, P2, P3, P4);
plane = PlanarProjection.definePlaneFromBasis(P0, VX, VY);
plane = PlanarProjection.definePlaneFromNormal(P0, VN, VXref);
```

Plane operations:

```matlab
[P, Q] = PlanarProjection.intersectPlane(Vn, G, plane);
P = PlanarProjection.reconstruct3d(Q, plane);
Q = PlanarProjection.worldToPlane(P, plane);
Q2 = PlanarProjection.mapPlaneToPlane(Q1, plane1, plane2);
```

Camera operations:

```matlab
camera = PlanarProjection.defineFrameCamera(G0, V0, F, referencePlane);
[Q, Pp] = PlanarProjection.projectToCamera(P, camera);
[Vn, Pp] = PlanarProjection.projectFromCamera(Q, camera);
[Qcamera, Pp] = PlanarProjection.projectPlaneToCamera(Qplane, plane, camera);
[Qplane, P] = PlanarProjection.projectCameraToPlane(Qcamera, camera, plane);
```

General geometry helpers:

```matlab
Vn = PlanarProjection.pointsToViewVectors(P, G);
VnUnit = PlanarProjection.normalizeVectors(Vn);
[P, residual, Pnear1, Pnear2] = PlanarProjection.triangulateRays(G1, V1, G2, V2);
tf = PlanarProjection.validatePlane(plane);
tf = PlanarProjection.validateCamera(camera);
```

## Error Policy

The first MATLAB implementation throws errors for invalid geometry instead of returning `NaN` or `Inf`. This includes zero-length vectors, malformed array sizes, degenerate plane definitions, rays parallel to planes, and camera points behind the optical center.

This is intentional for early development. A future CUDA-oriented path may choose `NaN`/`Inf` signaling for throughput-friendly kernels.

## Running Tests

From MATLAB:

```matlab
results = runTests;
```

With MATLAB buildtool:

```matlab
buildtool test
buildtool coverage
```

The tests use MATLAB's class-based `matlab.unittest` framework and exercise the public API with deterministic numeric examples.

## Projection Viewer Prototype

The interactive prototype is programmatic MATLAB app code, not an `.mlapp` file. From MATLAB:

```matlab
app = runProjectionViewerPrototype;
```

The default launcher expects the local ignored prototype image at `test_data/10.tif`.
To launch the prototype with two local dummy textures:

```matlab
app = runProjectionViewerPrototype(["test_data/10.tif", "test_data/102.tif"]);
```

The viewer supports one or more image layers. Each layer has independent source
geometry, alpha, visibility, blend mode, projection-plane offset, and omega/phi/
kappa view-vector correction state. Multi-layer previews share one projection
plane, with a small display-only depth bias so layers do not fight in the
renderer. The default selected layer is the topmost layer.

Core controls:

- Mouse wheel zooms the view.
- Shift + wheel adjusts Tip, Alt/Option + wheel adjusts Tilt, and Control +
  wheel adjusts Twist camera roll.
- Plain left-drag pans the camera.
- Control + left-drag translates the selected layer on the projection plane,
  using the same selected-layer projection offset as W/A/S/D.
- Control + right-drag adjusts omega and phi for the selected layer so the
  projected image tracks the mouse drag.
- W/A/S/D translates the selected layer up/left/down/right on the projection
  plane.
- I/K adjust phi, J/L adjust omega, and U/O adjust kappa. Omega and phi default
  to one estimated IFOV per key press; kappa defaults to 0.1 degrees.
- Save and Load write/read a human-readable JSON viewer state containing camera,
  layer, alpha, blend, projection offset, OPK, tip, tilt, and twist settings.

Projection scenes can choose how the initial projection plane is built:

```matlab
options = struct(ProjectionPlaneMode="fit");      % "current", "fit", or "stereo"
scene = ProjectionViewerHarness.createDefaultScene("test_data/10.tif", options);
app = ProjectionViewerApp(scene);
```

You can also pass an explicit plane, either while creating the scene or when
constructing the app from an existing scene:

```matlab
plane = PlanarProjection.defineFitPlane(G0, V0, P1, P2, P3, P4);
scene = ProjectionViewerHarness.createDefaultScene("test_data/10.tif", ...
    struct(ProjectionPlane=plane));
app = ProjectionViewerApp(scene, plane);
```

Sensor-specific geometry can be supplied through the `SampleFcn(rowIndices,
columnIndices)` contract. For sparse camera-model posts, use
`ProjectionSourceGeometry.fromGrid` to adapt uniformly spaced row/column geometry
posts into the same sampled-origin and sampled-view-vector interface used by the
mesh builder.
