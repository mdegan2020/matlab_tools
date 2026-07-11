# Dense-Surface Synthetic Acceptance Report

Status: first full-scale evidence complete. Numerical thresholds are proposed
in a separate reviewable documentation change.

## Scope And Privacy

This report summarizes the first configured run without publishing private
fixture inputs. Sensor, collection, image-size, schedule, terrain, texture, and
navigation values remain only in the ignored local configuration. The ignored
evidence artifacts retain the configuration fingerprint and derived metrics so
an authorized operator can reproduce the exact run.

The acceptance path uses one shared truth render for both generic inertial
grades and both acceptance modes. Viewer scenes receive images and reported
geometry only. Compact terrain, trajectory, visibility, and source-coordinate
truth are consulted after each processing stage and never enter scene layers or
viewer metadata.

## Workflow

`ProjectionDenseSurfaceSyntheticAcceptance` exercises the production-facing
in-memory contracts in this order:

1. Build a viewer scene from shared image references and one reported-geometry
   variant.
2. Render bounded alignment working images from full source radiometry.
3. Match, geometrically filter, and solve OPK with the reference layer fixed.
4. Apply only proposals accepted by the existing safe-solve policy.
5. Extract a dense surface from the resulting current scene.
6. Compare sparse and dense source observations with compact truth on mutually
   visible terrain, reporting true occlusion separately.

Fixing the reference layer makes the recovered correction an observable
differential OPK quantity. Absolute common-mode layer values are retained only
as diagnostics and are not treated as a recovery measurement.

## First Evidence

All four preset/mode combinations completed their alignment stages and
produced successful CPU dense surfaces. Each run retained substantial spatial
support: raw match counts were 177-286, filtered counts were 169-262, and
working-image spatial coverage was 0.630-0.841.

Sparse truth-correspondence P95 separation was 14.30-18.23 metres. The two
pointing-only proposals improved forward-ray RMS by 2.2%-7.7%; the existing
10% safe-apply floor therefore rejected them without mutating the scenes. Both
combined-error proposals were actionable and reduced forward-ray RMS by
26.0%-59.5%. Pointing-only differential OPK recovery error was
0.0137-0.0220 degrees; combined-error recovery error was 0.111-0.127 degrees,
consistent with unmodeled within-image navigation drift in that robustness
mode.

The dense products retained 61,954-70,330 mutually visible samples per run and
explicitly excluded 14-17 genuinely occluded samples. Height RMS was
8.28-32.05 metres, height P95 was 15.48-43.81 metres, and dense ray-separation
P95 was 0.203-1.017 metres. These measurements establish evidence; they are not
yet committed pass/fail limits.

Two complete configured acceptance passes agreed exactly after excluding
runtime fields. The first pass took approximately 10.1 seconds and the warm
repeat approximately 7.7 seconds on the development system. Generation runtime
and estimated peak/retained memory are carried into the ignored report from the
generation summary. The persisted acceptance MAT and JSON are compact and
contain neither images nor viewer scenes.

## Interpretation

The evidence exercises the intended distinction between modes. Pointing-only
isolates a small constant component and confirms that marginal proposals remain
non-destructive under the established safe policy. Combined navigation error
demonstrates useful constant-OPK improvement while leaving expected
column-correlated residual structure for future time-varying models.

The first run also confirms that dense error must be evaluated only after
mapping retained dense samples back to both source images. Treating every
disparity as visible truth would incorrectly penalize terrain occlusion.

The separately committed threshold proposal derives conservative limits from
these results without revealing or freezing private fixture inputs. See
`docs/dense_surface_synthetic_acceptance_thresholds.md`.
