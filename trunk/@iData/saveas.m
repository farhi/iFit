function [filename,format] = saveas(a, varargin)
% f = saveas(s, filename, format) : save iData object into various data formats
%
%   @iData/saveas function to save data sets
%   This function save the content of iData objects. 
%
% input:  s: object or array (iData)
%         filename: name of file to save to. Extension, if missing, is appended (char)
%                   If the filename already exists, the file is overwritten.
%                   If given as filename='gui', a file selector pops-up
%         format: data format to use (char), or determined from file name extension
%           'm'    save as a flat Matlab .m file (a function which returns an iData object or structure)
%           'mat'  save as a '.mat' binary file (same as 'save')
%           'hdf5' save as an HDF5 data set
%           'nc'   save as NetCDF 
%         as well as other lossy formats
%           'hdf4' save as an HDF4 immage
%           'edf'  EDF ESRF format for 1D and 2D data sets
%           'gif','bmp' save as an image (no axes, only for 2D data sets)
%           'png','tiff','jpeg','ps','pdf','ill','eps' save as an image (with axes)
%           'xls'  save as an Excel sheet (requires Excel to be installed)
%           'csv'  save as a comma separated value file
%           'svg'  save as Scalable Vector Graphics (SVG) format
%           'wrl'  save as Virtual Reality VRML 2.0 file
%           If given as format='gui' and filename extension is not specified, a format list pops-up
%         options: specific format options, which are usually plot options
%           default is 'view2 axis tight'
%
% output: f: filename(s) used to save data (char)
% ex:     b=saveas(a, 'file', 'm');
%         b=saveas(a, 'file', 'svg', 'axis tight');
%
% Contributed code (Matlab Central): 
%   plot2svg:   Juerg Schwizer, 22-Jan-2006 
%   iData_private_saveas_hdfnc
%   pmedf_write:
%
% Version: $Revision: 1.14 $
% See also iData, iData/load, iData/getframe, save

% handle array of objects to save iteratively
if length(a) > 1
  if length(varargin) >= 1, filename_base = varargin{1}; 
  else filename_base = ''; end
  if strcmp(filename_base, 'gui'), filename_base=''; end
  filename = cell(size(a));
  for index=1:length(a(:))
    [filename{index}, format] = saveas(a(index), varargin{:});
    if isempty(filename_base), filename_base = filename{index}; end
    if length(a(:)) > 1
      [path, name, ext] = fileparts(filename_base);
      varargin{1} = [ path name '_' num2str(index) ext ];
    end
  end
  return
end

% default options checks
if nargin < 2, filename = ''; else filename = varargin{1}; end
if isempty(filename), filename = a.Tag; end
if nargin < 3, format=''; else format = varargin{2}; end
if nargin < 4, options=''; else options=varargin{3}; end
if isempty(options) && ndims(a) >= 2, options='view2 axis tight'; end

% supported format list
filterspec = {'*.m',   'Matlab script/function (*.m)'; ...
      '*.dat', 'Flat text file with comments (*.dat)'; ...
      '*.mat', 'Matlab binary file (*.mat)'; ...
      '*.pdf', 'Portable Document Format (*.pdf)'; ...
      '*.eps', 'Encapsulated PostScrip (color, *.eps)'; ...
      '*.ps',  'PostScrip (color, *.ps)'; ...
      '*.nc',  'NetCDF (*.nc, *.cdf)'; ...
      '*.hdf5','Hierarchical Data Format (*.hdf5, *.h5, *.nx)'; ...
      '*.xls', 'Excel format (requires Excel to be installed, *.xls)'; ...
      '*.csv', 'Comma Separated Values (suitable for Excel, *.csv)'; ...
      '*.png', 'Portable Network Graphics image (*.png)'; ...
      '*.jpg', 'JPEG image (*.jpg)'; ...
      '*.tiff;*.tif', 'TIFF image (*.tif)'; ...
      '*.svg', 'Scalable Vector Graphics (*.svg)'; ...
      '*.wrl', 'Virtual Reality file (*.wrl, *.vrml)'};

% filenape='gui' pops-up a file selector
if strcmp(filename, 'gui')  
  [filename, pathname, filterindex] = uiputfile( ...
       filterspec, ...
        ['Save ' a.Title ' as...'], a.Tag);
  if ~isempty(filename) & filename ~= 0
    ext = filterspec{filterindex,1};
    if iscellstr(ext), ext=ext{1}; end
    % check if extension was given
    [f,p,e] = fileparts(filename);
    if isempty(e), 
      filename=[ filename ext(2:end) ];
      format=ext(3:end);
    elseif isempty(format)
      format=e(2:end);
    end
  else
    filename=[]; return
  end
end

% format='gui' pops-up a list of available file formats, if not given from file extension
if strcmp(format, 'gui')
  liststring= filterspec(:,2);
  format_index=listdlg('ListString',liststring,'Name',[ 'Select format to save ' filename ], ...
    'PromptString', {'Select format ',['to save file ' filename ]}, ...
    'ListSize', [300 200]);
  if isempty(format_index), return; end
  format = filterspec{format_index,1};
  format = format(3:end);
end

