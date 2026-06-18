function info = build_panel_topology_model(spec, arrayData, conductance, ~)
% Panel topology model for the two-layer longitudinal-coupling subarray.
% A selectable feed junction feeds the lower guide, splits up/down, and each
% complete radiating guide is fed by one longitudinal coupling slot.

[fid, vbsPath, projectPath] = hfssapi.open_script(spec, 'panel_topology');

wgRad = arrayData.radiating_waveguide;
calcRad = arrayData.radiating_calc;
wgCpl = arrayData.coupling_waveguide;
calcCpl = arrayData.coupling_calc;
lambda0 = arrayData.lambda0_mm;
lambda_g_rad = calcRad.lambda_g_mm;
lambda_g_cpl = calcCpl.lambda_g_mm;
aRad = wgRad.a_mm;
bRad = wgRad.b_mm;
aCpl = wgCpl.a_mm;
bCpl = wgCpl.b_mm;
wall = spec.geometry.wall_mm;
shellMargin = local_get_geom_value(spec.geometry, 'outer_shell_margin_mm', wall);
setupName = hfssapi.get_setup_name(spec);
closedForm = utils.use_closed_form_mapping(spec);
feedPhase = local_feed_phase_config(spec);
usePhysicalET = strcmpi(feedPhase.junction_type, 'E_T');

Nx = arrayData.Nx;   % radiating-guide count
Ny = arrayData.Ny;   % radiating-slot count per guide

rowPitch = arrayData.row_outer_pitch_mm;  % a_rad + wall = lambda_g_cpl/2
radPitch = 0.5 * lambda_g_rad;
cplPitch = arrayData.coupling_slot_pitch_mm;
radBackshort = 0.25 * lambda_g_rad;
cplBackshort = 0.25 * lambda_g_cpl;

rowY = ((1:Nx) - (Nx+1)/2) * rowPitch;
slotX = ((1:Ny) - (Ny+1)/2) * radPitch;
maxBranchShift = local_estimate_max_branch_shift(arrayData, conductance, spec);

if closedForm
    branchLen = (Ny - 1) * radPitch + 2.0 * radBackshort;
    feedLen = (Nx - 1) * rowPitch + 2.0 * cplBackshort;
else
    branchLen = (Ny - 1) * radPitch + 2.0 * radBackshort + ...
        2.0 * spec.geometry.branch_margin_lambda0 * lambda0;
    feedLen = (Nx - 1) * rowPitch + 2.0 * cplBackshort + ...
        2.0 * spec.geometry.main_margin_lambda0 * lambda0;
end
stemLen = spec.geometry.feed_stem_length_mm + local_opt_scalar(spec, 'feed_stem_trim_mm', 0);

% Layer stack: lower coupling/feed guide, upper radiating guides.
z0 = 0;
z1 = wall;
z2 = z1 + bCpl;
z3 = z2 + wall;
z4 = z3 + bRad;
z5 = z4 + wall;

radPanelXMin = -branchLen/2 - maxBranchShift - shellMargin;
radPanelXMax = branchLen/2 + maxBranchShift + shellMargin;
radPanelYMin = min(rowY) - aRad/2 - shellMargin;
radPanelYMax = max(rowY) + aRad/2 + shellMargin;

feedPanelXMin = -aCpl/2 - shellMargin;
if usePhysicalET
    feedPanelXMax = aCpl/2 + shellMargin;
else
    feedPanelXMax = aCpl/2 + stemLen + shellMargin;
end
feedPanelYMin = -feedLen/2 - shellMargin;
feedPanelYMax = feedLen/2 + shellMargin;

xMin = min([radPanelXMin, feedPanelXMin]);
xMax = max([radPanelXMax, feedPanelXMax]);
yMin = min([radPanelYMin, feedPanelYMin]);
yMax = max([radPanelYMax, feedPanelYMax]);
if usePhysicalET
    panelZMin = -stemLen - wall;
else
    panelZMin = z0;
