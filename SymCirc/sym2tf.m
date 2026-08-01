function H = sym2tf(Hsym)
%SYM2TF Turns a symbolic fraction in a single parameter into a TF
[N, D] = numden(Hsym);
Np = sym2poly(N);
Dp = sym2poly(D);
H  = tf(Np / Np(1), Dp / Np(1));
end

