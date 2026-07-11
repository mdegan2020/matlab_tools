# Backend App Workflow

This workflow exports the current interactive viewer state as a backend job,
validates that the job resolves without rendering, and then runs the backend.
Backend rendering uses the full scene image data and output grid; viewer preview
pyramids and tiled display surfaces are not part of backend processing.

```matlab
app = runProjectionViewerPrototype("test_data/10.tif");
```

After aligning layers in the app:

```matlab
jobOptions = struct();
jobOptions.RenderOptions = struct(OutputSize=[512 512], TileSize=[128 128]);
jobOptions.Execution = struct(Mode="serial");
jobOptions.Output = struct( ...
    Directory="backend_output", ...
    WriteFiles=true, ...
    Formats=["png", "tiff"]);

job = app.exportBackendJob(jobOptions);
ProjectionBackendJob.write("backend_job.json", job);
```

To run alignment headlessly before rendering, include an alignment block in the
job. The request chooses the layers and single-band analysis inputs used for
matching; the solved correction state is applied to the scene, so rendering still
uses every band in each source image.

```matlab
job.Alignment = struct();
job.Alignment.Enabled = true;
job.Alignment.Request = struct( ...
    LayerIndices=[1 2], ...
    ReferenceLayerIndex=1, ...
    AnalysisBands=[1 1]);
job.Alignment.RenderOptions = struct(OutputSize=[512 512]);
job.Alignment.WriteUpdatedViewerState = true;
job.Alignment.WriteDiagnostics = true;
job.Alignment.ViewerStateFileName = "aligned_viewer_state.json";
job.Alignment.DiagnosticsFileName = "alignment_diagnostics.json";

ProjectionBackendJob.write("backend_alignment_job.json", job);
```

Validate the saved job without rendering:

```matlab
validation = validateProjectionBackendJob("backend_job.json");
```

Run the backend:

```matlab
result = ProjectionBackendProcessor.run("backend_job.json");
```

Validation and render results include a JSON-safe `RenderPlan` summary. It
records the output size, interpolation policy, visible layers, numerical mode,
mesh/topology preparation counts, and effective GPU decision. The actual
runtime plan is compiled once per invocation, reused by all tiles, and is never
written into the job or scene payload.

```matlab
validation.RenderPlan
result.RenderPlan
result.Readback.RenderPlan
```

The default numerical mode is `fullSourceInverseWarp`: sparse geometry maps
each output pixel to a continuous source row/column coordinate, then every band
is sampled from full `layer.Image` with the requested nearest or bilinear
policy. Preview pyramids, display textures, display tiles, and alignment working
images are not plan inputs. The previous sparse-intensity renderer is available
for explicit compatibility comparisons:

```matlab
jobOptions.RenderOptions.NumericalMode = ...
    "sparseIntensityScatteredInterpolant";
```

Use `backend_inverse_warp_evaluation` to render both numerical modes over one
deterministic output grid and report per-band and validity-mask differences.
Alignment working images now independently default to full-source inverse warp
after the Reliability Pack 2 truth-aware comparison. They remain bounded
analysis products and are never backend radiometric inputs.

An alignment-enabled run reports `result.Status` as `"aligned"` or
`"stateAppliedAligned"`, stores the alignment summary under `result.Alignment`,
and writes the aligned viewer state plus alignment diagnostics when output file
writing is enabled.

Use thread-pool execution only with MATLAB's thread pool:

```matlab
jobOptions.Execution = struct(Mode="threads");
```

GPU requests are optional. On systems without compatible GPU support, the
backend falls back to CPU and records the effective GPU status in `GpuInfo`.

```matlab
jobOptions.RenderOptions.UseGPU = true;
```

## Large-output status

Backend Performance Packs 0-4 are complete: one runtime render plan is compiled
per job, backend radiometry defaults to full-source inverse warp, and serial
TIFF products can be streamed without retaining output-wide image, mask, or
query-coordinate arrays. Thread mode submits at most
`Execution.MaximumInFlightTiles` through `parfeval`, consumes completed tiles
incrementally, and writes indexed TIFF tiles on the client.

Use the bounded path explicitly for large output:

```matlab
jobOptions.RenderOptions.TileSize = [256 256];
jobOptions.RenderOptions.IncludeQueryCoordinates = false;
jobOptions.Execution = struct( ...
    Mode="threads", ...
    MaximumInFlightTiles=4);
jobOptions.Output = struct( ...
    Directory="backend_output", ...
    WriteFiles=true, ...
    Formats="tiff", ...
    InMemoryPolicy="never", ...
    MaximumInMemoryPixels=16000000, ...
    OutputClass="uint16", ...
    RadiometricScale=1, ...
    RadiometricOffset=0, ...
    FillValue=0, ...
    OutOfRangePolicy="clip");
```

`InMemoryPolicy="auto"` streams writing jobs above
`MaximumInMemoryPixels`; `"always"` requires the planned output to fit that
ceiling, and `"never"` requires file output. Streaming currently accepts only
serial or thread execution, TIFF-only formats, tile dimensions that are
multiples of 16, and normalized `[0,1]` radiometry. Only
`parpool("threads")` is accepted. Streamed masks use TIFF. PNG remains
in-memory. `OutputClass` accepts `uint8`, `uint16`, or TIFF-only `single`.
Stored normalized values reconstruct physical renderer values as
`storedNormalized * RadiometricScale + RadiometricOffset`; this contract and
the fill/clipping policy are written to metadata. Optional
`RenderOptions.WorkingPrecision="single"` casts tile image/coordinate products
before retention or worker transfer; the tested tolerance versus double is
`1e-6`. Pack 5 owns file-backed source regions. See
`docs/project_status.md` and `docs/performance_optimization_workplan.md`.
