function s = sqw_spinwave(file, action)
% sqw_spinwave: build a SpinWave model (S. Petit/LLB)
%
% Performs a SPINWAVE calculation using S. Petit/LLB code. The input file can be:
%   * a spinwave input file, such as MnFe4Si3.txt (in Data)
%   * a CIF/CFL/ShelX file. In this case only the structure is imported, and
%       it is REQUIRED to edit the generated model in particular 
%       the moment type 'NOM' and couplings J1,D1 (J2,D2) must be set.
%   * 'defaults' will use an example.
%
% The input file may contain tokens to identify variable model patrameters.
% The tokens format can be '$par' or '($par=val)' to specify default values.
% 
% You may edit the SPINWAVE input file anytime with: sqw_spinwave(model, 'edit')
%
% Reference: SpinWave, S. Petit LLB <http://www-llb.cea.fr/logicielsllb/SpinWave/SW.html>
%
% model = sqw_spinwave(file)
%
% input:
%   file: file name of a SpinWave input file
%
% output:
%   model: SpinWave model [iFunc_Sqw4D]
%
% Example:
%   m = sqw_spinwave('defaults');
%   m = sqw_spinwave('MnFe4Si3.txt'); S=iData(m, [], 0:.05:15, 0,0, 0:0.5:20);
%   plot(log10(S));

if nargin < 1, file = ''; end
if nargin < 2, action = ''; end
s = []; template = '';

if isa(file, 'iFunc')
  ud = file.UserData;
  if isfield(ud,'spinwave_template')
    template = ud.spinwave_template;
  end
  if isfield(ud,'spinwave_filename')
    file = ud.spinwave_filename;
  end
  action = 'edit';
end

if strcmp(file, 'defaults')
  file = 'MnFe4Si3.txt';
end

if isempty(file)
  [filename, pathname, filterindex] = uigetfile('*.*', 'Pick a SpinWave template file');
  if isempty(filename) || isequal(filename, 0), return; end
  file = fullfile(pathname, filename);
end

% check if this is a CIF/CFL/ShelX file
if isempty(template)
  template = cif2spinwave(file);
  if ~isempty(template), action = 'edit'; end % NEED to edit the generated template
end

if isempty(template)
  % read the file content
  try
    template = fileread(file);
  catch ME
    disp([ mfilename ': ERROR: Can not read SPINWAVE template from ' file ]);
    return
  end
end

if iscellstr(template)
  template = sprintf('%s\n', template{:});
end
if isempty(template) || ~ischar(template)
  disp([ mfilename ': ERROR: Invalid SPINWAVE template from ' file ]);
end

% TEMPLATE ---------------------------------------------------------------------
% remove any SCAN stuff
for tok={'Q0X','Q0Y','Q0Z','WMAX','NP','DQX','DQY','DQZ','COUPE','EN0', ...
  'COUP1D','DQ1X','DQ1Y','DQ1Z','DQ2X','DQ2Y','DQ2Z','DQ3X','DQ3Y','DQ3Z', ...
  'NP1','NP2','NP3','NW'}
  template = regexprep(template, [ tok{1} '=\d+\.?\d*,?' ], '');
end
% must also remove 'FICH=filename' as we shall put our own
template = regexprep(template, 'FICH=\w+\.?\w*,?', '');
% and remove any empty lines
template = textscan(template, '%s', 'Delimiter', '\n\r'); template = strtrim(template{1});
template(cellfun(@isempty, template)) = [];
% rebuild single char
template = sprintf('%s\n', template{:});

% EDIT template when requested to
if strcmp(action, 'edit')
  disp([ mfilename ': Modify the SPINWAVE template from file ' file ])
  disp ' * Check cell parameters'
  disp ' * remove non magnetic atoms (change the "I=" index for those remaining)'
  disp ' * check magnetic moments type ("NOM=")'
  disp ' * check/add coupling I1= I2= J1= and cut-off distance D1 (possibly and J2= D2=)'
  disp ' * indicate variable parameters with syntax "($par=default_value)"'
  disp ' * you do not need to enter HKLE scan specifications nor output file "FICH"'
  disp 'You may edit the SPINWAVE template anytime with sqw_spinwave(model, ''edit'')'
  h = TextEdit(template);
  waitfor(h)
end

% Search for $xx and %xx tokens in file, as well as '(%par,value)' and '($par,value)'

