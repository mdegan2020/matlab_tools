function y = evalrat(x,a,b,e)
arguments
    x {mustBePts3}
    a (:,1) double {mustBeFinite}
    b (:,1) double {mustBeFinite}
    e (:,3) double {mustBeNonnegative,mustBeInteger}
end
t=pterm(x,e);
y=(t*a)./(t*b);
end
