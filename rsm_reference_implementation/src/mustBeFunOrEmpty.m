function mustBeFunOrEmpty(f)
arguments
    f
end
if ~(isempty(f) || isa(f,"function_handle"))
    error("RSM:Fun","Input must be empty or a function handle.");
end
end
