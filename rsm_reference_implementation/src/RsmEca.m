classdef RsmEca
    properties (SetAccess=private)
        cfg (1,1) RsmCfg
        a (1,1) RsmAdj
        c (6,6) double
    end

    methods
        function o = RsmEca(cfg,a,c)
            arguments
                cfg (1,1) RsmCfg
                a (1,1) RsmAdj
                c (6,6) double {mustBeFinite}
            end
            o.cfg=cfg; o.a=a; o.c=c;
        end

        function f = fields(o)
            arguments
                o (1,1) RsmEca
            end
            d=o.a.d; f=struct();
            f.IID=o.cfg.iid; f.EDITION=o.cfg.ed; f.TID="POSE6";
            f.INCLIC="Y"; f.INCLUC="N"; f.NPAR=6; f.NPARO=6;
            f.IGN=1; f.CVDATE=o.cfg.dt;
            f.XUOL=d.gr(2); f.YUOL=d.gr(1); f.ZUOL=d.gr(3);
            f.XUXL=1; f.XUYL=0; f.XUZL=0;
            f.YUXL=0; f.YUYL=1; f.YUZL=0;
            f.ZUXL=0; f.ZUYL=0; f.ZUZL=1;
            f.NUMOPG=6; f.ERRCVG=packtri(o.c,true);
            f.TCDF=0; f.NCSEG=1; f.CORSEG="CONSTANT_ONE"; f.TAUSEG=Inf; f.MAP=eye(6);
            f.PARAM_ID=o.a.id; f.PARAM_UNIT=o.a.un;
            f.ROW_COEFF=o.a.cr; f.COL_COEFF=o.a.cc; f.EXP=o.a.e;
            f.UNMODELED_INCLUDED=false;
        end
    end
end
