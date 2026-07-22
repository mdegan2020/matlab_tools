classdef RsmApb
    properties (SetAccess=private)
        cfg (1,1) RsmCfg
        a (1,1) RsmAdj
    end

    methods
        function o = RsmApb(cfg,a)
            arguments
                cfg (1,1) RsmCfg
                a (1,1) RsmAdj
            end
            o.cfg=cfg; o.a=a;
        end

        function f = fields(o)
            arguments
                o (1,1) RsmApb
            end
            a=o.a; f=struct();
            f.IID=o.cfg.iid; f.EDITION=o.cfg.ed; f.VARIANT="B";
            f.AP_SET_ID="SVD_BASIS"; f.AP_TYPE="IMAGE_SPACE";
            f.APBASE="Y"; f.NPAR=size(a.m,2); f.NBASIS=size(a.m,2);
            f.PARAM_ID=a.id; f.PARAM_UNIT=a.un;
            f.PARAM_SCALE=ones(size(a.m,2),1);
            f.PARAM_ASSOC=repmat("GLOBAL",size(a.m,2),1);
            f.ROW_MODEL="POLYNOMIAL"; f.COL_MODEL="POLYNOMIAL";
            f.POW_X=max(a.e(:,1)); f.POW_Y=max(a.e(:,2)); f.POW_Z=max(a.e(:,3));
            f.NTERM=size(a.e,1); f.EXP=a.e;
            f.ROW_COEFF=a.cr; f.COL_COEFF=a.cc;
            f.AEL=a.m; f.COV=a.cp;
        end
    end
end
