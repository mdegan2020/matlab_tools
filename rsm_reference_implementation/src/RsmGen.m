classdef RsmGen
    properties (SetAccess=private)
        s (1,1) Sens
        cfg (1,1) RsmCfg
    end

    methods
        function o = RsmGen(s,cfg)
            arguments
                s (1,1) Sens
                cfg (1,1) RsmCfg
            end
            o.s=s; o.cfg=cfg;
        end

        function p = build(o)
            arguments
                o (1,1) RsmGen
            end
            s=o.s; cfg=o.cfg;
            d=mkdom(s,cfg);
            rp=RsmPoly.fit(s,d,cfg);
            if isempty(cfg.gf), rg=mkgrid(s,d,cfg); else, rg=cfg.gf(s,d,cfg); end
            [g,u]=mksamp(s,d,cfg.nt);
            ep=rp.groundToImage(g)-u;
            eg=rg.groundToImage(g)-u;
            rep.poly_rms=sqrt(mean(sum(ep.^2,2)));
            rep.poly_max=max(vecnorm(ep,2,2));
            rep.grid_rms=sqrt(mean(sum(eg.^2,2)));
            rep.grid_max=max(vecnorm(eg,2,2));
            rep.poly_pass=rep.poly_max<=cfg.ptol;
            rep.grid_pass=rep.grid_max<=cfg.gtol;
            rep.poly_fit=rp.st; rep.grid_fit=rg.st;

            ida=RsmIda(cfg,d); pia=RsmPia(cfg,d); pca=RsmPca(cfg,rp);
            gia=RsmGia(cfg,rg); gga=RsmGga(cfg,rg);
            a=[]; q=[]; apa=[]; apb=[]; eca=[]; ecb=[]; dca=[]; dcb=[];

            if s.hasp
                [c,cs]=condcov(s.c); j=fdjac(s,g,cfg.dq);
                id=["DLAT";"DLON";"DHAE";"DROLL";"DPITCH";"DHEAD"];
                un=["deg";"deg";"m";"rad";"rad";"rad"];
                aa=fitadj(g,j,eye(6),c,d,cfg.adeg,cfg.lam,id,un);
                [m,cp,bs]=redbasis(j,c,cfg.kmax,cfg.ekeep);
                k=size(m,2); bid="SVD"+compose("%02d",(1:k).');
                bun=repmat("sigma",k,1);
                a=fitadj(g,j,m,cp,d,cfg.adeg,cfg.lam,bid,bun);
                q=mkdirect(g,j,c,d,cfg.ddeg,cfg.lam,a);
                ci=propcov(j,c);
                apa=RsmApa(cfg,aa); apb=RsmApb(cfg,a);
                eca=RsmEca(cfg,aa,c); ecb=RsmEcb(cfg,a);
                dca=RsmDca(cfg,g,ci); dcb=RsmDcb(cfg,q);
                rep.cov_cond=cs; rep.basis=bs;
                rep.adj_physical=aa.st; rep.adj_reduced=a.st; rep.direct=q.st;
                if cfg.mc > 0
                    ii=unique(round(linspace(1,size(g,1),min(25,size(g,1)))));
                    rep.mc=mccov(s,g(ii,:),c,j(ii,:,:),cfg.mc,cfg.seed);
                end
            else
                rep.cov_note="No pose perturbation callback; covariance products omitted.";
            end

            p=RsmProd(dom=d,poly=rp,grid=rg,adj=a,dir=q, ...
                ida=ida,pia=pia,pca=pca,gia=gia,gga=gga, ...
                apa=apa,apb=apb,eca=eca,ecb=ecb,dca=dca,dcb=dcb,rep=rep);
        end
    end
end
