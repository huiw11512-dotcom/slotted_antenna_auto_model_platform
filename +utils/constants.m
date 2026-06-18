function C = constants()
C = struct();
C.c0 = 299792458;
C.mu0 = 4*pi*1e-7;
C.eps0 = 1/(C.mu0*C.c0^2);
end
