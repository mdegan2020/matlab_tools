classdef RsmAdj
    properties (SetAccess=private)
        d (1,1) RsmDom
        e double
        cr double
        cc double
        m double
        cp double
        id string
        un string
        st struct
    end

    methods
        function o = RsmAdj(d,e,cr,cc,m,cp,id,un,st)
            arguments
                d (1,1) RsmDom
                e (:,3) double {mustBeNonnegative,mustBeInteger}
                cr double {mustBeFinite}
                cc double {mustBeFinite}
                m double {mustBeFinite}
                cp double {mustBeFinite,mustMatchAdj(cp,cr,cc,m,e)}
                id string {mustMatchTextCount(id,m)}
                un string {mustMatchTextCount(un,m)}
                st struct = struct()
            end
            o.d=d; o.e=e; o.cr=cr; o.cc=cc; o.m=m; o.cp=cp;
            o.id=id; o.un=un; o.st=st;
        end

        function z = basis(o,g)
            arguments
                o (1,1) RsmAdj
                g {mustBePts3}
            end
            t=pterm(o.d.nx(g),o.e);
            z=cat(3,t*o.cr,t*o.cc);
        end

        function du = shift(o,g,p)
            arguments
                o (1,1) RsmAdj
                g {mustBePts3}
                p (:,1) double {mustBeFinite,mustMatchAdjParam(p,o)}
            end
            t=pterm(o.d.nx(g),o.e);
            du=[(t*o.cr)*p (t*o.cc)*p];
        end

        function q = sourceState(o,p)
            arguments
                o (1,1) RsmAdj
                p (:,1) double {mustBeFinite,mustMatchAdjParam(p,o)}
            end
            q=o.m*p;
        end

        function c = imageCov(o,g)
            arguments
                o (1,1) RsmAdj
                g {mustBePts3}
            end
            t=pterm(o.d.nx(g),o.e); br=t*o.cr; bc=t*o.cc;
            c=zeros(2,2,size(g,1));
            for i=1:size(g,1)
                b=[br(i,:);bc(i,:)]; c(:,:,i)=b*o.cp*b.';
            end
        end
    end
end
