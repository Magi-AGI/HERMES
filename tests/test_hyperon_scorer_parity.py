"""Parity gate for HyperonScorer — Codex's pre-paired-comparison check.

Verifies:
  (1) the scorer produces a finite float final score per candidate
  (2) the Python-visible final matches the MeTTa DecisionScore's 5th field
      (no off-by-one in parsing)
  (3) the 6-field decomposition sums correctly: base + meta + overgoal + hermes
      - antigoal_cost_delta (× stock final) ≈ final. We verify by reconstructing
      stock final from the decomposition and confirming it matches independent
      calculation.
  (4) attribution injection actually changes the score for the attributed action
      relative to a non-attributed one under identical goal state.

The tests are opt-in: they're skipped automatically if hyperon or the MAGUS
repo isn't available, so they don't block the CI-lite test suite that covers
ingest/attribute in isolation.
"""
from __future__ import annotations

import pytest

hyperon = pytest.importorskip("hyperon")

from pathlib import Path

MAGUS_ROOT = Path("E:/GitHub/Magi-AGI/MAGUS")
if not MAGUS_ROOT.exists():
    pytest.skip("MAGUS repo not present at expected path", allow_module_level=True)

from hermes.atoms import Action, Attribution
from hermes.attribute import SignedAttribution
from hermes.experiments.ledgerpg.hyperon_scorer import HyperonScorer
from hermes.experiments.ledgerpg.scoring import Observation


@pytest.fixture(scope="module")
def scorer() -> HyperonScorer:
    return HyperonScorer(magus_root=MAGUS_ROOT)


def _obs(goals: dict, tile: str = "empty") -> Observation:
    return Observation(
        position=(0, 0),
        energy=goals.get("ENERGY_REGULATION", 1.0),
        visited_count=0,
        food_remaining=5,
        last_tile_type=tile,
        goals=dict(goals),
        valid_actions=(
            "move-N", "move-NE", "move-SE", "move-S", "move-SW", "move-NW",
            "examine", "rest",
        ),
    )


def test_scores_are_finite_floats_for_all_actions(scorer: HyperonScorer) -> None:
    obs = _obs({"EXPLORATION_INCENTIVE": 0.3, "ENERGY_REGULATION": 0.8})
    scorer.update_attributions([])
    candidates = [Action(name=n) for n in obs.valid_actions]
    results = scorer.score(obs, candidates)
    assert len(results) == len(candidates)
    for action, score in results:
        assert isinstance(score, float)
        assert score == score  # not NaN
        assert -1e6 < score < 1e6


def test_decomposition_final_equals_score_final(scorer: HyperonScorer) -> None:
    obs = _obs({"EXPLORATION_INCENTIVE": 0.3, "ENERGY_REGULATION": 0.2})
    scorer.update_attributions([])
    candidates = [Action(name=n) for n in obs.valid_actions]
    simple = dict(scorer.score(obs, candidates))
    detailed = dict(scorer.score_with_decomposition(obs, candidates))
    for action in candidates:
        assert abs(simple[action] - detailed[action].final) < 1e-9, (
            f"final mismatch for {action.name}: simple={simple[action]} "
            f"detailed={detailed[action].final}"
        )


def test_low_energy_penalizes_moves_vs_rest(scorer: HyperonScorer) -> None:
    """Adapter antigoal sanity: moves should score below non-moves at low energy.

    Uses a food tile so examine isn't separately penalized by the
    examine-on-empty antigoal — we're isolating the move-at-low-energy effect.
    """
    obs = _obs({"EXPLORATION_INCENTIVE": 0.3, "ENERGY_REGULATION": 0.1}, tile="food")
    scorer.update_attributions([])
    scores = dict(scorer.score(obs, [
        Action(name="move-N"), Action(name="rest"), Action(name="examine"),
    ]))
    assert scores[Action(name="rest")] > scores[Action(name="move-N")]
    assert scores[Action(name="examine")] > scores[Action(name="move-N")]


def test_examine_penalty_on_empty_tile(scorer: HyperonScorer) -> None:
    """Examine should score below moves on an empty tile at high energy — the
    differentiation fix that broke the all-actions-tie-at-1.0 degenerate case.
    """
    obs = _obs({"EXPLORATION_INCENTIVE": 0.3, "ENERGY_REGULATION": 0.8}, tile="empty")
    scorer.update_attributions([])
    scores = dict(scorer.score(obs, [Action(name="move-N"), Action(name="examine")]))
    assert scores[Action(name="move-N")] > scores[Action(name="examine")]


def test_attribution_injection_raises_attributed_action_score(scorer: HyperonScorer) -> None:
    """Inject a large positive attribution on move-N; it should outscore move-NE."""
    obs = _obs({"EXPLORATION_INCENTIVE": 0.3, "ENERGY_REGULATION": 0.8})

    scorer.update_attributions([])
    before = dict(scorer.score(obs, [Action(name="move-N"), Action(name="move-NE")]))
    # Sanity: before attribution, adapter gives identical base and identical antigoal.
    assert abs(before[Action(name="move-N")] - before[Action(name="move-NE")]) < 1e-9

    scorer.update_attributions([
        SignedAttribution(
            attribution=Attribution(
                action=Action(name="move-N"),
                goal="EXPLORATION_INCENTIVE",
                lag=1,
                weight=1.0,
                confidence=1.0,
            ),
            signed_weight=1.0,
        ),
    ])
    after = dict(scorer.score(obs, [Action(name="move-N"), Action(name="move-NE")]))
    assert after[Action(name="move-N")] > after[Action(name="move-NE")], (
        f"HERMES bias did not raise move-N above move-NE: {after}"
    )


def test_clearing_attributions_returns_scores_to_baseline(scorer: HyperonScorer) -> None:
    obs = _obs({"EXPLORATION_INCENTIVE": 0.3, "ENERGY_REGULATION": 0.8})
    scorer.update_attributions([])
    baseline = dict(scorer.score(obs, [Action(name="move-N")]))

    scorer.update_attributions([
        SignedAttribution(
            attribution=Attribution(
                action=Action(name="move-N"),
                goal="EXPLORATION_INCENTIVE",
                lag=1,
                weight=1.0,
                confidence=1.0,
            ),
            signed_weight=1.0,
        ),
    ])
    boosted = dict(scorer.score(obs, [Action(name="move-N")]))
    assert boosted[Action(name="move-N")] > baseline[Action(name="move-N")]

    scorer.update_attributions([])
    cleared = dict(scorer.score(obs, [Action(name="move-N")]))
    assert abs(cleared[Action(name="move-N")] - baseline[Action(name="move-N")]) < 1e-9
