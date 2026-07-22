function mustBeIncreasing(x)
arguments
    x double
end
if numel(x)<2 || any(~isfinite(x(:))) || any(diff(x(:))<=0)
    error("RSM:Increasing","Axis values must be finite and strictly increasing.");
end
end
