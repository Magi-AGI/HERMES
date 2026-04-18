"""HyperonScorer — the paper's real MAGUS scorer for LedgeRPG.

Loads MAGUS Scoring v2 + the LedgeRPG adapter into a Hyperon MeTTa interpreter
and invokes `score-decision-v2-hermes` once per candidate action. The adapter
owns the HERMES-attribution hook, so attributions are symbolically visible to
MAGUS during scoring (Option B from the adapter-design discussion).

Responsibilities:

- Initialize MAGUS once, load MeTTa files in the canonical order
  (the `!(load ...)` directives inside the files are bypassed — we load
  everything explicitly via `metta.run(file_contents)`).
- Publish per-step live goal values into `&ledgerpg-goal-state` (rebinds
  the space each call so stale values don't leak).
- Publish per-episode HERMES attributions into `&ledgerpg-attribution-space`
  via `update_attributions(...)`, typically called once between episodes.
- Per candidate: invoke `score-decision-v2-hermes` and parse the returned
  5-field `DecisionScore`. Also exposes a `score_with_decomposition` variant
  returning the 6-tuple (base, meta, over, anti, hermes, final) via the
  adapter's breakdown function — for Codex's per-step audit logging.

Intentionally NOT used:

- `rank-decisions` in stock MAGUS — we rank Python-side so the driver's
  deterministic tiebreak rule remains the single source of ordering truth.
"""
from __future__ import annotations

import sys
from pathlib import Path
from typing import Iterable, List, Optional, Tuple

from hermes.atoms import Action
from hermes.attribute import SignedAttribution
from hermes.experiments.ledgerpg.scoring import Observation


DEFAULT_MAGUS_ROOT = Path("E:/GitHub/Magi-AGI/MAGUS")
DEFAULT_ADAPTER_PATH = Path(__file__).parent / "ledgerpg_magus.metta"


def _canonical_magus_load_order(magus_root: Path) -> List[Path]:
    return [
        magus_root / "types.metta",
        magus_root / "Milestone_2/goal-fitness-metrics/measurability/initial_measurability_calculation.metta",
        magus_root / "Milestone_2/goal-fitness-metrics/correlation/initial_correlation_calculation.metta",
        magus_root / "Milestone_3/core/metagoals.metta",
        magus_root / "Milestone_3/core/antigoals.metta",
        magus_root / "Milestone_3/core/overgoal.metta",
        magus_root / "Milestone_3/core/scoring-v2.metta",
    ]


class Decomposition:
    """Flat score breakdown per candidate, matching the adapter's breakdown atom."""

    __slots__ = ("base", "metagoal", "overgoal", "antigoal", "hermes", "final")

    def __init__(self, base: float, metagoal: float, overgoal: float,
                 antigoal: float, hermes: float, final: float) -> None:
        self.base = base
        self.metagoal = metagoal
        self.overgoal = overgoal
        self.antigoal = antigoal
        self.hermes = hermes
        self.final = final

    def as_dict(self) -> dict:
        return {
            "base": self.base,
            "metagoal": self.metagoal,
            "overgoal": self.overgoal,
            "antigoal": self.antigoal,
            "hermes": self.hermes,
            "final": self.final,
        }


