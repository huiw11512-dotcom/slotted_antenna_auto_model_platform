function X = sample_variables(vars, n, seed)
%SAMPLE_VARIABLES Random bounded samples around the formula baseline.
if nargin < 3 || isempty(seed)
    seed = 7;
end
rng(seed);
x0 = [vars.x0];
lb = [vars.lb];
ub = [vars.ub];
X = zeros(n, numel(vars));
X(1, :) = x0;
for k = 2:n
    r = rand(size(x0));
    X(k, :) = lb + r .* (ub - lb);
end
end