% get parameters with default values or not
tokens1 = regexp(template, '\([\$|\%]\w*[=|:|,|\s]\d+\.?\d*\)','match');
tokens2 = regexp(template, '[\$|\%]\w*','match');

% clean up tokens: remove '%$():=,' and get default values or 0
tokens = [ tokens1 tokens2 ]; 
pars   = {};
guess  = [];
for index=1:numel(tokens)
  tok = tokens{index};
  tok = strtrim(regexprep(tok, '[\$|\%|\(|\)]',' '));
  [tok,val] = strtok(tok, ':=, ');
  val = str2double(val(2:end));
  if ~isfinite(val), val = 0; end
  % is this parameter already there or new one ?
  found = find(strcmp(tok, pars));
  if isempty(found)
    pars{end+1}  = strtrim(tok);
    guess(end+1) = val;
  elseif guess(found) == 0 && val
    guess(found)  = val; % upgrade default value
  end
  % change tokens in the template, now that we have the values
  template = strrep(template, tokens{index}, [ '$' tok ]);
end

% Model structure --------------------------------------------------------------
[p,f] = fileparts(file);

s.Name       = [ 'SpinWave S.Petit (LLB) ' f ' [' mfilename ']' ];
s.Description= 'A spin-wave dispersion(HKL) from S. Petit';
s.Parameters = pars;    % parameter names
s.Guess      = guess;   % default values
s.ParameterValues = guess;
s.Dimension  = 4;

disp([ 'Building: ' s.Name ' from ' file ])

% store the template in the UserData
s.UserData.spinwave_template = template;
s.UserData.spinwave_filename = file;
s.UserData.dir      = ''; % will use temporary directory to generate files and run
s.UserData.executable = find_executable;

if isempty(s.UserData.executable)
  error([ mfilename ': SPINWAVE is not available. Install it from <http://www-llb.cea.fr/logicielsllb/SpinWave/SW.html>' ])
end

% get code to read xyzt and build HKL list and convolve DHO line shapes
script_hkl = sqw_phonons_templates;
if ismac,      precmd = 'DYLD_LIBRARY_PATH= ;';
elseif isunix, precmd = 'LD_LIBRARY_PATH= ; '; 
else           precmd = ''; end