% handle aliases
switch format
case {'netcdf','nc'}
  format='cdf';
case 'vrml'
  format='wrl';
end

% handle extensions
[path, name, ext] = fileparts(filename);
if isempty(ext) & ~isempty(format), 
  ext = [ '.' format ]; 
  filename = [ filename ext ];
elseif isempty(format) & ~isempty(ext)
  format = ext(2:end);
elseif isempty(format) & isempty(ext) 
  format='m'; filename = [ filename '.m' ];
end

% handle some format aliases (after extension extraction from file name)
switch format
case 'jpg'
  format='jpeg';
case 'eps'
  format='epsc';
case 'ps'
  format='psc';
case 'netcdf'
  format='cdf';
end

% ==============================================================================
% handle specific format actions
switch lower(format)
case 'm'  % single m-file Matlab output (text), with the full object description
  NL = sprintf('\n');
  str = [ 'function this=' name NL ...
          '% Original data: ' NL ...
          '%   class:    ' class(a) NL ...
          '%   variable: ' inputname(1) NL ...
          '%   tag:      ' a.Tag NL ...
          '%   label:    ' a.Label NL ...
          '%   source:   ' a.Source NL ... 
          '%' NL ...
          '% Matlab ' version ' m-file ' filename ' saved on ' datestr(now) ' with iData/saveas' NL ...
          '% To use/import data, type ''' name ''' at the matlab prompt.' NL ...
          '% You will obtain an iData object (if you have iData installed) or a structure.' NL ...
          '%' NL ...
          class2str('this', a) ];
  [fid, message]=fopen(filename,'w+');
  if fid == -1
    iData_private_warning(mfilename,[ 'Error opening file ' filename ' to save object ' a.Tag ]);
    return
  end
  fprintf(fid, '%s', str);
  fclose(fid);
case 'dat'  % flat text file with commented blocks, in the style of McStas/PGPLOT
  NL = sprintf('\n');
  str = [ '# Format: data with text headers' NL ...
          '# URL: ifit.mccode.org' NL ...
          '# Creator: iFit/@iData/saveas - ' version(a) NL ...
          '# Title: ' a.Title NL ...
          '# Label: ' a.Label NL ...
          '# DisplayName: ' a.DisplayName NL ...
          '# User: ' a.User NL ...
          '# CreationDate: ' a.Date NL ...
          '# ModificationDate: ' a.ModificationDate NL ...
          '# Tag: ' a.Tag NL ...
          '# ' NL ...
          class2str('', a, 'flat') ];
  [fid, message]=fopen(filename,'w+');
  if fid == -1
    iData_private_warning(mfilename,[ 'Error opening file ' filename ' to save object ' a.Tag ]);
    return
  end
  fprintf(fid, '%s', str);
  fclose(fid);
case 'mat'  % single mat-file Matlab output (binary), with the full object description
  save(filename, 'a');
case {'hdf5', 'nc',' cdf', 'nx','h5'} % HDF4, HDF5, NetCDF formats: converts fields to double and chars
  filename = saveas_hdfnc(a, filename); % inline function (below)
case 'edf'  % EDF ESRF format
  filename = medfwrite(a, filename);
case 'xls'  % Excel file format
  xlswrite(filename, double(a), a.Title);
case 'csv'  % Spreadsheet comma separated values file format
  csvwrite(filename, double(a));
case {'gif','bmp','pbm','pcx','pgm','pnm','ppm','ras','xwd','hdf4'}  % bitmap images
  if ndims(a) == 2 
    b=double(a);
    if abs(log10(size(b,1)) - log10(size(b,2))) > 1
      x = round(linspace(1, size(b,1), max(size(b,1), 1024)));
      y = round(linspace(1, size(b,2), max(size(b,2), 1024)));
      b = b(x,y);
    end
    b=(b-min(b(:)))/(max(b(:))-min(b(:)))*64;
  else
    f=getframe(a);
    b = f.cdata;
  end
  switch format
  case 'gif'
    imwrite(b, jet(64), filename, format, 'Comment',char(a));
  otherwise
    imwrite(b, jet(64), filename, format);
  end
case 'epsc' % color encapsulated postscript file format, with TIFF preview
  f=figure('visible','off');
  plot(a,options);
  print(f, '-depsc', '-tiff', filename);
  close(f);
case {'png','tiff','jpeg','psc','pdf','ill'}  % other bitmap and vector graphics formats (PDF, ...)
  f=figure('visible','off');
  plot(a,options);
  print(f, [ '-d' format ], filename);
  close(f);
case 'fig'  % Matlab figure format
  f=figure('visible','off');
  plot(a,options);
  saveas(f, filename, 'fig');
  close(f);
case 'svg'  % scalable vector graphics format (private function)
  f=figure('visible','off');
  plot(a,options);
  plot2svg(filename, f);
  close(f);
case {'vrml','wrl'} % VRML format
  f=figure('visible','off');
  h = plot(a,options);
  vrml(gca,filename);
  close(f);
otherwise
  iData_private_warning(mfilename,[ 'Export of object ' inputname(1) ' ' a.Tag ' into format ' format ' is not supported. Ignoring.' ]);
  filename = [];
end

% end of iData/saveas


