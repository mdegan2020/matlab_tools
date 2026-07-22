classdef ToyPb
    properties (SetAccess=private)
        lat (1,1) double
        lon (1,1) double
        hae (1,1) double
        hc (1,1) double
        r0 (1,1) double
        c0 (1,1) double
        sp (1,1) double
        fp (1,1) double
        re (1,1) double
        b0 (3,3) double
    end

    methods
        function o = ToyPb(x)
            arguments
                x.lat (1,1) double {mustBeFinite} = 35.0
                x.lon (1,1) double {mustBeFinite} = -117.0
                x.hae (1,1) double {mustBeFinite} = 500.0
                x.hc (1,1) double {mustBeFinite} = 705000.0
                x.r0 (1,1) double {mustBeFinite} = 599.5
                x.c0 (1,1) double {mustBeFinite} = 999.5
                x.sp (1,1) double {mustBePositive} = 8.0
                x.fp (1,1) double {mustBePositive} = 950000.0
            end
            o.lat=x.lat; o.lon=x.lon; o.hae=x.hae; o.hc=x.hc;
            o.r0=x.r0; o.c0=x.c0; o.sp=x.sp; o.fp=x.fp;
            o.re=6378137.0;
            % Body x=north/flight, body y=east/cross-track, body z=down.
            o.b0=[0 1 0; 1 0 0; 0 0 -1];
        end

        function u = groundToImage(o,g)
            arguments
                o (1,1) ToyPb
                g {mustBePts3}
            end
            u=o.proj(g,zeros(1,6));
        end

        function u = groundToImagePerturbed(o,g,dq)
            arguments
                o (1,1) ToyPb
                g {mustBePts3}
                dq (1,6) double {mustBeFinite}
            end
            u=o.proj(g,dq);
        end

        function g = imageToGround(o,u,h)
            arguments
                o (1,1) ToyPb
                u {mustBePts2}
                h double {mustMatchH(h,u)}
            end
            if isscalar(h), h=repmat(h,size(u,1),1); end
            q=zeros(1,6); [c,r]=o.pose(q);
            v=[zeros(size(u,1),1) (u(:,2)-o.c0)/o.fp ones(size(u,1),1)];
            w=v*r.';
            cv=repmat(c,size(u,1),1)+(u(:,1)-o.r0).*[0 o.sp 0];
            hz=h(:)-o.hae;
            t=(hz-cv(:,3))./w(:,3);
            p=cv+t.*w;
            g=o.fromenu(p);
        end
    end

    methods (Access=private)
        function u = proj(o,g,q)
            p=o.toenu(g); [c,r]=o.pose(q); v=[0 o.sp 0];
            ex=r(:,1).'; den=dot(v,ex);
            rr=o.r0+((p-c)*ex.')/den;
            cv=c+(rr-o.r0).*v;
            z=(p-cv)*r;
            cc=o.c0+o.fp*z(:,2)./z(:,3);
            u=[rr cc];
        end

        function [c,r] = pose(o,q)
            de=q(2)*pi/180*o.re*cosd(o.lat);
            dn=q(1)*pi/180*o.re;
            du=q(3);
            c=[de dn o.hc-o.hae+du];
            cr=cos(q(4)); sr=sin(q(4));
            cp=cos(q(5)); sp=sin(q(5));
            ch=cos(q(6)); sh=sin(q(6));
            rx=[1 0 0;0 cr -sr;0 sr cr];
            ry=[cp 0 sp;0 1 0;-sp 0 cp];
            rz=[ch -sh 0;sh ch 0;0 0 1];
            r=o.b0*rz*ry*rx;
        end

        function p = toenu(o,g)
            e=(g(:,2)-o.lon)*pi/180*o.re*cosd(o.lat);
            n=(g(:,1)-o.lat)*pi/180*o.re;
            z=g(:,3)-o.hae;
            p=[e n z];
        end

        function g = fromenu(o,p)
            lat=o.lat+p(:,2)/o.re*180/pi;
            lon=o.lon+p(:,1)/(o.re*cosd(o.lat))*180/pi;
            hae=o.hae+p(:,3);
            g=[lat lon hae];
        end
    end
end
