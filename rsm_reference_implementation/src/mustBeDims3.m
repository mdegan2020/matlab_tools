function mustBeDims3(x)
arguments
    x double
end
if ~isequal(size(x),[1 3]) || any(~isfinite(x)) || any(x < 2) || any(x ~= floor(x))
    error("RSM:Dims3","Sampling and grid dimensions must be integer 1-by-3 vectors with values at least two.");
end
end
