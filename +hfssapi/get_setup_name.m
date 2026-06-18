function setupName = get_setup_name(spec)
setupName = 'Setup1';
if isfield(spec, 'hfss') && isfield(spec.hfss, 'setup_name') && ~isempty(spec.hfss.setup_name)
    setupName = spec.hfss.setup_name;
end
end
