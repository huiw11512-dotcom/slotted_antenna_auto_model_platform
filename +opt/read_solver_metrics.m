function metrics = read_solver_metrics(outputDir, cfg)
%READ_SOLVER_METRICS Read exported S11 and principal-cut files if present.
% Expected CSVs can be named by cfg.result_files. Missing files are allowed;
% score_results will report that the candidate still needs solver export.

metrics = struct();
metrics.available = false;
metrics.output_dir = outputDir;
metrics.s11 = [];
metrics.phi0 = [];
metrics.phi90 = [];

if nargin < 2 || isempty(cfg)
    cfg = opt.default_config();
end

metrics.s11 = local_read_first(outputDir, cfg.result_files.s11, {'freq_GHz', 's11_dB'});
metrics.phi0 = local_read_first(outputDir, cfg.result_files.phi0, {'theta_deg', 'value_dB'});
metrics.phi90 = local_read_first(outputDir, cfg.result_files.phi90, {'theta_deg', 'value_dB'});
metrics.available = ~isempty(metrics.s11) || ~isempty(metrics.phi0) || ~isempty(metrics.phi90);
end

function data = local_read_first(outputDir, names, canonicalNames)
data = [];
for k = 1:numel(names)
    pathValue = fullfile(outputDir, names{k});
    if exist(pathValue, 'file')
        data = local_read_numeric_csv(pathValue, canonicalNames);
        return;
    end
end
end

function data = local_read_numeric_csv(pathValue, canonicalNames)
raw = readmatrix(pathValue);
raw = raw(:, any(isfinite(raw), 1));
if size(raw, 2) < 2
    data = [];
    return;
end
data = struct();
data.file = pathValue;
data.(canonicalNames{1}) = raw(:, 1);
data.(canonicalNames{2}) = raw(:, 2);
end
