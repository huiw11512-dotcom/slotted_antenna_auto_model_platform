function evaluation = evaluate_design(baseSpec, x, vars, cfg)
%EVALUATE_DESIGN Generate/run one candidate and score exported results.
if nargin < 4 || isempty(cfg)
    cfg = opt.default_config(baseSpec);
end

candidateId = opt.param_hash(x);
candidateSpec = opt.decode_params_to_spec(baseSpec, x, vars, candidateId);
candidateSpec.solver = upper(char(cfg.solver));
candidateSpec.hfss.execute_hfss = strcmpi(candidateSpec.solver, 'HFSS') && logical(cfg.execute_solver);
candidateSpec.cst.execute_cst = strcmpi(candidateSpec.solver, 'CST') && logical(cfg.execute_solver);
candidateSpec.hfss.solve_setup = strcmpi(candidateSpec.solver, 'HFSS') && logical(cfg.execute_solver);
candidateSpec.hfss.export_reports = strcmpi(candidateSpec.solver, 'HFSS') && logical(cfg.execute_solver);

cachePath = fullfile(candidateSpec.output_dir, 'candidate_result.mat');
if exist(cachePath, 'file') && ~logical(cfg.force)
    data = load(cachePath);
    evaluation = data.evaluation;
    return;
end

if ~exist(candidateSpec.output_dir, 'dir')
    mkdir(candidateSpec.output_dir);
end

result = synthesize_waveguide_panel_model(candidateSpec);
metrics = opt.read_solver_metrics(candidateSpec.output_dir, cfg);
score = opt.score_results(metrics, cfg, x, vars);

evaluation = struct();
evaluation.candidate_id = candidateId;
evaluation.x = x(:).';
evaluation.vars = vars;
evaluation.spec = candidateSpec;
evaluation.generated_files = result.generated_files;
evaluation.metrics = metrics;
evaluation.score = score;
evaluation.cache_path = cachePath;

save(cachePath, 'evaluation');
end
