function fit = default_coupling_slot_fit(arrayData, spec)
% Build a seed fit table for longitudinal coupling slots.
%
% This is not the final extracted dataset. It is a theory-guided initial
% table whose purpose is to:
% - keep coupling-slot resonance length nearly constant
% - let coupling amplitude be driven mainly by transverse offset
% - provide a direct interpolation target that can later be replaced by
%   extracted HFSS data without changing the panel builder

feedData = arrayData;
if isfield(arrayData, 'feeder_waveguide')
    feedData.waveguide = arrayData.feeder_waveguide;
end
if isfield(arrayData, 'feeder_calc')
    feedData.calc = arrayData.feeder_calc;
end

if isfield(spec, 'coupling_slot') && isfield(spec.coupling_slot, 'g_grid') && ...
        ~isempty(spec.coupling_slot.g_grid)
    gGrid = spec.coupling_slot.g_grid(:);
else
    gGrid = [0.03; 0.06; 0.10; 0.16; 0.24; 0.32];
end
gGrid = sort(max(gGrid, 1e-4));

slotWidth = spec.geometry.cpl_slot_width_mm;

if isfield(spec, 'geometry') && isfield(spec.geometry, 'cpl_slot_length_mm') && ...
        ~isempty(spec.geometry.cpl_slot_length_mm)
    lenRes = spec.geometry.cpl_slot_length_mm;
else
    seedGeom = utils.design_radiating_slot(feedData, median(gGrid), spec);
    lenRes = seedGeom.length_mm;
end

offsets = zeros(size(gGrid));
for idx = 1:numel(gGrid)
    seedGeom = utils.design_radiating_slot(feedData, gGrid(idx), spec);
    offsets(idx) = seedGeom.offset_mm;
end

lengthMode = 'resonant_constant';
if isfield(spec, 'coupling_slot') && isfield(spec.coupling_slot, 'length_mode') && ...
        ~isempty(spec.coupling_slot.length_mode)
    lengthMode = lower(spec.coupling_slot.length_mode);
end

switch lengthMode
    case {'resonant_constant', 'constant'}
        lengths = lenRes * ones(size(gGrid));
    case {'mild_linear', 'mild_trim'}
        gMid = mean([min(gGrid), max(gGrid)]);
        span = max(gGrid) - min(gGrid);
        if span < eps
            lengths = lenRes * ones(size(gGrid));
        else
            lengths = lenRes * (1 + 0.06 * (gGrid - gMid) / span);
        end
    otherwise
        error('Unknown coupling-slot length_mode: %s', lengthMode);
end

fit = struct();
fit.source = 'seed_offset_only';
fit.note = ['Seed table for longitudinal coupling slots. Replace this table ', ...
    'with extracted HFSS |S21|/phase data once the unit-coupler sweep is available.'];
fit.g = gGrid;
fit.offset_mm = offsets;
fit.length_mm = lengths;
fit.width_mm = slotWidth * ones(size(gGrid));
% Keep the coupling slot at a fixed phase point inside each branch guide by
% shifting the branch guide by the same signed magnitude used on the feed
% broad wall. The sign is applied later in the panel builder.
fit.branch_shift_mm = offsets;
fit.phase_ref_deg = zeros(size(gGrid));
end
