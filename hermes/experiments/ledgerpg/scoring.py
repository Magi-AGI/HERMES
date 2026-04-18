"""MAGUS-scoring interface.

The driver calls `MagusScorer.score(obs, candidates) -> [(Action, raw_score), ...]`.

Two implementations:

- HeuristicScorer: a deterministic Python stand-in for scaffold validation.
  It does not call MAGUS; it is used to smoke-test the driver/HERMES/bias
  pipeline end to end without requiring the Hyperon runtime. Paper results
  are NOT reported from this scorer.

- HyperonScorer: the real paper scorer. Wraps a Hyperon 0.2.1 interpreter,
  loads MAGUS Scoring v2, and calls `rank-decisions` on LedgeRPG candidates.
  Implemented separately in `hyperon_scorer.py` once MAGUS is smoke-tested.

The split exists so the full MAGUS + HERMES + LedgeRPG loop can be validated
end to end before MAGUS's MeTTa runtime is wired in, per Codex's contract-first
guidance.
"""
from __future__ import annotations

from dataclasses import dataclass
from typing import Dict, List, Protocol, Tuple

from hermes.atoms import Action


@dataclass(frozen=True)
class Observation:
    """Canonicalized view of a LedgeRPG step state for scoring.

    Carries only what the scorer needs — no raw HTTP payloads leak past this
    boundary, so the scorer can be swapped without touching the driver.
    """

    position: Tuple[int, int]
    energy: float
    visited_count: int
    food_remaining: int
    last_tile_type: str
    goals: Dict[str, float]
    valid_actions: Tuple[str, ...]


class MagusScorer(Protocol):
    def score(
        self,
        obs: Observation,
        candidates: List[Action],
    ) -> List[Tuple[Action, float]]:
        ...


class HeuristicScorer:
    """Deterministic stand-in for MAGUS Scoring v2.

    Intent: keep the driver exercisable before the MeTTa runtime is wired.
    Ranks actions by a cheap affine combination of the two LedgeRPG goals,
    intentionally crude so paper results are never mistaken for this output.
    """

    def score(
        self,
        obs: Observation,
        candidates: List[Action],
    ) -> List[Tuple[Action, float]]:
        exploration_pressure = 1.0 - obs.goals.get("EXPLORATION_INCENTIVE", 0.0)
        energy_pressure = 1.0 - obs.goals.get("ENERGY_REGULATION", 1.0)

        out: List[Tuple[Action, float]] = []
        for a in candidates:
            base = 0.0
            if a.name.startswith("move-"):
                base += 0.6 * exploration_pressure - 0.2 * energy_pressure
            elif a.name == "examine":
                base += 0.4 + 0.5 * energy_pressure if obs.last_tile_type == "food" else 0.1
            elif a.name == "rest":
                base += 0.8 * energy_pressure
            out.append((a, base))
        return out
