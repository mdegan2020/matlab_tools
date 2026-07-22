function mustBeSize2(x)
arguments
    x double
end
if ~isequal(size(x),[1 2]) || any(~isfinite(x)) || any(x <= 0) || any(x ~= floor(x))
    error("RSM:Size2","Image size must be a positive integer 1-by-2 vector.");
end
end
