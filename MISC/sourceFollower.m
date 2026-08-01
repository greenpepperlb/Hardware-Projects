% sizing of transistors in a source follower using tables of transistor
% data
% we use an nMOS source follower loaded at its source by an nMOS current
% source
% CMOS process used is 65nm

if not(exist('NRVT'))
    load 'C:\Users\wambacq\OneDrive - imec\lessons\exercises\20-21\AEC_2020_21_TA _MASTER\models\UMC65_RVT.mat'
% THIS PATH NEEDS TO BE ADAPTED
    N = NRVT; % shorthand notation
    P = PRVT; % shorthand notation
end



% transistors: MnSf and MnCs
% MnSf is the source follower transistor
% MnCs is the current source transistor
disp('        VDD           ');
disp('         |            ');
disp('         |            ');
disp('IN--Rs--MnSf          ');
disp('         |----+-OUT   ');
disp(' BIAS---MnCs  |        ');
disp('         |    CL      ');
disp('         |    |       ');
disp('        GND  GND      ');

load 'constants.mat';
temperature = 300;

simulator = 'spectre'; % not relevant here
circuitName = 'sf';
circuitTitle = 'source follower with current source load';
transcriptFile = strcat(circuitName, '.txt');
global fid;
fid = 1;

simulFile = strcat(circuitName, '.scs'); % not relevant here
simulSkelFile = strcat(circuitName, '.scs'); % not relevant here


designkitName = 'umc65';

elementList.nmos = {'MnSf', 'MnCs'};
elementList.pmos = {}; 
elementList.cap = {'Cl'}; % load capacitance
elementList.v = {'Vdd', 'Vbias'};
elementlist.res = {'Rs'};



spec.Cl.val = 100e-15;

choice.Vdd.val = 1.1;
choice.Vbias.val = 0.45;
choice.Vin.val = 0.6;

choice.MnSf.lg = 100e-9;
choice.MnCs.lg = 100e-9;

choice.MnSf.vov = 0.1;
choice.MnSf.gm = 10e-3;

choice.Rs.val = 50;

% Initialization of the circuit
sf = cirInit('sf', circuitTitle, 'top', elementList, spec, choice, ...
    designkitName, N, P, simulator, simulFile,simulSkelFile);

cirPrintHeader(sf, fid, spec, choice);
sf = cirCheckInChoice(sf, choice);



%% Beginning of the sizing

MnSf.vgb = Vin.val;
MnSf.vsb = mosVsbBody(MnSf, MnSf.vgb, Vdd.val, MnSf.vov, 0.1);
fprintf(1, 'MnSf.vsb is %g\n', MnSf.vsb);
MnSf.vgs = MnSf.vgb - MnSf.vsb;
MnSf.vds = Vdd.val - MnSf.vsb;

MnSf.w = mosWidth('gm', MnSf.gm, MnSf);
MnSf.nFingers = floor(MnSf.w/1e-6);
MnSf = mosOpValues(MnSf);
mosCheckSaturation(MnSf);



MnCs.vds = MnSf.vsb;
MnCs.vsb = 0;
MnCs.vgs = Vbias.val;
MnCs.w = mosWidth('ids', MnSf.ids, MnCs);
MnCs.nFingers = floor(MnCs.w/1e-6);
MnCs = mosOpValues(MnCs);
mosCheckSaturation(MnCs);

Cl.val = spec.Cl.val;



gain = MnSf.gm/(MnSf.gm + MnSf.gmbs + MnSf.gds + MnCs.gds);

%transfer function:
%      a0 + a1*s
% = -----------------------
%    b0 + b1*s + b2*s^2
% see course notes for the coefficients

% first some shorthand notations:
Gs = 1/Rs.val; 
gm = MnSf.gm;
Cgs = MnSf.cgs;
Csb = MnSf.csb + Cl.val + MnCs.cdb + MnCs.cgd;
Cgd = MnSf.cgd + MnSf.cgb;
GE = MnSf.gds + MnSf.gmbs + MnCs.gds;

a0 = Gs*gm;
a1 = Gs*Cgs;
b0 = Gs*(GE + gm);
b1 = Cgs*Gs + Csb*Gs + Cgs*GE + Cgd*GE + Cgd*gm;
b2 = Csb*Cgs + Csb*Cgd + Cgd*Cgs;

% poles and zeros:
polesExact = roots([b2 b1 b0]);
zero = -a0/a1;
% approximate expression of the pole:
poleApprox = -(GE + gm)/(Csb + Cgs);

% plotting
% Initialization
fStart = 1;
fStop = 10e10;
nFreq = 500;
freq = logspace(log10(fStart), log10(fStop), nFreq); 
s = sqrt(-1)*2*pi*freq;
tfExact = polyval([a1 a0], s) ./ polyval([b2 b1 b0], s);

% 2: bodeplot of exact and approximate differential transfer function:
figNumber = 1;

figure(figNumber);
subplot(2,1,1), semilogx(freq, 20*log10(abs(tfExact)));
title('source follower: magnitude of exact TF');
xlabel('Frequency (Hz)');
ylabel('Gain (dB)');
grid on;
subplot(2,1,2), semilogx(freq, 180/pi*(imag(log(tfExact))));
title('Phase of exact TF');
xlabel('Frequency (Hz)');
ylabel('Phase (degrees)');
grid on;

sf = cirElementsCheckOut(sf);
mosPrintSizesAndOpInfo(1, sf);

