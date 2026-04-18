"""HERMES-attribution → per-candidate additive bias.

The MAGUS-alone condition passes a zero bias for every candidate. The
MAGUS+HERMES condition passes a bias computed from the previous episode's
attributions: for candidate action A, sum over goals g of
(signed_weight(A, g) * confidence(A, g) * BIAS_SCALE).

BIAS_SCALE keeps the bias small relative to MAGUS's own score so the paper
can honestly report MAGUS scoring as dominant and HERMES as a nudge, not a
replacement. Keep this small; inflating it is a scope violation.
"""
from __future__ import annotations

from dataclasses import dataclass
from typing import Dict, Iterable, List, Tuple

from hermes.atoms import Action
from hermes.attribute import SignedAttribution


BIAS_SCALE: float = 0.1


@dataclass(frozen=True)
class BiasTable:
    """Action → aggregate bias, computed once per episode from prior attributions."""

    per_action: Dict[Action, float]

    @classmethod
    def zero(cls) -> "BiasTable":
        return cls(per_action={})

    def bias_for(self, action: Action) -> float:
        return self.per_action.get(action, 0.0)


def build_bias_table(attributions: Iterable[SignedAttribution]) -> BiasTable:
    """Fold a list of SignedAttribution into a per-action scalar bias."""
    agg: Dict[Action, float] = {}
    for sa in attributions:
        term = sa.signed_weight * sa.attribution.confidence * BIAS_SCALE
        agg[sa.attribution.action] = agg.get(sa.attribution.action, 0.0) + term
    return BiasTable(per_action=agg)


def apply_bias(
    scored_candidates: List[Tuple[Action, float]],
    bias: BiasTable,
) -> List[Tuple[Action, float]]:
    """Add the per-action bias to each (action, raw_score) pair.

    Preserves input order. The driver sorts downstream.
    """
    return [(a, s + bias.bias_for(a)) for (a, s) in scored_candidates]
