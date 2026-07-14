# UFM Learned Dense Matcher Evaluation Workplan

Status: proposed July 14, 2026. Evaluation has not started. No UFM code,
checkpoint, Python environment, or supported product dependency has been added
to Sightline Workbench.

## Decision Objective

Determine whether `infinity1096/UFM-Base` provides enough correspondence
quality, coverage, and end-to-end speed on representative Sightline data to
justify an optional external dense matcher, and determine the license,
hardware, packaging, and operator constraints under which that integration
could be supported.

This is an evidence-gathering workstream, not approval to replace the current
SGM or classical template matchers. The possible final decisions are:

1. stop after evaluation and retain only the evidence;
2. retain a developer-only experimental adapter;
3. ship a supported optional external matcher without redistributing weights;
4. evaluate another UFM checkpoint, such as a refinement or 980-resolution
   variant, under a separately approved plan; or
5. reject the technique for the intended use or target hardware.

The work shall follow the ordered gates below. A failed gate stops later work
unless the failure is explicitly reviewed and this plan is revised.

## Why This Candidate Is Worth Evaluating

UFM is a learned dense correspondence model that directly predicts two-axis
flow from one image into another and also reports a covisibility field. It is
designed to cover both optical-flow and wide-baseline matching cases. That is
architecturally relevant to the current Surface Workbench, where the classical
template matcher can spend many minutes per pair in nested candidate and
reverse-consistency searches.

The candidate is promising, but the published GPU inference number is not a
Sightline end-to-end measurement. It excludes MATLAB/Python transfer, model
load, source-map conversion, masks, reverse checking, observation selection,
ray construction, association, multi-ray reconstruction, and fusion. It was
also measured on an RTX 5090, not on the current macOS development host or the
intended deployment workstation. No performance or quality claim is accepted
until the stages below produce local evidence.

## Evaluated Upstream Snapshot

The following values capture the candidate inspected while this workplan was
written. UFM-0 must re-resolve, pin, and checksum every executable dependency
before an evaluation run.

| Item | Inspected value | Consequence |
| --- | --- | --- |
| UFM repository | `UniFlowMatch/UFM` `main` at `ff78d6c3db807c91578acccb58ee67d4394d5e5f` | Pin this or an explicitly reviewed successor; never evaluate a floating branch. |
| UniCeption submodule | Repository listing reports `ee7fa0b` | Record the full resolved submodule commit in the environment lock. |
| UFM package | Alpha `0.1.0`; Python `>=3.9`; upstream setup recommends Python 3.11 | Use an isolated Python 3.11 environment and pin the full transitive dependency set. |
| Model repository | `infinity1096/UFM-Base` revision `cb60fe3d33ace8bbe1416a1e93de0807336927c1` | Resolve weights by immutable revision and verify a local checksum. |
| Model shape | Approximately 428 million F32 parameters; checkpoint is about 1.7 GB | Load once into a persistent worker; never reload for each pair. |
| Trained inference resolution | Configuration reports `[560, 420]` | UFM internally resizes the bounded pair images; it does not operate on the original full-resolution sources. |
| Input/output | Equal-size, three-channel images; forward two-axis flow and covisibility | Sightline's current 2-D analysis images need a declared three-channel policy and exact flow-coordinate validation. |
| Advertised runtime | 33 ms typical for UFM-Base on an RTX 5090 | Treat only as upstream context, not as a local acceptance value. |
| Code license | BSD-3-Clause | Code use is separable from checkpoint use. |
| Checkpoint license text | UFM README says CC BY-NC-SA 4.0; Hugging Face metadata says CC BY-NC 4.0 | Treat the checkpoint as noncommercial and subject to the stricter terms until the rights holder resolves the discrepancy. |

Primary upstream references are listed at the end of this document.

## Existing Sightline Boundary

The candidate fits the existing extension architecture, but not without an
adapter:

- `ProjectionDenseMatchRequest` supplies two equal-size, finite 2-D analysis
  images, validity masks, overlap, continuous full-source row/column maps,
  corrected geometry, and stable pair/view identity.
