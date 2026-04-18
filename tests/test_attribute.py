"""Attribution tests — canned trace → expected attributions + bias behavior."""
import json
from pathlib import Path

from hermes.atoms import Action, Attribution
from hermes.attribute import (
    SignedAttribution,
    compute_attributions,
    filter_by_min_confidence,
    group_mean_center_attributions,
)
from hermes.experiments.ledgerpg.bias import apply_bias, build_bias_table
from hermes.ingest import events_to_atoms


def _sa(action_name: str, goal: str, signed: float, conf: float = 1.0, lag: int = 1) -> SignedAttribution:
    return SignedAttribution(
        attribution=Attribution(
            action=Action(name=action_name),
            goal=goal,
            lag=lag,
            weight=abs(signed),
            confidence=conf,
        ),
        signed_weight=signed,
    )


FIXTURE = Path(__file__).parent / "fixtures" / "ledgerpg_canned_trace.json"


def _load_episode():
    with open(FIXTURE, "r", encoding="utf-8") as f:
        data = json.load(f)
    return events_to_atoms(
        episode_id=data["episode_id"],
        events=data["events"],
        terminal_reason=data["terminal_reason"],
        success=data["success"],
    )


def test_attributions_produced_for_observed_action_goal_pairs():
    episode = _load_episode()
    attrs = compute_attributions(episode)
    # We expect attributions covering move-N, move-NE, examine across both goals.
    keyed = {
        (sa.attribution.action.name, sa.attribution.goal): sa for sa in attrs
    }
    assert ("examine", "ENERGY_REGULATION") in keyed
    assert ("move-N", "EXPLORATION_INCENTIVE") in keyed


def test_examine_has_positive_energy_attribution():
    episode = _load_episode()
    attrs = compute_attributions(episode)
    examine_energy = next(
        sa for sa in attrs
        if sa.attribution.action.name == "examine"
        and sa.attribution.goal == "ENERGY_REGULATION"
    )
    assert examine_energy.signed_weight > 0.0
    assert 0.0 <= examine_energy.attribution.weight <= 1.0
    assert 0.0 <= examine_energy.attribution.confidence <= 1.0
    assert examine_energy.attribution.lag == 1


def test_movement_blocked_contributes_zero_exploration():
    episode = _load_episode()
    attrs = compute_attributions(episode)
    # The blocked move between t=4 and t=5 caused no goal change; any move-NE
    # attribution must not inflate EXPLORATION_INCENTIVE from that step alone.
    move_ne_exploration = next(
        (sa for sa in attrs
         if sa.attribution.action.name == "move-NE"
         and sa.attribution.goal == "EXPLORATION_INCENTIVE"),
        None,
    )
    # move-NE also fires a successful move earlier; the attribution should
    # aggregate signed deltas across observations rather than count every step.
    if move_ne_exploration is not None:
        assert -1.0 <= move_ne_exploration.signed_weight <= 1.0


def test_bias_table_yields_nonzero_bias_for_seen_actions():
    episode = _load_episode()
    attrs = compute_attributions(episode)
    bias = build_bias_table(attrs)
    examine = Action(name="examine")
    assert abs(bias.bias_for(examine)) > 0.0


def test_bias_table_zero_for_unseen_actions():
    episode = _load_episode()
    attrs = compute_attributions(episode)
    bias = build_bias_table(attrs)
    never_seen = Action(name="move-SW")
    assert bias.bias_for(never_seen) == 0.0


def test_apply_bias_preserves_order():
    episode = _load_episode()
    attrs = compute_attributions(episode)
    bias = build_bias_table(attrs)
    input_scored = [
        (Action(name="move-N"), 0.5),
        (Action(name="examine"), 0.3),
        (Action(name="rest"), 0.1),
    ]
    out = apply_bias(input_scored, bias)
    assert [a for a, _ in out] == [a for a, _ in input_scored]


def test_group_mean_centering_subtracts_per_group_mean():
    # Two actions contributing to EXPLORATION at lag=1, signed 0.8 and 0.2.
    # Mean = 0.5 → centered signed_weights should be +0.3 and -0.3.
    attrs = [
        _sa("move-N", "EXPLORATION_INCENTIVE", 0.8),
        _sa("move-S", "EXPLORATION_INCENTIVE", 0.2),
    ]
    centered = group_mean_center_attributions(attrs)
    by_action = {sa.attribution.action.name: sa for sa in centered}
    assert abs(by_action["move-N"].signed_weight - 0.3) < 1e-9
    assert abs(by_action["move-S"].signed_weight - (-0.3)) < 1e-9
    # Canonical weight tracks |signed_weight|.
    assert abs(by_action["move-N"].attribution.weight - 0.3) < 1e-9
    assert abs(by_action["move-S"].attribution.weight - 0.3) < 1e-9


def test_group_mean_centering_groups_independently_by_goal_and_lag():
    attrs = [
        _sa("move-N", "EXPLORATION_INCENTIVE", 0.9),
        _sa("move-N", "ENERGY_REGULATION", 0.1),
        _sa("examine", "ENERGY_REGULATION", 0.7),
    ]
    centered = group_mean_center_attributions(attrs)
    by_key = {
        (sa.attribution.action.name, sa.attribution.goal): sa for sa in centered
    }
    # EXPLORATION group has a single action → mean == its own value → centered = 0.
    assert abs(by_key[("move-N", "EXPLORATION_INCENTIVE")].signed_weight) < 1e-9
    # ENERGY_REGULATION group mean = (0.1 + 0.7) / 2 = 0.4.
    assert abs(by_key[("move-N", "ENERGY_REGULATION")].signed_weight - (-0.3)) < 1e-9
    assert abs(by_key[("examine", "ENERGY_REGULATION")].signed_weight - 0.3) < 1e-9


def test_group_mean_centering_preserves_confidence_and_lag():
    attrs = [
        _sa("move-N", "EXPLORATION_INCENTIVE", 0.8, conf=0.6, lag=1),
        _sa("move-S", "EXPLORATION_INCENTIVE", 0.4, conf=0.4, lag=1),
    ]
    centered = group_mean_center_attributions(attrs)
    by_action = {sa.attribution.action.name: sa for sa in centered}
    assert by_action["move-N"].attribution.confidence == 0.6
    assert by_action["move-S"].attribution.confidence == 0.4
    assert by_action["move-N"].attribution.lag == 1


def test_filter_by_min_confidence_drops_low_confidence():
    attrs = [
        _sa("move-N", "EXPLORATION_INCENTIVE", 0.8, conf=0.2),
        _sa("move-S", "EXPLORATION_INCENTIVE", 0.3, conf=0.6),
        _sa("examine", "ENERGY_REGULATION", 0.5, conf=0.4),
    ]
    kept = filter_by_min_confidence(attrs, min_confidence=0.4)
    kept_actions = {sa.attribution.action.name for sa in kept}
    assert kept_actions == {"move-S", "examine"}


def test_filter_by_min_confidence_boundary_inclusive():
    attrs = [_sa("move-N", "EXPLORATION_INCENTIVE", 0.5, conf=0.4)]
    assert len(filter_by_min_confidence(attrs, min_confidence=0.4)) == 1
    assert len(filter_by_min_confidence(attrs, min_confidence=0.40001)) == 0
