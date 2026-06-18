function cfg = default_config(spec)
%DEFAULT_CONFIG Optimization defaults for the slotted-waveguide array.
% The optimizer only changes correction factors around the formula-driven
% geometry. Waveguide sizes, guided-wavelength spacings, backshort rules,
% and E-T topology remain fixed in the synthesis path.

if nargin < 1
    spec = build_demo_spec();
end

cfg = struct();
cfg.stage = 'joint';              % matching | sidelobe | joint
cfg.solver = upper(char(spec.solver));
cfg.execute_solver = false;       % set true after result export is verified
cfg.force = false;
cfg.initial_sample_count = 12;
cfg.random_seed = 7;

cfg.targets = struct();
cfg.targets.s11_dB = -20;
cfg.targets.sll_dB = -25;
cfg.targets.beam_theta_deg = 0;
cfg.targets.beam_tolerance_deg = 2.0;
cfg.targets.min_peak_dBi = [];

cfg.weights = struct();
cfg.weights.s11 = 3.0;
cfg.weights.sll = 5.0;
cfg.weights.beam = 2.0;
cfg.weights.gain = 0.5;
cfg.weights.regularization = 0.15;

cfg.main_lobe_exclusion_deg = 18;
cfg.result_files = struct();
cfg.result_files.s11 = {'s11.csv', 'S Parameter Plot 1.csv', 'SParameterPlot1.csv'};
cfg.result_files.phi0 = {'gain_phi0.csv', 'GainCutPhi0.csv', 'DirectivityPhi0.csv'};
cfg.result_files.phi90 = {'gain_phi90.csv', 'GainCutPhi90.csv', 'DirectivityPhi90.csv'};
end
