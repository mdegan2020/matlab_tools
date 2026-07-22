classdef RsmGrid
    properties (SetAccess=private)
        d (1,1) RsmDom
        a (:,1) double
        b (:,1) double
        h (:,1) double
        r double
        c double
        ok logical
        st struct
    end

    methods
        function o = RsmGrid(d,a,b,h,r,c,ok,st)
            arguments
                d (1,1) RsmDom
                a (:,1) double {mustBeIncreasing}
                b (:,1) double {mustBeIncreasing}
                h (:,1) double {mustBeIncreasing}
                r double {mustMatchGrid(r,a,b,h)}
                c double {mustMatchGrid(c,a,b,h)}
                ok logical {mustMatchGrid(ok,a,b,h)}
                st struct = struct()
            end
            o.d=d; o.a=a; o.b=b; o.h=h; o.r=r; o.c=c; o.ok=ok; o.st=st;
        end

        function u = groundToImage(o,g)
            arguments
                o (1,1) RsmGrid
                g {mustBePts3}
            end
            rr=interpn(o.a,o.b,o.h,o.r,g(:,1),g(:,2),g(:,3),'linear',NaN);
            cc=interpn(o.a,o.b,o.h,o.c,g(:,1),g(:,2),g(:,3),'linear',NaN);
            u=[rr cc];
        end

        function g = imageToGround(o,u,h,g0)
            arguments
                o (1,1) RsmGrid
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
                q=o.groundToImage(g); z=u-q;
                if max(vecnorm(z,2,2)) < 1e-6, break; end
                g1=g; g1(:,1)=g1(:,1)+ds(1);
                g2=g; g2(:,2)=g2(:,2)+ds(2);
                j1=(o.groundToImage(g1)-q)/ds(1);
                j2=(o.groundToImage(g2)-q)/ds(2);
                for i=1:size(g,1)
                    j=[j1(i,:).' j2(i,:).'];
                    if rcond(j) > 1e-12
                        w=j\z(i,:).';
                        g(i,1:2)=g(i,1:2)+w.';
                    end
                end
                g(:,1)=min(max(g(:,1),o.d.gl(1)),o.d.gh(1));
                g(:,2)=min(max(g(:,2),o.d.gl(2)),o.d.gh(2));
            end
        end

        function [g,u,ok] = nodes(o)
            arguments
                o (1,1) RsmGrid
            end
            [aa,bb,hh]=ndgrid(o.a,o.b,o.h);
            g=[aa(:) bb(:) hh(:)];
            u=[o.r(:) o.c(:)]; ok=o.ok(:);
        end
    end
end
