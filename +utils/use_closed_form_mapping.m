function tf = use_closed_form_mapping(spec)
tf = false;
if isfield(spec, 'mapping') && isfield(spec.mapping, 'mode') && strcmpi(spec.mapping.mode, 'closed_form')
    tf = true;
end
end
