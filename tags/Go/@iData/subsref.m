function b = subsref(a,S)
% b = subsref(a,s) : iData indexed references
%
%   @iData/subsref: function returns subset indexed references
%   such as a(1:2) or a.field.
%   The special syntax a{0} where a is a single iData returns the signal, and a{n} returns the axis of rank n.
%
% See also iData, iData/subsasgn

% This implementation is very general, except for a few lines
% EF 27/07/00 creation
% EF 23/09/07 iData impementation

b = a;  % will be refined during the index level loop

if isempty(S)
  return
end

for i = 1:length(S)     % can handle multiple index levels
  s = S(i);
  switch s.type
  case '()'             % extract Data using indexes
    if length(b(:)) > 1   % iData array
      b = b(s.subs{:});
    else                  % single iData
      % this is where specific class structure is taken into account
      if ischar(s.subs{:}), b=get(b, s.subs{:}); return; end
      d=get(b,'Signal'); d=d(s.subs{:});  b=set(b,'Signal', d);

      d=get(b,'Error');  d=d(s.subs{:}); b=set(b,'Error', d);

      d=get(b,'Monitor'); d=d(s.subs{:}); b=set(b,'Monitor', d);

      % must also affect axis
      for index=1:ndims(b)
        if index <= length(b.Alias.Axis)
          x = getaxis(b,index);
          if all(size(x) == size(b)) % meshgrid type axes
            b = setaxis(b, index, x(s.subs{:}));
          else  % vector type axes
            b = setaxis(b, index, x(s.subs{index}));
          end
        end
      end
      
      b = copyobj(b);
      
      % add command to history
      if ~isempty(inputname(2))
        toadd = [ inputname(2) ];
      elseif length(s.subs) == 1
        toadd = [  mat2str(double(s.subs{1})) ];
      elseif length(s.subs) == 2
        toadd = [  mat2str(double(s.subs{1})) ', ' mat2str(double(s.subs{2})) ];
      else
        toadd = [ toadd ', ' '<not listable>' ];  
      end
      if ~isempty(inputname(1))
        toadd = [  b.Tag ' = ' inputname(1) '(' toadd ');' ];
      else
        toadd = [ b.Tag ' = ' a.Tag '(' toadd ');' ];
      end
  
      b = iData_private_history(b, toadd);
      % final check
      b = iData(b);
    end               % if single iData
  case '{}'
    if length(b(:)) > 1   % iData array
      b = b(s.subs{:});
    else
      if length(s.subs{:}) == 1
        b=getaxis(b, s.subs{:});
      else
        iData_private_error(mfilename, [ 'do not know how to extract cell index in ' inputname(1)  ' ' b.Tag '.' ]);
      end
    end
  case '.'
    if ~isstruct(b)
      b = get(b,s.subs);          % get field from iData
    else
      b = getfield(b,s.subs);     % get field from struct
    end
  end   % switch s.type
end % for s index level
