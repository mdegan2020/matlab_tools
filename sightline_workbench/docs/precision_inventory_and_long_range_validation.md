# Precision Inventory And Long-Range Viewer Validation

Status: P0 and P1 complete. P2 scientific mixed-precision selection and P3
target-hardware CUDA precision remain later ordered work.

## P0 Current Precision Inventory

`ProjectionPrecisionInventory.inspect()` is the executable inventory. It
classifies 16 boundaries spanning source radiometry, authoritative geometry,
display-derived arrays, backend geometry/radiometry, alignment observations,
solver state, covariance, dense intermediates, surface points, synthetic truth,
optional GPU data, and future fusion data.

The current policy evidenced by source inspection and runtime probes is:

- source radiometry preserves its caller type;
- source origins/rays, planes/cameras, render origins, world meshes, backend
  output grids/maps, alignment observations, OPK solver state/Jacobians,
  corrections/covariance, dense rays/surface points, and synthetic truth use
  double;
- display textures preserve natural imagery or use normalized single and remain
  discardable presentation data;
- backend tile radiometry is explicitly configurable as double or single while
  backend geometry remains double;
- SGM rectified intensity and disparity are single intermediates, followed by
  double observation resampling and triangulation;
- optional GPU dense intermediates may be single `gpuArray` values and are
  gathered before authoritative double geometry; and
- voxel/fusion precision is not selected before the P2/fusion contracts exist.

No scientific mixed-precision boundary was adopted by P0.

## P1 Long-Range Matrix

`ProjectionViewerPrecisionValidation.run()` uses an unrefracted spherical
horizon based on the WGS84 semimajor axis. The default observer HAE is 4,000 m,
giving a geometric horizon of 225,922.766 m. The matrix covers 1 km, 25 km, the
required 100 km range, and the 200 km stretch range in both local coordinates
and a large translated world frame.

The double viewer reference is compared with two single-precision boundaries:

1. **Safe candidate:** subtract the double render origin, then cast the
   discardable camera-relative/display vertices to single.
2. **Unsafe comparison:** cast large absolute world points and the render
   origin to single before subtraction.

At two screen pixels per meter, the safe path produced a maximum world error of
`2.003e-5 m` and a maximum screen error of `4.005e-5 pixel`. All values remained
finite and stereo eye ordering was preserved. This is well within the
provisional 0.1-pixel display gate.

The unsafe path produced up to `0.393 m` world error and `0.786 pixel` screen
error in the translated frame. It also collapsed the signed 0.02 m stereo
baseline in all four translated-range cases. This comparison demonstrates that
single precision is acceptable only after the authoritative double local-origin
shift; it is not acceptable for large absolute geometry.

At 1,000 m HAE, the same fixture verifies that the stretch range is limited to
the 112.9 km geometric horizon while still covering the required 100 km.
Altitudes whose horizon cannot reach 100 km fail explicitly.

## Decision

Authoritative viewer/world geometry remains double. A future performance change
may cast discardable viewer-relative vertices to single only after double
render-origin subtraction and must preserve the P1 gate. No backend, solver,
covariance, triangulation, fusion, or truth precision is changed by P0/P1.
