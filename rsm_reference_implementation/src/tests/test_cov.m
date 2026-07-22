function test_cov()
arguments
end
[s,cfg]=toy_setup(); d=mkdom(s,cfg); [g,~]=mksamp(s,d,[5 5 3]);
[c,st]=condcov(s.c); assert(min(eig(c)) >= -1e-12); assert(st.clip>=0);
j=fdjac(s,g,cfg.dq); ci=propcov(j,c);
for i=1:size(ci,3), assert(min(eig(ci(:,:,i))) >= -1e-8); end
[m,cp,bs]=redbasis(j,c,cfg.kmax,cfg.ekeep);
assert(size(m,1)==6 && size(m,2)==bs.k && isequal(cp,eye(bs.k)));
a=fitadj(g,j,m,cp,d,2,cfg.lam);
ca=a.imageCov(g(1:10,:));
for i=1:size(ca,3), assert(min(eig(ca(:,:,i))) >= -1e-8); end
q=mkdirect(g,j,c,d,2,cfg.lam); cd=q.eval(g(1:10,:));
for i=1:size(cd,3), assert(min(eig(cd(:,:,i))) >= -1e-8); end
end
