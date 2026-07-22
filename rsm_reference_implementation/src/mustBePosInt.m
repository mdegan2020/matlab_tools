function mustBePosInt(x)
arguments
    x double
end
if ~isscalar(x) || ~isfinite(x) || x < 1 || x ~= floor(x)
    error("RSM:PosInt","Input must be a positive integer scalar.");
end
end
