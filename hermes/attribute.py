"""Episode-level attribution.

For the paper MVP this implements a simple, deterministic, lag=1 credit
assignment: the action at step t is held responsible for the goal-value change
between step t and step t+1. Across the episode, per (action, goal) pair we
compute:

- weight:    sum of signed deltas attributable to (action, goal),
             normalized by the sum of abs deltas for that goal → clipped to [-1, 1].
             We then map to [0, 1] at output time for the canonical Attribution atom
             and record the sign separately on a companion field.
- confidence: a simple observation-count heuristic
             min(1.0, n_observations / CONFIDENCE_SATURATION).

This is intentionally small. Richer credit assignment (eligibility traces,
lag inference, calibrated confidence) is deferred per project scope.
"""
from __future__ import annotations

from collections import defaultdict
from dataclasses import dataclass
from typing import Dict, List, Tuple

from hermes.atoms import Action, Attribution
from hermes.ingest import EpisodeAtoms


CONFIDENCE_SATURATION = 5.0
FIXED_LAG = 1


@dataclass(frozen=True)
class SignedAttribution:
    """Attribution plus the sign of the effect, for driver-side bias lookup.

    The canonical Attribution atom emitted to MeTTa keeps `weight` in [0, 1].
    Downstream code that needs to distinguish beneficial from harmful actions
    uses `signed_weight` from this wrapper.
    """

    attribution: Attribution
    signed_weight: float


def compute_attributions(episode: EpisodeAtoms) -> List[SignedAttribution]:
    """Compute one Attribution per (action, goal) pair observed in the episode.

    Returns SignedAttribution records so the driver can distinguish positive
    from negative contributions. The inner .attribution field carries the
    canonical [0, 1] weight for MeTTa serialization.
    """
    pair_delta_sum: Dict[Tuple[Action, str], float] = defaultdict(float)
    pair_counts: Dict[Tuple[Action, str], int] = defaultdict(int)
    goal_abs_totals: Dict[str, float] = defaultdict(float)

    steps = episode.steps
    trajectory = episode.goal_trajectory
    # trajectory[0] is the pre-episode baseline (empty if ingest wasn't given
    # initial_goals); trajectory[i+1] is the goal snapshot AFTER action at steps[i].
    # With lag=1 we credit action at steps[i] for trajectory[i+1] - trajectory[i].
    if len(trajectory) != len(steps) + 1:
        # Back-compat with callers that pre-date the baseline slot.
        trajectory = [{}] + list(trajectory)

    for i, (_t, action, _links, _sat_deltas) in enumerate(steps):
        prev_goals = trajectory[i]
        post_goals = trajectory[i + FIXED_LAG]
        for goal, post_v in post_goals.items():
            prev_v = prev_goals.get(goal)
            if prev_v is None:
                continue
            dv = float(post_v) - float(prev_v)
            if abs(dv) < 1e-9:
                continue
            pair_delta_sum[(action, goal)] += dv
            pair_counts[(action, goal)] += 1
            goal_abs_totals[goal] += abs(dv)

    results: List[SignedAttribution] = []
    for (action, goal), summed in pair_delta_sum.items():
        total_abs = goal_abs_totals[goal]
        if total_abs < 1e-9:
            continue
        signed = max(-1.0, min(1.0, summed / total_abs))
        n = pair_counts[(action, goal)]
        confidence = min(1.0, n / CONFIDENCE_SATURATION)
        atom = Attribution(
            action=action,
            goal=goal,
            lag=FIXED_LAG,
            weight=abs(signed),
            confidence=confidence,
        )
        results.append(SignedAttribution(attribution=atom, signed_weight=signed))

    results.sort(
        key=lambda sa: (sa.attribution.action.name, sa.attribution.action.args, sa.attribution.goal)
    )
    return results


def group_mean_center_attributions(
    attributions: List[SignedAttribution],
) -> List[SignedAttribution]:
    """Subtract per-(goal, lag) mean signed_weight across contributing actions.

    The single-episode linear aggregation used by `compute_attributions`
    produces attributions whose signed_weights are share-of-total-movement,
    so the sum across contributing actions for a given (goal, lag) is close
    to the sign of the net episode delta. This leaves the top-contributing
    action with a large positive bonus even when most actions moved the
    goal comparably. The result is "winner amplification": in the feedback
    episode the driver over-weights the single-episode winner, producing
    exploration concentration and wall-collision lockup (observed in the
    30-seed paired comparison, 29/30 negative uplift on EXPLORATION).

    Centering subtracts the per-group mean, so only actions that contributed
    MORE than the average to a goal get a positive bias in feedback. Actions
    tied at the mean contribute zero. The canonical (unsigned) weight in the
    Attribution atom is also re-derived as `abs(centered_signed_weight)`.
    """
    groups: Dict[Tuple[str, int], List[float]] = defaultdict(list)
    for sa in attributions:
        groups[(sa.attribution.goal, sa.attribution.lag)].append(sa.signed_weight)

    means: Dict[Tuple[str, int], float] = {
        key: (sum(vs) / len(vs)) if vs else 0.0 for key, vs in groups.items()
    }

    centered: List[SignedAttribution] = []
    for sa in attributions:
        key = (sa.attribution.goal, sa.attribution.lag)
        new_signed = sa.signed_weight - means[key]
        new_atom = Attribution(
            action=sa.attribution.action,
            goal=sa.attribution.goal,
            lag=sa.attribution.lag,
            weight=abs(new_signed),
            confidence=sa.attribution.confidence,
        )
        centered.append(SignedAttribution(attribution=new_atom, signed_weight=new_signed))
    return centered


def filter_by_min_confidence(
    attributions: List[SignedAttribution],
    min_confidence: float,
) -> List[SignedAttribution]:
    """Drop attributions whose confidence is below the threshold.

    Confidence is `min(1.0, n_observations / CONFIDENCE_SATURATION)`, so a
    threshold of 0.4 corresponds to requiring at least 2 observations of the
    (action, goal) pair in the episode. Useful for suppressing single-sample
    attributions that drove the winner-amplification failure mode.
    """
    return [
        sa for sa in attributions if sa.attribution.confidence >= min_confidence
    ]
