function dbm = rms2dBm(rms)
% RMS2DBM - converts V rms of single tone sine wave to dBm
%   

dbm=10*log10(rms.*rms/50/1e-3);

