function y = rpc2rsm(x)
arguments
    x (20,1) double {mustBeFinite}
end
a=rpc00bexp(); b=rsmexp(3);
y=zeros(size(x));
for i=1:size(b,1)
    j=find(all(a==b(i,:),2),1);
    y(i)=x(j);
end
end
