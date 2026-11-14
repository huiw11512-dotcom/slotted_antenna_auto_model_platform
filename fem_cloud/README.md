# Free Cloud FEM Antenna Prototype

This branch adds a zero-license-cost 3D finite-element antenna benchmark to the existing antenna model-generation project. It does **not** modify the default `main` branch.

## Solver selected for the first test

- **OpenParEM 2.2.1**, GPL-3.0-or-later, full-wave 3D frequency-domain FEM.
- High-order finite elements, adaptive mesh refinement and MPI parallel execution.
- 3D field results, multi-port S-parameters, antenna gain, directivity and radiation efficiency.
- The upstream project includes a coax-fed microstrip patch-antenna regression model and reference test values.

Official sources:
- https://openparem.org/
- https://github.com/OpenParEM/OpenParEM
- https://github.com/OpenParEM/OpenParEM/releases/tag/2.2.1

## Free cloud execution

The workflow `.github/workflows/fem-antenna-benchmark.yml` runs on the standard `ubuntu-24.04` GitHub-hosted runner. This repository is public; standard GitHub-hosted runners for public repositories are free. The selected runner has 4 vCPU and 16 GB RAM.

The workflow:
1. Downloads the official OpenParEM 2.2.1 precompiled Linux package.
2. Checks out the upstream OpenParEM regression model.
3. Runs the coax-fed patch antenna FEM case at 5.86 GHz and 6.40 GHz.
4. Compares S11, gain, directivity and radiation efficiency against the upstream regression tolerances.
5. Saves input files, solver logs, numerical results and a machine-readable validation report.
6. Uploads a 7-day Actions artifact and commits the small result bundle back to this branch.

The first run is triggered by a push to `fem-cloud-prototype`. Once this workflow is merged into the default branch, it can also be started manually from the GitHub Actions tab.

## First benchmark model

Upstream case:
`regression/OpenParEM3D/antenna/patch/`

It is a coax-fed patch on an F4B-like dielectric substrate (the upstream example uses relative permittivity 2.5 and loss tangent 0.002). The reference model uses radiation boundaries and evaluates:
- S11 at 5.86 GHz and 6.40 GHz
- Gain
- Directivity
- Radiation efficiency

The upstream regression values are a reproducibility check for the published example, **not** an independent validation against CST/HFSS or measurement.

## Important solver limitations

- OpenParEM currently uses a first-order radiation boundary; it does not currently provide a PML boundary.
- Radiation-boundary placement and mesh refinement must be checked for convergence before using results in a paper or engineering sign-off.
- OpenParEM3D uses 2D multimode wave ports. A coaxial feed can be modeled as a real coax section terminated by a coaxial wave port, as in the upstream patch example.
- The cloud runner is headless. OpenParEMg is the graphical front end for local geometry creation; the cloud workflow performs the solve and post-processing.
- The first benchmark is deliberately small. It does not yet establish suitability for every antenna, array, substrate, anisotropic material, or near-field problem.

## Next engineering steps

1. Pass the upstream patch regression.
2. Repeat the same antenna with at least two outer-domain sizes and two mesh levels.
3. Cross-check a representative result against CST/HFSS or a trusted analytical result.
4. Add a parameterized X-band antenna case with its real coax-to-microstrip transition.
5. Add automatic parameter sweeps and optimization only after the solver benchmark is stable.

## Results

Generated results are stored under `fem_cloud/results/`:
- `patch_results.csv`
- `patch_FarField_results.csv`
- `validation.json`
- `solver.log`
- copied input mesh, project, port and material files

Do not treat a run as validated unless `validation.json` reports `PASS` and the mesh/domain convergence checks have also been completed.
