function mustMatchG0(g,u)
arguments
    g double
    u double
end
if ~(isempty(g) || (size(g,1)==size(u,1) && size(g,2)==3 && all(isfinite(g(:)))))
    error("RSM:G0Count","Initial ground coordinates must be empty or one finite row per image point.");
end
end