% the Model expression, calling spinwave executable
s.Expression = { ...
  [ 'target = this.UserData.dir;' ], ...
  'if ~isdir(target), target = tempname; mkdir(target); this.UserData.dir=target; end', ...
  [ '% replace tokens as variable parameters in the template ' num2str(numel(s.Parameters)) ]...
  'template = this.UserData.spinwave_template;' ...
  'for index=1:numel(this.Parameters)' ...
  '  template = strrep(template, [ ''%'' this.Parameters{index} ], num2str(p(index)));' ...
  '  template = strrep(template, [ ''$'' this.Parameters{index} ], num2str(p(index)));' ...
  'end' ...
  'template = [ template sprintf(''FICH=%s\n'', fullfile(target,''results.dat'')) ];' ...
  script_hkl{:}, ...
  'xu =unique(x(:)); yu=unique(y(:)); zu=unique(z(:)); tu=unique(t(:));', ...
  'dax={(max(xu)-min(xu))/numel(xu),(max(yu)-min(yu))/numel(yu),(max(zu)-min(zu))/numel(zu)};' ...
  'sz= [ numel(xu) numel(yu) numel(zu) ];', ...
  'allvect = all(cellfun(@(c)max(size(c)) == numel(c), {x y z})) && ((numel(unique(sz)) == 2 && min(sz)==1) || numel(unique(sz)) == 1);' ...
  'ax={xu,yu,zu}; N_id = ''XYZ'';' ...
  '[dummy,L_id] = min(sz);             % the smallest Q dimension (loop)', ...
  'G_id = find(L_id ~= 1:length(sz));  % the other 2 sizes in grid', ...
  'if (allvect), ' ...
    'tuu=1; axL = 1;' ...
    'signal = zeros([ max(sz) numel(tu) ]);' ...
  'else' ...
    'tuu=tu; axL = ax{L_id};' ...
    'signal = zeros([ sz numel(tu) ]);' ...
  'end' ...
  'for ie=1:numel(tuu)' ...
    'if (allvect),' ...
      'templateE = [ template  sprintf(''WMIN=%g,WMAX=%g,NW=%i\n'', min(tu), max(tu), numel(tu)) ];' ...
      'templateE = [ templateE sprintf(''Q0X=%g,Q0Y=%g,Q0Z=%g\n'', min(xu),min(yu),min(zu)) ];' ...
      'templateE = [ templateE sprintf(''DQX=%g,DQY=%g,DQZ=%g\n'', dax{:}) ];' ...
      'templateE = [ templateE sprintf(''NP=%i\n'', max(sz) ) ];' ...
    'else' ...
      'templateE = [ template sprintf(''COUPE,EN0=%g,NP1=%i,NP2=%i\n'', tu(ie), numel(ax{G_id(1)}), numel(ax{G_id(2)})) ];' ...
      'volHKL = zeros(sz);' ...
    'end' ...
    'for is=1:numel(axL)' ...
      '% starting point' ...
      'if (allvect), ' ...
        'templateHKL = templateE;' ...
      'else' ...
        'Qs = ax{L_id};' ...
        'templateHKL = [ templateE   sprintf(''Q0%c=%g\n'',N_id(L_id),Qs(is)) ];' ...
        'templateHKL = [ templateHKL sprintf(''Q0%c=%g\n'',N_id(G_id(1)),min(ax{G_id(1)}) ) ];' ...
        'templateHKL = [ templateHKL sprintf(''Q0%c=%g\n'',N_id(G_id(2)),min(ax{G_id(2)}) ) ];' ...
        'templateHKL = [ templateHKL sprintf(''DQ1%c=%g\n'',N_id(L_id),0) ];' ...
        'templateHKL = [ templateHKL sprintf(''DQ2%c=%g\n'',N_id(L_id),0) ];' ...
        'templateHKL = [ templateHKL sprintf(''DQ1%c=%g\n'',N_id(G_id(1)),dax{G_id(1)}) ];' ...
        'templateHKL = [ templateHKL sprintf(''DQ2%c=%g\n'',N_id(G_id(1)),0) ];' ...
        'templateHKL = [ templateHKL sprintf(''DQ1%c=%g\n'',N_id(G_id(2)),0) ];' ...
        'templateHKL = [ templateHKL sprintf(''DQ2%c=%g\n'',N_id(G_id(2)),dax{G_id(2)}) ];' ...
      'end' ...
      '% write the spinwave input file and execute' ...
      'this.UserData.spinwave_input = templateHKL;' ...
      'try' ...
        'fid = fopen(fullfile(target, ''input.txt''), ''w'');' ...
        'fprintf(fid, ''%s'', templateHKL);' ...
        'fclose(fid)' ...
        [ 'cmd = [ ''' precmd s.UserData.executable ' < '' fullfile(target,''input.txt'') '' > '' fullfile(target,''spinwave.log'') ];' ] ...
        '[status,result] = system(cmd);', ...
        '% get result 5th column and catenate' ...
        'cut2D = load(fullfile(target,''results.dat''),''-ascii'');' ...
        'cut2D = cut2D(:,5);' ...
      'catch ME;', ...
        'disp([ ''model '' this.Name '' '' this.Tag '': FAILED running SPINWAVE'' target ]);' ...
        'disp([ ''  from '' target ]);' ...
        'disp(getReport(ME)); cut2D=[]; break;', ...
      'end', ...
      'if (allvect)' ...
        'signal = transpose(reshape(cut2D, numel(tu), max(sz)));' ...
      'else' ...
        'if     L_id == 1, volHKL(is,:,:) = cut2D;' ...
        'elseif L_id == 2, volHKL(:,is,:) = cut2D;' ...
        'else              volHKL(:,:,is) = cut2D; end' ...
      'end' ...
    'end % for is' ...
    'if (~allvect), signal (:,:,:,ie) = volHKL; end' ...
  'end % for ie' ...
  };


% build the iFunc
s = iFunc(s);
s = iFunc_Sqw4D(s); % overload Sqw4D flavour

end % sqw_spinwave

% ------------------------------------------------------------------------------

