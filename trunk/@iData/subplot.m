function h=subplot(a, varargin)
% h = subplot(s) : plot iData array as subplots
%
%   @iData/subplot plot each iData element in a subplot
%     subplot(a, [])    uses the best subplot fit
%     subplot(a, [m n]) uses an m x n subplot grid
%     subplot(a, [m n], options) sends options to the plot
%
% input:  s: object or array (iData)
%         [m n]: optional subplot grid dimensions
%         additional arguments are passed to the plot method (e.g. color, plot type, ...)
% output: h: plot handles (double)
% ex:     subplot([ a a ])
%
% Version: $Revision: 1.12 $
% See also iData, iData/plot

% EF 23/11/07 iData implementation

if length(a(:)) == 1
  h=plot(a, varargin{:});
  return
end

a = squeeze(a); % remove singleton dimensions
m=[];
n=[];
if length(varargin) >=1
  if isnumeric(varargin{1}) | isempty(varargin{1})
    dim = varargin{1};
    if length(dim) == 1 & dim(1) > 0
      m = dim; 
    elseif length(dim) == 2, m=dim(1); n=dim(2); 
    else m=[]; end
    % else use best fit
    if length(varargin) >= 2  
      varargin = varargin(2:end);
    else varargin = {}; end
  elseif length(size(a)) == 2 & all(size(a) > 1)
    m = size(a,1); n = size(a,2);
  end
end
if any(m==0), m=[]; end
if isempty(m)
  p = length(a(:));
  n = floor(sqrt(p));
  m = ceil(p/n);
elseif isempty(n)
  n = ceil(length(a(:))/m);
end

h=[];
for index=1:length(a(:))
  if ~isempty(a(index))
    subplot(m,n,index);
    h = [ h plot(a(index), varargin{:}) ];
  else h = [ h nan ];
  end
end
