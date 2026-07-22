function test_grid()
arguments
end
[s,cfg]=toy_setup(); d=mkdom(s,cfg); q=mkgrid(s,d,cfg);
[g,u]=mksamp(s,d,cfg.nt); v=q.groundToImage(g);
assert(max(vecnorm(v-u,2,2)) < 0.2);
[g0,~,ok]=q.nodes();
assert(size(g0,1)==numel(q.a)*numel(q.b)*numel(q.h));
assert(all(ok));
end
