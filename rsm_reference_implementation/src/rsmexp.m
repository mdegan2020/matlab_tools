function e = rsmexp(d)
arguments
    d (1,1) double {mustBeNonnegative,mustBeInteger} = 3
end
% Isolated RSM traversal: Z outer, Y middle, X inner, total degree <= d.
% Replace this one function when a locked profile uses a different order.
e=zeros(nchoosek(d+3,3),3);
n=0;
for k=0:d
    for j=0:d
        for i=0:d
            if i+j+k <= d
                n=n+1;
                e(n,:)=[i j k];
            end
        end
    end
end
e=e(1:n,:);
end
