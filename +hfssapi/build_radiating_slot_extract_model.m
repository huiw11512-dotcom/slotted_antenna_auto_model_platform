function info = build_radiating_slot_extract_model(spec, arrayData, ~)
% Build the first paper-aligned step: radiating broad-wall slot extraction.
[fid, vbsPath, projectPath] = hfssapi.open_script(spec, 'radiating_slot_extract');
setupName = hfssapi.get_setup_name(spec);

wg = arrayData.waveguide;
calc = arrayData.calc;
lambda_g = calc.lambda_g_mm;
a = wg.a_mm; b = wg.b_mm;
wall = spec.geometry.wall_mm;
closedForm = utils.use_closed_form_mapping(spec);

nSlots = arrayData.Ny;
slotPitch = 0.5 * lambda_g;
if closedForm
    L = nSlots * slotPitch;
else
    L = nSlots * slotPitch + 2.0 * lambda_g;
end
outer = [L + 2*wall, a + 2*wall, b + 2*wall];
start = [0, 0, 0];

hfssapi.add_box_pec_shell(fid, 'branchGuide', start, outer, wall);

% alternating offset broad-wall longitudinal slots on top wall
if closedForm
    gSlot = 1 / max(nSlots, 1);
    slotGeom = utils.design_radiating_slot(arrayData, gSlot, spec);
    slotLen = slotGeom.length_mm;
    slotW = slotGeom.width_mm;
    offMag = slotGeom.offset_mm;
else
    lenRange = spec.mapping.rad_length_ratio * arrayData.lambda0_mm;
    slotLen = mean(lenRange);
    slotW = spec.geometry.slot_width_mm;
    offMag = 0.5 * (spec.mapping.min_offset_ratio + spec.mapping.max_offset_ratio) * a;
end
yCenter = wall + a/2;
zTop = wall + b + wall/2 - slotW/2;
x0 = wall + 0.5 * slotPitch;

for k = 1:nSlots
    xCenter = x0 + (k-1) * slotPitch;
    offset = offMag * ((-1)^(k+1));
    slotStart = [xCenter - slotLen/2, yCenter + offset - slotW/2, zTop - 0.6*wall];
    slotSize = [slotLen, slotW, 1.2*wall];
    cutName = sprintf('radSlot_%02d', k);
    hfssapi.add_slot_cutout(fid, cutName, slotStart, slotSize);
    hfssSubtract(fid, 'branchGuide', cutName);
end

% input wave port at the x-min cross section
portStart = [0, wall, wall];
portW = a;
portH = b;
intStart = [0, wall + a/2, wall];
intEnd   = [0, wall + a/2, wall + b];
hfssapi.add_waveport_from_rect(fid, 'P1_sheet', 'X', portStart, portW, portH, intStart, intEnd);

hfssapi.add_region_and_setup(fid, spec, setupName);
info = hfssapi.finalize_script(fid, spec, vbsPath, projectPath, setupName);
info.model_kind = 'radiating_slot_extract';
end
