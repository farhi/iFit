function v = subsref(a,S)
% a = subsref(a,index) : indexed reference
%
%   @estruct/subsref: function defines indexed assignement 
%   such as a(1:2,3)    get indexed elements in array
%           a.('b')     get single field in structure
%           a('b')      get complex field in structure and follow links
%
%   The special syntax a('f1.f2') allows recursive field reference and follows
%   links, e.g. a=estruct('f1',1,'f2','f1'); a('f2') is a.f1=1
%
% Version: $Date$
v = [];
if numel(a) > 1
  v = {};
  for index=1:numel(a)
    v{end+1} = subsref(a(index),S);
  end
  if numel(v) == 1, v=v{1}; end
  return
end

% we use the default subsasgn except for single level assigment
%   S.type = '()';
%   ischar(S.subs) -> set(a, S.subs, val, link)
if numel(S) == 1 && strcmp(S.type,'()') && iscellstr(S.subs)
  v = get(a, S.subs{1},'link'); % new syntax a('fields')
  return
end

% special syntax not handled: use builtin
v = builtin('subsref', a, S);


