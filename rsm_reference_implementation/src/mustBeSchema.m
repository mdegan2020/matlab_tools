function mustBeSchema(s)
arguments
    s struct
end
n=["name" "width" "kind" "fmt" "count" "cond"];
if ~all(isfield(s,n))
    error("RSM:Schema","Schema entries require name, width, kind, fmt, count, and cond fields.");
end
end
