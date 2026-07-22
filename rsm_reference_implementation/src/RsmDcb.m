classdef RsmDcb
    properties (SetAccess=private)
        cfg (1,1) RsmCfg
        q (1,1) RsmDir
    end

    methods
        function o = RsmDcb(cfg,q)
            arguments
                cfg (1,1) RsmCfg
                q (1,1) RsmDir
            end
            o.cfg=cfg; o.q=q;
        end

        function f = fields(o)
            arguments
                o (1,1) RsmDcb
            end
            e=o.q.e; d=o.q.d; f=struct();
            f.IID=o.cfg.iid; f.EDITION=o.cfg.ed; f.VARIANT="B";
            f.MODEL_TYPE="POLYNOMIAL_DIRECT";
            f.X_OFF=d.xo(1); f.Y_OFF=d.xo(2); f.Z_OFF=d.xo(3);
            f.X_SCALE=d.xs(1); f.Y_SCALE=d.xs(2); f.Z_SCALE=d.xs(3);
            f.POW_X=max(e(:,1)); f.POW_Y=max(e(:,2)); f.POW_Z=max(e(:,3));
            f.NTERM=size(e,1); f.EXP=e;
            f.ROW_VAR_COEFF=o.q.cf(:,1);
            f.ROW_COL_COV_COEFF=o.q.cf(:,2);
            f.COL_VAR_COEFF=o.q.cf(:,3);
            f.CORR_GROUP_COUNT=1; f.CORR_FUNCTION_ID="GLOBAL_SHARED_STATE";
            f.CORR_PARAM_COUNT=0; f.BASIS_LINK="RSMAPB/RSMECB";
            f.UNMODELED_INCLUDED=false;
        end
    end
end
