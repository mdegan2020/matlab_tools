classdef Sens
    properties (SetAccess=private)
        g2i (1,1) function_handle
        i2g (1,1) function_handle
        p2i
        c (6,6) double
        hasp (1,1) logical
    end

    methods
        function o = Sens(g2i,i2g,c,p2i)
            arguments
                g2i (1,1) function_handle
                i2g (1,1) function_handle
                c {mustBeCov6}
                p2i {mustBeFunOrEmpty} = []
            end
            if isvector(c)
                c = diag(c(:));
            end
            o.g2i = g2i;
            o.i2g = i2g;
            o.c = c;
            o.p2i = p2i;
            o.hasp = ~isempty(p2i);
        end

        function u = groundToImage(o,g)
            arguments
                o (1,1) Sens
                g {mustBePts3}
            end
            u = o.g2i(g);
        end

        function g = imageToGround(o,u,h)
            arguments
                o (1,1) Sens
                u {mustBePts2}
                h double {mustMatchH(h,u)}
            end
            if isscalar(h)
                h = repmat(h,size(u,1),1);
            end
            g = o.i2g(u,h(:));
        end

        function u = groundToImagePerturbed(o,g,dq)
            arguments
                o (1,1) Sens
                g {mustBePts3}
                dq (1,6) double {mustBeFinite}
            end
            if ~o.hasp
                error("RSM:NoPoseCallback", ...
                    ["Covariance generation requires groundToImagePerturbed(g,dq). " ...
                     "Nominal image/ground functions do not identify pose sensitivity."]);
            end
            u = o.p2i(g,dq);
        end
    end
end
