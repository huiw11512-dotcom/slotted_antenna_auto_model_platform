function calc = waveguide_calc(a_mm, b_mm, f0_Hz)
C = utils.constants();
a = a_mm * 1e-3;
b = b_mm * 1e-3;
f = f0_Hz;

lambda0 = C.c0 / f;
fc10 = C.c0 / (2*a);
fc20 = C.c0 / a;

assert(f > fc10, 'Operating frequency is below TE10 cutoff.');

lambda_g = lambda0 / sqrt(1 - (fc10/f)^2);

calc = struct();
calc.lambda0_mm = lambda0 * 1e3;
calc.lambda_g_mm = lambda_g * 1e3;
calc.fc10_GHz = fc10 / 1e9;
calc.fc20_GHz = fc20 / 1e9;
calc.single_mode_note = sprintf('TE10 cutoff %.3f GHz, TE20 cutoff %.3f GHz', calc.fc10_GHz, calc.fc20_GHz);
calc.a_mm = a_mm;
calc.b_mm = b_mm;
end