- `ProjectionDenseMatcher` owns validation, progress, cooperative
  cancellation, error classification, execution reporting, and provenance.
- `ProjectionDenseMatchResult` requires continuous full-source observations,
  one supported state per observation, scores, confidence in `[0,1]`, optional
  pixel covariance, timing, memory, execution, and provenance.
- `ProjectionDenseMatcherRegistry` registers explicit matcher instances. It
  does not discover Python code or construct class names from saved data.
- `ProjectionSurfaceWorkbenchRunner` currently exposes built-in SGM, classical
  template matching, or the first registered external matcher. A supported UFM
  integration needs a named selection and cannot depend on external-registry
  order.
- The current request schema intentionally rejects display textures and accepts
  only 2-D scientific analysis radiometry. UFM requires three channels.

The natural adapter is a future `ProjectionDenseUfmMatcher` subclass backed by
a persistent out-of-process Python service. It shall return only the portable
MATLAB result contract; Python objects, tensors, model handles, processes, and
GPU resources remain runtime-only.

## Scientific And Product Invariants

All stages must preserve these constraints:

1. UFM remains optional. The complete tested MATLAB CPU path must work without
   Python, PyTorch, CUDA, the UFM source, or model weights.
2. No automatic `Best` policy may silently choose UFM. The operator or an
   explicit headless configuration selects it.
3. Checkpoint files are never committed to this repository or redistributed
   with Sightline without a separately recorded license decision.
4. No network download occurs when the operator presses Run. Installation or
   checkpoint acquisition is an explicit setup action; preflight reports a
   missing or mismatched checkpoint before processing begins.
5. UFM consumes only analysis-safe radiometry. Display pyramids, normalized
   display textures, RGB presentation conversions, alpha/composite images, and
   camera-selected display LOD remain forbidden scientific inputs.
6. The bounded 512/768 working grids remain coarse analysis inputs. Continuous
   full-source maps and corrected source geometry remain authoritative for
   output observations and reconstruction.
7. Covisibility is an uncalibrated model output until evaluation proves a
   useful calibration. It shall not masquerade as measurement probability or
   covariance.
8. UFM-Base supplies no accepted per-observation covariance. Leave
   `CovariancePixelsSquared` empty unless a separately validated estimator is
   added.
9. The observation cap limits downstream selection and reconstruction. It does
   not reduce UFM's dense forward-pass work and shall not be presented as an
   inference-time control.
10. `sparseSeeded` is not a meaningful geometry-search mode for a global
    learned flow model. UFM preflight and UI shall report `learnedGlobal` or an
    equivalent explicit value and disable incompatible search controls.
11. Every accepted point must pass target bounds, moving and reference masks,
    overlap/ROI policy, model covisibility policy, source-map validity, and
    downstream forward-geometry/conditioning gates.
12. Private image values, dimensions, paths, geometry, timing labels that
    identify a collection, and model outputs derived from those inputs remain
    outside Git. Only anonymized aggregate evidence may be committed.
13. Evaluation results must identify the UFM code commit, submodule commit,
    model revision and checksum, Python/PyTorch/CUDA versions, GPU, driver,
    precision mode, input policy, and every threshold that affects selection.

## Required Coordinate And Mask Contract

The initial implementation hypothesis is that a moving working-grid pixel
`(row_m, column_m)` maps to a reference working-grid pixel as:

```text
column_r = column_m + flow_x
row_r    = row_m    + flow_y
```

This is not accepted merely because it matches common optical-flow notation.
UFM-2 must prove axis order, sign, pixel-center convention, resize/unmap
behavior, and direction using identity, integer translation, subpixel
translation, and asymmetric fixtures.

For a surviving sample, the adapter shall interpolate the request's source
maps at the continuous working coordinates:

```text
moving source  = map_m(row_m, column_m)
reference source = map_r(row_r, column_r)
```

Interpolation must use the same declared pixel-center convention on both
sides. A result is never marked `valid` if either interpolation is outside the
map, touches invalid support under the selected validity policy, or produces a
nonfinite source coordinate.

The upstream base implementation computes a resize/unmap validity value but
does not expose it through the public result inspected for this plan. The
adapter therefore must independently reject padding/unmap borders, target
bounds, and masks. Covisibility alone is insufficient.

