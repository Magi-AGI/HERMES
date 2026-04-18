"""Summarize results/paired.jsonl from run_paired_comparison.py.

Per Gemini's advisory: focus on Steps-to-Reward, Energy Remaining, variance.
Reports a per-condition summary plus a paired-within-seed delta.

Usage: python scripts/summarize_paired.py results/paired.jsonl
"""
from __future__ import annotations

import json
import math
import sys
from pathlib import Path
from statistics import mean, pstdev
from typing import Any, Dict, List


def _load(path: Path) -> List[Dict[str, Any]]:
    out: List[Dict[str, Any]] = []
    with open(path, "r", encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            out.append(json.loads(line))
    return out


def _col(rows: List[Dict[str, Any]], condition: str, key: str) -> List[float]:
    return [float(r[condition].get(key, 0)) for r in rows]


def _final_goal(rows: List[Dict[str, Any]], condition: str, goal: str) -> List[float]:
    return [float(r[condition]["final_goals"].get(goal, 0.0)) for r in rows]


def _stats(xs: List[float]) -> str:
    if not xs:
        return "n=0"
    return f"n={len(xs)} mean={mean(xs):.3f} stdev={pstdev(xs):.3f} min={min(xs):.3f} max={max(xs):.3f}"


def _paired_delta_stats(a: List[float], b: List[float]) -> str:
    deltas = [bi - ai for ai, bi in zip(a, b)]
    if not deltas:
        return "n=0"
    return (f"n={len(deltas)} mean_delta={mean(deltas):+.3f} "
            f"stdev={pstdev(deltas):.3f} "
            f"wins={sum(1 for d in deltas if d > 0)} "
            f"ties={sum(1 for d in deltas if d == 0)} "
            f"losses={sum(1 for d in deltas if d < 0)}")


def main() -> int:
    if len(sys.argv) < 2:
        print("usage: summarize_paired.py <paired.jsonl>", file=sys.stderr)
        return 2
    rows = _load(Path(sys.argv[1]))

    print(f"=== Paired comparison ({len(rows)} seeds) ===\n")

    for cond in ("baseline", "feedback"):
        print(f"[{cond}]")
        print(f"  steps_taken:   {_stats(_col(rows, cond, 'steps_taken'))}")
        print(f"  success_rate:  {mean(_col(rows, cond, 'success')):.3f}")
        print(f"  attributions:  {_stats(_col(rows, cond, 'num_attributions'))}")
        for g in ("ENERGY_REGULATION", "EXPLORATION_INCENTIVE"):
            print(f"  final {g}: {_stats(_final_goal(rows, cond, g))}")
        print()

    print("=== Paired deltas (feedback - baseline, per seed) ===")
    print(f"  steps:   {_paired_delta_stats(_col(rows, 'baseline', 'steps_taken'), _col(rows, 'feedback', 'steps_taken'))}")
    print(f"  success: {_paired_delta_stats(_col(rows, 'baseline', 'success'), _col(rows, 'feedback', 'success'))}")
    for g in ("ENERGY_REGULATION", "EXPLORATION_INCENTIVE"):
        print(f"  {g}: {_paired_delta_stats(_final_goal(rows, 'baseline', g), _final_goal(rows, 'feedback', g))}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
