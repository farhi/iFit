function [p, labels] = ResLibCal_EXP2RescalPar(EXP)
% [p, labels] = ResLibCal_EXP2RescalPar(EXP): Convert a ResLib EXP structure to a ResCal5 parameter vector
%
% Returns:
%  p:      parameters (42 rescal+27 popovici)
%  labels: signification of parameters

% Calls: none

  persistent labels_c

  if nargin == 0, EXP=[]; end
  
  p = [];
  if isempty(labels_c) % only the first time, else persistent
    lres={ ...
     'DM Monochromator d-spacing', ...
     'DA Analyzer d-spacing', ...
     'ETAM Monochromator mosaic', ...
     'ETAA Analyzer mosaic', ...
     'ETAS Sample mosaic', ...
     'SM scattering sense from monochromator +1=right, -1=left', ...
     'SS scattering sense from sample +1=right, -1=left', ...
     'SA scattering sense from analyzer +1=right, -1=left', ...
     'KFIX fixed neutron wavevector in Ang.-1', ...
     'FX index for fixed wavevector 1=incident 2=final (10)', ...
     'ALF1 horizontal source-mono. collimation in min', ...
     'ALF2 horizontal mono.-sample collimation in min', ...
     'ALF3 horizontal sample-analyser collimation in min', ...
     'ALF4 horizontal analyser-detector collimation in min', ...
     'BET1 vertical source-mono.  collimation in min', ...
     'BET2 vertical mono.-sample collimation in min', ...
     'BET3 vertical sample-analyser collimation in min', ...
     'BET4 vertical analyser-detector collimation in min', ...
     'AS sample lattice parameter A in Ang. (19)', ...
     'BS sample lattice parameter B in Ang.', ...
     'CS sample lattice parameter C in Ang.', ...
     'AA (alpha) angle in deg. between axis B and C', ...
     'BB (beta) angle in deg. between axis A and C', ...
     'CC (gamma) angle in deg. between axis A and B', ...
     'AX First wavevector in scattering plane coordinate H (rlu), along KI', ...
     'AY First wavevector in scattering plane coordinate K (rlu)', ...
     'AZ First wavevector in scattering plane coordinate L (rlu)', ...
     'BX Second wavevector in scattering plane coordinate H (rlu)', ...
     'BY Second wavevector in scattering plane coordinate K (rlu)', ...
     'BZ Second wavevector inou scattering plane coordinate L (rlu)', ...
     'QH Position of resolution wavevector (center of measurement) H (rlu) (31)', ...
     'QK Position of resolution wavevector (center of measurement) K (rlu)', ...
     'QL Position of resolution wavevector (center of measurement) L (rlu)', ...
     'EN (W) Position of resolution wavevector (center of measurement) W (meV)', ...
     'DQH Increment of Q,E defining general scan step along QH (rlu)', ...
     'DQK Increment of Q,E defining general scan step along QK (rlu)', ...
     'DQL Increment of Q,E defining general scan step along QL (rlu)', ...
     'DEN Increment of Q,E defining general scan step along EN (meV)', ...
     'GH Gradient of the dispersion (planar) direction along QH (rlu)', ...
     'GK Gradient of the dispersion (planar) direction along QK (rlu)', ...
     'GL Gradient of the dispersion (planar) direction along QL (rlu)', ...
     'GMOD  Gradient of the dispersion (planar) direction along EN (meV)'};
     
    linst = {...
     'BeamShape =0 for circular source, =1 for rectangular source (1)', ...
     'WB width/diameter of the source (cm) (2)', ...
     'HB height/diameter of the source (cm) (3)', ...
     'Guide =0 No Guide, =1 for Guide (4)', ...
     'GDH horizontal guide divergence (minutes/Angs) (5)', ...
     'GDV vertical guide divergence (minutes/Angs) (6)',  ...
     'SampleShape =0 for cylindrical sample, =1 for cuboid sample (7)', ...
     'WS sample width/diameter perp. to Q (cm) (8)', ...
     'TS sample width/diameter along Q (cm) (9)', ...
     'HS sample height (cm) (10)', ...
     'DetecteorShape =0 for circular detector, =1 for rectangular detector (11)', ...
     'WD width/diameter of the detector (cm) (12)', ...
     'HD height/diameter of the detector (cm) (13)', ...
     'TM thickness of monochromator (cm) (14)', ...
     'WM width of monochromator (cm) (15)', ...
     'HM height of monochromator (cm) (16)', ...
     'TA thickness of analyser (cm) (17)', ...
     'WA width of analyser (cm) (18)', ...
     'HA height of analyser (cm) (19)', ...
     'L1 distance between source and monochromator (cm) (20)', ...
     'L2 distance between monochromator and sample (cm) (21)', ...
     'L3 distance between sample and analyser (cm) (22)', ...
     'L4 distance between analyser and detector (cm) (23)', ...
     'ROMH horizontal curvature of monochromator 1/radius (m-1) (24)', ...
     'ROMV vertical curvature of monochromator (m-1) (25)', ...
     'ROAH horizontal curvature of analyser (m-1) (26)', ...
     'ROAV vertical curvature of analyser (m-1) (27)'};
    
    labels_c=[ lres, linst ];
  end
  labels = labels_c;
  if isempty(EXP), return; end
  if isfield(EXP,'EXP')
    EXP = EXP.EXP;
  end

