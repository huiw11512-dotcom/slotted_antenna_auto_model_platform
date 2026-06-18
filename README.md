# Slotted Antenna Auto Model Platform

MATLAB-based automatic modeling platform for a slotted waveguide antenna array. The code builds a parameterized waveguide-slot panel, maps aperture synthesis results to slot geometry, and generates HFSS or CST model scripts from the same design specification.

## Features

- Parameterized slotted waveguide panel synthesis for frequency, aperture target, waveguide size, array size, taper, slot geometry, and feed topology.
- Shared HFSS/CST backend selection through `spec.solver`.
- Taylor/Chebyshev amplitude taper synthesis and conductance mapping.
- HFSS VBS generation for radiating slot extraction, coupling slot extraction, branch array, and full panel topology.
- CST macro generation for the full panel topology.
- GUI/console entry point plus candidate-based optimization scaffolding.

## Repository Layout

```text
+synthesis/                       Aperture weights and conductance synthesis
+utils/                           Waveguide database and geometry helpers
+hfssapi/                         HFSS script generation helpers
+cstapi/                          CST macro generation helpers
+opt/                             Candidate encoding, sampling, scoring, optimization flow
CST-MATLAB-API-master/            CST MATLAB API dependency
vendor/HFSS-MATLAB-API-master/    HFSS MATLAB API dependency
refs/                             Workflow and parameter notes
build_demo_spec.m                 Default design specification
main_demo.m                       Minimal HFSS demo entry
run_full_antenna_model.m          Unified GUI/console entry for HFSS/CST generation
run_optimize_antenna_model.m      Candidate-based optimization entry
synthesize_waveguide_panel_model.m Shared model synthesis dispatcher
synthesize_waveguide_panel_hfss.m HFSS-focused synthesis entry
```

## Requirements

- Windows with MATLAB.
- Ansys Electronics Desktop/HFSS for HFSS model generation or execution.
- CST Studio Suite for CST model generation or execution.
- Update local executable paths in `build_demo_spec.m` before running solver execution:
  - `spec.hfss.executable`
  - `spec.cst.executable`

## Quick Start

Open MATLAB in the repository root and run:

```matlab
addpath(genpath(pwd));
run_full_antenna_model;
```

For the minimal HFSS demo:

```matlab
addpath(genpath(pwd));
main_demo;
```

To generate files without running the external solver, edit `build_demo_spec.m`:

```matlab
spec.hfss.execute_hfss = false;
spec.cst.execute_cst = false;
```

Then call the synthesis flow:

```matlab
spec = build_demo_spec();
spec.solver = 'HFSS';  % or 'CST'
result = synthesize_waveguide_panel_model(spec);
disp(result.summary);
```

## Optimization Entry

The optimization scaffold can be started with:

```matlab
run_optimize_antenna_model;
```

The default configuration uses `cfg.execute_solver = false` so candidate geometry can be checked before wiring solver result extraction into the scoring loop.

## Generated Files

Generated solver projects, simulation caches, result tables, MATLAB result snapshots, exported figures, papers, screenshots, and packaged archives are intentionally excluded from Git. Typical generated files are written to `output/`, `output_*`, or solver-specific project/cache directories and can be regenerated from the MATLAB scripts.

## Notes

- `build_demo_spec.m` is the main place to adjust frequency, array size, waveguide dimensions, taper, feed settings, solver choice, and output directory.
- `synthesize_waveguide_panel_model.m` keeps the synthesis path shared across HFSS and CST; backend-specific generation is isolated in `+hfssapi` and `+cstapi`.
- Third-party MATLAB API helper code is kept in `vendor/` and `CST-MATLAB-API-master/` for reproducible script generation.
