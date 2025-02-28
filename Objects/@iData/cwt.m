function s = cwt(a,dim,scales,wname,plotit)
% CWT  Continuous wavelet transform.
%   B = CWT(S) computes the continuous wavelet transform (CWT) of object S along
%   the first dimension. The continuous wavelet transform performs a multi-scale
%   component analysis. It expands the data set into spatial frequency.
%   The resulting object has dimension of the input plus S 'period' axis,
%   and contains the wavelet decomposition coeficients (e.g. complex).
%   The low period contribution indicates sharp features, whereas the high
%   period ones indicate slow variation/constant contributions.
%   For easier interpretation you can compute the power spectrum abs(B).^2  
%  
%   B = CWT(S, DIM) computes the CWT along dimension DIM.
%
%   B = CWT(S, DIM, SCALES) computes the CWT specifying the number of 'scales'
%   to use. Default is [] for automatic.
%
%   B = CWT(S,DIM,SCALES,WNAME) specifies the Wavelet Family Short Name among
%   'Morlet','Paul','Dog' (default='Morlet').
%
%   B = CWT(..., 'plot') plots the continuous wavelet transform power spectra
%        plot(log(abs(B).^2)). 
%   You can optionally use slice-o-matic for an interactive inspection with:         
%        slice(log(abs(b).^2)) 
%   for an initial 2D data sets (3D result).
%
% Reference: 
%   Grinsted, A., Moore, J.C., Jevrejeva, S. (2004) Application of the 
%     cross wavelet transform and wavelet coherence to geophysical time 
%     series, Nonlin. Processes Geophys., 11, 561–566, doi:10.5194/npg-11-561-2004
%   Wavelet software was provided by C. Torrence and G. Compo,
%     and is available at URL: http://paos.colorado.edu/research/wavelets/
%   http://noc.ac.uk/using-science/crosswavelet-wavelet-coherence
%   http://en.wikipedia.org/wiki/Continuous_wavelet_transform
%
% Example: a=iData(peaks); b=cwt(a); ndims(b) == ndims(a)+1
% Version: $Date$ $Version$ $Author$
% See also iData, iData/fft, iData/xcorr, iData/conv

% handle input arguments
if nargin < 2, dim    = 1;  end
if nargin < 3, scales = []; end
if nargin < 4, wname  = ''; end
if nargin < 5, plotit = 0;  end

if ischar(dim)
  if isempty(wname), wname = dim; 
  else               plotit= 1; end
  dim=1;
end
if ischar(scales)
  if isempty(wname), wname = scales; 
  else               plotit= 1; end
  scales=[];
end

if strcmpi(wname, 'plot')
  plotit = 1;
  wname = '';
end
if isempty(dim),   dim=1;            end
if isempty(wname), wname = 'Morlet'; end
if isempty(plotit),plotit=0;         end

% handle input iData arrays
if numel(a) > 1
  s = zeros(iData, numel(a),1);
  for index=1:numel(a)
    s(index) = feval(mfilename, a(index), dim, scales, wname, plotit);
  end
  s = reshape(s, size(a));
  return
end

% handle multi-dimensional object: make it a 1D long vector
if dim > ndims(a), dim = 1; end

signal = double(interp(a,'grid')); % Signal/Monitor from regular grid

% permute axes so that 'dim' is first
if dim > 1
  signal = permute(signal, [ dim 1 ]);
end
ax     = getaxis(a, dim);

% signal is made (1:end) (along rows first)
signal = signal(:);
ax     = ax(:);

% assemble 'time series' which must have a continuous, equally binned 'x' axis

% default options to pass to 'wavelet'
dt      = mean(abs(diff(ax)));
if (dt==0)
  error([ mfilename ...
     ': Axis rank ' num2str(dim) ' is constant. Can not analyze.' ])
end
n       = length(signal);
S0      = 2*dt;       % Minimum scale
Dj      = 1/12;       % Octaves per scale (default: '1/12')
MaxScale= (n*.17)*S0; % default automaxscale
J1      = round(log2(MaxScale/S0)/Dj);  % Total number of scales
AR1     = ar1nv(signal);  % the ar1 coefficient of the series 
if any(isnan(AR1))
  error([ mfilename ...
    ': Automatic AR1 estimation failed. Specify it manually (use arcov or arburg).' ])
end

% override defaults from parameters
if isscalar(scales) && scales > 1
  J1 = scales;
elseif isvector(scales)
  S0 = min(scales); 
  J1 = numel(scales);
end

% we now call the private method
[wave,period,scale,coi] = wavelet(signal, dt, 1, Dj, S0, J1, wname);

% compute coefficients to plot
sigma2 = var(signal); clear signal

% put back dimensionality/size
sz = size(a);
if dim > 1
  sz([ dim 1]) = sz([1 dim]);
end
sz    = [ length(scale) sz ];  % wavelet period is 1st rank
sz(sz == 1) = []; % remove singleton dimensions (e.g. for 1D initial data sets)
wave  = reshape(wave,  sz);

% now put period axis last
sz=[ 2:length(sz) 1 ]; % put period last
wave  = permute(wave,  sz);

% create the final object
s=copyobj(a); 
s=history(s, mfilename, a, dim,scales,wname,plotit);

s=set(s, 'Signal', wave, 'Error', 0);
s=setalias(s, [ 'Period_' num2str(dim) ], log10(period),[ 'Axis ' label(s,dim) ' rank ' label(s,dim) ' Wavelet Period (log)' ]);
s=setaxis(s,  length(sz), [ 'Period_' num2str(dim) ]);

s.Name = sprintf('Wavelet power spectrum along axis %s rank %d\n%s', ...
  label(s,dim), dim , s.Name);

% if plotit, do that, add title, labels, ...
if plotit
  plot(log(abs(s).^2/sigma2)); 
  hold on
  plot(a);
end