class HyperonScorer:
    def __init__(
        self,
        magus_root: Optional[Path] = None,
        adapter_path: Optional[Path] = None,
    ) -> None:
        magus_root = Path(magus_root) if magus_root else DEFAULT_MAGUS_ROOT
        adapter_path = Path(adapter_path) if adapter_path else DEFAULT_ADAPTER_PATH

        if str(magus_root) not in sys.path:
            sys.path.insert(0, str(magus_root))
        # magus_init lives at the MAGUS repo root.
        from magus_init import initialize_magus  # type: ignore

        self.metta = initialize_magus()

        for module in _canonical_magus_load_order(magus_root) + [adapter_path]:
            if not module.exists():
                raise FileNotFoundError(f"required MeTTa module missing: {module}")
            with open(module, "r", encoding="utf-8") as fh:
                self.metta.run(fh.read())

        self._adapter_path = adapter_path
        self._magus_root = magus_root

    def update_attributions(self, attributions: Iterable[SignedAttribution]) -> None:
        """Replace the contents of &ledgerpg-attribution-space.

        Called once between episodes with the prior-episode attributions, or
        with an empty iterable for the MAGUS-alone baseline.

        Hyperon 0.2.10 quirk: `!(bind! &s (new-space))` does NOT clear atoms
        from an already-bound space. We clear explicitly via match + remove-atom.
        """
        self.metta.run(
            "!(match &ledgerpg-attribution-space "
            "(attribution $a $g $l $w $c) "
            "(remove-atom &ledgerpg-attribution-space "
            "(attribution $a $g $l $w $c)))"
        )
        for sa in attributions:
            atom_str = self._attribution_to_metta(sa)
            self.metta.run(f"!(add-atom &ledgerpg-attribution-space {atom_str})")

    def score(
        self,
        obs: Observation,
        candidates: List[Action],
    ) -> List[Tuple[Action, float]]:
        self._publish_goal_state(obs.goals)
        self._publish_context(obs)
        out: List[Tuple[Action, float]] = []
        for a in candidates:
            final = self._score_candidate_final(a)
            out.append((a, final))
        return out

    def score_with_decomposition(
        self,
        obs: Observation,
        candidates: List[Action],
    ) -> List[Tuple[Action, Decomposition]]:
        """Full per-candidate 6-tuple (base, meta, over, anti, hermes, final).

        Useful for the paper's per-step audit log and for the parity harness.
        """
        self._publish_goal_state(obs.goals)
        self._publish_context(obs)
        out: List[Tuple[Action, Decomposition]] = []
        for a in candidates:
            decomp = self._score_candidate_decomposition(a)
            out.append((a, decomp))
        return out

    # -- internal --

    def _publish_goal_state(self, goals: dict) -> None:
        # Hyperon 0.2.10: bind!+new-space doesn't clear; remove prior atoms first.
        self.metta.run(
            "!(match &ledgerpg-goal-state (goal-value $n $v) "
            "(remove-atom &ledgerpg-goal-state (goal-value $n $v)))"
        )
        for name, value in goals.items():
            self.metta.run(
                f"!(add-atom &ledgerpg-goal-state (goal-value {name} {float(value)}))"
            )

    def _publish_context(self, obs: Observation) -> None:
        """Publish per-step context (tile-type, visited_count) into the adapter space.

        Lives in the same knowledge base as goal-values so the adapter's antigoals
        can pattern-match on it alongside goal state.
        """
        self.metta.run(
            "!(match &ledgerpg-goal-state (tile-type $t) "
            "(remove-atom &ledgerpg-goal-state (tile-type $t)))"
        )
        self.metta.run(
            "!(match &ledgerpg-goal-state (visited-count $v) "
            "(remove-atom &ledgerpg-goal-state (visited-count $v)))"
        )
        self.metta.run(
            f"!(add-atom &ledgerpg-goal-state (tile-type {obs.last_tile_type}))"
        )
        self.metta.run(
            f"!(add-atom &ledgerpg-goal-state (visited-count {int(obs.visited_count)}))"
        )

    def _candidate_expr(self, action: Action) -> str:
        args = " ".join(action.args) if action.args else ""
        params = f"({args})" if args else "()"
        return f"(action-candidate (action {action.name} {params}))"

    def _scoring_call(self, fn: str, action: Action) -> str:
        cand = self._candidate_expr(action)
        return (
            f"!({fn} {cand} (ledgerpg-considerations) (ledgerpg-discouragements) "
            f"(ledgerpg-metagoals) (ledgerpg-antigoals) "
            f"(scoring-context (ledgerpg-goals) Nil 0))"
        )

    def _score_candidate_final(self, action: Action) -> float:
        result = self.metta.run(self._scoring_call("score-decision-v2-hermes", action))
        atom = self._single_result_atom(result, action)
        children = atom.get_children()
        if len(children) != 6:
            raise RuntimeError(
                f"expected (decision-score b m o a f), got {len(children)} children: {atom}"
            )
        return float(str(children[5]))

    def _score_candidate_decomposition(self, action: Action) -> Decomposition:
        result = self.metta.run(
            self._scoring_call("score-decision-v2-hermes-breakdown", action)
        )
        atom = self._single_result_atom(result, action)
        children = atom.get_children()
        if len(children) != 7:
            raise RuntimeError(
                f"expected (breakdown b m o a h f), got {len(children)} children: {atom}"
            )
        return Decomposition(
            base=float(str(children[1])),
            metagoal=float(str(children[2])),
            overgoal=float(str(children[3])),
            antigoal=float(str(children[4])),
            hermes=float(str(children[5])),
            final=float(str(children[6])),
        )

    @staticmethod
    def _single_result_atom(result, action: Action):
        if not result or not result[0]:
            raise RuntimeError(f"scoring returned empty result for {action.name}")
        atoms = result[0]
        if len(atoms) > 1:
            # Log and keep the first — all should be identical in steady state.
            # Raise instead if this ever disagrees, to fail fast during development.
            first_str = str(atoms[0])
            for other in atoms[1:]:
                if str(other) != first_str:
                    raise RuntimeError(
                        f"non-deterministic scoring for {action.name}: got {atoms}"
                    )
        return atoms[0]

    @staticmethod
    def _attribution_to_metta(sa: SignedAttribution) -> str:
        atom = sa.attribution
        action_name = atom.action.name
        return (
            f"(attribution {action_name} {atom.goal} {int(atom.lag)} "
            f"{float(sa.signed_weight)} {float(atom.confidence)})"
        )
