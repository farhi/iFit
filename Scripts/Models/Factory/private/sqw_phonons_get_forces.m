function [options, sav] = sqw_phonons_get_forces(options, decl, calc)
% sqw_phonons_get_forces: perform the force estimate using calculator
%   requires atoms.pkl, supercell and calculator, creates the phonon.pkl

  target = options.target;
  % GPAW Bug: gpaw.aseinterface.GPAW does not support pickle export for 'input_parameters'. This is included in Phonon object -> set to None
  % Also the case for other caculators such as LAMMPS
  sav = sprintf('ph.calc=None\natoms.calc=None\nph.atoms.calc=None\n');
  
  % determine if the phonon.pkl exists. If so, nothing else to do
  if ~isempty(dir(fullfile(target, 'phonon.pkl')))
    disp([ mfilename ': re-using ' fullfile(target, 'phonon.pkl') ]);
    return
  end
  
  % required to avoid Matlab to use its own libraries
  if ismac,      precmd = 'DYLD_LIBRARY_PATH= ; DISPLAY= ; ';
  elseif isunix, precmd = 'LD_LIBRARY_PATH= ; DISPLAY= ; '; 
  else           precmd = ''; end
  
  % Call phonons. Return number of remaining steps in 'ret', or 0 when all done.
  % handle accuracy requirement
  if isfield(options.available,'phonopy') && ~isempty(options.available.phonopy) ...
    && options.use_phonopy && strcmpi(options.accuracy,'single_shot')
    % use PhonoPy = very fast (forward difference) in a single calculation (no ETA)
    ph_run = 'ret=ifit.phonopy_run(ph, single=False)\n';
  elseif isfield(options.available,'phonopy') && ~isempty(options.available.phonopy) ...
    && options.use_phonopy
    % use PhonoPy = very fast (forward difference)
    ph_run = 'ret=ifit.phonopy_run(ph, single=True)\n';
  elseif isfield(options, 'accuracy') && strcmpi(options.accuracy,'very fast')
    % very fast: twice faster, but less accurate (assumes initial lattice at equilibrium)
    options.use_phonopy = 0;
    ph_run = 'ret=ifit.phonons_run(ph, single=True, difference="forward")\n'; 
  elseif isfield(options, 'accuracy') && strcmpi(options.accuracy,'single_shot')
    % very fast, and in a single shot mode (no ETA)
    options.use_phonopy = 0;
    ph_run = 'ret=ifit.phonons_run(ph, single=True, difference="forward")\n'; 
  elseif isfield(options, 'accuracy') && any(strcmpi(options.accuracy,{'slow','accurate'}))
    % slow: the default ASE routine: all moves, slower, more accurate
    ph_run = 'ph.run(); ret=0\n';
  else
    % fast (use symmetry operators from spacegroup), with +/- difference
    ph_run = 'ret=ifit.phonons_run(ph, single=True, difference="central")\n'; 
  end
  
  displ = options.disp;
  if ~isscalar(displ), displ=0.01*norm(options.disp); end

  % start python --------------------------  
  if ~isempty(dir(fullfile(target, 'ifit.py')))
    options.script_ifitpy = fileread(fullfile(target, 'ifit.py')); % python
  end
  
  % this scripts should be repeated as long as its return value is null (all is fine)
  options.script_get_forces_iterate = [ ...
    '# python script built by ifit.mccode.org/Models.html sqw_phonons\n', ...
    '# on ' datestr(now) '\n' ...
    '# E. Farhi, Y. Debab and P. Willendrup, J. Neut. Res., 17 (2013) 5\n', ...
    '# S. R. Bahn and K. W. Jacobsen, Comput. Sci. Eng., Vol. 4, 56-66, 2002.\n', ...
    '#\n', ...
    '# Computes the Hellmann-Feynman forces and stores an ase.phonon.Phonons object in a pickle\n', ...
    '# Launch with: python sqw_phonons_iterate.py (and wait...)\n', ...
    'from ase.phonons import Phonons\n', ...
    'import pickle\n', ...
    'import numpy\n', ...
    'import scipy.io as sio\n', ...
    'from ase.parallel import world\n', ...
    'from os import chdir\n', ...
    'import ifit\n' ...
    'chdir("' target '")\n', ...
    '# Get the crystal and calculator\n', ...
    'fid = open("atoms.pkl","rb")\n' ...
    'atoms = pickle.load(fid)\n' ...
    'fid.close()\n' ...
    decl '\n', ...
    calc '\n', ...
    'atoms.set_calculator(calc)\n' ...
    '# Phonon calculator\n', ...
    sprintf('ph = Phonons(atoms, calc, supercell=(%i, %i, %i), delta=%f)\n',options.supercell, displ), ...
    ph_run, ...
    'fid = open("phonon.pkl","wb")\n', ...
    'calc = ph.calc\n', ...
    sav, ...
    'pickle.dump(ph, fid)\n', ...
    'fid.close()\n', ...
    '# return the number of remaining steps\n', ...
    'exit(ret)\n' ];
    
  options.script_get_forces_finalize = [ ...
    '# python script built by ifit.mccode.org/Models.html sqw_phonons\n', ...
    '# on ' datestr(now) '\n' ...
    '# E. Farhi, Y. Debab and P. Willendrup, J. Neut. Res., 17 (2013) 5\n', ...
    '# S. R. Bahn and K. W. Jacobsen, Comput. Sci. Eng., Vol. 4, 56-66, 2002.\n', ...
    '#\n', ...
    '# Computes the Hellmann-Feynman forces and stores an ase.phonon.Phonons object in a pickle\n', ...
    '# Launch with: python sqw_phonons_finalize.py\n', ...
    'from ase.phonons import Phonons\n', ...
    'import pickle\n', ...
    'import numpy\n', ...
    'import scipy.io as sio\n', ...
    'from os import chdir\n', ...
    'import ifit\n' ...
    'chdir("' target '")\n', ...
    '# Get the crystal and calculator\n', ...
    'fid = open("atoms.pkl","rb")\n' ...
    'atoms = pickle.load(fid)\n' ...
    'fid.close()\n' ...
    decl '\n', ...
    calc '\n', ...
    'fid = open("phonon.pkl","rb")\n' , ...
    'ph = pickle.load(fid)\n' ...
    'fid.close()\n' ...
    'atoms.set_calculator(calc)\n' ...
    'ph.calc=calc\n' ...
    'ph.atoms.calc = calc\n' ...
    '# Read forces and assemble the dynamical matrix\n', ...
    'print "Reading forces..."\n', ...
    'if ph.C_N is None:\n', ...
    '    try: ifit.phonons_read(ph, acoustic=True, cutoff=None) # cutoff in Angs\n', ...
    '    except UnboundLocalError: ph.C_N=0\n', ...
    'fid = open("phonon.pkl","wb")\n' , ...
    'calc = ph.calc\n', ...
    sav, ...
    'pickle.dump(ph, fid)\n', ...
    'fid.close()\n', ...
    '# save FORCES and phonon object as a pickle\n', ...
    'sio.savemat("FORCES.mat", { "FORCES":ph.get_force_constant(), "delta":ph.delta, "celldisp":atoms.get_celldisp() })\n', ...
    '# additional information\n', ...
    'atoms.set_calculator(calc) # reset calculator as we may have cleaned it for the pickle\n', ...
    'print "Computing properties\\n"\n', ...
    'try:    magnetic_moment    = atoms.get_magnetic_moment()\n', ...
    'except: magnetic_moment    = None\n', ...
    'try:    kinetic_energy     = atoms.get_kinetic_energy()\n', ... 
    'except: kinetic_energy     = None\n', ...
    'try:    potential_energy   = atoms.get_potential_energy()\n',... 
    'except: potential_energy   = None\n', ...
    'try:    stress             = atoms.get_stress()\n', ... 
    'except: stress             = None\n', ...
    'try:    total_energy       = atoms.get_total_energy()\n', ...
    'except: total_energy       = None\n', ...
    'try:    angular_momentum   = atoms.get_angular_momentum()\n', ... '
    'except: angular_momentum   = None\n', ...
    'try:    charges            = atoms.get_charges()\n', ...
    'except: charges            = None\n', ...
    'try:    dipole_moment      = atoms.get_dipole_moment()\n', ... 
    'except: dipole_moment      = None\n', ...
    'try:    momenta            = atoms.get_momenta()\n', ... 
    'except: momenta            = None\n', ...
    'try:    moments_of_inertia = atoms.get_moments_of_inertia()\n', ...
    'except: moments_of_inertia = None\n', ...
    'try:    center_of_mass     = atoms.get_center_of_mass()\n', ...
    'except: center_of_mass     = None\n', ...
    'try:\n', ...
    '    from ase.dft import DOS\n', ...
    '    dos = DOS(calc, width=0.2)\n', ...
    '    edos_g = dos.get_dos()\n', ...
    '    edos_e = dos.get_energies()\n', ...
    'except: edos_g=edos_e= None\n', ...
    '# get the previous properties from the init phase\n' ...
    'try:\n' ...
    '  fid = open("properties.pkl","rb")\n' ...
    '  properties = pickle.load(fid)\n' ...
    '  fid.close()\n' ...
    'except:\n' ...
    '  properties = dict()\n' ...
    'properties["magnetic_moment"]  = magnetic_moment\n' ...
    'properties["kinetic_energy"]   = kinetic_energy\n' ...
    'properties["potential_energy"] = potential_energy\n' ...
    'properties["stress"]           = stress\n' ...
    'properties["momenta"]          = momenta\n' ...
    'properties["total_energy"]     = total_energy\n' ...
    'properties["angular_momentum"] = angular_momentum\n' ...
    'properties["charges"]          = charges\n' ...
    'properties["dipole_moment"]    = dipole_moment\n' ...
    'properties["moments_of_inertia"]= moments_of_inertia\n' ...
    'properties["center_of_mass"]   = center_of_mass\n' ...
    'properties["density_of_states_g"]= edos_g\n' ...
    'properties["density_of_states_e"]= edos_e\n' ...
    '# remove None values in properties\n' ...
    'properties = {k: v for k, v in properties.items() if v is not None}\n' ...
    '# export properties as pickle\n' ...
    'fid = open("properties.pkl","wb")\n' ...
    'pickle.dump(properties, fid)\n' ...
    'fid.close()\n' ...
    '# export properties as MAT\n' ...
    'sio.savemat("properties.mat", properties)\n' ...
  ];
  % end   python --------------------------

  
  
  % moves ----------------------------------------------------------------------
  
  % clean up any previous forces/phonon displacement pickle file
  delete(fullfile(target,'phonon.*.pckl'))
  
  % write the script in the target directory
  fid = fopen(fullfile(target,'sqw_phonons_forces_iterate.py'),'w');
  fprintf(fid, options.script_get_forces_iterate);
  fclose(fid);
  
  % call python script with calculator
  disp([ mfilename ': computing Hellmann-Feynman forces...' ]);
  disp(calc)
  options.status = 'Starting computation. Script is <a href="sqw_phonons_forces_iterate.py">sqw_phonons_forces_iterate.py</a>';
  sqw_phonons_htmlreport('', 'status', options);
  
  nb_of_steps = 0;
  
  result = '';
  st = 1; st_previous = Inf;
  t0 = clock;           % a vector used to compute elapsed/remaining seconds
  
  while st>0
    try
      if strcmpi(options.calculator, 'GPAW') && isfield(options,'mpi') ...
        && ~isempty(options.mpi) && options.mpi > 1
        [st, result] = system([ precmd options.available.mpirun ' -np ' num2str(options.mpi) ' '  options.available.gpaw ' ' fullfile(target,'sqw_phonons_forces_iterate.py') ]);
      else
        [st, result] = system([ precmd options.available.python ' ' fullfile(target,'sqw_phonons_forces_iterate.py') ]);
      end
      disp(st)
      % the first return 'st' gives the max number of steps remaining
      % but one at least was done so far
      if ~nb_of_steps && st > 0, nb_of_steps = st+1; end

      % display result
      disp(result)
      options.status = result;
      sqw_phonons_htmlreport('', 'status', options);
      
      if 0 <= st && st <= nb_of_steps && nb_of_steps
        % we have done so far nb_of_steps - st steps, which took etime(clock, t0)
        % so one step takes etime(clock, t0)/(nb_of_steps-st)
        time_per_step = etime(clock, t0)/(nb_of_steps-st);
        % then the remaining time is
        remaining = time_per_step*st;

        hours     = floor(remaining/3600);
        minutes   = floor((remaining-hours*3600)/60);
        seconds   = floor(remaining-hours*3600-minutes*60);
        enddate   = addtodate(now, ceil(remaining), 'second');
        
        options.status = [ '[' datestr(now) '] ETA ' sprintf('%i:%02i:%02i', hours, minutes, seconds) ', ending on ' datestr(enddate) '. Remaining steps ' num2str(st) '/' num2str(nb_of_steps) ' [' num2str(round(nb_of_steps-st)/nb_of_steps*100) '%]'];
        disp([ mfilename ': ' options.status ]);
        sqw_phonons_htmlreport('', 'status', options);
      else
        % something is wrong. The phonon remaining displacement is inconsistent
        break
      end
      % detect if we are stuck (and we are not finished)
      if st == st_previous
        break
      end
      st_previous = st;
    catch ME
      disp(result)
      disp(getReport(ME))
      options.status = result;
      sqw_phonons_htmlreport('', 'status', options);
      sqw_phonons_error([ mfilename ': failed calling ASE with script ' ...
        fullfile(target,'sqw_phonons_iterate.py') ], options);
      options = [];
      return
    end
  end
  
  % now finalize ---------------------------------------------------------------
  
  % in principle, if all went OK, we have st == 0 (no more iteration needed)
  if st ~= 0
    % something got wrong
    sqw_phonons_error([ mfilename ': failed some iterations of ASE script ' ...
        fullfile(target,'sqw_phonons_iterate.py') ], options);
    % we still continue in case it can be processed, building force constants (lucky)
    % but result should be expected wrong...
  end
  
  % write the script in the target directory
  fid = fopen(fullfile(target,'sqw_phonons_forces_finalize.py'),'w');
  fprintf(fid, options.script_get_forces_finalize);
  fclose(fid);
  
  % call python script with calculator
  disp([ mfilename ': computing Force Constants, creating Phonon model.' ]);
  options.status = 'Ending computation. Script is <a href="sqw_phonons_forces_finalize.py">sqw_phonons_forces_finalize.py</a>';
  sqw_phonons_htmlreport('', 'status', options);
  
  try
    [st, result] = system([ precmd options.available.python ' ' fullfile(target,'sqw_phonons_forces_finalize.py') ]);
    % display result
    disp(result)
    options.status = result;
    sqw_phonons_htmlreport('', 'status', options);
  catch ME
    disp(result)
    disp(getReport(ME))
    sqw_phonons_error([ mfilename ': failed calling ASE with script ' ...
      fullfile(target,'sqw_phonons_finalize.py') ], options);
    options = [];
    return
  end
  
  
