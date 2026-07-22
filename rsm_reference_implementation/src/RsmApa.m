classdef RsmApa
    properties (SetAccess=private)
        cfg (1,1) RsmCfg
        a (1,1) RsmAdj
    end

    methods
        function o = RsmApa(cfg,a)
            arguments
                cfg (1,1) RsmCfg
                a (1,1) RsmAdj
            end
            o.cfg=cfg; o.a=a;
        end

        function f = fields(o)
            arguments
                o (1,1) RsmApa
            end
            f=adjfields(o.cfg,o.a,"PHYSICAL","A");
        end
    end
end
