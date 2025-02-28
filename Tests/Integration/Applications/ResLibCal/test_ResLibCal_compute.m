function result=test_ResLibCal_compute

  out=ResLibCal('default','compute');	% load the default figure/parameters
  out=ResLibCal('view2');
  out=ResLibCal('view3');
  out=ResLibCal('geometry');

  ResLibCal('quit');

  if isjava('jvm') && abs(out.resolution.rlu.Bragg(5) - 0.89) < 1e-2
    result = [ 'OK     ' mfilename ];
  elseif ~isjava('jvm') && abs(out.resolution.rlu.Bragg(5) - 3.04) < 1e-2
    result = [ 'OK     ' mfilename ];
  else
    result = [ 'FAILED ' mfilename ];
  end