function executable = find_executable
  % find_executable: locate executable, return it
  
  % stored here so that they are not searched for further calls
  persistent found_executable
  
  if ~isempty(found_executable)
    executable = found_executable;
    return
  end
  
  if ismac,      precmd = 'DYLD_LIBRARY_PATH= ;';
  elseif isunix, precmd = 'LD_LIBRARY_PATH= ; '; 
  else           precmd=''; end
  
  if ispc, ext='.exe'; else ext=''; end
  
  executable  = [];
  this_path   = fullfile(fileparts(which(mfilename)));
  
  % what we may use. Prefer local installation.
  for exe =  { [ 'spinwave_' computer('arch') ], 'spinwave', 'spinwave2p2' }
    if ~isempty(executable), break; end
    for try_target={ ...
      fullfile(this_path, [ exe{1} ext ]), ...
      fullfile(this_path, [ exe{1} ]), ...
      [ exe{1} ext ], ... 
      fullfile(this_path, 'private', [ exe{1} ext ]), ...
      fullfile(this_path, 'private', [ exe{1} ]), ...
      exe{1} }
      
      [status, result] = system([ precmd try_target{1} ]);

      if status ~= 127
        % the executable is found
        executable = try_target{1};
        disp([ mfilename ': found ' exe{1} ' as ' try_target{1} ])
        break
      end
    end
  
  end
  
  if isempty(executable)
    executable = compile_spinwave;
  end
  
  found_executable = executable;
  
end % find_executable

% ------------------------------------------------------------------------------
function executable = compile_spinwave
  % compile spinwave 2.2 from S. Petit LLB
  executable = '';
  if ismac,      precmd = 'DYLD_LIBRARY_PATH= ;';
  elseif isunix, precmd = 'LD_LIBRARY_PATH= ; '; 
  else           precmd=''; end
  
  if ispc, ext='.exe'; else ext=''; end

  % search for a fortran compiler
  fc = '';
  for try_fc={getenv('FC'),'gfortran','g95','pgfc','ifort'}
    if ~isempty(try_fc{1})
      [status, result] = system([ precmd try_fc{1} ]);
      if status == 4 || ~isempty(strfind(result,'no input file'))
        fc = try_fc{1};
        break;
      end
    end
  end
  if isempty(fc)
    if ~ispc
      disp([ mfilename ': ERROR: FORTRAN compiler is not available from PATH:' ])
      disp(getenv('PATH'))
      disp([ mfilename ': Try again after extending the PATH with e.g.' ])
      disp('setenv(''PATH'', [getenv(''PATH'') '':/usr/local/bin'' '':/usr/bin'' '':/usr/share/bin'' ]);');
    end
    error('%s: Can''t find a valid Fortran compiler. Install any of: gfortran, g95, pgfc, ifort\n', ...
    mfilename);
  end
  
  % when we get there, target is spinwave_arch, not existing yet
  this_path = fileparts(which(mfilename));
  target = fullfile(this_path, 'private', [ 'spinwave_' computer('arch') ext ]);

  % attempt to compile as local binary
  if isempty(dir(fullfile(this_path,'private','spinwave'))) % no executable available
    fprintf(1, '%s: compiling binary...\n', mfilename);
    % gfortran -o spinwave -O2 -static spinwave.f90
    cmd = {fc, '-o', target, '-O2', '-static', ...
       fullfile(this_path,'private', 'spinwave.f90')}; 
    disp([ sprintf('%s ', cmd{:}) ]);
    [status, result] = system([ precmd sprintf('%s ', cmd{:}) ]);
    if status ~= 0 % not OK, compilation failed
      disp(result)
      warning('%s: Can''t compile spinwave.f90 as binary\n       in %s\n', ...
        mfilename, fullfile(this_path, 'private'));
    else
      delete(fullfile(this_path,'private', '*.mod'));
      executable = target;
    end
  end
  
end % compile_spinwave

% ------------------------------------------------------------------------------

