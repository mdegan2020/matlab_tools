function mustMatchGrid(x,a,b,h)
arguments
    x
    a double
    b double
    h double
end
sz=[numel(a) numel(b) numel(h)];
if ~isequal(size(x),sz)
    error("RSM:GridShape","Grid arrays must match the three axis dimensions.");
end
end
