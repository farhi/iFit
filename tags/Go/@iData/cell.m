function [content,fields]=cell(s)
% [content,fields]=cell(s) : convert iData objects into cells
%
%   @iData/cell function to convert iData objects into cells
%
% input:  s: iData single object (iData)
% output: content: content of the iData structure (cell)
%         fields:  field names of the iData object (cell)
%
% See also  iData/cell, iData/double, iData/struct, 
%           iData/char, iData/size

% EF 27/07/00 creation
% EF 23/09/07 iData implementation

if length(s(:)) > 1
  iData_private_error(mfilename, ['I can not handle iData arrays. ' inputname(1) ' size is [' num2str(size(s)) '].']);
end

content = struct2cell(s);
fields  = fieldnames(s);
