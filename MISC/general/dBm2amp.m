function amp = dBm2amp(dbm)
% DBM2AMP - convert dBm to V amplitude, assumes single tone sine wave
%   

amp=sqrt(2)*dBm2rms(dbm);
