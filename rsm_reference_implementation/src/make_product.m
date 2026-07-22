function p = make_product(s,cfg)
arguments
    s (1,1) Sens
    cfg (1,1) RsmCfg
end
g=RsmGen(s,cfg);
p=g.build();
end
