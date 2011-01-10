function [ai,bi] = intersect(a, b)
% [ai,bi] = intersect(a, b) : computes object intersection area and values
%
%   @iData/intersect function to intersect axes data sets
%   This function computes the common intersection between data sets
%   Resulting objects are returned, e.g. for performing further operations
%     ai = intersect(a) where 'a' is an object array computes intersection of all elements
%
% input:  a: object or array (iData)
%         b: object (iData)
% output: ai: object or array (iData)
%         bi: object or array (iData)
% ex:     b=intersect(a, a);
%
% Version: $Revision: 1.6 $
% See also iData, iData/setaxis, iData/getaxis, iData/interp, iData/union

if nargin == 2
  bi = intersect([a b]);
  ai = bi(1);
  bi = bi(2);
  return
end

if length(a) == 1, ai=a; bi=a; return; end

% first check if all objects have same axes
all_identical_axes=1;
for index=1:ndims(a(1)) % loop on axes
  x = getaxis(a(1), index);
  for obj=2:length(a)
    if ~isequal(getaxis(a(obj), index), x)
      all_identical_axes=0; break;
    end
  end
  if ~all_identical_axes, break; end
end
% return if using identical axes: no need to interpolate. retain axes and data.
if all_identical_axes, ai=a; bi=[]; return; end

% determine largest dimensionality
max_ndims=max(ndims(a));

% initiate new axes
for index=1:max_ndims
  c_step{index} =  Inf;
  c_min{index}  = -Inf;
  c_max{index}  =  Inf;
  c_len{index}  =  0;
end

% loop on all iData to find intersection area
for index=1:length(a)
  if ndims(a(index)) ~= ndims(a(1))
    iData_private_warning(mfilename, [ 'Object intersection requires same dimensionality.\n\tobject ' inputname(1) ' ' a(1).Tag ' is ' num2str(ndims(a(1))) ' but object ' a(index).Tag ' is ' num2str(ndims(a(index))) '. Extending object.' ]);
  end
  for j_ax = 1:max_ndims  % for each dimension
    if j_ax <= ndims(a(index))
      x = getaxis(a(index), j_ax); x=unique(x(:));    % extract axis, and remove duplicates. diff > 0
      c_step{j_ax} = min(min(diff(x)), c_step{j_ax}); % smallest step
      c_min{j_ax}  = max(min(x), c_min{j_ax});        % highest min
      c_max{j_ax}  = min(max(x), c_max{j_ax});        % lowest max
      c_len{j_ax}  = c_len{j_ax} + length(x);         % cumulated axes length
    end
  end
end

% build new axes
for j_ax = 1:max_ndims % for each dimension
  c_len{j_ax} = c_len{j_ax}/length(a);                  % mean axis length from original data
  len         = (c_max{j_ax}-c_min{j_ax})/c_step{j_ax}; % theoretical axis length
  c_len{j_ax} = min(len, 10*c_len{j_ax});               % can not extend axes more than 10 times
  c_axis{j_ax} = linspace(c_min{j_ax}, c_max{j_ax}, c_len{j_ax});
end

% loop on all iData to interpolate
ai = a; bi=[];
for index=1:length(a)
  ai(index) = interp(a(index), c_axis(1:ndims(a)));
end

