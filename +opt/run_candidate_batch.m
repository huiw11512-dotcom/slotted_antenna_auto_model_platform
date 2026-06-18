function results = run_candidate_batch(baseSpec, cfg)
%RUN_CANDIDATE_BATCH Generate and score bounded optimization candidates.
% The batch only perturbs formula-derived correction factors. The waveguide
% sizing, guided-wavelength spacing, E-T feed topology and backshort rules
% remain owned by the normal synthesis/build path.

if nargin < 2 || isempty(cfg)
    cfg = opt.default_config(baseSpec);
end

cfg.solver = upper(char(baseSpec.solver));
if ~isfield(cfg, 'initial_sample_count') || isempty(cfg.initial_sample_count)
    cfg.initial_sample_count = 12;
end
if ~isfield(cfg, 'random_seed') || isempty(cfg.random_seed)
    cfg.random_seed = 7;
end
if ~isfield(cfg, 'execute_solver') || isempty(cfg.execute_solver)
    cfg.execute_solver = false;
end

if ~exist(baseSpec.output_dir, 'dir')
    mkdir(baseSpec.output_dir);
end

[x0, vars] = opt.encode_params(baseSpec, cfg);
fprintf('Optimization stage: %s\n', cfg.stage);
fprintf('Solver backend: %s\n', cfg.solver);
fprintf('Execute solver: %d\n', logical(cfg.execute_solver));
fprintf('Variables: %d\n', numel(vars));
for k = 1:numel(vars)
    fprintf('  %-22s x0=%8.4f  [%8.4f, %8.4f]\n', ...
        vars(k).name, vars(k).x0, vars(k).lb, vars(k).ub);
end

sampleCount = max(1, round(cfg.initial_sample_count));
X = opt.sample_variables(vars, sampleCount, cfg.random_seed);
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
    if isfield(evaluation.score, 'objective') && isfinite(evaluation.score.objective)
        fprintf('  objective: %.5g\n', evaluation.score.objective);
    end
    if k == 1
        results.evaluations = evaluation;
    else
        results.evaluations(k, 1) = evaluation; %#ok<AGROW>
    end
end

summaryPath = fullfile(baseSpec.output_dir, 'optimization_summary.mat');
save(summaryPath, 'results');
fprintf('\nSaved optimization summary: %s\n', summaryPath);
end
