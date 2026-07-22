function mustBeCov6(c)
arguments
    c double
end
ok = isequal(size(c),[6 6]) || (isvector(c) && numel(c) == 6);
if ~ok || any(~isfinite(c(:))) || any(c(:) < 0 & isvector(c))
    error("RSM:Cov6", ...
        "Covariance must be a finite 6-vector of variances or a finite 6-by-6 matrix.");
end
end
