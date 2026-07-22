function [g,u] = mksamp(s,d,n)
arguments
    s (1,1) Sens
    d (1,1) RsmDom
    n (1,3) double {mustBePositive,mustBeInteger}
end
r=linspace(d.ur(1),d.ur(2),n(1));
c=linspace(d.ur(3),d.ur(4),n(2));
h=linspace(d.gl(3),d.gh(3),n(3));
[rr,cc,hh]=ndgrid(r,c,h);
u=[rr(:) cc(:)];
g=s.imageToGround(u,hh(:));
ok=all(isfinite(g),2);
g=g(ok,:); u=u(ok,:);
end
