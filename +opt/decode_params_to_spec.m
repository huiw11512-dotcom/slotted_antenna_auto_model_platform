function specOut = decode_params_to_spec(specIn, x, vars, candidateId)
%DECODE_PARAMS_TO_SPEC Apply bounded correction variables to a spec.
if nargin < 4 || isempty(candidateId)
    candidateId = opt.param_hash(x);
end

specOut = specIn;
nCpl = floor(specOut.array.Nx/2);
nRad = floor(specOut.array.Ny/2);

optStruct = struct();
optStruct.coupling_g_pair_scale = ones(1, nCpl);
optStruct.radiating_g_pair_scale = ones(1, nRad);
optStruct.coupling_length_scale = 1;
optStruct.coupling_offset_scale = 1;
optStruct.radiating_length_scale = 1;
optStruct.radiating_offset_scale = 1;
optStruct.feed_stem_trim_mm = 0;

for k = 1:numel(vars)
    value = min(max(x(k), vars(k).lb), vars(k).ub);
    switch vars(k).target
        case {'coupling_g_pair_scale', 'radiating_g_pair_scale'}
            vec = optStruct.(vars(k).target);
            vec(vars(k).index) = value;
            optStruct.(vars(k).target) = vec;
        otherwise
            optStruct.(vars(k).target) = value;
    end
end

optStruct.candidate_id = candidateId;
optStruct.variable_names = {vars.name};
optStruct.x = x(:).';
specOut.optimization = optStruct;

if isfield(specOut, 'output_dir') && ~isempty(specOut.output_dir)
    specOut.output_dir = fullfile(specOut.output_dir, 'opt_runs', candidateId);
end

if isfield(specOut, 'hfss') && isfield(specOut.hfss, 'project_basename')
    specOut.hfss.project_basename = local_append_id(specOut.hfss.project_basename, candidateId);
end
if isfield(specOut, 'cst') && isfield(specOut.cst, 'project_basename')
    specOut.cst.project_basename = local_append_id(specOut.cst.project_basename, candidateId);
end
end

function name = local_append_id(name, candidateId)
name = char(name);
name = regexprep([name '_' candidateId], '[^\w\-]+', '_');
end
