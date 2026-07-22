function y = packtri(c,upper)
arguments
    c (:,:) double {mustBeFinite,mustBeSquare}
    upper (1,1) logical = true
end
n=size(c,1); y=zeros(n*(n+1)/2,1); k=0;
if upper
    for i=1:n
        for j=i:n, k=k+1; y(k)=c(i,j); end
    end
else
    for i=1:n
        for j=1:i, k=k+1; y(k)=c(i,j); end
    end
end
end
