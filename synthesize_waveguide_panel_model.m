function result = synthesize_waveguide_panel_model(spec)
% Shared synthesis entry. The electromagnetic backend is selected by
% spec.solver: 'HFSS' or 'CST'. The aperture synthesis, taper, E-T feed
% topology, and slot geometry mapping stay identical across backends.
if nargin < 1
    error('Run run_full_antenna_model.m or pass a populated spec struct.');
end
if ~isfield(spec, 'output_dir')
    spec.output_dir = fullfile(pwd, 'output');
end
if ~exist(spec.output_dir, 'dir')
    mkdir(spec.output_dir);
end
if ~isfield(spec, 'solver') || isempty(spec.solver)
    spec.solver = 'HFSS';
end

arrayData = synthesis.spec_to_array(spec);
weights = synthesis.synthesize_weights(arrayData, spec);
conductance = synthesis.power_to_conductance(weights, arrayData);
arrayData = local_fit_radiating_height(spec, arrayData, conductance);

summary = local_build_summary(spec, arrayData, weights, conductance);

result = struct();
result.spec = spec;
result.array = arrayData;
result.weights = weights;
result.conductance = conductance;
result.summary = summary;

target = lower(spec.run.target);
solverName = upper(strtrim(char(spec.solver)));

switch solverName
    case 'HFSS'
        files = local_build_hfss_files(spec, arrayData, conductance, weights, target);
    case 'CST'
        files = local_build_cst_files(spec, arrayData, conductance, weights, target);
    otherwise
        error('未知仿真软件：%s。可选 HFSS 或 CST。', spec.solver);
end

if isfield(spec.run, 'save_design_mat') && spec.run.save_design_mat
    designMat = fullfile(spec.output_dir, 'design_snapshot.mat');
    save(designMat, 'spec', 'arrayData', 'weights', 'conductance');
    files.design_mat = designMat;
end

result.generated_files = files;
end

function files = local_build_hfss_files(spec, arrayData, conductance, weights, target)
files = struct();
switch target
    case 'radiating_slot_extract'
        files.radiating_slot_extract = hfssapi.build_radiating_slot_extract_model(spec, arrayData, conductance);
    case 'coupling_slot_extract'
        files.coupling_slot_extract = hfssapi.build_coupling_slot_extract_model(spec, arrayData, conductance);
    case 'branch_array'
        files.branch_array = hfssapi.build_branch_array_model(spec, arrayData, conductance, weights);
    case 'panel_topology'
        files.panel_topology = hfssapi.build_panel_topology_model(spec, arrayData, conductance, weights);
    case 'all'
        files.radiating_slot_extract = hfssapi.build_radiating_slot_extract_model(spec, arrayData, conductance);
        files.coupling_slot_extract = hfssapi.build_coupling_slot_extract_model(spec, arrayData, conductance);
        files.branch_array = hfssapi.build_branch_array_model(spec, arrayData, conductance, weights);
        files.panel_topology = hfssapi.build_panel_topology_model(spec, arrayData, conductance, weights);
    otherwise
        error('Unknown spec.run.target = %s', target);
end
end

function files = local_build_cst_files(spec, arrayData, conductance, weights, target)
files = struct();
switch target
    case 'panel_topology'
        files.panel_topology = cstapi.build_panel_topology_model(spec, arrayData, conductance, weights);
    case 'all'
        files.panel_topology = cstapi.build_panel_topology_model(spec, arrayData, conductance, weights);
    otherwise
        error('CST 版当前只支持完整天线 panel_topology。当前 target=%s。', target);
end
end

function summary = local_build_summary(spec, arrayData, weights, conductance)
summary = struct();
summary.solver = upper(strtrim(char(spec.solver)));
summary.f0_GHz = spec.f0_Hz / 1e9;
summary.radiating_waveguide = arrayData.waveguide.name;
summary.radiating_a_mm = arrayData.waveguide.a_mm;
summary.radiating_b_mm = arrayData.waveguide.b_mm;
summary.feeder_waveguide = arrayData.feeder_waveguide.name;
summary.feeder_a_mm = arrayData.feeder_waveguide.a_mm;
summary.feeder_b_mm = arrayData.feeder_waveguide.b_mm;
summary.Nx_branch = arrayData.Nx;
summary.Ny_slot = arrayData.Ny;
summary.branch_pitch_mm = arrayData.dx_mm;
summary.row_outer_pitch_mm = arrayData.row_outer_pitch_mm;
summary.slot_pitch_mm = arrayData.dy_mm;
summary.coupling_slot_pitch_mm = arrayData.coupling_slot_pitch_mm;
summary.feeder_slot_pitch_mm = arrayData.main_slot_pitch_mm;
summary.aperture_x_mm = arrayData.aperture_x_mm;
summary.aperture_y_mm = arrayData.aperture_y_mm;
summary.estimated_gain_dBi = arrayData.estimated_gain_dBi;
summary.sizing_mode = arrayData.sizing_mode;
summary.sizing_note = arrayData.sizing_note;
summary.weight_type_x = spec.synth_x.type;
summary.weight_type_y = spec.synth_y.type;
summary.weight_1d_x = weights.ax;
summary.weight_1d_y = weights.ay.';
summary.feed_pair_g = conductance.feed_pair_g;
summary.rad_pair_g = conductance.rad_pair_g;
if isfield(spec, 'feed') && isfield(spec.feed, 'junction_type')
    summary.feed_junction_type = spec.feed.junction_type;
