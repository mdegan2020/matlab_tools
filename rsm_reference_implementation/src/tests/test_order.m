function test_order()
arguments
end
x=(1:20).';
y=rsm2rpc(rpc2rsm(x));
assert(isequal(x,y));
a=rpc00bexp(); b=rsmexp(3);
assert(size(a,1)==20 && size(b,1)==20);
assert(size(unique(b,'rows'),1)==20);
end
