"""Ingest tests — canned trace → expected atoms."""
import json
from pathlib import Path

from hermes.atoms import Action
from hermes.ingest import events_to_atoms


FIXTURE = Path(__file__).parent / "fixtures" / "ledgerpg_canned_trace.json"


def _load():
    with open(FIXTURE, "r", encoding="utf-8") as f:
        return json.load(f)


def test_ingest_step_count():
    data = _load()
    atoms = events_to_atoms(
        episode_id=data["episode_id"],
        events=data["events"],
        terminal_reason=data["terminal_reason"],
        success=data["success"],
    )
    assert len(atoms.steps) == len(data["events"])
    assert atoms.episode_id == "ep-canned-0001"
    assert atoms.terminal_reason == "target_reached"
    assert atoms.success is True


def test_ingest_emits_links_for_all_delta_kinds():
    data = _load()
    atoms = events_to_atoms(
        episode_id=data["episode_id"],
        events=data["events"],
    )
    seen_kinds_in_links = set()
    for _t, _action, links, _sat in atoms.steps:
        for link in links:
            if "agent-at" in link.dst:
                seen_kinds_in_links.add("position")
            elif "energy" in link.dst:
                seen_kinds_in_links.add("energy")
            elif "tile-discovered" in link.dst:
                seen_kinds_in_links.add("tile-discovered")
            elif "food-consumed" in link.dst:
                seen_kinds_in_links.add("food-consumed")
            elif "movement-blocked" in link.dst:
                seen_kinds_in_links.add("movement-blocked")
    assert seen_kinds_in_links == {
        "position", "energy", "tile-discovered", "food-consumed", "movement-blocked"
    }


def test_ingest_emits_satisfaction_deltas_between_steps():
    data = _load()
    atoms = events_to_atoms(
        episode_id=data["episode_id"],
        events=data["events"],
    )
    # First step has no prior, so no satisfaction deltas.
    _t0, _a0, _l0, sat0 = atoms.steps[0]
    assert sat0 == []
    # Step 2 sees EXPLORATION_INCENTIVE go 0.08 → 0.12 and ENERGY_REGULATION go 0.95 → 0.90
    _t1, _a1, _l1, sat1 = atoms.steps[1]
    deltas_by_goal = {sd.goal: sd.delta for sd in sat1}
    assert abs(deltas_by_goal["EXPLORATION_INCENTIVE"] - 0.04) < 1e-9
    assert abs(deltas_by_goal["ENERGY_REGULATION"] - (-0.05)) < 1e-9


def test_ingest_action_names_preserved():
    data = _load()
    atoms = events_to_atoms(
        episode_id=data["episode_id"],
        events=data["events"],
    )
    action_names = [action.name for _t, action, _l, _s in atoms.steps]
    assert action_names[:3] == ["move-N", "move-N", "examine"]
    assert Action(name="move-NE") == atoms.steps[3][1]
