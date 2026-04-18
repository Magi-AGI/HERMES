"""Human-readable reasoning trace for an episode.

Purpose: the paper needs an *explanation-trace exhibit* — a chain of
"action chosen -> because HERMES attributed this effect in episode N-1 -> world
responded with this delta". This module renders exactly that from the artifacts
the driver already produces (EpisodeResult + optional prior BiasTable /
attributions).

Kept separate from driver.py so the driver stays focused on the control loop;
this module is pure formatting and is safe to call post-hoc on saved artifacts.
"""
from __future__ import annotations

from typing import Iterable, List, Optional

from hermes.atoms import Action
from hermes.attribute import SignedAttribution
from hermes.experiments.ledgerpg.bias import BIAS_SCALE, BiasTable
from hermes.experiments.ledgerpg.driver import EpisodeResult


def _fmt_action(a: Action) -> str:
    if not a.args:
        return a.name
    return f"{a.name}({', '.join(a.args)})"


def _supporting_attributions(
    prior: Iterable[SignedAttribution], action: Action
) -> List[SignedAttribution]:
    return [sa for sa in prior if sa.attribution.action == action]


def format_step(
    step_index: int,
    action: Action,
    links_dsts: List[str],
    sat_delta_strs: List[str],
    prior_attributions: Optional[Iterable[SignedAttribution]] = None,
    bias: Optional[BiasTable] = None,
) -> str:
    lines = [f"Step {step_index}: {_fmt_action(action)} chosen."]

    if bias is not None:
        b = bias.bias_for(action)
        if abs(b) > 1e-9:
            lines.append(f"  Bias applied: {b:+.3f} (scale={BIAS_SCALE:g})")

    if prior_attributions is not None:
        supporting = _supporting_attributions(prior_attributions, action)
        for sa in supporting:
            atom = sa.attribution
            lines.append(
                f"  Basis: (Attribution {_fmt_action(atom.action)} {atom.goal} "
                f"lag={atom.lag} signed_weight={sa.signed_weight:+.3f} "
                f"confidence={atom.confidence:.2f})"
            )

    for dst in links_dsts:
        lines.append(f"  Effect: {dst}")
    for sd in sat_delta_strs:
        lines.append(f"  {sd}")

    return "\n".join(lines)


def format_episode(
    result: EpisodeResult,
    prior_attributions: Optional[Iterable[SignedAttribution]] = None,
    bias: Optional[BiasTable] = None,
) -> str:
    """Render a complete episode as a reasoning trace.

    `prior_attributions` and `bias` are what this episode was *conditioned on*
    (typically from episode N-1). Pass None for the baseline episode.
    """
    header = [
        f"=== Episode {result.episode_id} (seed={result.seed}) ===",
        f"steps={result.steps_taken} terminal={result.terminal_reason} success={result.success}",
    ]
    if prior_attributions is None and bias is None:
        header.append("condition: MAGUS-alone (no prior attributions)")
    else:
        header.append("condition: MAGUS+HERMES-feedback")

    body: List[str] = []
    for t, action, links, sat_deltas in result.episode_atoms.steps:
        link_dsts = [link.dst for link in links]
        sat_strs = [
            f"SatisfactionDelta {sd.goal} {sd.delta:+.3f}" for sd in sat_deltas
        ]
        body.append(
            format_step(
                step_index=t,
                action=action,
                links_dsts=link_dsts,
                sat_delta_strs=sat_strs,
                prior_attributions=prior_attributions,
                bias=bias,
            )
        )

    footer = ["--- End-of-episode attributions ---"]
    for sa in result.attributions:
        atom = sa.attribution
        footer.append(
            f"  (Attribution {_fmt_action(atom.action)} {atom.goal} "
            f"lag={atom.lag} signed_weight={sa.signed_weight:+.3f} "
            f"confidence={atom.confidence:.2f})"
        )

    return "\n".join(header + [""] + body + [""] + footer)
