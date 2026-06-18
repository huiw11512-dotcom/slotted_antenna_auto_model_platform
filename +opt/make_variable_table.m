function vars = make_variable_table(spec, cfg)
%MAKE_VARIABLE_TABLE Create bounded optimization variables.
% Pair index 1 is the center-most symmetric pair; the index increases
% toward the aperture edge, matching synthesis.power_to_conductance.

if nargin < 2 || isempty(cfg)
    cfg = opt.default_config(spec);
end

Nx = spec.array.Nx;
Ny = spec.array.Ny;
nCpl = floor(Nx/2);
nRad = floor(Ny/2);
vars = struct('name', {}, 'target', {}, 'index', {}, 'x0', {}, 'lb', {}, 'ub', {}, 'description', {});
stage = lower(char(cfg.stage));

if any(strcmp(stage, {'matching', 'joint'}))
    for k = 1:nCpl
        vars(end+1) = local_var(sprintf('cpl_g_p%02d', k), 'coupling_g_pair_scale', k, ...
            1.0, 0.70, 1.30, 'Coupling-slot conductance mapping scale'); %#ok<AGROW>
    end
    vars(end+1) = local_var('cpl_len_scale', 'coupling_length_scale', 1, ...
        1.0, 0.92, 1.08, 'Global coupling-slot length scale');
    vars(end+1) = local_var('cpl_off_scale', 'coupling_offset_scale', 1, ...
        1.0, 0.75, 1.25, 'Global coupling-slot offset and branch-shift scale');
    vars(end+1) = local_var('feed_stem_trim_mm', 'feed_stem_trim_mm', 1, ...
        0.0, -3.0, 3.0, 'Input E-plane stem length trim in mm');
end

if any(strcmp(stage, {'sidelobe', 'joint'}))
    for k = 1:nRad
        vars(end+1) = local_var(sprintf('rad_g_p%02d', k), 'radiating_g_pair_scale', k, ...
            1.0, 0.75, 1.25, 'Radiating-slot conductance mapping scale'); %#ok<AGROW>
    end
    vars(end+1) = local_var('rad_len_scale', 'radiating_length_scale', 1, ...
        1.0, 0.94, 1.06, 'Global radiating-slot length scale');
    vars(end+1) = local_var('rad_off_scale', 'radiating_offset_scale', 1, ...
        1.0, 0.80, 1.20, 'Global radiating-slot offset scale');
end
end

function v = local_var(name, target, index, x0, lb, ub, description)
v = struct('name', name, 'target', target, 'index', index, ...
    'x0', x0, 'lb', lb, 'ub', ub, 'description', description);
end
