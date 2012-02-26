function [data, format] = iLoad(filename, loader, varargin)
% [data, loader] = iLoad(file, loader, ...)
%
% imports any data into Matlab. 
% The definition of specific formats can be set in the iLoad_ini.m file.
% These formats can be obtained using [config, configfile]=iLoad('load config').
% The file formats cache can be rebuilt with 
%   iLoad force
% the iLoad_ini configuration file can be saved in the Preference directory
% using 
%   [config, configfile] = iLoad(config,'save config').
% A list of all supported formats is shown with 
%   iLoad('formats');
%
%   Default supported formats include: any text based including CSV, Lotus1-2-3, SUN sound, 
%     WAV sound, AVI movie, NetCDF, FITS, XLS, BMP GIF JPEG TIFF PNG ICO images,
%     HDF4, HDF5, MAT workspace, XML.
%   Other specialized formats include: McStas, ILL, SPEC, ISIS/SPE, INX, EDF.
%   Compressed files are also supported, with on-the-fly extraction (zip, gz, tar, Z).
%
%   Distant files are supported through e.g. URLs such as 
%     file://, ftp:// http:// and https://
%   File names may end with an internal anchor reference '#anchor", as used in HTML 
%     links, in which case the members matching the anchor are returned.
%
% input arguments:
%   file:   file name, or cell of file names, or any Matlab variable, or a URL
%             or an empty string (then pops'up a file selector)
%   loader: a function name to use as import routine, OR a structure with:
%             loader = 'auto' (default) 
%             loader = 'gui' (asks for the format to use)
%             loader.method = 'function name'
%             loader.options= string of options to catenate after file name
%                          OR cell of options to use as additional arguments
%                             to the method
%   additional arguments are passed to the import routine.
%
% output variables:
%   data:   a single structure containing file data, or a cell of structures
%   loader: the loader that was used for importation, or a cell of loaders.
%
% example: iLoad; iLoad('file'); iLoad('http://path/name'); iLoad('file.zip')
%          iLoad('file#anchor');
%
% See also: importdata, load, iLoad_ini
%
% Part of: iFiles utilities (ILL library)
% Author:  E. Farhi <farhi@ill.fr>. 
% Version: $Revision: 1.60 $

% calls:    urlread
% optional: uigetfiles, looktxt, unzip, untar, gunzip (can do without)
% private:  iLoad_loader_auto, iLoad_config_load, iLoad_config_save, 
%           iLoad_import, iLoad_loader_check, findfields

persistent config

data = []; format = [];
if nargin == 0, filename=''; end
if nargin < 2,  loader = ''; end
if nargin ==1
  if ~isempty(strmatch(filename, {'load config','config','force','force load config','formats','display config'}))
    [data, format] = iLoad('', filename);
    return
  end
end
if any(strcmp(loader, {'load config','config'}))
  if isempty(config), config  = iLoad_config_load; end
  % check for availability of looktxt as MeX file, and trigger compilation if needed.
  if exist('looktxt') ~= 3
    looktxt('--version');
  end
  % look for a specific importer when filename is specified
  if ~isempty(filename)
    data = {};
    for index=1:length(config.loaders)
      this = config.loaders{index};
      keepme=0;
      if ~isempty(strfind(lower(this.name), lower(filename))) | ~isempty(strfind(lower(this.method), lower(filename)))
        keepme = 1;
      elseif isfield(this,'extension') && ~isempty(strmatch(lower(filename), lower(this.extension)))
        keepme=1;
      end
      if keepme, data = { data{:} this }; end
    end
    if length(data) == 1
      data = data{1}; 
    end
  else
    data = config;
  end
  return
elseif any(strcmp(loader, {'force','force load config'}))
  config  = iLoad_config_load;
  if ~isempty(filename)
    data    = iLoad(filename, 'load config');
  else
    data    = config;
  end
  return
elseif strcmp(loader, 'formats') | strcmp(loader, 'display config')
  data = iLoad('','load config');
  fprintf(1, ' EXT                    READER  DESCRIPTION [%s]\n', mfilename);
  fprintf(1, '-----------------------------------------------------------------\n');  
  for index=1:length(data.loaders)
    this=data.loaders{index};
    if isfield(this,'postprocess'), 
      if ~isempty(this.postprocess)
        if iscell(this.postprocess)
          for i=1:length(this.postprocess)
            this.method = [ this.method '/' this.postprocess{i} ]; 
          end
        else
          this.method = [ this.method '/' this.postprocess ]; 
        end
      end
    end
    if length(this.method)>25, this.method = [ this.method(1:22) '...' ]; end
    if ~isfield(this,'extension'), this.extension = '*';
    elseif isempty(this.extension), this.extension='*'; end
    if iscellstr(this.extension)
      fprintf(1,'%4s %25s  %s\n', upper(this.extension{1}), this.method,this.name);
      for j=2:length(this.extension),fprintf(1,'  |.%s\n', upper(this.extension{j})); end
    else
      fprintf(1,'%4s %25s  %s\n', upper(this.extension), this.method,this.name);
    end
  end
  disp([ '% iLoad configuration file: ' config.FileName ]);
  if ~isempty(filename)
    data    = iLoad(filename, 'load config');
  end
  return
elseif strcmp(loader, 'save config') | strcmp(filename, 'save config')
  if isempty(filename) || nargin == 1
    config  = iLoad('','load config');
  else
    config = filename;
  end
  data = iLoad_config_save(config);
  return
end

% multiple file handling
if iscellstr(filename) & length(filename) > 1 & ~isempty(filename)
  data  = {};
  format= data;
  for index=1:length(filename(:))
    [this_data, this_format] = iLoad(filename{index}, loader);
    if ~iscell(this_data),   this_data  ={ this_data }; end
    if ~iscell(this_format), this_format={ this_format }; end
    data  = { data{:}   this_data{:} };
    format= { format{:} this_format{:} };
    clear this_data this_format
  end
  return
end

if iscellstr(filename) & length(filename) == 1
  filename = filename{1};
end

url = false; % flag indicating that 'filename' is a temp file to be removed afterwards

% handle single file name
if ischar(filename) & length(filename) > 0
  % handle ~ substitution for $HOME
  if filename(1) == '~' && (length(filename==1) || filename(2) == '/' || filename(2) == '\')
    filename(1) = '';
    if usejava('jvm')
      filename = [ char(java.lang.System.getProperty('user.home')) filename ];
    elseif ~ispc  % does not work under Windows
      filename = [ getenv('HOME') filename ];
    end
  end

  % local/distant file (general case)
  f=find(filename == '#');
  if length(f) == 1 && f > 1  % the filename contains an internal link (HTML anchor)
    [fileroot,filesub]=strtok(filename, '#');
    [data, format]=iLoad(fileroot);
    % now search for the fieldnames
    f = findfield(data, filesub(2:end)); % calls private function
    if ~isempty(f)
      % 'data' will be a cell array of structure based on the initial one
      this_data = {}; this_format = {};
      for index=1:length(f)
        ret = data;
        fields = textscan(f{index},'%s','Delimiter','.'); % split the path in the structure with '.' char
        ret.Data = getfield(data,fields{1}{:});             % access that path by expanding it;
        try
          fields{1}{1} = 'Headers';
          ret.Headers = getfield(data,fields{1}{:});
        end
        this_data{end+1}   = ret;
        this_format{end+1} = loader;

      end
      data   = this_data;
      format = this_format;
      return
    else
      fprintf(1, 'iLoad: Warning: Could not find pattern "%s". Importing whole file...\n', filesub(2:end));
      filename = fileroot;
    end
  end
  
  if strncmp(filename, 'file://', length('file://'))
    filename = filename(8:end); % remove 'file://' from local name
  end
  
  % handle / to \ substitution for Windows systems, not in URLs
  if ~(strncmp(filename, 'http://', length('http://')) | ...
       strncmp(filename, 'https://',length('https://'))   | ...
       strncmp(filename, 'ftp://',  length('ftp://'))   | ...
       strncmp(filename, 'file://', length('file://')) )
    if    ~ispc, filename = strrep(filename, '\', filesep);
    elseif ispc, filename = strrep(filename, '/', filesep);
    end
  end
  
  if isdir(filename), filename = [ filename filesep '*']; end % all elements in case of directory
  
  % handle single file name (possibibly with wildcard)
  if ~isempty(find(filename == '*')) | ~isempty(find(filename == '?'))  % wildchar !!#
    [filepath,name,ext]=fileparts(filename);  % 'file' to search
    if isempty(filepath), filepath = pwd; end
    this_dir = dir(filename);
    if isempty(this_dir), return; end % directory is empty
    % removes '.' and '..'
    index = find(~strcmp('.', {this_dir.name}) & ~strcmp('..', {this_dir.name}));
    this_dir = char(this_dir.name);
    this_dir = (this_dir(index,:));
    if isempty(this_dir), return; end % directory only contains '.' and '..'
    rdir = cellstr(this_dir); % original directory listing as cell
    rdir = strcat([ filepath filesep ], char(rdir));
    filename = cellstr(rdir);
    [data, format] = iLoad(filename, loader);
    return
  end
  
  % handle file on the internet
  if strncmp(filename, 'http://', length('http://')) ...
   | strncmp(filename, 'https://',length('https://')) ...
   | strncmp(filename, 'ftp://',  length('ftp://'))
    if (~usejava('mwt'))
        fprintf(1, 'iLoad: Reading from a URL requires a Java Virtual Machine.\n\tSkipping...\n');
        return
    end
    % access the net. Proxy settings must be set (if any).
    try
      % write to temporary file
      filename = urlwrite(filename, tempname);
      url = true;
    catch
      fprintf(1, 'iLoad: Can''t read URL "%s".\n', filename);
      return
    end
  end
  
  % handle compressed files (local or distant)
  [pathstr, name, ext] = fileparts(filename);
  if     strcmp(ext, '.zip'), cmd = 'unzip';
  elseif strcmp(ext, '.tar'), cmd = 'untar';
  elseif strcmp(ext, '.gz') || strcmp(ext, '.tgz'),  cmd = 'gunzip';
  elseif strcmp(ext, '.Z'),   cmd = 'uncompress';
  else                        cmd=''; end
  if ~isempty(cmd)
    % this is a compressed file/url. Extract to temporary dir.
    if strcmp(cmd, 'uncompress')
      copyfile(filename, tempdir, 'f');
      try
        system(['uncompress ' tempdir filesep name ext ]);
        filename = [ tempdir filesep name ];
        url = true;
      catch
        fprintf(1, 'iLoad: Can''t extract file "%s" (%s).\n', filename,cmd);
        return
      end
    elseif exist(cmd)
      % extract to temporary dir
      try
        filenames = feval(cmd, filename, tempdir);
      catch
        fprintf(1, 'iLoad: Can''t extract file "%s" (%s).\n', filename,cmd);
        return
      end
      [data, format] = iLoad(filenames, loader); % is now local
      for index=1:length(filenames)
        try
          delete(filenames{index});
        catch
          fprintf(1,'iLoad: Can''t delete temporary file "%s" (%s).\n', filename{index},cmd);
        end
      end
      return
    end
  end
  
  % The import takes place HERE ================================================
  if isdir(filename), filename = [ filename filesep '*']; end % all elements in case of directory
  % handle the '%20' character replacement as space
  filename = strrep(filename, '%20',' ');
  try
    [data, format] = iLoad_import(filename, loader, varargin{:});
  catch
    fprintf(1, 'iLoad: Failed to import file %s. Ignoring.\n', filename);
    data=[];
  end
  
elseif isempty(filename)
  config = iLoad('','load config');
  if exist('uigetfiles') & strcmp(config.UseSystemDialogs, 'no')
      [filename, pathname] = uigetfiles('.*','Select file(s) to load');
  else
    if usejava('swing')
      setappdata(0,'UseNativeSystemDialogs',false);
      [filename, pathname] = uigetfile('*.*', 'Select file(s) to load', 'MultiSelect', 'on');
    else
      [filename, pathname] = uigetfile('*.*', 'Select a file to load');
    end
  end
  if isempty(filename),    return; end
  if isequal(filename, 0), return; end
  filename = strcat(pathname, filesep, filename);
  if ~iscellstr(filename)
    if isdir(filename)
      filename = [ filename filesep '*']; 
    end % all elements in case of directory
  end
  [data, format] = iLoad(filename, loader);
else
  % data not empty, but not a file name
  data = iLoad_loader_check([ inputname(1) ' variable of class ' class(filename) ], filename, 'variable');
  format= '' ;
end

% remove temporary file if needed
if (url)
  try
  delete(filename);
  catch
  fprintf(1,'iLoad: Can''t delete temporary file "%s".\n', filename);
  end
end

% -----------------------------------------------------------
% private function to import single data with given method(s)
function [data, loader] = iLoad_import(filename, loader, varargin)
  data = [];
  if isempty(loader), loader='auto'; end
  if strcmp(loader, 'auto')
    loader = iLoad_loader_auto(filename);
  elseif strcmp(loader, 'gui')
    [dummy, filename_short, ext] = fileparts(filename);
    filename_short = [ filename_short ext];
    loader = iLoad_loader_auto(filename);
    loader_names=[loader{:}];
    tmp         = cell(size(loader_names)); tmp(:)={' - '};
    loader_names= strcat({loader_names.name}, tmp,{loader_names.method});
    loader_index=listdlg(...
      'PromptString',...
        {'Select suitable import methods',['to import file ' filename_short ]}, ...
      'SelectionMode','Multiple',...
      'ListString', loader_names, ...
      'ListSize', [300 160], ...
      'Name', ['Loader for ' filename_short ]);
    if isempty(loader_index), loader=[]; return; end
    loader=loader(loader_index);
  elseif ischar(loader)
    % test if loader is the user name of a function
    config = iLoad('','load config');
    formats = config.loaders;
    loaders={};
    loaders_count=0;
    for index=1:length(formats)
      this_loader = formats{index};
      if ~isempty(strfind(this_loader.name, loader)) || ~isempty(strfind(this_loader.method, loader)) || ~isempty(strfind(this_loader.extension, loader))
        loaders_count = loaders_count+1;
        loaders{loaders_count} = this_loader;
      end
    end
    if ~isempty(loaders) loader = loaders; end
  end
  
  % handle multiple loaders (cell or struct array)
  if (iscell(loader) | isstruct(loader)) & length(loader) > 1
    loader=loader(:);
    for index=1:length(loader)
      if iscell(loader), this_loader = loader{index};
      else this_loader = loader(index); end
      try
        data = iLoad_import(filename, this_loader, varargin{:});
      catch
        l=lasterror;
        disp(l.message);
        [dummy, name_short, ext] = fileparts(filename);
        fprintf(1, 'iLoad: Failed to import file %s with method %s (%s). Ignoring.\n', name_short, this_loader.name, this_loader.method);
        data = [];
        if strcmp(l.identifier, 'MATLAB:nomem') || ~isempty(strmatch(lower(l.message), 'out of memory'))
          fprintf(1,'iLoad: Not enough memory. Skipping import of this file.\n');
          break;
        end
      end
      if ~isempty(data)
        loader = this_loader;
        return;
      end
    end % for
    loader = 'Failed to load file (all known methods failed)';
    return; % all methods tried, none effective
  end % if iscell
  if iscell(loader) & length(loader) == 1
    loader = loader{1};
  end

  % handle single char loaders (IMPORT takes place HERE)
  if ischar(loader)
    tmp=loader; clear loader;
    loader.method = tmp; loader.options='';
  end
  if ~isfield(loader,'method'), return; end
  if ~isfield(loader,'name'), loader.name = loader.method; end
  if isempty(loader.method), return; end
  fprintf(1, 'iLoad: Importing file %s with method %s (%s)\n', filename, loader.name, loader.method);
  if isempty(loader.options)
    data = feval(loader.method, filename, varargin{:});
  elseif iscell(loader.options)
    data = feval(loader.method, filename, loader.options{:}, varargin{:})
  elseif ischar(loader.options)
    try
    data = feval(loader.method, filename, loader.options, varargin{:});
    catch
    data = feval(loader.method, [ filename ' '  loader.options ], varargin{:});
    end
  end
  data = iLoad_loader_check(filename, data, loader);
  if isempty(data), return; end
  if isfield(loader, 'name') data.Format = loader.name; 
  else data.Format=[ loader.method ' import' ]; end
  return
  
% -----------------------------------------------------------
% private function to make the data pretty looking
function data = iLoad_loader_check(file, data, loader)

  if isempty(data), return; end
  % handle case when a single file generates a data set
  if isstruct(data) & length(data)>1
    for index=1:length(data)
      data(index) = iLoad_loader_check(file, data(index), loader);
    end
    return
  elseif iscellstr(data)
    fprintf(1, 'iLoad: Failed to import file %s with method %s (%s). Got a cell of strings. Ignoring\n', file, loader.name, loader.method);
  elseif iscell(data) & length(data)>1
    newdata=[];
    for index=1:length(data)
      newdata(index) = iLoad_loader_check(file, data{index}, loader);
    end
    data = newdata; % now an array of struct
    return
  end
  
  name='';
  if isstruct(loader),
    method = loader.method;
    options= loader.options;
    if isfield(loader, 'name'), name=loader.name; end
  else
    method = loader; options=''; 
  end

  if isempty(method), method='iData/load'; end
  if strcmp(loader, 'variable')
    method='iData/load';
  end
  if isempty(name), name=method; end
  if iscell(options), options= cellstr(options{1}); options= [ options{1} ' ...' ]; end
  if ~isfield(data, 'Source')  & ~isfield(data, 'Date') & ~isfield(data, 'Format') ...
   & ~isfield(data, 'Command') & ~isfield(data,' Data')
    new_data.Data = data;
    % transfer some standard fields as possible
    if isfield(data, 'Source'), new_data.Source = data.Source; end
    if isfield(data, 'Title'),  new_data.Title = data.Title; end
    if isfield(data, 'Date'),   new_data.Date = data.Date; end
    if isfield(data, 'Label'),  new_data.Label = data.Label; end
    
    data = new_data;
    
  end

  if ~isfield(data, 'Source') && ~isfield(data, 'Filename'),  data.Source = file;
  elseif ~isfield(data, 'Source') && isfield(data, 'Filename'), data.Source = data.Filename; end

  if ~isfield(data, 'Title'),   
    [pathname, filename, ext] = fileparts(file);
    if ~strcmp(loader, 'variable'), data.Title  = [ filename ext ' ' name  ];
    else data.Title  = [ filename ext ]; end
  end
  
  if ~isfield(data, 'Date')
    if strcmp(loader, 'variable') data.Date   = datevec(now); 
    else d=dir(file); data.Date=d.date; end
  end

  if ~isfield(data, 'Format'),
    if ~strcmp(loader, 'variable'), data.Format  = [ name ' import with Matlab ' method ];  
    else data.Format  = [ 'Matlab ' method ]; end
  end
  if ~isfield(data, 'Command'),
    if strcmp(loader, 'variable')
      data.Command = [ method '(' file ', '''  options ''')' ];
    else
      data.Command = [ method '(''' file ''', '''  options ''')' ];
    end
  end
  if ~isfield(data, 'Creator'), data.Creator = [ name ' iData/load/' method ]; 
  else data.Creator = [ name ' iData/load/' method ' - ' data.Creator ]; end
  if ~isfield(data, 'User'),
    if isunix
      data.User    = [ getenv('USER') ' running on ' computer ' from ' pwd ];
    else
      data.User    = [ 'User running on ' computer ' from ' pwd ];
    end
  end
  return

% -----------------------------------------------------------
% private function to determine which parser to use to analyze content
% if allformats == 1, no pattern search is done
function loaders = iLoad_loader_auto(file)
  config  = iLoad('','load config');
  loaders = config.loaders;
    
  % read start of file
  [fid,message] = fopen(file, 'r');
  if fid == -1
    fprintf(1, 'iLoad: %s: %s. Check existence/permissions.\n', file, message );
    error([ 'Could not open file ' file ' for reading. ' message '. Check existence/permissions.' ]);
  end
  file_start = fread(fid, 10000, 'uint8=>char')';
  fclose(fid);
  % loop to test each format for patterns
  formats = loaders;
  loaders={};
  loaders_count=0;
  % identify by extensions
  [dummy, dummy, fext] = fileparts(file);
  fext=strrep(fext,'.','');
  
  % identify by patterns
  for index=1:length(formats)
    loader = formats{index};
    if ~isstruct(loader), break; end

    if exist(loader.method)
      for this=sprintf('\r\n\t\b\f\a\v')
        file_start = strrep(file_start, this, ' ');
      end
      
      if strcmp(loader.method, 'looktxt') && ...
              length(find(file_start >= 32 & file_start < 127))/length(file_start) < 0.9
        % fprintf(1,'iLoad: skip method %s as file %s is probably binary\n', loader.method, file);
        patterns_found  = 0;
        continue;  % does not use looktxt for binary data files
      end
      patterns_found  = 1;
      if ~isfield(loader,'patterns') loader.patterns=''; end
      if isempty(loader.patterns)  % no pattern to search, test extension
        if ~isfield(loader,'extension'), ext=''; 
        else ext=loader.extension; end
        if ischar(ext) && length(ext), ext=cellstr(ext); end
        if length(ext) && length(fext) 
          if isempty(strmatch(lower(fext), lower(ext), 'exact'))
            patterns_found  = 0;  % extension does not match
            % fprintf(1,'iLoad: method %s file %s: extension does not match (%s) \n', loader.name, file, fext);
          end
        else
          patterns_found  = 1;    % no extension, no patterns: try loader anyway
        end
      else  % check patterns
        if ischar(loader.patterns), loader.patterns=cellstr(loader.patterns); end
        for index_pat=1:length(loader.patterns(:))
          if isempty(strfind(file_start, loader.patterns{index_pat}))
            patterns_found=0;     % at least one pattern does not match
            % fprintf(1,'iLoad: method %s file %s: at least one pattern does not match (%s)\n', loader.name, file, loader.patterns{index_pat});
            continue;
          end
        end % for patterns
      end % if patterns
      
      if patterns_found
        loaders_count = loaders_count+1;
        loaders{loaders_count} = loader;
      end
    else
      fprintf(1,'iLoad: method %s file %s: method not found ? Check the iLoad_ini configuration file.\n', loader.name, file);
    end % if exist(method)
  end % for index
  
  return;

% -----------------------------------------------------------
% private function to save the configuration and format customization
function config = iLoad_config_save(config)
  data = config.loaders;
  format_names  ={};
  format_methods={};
  format_unique =ones(1,length(data));
  % remove duplicated format definitions
  for index=1:length(data)
    if ~isempty(data{index}.name) & ~isempty(strmatch(data{index}.name, format_names, 'exact')) & ~isempty(strmatch(data{index}.method, format_methods, 'exact'))
      format_unique(index) = 0; % already exists. Skip it.
      format_names{index}  = '';
      format_methods{index}= '';
    else
      format_names{index} = data{index}.name;
      format_methods{index} = data{index}.method;
    end
  end
  data = data(find(format_unique));
  config.loaders = data;
  % save iLoad.ini configuration file
  % make header for iLoad.ini
  config.FileName=fullfile(prefdir, 'iLoad.ini'); % store preferences in PrefDir (Matlab)
  str = [ '% iLoad configuration script file ' sprintf('\n') ...
          '%' sprintf('\n') ...
          '% Matlab ' version ' m-file ' config.FileName sprintf('\n') ...
          '% generated automatically on ' datestr(now) ' with iLoad('''',''save config'');' sprintf('\n') ...
          '%' sprintf('\n') ...
          '% The configuration may be specified as:' sprintf('\n') ...
          '%     config = { format1 .. formatN }; (a single cell of format definitions, see below).' sprintf('\n') ...
          '%   OR a structure' sprintf('\n') ...
          '%     config.loaders = { format1 .. formatN }; (see below)' sprintf('\n') ...
          '%     config.UseSystemDialogs=''yes'' to use built-in Matlab file selector (uigetfile)' sprintf('\n') ...
          '%                             ''no''  to use iLoad file selector           (uigetfiles)' sprintf('\n') ...
          '%' sprintf('\n') ...
          '% User definitions of specific import formats to be used by iLoad' sprintf('\n') ...
          '% Each format is specified as a structure with the following fields' sprintf('\n') ...
          '%   method:   function name to use, called as method(filename, options...)' sprintf('\n') ...
          '%   extension:a single or a cellstr of extensions associated with the method' sprintf('\n') ...
          '%   patterns: list of strings to search in data file. If all found, then method' sprintf('\n') ...
          '%             is qualified' sprintf('\n') ...
          '%   name:     name of the method/format' sprintf('\n') ...
          '%   options:  additional options to pass to the method.' sprintf('\n') ...
          '%             If given as a string they are catenated with file name' sprintf('\n') ...
          '%             If given as a cell, they are given to the method as additional arguments' sprintf('\n') ...
          '%   postprocess: function called from iData/load after file import, to assign aliases, ...' sprintf('\n') ...
          '%             called as iData=postprocess(iData)' sprintf('\n') ...
          '%' sprintf('\n') ...
          '% all formats must be arranged in a cell, sorted from the most specific to the most general.' sprintf('\n') ...
          '% Formats will be tried one after the other, in the given order.' sprintf('\n') ...
          '% System wide loaders are tested after user definitions.' sprintf('\n') ...
          '%' sprintf('\n') ...
          '% NOTE: The resulting configuration must be named "config"' sprintf('\n') ...
          '%' sprintf('\n') ...
          class2str('config', config) ];
  [fid, message]=fopen(config.FileName,'w+');
  if fid == -1
    warning(['Error opening file ' config.FileName ' to save iLoad configuration.' ]);
    config.FileName = [];
  else
    fprintf(fid, '%s', str);
    fclose(fid);
    disp([ '% Saved iLoad configuration into ' config.FileName ]);
  end
  
% -----------------------------------------------------------
% private function to load the configuration and format customization
function config = iLoad_config_load
  loaders      = {};
  % read user list of loaders which is a cell of format descriptions
  if exist(fullfile(prefdir, 'iLoad.ini'), 'file')
    % there is an iLoad_ini in the Matlab preferences directory: read it
    configfile = fullfile(prefdir, 'iLoad.ini');
    fid = fopen(configfile, 'r');
    content = fread(fid, Inf, 'uint8=>char');
    fclose(fid);
    % evaluate content of file
    config=[]; eval(content(:)'); % this makes a 'config' variable
    if iscell(config)
      loaders = config; config=[];
      config.loaders = loaders;
      config.FileName= configfile;
    end
    disp([ '% Loaded iLoad format descriptions from ' config.FileName ]);
  elseif exist('iLoad_ini')
    config = iLoad_ini;
  end
  
  % check if other configuration fields are present, else defaults
  if ~isfield(config, 'UseSystemDialogs'), config.UseSystemDialogs = 'no'; end
  if ~isfield(config, 'FileName'),         config.FileName = ''; end
  
  loaders = config.loaders;
  
  % ADD default loaders: method, ext, name, options
  % default importers, when no user specification is given. 
  % These do not have any pattern recognition or postprocess
  % format = { method, extension, name, options, patterns, postprocess }
  formats = {...
    { 'csvread', 'csv', 'Comma Separated Values (.csv)',''}, ...
    { 'dlmread', 'dlm', 'Numerical single block',''}, ...
    { 'xmlread', 'xml', 'XML',''}, ...
    { 'looktxt', '',    'Data (text format with fastest import method)',    ...
        '--headers --binary --fast --comment=NULL --silent --metadata=xlabel --metadata=ylabel --metadata=x_label --metadata=y_label', ...
          '',{'load_xyen','load_vitess_2d'}}, ...
    { 'looktxt', '',    'Data (text format with fast import method)',       ...
        '--headers --binary --comment=NULL --silent','','load_xyen'}, ...
    { 'looktxt', '',    'Data (text format)',                               ...
        '--headers --comment=NULL --silent','','load_xyen'}, ...
    { 'wk1read', 'wk1', 'Lotus1-2-3 (first spreadsheet)',''}, ...
    { 'auread',  'au',  'NeXT/SUN (.au) sound',''}, ...
    { 'wavread', 'wav'  'Microsoft WAVE (.wav) sound',''}, ...
    { 'aviread', 'avi', 'Audio/Video Interleaved (AVI) ',''}, ...
    { 'mcdfread', {'nc','cdf'}, 'NetCDF 2 (.nc)',''}, ...
    { 'netcdf',   {'nc','cdf'}, 'NetCDF 1.0 (.nc)','','','load_netcdf1'}, ...
    { 'mfitsread',{'fits','fts'},'FITS',''}, ...
    { 'xlsread', 'xls', 'Microsoft Excel (first spreadsheet, .xls)',''}, ...
    { 'mimread',  {'bmp','jpg','jpeg','tiff','tif','png','ico'}, 'Image/Picture',''}, ...
    { 'hdf5extract',{'hdf','hdf5','h5'}, 'HDF5','','','load_psi_RITA'}, ...
    { 'hdf5extract',{'nx','nxs','n5','nxspe'}, 'NeXus/HDF5',''}, ...
    { 'mhdf4read',{'hdf4','h4','hdf'},  'HDF4',''}, ...
    { 'mhdf4read',{'nx','nxs','n4'},  'NeXus/HDF4',''}, ...
    { 'load',    'mat', 'Matlab workspace (.mat)',''}, ...
    { 'importdata','',  'Matlab importer',''}, ...
  };
  for index=1:length(formats) % the default loaders are addded after the INI file
    format = formats{index};
    if isempty(format), break; end
    if length(format) < 4, continue; end
    if length(format) < 5, format{5}=''; end
    if length(format) < 6, format{6}=''; end
    % check if format already exists in list
    skip_format=0;
    for j=1:length(loaders)
      this=loaders{j};
      if strcmp(format{3}, this.name)
        skip_format=1;
        break;
      end
    end
    if ~skip_format
      loader.method     = format{1};
      loader.extension  = format{2};
      loader.name       = format{3};
      loader.options    = format{4};
      loader.patterns   = format{5};
      loader.postprocess= format{6};
      loaders = { loaders{:} , loader };
    end
  end
  
  for index=1:length(loaders)
    loader = loaders{index};
    if ~isfield(loader,'method'),     loader.method = ''; end
    if ~isfield(loader,'extension'),  loader.extension=''; end
    if ~isfield(loader,'name'),       loader.name=''; end
    if ~isfield(loader,'options'),    loader.options=''; end
    if ~isfield(loader,'patterns'),   loader.patterns=''; end
    if ~isfield(loader,'postprocess'),loader.postprocess=''; end
    loaders{index} = loader;
  end
  config.loaders = loaders; % updated list of loaders

% ------------------------------------------------------------------------------
% private function findfield, returns all field name and values, that match 'name'
function match = findfield(s, field)
% match=findfield(s, field, option) : look for numerical fields in a structure
%
% input:  s: structure
%         field: field name to search, or '' (char).
%         option: 'exact' 'case' or '' (char)
% output: match: names of structure fields (cellstr)
% ex:     findfield(s) or findfield(s,'Title')

if length(s(:)) > 1
  match = cell(1, length(s(:))); dims=match;
  for index=1:length(s)
    match{index}=findfield(s(index), field);
  end
  return
end

match = struct_getfields(struct(s), ''); % return the numerical fields

if ~isempty(field)
  field = lower(field);
  matchs= lower(match);

  if iscellstr(field)
    index = [];
    for findex=1:length(field)
      tmp = strfind(matchs, field{findex});
      if iscell(tmp), tmp = find(cellfun('isempty', tmp) == 0); end
      index= [ index ; tmp ];
    end
    index = unique(index);
  else
    index = strfind(matchs, field);
  end

  if ~isempty(index) && iscell(index), index = find(cellfun('isempty', index) == 0); end
  if isempty(index)
    match=[];
  else
    match = match(index);
  end
end

% ============================================================================
% private function iData_getfields, returns field, class, numel 
function f = struct_getfields(structure, parent)

f=[];
if ~isstruct(structure), return; end
if numel(structure) > 1
  structure=structure(:);
  for index=1:length(structure)
    sf = struct_getfields(structure(index), [ parent '(' num2str(index) ')' ]);
    f = [f(:) ; sf(:)];
  end
  return
end

% get content and type of structure fields
c = struct2cell(structure);
f = fieldnames(structure);
try
  t = cellfun(@class, c, 'UniformOutput', 0);
catch
  t=cell(1,length(c));
  index = cellfun('isclass', c, 'double'); t(find(index)) = {'double'};
  index = cellfun('isclass', c, 'single'); t(find(index)) = {'single'};
  index = cellfun('isclass', c, 'logical');t(find(index)) = {'logical'};
  index = cellfun('isclass', c, 'struct'); t(find(index)) = {'struct'};
  index = cellfun('isclass', c, 'uint8');  t(find(index)) = {'uint8'};
  index = cellfun('isclass', c, 'uint16'); t(find(index)) = {'uint16'};
  index = cellfun('isclass', c, 'uint32'); t(find(index)) = {'uint32'};
  index = cellfun('isclass', c, 'uint64'); t(find(index)) = {'uint64'};
  index = cellfun('isclass', c, 'int8');   t(find(index)) = {'int8'};
  index = cellfun('isclass', c, 'int16');  t(find(index)) = {'int16'};
  index = cellfun('isclass', c, 'int32');  t(find(index)) = {'int32'};
  index = cellfun('isclass', c, 'int64');  t(find(index)) = {'int64'};
end

toremove=[];
% only retain numerics
for index=1:length(c)
  if ~any(strncmp(t{index},{'dou','sin','int','uin','str'}, 3))
    toremove(end+1)=index;
  end
end
c(toremove)=[];
f(toremove)=[];

if ~isempty(parent), f = strcat([ parent '.' ], f); end

% find sub-structures and make a recursive call for each of them
for index=transpose(find(cellfun('isclass', c, 'struct')))
  try
  sf = struct_getfields(c{index}, f{index});
  f = [f(:) ; sf(:)];
  end
end



