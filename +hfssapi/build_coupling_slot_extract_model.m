function info = build_coupling_slot_extract_model(spec, arrayData, ~)
% Coupling-slot extraction model for one longitudinal feed slot.
% This model is meant to extract the mapping:
%   target coupling <-> {slot offset, slot length, slot phase}
% using the actual lower feed guide and upper radiating guide dimensions.

[fid, vbsPath, projectPath] = hfssapi.open_script(spec, 'coupling_slot_extract');
setupName = hfssapi.get_setup_name(spec);

wgCpl = arrayData.coupling_waveguide;
calcCpl = arrayData.coupling_calc;
wgRad = arrayData.radiating_waveguide;
calcRad = arrayData.radiating_calc;
wall = spec.geometry.wall_mm;

lambda_g_cpl = calcCpl.lambda_g_mm;
lambda_g_rad = calcRad.lambda_g_mm;
aCpl = wgCpl.a_mm;
bCpl = wgCpl.b_mm;
aRad = wgRad.a_mm;
bRad = wgRad.b_mm;

cfg = local_extract_cfg(spec, arrayData, lambda_g_cpl, lambda_g_rad);
cplGeom = utils.design_coupling_slot(arrayData, cfg.gSeed, spec);

hfssapi.add_design_var(fid, 'cpl_a', aCpl, 'mm');
hfssapi.add_design_var(fid, 'cpl_b', bCpl, 'mm');
hfssapi.add_design_var(fid, 'rad_a', aRad, 'mm');
hfssapi.add_design_var(fid, 'rad_b', bRad, 'mm');
hfssapi.add_design_var(fid, 'wall', wall, 'mm');
hfssapi.add_design_var(fid, 'lambda_g_cpl', lambda_g_cpl, 'mm');
hfssapi.add_design_var(fid, 'lambda_g_rad', lambda_g_rad, 'mm');
hfssapi.add_design_var(fid, 'main_backshort', cfg.mainBackshort, 'mm');
hfssapi.add_design_var(fid, 'main_port_arm', cfg.mainPortArm, 'mm');
hfssapi.add_design_var(fid, 'branch_backshort', cfg.branchBackshort, 'mm');
hfssapi.add_design_var(fid, 'branch_port_arm', cfg.branchPortArm, 'mm');
hfssapi.add_design_var(fid, 'main_len', 'main_backshort+main_port_arm', '');
hfssapi.add_design_var(fid, 'branch_len', 'branch_backshort+branch_port_arm', '');
hfssapi.add_design_var(fid, 'slot_len', cplGeom.length_mm, 'mm');
hfssapi.add_design_var(fid, 'slot_w', cplGeom.width_mm, 'mm');
hfssapi.add_design_var(fid, 'slot_off', cplGeom.offset_mm, 'mm');
hfssapi.add_design_var(fid, 'slot_thk', 1.2 * wall, 'mm');
hfssapi.add_design_var(fid, 'main_z0', 0, 'mm');
hfssapi.add_design_var(fid, 'main_cav_z0', wall, 'mm');
hfssapi.add_design_var(fid, 'branch_z0', bCpl + wall, 'mm');
hfssapi.add_design_var(fid, 'branch_cav_z0', bCpl + 2*wall, 'mm');
hfssapi.add_design_var(fid, 'region_pad', spec.geometry.region_pad_mm, 'mm');

mainStart = {'(-cpl_a/2-wall)', '(-main_port_arm-wall)', '0mm'};
mainSize = {'(cpl_a+2*wall)', '(main_len+2*wall)', '(cpl_b+2*wall)'};
hfssBox(fid, 'mainGuide_outer', mainStart, mainSize, 'mm');
hfssBox(fid, 'mainGuide_inner', {'(-cpl_a/2)', '(-main_port_arm)', 'main_cav_z0'}, ...
    {'cpl_a', 'main_len', 'cpl_b'}, 'mm');
hfssSubtract(fid, 'mainGuide_outer', 'mainGuide_inner');
hfssRename(fid, 'mainGuide_outer', 'mainGuide');
hfssAssignMaterial(fid, 'mainGuide', 'pec');

branchStart = {'(-branch_backshort-wall)', '(-rad_a/2-wall)', 'branch_z0'};
branchSize = {'(branch_len+2*wall)', '(rad_a+2*wall)', '(rad_b+2*wall)'};
hfssBox(fid, 'branchGuide_outer', branchStart, branchSize, 'mm');
hfssBox(fid, 'branchGuide_inner', {'(-branch_backshort)', '(-rad_a/2)', 'branch_cav_z0'}, ...
    {'branch_len', 'rad_a', 'rad_b'}, 'mm');
hfssSubtract(fid, 'branchGuide_outer', 'branchGuide_inner');
hfssRename(fid, 'branchGuide_outer', 'branchGuide');
hfssAssignMaterial(fid, 'branchGuide', 'pec');

slotStart = { ...
    '((slot_off)-(slot_w/2))', ...
    '(-slot_len/2)', ...
    '((branch_z0)-(slot_thk/2))'};
slotSize = {'slot_w', 'slot_len', 'slot_thk'};
hfssapi.add_slot_cutout(fid, 'cplSlot_raw', slotStart, slotSize);
hfssSubtract(fid, 'mainGuide', 'cplSlot_raw');
hfssSubtract(fid, 'branchGuide', 'cplSlot_raw');

