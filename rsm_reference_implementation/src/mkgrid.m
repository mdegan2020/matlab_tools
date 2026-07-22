function q = mkgrid(s,d,cfg)
arguments
    s (1,1) Sens
    d (1,1) RsmDom
    cfg (1,1) RsmCfg
end
n=cfg.ng; it=0;
while true
    a=linspace(d.gl(1),d.gh(1),n(1));
    b=linspace(d.gl(2),d.gh(2),n(2));
    h=linspace(d.gl(3),d.gh(3),n(3));
    [aa,bb,hh]=ndgrid(a,b,h);
    g=[aa(:) bb(:) hh(:)]; u=s.groundToImage(g);
    ok=all(isfinite(u),2);
    r=reshape(u(:,1),n); c=reshape(u(:,2),n); ko=reshape(ok,n);
    z=RsmGrid(d,a(:),b(:),h(:),r,c,ko,struct());
    [mx,rmsv]=griderr(s,z);
    if mx <= cfg.gtol || prod(2*n-1) > cfg.gmax
        st.mx=mx; st.rms=rmsv; st.n=n; st.it=it;
        q=RsmGrid(d,a(:),b(:),h(:),r,c,ko,st);
        return
    end
    n=2*n-1; it=it+1;
end
end

function [mx,rmsv] = griderr(s,q)
a=(q.a(1:end-1)+q.a(2:end))/2;
b=(q.b(1:end-1)+q.b(2:end))/2;
h=(q.h(1:end-1)+q.h(2:end))/2;
[aa,bb,hh]=ndgrid(a,b,h);
g=[aa(:) bb(:) hh(:)];
u0=s.groundToImage(g); u1=q.groundToImage(g);
r=vecnorm(u1-u0,2,2); r=r(isfinite(r));
if isempty(r), mx=Inf; rmsv=Inf; else, mx=max(r); rmsv=sqrt(mean(r.^2)); end
end
