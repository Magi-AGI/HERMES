"""HERMES — Hypergraph Experiential Reasoning and Motivational Engagement System.

Paper-scope MVP: ingest game-server traces, compute episode-level attributions,
and feed them back as scoring bias for the next episode. No online updates,
no pattern miner, no MORK persistence.
"""
from hermes.atoms import Action, Attribution, CausalLink, SatisfactionDelta
from hermes.ingest import EpisodeAtoms, events_to_atoms
from hermes.attribute import compute_attributions

__all__ = [
    "Action",
    "Attribution",
    "CausalLink",
    "SatisfactionDelta",
    "EpisodeAtoms",
    "events_to_atoms",
    "compute_attributions",
]
