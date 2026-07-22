function test_sensor()
arguments
end
[~,~,pb]=toy_setup();
u=[0 0;0 999;599 0;599 999;217.25 611.75];
h=[0;0;1200;1200;350];
g=pb.imageToGround(u,h);
v=pb.groundToImage(g);
assert(max(vecnorm(v-u,2,2)) < 1e-5);
end
