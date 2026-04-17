# LedgeRPG Server MVP — HERMES/MAGUS Contract

**Purpose:** Minimal Python game server for LedgeRPG, consumed headlessly by MAGUS+HERMES for the April 20 2026 AGI paper experiments. The Unity client is downstream of this contract and is not required for paper results.

**Inspiration:** Berick / Patrick Hammer AIRIS grid-world demo — simplicity is the goal.

## Scope guarantees

- **Deterministic:** same seed → same initial map, same reward positions, same tile types.
- **Headless-first:** pure HTTP JSON; no Unity dependency.
- **HERMES-native trace output:** every step emits a trace line in the existing HERMES Trace JSON format (see `hermes/docs/goals.md`). The server is the source of truth for traces; no translation layer.
- **Resettable:** starting a new episode must be a single call and must fully reset state.

## World model

- **Grid:** 8×8 hex grid using axial coordinates `(q, r)`. (Offset-based coords are fine internally; axial at the API.)
- **Tile types** (3 only):
  - `empty` — passable, no effect
  - `food` — passable, restores energy when examined
  - `obstacle` — impassable
- **Agent:** single agent with `position: (q, r)` and `energy ∈ [0.0, 1.0]` (starts at 1.0).
- **Visited set:** server tracks `visited_tiles: Set<(q,r)>`.

## Action set (8 discrete)

- `move-N`, `move-NE`, `move-SE`, `move-S`, `move-SW`, `move-NW` — energy cost `0.05` per move; no-op if target tile is `obstacle` or out-of-bounds
- `examine` — reveals tile type at current position; if tile is `food`, restores energy to 1.0 and marks that food tile as `consumed` (becomes `empty`)
- `rest` — energy cost 0.0; increments step counter (for time-limited experiments)

## Episode termination

Every episode ends with a single `terminal_reason` enum:

- `"target_reached"` — **success**: all food tiles consumed (task objective)
- `"step_limit"` — failure: reached max steps without clearing all food
- `"energy_depleted"` — failure: energy ≤ 0.0

**The task objective is "collect all food tiles"**, not mere survival. This is load-bearing for the MAGUS+HERMES-vs-MAGUS comparison: a trivial stay-alive heuristic would dominate a pure survival task and make the HERMES feedback loop look redundant. Requiring full-collection forces episode-to-episode learning about which tile discoveries led to energy-efficient paths.

## Goal satisfaction signals (emitted per step)

Two goals for MVP (both in `[0.0, 1.0]`, higher = more satisfied):

- `EXPLORATION_INCENTIVE`: `visited_count / total_passable_tiles`
- `ENERGY_REGULATION`: `current_energy / 1.0`

MAGUS uses these as live goal values; HERMES records their deltas between steps for `SatisfactionDelta` atoms.

## HTTP API

All endpoints are JSON in/out. Server binds to `127.0.0.1:<port>` by default.

### `POST /episode/start`
**Request:** `{ "seed": 42, "grid_size": 8, "step_limit": 100, "food_count": 5, "obstacle_count": 8 }`
**Response:** `{ "episode_id": "ep-000042", "state": <State>, "goals": <Goals> }`

### `POST /episode/step`
**Request:** `{ "episode_id": "ep-000042", "action": {"name": "move-N"} }`
**Response:**
```json
{
  "trace": {
    "episode_id": "ep-000042",
    "t": 7,
    "action": {"name": "move-N", "args": {}},
    "valid_actions": ["move-N", "move-NE", "move-SE", "move-S", "move-SW", "move-NW", "examine", "rest"],
    "state": {
      "agent": {"q": 3, "r": 4, "energy": 0.65},
      "tile": {"type": "empty"},
      "visited_count": 12,
      "food_remaining": 3
    },
    "state_delta": [
      {"kind": "position", "from": [3, 5], "to": [3, 4]},
      {"kind": "energy", "delta": -0.05, "from": 0.70, "to": 0.65},
      {"kind": "tile-discovered", "at": [3, 4]}
    ],
    "goals": { "EXPLORATION_INCENTIVE": 0.34, "ENERGY_REGULATION": 0.65 },
    "context": { "scenario": "LedgeRPG-MVP", "seed": 42 }
  },
  "done": false,
  "success": false,
  "terminal_reason": null
}
```

