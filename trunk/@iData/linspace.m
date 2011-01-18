function v = linspace(a,b,n)
% v = linspace(a,b,n) : creates a linearly spaced vector of objects
%
%   @iData/linspace function to create a linearly spaced vector of iData objects
%   This corresponds to a 'morphing' from a to b in n steps.
%
% input:  a: object  (iData)
%         b: object  (iData)
%         n: number of steps, i.e. length of vector. Default is n=10 (integer)
% output: v: vector (iData array)
% ex:     b=linspace(a,b);
%
% Version: $Revision: 1.4 $
% See also iData, iData/max, iData/min, iData/colon, iData/logspace

if ~isa(a, 'iData') | ~isa(b,'iData')
  iData_private_error(mfilename, 'Operation requires 2 single iData objects as argument');
end

if nargin == 2
  n = [];
end
if isempty(n) | n <=0
  n=10;
end

[a,b] = intersect(a,b);

xa = linspace(1,0,n);

v = [];
for index=1:n
  c = a.*xa(index) + b.*(1-xa(index));
  v = [ v c ];
end

