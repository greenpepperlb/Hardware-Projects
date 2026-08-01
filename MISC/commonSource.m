% COMMON SOURCE AMPLIFIER
% using the 0.18um transistor from Chapter 1, slides 150-159
% we will analyze the transfer function, its poles and verify the accurarcy
% of the approximate expressions

% we define transistor M1 as a structure with several fields, similarly to
% what will be done in the lab sessions
% M1 will have the following fields:
% vds, vgs, vsb
% gm, gds, cgs, cgb, cdbE (extrinsic cdb), cdbI (intrinsic cdb), cdb (total
% cdb, i.e. cdb = cdbI + cdbE)
clear all;
VDD = 1.5;
M1.vds = 0.6; % see slide 150

% we choose RL from (VDD - VDS)/IDS
M1.ids = 0.12e-3; % see slide 153

RL = (VDD - M1.vds)/M1.ids;

% small-signal parameters:
M1.gm = 2e-3; % see slide 152
M1.gds = 80e-6; % see slide 154
% conductance at the output = 1/RL || M1.gds:
GLtot = 1/RL + M1.gds;

% parasitic capacitors:
M1.cgs = 20e-15; % see slide 155
M1.cgb = 4e-15 % see slide 155
M1.cgd = 8.79e-13 % see slide 155
CgsTot = M1.cgs + M1.cgb % combining the two parallel capacitors
M1.cdbI = 2.62e-18; % see slide 155
M1.cdbE = 8e-15; % see slide 157 top
M1.cdb = M1.cdbE + M1.cdbI;

% for the load capacitance we take a value equal to Cgs of M1, to mimic a
% subsequent amplifying stage
CL = M1.cgs;
CLtot = CL + M1.cdb % total capacitance between drain and GND

% for the output resistance of the voltage source we take 1/gds of M1
% as if the common source amplifier were driven by another common-source
% amplifier:
GS = M1.gds

% low-frequency voltage gain
Av = -M1.gm/GLtot

% coefficients of the transfer function:
a0 = -GS*M1.gm; % coeff. of zeroth power of s in numerator
a1 = GS*M1.cgd; % coeff. of first power of s in numerator
b0 = GLtot*GS;
b1 = CgsTot*GLtot + M1.cgd*M1.gm + M1.cgd*GLtot + CLtot*GS + M1.cgd*GS;
b2 = CLtot*CgsTot + M1.cgd*CgsTot + CLtot*M1.cgd;

% exact position of the poles (in rad/sec, not in Hz):
polesExact = roots([b2 b1 b0]);
% approximate expressions for large Cgd:
p1LargeCgd = -GS/(CgsTot + M1.cgd*(1-Av))
p2LargeCgd = -M1.gm*M1.cgd/(CLtot*CgsTot + M1.cgd*CgsTot + CLtot*M1.cgd)
% approximate expressions for small Cgd:

p1SmallCgd = -GS/CgsTot
p2SmallCgd = -GLtot/CLtot

disp('Approximate expressions (in rad/s)');
fprintf(1, 'For large Cgd: p2 = %g, p1 = %g\n', p2LargeCgd, p1LargeCgd);
fprintf(1, 'For small Cgd: p2 = %g, p1 = %g\n', p2SmallCgd, p1SmallCgd);
disp('Compare with exact values:');
fprintf(1, 'p2 = %g, p1 = %g\n', polesExact(1), polesExact(2));


