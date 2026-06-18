
function add_result_reports(fid, spec, portName)
% Create simple S11 and far-field cut reports.
setupName = 'Setup1';
sweepName = 'Sweep1';
ffName = 'FF1';
f0_GHz = spec.f0_Hz / 1e9;

if isfield(spec,'hfss')
    if isfield(spec.hfss,'setup_name') && ~isempty(spec.hfss.setup_name), setupName = spec.hfss.setup_name; end
    if isfield(spec.hfss,'sweep_name') && ~isempty(spec.hfss.sweep_name), sweepName = spec.hfss.sweep_name; end
    if isfield(spec.hfss,'ff_name') && ~isempty(spec.hfss.ff_name), ffName = spec.hfss.ff_name; end
    if isfield(spec.hfss,'solution_f_GHz') && ~isempty(spec.hfss.solution_f_GHz), f0_GHz = spec.hfss.solution_f_GHz; end
end

fprintf(fid, '\n');
fprintf(fid, 'Set oModule = oDesign.GetModule("ReportSetup")\n');

% S11 report on sweep.
fprintf(fid, 'oModule.CreateReport "S Parameter Plot 1", "Modal Solution Data", _\n');
fprintf(fid, '"Rectangular Plot", "%s : %s", _\n', setupName, sweepName);
fprintf(fid, 'Array("Domain:=", "Sweep"), _\n');
fprintf(fid, 'Array("Freq:=", Array("All")), _\n');
fprintf(fid, 'Array("X Component:=", "Freq", "Y Component:=", Array("dB(S(%s,%s))")), Array()\n', portName, portName);

% Principal cut: phi = 0 deg, theta sweeps over the full requested sphere.
fprintf(fid, 'oModule.CreateReport "GainCutPhi0", "Far Fields", _\n');
fprintf(fid, '"Rectangular Plot", "%s : LastAdaptive", _\n', setupName);
fprintf(fid, 'Array("Context:=", "%s"), _\n', ffName);
fprintf(fid, 'Array("Theta:=", Array("All"), "Phi:=", Array("0deg"), "Freq:=", Array("%gGHz")), _\n', f0_GHz);
fprintf(fid, 'Array("X Component:=", "Theta", "Y Component:=", Array("dB(GainTotal)")), Array()\n');

% Orthogonal principal cut: phi = 90 deg, theta sweeps over the full sphere.
fprintf(fid, 'oModule.CreateReport "GainCutPhi90", "Far Fields", _\n');
fprintf(fid, '"Rectangular Plot", "%s : LastAdaptive", _\n', setupName);
fprintf(fid, 'Array("Context:=", "%s"), _\n', ffName);
fprintf(fid, 'Array("Theta:=", Array("All"), "Phi:=", Array("90deg"), "Freq:=", Array("%gGHz")), _\n', f0_GHz);
fprintf(fid, 'Array("X Component:=", "Theta", "Y Component:=", Array("dB(GainTotal)")), Array()\n');

if isfield(spec, 'hfss') && isfield(spec.hfss, 'export_reports') && spec.hfss.export_reports
    hfssExportToFile(fid, 'S Parameter Plot 1', local_vbs_path(fullfile(spec.output_dir, 's11.csv')));
    hfssExportToFile(fid, 'GainCutPhi0', local_vbs_path(fullfile(spec.output_dir, 'GainCutPhi0.csv')));
    hfssExportToFile(fid, 'GainCutPhi90', local_vbs_path(fullfile(spec.output_dir, 'GainCutPhi90.csv')));
end
end

function pathText = local_vbs_path(pathText)
pathText = strrep(char(pathText), '\', '/');
pathText = strrep(pathText, '"', '""');
end
