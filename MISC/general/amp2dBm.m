function dbm = amp2dBm(amp)
% AMP2DBM - converts amplitude of single tone sine wave to dBm
%   
dbm=rms2dBm(amp/sqrt(2));
