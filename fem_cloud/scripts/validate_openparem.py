#!/usr/bin/env python3
"""Validate OpenParEM3D patch-antenna output against upstream regression cases."""

from __future__ import annotations

import argparse
import csv
import json
import math
from datetime import datetime, timezone
from pathlib import Path


def numeric_rows(path: Path) -> list[list[float]]:
    rows: list[list[float]] = []
    if not path.exists():
        raise FileNotFoundError(path)
    for raw in path.read_text(encoding="utf-8", errors="replace").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        try:
            rows.append([float(item.strip()) for item in line.split(",")])
        except ValueError:
            # Ignore non-numeric informational lines, but keep the raw solver log.
            continue
    if not rows:
        raise RuntimeError(f"No numeric rows found in {path}")
    return rows


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--case-dir", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()

    case_dir = args.case_dir.resolve()
    s_rows = numeric_rows(case_dir / "patch_results.csv")
    ff_rows = numeric_rows(case_dir / "patch_FarField_results.csv")

    test_file = case_dir / "patch_test_cases.csv"
    checks: list[dict] = []
    with test_file.open("r", encoding="utf-8", newline="") as handle:
        for raw in handle:
            line = raw.strip()
            if not line or line.startswith("#"):
                continue
            fields = next(csv.reader([line]))
            if len(fields) < 8:
                raise ValueError(f"Malformed regression row: {line}")
            name, freq_hz, metric, port, _index, relation, target, tolerance = fields[:8]
            freq_ghz = float(freq_hz) / 1.0e9
            port_number = int(port)
            expected = float(target)
            tol = float(tolerance)

            if metric in ("magS(dB)", "argS(deg)"):
                candidates = [row for row in s_rows if len(row) >= 3 and abs(row[0] - freq_ghz) < 1e-4]
                if not candidates:
                    raise RuntimeError(f"No S-parameter result near {freq_ghz} GHz for {name}")
                actual_row = min(candidates, key=lambda row: abs(row[0] - freq_ghz))
                actual = actual_row[1] if metric == "magS(dB)" else actual_row[2]
            else:
                candidates = [
                    row for row in ff_rows
                    if len(row) >= 5 and int(round(row[0])) == port_number
                    and abs(row[1] - freq_ghz) < 1e-4
                ]
                if not candidates:
                    raise RuntimeError(f"No far-field result near {freq_ghz} GHz for {name}")
                actual_row = min(candidates, key=lambda row: abs(row[1] - freq_ghz))
                column = {
                    "gain": 2,
                    "directivity": 3,
                    "radiationEfficiency": 4,
                }.get(metric)
                if column is None:
                    raise ValueError(f"Unsupported metric in upstream test case: {metric}")
                actual = actual_row[column]

            if relation != "equal":
                raise ValueError(f"Unsupported regression relation: {relation}")
            error = abs(actual - expected)
            passed = math.isfinite(actual) and error <= tol + 1e-12
            checks.append({
                "name": name,
                "frequency_GHz": freq_ghz,
                "metric": metric,
                "port": port_number,
                "actual": actual,
                "expected": expected,
                "absolute_error": error,
                "tolerance": tol,
                "passed": passed,
            })

    report = {
        "solver": "OpenParEM 2.2.1",
        "case": "coax-fed microstrip patch antenna regression",
        "timestamp_utc": datetime.now(timezone.utc).isoformat(),
        "status": "PASS" if checks and all(item["passed"] for item in checks) else "FAIL",
        "check_count": len(checks),
        "passed_count": sum(bool(item["passed"]) for item in checks),
        "failed_count": sum(not bool(item["passed"]) for item in checks),
        "checks": checks,
        "qualification": (
            "This checks reproducibility against the upstream regression dataset only. "
            "It is not an independent CST/HFSS or measurement validation, and does not "
            "replace mesh/domain convergence studies."
        ),
    }

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2, ensure_ascii=False))
    return 0 if report["status"] == "PASS" else 2


if __name__ == "__main__":
    raise SystemExit(main())
