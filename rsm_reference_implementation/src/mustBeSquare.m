function mustBeSquare(x)
arguments
    x double
end
if size(x,1) ~= size(x,2)
    error("RSM:Square","Input matrix must be square.");
end
end