The `trace` object conforms to the HERMES Trace JSON format in `goals.md`. HERMES ingests it as-is.

**`state_delta` emission is required**, not optional. The server computes deltas directly rather than forcing HERMES to diff consecutive states; this avoids brittleness and makes the causal-link construction cleaner. Delta `kind` values for MVP:
- `position` — agent moved between tiles (includes blocked-move no-ops as `from == to`)
- `energy` — energy changed
- `tile-discovered` — first visit to a tile
- `food-consumed` — food tile became `empty` via `examine`
- `movement-blocked` — action was `move-*` but target was obstacle or out-of-bounds

Each delta kind maps directly to one or more HERMES atoms (e.g. `(agent-moved N)`, `(energy decreased 0.05)`, `(tile-discovered (3,4))`, `(food-consumed (5,2))`).

On terminal step, response includes `"success": true|false` and `"terminal_reason"` enum.

### `GET /episode/state?episode_id=ep-000042`
Returns current `state` + `goals` + `done` without advancing. Convenience for debugging.

### `POST /episode/end`
**Request:** `{ "episode_id": "ep-000042" }`
**Response:** `{ "ok": true, "final_trace_count": 87 }`

## State schema

```json
{
  "agent_position": [q, r],
  "energy": 0.65,
  "visited_count": 12,
  "step": 7,
  "last_tile_type": "empty",
  "grid": { /* optional: full grid for debug; agent can also derive from step history */ }
}
```

The agent's observation may be *partial* (nearby-only) or *full*. For MVP, emit **full grid** in `/episode/start`, then emit only the agent's position/energy updates per step. This keeps traces small while giving MAGUS enough info to rank moves.

## Determinism + reproducibility

- Seed controls: initial agent position, food tile positions, obstacle positions.
- Same seed + same action sequence → **logically identical** trace sequences (canonical JSON: sorted keys, no timestamps or wallclock fields, stable float formatting).
- Do not emit `timestamp`, `wallclock`, `server_pid`, or any similar field in traces. Anything that changes between runs breaks the paper's reproducibility claim.
- This is **load-bearing** for the paper's MAGUS-vs-MAGUS+HERMES comparison — both conditions must run on identical world instances.

## Non-requirements (explicitly out of scope for MVP)

- No multi-agent, no noise/observation dropout, no modulator emission (leave `context` fields sparse — MAGUS doesn't need Bach modulators for the MVP).
- No win/loss narrative; termination is mechanical.
- No rendering, no animation, no Unity hooks. Unity client consumes the same API later.
- No pattern mining, no MORK persistence, no motif discovery.

## Minimal deliverable for paper

1. `python -m ledgerpg.server --port 8765 --seed 42` starts the server.
2. A reference client script that runs a hardcoded action sequence and prints the trace stream — proves the contract before MAGUS/HERMES plug in.
3. Unit tests: determinism (two seed-42 episodes with same action sequence produce logically identical trace sequences), termination (all three terminal reasons fire correctly), action validation (invalid actions rejected, blocked moves produce `movement-blocked` deltas).
4. Expected experiment load: **30 fixed seeds × 2 conditions = 60 episodes**, each capped at 100 steps. Server must handle this batch headlessly in minutes, not hours.

## HERMES feedback-loop scope (the paper's "result")

Strictly **episode-level**, not online within an episode:

- Episode N runs to termination, trace stored.
- Between episodes, HERMES computes `Attribution(action, goal, lag, weight, confidence)` tuples from the accumulated trace history.
- Episode N+1: MAGUS's action-ranking applies a small additive or multiplicative bias from those attributions when scoring candidate actions. No mid-episode updates.

This keeps HERMES out of the hot loop and avoids accidentally building a planner.

## Estimated scope

~300-500 lines of Python. Should fit inside a day of focused work by one agent.
