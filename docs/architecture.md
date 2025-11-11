Architecture Overview

Component Diagram:
```
┌────────────────────────────────────────────────────────────┐
│                      HERMES System                         │
├────────────────────────────────────────────────────────────┤
│  ┌────────────┐   ┌───────────────┐   ┌────────────────┐  │
│  │ Ingestion  │──▶│    Event      │──▶│     State      │  │
│  │  Module    │   │ Segmentation  │   │  Differencing  │  │
│  └────────────┘   └───────────────┘   └────────────────┘  │
│                                               │            │
│                                               ▼            │
│                                   ┌───────────────────┐   │
│                                   │  Goal Delta       │   │
│                                   │  Extraction       │   │
│                                   └───────────────────┘   │
│                                               │            │
│                                               ▼            │
│                           ┌──────────────────────────────┐│
│                           │ Temporal Credit & Confidence ││
│                           └──────────────────────────────┘│
│                                               │            │
│                                               ▼            │
│                           ┌──────────────────────────────┐│
│                           │  Causal Graph Constructor    ││
│                           └──────────────────────────────┘│
│                                       │                    │
│                    ┌──────────────────┴──────────────┐    │
│                    ▼                                  ▼    │
│           ┌────────────────┐               ┌──────────────┐│
│           │    Pattern     │               │   Export &   ││
│           │    Miner       │◀──────────────│    Query     ││
│           │  Integration   │               │    Engine    ││
│           └────────────────┘               └──────────────┘│
│                    │                                  │    │
│                    ▼                                  ▼    │
│           ┌──────────────────────────────────────────────┐│
│           │      Atomspace + MORK Persistence            ││
│           └──────────────────────────────────────────────┘│
│                                                            │
├────────────────────────────────────────────────────────────┤
│                   External Interfaces                      │
│  ┌────────────┐  ┌────────────┐  ┌────────────────────┐  │
│  │   MAGUS    │  │   AIRIS    │  │  CLI / HTTP API    │  │
│  │ Connector  │  │ Connector  │  │                    │  │
│  └────────────┘  └────────────┘  └────────────────────┘  │
└────────────────────────────────────────────────────────────┘
```

Component Descriptions:

1. Ingestion Module
   - Batch loader: Reads episode files (JSONL format) from games/AIRIS
     - Validates JSON schema: episode_id, t, action, state, goals, context
     - Returns ingestion summary: {accepted: N, rejected: M, reasons: [...]}
   - Stream adapter: Subscribes to live logs and buffers into 1000-event segments
     - Supports concurrent ingestion of multiple episodes
     - Transactional semantics: no data loss during ingestion

2. Event Segmentation
   - Splits streams into episodes/sub-episodes by:
     - Goal shifts: Change in dominant goal (e.g., Safety → Exploration)
     - Significant ΔState: Composite state change exceeds threshold
     - Explicit markers: action.name = "episode_start" / "episode_end"
     - Time gaps: Δt > threshold (e.g., 100 steps)
   - Emits trace chunks with metadata: episode ID, start/end timesteps, dominant goals, context summary

3. State Differencing
   - diff_state(s_t, s_{t+1}) → symbolic StateDelta atoms for MeTTa/Atomspace
   - Pluggable domain-specific mappers:
     - Inventory mapper: (inventory added item), (inventory removed item)
     - World state mapper: (gate open), (entity changed delta)
     - Numeric mapper: (key changed delta) for threshold-exceeding changes
   - Fallback to generic differ if no mapper matches

4. Goal Delta Extraction
   - measure_goal_change(goals_t, goals_{t+1}) for all MAGUS goals
   - Per-goal thresholds (default |Δ| ≥ 0.05) and normalization to [0,1]
   - Imports canonical goal IDs from ../metta-magus/ (JOY, GROWTH, CHOICE hierarchies)
   - Creates SatisfactionDelta(goal, Δ) atoms for significant changes

5. Temporal Credit & Confidence Module
   - Eligibility traces: e_t(action, goal) with goal-specific γ, λ parameters
     - Long-term goals (Safety): γ=0.95, λ=0.9
     - Short-term goals (POSITIVE_EMOTION): γ=0.7, λ=0.6
   - Lag inference via cross-correlation/MI across episodes
     - Stores distributions: (action, goal, context) → (τ_mean, τ_std)
   - Attribution weight: e_t(a,g) × lag_weight, normalized to sum ≤1.0
   - Confidence calibration: α×accuracy + β×consistency + γ×reliability (α=0.5, β=0.3, γ=0.2)

6. Causal Graph Constructor
   - Creates/updates Atomspace subgraphs: Action, StateDelta, Goal, Context nodes
   - Adds relations: CausalLink, SatisfactionDelta, Attribution with attributes (weight, confidence, lag)
   - Idempotent merges: Re-processing same episode updates weights/confidences via weighted average
   - Tags all atoms with episode, time window, context for provenance and filtering
   - Consistency enforcement: Attribution weights for (goal, horizon) sum ≤1.0

7. Pattern Miner Integration
   - Export phase: Publishes CausalLink and Attribution facts to &miner space (hyperon-miner compatible)
   - Discovery phase: Runs frequent pattern mining with min_support threshold (default 3)
   - Filter phase: Applies surprisingness scoring to identify causal vs. spurious motifs
   - Abstraction phase: Replaces frequent subgraphs (≥3 instances) with Motif nodes
   - Refinement phase: Updates lag distributions conditioned on motif context for improved credit assignment

8. Export & Query Engine
   - MeTTa serializer for all structures: CausalLink, Attribution, SatisfactionDelta
   - Query functions: get-attributions, get-causal-chain, suggest-actions
   - Atomspace writer with MORK persistence for high-performance storage
   - Optional HTTP API: /ingest, /attributions, /suggest-actions, /export
   - CLI tools: hermes ingest, hermes query, hermes export, hermes mine

9. MAGUS Connector
   - GetAttributions(goal, context, horizon): Returns actions attributed to goal satisfaction
   - SuggestActions(goal, context, k): Returns top-k actions for achieving goal
   - Integration with MAGUS scoring-v2: Provides attribution boosts to consideration scores
   - Context filtering: Matches modulator values (±0.2) and scenario tags

10. AIRIS Connector
    - IngestAIRISEpisode: Converts AIRIS logs to HERMES format
    - GetGoalHints(state, predictions): Suggests MAGUS goals likely to change
    - Maps AIRIS curiosity → MAGUS CURIOSITY_SATISFACTION/EXPLORATION
    - Enables feedback loop: AIRIS explores → HERMES learns → HERMES guides → AIRIS refines

Data Flow (high‑level)
1) AIRIS/games → Ingestion (JSON traces) → Event Segmentation
2) Segments → State Differencing + Goal Delta Extraction
3) → Temporal Credit & Confidence (with lag inference)
4) → Causal Graph Constructor (Atomspace/MeTTa)
5) → Pattern Miner round‑trip (motif compression, priors)
6) → Export & Query (MeTTa, API) → MAGUS/AIRIS
7) → Persist in MORK

Operational Notes
- MeTTa modules are organized per metta-best-practices with dedicated spaces (&kb for facts, &self for rules/queries/tests).
- Pattern miner runs can be scheduled batch‑wise on accumulated facts; streaming updates use incremental motifs when available.
- All graph operations tag Context and TimeWindow for selective retrieval and evaluation.

