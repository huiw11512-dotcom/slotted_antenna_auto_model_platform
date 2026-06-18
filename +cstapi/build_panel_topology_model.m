function info = build_panel_topology_model(spec, arrayData, conductance, ~)
% Generate a CST VBA macro for the same E-T fed longitudinal-slot topology
% used by the HFSS builder. CST geometry is written as parameterized VBA
% instead of using the bundled Cstbrick helper because that helper converts
% dimensions with int2str and loses sub-mm accuracy.
if ~isfield(spec, 'output_dir') || isempty(spec.output_dir)
    spec.output_dir = fullfile(pwd, 'output');
end
if ~exist(spec.output_dir, 'dir')
    mkdir(spec.output_dir);
end

baseName = local_cst_basename(spec);
macroPath = fullfile(spec.output_dir, [baseName '_panel_topology.bas']);
legacyMcsPath = fullfile(spec.output_dir, [baseName '_panel_topology.mcs']);
mcsPath = '';
projectPath = fullfile(spec.output_dir, [baseName '_panel_topology.cst']);

fid = fopen(macroPath, 'w');
if fid < 0
    error('无法创建 CST 宏文件：%s', macroPath);
end
cleanupObj = onCleanup(@() fclose(fid));

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
closedForm = utils.use_closed_form_mapping(spec);

Nx = arrayData.Nx;
Ny = arrayData.Ny;
rowPitch = arrayData.row_outer_pitch_mm;
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
feedPanelXMax = aCpl/2 + shellMargin;
feedPanelYMin = -feedLen/2 - shellMargin;
feedPanelYMax = feedLen/2 + shellMargin;
xMin = min([radPanelXMin, feedPanelXMin]);
xMax = max([radPanelXMax, feedPanelXMax]);
yMin = min([radPanelYMin, feedPanelYMin]);
yMax = max([radPanelYMax, feedPanelYMax]);
panelZMin = -stemLen - wall;

local_write_header(fid, spec, projectPath);
param = local_define_panel_variables(fid, spec, arrayData, conductance, ...
    Nx, Ny, aCpl, bCpl, aRad, bRad, wall, lambda0, lambda_g_cpl, lambda_g_rad, ...
    rowPitch, radPitch, cplPitch, branchLen, feedLen, stemLen, rowY, slotX, ...
    z0, z1, z2, z3, z4, z5, xMin, xMax, yMin, yMax, panelZMin);

local_write_box(fid, 'panelMetal', 'pec', 'PEC', ...
    '(-cpl_a/2-wall)', '(cpl_a/2+wall)', ...
    '(-cpl_b/2-wall)', '(cpl_b/2+wall)', ...
    '(-stem_len-wall)', '(cpl_b+2*wall)');

local_write_box(fid, 'feedUpperGuide', 'pec', 'PEC', ...
    '(-cpl_a/2-wall)', '(cpl_a/2+wall)', ...
    '(-wall)', '(feed_len/2+wall)', ...
    '0', '(cpl_b+2*wall)');
local_write_add(fid, 'pec:panelMetal', 'pec:feedUpperGuide');

local_write_box(fid, 'feedLowerGuide', 'pec', 'PEC', ...
    '(-cpl_a/2-wall)', '(cpl_a/2+wall)', ...
    '(-feed_len/2-wall)', 'wall', ...
    '0', '(cpl_b+2*wall)');
local_write_add(fid, 'pec:panelMetal', 'pec:feedLowerGuide');

for ix = 1:Nx
    shellName = sprintf('branchGuide_%02d', ix);
    local_write_box(fid, shellName, 'pec', 'PEC', ...
        sprintf('((-branch_len/2)+(%s)-wall)', param.branch_shift{ix}), ...
        sprintf('(( branch_len/2)+(%s)+wall)', param.branch_shift{ix}), ...
        sprintf('((%s)-(rad_a/2)-wall)', param.row_y{ix}), ...
        sprintf('((%s)+(rad_a/2)+wall)', param.row_y{ix}), ...
        'z2', 'z5');
    local_write_add(fid, 'pec:panelMetal', ['pec:' shellName]);
