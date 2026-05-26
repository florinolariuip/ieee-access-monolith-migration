#!/usr/bin/env python3
"""
Inferential statistics for the paper. Run after aggregate.py.

Outputs:
  - Welch's t-test for skill-mediated vs baseline alignment rates,
    computed without scipy so the script is dependency-free.
  - Wilson 95% confidence interval for the skill-invocation failure rate.

Usage:
  python3 scoring/statistics.py
"""
from __future__ import annotations

import json
import math
import statistics as st
import sys
from pathlib import Path


def t_two_sided_p(t: float, df: float) -> float:
    """Two-sided p-value for Student's t via the regularised incomplete beta.

    Implemented directly (no scipy). Numerical Recipes betacf for I_x(a,b).
    """
    x = df / (df + t * t)
    a, b = df / 2.0, 0.5

    def betacf(x, a, b, itmax=400, eps=1e-14):
        qab, qap, qam = a + b, a + 1, a - 1
        c, d = 1.0, 1.0 - qab * x / qap
        if abs(d) < 1e-30:
            d = 1e-30
        d = 1.0 / d
        h = d
        for m in range(1, itmax + 1):
            m2_ = 2 * m
            aa = m * (b - m) * x / ((qam + m2_) * (a + m2_))
            d = 1.0 + aa * d
            if abs(d) < 1e-30:
                d = 1e-30
            c = 1.0 + aa / c
            if abs(c) < 1e-30:
                c = 1e-30
            d = 1.0 / d
            h *= d * c
            aa = -(a + m) * (qab + m) * x / ((a + m2_) * (qap + m2_))
            d = 1.0 + aa * d
            if abs(d) < 1e-30:
                d = 1e-30
            c = 1.0 + aa / c
            if abs(c) < 1e-30:
                c = 1e-30
            d = 1.0 / d
            del_ = d * c
            h *= del_
            if abs(del_ - 1.0) < eps:
                break
        return h

    bt = math.exp(
        math.lgamma(a + b) - math.lgamma(a) - math.lgamma(b)
        + a * math.log(x) + b * math.log(1 - x)
    )
    if x < (a + 1) / (a + b + 2):
        ix = bt * betacf(x, a, b) / a
    else:
        ix = 1 - bt * betacf(1 - x, b, a) / b
    return ix  # = P(T > |t|) for the relevant tail; *2 for two-sided


def welch(x, y):
    m1, s1, n1 = st.mean(x), st.stdev(x), len(x)
    m2, s2, n2 = st.mean(y), st.stdev(y), len(y)
    se = math.sqrt(s1 ** 2 / n1 + s2 ** 2 / n2)
    t = (m1 - m2) / se
    df = (s1 ** 2 / n1 + s2 ** 2 / n2) ** 2 / (
        (s1 ** 2 / n1) ** 2 / (n1 - 1) + (s2 ** 2 / n2) ** 2 / (n2 - 1)
    )
    p = 2 * t_two_sided_p(abs(t), df)
    return {"t": t, "df": df, "p_two_sided": p,
            "mean_x": m1, "sd_x": s1, "n_x": n1,
            "mean_y": m2, "sd_y": s2, "n_y": n2}


def wilson_ci(successes: int, n: int, conf: float = 0.95) -> tuple[float, float]:
    z = 1.959963984540054 if abs(conf - 0.95) < 1e-6 else _z_from_conf(conf)
    p = successes / n
    center = (p + z * z / (2 * n)) / (1 + z * z / n)
    margin = z * math.sqrt(p * (1 - p) / n + z * z / (4 * n * n)) / (1 + z * z / n)
    return center - margin, center + margin


def _z_from_conf(conf):
    # Standard normal inverse via Beasley-Springer-Moro for non-95%.
    # Not needed for the paper's reporting but kept for completeness.
    p = (1 + conf) / 2
    if p < 0.5:
        return -_z_from_conf(2 * (1 - p) - 1)
    a = [0, -3.969683028665376e+01, 2.209460984245205e+02, -2.759285104469687e+02,
         1.383577518672690e+02, -3.066479806614716e+01, 2.506628277459239e+00]
    b = [0, -5.447609879822406e+01, 1.615858368580409e+02, -1.556989798598866e+02,
         6.680131188771972e+01, -1.328068155288572e+01]
    q = p - 0.5
    if abs(q) <= 0.425:
        r = q * q
        return q * (((((a[1]*r+a[2])*r+a[3])*r+a[4])*r+a[5])*r+a[6]) / \
               (((((b[1]*r+b[2])*r+b[3])*r+b[4])*r+b[5])*r+1)
    return 0  # not reached for 95%


def main():
    # Load per-run alignment from the aggregate output if present; otherwise
    # use the data committed alongside this script for reproducibility.
    workspace = Path(__file__).resolve().parent.parent / "runs"
    skill_scores: list[int] = []
    baseline_scores: list[int] = []

    for phase, target in (("refactor-skill", skill_scores),
                          ("refactor-baseline", baseline_scores)):
        phase_dir = workspace / phase
        if not phase_dir.is_dir():
            continue
        for run in sorted(phase_dir.iterdir()):
            sc = run / "scoring.json"
            if not sc.exists():
                continue
            # Exclude skill-invocation failures from the alignment comparison.
            if phase == "refactor-skill" and run.name == "run-005":
                continue
            d = json.loads(sc.read_text())
            target.append(d["aligned"])

    if not skill_scores or not baseline_scores:
        # Fallback to the locked study data, so the script can be reproduced
        # from the repo even without the runs/ tarball.
        skill_scores   = [11, 11, 13, 12, 13, 12, 12, 12, 13]
        baseline_scores = [15, 15, 15, 16, 14, 15, 15, 14, 15, 14]

    result = {
        "welch_t_test": welch(skill_scores, baseline_scores),
        "skill_scores": skill_scores,
        "baseline_scores": baseline_scores,
        "invocation_failure_rate": {
            "attempts": 10,
            "failures": 1,
            "point_estimate": 0.10,
            "wilson_95_ci": list(wilson_ci(1, 10, 0.95)),
        },
    }

    out = Path(__file__).resolve().parent.parent / "runs" / "_statistics.json"
    out.write_text(json.dumps(result, indent=2))
    print(json.dumps(result, indent=2))
    print(f"\nWritten: {out}")


if __name__ == "__main__":
    main()
