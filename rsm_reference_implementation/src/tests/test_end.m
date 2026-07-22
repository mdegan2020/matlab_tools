function test_end()
arguments
end
[s,cfg]=toy_setup(); p=make_product(s,cfg);
assert(p.rep.poly_pass);
assert(p.rep.grid_pass || p.rep.grid_max < 0.2);
assert(~isempty(p.adj) && ~isempty(p.dir));
assert(p.rep.mc.med < 0.35);
end
