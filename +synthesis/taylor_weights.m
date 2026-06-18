function w = taylor_weights(N, nbar, sll_dB)
% Taylor line-source taper, toolbox-free.
% Returns a symmetric positive row vector normalized to max=1.

if N == 1
    w = 1;
    return;
end

A = acosh(10^(abs(sll_dB)/20)) / pi;
s2 = nbar^2 / (A^2 + (nbar - 0.5)^2);
Fm = zeros(1, nbar-1);

for m = 1:(nbar-1)
    num = 1;
    den = 1;
    for n = 1:(nbar-1)
        num = num * (1 - (m^2) / (s2 * (A^2 + (n - 0.5)^2)));
        if n ~= m
            den = den * (1 - (m^2)/(n^2));
        end
    end
    Fm(m) = ((-1)^(m+1) / 2) * (num / den);
end

x = ((0:N-1) - (N-1)/2) / N;
w = ones(1,N);
for m = 1:(nbar-1)
    w = w + 2 * Fm(m) * cos(2*pi*m*x);
end
w = real(w);
w = max(w, 0);
if max(w) == 0
    w = ones(1,N);
end
w = w / max(w);
end
