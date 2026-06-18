function slot = design_coupling_slot(arrayData, g, spec)
% Closed-form baseline for longitudinal coupling slots.
% The feeder slot starts from the same resonant-slot baseline as a
% longitudinal shunt slot, then uses an alternating transverse offset on the
% feeder broad wall. The fed branch guide is shifted by the same amount so
% the coupling slot stays centered between the nearest radiating slots.

gUse = min(max(g, 1e-4), 1.0);
mode = local_get_mode(spec);

if any(strcmp(mode, {'fit_table', 'extracted_fit', 'seed_fit'}))
    fit = local_get_fit_table(arrayData, spec);
    slot = local_interp_fit(fit, gUse);
    slot.g_requested = gUse;
    slot.angle_deg = 0;
    slot.orientation = 'longitudinal';
    if ~isfield(slot, 'branch_shift_mm') || isempty(slot.branch_shift_mm)
        slot.branch_shift_mm = 0;
    end
    return;
end

feedData = arrayData;
if isfield(arrayData, 'feeder_waveguide')
    feedData.waveguide = arrayData.feeder_waveguide;
end
if isfield(arrayData, 'feeder_calc')
    feedData.calc = arrayData.feeder_calc;
end
slot = utils.design_radiating_slot(feedData, gUse, spec);
slot.angle_deg = 0;
if isfield(spec, 'geometry') && isfield(spec.geometry, 'cpl_slot_width_mm') && ~isempty(spec.geometry.cpl_slot_width_mm)
    slot.width_mm = spec.geometry.cpl_slot_width_mm;
end
if isfield(arrayData, 'radiating_waveguide') && isfield(arrayData, 'coupling_slot_pitch_mm')
    edgeClear = 0.0;
    if isfield(spec, 'geometry') && isfield(spec.geometry, 'cpl_slot_edge_clear_mm') && ...
            ~isempty(spec.geometry.cpl_slot_edge_clear_mm)
        edgeClear = spec.geometry.cpl_slot_edge_clear_mm;
    end
    maxLen = arrayData.radiating_waveguide.a_mm - 2*edgeClear;
    if maxLen > slot.width_mm
        slot.length_mm = min(slot.length_mm, maxLen);
    end
end
slot.offset_mm = max(slot.offset_mm, 0);
slot.branch_shift_mm = slot.offset_mm;
slot.orientation = 'longitudinal';
end

function mode = local_get_mode(spec)
mode = 'fit_table';
if isfield(spec, 'coupling_slot') && isfield(spec.coupling_slot, 'design_mode') && ...
        ~isempty(spec.coupling_slot.design_mode)
    mode = lower(spec.coupling_slot.design_mode);
end
end

function fit = local_get_fit_table(arrayData, spec)
if isfield(spec, 'coupling_slot') && isfield(spec.coupling_slot, 'fit_table') && ...
        ~isempty(spec.coupling_slot.fit_table)
    fit = spec.coupling_slot.fit_table;
elseif isfield(spec, 'coupling_slot') && isfield(spec.coupling_slot, 'fit_table_path') && ...
        ~isempty(spec.coupling_slot.fit_table_path) && exist(spec.coupling_slot.fit_table_path, 'file')
    data = load(spec.coupling_slot.fit_table_path);
    if isfield(data, 'fit')
        fit = data.fit;
    elseif isfield(data, 'fitTable')
        fit = data.fitTable;
    else
        error('Coupling-slot fit table file does not contain ''fit'' or ''fitTable'': %s', ...
            spec.coupling_slot.fit_table_path);
    end
else
    fit = utils.default_coupling_slot_fit(arrayData, spec);
end
end

function slot = local_interp_fit(fit, gUse)
gVec = fit.g(:);
[gVec, order] = sort(gVec);

offsetVec = fit.offset_mm(:);
offsetVec = offsetVec(order);
lenVec = fit.length_mm(:);
lenVec = lenVec(order);
widthVec = fit.width_mm(:);
widthVec = widthVec(order);

shiftVec = zeros(size(gVec));
if isfield(fit, 'branch_shift_mm') && ~isempty(fit.branch_shift_mm)
    shiftVec = fit.branch_shift_mm(:);
    shiftVec = shiftVec(order);
end

phaseVec = zeros(size(gVec));
if isfield(fit, 'phase_ref_deg') && ~isempty(fit.phase_ref_deg)
    phaseVec = fit.phase_ref_deg(:);
    phaseVec = phaseVec(order);
end

slot = struct();
slot.fit_source = fit.source;
slot.g_requested = gUse;
slot.g_grid = gVec;
slot.offset_mm = local_interp_clamped(gVec, offsetVec, gUse);
slot.length_mm = local_interp_clamped(gVec, lenVec, gUse);
slot.width_mm = local_interp_clamped(gVec, widthVec, gUse);
slot.branch_shift_mm = local_interp_clamped(gVec, shiftVec, gUse);
slot.phase_ref_deg = local_interp_clamped(gVec, phaseVec, gUse);
slot.orientation = 'longitudinal';
slot.angle_deg = 0;
end

function y = local_interp_clamped(x, v, xq)
if numel(x) == 1
    y = v(1);
    return;
end
xq = min(max(xq, x(1)), x(end));
y = interp1(x, v, xq, 'linear');
end
