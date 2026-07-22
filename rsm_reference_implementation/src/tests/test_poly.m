function test_poly()
arguments
end
[s,cfg]=toy_setup();
d=mkdom(s,cfg); p=RsmPoly.fit(s,d,cfg);
[g,u]=mksamp(s,d,cfg.nt);
v=p.groundToImage(g);
assert(max(vecnorm(v-u,2,2)) < 0.05);
g1=p.imageToGround(u(1:20,:),g(1:20,3));
assert(max(vecnorm(g1(:,1:2)-g(1:20,1:2),2,2)) < 1e-7);
end
