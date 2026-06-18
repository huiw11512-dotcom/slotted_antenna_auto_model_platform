function [x0, vars] = encode_params(spec, cfg)
%ENCODE_PARAMS Return the default optimization vector and metadata.
if nargin < 2 || isempty(cfg)
    cfg = opt.default_config(spec);
end
vars = opt.make_variable_table(spec, cfg);
x0 = [vars.x0].';
end
