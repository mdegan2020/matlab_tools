function mustMatchH(h,u)
arguments
    h double
    u double
end
if ~(isscalar(h) || (isvector(h) && numel(h)==size(u,1))) || any(~isfinite(h(:)))
    error("RSM:HeightCount","Height must be scalar or have one finite value per image point.");
end
end
