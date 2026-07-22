classdef TreWriter
    methods (Static)
        function y = write(f,s)
            arguments
                f (1,1) struct
                s (1,:) struct {mustBeSchema}
            end
            y="";
            for i=1:numel(s)
                z=s(i);
                if isa(z.cond,"function_handle") && ~z.cond(f), continue; end
                if ~isfield(f,z.name)
                    error("RSM:MissingField","Missing TRE field %s.",z.name);
                end
                v=f.(z.name);
                if isa(z.count,"function_handle"), n=z.count(f); else, n=z.count; end
                if isempty(n), n=numel(v); end
                if numel(v) < n
                    error("RSM:FieldCount","TRE field %s has too few values.",z.name);
                end
                for k=1:n
                    y=y+TreWriter.one(v(k),z);
                end
            end
            y=char(y);
        end
    end

    methods (Static,Access=private)
        function y = one(v,z)
            if z.kind=="s"
                q=char(string(v));
                if strlength(string(q)) > z.width
                    error("RSM:FieldWidth","String field %s exceeds width %d.",z.name,z.width);
                end
                y=string([q blanks(z.width-strlength(string(q)))]);
            else
                q=sprintf(char(z.fmt),v);
                if strlength(string(q)) > z.width
                    error("RSM:FieldWidth","Numeric field %s exceeds width %d.",z.name,z.width);
                end
                y=string([blanks(z.width-strlength(string(q))) q]);
            end
        end
    end
end
