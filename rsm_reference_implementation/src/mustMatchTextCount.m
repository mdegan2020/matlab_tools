function mustMatchTextCount(x,m)
arguments
    x string
    m double
end
if numel(x) ~= size(m,2)
    error("RSM:TextCount","Parameter text count must match the adjustable parameter count.");
end
end
