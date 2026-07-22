function a = pterm(x,e)
arguments
    x {mustBePts3}
    e (:,3) double {mustBeNonnegative,mustBeInteger}
end
n=size(x,1); m=size(e,1); a=ones(n,m);
for j=1:m
    a(:,j)=x(:,1).^e(j,1).*x(:,2).^e(j,2).*x(:,3).^e(j,3);
end
end