UFM requires three channels. The first evaluation policy for Sightline's
single-band analysis image is deterministic replication of the untouched
analysis band into three equal channels. This is a compatibility experiment,
not a claim that replicated grayscale matches the model's natural RGB training
domain. True source RGB requires a future request-contract change and is out of
scope until replicated-band evidence justifies it.

## Evaluation Artifact Layout

The implementation stages shall use the following repository layout unless a
reviewed implementation pack records a better project-native location:

```text
scripts/ufm_eval/                 committed harness and reporting code
config/ufm_eval/                  committed non-private configurations
tests/python/ufm_eval/            committed Python unit/contract tests
tests/ProjectionDenseUfm*.m       committed MATLAB adapter tests, if approved
docs/ufm_evaluation_report.md     committed final aggregate decision record
artifacts/ufm_evaluation/         ignored local/private outputs
```

The first implementation commit must add `artifacts/ufm_evaluation/*` to
`.gitignore`, retain a `.gitkeep` only if useful, and add a pre-commit privacy
check for unexpected image, checkpoint, tensor, pair-bundle, or local-path
files in the evaluation tree.

Weights, Python virtual environments, pip/conda caches, cloned upstream source,
private pair bundles, GPU traces, and raw dense flow arrays remain outside Git.

## Evaluation Corpus

The corpus has four tiers. Results must keep tier labels separate; a private
real-data aggregate cannot replace a truth-known synthetic test.

| Tier | Contents | Purpose | Git policy |
| --- | --- | --- | --- |
| T0 semantic | Identity, asymmetric horizontal/vertical shifts, subpixel shift, masked border, aspect-ratio, and low-texture fixtures | Prove coordinate, resize, mask, and failure-state semantics | Commit generated fixture definitions and small non-sensitive expected values. |
| T1 project synthetic | Existing non-private dense-surface and geometry cases with truth where applicable | Measure endpoint, height, ray, occlusion, and downstream reconstruction behavior | Reuse committed generators; commit aggregate evidence only. |
| T2 representative private pairs | Bounded 512/768 analysis images exported from real Surface Workbench requests | Measure domain fit, coverage, runtime, covisibility, and failure modes | Store bundles and raw results only under ignored local artifacts. |
| T3 representative private network | At least one multi-view schedule with repeated views and several physical pairs | Measure association, duplicate-ray handling, reconstruction, and total operator wait | Store raw evidence locally; commit only anonymized aggregate results. |

T2 should span, where available, easy and difficult overlap, wide and narrow
baselines, relief, repetitive texture, weak texture, masked/nodata edges,
radiometric differences, and meaningful occlusion. Pair labels in the durable
report shall be anonymous stable case IDs.

Each exported pair bundle shall contain a versioned manifest, stable anonymized
pair/view IDs, analysis images, masks, overlap/ROI, continuous source maps,
precision/radiometry metadata, and checksums. Synthetic bundles may add truth.
Do not serialize function handles or private source paths. Geometry-dependent
Stage UFM-3 may retain a separate local MATLAB-side mapping from anonymous IDs
to the in-memory corrected source models.

## Measurements And Fair-Comparison Rules

### Timing and resource metrics

Record at least:

- environment creation and checkpoint acquisition separately from execution;
- worker startup, import, checkpoint load, first inference, and warm inference;
- MATLAB-to-worker transfer, device upload, model forward, device download,
  postmask, spatial selection, source-map conversion, and result validation;
- pairwise matching, association, multi-ray reconstruction, fusion, and total
  Run elapsed time;
- peak host RAM, peak GPU allocated/reserved memory, checkpoint disk bytes, and
  output bytes; and
- cold versus warm results and median/p95 across repeated runs.

The UI must publish a stage within 500 ms of Run. Checkpoint download time is
never included in a favorable runtime figure because Run may not download.

### Correspondence and geometry metrics

Record where truth or geometry supports them:

- working-grid endpoint error and valid-flow coverage;
- forward/reverse cycle error and cycle-pass fraction;
- covisibility precision/recall and retained fraction at each evaluated
  threshold;
