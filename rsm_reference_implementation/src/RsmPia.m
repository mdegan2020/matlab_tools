classdef RsmPia
    properties (SetAccess=private)
        cfg (1,1) RsmCfg
        d (1,1) RsmDom
    end

    methods
        function o = RsmPia(cfg,d)
            arguments
                cfg (1,1) RsmCfg
                d (1,1) RsmDom
            end
            o.cfg=cfg; o.d=d;
        end

        function f = fields(o)
            arguments
                o (1,1) RsmPia
            end
            f=struct(); f.IID=o.cfg.iid; f.EDITION=o.cfg.ed;
            % A single section is selected everywhere, so both section-index
            % functions are the constant one polynomial.
            f.R0=1; f.RX=0; f.RY=0; f.RZ=0; f.RXX=0;
            f.RXY=0; f.RXZ=0; f.RYY=0; f.RYZ=0; f.RZZ=0;
            f.C0=1; f.CX=0; f.CY=0; f.CZ=0; f.CXX=0;
            f.CXY=0; f.CXZ=0; f.CYY=0; f.CYZ=0; f.CZZ=0;
            f.RNIS=1; f.CNIS=1; f.TNIS=1;
            f.RSSIZ=o.cfg.im(1); f.CSSIZ=o.cfg.im(2);
            f.ROW_ORIGIN=o.d.ur(1); f.COL_ORIGIN=o.d.ur(3);
            f.X_OFF=o.d.xo(1); f.Y_OFF=o.d.xo(2); f.Z_OFF=o.d.xo(3);
            f.X_SCALE=o.d.xs(1); f.Y_SCALE=o.d.xs(2); f.Z_SCALE=o.d.xs(3);
        end
    end
end
