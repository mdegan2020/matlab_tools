function d = mkdom(s,cfg)
arguments
    s (1,1) Sens
    cfg (1,1) RsmCfg
end
nr=cfg.im(1); nc=cfg.im(2);
ur=[0 nr-1 0 nc-1];
u=[ur(1) ur(3); ur(1) ur(4); ur(2) ur(4); ur(2) ur(3)];
h=[repmat(cfg.h(1),4,1); repmat(cfg.h(2),4,1)];
v=s.imageToGround([u;u],h);
ok=all(isfinite(v),2);
if ~all(ok)
    error("RSM:DomainProjection","Image corner projection failed while building the domain.");
end
gl=min(v,[],1); gh=max(v,[],1);
gl(3)=cfg.h(1); gh(3)=cfg.h(2);
ui=[(ur(1)+ur(2))/2 (ur(3)+ur(4))/2];
gr=s.imageToGround(ui,mean(cfg.h));
d=RsmDom(gl,gh,ur,v,gr,ui);
end
