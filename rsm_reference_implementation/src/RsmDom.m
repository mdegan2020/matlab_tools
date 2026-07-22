classdef RsmDom
    properties (SetAccess=private)
        gl (1,3) double
        gh (1,3) double
        xo (1,3) double
        xs (1,3) double
        uo (1,2) double
        us (1,2) double
        ur (1,4) double
        v (8,3) double
        gr (1,3) double
        ui (1,2) double
    end

    methods
        function o = RsmDom(gl,gh,ur,v,gr,ui)
            arguments
                gl (1,3) double {mustBeFinite}
                gh (1,3) double {mustBeFinite,mustBeAbove(gh,gl)}
                ur (1,4) double {mustBeRect4}
                v (8,3) double {mustBeFinite}
                gr (1,3) double {mustBeFinite}
                ui (1,2) double {mustBeFinite}
            end
            o.gl=gl; o.gh=gh; o.ur=ur; o.v=v; o.gr=gr; o.ui=ui;
            o.xo=[(gl(2)+gh(2))/2, (gl(1)+gh(1))/2, (gl(3)+gh(3))/2];
            o.xs=[(gh(2)-gl(2))/2, (gh(1)-gl(1))/2, (gh(3)-gl(3))/2];
            o.uo=[(ur(1)+ur(2))/2, (ur(3)+ur(4))/2];
            o.us=[(ur(2)-ur(1))/2, (ur(4)-ur(3))/2];
        end

        function x = nx(o,g)
            arguments
                o (1,1) RsmDom
                g {mustBePts3}
            end
            x=([g(:,2) g(:,1) g(:,3)]-o.xo)./o.xs;
        end

        function g = dx(o,x)
            arguments
                o (1,1) RsmDom
                x {mustBePts3}
            end
            z=x.*o.xs+o.xo;
            g=[z(:,2) z(:,1) z(:,3)];
        end

        function y = nu(o,u)
            arguments
                o (1,1) RsmDom
                u {mustBePts2}
            end
            y=(u-o.uo)./o.us;
        end

        function u = du(o,y)
            arguments
                o (1,1) RsmDom
                y {mustBePts2}
            end
            u=y.*o.us+o.uo;
        end

        function tf = inside(o,u)
            arguments
                o (1,1) RsmDom
                u {mustBePts2}
            end
            tf=u(:,1)>=o.ur(1) & u(:,1)<=o.ur(2) & ...
               u(:,2)>=o.ur(3) & u(:,2)<=o.ur(4);
        end
    end
end
