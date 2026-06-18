function array = spec_to_array(spec)
% Convert user specifications to an initial panel size and waveguide choice.

c0 = utils.constants().c0;
lambda0 = c0 / spec.f0_Hz;

wgCpl = utils.recommend_waveguide(spec.waveguide, spec.f0_Hz);
calcCpl = utils.waveguide_calc(wgCpl.a_mm, wgCpl.b_mm, spec.f0_Hz);

eta = spec.efficiency;
Glin = 10.^(spec.gain_dBi/10);
Areq_m2 = Glin * lambda0^2 / (4*pi*eta);

% Longitudinal-coupling baseline:
% 1) choose the coupling/feed guide
% 2) derive the radiating-guide broad wall from a_rad = lambda_g(cpl)/2 - t
% 3) derive lambda_g(rad) from that radiating guide
% 4) the coupling-slot and radiating-slot chains each use their own lambda_g/2
wall_mm = 0.0;
if isfield(spec, 'geometry') && isfield(spec.geometry, 'wall_mm') && ~isempty(spec.geometry.wall_mm)
    wall_mm = spec.geometry.wall_mm;
end

[wgRad, calcRad] = local_resolve_radiating_waveguide(spec, wgCpl, calcCpl, wall_mm);
cplSlotPitch_mm = 0.5 * calcCpl.lambda_g_mm;
dy_mm = 0.5 * calcRad.lambda_g_mm;
rowOuterPitch_mm = wgRad.a_mm + wall_mm;
dx_mm = rowOuterPitch_mm;

useFixedSize = isfield(spec, 'array') && isstruct(spec.array) && ...
    isfield(spec.array, 'mode') && strcmpi(spec.array.mode, 'fixed');

if useFixedSize
    assert(isfield(spec.array, 'Nx') && isfield(spec.array, 'Ny'), ...
        'spec.array.mode=''fixed'' requires spec.array.Nx and spec.array.Ny.');
    Nx = round(spec.array.Nx);
    Ny = round(spec.array.Ny);
    assert(Nx > 0 && Ny > 0, 'spec.array.Nx and spec.array.Ny must be positive integers.');
    assert(mod(Nx, 2) == 0 && mod(Ny, 2) == 0, ...
        'Fixed Nx/Ny must be even for the symmetric center-fed topology.');
    sizingMode = 'fixed';
    sizingNote = sprintf('Fixed development array size: %dx%d.', Nx, Ny);
else
    aperture_ratio = spec.aperture_aspect_ratio;
    Nx = ceil(sqrt((Areq_m2 * aperture_ratio) / ((dx_mm*1e-3)*(dy_mm*1e-3))));
    Ny = ceil(Areq_m2 / ((Nx*dx_mm*1e-3)*(dy_mm*1e-3)));

    % enforce even counts for symmetric center-fed layout
    Nx = Nx + mod(Nx,2);
    Ny = Ny + mod(Ny,2);
    sizingMode = 'auto';
    sizingNote = sprintf('Auto-sized from %.1f dBi target gain.', spec.gain_dBi);
end


aperture_x_mm = Ny * dy_mm;
aperture_y_mm = (Nx - 1) * dx_mm + wgRad.a_mm;
Aest_m2 = (aperture_x_mm*1e-3) * (aperture_y_mm*1e-3);
Gest_dBi = 10*log10(eta * 4*pi*Aest_m2 / lambda0^2);

array = struct();
array.lambda0_mm = lambda0 * 1e3;
array.f0_Hz = spec.f0_Hz;
array.waveguide = wgRad;
array.calc = calcRad;
array.radiating_waveguide = wgRad;
array.radiating_calc = calcRad;
array.feeder_waveguide = wgCpl;
array.feeder_calc = calcCpl;
array.coupling_waveguide = wgCpl;
array.coupling_calc = calcCpl;
array.Nx = Nx;
array.Ny = Ny;
array.dx_mm = dx_mm;
array.dy_mm = dy_mm;
array.row_outer_pitch_mm = rowOuterPitch_mm;
array.coupling_slot_pitch_mm = cplSlotPitch_mm;
array.main_slot_pitch_mm = cplSlotPitch_mm;
array.row_center_pitch_mm = dx_mm;
array.branch_pitch_note = sprintf(['Derived radiating guide uses a(rad)=lambda_g(cpl)/2-wall = %.3f mm; ', ...
    'coupling-slot pitch = %.3f mm; radiating-row center pitch = %.3f mm.'], ...
    wgRad.a_mm, cplSlotPitch_mm, dx_mm);
array.aperture_x_mm = aperture_x_mm;
array.aperture_y_mm = aperture_y_mm;
array.Areq_m2 = Areq_m2;
array.estimated_gain_dBi = Gest_dBi;
array.t_mm = wgRad.t_mm;
array.sizing_mode = sizingMode;
array.sizing_note = sizingNote;
end

function [wgRad, calcRad] = local_resolve_radiating_waveguide(spec, wgCpl, calcCpl, wall_mm)
if isfield(spec, 'radiating_waveguide') && isstruct(spec.radiating_waveguide)
    radSpec = spec.radiating_waveguide;
else
    radSpec = struct();
end

mode = 'derived_from_coupling';
if isfield(radSpec, 'mode') && ~isempty(radSpec.mode)
    mode = lower(radSpec.mode);
end

default_t = wgCpl.t_mm;
if isfield(radSpec, 't_mm') && ~isempty(radSpec.t_mm)
    default_t = radSpec.t_mm;
end

switch mode
    case {'derived_from_coupling', 'coupling_chain', 'literature_longitudinal'}
        aRad_mm = 0.5 * calcCpl.lambda_g_mm - wall_mm;
        lambda0_mm = calcCpl.lambda0_mm;
        assert(aRad_mm > 0, ...
            'Derived radiating-guide broad wall %.3f mm must be positive.', aRad_mm);
        assert(aRad_mm > 0.5 * lambda0_mm, ...
            ['Derived radiating-guide broad wall %.3f mm is below TE10 cutoff at %.3f GHz. ', ...
             'Need a(rad) > lambda0/2 = %.3f mm.'], ...
            aRad_mm, spec.f0_Hz/1e9, 0.5 * lambda0_mm);
        bOverA = 0.5;
        if isfield(radSpec, 'b_over_a') && ~isempty(radSpec.b_over_a)
            bOverA = radSpec.b_over_a;
        end
        bRad_mm = bOverA * aRad_mm;
        if isfield(radSpec, 'b_mm') && ~isempty(radSpec.b_mm)
            bRad_mm = radSpec.b_mm;
        end
        wgRad = struct();
        wgRad.name = 'DERIVED_FROM_COUPLING';
        wgRad.a_mm = aRad_mm;
        wgRad.b_mm = bRad_mm;
        wgRad.t_mm = default_t;
        wgRad.f_low_GHz = NaN;
        wgRad.f_high_GHz = NaN;
        wgRad.selection_note = sprintf(['Radiating guide derived from coupling guide via ', ...
            'a(rad)=lambda_g(cpl)/2-wall = %.3f mm.'], aRad_mm);
    case {'auto', 'standard', 'custom'}
        wgRad = utils.recommend_waveguide(radSpec, spec.f0_Hz);
        if ~isfield(wgRad, 't_mm') || isempty(wgRad.t_mm)
            wgRad.t_mm = default_t;
        end
    otherwise
        error('Unknown radiating waveguide mode: %s', mode);
end

calcRad = utils.waveguide_calc(wgRad.a_mm, wgRad.b_mm, spec.f0_Hz);
end
