# Dense-Surface Synthetic Acceptance Threshold Proposal

Status: proposed from the first repeatable full-scale evidence package. These
limits are documentation-only until a separately approved change implements an
automated evaluator.

## Intent And Privacy Boundary

The proposal makes the deterministic synthetic fixture the primary systematic
alignment and dense-surface gate without committing its private inputs. It
references only derived acceptance metrics. Sensor, collection, image-size,
schedule, terrain, texture, and navigation parameters remain in the ignored
local configuration.

Thresholds use conservative margins around the first exact two-pass evidence.
They are intended to detect material regressions, not to tune algorithms to one
realization. Any later change must preserve the original evidence artifact,
explain the reason for the adjustment, and update one metric at a time where
practical.

## Required Preconditions

A candidate run is eligible for quantitative evaluation only when all of the
following are true:

- the configuration fingerprint agrees across feasibility, generation,
  navigation, and acceptance artifacts;
- every feasibility check passes before full-scale allocation;
- generation completes with exact output readback, complete valid coverage,
  and the required nonzero occlusion audit;
- both generic inertial grades and both acceptance modes are present;
- all four alignment records complete and all four dense products succeed;
- the repeated acceptance pass reports exact deterministic agreement after
  excluding runtime fields; and
- ignored artifacts contain no embedded full image arrays or viewer scenes.

Failure of a precondition is a gate failure, not a skipped metric.

## Proposed Functional Limits

The following limits apply independently to every preset/mode run unless the
row says otherwise.

| Metric | Proposed limit | First evidence |
| --- | ---: | ---: |
| Raw matches | at least 150 | 177-286 |
| Filtered matches | at least 140 | 169-262 |
| Solver-used observations | at least 140 | 169-262 |
| Working-image spatial coverage | at least 0.55 | 0.630-0.841 |
| Sparse truth-correspondence P95 | at most 25 m | 14.30-18.23 m |
| Absolute residual/column correlation | at most 0.25 | 0.018-0.091 |
| Absolute residual slope per source column | at most `1e-4` | `5.6e-6`-`2.5e-5` |
| Dense mutually visible samples | at least 50,000 | 61,954-70,330 |
| Dense height RMS | at most 40 m | 8.27-32.05 m |
| Dense height P95 | at most 55 m | 15.48-43.81 m |
| Dense ray-separation P95 | at most 1.5 m | 0.203-1.017 m |
| Explicit occlusion exclusions | at least 1 | 14-17 |

The forward-ray and recoverability limits are mode-specific:

| Mode | Metric | Proposed limit | First evidence |
| --- | --- | ---: | ---: |
| Pointing-only | Forward-ray RMS after/before | at most 1.00 | 0.923-0.978 |
| Pointing-only | Differential OPK recovery error | at most 0.030 deg | 0.0137-0.0220 deg |
| Combined error | Forward-ray RMS after/before | at most 0.85 | 0.405-0.740 |
| Combined error | Differential OPK recovery error | at most 0.150 deg | 0.111-0.127 deg |

Combined-error recovery is intentionally looser because constant OPK cannot
remove correlated position, velocity, attitude, and within-image drift. The
proposal also requires combined-error recovery error to exceed the associated
pointing-only value for each grade; reversing that relationship would indicate
that the modes no longer exercise distinct behavior.

## Safe-Apply Outcomes

The gate evaluates the existing safe-solve policy rather than overriding it:

- a record may mutate the scene only when its post-policy status is `solved`;
- a rejected proposal must leave the scene unchanged and continue to dense
  extraction from the unchanged reported geometry;
- both combined-error records must remain actionable for this fixture; and
- pointing-only records may be applied or safely rejected, provided their
  forward-ray and differential-recovery limits pass.

This accommodates small, non-degrading pointing proposals that do not exceed
the established 10% residual-improvement floor while still detecting an unsafe
mutation or a lost robustness correction.

## Runtime And Memory Evidence

Runtime is hardware-sensitive and should not block functional acceptance on an
unqualified host. On the current development-system class, the proposed
advisory limits are 15 seconds per complete four-variant acceptance pass and a
1.5 ratio between the slower and faster deterministic repeats. The first
evidence was approximately 10.1 and 7.7 seconds.

Generation retained-memory and estimated-peak-memory values must remain finite,
positive, and within the planner/configuration memory budget. Acceptance must
load the shared images once per pass and must not duplicate them inside
navigation variants, run records, MAT artifacts, or JSON artifacts. A future
target-Windows benchmark may add absolute runtime and measured peak-resident-
memory limits; the current estimated peak is not presented as an observed
process high-water mark.

## Adoption And Change Control

This document proposes the first limits but does not alter runtime code. An
automated evaluator should be a focused follow-up change that:

1. encodes these values in a public, fixture-input-free policy;
2. reports every failed metric rather than stopping at the first quantitative
   failure;
3. preserves the ordered feasibility gate and exact repeatability check;
4. distinguishes hard functional limits from advisory hardware timing; and
5. adds deterministic public tests around boundary values without loading the
   ignored configuration.

Air-gapped real-data observations may motivate isolated adjustments later, but
they are not required to adopt this synthetic gate.
