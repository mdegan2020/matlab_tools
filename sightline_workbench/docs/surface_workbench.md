# Surface Workbench And 3-D Viewer

B6 provides a separate floating Surface Workbench for inspecting B5 multi-ray
and S6 fusion products. It does not add controls to the main projection viewer,
and it does not make graphics state part of any scientific value.

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
  products until S7/B7 supplies them.

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

Construct the catalog, then launch the independent workbench:

```matlab
catalog = ProjectionSurfaceProductCatalog.create( ...
    multiRayPointSet, {hardVoxelResult, gaussianResult});
surfaceApp = ProjectionSurfaceWorkbenchApp(catalog);
```

The Workbench includes image-network and pass selection, pair/dense/search
settings, processing/uncertainty/fusion/DEM/output controls, a product table,
diagnostics, relative cost and memory estimates, progress, cooperative cancel,
and a lazy **Open 3-D viewer** action. `setProgress`, `requestCancel`, and
`isCancellationRequested` are runtime hooks suitable for the S6 callback
contract; they are absent from `modelState`.

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

Run the six authoritative fresh-class groups in separate MATLAB MCP calls as
documented in `test_suite_grouping.md`; never use the aggregate suite in one
MCP call.
