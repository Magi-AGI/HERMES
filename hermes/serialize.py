"""Atoms → MeTTa S-expression text.

Used by the paper's qualitative trace output: one episode's atoms are written
to a single .metta file that a reader can inspect or feed to Hyperon.
"""
from __future__ import annotations

from typing import Iterable, List

from hermes.atoms import Attribution, CausalLink, SatisfactionDelta
from hermes.attribute import SignedAttribution
from hermes.ingest import EpisodeAtoms


def episode_to_metta_lines(
    episode: EpisodeAtoms,
    attributions: Iterable[SignedAttribution],
) -> List[str]:
    lines: List[str] = []
    lines.append(f"; episode {episode.episode_id}")
    if episode.terminal_reason is not None:
        lines.append(
            f"; terminal_reason={episode.terminal_reason} success={str(episode.success).lower()}"
        )

    for t, action, links, sat_deltas in episode.steps:
        lines.append(f"; step {t} action={action.as_sexpr()}")
        for link in links:
            lines.append(link.as_sexpr())
        for sd in sat_deltas:
            lines.append(sd.as_sexpr())

    lines.append("; episode-level attributions")
    for sa in attributions:
        lines.append(sa.attribution.as_sexpr())
    return lines


def write_episode_metta(
    path: str,
    episode: EpisodeAtoms,
    attributions: Iterable[SignedAttribution],
) -> None:
    lines = episode_to_metta_lines(episode, attributions)
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
