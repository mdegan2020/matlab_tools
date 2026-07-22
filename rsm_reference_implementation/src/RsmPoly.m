classdef RsmPoly
    properties (SetAccess=private)
        d (1,1) RsmDom
        e (20,3) double
        rn (20,1) double
        rd (20,1) double
        cn (20,1) double
        cd (20,1) double
        st struct
    end

    methods
        function o = RsmPoly(d,rn,rd,cn,cd,st)
            arguments
                d (1,1) RsmDom
                rn (20,1) double {mustBeFinite}
                rd (20,1) double {mustBeFinite}
                cn (20,1) double {mustBeFinite}
                cd (20,1) double {mustBeFinite}
                st struct = struct()
            end
            o.d=d; o.e=rsmexp(3); o.rn=rn; o.rd=rd;
            o.cn=cn; o.cd=cd; o.st=st;
        end

        function u = groundToImage(o,g)
            arguments
                o (1,1) RsmPoly
                g {mustBePts3}
            end
            x=o.d.nx(g); t=pterm(x,o.e);
            y=[(t*o.rn)./(t*o.rd) (t*o.cn)./(t*o.cd)];
            u=o.d.du(y);
        end

        function g = imageToGround(o,u,h,g0)
            arguments
                o (1,1) RsmPoly
                u {mustBePts2}
                h double {mustMatchH(h,u)}
                g0 double {mustMatchG0(g0,u)} = zeros(0,3)
            end
            if isscalar(h), h=repmat(h,size(u,1),1); end
            if isempty(g0)
                g=repmat(o.d.gr,size(u,1),1); g(:,3)=h(:);
            else
                g=g0; g(:,3)=h(:);
            end
            ds=[max(o.d.gh(1)-o.d.gl(1),eps)*1e-6, ...
                max(o.d.gh(2)-o.d.gl(2),eps)*1e-6];
            for k=1:15
                q=o.groundToImage(g); r=u-q;
                if max(vecnorm(r,2,2)) < 1e-7, break; end
                g1=g; g1(:,1)=g1(:,1)+ds(1);
                g2=g; g2(:,2)=g2(:,2)+ds(2);
                j1=(o.groundToImage(g1)-q)/ds(1);
                j2=(o.groundToImage(g2)-q)/ds(2);
                for i=1:size(g,1)
                    j=[j1(i,:).' j2(i,:).'];
                    z=j\r(i,:).';
                    g(i,1:2)=g(i,1:2)+z.';
                end
            end
        end
    end

    methods (Static)
        function o = fit(s,d,cfg)
            arguments
                s (1,1) Sens
                d (1,1) RsmDom
                cfg (1,1) RsmCfg
            end
            [g,u]=mksamp(s,d,cfg.ns); x=d.nx(g); y=d.nu(u);
            [rn0,rd0,sr]=fitrat(x,y(:,1),cfg);
            [cn0,cd0,sc]=fitrat(x,y(:,2),cfg);
            rn=rpc2rsm(rn0); rd=rpc2rsm(rd0);
            cn=rpc2rsm(cn0); cd=rpc2rsm(cd0);
            st.row=sr; st.col=sc;
            o=RsmPoly(d,rn,rd,cn,cd,st);
        end
    end
end
