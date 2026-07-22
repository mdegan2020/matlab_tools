function s = schema_example()
% Schema shape only. Replace widths and formats with the locked profile.
% cond is a function of the complete field struct; count can also be a function.
arguments
end
s(1)=struct('name','IID','width',80,'kind',"s",'fmt',"",'count',1,'cond',@(f) true);
s(2)=struct('name','EDITION','width',40,'kind',"s",'fmt',"",'count',1,'cond',@(f) true);
s(3)=struct('name','RSN','width',3,'kind',"n",'fmt',"%03d",'count',1,'cond',@(f) true);
s(4)=struct('name','CSN','width',3,'kind',"n",'fmt',"%03d",'count',1,'cond',@(f) true);
s(5)=struct('name','RNPCF','width',21,'kind',"n",'fmt',"%+21.14E", ...
    'count',@(f) f.RNTRMS,'cond',@(f) true);
end
