%% Clean Plotting Section: MATLAB vs LTspice
% Extract MATLAB margins and crossover frequency
[Gm_mat, Pm_mat, Wcg_mat, Wcp_mat] = margin(TF1);
f_0dB_mat = Wcp_mat / (2*pi);

% Read LTspice data and extract margins
spice_tbl = read_LTspice_data("final_project_regular.txt");
mag_lt_lin = abs(spice_tbl.G1);
phase_lt_deg = unwrap(angle(spice_tbl.G1)) * 180/pi;
[Gm_lt, Pm_lt, Wcg_lt, Wcp_lt] = margin(mag_lt_lin, phase_lt_deg, 2*pi*spice_tbl.freq);
f_0dB_lt = Wcp_lt / (2*pi);

% Extract LTspice DC gain (gain at the lowest simulated frequency)
DC_gain_lt_dB = 20*log10(mag_lt_lin(1));

% Generate frequency vector for MATLAB Bode plot (to match LTspice range)
freq_mat = logspace(log10(min(spice_tbl.freq)), log10(max(spice_tbl.freq)), 1000);
[mag_mat_bode, phase_mat_bode] = bode(TF1, 2*pi*freq_mat);
mag_mat_bode = squeeze(mag_mat_bode);
phase_mat_bode = squeeze(phase_mat_bode);

% Extract MATLAB DC gain (gain at the lowest simulated frequency)
DC_gain_mat_dB = 20*log10(mag_mat_bode(1));

%% Figure 1: MATLAB Bode Plot
fig1 = figure('Name', 'MATLAB Frequency Response', 'Color', 'w');

% MATLAB Gain Plot
subplot(2, 1, 1);
semilogx(freq_mat, 20*log10(mag_mat_bode), 'b', 'LineWidth', 1.5);
grid on;
xlabel('Frequency (Hz)', 'FontWeight', 'bold');
ylabel('Gain (dB)', 'FontWeight', 'bold');
% Updated title to include MATLAB DC Gain
title(sprintf('MATLAB Frequency Response\nf_{GBW} = %.2f MHz | Phase Margin = %.1f° | DC Gain = %.1f dB', f_0dB_mat/1e6, Pm_mat, DC_gain_mat_dB), 'FontSize', 11);
xline(f_0dB_mat, 'k--', 'HandleVisibility', 'off'); % Marks the 0dB crossover
yline(0, 'k-', 'HandleVisibility', 'off');

% MATLAB Phase Plot
subplot(2, 1, 2);
semilogx(freq_mat, phase_mat_bode, 'b', 'LineWidth', 1.5);
grid on;
xlabel('Frequency (Hz)', 'FontWeight', 'bold');
ylabel('Phase (°)', 'FontWeight', 'bold');
xline(f_0dB_mat, 'k--', 'HandleVisibility', 'off');

%% Figure 2: LTspice Bode Plot
fig2 = figure('Name', 'Frequency Response', 'Color', 'w');

% LTspice Gain Plot
subplot(2, 1, 1);
semilogx(spice_tbl.freq, 20*log10(mag_lt_lin), 'r', 'LineWidth', 1.5);
grid on;
xlabel('Frequency (Hz)', 'FontWeight', 'bold');
ylabel('Gain (dB)', 'FontWeight', 'bold');
% Updated title to include LTspice DC Gain
title(sprintf('LT Spice frequency response ( with C and R) \nf_{GBW} = %.2f MHz | Phase Margin = %.1f° | DC Gain = %.1f dB', f_0dB_lt/1e6, Pm_lt, DC_gain_lt_dB), 'FontSize', 11);
xline(f_0dB_lt, 'k--', 'HandleVisibility', 'off'); % Marks the 0dB crossover
yline(0, 'k-', 'HandleVisibility', 'off');

% LTspice Phase Plot
subplot(2, 1, 2);
semilogx(spice_tbl.freq, phase_lt_deg, 'r', 'LineWidth', 1.5);
grid on;
xlabel('Frequency (Hz)', 'FontWeight', 'bold');
ylabel('Phase (°)', 'FontWeight', 'bold');
xline(f_0dB_lt, 'k--', 'HandleVisibility', 'off');

%% Figure 3: LTspice Output-Referred and input-Referred Noise Plot
% Bypass the custom function to avoid the 'Freq.' header error
noise_raw = readtable("final_project_noiseinput.txt");

% Extract frequency (Hz) from the 1st column, regardless of its name
freq_noise = noise_raw{:, 1};

% Extract noise voltage (V/sqrt(Hz)) from the 2nd column
v_noise = abs(noise_raw{:, 2}); 

% Calculate Noise Voltage Power Density (V^2 / Hz) by squaring the voltage
p_noise = v_noise.^2;

fig3 = figure('Name', 'LTspice Noise Power Density', 'Color', 'w');

% Plot using a log-log scale as requested
loglog(freq_noise, p_noise, 'g', 'LineWidth', 1.5);
grid on;
grid minor;
xlabel('Frequency (Hz)', 'FontWeight', 'bold');
ylabel('Noise Power Density (V^2/Hz)', 'FontWeight', 'bold');
title('Input-Referred Noise Power Density', 'FontSize', 11);
yticks([1e-18, 2e-18, 5e-18, 1e-17, 2e-17, 5e-17, 1e-16]);
% Ensure the x-axis matches your 1 kHz to 10 GHz simulation range
xlim([10e3 1e8]);

%% Export to High-Resolution PNG for Word
exportgraphics(fig1, 'MATLAB_Bode_Plot.png', 'Resolution', 300);
exportgraphics(fig2, 'LTspice_Bode_Plot_good.png', 'Resolution', 300);
exportgraphics(fig3, 'LTspice_Noise_Plot_input3.png', 'Resolution', 300);
disp('Successfully exported plots as MATLAB_Bode_Plot.png, LTspice_Bode_Plot.png, and LTspice_Noise_Plot.png');
%% --- EXTRACTION OF MISSING TABLE METRICS ---

% 1. Extract LTspice Dominant Pole (f_dom)
% The dominant pole is the frequency where the gain drops by 3 dB from its DC value.
% We use interp1 to find the exact frequency at (DC_gain_lt_dB - 3)
f_dom_lt = interp1(20*log10(mag_lt_lin), spice_tbl.freq, DC_gain_lt_dB - 3);
fprintf('LTspice Dominant Pole (f_dom): %.2f kHz\n', f_dom_lt / 1000);

% 2. Extract Total Integrated Output-Referred Noise (Vrms)
% Integrate the noise power density (p_noise in V^2/Hz) over the frequency range (freq_noise)
total_noise_power = trapz(freq_noise, p_noise); 
v_out_eq_rms = sqrt(total_noise_power);
fprintf('LTspice Output-Referred Noise: %.4e Vrms\n', v_out_eq_rms);

% (Optional) Theoretical check for f_dom based on GBW and linear DC gain
% f_dom_approx = f_0dB_lt / mag_lt_lin(1);