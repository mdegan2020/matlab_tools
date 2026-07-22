function mustBeCov2N(c)
arguments
    c double
end
if ndims(c) > 3 || size(c,1) ~= 2 || size(c,2) ~= 2 || any(~isfinite(c(:)))
    error("RSM:Cov2N","Input must be a finite 2-by-2-by-N covariance array.");
end
end
