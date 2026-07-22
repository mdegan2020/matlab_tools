# Validation Report

Revision 1.0

## Static package checks

- No `+package` directories or namespace-qualified calls.
- All 22 classes are concrete.
- No `abstract` class or method declarations.
- No `inputParser`, `validateattributes`, `nargin`, or production `assert` calls.
- Public functions and public methods use `arguments` blocks for input validation.
- Custom validators are called from `arguments` blocks.
- TRE field traceability table contains 354 field or repeated-field-group rows.
- Test suite contains sensor, coefficient-order, polynomial, grid, covariance, TRE, and end-to-end tests.

## Independent numerical mirror checks

The central equations were independently mirrored in Python using the same toy pushbroom geometry,
normalization, RPC00B monomials, RSM permutation, grid interpolation, and covariance units.
This was not a MATLAB execution test.

Observed results for the included test configuration:

- Toy pushbroom image-ground-image round trip: below `1e-9` pixel at tested points.
- Single cubic rational polynomial withheld maximum error: approximately `2.4e-9` pixel.
- Initial 5-by-5-by-3 trilinear grid cell-centre maximum error: approximately `1.6e-4` pixel.
- Linear covariance versus 10,000-sample Monte Carlo median relative Frobenius error:
  approximately `0.027` for the small perturbations used by the example.

## Runtime limitation

A MATLAB or Octave executable was not available in the generation environment. The included MATLAB
tests were therefore reviewed statically but not executed here. Run `tests/run_tests.m` in MATLAB
R2022b or newer before integrating the package.

## Standards limitations requiring program binding

- The package produces numerical models and TRE semantic field structures.
- `TreWriter` requires a revision-specific schema supplied by the program.
- Exact field widths, formatting, blank rules, conditional branches, packed-triangle traversal,
  grid-node partitioning, and A/B variant details must be checked against the authoritative
  controlled-extension revision.
- `rsmexp.m` isolates the coefficient traversal and must be replaced if the selected profile uses a
  different RSM ordering.
- The provided covariance represents one global six-state pose error. It does not invent temporal
  knots, line-dependent stochastic processes, or unmodeled error terms absent from the source data.
- Covariance generation requires a pose-perturbed projection callback. Nominal image/ground
  functions plus six variances are insufficient to identify pose-to-image sensitivity.
