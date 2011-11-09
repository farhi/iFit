function out = openinx(filename)
%OPENINX Open an INX tof data file, display it
%        and set the 'ans' variable to an iData object with its content

out = iData(filename);
plot(out);

if ~isdeployed
  assignin('base','ans',out);
end
