%%  OpAmp Characterization Plots 
% Laurent Béguelin 
clc; close all; clear;

addpath(genpath('circuitDesign'));
addpath(genpath('models'));
load('UMC65_RVT.mat');

%% Initialization
designkitName = 'umc65';
circuitTitle  = 'Analog Design - OTA';
elementList.nmos = {'Mn1'};
elementList.pmos = {'Mp2'};

choice.maxFingerWidth = 10e-6;
choice.minFingerWidth = 200e-9;
choice.Mn1.vsb = 0; choice.Mn1.w = 10e-6;
choice.Mp2.vsb = 0; choice.Mp2.w = 10e-6;

spec = []; simulator = 'spectre'; simulFile = 0; simulSkelFile = 0;
analog = cirInit('analog', circuitTitle, 'top', elementList, spec, choice, ...
    designkitName, NRVT, PRVT, simulator, simulFile, simulSkelFile);
analog = cirCheckInChoice(analog, choice);

%% Sweep Setup
VGS = linspace(0, 1.1, 201);
L   = [60e-9, 80e-9, 100e-9, 125e-9, 200e-9, 300e-9, 500e-9, 1000e-9]; % Standard L sweeps
nL  = numel(L);
nV  = numel(VGS);

gmId_nmos  = nan(nV, nL); gmGds_nmos = nan(nV, nL); vth_nmos = nan(nV, nL);
gmId_pmos  = nan(nV, nL); gmGds_pmos = nan(nV, nL); vth_pmos = nan(nV, nL);

for i = 1:nL
    for j = 2:nV
        % NMOS (VDS = 0.55V, W/L = 10)
        Mn1.w   = 10 * L(i);       
        Mn1.lg  = L(i); 
        Mn1.vgs = VGS(j); 
        Mn1.vds = 0.25;
        Mn1 = mosNfingers(Mn1); 
        Mn1 = mosOpValues(Mn1);
        
        gmId_nmos(j,i)  = Mn1.gm / Mn1.ids;
        gmGds_nmos(j,i) = Mn1.gm / Mn1.gds;
        vth_nmos(j,i)   = Mn1.vth;
        
        % PMOS (VDS = -0.55V, W/L = 10)
        Mp2.w   = 10 * L(i);       
        Mp2.lg  = L(i); 
        Mp2.vgs = -VGS(j); 
        Mp2.vds = -0.25;
        Mp2 = mosNfingers(Mp2); 
        Mp2 = mosOpValues(Mp2);
        
        gmId_pmos(j,i)  = Mp2.gm / Mp2.ids;
        gmGds_pmos(j,i) = Mp2.gm / Mp2.gds;
        vth_pmos(j,i)   = Mp2.vth;
    end
end

VOV_nmos = VGS.' - vth_nmos;
VOV_pmos = -VGS.' - vth_pmos;

outDir = fullfile(pwd, 'report_figures');
if ~exist(outDir, 'dir'), mkdir(outDir); end

legStr = arrayfun(@(x) sprintf('L = %d nm', x*1e9), L, 'UniformOutput', false);

%% Figure 1: NMOS gm/gds vs VOV
f1 = figure('Color','w');
plot(VOV_nmos, gmGds_nmos, 'LineWidth', 1.8); grid on;
xlabel('V_{OV} (V)'); ylabel('g_m / g_{ds} (-)');
title('Figure 1: NMOS Intrinsic Gain (g_m/g_{ds}) vs V_{OV} (W/L=10, |V_{DS}|=0.55V)'); 
legend(legStr, 'Location', 'best');
exportgraphics(f1, fullfile(outDir, 'Figure1_NMOS_gmGds_vs_VOV.png'), 'Resolution', 300);

%% Figure 2: NMOS gm/gds vs VGS
f2 = figure('Color','w');
plot(VGS, gmGds_nmos, 'LineWidth', 1.8); grid on;
xlabel('V_{GS} (V)'); ylabel('g_m / g_{ds} (-)');
title('Figure 2: NMOS Intrinsic Gain (g_m/g_{ds}) vs V_{GS} (W/L=10, |V_{DS}|=0.55V)');
legend(legStr, 'Location', 'best');
exportgraphics(f2, fullfile(outDir, 'Figure2_NMOS_gmGds_vs_VGS.png'), 'Resolution', 300);


%% Figure 3: PMOS gm/gds vs VOV
f3 = figure('Color','w');
plot(VOV_pmos, gmGds_pmos, 'LineWidth', 1.8); grid on;
xlabel('V_{OV} (V)'); ylabel('g_m / g_{ds} (-)');
title('Figure 3: PMOS Intrinsic Gain (g_m/g_{ds}) vs V_{OV} (W/L=10, |V_{DS}|=0.55V)'); 
legend(legStr, 'Location', 'best');
exportgraphics(f3, fullfile(outDir, 'Figure3_PMOS_gmGds_vs_VOV.png'), 'Resolution', 300);