end

param = local_define_panel_variables(fid, spec, arrayData, conductance, ...
    Nx, Ny, aCpl, bCpl, aRad, bRad, wall, lambda0, lambda_g_cpl, lambda_g_rad, ...
    rowPitch, radPitch, cplPitch, branchLen, feedLen, stemLen, rowY, slotX, ...
    z0, z1, z2, z3, z4, z5, ...
    radPanelXMin, radPanelXMax, radPanelYMin, radPanelYMax, ...
    feedPanelXMin, feedPanelXMax, feedPanelYMin, feedPanelYMax, ...
    xMin, xMax, yMin, yMax, panelZMin);

% Build the outer PEC envelope first, then subtract all cavities from the
% united solid. Subtracting before Unite can refill cavity intersections at
% the T junction because overlapping shell walls become metal again.
if usePhysicalET
    % E-plane tee: input guide propagates in Z and enters the feed guide at
    % its center. The two Y arms are 180 deg apart, compensated by flipping
    % one side of the radiating-slot offset sequence.
    hfssBox(fid, 'panelMetal', ...
        {'(-cpl_a/2-wall)', '(-cpl_b/2-wall)', '(-stem_len-wall)'}, ...
        {'(cpl_a + 2*wall)', '(cpl_b + 2*wall)', '(stem_len + cpl_b + 3*wall)'}, ...
        'mm');
else
    % H-plane tee / side input retained as a selectable reference topology.
    hfssBox(fid, 'panelMetal', ...
        {'(-wall)', '(-cpl_a/2-wall)', '0mm'}, ...
        {'(stem_len + cpl_a/2 + 2*wall)', '(cpl_a + 2*wall)', '(cpl_b + 2*wall)'}, ...
        'mm');
end

hfssBox(fid, 'feedUpperGuide', ...
    {'(-cpl_a/2-wall)', '(-wall)', '0mm'}, ...
    {'(cpl_a + 2*wall)', '(feed_len/2 + 2*wall)', '(cpl_b + 2*wall)'}, ...
    'mm');
hfssUnite(fid, 'panelMetal', 'feedUpperGuide');

hfssBox(fid, 'feedLowerGuide', ...
    {'(-cpl_a/2-wall)', '(-feed_len/2-wall)', '0mm'}, ...
    {'(cpl_a + 2*wall)', '(feed_len/2 + 2*wall)', '(cpl_b + 2*wall)'}, ...
    'mm');
hfssUnite(fid, 'panelMetal', 'feedLowerGuide');

% Upper complete radiating-guide outer envelopes.
for ix = 1:Nx
    shellName = sprintf('branchGuide_%02d', ix);
    hfssBox(fid, shellName, ...
        {sprintf('(((-branch_len/2)+(%s))-wall)', param.branch_shift{ix}), ...
         sprintf('((%s)-(rad_a/2)-wall)', param.row_y{ix}), ...
         'z2'}, ...
        {'(branch_len + 2*wall)', '(rad_a + 2*wall)', '(rad_b + 2*wall)'}, ...
        'mm');
    hfssUnite(fid, 'panelMetal', shellName);
end
hfssAssignMaterial(fid, 'panelMetal', 'pec');

% Now remove all real cavities from the single united PEC body. This keeps
% the T junction, input feed, and upper/lower feed halves continuously open.
if usePhysicalET
    hfssapi.add_slot_cutout(fid, 'feedInputCavity', ...
        {'(-cpl_a/2)', '(-cpl_b/2)', '(-stem_len)'}, ...
        {'cpl_a', 'cpl_b', '(stem_len + cpl_b + wall)'});
    hfssSubtract(fid, 'panelMetal', 'feedInputCavity');
else
    hfssapi.add_slot_cutout(fid, 'feedStemCavity', {'0mm', '(-cpl_a/2)', 'z1'}, ...
        {'(stem_len + cpl_a/2)', 'cpl_a', 'cpl_b'});
    hfssSubtract(fid, 'panelMetal', 'feedStemCavity');
