# MATLAB Tools

Small, self-contained MATLAB utilities for use in other projects.

## Tools

### `estimateVerticalScaleDifference`

Estimates a small vertical-only scale mismatch between two already-registered
remote sensing images. Inputs can be image arrays or filenames accepted by
`imread`.

```matlab
r = estimateVerticalScaleDifference("time1.tif", "time2.tif");
fprintf("Vertical scale moving-to-fixed: %.6f (%.3f%%)\n", ...
    r.scaleMovingToFixed, r.percentDifference);
```

`scaleMovingToFixed` is the factor to apply to the second image's row dimension
to match the first image. A value of `1.020000` means the moving image should be
stretched vertically by 2 percent.

Run `demo_estimateVerticalScaleDifference` for a synthetic sanity check.
