"""Run the LedgeRPG server-acceptance check against a live server.

Usage: python scripts/run_acceptance.py [--base-url URL] [--seed N]

Exits nonzero if any check fails. This is the gate Codex called for before
running run_paired_comparison: we want to confirm the server honors the
published contract and that the HERMES bias path is live end-to-end.
"""
from __future__ import annotations

import argparse
import sys

from hermes.experiments.ledgerpg.acceptance import run_all
from hermes.experiments.ledgerpg.client import LedgeRPGClient
from hermes.experiments.ledgerpg.scoring import HeuristicScorer


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base-url", default="http://127.0.0.1:8765")
    parser.add_argument("--seed", type=int, default=42)
    args = parser.parse_args()

    client = LedgeRPGClient(base_url=args.base_url)
    scorer = HeuristicScorer()

    results = run_all(client, scorer, seed=args.seed)

    all_ok = True
    for r in results:
        mark = "PASS" if r.ok else "FAIL"
        print(f"[{mark}] {r.name}: {r.detail}")
        if not r.ok:
            all_ok = False

    return 0 if all_ok else 1


if __name__ == "__main__":
    sys.exit(main())
