function fit = extract_coupling_slot_fit()
% Run a sweep of single coupling-slot extraction models and build a first
% extracted fit table for the longitudinal coupling slots.

spec = build_demo_spec();
spec.run.target = 'coupling_slot_extract';
spec.hfss.execute_hfss = true;
spec.hfss.visible = false;
spec.hfss.create_reports = false;
spec.hfss.sweep_f1_GHz = 9.6;
spec.hfss.sweep_f2_GHz = 10.4;
spec.hfss.sweep_points = 81;

gSeed = spec.coupling_slot.g_grid(:).';
nSeed = numel(gSeed);
rows = repmat(struct(), nSeed, 1);

for idx = 1:nSeed
    specRun = spec;
    specRun.coupling_slot.extract_g_seed = gSeed(idx);
    specRun.hfss.project_basename = sprintf('hfss_waveguide_panel_v0_8_1_cpl_extract_g%02d', idx);
    result = synthesize_waveguide_panel_hfss(specRun);
    rows(idx) = local_collect_one(result, specRun, gSeed(idx));
end

gMeasured = [rows.s21_power].';
[gMeasured, order] = sort(gMeasured);
rows = rows(order);

lambdaGBranch = rows(1).lambda_g_rad_mm;
for idx = 1:numel(rows)
    phaseShift = -lambdaGBranch * rows(idx).s21_phase_deg / 360.0;
    halfPeriod = 0.25 * lambdaGBranch;
    phaseShift = mod(phaseShift + halfPeriod, 2*halfPeriod) - halfPeriod;
    rows(idx).branch_shift_fit_mm = rows(idx).offset_mm + phaseShift;
end

fit = struct();
fit.source = 'extracted_s21_power_phase';
fit.note = ['Generated from single-slot extraction runs. g uses measured |S21|^2 at f0, ', ...
    'and branch_shift includes a first-order phase compensation term.'];
fit.g = gMeasured;
fit.offset_mm = reshape([rows.offset_mm], [], 1);
fit.length_mm = reshape([rows.length_mm], [], 1);
fit.width_mm = reshape([rows.width_mm], [], 1);
fit.branch_shift_mm = reshape([rows.branch_shift_fit_mm], [], 1);
fit.phase_ref_deg = reshape([rows.s21_phase_deg], [], 1);
fit.rows = rows;

outPath = spec.coupling_slot.fit_table_path;
save(outPath, 'fit');
local_write_summary_csv(rows, fullfile(spec.output_dir, 'coupling_slot_fit_table.csv'));
fprintf('Saved coupling-slot fit table to:\n%s\n', outPath);
end

function row = local_collect_one(result, spec, gSeed)
arrayData = result.array;
slot = utils.design_coupling_slot(arrayData, gSeed, spec);
csvDir = fullfile(spec.output_dir, 'coupling_extract_reports');
base = spec.hfss.project_basename;
s11 = local_read_report_csv(fullfile(csvDir, [base '_CplS11.csv']));
s21Mag = local_read_report_csv(fullfile(csvDir, [base '_CplS21Mag.csv']));
s21Phase = local_read_report_csv(fullfile(csvDir, [base '_CplS21Phase.csv']));
f0GHz = spec.f0_Hz / 1e9;
row = struct();
row.g_seed = gSeed;
row.g_requested = slot.g_requested;
row.offset_mm = slot.offset_mm;
row.length_mm = slot.length_mm;
row.width_mm = slot.width_mm;
row.lambda_g_rad_mm = arrayData.radiating_calc.lambda_g_mm;
row.f0_GHz = f0GHz;
row.s11_dB = local_interp_report(s11, f0GHz);
row.s21_dB = local_interp_report(s21Mag, f0GHz);
row.s21_phase_deg = local_interp_report(s21Phase, f0GHz);
row.s21_power = 10.^(row.s21_dB / 10.0);
end

function data = local_read_report_csv(pathIn)
opts = detectImportOptions(pathIn, 'FileType', 'text');
tbl = readtable(pathIn, opts);
data = table2array(tbl(:, 1:2));
end

function y = local_interp_report(data, xq)
x = data(:,1);
v = data(:,2);
[x, order] = sort(x);
v = v(order);
y = interp1(x, v, xq, 'linear', 'extrap');
end

function local_write_summary_csv(rows, pathOut)
fid = fopen(pathOut, 'wt');
fprintf(fid, 'g_seed,offset_mm,length_mm,width_mm,s11_dB,s21_dB,s21_phase_deg,s21_power,branch_shift_fit_mm\n');
for idx = 1:numel(rows)
    fprintf(fid, '%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.9f,%.6f\n', ...
        rows(idx).g_seed, rows(idx).offset_mm, rows(idx).length_mm, rows(idx).width_mm, ...
        rows(idx).s11_dB, rows(idx).s21_dB, rows(idx).s21_phase_deg, ...
        rows(idx).s21_power, rows(idx).branch_shift_fit_mm);
end
fclose(fid);
end
