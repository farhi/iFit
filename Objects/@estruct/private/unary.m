function b = unary(a, op, varargin)
% UNARY handles unary operations
%
% Supported operations:
% abs acosh acos asinh asin atanh atan ceil conj cosh cos ctranspose del2 exp
% fliplr flipud floor full imag isfinite isfloat isinf isinteger islogical
% isnan isnumeric isreal isscalar issparse log10 log norm not permute
% real reshape resize round sign sinh sin sparse sqrt tanh tan transpose uminus uplus
%
% present but not used here: 'double','single','logical','find'

% handle input iData arrays
if numel(a) > 1
  b = {};
  for index=1:numel(a)
    this = unary(a(index), op, varargin{:});
    if (isnumeric(this)||islogical(this)) && ~isa(this, 'estruct') && ~isscalar(this),
      this = { this };
    end
    b = [ b this ];
  end
  b = reshape(b, size(a));
  return
end

cmd=a.Command;

% get Signal Error and Monitor (does a check if needed)
s = subsref(a,struct('type','.','subs','Signal'));
e = subsref(a,struct('type','.','subs','Error'));
m = subsref(a,struct('type','.','subs','Monitor'));
if numel(e) > 1 && all(e(:) == e(1)), e=e(1); end
if numel(m) > 1 && all(m(:) == m(1)), m=m(1); end

% make sure sparse is done with 'double' type
if strcmp(op, 'sparse')
  if ndims(a) > 2
    error([ mfileame ': Operation ' op ' can only be used on 1d/2d data sets. Object ' a.Tag ' is ' num2str(ndims(a)) 'd.' ]);
  end
  if ~strcmp(class(s), 'double') && ~strcmp(class(s), 'logical')
    s = double(s);
  end
  if ~strcmp(class(e), 'double') && ~strcmp(class(e), 'logical')
    e = double(e);
  end
  if ~strcmp(class(m), 'double') && ~strcmp(class(m), 'logical')
    m = double(m);
  end
end

% non-linear operators should perform on the Signal/Monitor
% and then multiply again by the Monitor

% operate with Signal/Monitor and Error/Monitor
if ~isempty(find(strcmp(op, {'norm','asin', 'acos','atan','cos','sin','exp','log',...
 'log10','sqrt','tan','asinh','atanh','acosh','sinh','cosh','tanh','isnan','isfinite','isinf'}))) ...
   && not(all(m(:) == 0 | m(:) == 1))
  s = genop(@rdivide, s, m);
  e = genop(@rdivide, e, m);
end

% new Signal value is set HERE <================================================
if ~isfloat(s) && ~any(strcmp(op, {'isfloat','isinteger','islogical'})), s=double(s); end

new_s = feval(op, s, varargin{:});

% handle error/monitor stuff
try
  switch op
  case 'acos'
    e = -e./sqrt(1-s.*s);
  case 'acosh'
    e = e./sqrt(s.*s-1);
  case 'asin'
    e = e./sqrt(1-s.*s);
  case 'asinh'
    e = e./sqrt(1+s.*s);
  case 'atan'
    e = e./(1+s.*s);
  case 'atanh'
    e = e./(1-s.*s);
  case 'cos'
    e = -e.*sin(s);
  case 'cosh'
    e = e.*sinh(s);
  case 'exp'
    e = e.*exp(s);
  case 'log'
    e = e./s;
  case 'log10'
    e = e./(log(10)*s);
  case 'sin'
    e = e.*cos(s);
  case 'sinh'
    e = e.*cosh(s);
  case 'sqrt'
    e = e./(2*sqrt(s));
    m = m.^0.5;
  case 'tan'
    c = cos(s);
    e = e./(c.*c);
  case 'tanh'
    c = cosh(s);
    e = e./(c.*c);
  case { 'transpose', 'ctranspose'}; % .' and ' respectively
    e = feval(op, e), varargin{:};
    m = feval(op, m, varargin{:});
  case {'sparse','full','flipud','fliplr','flipdim'}
    % apply same operator on error and Monitor
    e = feval(op, e, varargin{:});
    m = feval(op, m, varargin{:});
  case {'floor','ceil','round'}
    % apply same operator on error
    e = feval(op, e, varargin{:});
  case 'del2'
    new_s = new_s*2*ndims(a);
    e = 2*ndims(a)*del2(e);
  case {'sign','isfinite','isnan','isinf'}
    b = new_s;
    return
  case {'isscalar','isvector','issparse','isreal','isfloat','isnumeric','isinteger', ...
        'islogical','double','single','logical','find','norm','all','any','nonzeros'}
    % result is a single value or array
    b = new_s;
    return
  case {'uminus','abs','real','imag','uplus','not','conj'}
    % retain error, do nothing
  case {'sum'}
    if isscalar(new_s)
      b = new_s;
      return
    else
      try; e = sqrt(feval(op, e.^2, varargin{:})); end
      try; m = feval(op, m, varargin{:}); end
    end
  case {'permute','reshape','resize'}
    if ~isscalar(e) && ~isempty(e),  e = feval(op, e, varargin{:}); end
    if ~isscalar(m) && ~isempty(m),  m = feval(op, m, varargin{:}); end
  otherwise
    error([ mfilename, ': Can not apply operation ' op ' on object ' a.Tag ]);
  end
end
clear s

% operate with Signal/Monitor and Error/Monitor (back to Monitor data)
if ~isempty(find(strcmp(op, {'norm','asin', 'acos','atan','cos','sin','exp','log',...
 'log10','sqrt','tan','asinh','atanh','acosh','sinh','cosh','tanh'}))) ...
   && not(all(m(:) == 0 | m(:) == 1))
  new_s = genop(@times, new_s, m);
  e     = genop(@times, e, m);
end

% new object -------------------------------------------------------------------
e = abs(e);
b = copyobj(a);
b = set(b, 'Signal', new_s, 'Error', e, 'Monitor', m);
label(b, 'Signal', [  op '(' label(a, 'Signal') ')' ]);
clear new_s e m

if any(strcmp(op,{ 'transpose', 'ctranspose'})); % .' and ' respectively
  if ndims(b) > 1
    x1 = getaxis(b, '1'); % axis names
    x2 = getaxis(b, '2');
    v1 = getaxis(b, 1);   % axis values
    v2 = getaxis(b, 2);
    if ~isempty(x2), b= setaxis(b, 1, x2); set(b, x2, transpose(v2)); end
    if ~isempty(x1), b= setaxis(b, 2, x1); set(b, x1, transpose(v1)); end
  end
end
b.Command=cmd;
history(b, op, a);

