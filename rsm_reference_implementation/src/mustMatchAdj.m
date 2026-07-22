function mustMatchAdj(cp,cr,cc,m,e)
arguments
    cp double
    cr double
    cc double
    m double
    e double
end
k=size(m,2);
if size(m,1)~=6 || size(cr,1)~=size(e,1) || size(cc,1)~=size(e,1) || ...
        size(cr,2)~=k || size(cc,2)~=k || ~isequal(size(cp),[k k])
    error("RSM:AdjShape","Adjustment exponent, coefficient, map, and covariance dimensions disagree.");
end
end