- moving and reference spatial coverage by a fixed grid, including empty-cell
  fraction and concentration;
- full-source coordinate error on truth-known cases;
- accepted and rejected counts by `ProjectionDenseMatchResult` state;
- forward-ray validity, ray separation median/p95, conditioning, and
  reconstruction residual;
- height/elevation error and completeness on truth-known surfaces;
- independent view/pass support and multi-view track count; and
- surface holes, gross outliers, and spatially clustered failures.

### Baseline integrity

Compare against `currentSgm` and `classicalTemplate` using the same exported
pair request, masks, source maps, pair direction, final observation budget, and
downstream reconstruction settings. Record each matcher's actual executed
options rather than only the UI selection.

The current Surface Workbench configuration can display `sparseSeeded` even
when the classical template matcher receives no recognized
`ProjectionDenseSearchPredictor` prediction and falls back to its global
search range. That is a known comparison confound. Before comparative scoring:

1. assert the matcher result provenance identifies the actual search domain;
2. if selected and executed search policies differ, mark the run invalid;
3. either correct that separate defect under an approved implementation pack or
   compare the template matcher under an explicitly named supported global
   range; and
4. never credit UFM with a speedup against a baseline whose preflight or search
   provenance is false.

UFM produces a dense field before observation selection. Apply one shared,
deterministic, aspect-aware spatial selector to UFM results for downstream
comparisons. Do not select only the highest covisibility pixels. Preserve the
uncapped inference time and distinguish raw dense coverage from capped
downstream observations.

### Initial promotion thresholds

Freeze the final thresholds in UFM-0 before scoring private cases. Unless that
gate records different values with rationale, use these initial decision rules:

- zero unresolved coordinate, identity, target-bound, or source-map failures
  in T0;
- no accepted observation bypasses an input mask, overlap/ROI rule, or required
  geometry validity check;
- warm end-to-end matching through validated full-source result is targeted at
  p95 `<= 5 s` per 768-bounded pair on the qualified GPU;
- p95 `>= 60 s` per warm pair is a performance stop because it fails the
  operator's stated upper bound; values between 5 and 60 seconds require an
  explicit benefit/optimization review;
- a ten-pair warm pairwise stage is targeted at `<= 60 s`, excluding later
  reconstruction/fusion but including transfer and result conversion;
- the qualified GPU must retain at least 25 percent memory headroom during the
  worst evaluated pair so ordinary system variation does not cause OOM;
- no truth-known median or p95 geometric error may regress by more than 10
  percent relative to the best valid baseline without an explicit coverage
  tradeoff decision; and
- promotion requires at least one material benefit: 25 percent lower primary
  geometric error at at least 80 percent of baseline coverage, two times valid
  coverage without more than 10 percent error regression, or ten times lower
  warm matching time with quality within 10 percent of the best baseline.

These are evaluation gates, not universal scientific constants or product
defaults. The final report shall show sensitivity to covisibility, cycle, and
sampling thresholds rather than tuning one threshold on the reported test set.

## Ordered Execution Queue

### UFM-0 — License, Use, Hardware, And Threshold Gate

Status: not started. This gate blocks checkpoint download and implementation.

Tasks:

1. State the intended use classification: internal research, noncommercial
   operational use, commercial product, redistribution, or another defined
   category.
2. Obtain a written license determination for the checkpoint. Resolve the
   UFM README's CC BY-NC-SA 4.0 statement against the Hugging Face
   CC BY-NC 4.0 metadata and review relevant training-dataset obligations.
3. Decide whether local weight acquisition is permitted and whether results or
   derivative artifacts have sharing restrictions. Default to no commercial
   use and no redistribution until resolved.
4. Name the target evaluation GPU, OS, driver, CUDA version, available VRAM,
   and whether it represents the intended deployment system. The current
   macOS host is not GPU qualification evidence.
5. Freeze the exact UFM, UniCeption, model, Python, PyTorch, torchvision,
   torchaudio, CUDA, and dependency revisions. Prefer `model.safetensors`; do
   not load the pickle checkpoint unless separately justified.
