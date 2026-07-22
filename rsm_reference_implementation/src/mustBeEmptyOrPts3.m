function mustBeEmptyOrPts3(g)
arguments
    g double
end
if ~(isempty(g) || (size(g,2)==3 && all(isfinite(g(:)))))
    error("RSM:EmptyOrPts3","Initial ground coordinates must be empty or a finite N-by-3 array.");
end
end
