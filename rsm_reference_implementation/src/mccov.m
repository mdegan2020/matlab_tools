function st = mccov(s,g,c,j,n,seed)
arguments
    s (1,1) Sens
    g {mustBePts3}
    c (6,6) double {mustBeFinite}
    j (:,2,6) double {mustBeFinite}
    n (1,1) double {mustBePosInt} = 300
    seed (1,1) double {mustBeNonnegative,mustBeInteger} = 7
end
rng(seed,"twister");
[v,d]=eig((c+c.')/2,"vector"); l=v*diag(sqrt(max(d,0)));
u0=s.groundToImage(g); z=zeros(size(g,1),2,n);
for k=1:n
    q=(l*randn(6,1)).';
    z(:,:,k)=s.groundToImagePerturbed(g,q)-u0;
end
cm=zeros(2,2,size(g,1));
for i=1:size(g,1)
    a=squeeze(z(i,:,:)).'; cm(:,:,i)=cov(a,1);
end
cl=propcov(j,c); er=zeros(size(g,1),1);
for i=1:size(g,1)
    er(i)=norm(cm(:,:,i)-cl(:,:,i),"fro")/max(norm(cl(:,:,i),"fro"),eps);
end
st.c=cm; st.lin=cl; st.med=median(er); st.mx=max(er); st.n=n;
end
