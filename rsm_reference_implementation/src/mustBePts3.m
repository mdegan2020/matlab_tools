function mustBePts3(x)
arguments
    x double
end
if size(x,2) ~= 3 || any(~isfinite(x(:)))
    error("RSM:Pts3","Input must be a finite N-by-3 array.");
end
end