end

hfssapi.add_slot_cutout(fid, 'feedUpperCavity', {'(-cpl_a/2)', '0mm', 'z1'}, ...
    {'cpl_a', '(feed_len/2)', 'cpl_b'});
hfssSubtract(fid, 'panelMetal', 'feedUpperCavity');

hfssapi.add_slot_cutout(fid, 'feedLowerCavity', {'(-cpl_a/2)', '(-feed_len/2)', 'z1'}, ...
    {'cpl_a', '(feed_len/2)', 'cpl_b'});
hfssSubtract(fid, 'panelMetal', 'feedLowerCavity');

for ix = 1:Nx
    cavName = sprintf('branchCavity_%02d', ix);
    hfssapi.add_slot_cutout(fid, cavName, ...
        {sprintf('((-branch_len/2)+(%s))', param.branch_shift{ix}), ...
         sprintf('((%s)-(rad_a/2))', param.row_y{ix}), ...
         'z3'}, ...
        {'branch_len', 'rad_a', 'rad_b'});
    hfssSubtract(fid, 'panelMetal', cavName);
end

% One longitudinal coupling slot per radiating guide. Within each feed half,
% adjacent coupling slots are spaced by lambda_g(cpl)/2, so their transverse
% offsets alternate. Across the upper/lower halves, the sign pattern is
% mirrored so both halves launch the branch guides with the same phase.
for ix = 1:Nx
    cutName = sprintf('cplSlot_b%02d', ix);
    hfssapi.add_slot_cutout(fid, cutName, ...
        {sprintf('((%s)-(%s/2))', param.cpl_off{ix}, param.cpl_w{ix}), ...
         sprintf('((%s)-(%s/2))', param.row_y{ix}, param.cpl_len{ix}), ...
         '((cpl_z_center)-(cpl_thk/2))'}, ...
        {param.cpl_w{ix}, param.cpl_len{ix}, 'cpl_thk'});
    hfssSubtract(fid, 'panelMetal', cutName);
end

% Alternating longitudinal radiating slots on each radiating guide.
% The offset alternation is along the guide only; all six guides share the
% same sign sequence so equal-phase branch excitation does not turn into a
% checkerboard aperture phase error.
halfY = floor(Ny/2);
for ix = 1:Nx
    gPairs = conductance.rad_pair_g(ix, :);
    if isempty(gPairs)
        gPairs = 0.08 * ones(1, ceil(Ny/2));
    end
    for k = 1:Ny
        symDepth = min(k, Ny-k+1);
        pairIdx = max(halfY - symDepth + 1, 1);
        pairIdx = min(pairIdx, numel(gPairs));
        g = max(min(gPairs(pairIdx), 1.0), 0.01);
        g = local_opt_pair_g(spec, 'radiating_g_pair_scale', g, pairIdx);
        if closedForm
            slotGeom = utils.design_radiating_slot(arrayData, g, spec);
            offMag = slotGeom.offset_mm;
            slotLen = slotGeom.length_mm;
            slotW = slotGeom.width_mm;
        else
            offRatio = spec.mapping.min_offset_ratio + ...
                (spec.mapping.max_offset_ratio - spec.mapping.min_offset_ratio) * min(g/0.25, 1.0);
            offMag = offRatio * aRad;
            slotLen = (spec.mapping.rad_length_ratio(1) + ...
                (spec.mapping.rad_length_ratio(2)-spec.mapping.rad_length_ratio(1))*min(g/0.25,1.0)) * lambda0;
            slotW = spec.geometry.slot_width_mm;
        end
        offMag = offMag * local_opt_scalar(spec, 'radiating_offset_scale', 1);
        slotLen = slotLen * local_opt_scalar(spec, 'radiating_length_scale', 1);
        radName = sprintf('radSlot_b%02d_k%02d', ix, k);
        radSideSign = local_radiating_phase_comp_sign(feedPhase, rowY(ix));
        radVar = local_register_rad_slot_vars(fid, ix, k, slotW, slotLen, offMag, radSideSign * (-1)^(k+1));
        slotStart = { ...
            sprintf('(((%s)+(%s))-(%s/2))', param.slot_x{k}, param.branch_shift{ix}, radVar.length), ...
            sprintf('((%s)+(%s)-(%s/2))', param.row_y{ix}, radVar.off_expr, radVar.width), ...
            'rad_slot_z'};
        slotSize = {radVar.length, radVar.width, 'rad_slot_thk'};
        hfssapi.add_slot_cutout(fid, radName, slotStart, slotSize);
        hfssSubtract(fid, 'panelMetal', radName);
    end
