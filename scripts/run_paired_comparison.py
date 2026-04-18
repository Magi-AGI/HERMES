"""Paper's paired-comparison runner: MAGUS-alone vs MAGUS+HERMES, per seed.

Drives HyperonScorer (real MAGUS Scoring v2 + LedgeRPG adapter) through
`run_paired_comparison_hyperon` across a user-specified seed range. Writes
one JSON line per seed to --out, with the two EpisodeResults summarized,
plus a reasoning-trace exhibit for the smallest seed for the paper.

Usage:
  python scripts/run_paired_comparison.py \\
      --base-url http://127.0.0.1:8765 \\
      --seeds 42-71 \\
      --out results/paired.jsonl \\
      --trace-seed 42 \\
      --trace-out results/trace.txt

The LedgeRPG server must be reachable and MAGUS must be present at
E:/GitHub/Magi-AGI/MAGUS (or pass --magus-root).
"""
from __future__ import annotations

import argparse
import json
import sys
from dataclasses import asdict
from pathlib import Path
from typing import Any, Dict, List, Tuple

from hermes.atoms import Action
from hermes.experiments.ledgerpg.bias import BiasTable
from hermes.experiments.ledgerpg.client import LedgeRPGClient, StartConfig
from hermes.experiments.ledgerpg.driver import (
    AGGREGATION_MODES,
    DEFAULT_MIN_CONFIDENCE,
    EpisodeResult,
    run_episode,
    run_paired_comparison_hyperon,
)
from hermes.experiments.ledgerpg.hyperon_scorer import HyperonScorer
from hermes.experiments.ledgerpg.reasoning import format_episode
from hermes.experiments.ledgerpg.scoring import Observation


def _parse_seed_range(spec: str) -> List[int]:
    if "-" in spec:
        lo, hi = spec.split("-", 1)
        return list(range(int(lo), int(hi) + 1))
    return [int(s) for s in spec.split(",") if s.strip()]


def _summarize_result(r: EpisodeResult) -> Dict[str, Any]:
    traj = r.episode_atoms.goal_trajectory
    final_goals = traj[-1] if traj else {}
    return {
        "episode_id": r.episode_id,
        "seed": r.seed,
        "steps_taken": r.steps_taken,
        "terminal_reason": r.terminal_reason,
        "success": r.success,
        "num_attributions": len(r.attributions),
        "num_steps_atoms": len(r.episode_atoms.steps),
        "final_goals": dict(final_goals),
    }


def _summarize_pair(
    seed: int, baseline: EpisodeResult, feedback: EpisodeResult
) -> Dict[str, Any]:
    return {
        "seed": seed,
        "baseline": _summarize_result(baseline),
        "feedback": _summarize_result(feedback),
        "delta_steps_feedback_minus_baseline":
            feedback.steps_taken - baseline.steps_taken,
        "delta_success": int(feedback.success) - int(baseline.success),
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base-url", default="http://127.0.0.1:8765")
    parser.add_argument("--seeds", default="42-71",
                        help="seed range 'lo-hi' or comma list '42,43,44'")
    parser.add_argument("--out", default="results/paired.jsonl")
    parser.add_argument("--trace-seed", type=int, default=None,
                        help="seed to also emit a reasoning trace for")
    parser.add_argument("--trace-out", default="results/trace.txt")
    parser.add_argument("--magus-root", default=None)
    parser.add_argument(
        "--aggregation",
        choices=AGGREGATION_MODES,
        default="none",
        help=(
            "feedback-path attribution transform. 'none' = legacy share-of-movement "
            "(winner amplification). 'group_mean' centers per (goal, lag). "
            "'group_mean_filtered' additionally drops low-confidence pairs."
        ),
    )
    parser.add_argument(
        "--min-confidence",
        type=float,
        default=DEFAULT_MIN_CONFIDENCE,
        help="confidence threshold for --aggregation=group_mean_filtered",
    )
    args = parser.parse_args()

    seeds = _parse_seed_range(args.seeds)
    out_path = Path(args.out)
    out_path.parent.mkdir(parents=True, exist_ok=True)

    client = LedgeRPGClient(base_url=args.base_url)
    scorer = HyperonScorer(
        magus_root=Path(args.magus_root) if args.magus_root else None
    )

    trace_pair: Tuple[EpisodeResult, EpisodeResult] | None = None
    print(
        f"loading scorer (magus_root={args.magus_root or 'default'}) "
        f"aggregation={args.aggregation} min_confidence={args.min_confidence}...",
        flush=True,
    )
    with open(out_path, "w", encoding="utf-8") as fh:
        for i, seed in enumerate(seeds, 1):
            baseline, feedback = run_paired_comparison_hyperon(
                client,
                scorer,
                seed=seed,
                aggregation=args.aggregation,
                min_confidence=args.min_confidence,
            )
            fh.write(json.dumps(_summarize_pair(seed, baseline, feedback)) + "\n")
            fh.flush()
            if args.trace_seed is not None and seed == args.trace_seed:
                trace_pair = (baseline, feedback)
            print(
                f"[{i}/{len(seeds)}] seed={seed} "
                f"B:steps={baseline.steps_taken} succ={int(baseline.success)} "
                f"F:steps={feedback.steps_taken} succ={int(feedback.success)} "
                f"dsteps={feedback.steps_taken - baseline.steps_taken:+d}",
                flush=True,
            )

    if trace_pair is not None:
        baseline, feedback = trace_pair
        trace_path = Path(args.trace_out)
        trace_path.parent.mkdir(parents=True, exist_ok=True)
        with open(trace_path, "w", encoding="utf-8") as fh:
            fh.write(format_episode(baseline))
            fh.write("\n\n" + "=" * 72 + "\n\n")
            fh.write(format_episode(
                feedback, prior_attributions=baseline.attributions
            ))

    return 0


if __name__ == "__main__":
    sys.exit(main())
