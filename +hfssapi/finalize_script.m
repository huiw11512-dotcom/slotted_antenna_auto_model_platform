function info = finalize_script(fid, spec, vbsPath, projectPath, setupName)
if nargin >= 5 && ~isempty(setupName)
    hfssSaveProject(fid, projectPath, true);
end
fprintf(fid, '\n');
fclose(fid);

info = struct();
info.vbs_path = vbsPath;
info.project_path = projectPath;
info.executed = false;
if isfield(spec, 'hfss') && isfield(spec.hfss, 'execute_hfss') && spec.hfss.execute_hfss
    info = hfssapi.run_vbs(spec, info);
end
end