end

if usePhysicalET
    % Wave port on the bottom E-plane input guide.
    hfssapi.add_waveport_from_rect(fid, 'Port1Sheet', 'Z', ...
        {'(-cpl_a/2)', '(-cpl_b/2)', '(-stem_len)'}, 'cpl_a', 'cpl_b', ...
        {'0mm', '0mm', '(-stem_len)'}, {'0mm', '0mm', '(-stem_len)'}, 'Port1');
else
    % Wave port at the side input stem.
    hfssapi.add_waveport_from_rect(fid, 'Port1Sheet', 'X', ...
        {'port_x', '(-cpl_a/2)', 'z1'}, 'cpl_a', 'cpl_b', ...
        {'port_x', '0mm', 'port_int_start_z'}, {'port_x', '0mm', 'port_int_end_z'}, 'Port1');
end

hfssapi.add_region_and_setup(fid, spec, setupName);
if isfield(spec, 'hfss') && isfield(spec.hfss, 'solve_setup') && spec.hfss.solve_setup
    hfssSolveSetup(fid, setupName);
end
if isfield(spec,'hfss') && isfield(spec.hfss,'create_reports') && spec.hfss.create_reports
    hfssapi.add_result_reports(fid, spec, 'Port1');
end
info = hfssapi.finalize_script(fid, spec, vbsPath, projectPath, setupName);
info.model_kind = 'panel_topology';
if usePhysicalET
    feedNote = 'Bottom E-plane input tee with one phase-compensated feed half';
else
    feedNote = 'Side H-plane input tee';
end
info.topology_note = [feedNote, ', two feed halves, six longitudinal coupling slots, ', ...
    'six complete radiating guides, and 6x6 alternating radiating slots.'];
end

function param = local_define_panel_variables(fid, spec, arrayData, conductance, ...
    Nx, Ny, aCpl, bCpl, aRad, bRad, wall, lambda0, lambda_g_cpl, lambda_g_rad, ...
    rowPitch, radPitch, cplPitch, branchLen, feedLen, stemLen, rowY, slotX, ...
    z0, z1, z2, z3, z4, z5, ...
    radPanelXMin, radPanelXMax, radPanelYMin, radPanelYMax, ...
    feedPanelXMin, feedPanelXMax, feedPanelYMin, feedPanelYMax, ...
    xMin, xMax, yMin, yMax, panelZMin)

hfssapi.add_design_var(fid, 'cpl_a', aCpl, 'mm');
hfssapi.add_design_var(fid, 'cpl_b', bCpl, 'mm');
hfssapi.add_design_var(fid, 'rad_a', aRad, 'mm');
hfssapi.add_design_var(fid, 'rad_b', bRad, 'mm');
hfssapi.add_design_var(fid, 'wall', wall, 'mm');
hfssapi.add_design_var(fid, 'lambda0', lambda0, 'mm');
hfssapi.add_design_var(fid, 'lambda_g_cpl', lambda_g_cpl, 'mm');
hfssapi.add_design_var(fid, 'lambda_g_rad', lambda_g_rad, 'mm');
hfssapi.add_design_var(fid, 'row_pitch', rowPitch, 'mm');
hfssapi.add_design_var(fid, 'rad_pitch', radPitch, 'mm');
hfssapi.add_design_var(fid, 'cpl_pitch', cplPitch, 'mm');
hfssapi.add_design_var(fid, 'rad_backshort', 0.25 * lambda_g_rad, 'mm');
hfssapi.add_design_var(fid, 'cpl_backshort', 0.25 * lambda_g_cpl, 'mm');
hfssapi.add_design_var(fid, 'branch_len', branchLen, 'mm');
hfssapi.add_design_var(fid, 'feed_len', feedLen, 'mm');
hfssapi.add_design_var(fid, 'stem_len', stemLen, 'mm');
hfssapi.add_design_var(fid, 'region_pad', spec.geometry.region_pad_mm, 'mm');

