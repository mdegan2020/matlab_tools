# B3 Pairwise Point Covariance

Status: complete. `ProjectionPairwisePointCovariance` performs forward-valid
pair triangulation and initial linear covariance propagation without forming a
mesh, grid, or fused surface.

Inputs retain stable pair/view identity, two origins and directions, optional
combined 4×4 full-source observation covariance ordered as `[first column,
first row, second column, second row]`, 3×2 pixel-to-direction Jacobians, and an
optional correlated 12×12 ray-state covariance ordered as the two origins and
directions. Covariance status and the world frame are explicit; missing
uncertainty is unavailable rather than zero.

Central numerical Jacobians propagate localization and geometry contributions
into one symmetric 3×3 world-frame covariance in meters squared. Each record
reports the provisional point, forward ray parameters, separation,
intersection angle, condition number, covariance/reliability status, reason,
and principal-axis sigmas. Weak geometry or a non-PSD linearization remains
labeled unreliable instead of being silently repaired.

`ProjectionPairwisePointCovarianceTest` covers exact intersection, forward
validity, symmetry/PSD, observation and ray-state covariance scaling, explicit
frame/units, missing uncertainty, weak geometry, and behind-ray rejection.