%% Figure 4: PMOS gm/gds vs VGS
f4 = figure('Color','w');
plot(-VGS, gmGds_pmos, 'LineWidth', 1.8); grid on;
xlabel('V_{GS} (V)'); ylabel('g_m / g_{ds} (-)');
title('Figure 4: PMOS Intrinsic Gain (g_m/g_{ds}) vs V_{GS} (W/L=10, |V_{DS}|=0.55V)');
legend(legStr, 'Location', 'best');
exportgraphics(f4, fullfile(outDir, 'Figure4_PMOS_gmGds_vs_VGS.png'), 'Resolution', 300);

%% Figure 5: PMOS gm/ID vs VOV
f5 = figure('Color','w');
plot(VOV_pmos, gmId_pmos, 'LineWidth', 1.8); grid on;
xlabel('V_{OV} (V)'); ylabel('g_m / I_D (S/A)');
title('Figure 5: PMOS Transconductance Efficiency (g_m/I_D) vs V_{OV} (W/L=10, |V_{DS}|=0.55V)'); 
legend(legStr, 'Location', 'best');
exportgraphics(f5, fullfile(outDir, 'Figure5_PMOS_gmID_vs_VOV.png'), 'Resolution', 300);
disp('Done! Figures 1-5 generated in report_figures/');

%% Figure 6: NMOS gm/ID vs VOV (For your own hand calculations)
f6 = figure('Color','w');
plot(VOV_nmos, gmId_nmos, 'LineWidth', 1.8); grid on;
xlabel('V_{OV} (V)'); ylabel('g_m / I_D (S/A)');
title('Figure 6: NMOS Transconductance Efficiency (g_m/I_D) vs V_{OV} (W/L=10, |V_{DS}|=0.55V)'); 
legend(legStr, 'Location', 'best');
exportgraphics(f6, fullfile(outDir, 'Figure6_NMOS_gmID_vs_VOV.png'), 'Resolution', 300);
%% Figure 7: NMOS gm/ID vs VGS
f7 = figure('Color','w');
plot(VGS, gmId_nmos, 'LineWidth', 1.8); grid on;
xlabel('V_{GS} (V)'); ylabel('g_m / I_D (S/A)');
title('Figure 7: NMOS Transconductance Efficiency (g_m/I_D) vs V_{GS} (W/L=10, |V_{DS}|=0.55V)');
legend(legStr, 'Location', 'best');
exportgraphics(f7, fullfile(outDir, 'Figure7_NMOS_gmID_vs_VGS.png'), 'Resolution', 300);
%% Figure 8: PMOS gm/gds vs VOV ( VDS =-0.25V)
f8 = figure('Color','w');
plot(VOV_pmos, gmGds_pmos, 'LineWidth', 1.8); grid on;
xlabel('V_{OV} (V)'); ylabel('g_m / g_{ds} (-)');
title('Figure 8: PMOS Intrinsic Gain (g_m/g_{ds}) vs V_{OV} (W/L=10, |V_{DS}|=0.25V)'); 
legend(legStr, 'Location', 'best');
exportgraphics(f8, fullfile(outDir, 'Figure8_PMOS_gmGds_vs_VOV.png'), 'Resolution', 300);
%% Figure 9: PMOS gm/ID vs VOV (VDS= -0.25)
f9 = figure('Color','w');
plot(VOV_pmos, gmId_pmos, 'LineWidth', 1.8); grid on;
xlabel('V_{OV} (V)'); ylabel('g_m / I_D (S/A)');
title('Figure 9: PMOS Transconductance Efficiency (g_m/I_D) vs V_{OV} (W/L=10, |V_{DS}|=0.25V)'); 
legend(legStr, 'Location', 'best');
exportgraphics(f9, fullfile(outDir, 'Figure9_PMOS_gmID_vs_VOV.png'), 'Resolution', 300);
%% Figure 10: PMOS gm/gds vs VGS (VDS = -0.25)
f4 = figure('Color','w');
plot(-VGS, gmGds_pmos, 'LineWidth', 1.8); grid on;
xlabel('V_{GS} (V)'); ylabel('g_m / g_{ds} (-)');
title('Figure 10: PMOS Intrinsic Gain (g_m/g_{ds}) vs V_{GS} (W/L=10, |V_{DS}|=0.25V)');
legend(legStr, 'Location', 'best');
exportgraphics(f4, fullfile(outDir, 'Figure10_PMOS_gmGds_vs_VGS.png'), 'Resolution', 300);
