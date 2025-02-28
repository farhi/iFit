function out = openyaml(filename)
%OPENYAML Open a YAML File, display it
%        and set the 'ans' variable to an iData object with its content
% 

if ~isa(filename,'iData')
  out = load(iData,filename,'YAML');   % with post-processing
else
  out = filename;
end
clear filename;

if numel(out) > 1
  % handle input iData arrays
  for index=1:numel(out)
    out(index) = feval(mfilename, out(index));
  end
end

if ~nargout
  figure; subplot(out);
  
  if ~isdeployed
    assignin('base','ans',out);
    ans = out
  end
end

