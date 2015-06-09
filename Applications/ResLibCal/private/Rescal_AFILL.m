function [R0, RMS] = Rescal_AFILL(H,K,L,W,EXP)  
% from vTAS_view/AFILL A. Bouvet 
%
%      THIS GENERATES COOPER-NATHANS RESOLUTION MATRIX.
%      AGREES WITH MATRIX GENERATED BY INDEPENDENT METHOD BY R. PYNN.
%      COORDINATE AXES REVERSED W.R.T. COOPER-NATHANS CONVENTION.

% specificity: original CN only takes isotropic mosaicity

  FOC =  EXP.sample.dir*EXP.mono.dir; 
  MOD = -EXP.ana.dir   *EXP.mono.dir;
  PIT = 2*pi/(360*60);		
  % convert collimator divergence from minutes to radian
  ALZ =EXP.hcol(1)*PIT;
  ALM =EXP.hcol(2)*PIT;
  ALA =EXP.hcol(3)*PIT;
  AL3 =EXP.hcol(4)*PIT;
  BET0=EXP.vcol(1)*PIT;
  BET1=EXP.vcol(2)*PIT;
  BET2=EXP.vcol(3)*PIT;
  BET3=EXP.vcol(4)*PIT;
  % convert mosaic spread from minutes to radian
  ETAM=EXP.mono.mosaic*PIT;
  ETAA=EXP.ana.mosaic*PIT;
  ETAS=EXP.sample.mosaic*PIT;
  % call rc_re2rc from ResCal to get the reciprocal Q vector
  [q0,Qmag]= rc_re2rc( [ EXP.sample.a EXP.sample.b EXP.sample.c ], ...
    [ EXP.sample.alpha EXP.sample.beta EXP.sample.gamma ] , ...
    [ H K L ] );

  % compute Ki, Kf, Ei, Ef (standard method)
  fx = 2*(EXP.infin==-1)+(EXP.infin==1);
  kfix = EXP.Kfixed;
  f=0.4826; % f converts from energy units into k^2, f=0.4826 for meV
  EXP.ki=sqrt(kfix^2+(fx-1)*f*W);  % kinematical equations.
  EXP.kf=sqrt(kfix^2-(2-fx)*f*W);

  Q=Qmag; % norm
  ENF = 0.4826;
  EN  = W;
  AOM=EN*ENF;
  AKI=EXP.ki;
  AKF=EXP.kf;

  R0=0; RMS=[];

  ALAM=AKI/AKF;
  BE=-(Q*Q-2.*AKI*AKI+AOM)/(2.*AKI*AKF);
  if (abs(BE) > 1.0)
	  disp([ datestr(now) ': ' mfilename ': KI,KF,Q triangle will not close (kinematic equations). Change the value of KFIX,FX,QH,QK or QL.' ]);
    disp([ H K L W ]);
    return
  end
  AL=sqrt(1.-BE*BE)*FOC;
  B =-1.*(Q*Q-AOM)/(2.*Q*AKF);
  if (abs(B) > 1.0)
	  disp([ datestr(now) ': ' mfilename ': KI,KF,Q triangle will not close (kinematic equations). Change the value of KFIX,FX,QH,QK or QL.' ]);
  end

  ALP(1)=-B/AL;
  ALP(2)=sqrt(1.-B*B)*FOC/AL;
  ALP(3)=1./(AL*2.*AKF);
  SB=(Q*Q+AOM)/(2.*Q*AKI);
  if (abs(SB) > 1.0) 
    disp([ datestr(now) ': ' mfilename ': KI,KF,Q triangle will not close (kinematic equations). Change the value of KFIX,FX,QH,QK or QL.' ]);
    disp([ H K L W ]);
    return
  end
  SASA=sqrt(1.-SB*SB)*FOC;

  BET(1)=-SB/AL;
  BET(2)=SASA/AL;
  BET(3)=BE/(AL*2.*AKF);
  GAM(1)=0.;
  GAM(2)=0.;
  GAM(3)=-1./(2.*AKF);
  if ( (AKI < (pi/EXP.mono.d)) || (AKF < (pi/EXP.ana.d)) )
	  error([ mfilename ': KI or KF Cannot Be Obtained. Change the value of EXP.mono.d,EXP.ana.d,KFIX or FX.' ])
  end

  TOM=-pi/(EXP.mono.d*sqrt(AKI*AKI-pi*pi/(EXP.mono.d*EXP.mono.d)));
  TOA=(MOD*pi/EXP.ana.d)/sqrt(AKF*AKF-pi*pi/(EXP.ana.d*EXP.ana.d));
  if (ETAM <= 0. || ETAA <= 0.)
	  error([ mfilename ': division by zero. Change the value of ETAM or ETAA.' ]);
  end

  A1=TOM/(AKI*ETAM);
  A2=1./(AKI*ETAM);
  A3=1./(AKI*ALM);
  A4=1./(AKF*ALA);
  A5=TOA/(AKF*ETAA);
  A6=-1./(AKF*ETAA);
  A7=2.*TOM/(AKI*ALZ);
  A8=1./(AKI*ALZ);
  A9=2.*TOA/(AL3*AKF);
  A10=-1./(AL3*AKF);
  B0=A1*A2+A7*A8;
  B1=A2*A2+A3*A3+A8*A8;
  B2=A4*A4+A6*A6+A10*A10;
  B3=A5*A5+A9*A9;
  B4=A5*A6+A9*A10;
  B5=A1*A1+A7*A7;
  C=-1.*(ALAM-BE)/AL;
  E=-1.*(BE*ALAM-1.)/AL;
  AP=A1*A1+2.*B0*C+B1*C*C+B2*E*E+B3*ALAM*ALAM+2.*B4*ALAM*E+A7*A7;
  D0=B1-1./AP*(B0+B1*C)*(B0+B1*C);
  D1=B2-1./AP*(B2*E+B4*ALAM)*(B2*E+B4*ALAM);
  D2=B3-1./AP*(B3*ALAM+B4*E)*(B3*ALAM+B4*E);
  D3=2.*B4-2./AP*(B2*E+B4*ALAM)*(B3*ALAM+B4*E);
  D4=-2./AP*(B0+B1*C)*(B2*E+B4*ALAM);
  D5=-2./AP*(B0+B1*C)*(B3*ALAM+B4*E);
  for I = 1:3
	  for J = 1:3
		  II=I;
				JJ=J;
				if (I == 3) II=4; end
				if (J == 3) JJ=4; end
				RMS(II,JJ)=D0*ALP(I)*ALP(J) ...
						   +D1*BET(I)*BET(J)+D2*GAM(I)*GAM(J) ...
						+.5*D3*(BET(I)*GAM(J)+BET(J)*GAM(I)) ...
						+.5*D4*(ALP(I)*BET(J)+ALP(J)*BET(I)) ...
						+.5*D5*(ALP(I)*GAM(J)+ALP(J)*GAM(I));
	  end
  end 

  % vertical resolution
  SOM=-pi/(EXP.mono.d*AKI);
  SOA=MOD*pi/(EXP.ana.d*AKF);
  DUM1=(4*SOM*SOM*ETAM*ETAM+BET0*BET0)*AKI*AKI;
  A112=1./DUM1+1./(BET1*BET1*AKI*AKI);
  DUM1=(4*SOA*SOA*ETAA*ETAA+BET3*BET3)*AKF*AKF;
  A122=1./DUM1+1./(BET2*BET2*AKF*AKF);
  RMS(3,3)=A112*A122/(A112+A122);

  DETR=0.;
  DETB=1.;
  DETC=1.;
  if (ETAS >= 0.00005)
	  DETS=1./(Q*Q*ETAS*ETAS);
	  DETR=1./(DETS+RMS(2,2));
	  DETB=DETS/(DETS+RMS(2,2));
	  DETC=DETS/(DETS+RMS(3,3));
  end
  FAC=sqrt(DETB*DETC);
  AD(1,1)=RMS(1,1)-RMS(1,2)*RMS(1,2)*DETR;
  AD(1,2)=RMS(1,2)*DETB;
  AD(1,3)=RMS(1,3);
  AD(1,4)=(RMS(1,4)-RMS(1,2)*RMS(2,4)*DETR)*ENF;
  AD(2,1)=AD(1,2);
  AD(2,2)=RMS(2,2)*DETB;
  AD(2,3)=RMS(2,3);
  AD(2,4)=RMS(2,4)*DETB*ENF;
  AD(3,1)=AD(1,3);
  AD(3,2)=AD(2,3);
  AD(3,3)=RMS(3,3)*DETC;
  AD(3,4)=RMS(3,4);
  AD(4,1)=AD(1,4);
  AD(4,2)=AD(2,4);
  AD(4,3)=AD(3,4);
  AD(4,4)=(RMS(4,4)-RMS(4,2)*RMS(4,2)*DETR)*ENF*ENF;
  RMS = AD*8*log(2);

  for I=1:4
	  RMS(I,2)=-RMS(I,2)*EXP.mono.dir;
	  RMS(2,I)=-RMS(2,I)*EXP.mono.dir;
  end

  % intensity pre-factor
  
  thetaa=asin(pi/(EXP.ana.d*AKF));      % theta angles for analyser
  thetam=asin(pi/(EXP.mono.d*AKI));     % and monochromator.
  
  % intensity from Chesser/Axe 1972
  R0 = 2*pi/(AKI^2*AKF^3*AL) ...
		/sqrt(AP*(A112+A122)) ...
		*sqrt( ...
		   BET0^2/(BET0^2+(2*ETAM*sin(thetam))^2) ...
		  *BET3^2/(BET3^2+(2*ETAA*sin(thetaa))^2));
  R0 = abs(R0);
  
  %Transform prefactor to Chesser-Axe normalization
  R0  = R0/(2*pi)^2*sqrt(det(RMS));
  %---------------------------------------------------------------------------
  %Include kf/ki part of cross section
  R0  = R0*AKF/AKI;
  % sample mosaic S. A. Werner & R. Pynn, J. Appl. Phys. 42, 4736, (1971), eq 19
  R0  = R0/sqrt((1+(Q*ETAS)^2*RMS(3,3))*(1+(Q*ETAS)^2*RMS(2,2)));
  
