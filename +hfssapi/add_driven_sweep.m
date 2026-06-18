function add_driven_sweep(fid, spec, setupName)
% Add a driven sweep using the requested HFSS sweep type.

if ~isfield(spec, 'hfss') || ~isfield(spec.hfss, 'sweep_f1_GHz') || ~isfield(spec.hfss, 'sweep_f2_GHz')
    return;
end

sweepName = 'Sweep1';
if isfield(spec.hfss, 'sweep_name') && ~isempty(spec.hfss.sweep_name)
    sweepName = spec.hfss.sweep_name;
end

nPts = 201;
if isfield(spec.hfss, 'sweep_points') && ~isempty(spec.hfss.sweep_points)
    nPts = spec.hfss.sweep_points;
end

sweepType = 'Discrete';
if isfield(spec.hfss, 'sweep_type') && ~isempty(spec.hfss.sweep_type)
    sweepType = spec.hfss.sweep_type;
end

saveFields = true;
if isfield(spec.hfss, 'save_fields') && ~isempty(spec.hfss.save_fields)
    saveFields = logical(spec.hfss.save_fields);
end

saveRadFields = false;
if isfield(spec.hfss, 'save_radiated_fields_only') && ~isempty(spec.hfss.save_radiated_fields_only)
    saveRadFields = logical(spec.hfss.save_radiated_fields_only);
end

f1 = spec.hfss.sweep_f1_GHz;
f2 = spec.hfss.sweep_f2_GHz;

switch lower(sweepType)
    case 'interpolating'
        maxSols = 101;
        if isfield(spec.hfss, 'sweep_max_solutions') && ~isempty(spec.hfss.sweep_max_solutions)
            maxSols = spec.hfss.sweep_max_solutions;
        end
        interpTol = 0.5;
        if isfield(spec.hfss, 'sweep_interp_tol') && ~isempty(spec.hfss.sweep_interp_tol)
            interpTol = spec.hfss.sweep_interp_tol;
        end
        hfssInterpolatingSweep(fid, sweepName, setupName, f1, f2, nPts, maxSols, interpTol);
    case 'discrete'
        fprintf(fid, '\n');
        fprintf(fid, 'Set oModule = oDesign.GetModule("AnalysisSetup")\n');
        fprintf(fid, 'oModule.InsertDrivenSweep "%s", Array("NAME:%s", _\n', setupName, sweepName);
        fprintf(fid, '"IsEnabled:=", true, _\n');
        fprintf(fid, '"RangeType:=", "LinearCount", _\n');
        fprintf(fid, '"RangeStart:=", "%gGHz", _\n', f1);
        fprintf(fid, '"RangeEnd:=", "%gGHz", _\n', f2);
        fprintf(fid, '"RangeCount:=", %d, _\n', nPts);
        fprintf(fid, '"Type:=", "Discrete", _\n');
        fprintf(fid, '"SaveFields:=", %s, _\n', local_vbs_bool(saveFields));
        fprintf(fid, '"SaveRadFields:=", %s, _\n', local_vbs_bool(saveRadFields));
        fprintf(fid, '"ExtrapToDC:=", false)\n');
    otherwise
        error('Unsupported sweep type: %s', sweepType);
end
end

function txt = local_vbs_bool(tf)
if tf
    txt = 'true';
else
    txt = 'false';
end
end
