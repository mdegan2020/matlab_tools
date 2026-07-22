classdef RsmCfg
    properties
        iid (1,1) string
        isid (1,1) string
        sid (1,1) string
        stid (1,1) string
        ed (1,1) string
        dt (1,1) string
        im (1,2) double
        h (1,2) double
        ns (1,3) double
        nt (1,3) double
        ng (1,3) double
        gmax (1,1) double
        ptol (1,1) double
        gtol (1,1) double
        irls (1,1) double
        hub (1,1) double
        lam (1,1) double
        adeg (1,1) double
        ddeg (1,1) double
        kmax (1,1) double
        ekeep (1,1) double
        mc (1,1) double
        seed (1,1) double
        dq (1,6) double
        gf
    end

    methods
        function o = RsmCfg(x)
            arguments
                x.iid (1,1) string = "RSM_REF"
                x.isid (1,1) string = "01"
                x.sid (1,1) string = "SENSOR"
                x.stid (1,1) string = "PUSHBROOM"
                x.ed (1,1) string = "RSM1"
                x.dt (1,1) string {mustBeUtc14} = "20000101000000"
                x.im (1,2) double {mustBeSize2} = [1000 1000]
                x.h (1,2) double {mustBeRange2} = [0 1000]
                x.ns (1,3) double {mustBeDims3} = [21 21 7]
                x.nt (1,3) double {mustBeDims3} = [17 17 5]
                x.ng (1,3) double {mustBeDims3} = [5 5 3]
                x.gmax (1,1) double {mustBePosInt} = 250000
                x.ptol (1,1) double {mustBePositive} = 0.05
                x.gtol (1,1) double {mustBePositive} = 0.10
                x.irls (1,1) double {mustBeNonnegative,mustBeInteger} = 3
                x.hub (1,1) double {mustBePositive} = 1.5
                x.lam (1,1) double {mustBeNonnegative} = 1e-12
                x.adeg (1,1) double {mustBeNonnegative,mustBeInteger} = 2
                x.ddeg (1,1) double {mustBeNonnegative,mustBeInteger} = 2
                x.kmax (1,1) double {mustBePosInt} = 6
                x.ekeep (1,1) double {mustBeGreaterThan(x.ekeep,0),mustBeLessThanOrEqual(x.ekeep,1)} = 0.999
                x.mc (1,1) double {mustBeNonnegative,mustBeInteger} = 300
                x.seed (1,1) double {mustBeNonnegative,mustBeInteger} = 7
                x.dq (1,6) double {mustBePositive} = [1e-7 1e-7 0.05 1e-6 1e-6 1e-6]
                x.gf {mustBeFunOrEmpty} = []
            end
            o.iid=x.iid; o.isid=x.isid; o.sid=x.sid; o.stid=x.stid;
            o.ed=x.ed; o.dt=x.dt; o.im=x.im; o.h=x.h;
            o.ns=x.ns; o.nt=x.nt; o.ng=x.ng; o.gmax=x.gmax;
            o.ptol=x.ptol; o.gtol=x.gtol; o.irls=x.irls;
            o.hub=x.hub; o.lam=x.lam; o.adeg=x.adeg; o.ddeg=x.ddeg;
            o.kmax=x.kmax; o.ekeep=x.ekeep; o.mc=x.mc;
            o.seed=x.seed; o.dq=x.dq; o.gf=x.gf;
        end
    end
end
