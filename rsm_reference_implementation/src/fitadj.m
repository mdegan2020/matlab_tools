function a = fitadj(g,j,m,cp,d,deg,lam,id,un)
arguments
    g {mustBePts3}
    j (:,2,6) double {mustBeFinite}
    m double {mustBeFinite}
    cp double {mustBeFinite}
    d (1,1) RsmDom
    deg (1,1) double {mustBeNonnegative,mustBeInteger} = 2
    lam (1,1) double {mustBeNonnegative} = 1e-12
    id string = strings(0,1)
    un string = strings(0,1)
end
n=size(g,1); k=size(m,2); br=zeros(n,k); bc=zeros(n,k);
for i=1:n
    b=reshape(j(i,:,:),2,6)*m;
    br(i,:)=b(1,:); bc(i,:)=b(2,:);
end
e=rsmexp(deg); x=d.nx(g);
[cr,sr]=fitlin(x,br,e,lam); [cc,sc]=fitlin(x,bc,e,lam);
if isempty(id), id="P"+compose("%02d",(1:k).'); end
if isempty(un), un=repmat("1-sigma",k,1); end
st.row=sr; st.col=sc;
a=RsmAdj(d,e,cr,cc,m,cp,id,un,st);
end
