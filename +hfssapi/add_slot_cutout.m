function add_slot_cutout(fid, name, start_mm, size_mm, material)
if nargin < 5
    material = 'vacuum';
end
if iscell(start_mm)
    start_mm = reshape(start_mm, numel(start_mm), 1);
end
if iscell(size_mm)
    size_mm = reshape(size_mm, numel(size_mm), 1);
end
hfssBox(fid, name, start_mm, size_mm, 'mm');
if strcmpi(material, 'pec')
    hfssAssignMaterial(fid, name, 'pec');
end
end
