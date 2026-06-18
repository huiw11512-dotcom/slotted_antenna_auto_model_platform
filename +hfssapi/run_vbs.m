function info = run_vbs(spec, info)
if ~isfield(spec.hfss, 'executable') || isempty(spec.hfss.executable)
    warning('spec.hfss.execute_hfss=true but spec.hfss.executable is empty. VBS was generated only.');
    return;
end
exe = spec.hfss.executable;
script = info.vbs_path;
if ~exist(exe, 'file')
    warning('HFSS executable not found: %s', exe);
    return;
end
visible = isfield(spec.hfss, 'visible') && spec.hfss.visible;
if visible
    cmd = ['"' exe '" -RunScript "' script '"'];
else
    cmd = ['"' exe '" -RunScriptAndExit "' script '"'];
end
[status, out] = system(cmd);
info.executed = (status == 0);
info.launch_status = status;
info.launch_output = out;
end
