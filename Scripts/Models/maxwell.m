function y=maxwell(varargin)
% y = Maxwell(p, x, [y]) : Maxwellian
%
%   iFunc/Maxwell Maxwellian fitting function
%     Sum of 3 Maxwellian distributions
%
% Reference: http://en.wikipedia.org/wiki/Maxwell%E2%80%93Boltzmann_distribution
%
% input:  p: Maxwellian model parameters (double)
%            p = [ 'T1','I1','T2','I2','T3','I3' ]
%          or 'guess'
%         x: axis (double)
%         y: when values are given and p='guess', a guess of the parameters is performed (double)
% output: y: model value
% ex:     y=Maxwell([1 0 1 1], -10:10); or plot(Maxwell);
%
% Version: $Date$
% See also iFunc, iFunc/fits, iFunc/plot
% $

y.Name      = [ 'Maxwell-Boltzmann *3 distribution function (1D) [' mfilename ']' ];
y.Parameters= {'T1','I1','T2','I2','T3','I3'};
y.Description='3 Maxwell-Boltzmann distributions. http://en.wikipedia.org/wiki/Maxwell%E2%80%93Boltzmann_distribution';
y.Expression= {...
  'HBAR    =1.05459E-34;', ...
  'MNEUTRON=1.67492E-27;', ...
  'kk       = 1.38066e-23;', ...
  'lambda=abs(x);', ...
  'T1=p(1);', ...
  'I1=p(2);', ...
  'T2=p(3);', ...
  'I2=p(4);', ...
  'T3=p(5);', ...
  'I3=p(6);', ...
  '  if (T1>0)', ...
  '    lambda0  = 1.0e10*sqrt(HBAR*HBAR*4.0*pi*pi/2.0/MNEUTRON/kk/T1);', ...
  '    lambda02 = lambda0*lambda0;	   ', ...
  '    L2P      = 2*lambda02*lambda02;', ...
  '  else lambda0=0;', ...
  '  end', ...
  '  if (T2>0)', ...
  '    lambda0b  = 1.0e10*sqrt(HBAR*HBAR*4.0*pi*pi/2.0/MNEUTRON/kk/T2);', ...
  '    lambda02b = lambda0b*lambda0b;	   ', ...
  '    L2Pb      = 2*lambda02b*lambda02b;', ...
  '  else lambda0b=0;', ...
  '  end', ...
  '  if (T3>0)', ...
  '    lambda0c  = 1.0e10*sqrt(HBAR*HBAR*4.0*pi*pi/2.0/MNEUTRON/kk/T3);', ...
  '    lambda02c = lambda0c*lambda0c;	   ', ...
  '    L2Pc      = 2*lambda02c*lambda02c;', ...
  '  else lambda0c=0;', ...
  '  end', ...
  '  lambda2=lambda .*lambda;', ...
  '  lambda5=lambda2.*lambda2.*lambda;', ...
  '  maxwell=I1*zeros(size(x));', ...
  '  if (T1 > 0)', ...
  '    maxwell= I1*L2P./lambda5.*exp(-lambda02./lambda2);', ...
  '    if ((T2 > 0) & (I1 ~= 0))', ...
  '      if (I2 == 0), I2 = I1; end', ...
  '      maxwell = maxwell+ (I2).*L2Pb./lambda5.*exp(-lambda02b./lambda2);', ...
  '    end', ...
  '    if ((T3 > 0) & (I1 ~= 0))', ...
  '      if (I3 == 0), I3 = I1; end', ...
  '      maxwell = maxwell+ (I3).*L2Pc./lambda5.*exp(-lambda02c./lambda2);', ...
  '     end', ...
  '  end', ...
  '  signal=maxwell;' };
y.Guess     = [ 213 1.46e13 83 3.26e12 26 1.2e13 ];
y.Dimension =1;

y = iFunc(y);

if nargin == 1 && isnumeric(varargin{1})
  y.ParameterValues = varargin{1};
elseif nargin > 1
  y = y(varargin{:});
end

