#!/usr/bin/env python3
"""
Aggregate per-run timing + scoring across all runs in a phase directory.
Produces a summary CSV + a JSON for inclusion in the paper.

Usage:
  python3 aggregate.py [phase_dir]            # default: runs/
  python3 aggregate.py runs/refactor-skill
"""
from __future__ import annotations

import json
import statistics
import sys
from pathlib import Path


def load_excluded_runs(runs_root: Path) -> set[str]:
    """Read KNOWN_RUN_ISSUES.md and return {"phase/run-NNN", ...}."""
    issues = runs_root / "KNOWN_RUN_ISSUES.md"
    excluded: set[str] = set()
    if not issues.exists():
        return excluded
    for line in issues.read_text().splitlines():
        # Look for headings like "## refactor-skill / run-005"
        if line.startswith("## ") and "/" in line and "run-" in line:
            tag = line[3:].split("(")[0].strip().replace(" ", "")
            excluded.add(tag)
    return excluded


def collect_phase(phase_dir: Path, excluded: set[str]) -> dict:
    runs = sorted([p for p in phase_dir.iterdir() if p.is_dir() and p.name.startswith("run-")])
    durations = []
    alignment_rates = []
    per_dim_counts: dict[str, dict[str, int]] = {}  # dim_id -> {aligned: n, total: n}
    failed_runs = []
    invocation_failures = []

    for run in runs:
        tag = f"{phase_dir.name}/{run.name}"
        timing_p = run / "timing.json"
        scoring_p = run / "scoring.json"

        if tag in excluded:
            invocation_failures.append(run.name)
            # Still record duration so we report it honestly, but skip alignment.
            if timing_p.exists():
                t = json.loads(timing_p.read_text())
                if not t.get("timed_out", False):
                    durations.append(t["wall_clock_seconds"])
            continue

        if timing_p.exists():
            t = json.loads(timing_p.read_text())
            if not t.get("timed_out", False):
                durations.append(t["wall_clock_seconds"])

        if scoring_p.exists():
            s = json.loads(scoring_p.read_text())
            alignment_rates.append(s["alignment_rate"])
            for r in s["results"]:
                d = per_dim_counts.setdefault(r["id"], {"aligned": 0, "total": 0})
                d["total"] += 1
                if r["aligned"]:
                    d["aligned"] += 1
        else:
            failed_runs.append(run.name)

    return {
        "phase": phase_dir.name,
        "n_runs_attempted": len(runs),
        "n_scored_for_alignment": len(alignment_rates),
        "n_invocation_failures": len(invocation_failures),
        "invocation_failure_rate": round(len(invocation_failures) / len(runs), 3) if runs else None,
        "invocation_failures": invocation_failures,
        "n_other_failures": len(failed_runs),
        "failed_runs": failed_runs,
        "duration_seconds": {
            "mean": round(statistics.mean(durations), 1) if durations else None,
            "stdev": round(statistics.stdev(durations), 1) if len(durations) > 1 else None,
            "min": min(durations) if durations else None,
            "max": max(durations) if durations else None,
        },
        "duration_minutes": {
            "mean": round(statistics.mean(durations) / 60, 2) if durations else None,
            "stdev": round(statistics.stdev(durations) / 60, 2) if len(durations) > 1 else None,
        },
        "alignment_rate": {
            "mean": round(statistics.mean(alignment_rates), 3) if alignment_rates else None,
            "stdev": round(statistics.stdev(alignment_rates), 3) if len(alignment_rates) > 1 else None,
            "min": min(alignment_rates) if alignment_rates else None,
            "max": max(alignment_rates) if alignment_rates else None,
        },
        "per_dimension_alignment": {
            dim_id: round(c["aligned"] / c["total"], 3) if c["total"] else 0
            for dim_id, c in sorted(per_dim_counts.items())
        },
    }


def main():
    default_root = Path(__file__).resolve().parent.parent / "runs"
    if len(sys.argv) > 1:
        targets = [Path(p) for p in sys.argv[1:]]
    else:
        targets = [p for p in default_root.iterdir() if p.is_dir() and not p.name.startswith("_")]

    excluded = load_excluded_runs(default_root)
    summaries = {}
    for phase in targets:
        if not phase.is_dir():
            continue
        summaries[phase.name] = collect_phase(phase, excluded)

    output = default_root / "_aggregate.json"
    output.write_text(json.dumps(summaries, indent=2))
    print(json.dumps(summaries, indent=2))
    print(f"\nWritten: {output}")


if __name__ == "__main__":
    main()
