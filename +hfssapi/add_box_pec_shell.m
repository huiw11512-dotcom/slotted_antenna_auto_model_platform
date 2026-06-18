function add_box_pec_shell(fid, name, start_mm, outer_mm, wall_mm)
innerStart = start_mm + [wall_mm, wall_mm, wall_mm];
innerSize  = outer_mm - 2*wall_mm;
if any(innerSize <= 0)
    error('Shell wall is too thick for object %s.', name);
end
hfssBox(fid, [name '_outer'], start_mm, outer_mm, 'mm');
hfssBox(fid, [name '_inner'], innerStart, innerSize, 'mm');
hfssSubtract(fid, [name '_outer'], [name '_inner']);
hfssRename(fid, [name '_outer'], name);
hfssAssignMaterial(fid, name, 'pec');
end
