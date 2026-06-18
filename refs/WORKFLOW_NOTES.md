# Workflow notes V0.2

V0.2 keeps the paper workflow order:

1. Taylor synthesis / target conductance
2. Radiating-slot extraction model
3. Coupling-slot extraction model
4. Single-branch model
5. Single-input panel topology skeleton

Important boundary of this package:
- The panel topology model is a **geometry skeleton**, not a claimed final calibrated antenna.
- The next iteration should connect the extraction/fitting outputs back into branch and coupling-slot geometry.
- Use `spec.run.target = ''panel_topology''` first to inspect topology generation before enabling HFSS execution.
