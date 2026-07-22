classdef RsmProd
    properties (SetAccess=private)
        dom
        poly
        grid
        adj
        dir
        ida
        pia
        pca
        gia
        gga
        apa
        apb
        eca
        ecb
        dca
        dcb
        rep struct
    end

    methods
        function o = RsmProd(x)
            arguments
                x.dom
                x.poly
                x.grid
                x.adj = []
                x.dir = []
                x.ida
                x.pia
                x.pca
                x.gia
                x.gga
                x.apa = []
                x.apb = []
                x.eca = []
                x.ecb = []
                x.dca = []
                x.dcb = []
                x.rep struct = struct()
            end
            o.dom=x.dom; o.poly=x.poly; o.grid=x.grid; o.adj=x.adj; o.dir=x.dir;
            o.ida=x.ida; o.pia=x.pia; o.pca=x.pca; o.gia=x.gia; o.gga=x.gga;
            o.apa=x.apa; o.apb=x.apb; o.eca=x.eca; o.ecb=x.ecb;
            o.dca=x.dca; o.dcb=x.dcb; o.rep=x.rep;
        end

        function t = summary(o)
            arguments
                o (1,1) RsmProd
            end
            covok=~isempty(o.adj);
            t=table(o.rep.poly_rms,o.rep.poly_max,o.rep.grid_rms,o.rep.grid_max,covok, ...
                'VariableNames',{'PolyRmsPx','PolyMaxPx','GridRmsPx','GridMaxPx','HasCov'});
        end
    end
end