% Feed-guide input port on the Y-min face.
hfssapi.add_waveport_from_rect(fid, 'P1_sheet', 'Y', ...
    {'(-cpl_a/2)', '(-main_port_arm-wall)', 'main_cav_z0'}, ...
    'cpl_a', 'cpl_b', ...
    {'0mm', '(-main_port_arm-wall)', 'main_cav_z0'}, ...
    {'0mm', '(-main_port_arm-wall)', '(main_cav_z0+cpl_b)'}, ...
    'Port1');

% Branch-guide output port on the X-max face.
hfssapi.add_waveport_from_rect(fid, 'P2_sheet', 'X', ...
    {'(branch_port_arm+wall)', '(-rad_a/2)', 'branch_cav_z0'}, ...
    'rad_a', 'rad_b', ...
    {'(branch_port_arm+wall)', '0mm', 'branch_cav_z0'}, ...
    {'(branch_port_arm+wall)', '0mm', '(branch_cav_z0+rad_b)'}, ...
    'Port2');

hfssapi.add_region_and_setup(fid, spec, setupName);
local_add_extract_reports(fid, spec);
local_export_extract_reports(fid, spec);

info = hfssapi.finalize_script(fid, spec, vbsPath, projectPath, setupName);
info.model_kind = 'coupling_slot_extract';
info.topology_note = ['Two-port extraction model: lower feed guide input to upper branch-guide output. ', ...
    'Use this model to fit coupling-slot offset/length against |S21|, angle(S21), and S11.'];
end

function cfg = local_extract_cfg(spec, arrayData, lambda_g_cpl, lambda_g_rad)
cfg = struct();
cfg.gSeed = 1 / max(arrayData.Nx, 1);
cfg.mainBackshort = 0.25 * lambda_g_cpl;
cfg.branchBackshort = 0.25 * lambda_g_rad;
cfg.mainPortArm = 0.75 * lambda_g_cpl;
cfg.branchPortArm = 0.75 * lambda_g_rad;

if isfield(spec, 'coupling_slot') && isstruct(spec.coupling_slot)
    cs = spec.coupling_slot;
    if isfield(cs, 'extract_g_seed') && ~isempty(cs.extract_g_seed)
        cfg.gSeed = cs.extract_g_seed;
    end
    if isfield(cs, 'main_backshort_lambda_g') && ~isempty(cs.main_backshort_lambda_g)
        cfg.mainBackshort = cs.main_backshort_lambda_g * lambda_g_cpl;
    end
    if isfield(cs, 'branch_backshort_lambda_g') && ~isempty(cs.branch_backshort_lambda_g)
        cfg.branchBackshort = cs.branch_backshort_lambda_g * lambda_g_rad;
    end
    if isfield(cs, 'main_port_arm_lambda_g') && ~isempty(cs.main_port_arm_lambda_g)
        cfg.mainPortArm = cs.main_port_arm_lambda_g * lambda_g_cpl;
    end
    if isfield(cs, 'branch_port_arm_lambda_g') && ~isempty(cs.branch_port_arm_lambda_g)
        cfg.branchPortArm = cs.branch_port_arm_lambda_g * lambda_g_rad;
    end
end
end

function local_add_extract_reports(fid, spec)
setupName = 'Setup1';
sweepName = 'Sweep1';
if isfield(spec, 'hfss')
    if isfield(spec.hfss, 'setup_name') && ~isempty(spec.hfss.setup_name)
        setupName = spec.hfss.setup_name;
    end
    if isfield(spec.hfss, 'sweep_name') && ~isempty(spec.hfss.sweep_name)
        sweepName = spec.hfss.sweep_name;
    end
end

fprintf(fid, '\n');
fprintf(fid, 'Set oModule = oDesign.GetModule("ReportSetup")\n');
fprintf(fid, 'oModule.CreateReport "CplS11", "Modal Solution Data", _\n');
fprintf(fid, '"Rectangular Plot", "%s : %s", _\n', setupName, sweepName);
fprintf(fid, 'Array("Domain:=", "Sweep"), _\n');
fprintf(fid, 'Array("Freq:=", Array("All")), _\n');
fprintf(fid, 'Array("X Component:=", "Freq", "Y Component:=", Array("dB(S(Port1,Port1))")), Array()\n');

fprintf(fid, 'oModule.CreateReport "CplS21Mag", "Modal Solution Data", _\n');
fprintf(fid, '"Rectangular Plot", "%s : %s", _\n', setupName, sweepName);
fprintf(fid, 'Array("Domain:=", "Sweep"), _\n');
fprintf(fid, 'Array("Freq:=", Array("All")), _\n');
fprintf(fid, 'Array("X Component:=", "Freq", "Y Component:=", Array("dB(S(Port2,Port1))")), Array()\n');

fprintf(fid, 'oModule.CreateReport "CplS21Phase", "Modal Solution Data", _\n');
fprintf(fid, '"Rectangular Plot", "%s : %s", _\n', setupName, sweepName);
fprintf(fid, 'Array("Domain:=", "Sweep"), _\n');
fprintf(fid, 'Array("Freq:=", Array("All")), _\n');
fprintf(fid, 'Array("X Component:=", "Freq", "Y Component:=", Array("ang_deg(S(Port2,Port1))")), Array()\n');
end

function local_export_extract_reports(fid, spec)
csvDir = fullfile(spec.output_dir, 'coupling_extract_reports');
if ~exist(csvDir, 'dir')
    mkdir(csvDir);
end
base = spec.hfss.project_basename;
hfssExportToFile(fid, 'CplS11', fullfile(csvDir, [base '_CplS11.csv']));
hfssExportToFile(fid, 'CplS21Mag', fullfile(csvDir, [base '_CplS21Mag.csv']));
hfssExportToFile(fid, 'CplS21Phase', fullfile(csvDir, [base '_CplS21Phase.csv']));
end