6. Freeze the initial thresholds above before examining private results.
7. Record who may access private bundles and how local artifacts are removed.

Required artifact:

- a short approved gate record in the eventual evaluation report containing
  use classification, license disposition, target hardware, immutable
  revisions/checksums, thresholds, and the go/no-go decision.

Exit criteria:

- proceed only if checkpoint use for the intended evaluation is permitted, a
  CUDA-capable target is available, and immutable dependencies can be
  acquired; otherwise record `stopped-at-UFM-0` and end the workstream.

### UFM-1 — Reproducible Python Runtime And Standalone Harness

Status: blocked by UFM-0.

Tasks:

1. Add the ignored local artifact boundary and committed harness/config/test
   layout.
2. Create an isolated Python 3.11 environment. Lock exact packages and record
   platform-specific hashes; upstream's unpinned `torch` dependencies are not
   sufficient for reproducibility.
3. Acquire the pinned Git repository recursively, verify the UFM and
   UniCeption commits, acquire `model.safetensors` at the pinned Hugging Face
   revision, and verify its cryptographic checksum.
4. Implement a Python-only CLI that loads the model once, accepts a versioned
   pair bundle, runs batch size one, and writes a versioned result manifest plus
   flow, covisibility, validity, timing, and resource evidence.
5. Make device and precision explicit. Record the upstream CUDA/bfloat16 path;
   do not claim CPU or Apple Silicon support merely because PyTorch imports.
6. Separate startup/load timing from warm inference and run at least 20 warm
   repetitions after stabilization.
7. Add deterministic input/output checksums and reject mismatched model or
   manifest versions.

Required artifacts:

- locked environment specification;
- setup/verification instructions that do not mutate the user's base Python;
- Python CLI and contract tests;
- machine-readable environment and runtime manifest; and
- a small committed T0 smoke result with no model weights or private arrays.

Exit criteria:

- a fresh environment can reproduce the T0 smoke result from the pinned inputs;
- 20 warm runs complete without process growth, OOM, nonfinite flow, or
  unexplained output drift; and
- the report separates model time from all setup and transfer costs.

### UFM-2 — Flow Semantics, RGB Policy, Masks, And Exported-Pair Benchmark

Status: blocked by UFM-1.

Tasks:

1. Build the complete T0 suite and prove flow direction, axis order, sign,
   pixel centers, resize/unmap behavior, aspect ratio, and continuous sampling.
2. Evaluate deterministic single-band replication to RGB. Record the exact
   radiometric class/range transformation; do not reuse display normalization.
3. Enforce source and target bounds, validity masks, overlap/ROI, padding
   validity, and covisibility as distinct rejection gates.
4. Evaluate covisibility thresholds without calling them calibrated
   confidence. Map final states into the existing result vocabulary with
   per-gate counts retained in diagnostics.
5. Run forward inference for all T1 and T2 pairs. Run reverse inference on the
   evaluation subset needed to characterize cycle consistency and its added
   cost.
6. Measure cold and warm load/inference, transfer-independent Python cost,
   peak host/GPU memory, raw dense coverage, covisibility, cycle error, and
   spatial distribution at 512- and 768-bounded inputs.
7. Test cancellation between pair calls and worker recovery after a deliberate
   invalid request or process failure.

Required artifacts:

- semantic contract test results;
- anonymized per-case aggregate correspondence/runtime table;
- covisibility and cycle-threshold sensitivity tables; and
- explicit failure inventory for domain shift, masks, borders, weak texture,
  repetitive texture, and occlusion.

Exit criteria:

- all blocking T0 rules pass;
- warm pair runtime is below the 60-second stop threshold;
- model memory fits the target GPU with the required headroom; and
- at least a useful, spatially distributed subset of representative pixels
  survives masks/covisibility without unexplained directional bias.

### UFM-3 — Full-Source Mapping And Downstream Geometry

Status: blocked by UFM-2.

Tasks:

1. Convert continuous UFM working-grid flow through both request source maps as
   defined above. Preserve double-precision full-source coordinates.
