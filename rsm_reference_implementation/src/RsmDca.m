classdef RsmDca
    properties (SetAccess=private)
        cfg (1,1) RsmCfg
        g double
        c double
    end

    methods
        function o = RsmDca(cfg,g,c)
            arguments
                cfg (1,1) RsmCfg
                g {mustBePts3}
                c double {mustBeCov2N,mustMatchCovCount(c,g)}
            end
            o.cfg=cfg; o.g=g; o.c=c;
        end

        function f = fields(o)
            arguments
                o (1,1) RsmDca
            end
            n=size(o.g,1); rr=zeros(n,1); rc=rr; cc=rr;
            for i=1:n
                rr(i)=o.c(1,1,i); rc(i)=o.c(1,2,i); cc(i)=o.c(2,2,i);
            end
            f=struct(); f.IID=o.cfg.iid; f.EDITION=o.cfg.ed;
            f.VARIANT="A"; f.MODEL_TYPE="SAMPLED_DIRECT";
            f.NSAMPLE=n; f.GROUND=o.g; f.ROW_VAR=rr;
            f.ROW_COL_COV=rc; f.COL_VAR=cc;
            f.CORR_GROUP_COUNT=1; f.CORR_FUNCTION_ID="GLOBAL_SHARED_STATE";
            f.CORR_PARAM_COUNT=0; f.UNMODELED_INCLUDED=false;
        end
    end
end