hfssapi.add_design_var(fid, 'z0', z0, 'mm');
hfssapi.add_design_var(fid, 'z1', z1, 'mm');
hfssapi.add_design_var(fid, 'z2', z2, 'mm');
hfssapi.add_design_var(fid, 'z3', z3, 'mm');
hfssapi.add_design_var(fid, 'z4', z4, 'mm');
hfssapi.add_design_var(fid, 'z5', z5, 'mm');

hfssapi.add_design_var(fid, 'panel_x_min', xMin, 'mm');
hfssapi.add_design_var(fid, 'panel_y_min', yMin, 'mm');
hfssapi.add_design_var(fid, 'panel_z_min', panelZMin, 'mm');
hfssapi.add_design_var(fid, 'panel_x_size', xMax - xMin, 'mm');
hfssapi.add_design_var(fid, 'panel_y_size', yMax - yMin, 'mm');
hfssapi.add_design_var(fid, 'panel_z_size', z5 - panelZMin, 'mm');
hfssapi.add_design_var(fid, 'rad_panel_x_min', radPanelXMin, 'mm');
hfssapi.add_design_var(fid, 'rad_panel_y_min', radPanelYMin, 'mm');
hfssapi.add_design_var(fid, 'rad_panel_x_size', radPanelXMax - radPanelXMin, 'mm');
hfssapi.add_design_var(fid, 'rad_panel_y_size', radPanelYMax - radPanelYMin, 'mm');
hfssapi.add_design_var(fid, 'feed_panel_x_min', feedPanelXMin, 'mm');
hfssapi.add_design_var(fid, 'feed_panel_y_min', feedPanelYMin, 'mm');
hfssapi.add_design_var(fid, 'feed_panel_x_size', feedPanelXMax - feedPanelXMin, 'mm');
hfssapi.add_design_var(fid, 'feed_panel_y_size', feedPanelYMax - feedPanelYMin, 'mm');

hfssapi.add_design_var(fid, 'port_x', aCpl/2 + stemLen, 'mm');
hfssapi.add_design_var(fid, 'port_int_start_z', z1 + 0.15*bCpl, 'mm');
hfssapi.add_design_var(fid, 'port_int_end_z', z1 + 0.85*bCpl, 'mm');
hfssapi.add_design_var(fid, 'cpl_thk', 1.2*wall, 'mm');
hfssapi.add_design_var(fid, 'cpl_z_center', z2 + wall/2, 'mm');
hfssapi.add_design_var(fid, 'rad_slot_z', z4 - 0.1*wall, 'mm');
hfssapi.add_design_var(fid, 'rad_slot_thk', 1.2*wall, 'mm');

param = struct();
param.panel_x_min = 'panel_x_min';
param.panel_y_min = 'panel_y_min';
param.panel_z_min = 'panel_z_min';
param.panel_x_size = 'panel_x_size';
param.panel_y_size = 'panel_y_size';
param.panel_z_size = 'panel_z_size';
param.rad_panel_x_min = 'rad_panel_x_min';
param.rad_panel_y_min = 'rad_panel_y_min';
param.rad_panel_x_size = 'rad_panel_x_size';
param.rad_panel_y_size = 'rad_panel_y_size';
param.feed_panel_x_min = 'feed_panel_x_min';
param.feed_panel_y_min = 'feed_panel_y_min';
param.feed_panel_x_size = 'feed_panel_x_size';
param.feed_panel_y_size = 'feed_panel_y_size';