2. Use a deterministic aspect-aware selector to enforce the downstream
   observation cap after validity gating. Record raw, eligible, and selected
   counts separately.
3. Reuse the existing corrected source geometry, ray construction,
   association, robust multi-ray reconstruction, conditioning, and fusion
   contracts. Do not add an UFM-specific triangulator.
4. Compare forward-only, covisibility-filtered, and forward/reverse-cycle
   policies. Report the roughly doubled inference cost of reverse checking.
5. Measure T1 truth metrics and T2/T3 ray separation, forward validity,
   conditioning, support, reconstruction residual, completeness, and spatial
   holes.
6. Audit one-ray-per-stable-observation behavior when the same view pixel
   participates in multiple pair records.
7. Keep covariance absent. Confirm downstream code truthfully reports
   unavailable observation covariance rather than inventing a default.

Required artifacts:

- headless portable result bundles conforming to
  `ProjectionDenseMatchResult` semantics;
- anonymized pair and network geometry tables;
- visual diagnostics kept locally for representative failure cases; and
- a source-coordinate/ray audit showing the complete path from working pixel
  through full-source observation to reconstructed point.

Exit criteria:

- all valid results have finite, in-bounds authoritative source coordinates;
- no model/presentation data enters portable scientific products;
- T1 truth gates pass; and
- T2/T3 geometry is sufficiently valid to support the controlled comparison
  in UFM-4.

### UFM-4 — Controlled Baseline Comparison And Integration Decision

Status: blocked by UFM-3.

Tasks:

1. Resolve the baseline-integrity rule above and freeze executable SGM,
   template, and UFM configurations.
2. Run all three matchers over the same T1/T2 pair bundles and the same T3
   schedule with identical downstream selection caps and reconstruction gates.
3. Report cold and warm time, total ten-pair time, raw/selected coverage,
   endpoint/geometry/height metrics, multi-view support, and failure states.
4. Separate algorithm time from existing eager Surface Workbench launch time.
   UFM cannot be credited with fixing scene preparation unless that path is
   independently changed and measured.
5. Review qualitative local diagnostics for gross correspondence fields,
   spatial gaps, repeated structures, occlusion edges, and radiometric/domain
   failures without committing private imagery.
6. Apply the frozen promotion thresholds and record one decision:
   `stop`, `developer-prototype`, or `approve-MATLAB-adapter`.

Required artifact:

- the first complete `docs/ufm_evaluation_report.md`, including environment,
  configurations, anonymized results, threshold decisions, known limitations,
  and the signed-off UFM-4 outcome.

Exit criteria:

- UFM-5 may begin only for `approve-MATLAB-adapter`. A developer-only Python
  harness may remain after `developer-prototype`; `stop` adds no MATLAB or UI
  dependency.

### UFM-5 — Optional MATLAB Matcher Adapter

Status: blocked by an `approve-MATLAB-adapter` UFM-4 decision.

Tasks:

1. Add `ProjectionDenseUfmMatcher < ProjectionDenseMatcher` with an explicit
   algorithm ID, semantic adapter version, capability metadata, deterministic
   model identity, option validation, and honest CPU/GPU support claims.
2. Prototype out-of-process MATLAB Python execution only if it accelerates
   contract validation. The supported boundary should be a dedicated
   persistent worker if it provides materially better lifecycle, crash
   isolation, cancellation, logging, and dependency control.
3. Load and warm the model once per worker. Reuse it across every pair in a
   Surface Workbench run and across compatible subsequent runs. Never load once
   per pair.
4. Define a versioned worker protocol with request/result IDs, shapes, dtypes,
   checksums, model identity, stage timings, structured errors, and an explicit
   shutdown. Avoid the 2 GB MATLAB out-of-process transfer limit and unbounded
   array copies.
5. Publish progress for worker startup, model load, transfer, inference,
   postmask, source mapping, and result validation. Cancellation must be checked
   between bounded stages. If an in-flight CUDA call cannot be interrupted,
   report `cancellation pending`; define whether hard cancel terminates and
   reloads the worker.
6. Convert worker output through the UFM-3 mapping/selection path and return
   only a validated portable MATLAB struct. No Python object may escape the
   matcher.
