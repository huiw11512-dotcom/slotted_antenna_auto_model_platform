function ensure_vendor_api(spec)
if ~isfield(spec, 'hfss') || ~isfield(spec.hfss, 'vendor_api_dir')
    error('spec.hfss.vendor_api_dir is required.');
end
apiDir = spec.hfss.vendor_api_dir;
if ~exist(apiDir, 'dir')
    error('HFSS API folder not found: %s', apiDir);
end
addpath(genpath(apiDir));
end
