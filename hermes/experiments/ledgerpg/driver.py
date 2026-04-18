"""LedgeRPG episode driver — the paper's per-episode orchestrator.

Runs one episode against a LedgeRPG server:

1. POST /episode/start
2. loop: observe -> enumerate valid actions -> score -> apply HERMES bias -> pick -> step
3. POST /episode/end
4. ingest the full trace into HERMES atoms and compute attributions
5. return an EpisodeResult that the next episode consumes for its bias table

The feedback loop is strictly episode-level, per project scope.
"""
from __future__ import annotations

import hashlib
from dataclasses import dataclass, field
from typing import Any, Dict, Iterable, List, Optional, Protocol, Tuple

from hermes.atoms import Action
from hermes.attribute import (
    SignedAttribution,
    compute_attributions,
    filter_by_min_confidence,
    group_mean_center_attributions,
)
from hermes.experiments.ledgerpg.bias import BiasTable, apply_bias, build_bias_table
from hermes.experiments.ledgerpg.client import LedgeRPGClient, StartConfig
from hermes.experiments.ledgerpg.scoring import MagusScorer, Observation
from hermes.ingest import EpisodeAtoms, events_to_atoms


AGGREGATION_MODES = ("none", "group_mean", "group_mean_filtered")
DEFAULT_MIN_CONFIDENCE = 0.4


def _aggregate_for_feedback(
    attributions: List[SignedAttribution],
    mode: str,
    min_confidence: float = DEFAULT_MIN_CONFIDENCE,
) -> List[SignedAttribution]:
    """Apply the chosen aggregation transform before feeding to the next episode.

    Modes:
      - ``none``: pass-through (legacy behavior, winner-amplification baseline).
      - ``group_mean``: subtract per-(goal, lag) mean signed_weight.
      - ``group_mean_filtered``: group-mean centering + drop low-confidence pairs.
    """
    if mode == "none":
        return list(attributions)
    if mode == "group_mean":
        return group_mean_center_attributions(attributions)
    if mode == "group_mean_filtered":
        filtered = filter_by_min_confidence(attributions, min_confidence)
        return group_mean_center_attributions(filtered)
    raise ValueError(
        f"unknown aggregation mode: {mode!r}; expected one of {AGGREGATION_MODES}"
    )


@dataclass
class EpisodeResult:
    episode_id: str
    seed: int
    steps_taken: int
    terminal_reason: str
    success: bool
    episode_atoms: EpisodeAtoms
    attributions: List[SignedAttribution]
    raw_events: List[Dict[str, Any]] = field(default_factory=list)


def _observation_from_trace(trace: Dict[str, Any], food_initial: int) -> Observation:
    state = trace.get("state", {})
    agent = state.get("agent", {})
    tile = state.get("tile", {})
    return Observation(
        position=(int(agent.get("q", 0)), int(agent.get("r", 0))),
        energy=float(agent.get("energy", 1.0)),
        visited_count=int(state.get("visited_count", 0)),
        food_remaining=int(state.get("food_remaining", 0)),
        food_initial=food_initial,
        last_tile_type=str(tile.get("type", "empty")),
        goals=dict(trace.get("goals", {})),
        valid_actions=tuple(trace.get("valid_actions", [])),
    )


def _tiebreak_key(seed: int, step_index: int, action: Action) -> int:
    """Seed+step-deterministic hash over action identity.

    Spreads ties across actions rather than collapsing them lexically onto the
    alphabetically-first action ('examine' or 'move-N'). Same (seed, step)
    always produces the same ordering across runs — the paired comparison
    stays deterministic while the adapter's degenerate ties no longer lock
    the agent into one action forever.
    """
    key = f"{seed}:{step_index}:{action.name}:{','.join(action.args)}"
    return int.from_bytes(hashlib.sha256(key.encode()).digest()[:8], "big")


def _pick_best(
    scored: List[Tuple[Action, float]],
    seed: int,
    step_index: int,
) -> Action:
    """Pick the top-scoring action; deterministic hash tiebreak on exact ties."""
    scored_sorted = sorted(
        scored,
        key=lambda x: (-x[1], _tiebreak_key(seed, step_index, x[0])),
    )
    return scored_sorted[0][0]


