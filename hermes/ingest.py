"""Trace event → atoms.

One trace event (the `trace` object in the LedgeRPG server response) becomes:
- zero or more CausalLink atoms (one per state_delta kind)
- zero or more SatisfactionDelta atoms (one per goal whose value changed from the prior step)

Episode-level Attribution atoms are computed separately in hermes.attribute.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any, Dict, List, Optional, Tuple

from hermes.atoms import Action, CausalLink, SatisfactionDelta


@dataclass
class EpisodeAtoms:
    """Per-step atoms for a full episode, kept in trace order.

    - steps: list of (step_index, action, causal_links, satisfaction_deltas)
    - goal_trajectory: (len(steps) + 1) goal snapshots. Index 0 is the pre-episode
      initial_goals (empty dict if unknown); index i >= 1 is post-step-(i-1) goals.
      This lets attribute.py compute lag=1 credit as trajectory[i] - trajectory[i-1]
      for action at steps[i-1] without special-casing the first step.
    - terminal_reason: the final termination enum, if the episode ended
    """

    episode_id: str
    steps: List[Tuple[int, Action, List[CausalLink], List[SatisfactionDelta]]] = field(
        default_factory=list
    )
    goal_trajectory: List[Dict[str, float]] = field(default_factory=list)
    terminal_reason: Optional[str] = None
    success: bool = False


def _fmt_coord(coord) -> str:
    if isinstance(coord, (list, tuple)) and len(coord) == 2:
        return f"({coord[0]} {coord[1]})"
    return str(coord)


def _position_link(action: Action, delta: Dict[str, Any]) -> CausalLink:
    to = _fmt_coord(delta.get("to"))
    return CausalLink(src=action.as_sexpr(), dst=f"(agent-at {to})")


def _energy_link(action: Action, delta: Dict[str, Any]) -> CausalLink:
    d = delta.get("delta", 0.0)
    direction = "decreased" if d < 0 else "increased"
    return CausalLink(
        src=action.as_sexpr(),
        dst=f"(energy {direction} {abs(d):.3f})",
    )


def _tile_discovered_link(action: Action, delta: Dict[str, Any]) -> CausalLink:
    at = _fmt_coord(delta.get("at"))
    return CausalLink(src=action.as_sexpr(), dst=f"(tile-discovered {at})")


def _food_consumed_link(action: Action, delta: Dict[str, Any]) -> CausalLink:
    at = _fmt_coord(delta.get("at"))
    return CausalLink(src=action.as_sexpr(), dst=f"(food-consumed {at})")


def _movement_blocked_link(action: Action, delta: Dict[str, Any]) -> CausalLink:
    return CausalLink(src=action.as_sexpr(), dst="(movement-blocked)")


# Wire the lookup table after all helpers are defined.
_DELTA_KIND_TO_LINK = {
    "position": _position_link,
    "energy": _energy_link,
    "tile-discovered": _tile_discovered_link,
    "food-consumed": _food_consumed_link,
    "movement-blocked": _movement_blocked_link,
}


def _action_from_event(event_action: Dict[str, Any]) -> Action:
    name = event_action.get("name", "unknown")
    raw_args = event_action.get("args") or {}
    arg_values = tuple(str(v) for v in raw_args.values()) if isinstance(raw_args, dict) else ()
    return Action(name=name, args=arg_values)


def events_to_atoms(
    episode_id: str,
    events: List[Dict[str, Any]],
    initial_goals: Optional[Dict[str, float]] = None,
    terminal_reason: Optional[str] = None,
    success: bool = False,
) -> EpisodeAtoms:
    """Convert a list of per-step LedgeRPG trace events into an EpisodeAtoms record.

    Expects each event to be the `trace` object from the LedgeRPG server's
    `/episode/step` response. Events must be in temporal order.

    `initial_goals` is the pre-episode goal snapshot returned by /episode/start.
    Pass it so attribution can credit the first step; if omitted, the first
    step's SatisfactionDelta atoms will be empty and its attributions skipped.
    """
    out = EpisodeAtoms(
        episode_id=episode_id,
        terminal_reason=terminal_reason,
        success=success,
    )
    baseline = dict(initial_goals) if initial_goals is not None else {}
    out.goal_trajectory.append(baseline)
    prev_goals: Dict[str, float] = baseline

    for ev in events:
        t = int(ev.get("t", len(out.steps)))
        action = _action_from_event(ev.get("action", {}))
        deltas = ev.get("state_delta") or []
        goals = dict(ev.get("goals") or {})

        links: List[CausalLink] = []
        for d in deltas:
            kind = d.get("kind")
            builder = _DELTA_KIND_TO_LINK.get(kind)
            if builder is None:
                continue
            links.append(builder(action, d))

        sat_deltas: List[SatisfactionDelta] = []
        for g, v in goals.items():
            p = prev_goals.get(g)
            if p is None:
                continue
            dv = float(v) - float(p)
            if abs(dv) > 1e-9:
                sat_deltas.append(SatisfactionDelta(goal=g, delta=dv))

        out.steps.append((t, action, links, sat_deltas))
        out.goal_trajectory.append(goals)
        prev_goals = goals

    return out
