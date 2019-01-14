function result = test_Models_Factory

% check that all Models can be instantiated and evaluated (with guess)

  p = fullfile(fileparts(which('lorz')), 'Factory');
  % get all M-files in there
  m = getfield(what(p), 'm');
  success = {};
  failed_instantiate = {};
  failed_eval        = {};
  
  for index=1:numel(m)
    % name of Model script
    [~,this] = fileparts(m{index});
    
    try
      model = feval(this,'defaults'); % needed to avoid GUI dialogue
    catch
      model = [];
      failed_instantiate{end+1} = this;
    end
    
    try
      value = feval(model);
    catch
      value = [];
      failed_eval{end+1} = this;
    end
    
    if ~isempty(value), success{end+1}=this; end
    
  end
  
  if numel(success) == numel(m)
    result = [ 'OK     ' mfilename ' (' num2str(numel(m)) ' models in ' p ')' ];
  else
    result = [ 'FAILED ' mfilename ];
    disp('Failed instantiate:')
    fprintf(1, '%s ', failed_instantiate{:});
    disp(' ')
    disp('Failed evaluate:')
    fprintf(1, '%s ', failed_eval{:});
    disp(' ')
  end
