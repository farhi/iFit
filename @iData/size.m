function y=size(s, dim)
% size(s) : get iData object size (number of elements)
%
%   @iData/size function to get iData object size
%
% input:  s: object or array (iData)
%         dim: optional dimension/rank to inquire
% output: v: size of the iData Signal (double)
% ex:     size(iData), size(iData,1)
%
% Version: $Revision: 1.4 $
% See also iData, iData/disp, iData/get, length

% EF 23/09/07 iData implementation

if numel(s) > 1  % this is an array of iData
  if nargin > 1, y = size(struct(s), dim);
  else           y = size(struct(s)); end
  return
end

s = subsref(s,struct('type','.','subs','Signal'));
if nargin > 1, y = size(s, dim);
else           y = size(s); end

