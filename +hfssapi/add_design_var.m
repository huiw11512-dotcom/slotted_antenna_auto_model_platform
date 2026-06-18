function add_design_var(fid, varName, value, units)
if nargin < 4
    units = '';
end
hfssaddVar(fid, varName, value, units);
end
