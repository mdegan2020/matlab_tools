function f = collect_fields(p)
arguments
    p (1,1) RsmProd
end
f=struct();
f.RSMIDA=p.ida.fields();
f.RSMPIA=p.pia.fields();
f.RSMPCA=p.pca.fields();
f.RSMGIA=p.gia.fields();
f.RSMGGA=p.gga.fields();
if ~isempty(p.apa), f.RSMAPA=p.apa.fields(); end
if ~isempty(p.apb), f.RSMAPB=p.apb.fields(); end
if ~isempty(p.eca), f.RSMECA=p.eca.fields(); end
if ~isempty(p.ecb), f.RSMECB=p.ecb.fields(); end
if ~isempty(p.dca), f.RSMDCA=p.dca.fields(); end
if ~isempty(p.dcb), f.RSMDCB=p.dcb.fields(); end
end
