# MATLAB Reference Implementation for NITF RSM Generation

Revision 1.0

This package is a concrete, toolbox-free MATLAB R2022b-or-newer reference implementation for building a
single-section pushbroom Replacement Sensor Model (RSM) from an elementary sensor model.
The required elementary operations are:

- `groundToImage(g)` where `g = [lat_deg, lon_deg, hae_m]` and the result is `[row, col]`.
- `imageToGround(u,h)` where `u = [row, col]` and `h` is HAE in metres.
- A 6-state camera-pose covariance ordered as
  `[lat_deg, lon_deg, hae_m, roll_rad, pitch_rad, heading_rad]`.

For covariance generation, a third adapter operation is required:

- `groundToImagePerturbed(g,dq)`, where `dq` is a pose perturbation in the same state order.

The perturbation operation is mathematically necessary. Projection and inverse projection at
the nominal state do not reveal the derivative of image coordinates with respect to camera pose.
When the callback is omitted, deterministic polynomial and grid RSM products still build, while
adjustable-parameter and covariance generation is disabled with a clear runtime error.

## Design constraints implemented

- Short internal variable names.
- No MATLAB package namespaces (`+folder` syntax is not used).
- Concrete classes only; no abstract classes or interfaces.
- Public input validation appears only in `arguments` blocks. Custom validators are invoked from
  those blocks. Algorithmic convergence and model-state failures use ordinary `error` calls.
- No Statistics, Optimization, Mapping, or Aerospace Toolbox dependency.

## Coordinate and attitude conventions

External ground coordinates are `g = [latitude, longitude, HAE]` with latitude and longitude in
degrees and HAE in metres. The internal RSM polynomial variables are
`x = [longitude, latitude, HAE]`, corresponding to RSM X/Y/Z.

The pose perturbation state is:

```
dq = [dlat_deg, dlon_deg, dhae_m, droll_rad, dpitch_rad, dheading_rad]
```

Roll is about the body x-axis, pitch about the body y-axis, and heading about the body z-axis.
The included `ToyPb` class uses right-handed intrinsic aerospace rotations. A production adapter
must apply the same convention used to form its covariance.

## Quick start

Run:

```matlab
addpath('rsm_matlab_reference_rev1_0');
run_demo
```

The principal integration pattern is:

```matlab
c = diag([vlat, vlon, vhae, vroll, vpitch, vheading]);
s = Sens(@(g) sm.groundToImage(g), ...
         @(u,h) sm.imageToGround(u,h), ...
         c, ...
         @(g,dq) sm.groundToImagePerturbed(g,dq));

cfg = RsmCfg(im=[nrow ncol], h=[hmin hmax], iid="IMAGE_001");
gen = RsmGen(s,cfg);
p = gen.build();
```

If the production model is mutable rather than explicitly perturbable, the fourth callback can
clone the model, apply `dq`, and call its normal `groundToImage` method.

## Main outputs

`RsmProd` contains:

- `ida`, `pia`, `pca`: identification and polynomial TRE semantic objects.
- `gia`, `gga`: grid identification and node-data semantic objects.
- `apa`, `apb`: physical and covariance-weighted reduced adjustable-parameter models.
- `eca`, `ecb`: indirect covariance semantic objects.
- `dca`, `dcb`: sampled and fitted direct covariance semantic objects.
- `poly`: executable rational polynomial model.
- `grid`: executable trilinear grid model.
- `adj`: executable reduced adjustable model.
- `dir`: executable direct covariance model.
- `rep`: numerical fit and conditioning report.

Every TRE object has a `fields()` method returning a struct keyed by TRE field names or by explicit
semantic field-group names. `tre_field_map.csv` gives source expressions and mapping notes.

## Polynomial model

The implementation uses the 20 RPC00B monomials and fixes each denominator constant to one. It
solves the standard linearized rational least-squares system with optional Huber IRLS. Coefficients
are transformed from RPC00B order to the isolated RSM order returned by `rsmexp`.

`rsmexp` is the only function that defines the RSM coefficient traversal. The included order is a
lexicographic i/j/k loop constrained to total degree three. Replace that function if the controlled
extension revision used by your program prescribes a different traversal.

## Grid model

`mkgrid` creates a regular 3-D ground grid, evaluates the elementary model at every node, tests
cell centres against trilinear interpolation, and refines all axes as `n <- 2*n-1` until tolerance or
node limits are reached. Replace `mkgrid` with an existing direct-RPC grid builder by returning an
`RsmGrid` object with the same properties. It can also be injected without editing the generator:

```matlab
cfg = RsmCfg(..., gf=@(s,d,cfg) myGridBuilder(s,d,cfg));
```

## Covariance model

1. `condcov` symmetrizes and eigen-clips the 6-state covariance.
2. `fdjac` forms central finite-difference image Jacobians with respect to pose.
3. `redbasis` whitens the source covariance and performs SVD on the stacked image response.
4. `fitadj` fits row/column displacement functions for physical and reduced parameters.
5. `mkdirect` propagates covariance to sampled 2-by-2 image covariances and fits direct component
   functions.
6. `mccov` independently checks the linear covariance by Monte Carlo perturbation.

The reduced parameter vector has identity covariance; `RsmAdj.m` stores the source-state mapping
`m`, so `dq = m*p`.

## TRE wire serialization

Exact byte widths, numeric formats, conditional branches, and loop traversal are controlled by the
specific STDI/NITF controlled-extension revision. `TreWriter` therefore accepts a caller-supplied
schema and never embeds guessed widths. Use `schema_example` as the schema shape, then replace it
with the program-authoritative field table.

The numerical generator and semantic TRE objects are complete enough to bind to either A or B
variant schemas. The following records have especially revision-dependent layouts and must be
bound against the authoritative profile before operational emission:

- `RSMGIA` / `RSMGGA`
- `RSMAPA` / `RSMAPB`
- `RSMDCA` / `RSMDCB`

## Tests

Run:

```matlab
addpath('rsm_matlab_reference_rev1_0');
addpath('rsm_matlab_reference_rev1_0/tests');
run_tests
```

The tests cover polynomial ordering, rational fitting, grid interpolation, covariance conditioning,
SVD basis reduction, TRE mappings, and an end-to-end build with `ToyPb`.

## Reference status

This is engineering reference code, not a certification artifact. Before operational use:

- bind every semantic object to the exact controlled-extension revision;
- verify all field widths, signs, blank rules, conditional loops, and repeated-record partitioning;
- run independent-reader interoperability tests;
- validate pixel-origin, latitude/longitude order, angle units, and pose perturbation convention;
- compare direct and indirect covariance against Monte Carlo truth over the complete domain.
