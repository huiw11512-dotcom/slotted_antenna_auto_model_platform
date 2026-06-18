function results = run_optimize_antenna_model()
%RUN_OPTIMIZE_ANTENNA_MODEL Candidate-based optimization entry point.
% First use with cfg.execute_solver=false to verify generated candidates.
% After HFSS/CST CSV export is wired, set cfg.execute_solver=true.

repoRoot = fileparts(mfilename('fullpath'));
addpath(repoRoot);

baseSpec = build_demo_spec();
baseSpec.solver = 'HFSS';  % change to 'CST' if required
baseSpec.output_dir = fullfile(repoRoot, 'output_optimization');

cfg = opt.default_config(baseSpec);
cfg.stage = 'joint';
cfg.solver = baseSpec.solver;
cfg.execute_solver = false;
cfg.initial_sample_count = 8;

[x0, vars] = opt.encode_params(baseSpec, cfg);
fprintf('Optimization stage: %s\n', cfg.stage);
fprintf('Variables: %d\n', numel(vars));
for k = 1:numel(vars)
    fprintf('  %-22s x0=%8.4f  [%8.4f, %8.4f]\n', ...
        vars(k).name, vars(k).x0, vars(k).lb, vars(k).ub);
end

X = opt.sample_variables(vars, cfg.initial_sample_count, cfg.random_seed);
X(1, :) = x0(:).';

results = struct();
results.cfg = cfg;
results.vars = vars;
results.evaluations = [];

for k = 1:size(X, 1)
    fprintf('\nCandidate %d/%d\n', k, size(X, 1));
    evaluation = opt.evaluate_design(baseSpec, X(k, :).', vars, cfg);
    fprintf('  id: %s\n', evaluation.candidate_id);
    fprintf('  output: %s\n', evaluation.spec.output_dir);
    fprintf('  score status: %s\n', evaluation.score.status);
    if k == 1
        results.evaluations = evaluation;
    else
        results.evaluations(k, 1) = evaluation; %#ok<AGROW>
    end
end

save(fullfile(baseSpec.output_dir, 'optimization_summary.mat'), 'results');
fprintf('\nSaved optimization summary: %s\n', fullfile(baseSpec.output_dir, 'optimization_summary.mat'));
end
