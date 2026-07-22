classdef RsmPca
    properties (SetAccess=private)
        cfg (1,1) RsmCfg
        p (1,1) RsmPoly
    end

    methods
        function o = RsmPca(cfg,p)
            arguments
                cfg (1,1) RsmCfg
                p (1,1) RsmPoly
            end
            o.cfg=cfg; o.p=p;
        end

        function f = fields(o)
            arguments
                o (1,1) RsmPca
            end
            d=o.p.d; e=o.p.e; f=struct();
            f.IID=o.cfg.iid; f.EDITION=o.cfg.ed; f.RSN=1; f.CSN=1;
            f.RFEP=o.p.st.row.mx*d.us(1); f.CFEP=o.p.st.col.mx*d.us(2);
            f.RNRMO=d.uo(1); f.CNRMO=d.uo(2);
            f.XNRMO=d.xo(1); f.YNRMO=d.xo(2); f.ZNRMO=d.xo(3);
            f.RNRMSF=d.us(1); f.CNRMSF=d.us(2);
            f.XNRMSF=d.xs(1); f.YNRMSF=d.xs(2); f.ZNRMSF=d.xs(3);
            f.RNPWRX=max(e(:,1)); f.RNPWRY=max(e(:,2)); f.RNPWRZ=max(e(:,3));
            f.RNTRMS=size(e,1); f.RNPCF=o.p.rn;
            f.RDPWRX=max(e(:,1)); f.RDPWRY=max(e(:,2)); f.RDPWRZ=max(e(:,3));
            f.RDTRMS=size(e,1); f.RDPCF=o.p.rd;
            f.CNPWRX=max(e(:,1)); f.CNPWRY=max(e(:,2)); f.CNPWRZ=max(e(:,3));
            f.CNTRMS=size(e,1); f.CNPCF=o.p.cn;
            f.CDPWRX=max(e(:,1)); f.CDPWRY=max(e(:,2)); f.CDPWRZ=max(e(:,3));
            f.CDTRMS=size(e,1); f.CDPCF=o.p.cd;
            f.COEFF_ORDER=e;
        end
    end
end
