function [m,cp,st] = redbasis(j,c,kmax,ekeep)
arguments
    j (:,2,6) double {mustBeFinite}
    c (6,6) double {mustBeFinite}
    kmax (1,1) double {mustBePosInt} = 6
    ekeep (1,1) double {mustBeGreaterThan(ekeep,0),mustBeLessThanOrEqual(ekeep,1)} = 0.999
end
n=size(j,1); a=zeros(2*n,6);
for i=1:n
    a(2*i-1:2*i,:)=reshape(j(i,:,:),2,6);
end
[v,d]=eig((c+c.')/2,"vector");
l=v*diag(sqrt(max(d,0)));
[~,s,w]=svd(a*l,"econ");
sv=diag(s); en=sv.^2;
if sum(en) <= eps
    error("RSM:ZeroSensitivity","Pose covariance has no observable image response.");
end
k=find(cumsum(en)/sum(en)>=ekeep,1);
k=min([k kmax size(w,2)]);
m=l*w(:,1:k); cp=eye(k);
st.sv=sv; st.k=k; st.keep=sum(en(1:k))/sum(en);
st.res=sqrt(sum(en(k+1:end))/sum(en));
end
