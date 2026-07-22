function mustMatchAdjParam(p,o)
arguments
    p double
    o RsmAdj
end
if numel(p) ~= size(o.m,2)
    error("RSM:AdjCount","Parameter count does not match the adjustable model.");
end
end
