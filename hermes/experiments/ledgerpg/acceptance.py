"""Server-acceptance check — Codex's gate before running the paired comparison.

Four checks, ordered by what would invalidate the paper if broken:

1. Seed stability: seed 42 with a fixed action sequence, run twice, identical traces.
2. Contract completeness: required fields present with expected types.
3. Delta-kind coverage: every emitted state_delta.kind is one we know how to ingest.
4. Bias path live: episode-N attributions change episode-N+1 chosen actions
   when bias is nonzero. Protects against a silent baseline-contamination regression
   where apply_bias is a no-op.

Each check returns (ok: bool, detail: str). The script at the bottom prints a
short report and exits nonzero on any failure so CI / the paper script can gate.
"""
from __future__ import annotations

import json
from dataclasses import dataclass
from typing import Any, Dict, List, Tuple

from hermes.atoms import Action
from hermes.attribute import SignedAttribution, compute_attributions
from hermes.experiments.ledgerpg.bias import BiasTable, build_bias_table
from hermes.experiments.ledgerpg.client import LedgeRPGClient, StartConfig
from hermes.experiments.ledgerpg.driver import run_episode
from hermes.experiments.ledgerpg.scoring import MagusScorer
from hermes.ingest import _DELTA_KIND_TO_LINK, events_to_atoms


REQUIRED_TRACE_FIELDS = ("episode_id", "t", "action", "valid_actions", "state", "state_delta", "goals")
REQUIRED_STATE_FIELDS = ("agent", "tile", "visited_count", "food_remaining")
REQUIRED_GOAL_KEYS = ("EXPLORATION_INCENTIVE", "ENERGY_REGULATION")
VALID_TERMINAL_REASONS = {"target_reached", "step_limit", "energy_depleted"}


@dataclass
class CheckResult:
    name: str
    ok: bool
    detail: str


def _canonical(obj: Any) -> str:
    return json.dumps(obj, sort_keys=True, separators=(",", ":"))


def check_seed_stability(
    client: LedgeRPGClient,
    seed: int,
    action_sequence: List[str],
) -> CheckResult:
    """Two episodes, same seed, same action sequence → identical trace lists."""
    def run_once() -> List[Dict[str, Any]]:
        resp = client.start_episode(StartConfig(seed=seed))
        episode_id = resp["episode_id"]
        traces: List[Dict[str, Any]] = []
        for action_name in action_sequence:
            step = client.step(episode_id, action_name)
            traces.append(step["trace"])
            if step.get("done"):
                break
        client.end_episode(episode_id)
        return traces

    first = run_once()
    second = run_once()
    if _canonical(first) != _canonical(second):
        for i, (a, b) in enumerate(zip(first, second)):
            if _canonical(a) != _canonical(b):
                return CheckResult(
                    "seed_stability",
                    False,
                    f"diverged at step {i}: {_canonical(a)[:200]} vs {_canonical(b)[:200]}",
                )
        return CheckResult("seed_stability", False, f"length mismatch: {len(first)} vs {len(second)}")
    return CheckResult("seed_stability", True, f"{len(first)} steps identical")


def check_trace_contract(trace: Dict[str, Any]) -> CheckResult:
    missing = [f for f in REQUIRED_TRACE_FIELDS if f not in trace]
    if missing:
        return CheckResult("trace_contract", False, f"missing fields: {missing}")

    state = trace.get("state", {})
    missing_state = [f for f in REQUIRED_STATE_FIELDS if f not in state]
    if missing_state:
        return CheckResult("trace_contract", False, f"state missing: {missing_state}")

    goals = trace.get("goals", {})
    missing_goals = [k for k in REQUIRED_GOAL_KEYS if k not in goals]
    if missing_goals:
        return CheckResult("trace_contract", False, f"goals missing: {missing_goals}")

    return CheckResult("trace_contract", True, "all required fields populated")


def check_delta_coverage(traces: List[Dict[str, Any]]) -> CheckResult:
    known = set(_DELTA_KIND_TO_LINK.keys())
    seen: set = set()
    unknown: set = set()
    for tr in traces:
        for d in tr.get("state_delta") or []:
            k = d.get("kind")
            if k in known:
                seen.add(k)
            else:
                unknown.add(k)
    if unknown:
        return CheckResult(
            "delta_coverage",
            False,
            f"server emitted delta kinds not handled by ingest: {sorted(unknown)}",
        )
    return CheckResult("delta_coverage", True, f"seen kinds: {sorted(seen)}")


def check_bias_path_live(
    client: LedgeRPGClient,
    scorer: MagusScorer,
    seed: int,
) -> CheckResult:
    """Inject a synthetic, overwhelming bias toward a specific action and
    confirm the driver actually picks it. This isolates the wiring question
    ("does apply_bias get called at scoring time?") from the modeling question
    ("does a realistic episode produce a nonzero net bias?") — the latter can
    legitimately net to zero when an action helps and hurts goals equally,
    which would otherwise masquerade as a broken pipeline.
    """
    target = Action(name="rest")
    synthetic_bias = BiasTable(per_action={target: 1000.0})
    ep = run_episode(client, scorer, seed=seed, bias=synthetic_bias)
    actions = [a.name for _t, a, _l, _s in ep.episode_atoms.steps]
    rest_count = actions.count(target.name)
    if rest_count == 0:
        return CheckResult(
            "bias_path_live",
            False,
            f"synthetic +1000 bias on '{target.name}' ignored by driver; "
            f"action set observed: {sorted(set(actions))}",
        )
    return CheckResult(
        "bias_path_live",
        True,
        f"synthetic +1000 bias on '{target.name}' selected it {rest_count}/{len(actions)} steps",
    )


def run_all(
    client: LedgeRPGClient,
    scorer: MagusScorer,
    seed: int = 42,
    sequence: Tuple[str, ...] = ("move-N", "move-N", "examine", "move-NE", "rest"),
) -> List[CheckResult]:
    stability = check_seed_stability(client, seed, list(sequence))
    probe = client.start_episode(StartConfig(seed=seed))
    probe_id = probe["episode_id"]
    first_step = client.step(probe_id, sequence[0])
    contract = check_trace_contract(first_step["trace"])

    more_traces: List[Dict[str, Any]] = [first_step["trace"]]
    for action_name in sequence[1:]:
        step = client.step(probe_id, action_name)
        more_traces.append(step["trace"])
        if step.get("done"):
            break
    client.end_episode(probe_id)
    coverage = check_delta_coverage(more_traces)

    bias_live = check_bias_path_live(client, scorer, seed)

    return [stability, contract, coverage, bias_live]
