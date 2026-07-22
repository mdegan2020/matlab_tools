classdef RsmIda
    properties (SetAccess=private)
        cfg (1,1) RsmCfg
        d (1,1) RsmDom
    end

    methods
        function o = RsmIda(cfg,d)
            arguments
                cfg (1,1) RsmCfg
                d (1,1) RsmDom
            end
            o.cfg=cfg; o.d=d;
        end

        function f = fields(o)
            arguments
                o (1,1) RsmIda
            end
            q=char(o.cfg.dt); f=struct();
            f.IID=o.cfg.iid; f.EDITION=o.cfg.ed; f.ISID=o.cfg.isid;
            f.SID=o.cfg.sid; f.STID=o.cfg.stid;
            f.YEAR=str2double(q(1:4)); f.MONTH=str2double(q(5:6));
            f.DAY=str2double(q(7:8)); f.HOUR=str2double(q(9:10));
            f.MINUTE=str2double(q(11:12)); f.SECOND=str2double(q(13:14));
            f.NRG=o.cfg.im(1); f.NCG=o.cfg.im(2);
            f.TRG=o.d.ui(1); f.TCG=o.d.ui(2); f.GRNDD="G";
            f.XUOR=o.d.gr(2); f.YUOR=o.d.gr(1); f.ZUOR=o.d.gr(3);
            a=eye(3);
            f.XUXR=a(1,1); f.XUYR=a(1,2); f.XUZR=a(1,3);
            f.YUXR=a(2,1); f.YUYR=a(2,2); f.YUZR=a(2,3);
            f.ZUXR=a(3,1); f.ZUYR=a(3,2); f.ZUZR=a(3,3);
            v=[o.d.v(:,2) o.d.v(:,1) o.d.v(:,3)];
            for i=1:8
                f.(sprintf('V%dX',i))=v(i,1);
                f.(sprintf('V%dY',i))=v(i,2);
                f.(sprintf('V%dZ',i))=v(i,3);
            end
            f.MIN_ROW=o.d.ur(1); f.MAX_ROW=o.d.ur(2);
            f.MIN_COL=o.d.ur(3); f.MAX_COL=o.d.ur(4);
            f.GROUND_FRAME="G/H"; f.HEIGHT_DATUM="HAE";
            f.PIXEL_ORIGIN="ZERO_BASED_PIXEL_CENTER";
        end
    end
end
