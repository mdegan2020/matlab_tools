function mustBeRange2(x)
arguments
    x double
end
if ~isequal(size(x),[1 2]) || any(~isfinite(x)) || x(1) >= x(2)
    error("RSM:Range2","Input must be a finite increasing 1-by-2 range.");
end
end