7. Make missing Python, incompatible GPU, missing/mismatched weights, worker
   crash, OOM, invalid flow, and timeout explicit unsupported/failure outcomes.
   Do not silently fall back to another matcher under the UFM identity.
8. Add a fake-worker conformance test so ordinary repository CI does not need
   Python, CUDA, UFM, or weights. Keep real-model tests separately tagged and
   hardware-gated.

Required artifacts:

- adapter, worker/protocol layer, headless tests, setup documentation, and
  updated matcher SDK documentation;
- exact execution/provenance fields for code/model/environment/device; and
- cold/warm MATLAB bridge benchmarks against the Python-only results.

Exit criteria:

- normal CPU-only repository tests remain green with no UFM installation;
- fake-worker tests cover success, invalid states, progress, cancellation,
  timeout, crash, OOM, and teardown;
- real-model results agree with the UFM-3 oracle within frozen tolerances; and
- bridge overhead does not cause the accepted UFM-4 performance class to fail.

### UFM-6 — Surface Workbench Integration And Operator Validation

Status: blocked by UFM-5.

Tasks:

1. Replace generic first-external selection with a stable named UFM method when
   the explicit registry contains a capable adapter. Preserve arbitrary custom
   matcher support separately.
2. Add capability-aware preflight showing UFM code/model identity, checkpoint
   path status, RGB policy, internal/input resolution, device/precision, memory
   estimate, covisibility and cycle policies, downstream cap, and no-covariance
   status.
3. Label geometry search `learnedGlobal` and disable incompatible
   `sparseSeeded` controls. Keep pair scheduling independent of matcher search.
4. Keep UFM non-default. Opening Surface Workbench must not start Python or
   load weights. Model startup begins only after explicit Run and immediately
   produces visible progress.
5. Run one selected-pair diagnostic, one planned multi-pair schedule, and one
   all-quality T3 schedule. Measure launch preparation separately from Run,
   cold first pair, warm later pairs, cancellation, rerun reuse, and close
   cleanup.
6. Preserve all pair evidence and exact matcher state/provenance in MAT export;
   compact JSON retains metadata/counts but omits image-sized arrays as it does
   for existing matchers.
7. Verify no model process, GPU allocation, temporary private array, callback,
   or owned window leaks after normal close, cancellation, worker crash, viewer
   deletion, or MATLAB class reset.

Required artifacts:

- named UI/configuration integration, operator documentation, workflow tests,
  target-hardware evidence, and updated evaluation report.

Exit criteria:

- the operator can distinguish scene preparation, model loading, current pair,
  inference, postprocessing, reconstruction, and fusion;
- a ten-pair warm run meets or has an explicitly accepted exception to the
  frozen time gate;
- cancel and close have bounded, truthful behavior; and
- existing SGM/template/custom workflows and CPU-only launch remain unchanged.

### UFM-7 — Final Support Decision And Repository Reconciliation

Status: blocked by UFM-6 or an earlier stop decision.

Tasks:

1. Update the evaluation report with exact results, unresolved risks, license
   disposition, supported hosts, installation burden, and operator guidance.
2. Record one final state: `rejected`, `evaluation-only`, `experimental`, or
   `supported-optional`.
3. For `rejected` or `evaluation-only`, remove incomplete MATLAB/UI paths and
   retain only reproducible harness/evidence that has ongoing value.
4. For `experimental` or `supported-optional`, document environment creation,
   offline checkpoint placement/verification, capability checks, failure
   recovery, upgrade procedure, and how to remove the integration completely.
5. Review all licenses and notices. Confirm no weights, upstream source copy,
   environment, private bundle, raw flow, or identifying artifact is staged.
6. Run Code Analyzer on every changed MATLAB file and run the six authoritative
   fresh-class groups in separate MATLAB sessions as defined in
   `docs/test_suite_grouping.md`. Run the hardware-gated UFM suite separately
   and never make it a requirement for the ordinary CPU baseline.
7. Update `docs/project_status.md`, `docs/dense_matcher_sdk.md`,
   `docs/surface_workbench.md`, operator guidance, and the SRS only for the
   capabilities actually accepted.

