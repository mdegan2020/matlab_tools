function mustMatchCovCount(c,g)
arguments
    c double
    g double
end
if size(c,3) ~= size(g,1)
    error("RSM:DirectCount","Ground and covariance sample counts differ.");
end
end
