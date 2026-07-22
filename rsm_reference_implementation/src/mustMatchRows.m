function mustMatchRows(b,a)
arguments
    b double
    a double
end
if size(b,1) ~= size(a,1)
    error("RSM:PairCount","Paired arrays must have the same number of rows.");
end
end
