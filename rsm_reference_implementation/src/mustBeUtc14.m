function mustBeUtc14(x)
arguments
    x (1,1) string
end
if strlength(x) ~= 14 || any(~isstrprop(char(x),'digit'))
    error("RSM:Utc14","Time must be a fourteen-digit UTC string YYYYMMDDhhmmss.");
end
end
