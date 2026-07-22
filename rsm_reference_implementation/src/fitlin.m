function [c,st] = fitlin(x,y,e,lam)
arguments
    x {mustBePts3}
    y double {mustBeFinite}
    e (:,3) double {mustBeNonnegative,mustBeInteger}
    lam (1,1) double {mustBeNonnegative} = 1e-12
end
a=pterm(x,e);
c=(a.'*a+lam*eye(size(a,2)))\(a.'*y);
r=a*c-y;
st.rms=sqrt(mean(r.^2,1)); st.mx=max(abs(r),[],1);
end
