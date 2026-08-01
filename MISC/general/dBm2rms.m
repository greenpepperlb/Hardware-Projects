function rms = dBm2rms(dbm)
% DBM2RMS - convert dBm to V rms
%   

rms=sqrt(1e-3.*50.*10.^(dbm/10));