end

local_write_box(fid, 'feedInputCavity', 'tool', 'Vacuum', ...
    '(-cpl_a/2)', '(cpl_a/2)', ...
    '(-cpl_b/2)', '(cpl_b/2)', ...
    '(-stem_len)', '(cpl_b+wall)');
local_write_subtract(fid, 'pec:panelMetal', 'tool:feedInputCavity');

local_write_box(fid, 'feedInputPortOpening', 'tool', 'Vacuum', ...
    '(-cpl_a/2)', '(cpl_a/2)', ...
    '(-cpl_b/2)', '(cpl_b/2)', ...
    '(-stem_len-wall)', '(-stem_len)');
local_write_subtract(fid, 'pec:panelMetal', 'tool:feedInputPortOpening');

local_write_box(fid, 'feedUpperCavity', 'tool', 'Vacuum', ...
    '(-cpl_a/2)', '(cpl_a/2)', ...
    '0', '(feed_len/2)', ...
    'z1', 'z2');
local_write_subtract(fid, 'pec:panelMetal', 'tool:feedUpperCavity');

local_write_box(fid, 'feedLowerCavity', 'tool', 'Vacuum', ...
    '(-cpl_a/2)', '(cpl_a/2)', ...
    '(-feed_len/2)', '0', ...
    'z1', 'z2');
local_write_subtract(fid, 'pec:panelMetal', 'tool:feedLowerCavity');

for ix = 1:Nx
    cavName = sprintf('branchCavity_%02d', ix);
    local_write_box(fid, cavName, 'tool', 'Vacuum', ...
        sprintf('((-branch_len/2)+(%s))', param.branch_shift{ix}), ...
        sprintf('(( branch_len/2)+(%s))', param.branch_shift{ix}), ...
        sprintf('((%s)-(rad_a/2))', param.row_y{ix}), ...
        sprintf('((%s)+(rad_a/2))', param.row_y{ix}), ...
        'z3', 'z4');
    local_write_subtract(fid, 'pec:panelMetal', ['tool:' cavName]);
end

for ix = 1:Nx
    cutName = sprintf('cplSlot_b%02d', ix);
    local_write_box(fid, cutName, 'tool', 'Vacuum', ...
        sprintf('((%s)-(%s/2))', param.cpl_off{ix}, param.cpl_w{ix}), ...
        sprintf('((%s)+(%s/2))', param.cpl_off{ix}, param.cpl_w{ix}), ...
        sprintf('((%s)-(%s/2))', param.row_y{ix}, param.cpl_len{ix}), ...
        sprintf('((%s)+(%s/2))', param.row_y{ix}, param.cpl_len{ix}), ...
        '((cpl_z_center)-(cpl_thk/2))', '((cpl_z_center)+(cpl_thk/2))');
    local_write_subtract(fid, 'pec:panelMetal', ['tool:' cutName]);
end

feedPhase = local_feed_phase_config(spec);
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
        radSideSign = local_radiating_phase_comp_sign(feedPhase, rowY(ix));
        radVar = local_register_rad_slot_vars(fid, ix, k, slotW, slotLen, offMag, radSideSign * (-1)^(k+1));
        radName = sprintf('radSlot_b%02d_k%02d', ix, k);
        local_write_box(fid, radName, 'tool', 'Vacuum', ...
            sprintf('(((%s)+(%s))-(%s/2))', param.slot_x{k}, param.branch_shift{ix}, radVar.length), ...
            sprintf('(((%s)+(%s))+(%s/2))', param.slot_x{k}, param.branch_shift{ix}, radVar.length), ...
            sprintf('((%s)+(%s)-(%s/2))', param.row_y{ix}, radVar.off_expr, radVar.width), ...
            sprintf('((%s)+(%s)+(%s/2))', param.row_y{ix}, radVar.off_expr, radVar.width), ...
            'rad_slot_z', '(rad_slot_z+rad_slot_thk)');
        local_write_subtract(fid, 'pec:panelMetal', ['tool:' radName]);
    end