end
if isfield(spec, 'feed') && isfield(spec.feed, 'et_phase_compensation')
    summary.feed_et_phase_compensation = spec.feed.et_phase_compensation;
end
if isfield(spec, 'coupling_slot') && isfield(spec.coupling_slot, 'design_mode')
    summary.coupling_slot_design_mode = spec.coupling_slot.design_mode;
end
if isfield(spec, 'coupling_slot') && isfield(spec.coupling_slot, 'fit_source')
    summary.coupling_slot_fit_source = spec.coupling_slot.fit_source;
end
if isfield(arrayData, 'radiating_height_fit')
    summary.radiating_height_fit = arrayData.radiating_height_fit;
end
summary.note = ['Coupling-first longitudinal design: choose the coupling guide, derive a(rad)=lambda_g(cpl)/2-wall, ', ...
    'derive lambda_g(rad), keep radiating-guide center pitch at a(rad)+wall=lambda_g(cpl)/2, ', ...
    'and map coupling-slot geometry through a dedicated fit-table interface rather than reusing the radiating-slot formula.'];
end

function arrayData = local_fit_radiating_height(spec, arrayData, conductance)
if ~utils.use_closed_form_mapping(spec)
    return;
end
if ~isfield(spec, 'radiating_waveguide') || ~isstruct(spec.radiating_waveguide)
    return;
end
radSpec = spec.radiating_waveguide;
if isfield(radSpec, 'b_mm') && ~isempty(radSpec.b_mm)
    return;
end
if ~isfield(radSpec, 'height_mode') || ~strcmpi(radSpec.height_mode, 'conductance_fit')
    return;
end

gReq = max(conductance.rad_pair_g(:));
if isempty(gReq) || gReq <= 0
    return;
end

lambda0 = arrayData.lambda0_mm;
lambdaG = arrayData.radiating_calc.lambda_g_mm;
a = arrayData.radiating_waveguide.a_mm;
shapeTerm = cos(0.464*pi*lambda0/lambdaG) - cos(0.464*pi);
gCoeffNoHeight = 2.09 * (lambdaG/lambda0) * a * shapeTerm^2;
gMaxNoHeight = 0.98 * gCoeffNoHeight;

margin = 1.05;
if isfield(radSpec, 'height_margin') && ~isempty(radSpec.height_margin)
    margin = radSpec.height_margin;
end
minB = 1.5 * spec.geometry.slot_width_mm;
if isfield(radSpec, 'min_b_mm') && ~isempty(radSpec.min_b_mm)
    minB = radSpec.min_b_mm;
end

bOld = arrayData.radiating_waveguide.b_mm;
bFromGMax = gMaxNoHeight / (margin * gReq);

slotWidth = spec.geometry.slot_width_mm;
offsetLimitRatio = 0.30;
if isfield(spec, 'mapping') && isfield(spec.mapping, 'max_offset_ratio') && ...
        ~isempty(spec.mapping.max_offset_ratio)
    offsetLimitRatio = spec.mapping.max_offset_ratio;
end
offsetLimit = min(offsetLimitRatio * a, max(0, 0.5*(a - slotWidth) - 0.25));
sinLimit = sin(pi * offsetLimit / a)^2;
bFromOffset = gCoeffNoHeight * sinLimit / (margin * gReq);

bTarget = min(bFromGMax, bFromOffset);
bNew = min(bOld, bTarget);
bNew = max(bNew, minB);

arrayData.radiating_waveguide.b_mm = bNew;
arrayData.waveguide.b_mm = bNew;
arrayData.radiating_calc = utils.waveguide_calc( ...
    arrayData.radiating_waveguide.a_mm, bNew, arrayData.f0_Hz);
arrayData.calc = arrayData.radiating_calc;

fit = struct();
fit.mode = 'conductance_fit';
fit.required_max_g = gReq;
fit.margin = margin;
fit.original_b_mm = bOld;
fit.fitted_b_mm = bNew;
fit.closed_form_gmax = gMaxNoHeight / bNew;
fit.offset_limit_mm = offsetLimit;
fit.closed_form_g_at_offset_limit = (gCoeffNoHeight / bNew) * sinLimit;
fit.saturated = fit.closed_form_gmax < gReq || ...
    fit.closed_form_g_at_offset_limit < gReq;
arrayData.radiating_height_fit = fit;
end
