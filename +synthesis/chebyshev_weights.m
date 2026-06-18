function w = chebyshev_weights(N, sll_dB)
% Toolbox-free Dolph-Chebyshev window approximation based on FFT form.
% Returns a symmetric positive row vector normalized to max=1.

if N == 1
    w = 1;
    return;
end

M = N - 1;
R = 10^(abs(sll_dB)/20);
beta = cosh(acosh(R)/M);
k = 0:(N-1);
x = beta * cos(pi*k/N);
p = zeros(1,N);

ix1 = x > 1;
ix2 = x < -1;
ix3 = ~ix1 & ~ix2;
p(ix1) = cosh(M * acosh(x(ix1)));
p(ix3) = cos(M * acos(x(ix3)));
if any(ix2)
    sgn = 2*mod(N,2) - 1;  % +1 odd, -1 even
    p(ix2) = sgn * cosh(M * acosh(-x(ix2)));
end

if mod(N,2)==1
    W = real(fft(p));
    n = (N+1)/2;
    w = [W(n:-1:2), W(1:n)];
else
    p = p .* exp(1j*pi*(0:N-1)/N);
    W = real(fft(p));
    n = N/2 + 1;
    w = [W(n:-1:2), W(1:n-1)];
end

w = abs(w);
w = w / max(w);
end
