classdef RsmEcb
    properties (SetAccess=private)
        cfg (1,1) RsmCfg
        a (1,1) RsmAdj
    end

    methods
        function o = RsmEcb(cfg,a)
            arguments
                cfg (1,1) RsmCfg
                a (1,1) RsmAdj
            end
            o.cfg=cfg; o.a=a;
        end

        function f = fields(o)
            arguments
                o (1,1) RsmEcb
            end
            a=o.a; d=a.d; k=size(a.m,2); f=struct();
            f.IID=o.cfg.iid; f.EDITION=o.cfg.ed; f.TID="SVD_BASIS";
            f.INCLIC="Y"; f.INCLUC="N"; f.NPARO=6; f.IGN=1;
            f.CVDATE=o.cfg.dt; f.NPAR=k; f.APTYP="I"; f.LOCTYP="R";
            f.NSFX=0; f.NSFY=0; f.NSFZ=0; f.NOFFX=0; f.NOFFY=0; f.NOFFZ=0;
            f.XUOL=d.gr(2); f.YUOL=d.gr(1); f.ZUOL=d.gr(3);
            f.XUXL=1; f.XUYL=0; f.XUZL=0;
            f.YUXL=0; f.YUYL=1; f.YUZL=0;
            f.ZUXL=0; f.ZUYL=0; f.ZUZL=1;
            f.APBASE="Y"; f.NBASIS=k; f.AEL=a.m;
            f.NISAP=k; f.NISAPR=size(a.e,1); f.NISAPC=size(a.e,1);
            f.XPWRR=max(a.e(:,1)); f.YPWRR=max(a.e(:,2)); f.ZPWRR=max(a.e(:,3));
            f.XPWRC=f.XPWRR; f.YPWRC=f.YPWRR; f.ZPWRC=f.ZPWRR;
            f.ROW_COEFF=a.cr; f.COL_COEFF=a.cc; f.EXP=a.e;
            f.NUMOPG=k; f.ERRCVG=packtri(a.cp,true);
            f.TCDF=0; f.ACSMC="N"; f.NCSEG=1; f.CORSEG="CONSTANT_ONE"; f.TAUSEG=Inf; f.MAP=a.m;
            f.UNMODELED_INCLUDED=false;
        end
    end
end
