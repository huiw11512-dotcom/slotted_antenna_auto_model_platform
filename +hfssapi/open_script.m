function [fid, vbsPath, projectPath] = open_script(spec, modelTag)
hfssapi.ensure_vendor_api(spec);
if ~exist(spec.output_dir, 'dir')
    mkdir(spec.output_dir);
end
vbsPath = fullfile(spec.output_dir, [spec.hfss.project_basename '_' modelTag '.vbs']);
projectPath = fullfile(spec.output_dir, [spec.hfss.project_basename '_' modelTag '.aedt']);
fid = fopen(vbsPath, 'wt');
if fid < 0
    error('Cannot open VBS file for writing: %s', vbsPath);
end
hfssNewProject(fid);
hfssInsertDesign(fid, modelTag, 'driven modal');
end
