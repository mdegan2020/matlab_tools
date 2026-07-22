classdef RsmGga
    properties (SetAccess=private)
        cfg (1,1) RsmCfg
        q (1,1) RsmGrid
    end

    methods
        function o = RsmGga(cfg,q)
            arguments
                cfg (1,1) RsmCfg
                q (1,1) RsmGrid
            end
            o.cfg=cfg; o.q=q;
        end

        function f = fields(o)
            arguments
                o (1,1) RsmGga
            end
            [g,u,ok]=o.q.nodes(); f=struct();
            f.IID=o.cfg.iid; f.EDITION=o.cfg.ed; f.SECTION_ID=1;
            f.PART_INDEX=1; f.PART_COUNT=1; f.NODE_COUNT=size(g,1);
            f.NODE_G1=g(:,1); f.NODE_G2=g(:,2); f.NODE_H=g(:,3);
            f.NODE_ROW=u(:,1); f.NODE_COL=u(:,2); f.NODE_VALID=ok;
            f.NODE_ORDER="G1_FAST_G2_MIDDLE_H_SLOW";
            f.VALUE_TYPE="ABSOLUTE_IMAGE_COORDINATE";
        end
    end
end
