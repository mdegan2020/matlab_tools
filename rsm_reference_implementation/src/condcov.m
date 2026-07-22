function [c,st] = condcov(c0,flr)
arguments
    c0 {mustBeCov6}
    flr (1,1) double {mustBeNonnegative} = 1e-12
end
if isvector(c0), c0=diag(c0(:)); end
c0=(c0+c0.')/2;
[v,d]=eig(c0,"vector");
sc=max(max(abs(d)),1);
d1=max(d,flr*sc);
c=v*diag(d1)*v.'; c=(c+c.')/2;
st.e0=d; st.e1=d1; st.clip=sum(d1~=d);
st.rel=norm(c-c0,"fro")/max(norm(c0,"fro"),eps);
end
