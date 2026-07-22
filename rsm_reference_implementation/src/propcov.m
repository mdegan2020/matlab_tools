function c = propcov(j,q)
arguments
    j (:,2,6) double {mustBeFinite}
    q (6,6) double {mustBeFinite}
end
n=size(j,1); c=zeros(2,2,n);
for i=1:n
    a=reshape(j(i,:,:),2,6); c(:,:,i)=a*q*a.';
end
end
