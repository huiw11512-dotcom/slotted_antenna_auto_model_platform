
function add_region_and_setup(fid, spec, setupName)
% Add the outer radiation region, solution setup, sweep, optional infinite sphere,
% and first-pass report requests. This uses the vendor API syntax directly,
% which is more stable than custom VBS snippets.

pad = spec.geometry.region_pad_mm;
hfssCreateRegion(fid, 1, [pad pad], [pad pad], [pad pad], 'mm');
hfssAssignRadiation(fid, 'Rad1', 'Region');

f0_GHz = spec.f0_Hz / 1e9;
if isfield(spec, 'hfss') && isfield(spec.hfss, 'solution_f_GHz') && ~isempty(spec.hfss.solution_f_GHz)
    f0_GHz = spec.hfss.solution_f_GHz;
end

hfssInsertSolution(fid, setupName, f0_GHz, 0.02, 12);

if isfield(spec, 'hfss') && isfield(spec.hfss, 'sweep_f1_GHz') && isfield(spec.hfss, 'sweep_f2_GHz')
    hfssapi.add_driven_sweep(fid, spec, setupName);
end

if isfield(spec, 'hfss') && isfield(spec.hfss, 'create_farfield') && spec.hfss.create_farfield
    ffName = 'FF1';
    if isfield(spec.hfss, 'ff_name') && ~isempty(spec.hfss.ff_name)
        ffName = spec.hfss.ff_name;
    end
    t1 = -180; t2 = 180; ts = 2; p1 = -180; p2 = 180; ps = 2;
    if isfield(spec.hfss, 'ff_theta_start'); t1 = spec.hfss.ff_theta_start; end
    if isfield(spec.hfss, 'ff_theta_stop');  t2 = spec.hfss.ff_theta_stop; end
    if isfield(spec.hfss, 'ff_theta_step');  ts = spec.hfss.ff_theta_step; end
    if isfield(spec.hfss, 'ff_phi_start');   p1 = spec.hfss.ff_phi_start; end
    if isfield(spec.hfss, 'ff_phi_stop');    p2 = spec.hfss.ff_phi_stop; end
    if isfield(spec.hfss, 'ff_phi_step');    ps = spec.hfss.ff_phi_step; end
    hfssFarFieldSphere(fid, ffName, t1, t2, ts, p1, p2, ps);
end
end
