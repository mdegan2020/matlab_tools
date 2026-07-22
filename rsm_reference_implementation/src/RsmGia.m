classdef RsmGia
    properties (SetAccess=private)
        cfg (1,1) RsmCfg
        q (1,1) RsmGrid
    end

    methods
        function o = RsmGia(cfg,q)
            arguments
                cfg (1,1) RsmCfg
                q (1,1) RsmGrid
            end
            o.cfg=cfg; o.q=q;
        end

        function f = fields(o)
            arguments
                o (1,1) RsmGia
            end
            f=struct(); f.IID=o.cfg.iid; f.EDITION=o.cfg.ed;
            f.NUM_GRID_SECTIONS=1; f.SECTION_ID=1;
            f.G1_ORIGIN=o.q.a(1); f.G2_ORIGIN=o.q.b(1); f.H_ORIGIN=o.q.h(1);
            f.DG1=o.q.a(2)-o.q.a(1); f.DG2=o.q.b(2)-o.q.b(1);
            f.DH=o.q.h(2)-o.q.h(1);
            f.NG1=numel(o.q.a); f.NG2=numel(o.q.b); f.NH=numel(o.q.h);
            f.INTERPOLATION="TRILINEAR";
            f.NODE_ORDER="G1_FAST_G2_MIDDLE_H_SLOW";
            f.DATA_TRE="RSMGGA"; f.DATA_PARTS=1;
            f.GROUND_FRAME="G/H"; f.HEIGHT_DATUM="HAE";
        end
    end
end
