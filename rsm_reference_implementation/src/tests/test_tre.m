function test_tre()
arguments
end
[s,cfg]=toy_setup(); p=make_product(s,cfg);
f=p.pca.fields();
assert(isfield(f,'RNPCF') && numel(f.RNPCF)==20);
assert(isfield(p.ida.fields(),'V8Z'));
assert(isfield(p.gga.fields(),'NODE_ROW'));
assert(isfield(p.apb.fields(),'AEL'));
assert(isfield(p.ecb.fields(),'ERRCVG'));
assert(isfield(p.dcb.fields(),'ROW_VAR_COEFF'));
sch=schema_example(); y=TreWriter.write(f,sch);
assert(numel(y)==80+40+3+3+21*f.RNTRMS);
end
