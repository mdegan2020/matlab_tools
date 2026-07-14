# Surface Workbench And 3-D Viewer

B6 provides a separate floating Surface Workbench for inspecting B5 multi-ray
and S6 fusion products. RD-5 connects that existing product viewer to the
active scene without making graphics state part of any scientific value. The
Alignment Workbench exposes **Surface Workbench...**, which opens or focuses
one scene-bound Workbench and preselects the active physical pair. The former
direct Selected-pair SGM button has been retired so dense matching, surface
reconstruction, fusion, and 3-D extraction all start in the appropriate bench.

`ProjectionSurfaceWorkbenchRunner` is the graphics-independent execution
boundary. It consumes fresh pair working images and full-source coordinate/ray
links prepared by the viewer, uses the public dense-matcher and surface-fusion
registries, and returns a complete catalog plus portable run evidence. The
Workbench has an explicit Run/Cancel lifecycle; its processing controls are no
longer inert selectors. The original programmatic catalog-only constructor
remains supported for inspection workflows and intentionally disables Run.

## Product boundary

`ProjectionSurfaceProductCatalog.create` adapts one authoritative
`ProjectionMultiRayPointSet`, zero or more normalized S6 fusion results, and
optional mesh/grid values into a versioned graphics-independent catalog. The
catalog distinguishes:

- raw pairwise points;
- authoritative robust multi-view points;
- a virtual uncertainty-filtered view of the authoritative product;
- fusion-derived point products;
- per-scale sparse voxel evidence;
- optional mesh/TIN and gridded products; and
- explicit unavailable placeholders for DEM, registered, and DEM-difference
  products when no S7/B7 registration result is supplied.

`ProjectionSurfaceProductCatalog.registrationProducts` supplies those three
S7/B7 products from a normalized `ProjectionDemGrid` and a successful or
reviewable registration result. The registered preview keeps full-source links,
adds translation covariance, records point-to-DEM differences, and leaves the
authoritative imagery-only product unchanged.

Every available point keeps stable identity, world coordinates, independent
view/pass counts, residual, uncertainty, conditioning, fusion method,
pair/pass identities, covariance, evidence weight where applicable, and its
full-source observation links. Source intensity is aggregated from the B5 raw
radiometric evidence. The catalog rejects duplicate product identities,
runtime handles/callbacks, malformed point/link values, inconsistent mesh
faces/vertices, and inconsistent grid cells/point identities.

The authoritative B5 robust point product remains unchanged. Voxel and other
fusion products remain derived/diagnostic according to the S6/B4 decision.

## Headless model

`ProjectionSurfaceWorkbenchModel` owns the portable selection state and the
complete catalog. Its configuration covers selected views/passes, pair
schedule, dense method, geometry search, processing stage, maximum
uncertainty, fusion product, DEM-registration mode, output/comparison products,
color mode, decimation limit, and uncertainty-glyph bound.

The model exposes:

- product summaries and per-product counts;
- pair/multi-view evidence statistics;
- relative scheduled-pair work units and byte estimates (explicitly not a
  wall-clock prediction);
- deterministic display payloads and color values; and
- selected-point full-source observation links.

Interactive filtering and decimation create bounded display payloads only.
`CompleteProductRetained=true` records that the catalog still owns the full
product. Mesh/grid payloads fall back to decimated point display when their
native topology cannot be shown completely; the source mesh/grid remains
intact.

## Floating applications

The usual operator path is **Alignment Workbench > Surface Workbench...** after
accepted alignment evidence has been previewed, applied, or manually adjusted.
The viewer builds one request per accepted physical pair and binds a runner.
Programmatic catalog inspection remains available:

```matlab
catalog = ProjectionSurfaceProductCatalog.create( ...
    multiRayPointSet, {hardVoxelResult, gaussianResult});
surfaceApp = ProjectionSurfaceWorkbenchApp(catalog);
```

The Workbench includes image-network and pass selection; selected, planned,
all-plausible, and explicit pair schedules; SGM, classical template, and
registered custom matchers; geometry-search, consistency, occlusion, CPU/GPU,
observation-cap, pairwise/multi-ray/fusion, uncertainty, DEM, and output
controls; a product table; diagnostics; bounded relative cost/memory estimates;
and a lazy **Open 3-D viewer** action.

Before Run, preflight states the exact views and stable pair IDs, matcher and
options, rectification state, search bounds, consistency/occlusion policy,
requested execution path and CPU fallback, processing/fusion stage, bounded
input size, and observation cap. Run cooperatively accepts cancellation between
stages and through matcher callbacks. Outcomes distinguish `succeeded`,
`partial`, `empty`, `cancelled`, `unsupported`, and `failed`; they retain exact
pair/method/options/fallback provenance and counts for matcher states,
correspondences, association, reconstructed points, conditioning, fusion, and
uncertainty availability.

**Open evidence** shows the retained moving/reference analysis images,
validity/overlap masks, disparity diagnostic, matcher score/confidence,
ray-separation distribution, and reconstructed-height distribution. MAT export
retains the complete portable run and intermediate evidence. Compact JSON
retains metadata, counts, states, policies, and provenance while intentionally
omitting image-sized evidence arrays. Run state, progress, cancellation,
figures, callbacks, and evidence windows remain runtime-only.

The initial catalog is a deliberately permissive sparse-bootstrap preview so a
weak scene can still open for diagnosis. It is not evidence that a dense run
passed: every actual Run uses the selected matcher and configured association,
conditioning, reconstruction, and fusion gates. No smoothing, hole filling, or
forced DEM intersection is used to manufacture a surface.

`ProjectionSurface3DViewer` renders point-cloud, voxel, triangle-mesh, and grid
representations. It can compare any two available products and color by source
intensity, elevation, independent view/pass count, residual, uncertainty,
conditioning, fusion method, pair/pass identity, DEM difference, or evidence
weight as applicable. Selecting a displayed point publishes all contributing
full-source `[column,row]` observations. Uncertainty is rendered as the three
principal covariance axes for the selected point only; it is never stored in
the catalog.

Closing the Workbench deletes its owned 3-D viewer. Closing only the viewer
allows the Workbench to create a fresh viewer later. All figures, axes,
controls, callbacks, render objects, and glyph handles are runtime-only.

## Validation and suite ownership

`ProjectionSurfaceWorkbenchModelTest` covers adapters, strict validation,
source links, uncertainty filtering, deterministic decimation/coloring,
mesh/grid behavior, statistics/costs, and portable state. It belongs to
`backendSurface`.

`ProjectionSurfaceWorkbenchWorkflowTest` covers the responsive floating layout,
selection/progress/cancel state, point/voxel/mesh/grid rendering, comparison,
source-link selection, bounded glyphs, full-result preservation, and owned
window lifecycle. It belongs to `viewerPresentationWorkflows`.

`ProjectionSurfaceWorkbenchRunnerTest` covers exact preflight/fallback,
scene-bound Run/Cancel, SGM/template/custom matcher identity, retained evidence,
explicit failure states, catalog replacement/export, explicit scheduling, and
a deterministic five-image/all-ten-pair multi-ray/fusion run. Existing dense
truth and fusion audits remain the numerical truth owners. The runner test
belongs to `backendSurface`.

Representative private imagery remains the external operator-acceptance gate
for calling the output practically useful; the repository claims structural,
provenance, lifecycle, and synthetic-truth coverage, not universal real-image
quality.

Run the six authoritative fresh-class groups in separate MATLAB MCP calls as
documented in `test_suite_grouping.md`; never use the aggregate suite in one
MCP call.
