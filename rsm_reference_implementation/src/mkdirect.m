function q = mkdirect(g,j,c,d,deg,lam,a)
arguments
    g {mustBePts3}
    j (:,2,6) double {mustBeFinite}
    c (6,6) double {mustBeFinite}
    d (1,1) RsmDom
    deg (1,1) double {mustBeNonnegative,mustBeInteger} = 2
    lam (1,1) double {mustBeNonnegative} = 1e-12
    a = []
end
z=propcov(j,c); n=size(g,1); y=zeros(n,3);
for i=1:n
    y(i,:)=[z(1,1,i) z(1,2,i) z(2,2,i)];
end
e=rsmexp(deg); [cf,st]=fitlin(d.nx(g),y,e,lam);
q=RsmDir(d,e,cf,a,st);
end
