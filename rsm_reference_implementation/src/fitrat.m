function [a,b,st] = fitrat(x,y,cfg)
arguments
    x {mustBePts3}
    y (:,1) double {mustBeFinite}
    cfg (1,1) RsmCfg
end
e=rpc00bexp(); t=pterm(x,e); n=size(t,2);
w=ones(size(y)); z=zeros(2*n-1,1);
for k=0:cfg.irls
    q=[t -y.*t(:,2:end)];
    sw=sqrt(w);
    qw=q.*sw; yw=y.*sw;
    z=(qw.'*qw+cfg.lam*eye(size(q,2)))\(qw.'*yw);
    a=z(1:n); b=[1;z(n+1:end)];
    yp=(t*a)./(t*b);
    r=yp-y;
    sc=1.4826*median(abs(r-median(r)))+eps;
    zc=abs(r)/(cfg.hub*sc);
    w=ones(size(r)); jj=zc>1; w(jj)=1./zc(jj);
end
yp=(t*a)./(t*b); r=yp-y;
st.rms=sqrt(mean(r.^2)); st.mx=max(abs(r)); st.den=min(abs(t*b));
end
