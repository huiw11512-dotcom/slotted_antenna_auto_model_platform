
clear; clc;
addpath(genpath(fileparts(mfilename('fullpath'))));

spec = build_demo_spec();

result = synthesize_waveguide_panel_hfss(spec);

disp('--- SUMMARY ---');
disp(result.summary);
if isfield(result, 'generated_files')
    disp('--- GENERATED FILES ---');
    disp(result.generated_files);
end
