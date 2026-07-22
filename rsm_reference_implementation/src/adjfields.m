function f = adjfields(cfg,a,typ,var)
arguments
    cfg (1,1) RsmCfg
    a (1,1) RsmAdj
    typ (1,1) string
    var (1,1) string
end
f=struct(); f.IID=cfg.iid; f.EDITION=cfg.ed; f.VARIANT=var;
f.AP_SET_ID="POSE6"; f.AP_TYPE=typ; f.NPAR=size(a.m,2);
f.PARAM_ID=a.id; f.PARAM_UNIT=a.un; f.PARAM_SCALE=ones(size(a.m,2),1);
f.PARAM_ASSOC=repmat("GLOBAL",size(a.m,2),1);
f.ROW_MODEL="POLYNOMIAL"; f.COL_MODEL="POLYNOMIAL";
f.POW_X=max(a.e(:,1)); f.POW_Y=max(a.e(:,2)); f.POW_Z=max(a.e(:,3));
f.NTERM=size(a.e,1); f.EXP=a.e; f.ROW_COEFF=a.cr; f.COL_COEFF=a.cc;
f.SOURCE_MAP=a.m; f.COV=a.cp;
end
