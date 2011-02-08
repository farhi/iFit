function [s, f] = std(a, dim)
% [half_width, center] = std(s, dim) : standard deviation of iData
%
%   @iData/std function to compute the standard deviation of objects, that is
%     their gaussian half width (second moment). Optionally, the distribution  
%     center (first moment) can be returned as well.
%   std(a,dim) computes standard deviation along axis of ramk 'dim'.
%     When omitted, dim is set to 1.
%     Using a negative dimension will subtract minimum signal value to signal
%       before computation of std, that is remove background.
%
% input:  a: object or array (iData/array of)
%         dim: dimension to use. Negative dim subtract background (int)
% output: half_width: standard deviation (scalar/array)
%         center:     center of distribution (scalar/array)
% ex:     c=std(a);
%
% Version: $Revision: 1.2 $
% See also iData, iData/median, iData/mean

if nargin < 2, dim=1; end
if length(a) > 1
  s = []; f = [];
  for index=1:length(a)
    [si, fi] = std(a(index), dim);
    s = [ s si ];
    f = [ f fi ];
  end
  return
end

if abs(dim) > prod(ndims(a))
  dim = 1;
end

if dim == 0
  s = double(a);
  f = mean(s(:));
  s = std(s(:));
  return
end

% we first compute projection of iData on the selected dimension
b = camproj(a, abs(dim));


% then we compute sum(axis{dim}.*Signal)/sum(Signal)
s = iData_private_cleannaninf(get(b,'Signal'));
if (dim < 0)
  s = s - min(s);
end
x = getaxis(b, 1);

sum_s = sum(s);

% first moment (mean)
f = sum(s.*x)./sum_s; % mean value

% second moment: sqrt(sum(x^2*s)/sum(s)-fmon_x*fmon_x);
s = sqrt(sum(x.*x.*s/sum_s) - f*f);

