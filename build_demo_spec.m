function spec = build_demo_spec()
spec = struct();
spec.f0_Hz = 10e9;
spec.gain_dBi = 35;
spec.sll_dB = -25;
spec.efficiency = 0.58;
spec.aperture_aspect_ratio = 1.0;
spec.output_dir = fullfile(pwd, 'output');
spec.solver = 'HFSS';

spec.array = struct();
spec.array.mode = 'fixed';
spec.array.Nx = 6;
spec.array.Ny = 6;

taperTypeX = 'taylor';
taperTypeY = 'taylor';
taperNbarX = 3;
taperNbarY = 3;
spec.synth_x = struct('type', taperTypeX, 'nbar', taperNbarX, 'sll_dB', abs(spec.sll_dB));
spec.synth_y = struct('type', taperTypeY, 'nbar', taperNbarY, 'sll_dB', abs(spec.sll_dB));

spec.waveguide = struct();
spec.waveguide.mode = 'standard';
spec.waveguide.name = 'BJ100';
spec.waveguide.a_mm = 22.86;
spec.waveguide.b_mm = 10.16;
spec.waveguide.t_mm = 1.5;

spec.radiating_waveguide = struct();
spec.radiating_waveguide.mode = 'derived_from_coupling';
spec.radiating_waveguide.b_over_a = spec.waveguide.b_mm / spec.waveguide.a_mm;
spec.radiating_waveguide.t_mm = spec.waveguide.t_mm;
spec.radiating_waveguide.height_mode = 'conductance_fit';
spec.radiating_waveguide.height_margin = 1.08;
spec.radiating_waveguide.min_b_mm = 3.0;

spec.geometry = struct();
spec.geometry.slot_width_mm = 1.2;
spec.geometry.wall_mm = 1.5;
spec.geometry.outer_shell_margin_mm = spec.geometry.wall_mm;
spec.geometry.main_margin_lambda0 = 0.30;
spec.geometry.branch_margin_lambda0 = 0.25;
spec.geometry.branch_pitch_margin_mm = 0.6;
spec.geometry.region_pad_mm = 8.0;
spec.geometry.rad_slot_end_clear_mm = 1.0;
spec.geometry.cpl_slot_length_mm = [];
spec.geometry.cpl_slot_width_mm = 1.2;
spec.geometry.cpl_slot_edge_clear_mm = 0.1;
spec.geometry.cpl_slot_angle_seed_deg = 13.5;
spec.geometry.feed_stem_length_mm = 18.0;
spec.geometry.main_stub_extra_mm = 4.0;

spec.mapping = struct();
spec.mapping.mode = 'closed_form';
spec.mapping.max_offset_ratio = 0.30;
spec.mapping.min_offset_ratio = 0.05;
spec.mapping.rad_length_ratio = [0.42, 0.50];
spec.mapping.cpl_angle_deg = [8, 18];

spec.feed = struct();
spec.feed.junction_type = 'E_T';
spec.feed.et_phase_compensation = 'radiating_slots';
spec.feed.et_flip_side = 'lower';

spec.coupling_slot = struct();
spec.coupling_slot.design_mode = 'fit_table';
spec.coupling_slot.fit_source = 'seed_offset_only';
spec.coupling_slot.length_mode = 'resonant_constant';
spec.coupling_slot.g_grid = [0.03, 0.06, 0.10, 0.16, 0.24, 0.32];
spec.coupling_slot.extract_g_seed = 1 / spec.array.Nx;
spec.coupling_slot.main_backshort_lambda_g = 0.25;
spec.coupling_slot.branch_backshort_lambda_g = 0.25;
spec.coupling_slot.main_port_arm_lambda_g = 0.75;
spec.coupling_slot.branch_port_arm_lambda_g = 0.75;
spec.coupling_slot.fit_table_path = fullfile(spec.output_dir, 'coupling_slot_fit_table.mat');

spec.formula = struct();
spec.formula.cpl_angle_max_deg = 45;
spec.formula.cpl_angle_min_deg = 8;

spec.run = struct();
spec.run.target = 'panel_topology';
spec.run.save_design_mat = true;

spec.environment = struct();
spec.environment.python_executable = '';

spec.hfss = struct();
spec.hfss.vendor_api_dir = fullfile(fileparts(mfilename('fullpath')), 'vendor', 'HFSS-MATLAB-API-master');
spec.hfss.executable = 'D:\software\HFSS\AnsysEM19.0\Win64\ansysedt.exe';
spec.hfss.execute_hfss = true;
spec.hfss.visible = true;
spec.hfss.project_basename = 'hfss_waveguide_panel_v0_8_1_longcpl_bj100_10g_6x6';
spec.hfss.setup_name = 'Setup1';
spec.hfss.sweep_name = 'Sweep1';
spec.hfss.sweep_type = 'discrete';
spec.hfss.sweep_f1_GHz = 9.0;
spec.hfss.sweep_f2_GHz = 11.0;
spec.hfss.sweep_points = 201;
spec.hfss.save_fields = true;
spec.hfss.save_radiated_fields_only = false;
spec.hfss.solution_f_GHz = 10.0;
spec.hfss.create_farfield = true;
spec.hfss.ff_name = 'FF1';
spec.hfss.ff_theta_start = -180;
spec.hfss.ff_theta_stop = 180;
spec.hfss.ff_theta_step = 2;
spec.hfss.ff_phi_start = -180;
spec.hfss.ff_phi_stop = 180;
spec.hfss.ff_phi_step = 2;
spec.hfss.create_reports = true;

spec.cst = struct();
spec.cst.api_dir = fullfile(fileparts(mfilename('fullpath')), 'CST-MATLAB-API-master');
spec.cst.executable = 'D:\software\CST\AMD64\CST DESIGN ENVIRONMENT_AMD64.exe';
spec.cst.execute_cst = true;
spec.cst.visible = true;
spec.cst.project_basename = 'cst_waveguide_panel_v0_8_1_longcpl_bj100_10g_6x6';
end
