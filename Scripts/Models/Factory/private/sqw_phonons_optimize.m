function [options, sav] = sqw_phonons_optimize(decl, calc, options)
% sqw_phonons_optimize: perform the optimization step with ASE
%   requires valid 'atoms.pkl' and calculator

target = options.target;
% init calculator

if strcmpi(options.calculator, 'GPAW')
  % GPAW Bug: gpaw.aseinterface.GPAW does not support pickle export for 'input_parameters'
  sav = sprintf('  atoms.set_calculator(None)\n');
else
  sav = '';
end

if ~isempty(options.optimizer) && strcmpi(options.calculator, 'QUANTUMESPRESSO') ...
  && ~strcmpi(options.calculator, 'QUANTUMESPRESSO_ASE')
  options.optimizer = [];
end

if ~isempty(options.optimizer)
  switch lower(options.optimizer)
  case 'lbfgs'  % fast, low on memory
    options.optimizer='LBFGS';
  case 'fire'   % slow
    options.optimizer='FIRE';
  case 'mdmin'  % fast
    options.optimizer='MDMin';
  otherwise
  % case 'bfgs'   % fast
    options.optimizer='BFGS';
  end
  options.script_optimize = sprintf([ ...
    '# python script built by ifit.mccode.org/Models.html sqw_phonons\n' ...
    '# on ' datestr(now) '\n' ...
    '# E. Farhi, Y. Debab and P. Willendrup, J. Neut. Res., 17 (2013) 5\n' ...
    '# S. R. Bahn and K. W. Jacobsen, Comput. Sci. Eng., Vol. 4, 56-66, 2002.\n' ...
    '#\n' ...
    '# optimize material structure and update atoms as a pickle\n\n' ...
    'import pickle\n' ...
    'from ase.optimize import ' options.optimizer '\n' ...
    'fid = open("' fullfile(target, 'atoms.pkl') '","rb")\n' ...
    'atoms = pickle.load(fid)\n' ...
    'fid.close()\n' ...
    decl '\n' ...
    calc '\n' ...
    'print "Optimising structure with the ' options.optimizer ' optimizer...\\n"\n' ...
    'try:\n' ...
    '  atoms.set_calculator(calc)\n' ...
    '  dyn = ' options.optimizer '(atoms)\n' ...
    '  dyn.run(fmax=0.05)\n' ...
    '# update pickle and export (overwrite initial structure)\n' ...
    sav ...
    '  fid = open("' fullfile(target, 'atoms.pkl') '","wb")\n' ...
    '  pickle.dump(atoms, fid)\n' ...
    '  fid.close()\n' ...
    '  from ase.io import write\n' ...
    '  write("' fullfile(target, 'optimized.png') '", atoms)\n' ...
    '  write("' fullfile(target, 'optimized.cif') '", atoms, "cif")\n' ...
    '  write("' fullfile(target, 'optimized.pdb') '", atoms, "pdb")\n' ...
    '  write("' fullfile(target, 'optimized_POSCAR') '", atoms, "vasp")\n' ...
    'except:\n' ...
    '  print "Optimisation failed. Proceeding with initial structure\\n"\n' ...
    ]);
    
  % we create a python script to optimize the initial structure
  fid = fopen(fullfile(target,'sqw_phonons_optimize.py'),'w');
  if fid ~= -1
    fprintf(fid, '%s\n', options.script_optimize);
    fclose(fid);
    % call python: optimize initial configuration
    % ------------------------------------------------------------------------------
    result = '';
    disp([ mfilename ': optimizing material structure.' ]);
    try
      [st, result] = system([ precmd options.available.python ' ' fullfile(target,'sqw_phonons_optimize.py') ]);
    catch
      st = 127;
    end
    disp(result)
    % was there an error ? if so, continue (we still use the initial atoms.pkl)
    if isempty(dir(fullfile(target, 'atoms.pkl'))) || st ~= 0
      disp([ mfilename ': WARNING: failed optimize material structure in ' target ' (sqw_phonons_optimize.py). Ignoring.' ]);
    else
      sqw_phonons_htmlreport('', 'optimize', options);
    end

  end
else
  options.script_optimize = '';
end
