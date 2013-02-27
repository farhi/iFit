function [res, inst] = ResLibCal_FormatString(out, mode)
% ResLibCal_FormatString: build a text with results
%
% Input:
%  out:  EXP ResLib structure 
%  mode: can be set to 'rlu' so that the plot is in lattice RLU frame
%
% Return:
%  res:  resolution text
%  inst: instrument parameters

% Calls: none

% input parameters
if nargin == 1, mode=''; end
EXP = out.EXP;
H   = EXP.QH; K=EXP.QK; L=EXP.QL; W=EXP.W;
R0  = out.resolution.R0;
if ~isempty(strfind(mode,'rlu'))
  NP = out.resolution.RMS;
  frame = '[Q1,Q2,Qz,E]';
else
  NP = out.resolution.RM;
  frame = '[Qx,Qy,Qz,E]';
end

ResVol=(2*pi)^2/sqrt(det(NP));

NP = out.resolution.RMS/1e4;

res = { ...
          ['Method: ' out.EXP.method ], ...
          'Position', ...
  sprintf(' QH=%5.3g QK=%5.3g QL=%5.3g E=%5.3g [meV]', H,K,L,W), ...
         ['Resolution Matrix M in ' frame ' (M/10^4)'], ...
          num2str(NP,4), ...
  sprintf('Resolution volume:   V0=%7.3g meV/A^3', ResVol*2), ...
  sprintf('Intensity prefactor: R0=%7.3g',R0) };
inst = { ...
          'Instrument parameters:', ...
  sprintf(' DM  =%7.3f ETAM=%7.3f SM=%i',EXP.mono.d, EXP.mono.mosaic, EXP.mono.dir), ...
  sprintf(' DA  =%7.3f ETAA=%7.3f SA=%i',EXP.ana.d, EXP.ana.mosaic, EXP.ana.dir), ...
  sprintf(' KFIX=%7.3f FX  =%7i SS=%i',  EXP.Kfixed, 2*(EXP.infin==-1)+(EXP.infin==1), EXP.sample.dir), ...
  sprintf(' A1=%5.3g A2=%5.3g A3=%5.3g A4=%5.3g A5=%5.3g A6=%5.3g [deg]', out.resolution.angles), ...
          'Collimation [arcmin]:', ...
  sprintf(' ALF1=%5.2f ALF2=%5.2f ALF3=%5.2f ALF4=%5.2f', EXP.hcol), ...
  sprintf(' BET1=%5.2f BET2=%5.2f BET3=%5.2f BET4=%5.2f', EXP.vcol), ...
          'Sample:', ...
  sprintf(' AS  =%7.3f BS  =%7.3f CS  =%7.3f [Angs]', EXP.sample.a, EXP.sample.b, EXP.sample.c), ...
  sprintf(' AA  =%7.3f BB  =%7.3f CC  =%7.3f [deg]', EXP.sample.alpha, EXP.sample.beta, EXP.sample.gamma), ...
  sprintf(' AX  =%7.3f AY  =%7.3f AZ  =%7.3f [rlu]', EXP.orient1), ...
  sprintf(' BX  =%7.3f BY  =%7.3f BZ  =%7.3f [rlu]', EXP.orient2) };

