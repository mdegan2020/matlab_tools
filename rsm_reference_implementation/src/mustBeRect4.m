function mustBeRect4(x)
arguments
    x double
end
if ~isequal(size(x),[1 4]) || any(~isfinite(x)) || x(1)>=x(2) || x(3)>=x(4)
    error("RSM:Rect4","Image rectangle must be [minRow maxRow minCol maxCol] with increasing bounds.");
end
end
