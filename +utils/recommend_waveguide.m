function wg = recommend_waveguide(wgSpec, f0_Hz)
% Pick waveguide from auto / standard / custom settings.
% Auto mode prefers the guide whose recommended band center is nearest f0,
% with a penalty for being too close to the band edges.

db = utils.waveguide_db();
fGHz = f0_Hz / 1e9;
mode = lower(wgSpec.mode);

default_t = 1.0;
if isfield(wgSpec, 't_mm')
    default_t = wgSpec.t_mm;
end

switch mode
    case 'auto'
        centers = arrayfun(@(x) 0.5*(x.f_low_GHz + x.f_high_GHz), db);
        spans = arrayfun(@(x) (x.f_high_GHz - x.f_low_GHz), db);
        inBand = arrayfun(@(x) fGHz >= x.f_low_GHz && fGHz <= x.f_high_GHz, db);
        score = abs(centers - fGHz) ./ max(spans, eps);
        edgePenalty = zeros(size(score));
        for k = 1:numel(db)
            margin = min(fGHz - db(k).f_low_GHz, db(k).f_high_GHz - fGHz);
            if inBand(k)
                edgePenalty(k) = 0.15 * (1 - max(margin,0) / max(0.5*spans(k), eps));
            else
                edgePenalty(k) = 2 + min(abs(fGHz-db(k).f_low_GHz), abs(fGHz-db(k).f_high_GHz));
            end
        end
        score = score + edgePenalty;
        [~, idx] = min(score);
        wg = db(idx);
        wg.t_mm = default_t;
        wg.selection_note = sprintf('Auto-selected %s for %.3f GHz (recommended %.2f-%.2f GHz).', ...
            wg.name, fGHz, wg.f_low_GHz, wg.f_high_GHz);
    case 'standard'
        names = {db.name};
        idx = find(strcmpi(names, wgSpec.name), 1, 'first');
        assert(~isempty(idx), 'Unknown standard waveguide: %s', wgSpec.name);
        wg = db(idx);
        wg.t_mm = default_t;
        wg.selection_note = sprintf('User-selected standard waveguide %s.', wg.name);
    case 'custom'
        wg = struct();
        wg.name = 'CUSTOM';
        wg.a_mm = wgSpec.a_mm;
        wg.b_mm = wgSpec.b_mm;
        wg.t_mm = default_t;
        wg.f_low_GHz = NaN;
        wg.f_high_GHz = NaN;
        wg.selection_note = 'User-defined rectangular waveguide dimensions.';
    otherwise
        error('Unknown waveguide mode: %s', wgSpec.mode);
end
end
