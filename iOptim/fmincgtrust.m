function [pars,fval,exitflag,output] = fmincgtrust(varargin)
% [MINIMUM,FVAL,EXITFLAG,OUTPUT] = fmincgtrust(FUN,PARS,[OPTIONS],[CONSTRAINTS]) Steihaug Newton-CG-Trust region algoirithm
%
% This minimization method uses the Steihaug Newton-CG-Trust region algoirithm
% 
% Calling:
%   fmincgtrust(fun, pars) asks to minimize the 'fun' objective function with starting
%     parameters 'pars' (vector)
%   fmincgtrust(fun, pars, options) same as above, with customized options (optimset)
%   fmincgtrust(fun, pars, options, fixed) 
%     is used to fix some of the parameters. The 'fixed' vector is then 0 for
%     free parameters, and 1 otherwise.
%   fmincgtrust(fun, pars, options, lb, ub) 
%     is used to set the minimal and maximal parameter bounds, as vectors.
%   fmincgtrust(fun, pars, options, constraints) 
%     where constraints is a structure (see below).
%
% Example:
%   banana = @(x)100*(x(2)-x(1)^2)^2+(1-x(1))^2;
%   [x,fval] = fmincgtrust(banana,[-1.2, 1])
%
% Input:
%  FUN is the function to minimize (handle or string).
%
%  PARS is a vector with initial guess parameters. You must input an
%  initial guess.
%
%  OPTIONS is a structure with settings for the optimizer, 
%  compliant with optimset. Default options may be obtained with
%     o=fminbfgs('defaults')
%
%  CONSTRAINTS may be specified as a structure
%   constraints.min=   vector of minimal values for parameters
%   constraints.max=   vector of maximal values for parameters
%   constraints.fixed= vector having 0 where parameters are free, 1 otherwise
%   constraints.step=  vector of maximal parameter changes per iteration
%
% Output:
%          MINIMUM is the solution which generated the smallest encountered
%            value when input into FUN.
%          FVAL is the value of the FUN function evaluated at MINIMUM.
%          EXITFLAG return state of the optimizer
%          OUTPUT additional information returned as a structure.
% Reference: Broyden, C. G., J. of the Inst of Math and Its Appl 1970, 6, 76-90
%   Fletcher, R., Computer Journal 1970, 13, 317-322
%   Goldfarb, D., Mathematics of Computation 1970, 24, 23-26
%   Shanno, D. F.,Mathematics of Computation 1970, 24, 647-656
% Contrib: C. T. Kelley, 1998, Iterative Methods for Optimization [cgtrust]
%
% Version: $Revision: 1.3 $
% See also: fminsearch, optimset

% default options for optimset
if nargin == 0 || (nargin == 1 && strcmp(varargin{1},'defaults'))
  options=optimset; % empty structure
  options.Display='';
  options.TolFun =1e-3;
  options.TolX   =1e-8;
  options.MaxIter='100*numberOfVariables';
  options.MaxFunEvals=10000;
  options.algorithm  = [ 'Steihaug Newton-CG-Trust region algoirithm (by Kelley) [' mfilename ']' ];
  options.optimizer = mfilename;
  pars = options;
  return
end

[pars,fval,exitflag,output] = fmin_private_wrapper(mfilename, varargin{:});

