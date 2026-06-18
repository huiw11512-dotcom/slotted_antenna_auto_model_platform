function weights = synthesize_weights(array, spec)
% Build 2D separable amplitude taper.

ax = local_build_1d(array.Nx, spec.synth_x);
ay = local_build_1d(array.Ny, spec.synth_y);

ax = ax(:).' / max(ax);
ay = ay(:)   / max(ay);
Wamp = ay * ax;
Wamp = Wamp / max(Wamp(:));
Wpow = Wamp.^2;
Wpow = Wpow / sum(Wpow(:));

weights = struct();
weights.ax = ax;
weights.ay = ay;
weights.Wamp = Wamp;
weights.Wpow = Wpow;
end

function w = local_build_1d(N, cfg)
type = lower(cfg.type);
sll = abs(cfg.sll_dB);
nbar = cfg.nbar;
switch type
    case {'uniform', 'flat'}
        w = ones(1, N);
    case {'cheb', 'chebyshev', 'dolph-chebyshev'}
        w = synthesis.chebyshev_weights(N, sll);
    case 'taylor'
        % Small development arrays cannot support arbitrarily large nbar.
        nbar = max(1, min(nbar, N-1));
        w = synthesis.taylor_weights(N, nbar, sll);
    otherwise
        error('Unknown taper type: %s', cfg.type);
end
end
