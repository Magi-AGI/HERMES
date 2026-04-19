"""PettaScorer — MAGUS scorer running on the PeTTa (SWI-Prolog) MeTTa backend.

Parallel to HyperonScorer: loads the petta_compat MAGUS bundle + adapter,
then invokes `score-decision-v2-hermes` / `...-breakdown` per candidate.
The purpose is speed parity evaluation: if PeTTa's Prolog core executes the
scoring path significantly faster than Hyperon while producing the same
numeric scores, we switch the paper's pipeline to PettaScorer.

Differences from HyperonScorer:
- Uses petta_compat/bundle_magus.metta (type declarations stripped; the
  PeTTa type checker rejects arrow types that reference user-defined
  non-builtin types).
- Consults petta_math_shim.pl via janus_swi so `sqrt`, `pow`, etc. are
  grounded against SWI-Prolog arithmetic.
- PeTTa returns result atoms as Python strings, so we parse the
  (decision-score ...) / (breakdown ...) atoms textually.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path
from typing import Iterable, List, Optional, Tuple

from hermes.atoms import Action
from hermes.attribute import SignedAttribution
from hermes.experiments.ledgerpg.scoring import Observation


DEFAULT_PETTA_PYTHON = Path("E:/GitHub/hyperon reference/PeTTa/python")
DEFAULT_BUNDLE_PATH = (
    Path(__file__).parent / "petta_compat" / "bundle_magus.metta"
)
DEFAULT_ADAPTER_PATH = Path(__file__).parent / "ledgerpg_magus.metta"
DEFAULT_MATH_SHIM = (
    Path(__file__).resolve().parents[3] / "tmp" / "petta_math_shim.pl"
)


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


class PettaScorer:
    def __init__(
        self,
        bundle_path: Optional[Path] = None,
        adapter_path: Optional[Path] = None,
        math_shim_path: Optional[Path] = None,
        petta_python_path: Optional[Path] = None,
    ) -> None:
        bundle_path = Path(bundle_path) if bundle_path else DEFAULT_BUNDLE_PATH
        adapter_path = Path(adapter_path) if adapter_path else DEFAULT_ADAPTER_PATH
        math_shim_path = Path(math_shim_path) if math_shim_path else DEFAULT_MATH_SHIM
        petta_python_path = Path(petta_python_path) if petta_python_path else DEFAULT_PETTA_PYTHON

        if str(petta_python_path) not in sys.path:
            sys.path.insert(0, str(petta_python_path))

        from petta import PeTTa  # type: ignore
        import janus_swi as janus  # type: ignore

        self.petta = PeTTa()

        shim = str(math_shim_path).replace("\\", "/")
        janus.consult(shim)

        for module in (bundle_path, adapter_path):
            if not module.exists():
                raise FileNotFoundError(f"required MeTTa module missing: {module}")
            self.petta.load_metta_file(str(module).replace("\\", "/"))

        self._bundle_path = bundle_path
        self._adapter_path = adapter_path

    def update_attributions(self, attributions: Iterable[SignedAttribution]) -> None:
        """Replace the contents of &ledgerpg-attribution-space."""
        self.petta.process_metta_string(
            "!(match &ledgerpg-attribution-space "
            "(attribution $a $g $l $w $c) "
            "(remove-atom &ledgerpg-attribution-space "
            "(attribution $a $g $l $w $c)))"
        )
        for sa in attributions:
            atom_str = self._attribution_to_metta(sa)
            self.petta.process_metta_string(
                f"!(add-atom &ledgerpg-attribution-space {atom_str})"
            )

    def score(
        self,
        obs: Observation,
        candidates: List[Action],
    ) -> List[Tuple[Action, float]]:
        self._publish_goal_state(self._goals_with_food_pursuit(obs))
        self._publish_context(obs)
        out: List[Tuple[Action, float]] = []
        for a in candidates:
            out.append((a, self._score_candidate_final(a)))
        return out

    def score_with_decomposition(
        self,
        obs: Observation,
        candidates: List[Action],
    ) -> List[Tuple[Action, Decomposition]]:
        self._publish_goal_state(self._goals_with_food_pursuit(obs))
        self._publish_context(obs)
        out: List[Tuple[Action, Decomposition]] = []
        for a in candidates:
            out.append((a, self._score_candidate_decomposition(a)))
        return out

    # -- internal --

    @staticmethod
    def _goals_with_food_pursuit(obs: Observation) -> dict:
        merged = dict(obs.goals)
        initial = int(getattr(obs, "food_initial", 0) or 0)
        remaining = int(obs.food_remaining)
        if initial > 0:
            sat = max(0.0, min(1.0, (initial - remaining) / initial))
        else:
            sat = 1.0
        merged["FOOD_PURSUIT"] = sat
        return merged

    def _publish_goal_state(self, goals: dict) -> None:
        self.petta.process_metta_string(
            "!(match &ledgerpg-goal-state (goal-value $n $v) "
            "(remove-atom &ledgerpg-goal-state (goal-value $n $v)))"
        )
        for name, value in goals.items():
            self.petta.process_metta_string(
                f"!(add-atom &ledgerpg-goal-state (goal-value {name} {float(value)}))"
            )

    def _publish_context(self, obs: Observation) -> None:
        self.petta.process_metta_string(
            "!(match &ledgerpg-goal-state (tile-type $t) "
            "(remove-atom &ledgerpg-goal-state (tile-type $t)))"
        )
        self.petta.process_metta_string(
            "!(match &ledgerpg-goal-state (visited-count $v) "
            "(remove-atom &ledgerpg-goal-state (visited-count $v)))"
        )
        self.petta.process_metta_string(
            f"!(add-atom &ledgerpg-goal-state (tile-type {obs.last_tile_type}))"
        )
        self.petta.process_metta_string(
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
        results = self.petta.process_metta_string(
            self._scoring_call("score-decision-v2-hermes", action)
        )
        tokens = self._single_result_tokens(results, action, head="decision-score", arity=5)
        return float(tokens[4])  # final

    def _score_candidate_decomposition(self, action: Action) -> Decomposition:
        results = self.petta.process_metta_string(
            self._scoring_call("score-decision-v2-hermes-breakdown", action)
        )
        tokens = self._single_result_tokens(results, action, head="breakdown", arity=6)
        return Decomposition(
            base=float(tokens[0]),
            metagoal=float(tokens[1]),
            overgoal=float(tokens[2]),
            antigoal=float(tokens[3]),
            hermes=float(tokens[4]),
            final=float(tokens[5]),
        )

    @staticmethod
    def _single_result_tokens(
        results, action: Action, head: str, arity: int
    ) -> List[str]:
        """Parse a single (head t0 t1 ... t{arity-1}) atom out of PeTTa's string results."""
        if not results:
            raise RuntimeError(f"scoring returned empty result for {action.name}")
        seen: List[str] = []
        for r in results:
            if r is None:
                continue
            s = str(r).strip()
            if s not in seen:
                seen.append(s)
        if not seen:
            raise RuntimeError(f"scoring returned no usable atoms for {action.name}")
        if len(seen) > 1:
            raise RuntimeError(
                f"non-deterministic scoring for {action.name}: got {seen}"
            )
        atom = seen[0]
        m = re.match(r"^\((\S+)((?:\s+[^()\s]+)+)\)$", atom)
        if not m:
            raise RuntimeError(
                f"unexpected atom shape for {action.name}: {atom!r}"
            )
        got_head = m.group(1)
        if got_head != head:
            raise RuntimeError(
                f"expected ({head} ...), got head {got_head} for {action.name}: {atom!r}"
            )
        toks = m.group(2).split()
        if len(toks) != arity:
            raise RuntimeError(
                f"expected {head} arity {arity}, got {len(toks)} for {action.name}: {atom!r}"
            )
        return toks

    @staticmethod
    def _attribution_to_metta(sa: SignedAttribution) -> str:
        atom = sa.attribution
        action_name = atom.action.name
        return (
            f"(attribution {action_name} {atom.goal} {int(atom.lag)} "
            f"{float(sa.signed_weight)} {float(atom.confidence)})"
        )
