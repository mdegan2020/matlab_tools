# MATLAB SDK Read-Only Audit

Status: completed read-only inventory

Audit date: July 11, 2026

Audited baseline: `2f0d7ef` (`main`, synchronized with `origin/main`)

## Scope

This audit inventories the current public and headless MATLAB entry points for:

- viewer launch;
- sparse matching and filtering;
- OPK solving;
- correction application and export;
- backend alignment;
- dense matching and extraction; and
- optional GPU capability handling.

It identifies proposed reuse points and compatibility risks for the future
MATLAB SDK. It does not implement the planned correction-result lifecycle,
dense-matcher extension interface, matcher registry, or new SDK schemas.

## Current Entry Points And Reuse Candidates

| Surface | Current entry points | Proposed reuse |
| --- | --- | --- |
| Viewer launch | `runProjectionViewer`, `ProjectionViewerApp` | Preserve the lightweight layer names, image arrays, geometry definitions, and projection-plane launch contract. Continue accepting optional `ViewId`, `PassId`, and timing metadata without making them mandatory for basic launch. |
| Viewer state and backend handoff | `ProjectionViewerApp.exportState`, `importState`, `saveState`, `loadState`, `exportBackendJob`, `writeBackendJob`; `ProjectionViewerState`; `ProjectionBackendJob` | Reuse the existing versioned state/job validation and JSON/MAT payload patterns. Keep viewer presentation state separate from scientific correction results. |
| Headless alignment pipeline | `ProjectionAlignmentRunner.run` | Reuse its working-image, match, filter, solve, safe-policy, and timing orchestration as a compatibility adapter. Do not use its current automatic apply behavior as the future correction lifecycle contract. |
| Working imagery | `ProjectionAlignmentWorkingImageRenderer.render` | Reuse pair working images, validity masks, overlap masks, continuous source-row/source-column maps, projection-plane maps, and stable `LayerId` provenance. Treat these products as bounded analysis inputs only, never backend radiometric inputs. |
| Sparse matching | `ProjectionAlignmentFeatureMatcher.capabilities`, `match`, `showMatchedPair` | Reuse detector capability reporting, deterministic matcher diagnostics, source-coordinate recovery, and result normalization where compatible with a future matcher adapter. |
| Match filtering and provenance | `ProjectionAlignmentMatchFilter.filter`; `ProjectionAlignmentMatchLedger` | Reuse staged acceptance masks, rejection reasons, stable raw-match records, source observations, residual attachment, and solver-observation provenance. |
| Solving | `ProjectionAlignmentOpkSolver.solve`, `compareScenes` | Reuse numerical solving, runtime cancellation, residual diagnostics, observability diagnostics, bounds, and common/differential parameter decomposition. Wrap outputs in a new correction-result value rather than changing existing names. |
| Correction mutation | `ProjectionAlignmentOpkSolver.applyCorrections`, `previewCorrections`, `revertCorrections` | Reuse the scene-copy mutation mechanics behind a stricter compatibility gate that validates stable view identity, geometry revision, conventions, and lifecycle state. |
| Alignment result serialization | `ProjectionAlignmentResult.validate`, `encode`, `decode`, `write`, `read` | Reuse the versioned validation and portable JSON pattern. Preserve `ProjectionAlignmentResult` version-2 behavior while introducing a separately versioned correction-result envelope. |
| Backend alignment | `ProjectionBackendJob`, `ProjectionBackendProcessor.run`, `validate` | Reuse the existing headless job path, safe-solve behavior, aligned scene/state output, diagnostics files, and render-after-alignment integration. |
| Dense extraction | `ProjectionDenseSurfaceExtractor.capabilities`, `defaults`, `validateOptions`, `extract` | Wrap the current CPU-complete SGM implementation as the first built-in dense-matcher adapter. Preserve optional capability-checked GPU fallback. |
| Dense result viewing | `ProjectionDenseSurfaceViewer.show` | Keep visualization as a consumer of authoritative numeric results, not part of the matcher interface. |
| GPU capability | `ProjectionGpuSupport.capability`, `resolve` | Reuse the explicit requested/available/enabled/fallback model for matcher capability reporting. |

## Correction-Result Compatibility Risks

1. Current solved corrections are keyed by `LayerId` and `LayerIndex`, not the
   stable multi-image `ViewId` and `PassId` required by the planned SDK.