param.row_y = cell(Nx, 1);
for ix = 1:Nx
    name = sprintf('row_y_%02d', ix);
    hfssapi.add_design_var(fid, name, rowY(ix), 'mm');
    param.row_y{ix} = name;
end

param.slot_x = cell(Ny, 1);
for k = 1:Ny
    name = sprintf('slot_x_%02d', k);
    hfssapi.add_design_var(fid, name, slotX(k), 'mm');
    param.slot_x{k} = name;
end

param.cpl_len = cell(Nx, 1);
param.cpl_w = cell(Nx, 1);
param.cpl_off = cell(Nx, 1);
param.branch_shift = cell(Nx, 1);
feedG = conductance.feed_pair_g(:);
halfX = floor(Nx/2);
for ix = 1:Nx
    symDepth = min(ix, Nx-ix+1);
    pairIdx = max(halfX - symDepth + 1, 1);
    if isempty(feedG)
        g = 0.05;
    else
        pairIdx = min(pairIdx, numel(feedG));
        g = max(min(feedG(pairIdx), 1.0), 0.01);
    end
    g = local_opt_pair_g(spec, 'coupling_g_pair_scale', g, pairIdx);
    cplGeom = utils.design_coupling_slot(arrayData, g, spec);
    cplGeom = local_opt_coupling_geom(spec, cplGeom);
    nameLen = sprintf('cpl_len_%02d', ix);
    nameW = sprintf('cpl_w_%02d', ix);
    nameOff = sprintf('cpl_off_%02d', ix);
    nameShift = sprintf('branch_shift_%02d', ix);
    cplSign = (-1)^(pairIdx + 1);
    cplSign = cplSign * local_coupling_phase_comp_sign(spec, rowY(ix));
    hfssapi.add_design_var(fid, nameLen, cplGeom.length_mm, 'mm');
    hfssapi.add_design_var(fid, nameW, cplGeom.width_mm, 'mm');
    hfssapi.add_design_var(fid, nameOff, cplSign * cplGeom.offset_mm, 'mm');
    hfssapi.add_design_var(fid, nameShift, cplSign * cplGeom.branch_shift_mm, 'mm');
    param.cpl_len{ix} = nameLen;
    param.cpl_w{ix} = nameW;
    param.cpl_off{ix} = nameOff;
    param.branch_shift{ix} = nameShift;
end
end

function maxShift = local_estimate_max_branch_shift(arrayData, conductance, spec)
maxShift = 0.0;
feedG = conductance.feed_pair_g(:);
Nx = arrayData.Nx;
halfX = floor(Nx/2);
for ix = 1:Nx
    symDepth = min(ix, Nx-ix+1);
    pairIdx = max(halfX - symDepth + 1, 1);
    if isempty(feedG)
        g = 0.05;
    else
        pairIdx = min(pairIdx, numel(feedG));
        g = max(min(feedG(pairIdx), 1.0), 0.01);
    end
    g = local_opt_pair_g(spec, 'coupling_g_pair_scale', g, pairIdx);
    cplGeom = utils.design_coupling_slot(arrayData, g, spec);
    cplGeom = local_opt_coupling_geom(spec, cplGeom);
    if isfield(cplGeom, 'branch_shift_mm') && ~isempty(cplGeom.branch_shift_mm)
        maxShift = max(maxShift, abs(cplGeom.branch_shift_mm));
    end
end
end

function value = local_get_geom_value(geom, fieldName, fallback)
value = fallback;
if isfield(geom, fieldName) && ~isempty(geom.(fieldName))
    value = geom.(fieldName);
end
end

