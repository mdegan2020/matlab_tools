# Viewer Performance Pack 8 Raster Preview Decision

## Decision

Retain the CPU single-raster path as an optional diagnostic and architecture
prototype. Do not make it the production viewer default yet.

The prototype confirms that a viewport-sized numeric composite can reduce the
graphics object count to one opaque image and can make some state-only changes,
especially visibility, inexpensive. It also confirms the principal risk from
the workplan: a camera change currently requires rebuilding inverse maps,
resampling every compiled layer raster, compositing, and uploading a new
texture. That cost is far above the already-optimized surface camera path on
the local workstation.

The production viewer therefore remains on differential tiled surfaces. The
prototype stays callable through:

```matlab
plan = app.compileRasterPreview(options);
result = app.renderRasterPreview(options);
```

The pure implementation is split between:

```text
ProjectionViewportGrid
ProjectionRasterPreviewRenderer
```

Both return plain numeric structs. They contain no graphics handles, are
CPU-complete, and are runtime-only. The raster path consumes either normalized
`DisplayTexture` data or, for small diagnostic comparisons, a display-normalized
view of the full source. It is not used by backend processing, export, or
readback.

## Prototype Semantics

`ProjectionViewportGrid` converts an orthographic viewer camera state into a
viewport-sized screen grid and intersects parallel camera rays with a reference
projection plane. It can also express that grid as a
`ProjectionReadbackRenderer` output grid. This makes the viewport definition
shared and testable rather than deriving it from graphics pixels.

`ProjectionRasterPreviewRenderer.compile` performs the geometry-dependent work:

1. Build each layer's current projection mesh.
2. Intersect viewport rays with that layer's projection plane.
3. Invert the sampled projection footprint to source row/column positions.
4. Sample normalized display data into one viewport-sized RGB raster per layer.

`ProjectionRasterPreviewRenderer.composite` then applies current visibility,
alpha, layer order, and alpha or red/blue-anaglyph blend semantics without
rebuilding the inverse maps. All layers are compiled, including layers hidden
at compile time, so a visibility toggle can reuse the plan. Camera, projection,
OPK, or projection-offset changes invalidate the geometry-dependent plan.

The prototype deliberately does not add a second production rendering mode to
the app. `scripts/viewer_raster_preview_evaluation.m` owns the experimental
one-image presentation and actual surface-versus-raster frame capture.

## Local Measurements

The decision-scale run used two `480 x 640` normalized single-band synthetic
layers, a `300 x 400` output raster, six iterations, CPU bilinear sampling, and
the actual programmatic viewer surface frame. Results are local measurements,
not portable acceptance thresholds.

| Measurement | Surface viewer | Raster prototype |
| --- | ---: | ---: |
| Graphics objects carrying imagery | 2 transparent surfaces | 1 opaque image |
| Estimated retained numeric graphics/plan data | 7.09 MiB | 4.35 MiB |
| Alpha median | 3.17 ms | 4.10 ms |
| Visibility median | 19.64 ms | 2.16 ms |
| Twist/camera median | 3.00 ms | 91.58 ms |
| Crosshair median | 24.75 ms | 1.76 ms |

Initial raster plan compilation took about `93.5 ms`. The raster camera result
is therefore roughly thirty times slower than the surface camera update in this
fixture. Raster visibility was about nine times faster, while alpha was mildly
slower once numeric compositing, texture assignment, and `drawnow` were all
included. The opaque raster also reduced transparency repaint cost during the
crosshair micro-interaction, but it did not offset the camera penalty.

Visual comparisons over pixels valid in both raster and exact paths reported:

| Comparison | Mean absolute error | 95th-percentile absolute error |
| --- | ---: | ---: |
| Raster preview versus exact readback | 0.0241 | 0.0554 |
| Actual surface frame versus raster preview | 0.0527 | 0.1506 |

Values are in normalized display units. The evaluation fixture intentionally
uses a stride-16 surface mesh, so the raster/exact difference includes sparse
geometry inversion and display interpolation. A separate deterministic
stride-1 affine unit fixture agrees with exact readback to less than `2e-4`
maximum absolute error. Actual surface-frame comparison additionally includes
MATLAB renderer interpolation, alpha compositing, capture, and resize effects.

Reproduce the measurement with:

```matlab
summary = viewer_raster_preview_evaluation;
```

The script can write MAT, JSON, and PNG comparison artifacts under
`artifacts/viewer_performance`; that directory remains a local evaluation
output, not a committed source of truth.

## Why The Surface Path Remains Default

- Twist, pan, and zoom are core viewer interactions. The raster path's current
  geometry-dependent compile is well outside an interactive frame budget.
- The existing surface path now has latest-state scheduling, LOD hysteresis,
  cached visibility geometry, differential surface reuse, targeted geometry
  invalidation, scalar grayscale tiles, and explicit object/texture budgets.
- A raster default would introduce a second cache/invalidation architecture and
  change interpolation appearance while delivering a mixed performance result.
- The prototype currently compiles viewport-sized layer rasters eagerly. More
  visible layers increase CPU work and retained plan memory linearly.
- Keeping the prototype optional preserves a useful preview/exact diagnostic
  without changing established viewer behavior.

## Conditions For Reconsideration

Reconsider a production raster mode only after profiling demonstrates all of
the following on representative 100-150 MP Windows workstations:

1. Camera-dependent inverse maps are reused or rebuilt within the interactive
   latency budget at the chosen viewport resolution.
2. Background/latest-state rendering can discard stale frames without blocking
   the UI, while the complete serial CPU path remains available.
3. File-backed preview LOD sampling avoids full-source display allocations.
4. Alpha, visibility, crosshair, twist, pan, zoom, OPK, and projection-offset
   scenarios all beat or materially simplify the surface path.
5. Surface/raster and raster/exact differences are acceptable on real geometry,
   seams, oblique planes, arbitrary bands, invalid borders, and alignment
   overlays.

No GPU requirement should be introduced. Any future parallel CPU experiment
must use only `parpool("threads")` and retain a deterministic serial path.
