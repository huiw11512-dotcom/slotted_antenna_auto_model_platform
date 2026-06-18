function info = build_branch_array_model(spec, arrayData, conductance, ~)
% Initial single-branch array model with alternating broad-wall radiating slots.
[fid, vbsPath, projectPath] = hfssapi.open_script(spec, 'branch_array');

wg = arrayData.waveguide;
calc = arrayData.calc;
lambda_g = calc.lambda_g_mm;
a = wg.a_mm; b = wg.b_mm; wall = spec.geometry.wall_mm;
setupName = hfssapi.get_setup_name(spec);
closedForm = utils.use_closed_form_mapping(spec);

nSlots = arrayData.Ny;
slotPitch = 0.5 * lambda_g;
if closedForm
    branchL = nSlots * slotPitch;
else
    branchL = nSlots * slotPitch + 2.0 * lambda_g;
end
outer = [branchL + 2*wall, a + 2*wall, b + 2*wall];
start = [0, 0, 0];
hfssapi.add_box_pec_shell(fid, 'branchGuide', start, outer, wall);

yCenter = wall + a/2;
gDesign = conductance.rad_pair_g(ceil(arrayData.Nx/2), :);
if isempty(gDesign)
    gDesign = ones(1, floor(nSlots/2));
end
slotGeomDefault = utils.design_radiating_slot(arrayData, gDesign(1), spec);
slotW = slotGeomDefault.width_mm;
zTop = wall + b + wall/2 - slotW/2;
x0 = wall + 0.5 * slotPitch;
gPairs = conductance.rad_pair_g(ceil(arrayData.Nx/2), :);
if isempty(gPairs)
    gPairs = ones(1, floor(nSlots/2)) / max(floor(nSlots/2),1);
end

for k = 1:nSlots
    symDepth = min(k, nSlots-k+1);
    pairIdx = max(floor(nSlots/2) - symDepth + 1, 1);
    pairIdx = min(pairIdx, numel(gPairs));
    g = max(min(gPairs(pairIdx), 0.25), 0.01);
    if closedForm
        slotGeom = utils.design_radiating_slot(arrayData, g, spec);
        offMag = slotGeom.offset_mm;
        slotLen = slotGeom.length_mm;
        slotW = slotGeom.width_mm;
        zTop = wall + b + wall/2 - slotW/2;
    else
        offRatio = spec.mapping.min_offset_ratio + (spec.mapping.max_offset_ratio - spec.mapping.min_offset_ratio) * min(g/0.25, 1.0);
        offMag = offRatio * a;
        slotLen = (spec.mapping.rad_length_ratio(1) + (spec.mapping.rad_length_ratio(2)-spec.mapping.rad_length_ratio(1))*min(g/0.25,1.0)) * arrayData.lambda0_mm;
    end
    xCenter = x0 + (k-1) * slotPitch;
    offset = offMag * ((-1)^(k+1));
    slotStart = [xCenter - slotLen/2, yCenter + offset - slotW/2, zTop - 0.6*wall];
    slotSize = [slotLen, slotW, 1.2*wall];
    cutName = sprintf('radSlot_%02d', k);
    hfssapi.add_slot_cutout(fid, cutName, slotStart, slotSize);
    hfssSubtract(fid, 'branchGuide', cutName);
end

% Center feed sheet port for standalone branch-array tuning.
feedX = branchL/2 + wall;
portStart = [feedX, wall, wall];
intStart = [feedX, wall + a/2, wall];
intEnd   = [feedX, wall + a/2, wall + b];
hfssapi.add_waveport_from_rect(fid, 'Pcenter_sheet', 'X', portStart, a, b, intStart, intEnd);

hfssapi.add_region_and_setup(fid, spec, setupName);
info = hfssapi.finalize_script(fid, spec, vbsPath, projectPath, setupName);
info.model_kind = 'branch_array';
end