Exit criteria:

- documentation, code, tests, runtime capability, license, and the final
  support label agree; and
- the worktree contains no private or redistributable checkpoint material.

## Implementation Commit Boundaries

If the gates authorize implementation, prefer these coherent commits:

1. UFM-0/UFM-1: governance record, ignored artifact boundary, pinned standalone
   environment, harness, and T0 contract tests;
2. UFM-2 through UFM-4: exported-pair, source-map, geometry, baseline evidence,
   and the explicit adapter decision;
3. UFM-5: headless matcher/worker adapter with fake-worker and target-hardware
   conformance evidence; and
4. UFM-6/UFM-7: named Workbench integration, operator lifecycle, final support
   decision, documentation, and full validation.

Do not create a MATLAB adapter commit before the UFM-4 decision. Do not combine
model acquisition, private evidence, or local environment files with any Git
commit.

## Risk Register

| Risk | Evidence needed | Mitigation or stop condition |
| --- | --- | --- |
| Checkpoint license incompatible with intended use | Written UFM-0 determination | Stop; do not download, redistribute, or integrate the checkpoint. |
| License metadata disagreement | Rights-holder/legal clarification | Apply stricter noncommercial/share-alike interpretation until resolved. |
| Domain shift from natural RGB training to Sightline single-band imagery | T1/T2 correspondence and geometry results | Retain replicated-band policy only if it passes; otherwise stop before changing the RGB request contract. |
| GPU-only upstream path | Target CUDA evidence | Support only qualified CUDA hosts; do not advertise CPU/MPS. |
| Large dependency and checkpoint footprint | Locked environment size/startup evidence | Keep external/optional, preinstall offline, load once, and report exact requirements. |
| MATLAB/Python transfer dominates runtime | UFM-1 versus UFM-5 timing breakdown | Use persistent worker and bounded binary transfer; stop if bridge loses the accepted performance class. |
| Internal resize loses fine correspondence precision | T0/T1 endpoint and downstream truth metrics | Compare UFM-Base with full-source geometry; consider another checkpoint only under a new approved gate. |
| Covisibility is poorly calibrated | Threshold sensitivity and occlusion truth | Treat as score, combine with explicit masks/cycle/geometry, and avoid probability claims. |
| Dropped unmap/padding validity | Border/aspect T0 fixtures | Independently reject invalid support before source mapping. |
| No observation covariance | Downstream uncertainty audit | Leave covariance unavailable; do not synthesize one from covisibility. |
| Reverse checking doubles cost | Forward/reverse quality and timing evidence | Make it an explicit policy; use only if material quality gain justifies cost. |
| Dense output overwhelms downstream work | Raw/eligible/selected accounting | Deterministic spatial selection after inference; cap does not change model runtime. |
| UI claims unsupported search/execution | Preflight/provenance tests | Use named `learnedGlobal`, exact device, model, and executed-policy provenance. |
| Worker crash or cancellation leaks GPU/process state | Repeated failure/teardown tests | Out-of-process isolation, bounded termination, clean reload, and explicit failure state. |
| Comparison flatters UFM through a broken baseline | Executed baseline provenance | Invalidate mismatched runs and resolve the confound before scoring. |

## Upstream References

- UFM repository, setup, API, runtime table, and license:
  <https://github.com/UniFlowMatch/UFM>
- UFM-Base model card and model metadata:
  <https://huggingface.co/infinity1096/UFM-Base>
- UFM paper, arXiv version 2:
  <https://arxiv.org/abs/2506.09278v2>
- Upstream Python package declaration:
  <https://github.com/UniFlowMatch/UFM/blob/ff78d6c3db807c91578acccb58ee67d4394d5e5f/pyproject.toml>
- Upstream prediction and resize/unmap implementation:
  <https://github.com/UniFlowMatch/UFM/blob/ff78d6c3db807c91578acccb58ee67d4394d5e5f/uniflowmatch/models/base.py>
- MATLAB out-of-process Python execution behavior:
  <https://www.mathworks.com/help/matlab/matlab_external/out-of-process-execution-of-python-functionality.html>