2. `ViewVectorAngularOffsetsDegrees` currently represents the effective stored
   layer correction. Results do not explicitly declare angle order, increment
   versus absolute semantics, sign convention, reference frame, or convention
   version.
3. `ProjectionAlignmentRunner.run` automatically applies a safe result. This
   combines solver proposal and application, while the planned lifecycle must
   distinguish proposed, accepted, applied, rejected, superseded, and
   historical generations.
4. The GUI keeps its alignment result in private runtime state. There is no
   narrow public API to query the current accepted result, query a historical
   generation, accept a proposal, or apply a reviewed portable result.
5. Correction application validates `LayerId` when present and otherwise falls
   back to layer index. It does not validate `ViewId`, geometry revision or
   fingerprint, units, frame, dimensions, or stale-result compatibility.
6. Starting corrections, bounds, safe-solve policy, observability, priors, and
   parameter decomposition exist in diagnostics, but their nested layout is not
   yet a stable correction SDK contract.
7. `ProjectionAlignmentResult` has a useful versioned JSON contract, but its
   status vocabulary describes matching/solving rather than operator acceptance
   and application history.
8. No authoritative correction-generation callback/event or queryable history
   exists. Any future event must remain supplementary to a query API.

## Dense-Matcher Compatibility Risks

1. `ProjectionDenseSurfaceExtractor` is a concrete static SGM implementation,
   not an abstract or replaceable dense-correspondence interface.
2. There is no matcher identity/version contract, option schema discovery,
   explicit registry, subclass conformance suite, progress hook, cooperative
   cancellation hook, or deterministic seed in the dense path.
3. The current extractor consumes `pairWorking` and sparse `pairMatch` structs.
   A public request must define stable view IDs, corrected source geometry,
   validity masks, overlap ROI, source-coordinate maps, precision policy, and
   capability results independently of UI state.
4. The current disparity product is expressed on rectified working imagery.
   It must not be exposed as if it were a full-source observation.
5. `result.Surface` may be decimated by `MaximumSurfacePoints`. A dense surface
   is a downstream triangulation product, not a substitute for the complete
   correspondence result.
6. The reusable authoritative pieces are the continuous
   `MovingSourceRows`, `MovingSourceColumns`, `ReferenceSourceRows`, and
   `ReferenceSourceColumns` maps plus validity, score/confidence, occlusion or
   no-match state, and provenance. The future matcher result should center these
   source-image observations.
7. CPU execution is complete and tested. GPU execution is optional and already
   capability-checked, but the future matcher contract must report requested,
   available, selected, and fallback execution explicitly.

## Recommended Boundary For Future SDK Work

1. Preserve all existing `PlanarProjection` and `Projection*` public names.
2. Add a separately versioned, immutable/value-like correction-result envelope
   keyed by stable `ViewId` and `PassId`; adapt existing solver results into it.
3. Make proposal, acceptance, application, rejection, and supersession explicit
   operations. Do not make `ProjectionAlignmentRunner.run` automatic application
   the new public lifecycle.
4. Validate geometry fingerprints and correction conventions before mutation;
   retain an explicit adapter for existing `LayerId` results.
5. Add a strict dense request/result contract and abstract matcher interface.
   Wrap `ProjectionDenseSurfaceExtractor` as the first built-in adapter rather
   than changing its current public behavior.
6. Put common validation, cancellation, source-coordinate checks, provenance,
   error classification, and CPU/GPU reporting in the base contract.
7. Register matchers explicitly through an embedding-supplied registry. Do not
   scan arbitrary paths or instantiate classes named by untrusted serialized
   data.
8. Keep display pyramids, preview tiles, alignment working imagery, dense
   surfaces, and runtime caches out of backend radiometric inputs and portable
   scientific correction state.

## Deferred Decisions

The following remain intentionally deferred to the ongoing planning work:

- correction-result class/struct names and exact schema versions;
- correction generation/history ownership and persistence;
- operator acceptance and optional notification semantics;
- geometry fingerprint definition;
- exact covariance and selected-marginal representation;
- dense matcher abstract-class versus strict functional-interface form;
- progress/cancellation object shape;
- registry ownership and matcher discovery policy; and
- the complete dense no-match/occlusion/confidence/covariance result schema.
