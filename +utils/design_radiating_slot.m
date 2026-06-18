function slot = design_radiating_slot(arrayData, g, spec)
% Closed-form baseline for resonant longitudinal shunt slots.
% The coefficient follows the adapted Elliott/Stevenson-style conductance
% relation used for rectangular-waveguide slotted arrays.

lambda0 = arrayData.lambda0_mm;
lambdaG = arrayData.calc.lambda_g_mm;
a = arrayData.waveguide.a_mm;
b = arrayData.waveguide.b_mm;

gReq = max(g, 1e-4);
gForLength = min(max(gReq, 0), 1.0);

gCoeff = 2.09 * (lambdaG / lambda0) * (a / b) * ...
    (cos(0.464*pi*lambda0/lambdaG) - cos(0.464*pi))^2;
gMax = 0.98 * gCoeff;
gForOffset = min(gReq, gMax);

slotWidth = 0.8;
if nargin >= 3 && isfield(spec, 'geometry') && isfield(spec.geometry, 'slot_width_mm') ...
        && ~isempty(spec.geometry.slot_width_mm)
    slotWidth = spec.geometry.slot_width_mm;
end

offsetTheory = (a / pi) * asin(sqrt(gForOffset / max(gCoeff, eps)));

offsetLimitRatio = 0.22;
if nargin >= 3 && isfield(spec, 'mapping') && isfield(spec.mapping, 'max_offset_ratio') ...
        && ~isempty(spec.mapping.max_offset_ratio)
    offsetLimitRatio = spec.mapping.max_offset_ratio;
end
offsetLimit = offsetLimitRatio * a;
offsetWallLimit = max(0, 0.5 * (a - slotWidth) - 0.25);
offsetLimit = min(offsetLimit, offsetWallLimit);

slot = struct();
slot.g_requested = gReq;
slot.g_used_length = gForLength;
slot.g_used_offset = gForOffset;
slot.g_coefficient = gCoeff;
slot.g_max_closed_form = gMax;
slot.offset_theory_mm = offsetTheory;
slot.offset_limit_mm = offsetLimit;
slot.saturated = (gReq > gForOffset) || (offsetTheory > offsetLimit);
slot.pitch_mm = 0.5 * lambdaG;
slot.backshort_mm = 0.25 * lambdaG;
slot.width_mm = slotWidth;
slot.offset_mm = min(offsetTheory, offsetLimit);

lenFactor = 0.210324 * gForLength^4 - 0.338065 * gForLength^3 + ...
    0.12712 * gForLength^2 + 0.034433 * gForLength + 0.48253;
slot.length_mm = lambda0 * lenFactor;
end
