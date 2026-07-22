classdef RsmDir
    properties (SetAccess=private)
        d (1,1) RsmDom
        e double
        cf double
        a
        st struct
    end

    methods
        function o = RsmDir(d,e,cf,a,st)
            arguments
                d (1,1) RsmDom
                e (:,3) double {mustBeNonnegative,mustBeInteger}
                cf (:,3) double {mustBeFinite}
                a = []
                st struct = struct()
            end
            o.d=d; o.e=e; o.cf=cf; o.a=a; o.st=st;
        end

        function c = eval(o,g)
            arguments
                o (1,1) RsmDir
                g {mustBePts3}
            end
            y=pterm(o.d.nx(g),o.e)*o.cf;
            c=zeros(2,2,size(g,1));
            for i=1:size(g,1)
                z=[y(i,1) y(i,2); y(i,2) y(i,3)];
                [v,w]=eig((z+z.')/2,"vector");
                w=max(w,0); c(:,:,i)=v*diag(w)*v.';
            end
        end

        function c = crossCov(o,g1,g2)
            arguments
                o (1,1) RsmDir
                g1 {mustBePts3}
                g2 {mustBePts3,mustMatchRows(g2,g1)}
            end
            if isempty(o.a)
                error("RSM:NoCrossCov","Cross-location covariance requires the fitted shared-state basis.");
            end
            b1=o.a.basis(g1); b2=o.a.basis(g2); n=size(g1,1);
            c=zeros(2,2,n);
            for i=1:n
                x=[reshape(b1(i,:,1),1,[]);reshape(b1(i,:,2),1,[])];
                y=[reshape(b2(i,:,1),1,[]);reshape(b2(i,:,2),1,[])];
                c(:,:,i)=x*o.a.cp*y.';
            end
        end
    end
end
