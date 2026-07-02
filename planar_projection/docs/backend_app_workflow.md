# Backend App Workflow

This workflow exports the current interactive viewer state as a backend job,
validates that the job resolves without rendering, and then runs the backend.

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

Validate the saved job without rendering:

```matlab
validation = validateProjectionBackendJob("backend_job.json");
```

Run the backend:

```matlab
result = ProjectionBackendProcessor.run("backend_job.json");
```

Use thread-pool execution only with MATLAB's thread pool:

```matlab
jobOptions.Execution = struct(Mode="threads");
```

GPU requests are optional. On systems without compatible GPU support, the
backend falls back to CPU and records the effective GPU status in `GpuInfo`.

```matlab
jobOptions.RenderOptions.UseGPU = true;
```