% ResCal parameters (pres: 42)
  p=[];
  p(1) =EXP.mono.d;
  p(2) =EXP.ana.d;
  p(3) =EXP.mono.mosaic;
  p(4) =EXP.ana.mosaic;
  p(5) =EXP.sample.mosaic;
  p(6) =EXP.mono.dir;
  p(7) =EXP.sample.dir;
  p(8) =EXP.ana.dir;
  p(9) =EXP.Kfixed;
  p(10)=2*(EXP.infin==-1)+(EXP.infin==1);
  p(11:14)=EXP.hcol(1:4);
  p(15:18)=EXP.vcol(1:4);
  p(19:21)=[ EXP.sample.a     EXP.sample.b    EXP.sample.c ];
  p(22:24)=[ EXP.sample.alpha EXP.sample.beta EXP.sample.gamma ];
  p(25:27)=EXP.orient1;
  p(28:30)=EXP.orient2;
  p(31:34)=[ mean(EXP.QH) mean(EXP.QK) mean(EXP.QL) mean(EXP.W) ];
  p(35:38)=[ 0 0 0 1 ];
  p(39:42)=[ 0 0 1 0 ];

  pres = p; % ResCal
   
% Popovici parameters (pinst: 27)
  p=[];
  p(1) =1;                  % =0 for circular source, =1 for rectangular source
  p(2) =EXP.beam.width;     % width/diameter of the source (cm)
  p(3) =EXP.beam.height;    % height/diameter of the source (cm)
  if any(EXP.hcol < 0 | EXP.vcol < 0) 
   p(4) = 1;              % =0 No Guide, =1 for Guide
   p(5) = abs(mean(EXP.hcol(EXP.hcol < 0))*0.1*60);    % horizontal guide divergence (minutes/Angs)
   p(6) = abs(mean(EXP.vcol(EXP.vcol < 0))*0.1*60);    % vertical guide divergence (minutes/Angs)
  else p(4) = 0; p(5)=0; p(6)=0;
  end       
  p(7) = 1;                % =0 for cylindrical sample, =1 for cuboid sample
  p(8) = EXP.sample.depth; % sample width/diameter perp. to Q (cm)
  p(9) = EXP.sample.width; % sample width/diameter along Q (cm)
  p(10)= EXP.sample.height;% sample height (cm)
  p(11)= 1;                % =0 for circular detector, =1 for rectangular detector
  p(12)=EXP.detector.width;% width/diameter of the detector (cm)
  p(13)=EXP.detector.height;% height/diameter of the detector (cm)
  p(14)=EXP.mono.depth;    % thickness of monochromator (cm)
  p(15)=EXP.mono.width;    % width of monochromator (cm)
  p(16)=EXP.mono.height;   % height of monochromator (cm)
  p(17)=EXP.ana.depth;     % thickness of analyser (cm)
  p(18)=EXP.ana.width;     % width of analyser (cm)
  p(19)=EXP.ana.height;    % height of analyser (cm)
  p(20)=EXP.arms(1);       % distance between source and monochromator (cm)
  p(21)=EXP.arms(2);       % distance between monochromator and sample (cm)
  p(22)=EXP.arms(3);       % distance between sample and analyser (cm)
  p(23)=EXP.arms(4);       % distance between analyser and detector (cm)
  p(24)=100/EXP.mono.rh;       % horizontal curvature of monochromator 1/radius (m-1)
  p(25)=100/EXP.mono.rv;       % vertical curvature of monochromator (m-1)
  p(26)=100/EXP.ana.rh;        % horizontal curvature of analyser (m-1)
  p(27)=100/EXP.ana.rv;        % vertical curvature of analyser (m-1)
  pinst = p;               % Popovici

  p=[pres pinst];
   
% end ResLibCal_EXP2RescalPar