function cfg = local_feed_phase_config(spec)
cfg = struct();
cfg.junction_type = 'H_T';
cfg.et_phase_compensation = 'none';
cfg.et_flip_side = 'lower';
if isfield(spec, 'feed') && isstruct(spec.feed)
    if isfield(spec.feed, 'junction_type') && ~isempty(spec.feed.junction_type)
        cfg.junction_type = upper(strrep(spec.feed.junction_type, '-', '_'));
    end
    if isfield(spec.feed, 'et_phase_compensation') && ~isempty(spec.feed.et_phase_compensation)
        cfg.et_phase_compensation = lower(spec.feed.et_phase_compensation);
    end
    if isfield(spec.feed, 'et_flip_side') && ~isempty(spec.feed.et_flip_side)
        cfg.et_flip_side = lower(spec.feed.et_flip_side);
    end
end
end

function s = local_radiating_phase_comp_sign(cfg, rowY)
s = 1;
if ~strcmpi(cfg.junction_type, 'E_T')
    return;
end
if ~any(strcmp(cfg.et_phase_compensation, {'radiating_slots', 'radiating', 'slots'}))
    return;
end
if local_is_et_flip_side(cfg, rowY)
    s = -1;
end
end

function s = local_coupling_phase_comp_sign(spec, rowY)
s = 1;
cfg = local_feed_phase_config(spec);
if ~strcmpi(cfg.junction_type, 'E_T')
    return;
end
if ~any(strcmp(cfg.et_phase_compensation, {'coupling_slots', 'coupling'}))
    return;
end
if local_is_et_flip_side(cfg, rowY)
    s = -1;
end
end

function tf = local_is_et_flip_side(cfg, rowY)
switch cfg.et_flip_side
    case {'lower', 'negative', '-y'}
        tf = rowY < 0;
    case {'upper', 'positive', '+y'}
        tf = rowY > 0;
    otherwise
        error('Unknown spec.feed.et_flip_side: %s', cfg.et_flip_side);
end
end

function radVar = local_register_rad_slot_vars(fid, ix, k, slotW, slotLen, offMag, signVal)
nameW = sprintf('rad_w_b%02d_k%02d', ix, k);
nameL = sprintf('rad_len_b%02d_k%02d', ix, k);
nameOff = sprintf('rad_off_b%02d_k%02d', ix, k);
hfssapi.add_design_var(fid, nameW, slotW, 'mm');
hfssapi.add_design_var(fid, nameL, slotLen, 'mm');
hfssapi.add_design_var(fid, nameOff, signVal * offMag, 'mm');
radVar = struct('width', nameW, 'length', nameL, 'off_expr', nameOff);
end

function value = local_opt_scalar(spec, fieldName, fallback)
value = fallback;
if isfield(spec, 'optimization') && isstruct(spec.optimization) && ...
        isfield(spec.optimization, fieldName) && ~isempty(spec.optimization.(fieldName))
    value = spec.optimization.(fieldName);
end
end

function gOut = local_opt_pair_g(spec, fieldName, gIn, pairIdx)
scale = 1;
if isfield(spec, 'optimization') && isstruct(spec.optimization) && ...
        isfield(spec.optimization, fieldName) && ~isempty(spec.optimization.(fieldName))
    values = spec.optimization.(fieldName);
    pairIdx = min(max(pairIdx, 1), numel(values));
    scale = values(pairIdx);
end
gOut = min(max(gIn * scale, 1e-4), 0.98);
end

function cplGeom = local_opt_coupling_geom(spec, cplGeom)
lenScale = local_opt_scalar(spec, 'coupling_length_scale', 1);
offScale = local_opt_scalar(spec, 'coupling_offset_scale', 1);
cplGeom.length_mm = cplGeom.length_mm * lenScale;
cplGeom.offset_mm = cplGeom.offset_mm * offScale;
if isfield(cplGeom, 'branch_shift_mm') && ~isempty(cplGeom.branch_shift_mm)
    cplGeom.branch_shift_mm = cplGeom.branch_shift_mm * offScale;
end
end
