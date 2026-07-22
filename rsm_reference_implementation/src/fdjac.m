function j = fdjac(s,g,dq)
arguments
    s (1,1) Sens
    g {mustBePts3}
    dq (1,6) double {mustBePositive}
end
n=size(g,1); j=zeros(n,2,6);
for k=1:6
    q=zeros(1,6); q(k)=dq(k);
    up=s.groundToImagePerturbed(g,q);
    um=s.groundToImagePerturbed(g,-q);
    j(:,:,k)=(up-um)/(2*dq(k));
end
end