function template = cif2spinwave(c)
  % generate a SpinWave input file from a CIF/CFL/ShelX
  template = '';
  try
    c = iLoad(c);
  end
  if isfield(c, 'Data'), c=c.Data; end
  if ~isfield(c, 'structure'), return; end
  
  % c.cell is the cell definition
  template = { ...
   '# SpinWave input file S. Petit LLB <http://www-llb.cea.fr/logicielsllb/SpinWave/SW.html>', ...
   '#' ...
   [ '# ' datestr(now) ] ...
   [ '# ' c.title ], ...
   [ '# File:       ' c.file ], ...
   [ '# Spacegroup: ' c.Spgr ], ...
   '#' ...
   '# What you need to do:' ...
   '# * Check cell parameters' ...
   '# * remove non magnetic atoms (change the "I=" index for those remaining)' ...
   '# * check magnetic moments type ("NOM=")' ...
   '# * check/add coupling I1= I2= J1= and cut-off distance D1 (possibly and J2= D2=)' ...
   '# * indicate variable parameters with syntax "($par=default_value)"' ...
   '# * you do not need to enter HKLE scan specifications nor output file "FICH"' ...
   '# You may edit the SPINWAVE template anytime with sqw_spinwave(model, ''edit'')' ...
   '#' ...
   '# ---------------------------------------------------------' ...
   '# definition of the unit cell' ...
   sprintf('AX  = %g', c.cell(1)) ...
   sprintf('AY  = %g', c.cell(2)) ...
   sprintf('AZ  = %g', c.cell(3)) ...
   sprintf('ALFA= %g', c.cell(4)) ...
   sprintf('BETA= %g', c.cell(5)) ...
   sprintf('GAMA= %g', c.cell(6)) ...
   '#' ...
   '# ---------------------------------------------------------' ...
   '# position of the spins' ...
   '# NOM=name of the spin, SD2 = spin 1/2 ' ...
   '# line format: I=,NOM=,X=,Y=,Z=,PHI=120,THETA=90,CZ=1' ...
  };
   
  % add the atom locations, and their spin
  % usual nuclear spin table: http://vamdc.eu/documents/standards/dataModel/vadcxsams/appAtoms.html
  %
  % from SpinWave manual: magnetic moment
  %    Ion	J	    gJ 	  α
  %   --------------------
  %    ND	  9/2	  8/11	−7/(9 × 121)
  %    ER	  15/2	6/5	  4/(9 × 25 × 7)
  %    YB	  7/2	  8/7	  2/63
  %    HO	  8	    5/4	  −1/(2 × 9 × 25)
  %    TB	  6	    3/2	  −1/99
  %    PR	  4	    4/5	  −4 × 13/(9 × 25 × 11)
  %    DY	  15/2	4/3	  −2/(9 × 5 × 7)
  %    CE	  5/2	  6/7	  1
  %    S1	  1	    2	    1
  %    S2	  2	    2	    1
  %    S3	  3	    2	    1
  %    S4	  4	    2	    1
  %    S5	  5	    2	    1
  %    S6	  6	    2	    1
  %    S7	  7	    2	    1
  %    S8	  8	    2	    1
  %    S9	  9	    2	    1
  %    S10	10	  2	    1
  %    SD2	1/2	  2	    1
  %    S3D2	3/2	  2	    1
  %    S5D2	5/2	  2	    1
  %    MN3	2	    2	    1
  %    MN4	3/2	  2   	1
  %    FE3	5/2	  2	    1

  atoms = fieldnames(c.structure);
  known='ND ER YB HO TB PR DY CE MN FE'; 
  known = textscan(known, '%s','Delimiter',' '); known = known{1};
  % except for known atoms, we use a J=1/2 
  for index=1:numel(atoms)
    name  = atoms{index};
    xyz   = c.structure.(name); % x y z B occ Spin Charge
    template{end+1} = sprintf('# atom: %s', name); 
    found = find(strncmp(lower(known), lower(name), 2));
    if ~isempty(found), name = known{found}; else name = 'SD2'; end
    template{end+1} = sprintf('I=%i,NOM=%s,X=%g,Y=%g,Z=%g,PHI=120,THETA=90,CZ=1', ...
      index, upper(name), xyz(1), xyz(2), xyz(3)); 
  end % atom

  % add comment on J to be edited by use
  template{end+1} = '#';
  template{end+1} = '# ---------------------------------------------------------';
  template{end+1} = '# Couplings. Enter lines specifying J1 (and optionally J2) with cut-off distances';
  template{end+1} = '# line format: I1=1 ,I2=4, J1=0, D1=4, J2=-4, D2=4.4';
  template{end+1} = '#';
  template{end+1} = '# ---------------------------------------------------------';
  template{end+1} = '# calculation';
  template{end+1} = '#';
  template{end+1} = 'FFORM';
  template{end+1} = '# method, with REG a regularization term (should be small compared to J)';
  template{end+1} = 'CALC=2,REG1=0.05,REG2=0.05,REG3=0.05';
  template{end+1} = '#';
  template{end+1} = '# MF iterations to find the stable structure';
  template{end+1} = 'MF,NITER=100';
  
  template = sprintf('%s\n', template{:});
  
end % cif2spinwave 
