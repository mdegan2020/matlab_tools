function mustBePts2(x)
arguments
    x double
end
if size(x,2) ~= 2 || any(~isfinite(x(:)))
    error("RSM:Pts2","Input must be a finite N-by-2 array.");
end
end
