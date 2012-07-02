function h = plot(a, p, varargin)
% h = plot(model, parameters, axes, ...) plot a model
%
%   @iFunc/plot applies the function 'model' using the specified parameters and axes
%     and function parameters 'pars' with optional additional parameters. A plot of
%     the model is then produced.
%
% input:  model: model function (iFunc, single or array)
%         parameters: model parameters (vector, cell or vectors) or 'guess'
%         ...: additional parameters may be passed, which are then forwarded to the model
% output: h: handle to the plotted object (handle)
%
% ex:     b=plot(gauss); plot(gauss*lorz, [1 2 3 4, 5 6 7 8]);
%
% Version: $Revision: 1.1 $
% See also iFunc, iFunc/fit, iFunc/feval

if nargin < 2, 
  p=a.ParameterValues;
end

if ndims(a) > 3
  error([ 'iFunc:' mfilename ], 'Can only plot dimensionality <= 3. Failed to plot ndims=%d model %s\n', ndims(a), a.Name);
end
if strcmp(p, 'guess'), p=[]; end
[signal, ax, name] = feval(a, p, varargin{:});
% Parameters are stored in the updated model
if length(inputname(1))
  assignin('caller',inputname(1),a); % update in original object
end

if iscell(signal)
  h = [];
  ih = ishold;
  for index=1:numel(signal)
    if index > 1
      hold on
    end
    h = [ h iFunc_plot(name{index}, signal{index}, ax{index}) ];
    if ndims(a(index)) == 1 && strcmp(get(h(index),'Type'),'line')
      % change color of line
      colors = 'bgrcmk';
      set(h(index), 'color', colors(1+mod(index, length(colors))));
    end
    h = iFunc_plot_menu(h(index), a(index), name{index});
  end
  if ih == 1, hold on; else hold off; end
  return
end

% call the single plot method
h = iFunc_plot(name, signal, ax);
h = iFunc_plot_menu(h, a, name);

% ------------------------------------------------------------------------------
% simple plot of the model "name" signal(ax)
function h=iFunc_plot(name, signal, ax)
% this internal function plots a single model, 1D, 2D or 3D.

if isvector(signal)
  h = plot(ax{1}, signal);
elseif ndims(signal) == 2
  h = surf(ax{2}, ax{1}, signal);
elseif ndims(signal) == 3
  h =patch(isosurface(ax{2}, ax{1}, ax{3}, signal, mean(signal(:))));
  set(h,'EdgeColor','None','FaceColor','green'); alpha(0.7);
  light
  view(3)
else
  error([ 'iFunc:' mfilename ], 'Failed to plot model %s\n', name);
end

set(h, 'DisplayName', name);
title(name);

%-------------------------------------------------------------------------------
function h=iFunc_plot_menu(h, a, name)
% contextual menu for the single object being displayed
% internal functions must be avoided as it uses LOTS of memory
  uicm = uicontextmenu; 
  % menu About
  uimenu(uicm, 'Label', [ 'About ' a.Name ': ' num2str(a.Dimension) 'D model ...' ], ...
    'Callback', [ 'msgbox(getfield(get(get(gco,''UIContextMenu''),''UserData''),''properties''),' ...
                  '''About: Model ' name ''',' ...
                  '''custom'',getfield(getframe(gcf),''cdata''), get(gcf,''Colormap''));' ] );
  uimenu(uicm, 'Label', name);

  % make up title string and Properties dialog content
  properties={ [ 'Model ' a.Tag ': ' num2str(ndims(a)) 'D model' ], ...
               [ 'Name: ' name ], ...
               [ 'Description: ' a.Description ]};

  % Expression
  if ~isempty(a.Constraint)
    u = char(a.Constraint); u=strtrim(u); u(~isstrprop(u,'print'))=''; if ~isvector(u), u=u'; end
    if length(u) > 300, u = [ u(1:297) '...' ]; end
    properties{end+1} = [ 'Constraint: ' u(:)' ];
  end

  u = char(a.Expression); u=strtrim(u); u(~isstrprop(u,'print'))=''; if ~isvector(u), u=u'; end
  if length(u) > 300, u = [ u(1:297) '...' ]; end
  properties{end+1} = [ 'Expression: ' u(:)' ];

  properties{end+1} = '[Parameters]';
  for p=1:length(a.Parameters)
    [name, R] = strtok(a.Parameters{p}); % make sure we only get the first word (not following comments)
    R = strtrim(R);
    u = sprintf('  p(%3d)=%20s', p, name);
    val  = [];
    if ~isempty(a.ParameterValues)
    try
      val = a.ParameterValues(p);
    end
    end
    if ~isempty(val), u = [ u sprintf('=%g', val) ]; end
    if ~isempty(R),   u = [ u sprintf('  %% entered as: %s', R) ]; end
    properties{end+1} = u;
  end

  ud.properties=properties;     
  ud.handle = h;

  set(uicm,'UserData', ud);
  set(h,   'UIContextMenu', uicm); 
