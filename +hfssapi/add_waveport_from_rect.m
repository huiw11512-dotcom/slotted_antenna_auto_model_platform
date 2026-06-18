
function add_waveport_from_rect(fid, rectName, axis, start_mm, width_mm, height_mm, ~, ~, portName)
% Create a sheet and assign a wave port.
% For robustness, assign the wave port without an explicit integration line.

if nargin < 9 || isempty(portName)
    portName = [rectName '_port'];
end

axis = upper(axis);
if iscell(start_mm)
    start_mm = reshape(start_mm, numel(start_mm), 1);
end
switch axis
    case 'X'
        rectW = width_mm;
        rectH = height_mm;
    case 'Y'
        rectW = height_mm;
        rectH = width_mm;
    case 'Z'
        rectW = width_mm;
        rectH = height_mm;
    otherwise
        error('Unsupported port rectangle axis: %s', axis);
end
hfssRectangle(fid, rectName, axis, start_mm, rectW, rectH, 'mm');
hfssAssignWavePort(fid, portName, rectName, 1, false, [0,0,0], [0,0,0], 'mm');
end
