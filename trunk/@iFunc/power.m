function c = power(a,b)
% c = power(a,b) : computes the power of iFunc objects
%
%   @iFunc/power (.^) function to compute the power of functions
%
% input:  a: object or array (iFunc or numeric)
%         b: object or array (iFunc or numeric)
% output: c: object or array (iFunc)
% ex:     c=lorz.^gauss;
%
% Version: $Revision: 1.1 $
% See also iFunc, iFunc/minus, iFunc/plus, iFunc/times, iFunc/rdivide

if nargin ==1
	b=[];
end
c = iFunc_private_binary(a, b, 'power');

