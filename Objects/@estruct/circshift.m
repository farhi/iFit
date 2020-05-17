function a=circshift(a, varargin)
% CIRCSHIFT Shifts an object axis of specified rank by a value.
%   A=CIRCSHIFT(A, RANK, SHIFT) shifts object axes RANK by SHIFT.
%   This is equivalent to A{RANK} = A{RANK}+SHIFT; and MOVEAXIS.
%
% Example: a=estruct(peaks); circshift(a, 1, 5); max(getaxis(a,1))==54
% Version: $Date$ $Version$ $Author$
% See also  estruct/getaxis, estruct/setaxis

a = moveaxis(a, varargin{:});
