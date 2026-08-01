function dbm = dBm(P)
% DBM - conversion of power (in Watt) to dBm
%   
dbm=10*log10(P./1e-3);


