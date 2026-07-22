# Algorithm and Output Map

## 1. Adapt the elementary sensor

`Sens` fixes the external conventions and stores the source covariance. The nominal callbacks
produce image/ground coordinates. The perturbation callback applies a camera pose delta before
projection. The source state is ordered:

```
[dlat_deg dlon_deg dhae_m droll_rad dpitch_rad dheading_rad]
```

Output: a uniform sensor adapter used by all subsequent algorithms.

## 2. Build the common domain (`mkdom`)

1. Form the four zero-based image-corner coordinates.
2. Project each corner at minimum and maximum HAE.
3. Use the resulting eight points as the RSM ground-domain vertices.
4. Compute latitude, longitude, and height bounds.
5. Compute the reference image coordinate and its mid-height ground intercept.
6. Build shared image and ground offsets/scales.

Outputs: `RsmDom`, then `RsmIda`, `RsmPia`, `RsmPca`, `RsmGia`, `RsmDcb` fields.

## 3. Generate fitting samples (`mksamp`)

1. Create a tensor grid in row, column, and HAE.
2. Call `imageToGround` so every retained sample belongs to the sensor domain.
3. Return paired ground/image samples.

Outputs: rational fit observations, withheld tests, sensitivity locations, and covariance samples.

## 4. Fit the rational polynomial (`RsmPoly.fit`, `fitrat`)

For row and column independently:

1. Normalize ground and image coordinates with `RsmDom`.
2. Evaluate the 20 RPC00B monomials.
3. Fix the denominator constant to one.
4. Solve `[T, -y*T(:,2:end)]*[n;d(2:end)] = y` by regularized least squares.
5. Reweight residuals with a Huber rule and repeat.
6. Transform each coefficient vector from RPC00B order to `rsmexp` order.
7. Evaluate RMS, maximum error, and minimum denominator magnitude.

Outputs: executable `RsmPoly`; `RSMPCA` coefficient loops and normalization fields.

## 5. Build the grid (`mkgrid`)

1. Create regular latitude, longitude, and HAE axes.
2. Evaluate `groundToImage` at every node.
3. Build a trilinear `RsmGrid` evaluator.
4. Evaluate elementary-model and grid coordinates at every cell centre.
5. Accept when maximum residual is below tolerance.
6. Otherwise refine every axis as `n <- 2*n-1` and repeat within the node limit.

Outputs: executable `RsmGrid`; `RSMGIA` topology; `RSMGGA` ordered node tuples.

An existing builder can be injected as `RsmCfg(gf=@(s,d,cfg) myBuilder(s,d,cfg))`.

## 6. Condition source covariance (`condcov`)

1. Convert a six-value variance vector to a diagonal matrix when needed.
2. Symmetrize the matrix.
3. Compute its eigen-decomposition.
4. Clip eigenvalues to a relative numerical floor.
5. Reconstruct and symmetrize the positive-semidefinite matrix.
6. Report original/final eigenvalues, number clipped, and relative repair.

Outputs: physical adjustable-parameter covariance and covariance-generation report.

## 7. Compute pose sensitivity (`fdjac`)

For each state component:

1. Apply a positive perturbation.
2. Apply the equal negative perturbation.
3. Evaluate image coordinates at all ground samples.
4. Divide the difference by twice the perturbation magnitude.

Output: `J(i, image_component, source_parameter)` in pixels per source-state unit.

## 8. Build physical adjustable parameters (`fitadj`)

1. Use identity source mapping, so each parameter is one physical pose component.
2. Form row and column response values from each Jacobian column.
3. Fit low-order ground-normalized polynomials to every response field.
4. Retain the conditioned physical covariance.

Outputs: executable physical `RsmAdj`; `RSMAPA`; `RSMECA`.

## 9. Build reduced adjustable parameters (`redbasis`, `fitadj`)

1. Factor source covariance as `C = L*L'`.
2. Stack all 2-by-6 image Jacobians into `A`.
3. Compute `svd(A*L)`.
4. Retain the smallest number of modes satisfying the energy threshold and maximum count.
5. Form the source map `M = L*V(:,1:k)`.
6. Set reduced parameter covariance to identity.
7. Fit row/column displacement polynomials for `J*M`.

Outputs: executable reduced `RsmAdj`; `RSMAPB`; `RSMECB`; retained-mode report.

## 10. Build indirect covariance

For one location, the adjustable model evaluates `B(g)` and returns:

```
Cimg(g) = B(g) * Cp * B(g)'
```

For two locations, the shared-state cross covariance is:

```
Cimg(g1,g2) = B(g1) * Cp * B(g2)'
```

The six pose errors are global for the image, so the semantic correlation group is constant one.
No independent unmodeled component is invented.

Outputs: `RSMECA` or `RSMECB` covariance, map, basis, and correlation fields.

## 11. Build direct covariance (`mkdirect`)

1. Propagate every sampled Jacobian as `Ci = Ji*C*Ji'`.
2. Extract row variance, row-column covariance, and column variance.
3. Fit each component with a ground-normalized polynomial.
4. At evaluation, reconstruct a symmetric 2-by-2 matrix and eigen-clip numerical negatives.
5. Retain the shared-state basis as an independent cross-location validation path.

Outputs: sampled `RSMDCA`; fitted `RSMDCB`; executable `RsmDir`.

## 12. Verify covariance (`mccov`)

1. Draw source perturbations from the conditioned covariance.
2. Evaluate perturbed image coordinates.
3. Compute empirical image covariance at each selected location.
4. Compare it with linear propagation using relative Frobenius error.

Output: median and maximum covariance disagreement plus empirical/linear matrices.

## 13. Bind semantic objects to wire fields

Every TRE class returns a field struct. `collect_fields` collects the full suite. The mapping table
`tre_field_map.csv` identifies the numerical source, units, and whether a name is exact or remains
controlled-extension-profile dependent.

`TreWriter` consumes an explicit field schema. It deliberately does not guess field widths,
format strings, blank rules, conditional branches, or repeated-record partitioning.
