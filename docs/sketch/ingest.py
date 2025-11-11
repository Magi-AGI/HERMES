#!/usr/bin/env python3
"""
Minimal ingestion sketch: JSONL traces -> MeTTa facts.

Usage:
  python docs/sketch/ingest.py docs/samples/traces/hello-cube.jsonl --out docs/metta/out-hello-cube.metta

This is a demo-only script. Real HERMES will implement temporal credit,
lag inference, calibrated confidences, and Atomspace writes.
"""
import json
import argparse
from collections import defaultdict


def map_action_to_delta(action: dict, state: dict) -> str | None:
    name = action.get("name")
    args = action.get("args", {}) or {}
    if name == "pickup" and "object" in args:
        x = args["object"]
        return f"(inventory added {x})"
    if name == "place" and "object" in args and "location" in args:
        x = args["object"]
        loc = args["location"]
        return f"(world placed {x} {loc})"
    if name == "examine" and "object" in args:
        x = args["object"]
        # If state reveals composition, emit knowledge discovery
        comp = None
        # attempt nested lookup
        for key in ("knowledge",):
            if isinstance(state.get(key), dict) and "composition" in state[key]:
                comp = state[key]["composition"]
        if comp:
            return f"(knowledge discovered (composition {comp}))"
        return f"(knowledge discovered ({x}))"
    return None


def iter_events(path):
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            yield json.loads(line)


def emit(event, prev_goals, out_lines):
    action = event.get("action", {})
    state = event.get("state", {})
    goals = event.get("goals", {}) or {}

    delta = map_action_to_delta(action, state)
    if delta:
        out_lines.append(f"(CausalLink ({action['name']} { ' '.join(str(v) for v in action.get('args', {}).values())}) {delta})")

    # satisfaction deltas
    if prev_goals is not None:
        for g, val in goals.items():
            prev = prev_goals.get(g)
            if prev is None:
                continue
            dv = val - prev
            if abs(dv) > 1e-9:
                sign = "+" if dv >= 0 else ""
                out_lines.append(f"(SatisfactionDelta {g} {sign}{dv:.3f})")
                # naive attribution
                if action.get("name"):
                    out_lines.append(
                        f"(Attribution ({action['name']} { ' '.join(str(v) for v in action.get('args', {}).values())}) {g} 0 {abs(dv):.3f} 0.500)"
                    )


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("trace", help="Path to JSONL trace file")
    ap.add_argument("--out", required=True, help="Output MeTTa file")
    args = ap.parse_args()

    # group by episode and sort by t
    episodes = defaultdict(list)
    for ev in iter_events(args.trace):
        episodes[ev.get("episode_id", "unknown")].append(ev)
    for ep in episodes.values():
        ep.sort(key=lambda e: e.get("t", 0))

    out_lines = []
    for eid, ep in episodes.items():
        prev_goals = None
        for ev in ep:
            emit(ev, prev_goals, out_lines)
            prev_goals = ev.get("goals", {}) or {}

    with open(args.out, "w", encoding="utf-8") as f:
        for line in out_lines:
            f.write(line + "\n")


if __name__ == "__main__":
    main()

