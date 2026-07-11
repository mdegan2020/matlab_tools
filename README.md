# MATLAB Tools

Small MATLAB utilities and workbench-style subprojects for use in other
projects.

## Subprojects

### [Sightline Workbench](sightline_workbench/)

An interactive MATLAB environment for projection geometry, multi-image
visualization, pointing correction, stereo alignment, dense surface exploration,
and full-resolution image-processing workflows. See the
[Sightline Workbench README](sightline_workbench/README.md) for layout, API
conventions, current status, and test instructions.

## Tools

### `estimateVerticalScaleDifference`

Estimates a small vertical-only scale mismatch between two already-registered
remote sensing images. Inputs can be image arrays or filenames accepted by
`imread`.

```matlab
addpath("tools")
r = estimateVerticalScaleDifference("time1.tif", "time2.tif");
fprintf("Vertical scale moving-to-fixed: %.6f (%.3f%%)\n", ...
    r.scaleMovingToFixed, r.percentDifference);
```

`scaleMovingToFixed` is the factor to apply to the second image's row dimension
to match the first image. A value of `1.020000` means the moving image should be
stretched vertically by 2 percent.

Run `tools/demo_estimateVerticalScaleDifference.m` for a synthetic sanity check.