def run_episode(
    client: LedgeRPGClient,
    scorer: MagusScorer,
    seed: int,
    bias: Optional[BiasTable] = None,
    start_cfg: Optional[StartConfig] = None,
) -> EpisodeResult:
    cfg = start_cfg or StartConfig(seed=seed)
    bias_table = bias or BiasTable.zero()

    start_resp = client.start_episode(cfg)
    episode_id = start_resp["episode_id"]

    events: List[Dict[str, Any]] = []
    terminal_reason: Optional[str] = None
    success = False
    steps_taken = 0

    # We also need the initial-step trace. The spec says /episode/start returns
    # state + goals but NOT a trace; the first trace appears after the first step.
    # So we seed an "initial observation" from the start response.
    initial_state = start_resp.get("state", {})
    initial_goals = start_resp.get("goals", {})
    obs = Observation(
        position=(
            int(initial_state.get("agent_position", [0, 0])[0]),
            int(initial_state.get("agent_position", [0, 0])[1]),
        ),
        energy=float(initial_state.get("energy", 1.0)),
        visited_count=int(initial_state.get("visited_count", 0)),
        food_remaining=cfg.food_count,
        food_initial=cfg.food_count,
        last_tile_type=str(initial_state.get("last_tile_type", "empty")),
        goals=dict(initial_goals),
        # Valid actions are a fixed 8-action set per the LedgeRPG spec.
        valid_actions=(
            "move-N", "move-NE", "move-SE", "move-S", "move-SW", "move-NW",
            "examine", "rest",
        ),
    )

    while True:
        candidates = [Action(name=name) for name in obs.valid_actions]
        raw_scored = scorer.score(obs, candidates)
        biased = apply_bias(raw_scored, bias_table)
        chosen = _pick_best(biased, seed=seed, step_index=steps_taken)

        resp = client.step(episode_id, chosen.name)
        trace = resp["trace"]
        events.append(trace)
        steps_taken += 1

        if resp.get("done"):
            terminal_reason = resp.get("terminal_reason") or "unknown"
            success = bool(resp.get("success", False))
            break

        obs = _observation_from_trace(trace, food_initial=cfg.food_count)

    client.end_episode(episode_id)

    episode_atoms = events_to_atoms(
        episode_id=episode_id,
        events=events,
        initial_goals=dict(initial_goals),
        terminal_reason=terminal_reason,
        success=success,
    )
    attributions = compute_attributions(episode_atoms)

    return EpisodeResult(
        episode_id=episode_id,
        seed=seed,
        steps_taken=steps_taken,
        terminal_reason=terminal_reason or "unknown",
        success=success,
        episode_atoms=episode_atoms,
        attributions=attributions,
        raw_events=events,
    )


def run_paired_comparison(
    client: LedgeRPGClient,
    scorer: MagusScorer,
    seed: int,
) -> Tuple[EpisodeResult, EpisodeResult]:
    """The paper's per-seed comparison (Option A: Python-side bias).

    Condition A (MAGUS-alone): empty bias table.
    Condition B (MAGUS+HERMES-feedback): bias table built from a prior MAGUS-alone
    run on the same seed. This keeps world-state identical across conditions
    while isolating the HERMES contribution.
    """
    baseline = run_episode(client, scorer, seed=seed, bias=BiasTable.zero())
    bias_table = build_bias_table(baseline.attributions)
    feedback = run_episode(client, scorer, seed=seed, bias=bias_table)
    return baseline, feedback


class HyperonScorerProto(MagusScorer, Protocol):
    def update_attributions(self, attributions: Iterable[SignedAttribution]) -> None: ...


def run_paired_comparison_hyperon(
    client: LedgeRPGClient,
    scorer: HyperonScorerProto,
    seed: int,
    aggregation: str = "none",
    min_confidence: float = DEFAULT_MIN_CONFIDENCE,
    start_cfg: Optional[StartConfig] = None,
) -> Tuple[EpisodeResult, EpisodeResult]:
    """Per-seed comparison for Option B (attributions injected into MAGUS).

    HyperonScorer exposes ``update_attributions(...)`` so MAGUS reads HERMES
    state from its own MeTTa working memory. Python-side ``apply_bias`` must
    stay empty here or the bonus would double-count.

    Condition A: empty attribution space.
    Condition B: attribution space populated from baseline's attributions,
    same seed, same bias-free driver. ``aggregation`` selects the transform
    applied between the two conditions (see ``_aggregate_for_feedback``).
    """
    def _cfg(s: int) -> StartConfig:
        if start_cfg is None:
            return StartConfig(seed=s)
        return StartConfig(
            seed=s,
            grid_size=start_cfg.grid_size,
            step_limit=start_cfg.step_limit,
            food_count=start_cfg.food_count,
            obstacle_count=start_cfg.obstacle_count,
        )

    scorer.update_attributions([])
    baseline = run_episode(
        client, scorer, seed=seed, bias=BiasTable.zero(), start_cfg=_cfg(seed)
    )
    feedback_attrs = _aggregate_for_feedback(
        baseline.attributions, aggregation, min_confidence=min_confidence
    )
    scorer.update_attributions(feedback_attrs)
    feedback = run_episode(
        client, scorer, seed=seed, bias=BiasTable.zero(), start_cfg=_cfg(seed)
    )
    scorer.update_attributions([])
    return baseline, feedback