end

local_write_port(fid);
local_write_finish(fid, spec, projectPath);
clear cleanupObj;
if exist(legacyMcsPath, 'file')
    try
        delete(legacyMcsPath);
    catch
    end
end

info = struct();
info.macro_path = macroPath;
info.mcs_path = mcsPath;
info.project_path = projectPath;
info.executed = false;
info.model_kind = 'cst_panel_topology';
info.topology_note = 'CST macro: bottom E-plane input tee, two feed halves, one longitudinal coupling slot per radiating guide, and alternating radiating slots.';
if isfield(spec, 'cst') && isfield(spec.cst, 'execute_cst') && spec.cst.execute_cst
    info = cstapi.run_macro(spec, info);
end
end

function local_write_header(fid, spec, projectPath)
fprintf(fid, ''' Generated by slotted waveguide array designer\n');
fprintf(fid, 'Sub Main()\n');
fprintf(fid, 'On Error GoTo ErrHandler\n');
fprintf(fid, 'With Units\n');
fprintf(fid, '    .Geometry "mm"\n');
fprintf(fid, '    .Frequency "GHz"\n');
fprintf(fid, '    .Time "ns"\n');
fprintf(fid, '    .TemperatureUnit "Kelvin"\n');
fprintf(fid, '    .Voltage "V"\n');
fprintf(fid, '    .Current "A"\n');
fprintf(fid, '    .Resistance "Ohm"\n');
fprintf(fid, '    .Conductance "S"\n');
fprintf(fid, '    .Capacitance "PikoF"\n');
fprintf(fid, '    .Inductance "NanoH"\n');
fprintf(fid, 'End With\n\n');
fprintf(fid, 'Solver.FrequencyRange "%s", "%s"\n', ...
    local_num(spec.hfss.sweep_f1_GHz), local_num(spec.hfss.sweep_f2_GHz));
fprintf(fid, 'With Boundary\n');
fprintf(fid, '    .Xmin "expanded open"\n');
fprintf(fid, '    .Xmax "expanded open"\n');
fprintf(fid, '    .Ymin "expanded open"\n');
fprintf(fid, '    .Ymax "expanded open"\n');
fprintf(fid, '    .Zmin "expanded open"\n');
fprintf(fid, '    .Zmax "expanded open"\n');
fprintf(fid, '    .Xsymmetry "none"\n');
fprintf(fid, '    .Ysymmetry "none"\n');
fprintf(fid, '    .Zsymmetry "none"\n');
fprintf(fid, '    .ReflectionLevel "0.0001"\n');
fprintf(fid, '    .MinimumDistanceType "Fraction"\n');
fprintf(fid, '    .MinimumDistancePerWavelengthNewMeshEngine "4"\n');
fprintf(fid, '    .FrequencyForMinimumDistance "%s"\n', local_num(spec.hfss.sweep_f1_GHz));
fprintf(fid, 'End With\n\n');
fprintf(fid, 'With Background\n');
fprintf(fid, '    .Type "Normal"\n');
fprintf(fid, '    .Epsilon "1.0"\n');
fprintf(fid, '    .Mue "1.0"\n');
fprintf(fid, 'End With\n\n');
fprintf(fid, ''' Results are not deleted automatically; rerun in a clean CST project when needed.\n');
fprintf(fid, ''' Project will be saved to: %s\n\n', local_cst_path(projectPath));
end

function param = local_define_panel_variables(fid, spec, arrayData, conductance, ...
    Nx, Ny, aCpl, bCpl, aRad, bRad, wall, lambda0, lambda_g_cpl, lambda_g_rad, ...
    rowPitch, radPitch, cplPitch, branchLen, feedLen, stemLen, rowY, slotX, ...
    z0, z1, z2, z3, z4, z5, xMin, xMax, yMin, yMax, panelZMin)

local_write_param(fid, 'cpl_a', aCpl);
local_write_param(fid, 'cpl_b', bCpl);
local_write_param(fid, 'rad_a', aRad);
local_write_param(fid, 'rad_b', bRad);
local_write_param(fid, 'wall', wall);
local_write_param(fid, 'lambda0', lambda0);
local_write_param(fid, 'lambda_g_cpl', lambda_g_cpl);
local_write_param(fid, 'lambda_g_rad', lambda_g_rad);
local_write_param(fid, 'row_pitch', rowPitch);
local_write_param(fid, 'rad_pitch', radPitch);
local_write_param(fid, 'cpl_pitch', cplPitch);
local_write_param(fid, 'rad_backshort', 0.25 * lambda_g_rad);
local_write_param(fid, 'cpl_backshort', 0.25 * lambda_g_cpl);
local_write_param(fid, 'branch_len', branchLen);
local_write_param(fid, 'feed_len', feedLen);
local_write_param(fid, 'stem_len', stemLen);
local_write_param(fid, 'region_pad', spec.geometry.region_pad_mm);
local_write_param(fid, 'z0', z0);
local_write_param(fid, 'z1', z1);
local_write_param(fid, 'z2', z2);
local_write_param(fid, 'z3', z3);
local_write_param(fid, 'z4', z4);
local_write_param(fid, 'z5', z5);
local_write_param(fid, 'panel_x_min', xMin);
local_write_param(fid, 'panel_y_min', yMin);
local_write_param(fid, 'panel_z_min', panelZMin);
local_write_param(fid, 'panel_x_size', xMax - xMin);
local_write_param(fid, 'panel_y_size', yMax - yMin);
local_write_param(fid, 'panel_z_size', z5 - panelZMin);
local_write_param(fid, 'cpl_thk', 1.2*wall);
local_write_param(fid, 'cpl_z_center', z2 + wall/2);
local_write_param(fid, 'rad_slot_z', z4 - 0.1*wall);
local_write_param(fid, 'rad_slot_thk', 1.2*wall);

param = struct();
param.row_y = cell(Nx, 1);
for ix = 1:Nx
    name = sprintf('row_y_%02d', ix);
    local_write_param(fid, name, rowY(ix));
    param.row_y{ix} = name;
end

param.slot_x = cell(Ny, 1);
for k = 1:Ny
    name = sprintf('slot_x_%02d', k);
    local_write_param(fid, name, slotX(k));
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
    local_write_param(fid, nameLen, cplGeom.length_mm);
    local_write_param(fid, nameW, cplGeom.width_mm);
    local_write_param(fid, nameOff, cplSign * cplGeom.offset_mm);
    local_write_param(fid, nameShift, cplSign * cplGeom.branch_shift_mm);
    param.cpl_len{ix} = nameLen;
    param.cpl_w{ix} = nameW;
    param.cpl_off{ix} = nameOff;
    param.branch_shift{ix} = nameShift;
end
fprintf(fid, '\n');
end

function local_write_param(fid, name, value)
fprintf(fid, 'StoreParameter "%s", "%s"\n', name, local_num(value));
end

function local_write_box(fid, name, component, material, xmin, xmax, ymin, ymax, zmin, zmax)
fprintf(fid, 'With Brick\n');
fprintf(fid, '    .Reset\n');
fprintf(fid, '    .Name "%s"\n', name);
fprintf(fid, '    .Component "%s"\n', component);
fprintf(fid, '    .Material "%s"\n', material);
fprintf(fid, '    .Xrange "%s", "%s"\n', local_expr(xmin), local_expr(xmax));
fprintf(fid, '    .Yrange "%s", "%s"\n', local_expr(ymin), local_expr(ymax));
fprintf(fid, '    .Zrange "%s", "%s"\n', local_expr(zmin), local_expr(zmax));
fprintf(fid, '    .Create\n');
fprintf(fid, 'End With\n\n');
end

function local_write_add(fid, target, tool)
fprintf(fid, 'Solid.Add "%s", "%s"\n\n', target, tool);
end

function local_write_subtract(fid, target, tool)
fprintf(fid, 'Solid.Subtract "%s", "%s"\n\n', target, tool);
end

function local_write_port(fid)
fprintf(fid, 'Pick.PickFaceFromPoint "pec:panelMetal", "(cpl_a/2+0.5*wall)", "0", "(-stem_len-wall)"\n\n');
fprintf(fid, 'With Port\n');
fprintf(fid, '    .Reset\n');
fprintf(fid, '    .PortNumber "1"\n');
fprintf(fid, '    .Label ""\n');
fprintf(fid, '    .Folder ""\n');
fprintf(fid, '    .NumberOfModes "1"\n');
fprintf(fid, '    .AdjustPolarization "False"\n');
fprintf(fid, '    .PolarizationAngle "0.0"\n');
fprintf(fid, '    .ReferencePlaneDistance "0"\n');
fprintf(fid, '    .TextSize "50"\n');
fprintf(fid, '    .TextMaxLimit "0"\n');
fprintf(fid, '    .Coordinates "Picks"\n');
fprintf(fid, '    .Orientation "positive"\n');
fprintf(fid, '    .PortOnBound "False"\n');
fprintf(fid, '    .ClipPickedPortToBound "False"\n');
fprintf(fid, '    .Xrange "(-cpl_a/2-wall)", "(cpl_a/2+wall)"\n');
fprintf(fid, '    .Yrange "(-cpl_b/2-wall)", "(cpl_b/2+wall)"\n');
fprintf(fid, '    .Zrange "(-stem_len-wall)", "(-stem_len-wall)"\n');
fprintf(fid, '    .XrangeAdd "0.0", "0.0"\n');
fprintf(fid, '    .YrangeAdd "0.0", "0.0"\n');
fprintf(fid, '    .ZrangeAdd "0.0", "0.0"\n');
fprintf(fid, '    .SingleEnded "False"\n');
fprintf(fid, '    .WaveguideMonitor "False"\n');
fprintf(fid, '    .Create\n');
fprintf(fid, 'End With\n\n');
end

function local_write_finish(fid, spec, projectPath)
freq = spec.hfss.solution_f_GHz;
fprintf(fid, 'With Monitor\n');
fprintf(fid, '    .Reset\n');
fprintf(fid, '    .Name "Farfield %.3fGHz"\n', freq);
fprintf(fid, '    .Domain "Frequency"\n');
fprintf(fid, '    .FieldType "Farfield"\n');
fprintf(fid, '    .Frequency "%s"\n', local_num(freq));
fprintf(fid, '    .Create\n');
fprintf(fid, 'End With\n\n');
fprintf(fid, 'SaveAs "%s", True\n', local_cst_path(projectPath));
fprintf(fid, 'Exit Sub\n');
fprintf(fid, 'ErrHandler:\n');
fprintf(fid, '    MsgBox "CST macro failed: " & Err.Description\n');
fprintf(fid, 'End Sub\n');
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
cfg.junction_type = 'E_T';
cfg.et_phase_compensation = 'radiating_slots';
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
if ~strcmpi(cfg.junction_type, 'E_T')
    error('CST 版当前按要求只生成 E-T 功分馈电结构。');
end
end

function s = local_radiating_phase_comp_sign(cfg, rowY)
s = 1;
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
local_write_param(fid, nameW, slotW);
local_write_param(fid, nameL, slotLen);
local_write_param(fid, nameOff, signVal * offMag);
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

function baseName = local_cst_basename(spec)
if isfield(spec, 'cst') && isfield(spec.cst, 'project_basename') && ~isempty(spec.cst.project_basename)
    baseName = spec.cst.project_basename;
elseif isfield(spec, 'hfss') && isfield(spec.hfss, 'project_basename') && ~isempty(spec.hfss.project_basename)
    baseName = [spec.hfss.project_basename '_cst'];
else
    baseName = 'slotted_waveguide_array_cst';
end
baseName = regexprep(baseName, '[^\w\-]+', '_');
end

function txt = local_num(value)
txt = sprintf('%.12g', value);
end

function expr = local_expr(expr)
expr = strtrim(char(expr));
expr = strrep(expr, ' ', '');
end

function pathText = local_cst_path(pathText)
pathText = strrep(char(pathText), '"', '""');
end
