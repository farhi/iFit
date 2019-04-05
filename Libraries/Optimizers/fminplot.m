function stop = fminplot(pars, optimValues, state)
% stop=fminplot(pars, optimValues, state) default plotting function showing the 
%   criteria evolution as well as main parameters and status.
% A STOP button allows premature abortion of the optimization.
% When used after the optimization, fminplot can plot the criteria convergence 
%   and parameter distributions.
% 
% To use this optimization monitoring tool, use:
%   options.OutputFcn='fminplot'
% prior to the optimization/fit.
%
% To plot the criteria convergence and parameter distributions after the 
% optimization/fit completion, use:
%   [pars,fval,exitflag,output]=fmin(@objective, [], 'OutputFcn=fminplot')
%   fminplot(output);
%
% To retrieve the optimisation history from the fminplot window, use:
%   h = fminplot;
%
% Other defined function to be used as OutputFcn and PlotFcns:
%   @fminstop           displays a stop button (very fast, allow clean abort of fit)
%   @optimplotx         plots the current point
%   @optimplotfval      plots the function value
%   @optimplotfunccount plots the function count
%
% example: 
%   fmin(@objective, [], 'OutputFcn=fminplot')

%
% $%   fits(a, 'gauss', [], 'OutputFcn=fminplot')

% fields in optimValues: funcount, fval, iteration, procedure
% state values: 'init','interrupt','iter','done'

  persistent parsHistory;
  persistent fvalHistory;
  persistent updatePlot
  
  stop = false;
  flag_input_is_struct = 0;
  
  if nargin == 0
    % retrieve the information stored in the plot
    h = findall(0, 'Tag', 'fminplot'); 
    if ~isempty(h)
      stop = get(h,'UserData');
    else
      stop.parsHistory = parsHistory;
      stop.fvalHistory = fvalHistory;
    end
    return
  elseif nargin == 1 && (strcmp(pars, 'defaults') || strcmp(pars, 'identify'))
    return;
  end
  
  old_gcf = get(0, 'CurrentFigure');
  
  if isstruct(pars)  % we feed fminplot with an 'output' structure =============
    output=pars;
    parsHistory = pars.parsHistory;
    fvalHistory = pars.criteriaHistory;
    optimValues.funcount = pars.funcCount;
    optimValues.fval     = fvalHistory(end);
    optimValues.procedure= pars.optimizer;
    pars        = parsHistory(end, :);
    state       = 'iter';
    updatePlot  = 0;
    h = findall(0, 'Tag', 'fminplot'); 
    d = findall(0, 'Tag', 'fminplot:stop');
    
    [dummy, best] = sort(fvalHistory); % sort in ascending order
    best= best(1);
    flag_input_is_struct = 1;
    
  else              % normal execution during optimization =====================
    
    if ~isempty(optimValues) && ~isfield(optimValues, 'funcount')
      if isfield(optimValues, 'funcCount')
        optimValues.funcount = optimValues.funcCount;
      elseif isfield(optimValues, 'funccount')
        optimValues.funcount = optimValues.funccount;
      end
    end
    
    % check if user has closed the figure to end the optimization
    h = findall(0, 'Tag', 'fminplot'); d = findall(0, 'Tag', 'fminplot:stop');
    if ((isempty(h) || strncmp(get(d,'String'), 'END', 3)) ...
      && ~isempty(optimValues) && optimValues.funcount) || strcmp(state, 'abort')
      if ~isempty(d)
        set(d, 'String','END','BackgroundColor','green');
      end
      stop = true;  % figure was closed: abort optimization by user
      return
    end
    % update figure name
    name = [ state ' #' sprintf('%i',optimValues.funcount) ' f=' sprintf('%g',optimValues.fval) ' ' optimValues.procedure ' [close to abort]' ];
    try
      set(h, 'Name', name);
    catch
      stop=true;  % figure is not valid: was closed
      return;
    end
    % store data history as rows
    if isempty(fvalHistory) | optimValues.funcount < 1
      parsHistory = pars(:)'; 
      fvalHistory = optimValues.fval;
    else  
      parsHistory = [ parsHistory ; pars(:)' ];
      fvalHistory = [ fvalHistory ; optimValues.fval ];
    end
    
    % determine best guess up to now
    [dummy, best] = sort(fvalHistory); % sort in ascending order
    best= best(1);
    
    if length(fvalHistory) > 10
      if ~isempty(updatePlot)
        if etime(clock, updatePlot) < 2, return; end % plot every 2 secs
      end
    end
  end % isstruct(pars) or normal iteration
    
  % handle figure
  % only retain one instance of fminplot
  if length(h) > 1, delete(h(2:end)); h=h(1); end
  if isempty(h) && (optimValues.funcount <=2 || flag_input_is_struct) % create it
    h = figure('Tag','fminplot', 'Unit','pixels','MenuBar','figure', 'ToolBar', 'figure');
    ishidden = 0;
    tmp = get(h, 'Position'); tmp(3:4) = [500 400];
    set(h, 'Position', tmp);
    % add a 'STOP' button: push-button
    d = uicontrol(h, 'String','START','Callback','fminplot([],[],''abort'');', ...
      'Tag','fminplot:stop','ToolTip','Click here to abort optimization');
    % add context menu to plot histograms, dialogue with parameters
    uicm = uicontextmenu;
    uimenu(uicm,'Label','Plot parameter histograms...', ...
      'Callback','fminplot(get(gcf,''UserData''));');
    uimenu(uicm,'Label','Show best parameters...',...
      'Callback','helpdlg(num2str(getfield(get(gcf,''UserData''),''parsBest'')),''Best parameters'')');
    set(h, 'uicontextmenu', uicm);
  end

  try
    % raise existing figure (or keep it hidden)
    if old_gcf ~= h, set(0, 'CurrentFigure', h); end
  catch
    stop=true;  % figure is not valid: was closed
    return;
  end
  
  % update button label and color
  d = findall(h, 'Tag', 'fminplot:stop');
  set(d, 'String','STOP','BackgroundColor','red');
  
  % handle first subplot: criteria
  subplot(1,2,1); % this subplot shows the criteria
  hold off
  iterHistory = 1:length(fvalHistory);
  g=plot(iterHistory, fvalHistory,'b-', ...
    iterHistory(1),   fvalHistory(1),'ro', ...
    iterHistory(best),fvalHistory(best),'gv', ...
    iterHistory(end), fvalHistory(end), 'rs');
  set(g(end),'MarkerFaceColor','r');
  set(g(end-1),'MarkerFaceColor','g');
  if all(fvalHistory > 0) set(gca, 'yscale', 'log'); end
  xlabel([ 'Nb of Function Evaluations. ' sprintf('%i',length(pars)) ' Pars' ]); 
  ylabel('Criteria - {\bf Close figure to abort}');
  if strcmp(state, 'done')
    set(d, 'String','END','BackgroundColor','green' );
  elseif strcmp(state, 'init'), 
    set(d, 'String','INIT','BackgroundColor','yellow' );
  else
    NL = sprintf('\n');
    i = 1:length(pars);
    if length(pars) > 9
      dots = '...';
      i=1:9;
    else
      dots='';
    end
    pars=pars(:)';
    t=[' Click here to abort optimization' NL 'Start=' sprintf('%g ',parsHistory(1,i)) dots NL ...
       'Current=' sprintf('%g ',pars(i)) dots NL 'Best=' sprintf('%g ',parsHistory(best,i)) dots ];
    set(d, 'String','STOP', 'ToolTip', t);
    title([ 'Best=[' sprintf('%g ',parsHistory(best,i)) dots ']' ],'FontWeight','bold');
  end
  l = legend(g,{'Criteria','Start','Best','Last'},'Location','Best');
  axis auto
  
  % handle second subplot: parameters. The last set is highlighted
  subplot(1,2,2); % this subplot shows some parameters
  hold off
  if ~isempty(parsHistory)
    switch length(pars)
    case 1
      g=plot(fvalHistory,    parsHistory,'bo', ...
          fvalHistory(1),    parsHistory(1),'ro', ...
          fvalHistory(best), parsHistory(best),'gv', ...
          fvalHistory(end),  parsHistory(end),'rs');
      xlabel('Criteria'); ylabel('Par1'); 
    case 2
      g=plot3(parsHistory(:,1), parsHistory(:,2), fvalHistory, 'bo', ...
          parsHistory(1,1),    parsHistory(1,2), fvalHistory(1), 'ro', ...
          parsHistory(best,1), parsHistory(best,2), fvalHistory(best), 'gv', ...
          parsHistory(end,1),  parsHistory(end,2), fvalHistory(end), 'rs');
      xlabel('Par1'); ylabel('Par2'); zlabel('Criteria');
    otherwise
      % find the 3 first parameters that vary
      index = find(sum(abs(diff(parsHistory,1)),1));
      if length(index) > 3, index = index(1:3);
      else
        if ~any(index == 1), index = [ 1 index ]; end
        if ~any(index == 2), index = [ index 2 ]; end
        if ~any(index == 3), index = [ index 3 ]; end
      end
      g=plot3(parsHistory(:,index(1)), parsHistory(:,index(2)),   parsHistory(:,index(3)), 'bo', ...
            parsHistory(1,index(1)),   parsHistory(1,index(2)),   parsHistory(1,index(3)), 'ro', ...
            parsHistory(best,index(1)),parsHistory(best,index(2)),parsHistory(best,index(3)), 'gv', ...
            parsHistory(end,index(1)), parsHistory(end,index(2)), parsHistory(end,index(3)), 'rs');
      xlabel([ 'Par' sprintf('%i',index(1)) ]); ylabel([ 'Par' sprintf('%i',index(2)) ]); zlabel([ 'Par' sprintf('%i',index(3)) ]); 
    end
  end
  
  set(g(end),'MarkerFaceColor','r');
  set(g(end-1),'MarkerFaceColor','g');

  % resize axis frame to display title properly
  p=get(gca,'Position'); p(4)=0.75; set(gca,'Position',p);
  title([ '#' sprintf('%i',length(fvalHistory)) ' f=' sprintf('%g',optimValues.fval) ' [close to abort]' sprintf('\n') optimValues.procedure  ]);
  axis auto
  
  updatePlot=clock;
  drawnow
  try
    set(0, 'CurrentFigure', old_gcf);
  end % figure may have been closed in the mean time, so be tolerant...
  
  % store optimisation info in UserData for further use
  set(h(1),'UserData', struct('parsHistory',parsHistory,...
        'fvalHistory',fvalHistory,'best',best, 'parsBest',parsHistory(best,:),...
        'criteriaHistory',fvalHistory,'optimizer',optimValues.procedure, ...
        'funcCount',optimValues.funcount)); 
  
  if flag_input_is_struct
    fminplot_View_Parameters_Histograms(output);
  end

end

% ------------------------------------------------------------------------------

function fminplot_View_Parameters_Histograms(o)
  % display the Parameter distribution histograms
  
  % requires a structure with fields:
  %   optimizer
  %   parsBest
  %   criteriaHistory
  %   parsHistoryUncertainty
  if isempty(o), return; end
  if iscell(o), o=o{1}; end
  
  if ~isfield(o, 'parsHistoryUncertainty') || ~any(o.parsHistoryUncertainty>0)
    % compute the uncertainty if missing (from History)
    index      = find(o.criteriaHistory < min(o.criteriaHistory)+std(o.criteriaHistory)/2);   % identify tolerance region around optimum 
    if length(index) < 3
      index = 1:length(o.criteriaHistory);
    end
    try
      delta_pars = (o.parsHistory(index,:)-repmat(o.parsBest,[length(index) 1])); % get the corresponding parameter set
      o.parsHistoryUncertainty = std(delta_pars);
    end
  end
  
  titl = [ 'Parameter distributions: ' datestr(now) ' ' o.optimizer ];
  if isfield(o, 'model') && isfield(o.model, 'Name')
    titl = [ titl ' ' o.model.Name ];
  end
  figure('Name', titl);
  M=numel(o.parsBest);
  m=floor(sqrt(M)); n=ceil(M./m);
  index      = find(o.criteriaHistory < min(o.criteriaHistory)*10); % select a portion close to the optimum
  if numel(index)<20, index=1:numel(o.criteriaHistory); end
  
  
  
  % identify the parameters which are independent, from the Hessian Correlation matrix
  if ~isfield(o,'parsHessianCorrelation') || isempty(o.parsHessianCorrelation)
    corr = eye(M);
  else
    corr = o.parsHessianCorrelation;
  end
  parameters_independent = 1./sum(corr.^2);
  corr = corr - eye(M);
  
  if ~isfield(o, 'parsNames')
    o.parsNames = {};
    for P=1:M
      o.parsNames{end+1} = sprintf('[%i]', P);
    end
  end

  % plot distributions
  for P=1:M
    subplot(m,n,P);
    [N,X]=hist(o.parsHistory(index,P));
    h=bar(X,N);
    if parameters_independent(P) < 0.7, 
      set(h, 'FaceColor','red');
      [~,most_correlated] = max(abs(corr(:,P)));
      if corr(most_correlated) < 0
        most_correlated = sprintf('\nCorrelated to -%s', o.parsNames{most_correlated});
      else
        most_correlated = sprintf('\nCorrelated to %s', o.parsNames{most_correlated});
      end
    else
      most_correlated = '';
    end
    title(sprintf('p(%i):%s = %g +/- %g%s', P, ...
      o.parsNames{P}, o.parsBest(P), ...
      o.parsHistoryUncertainty(P), most_correlated));
    xlabel(o.parsNames{P});
  end
end
