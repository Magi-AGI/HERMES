Ingestion Sketch

Purpose
- Illustrate how HERMES can ingest JSONL traces and emit MeTTa/Atomspace facts.
- Provide a simple baseline for mapping actions and goal deltas to example atoms.

Overview
- Inputs: NDJSON (one JSON object per line) with fields described in message-contracts.md.
- Outputs: MeTTa expressions for CausalLink, SatisfactionDelta, and naive Attribution.

Algorithm (simplified)
1) Read events grouped by episode_id and sorted by t.
2) For each step, map action names to simple ΔState atoms:
   - pickup X → (inventory added X)
   - place X L → (world placed X L)
   - examine X → (knowledge discovered (...)) if present in state
3) Emit (CausalLink (action ...) (StateDelta ...)).
4) Compute goal deltas between consecutive steps; for each non-zero delta:
   - Emit (SatisfactionDelta Goal Δ)
   - Emit naive (Attribution (action ...) Goal lag weight confidence)
     - lag = 0 by default; can be updated by temporal credit component
     - weight = normalized |Δ| within the window or a simple |Δ|
     - confidence = heuristic default (e.g., 0.5)

Usage
- See docs/sketch/ingest.py for a minimal working example.
- Example:
  - python docs/sketch/ingest.py docs/samples/traces/hello-cube.jsonl --out docs/metta/out-hello-cube.metta

Notes
- This sketch is intentionally naive and serves only as an executable example; the production system will implement temporal credit, lag inference, calibrated confidences, and pattern-miner integration.

