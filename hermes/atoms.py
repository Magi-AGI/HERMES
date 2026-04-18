"""Canonical HERMES atoms.

Shapes follow docs/data-model.md exactly. No additions, no renames.
"""
from __future__ import annotations

from dataclasses import dataclass
from typing import Tuple


@dataclass(frozen=True)
class Action:
    """Concrete action taken by an agent. `args` is an ordered tuple for determinism."""

    name: str
    args: Tuple[str, ...] = ()

    def as_sexpr(self) -> str:
        if not self.args:
            return f"({self.name})"
        return f"({self.name} {' '.join(self.args)})"


@dataclass(frozen=True)
class CausalLink:
    """(CausalLink src dst) — src and dst are arbitrary atom S-expressions."""

    src: str
    dst: str

    def as_sexpr(self) -> str:
        return f"(CausalLink {self.src} {self.dst})"


@dataclass(frozen=True)
class SatisfactionDelta:
    """(SatisfactionDelta goal delta) — delta is signed."""

    goal: str
    delta: float

    def as_sexpr(self) -> str:
        sign = "+" if self.delta >= 0 else ""
        return f"(SatisfactionDelta {self.goal} {sign}{self.delta:.3f})"


@dataclass(frozen=True)
class Attribution:
    """(Attribution action goal lag weight confidence).

    weight ∈ [0,1]: normalized contribution of action to goal within the window.
    confidence ∈ [0,1]: calibration of link strength.
    lag ∈ Z≥0: estimated delay in steps.
    """

    action: Action
    goal: str
    lag: int
    weight: float
    confidence: float

    def as_sexpr(self) -> str:
        return (
            f"(Attribution {self.action.as_sexpr()} {self.goal} "
            f"{self.lag} {self.weight:.3f} {self.confidence:.3f})"
        )
